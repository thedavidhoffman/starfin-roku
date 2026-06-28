'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVSeason")
    initReferences()
    initHandlers()
    m.pageState = {
        request: invalid
        season: invalid
        episodes: []
        episodesLoaded: false
        episodeWindowStart: 0
        episodeListScroll: "horizontal"
        focusArea: "episodes"
    }
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.logoBanner = m.top.findNode("logoBanner")
    m.seasonLabel = m.top.findNode("seasonLabel")
    m.episodesList = m.top.findNode("episodesList")
    m.episodesGrid = m.top.findNode("episodesGrid")
    m.leftChevron = m.top.findNode("leftChevron")
    m.rightChevron = m.top.findNode("rightChevron")
    m.tvSeasonTask = m.top.findNode("tvSeasonTask")
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.tvSeasonTask.observeField("response", "onTVSeasonResponse")
    m.episodesList.observeField("rowItemFocused", "onEpisodeFocused")
    m.episodesList.observeField("rowItemSelected", "onEpisodeSelected")
    m.episodesGrid.observeField("itemFocused", "onEpisodeFocused")
    m.episodesGrid.observeField("itemSelected", "onEpisodeSelected")
end sub

'-------------------------------------------------------------------------------
' onEpisodeSelected
'-------------------------------------------------------------------------------
sub onEpisodeSelected()
    selection = buildFocusedEpisodeDetailsSelection()
    if selection = invalid then return

    m.top.selectedEpisodeDetails = selection
end sub

'-------------------------------------------------------------------------------
' getEpisodeNodeAtPosition
'-------------------------------------------------------------------------------
function getEpisodeNodeAtPosition(position as dynamic) as object
    if position = invalid or position.Count() < 2 then return invalid
    if m.episodesList.content = invalid then return invalid

    row = m.episodesList.content.getChild(position[0])
    if row = invalid then return invalid

    return row.getChild(position[1])
end function

'-------------------------------------------------------------------------------
' getGridEpisodeNodeAtPosition
'-------------------------------------------------------------------------------
function getGridEpisodeNodeAtPosition(position as dynamic) as object
    if position = invalid then return invalid
    if m.episodesGrid.content = invalid then return invalid
    if position < 0 or position >= m.episodesGrid.content.getChildCount() then return invalid

    return m.episodesGrid.content.getChild(position)
end function

'-------------------------------------------------------------------------------
' getFocusedEpisodeNode
'-------------------------------------------------------------------------------
function getFocusedEpisodeNode() as object
    if isVerticalEpisodeList() then return getGridEpisodeNodeAtPosition(m.episodesGrid.itemFocused)
    return getEpisodeNodeAtPosition(m.episodesList.rowItemFocused)
end function

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.season = request.season
    m.pageState.episodes = []
    m.pageState.episodesLoaded = false
    m.pageState.episodeListScroll = getTVEpisodeListScrollSetting()
    m.pageState.focusArea = "episodes"
    clearEpisodes()
    Status_SetLoading()
    renderSeason(request.season)

    m.tvSeasonTask.request = request
    m.tvSeasonTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    m.pageState.episodeListScroll = getTVEpisodeListScrollSetting()

    if m.pageState.focusArea = "episodes" then
        if m.pageState.episodesLoaded = true then renderEpisodes(m.pageState.episodes)
        setEpisodeListVisible(hasEpisodeItems())
        updateChevrons()
        focusEpisodesIfActive()
    end if
end sub

'-------------------------------------------------------------------------------
' onTVSeasonResponse
'-------------------------------------------------------------------------------
sub onTVSeasonResponse()
    response = m.tvSeasonTask.response
    if response = invalid then return

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load tv season."))
        return
    end if

    payload = response.payload
    if payload = invalid then
        Status_SetMessage("Unable to load tv season.")
        return
    end if

    m.pageState.season = payload.season
    m.pageState.episodes = getItemsFromPayload(payload.episodes)
    m.pageState.episodesLoaded = true
    renderSeason(payload.season)
    renderEpisodes(m.pageState.episodes)
    Status_ClearMessage()
    updateChevrons()
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' onEpisodeFocused
'-------------------------------------------------------------------------------
sub onEpisodeFocused()
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' onWatchedStateChange
'-------------------------------------------------------------------------------
sub onWatchedStateChange()
    change = m.top.watchedStateChange
    if change = invalid then return

    itemId = SafeString(change.itemId, "")
    if itemId = "" then return

    isWatched = change.isWatched = true
    updateEpisodeWatchedState(itemId, isWatched)
    renderEpisodes(m.pageState.episodes)
    restoreEpisodeFocus(itemId)
    notifySeasonWatchedStateChanged()
end sub

'-------------------------------------------------------------------------------
' onPlaybackProgressChange
'-------------------------------------------------------------------------------
sub onPlaybackProgressChange()
    change = m.top.playbackProgressChange
    if change = invalid then return

    itemId = SafeString(change.itemId, "")
    if itemId = "" then return

    if updateEpisodePlaybackProgress(itemId, change) <> true then return

    renderEpisodes(m.pageState.episodes)
    restoreEpisodeFocus(itemId)
    notifySeasonWatchedStateChanged()
end sub

'-------------------------------------------------------------------------------
' renderSeason
'-------------------------------------------------------------------------------
sub renderSeason(item as dynamic)
    if isAssocArray(item) = false then return

    m.logoBanner.title = FirstNonEmpty([item.SeriesName], "")
    m.logoBanner.logoUrl = getSeriesLogoUrl()
    m.seasonLabel.text = getItemTitle(item)
end sub

'-------------------------------------------------------------------------------
' getSeriesLogoUrl
'-------------------------------------------------------------------------------
function getSeriesLogoUrl() as string
    request = m.pageState.request
    if request = invalid then return ""

    return getImageUrl(request.series, "Logo", 600, 300)
end function

'-------------------------------------------------------------------------------
' renderEpisodes
'-------------------------------------------------------------------------------
sub renderEpisodes(episodes as object)
    if isVerticalEpisodeList() then
        renderEpisodesGrid(episodes)
    else
        renderEpisodesList(episodes)
    end if

    setEpisodeListVisible(hasEpisodeItems())
    m.pageState.episodeWindowStart = 0
end sub

'-------------------------------------------------------------------------------
' renderEpisodesList
'-------------------------------------------------------------------------------
sub renderEpisodesList(episodes as object)
    rowContent = CreateObject("roSGNode", "ContentNode")
    row = rowContent.createChild("ContentNode")

    appendSeasonSummaryItem(row)

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        appendEpisodeItem(row, episode)
    end for

    m.episodesList.content = rowContent
    m.episodesGrid.content = CreateObject("roSGNode", "ContentNode")
end sub

'-------------------------------------------------------------------------------
' renderEpisodesGrid
'-------------------------------------------------------------------------------
sub renderEpisodesGrid(episodes as object)
    gridContent = CreateObject("roSGNode", "ContentNode")

    appendSeasonSummaryItem(gridContent)

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        appendEpisodeItem(gridContent, episode)
    end for

    m.episodesList.content = CreateObject("roSGNode", "ContentNode")
    m.episodesGrid.content = gridContent
end sub

'-------------------------------------------------------------------------------
' clearEpisodes
'-------------------------------------------------------------------------------
sub clearEpisodes()
    m.episodesList.content = CreateObject("roSGNode", "ContentNode")
    m.episodesGrid.content = CreateObject("roSGNode", "ContentNode")
    m.episodesList.visible = false
    m.episodesGrid.visible = false
    m.pageState.episodeWindowStart = 0
    m.leftChevron.visible = false
    m.rightChevron.visible = false
end sub

'-------------------------------------------------------------------------------
' appendEpisodeItem
'-------------------------------------------------------------------------------
sub appendEpisodeItem(parent as object, episode as object)
    child = parent.createChild("ContentNode")
    child.title = getItemTitle(episode)
    child.description = FirstNonEmpty([episode.Overview], "")
    child.HDPosterUrl = getImageUrl(episode, "Primary", 530, 298)
    child.AddFields({
        itemId: SafeString(FirstNonEmpty([episode.Id], ""), "")
        itemType: SafeString(FirstNonEmpty([episode.Type], ""), "")
        episodeIndexNumber: FirstNonEmpty([episode.IndexNumber], "")
        premiereDate: FirstNonEmpty([episode.PremiereDate], "")
        airDate: FirstNonEmpty([episode.AirDate], "")
        dateCreated: FirstNonEmpty([episode.DateCreated], "")
        progressPercent: getProgressPercent(episode)
        progressWidth: getProgressWidth(episode)
        raw: episode
    })
end sub

'-------------------------------------------------------------------------------
' buildFocusedEpisodeDetailsSelection
'-------------------------------------------------------------------------------
function buildFocusedEpisodeDetailsSelection() as dynamic
    focusedEpisode = getFocusedEpisodeNode()
    if focusedEpisode = invalid then return invalid

    return {
        loadRequest: buildEpisodeLoadRequest(focusedEpisode)
    }
end function

'-------------------------------------------------------------------------------
' buildEpisodeLoadRequest
'-------------------------------------------------------------------------------
function buildEpisodeLoadRequest(node as dynamic) as dynamic
    playSelection = buildEpisodePlaySelection(node)
    if playSelection = invalid then return invalid

    request = m.pageState.request
    if request = invalid then return invalid

    return {
        server: request.server
        token: request.token
        userId: request.userId
        seriesId: request.seriesId
        seasonId: request.seasonId
        series: buildSeriesIdentity(request, playSelection.item)
        season: buildSeasonIdentity(request)
        itemId: playSelection.itemId
        item: playSelection.item
        posterUrl: SafeString(node.HDPosterUrl, "")
        startPositionTicks: playSelection.startPositionTicks
        playbackQueue: playSelection.playbackQueue
        playbackQueueIndex: playSelection.playbackQueueIndex
    }
end function

'-------------------------------------------------------------------------------
' buildSeriesIdentity
'-------------------------------------------------------------------------------
function buildSeriesIdentity(request as object, item as dynamic) as object
    seriesName = ""
    seriesId = ""
    if request.series <> invalid then seriesName = FirstNonEmpty([request.series.Name], "")
    if item <> invalid then
        seriesId = FirstNonEmpty([item.SeriesId], "")
        seriesName = FirstNonEmpty([item.SeriesName, seriesName], "")
    end if

    return {
        Id: FirstNonEmpty([request.seriesId, seriesId], "")
        Name: seriesName
        logoUrl: getSeriesLogoUrl()
    }
end function

'-------------------------------------------------------------------------------
' buildSeasonIdentity
'-------------------------------------------------------------------------------
function buildSeasonIdentity(request as object) as object
    seasonName = ""
    if request.season <> invalid then seasonName = FirstNonEmpty([request.season.Name], "")

    return {
        Id: FirstNonEmpty([request.seasonId], "")
        Name: seasonName
    }
end function

'-------------------------------------------------------------------------------
' getEpisodeNodeById
'-------------------------------------------------------------------------------
function getEpisodeNodeById(itemId as string) as dynamic
    if isVerticalEpisodeList() then
        if m.episodesGrid.content = invalid then return invalid

        for i = 0 to m.episodesGrid.content.getChildCount() - 1
            child = m.episodesGrid.content.getChild(i)
            if child <> invalid and SafeString(child.itemId, "") = itemId then return child
        end for

        return invalid
    end if

    if m.episodesList.content = invalid or m.episodesList.content.getChildCount() = 0 then return invalid

    row = m.episodesList.content.getChild(0)
    if row = invalid then return invalid

    for i = 0 to row.getChildCount() - 1
        child = row.getChild(i)
        if child <> invalid and SafeString(child.itemId, "") = itemId then return child
    end for

    return invalid
end function

'-------------------------------------------------------------------------------
' appendSeasonSummaryItem
'-------------------------------------------------------------------------------
sub appendSeasonSummaryItem(row as object)
    season = m.pageState.season
    if row = invalid or isAssocArray(season) = false then return

    child = row.createChild("ContentNode")
    child.title = getItemTitle(season)
    child.description = getSeasonSummaryDescription(season)
    child.HDPosterUrl = getSeasonBackgroundUrl(season)
    child.AddFields({
        itemId: SafeString(FirstNonEmpty([season.Id], ""), "")
        itemType: "SeasonSummary"
        episodeCount: FirstNonEmpty([season.RecursiveItemCount, season.ChildCount], "")
        seasonYear: getSeasonYearText(season)
        raw: season
    })
end sub

'-------------------------------------------------------------------------------
' hasEpisodeItems
'-------------------------------------------------------------------------------
function hasEpisodeItems() as boolean
    if isVerticalEpisodeList() then
        return m.episodesGrid.content <> invalid and m.episodesGrid.content.getChildCount() > 0
    end if

    if m.episodesList.content = invalid then return false
    if m.episodesList.content.getChildCount() = 0 then return false

    row = m.episodesList.content.getChild(0)
    return row <> invalid and row.getChildCount() > 0
end function

'-------------------------------------------------------------------------------
' setEpisodeListVisible
'-------------------------------------------------------------------------------
sub setEpisodeListVisible(isVisible as boolean)
    m.episodesList.visible = isVisible and isVerticalEpisodeList() = false
    m.episodesGrid.visible = isVisible and isVerticalEpisodeList()
end sub

'-------------------------------------------------------------------------------
' getActiveEpisodeList
'-------------------------------------------------------------------------------
function getActiveEpisodeList() as object
    if isVerticalEpisodeList() then return m.episodesGrid
    return m.episodesList
end function

'-------------------------------------------------------------------------------
' isVerticalEpisodeList
'-------------------------------------------------------------------------------
function isVerticalEpisodeList() as boolean
    return m.pageState.episodeListScroll = "vertical"
end function

'-------------------------------------------------------------------------------
' getTVEpisodeListScrollSetting
'-------------------------------------------------------------------------------
function getTVEpisodeListScrollSetting() as string
    keys = SettingsStore_Keys()
    value = m.top.settings[keys.tvEpisodeListDisplay]

    if LCase(value) = "vertical" then return "vertical"
    return "horizontal"
end function

'-------------------------------------------------------------------------------
' getSeasonSummaryDescription
'-------------------------------------------------------------------------------
function getSeasonSummaryDescription(season as dynamic) as string
    description = FirstNonEmpty([season.Overview], "")
    if description <> "" then return description

    request = m.pageState.request
    if request = invalid then return ""

    series = request.series
    if isAssocArray(series) = false then return ""

    return FirstNonEmpty([series.Overview], "")
end function

'-------------------------------------------------------------------------------
' getSeasonYearText
'-------------------------------------------------------------------------------
function getSeasonYearText(season as dynamic) as string
    year = FirstNonEmpty([season.ProductionYear], "")
    if year <> "" then return SafeString(year, "")

    return getYearFromDate(FirstNonEmpty([season.PremiereDate], ""))
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' focusEpisodesIfActive
'-------------------------------------------------------------------------------
sub focusEpisodesIfActive()
    if hasEpisodeItems() = false then return

    m.pageState.focusArea = "episodes"
    setEpisodeListVisible(true)
    m.top.setFocus(true)
    getActiveEpisodeList().setFocus(true)
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' updateChevrons
'-------------------------------------------------------------------------------
sub updateChevrons()
    if isVerticalEpisodeList() then
        m.leftChevron.visible = false
        m.rightChevron.visible = false
        return
    end if

    overflow = getEpisodeOverflowState()
    m.leftChevron.visible = overflow.left
    m.rightChevron.visible = overflow.right
end sub

'-------------------------------------------------------------------------------
' getEpisodeOverflowState
'-------------------------------------------------------------------------------
function getEpisodeOverflowState() as object
    state = { left: false, right: false }
    visibleItemCount = 3

    if m.episodesList.content = invalid then return state
    if m.episodesList.content.getChildCount() = 0 then return state

    row = m.episodesList.content.getChild(0)
    if row = invalid then return state

    itemCount = row.getChildCount()
    if itemCount <= visibleItemCount then return state

    focused = m.episodesList.rowItemFocused
    finalWindowStart = itemCount - visibleItemCount
    windowStart = m.pageState.episodeWindowStart
    if windowStart = invalid then windowStart = 0

    if focused <> invalid and focused.Count() >= 2 then
        focusedIndex = focused[1]
        if focusedIndex < windowStart then
            windowStart = focusedIndex
        else if focusedIndex >= windowStart + visibleItemCount then
            windowStart = focusedIndex - visibleItemCount + 1
        end if
    end if

    if windowStart < 0 then windowStart = 0
    if windowStart > finalWindowStart then windowStart = finalWindowStart
    m.pageState.episodeWindowStart = windowStart

    state.left = windowStart > 0
    state.right = (windowStart + visibleItemCount) < itemCount

    return state
end function

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.Name], "")
end function

'-------------------------------------------------------------------------------
' getProgressPercent
'-------------------------------------------------------------------------------
function getProgressPercent(item as dynamic) as float
    if isAssocArray(item) = false then return 0
    if item.UserData <> invalid and item.UserData.Played = true then return 0

    if item.UserData <> invalid and item.UserData.PlayedPercentage <> invalid then
        playedPercentage = item.UserData.PlayedPercentage
        if playedPercentage <= 0 then return 0
        if playedPercentage > 100 then return 100
        return playedPercentage
    end if

    if item.RunTimeTicks = invalid or item.RunTimeTicks <= 0 then return 0

    progressTicks = PlaybackProgress_GetTicksFromItem(item)
    if progressTicks <= 0 then return 0

    progressPercent = (progressTicks / item.RunTimeTicks) * 100
    if progressPercent > 100 then return 100

    return progressPercent
end function

'-------------------------------------------------------------------------------
' getProgressWidth
'-------------------------------------------------------------------------------
function getProgressWidth(item as dynamic) as integer
    progressPercent = getProgressPercent(item)
    if progressPercent <= 0 then return 0

    progressWidth = int(510 * (progressPercent / 100))
    if progressWidth < 1 then return 1
    if progressWidth > 510 then return 510

    return progressWidth
end function

'-------------------------------------------------------------------------------
' updateEpisodeWatchedState
'-------------------------------------------------------------------------------
sub updateEpisodeWatchedState(itemId as string, isWatched as boolean)
    if isAssocArray(m.pageState.season) and SafeString(FirstNonEmpty([m.pageState.season.Id], ""), "") = itemId then
        updateItemWatchedState(m.pageState.season, isWatched)
        updateSeasonEpisodesWatchedState(isWatched)
        return
    end if

    for each episode in m.pageState.episodes
        if isAssocArray(episode) = false then continue for
        if SafeString(FirstNonEmpty([episode.Id], ""), "") <> itemId then continue for

        wasWatched = isItemWatched(episode)
        updateItemWatchedState(episode, isWatched)
        updateSeasonUnplayedCount(wasWatched, isWatched)
        return
    end for
end sub

'-------------------------------------------------------------------------------
' updateSeasonEpisodesWatchedState
'-------------------------------------------------------------------------------
sub updateSeasonEpisodesWatchedState(isWatched as boolean)
    for each episode in m.pageState.episodes
        updateItemWatchedState(episode, isWatched)
    end for

    if isAssocArray(m.pageState.season) = false then return
    if m.pageState.season.UserData = invalid then m.pageState.season.UserData = {}

    if isWatched then
        m.pageState.season.UserData.UnplayedItemCount = 0
    else
        m.pageState.season.UserData.UnplayedItemCount = getEpisodeCount()
    end if
end sub

'-------------------------------------------------------------------------------
' updateSeasonUnplayedCount
'-------------------------------------------------------------------------------
sub updateSeasonUnplayedCount(wasWatched as boolean, isWatched as boolean)
    if isAssocArray(m.pageState.season) = false then return
    if m.pageState.season.UserData = invalid then m.pageState.season.UserData = {}

    current = m.pageState.season.UserData.UnplayedItemCount
    if current = invalid then current = countUnplayedEpisodes()
    current = int(current)

    if isWatched then
        if wasWatched <> true and current > 0 then current = current - 1
    else
        if wasWatched = true or current = 0 then current = current + 1
    end if

    if current < 0 then current = 0
    m.pageState.season.UserData.UnplayedItemCount = current
end sub

'-------------------------------------------------------------------------------
' notifySeasonWatchedStateChanged
'-------------------------------------------------------------------------------
sub notifySeasonWatchedStateChanged()
    season = m.pageState.season
    if isAssocArray(season) = false then return

    seasonId = SafeString(FirstNonEmpty([season.Id], ""), "")
    if seasonId = "" then return

    unplayedItemCount = 0
    if season.UserData <> invalid and season.UserData.UnplayedItemCount <> invalid then
        unplayedItemCount = int(season.UserData.UnplayedItemCount)
    end if

    m.top.seasonWatchedStateChanged = {
        seasonId: seasonId
        unplayedItemCount: unplayedItemCount
        isWatched: unplayedItemCount = 0
    }
end sub

'-------------------------------------------------------------------------------
' countUnplayedEpisodes
'-------------------------------------------------------------------------------
function countUnplayedEpisodes() as integer
    count = 0
    for each episode in m.pageState.episodes
        if isAssocArray(episode) and isItemWatched(episode) <> true then count = count + 1
    end for

    return count
end function

'-------------------------------------------------------------------------------
' getEpisodeCount
'-------------------------------------------------------------------------------
function getEpisodeCount() as integer
    if m.pageState.episodes = invalid then return 0
    return m.pageState.episodes.Count()
end function

'-------------------------------------------------------------------------------
' isItemWatched
'-------------------------------------------------------------------------------
function isItemWatched(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    if item.UserData = invalid then return false

    return item.UserData.Played = true
end function

'-------------------------------------------------------------------------------
' updateItemWatchedState
'-------------------------------------------------------------------------------
sub updateItemWatchedState(item as dynamic, isWatched as boolean)
    if isAssocArray(item) = false then return
    if item.UserData = invalid then item.UserData = {}

    item.UserData.Played = isWatched
    if isWatched then
        item.UserData.PlayedPercentage = 0
        item.UserData.PlaybackPositionTicks = 0
    else
        item.UserData.PlayedPercentage = 0
    end if
end sub

'-------------------------------------------------------------------------------
' updateEpisodePlaybackProgress
'-------------------------------------------------------------------------------
function updateEpisodePlaybackProgress(itemId as string, change as object) as boolean
    for each episode in m.pageState.episodes
        if isAssocArray(episode) = false then continue for
        if SafeString(FirstNonEmpty([episode.Id], ""), "") <> itemId then continue for

        wasWatched = isItemWatched(episode)
        updateItemPlaybackProgress(episode, change)
        updateSeasonUnplayedCount(wasWatched, isItemWatched(episode))
        return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' updateItemPlaybackProgress
'-------------------------------------------------------------------------------
sub updateItemPlaybackProgress(item as dynamic, change as object)
    if isAssocArray(item) = false then return
    if item.UserData = invalid then item.UserData = {}

    if change.isFinished = true then
        item.UserData.Played = true
        item.UserData.PlayedPercentage = 0
        item.UserData.PlaybackPositionTicks = 0
    else
        positionTicks = getPlaybackProgressTicks(change.positionTicks)
        item.UserData.Played = false
        item.UserData.PlaybackPositionTicks = positionTicks
        item.UserData.PlayedPercentage = getPlaybackProgressPercentage(positionTicks, item.RunTimeTicks, change.durationTicks)
    end if
end sub

'-------------------------------------------------------------------------------
' getPlaybackProgressTicks
'-------------------------------------------------------------------------------
function getPlaybackProgressTicks(value as dynamic) as longinteger
    if value = invalid or value <= 0 then return 0

    return value
end function

'-------------------------------------------------------------------------------
' getPlaybackProgressPercentage
'-------------------------------------------------------------------------------
function getPlaybackProgressPercentage(positionTicks as dynamic, runtimeTicks as dynamic, durationTicks as dynamic) as float
    if positionTicks = invalid or positionTicks <= 0 then return 0
    if runtimeTicks = invalid or runtimeTicks <= 0 then runtimeTicks = durationTicks
    if runtimeTicks = invalid or runtimeTicks <= 0 then return 0

    percentage = (positionTicks / runtimeTicks) * 100
    if percentage > 100 then return 100

    return percentage
end function

'-------------------------------------------------------------------------------
' restoreEpisodeFocus
'-------------------------------------------------------------------------------
sub restoreEpisodeFocus(itemId as string)
    index = getEpisodeContentIndex(itemId)
    if index < 0 then return

    if isVerticalEpisodeList() then
        m.episodesGrid.jumpToItem = index
    else
        m.episodesList.jumpToRowItem = [0, index]
    end if
end sub

'-------------------------------------------------------------------------------
' getEpisodeContentIndex
'-------------------------------------------------------------------------------
function getEpisodeContentIndex(itemId as string) as integer
    if itemId = "" then return -1

    if isVerticalEpisodeList() then
        if m.episodesGrid.content = invalid then return -1

        for i = 0 to m.episodesGrid.content.getChildCount() - 1
            child = m.episodesGrid.content.getChild(i)
            if child <> invalid and SafeString(child.itemId, "") = itemId then return i
        end for

        return -1
    end if

    if m.episodesList.content = invalid or m.episodesList.content.getChildCount() = 0 then return -1

    row = m.episodesList.content.getChild(0)
    if row = invalid then return -1

    for i = 0 to row.getChildCount() - 1
        child = row.getChild(i)
        if child <> invalid and SafeString(child.itemId, "") = itemId then return i
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Primary" and item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then tag = item.ImageTags.Primary
    if imageType = "Logo" and item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
    if imageType = "Thumb" and item.ImageTags <> invalid and item.ImageTags.Thumb <> invalid then tag = item.ImageTags.Thumb
    if imageType = "Backdrop" and item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""
    request = m.pageState.request
    if request = invalid then return ""

    options = invalid
    if imageType = "Logo" then options = { format: "Png" }
    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height, options)
end function

'-------------------------------------------------------------------------------
' getSeasonBackgroundUrl
'-------------------------------------------------------------------------------
function getSeasonBackgroundUrl(season as dynamic) as string
    request = m.pageState.request
    if request <> invalid then
        imageUrl = getImageUrl(request.series, "Thumb", 530, 298)
        if imageUrl <> "" then return imageUrl

        imageUrl = getImageUrl(request.series, "Backdrop", 530, 298)
        if imageUrl <> "" then return imageUrl
    end if

    return ""
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []

    payloadType = Type(payload)
    if payloadType = "roArray" then return payload
    if isAssocArray(payload) = false then return []

    if payload.Items <> invalid then return payload.Items
    return []
end function

'-------------------------------------------------------------------------------
' buildEpisodePlaySelection
'-------------------------------------------------------------------------------
function buildEpisodePlaySelection(node as dynamic) as dynamic
    if node = invalid then return invalid

    itemId = SafeString(node.itemId, "")
    if itemId = "" then return invalid

    item = node.raw
    if isAssocArray(item) = false then return invalid

    playbackQueue = buildPlaybackQueue(m.pageState.episodes)
    playbackQueueIndex = getPlaybackQueueIndex(playbackQueue, itemId)

    return {
        itemId: itemId
        item: item
        startPositionTicks: PlaybackProgress_GetTicksFromItem(item)
        playbackQueue: playbackQueue
        playbackQueueIndex: playbackQueueIndex
    }
end function

'-------------------------------------------------------------------------------
' buildPlaybackQueue
'-------------------------------------------------------------------------------
function buildPlaybackQueue(episodes as object) as object
    queue = []

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        episodeId = SafeString(FirstNonEmpty([episode.Id], ""), "")
        if episodeId = "" then continue for

        queue.Push({
            itemId: episodeId
            item: episode
            startPositionTicks: PlaybackProgress_GetTicksFromItem(episode)
        })
    end for

    return queue
end function

'-------------------------------------------------------------------------------
' getPlaybackQueueIndex
'-------------------------------------------------------------------------------
function getPlaybackQueueIndex(playbackQueue as object, itemId as string) as integer
    if playbackQueue = invalid then return 0

    for i = 0 to playbackQueue.Count() - 1
        item = playbackQueue[i]
        if item <> invalid and SafeString(item.itemId, "") = itemId then return i
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    if values = invalid then return ""

    text = ""
    for each value in values
        part = String_Trim(SafeString(value, ""))
        if part <> "" then
            if text <> "" then text = text + separator
            text = text + part
        end if
    end for

    return text
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        Status_ClearMessage()
        m.top.closeRequested = true
        return true
    end if

    return false
end function

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
        episodeWindowStart: 0
        episodeListScroll: "horizontal"
        focusArea: "episodes"
    }
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.showLogo = m.top.findNode("showLogo")
    m.seriesLabel = m.top.findNode("seriesLabel")
    m.seasonLabel = m.top.findNode("seasonLabel")
    m.episodesList = m.top.findNode("episodesList")
    m.episodesGrid = m.top.findNode("episodesGrid")
    m.episodeDetails = m.top.findNode("episodeDetails")
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
    m.episodeDetails.observeField("closeRequested", "onEpisodeDetailsCloseRequested")
    m.episodeDetails.observeField("selectedPerson", "onEpisodeDetailsPersonSelected")
    m.episodeDetails.observeField("playSelected", "onEpisodeDetailsPlaySelected")
end sub

'-------------------------------------------------------------------------------
' onEpisodeSelected
'-------------------------------------------------------------------------------
sub onEpisodeSelected()
    focusEpisodeDetails()
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
    m.pageState.episodeListScroll = getTVEpisodeListScrollSetting()
    m.pageState.focusArea = "episodes"
    clearEpisodes()
    m.episodeDetails.loadRequest = request
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
    if m.episodeDetails.visible = true then updateEpisodeDetails()
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsCloseRequested
'-------------------------------------------------------------------------------
sub onEpisodeDetailsCloseRequested()
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsPlaySelected
'-------------------------------------------------------------------------------
sub onEpisodeDetailsPlaySelected()
    selection = buildFocusedEpisodePlaySelection()
    if selection = invalid then return

    m.top.selectedEpisode = selection
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsPersonSelected
'-------------------------------------------------------------------------------
sub onEpisodeDetailsPersonSelected()
    selection = m.episodeDetails.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' renderSeason
'-------------------------------------------------------------------------------
sub renderSeason(item as dynamic)
    if isAssocArray(item) = false then return

    m.seriesLabel.text = FirstNonEmpty([item.SeriesName], "")
    m.seasonLabel.text = getItemTitle(item)
    renderShowLogo()
end sub

'-------------------------------------------------------------------------------
' renderShowLogo
'-------------------------------------------------------------------------------
sub renderShowLogo()
    request = m.pageState.request
    if request = invalid then
        m.showLogo.visible = false
        m.seriesLabel.visible = true
        return
    end if

    logoUrl = getImageUrl(request.series, "Logo", 600, 300)
    m.showLogo.visible = logoUrl <> ""
    m.showLogo.uri = logoUrl
    m.seriesLabel.visible = logoUrl = ""
end sub

'-------------------------------------------------------------------------------
' renderEpisodes
'-------------------------------------------------------------------------------
sub renderEpisodes(episodes as object)
    rowContent = CreateObject("roSGNode", "ContentNode")
    row = rowContent.createChild("ContentNode")
    gridContent = CreateObject("roSGNode", "ContentNode")

    appendSeasonSummaryItem(row)
    appendSeasonSummaryItem(gridContent)

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        appendEpisodeItem(row, episode)
        appendEpisodeItem(gridContent, episode)
    end for

    hasEpisodes = row.getChildCount() > 0
    m.episodesList.content = rowContent
    m.episodesGrid.content = gridContent
    setEpisodeListVisible(hasEpisodes)
    m.pageState.episodeWindowStart = 0
end sub

'-------------------------------------------------------------------------------
' clearEpisodes
'-------------------------------------------------------------------------------
sub clearEpisodes()
    m.episodesList.content = CreateObject("roSGNode", "ContentNode")
    m.episodesGrid.content = CreateObject("roSGNode", "ContentNode")
    m.episodesList.visible = false
    m.episodesGrid.visible = false
    m.episodeDetails.visible = false
    m.episodeDetails.itemContent = invalid
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
        episodeNumber: getEpisodeNumberText(episode)
        episodeDate: getEpisodeDateText(episode)
        progressPercent: getProgressPercent(episode)
        progressWidth: getProgressWidth(episode)
        raw: episode
    })
end sub

'-------------------------------------------------------------------------------
' updateEpisodeDetails
'-------------------------------------------------------------------------------
sub updateEpisodeDetails()
    focusedEpisode = getFocusedEpisodeNode()
    if focusedEpisode = invalid then return

    m.episodeDetails.itemContent = focusedEpisode
end sub

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
        itemId: ""
        itemType: "SeasonSummary"
        episodeNumber: getSeasonEpisodeCountText(season)
        episodeDate: getSeasonYearText(season)
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
' getSeasonEpisodeCountText
'-------------------------------------------------------------------------------
function getSeasonEpisodeCountText(season as dynamic) as string
    episodeCount = FirstNonEmpty([season.RecursiveItemCount, season.ChildCount], "")
    if episodeCount = "" then return ""

    return SafeString(episodeCount, "") + " episodes"
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
    if m.pageState.focusArea = "details" and m.episodeDetails.visible = true then
        m.episodeDetails.callFunc("activate")
    else
        focusEpisodesIfActive()
    end if
end sub

'-------------------------------------------------------------------------------
' focusEpisodesIfActive
'-------------------------------------------------------------------------------
sub focusEpisodesIfActive()
    if hasEpisodeItems() = false then return

    m.pageState.focusArea = "episodes"
    setEpisodeListVisible(true)
    m.episodeDetails.visible = false
    m.episodeDetails.callFunc("deactivate")
    m.top.setFocus(true)
    getActiveEpisodeList().setFocus(true)
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' focusEpisodeDetails
'-------------------------------------------------------------------------------
sub focusEpisodeDetails()
    m.pageState.focusArea = "details"
    m.episodesList.visible = false
    m.episodesGrid.visible = false
    updateEpisodeDetails()
    m.episodeDetails.visible = true
    m.leftChevron.visible = false
    m.rightChevron.visible = false
    m.episodeDetails.callFunc("activate")
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
' getEpisodeNumberText
'-------------------------------------------------------------------------------
function getEpisodeNumberText(item as dynamic) as string
    indexText = FirstNonEmpty([item.IndexNumber], "")
    if indexText <> "" then return "Episode " + SafeString(indexText, "")
    return "Episode"
end function

' getAiredDateText
'-------------------------------------------------------------------------------
function getAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.PremiereDate, item.AirDate, item.DateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

'-------------------------------------------------------------------------------
' getEpisodeDateText
'-------------------------------------------------------------------------------
function getEpisodeDateText(item as dynamic) as string
    airedDate = getAiredDateText(item)
    if Len(airedDate) < 10 then return airedDate

    year = Left(airedDate, 4)
    monthNumber = val(Mid(airedDate, 6, 2))
    day = val(Mid(airedDate, 9, 2))
    if monthNumber < 1 or monthNumber > 12 or day < 1 then return airedDate

    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return day.ToStr() + " " + monthNames[monthNumber - 1] + " " + year
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

    return buildImageUrl(itemId, imageType, tag, width, height)
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
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.pageState.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    imageUrl = url + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    if imageType = "Logo" then imageUrl = imageUrl + "&format=Png"
    return imageUrl
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
' buildFocusedEpisodePlaySelection
'-------------------------------------------------------------------------------
function buildFocusedEpisodePlaySelection() as dynamic
    node = getFocusedEpisodeNode()
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

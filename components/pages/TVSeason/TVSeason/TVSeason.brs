'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVSeason")
    m.showLogo = m.top.findNode("showLogo")
    m.seriesLabel = m.top.findNode("seriesLabel")
    m.seasonLabel = m.top.findNode("seasonLabel")
    m.episodesList = m.top.findNode("episodesList")
    m.leftChevron = m.top.findNode("leftChevron")
    m.rightChevron = m.top.findNode("rightChevron")
    m.cast = m.top.findNode("cast")
    m.episodeOptionsOverlay = m.top.findNode("episodeOptionsOverlay")
    m.tvSeasonTask = m.top.findNode("tvSeasonTask")
    m.episodeDetailsTask = m.top.findNode("episodeDetailsTask")

    m.tvSeasonTask.observeField("response", "onTVSeasonResponse")
    m.episodeDetailsTask.observeField("response", "onEpisodeDetailsResponse")
    m.episodesList.observeField("rowItemFocused", "onEpisodeFocused")
    m.episodesList.observeField("rowItemSelected", "onEpisodeSelected")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.episodeOptionsOverlay.observeField("closeRequested", "onEpisodeOptionsClosed")
    m.pageState = {
        request: invalid
        season: invalid
        episodes: []
        episodeWindowStart: 0
        focusArea: "episodes"
        focusedItemId: ""
    }
    m.layout = {
        castDefaultY: 950
        castFocusedY: 324
    }
end sub

'-------------------------------------------------------------------------------
' onEpisodeSelected
'-------------------------------------------------------------------------------
sub onEpisodeSelected()
    selected = m.episodesList.rowItemSelected
    episodeNode = getEpisodeNodeAtPosition(selected)
    if episodeNode = invalid then return
    if SafeString(episodeNode.itemType, "") = "SeasonSummary" then
        playFirstEpisode()
        return
    end if

    episode = episodeNode.raw
    episodeId = SafeString(FirstNonEmpty([episode.Id, episode.id, episodeNode.itemId], ""), "")
    if episodeId = "" then return

    m.top.selectedEpisode = {
        itemId: episodeId
        item: episode
        startPositionTicks: PlaybackProgress_GetTicksFromItem(episode)
        playbackQueue: buildPlaybackQueue(m.pageState.episodes)
        playbackQueueIndex: selected[1] - 1
    }
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
' getFocusedEpisodeNode
'-------------------------------------------------------------------------------
function getFocusedEpisodeNode() as object
    return getEpisodeNodeAtPosition(m.episodesList.rowItemFocused)
end function

'-------------------------------------------------------------------------------
' getFocusedEpisodeImageColumnX
'-------------------------------------------------------------------------------
function getFocusedEpisodeImageColumnX() as float
    return getFocusedEpisodeItemX() + 20 - (16.75 / 2)
end function

'-------------------------------------------------------------------------------
' getFocusedEpisodeItemX
'-------------------------------------------------------------------------------
function getFocusedEpisodeItemX() as float
    focused = m.episodesList.rowItemFocused
    if focused = invalid or focused.Count() < 2 then return 80.75

    gutter = 16.75
    rowListX = 80.75
    rowItemWidth = 575
    windowStart = m.pageState.episodeWindowStart
    if windowStart = invalid then windowStart = 0

    visibleIndex = focused[1] - windowStart
    if visibleIndex < 0 then visibleIndex = 0

    return rowListX + (visibleIndex * (rowItemWidth + gutter))
end function

'-------------------------------------------------------------------------------
' playFirstEpisode
'-------------------------------------------------------------------------------
sub playFirstEpisode()
    episodes = m.pageState.episodes
    if episodes = invalid or episodes.Count() = 0 then return

    firstEpisode = invalid
    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        episodeId = SafeString(FirstNonEmpty([episode.Id, episode.id], ""), "")
        if episodeId <> "" then
            firstEpisode = episode
            exit for
        end if
    end for

    if firstEpisode = invalid then return

    m.top.selectedEpisode = {
        itemId: SafeString(FirstNonEmpty([firstEpisode.Id, firstEpisode.id], ""), "")
        item: firstEpisode
        startPositionTicks: PlaybackProgress_GetTicksFromItem(firstEpisode)
        playbackQueue: buildPlaybackQueue(episodes)
        playbackQueueIndex: 0
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.season = request.season
    m.pageState.focusArea = "episodes"
    m.pageState.focusedItemId = ""
    m.cast.server = request.server
    m.cast.title = "Cast & Crew"
    renderPeopleSection([])
    Status_SetLoading()
    renderSeason(request.season)
    clearEpisodes()

    m.tvSeasonTask.request = request
    m.tvSeasonTask.control = "run"
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
    if payload = invalid then return

    m.pageState.season = payload.season
    m.pageState.episodes = getItemsFromPayload(payload.episodes)
    renderSeason(payload.season)
    renderEpisodes(m.pageState.episodes)
    updatePeopleForFocusedItem()
    Status_ClearMessage()
    updateChevrons()
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' onEpisodeOptionsClosed
'-------------------------------------------------------------------------------
sub onEpisodeOptionsClosed()
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' onEpisodeFocused
'-------------------------------------------------------------------------------
sub onEpisodeFocused()
    updateChevrons()
    updatePeopleForFocusedItem()
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsResponse
'-------------------------------------------------------------------------------
sub onEpisodeDetailsResponse()
    response = m.episodeDetailsTask.response
    if response = invalid then return
    if response.ok <> true then return
    if SafeString(response.itemId, "") <> m.pageState.focusedItemId then return

    people = getPeople(response.payload)
    renderPeopleSection(people)
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' renderSeason
'-------------------------------------------------------------------------------
sub renderSeason(item as dynamic)
    if isAssocArray(item) = false then return

    m.seriesLabel.text = FirstNonEmpty([item.SeriesName, item.seriesName], "")
    m.seasonLabel.text = getItemTitle(item)
    renderShowLogo()
end sub

'-------------------------------------------------------------------------------
' updatePeopleForFocusedItem
'-------------------------------------------------------------------------------
sub updatePeopleForFocusedItem()
    episodeNode = getFocusedEpisodeNode()
    if episodeNode = invalid then return

    itemType = SafeString(episodeNode.itemType, "")
    if itemType = "SeasonSummary" then
        m.pageState.focusedItemId = ""
        people = getPeople(m.pageState.season)
        renderPeopleSection(people)
        return
    end if

    itemId = SafeString(episodeNode.itemId, "")
    if itemId = "" or itemId = m.pageState.focusedItemId then return

    m.pageState.focusedItemId = itemId
    renderPeopleSection([])
    request = m.pageState.request
    if request = invalid then return

    m.episodeDetailsTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.episodeDetailsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' renderPeopleSection
'-------------------------------------------------------------------------------
sub renderPeopleSection(people as object)
    m.cast.people = people
    updatePeopleSectionLayout()
end sub

'-------------------------------------------------------------------------------
' updatePeopleSectionLayout
'-------------------------------------------------------------------------------
sub updatePeopleSectionLayout()
    if m.pageState.focusArea = "cast" then
        m.cast.translation = [96, m.layout.castFocusedY]
    else
        m.cast.translation = [96, m.layout.castDefaultY]
    end if
end sub

'-------------------------------------------------------------------------------
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item = invalid or item.People = invalid then return []
    return item.People
end function

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
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")
    appendSeasonSummaryItem(row)

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        child = row.createChild("ContentNode")
        child.title = getItemTitle(episode)
        child.description = FirstNonEmpty([episode.Overview, episode.overview], "")
        child.HDPosterUrl = getImageUrl(episode, "Primary", 530, 298)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([episode.Id, episode.id], ""), "")
            itemType: SafeString(FirstNonEmpty([episode.Type, episode.type], ""), "")
            episodeNumber: getEpisodeNumberText(episode)
            episodeDate: getEpisodeDateText(episode)
            durationText: getEpisodeDurationText(episode)
            ratingText: getEpisodeRatingText(episode)
            progressPercent: getProgressPercent(episode)
            progressWidth: getProgressWidth(episode)
            raw: episode
        })
    end for

    m.episodesList.content = content
    m.episodesList.visible = row.getChildCount() > 0
    m.pageState.episodeWindowStart = 0
end sub

'-------------------------------------------------------------------------------
' clearEpisodes
'-------------------------------------------------------------------------------
sub clearEpisodes()
    m.episodesList.content = CreateObject("roSGNode", "ContentNode")
    m.episodesList.visible = false
    m.pageState.episodeWindowStart = 0
    m.leftChevron.visible = false
    m.rightChevron.visible = false
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
        durationText: ""
        ratingText: ""
        raw: season
    })
end sub

'-------------------------------------------------------------------------------
' getSeasonSummaryDescription
'-------------------------------------------------------------------------------
function getSeasonSummaryDescription(season as dynamic) as string
    description = FirstNonEmpty([season.Overview, season.overview], "")
    if description <> "" then return description

    request = m.pageState.request
    if request = invalid then return ""

    series = request.series
    if isAssocArray(series) = false then return ""

    return FirstNonEmpty([series.Overview, series.overview], "")
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
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' focusEpisodesIfActive
'-------------------------------------------------------------------------------
sub focusEpisodesIfActive()
    if m.episodesList.visible <> true then return
    if m.episodesList.content = invalid then return
    if m.episodesList.content.getChildCount() = 0 then return
    if m.episodesList.content.getChild(0).getChildCount() = 0 then return

    m.pageState.focusArea = "episodes"
    updatePeopleSectionLayout()
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
    m.episodesList.setFocus(true)
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.pageState.focusArea = "cast"
    updatePeopleSectionLayout()
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' updateChevrons
'-------------------------------------------------------------------------------
sub updateChevrons()
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

'-------------------------------------------------------------------------------
' getEpisodeDurationText
'-------------------------------------------------------------------------------
function getEpisodeDurationText(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    if item.RunTimeTicks = invalid then return ""

    minutes = int(val(item.RunTimeTicks.ToStr()) / 600000000)
    if minutes <= 0 then return ""

    hours = int(minutes / 60)
    remainingMinutes = minutes mod 60
    if hours > 0 and remainingMinutes > 0 then return hours.ToStr() + " hr " + remainingMinutes.ToStr() + " min"
    if hours > 0 then return hours.ToStr() + " hr"

    return minutes.ToStr() + " min"
end function

'-------------------------------------------------------------------------------
' getEpisodeRatingText
'-------------------------------------------------------------------------------
function getEpisodeRatingText(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    if item.CommunityRating = invalid then return ""

    rating = val(item.CommunityRating.ToStr())
    if rating <= 0 then return ""

    rounded = int((rating * 10) + 0.5)
    whole = int(rounded / 10)
    decimal = rounded mod 10

    return whole.ToStr() + "." + decimal.ToStr()
end function

'-------------------------------------------------------------------------------
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
    return FirstNonEmpty([item.Name, item.name, item.title], "")
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
' getMetaText
'-------------------------------------------------------------------------------
function getMetaText(item as dynamic) as string
    parts = []

    episodeCount = FirstNonEmpty([item.RecursiveItemCount, item.ChildCount], "")
    if episodeCount <> "" then parts.Push(SafeString(episodeCount, "") + " episodes")

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
    if year <> "" then parts.Push(year)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    return joinText(parts, "  |  ")
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

    itemId = FirstNonEmpty([item.Id, item.id], "")
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
    if payload.items <> invalid then return payload.items

    return []
end function

'-------------------------------------------------------------------------------
' buildPlaybackQueue
'-------------------------------------------------------------------------------
function buildPlaybackQueue(episodes as object) as object
    queue = []

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        episodeId = SafeString(FirstNonEmpty([episode.Id, episode.id], ""), "")
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

    if m.episodeOptionsOverlay.visible = true then
        if key = "back" then
            m.episodeOptionsOverlay.callFunc("close")
            return true
        end if

        return false
    end if

    if key = "options" then
        episodeNode = getFocusedEpisodeNode()
        if episodeNode = invalid then return true

        m.episodeOptionsOverlay.episodeContent = episodeNode.raw
        m.episodeOptionsOverlay.episodeItemContent = episodeNode
        m.episodeOptionsOverlay.episodeItemX = getFocusedEpisodeItemX()
        m.episodeOptionsOverlay.episodeImageColumnX = getFocusedEpisodeImageColumnX()
        m.episodeOptionsOverlay.callFunc("open")
        return true
    end if

    if key = "down" and m.pageState.focusArea = "episodes" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
        return true
    end if

    if key = "back" then
        Status_ClearMessage()
        m.top.closeRequested = true
        return true
    end if

    return false
end function

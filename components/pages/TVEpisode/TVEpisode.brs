'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initHandlers()
    initStyles()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.log = CreateLogger("TVEpisode")
    m.mediaShell = m.top.findNode("mediaShell")
    m.mediaToolbar = m.top.findNode("mediaToolbar")
    m.streamOptions = m.top.findNode("streamOptions")
    m.cast = m.top.findNode("cast")
    m.episodeDetailsTask = m.top.findNode("episodeDetailsTask")
    m.watchedTask = m.top.findNode("watchedTask")
    m.state = {
        request: invalid
        itemId: ""
        itemContent: invalid
        playSelection: invalid
        selectedStreams: {
            audio: invalid
            subtitle: invalid
            subtitleOff: false
        }
        focusArea: "toolbar"
    }
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.episodeDetailsTask.observeField("response", "onEpisodeDetailsResponse")
    m.watchedTask.observeField("response", "onWatchedTaskResponse")
    m.mediaToolbar.observeField("focusExitDown", "onMediaToolbarFocusExitDown")
    m.mediaToolbar.observeField("playSelected", "onMediaToolbarPlaySelected")
    m.mediaToolbar.observeField("restartSelected", "onMediaToolbarRestartSelected")
    m.mediaToolbar.observeField("subtitlesSelected", "onMediaToolbarSubtitlesSelected")
    m.mediaToolbar.observeField("audioSelected", "onMediaToolbarAudioSelected")
    m.mediaToolbar.observeField("markAsWatchedSelected", "onMarkAsWatchedSelected")
    m.mediaToolbar.observeField("markAsUnwatchedSelected", "onMarkAsUnwatchedSelected")
    m.streamOptions.observeField("selectedSubtitle", "onSubtitleOptionSelected")
    m.streamOptions.observeField("selectedAudio", "onAudioOptionSelected")
    m.streamOptions.observeField("closeRequested", "onStreamOptionsCloseRequested")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    m.state.request = m.top.loadRequest
    m.state.itemId = ""
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.state.selectedStreams = {
        audio: invalid
        subtitle: invalid
        subtitleOff: false
    }
    clearContent()
    if m.state.request <> invalid then
        m.cast.server = m.state.request.server
        renderInitialEpisodeContent()
    end if
    loadItemDetails()
end sub

'-------------------------------------------------------------------------------
' getSeriesLogoUrl
'-------------------------------------------------------------------------------
function getSeriesLogoUrl(request as dynamic) as string
    if request = invalid or request.series = invalid then return ""

    logoUrl = FirstNonEmpty([request.series.logoUrl], "")
    if logoUrl <> "" then return logoUrl

    return getImageUrl(request.series, "Logo", 600, 300)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Logo" and item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
    if tag = "" then return ""
    request = m.state.request
    if request = invalid then return ""

    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height, { format: "Png" })
end function

'-------------------------------------------------------------------------------
' renderEpisodeContent
'-------------------------------------------------------------------------------
sub renderEpisodeContent(item as dynamic)
    if item = invalid then
        clearContent()
        return
    end if

    title = getDisplayTitle(item)
    m.mediaShell.mediaContent = {
        backdropUrl: SafeString(item.HDPosterUrl, "")
        logoUrl: ""
        title: title
        metaLine1: getEpisodePositionText(item)
        metaLine2: getSecondaryMetadataText(item)
        overview: SafeString(item.description, "")
    }

    if isSeasonDetailsItem(item) then
        m.mediaToolbar.mediaType = "tv-season"
    else
        m.mediaToolbar.mediaType = "tv-episode"
    end if
    rawItem = item.raw
    m.mediaToolbar.subtitleStreamCount = getSubtitleStreams(rawItem).Count()
    m.mediaToolbar.audioStreamCount = getAudioStreams(rawItem).Count()
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(rawItem))
    m.mediaToolbar.supportsWatchedActions = canMarkWatched(item)
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' isSeasonNumberTitle
'-------------------------------------------------------------------------------
function isSeasonNumberTitle(title as string) as boolean
    value = LCase(String_Trim(title))
    if Left(value, 7) <> "season " then return false

    seasonNumber = String_Trim(Mid(value, 8))
    if seasonNumber = "" then return false

    for i = 1 to Len(seasonNumber)
        char = Mid(seasonNumber, i, 1)
        if char < "0" or char > "9" then return false
    end for

    return true
end function

'-------------------------------------------------------------------------------
' getSecondaryMetadataText
'-------------------------------------------------------------------------------
function getSecondaryMetadataText(item as dynamic) as string
    if item = invalid then return ""
    if isSeasonDetailsItem(item) then return getSeasonMetadataText(item.raw)

    raw = item.raw
    if raw = invalid then return ""

    parts = []

    dateText = SafeString(item.episodeDate, "")
    if dateText <> "" then parts.Push(dateText)

    runtimeText = MediaMetadata_FormatRuntime(raw.RunTimeTicks)
    if runtimeText <> "" then parts.Push(runtimeText)

    ratingText = getRatingText(raw)
    if ratingText <> "" then parts.Push(ratingText)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getRatingText
'-------------------------------------------------------------------------------
function getRatingText(item as dynamic) as string
    rating = MediaMetadata_FormatRating(item.CommunityRating)
    if rating = "" then return ""

    return "Rating " + rating
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    if values = invalid then return ""

    result = ""
    for each value in values
        text = SafeString(value, "")
        if text = "" then continue for

        if result <> "" then result = result + separator
        result = result + text
    end for

    return result
end function

'-------------------------------------------------------------------------------
' getDisplayTitle
'-------------------------------------------------------------------------------
function getDisplayTitle(item as dynamic) as string
    if item = invalid then return ""
    return SafeString(item.title, "")
end function

'-------------------------------------------------------------------------------
' getEpisodePositionText
'-------------------------------------------------------------------------------
function getEpisodePositionText(item as dynamic) as string
    if item = invalid or item.raw = invalid then return ""
    if isSeasonDetailsItem(item) then return getSeasonPositionText(item.raw)

    seasonNumber = SafeString(item.raw.ParentIndexNumber, "")
    episodeNumber = SafeString(item.raw.IndexNumber, "")

    parts = []
    if seasonNumber <> "" then parts.Push("Season " + seasonNumber)
    if episodeNumber <> "" then parts.Push("Episode " + episodeNumber)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getSeasonMetadataText
'-------------------------------------------------------------------------------
function getSeasonMetadataText(item as dynamic) as string
    if item = invalid then return ""

    parts = []

    count = FirstNonEmpty([item.RecursiveItemCount, item.ChildCount], "")
    if count <> "" then parts.Push(SafeString(count, "") + " episodes")

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
    if year <> "" then parts.Push(SafeString(year, ""))

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getSeasonPositionText
'-------------------------------------------------------------------------------
function getSeasonPositionText(item as dynamic) as string
    seasonNumber = SafeString(item.IndexNumber, "")
    if seasonNumber <> "" then return "Season " + seasonNumber

    title = SafeString(item.Name, "")
    if isSeasonNumberTitle(title) then return title

    return ""
end function

'-------------------------------------------------------------------------------
' isSeasonDetailsItem
'-------------------------------------------------------------------------------
function isSeasonDetailsItem(item as dynamic) as boolean
    itemType = SafeString(item.itemType, "")
    if itemType = "SeasonSummary" or itemType = "Season" then return true
    if item.raw = invalid then return false

    return SafeString(item.raw.Type, "") = "Season"
end function

'-------------------------------------------------------------------------------
' loadItemDetails
'-------------------------------------------------------------------------------
sub loadItemDetails()
    request = m.state.request
    if request = invalid then return

    itemId = SafeString(request.itemId, "")
    if itemId = "" then
        m.state.itemId = ""
        m.cast.people = []
        return
    end if

    if itemId = m.state.itemId then return
    m.state.itemId = itemId
    m.cast.people = []

    m.episodeDetailsTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.episodeDetailsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsResponse
'-------------------------------------------------------------------------------
sub onEpisodeDetailsResponse()
    response = m.episodeDetailsTask.response
    if response = invalid then return
    if response.ok <> true then return
    if SafeString(response.itemId, "") <> m.state.itemId then return

    applySeriesDetails(response.series)
    applyEpisodeDetails(response.payload, false)
    m.cast.people = getPeople(response.payload)
end sub

'-------------------------------------------------------------------------------
' renderInitialEpisodeContent
'-------------------------------------------------------------------------------
sub renderInitialEpisodeContent()
    request = m.state.request
    if request = invalid or request.item = invalid then return

    applyEpisodeDetails(request.item, true)
end sub

'-------------------------------------------------------------------------------
' applySeriesDetails
'-------------------------------------------------------------------------------
sub applySeriesDetails(series as dynamic)
    if series = invalid then return
    if m.state.request = invalid then return

    m.state.request.series = series
end sub

'-------------------------------------------------------------------------------
' applyEpisodeDetails
'-------------------------------------------------------------------------------
sub applyEpisodeDetails(details as dynamic, useRequestPoster as boolean)
    if details = invalid then return

    item = buildEpisodeContentNode(details, useRequestPoster)
    m.state.itemContent = item
    m.state.playSelection = buildPlaySelection(details)
    renderEpisodeContent(item)
end sub

'-------------------------------------------------------------------------------
' buildEpisodeContentNode
'-------------------------------------------------------------------------------
function buildEpisodeContentNode(details as dynamic, useRequestPoster as boolean) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = FirstNonEmpty([details.Name], "")
    content.description = FirstNonEmpty([details.Overview], "")
    content.HDPosterUrl = getEpisodePosterUrl(details, useRequestPoster)
    content.AddFields({
        itemId: SafeString(FirstNonEmpty([details.Id], ""), "")
        itemType: SafeString(FirstNonEmpty([details.Type], ""), "")
        episodeNumber: getEpisodeNumberText(details)
        episodeDate: getEpisodeDateText(details)
        progressPercent: getProgressPercent(details)
        progressWidth: getProgressWidth(details)
        raw: details
    })

    return content
end function

'-------------------------------------------------------------------------------
' buildPlaySelection
'-------------------------------------------------------------------------------
function buildPlaySelection(details as dynamic) as dynamic
    request = m.state.request
    if request = invalid then return invalid

    itemId = SafeString(FirstNonEmpty([details.Id, request.itemId], ""), "")
    if itemId = "" then return invalid

    startPositionTicks = PlaybackProgress_GetTicksFromItem(details)
    if request.startPositionTicks <> invalid then startPositionTicks = request.startPositionTicks

    selection = {
        itemId: itemId
        item: details
        startPositionTicks: startPositionTicks
        playbackQueue: request.playbackQueue
        playbackQueueIndex: request.playbackQueueIndex
    }
    applySelectedStreamsToPlaySelection(selection)
    return selection
end function

'-------------------------------------------------------------------------------
' getEpisodePosterUrl
'-------------------------------------------------------------------------------
function getEpisodePosterUrl(item as dynamic, useRequestPoster as boolean) as string
    if useRequestPoster then
        requestPosterUrl = getRequestPosterUrl(item)
        if requestPosterUrl <> "" then return requestPosterUrl
    end if

    imageSize = DeviceCapabilities_GetMaxScreenImageSize()
    request = m.state.request
    if request = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, imageSize.width, imageSize.height, { format: "Png" })

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return Url_BuildImageUrl(request.server, parentThumbId, "Thumb", parentThumbTag, imageSize.width, imageSize.height, { format: "Png" })

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return Url_BuildImageUrl(request.server, seriesId, "Primary", seriesTag, imageSize.width, imageSize.height, { format: "Png" })

    return ""
end function

'-------------------------------------------------------------------------------
' getRequestPosterUrl
'-------------------------------------------------------------------------------
function getRequestPosterUrl(item as dynamic) as string
    request = m.state.request
    if request = invalid then return ""

    requestItemId = FirstNonEmpty([request.itemId], "")
    itemId = FirstNonEmpty([item.Id], "")
    if requestItemId = "" or itemId = "" or requestItemId <> itemId then return ""

    return FirstNonEmpty([request.posterUrl], "")
end function

'-------------------------------------------------------------------------------
' shouldKeepRequestPoster
'-------------------------------------------------------------------------------
function shouldKeepRequestPoster(item as dynamic) as boolean
    return getRequestPosterUrl(item) <> ""
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
' getAiredDateText
'-------------------------------------------------------------------------------
function getAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.PremiereDate, item.AirDate, item.DateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

'-------------------------------------------------------------------------------
' getProgressPercent
'-------------------------------------------------------------------------------
function getProgressPercent(item as dynamic) as float
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
' clearContent
'-------------------------------------------------------------------------------
sub clearContent()
    m.mediaShell.mediaContent = {
        backdropUrl: ""
        logoUrl: ""
        title: ""
        metaLine1: ""
        metaLine2: ""
        overview: ""
    }
    m.mediaToolbar.supportsWatchedActions = false
    m.mediaToolbar.isWatched = false
    m.mediaToolbar.mediaType = "tv-episode"
    m.mediaToolbar.subtitleStreamCount = 0
    m.mediaToolbar.audioStreamCount = 0
    m.mediaToolbar.resumePositionSeconds = 0
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.cast.people = []
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    if m.state.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        m.cast.callFunc("activate")
    else
        focusMediaToolbar()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.cast.callFunc("deactivate")
    m.top.setFocus(false)
end sub

'-------------------------------------------------------------------------------
' resetFocus
'-------------------------------------------------------------------------------
sub resetFocus()
    m.state.focusArea = "toolbar"
    m.mediaToolbar.callFunc("resetFocus")
end sub

'-------------------------------------------------------------------------------
' focusMediaToolbar
'-------------------------------------------------------------------------------
sub focusMediaToolbar()
    m.state.focusArea = "toolbar"
    m.mediaToolbar.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarFocusExitDown
'-------------------------------------------------------------------------------
sub onMediaToolbarFocusExitDown()
    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "cast"
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarPlaySelected
'-------------------------------------------------------------------------------
sub onMediaToolbarPlaySelected()
    if m.state.playSelection = invalid then return
    applySelectedStreamsToPlaySelection(m.state.playSelection)
    m.log.write("Play selected audioStreamIndex=" + SafeString(m.state.playSelection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(m.state.playSelection.subtitleStreamIndex, ""))
    m.top.selectedEpisode = m.state.playSelection
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarRestartSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarRestartSelected()
    if m.state.playSelection = invalid then return

    selection = buildRestartSelection(m.state.playSelection)
    applySelectedStreamsToPlaySelection(selection)
    m.log.write("Restart selected audioStreamIndex=" + SafeString(selection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(selection.subtitleStreamIndex, ""))
    m.top.selectedEpisode = selection
end sub

'-------------------------------------------------------------------------------
' buildRestartSelection
'-------------------------------------------------------------------------------
function buildRestartSelection(selection as dynamic) as dynamic
    restartSelection = {
        itemId: selection.itemId
        item: selection.item
        startPositionTicks: 0
        playbackQueue: selection.playbackQueue
        playbackQueueIndex: selection.playbackQueueIndex
    }

    return restartSelection
end function

'-------------------------------------------------------------------------------
' onMediaToolbarSubtitlesSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarSubtitlesSelected()
    item = m.state.itemContent
    if item = invalid or item.raw = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "subtitleOptions"
    m.streamOptions.callFunc("openSubtitleOptions", {
        subtitleStreams: getSubtitleStreams(item.raw)
        selectedSubtitleStreamIndex: getSelectedSubtitleStreamIndex()
    })
end sub

'-------------------------------------------------------------------------------
' onStreamOptionsCloseRequested
'-------------------------------------------------------------------------------
sub onStreamOptionsCloseRequested()
    focusMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onSubtitleOptionSelected
'-------------------------------------------------------------------------------
sub onSubtitleOptionSelected()
    selection = m.streamOptions.selectedSubtitle
    if selection = invalid then return

    if selection.isOff = true then
        m.state.selectedStreams.subtitle = invalid
        m.state.selectedStreams.subtitleOff = true
        m.log.write("Subtitle option selected: Off")
    else
        m.state.selectedStreams.subtitle = selection
        m.state.selectedStreams.subtitleOff = false
        m.log.write("Subtitle option selected streamIndex=" + SafeString(selection.streamIndex, "") + " label=" + SafeString(selection.label, ""))
    end if

    applySelectedStreamsToPlaySelection(m.state.playSelection)
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarAudioSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarAudioSelected()
    item = m.state.itemContent
    if item = invalid or item.raw = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "audioOptions"
    m.streamOptions.callFunc("openAudioOptions", {
        audioStreams: getAudioStreams(item.raw)
        selectedAudioStreamIndex: getSelectedAudioStreamIndex()
    })
end sub

'-------------------------------------------------------------------------------
' onAudioOptionSelected
'-------------------------------------------------------------------------------
sub onAudioOptionSelected()
    selection = m.streamOptions.selectedAudio
    if selection = invalid then return

    m.state.selectedStreams.audio = selection
    m.log.write("Audio option selected streamIndex=" + SafeString(selection.streamIndex, "") + " label=" + SafeString(selection.label, ""))
    applySelectedStreamsToPlaySelection(m.state.playSelection)
end sub

'-------------------------------------------------------------------------------
' onMarkAsWatchedSelected
'-------------------------------------------------------------------------------
sub onMarkAsWatchedSelected()
    runWatchedTask("MarkAsWatched")
end sub

'-------------------------------------------------------------------------------
' onMarkAsUnwatchedSelected
'-------------------------------------------------------------------------------
sub onMarkAsUnwatchedSelected()
    runWatchedTask("MarkAsUnwatched")
end sub

'-------------------------------------------------------------------------------
' runWatchedTask
'-------------------------------------------------------------------------------
sub runWatchedTask(action as string)
    item = m.state.itemContent
    request = m.state.request
    if item = invalid or request = invalid then return
    if canMarkWatched(item) <> true then return

    itemId = SafeString(item.itemId, "")
    if itemId = "" then return

    m.watchedTask.request = {
        action: action
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.watchedTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onWatchedTaskResponse
'-------------------------------------------------------------------------------
sub onWatchedTaskResponse()
    response = m.watchedTask.response
    if response = invalid then return

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to update watched state."))
        return
    end if

    item = m.state.itemContent
    if item = invalid then return

    itemId = SafeString(response.itemId, "")
    if itemId = "" or itemId <> SafeString(item.itemId, "") then return

    isWatched = SafeString(response.action, "") = "MarkAsWatched"
    updateItemWatchedState(item, isWatched)
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item.raw))
    m.mediaToolbar.isWatched = isWatched
    m.mediaToolbar.callFunc("focusWatchedAction")
    m.top.watchedStateChanged = {
        itemId: itemId
        isWatched: isWatched
    }
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    m.state.focusArea = "cast"
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" or key = "back" then
        m.top.closeRequested = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item = invalid or item.People = invalid then return []
    return item.People
end function

'-------------------------------------------------------------------------------
' getSubtitleStreams
'-------------------------------------------------------------------------------
function getSubtitleStreams(item as dynamic) as object
    if item = invalid or item.MediaStreams = invalid then return []

    subtitleStreams = []
    for i = 0 to item.MediaStreams.Count() - 1
        stream = item.MediaStreams[i]
        if stream <> invalid and LCase(SafeString(stream.Type, "")) = "subtitle" then
            if stream.Index = invalid then stream.AddReplace("sourceIndex", i)
            subtitleStreams.Push(stream)
        end if
    end for

    return subtitleStreams
end function

'-------------------------------------------------------------------------------
' getAudioStreams
'-------------------------------------------------------------------------------
function getAudioStreams(item as dynamic) as object
    if item = invalid or item.MediaStreams = invalid then return []

    audioStreams = []
    for i = 0 to item.MediaStreams.Count() - 1
        stream = item.MediaStreams[i]
        if stream <> invalid and LCase(SafeString(stream.Type, "")) = "audio" then
            if stream.Index = invalid then stream.AddReplace("sourceIndex", i)
            audioStreams.Push(stream)
        end if
    end for

    return audioStreams
end function

'-------------------------------------------------------------------------------
' applySelectedStreamsToPlaySelection
'-------------------------------------------------------------------------------
sub applySelectedStreamsToPlaySelection(selection as dynamic)
    if selection = invalid then return

    audioIndex = getSelectedAudioStreamIndex()
    if audioIndex >= 0 then selection.AddReplace("audioStreamIndex", audioIndex)

    subtitleIndex = getSelectedSubtitleStreamIndex()
    if subtitleIndex >= -1 then selection.AddReplace("subtitleStreamIndex", subtitleIndex)
end sub

'-------------------------------------------------------------------------------
' getSelectedAudioStreamIndex
'-------------------------------------------------------------------------------
function getSelectedAudioStreamIndex() as integer
    if m.state = invalid or m.state.selectedStreams = invalid then return -1
    if m.state.selectedStreams.audio = invalid then return -1

    return getSelectedStreamIndex(m.state.selectedStreams.audio, -1)
end function

'-------------------------------------------------------------------------------
' getSelectedSubtitleStreamIndex
'-------------------------------------------------------------------------------
function getSelectedSubtitleStreamIndex() as integer
    if m.state = invalid or m.state.selectedStreams = invalid then return -2
    if m.state.selectedStreams.subtitleOff = true then return -1
    if m.state.selectedStreams.subtitle = invalid then return -2

    return getSelectedStreamIndex(m.state.selectedStreams.subtitle, -2)
end function

'-------------------------------------------------------------------------------
' getSelectedStreamIndex
'-------------------------------------------------------------------------------
function getSelectedStreamIndex(selection as dynamic, fallback as integer) as integer
    if selection = invalid then return fallback
    if selection.streamIndex <> invalid then return int(selection.streamIndex)
    if selection.stream <> invalid and selection.stream.Index <> invalid then return int(selection.stream.Index)
    return fallback
end function

'-------------------------------------------------------------------------------
' isItemWatched
'-------------------------------------------------------------------------------
function isItemWatched(item as dynamic) as boolean
    if item = invalid then return false
    if item.raw = invalid then return false
    if item.raw.UserData = invalid then return false
    if SafeString(item.itemType, "") = "SeasonSummary" then
        return item.raw.UserData.UnplayedItemCount = 0
    end if

    return item.raw.UserData.Played = true
end function

'-------------------------------------------------------------------------------
' canMarkWatched
'-------------------------------------------------------------------------------
function canMarkWatched(item as dynamic) as boolean
    if item = invalid then return false
    if SafeString(item.itemId, "") = "" then return false

    return true
end function

'-------------------------------------------------------------------------------
' updateItemWatchedState
'-------------------------------------------------------------------------------
sub updateItemWatchedState(item as dynamic, isWatched as boolean)
    if item = invalid or item.raw = invalid then return

    raw = item.raw
    if raw.UserData = invalid then raw.UserData = {}

    raw.UserData.Played = isWatched
    if SafeString(item.itemType, "") = "SeasonSummary" then
        if isWatched then
            raw.UserData.UnplayedItemCount = 0
        else
            raw.UserData.UnplayedItemCount = 1
        end if
    end if

    if isWatched then
        raw.UserData.PlayedPercentage = 0
        raw.UserData.PlaybackPositionTicks = 0
    else
        raw.UserData.PlayedPercentage = 0
    end if

    item.raw = raw
    m.state.itemContent = item
    if m.state.playSelection <> invalid then
        m.state.playSelection.item = raw
    end if
end sub

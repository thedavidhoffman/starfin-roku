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
        playbackProgressChange: invalid
        selectedStreams: {
            audio: invalid
            subtitle: invalid
            subtitleOff: false
        }
        selectedChapterKey: ""
        focusArea: "toolbar"
        lifecycle: AsyncLifecycle_Create()
    }
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.episodeDetailsTask.observeField("response", "onEpisodeDetailsResponse")
    m.watchedTask.observeField("response", "onWatchedTaskResponse")
    m.mediaShell.observeField("overlayRequested", "onVideoMediaShellOverlayRequested")
    m.mediaToolbar.observeField("focusExitDown", "onVideoMediaToolbarFocusExitDown")
    m.mediaToolbar.observeField("playSelected", "onVideoMediaToolbarPlaySelected")
    m.mediaToolbar.observeField("restartSelected", "onVideoMediaToolbarRestartSelected")
    m.mediaToolbar.observeField("subtitlesSelected", "onVideoMediaToolbarSubtitlesSelected")
    m.mediaToolbar.observeField("audioSelected", "onVideoMediaToolbarAudioSelected")
    m.mediaToolbar.observeField("chaptersSelected", "onVideoMediaToolbarChaptersSelected")
    m.mediaToolbar.observeField("mediaInfoSelected", "onVideoMediaToolbarMediaInfoSelected")
    m.mediaToolbar.observeField("seriesSelected", "onVideoMediaToolbarSeriesSelected")
    m.mediaToolbar.observeField("seasonSelected", "onVideoMediaToolbarSeasonSelected")
    m.mediaToolbar.observeField("markAsWatchedSelected", "onMarkAsWatchedSelected")
    m.mediaToolbar.observeField("markAsUnwatchedSelected", "onMarkAsUnwatchedSelected")
    m.streamOptions.observeField("overlayRequested", "onStreamOptionsOverlayRequested")
    m.streamOptions.observeField("selectedSubtitle", "onSubtitleOptionSelected")
    m.streamOptions.observeField("selectedAudio", "onAudioOptionSelected")
    m.streamOptions.observeField("selectedChapter", "onChapterOptionSelected")
    m.streamOptions.observeField("closeRequested", "onStreamOptionsCloseRequested")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
end sub

'-------------------------------------------------------------------------------
' onVideoMediaShellOverlayRequested
'-------------------------------------------------------------------------------
sub onVideoMediaShellOverlayRequested()
    request = m.mediaShell.overlayRequested
    if request = invalid then return

    request.sourcePage = "tvEpisode"
    m.top.overlayRequested = request
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
    if m.state.request <> invalid then
        m.top.settings = m.state.request.settings
        applyVideoMediaShellBackgroundSetting(m.state.request.settings)
    else
        applyVideoMediaShellBackgroundSetting(invalid)
    end if
    if m.state.request <> invalid then
        AsyncLifecycle_Begin(m.state.lifecycle, m.state.request.itemId)
    else
        AsyncLifecycle_Begin(m.state.lifecycle, invalid)
    end if
    m.state.itemId = ""
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.state.playbackProgressChange = invalid
    m.state.selectedStreams = {
        audio: invalid
        subtitle: invalid
        subtitleOff: false
    }
    m.state.selectedChapterKey = ""
    clearPageState()
    if m.state.request <> invalid then
        m.cast.server = m.state.request.server
        renderInitialEpisodeContent()
    end if
    loadItemDetails()
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    settings = m.top.settings
    if m.state <> invalid and m.state.request <> invalid then m.state.request.settings = settings
    applyVideoMediaShellBackgroundSetting(settings)
end sub

'-------------------------------------------------------------------------------
' applyVideoMediaShellBackgroundSetting
'-------------------------------------------------------------------------------
sub applyVideoMediaShellBackgroundSetting(settings as dynamic)
    keys = SettingsStore_Keys()
    m.mediaShell.backgroundDisplay = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
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
sub renderEpisodeContent(item as dynamic, logoPending = false as boolean)
    if item = invalid then
        clearContent()
        return
    end if

    title = getDisplayTitle(item)
    episodePositionText = getEpisodePositionText(item)
    episodeMetadataText = getSecondaryMetadataText(item)
    m.mediaShell.mediaContent = {
        mediaType: getVideoMediaShellType(item)
        backdropUrl: SafeString(item.HDPosterUrl, "")
        logoUrl: getVideoMediaShellLogoUrl()
        logoTitle: getVideoMediaShellLogoTitle(item)
        logoPending: logoPending
        title: title
        primaryInfoText: episodePositionText
        secondaryInfoText: episodeMetadataText
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
    m.mediaToolbar.chapterCount = getChapters(rawItem).Count()
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(rawItem))
    m.mediaToolbar.supportsWatchedActions = canMarkWatched(item)
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' getVideoMediaShellType
'-------------------------------------------------------------------------------
function getVideoMediaShellType(item as dynamic) as string
    if isSeasonDetailsItem(item) then return "tv-season"
    return "tv-episode"
end function

'-------------------------------------------------------------------------------
' getVideoMediaShellLogoUrl
'-------------------------------------------------------------------------------
function getVideoMediaShellLogoUrl() as string
    return getSeriesLogoUrl(m.state.request)
end function

'-------------------------------------------------------------------------------
' getVideoMediaShellLogoTitle
'-------------------------------------------------------------------------------
function getVideoMediaShellLogoTitle(item as dynamic) as string
    seriesName = ""
    if item <> invalid and item.raw <> invalid then seriesName = FirstNonEmpty([item.raw.SeriesName], "")

    request = m.state.request
    if request = invalid or request.series = invalid then return seriesName

    return FirstNonEmpty([request.series.Name, seriesName], "")
end function

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
    if year = "" then year = DateTime_ToYear(item.PremiereDate)
    if year <> "" then parts.Push(SafeString(year, ""))

    return joinText(parts, MediaMetadata_BulletSeparator())
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
        loadPlaybackQueue: request.playbackQueue = invalid
    }
    m.episodeDetailsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsResponse
'-------------------------------------------------------------------------------
sub onEpisodeDetailsResponse()
    response = m.episodeDetailsTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.state.lifecycle, response, "itemId", "tvEpisodeDetails") <> true then return
    if response.ok <> true then
        renderEpisodeContent(m.state.itemContent, false)
        return
    end if
    if SafeString(response.itemId, "") <> m.state.itemId then return

    applySeriesDetails(response.series)
    applyPlaybackQueueDetails(response)
    applyEpisodeDetails(response.payload, false)
    m.cast.people = getPeople(response.payload)
end sub

'-------------------------------------------------------------------------------
' applyPlaybackQueueDetails
'-------------------------------------------------------------------------------
sub applyPlaybackQueueDetails(response as object)
    if response = invalid then return
    if m.state.request = invalid then return
    if response.playbackQueue = invalid then return

    m.state.request.playbackQueue = response.playbackQueue
    m.state.request.playbackQueueIndex = response.playbackQueueIndex
    if m.state.request.season = invalid and response.season <> invalid then m.state.request.season = response.season
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

    m.state.request.series = SeriesIdentity_FromItem(SafeString(m.state.request.server, ""), series)
end sub

'-------------------------------------------------------------------------------
' applyEpisodeDetails
'-------------------------------------------------------------------------------
sub applyEpisodeDetails(details as dynamic, logoPending = false as boolean)
    if details = invalid then return

    item = buildEpisodeContentNode(details)
    m.state.itemContent = item
    m.state.playSelection = buildPlaySelection(details)
    renderEpisodeContent(item, logoPending)
end sub

'-------------------------------------------------------------------------------
' buildEpisodeContentNode
'-------------------------------------------------------------------------------
function buildEpisodeContentNode(details as dynamic) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = FirstNonEmpty([details.Name], "")
    content.description = FirstNonEmpty([details.Overview], "")
    content.HDPosterUrl = getEpisodePosterUrl(details)
    content.AddFields({
        itemId: SafeString(FirstNonEmpty([details.Id], ""), "")
        itemType: SafeString(FirstNonEmpty([details.Type], ""), "")
        episodeNumber: getEpisodeNumberText(details)
        episodeDate: DateTime_ToShortDate(getAiredDateText(details))
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
        series: SeriesIdentity_FromItem(SafeString(request.server, ""), request.series)
        season: request.season
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
function getEpisodePosterUrl(item as dynamic) as string
    imageSize = DeviceCapabilities_GetMaxScreenImageSize()
    request = m.state.request
    if request = invalid then return ""

    if SafeString(item.Type, "") = "Season" then
        posterUrl = SafeString(request.posterUrl, "")
        if posterUrl <> "" then return posterUrl
    end if

    itemId = FirstNonEmpty([item.Id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, imageSize.width, imageSize.height)

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return Url_BuildImageUrl(request.server, parentThumbId, "Thumb", parentThumbTag, imageSize.width, imageSize.height)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return Url_BuildImageUrl(request.server, seriesId, "Primary", seriesTag, imageSize.width, imageSize.height)

    return ""
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
        mediaType: "tv-episode"
        backdropUrl: ""
        logoUrl: ""
        logoTitle: ""
        title: ""
        primaryInfoText: ""
        secondaryInfoText: ""
        overview: ""
    }
    m.mediaToolbar.supportsWatchedActions = false
    m.mediaToolbar.isWatched = false
    m.mediaToolbar.mediaType = "tv-episode"
    m.mediaToolbar.subtitleStreamCount = 0
    m.mediaToolbar.audioStreamCount = 0
    m.mediaToolbar.chapterCount = 0
    m.mediaToolbar.resumePositionSeconds = 0
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.cast.people = []
end sub

'-------------------------------------------------------------------------------
' clearPageState
'-------------------------------------------------------------------------------
sub clearPageState()
    m.mediaToolbar.supportsWatchedActions = false
    m.mediaToolbar.isWatched = false
    m.mediaToolbar.mediaType = "tv-episode"
    m.mediaToolbar.subtitleStreamCount = 0
    m.mediaToolbar.audioStreamCount = 0
    m.mediaToolbar.chapterCount = 0
    m.mediaToolbar.resumePositionSeconds = 0
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.cast.people = []
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.state.lifecycle, m.state.request, "itemId")
    m.top.setFocus(true)
    if m.state.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        m.cast.callFunc("activate")
    else
        focusVideoMediaToolbar()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.state.lifecycle)
    m.episodeDetailsTask.control = "stop"
    m.watchedTask.control = "stop"
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
' focusVideoMediaToolbar
'-------------------------------------------------------------------------------
sub focusVideoMediaToolbar()
    m.state.focusArea = "toolbar"
    m.mediaToolbar.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' focusMediaDescription
'-------------------------------------------------------------------------------
function focusMediaDescription() as boolean
    if m.mediaShell.callFunc("canFocusDescription") <> true then return false

    m.state.focusArea = "description"
    m.mediaToolbar.callFunc("deactivate")
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
    return m.mediaShell.callFunc("focusDescription")
end function

'-------------------------------------------------------------------------------
' handleDescriptionOverlayClosed
'-------------------------------------------------------------------------------
sub handleDescriptionOverlayClosed()
    focusMediaDescription()
end sub

'-------------------------------------------------------------------------------
' handleVideoMediaInfoOverlayClosed
'-------------------------------------------------------------------------------
sub handleVideoMediaInfoOverlayClosed()
    focusVideoMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "cast"
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarFocusExitDown
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarFocusExitDown()
    focusCast()
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarPlaySelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarPlaySelected()
    if m.state.playSelection = invalid then return
    applySelectedStreamsToPlaySelection(m.state.playSelection)
    m.log.write("Play selected audioStreamIndex=" + SafeString(m.state.playSelection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(m.state.playSelection.subtitleStreamIndex, ""))
    m.top.selectedEpisode = m.state.playSelection
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarRestartSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarRestartSelected()
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
        series: selection.series
        season: selection.season
        startPositionTicks: 0
        playbackQueue: selection.playbackQueue
        playbackQueueIndex: selection.playbackQueueIndex
    }

    return restartSelection
end function

'-------------------------------------------------------------------------------
' onVideoMediaToolbarSubtitlesSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarSubtitlesSelected()
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
' onStreamOptionsOverlayRequested
'-------------------------------------------------------------------------------
sub onStreamOptionsOverlayRequested()
    request = m.streamOptions.overlayRequested
    if request = invalid then return

    request.sourcePage = "tvEpisode"
    m.top.streamOptionsRequested = request
end sub

'-------------------------------------------------------------------------------
' handleStreamOptionsOverlayClosed
'-------------------------------------------------------------------------------
sub handleStreamOptionsOverlayClosed(closed as object)
    applyClosedStreamOptionsSelection(closed)
    m.streamOptions.callFunc("closeOptions")
end sub

'-------------------------------------------------------------------------------
' applyClosedStreamOptionsSelection
'-------------------------------------------------------------------------------
sub applyClosedStreamOptionsSelection(closed as object)
    if closed = invalid then return
    request = closed.request
    overlay = closed.overlay
    if request = invalid or overlay = invalid then return

    selection = getClosedOptionValue(overlay)
    if SafeString(request.id, "") = "subtitleOptions" then
        m.streamOptions.callFunc("applySubtitleSelection", selection)
    else if SafeString(request.id, "") = "audioOptions" then
        m.streamOptions.callFunc("applyAudioSelection", selection)
    else if SafeString(request.id, "") = "chapterOptions" and overlay.selectedOptionChanged = true then
        m.streamOptions.callFunc("applyChapterSelection", selection)
    end if
end sub

'-------------------------------------------------------------------------------
' getClosedOptionValue
'-------------------------------------------------------------------------------
function getClosedOptionValue(overlay as dynamic) as dynamic
    if overlay = invalid then return invalid
    if overlay.selectedOption = invalid then return invalid
    return overlay.selectedOption.value
end function

'-------------------------------------------------------------------------------
' onStreamOptionsCloseRequested
'-------------------------------------------------------------------------------
sub onStreamOptionsCloseRequested()
    focusVideoMediaToolbar()
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
' onVideoMediaToolbarAudioSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarAudioSelected()
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
' onVideoMediaToolbarChaptersSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarChaptersSelected()
    item = m.state.itemContent
    if item = invalid or item.raw = invalid then return

    chapters = getChapters(item.raw)
    if chapters.Count() = 0 then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "chapterOptions"
    m.streamOptions.callFunc("openChapterOptions", {
        chapters: chapters
        selectedChapterKey: m.state.selectedChapterKey
    })
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarMediaInfoSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarMediaInfoSelected()
    item = m.state.itemContent
    if item = invalid or item.raw = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "mediaInfo"
    m.top.overlayRequested = {
        id: "mediaInfo"
        sourcePage: "tvEpisode"
        componentName: "VideoMediaInfo"
        openFunction: "openVideoMediaInfo"
        closeField: "closeRequested"
        item: item.raw
    }
end sub

'-------------------------------------------------------------------------------
' onChapterOptionSelected
'-------------------------------------------------------------------------------
sub onChapterOptionSelected()
    selection = m.streamOptions.selectedChapter
    if selection = invalid or selection.startPositionTicks = invalid then return
    if m.state.playSelection = invalid then return

    playSelection = buildRestartSelection(m.state.playSelection)
    playSelection.startPositionTicks = selection.startPositionTicks
    applySelectedStreamsToPlaySelection(playSelection)
    m.state.selectedChapterKey = SafeString(selection.startPositionTicks, "")
    m.log.write("Chapter option selected startPositionTicks=" + SafeString(selection.startPositionTicks, "") + " label=" + SafeString(selection.label, ""))
    m.top.selectedEpisode = playSelection
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarSeriesSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarSeriesSelected()
    selection = getCurrentSeriesSelection()
    if selection = invalid then return

    m.top.selectedSeries = selection
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarSeasonSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarSeasonSelected()
    selection = getCurrentSeasonSelection()
    if selection = invalid then return

    m.top.selectedSeason = selection
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
    if m.state.lifecycle.isActive <> true then return

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
' onPlaybackProgressChange
'-------------------------------------------------------------------------------
sub onPlaybackProgressChange()
    change = m.top.playbackProgressChange
    if change = invalid then return

    m.state.playbackProgressChange = change
    m.top.playbackProgressChanged = change

    item = m.state.itemContent
    if item = invalid or item.raw = invalid then
        return
    end if

    itemId = SafeString(change.itemId, "")
    if itemId = "" or itemId <> SafeString(item.itemId, "") then
        return
    end if

    updateItemPlaybackProgress(item, change)
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item.raw))
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusVideoMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    selection.sourceItemType = "series"
    selection.sourceSeriesId = getCurrentSeriesId()
    m.state.focusArea = "cast"
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' getCurrentSeriesId
'-------------------------------------------------------------------------------
function getCurrentSeriesId() as string
    item = m.state.itemContent
    if item <> invalid and item.raw <> invalid then
        seriesId = FirstNonEmpty([item.raw.SeriesId], "")
        if seriesId <> "" then return seriesId
    end if

    request = m.state.request
    if request = invalid then return ""
    if request.series <> invalid then
        seriesId = FirstNonEmpty([request.series.Id], "")
        if seriesId <> "" then return seriesId
    end if

    return FirstNonEmpty([request.seriesId], "")
end function

'-------------------------------------------------------------------------------
' getCurrentSeriesSelection
'-------------------------------------------------------------------------------
function getCurrentSeriesSelection() as dynamic
    request = m.state.request
    if request = invalid then return invalid

    seriesId = getCurrentSeriesId()
    if seriesId = "" then return invalid

    series = invalid
    if request.series <> invalid then series = request.series

    return {
        itemId: seriesId
        item: series
    }
end function

'-------------------------------------------------------------------------------
' getCurrentSeasonSelection
'-------------------------------------------------------------------------------
function getCurrentSeasonSelection() as dynamic
    request = m.state.request
    if request = invalid then return invalid

    seriesId = getCurrentSeriesId()
    seasonId = getCurrentSeasonId()
    if seriesId = "" or seasonId = "" then return invalid

    return {
        seriesId: seriesId
        seasonId: seasonId
        series: request.series
        season: getCurrentSeasonIdentity(seasonId)
        seasons: request.seasons
        nextSeason: invalid
    }
end function

'-------------------------------------------------------------------------------
' getCurrentSeasonId
'-------------------------------------------------------------------------------
function getCurrentSeasonId() as string
    request = m.state.request
    if request <> invalid then
        seasonId = FirstNonEmpty([request.seasonId], "")
        if seasonId <> "" then return seasonId

        if request.season <> invalid then
            seasonId = FirstNonEmpty([request.season.Id], "")
            if seasonId <> "" then return seasonId
        end if
    end if

    item = m.state.itemContent
    if item <> invalid and item.raw <> invalid then
        return FirstNonEmpty([item.raw.SeasonId, item.raw.ParentId], "")
    end if

    return ""
end function

'-------------------------------------------------------------------------------
' getCurrentSeasonIdentity
'-------------------------------------------------------------------------------
function getCurrentSeasonIdentity(seasonId as string) as object
    request = m.state.request
    if request <> invalid and request.season <> invalid then return request.season

    seasonName = ""
    item = m.state.itemContent
    if item <> invalid and item.raw <> invalid then
        seasonName = FirstNonEmpty([item.raw.SeasonName], "")
        if seasonName = "" and item.raw.ParentIndexNumber <> invalid then seasonName = "Season " + SafeString(item.raw.ParentIndexNumber, "")
    end if

    return {
        Id: seasonId
        Name: seasonName
    }
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" and m.state.focusArea = "toolbar" then
        if focusMediaDescription() then return true
        return true
    end if

    if key = "down" and m.state.focusArea = "description" then
        focusVideoMediaToolbar()
        return true
    end if

    if key = "back" then
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
' getChapters
'-------------------------------------------------------------------------------
function getChapters(item as dynamic) as object
    return MediaOptions_GetChapters(item)
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
    if m.state = invalid or m.state.selectedStreams = invalid then return -1
    if m.state.selectedStreams.subtitleOff = true then return -1
    if m.state.selectedStreams.subtitle = invalid then return -1

    return getSelectedStreamIndex(m.state.selectedStreams.subtitle, -1)
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

'-------------------------------------------------------------------------------
' updateItemPlaybackProgress
'-------------------------------------------------------------------------------
sub updateItemPlaybackProgress(item as dynamic, change as object)
    if item = invalid or item.raw = invalid then return

    raw = item.raw
    if raw.UserData = invalid then raw.UserData = {}

    if change.isFinished = true then
        raw.UserData.Played = true
        raw.UserData.PlayedPercentage = 0
        raw.UserData.PlaybackPositionTicks = 0
    else
        positionTicks = getPlaybackProgressTicks(change.positionTicks)
        raw.UserData.Played = false
        raw.UserData.PlaybackPositionTicks = positionTicks
        raw.UserData.PlayedPercentage = getPlaybackProgressPercentage(positionTicks, raw.RunTimeTicks, change.durationTicks)
    end if

    item.raw = raw
    m.state.itemContent = item
    if m.state.playSelection <> invalid then
        m.state.playSelection.item = raw
        m.state.playSelection.startPositionTicks = raw.UserData.PlaybackPositionTicks
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

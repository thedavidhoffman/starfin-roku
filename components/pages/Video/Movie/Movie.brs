'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Movie")
    m.mediaShell = m.top.findNode("mediaShell")
    m.mediaToolbar = m.top.findNode("mediaToolbar")
    m.streamOptions = m.top.findNode("streamOptions")
    m.cast = m.top.findNode("cast")
    m.movieTask = m.top.findNode("movieTask")
    m.themeSongsTask = m.top.findNode("themeSongsTask")
    m.watchedTask = m.top.findNode("watchedTask")

    m.movieTask.observeField("response", "onMovieResponse")
    m.themeSongsTask.observeField("response", "onThemeSongsResponse")
    m.watchedTask.observeField("response", "onWatchedTaskResponse")
    m.mediaShell.observeField("overlayRequested", "onMediaShellOverlayRequested")
    m.mediaToolbar.observeField("focusExitDown", "onVideoMediaToolbarFocusExitDown")
    m.mediaToolbar.observeField("playSelected", "onVideoMediaToolbarPlaySelected")
    m.mediaToolbar.observeField("restartSelected", "onVideoMediaToolbarRestartSelected")
    m.mediaToolbar.observeField("subtitlesSelected", "onVideoMediaToolbarSubtitlesSelected")
    m.mediaToolbar.observeField("audioSelected", "onVideoMediaToolbarAudioSelected")
    m.mediaToolbar.observeField("chaptersSelected", "onVideoMediaToolbarChaptersSelected")
    m.mediaToolbar.observeField("mediaInfoSelected", "onVideoMediaToolbarMediaInfoSelected")
    m.mediaToolbar.observeField("markAsWatchedSelected", "onMarkAsWatchedSelected")
    m.mediaToolbar.observeField("markAsUnwatchedSelected", "onMarkAsUnwatchedSelected")
    m.streamOptions.observeField("overlayRequested", "onStreamOptionsOverlayRequested")
    m.streamOptions.observeField("selectedSubtitle", "onSubtitleOptionSelected")
    m.streamOptions.observeField("selectedAudio", "onAudioOptionSelected")
    m.streamOptions.observeField("selectedChapter", "onChapterOptionSelected")
    m.streamOptions.observeField("closeRequested", "onStreamOptionsCloseRequested")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.state = {
        request: invalid
        item: invalid
        selectedStreams: {
            audio: invalid
            subtitle: invalid
            subtitleOff: false
        }
        selectedChapterKey: ""
        focusArea: "toolbar"
        themeLookupActive: false
        lifecycle: AsyncLifecycle_Create()
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.state.request = request
    m.top.settings = request.settings
    applyMediaShellBackgroundSetting(request.settings)
    m.state.item = request.item
    m.state.themeLookupActive = false
    AsyncLifecycle_Begin(m.state.lifecycle, request.itemId)
    m.state.selectedStreams = {
        audio: invalid
        subtitle: invalid
        subtitleOff: false
    }
    m.state.selectedChapterKey = ""
    m.cast.server = request.server
    Spinner_Show()
    renderMovie(request.item, true)

    m.movieTask.request = request
    m.movieTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onMovieResponse
'-------------------------------------------------------------------------------
sub onMovieResponse()
    response = m.movieTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.state.lifecycle, response, "itemId", "movie") <> true then return

    if response.ok <> true then
        renderMovie(m.state.item, false)
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this movie."))
        return
    end if

    m.state.item = response.payload
    renderMovie(response.payload, false)
    Spinner_Hide()
    Status_ClearMessage()
    loadThemeSong(response.payload)
end sub

'-------------------------------------------------------------------------------
' loadThemeSong
'-------------------------------------------------------------------------------
sub loadThemeSong(item as dynamic)
    request = m.state.request
    if request = invalid then return
    if isThemeMusicEnabled() <> true then
        m.log.write("Theme music playback is disabled")
        return
    end if

    m.log.write("Theme music playback is enabled")

    itemId = SafeString(FirstNonEmpty([item.Id, request.itemId], ""), "")
    if itemId = "" then return

    m.state.themeLookupActive = true
    m.themeSongsTask.control = "stop"
    m.themeSongsTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.themeSongsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onThemeSongsResponse
'-------------------------------------------------------------------------------
sub onThemeSongsResponse()
    response = m.themeSongsTask.response
    if response = invalid then return
    if m.state.lifecycle.isActive <> true then return
    if m.state.themeLookupActive <> true then return
    if response.ok <> true then
        m.log.write("Theme song lookup failed: " + SafeString(response.errorMessage, "Unknown error."))
        return
    end if

    themeSong = response.payload
    if Array_IsAssocArray(themeSong) = false then
        m.state.themeLookupActive = false
        m.log.write("Theme music enabled, but no theme song was found")
        return
    end if

    request = m.state.request
    if request = invalid then return
    if SafeString(response.itemId, "") <> SafeString(request.itemId, "") then return

    m.state.themeLookupActive = false
    themeSongId = SafeString(themeSong.Id, "")
    if themeSongId = "" then
        m.state.themeLookupActive = false
        return
    end if

    m.log.write("Theme song found itemId=" + themeSongId)
    m.top.themeRequested = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: themeSongId
        title: FirstNonEmpty([themeSong.Name, m.state.item.Name], "Theme Music")
        sourceItemId: SafeString(request.itemId, "")
    }
end sub

'-------------------------------------------------------------------------------
' renderMovie
'-------------------------------------------------------------------------------
sub renderMovie(item as dynamic, logoPending = false as boolean)
    if Array_IsAssocArray(item) = false then return

    metadataText = getPrimaryMetaText(item)
    genreText = getSecondaryMetaText(item)
    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
        logoPending: logoPending
        title: getItemTitle(item)
        primaryInfoText: metadataText
        secondaryInfoText: genreText
        overview: FirstNonEmpty([item.Overview], "")
    }
    m.cast.people = getPeople(item)
    m.mediaToolbar.subtitleStreamCount = getSubtitleStreams(item).Count()
    m.mediaToolbar.audioStreamCount = getAudioStreams(item).Count()
    m.mediaToolbar.chapterCount = getChapters(item).Count()
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item))
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.state.lifecycle, m.state.request, "itemId")
    if m.state.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
    else
        focusVideoMediaToolbar()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.state.lifecycle)
    m.state.themeLookupActive = false
    m.movieTask.control = "stop"
    m.themeSongsTask.control = "stop"
    m.watchedTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onMediaShellOverlayRequested
'-------------------------------------------------------------------------------
sub onMediaShellOverlayRequested()
    request = m.mediaShell.overlayRequested
    if request = invalid then return

    request.sourcePage = "movie"
    m.top.overlayRequested = request
end sub

'-------------------------------------------------------------------------------
' handleDescriptionOverlayClosed
'-------------------------------------------------------------------------------
sub handleDescriptionOverlayClosed()
    focusMediaDescription()
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    settings = m.top.settings
    if m.state <> invalid and m.state.request <> invalid then m.state.request.settings = settings
    applyMediaShellBackgroundSetting(settings)
end sub

'-------------------------------------------------------------------------------
' applyMediaShellBackgroundSetting
'-------------------------------------------------------------------------------
sub applyMediaShellBackgroundSetting(settings as dynamic)
    keys = SettingsStore_Keys()
    m.mediaShell.backgroundDisplay = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
end sub

'-------------------------------------------------------------------------------
' handleVideoMediaInfoOverlayClosed
'-------------------------------------------------------------------------------
sub handleVideoMediaInfoOverlayClosed()
    focusVideoMediaToolbar()
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

    selection.sourceItemType = "movie"
    selection.sourceItemId = SafeString(m.state.request.itemId, "")
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' focusVideoMediaToolbar
'-------------------------------------------------------------------------------
sub focusVideoMediaToolbar()
    m.state.focusArea = "toolbar"
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
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
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.state.focusArea = "cast"
    m.mediaToolbar.callFunc("deactivate")
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
    selection = buildPlaySelection(invalid)
    if selection = invalid then return

    m.log.write("Play selected audioStreamIndex=" + SafeString(selection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(selection.subtitleStreamIndex, ""))
    m.top.playSelected = selection
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarRestartSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarRestartSelected()
    selection = buildPlaySelection(0)
    if selection = invalid then return

    m.log.write("Restart selected audioStreamIndex=" + SafeString(selection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(selection.subtitleStreamIndex, ""))
    m.top.playSelected = selection
end sub

'-------------------------------------------------------------------------------
' buildPlaySelection
'-------------------------------------------------------------------------------
function buildPlaySelection(startPositionTicks as dynamic) as dynamic
    item = m.state.item
    request = m.state.request
    if request = invalid or item = invalid then return invalid

    itemId = SafeString(FirstNonEmpty([item.Id, request.itemId], ""), "")
    if itemId = "" then return invalid

    selection = {
        itemId: itemId
        item: item
    }
    if startPositionTicks <> invalid then selection.AddReplace("startPositionTicks", startPositionTicks)

    applySelectedStreamsToPlaySelection(selection)
    return selection
end function

'-------------------------------------------------------------------------------
' onVideoMediaToolbarSubtitlesSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarSubtitlesSelected()
    item = m.state.item
    if item = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "subtitleOptions"
    m.streamOptions.callFunc("openSubtitleOptions", {
        subtitleStreams: getSubtitleStreams(item)
        selectedSubtitleStreamIndex: getSelectedSubtitleStreamIndex()
    })
end sub

'-------------------------------------------------------------------------------
' onStreamOptionsOverlayRequested
'-------------------------------------------------------------------------------
sub onStreamOptionsOverlayRequested()
    request = m.streamOptions.overlayRequested
    if request = invalid then return

    request.sourcePage = "movie"
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
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarAudioSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarAudioSelected()
    item = m.state.item
    if item = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "audioOptions"
    m.streamOptions.callFunc("openAudioOptions", {
        audioStreams: getAudioStreams(item)
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
    item = m.state.item
    request = m.state.request
    if item = invalid or request = invalid then return

    itemId = SafeString(FirstNonEmpty([item.Id, request.itemId], ""), "")
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

    item = m.state.item
    if item = invalid then return

    itemId = SafeString(response.itemId, "")
    if itemId = "" or itemId <> SafeString(FirstNonEmpty([item.Id], ""), "") then return

    isWatched = SafeString(response.action, "") = "MarkAsWatched"
    updateItemWatchedState(item, isWatched)
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item))
    m.mediaToolbar.isWatched = isWatched
    m.mediaToolbar.callFunc("focusWatchedAction")
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' onVideoMediaToolbarChaptersSelected
'-------------------------------------------------------------------------------
sub onVideoMediaToolbarChaptersSelected()
    item = m.state.item
    if item = invalid then return

    chapters = getChapters(item)
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
    item = m.state.item
    if item = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "mediaInfo"
    m.top.overlayRequested = {
        id: "mediaInfo"
        sourcePage: "movie"
        componentName: "VideoMediaInfo"
        openFunction: "openVideoMediaInfo"
        closeField: "closeRequested"
        item: item
    }
end sub

'-------------------------------------------------------------------------------
' onChapterOptionSelected
'-------------------------------------------------------------------------------
sub onChapterOptionSelected()
    selection = m.streamOptions.selectedChapter
    if selection = invalid or selection.startPositionTicks = invalid then return

    playSelection = buildPlaySelection(selection.startPositionTicks)
    if playSelection = invalid then return

    m.state.selectedChapterKey = SafeString(selection.startPositionTicks, "")
    m.log.write("Chapter option selected startPositionTicks=" + SafeString(selection.startPositionTicks, "") + " label=" + SafeString(selection.label, ""))
    m.top.playSelected = playSelection
end sub

'-------------------------------------------------------------------------------
' onPlaybackProgressChange
'-------------------------------------------------------------------------------
sub onPlaybackProgressChange()
    change = m.top.playbackProgressChange
    if change = invalid then return

    item = m.state.item
    if item = invalid then return

    itemId = SafeString(change.itemId, "")
    currentItemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if currentItemId = "" and m.state.request <> invalid then currentItemId = SafeString(m.state.request.itemId, "")
    if itemId = "" or itemId <> currentItemId then return

    updateItemPlaybackProgress(item, change)
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item))
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if Array_IsAssocArray(item) = false then return "Movie"
    return FirstNonEmpty([item.Name], "Movie")
end function

'-------------------------------------------------------------------------------
' getPrimaryMetaText
'-------------------------------------------------------------------------------
function getPrimaryMetaText(item as dynamic) as string
    parts = []

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = DateTime_ToYear(item.PremiereDate)
    if year <> "" then parts.Push(year)

    runtime = MediaMetadata_FormatRuntime(item.RunTimeTicks)
    if runtime <> "" then parts.Push(runtime)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    communityRating = MediaMetadata_FormatRating(FirstNonEmpty([item.CommunityRating], ""))
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

' getSecondaryMetaText
'-------------------------------------------------------------------------------
function getSecondaryMetaText(item as dynamic) as string
    parts = []

    genres = getGenreText(item)
    if genres <> "" then parts.Push(genres)

    directorText = getDirectorText(item)
    if directorText <> "" then parts.Push(directorText)

    return joinText(parts, "     ")
end function

' getGenreText
'-------------------------------------------------------------------------------
function getGenreText(item as dynamic) as string
    if item.Genres = invalid then return ""
    return joinText(item.Genres, ", ")
end function

'-------------------------------------------------------------------------------
' getDirectorText
'-------------------------------------------------------------------------------
function getDirectorText(item as dynamic) as string
    directors = []
    if item.People = invalid then return ""

    for each person in item.People
        if person = invalid then continue for
        personType = LCase(FirstNonEmpty([person.Type], ""))
        if personType = "director" then
            name = FirstNonEmpty([person.Name], "")
            if name <> "" then directors.Push(name)
        end if
    end for

    if directors.Count() = 0 then return ""
    if directors.Count() = 1 then return "Director " + directors[0]
    return "Directors " + joinText(directors, ", ")
end function

'-------------------------------------------------------------------------------
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item.People = invalid then return []
    return item.People
end function

'-------------------------------------------------------------------------------
' isItemWatched
'-------------------------------------------------------------------------------
function isItemWatched(item as dynamic) as boolean
    if item = invalid then return false
    if item.UserData = invalid then return false

    return item.UserData.Played = true
end function

'-------------------------------------------------------------------------------
' updateItemWatchedState
'-------------------------------------------------------------------------------
sub updateItemWatchedState(item as dynamic, isWatched as boolean)
    if item = invalid then return
    if item.UserData = invalid then item.UserData = {}

    item.UserData.Played = isWatched
    if isWatched then
        item.UserData.PlayedPercentage = 0
        item.UserData.PlaybackPositionTicks = 0
    else
        item.UserData.PlayedPercentage = 0
    end if

    m.state.item = item
end sub

'-------------------------------------------------------------------------------
' updateItemPlaybackProgress
'-------------------------------------------------------------------------------
sub updateItemPlaybackProgress(item as dynamic, change as object)
    if item = invalid then return
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

    m.state.item = item
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
' getBackdropUrl
'-------------------------------------------------------------------------------
function getBackdropUrl(item as dynamic) as string
    if item = invalid then return ""
    imageSize = DeviceCapabilities_GetMaxScreenImageSize()
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then
        itemId = FirstNonEmpty([item.Id], "")
        request = m.state.request
        if request = invalid then return ""
        return Url_BuildImageUrl(request.server, itemId, "Backdrop", item.BackdropImageTags[0], imageSize.width, imageSize.height)
    end if

    return getImageUrl(item, "Primary", imageSize.width, imageSize.height)
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
    if imageType = "Backdrop" and item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""
    request = m.state.request
    if request = invalid then return ""

    options = invalid
    if imageType = "Logo" then options = { format: "Png" }
    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height, options)
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
' isThemeMusicEnabled
'-------------------------------------------------------------------------------
function isThemeMusicEnabled() as boolean
    return false
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    if key = "up" and m.cast.isInFocusChain() then
        focusVideoMediaToolbar()
        return true
    end if

    if key = "up" and m.state.focusArea = "toolbar" then
        return focusMediaDescription()
    end if

    if key = "down" and m.state.focusArea = "description" then
        focusVideoMediaToolbar()
        return true
    end if

    if key = "down" and m.state.focusArea = "toolbar" then
        focusCast()
        return true
    end if

    if key = "play" and m.state.focusArea = "toolbar" then
        onVideoMediaToolbarPlaySelected()
        return true
    end if

    return false
end function

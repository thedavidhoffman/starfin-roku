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
    m.watchedTask = m.top.findNode("watchedTask")

    m.movieTask.observeField("response", "onMovieResponse")
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
    m.state = {
        request: invalid
        item: invalid
        selectedStreams: {
            audio: invalid
            subtitle: invalid
            subtitleOff: false
        }
        focusArea: "toolbar"
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.state.request = request
    m.state.item = request.item
    m.state.selectedStreams = {
        audio: invalid
        subtitle: invalid
        subtitleOff: false
    }
    m.cast.server = request.server
    Status_SetLoading()
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

    if response.ok <> true then
        renderMovie(m.state.item, false)
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this movie."))
        return
    end if

    m.state.item = response.payload
    renderMovie(response.payload, false)
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' renderMovie
'-------------------------------------------------------------------------------
sub renderMovie(item as dynamic, logoPending = false as boolean)
    if isAssocArray(item) = false then return

    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
        logoPending: logoPending
        title: getItemTitle(item)
        metaLine1: getPrimaryMetaText(item)
        metaLine2: getSecondaryMetaText(item)
        overview: FirstNonEmpty([item.Overview], "")
    }
    m.cast.people = getPeople(item)
    m.mediaToolbar.subtitleStreamCount = getSubtitleStreams(item).Count()
    m.mediaToolbar.audioStreamCount = getAudioStreams(item).Count()
    m.mediaToolbar.resumePositionSeconds = PlaybackProgress_TicksToSeconds(PlaybackProgress_GetTicksFromItem(item))
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.state.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
    else
        focusMediaToolbar()
    end if
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

    selection.sourceItemType = "movie"
    selection.sourceItemId = SafeString(m.state.request.itemId, "")
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' focusMediaToolbar
'-------------------------------------------------------------------------------
sub focusMediaToolbar()
    m.state.focusArea = "toolbar"
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
    m.mediaToolbar.callFunc("activate")
end sub

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
' onMediaToolbarFocusExitDown
'-------------------------------------------------------------------------------
sub onMediaToolbarFocusExitDown()
    focusCast()
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarPlaySelected
'-------------------------------------------------------------------------------
sub onMediaToolbarPlaySelected()
    selection = buildPlaySelection(invalid)
    if selection = invalid then return

    m.log.write("Play selected audioStreamIndex=" + SafeString(selection.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(selection.subtitleStreamIndex, ""))
    m.top.playSelected = selection
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarRestartSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarRestartSelected()
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
' onMediaToolbarSubtitlesSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarSubtitlesSelected()
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
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarAudioSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarAudioSelected()
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
    if isAssocArray(item) = false then return "Movie"
    return FirstNonEmpty([item.Name], "Movie")
end function

'-------------------------------------------------------------------------------
' getPrimaryMetaText
'-------------------------------------------------------------------------------
function getPrimaryMetaText(item as dynamic) as string
    parts = []

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
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

' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
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
        m.top.closeRequested = true
        return true
    end if

    if key = "up" and m.cast.isInFocusChain() then
        focusMediaToolbar()
        return true
    end if

    if key = "down" and m.state.focusArea = "toolbar" then
        focusCast()
        return true
    end if

    if key = "play" and m.state.focusArea = "toolbar" then
        onMediaToolbarPlaySelected()
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Movie")
    m.mediaShell = m.top.findNode("mediaShell")
    m.mediaToolbar = m.top.findNode("mediaToolbar")
    m.subtitleOptions = m.top.findNode("subtitleOptions")
    m.audioOptions = m.top.findNode("audioOptions")
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
    m.subtitleOptions.observeField("selectedSubtitle", "onSubtitleOptionSelected")
    m.subtitleOptions.observeField("closeRequested", "onSubtitleOptionsCloseRequested")
    m.audioOptions.observeField("selectedAudio", "onAudioOptionSelected")
    m.audioOptions.observeField("closeRequested", "onAudioOptionsCloseRequested")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.pageState = {
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

    m.pageState.request = request
    m.pageState.item = request.item
    m.pageState.selectedStreams = {
        audio: invalid
        subtitle: invalid
        subtitleOff: false
    }
    m.cast.server = request.server
    Status_SetLoading()
    renderMovie(request.item)

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
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this movie."))
        return
    end if

    m.pageState.item = response.payload
    renderMovie(response.payload)
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' renderMovie
'-------------------------------------------------------------------------------
sub renderMovie(item as dynamic)
    if isAssocArray(item) = false then return

    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
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
    if m.pageState.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
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

    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' focusMediaToolbar
'-------------------------------------------------------------------------------
sub focusMediaToolbar()
    m.pageState.focusArea = "toolbar"
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
    m.mediaToolbar.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.pageState.focusArea = "cast"
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
    item = m.pageState.item
    request = m.pageState.request
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
    item = m.pageState.item
    if item = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.pageState.focusArea = "subtitleOptions"
    m.subtitleOptions.subtitleStreams = getSubtitleStreams(item)
    m.subtitleOptions.selectedSubtitleStreamIndex = getSelectedSubtitleStreamIndex()
    m.subtitleOptions.callFunc("openOptions")
end sub

'-------------------------------------------------------------------------------
' onSubtitleOptionsCloseRequested
'-------------------------------------------------------------------------------
sub onSubtitleOptionsCloseRequested()
    focusMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onSubtitleOptionSelected
'-------------------------------------------------------------------------------
sub onSubtitleOptionSelected()
    selection = m.subtitleOptions.selectedSubtitle
    if selection = invalid then return

    if selection.isOff = true then
        m.pageState.selectedStreams.subtitle = invalid
        m.pageState.selectedStreams.subtitleOff = true
        m.log.write("Subtitle option selected: Off")
    else
        m.pageState.selectedStreams.subtitle = selection
        m.pageState.selectedStreams.subtitleOff = false
        m.log.write("Subtitle option selected streamIndex=" + SafeString(selection.streamIndex, "") + " label=" + SafeString(selection.label, ""))
    end if
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarAudioSelected
'-------------------------------------------------------------------------------
sub onMediaToolbarAudioSelected()
    item = m.pageState.item
    if item = invalid then return

    m.mediaToolbar.callFunc("deactivate")
    m.pageState.focusArea = "audioOptions"
    m.audioOptions.audioStreams = getAudioStreams(item)
    m.audioOptions.selectedAudioStreamIndex = getSelectedAudioStreamIndex()
    m.audioOptions.callFunc("openOptions")
end sub

'-------------------------------------------------------------------------------
' onAudioOptionsCloseRequested
'-------------------------------------------------------------------------------
sub onAudioOptionsCloseRequested()
    focusMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onAudioOptionSelected
'-------------------------------------------------------------------------------
sub onAudioOptionSelected()
    selection = m.audioOptions.selectedAudio
    if selection = invalid then return

    m.pageState.selectedStreams.audio = selection
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
    item = m.pageState.item
    request = m.pageState.request
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

    item = m.pageState.item
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

    m.pageState.item = item
end sub

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
    if m.pageState = invalid or m.pageState.selectedStreams = invalid then return -1
    if m.pageState.selectedStreams.audio = invalid then return -1

    return getSelectedStreamIndex(m.pageState.selectedStreams.audio, -1)
end function

'-------------------------------------------------------------------------------
' getSelectedSubtitleStreamIndex
'-------------------------------------------------------------------------------
function getSelectedSubtitleStreamIndex() as integer
    if m.pageState = invalid or m.pageState.selectedStreams = invalid then return -2
    if m.pageState.selectedStreams.subtitleOff = true then return -1
    if m.pageState.selectedStreams.subtitle = invalid then return -2

    return getSelectedStreamIndex(m.pageState.selectedStreams.subtitle, -2)
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
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then
        itemId = FirstNonEmpty([item.Id], "")
        return buildImageUrl(itemId, "Backdrop", item.BackdropImageTags[0], 1920, 1080)
    end if

    return getImageUrl(item, "Primary", 1920, 1080)
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

    return buildImageUrl(itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.pageState.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    url = url + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    if imageType = "Logo" then url = url + "&format=Png"
    return url
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

    if key = "down" and m.pageState.focusArea = "toolbar" then
        focusCast()
        return true
    end if

    if key = "play" and m.pageState.focusArea = "toolbar" then
        onMediaToolbarPlaySelected()
        return true
    end if

    return false
end function

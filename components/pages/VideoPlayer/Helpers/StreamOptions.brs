'-------------------------------------------------------------------------------
' updatePlaybackControlsOptions
'-------------------------------------------------------------------------------
sub updatePlaybackControlsOptions(item as dynamic)
    subtitleStreams = getSubtitleStreams(item)
    audioStreams = getAudioStreams(item)
    chapters = getChapters(item)
    m.streamOptions.subtitleStreams = subtitleStreams
    m.streamOptions.audioStreams = audioStreams
    m.streamOptions.chapters = chapters
    m.streamOptions.selectedChapterKey = ""
    m.streamOptions.selectedSubtitleStreamIndex = getSelectedSubtitleStreamIndex(m.top.playRequest)
    m.streamOptions.selectedAudioStreamIndex = getSelectedAudioStreamIndex(m.top.playRequest, audioStreams)
    m.playbackControls.hasSubtitleOptions = subtitleStreams.Count() > 0
    m.playbackControls.hasAudioOptions = audioStreams.Count() > 1
    m.playbackControls.hasChapterOptions = chapters.Count() > 0
end sub

'-------------------------------------------------------------------------------
' getSubtitleStreams
'-------------------------------------------------------------------------------
function getSubtitleStreams(item as dynamic) as object
    if item = invalid or item.MediaStreams = invalid then return []

    subtitleStreams = []
    for each stream in item.MediaStreams
        if stream <> invalid and LCase(SafeString(stream.Type, "")) = "subtitle" then subtitleStreams.Push(stream)
    end for

    return subtitleStreams
end function

'-------------------------------------------------------------------------------
' getAudioStreams
'-------------------------------------------------------------------------------
function getAudioStreams(item as dynamic) as object
    if item = invalid or item.MediaStreams = invalid then return []

    audioStreams = []
    for each stream in item.MediaStreams
        if stream <> invalid and LCase(SafeString(stream.Type, "")) = "audio" then audioStreams.Push(stream)
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
' getSelectedSubtitleStreamIndex
'-------------------------------------------------------------------------------
function getSelectedSubtitleStreamIndex(request as dynamic) as integer
    if request <> invalid and request.subtitleStreamIndex <> invalid then return int(request.subtitleStreamIndex)

    return -1
end function

'-------------------------------------------------------------------------------
' getSelectedAudioStreamIndex
'-------------------------------------------------------------------------------
function getSelectedAudioStreamIndex(request as dynamic, audioStreams as object) as integer
    if request <> invalid and request.audioStreamIndex <> invalid then return int(request.audioStreamIndex)

    for i = 0 to audioStreams.Count() - 1
        stream = audioStreams[i]
        if stream = invalid then continue for
        streamIndex = getStreamIndex(stream, i)
        if stream.IsDefault = true then return streamIndex
    end for

    if audioStreams.Count() = 0 then return -1
    return getStreamIndex(audioStreams[0], 0)
end function

'-------------------------------------------------------------------------------
' getStreamIndex
'-------------------------------------------------------------------------------
function getStreamIndex(stream as dynamic, fallback as integer) as integer
    if stream <> invalid and stream.Index <> invalid then return int(stream.Index)
    if stream <> invalid and stream.sourceIndex <> invalid then return int(stream.sourceIndex)
    return fallback
end function

'-------------------------------------------------------------------------------
' onSubtitleOptionsPressed
'-------------------------------------------------------------------------------
sub onSubtitleOptionsPressed()
    if m.streamOptions.subtitleStreams.Count() = 0 then return

    m.controlsHideTimer.control = "stop"
    m.top.streamOptionsRequested = {
        id: "subtitleOptions"
        sourcePage: "videoPlayer"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Subtitles"
        options: MediaOptions_BuildSubtitleOptions(m.streamOptions.subtitleStreams)
        selectedKey: m.streamOptions.selectedSubtitleStreamIndex.ToStr()
        emptyText: "No subtitles available."
    }
end sub

'-------------------------------------------------------------------------------
' onAudioOptionsPressed
'-------------------------------------------------------------------------------
sub onAudioOptionsPressed()
    if m.streamOptions.audioStreams.Count() <= 1 then return

    m.controlsHideTimer.control = "stop"
    m.top.streamOptionsRequested = {
        id: "audioOptions"
        sourcePage: "videoPlayer"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Audio"
        options: MediaOptions_BuildAudioOptions(m.streamOptions.audioStreams)
        selectedKey: m.streamOptions.selectedAudioStreamIndex.ToStr()
        emptyText: "No audio tracks available."
    }
end sub

'-------------------------------------------------------------------------------
' onChapterOptionsPressed
'-------------------------------------------------------------------------------
sub onChapterOptionsPressed()
    if m.streamOptions.chapters.Count() = 0 then return

    m.controlsHideTimer.control = "stop"
    m.top.streamOptionsRequested = {
        id: "chapterOptions"
        sourcePage: "videoPlayer"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Chapters"
        options: MediaOptions_BuildChapterOptions(m.streamOptions.chapters)
        selectedKey: m.streamOptions.selectedChapterKey
        allowDefaultSelection: false
        emptyText: "No chapters available."
    }
end sub

'-------------------------------------------------------------------------------
' handleStreamOptionsOverlayClosed
'-------------------------------------------------------------------------------
sub handleStreamOptionsOverlayClosed(closed as object)
    if closed = invalid then return
    request = closed.request
    overlay = closed.overlay
    if request = invalid or overlay = invalid then return

    requestId = SafeString(request.id, "")
    selection = getClosedOptionValue(overlay)
    chapterSelected = false
    if requestId = "subtitleOptions" then
        applySubtitleSelection(selection)
    else if requestId = "audioOptions" then
        applyAudioSelection(selection)
    else if requestId = "chapterOptions" and overlay.selectedOptionChanged = true then
        applyChapterSelection(selection)
        chapterSelected = true
    end if

    if chapterSelected = true then
        hideControls()
        return
    end if

    if m.overlay.area = "controls" then
        m.playbackControls.callFunc("activate")
        m.playbackControls.callFunc("focusButtons")
        m.controlsHideTimer.control = "start"
    else
        m.top.setFocus(true)
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
' applySubtitleSelection
'-------------------------------------------------------------------------------
sub applySubtitleSelection(selection as dynamic)
    if selection = invalid then return

    streamIndex = -1
    if selection.streamIndex <> invalid then streamIndex = int(selection.streamIndex)
    if streamIndex = m.streamOptions.selectedSubtitleStreamIndex then return

    m.streamOptions.selectedSubtitleStreamIndex = streamIndex
    restartPlaybackWithStreamOptions()
end sub

'-------------------------------------------------------------------------------
' applyAudioSelection
'-------------------------------------------------------------------------------
sub applyAudioSelection(selection as dynamic)
    if selection = invalid or selection.streamIndex = invalid then return

    streamIndex = int(selection.streamIndex)
    if streamIndex = m.streamOptions.selectedAudioStreamIndex then return

    m.streamOptions.selectedAudioStreamIndex = streamIndex
    restartPlaybackWithStreamOptions()
end sub

'-------------------------------------------------------------------------------
' applyChapterSelection
'-------------------------------------------------------------------------------
sub applyChapterSelection(selection as dynamic)
    if selection = invalid or selection.startPositionSeconds = invalid then return

    m.streamOptions.selectedChapterKey = SafeString(selection.startPositionTicks, "")
    targetPosition = selection.startPositionSeconds
    if m.playback.duration <> invalid and m.playback.duration > 0 then
        targetPosition = clampSeconds(targetPosition, 0, m.playback.duration)
    end if

    stopSeekTimers()
    m.playback.isSeeking = false
    m.playback.previewPosition = targetPosition
    m.playback.position = targetPosition
    m.videoPlayer.seek = targetPosition
    if m.playback.isPlaying = true then
        m.videoPlayer.control = "resume"
    else
        m.videoPlayer.control = "pause"
    end if

    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    m.playbackControls.position = targetPosition
    m.playbackControls.previewPosition = targetPosition
end sub

'-------------------------------------------------------------------------------
' restartPlaybackWithStreamOptions
'-------------------------------------------------------------------------------
sub restartPlaybackWithStreamOptions()
    request = buildStreamRestartPlayRequest()
    if request = invalid then return

    m.log.write("Restarting playback with stream options audioStreamIndex=" + SafeString(request.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(request.subtitleStreamIndex, ""))
    m.top.playRequest = request
end sub

'-------------------------------------------------------------------------------
' buildStreamRestartPlayRequest
'-------------------------------------------------------------------------------
function buildStreamRestartPlayRequest() as dynamic
    request = m.top.playRequest
    if request = invalid then return invalid

    restartRequest = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: request.itemId
        item: request.item
        series: request.series
        season: request.season
        startPositionTicks: secondsToTicks(m.playback.position)
        playbackQueue: request.playbackQueue
        playbackQueueIndex: request.playbackQueueIndex
        audioStreamIndex: m.streamOptions.selectedAudioStreamIndex
        subtitleStreamIndex: m.streamOptions.selectedSubtitleStreamIndex
    }
    if request.mediaSourceId <> invalid then restartRequest.AddReplace("mediaSourceId", request.mediaSourceId)

    return restartRequest
end function

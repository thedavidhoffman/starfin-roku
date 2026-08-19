'-------------------------------------------------------------------------------
' updatePlaybackControlsOptions
'-------------------------------------------------------------------------------
sub updatePlaybackControlsOptions(item as dynamic)
    subtitleStreams = VideoPlayerStreamSelection_GetSubtitleStreams(item)
    audioStreams = VideoPlayerStreamSelection_GetAudioStreams(item)
    chapters = getChapters(item)
    m.streamOptions.subtitleStreams = subtitleStreams
    m.streamOptions.audioStreams = audioStreams
    m.streamOptions.chapters = chapters
    m.streamOptions.selectedChapterKey = ""
    m.streamOptions.selectedSubtitleStreamIndex = VideoPlayerStreamSelection_GetSubtitleIndex(m.top.playRequest)
    m.streamOptions.selectedAudioStreamIndex = VideoPlayerStreamSelection_GetAudioIndex(m.top.playRequest, audioStreams)
    m.playbackControls.hasSubtitleOptions = subtitleStreams.Count() > 0
    m.playbackControls.hasAudioOptions = audioStreams.Count() > 1
    m.playbackControls.hasChapterOptions = chapters.Count() > 0
    m.playbackControls.hasVideoOptions = true
end sub

'-------------------------------------------------------------------------------
' getChapters
'-------------------------------------------------------------------------------
function getChapters(item as dynamic) as object
    return MediaOptions_GetChapters(item)
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
' onVideoOptionsPressed
'-------------------------------------------------------------------------------
sub onVideoOptionsPressed()
    request = m.top.playRequest
    if request = invalid then return

    m.controlsHideTimer.control = "stop"
    m.top.streamOptionsRequested = {
        id: "videoOptions"
        sourcePage: "videoPlayer"
        componentName: "VideoOptionsDialog"
        openFunction: "openVideoOptions"
        closeField: "closeRequested"
        selectedKey: SafeString(request.videoMode, PlaybackMode_Values().automatic)
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
    chapterSelected = false
    if requestId = "subtitleOptions" then
        selection = getClosedOptionValue(overlay)
        applySubtitleSelection(selection)
    else if requestId = "audioOptions" then
        selection = getClosedOptionValue(overlay)
        applyAudioSelection(selection)
    else if requestId = "chapterOptions" and overlay.selectedOptionChanged = true then
        selection = getClosedOptionValue(overlay)
        applyChapterSelection(selection)
        chapterSelected = true
    else if requestId = "videoOptions" then
        applyVideoModeSelection(overlay.selectedOption)
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
' applyVideoModeSelection
'-------------------------------------------------------------------------------
sub applyVideoModeSelection(selection as dynamic)
    if selection = invalid then return

    videoMode = PlaybackMode_Normalize(selection.key)
    request = m.top.playRequest
    if request = invalid then return
    if videoMode = PlaybackMode_Normalize(request.videoMode) then return

    m.streamOptions.pendingVideoMode = videoMode

    ' Yield one SceneGraph turn so OverlayHost removal renders before the
    ' playRequest change performs synchronous player teardown and setup.
    m.videoModeApplyTimer.control = "stop"
    m.videoModeApplyTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' onVideoModeApplyTimerFire
'-------------------------------------------------------------------------------
sub onVideoModeApplyTimerFire()
    videoMode = m.streamOptions.pendingVideoMode
    m.streamOptions.pendingVideoMode = ""
    if videoMode = "" then return

    restartRequest = buildStreamRestartPlayRequest()
    if restartRequest = invalid then return

    restartRequest.AddReplace("videoMode", videoMode)
    m.log.writeDisplaySafe("Restarting playback with video mode=" + videoMode)
    m.top.playRequest = restartRequest
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
        targetPosition = VideoPlayerMetadata_ClampSeconds(targetPosition, 0, m.playback.duration)
    end if

    stopSeekTimers()
    logPlaybackSeekRequest("chapterSelection", targetPosition)
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

    m.log.writeDisplaySafe("Restarting playback with stream options audioStreamIndex=" + SafeString(request.audioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(request.subtitleStreamIndex, ""))
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
        playbackQueueMode: request.playbackQueueMode
        audioStreamIndex: m.streamOptions.selectedAudioStreamIndex
        subtitleStreamIndex: m.streamOptions.selectedSubtitleStreamIndex
    }
    if request.mediaSourceId <> invalid then restartRequest.AddReplace("mediaSourceId", request.mediaSourceId)
    restartRequest.AddReplace("videoMode", getOriginalPlaybackMode())

    return restartRequest
end function

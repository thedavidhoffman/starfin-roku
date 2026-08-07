'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initHandlers()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.log = CreateLogger("VideoPlayer")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.playbackControls = m.top.findNode("playbackControls")
    m.clock = m.top.findNode("clock")
    m.castGradient = m.top.findNode("castGradient")
    m.cast = m.top.findNode("cast")
    m.skipIntroButton = m.top.findNode("skipIntroButton")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")
    m.mediaSegmentsTask = m.top.findNode("mediaSegmentsTask")
    m.playstateTask = m.top.findNode("playstateTask")
    m.trickplayPreloadTask = m.top.findNode("trickplayPreloadTask")
    m.controlsHideTimer = m.top.findNode("controlsHideTimer")
    m.playstateTimer = m.top.findNode("playstateTimer")
    m.fastSeekTimer = m.top.findNode("fastSeekTimer")
    m.leftSeekRepeatTimer = m.top.findNode("leftSeekRepeatTimer")
    m.rightSeekRepeatTimer = m.top.findNode("rightSeekRepeatTimer")
    m.videoModeApplyTimer = m.top.findNode("videoModeApplyTimer")
    m.recoveryBufferTimer = m.top.findNode("recoveryBufferTimer")
    m.recoveryStableTimer = m.top.findNode("recoveryStableTimer")

    m.playback = {
        isSeeking: false
        isPlaying: false
        startupPending: false
        hasReportedStart: false
        hasEmittedFinalProgress: false
        waitingForStartPosition: false
        previewPosition: 0
        position: 0
        duration: 0
    }

    m.session = {
        server: ""
        token: ""
        userId: ""
        itemId: ""
        playSessionId: ""
    }

    m.queue = {
        items: []
        index: -1
    }

    m.context = {
        item: invalid
        series: invalid
        season: invalid
    }

    m.overlay = {
        area: "none"
        hasCast: false
        resumeAfterPersonNavigation: false
        restoreCastAfterPersonNavigation: false
    }

    m.streamOptions = {
        subtitleStreams: []
        audioStreams: []
        chapters: []
        selectedSubtitleStreamIndex: -1
        selectedAudioStreamIndex: -1
        selectedChapterKey: ""
        pendingVideoMode: ""
    }

    m.seek = {
        speeds: [-180, -60, -30, -10, 10, 30, 60, 180]
        speedIndex: -1
        direction: ""
        isAccelerating: false
    }
    
    m.trickplay = invalid
    m.trickplayPreloadRequest = invalid
    initMediaSegments()
    initPlaybackRecovery()
#if playbackChaosMonkey
    initPlaybackChaosMonkey()
#endif
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.mediaSegmentsTask.observeField("response", "onMediaSegmentsResponse")
    m.trickplayPreloadTask.observeField("response", "onTrickplayPreloadResponse")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
    m.videoPlayer.observeField("position", "onVideoPositionChanged")
    m.videoPlayer.observeField("duration", "onVideoDurationChanged")
    m.playbackControls.observeField("visible", "onPlaybackControlsVisibilityChanged")
    m.playbackControls.observeField("playPausePressed", "onPlayPausePressed")
    m.playbackControls.observeField("skipBackPressed", "onSkipBackPressed")
    m.playbackControls.observeField("skipForwardPressed", "onSkipForwardPressed")
    m.playbackControls.observeField("last5Pressed", "onLast5Pressed")
    m.playbackControls.observeField("progressLeftPressed", "onProgressLeftPressed")
    m.playbackControls.observeField("progressRightPressed", "onProgressRightPressed")
    m.playbackControls.observeField("progressLeftReleased", "onProgressLeftReleased")
    m.playbackControls.observeField("progressRightReleased", "onProgressRightReleased")
    m.playbackControls.observeField("progressRewindPressed", "onProgressRewindPressed")
    m.playbackControls.observeField("progressFastForwardPressed", "onProgressFastForwardPressed")
    m.playbackControls.observeField("progressSeekCommit", "onProgressSeekCommit")
    m.playbackControls.observeField("progressSeekCancel", "onProgressSeekCancel")
    m.playbackControls.observeField("castOptionsPressed", "onCastOptionsPressed")
    m.playbackControls.observeField("chapterOptionsPressed", "onChapterOptionsPressed")
    m.playbackControls.observeField("subtitleOptionsPressed", "onSubtitleOptionsPressed")
    m.playbackControls.observeField("audioOptionsPressed", "onAudioOptionsPressed")
    m.playbackControls.observeField("videoOptionsPressed", "onVideoOptionsPressed")
    m.playbackControls.observeField("focusExitDown", "onPlaybackControlsFocusExitDown")
    m.cast.observeField("hasItems", "onCastAvailabilityChanged")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("focusExitDown", "onCastFocusExitDown")
    m.cast.observeField("userInteraction", "onCastUserInteraction")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.controlsHideTimer.observeField("fire", "onControlsHideTimerFire")
    m.playstateTimer.observeField("fire", "onPlaystateTimerFire")
    m.fastSeekTimer.observeField("fire", "onFastSeekTimerFire")
    m.leftSeekRepeatTimer.observeField("fire", "onLeftSeekRepeatTimerFire")
    m.rightSeekRepeatTimer.observeField("fire", "onRightSeekRepeatTimerFire")
    m.videoModeApplyTimer.observeField("fire", "onVideoModeApplyTimerFire")
    m.recoveryBufferTimer.observeField("fire", "onPlaybackRecoveryBufferTimerFire")
    m.recoveryStableTimer.observeField("fire", "onPlaybackRecoveryStableTimerFire")
end sub

'-------------------------------------------------------------------------------
' onPlaybackControlsVisibilityChanged
'-------------------------------------------------------------------------------
sub onPlaybackControlsVisibilityChanged()
    controlsVisible = m.playbackControls.visible = true
    m.clock.visible = controlsVisible
end sub

'-------------------------------------------------------------------------------
' onVideoStateChanged
'-------------------------------------------------------------------------------
sub onVideoStateChanged()
    state = LCase(SafeString(m.videoPlayer.state, ""))
    m.log.write("Video state changed state=" + state + " position=" + SafeString(m.videoPlayer.position, ""))
    updateBufferingSpinner(state)
    onPlaybackRecoveryStateChanged(state)
#if playbackChaosMonkey
    onPlaybackChaosMonkeyStateChanged(state)
#endif
    m.playback.isPlaying = state = "playing" or state = "buffering"
    m.playbackControls.isPlaying = m.playback.isPlaying
    updateSkipIntroButton(m.playback.position)
    if state = "error" then
        reportPlaystateStop()
        if handlePlaybackRecoveryFailure("videoError", SafeString(m.videoPlayer.errorStr, "")) then return
        finalizePlaybackRecoveryFailure("Unable to play this video after recovery attempts.")
    else if state = "finished" then
        stopPlaybackRecoveryTimers()
        reportPlaystateStop()
        emitPlaybackProgress(true)
        if isPlaylistPlaybackQueue() and startQueueItemAtOffset(1) then return
        requestUpNextAutoPlay()
        stopPlayback()
        m.top.closeRequested = true
    else if state = "playing" then
        if m.playback.hasReportedStart = true then
            reportPlaystateUpdate()
        else
            reportPlaystateStart()
        end if
        m.playstateTimer.control = "start"
    else if state = "paused" then
        m.playstateTimer.control = "stop"
        reportPlaystateUpdate()
    else if state = "stopped" then
        if isPlaybackRecoveryRestarting() then return
        emitPlaybackProgress(false)
        reportPlaystateStop()
        enableScreenSaver()
    end if

end sub

'-------------------------------------------------------------------------------
' updateBufferingSpinner
'-------------------------------------------------------------------------------
sub updateBufferingSpinner(state as string)
    if state = "buffering" then
        m.playback.startupPending = false
        Spinner_Show(0)
    else if state = "stopped" and m.playback.startupPending = true then
        return
    else
        m.playback.startupPending = false
        Spinner_Hide()
    end if
end sub

'-------------------------------------------------------------------------------
' onVideoPositionChanged
'-------------------------------------------------------------------------------
sub onVideoPositionChanged()
    position = Number_ToFloat(m.videoPlayer.position, 0)
    if m.playback.waitingForStartPosition and position <= 0 then return

    m.playback.waitingForStartPosition = false
    m.playback.position = position
    recordPlaybackRecoveryPosition(position)
    updateSkipIntroButton(position)
    if m.playback.isSeeking <> true then
        m.playbackControls.position = m.playback.position
    end if
end sub

'-------------------------------------------------------------------------------
' onVideoDurationChanged
'-------------------------------------------------------------------------------
sub onVideoDurationChanged()
    duration = m.videoPlayer.duration
    if duration = invalid or duration <= 0 then return

    m.playback.duration = duration
    m.playbackControls.duration = duration
end sub

'-------------------------------------------------------------------------------
' onControlsHideTimerFire
'-------------------------------------------------------------------------------
sub onControlsHideTimerFire()
    if m.playback.isSeeking = true then return
    if m.overlay.area = "cast" then
        hideCast(true)
        return
    end if
    hideControls()
end sub

'-------------------------------------------------------------------------------
' disableScreenSaver
'-------------------------------------------------------------------------------
sub disableScreenSaver()
    m.videoPlayer.disableScreenSaver = true
end sub

'-------------------------------------------------------------------------------
' enableScreenSaver
'-------------------------------------------------------------------------------
sub enableScreenSaver()
    m.videoPlayer.disableScreenSaver = false
end sub

'-------------------------------------------------------------------------------
' stopPlayback
'-------------------------------------------------------------------------------
sub stopPlayback(preserveRecovery = false as boolean)
    if m.playback <> invalid then m.playback.startupPending = false
    m.playbackInfoTask.control = "stop"
    m.mediaSegmentsTask.control = "stop"
    m.videoModeApplyTimer.control = "stop"
    stopPlaybackRecoveryTimers()
#if playbackChaosMonkey
    stopPlaybackChaosMonkeyTimer()
#endif
    m.streamOptions.pendingVideoMode = ""
    Spinner_Hide()
    hideControls()
    hideCast()
    reportPlaystateStop()
    cleanupTrickplayPreload()
    m.videoPlayer.control = "stop"
    enableScreenSaver()
    if preserveRecovery <> true then resetMediaSegments()
    if preserveRecovery <> true then resetPlaybackRecovery()
#if playbackChaosMonkey
    if preserveRecovery <> true then stopPlaybackChaosMonkey()
#endif
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if item = invalid then return "Video"
    return FirstNonEmpty([item.Name], "Video")
end function

'-------------------------------------------------------------------------------
' updatePlaybackControlsMetadata
'-------------------------------------------------------------------------------
sub updatePlaybackControlsMetadata(request as object, item as dynamic)
    if item = invalid then
        m.playbackControls.title = "Video"
        m.playbackControls.subtitle = ""
        m.playbackControls.hasSubtitleOptions = false
        m.playbackControls.hasAudioOptions = false
        m.playbackControls.hasChapterOptions = false
        return
    end if

    if isTVEpisodePlayback(request, item) then
        m.playbackControls.title = getSeriesTitle(request, item)
        m.playbackControls.subtitle = getEpisodePlaybackMetadata(item)
    else
        m.playbackControls.title = getItemTitle(item)
        m.playbackControls.subtitle = getMoviePlaybackMetadata(item)
    end if
end sub

'-------------------------------------------------------------------------------
' isTVEpisodePlayback
'-------------------------------------------------------------------------------
function isTVEpisodePlayback(request as object, item as dynamic) as boolean
    if request <> invalid and request.series <> invalid then return true
    if item = invalid then return false

    itemType = LCase(FirstNonEmpty([item.Type], ""))
    return itemType = "episode"
end function

'-------------------------------------------------------------------------------
' getSeriesTitle
'-------------------------------------------------------------------------------
function getSeriesTitle(request as object, item as dynamic) as string
    if request <> invalid and request.series <> invalid then
        identity = SeriesIdentity_FromItem(SafeString(request.server, ""), request.series)
        if identity <> invalid then
            title = FirstNonEmpty([identity.Name], "")
            if title <> "" then return title
        end if
    end if

    return FirstNonEmpty([item.SeriesName, item.Series], getItemTitle(item))
end function

'-------------------------------------------------------------------------------
' getMoviePlaybackMetadata
'-------------------------------------------------------------------------------
function getMoviePlaybackMetadata(item as dynamic) as string
    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = DateTime_ToYear(item.PremiereDate)

    return year
end function

'-------------------------------------------------------------------------------
' getEpisodePlaybackMetadata
'-------------------------------------------------------------------------------
function getEpisodePlaybackMetadata(item as dynamic) as string
    parts = []

    episodeNumberText = getEpisodePlaybackNumberText(item)
    if episodeNumberText <> "" then parts.Push(episodeNumberText)

    title = FirstNonEmpty([item.Name], "")
    if title <> "" then parts.Push(title)

    dateText = DateTime_ToShortDate(getEpisodeAiredDateText(item))
    if dateText <> "" then parts.Push(dateText)

    runtimeText = MediaMetadata_FormatRuntime(item.RunTimeTicks)
    if runtimeText <> "" then parts.Push(runtimeText)

    return joinPlaybackMetadata(parts)
end function

'-------------------------------------------------------------------------------
' getEpisodePlaybackNumberText
'-------------------------------------------------------------------------------
function getEpisodePlaybackNumberText(item as dynamic) as string
    seasonNumber = FirstNonEmpty([item.ParentIndexNumber, item.SeasonNumber], "")
    episodeNumber = FirstNonEmpty([item.IndexNumber, item.EpisodeNumber], "")

    if seasonNumber <> "" and episodeNumber <> "" then return "S" + seasonNumber + MediaMetadata_BulletSeparator() + "E" + episodeNumber
    if seasonNumber <> "" then return "S" + seasonNumber
    if episodeNumber <> "" then return "E" + episodeNumber
    return ""
end function

'-------------------------------------------------------------------------------
' getEpisodeAiredDateText
'-------------------------------------------------------------------------------
function getEpisodeAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.PremiereDate, item.AirDate, item.DateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

'-------------------------------------------------------------------------------
' joinPlaybackMetadata
'-------------------------------------------------------------------------------
function joinPlaybackMetadata(values as dynamic) as string
    if values = invalid then return ""

    result = ""
    for each value in values
        text = SafeString(value, "")
        if text = "" then continue for

        if result <> "" then result = result + MediaMetadata_BulletSeparator()
        result = result + text
    end for

    return result
end function

'-------------------------------------------------------------------------------
' getRuntimeSeconds
'-------------------------------------------------------------------------------
function getRuntimeSeconds(item as dynamic) as float
    if item = invalid then return 0

    runtimeTicks = 0
    if item.RunTimeTicks <> invalid then runtimeTicks = item.RunTimeTicks
    if runtimeTicks = 0 then return 0

    return runtimeTicks / 10000000
end function

'-------------------------------------------------------------------------------
' showControls
'-------------------------------------------------------------------------------
sub showControls(restartTimer as boolean)
    hideSkipIntroButton()
    hideCast()
    m.overlay.area = "controls"
    m.playbackControls.visible = true
    m.playbackControls.callFunc("resetFocus")
    m.playbackControls.callFunc("activate")
    if restartTimer = true then
        m.controlsHideTimer.control = "stop"
        m.controlsHideTimer.control = "start"
    else
        m.controlsHideTimer.control = "stop"
    end if
end sub

'-------------------------------------------------------------------------------
' showControlsWithProgressFocus
'-------------------------------------------------------------------------------
sub showControlsWithProgressFocus()
    showControls(false)
    m.playbackControls.callFunc("focusProgress")
end sub

'-------------------------------------------------------------------------------
' restartControlsHideTimerIfVisible
'-------------------------------------------------------------------------------
sub restartControlsHideTimerIfVisible()
    if m.playbackControls.visible <> true then return
    if m.playback.isSeeking = true then return

    m.controlsHideTimer.control = "stop"
    m.controlsHideTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' restartCastHideTimerIfVisible
'-------------------------------------------------------------------------------
sub restartCastHideTimerIfVisible()
    if m.overlay.area <> "cast" then return

    m.controlsHideTimer.control = "stop"
    m.controlsHideTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' hideControls
'-------------------------------------------------------------------------------
sub hideControls()
    m.controlsHideTimer.control = "stop"
    stopSeekTimers()
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    m.playbackControls.callFunc("deactivate")
    m.playbackControls.visible = false
    if m.overlay.area = "controls" then m.overlay.area = "none"
    m.top.setFocus(true)
    updateSkipIntroButton(m.playback.position)
end sub

'-------------------------------------------------------------------------------
' clampSeconds
'-------------------------------------------------------------------------------
function clampSeconds(value as float, minimum as float, maximum as float) as float
    if value < minimum then return minimum
    if value > maximum then return maximum

    return value
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    restartControlsHideTimerIfVisible()
    if press = true then restartCastHideTimerIfVisible()

    if press = false then
        if key = "left" then
            stopTenSecondRepeat("left")
            return true
        else if key = "right" then
            stopTenSecondRepeat("right")
            return true
        end if

        return false
    end if

    if m.overlay.area = "cast" then
        if key = "back" then
            hideCast()
            showControls(true)
            return true
        else if key = "up" then
            showControls(true)
            return true
        else if key = "play" then
            togglePlayback()
            return true
        else if key = "down" then
            onCastFocusExitDown()
            return true
        else if key = "left" or key = "right" or key = "OK" then
            return true
        end if
    end if

    if key = "back" then
        if m.skipIntroButton.visible = true then
            dismissCurrentIntroSegment()
            return true
        end if

        if m.playback.isSeeking = true then
            cancelSeek()
            return true
        end if

        if m.overlay.area = "cast" then
            hideCast(true)
            return true
        end if

        if m.playbackControls.visible = true then
            hideControls()
            return true
        end if

        emitPlaybackProgress(false)
        stopPlayback()
        m.top.closeRequested = true
        return true
    else if key = "left" then
        handleProgressSeekInput("left")
        return true
    else if key = "right" then
        handleProgressSeekInput("right")
        return true
    else if key = "rewind" then
        handleProgressSeekInput("rewind")
        return true
    else if key = "fastforward" then
        handleProgressSeekInput("fastforward")
        return true
    else if key = "OK" then
        if m.skipIntroButton.visible = true then
            onSkipIntroSelected()
        else if m.playback.isSeeking = true then
            commitSeek()
        else if m.playbackControls.visible = true then
            hideControls()
        else
            showControls(true)
        end if
        return true
    else if key = "play" then
        if m.playback.isSeeking = true then
            commitSeek()
        else
            togglePlayback()
        end if
        return true
    else if key = "up" then
        if m.overlay.area = "cast" then
            showControls(true)
        else
            showControls(true)
        end if
        return true
    else if key = "down" then
        if m.overlay.area <> "cast" then
            showControls(true)
        end if
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' beginSeek
'-------------------------------------------------------------------------------
sub beginSeek(direction as integer)
    if direction < 0 then
        handleProgressSeekInput("left")
    else
        handleProgressSeekInput("right")
    end if
end sub

'-------------------------------------------------------------------------------
' adjustSeek
'-------------------------------------------------------------------------------
sub adjustSeek(direction as integer)
    if direction < 0 then
        handleProgressSeekInput("left")
    else
        handleProgressSeekInput("right")
    end if
end sub

'-------------------------------------------------------------------------------
' startSeekPreview
'-------------------------------------------------------------------------------
sub startSeekPreview()
    if m.playback.duration <= 0 then return
    if m.playback.isSeeking = true then return

    m.playback.isSeeking = true
    m.playback.previewPosition = getCurrentPlaybackPosition()
    m.videoPlayer.control = "pause"
    m.playbackControls.isSeeking = true
    m.playbackControls.previewPosition = m.playback.previewPosition
    showControlsWithProgressFocus()
end sub

'-------------------------------------------------------------------------------
' handleProgressSeekInput
'-------------------------------------------------------------------------------
sub handleProgressSeekInput(key as string)
    if m.playback.duration <= 0 then return

    if m.playback.isSeeking <> true then startSeekPreview()
    if m.playback.isSeeking <> true then return

    if key = "left" then
        startTenSecondRepeat("left")
        applySeekDelta(-10)
    else if key = "right" then
        startTenSecondRepeat("right")
        applySeekDelta(10)
    else if key = "rewind" then
        processAcceleratedSeek("left")
    else if key = "fastforward" then
        processAcceleratedSeek("right")
    end if
end sub

'-------------------------------------------------------------------------------
' startTenSecondRepeat
'-------------------------------------------------------------------------------
sub startTenSecondRepeat(direction as string)
    m.fastSeekTimer.control = "stop"
    m.leftSeekRepeatTimer.control = "stop"
    m.rightSeekRepeatTimer.control = "stop"
    m.leftSeekRepeatTimer.duration = 0.5
    m.rightSeekRepeatTimer.duration = 0.5

    if direction = "left" then
        m.seek.speedIndex = 3
        m.leftSeekRepeatTimer.control = "start"
    else
        m.seek.speedIndex = 4
        m.rightSeekRepeatTimer.control = "start"
    end if

    m.seek.direction = direction
    m.seek.isAccelerating = false
end sub

'-------------------------------------------------------------------------------
' processAcceleratedSeek
'-------------------------------------------------------------------------------
sub processAcceleratedSeek(direction as string)
    stopTenSecondRepeatTimers()

    if m.seek.isAccelerating = true and m.seek.direction <> "" and m.seek.direction <> direction then
        m.fastSeekTimer.control = "stop"
        m.seek.direction = ""
        m.seek.speedIndex = -1
        m.seek.isAccelerating = false
        return
    end if

    if direction = "left" then
        if m.seek.direction <> "left" or m.seek.speedIndex < 0 or m.seek.speedIndex > 3 then
            m.seek.speedIndex = 3
        else if m.seek.speedIndex > 0 then
            m.seek.speedIndex = m.seek.speedIndex - 1
        end if
    else
        if m.seek.direction <> "right" or m.seek.speedIndex < 4 then
            m.seek.speedIndex = 4
        else if m.seek.speedIndex < m.seek.speeds.Count() - 1 then
            m.seek.speedIndex = m.seek.speedIndex + 1
        end if
    end if

    m.seek.direction = direction
    m.seek.isAccelerating = true
    m.fastSeekTimer.control = "start"
    applySeekDelta(m.seek.speeds[m.seek.speedIndex])
end sub

'-------------------------------------------------------------------------------
' applySeekDelta
'-------------------------------------------------------------------------------
sub applySeekDelta(deltaSeconds as integer)
    if m.playback.duration <= 0 then return

    m.playback.previewPosition = VideoPlayerMetadata_ClampSeconds(m.playback.previewPosition + deltaSeconds, 0, m.playback.duration)
    m.playbackControls.previewPosition = m.playback.previewPosition
    updateTrickplayPreview(m.playback.previewPosition)
end sub

'-------------------------------------------------------------------------------
' onFastSeekTimerFire
'-------------------------------------------------------------------------------
sub onFastSeekTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if
    if m.seek.speedIndex < 0 then return

    applySeekDelta(m.seek.speeds[m.seek.speedIndex])
end sub

'-------------------------------------------------------------------------------
' onLeftSeekRepeatTimerFire
'-------------------------------------------------------------------------------
sub onLeftSeekRepeatTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if

    m.leftSeekRepeatTimer.duration = 0.125
    applySeekDelta(-10)
end sub

'-------------------------------------------------------------------------------
' onRightSeekRepeatTimerFire
'-------------------------------------------------------------------------------
sub onRightSeekRepeatTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if

    m.rightSeekRepeatTimer.duration = 0.125
    applySeekDelta(10)
end sub

'-------------------------------------------------------------------------------
' stopTenSecondRepeatTimers
'-------------------------------------------------------------------------------
sub stopTenSecondRepeatTimers()
    m.leftSeekRepeatTimer.control = "stop"
    m.rightSeekRepeatTimer.control = "stop"
    m.leftSeekRepeatTimer.duration = 0.5
    m.rightSeekRepeatTimer.duration = 0.5
end sub

'-------------------------------------------------------------------------------
' stopTenSecondRepeat
'-------------------------------------------------------------------------------
sub stopTenSecondRepeat(direction as string)
    if direction = "left" then
        m.leftSeekRepeatTimer.control = "stop"
        m.leftSeekRepeatTimer.duration = 0.5
    else if direction = "right" then
        m.rightSeekRepeatTimer.control = "stop"
        m.rightSeekRepeatTimer.duration = 0.5
    end if

    if m.seek.isAccelerating <> true then
        m.seek.direction = ""
        m.seek.speedIndex = -1
    end if
end sub

'-------------------------------------------------------------------------------
' stopSeekTimers
'-------------------------------------------------------------------------------
sub stopSeekTimers()
    m.fastSeekTimer.control = "stop"
    stopTenSecondRepeatTimers()
    resetSeekState()
end sub

'-------------------------------------------------------------------------------
' resetSeekState
'-------------------------------------------------------------------------------
sub resetSeekState()
    m.seek.speedIndex = -1
    m.seek.direction = ""
    m.seek.isAccelerating = false
end sub

'-------------------------------------------------------------------------------
' commitSeek
'-------------------------------------------------------------------------------
sub commitSeek()
    if m.playback.isSeeking <> true then return

    stopSeekTimers()
    logPlaybackSeekRequest("progressSeekCommit", m.playback.previewPosition)
    m.videoPlayer.seek = m.playback.previewPosition
    m.videoPlayer.control = "resume"
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    showControlsWithProgressFocus()
end sub

'-------------------------------------------------------------------------------
' cancelSeek
'-------------------------------------------------------------------------------
sub cancelSeek(hideAfterCancel = false as boolean)
    if m.playback.isSeeking <> true then return

    stopSeekTimers()
    m.videoPlayer.control = "resume"
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    if hideAfterCancel = true then
        hideControls()
    else
        showControls(true)
    end if
end sub

'-------------------------------------------------------------------------------
' togglePlayback
'-------------------------------------------------------------------------------
sub togglePlayback()
    if m.playback.isPlaying = true then
        m.videoPlayer.control = "pause"
        m.playback.isPlaying = false
    else
        m.videoPlayer.control = "resume"
        m.playback.isPlaying = true
    end if

    m.playbackControls.isPlaying = m.playback.isPlaying
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' onPlayPausePressed
'-------------------------------------------------------------------------------
sub onPlayPausePressed()
    if m.playback.isSeeking = true then
        commitSeek()
    else
        togglePlayback()
    end if
end sub

'-------------------------------------------------------------------------------
' onLast5Pressed
'-------------------------------------------------------------------------------
sub onLast5Pressed()
    seekToLast5Seconds()
end sub

'-------------------------------------------------------------------------------
' seekToLast5Seconds
'-------------------------------------------------------------------------------
sub seekToLast5Seconds()
    duration = m.playback.duration
    if duration = invalid or duration <= 0 then duration = m.videoPlayer.duration
    if duration = invalid or duration <= 0 then return

    targetPosition = duration - 5
    if targetPosition < 0 then targetPosition = 0

    stopSeekTimers()
    m.playback.isSeeking = false
    logPlaybackSeekRequest("seekToLast5Seconds", targetPosition)
    m.videoPlayer.seek = targetPosition
    m.playback.position = targetPosition
    m.playback.previewPosition = targetPosition
    if m.playback.isPlaying = true then
        m.videoPlayer.control = "resume"
    else
        m.videoPlayer.control = "pause"
    end if

    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    m.playbackControls.position = targetPosition
    m.playbackControls.previewPosition = targetPosition
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' onProgressLeftPressed
'-------------------------------------------------------------------------------
sub onProgressLeftPressed()
    handleProgressSeekInput("left")
end sub

'-------------------------------------------------------------------------------
' onProgressRightPressed
'-------------------------------------------------------------------------------
sub onProgressRightPressed()
    handleProgressSeekInput("right")
end sub

'-------------------------------------------------------------------------------
' onProgressLeftReleased
'-------------------------------------------------------------------------------
sub onProgressLeftReleased()
    stopTenSecondRepeat("left")
end sub

'-------------------------------------------------------------------------------
' onProgressRightReleased
'-------------------------------------------------------------------------------
sub onProgressRightReleased()
    stopTenSecondRepeat("right")
end sub

'-------------------------------------------------------------------------------
' onProgressRewindPressed
'-------------------------------------------------------------------------------
sub onProgressRewindPressed()
    handleProgressSeekInput("rewind")
end sub

'-------------------------------------------------------------------------------
' onProgressFastForwardPressed
'-------------------------------------------------------------------------------
sub onProgressFastForwardPressed()
    handleProgressSeekInput("fastforward")
end sub

'-------------------------------------------------------------------------------
' onProgressSeekCommit
'-------------------------------------------------------------------------------
sub onProgressSeekCommit()
    commitSeek()
end sub

'-------------------------------------------------------------------------------
' onProgressSeekCancel
'-------------------------------------------------------------------------------
sub onProgressSeekCancel()
    cancelSeek(true)
end sub

'-------------------------------------------------------------------------------
' skipPlayback
'-------------------------------------------------------------------------------
sub skipPlayback(offsetSeconds as integer)
    if m.playback.duration <= 0 then return

    stopSeekTimers()
    targetPosition = VideoPlayerMetadata_ClampSeconds(m.videoPlayer.position + offsetSeconds, 0, m.playback.duration)
    logPlaybackSeekRequest("skipPlayback:" + SafeString(offsetSeconds, ""), targetPosition)
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
    showControls(true)
end sub

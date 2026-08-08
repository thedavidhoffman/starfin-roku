'-------------------------------------------------------------------------------
' initPlaybackRecovery
'-------------------------------------------------------------------------------
sub initPlaybackRecovery()
    m.recovery = {
        itemId: ""
        originalMode: "automatic"
        effectiveMode: "automatic"
        internalRestartPending: false
        restartInProgress: false
        sameModeRetryUsed: false
        hasEverPlayed: false
        isStable: false
        lastSafePosition: 0
        bufferLastPercent: -1
        bufferLastPosition: 0
        bufferStalledSeconds: 0
        bufferAtHundredSeconds: 0
        bufferMonitoring: false
    }
end sub

'-------------------------------------------------------------------------------
' beginPlaybackRecoveryRequest
'-------------------------------------------------------------------------------
function beginPlaybackRecoveryRequest(request as object) as boolean
    isRecoveryRestart = m.recovery.internalRestartPending = true
    m.recovery.internalRestartPending = false
    stopPlaybackRecoveryTimers()

    if isRecoveryRestart then
        m.recovery.effectiveMode = getRecoveryRequestMode(request)
        return true
    end if

    resetPlaybackRecovery(request)
    return false
end function

'-------------------------------------------------------------------------------
' resetPlaybackRecovery
'-------------------------------------------------------------------------------
sub resetPlaybackRecovery(request = invalid as dynamic)
    stopPlaybackRecoveryTimers()
    mode = "automatic"
    itemId = ""
    startPosition = 0
    if request <> invalid then
        mode = getRecoveryRequestMode(request)
        itemId = SafeString(request.itemId, "")
        startPosition = PlaybackProgress_TicksToSeconds(request.startPositionTicks)
    end if

    m.recovery.itemId = itemId
    m.recovery.originalMode = mode
    m.recovery.effectiveMode = mode
    m.recovery.internalRestartPending = false
    m.recovery.restartInProgress = false
    m.recovery.sameModeRetryUsed = false
    m.recovery.hasEverPlayed = false
    m.recovery.isStable = false
    m.recovery.lastSafePosition = startPosition
    resetPlaybackRecoveryBufferState()
end sub

'-------------------------------------------------------------------------------
' getRecoveryRequestMode
'-------------------------------------------------------------------------------
function getRecoveryRequestMode(request as dynamic) as string
    if request = invalid then return "automatic"
    mode = SafeString(request.videoMode, "automatic")
    if mode = "directPlay" or mode = "transcodeAllowRemux" or mode = "transcodeNoRemux" then return mode
    return "automatic"
end function

'-------------------------------------------------------------------------------
' getOriginalPlaybackMode
'-------------------------------------------------------------------------------
function getOriginalPlaybackMode() as string
    if m.recovery = invalid then return "automatic"
    return SafeString(m.recovery.originalMode, "automatic")
end function

'-------------------------------------------------------------------------------
' recordPlaybackRecoveryPosition
'-------------------------------------------------------------------------------
sub recordPlaybackRecoveryPosition(position as dynamic)
    if position = invalid then return
    state = LCase(SafeString(m.videoPlayer.state, ""))
    if state <> "playing" and state <> "paused" then return

    value = Number_ToFloat(position, 0)
    if value >= 0 then m.recovery.lastSafePosition = value
end sub

'-------------------------------------------------------------------------------
' onPlaybackRecoveryStateChanged
'-------------------------------------------------------------------------------
sub onPlaybackRecoveryStateChanged(state as string)
    if state = "buffering" then
        m.recovery.restartInProgress = false
        m.recovery.isStable = false
        m.recoveryStableTimer.control = "stop"
        startPlaybackRecoveryBufferMonitor()
        return
    end if

    stopPlaybackRecoveryBufferMonitor()
    if state = "playing" then
        m.recovery.restartInProgress = false
        m.recovery.hasEverPlayed = true
        m.recovery.isStable = false
        m.recoveryStableTimer.control = "stop"
        m.recoveryStableTimer.control = "start"
    else if state = "paused" then
        m.recoveryStableTimer.control = "stop"
    else if state = "finished" then
        m.recoveryStableTimer.control = "stop"
    end if
end sub

'-------------------------------------------------------------------------------
' startPlaybackRecoveryBufferMonitor
'-------------------------------------------------------------------------------
sub startPlaybackRecoveryBufferMonitor()
    if m.recovery.bufferMonitoring then return
    resetPlaybackRecoveryBufferState()
    m.recovery.bufferMonitoring = true
    m.recovery.bufferLastPercent = getPlaybackBufferPercent()
    m.recovery.bufferLastPosition = Number_ToFloat(m.videoPlayer.position, 0)
    m.recoveryBufferTimer.control = "stop"
    m.recoveryBufferTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' stopPlaybackRecoveryBufferMonitor
'-------------------------------------------------------------------------------
sub stopPlaybackRecoveryBufferMonitor()
    m.recoveryBufferTimer.control = "stop"
    m.recovery.bufferMonitoring = false
    resetPlaybackRecoveryBufferState()
end sub

'-------------------------------------------------------------------------------
' resetPlaybackRecoveryBufferState
'-------------------------------------------------------------------------------
sub resetPlaybackRecoveryBufferState()
    m.recovery.bufferLastPercent = -1
    m.recovery.bufferLastPosition = 0
    m.recovery.bufferStalledSeconds = 0
    m.recovery.bufferAtHundredSeconds = 0
end sub

'-------------------------------------------------------------------------------
' onPlaybackRecoveryBufferTimerFire
'-------------------------------------------------------------------------------
sub onPlaybackRecoveryBufferTimerFire()
    if LCase(SafeString(m.videoPlayer.state, "")) <> "buffering" then
        stopPlaybackRecoveryBufferMonitor()
        return
    end if

    percent = getPlaybackBufferPercent()
    position = Number_ToFloat(m.videoPlayer.position, 0)
    madeProgress = position > m.recovery.bufferLastPosition
    if percent >= 0 and percent > m.recovery.bufferLastPercent then madeProgress = true

    if madeProgress then
        m.recovery.bufferStalledSeconds = 0
    else
        m.recovery.bufferStalledSeconds = m.recovery.bufferStalledSeconds + 5
    end if

    if percent = 100 and madeProgress <> true then
        m.recovery.bufferAtHundredSeconds = m.recovery.bufferAtHundredSeconds + 5
    else
        m.recovery.bufferAtHundredSeconds = 0
    end if

    m.recovery.bufferLastPercent = percent
    m.recovery.bufferLastPosition = position
    if m.recovery.bufferAtHundredSeconds >= 10 then
        stopPlaybackRecoveryBufferMonitor()
        if handlePlaybackRecoveryFailure("bufferingStuckAt100", "Playback remained buffered at 100 percent.") <> true then
            finalizePlaybackRecoveryFailure("Unable to continue playback after recovery attempts.")
        end if
    else if m.recovery.bufferStalledSeconds >= 30 then
        stopPlaybackRecoveryBufferMonitor()
        if handlePlaybackRecoveryFailure("bufferingStalled", "Playback buffering stopped making progress.") <> true then
            finalizePlaybackRecoveryFailure("Unable to continue playback after recovery attempts.")
        end if
    end if
end sub

'-------------------------------------------------------------------------------
' getPlaybackBufferPercent
'-------------------------------------------------------------------------------
function getPlaybackBufferPercent() as integer
    status = m.videoPlayer.bufferingStatus
    if status = invalid or status.percentage = invalid then return -1
    return Number_ToInteger(status.percentage, -1)
end function

'-------------------------------------------------------------------------------
' onPlaybackRecoveryStableTimerFire
'-------------------------------------------------------------------------------
sub onPlaybackRecoveryStableTimerFire()
    if LCase(SafeString(m.videoPlayer.state, "")) <> "playing" then return
    m.recovery.isStable = true
    m.recovery.sameModeRetryUsed = false
    m.log.write("Playback recovery stabilized itemId=" + m.recovery.itemId + " effectiveMode=" + m.recovery.effectiveMode)
#if playbackChaosMonkey
    onPlaybackChaosMonkeyRecoveryStabilized()
#endif
end sub

'-------------------------------------------------------------------------------
' handlePlaybackRecoveryFailure
'-------------------------------------------------------------------------------
function handlePlaybackRecoveryFailure(reason as string, detail as string) as boolean
    request = m.top.playRequest
    if request = invalid or SafeString(request.itemId, "") = "" then return false

    nextMode = ""
    attemptKind = ""
    if m.recovery.sameModeRetryUsed <> true then
        nextMode = m.recovery.effectiveMode
        attemptKind = "sameMode"
        m.recovery.sameModeRetryUsed = true
    else if m.recovery.originalMode = "automatic" then
        if m.recovery.effectiveMode = "automatic" or m.recovery.effectiveMode = "directPlay" then
            nextMode = "transcodeAllowRemux"
            attemptKind = "allowRemux"
        else if m.recovery.effectiveMode = "transcodeAllowRemux" then
            nextMode = "transcodeNoRemux"
            attemptKind = "fullTranscode"
        end if
    end if

    if nextMode = "" then
        m.log.error("Playback recovery exhausted itemId=" + m.recovery.itemId + " reason=" + reason + " detail=" + detail + " effectiveMode=" + m.recovery.effectiveMode)
#if playbackChaosMonkey
        onPlaybackChaosMonkeyRecoveryExhausted(reason)
#endif
        return false
    end if

    failurePhase = "startup"
    if m.recovery.hasEverPlayed then failurePhase = "runtime"
    m.log.write("Playback recovery attempt itemId=" + m.recovery.itemId + " phase=" + failurePhase + " reason=" + reason + " detail=" + detail + " attempt=" + attemptKind + " fromMode=" + m.recovery.effectiveMode + " toMode=" + nextMode + " position=" + SafeString(m.recovery.lastSafePosition, ""))
    restartRequest = buildStreamRestartPlayRequest()
    if restartRequest = invalid then return false

    restartRequest.startPositionTicks = secondsToTicks(m.recovery.lastSafePosition)
    restartRequest.videoMode = nextMode
    m.recovery.effectiveMode = nextMode
    m.recovery.isStable = false
    m.recovery.internalRestartPending = true
    m.recovery.restartInProgress = true
#if playbackChaosMonkey
    onPlaybackChaosMonkeyRecoveryStarted(reason)
#endif
    stopPlaybackRecoveryTimers()
    Spinner_Show(0)
    m.top.playRequest = restartRequest
    return true
end function

'-------------------------------------------------------------------------------
' finalizePlaybackRecoveryFailure
'-------------------------------------------------------------------------------
sub finalizePlaybackRecoveryFailure(message as string)
#if playbackChaosMonkey
    stopPlaybackChaosMonkeyTimer()
#endif
    stopPlaybackRecoveryTimers()
    stopPlayback()
    enableScreenSaver()
    Status_SetMessage(message)
end sub

'-------------------------------------------------------------------------------
' stopPlaybackRecoveryTimers
'-------------------------------------------------------------------------------
sub stopPlaybackRecoveryTimers()
    m.recoveryBufferTimer.control = "stop"
    m.recoveryStableTimer.control = "stop"
    if m.recovery <> invalid then m.recovery.bufferMonitoring = false
end sub

'-------------------------------------------------------------------------------
' isPlaybackRecoveryRestarting
'-------------------------------------------------------------------------------
function isPlaybackRecoveryRestarting() as boolean
    return m.recovery <> invalid and m.recovery.restartInProgress = true
end function

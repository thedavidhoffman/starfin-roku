'-------------------------------------------------------------------------------
' initPlaybackDiagnostics
'-------------------------------------------------------------------------------
sub initPlaybackDiagnostics()
    m.playbackDiagnostics = {
        lastObservedPosition: -1
        lastState: ""
        expectedPosition: -1
        expectedReason: ""
    }
end sub

'-------------------------------------------------------------------------------
' logPlaybackRequest
'-------------------------------------------------------------------------------
sub logPlaybackRequest(request as dynamic, isRecoveryRestart as boolean)
    if request = invalid then return

    m.log.write("Playback request itemId=" + SafeString(request.itemId, "") + " mode=" + SafeString(request.videoMode, PlaybackMode_Values().automatic) + " startPosition=" + SafeString(PlaybackProgress_TicksToSeconds(request.startPositionTicks), "") + " recoveryRestart=" + playbackDiagnosticBool(isRecoveryRestart) + " currentPosition=" + SafeString(getCurrentPlaybackPosition(), "") + " state=" + LCase(SafeString(m.videoPlayer.state, "")))
end sub

'-------------------------------------------------------------------------------
' logPlaybackContentAssignment
'-------------------------------------------------------------------------------
sub logPlaybackContentAssignment(response as dynamic, startPosition as dynamic)
    m.playbackDiagnostics.lastObservedPosition = Number_ToFloat(startPosition, 0)
    m.playbackDiagnostics.expectedPosition = Number_ToFloat(startPosition, 0)
    m.playbackDiagnostics.expectedReason = "contentAssignment"

    m.log.write("Playback content assignment itemId=" + m.session.itemId + " playSessionId=" + m.session.playSessionId + " method=" + SafeString(response.playbackIdentity.playMethod, "") + " format=" + SafeString(response.streamFormat, "") + " startPosition=" + SafeString(startPosition, ""))
end sub

'-------------------------------------------------------------------------------
' logPlaybackSeekRequest
'-------------------------------------------------------------------------------
sub logPlaybackSeekRequest(reason as string, targetPosition as dynamic)
    sourcePosition = getCurrentPlaybackPosition()
    target = Number_ToFloat(targetPosition, 0)
    m.playbackDiagnostics.expectedPosition = target
    m.playbackDiagnostics.expectedReason = reason

    m.log.write("Playback seek requested reason=" + reason + " from=" + SafeString(sourcePosition, "") + " to=" + SafeString(target, "") + " delta=" + SafeString(target - sourcePosition, "") + " state=" + LCase(SafeString(m.videoPlayer.state, "")) + " itemId=" + m.session.itemId + " playSessionId=" + m.session.playSessionId)
end sub

'-------------------------------------------------------------------------------
' diagnosePlaybackPosition
'-------------------------------------------------------------------------------
sub diagnosePlaybackPosition(position as float)
    previousPosition = m.playbackDiagnostics.lastObservedPosition
    if previousPosition >= 0 and position < previousPosition - 2 then
        expected = isExpectedPlaybackPosition(position)
        severity = "UNEXPECTED"
        if expected then severity = "expected"

        m.log.write("Playback position moved backward classification=" + severity + " from=" + SafeString(previousPosition, "") + " to=" + SafeString(position, "") + " delta=" + SafeString(position - previousPosition, "") + " expectedReason=" + m.playbackDiagnostics.expectedReason + " expectedPosition=" + SafeString(m.playbackDiagnostics.expectedPosition, "") + " state=" + LCase(SafeString(m.videoPlayer.state, "")) + " bufferPercent=" + SafeString(getPlaybackBufferPercent(), "") + " itemId=" + m.session.itemId + " playSessionId=" + m.session.playSessionId)
    end if

    if isExpectedPlaybackPosition(position) then
        m.playbackDiagnostics.expectedPosition = -1
        m.playbackDiagnostics.expectedReason = ""
    end if
    m.playbackDiagnostics.lastObservedPosition = position
end sub

'-------------------------------------------------------------------------------
' diagnosePlaybackState
'-------------------------------------------------------------------------------
sub diagnosePlaybackState(state as string)
    previousState = m.playbackDiagnostics.lastState
    m.log.write("Playback state transition from=" + previousState + " to=" + state + " position=" + SafeString(m.videoPlayer.position, "") + " observedPosition=" + SafeString(m.playbackDiagnostics.lastObservedPosition, "") + " expectedReason=" + m.playbackDiagnostics.expectedReason + " expectedPosition=" + SafeString(m.playbackDiagnostics.expectedPosition, "") + " bufferPercent=" + SafeString(getPlaybackBufferPercent(), "") + " itemId=" + m.session.itemId + " playSessionId=" + m.session.playSessionId)
    m.playbackDiagnostics.lastState = state
end sub

'-------------------------------------------------------------------------------
' isExpectedPlaybackPosition
'-------------------------------------------------------------------------------
function isExpectedPlaybackPosition(position as float) as boolean
    expectedPosition = m.playbackDiagnostics.expectedPosition
    if expectedPosition < 0 then return false
    return Abs(position - expectedPosition) <= 5
end function

'-------------------------------------------------------------------------------
' playbackDiagnosticBool
'-------------------------------------------------------------------------------
function playbackDiagnosticBool(value as boolean) as string
    if value then return "true"
    return "false"
end function

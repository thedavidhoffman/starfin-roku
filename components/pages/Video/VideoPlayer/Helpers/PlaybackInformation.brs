'-------------------------------------------------------------------------------
' onPlaybackInfoPressed
'-------------------------------------------------------------------------------
sub onPlaybackInfoPressed()
    if m.session = invalid or m.session.playbackIdentity = invalid then return

    state = LCase(SafeString(m.videoPlayer.state, ""))
    m.overlay.resumeAfterPlaybackInformation = state = "playing" or state = "buffering"
    if m.overlay.resumeAfterPlaybackInformation = true then m.videoPlayer.control = "pause"

    m.controlsHideTimer.control = "stop"
    m.top.overlayRequested = {
        id: "playbackInfo"
        sourcePage: "videoPlayer"
        componentName: "PlaybackInfoDialog"
        openFunction: "openPlaybackInfo"
        closeField: "closeRequested"
        playbackInfo: buildPlaybackInformation()
    }
end sub

'-------------------------------------------------------------------------------
' buildPlaybackInformation
'-------------------------------------------------------------------------------
function buildPlaybackInformation() as object
    identity = m.session.playbackIdentity

    return {
        title: identity.title
        state: LCase(SafeString(m.videoPlayer.state, ""))
        position: getCurrentPlaybackPosition()
        duration: m.playback.duration
        isPaused: LCase(SafeString(m.videoPlayer.state, "")) = "paused"
        isSeeking: m.playback.isSeeking
        canSeek: m.playback.duration > 0
        itemId: identity.itemId
        playSessionId: identity.playSessionId
        mediaSourceId: identity.mediaSourceId
        liveStreamId: identity.liveStreamId
        playbackMode: identity.playbackMode
        playMethod: identity.playMethod
        transcodeReason: identity.transcodeReason
        streamFormat: identity.streamFormat
        container: identity.container
        videoStreamIndex: identity.videoStreamIndex
        audioStreamIndex: identity.audioStreamIndex
        subtitleStreamIndex: identity.subtitleStreamIndex
        videoStreamTitle: identity.videoStreamTitle
        audioStreamTitle: identity.audioStreamTitle
        subtitleStreamTitle: identity.subtitleStreamTitle
        videoCodec: identity.videoCodec
        audioCodec: identity.audioCodec
        width: identity.width
        height: identity.height
        videoBitrate: identity.videoBitrate
        audioBitrate: identity.audioBitrate
        audioChannels: identity.audioChannels
    }
end function

'-------------------------------------------------------------------------------
' handlePlaybackInfoOverlayClosed
'-------------------------------------------------------------------------------
sub handlePlaybackInfoOverlayClosed()
    if m.overlay.resumeAfterPlaybackInformation = true then m.videoPlayer.control = "resume"
    m.overlay.resumeAfterPlaybackInformation = false

    if m.overlay.area = "controls" then
        m.playbackControls.callFunc("activate")
        m.playbackControls.callFunc("focusButtons")
        m.controlsHideTimer.control = "start"
        return
    end if

    m.top.setFocus(true)
end sub

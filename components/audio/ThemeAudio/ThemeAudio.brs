'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("ThemeAudio")
    m.audio = m.top.findNode("audio")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")
    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.audio.observeField("state", "onAudioStateChanged")
    m.themeAudioState = {
        request: invalid
        isActive: false
    }
end sub

'-------------------------------------------------------------------------------
' playTheme
'-------------------------------------------------------------------------------
sub playTheme(request as object)
    if request = invalid then return
    if SafeString(request.itemId, "") = "" then return

    stopTheme()
    m.themeAudioState.request = request
    m.log.write("Resolving theme music playback itemId=" + SafeString(request.itemId, ""))
    m.playbackInfoTask.request = request
    m.playbackInfoTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' stopTheme
'-------------------------------------------------------------------------------
sub stopTheme()
    m.themeAudioState.isActive = false
    m.themeAudioState.request = invalid
    m.playbackInfoTask.control = "stop"
    m.audio.control = "stop"
    m.audio.content = invalid
end sub

'-------------------------------------------------------------------------------
' onPlaybackInfoResponse
'-------------------------------------------------------------------------------
sub onPlaybackInfoResponse()
    response = m.playbackInfoTask.response
    if response = invalid then return

    if response.ok <> true then
        m.log.write("Unable to play theme music: " + SafeString(response.errorMessage, "Unknown error."))
        return
    end if

    if m.themeAudioState.request = invalid then return
    if SafeString(response.itemId, "") <> SafeString(m.themeAudioState.request.itemId, "") then return

    content = CreateObject("roSGNode", "ContentNode")
    content.url = SafeString(response.streamUrl, "")
    content.streamFormat = SafeString(response.streamFormat, "")
    content.title = SafeString(response.title, "Theme Music")
    if content.url = "" then return

    m.themeAudioState.isActive = true
    m.audio.content = content
    m.audio.control = "play"
    m.log.write("Playing theme music itemId=" + SafeString(response.itemId, "") + " streamFormat=" + content.streamFormat)
end sub

'-------------------------------------------------------------------------------
' onAudioStateChanged
'-------------------------------------------------------------------------------
sub onAudioStateChanged()
    state = SafeString(m.audio.state, "")
    m.log.write("Theme music audio state changed state=" + state)
    if state = "finished" and m.themeAudioState.isActive = true then
        stopTheme()
    else if state = "error" then
        m.log.write("Theme music playback error")
        stopTheme()
    end if
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("PlayerPage")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.statusLabel = m.top.findNode("statusLabel")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")

    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
end sub

'-------------------------------------------------------------------------------
' onPlayRequestChanged
'-------------------------------------------------------------------------------
sub onPlayRequestChanged()
    request = m.top.playRequest
    if request = invalid then return

    m.statusLabel.text = "Loading video..."
    m.statusLabel.visible = true
    m.videoPlayer.control = "stop"
    m.playbackInfoTask.request = request
    m.playbackInfoTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onPlaybackInfoResponse
'-------------------------------------------------------------------------------
sub onPlaybackInfoResponse()
    response = m.playbackInfoTask.response
    if response = invalid then return

    if response.ok <> true then
        m.statusLabel.text = SafeString(response.errorMessage, "Unable to play this item.")
        m.statusLabel.visible = true
        return
    end if

    item = response.item
    content = CreateObject("roSGNode", "ContentNode")
    content.url = response.streamUrl
    content.streamFormat = response.streamFormat
    content.title = getItemTitle(item)
    content.AddHeader("Authorization", JellyfinAuth_BuildPlaybackHeader(m.top.playRequest.token, m.top.playRequest.userId))

    m.videoPlayer.content = content
    m.videoPlayer.setFocus(true)
    m.videoPlayer.control = "play"
    m.statusLabel.visible = false
end sub

'-------------------------------------------------------------------------------
' onVideoStateChanged
'-------------------------------------------------------------------------------
sub onVideoStateChanged()
    state = LCase(SafeString(m.videoPlayer.state, ""))
    if state = "error" then
        m.statusLabel.text = "Unable to play this video."
        m.statusLabel.visible = true
    else if state = "finished" then
        m.top.closeRequested = true
    end if
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if item = invalid then return "Video"
    return FirstNonEmpty([item.Name, item.name, item.title], "Video")
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        m.videoPlayer.control = "stop"
        m.top.closeRequested = true
        return true
    end if

    return false
end function

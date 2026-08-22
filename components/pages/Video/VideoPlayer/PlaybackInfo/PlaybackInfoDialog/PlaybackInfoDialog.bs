'-------------------------------------------------------------------------------
' openPlaybackInfo
'-------------------------------------------------------------------------------
sub openPlaybackInfo()
    m.top.title = "Playback Information"
    m.top.dialogWidth = 1152
    m.top.dialogHeight = 1000
    m.top.contentComponentName = "PlaybackInfoContent"

    content = m.top.callFunc("getContentComponent")
    content.playbackInfo = m.top.playbackInfo
    m.top.callFunc("openDialog")
    content.callFunc("focusInformation")
end sub

'-------------------------------------------------------------------------------
' openOptions
'-------------------------------------------------------------------------------
sub openOptions()
    configureDialog()
    syncContent()
    m.top.visible = true
    m.top.callFunc("openDialog")
    focusContent()
end sub

'-------------------------------------------------------------------------------
' configureDialog
'-------------------------------------------------------------------------------
sub configureDialog()
    rows = getVisibleRowCount()
    panelHeight = 208 + (rows * 52)
    panelY = int((1080 - panelHeight) / 2)

    m.top.title = "Audio"
    m.top.dialogWidth = 720
    m.top.dialogHeight = panelHeight
    m.top.panelX = 600
    m.top.panelY = panelY
    m.top.contentComponentName = "AudioOptionsContent"
end sub

'-------------------------------------------------------------------------------
' getVisibleRowCount
'-------------------------------------------------------------------------------
function getVisibleRowCount() as integer
    rows = 1
    if hasAudioStreams() then rows = m.top.audioStreams.Count()
    if rows > 8 then rows = 8

    return rows
end function

'-------------------------------------------------------------------------------
' hasAudioStreams
'-------------------------------------------------------------------------------
function hasAudioStreams() as boolean
    return m.top.audioStreams <> invalid and m.top.audioStreams.Count() > 0
end function

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getOptionsContent()
    if content = invalid then return

    content.audioStreams = m.top.audioStreams
    content.selectedAudioStreamIndex = m.top.selectedAudioStreamIndex
    content.visibleRowCount = getVisibleRowCount()
end sub

'-------------------------------------------------------------------------------
' getOptionsContent
'-------------------------------------------------------------------------------
function getOptionsContent() as dynamic
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' focusContent
'-------------------------------------------------------------------------------
sub focusContent()
    content = getOptionsContent()
    if content <> invalid then content.callFunc("focusOptions")
end sub

'-------------------------------------------------------------------------------
' onAudioStreamsChanged
'-------------------------------------------------------------------------------
sub onAudioStreamsChanged()
    configureDialog()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onSelectedAudioStreamIndexChanged
'-------------------------------------------------------------------------------
sub onSelectedAudioStreamIndexChanged()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    content = getOptionsContent()
    if content = invalid then return

    selection = content.callFunc("getSelectedAudio")
    if selection <> invalid then m.top.selectedAudio = selection
end sub

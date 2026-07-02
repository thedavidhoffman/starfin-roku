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

    m.top.title = "Subtitles"
    m.top.dialogWidth = 720
    m.top.dialogHeight = panelHeight
    m.top.panelX = 600
    m.top.panelY = panelY
    m.top.contentComponentName = "SubtitleOptionsContent"
end sub

'-------------------------------------------------------------------------------
' getVisibleRowCount
'-------------------------------------------------------------------------------
function getVisibleRowCount() as integer
    rows = 1
    if hasSubtitleStreams() then rows = m.top.subtitleStreams.Count() + 1
    if rows > 8 then rows = 8

    return rows
end function

'-------------------------------------------------------------------------------
' hasSubtitleStreams
'-------------------------------------------------------------------------------
function hasSubtitleStreams() as boolean
    return m.top.subtitleStreams <> invalid and m.top.subtitleStreams.Count() > 0
end function

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getOptionsContent()
    if content = invalid then return

    content.subtitleStreams = m.top.subtitleStreams
    content.selectedSubtitleStreamIndex = m.top.selectedSubtitleStreamIndex
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
' onSubtitleStreamsChanged
'-------------------------------------------------------------------------------
sub onSubtitleStreamsChanged()
    configureDialog()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onSelectedSubtitleStreamIndexChanged
'-------------------------------------------------------------------------------
sub onSelectedSubtitleStreamIndexChanged()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    content = getOptionsContent()
    if content = invalid then return

    selection = content.callFunc("getSelectedSubtitle")
    if selection <> invalid then m.top.selectedSubtitle = selection
end sub

'-------------------------------------------------------------------------------
' openVideoOptions
'-------------------------------------------------------------------------------
sub openVideoOptions()
    m.top.title = "Video"
    m.top.dialogWidth = 1480
    m.top.dialogHeight = 590
    m.top.panelX = 220
    m.top.panelY = 245
    m.top.contentComponentName = "VideoOptionsContent"

    content = m.top.callFunc("getContentComponent")
    content.selectedKey = SafeString(m.top.selectedKey, "automatic")
    content.observeField("optionSelected", "onContentOptionSelected")

    m.top.callFunc("openDialog")
    content.callFunc("focusOptions")
end sub

'-------------------------------------------------------------------------------
' onContentOptionSelected
'-------------------------------------------------------------------------------
sub onContentOptionSelected()
    content = m.top.callFunc("getContentComponent")
    if content = invalid then return

    m.top.selectedOption = content.optionSelected
end sub

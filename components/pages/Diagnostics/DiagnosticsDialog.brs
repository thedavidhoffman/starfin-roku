'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.dialog = m.top.findNode("diagnosticsDialog")
    if m.dialog <> invalid then m.dialog.observeField("closeRequested", "onDialogCloseRequested")
end sub

'-------------------------------------------------------------------------------
' openDiagnostics
'-------------------------------------------------------------------------------
sub openDiagnostics()
    if m.dialog = invalid then return

    content = m.dialog.callFunc("getContentComponent")
    if content <> invalid then
        content.cacheInfo = m.top.cacheInfo
        content.callFunc("updateDiagnostics")
    end if
    m.dialog.callFunc("openDialog")
end sub

'-------------------------------------------------------------------------------
' onDialogCloseRequested
'-------------------------------------------------------------------------------
sub onDialogCloseRequested()
    m.top.closeRequested = true
end sub

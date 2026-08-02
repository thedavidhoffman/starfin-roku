'-------------------------------------------------------------------------------
' openDiagnostics
'-------------------------------------------------------------------------------
sub openDiagnostics()
    m.top.title = "Diagnostics"
    m.top.dialogWidth = 1152
    m.top.dialogHeight = 940
    m.top.contentComponentName = "DiagnosticsContent"

    content = m.top.callFunc("getContentComponent")
    content.callFunc("updateDiagnostics")
    m.top.callFunc("openDialog")
    content.callFunc("focusDiagnostics")
end sub

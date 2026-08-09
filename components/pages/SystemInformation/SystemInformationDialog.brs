'-------------------------------------------------------------------------------
' openSystemInformation
'-------------------------------------------------------------------------------
sub openSystemInformation()
    m.top.title = "System Information"
    m.top.dialogWidth = 1536
    m.top.dialogHeight = 940
    m.top.contentComponentName = "SystemInformationContent"

    content = m.top.callFunc("getContentComponent")
    content.callFunc("updateSystemInformation")
    m.top.callFunc("openDialog")
    content.callFunc("focusSystemInformation")
end sub

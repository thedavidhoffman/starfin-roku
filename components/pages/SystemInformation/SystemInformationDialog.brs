'-------------------------------------------------------------------------------
' openSystemInformation
'-------------------------------------------------------------------------------
sub openSystemInformation()
    m.top.title = "System Information"
    m.top.dialogWidth = 1536
    m.top.dialogHeight = 940
    m.top.contentComponentName = "SystemInformationContent"

    content = m.top.callFunc("getContentComponent")
    m.top.callFunc("openDialog")
    content.callFunc("updateSystemInformation")
    content.callFunc("focusSystemInformation")
end sub

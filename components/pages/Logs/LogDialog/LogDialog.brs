'-------------------------------------------------------------------------------
' openLogs
'-------------------------------------------------------------------------------
sub openLogs()
    m.top.title = "Application Log"
    m.top.dialogWidth = 1840
    m.top.dialogHeight = 1020
    m.top.panelX = 40
    m.top.panelY = 30
    m.top.contentComponentName = "LogContent"
    m.top.closeOnContentSelected = false

    content = m.top.callFunc("getContentComponent")
    entries = []
    if m.global.logService <> invalid then entries = m.global.logService.callFunc("getSnapshot")
    content.callFunc("loadEntries", entries)
    m.top.callFunc("openDialog")
    content.callFunc("focusLog")
end sub

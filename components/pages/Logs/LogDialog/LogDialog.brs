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
    if m.global.logCollector <> invalid then entries = m.global.logCollector.callFunc("getSnapshot")
    content.callFunc("loadEntries", entries)
    m.top.callFunc("openDialog")
    content.callFunc("focusLog")
end sub

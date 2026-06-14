'-------------------------------------------------------------------------------
' openConfirmation
'-------------------------------------------------------------------------------
sub openConfirmation()
    m.top.title = "Exit?"
    m.top.dialogWidth = 800
    m.top.dialogHeight = 420
    m.top.contentComponentName = "ExitDialogContent"
    m.top.showButtons = true
    m.top.saveButtonText = "Exit"
    m.top.cancelButtonText = "Cancel"
    m.top.callFunc("openDialog")
    m.top.callFunc("focusSaveButton")
end sub

'-------------------------------------------------------------------------------
' closeConfirmation
'-------------------------------------------------------------------------------
sub closeConfirmation()
    closeDialogWithoutEvent()
end sub

'-------------------------------------------------------------------------------
' onSaveSelected
'-------------------------------------------------------------------------------
sub onSaveSelected()
    confirmExit()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    cancelExit()
end sub

'-------------------------------------------------------------------------------
' confirmExit
'-------------------------------------------------------------------------------
sub confirmExit()
    closeDialogWithoutEvent()
    m.top.confirmed = true
end sub

'-------------------------------------------------------------------------------
' cancelExit
'-------------------------------------------------------------------------------
sub cancelExit()
    closeDialogWithoutEvent()
    m.top.canceled = true
end sub

'-------------------------------------------------------------------------------
' closeDialogWithoutEvent
'-------------------------------------------------------------------------------
sub closeDialogWithoutEvent()
    dialog = m.top.findNode("dialog")
    if dialog <> invalid then dialog.visible = false
end sub

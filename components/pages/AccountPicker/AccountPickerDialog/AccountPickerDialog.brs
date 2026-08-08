'-------------------------------------------------------------------------------
' openAccountPicker
'-------------------------------------------------------------------------------
sub openAccountPicker()
    m.top.title = "Switch Account"
    m.top.dialogWidth = 920
    m.top.dialogHeight = 620
    m.top.contentComponentName = "AccountPickerContent"

    content = m.top.callFunc("getContentComponent")
    content.contentWidth = Number_ToInteger(m.top.dialogWidth - 120, 800)
    content.accounts = m.top.accounts
    content.observeField("accountSelected", "onAccountSelected")
    content.observeField("signInSelected", "onSignInSelected")
    m.top.callFunc("openDialog")
    content.callFunc("focusAccounts")
end sub

'-------------------------------------------------------------------------------
' onAccountSelected
'-------------------------------------------------------------------------------
sub onAccountSelected()
    content = m.top.callFunc("getContentComponent")
    m.top.selectedAccount = content.accountSelected
    m.top.callFunc("closeDialog")
end sub

'-------------------------------------------------------------------------------
' onSignInSelected
'-------------------------------------------------------------------------------
sub onSignInSelected()
    m.top.signInSelected = true
    m.top.callFunc("closeDialog")
end sub

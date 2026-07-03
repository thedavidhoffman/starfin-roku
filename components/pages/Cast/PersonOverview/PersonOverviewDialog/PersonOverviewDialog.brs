'-------------------------------------------------------------------------------
' openOverview
'-------------------------------------------------------------------------------
sub openOverview()
    m.top.visible = true
    configureDialog()
    syncContent()
    m.top.callFunc("openDialog")
    focusOverview()
end sub

'-------------------------------------------------------------------------------
' focusOverview
'-------------------------------------------------------------------------------
sub focusOverview()
    content = getPersonOverviewContent()
    if content <> invalid then content.callFunc("focusOverview")
end sub

'-------------------------------------------------------------------------------
' configureDialog
'-------------------------------------------------------------------------------
sub configureDialog()
    title = SafeString(m.top.personName, "")
    if title = "" then title = "Overview"

    m.top.title = title
    m.top.dialogWidth = 1536
    m.top.dialogHeight = 864
    m.top.contentComponentName = "PersonOverviewComponent"
end sub

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getPersonOverviewContent()
    if content = invalid then return

    content.overviewText = m.top.overviewText
end sub

'-------------------------------------------------------------------------------
' getPersonOverviewContent
'-------------------------------------------------------------------------------
function getPersonOverviewContent() as dynamic
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' onOverviewTextChanged
'-------------------------------------------------------------------------------
sub onOverviewTextChanged()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    m.top.visible = false
end sub

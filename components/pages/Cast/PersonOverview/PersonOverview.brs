'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.dialog = m.top.findNode("dialog")
    m.overview = m.top.findNode("overview")

    m.dialog.observeField("closeRequested", "onDialogCloseRequested")
    updateTitle()
    renderOverview()
end sub

'-------------------------------------------------------------------------------
' openOverview
'-------------------------------------------------------------------------------
sub openOverview()
    m.top.visible = true
    renderOverview()
    m.dialog.callFunc("openDialog")
    m.overview.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' closeOverview
'-------------------------------------------------------------------------------
sub closeOverview()
    m.dialog.callFunc("closeDialog")
end sub

'-------------------------------------------------------------------------------
' onOverviewTextChanged
'-------------------------------------------------------------------------------
sub onOverviewTextChanged()
    renderOverview()
end sub

'-------------------------------------------------------------------------------
' onPersonNameChanged
'-------------------------------------------------------------------------------
sub onPersonNameChanged()
    updateTitle()
end sub

'-------------------------------------------------------------------------------
' updateTitle
'-------------------------------------------------------------------------------
sub updateTitle()
    personName = m.top.personName
    if personName = invalid or personName = "" then personName = "Overview"
    m.dialog.title = personName
end sub

'-------------------------------------------------------------------------------
' renderOverview
'-------------------------------------------------------------------------------
sub renderOverview()
    if m.overview = invalid then return

    text = m.top.overviewText
    if text = invalid then text = ""
    m.overview.text = text
end sub

'-------------------------------------------------------------------------------
' onDialogCloseRequested
'-------------------------------------------------------------------------------
sub onDialogCloseRequested()
    m.top.visible = false
    m.top.closeRequested = true
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        closeOverview()
        return true
    end if

    return true
end function

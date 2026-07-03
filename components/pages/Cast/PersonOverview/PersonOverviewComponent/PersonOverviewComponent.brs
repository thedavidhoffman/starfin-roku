'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.overview = m.top.findNode("overview")
    renderOverview()
end sub

'-------------------------------------------------------------------------------
' focusOverview
'-------------------------------------------------------------------------------
sub focusOverview()
    m.overview.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onOverviewTextChanged
'-------------------------------------------------------------------------------
sub onOverviewTextChanged()
    renderOverview()
end sub

'-------------------------------------------------------------------------------
' renderOverview
'-------------------------------------------------------------------------------
sub renderOverview()
    m.overview.text = SafeString(m.top.overviewText, "")
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if key = "OK" or key = "select" then return true

    return false
end function

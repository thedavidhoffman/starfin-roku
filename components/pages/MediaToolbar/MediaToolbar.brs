'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.toolbarItems = m.top.findNode("toolbarItems")
    m.watchButton = m.top.findNode("watchButton")
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    m.watchButton.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "down" then
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    m.top.userInteraction = true

    if key = "up" then
        m.top.focusExitUp = true
        return true
    end if

    if key = "down" then
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" then
        if m.top.canFocusExitUp <> true then return false
        m.top.focusExitUp = true
        return true
    end if

    if key = "down" then
        if m.top.canFocusExitDown <> true then return false
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

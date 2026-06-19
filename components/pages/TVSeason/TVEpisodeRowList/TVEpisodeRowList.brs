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

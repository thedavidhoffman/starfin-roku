'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if key = "up" or key = "down" then
        m.top.navigationKeyPressed = {
            key: key
            press: press
        }
    end if

    return false
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.iconPoster = m.top.findNode("iconPoster")
    m.top.observeField("focusedChild", "onFocusChanged")
    updateIcon()
end sub

'-------------------------------------------------------------------------------
' updateIcon
'-------------------------------------------------------------------------------
sub updateIcon()
    if m.iconPoster = invalid then return

    if m.top.hasFocusVisual = true then
        m.iconPoster.uri = m.top.focusedIcon
    else
        m.iconPoster.uri = m.top.icon
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    m.top.hasFocusVisual = m.top.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "OK" or key = "select" then
        m.top.buttonSelected = true
        return true
    end if

    return false
end function

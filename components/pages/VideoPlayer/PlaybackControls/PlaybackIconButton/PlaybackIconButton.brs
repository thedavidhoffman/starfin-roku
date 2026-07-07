'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.iconPoster = m.top.findNode("iconPoster")
    m.top.observeField("focusedChild", "onFocusChanged")
    updateIcon()
    updateEnabled()
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
' updateEnabled
'-------------------------------------------------------------------------------
sub updateEnabled()
    if m.iconPoster = invalid then return

    if m.top.enabled = false then
        m.iconPoster.opacity = 0.35
        m.top.hasFocusVisual = false
    else
        m.iconPoster.opacity = 1.0
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    if m.top.enabled = false then
        m.top.hasFocusVisual = false
        return
    end if

    m.top.hasFocusVisual = m.top.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if m.top.enabled = false then
        return key = "OK" or key = "select"
    end if

    if key = "OK" or key = "select" then
        m.top.buttonSelected = true
        return true
    end if

    return false
end function

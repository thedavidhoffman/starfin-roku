'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.aLabel = m.top.findNode("aLabel")
    m.dashLabel = m.top.findNode("dashLabel")
    m.zLabel = m.top.findNode("zLabel")
    m.top.observeField("focusedChild", "onFocusChanged")
    applyLayout()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' onLayoutModeChanged
'-------------------------------------------------------------------------------
sub onLayoutModeChanged()
    applyLayout()
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    m.top.focused = m.top.isInFocusChain()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' updateFocusVisual
'-------------------------------------------------------------------------------
sub updateFocusVisual()
    hasFocus = m.top.isInFocusChain()

    if hasFocus then
        m.background.color = &hF3F7FBFF
        m.aLabel.color = &h0F1A2AFF
        m.dashLabel.color = &h0F1A2AFF
        m.zLabel.color = &h0F1A2AFF
    else
        m.background.color = &h102033FF
        m.aLabel.color = &hF3F7FBFF
        m.dashLabel.color = &hB9C7D6FF
        m.zLabel.color = &hF3F7FBFF
    end if
end sub

'-------------------------------------------------------------------------------
' applyLayout
'-------------------------------------------------------------------------------
sub applyLayout()
    if LCase(m.top.layoutMode) = "horizontal" then
        m.background.width = 132
        m.background.height = 42
        applyLabelLayout(m.aLabel, [18, 8], 26)
        applyLabelLayout(m.dashLabel, [53, 8], 26)
        applyLabelLayout(m.zLabel, [88, 8], 26)
        return
    end if

    m.background.width = 42
    m.background.height = 132
    applyLabelLayout(m.aLabel, [0, 18], 42)
    applyLabelLayout(m.dashLabel, [0, 52], 42)
    applyLabelLayout(m.zLabel, [0, 86], 42)
end sub

'-------------------------------------------------------------------------------
' applyLabelLayout
'-------------------------------------------------------------------------------
sub applyLabelLayout(label as object, translation as object, width as integer)
    if label = invalid then return

    label.translation = translation
    label.width = width
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    normalizedKey = LCase(key)
    if normalizedKey = "ok" or normalizedKey = "select" or normalizedKey = "left" then
        m.top.buttonSelected = true
        return true
    end if

    return false
end function

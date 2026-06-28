'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.aLabel = m.top.findNode("aLabel")
    m.dashLabel = m.top.findNode("dashLabel")
    m.zLabel = m.top.findNode("zLabel")
    m.top.observeField("focusedChild", "onFocusChanged")
    updateFocusVisual()
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

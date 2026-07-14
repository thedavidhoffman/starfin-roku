'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.focusBackground = m.top.findNode("focusBackground")
    m.letterLabel = m.top.findNode("letterLabel")
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.letterLabel.text = SafeString(item.title, "")
end sub

'-------------------------------------------------------------------------------
' onItemHasFocusChanged
'-------------------------------------------------------------------------------
sub onItemHasFocusChanged()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' onAvailabilityChanged
'-------------------------------------------------------------------------------
sub onAvailabilityChanged()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' updateFocusVisual
'-------------------------------------------------------------------------------
sub updateFocusVisual()
    if m.background = invalid or m.focusBackground = invalid or m.letterLabel = invalid then return

    hasFocus = m.top.itemHasFocus = true
    isAvailable = m.top.isAvailable = true
    m.focusBackground.visible = hasFocus

    if hasFocus and isAvailable then
        m.letterLabel.color = &h0F1A2AFF
    else if hasFocus then
        m.letterLabel.color = &h627080FF
    else if isAvailable then
        m.letterLabel.color = &hF3F7FBFF
    else
        m.letterLabel.color = &h627080FF
    end if

    if isAvailable then
        m.background.opacity = 1.0
    else
        m.background.opacity = 0.55
    end if
end sub

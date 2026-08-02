'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.bg = m.top.findNode("bg")
    m.icon = m.top.findNode("icon")
    m.textLabel = m.top.findNode("textLabel")
    if m.top.buttonWidth = invalid or m.top.buttonWidth <= 0 then m.top.buttonWidth = 300
    if m.top.buttonHeight = invalid or m.top.buttonHeight <= 0 then m.top.buttonHeight = 56
    onDimensionsChanged()
    onTextChanged()
    onIconUriChanged()
    onFocusVisualChanged()
end sub

'-------------------------------------------------------------------------------
' onTextChanged
'-------------------------------------------------------------------------------
sub onTextChanged()
    if m.textLabel <> invalid then m.textLabel.text = m.top.text
    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' onIconUriChanged
'-------------------------------------------------------------------------------
sub onIconUriChanged()
    hasIcon = m.top.iconUri <> invalid and m.top.iconUri <> ""
    if m.icon <> invalid then
        m.icon.uri = m.top.iconUri
        m.icon.visible = hasIcon
    end if
    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' onDimensionsChanged
'-------------------------------------------------------------------------------
sub onDimensionsChanged()
    width = int(m.top.buttonWidth)
    height = int(m.top.buttonHeight)
    if width <= 0 then width = 300
    if height <= 0 then height = 56

    if m.bg <> invalid then
        m.bg.width = width
        m.bg.height = height
    end if

    if m.textLabel <> invalid then
        m.textLabel.width = width
        m.textLabel.translation = [0, int((height - 32) / 2)]
    end if

    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' onFocusVisualChanged
'-------------------------------------------------------------------------------
sub onFocusVisualChanged()
    if m.bg = invalid then return

    if m.top.hasFocusVisual = true then
        m.bg.uri = "pkg:/images/buttons/primary_focused.9.png"
        if m.textLabel <> invalid then m.textLabel.color = &h0F1A2AFF
    else
        m.bg.uri = "pkg:/images/buttons/primary_unfocused.9.png"
        if m.textLabel <> invalid then m.textLabel.color = &hFFFFFFFF
    end if
end sub

'-------------------------------------------------------------------------------
' updateContentLayout
'-------------------------------------------------------------------------------
sub updateContentLayout()
    if m.textLabel = invalid then return

    width = int(m.top.buttonWidth)
    height = int(m.top.buttonHeight)
    if width <= 0 then width = 300
    if height <= 0 then height = 56

    textY = int((height - 32) / 2)
    hasIcon = m.top.iconUri <> invalid and m.top.iconUri <> ""
    if hasIcon <> true then
        m.textLabel.horizAlign = "center"
        m.textLabel.width = width
        m.textLabel.translation = [0, textY]
        if m.icon <> invalid then m.icon.visible = false
        return
    end if

    iconSize = 24
    iconGap = 12
    textWidth = getTextWidth()
    maxTextWidth = width - iconSize - iconGap - 24
    if maxTextWidth < 1 then maxTextWidth = 1
    if textWidth > maxTextWidth then textWidth = maxTextWidth

    contentWidth = iconSize + iconGap + textWidth
    contentX = int((width - contentWidth) / 2)
    if contentX < 0 then contentX = 0

    if m.icon <> invalid then
        m.icon.width = iconSize
        m.icon.height = iconSize
        m.icon.translation = [contentX, int((height - iconSize) / 2)]
        m.icon.visible = true
    end if

    m.textLabel.horizAlign = "left"
    m.textLabel.width = maxTextWidth
    m.textLabel.translation = [contentX + iconSize + iconGap, textY]
end sub

'-------------------------------------------------------------------------------
' getTextWidth
'-------------------------------------------------------------------------------
function getTextWidth() as integer
    textWidth = 1
    if m.top.text <> invalid then textWidth = Len(m.top.text) * 18
    if textWidth <= 0 then textWidth = 1
    return textWidth
end function

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

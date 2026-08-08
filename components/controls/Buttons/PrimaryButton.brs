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
    onTextFontChanged()
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
        iconUri = m.top.iconUri
        if m.top.hasFocusVisual and m.top.focusedIconUri <> invalid and m.top.focusedIconUri <> "" then iconUri = m.top.focusedIconUri
        m.icon.uri = iconUri
        m.icon.visible = hasIcon
    end if
    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' onDimensionsChanged
'-------------------------------------------------------------------------------
sub onDimensionsChanged()
    width = getButtonWidth()
    height = getButtonHeight()

    if m.bg <> invalid then
        m.bg.width = width
        m.bg.height = height
    end if

    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' onFocusVisualChanged
'-------------------------------------------------------------------------------
sub onFocusVisualChanged()
    if m.bg = invalid then return

    if m.top.hasFocusVisual = true then
        m.bg.uri = ButtonAssets_GetUri("primary-focused.9.png")
        if m.textLabel <> invalid then m.textLabel.color = &h0F1A2AFF
    else
        m.bg.uri = ButtonAssets_GetUri("primary-unfocused.9.png")
        if m.textLabel <> invalid then m.textLabel.color = &hFFFFFFFF
    end if
    onIconUriChanged()
end sub

'-------------------------------------------------------------------------------
' onTextFontChanged
'-------------------------------------------------------------------------------
sub onTextFontChanged()
    if m.textLabel = invalid then return
    textFont = m.top.textFont
    if textFont = invalid or textFont = "" then textFont = "font:MediumSystemFont"
    m.textLabel.font = textFont
    updateContentLayout()
end sub

'-------------------------------------------------------------------------------
' updateContentLayout
'-------------------------------------------------------------------------------
sub updateContentLayout()
    if m.textLabel = invalid then return

    width = getButtonWidth()
    height = getButtonHeight()
    textHeight = getTextHeight()
    textY = Number_ToInteger((height - textHeight) / 2, 0)
    m.textLabel.height = textHeight

    if hasButtonIcon() then
        layoutIconAndText(width, height, textY)
    else
        layoutTextOnly(width, textY)
    end if
end sub

'-------------------------------------------------------------------------------
' layoutTextOnly
'-------------------------------------------------------------------------------
sub layoutTextOnly(width as integer, textY as integer)
    m.textLabel.horizAlign = "center"
    m.textLabel.width = width
    m.textLabel.translation = [0, textY]
    if m.icon <> invalid then m.icon.visible = false
end sub

'-------------------------------------------------------------------------------
' layoutIconAndText
'-------------------------------------------------------------------------------
sub layoutIconAndText(width as integer, height as integer, textY as integer)
    iconSize = 24
    iconGap = getIconGap()
    textWidth = getTextWidth() + 8
    maxTextWidth = width - iconSize - iconGap - 24
    if maxTextWidth < 1 then maxTextWidth = 1
    if textWidth > maxTextWidth then textWidth = maxTextWidth

    contentWidth = iconSize + iconGap + textWidth
    contentX = Number_ToInteger((width - contentWidth) / 2, 0)
    contentX = contentX + Number_ToInteger(m.top.contentOffsetX, 0)
    if contentX < 0 then contentX = 0

    if m.icon <> invalid then
        m.icon.width = iconSize
        m.icon.height = iconSize
        iconY = Number_ToInteger((height - iconSize) / 2, 0)
        m.icon.translation = [contentX, iconY]
        m.icon.visible = true
    end if

    m.textLabel.horizAlign = "left"
    m.textLabel.width = textWidth
    m.textLabel.translation = [contentX + iconSize + iconGap, textY]
end sub

'-------------------------------------------------------------------------------
' hasButtonIcon
'-------------------------------------------------------------------------------
function hasButtonIcon() as boolean
    return m.top.iconUri <> invalid and m.top.iconUri <> ""
end function

'-------------------------------------------------------------------------------
' getButtonWidth
'-------------------------------------------------------------------------------
function getButtonWidth() as integer
    width = Number_ToInteger(m.top.buttonWidth, 0)
    if width <= 0 then return 300
    return width
end function

'-------------------------------------------------------------------------------
' getButtonHeight
'-------------------------------------------------------------------------------
function getButtonHeight() as integer
    height = Number_ToInteger(m.top.buttonHeight, 0)
    if height <= 0 then return 56
    return height
end function

'-------------------------------------------------------------------------------
' getIconGap
'-------------------------------------------------------------------------------
function getIconGap() as integer
    iconGap = Number_ToInteger(m.top.iconGap, 0)
    if iconGap <= 0 then return 12
    return iconGap
end function

'-------------------------------------------------------------------------------
' getTextHeight
'-------------------------------------------------------------------------------
function getTextHeight() as integer
    textHeight = Number_ToInteger(m.top.textHeight, 0)
    if textHeight <= 0 then return 32
    return textHeight
end function

'-------------------------------------------------------------------------------
' getTextWidth
'-------------------------------------------------------------------------------
function getTextWidth() as integer
    text = m.top.text
    if text = invalid or text = "" then return 1

    textWidth = 0
    if m.fontRegistry = invalid then m.fontRegistry = CreateObject("roFontRegistry")
    if m.fontRegistry <> invalid and m.textLabel <> invalid and m.textLabel.font <> invalid then
        fontSize = Number_ToInteger(m.textLabel.font.size, 0)
        if fontSize > 0 then
            measurementFont = m.fontRegistry.GetDefaultFont(fontSize, false, false)
            if measurementFont <> invalid then textWidth = measurementFont.GetOneLineWidth(text, 1920)
        end if
    end if
    if textWidth <= 0 then textWidth = Len(text) * 18
    if textWidth <= 0 then textWidth = 1
    return textWidth
end function

'-------------------------------------------------------------------------------
' getPreferredWidth
'-------------------------------------------------------------------------------
function getPreferredWidth(horizontalPadding as integer) as integer
    padding = horizontalPadding
    if padding < 0 then padding = 0
    return getTextWidth() + (padding * 2)
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

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.focusBg = m.top.findNode("focusBg")
    m.dateLabel = m.top.findNode("dateLabel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.characterLabel = m.top.findNode("characterLabel")

    initStyles()
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
    colors = Color()
    m.dateLabel.color = colors.text.secondary
    m.titleLabel.color = colors.text.primary
    m.characterLabel.color = colors.text.secondary
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.dateLabel.text = SafeString(item.releaseDate, "")
    m.titleLabel.text = SafeString(item.title, "")

    character = SafeString(item.character, "")
    if character <> "" then
        m.characterLabel.text = "as " + character
    else
        m.characterLabel.text = ""
    end if
end sub

'-------------------------------------------------------------------------------
' onItemHasFocusChanged
'-------------------------------------------------------------------------------
sub onItemHasFocusChanged()
    colors = Color()
    hasFocus = m.top.itemHasFocus = true
    m.focusBg.visible = hasFocus

    if hasFocus = true then
        m.dateLabel.color = colors.text.primary
        m.dateLabel.font = "font:SmallBoldSystemFont"
        m.titleLabel.color = colors.text.primary
        m.titleLabel.font = "font:SmallBoldSystemFont"
        m.characterLabel.color = colors.text.primary
    else
        m.dateLabel.color = colors.text.secondary
        m.dateLabel.font = "font:SmallSystemFont"
        m.titleLabel.color = colors.text.primary
        m.titleLabel.font = "font:SmallSystemFont"
        m.characterLabel.color = colors.text.secondary
    end if
end sub

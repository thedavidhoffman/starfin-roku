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

    m.characterLabel.text = getDetailText(item)
end sub

'-------------------------------------------------------------------------------
' getDetailText
'-------------------------------------------------------------------------------
function getDetailText(item as dynamic) as string
    parts = []
    character = SafeString(item.character, "")
    if character <> "" then parts.Push("as " + character)

    rating = MediaMetadata_FormatRating(item.voteAverage)
    if rating <> "" then parts.Push(rating)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    if values = invalid then return ""

    text = ""
    for each value in values
        part = String_Trim(SafeString(value, ""))
        if part <> "" then
            if text <> "" then text = text + separator
            text = text + part
        end if
    end for

    return text
end function

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

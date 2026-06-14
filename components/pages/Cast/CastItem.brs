'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.nameLabel = m.top.findNode("nameLabel")
    m.roleLabel = m.top.findNode("roleLabel")
    m.focus = [
        m.top.findNode("focusTop")
        m.top.findNode("focusBottom")
        m.top.findNode("focusLeft")
        m.top.findNode("focusRight")
    ]
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.nameLabel.text = SafeString(item.title, "")
    m.roleLabel.text = SafeString(item.description, "")

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' onItemHasFocusChanged
'-------------------------------------------------------------------------------
sub onItemHasFocusChanged()
    hasFocus = m.top.itemHasFocus
    for each border in m.focus
        border.visible = hasFocus
    end for

    if hasFocus then
        m.bg.color = &h21405EFF
    else
        m.bg.color = &h101820CC
    end if
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.focus = [
        m.top.findNode("focusTop")
        m.top.findNode("focusBottom")
        m.top.findNode("focusLeft")
        m.top.findNode("focusRight")
    ]
    m.title = m.top.findNode("title")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.title.text = SafeString(item.title, "")
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
        m.bg.color = &h313040FF
    end if
end sub

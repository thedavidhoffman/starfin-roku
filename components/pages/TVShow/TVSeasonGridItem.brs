'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.title.text = SafeString(item.title, "")
    m.subtitle.text = SafeString(item.description, "")

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

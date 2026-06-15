'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

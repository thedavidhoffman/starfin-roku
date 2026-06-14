'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.poster = m.top.findNode("poster")
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

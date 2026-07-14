'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.poster = m.top.findNode("poster")
    m.nameLabel = m.top.findNode("nameLabel")
    m.roleLabel = m.top.findNode("roleLabel")
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

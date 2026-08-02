'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.poster = m.top.findNode("poster")
    m.nameLabel = m.top.findNode("nameLabel")
    m.roleLabel = m.top.findNode("roleLabel")
    maskProfile = MaskAssets_GetProfile("cast-mask.png", [195, 195], [130, 130])
    m.posterMask.maskUri = maskProfile.uri
    m.posterMask.maskSize = maskProfile.size
    if maskProfile.isHd then m.posterMask.translation = [12, 6]
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

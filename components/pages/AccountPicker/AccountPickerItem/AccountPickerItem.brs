'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.poster = m.top.findNode("poster")
    m.nameLabel = m.top.findNode("nameLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.poster.observeField("loadStatus", "onPosterLoadStatusChanged")
    maskProfile = MaskAssets_GetProfile("cast-mask.png", [195, 195], [130, 130])
    m.posterMask.maskUri = maskProfile.uri
    m.posterMask.maskSize = maskProfile.size
    if maskProfile.isHd then m.posterMask.translation = [12, 6]
end sub

'-------------------------------------------------------------------------------
' onPosterLoadStatusChanged
'-------------------------------------------------------------------------------
sub onPosterLoadStatusChanged()
    if LCase(SafeString(m.poster.loadStatus, "")) <> "failed" then return
    placeholderUri = "pkg:/images/cast/cast-placeholder-195x195.png"
    if m.poster.uri <> placeholderUri then m.poster.uri = placeholderUri
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.nameLabel.text = SafeString(item.title, "")
    m.statusLabel.text = SafeString(item.description, "")
    imageUrl = SafeString(item.HDPosterUrl, "")
    if imageUrl = "" then imageUrl = "pkg:/images/cast/cast-placeholder-195x195.png"
    m.poster.uri = imageUrl
end sub

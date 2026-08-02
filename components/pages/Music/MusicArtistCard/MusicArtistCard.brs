'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    MaskAssets_Apply(m.top.findNode("artistMask"), "album-mask-342.png", [342, 342], [228, 228])
    m.artwork = m.top.findNode("artistArtwork")
    m.label = m.top.findNode("artistLabel")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.artwork.uri = SafeString(item.HDPosterUrl, "")
    m.label.text = FirstNonEmpty([item.title], "Unknown Artist")
end sub

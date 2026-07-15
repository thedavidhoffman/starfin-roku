'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.artwork = m.top.findNode("albumArtwork")
    m.albumLabel = m.top.findNode("albumLabel")
    m.yearLabel = m.top.findNode("yearLabel")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.artwork.uri = SafeString(item.HDPosterUrl, "")
    m.albumLabel.text = FirstNonEmpty([item.title], "Untitled Album")
    m.yearLabel.text = SafeString(item.releaseYear, "")
end sub

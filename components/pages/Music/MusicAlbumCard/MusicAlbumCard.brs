'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.artwork = m.top.findNode("albumArtwork")
    m.artistLabel = m.top.findNode("artistLabel")
    m.albumLabel = m.top.findNode("albumLabel")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.artwork.uri = getArtworkUrl(item)
    m.artistLabel.text = getArtistName(item)
    m.albumLabel.text = getAlbumName(item)
end sub

'-------------------------------------------------------------------------------
' getArtworkUrl
'-------------------------------------------------------------------------------
function getArtworkUrl(item as object) as string
    imageUrl = SafeString(item.HDPosterUrl, "")
    if imageUrl <> "" then return imageUrl

    return "pkg:/images/music/album-placeholder-250x250.png"
end function

'-------------------------------------------------------------------------------
' getArtistName
'-------------------------------------------------------------------------------
function getArtistName(item as object) as string
    raw = item.raw
    if raw <> invalid then return FirstNonEmpty([raw.AlbumArtist, raw.Artist], "Unknown Artist")

    return FirstNonEmpty([item.artistName], "Unknown Artist")
end function

'-------------------------------------------------------------------------------
' getAlbumName
'-------------------------------------------------------------------------------
function getAlbumName(item as object) as string
    raw = item.raw
    if raw <> invalid then return FirstNonEmpty([raw.Name], "Untitled Album")

    return FirstNonEmpty([item.title], "Untitled Album")
end function

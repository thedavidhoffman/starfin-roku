'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.artwork = m.top.findNode("albumArtwork")
    m.artistLabel = m.top.findNode("artistLabel")
    m.albumLabel = m.top.findNode("albumLabel")
    m.yearLabel = m.top.findNode("yearLabel")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.artwork.uri = getArtworkUrl(item)
    m.artistLabel.text = getPrimaryLabel(item)
    m.albumLabel.text = getSecondaryLabel(item)
    syncYearLabel(item)
end sub

'-------------------------------------------------------------------------------
' getArtworkUrl
'-------------------------------------------------------------------------------
function getArtworkUrl(item as object) as string
    imageUrl = SafeString(item.HDPosterUrl, "")
    if imageUrl <> "" then return imageUrl

    return "pkg:/images/music/album-placeholder-340x340.png"
end function

'-------------------------------------------------------------------------------
' getPrimaryLabel
'-------------------------------------------------------------------------------
function getPrimaryLabel(item as object) as string
    primaryLabel = FirstNonEmpty([item.primaryLabel], "")
    if primaryLabel <> "" then return primaryLabel

    return getArtistName(item)
end function

'-------------------------------------------------------------------------------
' getSecondaryLabel
'-------------------------------------------------------------------------------
function getSecondaryLabel(item as object) as string
    secondaryLabel = FirstNonEmpty([item.secondaryLabel], "")
    if secondaryLabel <> "" then return secondaryLabel

    return getAlbumName(item)
end function

'-------------------------------------------------------------------------------
' syncYearLabel
'-------------------------------------------------------------------------------
sub syncYearLabel(item as object)
    releaseYear = getReleaseYear(item)
    hasReleaseYear = releaseYear <> ""

    m.yearLabel.text = releaseYear
    m.yearLabel.visible = hasReleaseYear
    if hasReleaseYear then
        m.albumLabel.width = 252
    else
        m.albumLabel.width = 340
    end if
end sub

'-------------------------------------------------------------------------------
' getReleaseYear
'-------------------------------------------------------------------------------
function getReleaseYear(item as object) as string
    releaseYear = SafeString(item.releaseYear, "")
    if Len(releaseYear) = 4 then return releaseYear

    return ""
end function

'-------------------------------------------------------------------------------
' getArtistName
'-------------------------------------------------------------------------------
function getArtistName(item as object) as string
    artistName = FirstNonEmpty([item.artistName], "")
    if artistName <> "" then return artistName

    raw = item.raw
    if raw <> invalid then return FirstNonEmpty([raw.AlbumArtist, raw.Artist], "Unknown Artist")

    return "Unknown Artist"
end function

'-------------------------------------------------------------------------------
' getAlbumName
'-------------------------------------------------------------------------------
function getAlbumName(item as object) as string
    albumName = FirstNonEmpty([item.title], "")
    if albumName <> "" then return albumName

    raw = item.raw
    if raw <> invalid then return FirstNonEmpty([raw.Name], "Untitled Album")

    return "Untitled Album"
end function

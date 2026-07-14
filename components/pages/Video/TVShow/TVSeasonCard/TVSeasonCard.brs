'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.watchedIndicator = m.top.findNode("watchedIndicator")
    m.title = m.top.findNode("title")
    m.year = m.top.findNode("year")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then
        m.itemContent = invalid
        m.itemContentKey = ""
        m.watchedIndicator.visible = false
        return
    end if
    itemContentKey = SafeString(item.itemId, "")
    m.itemContent = item
    if m.itemContentKey <> itemContentKey then
        m.itemContentKey = itemContentKey
        item.observeField("raw", "onItemDataChanged")
    end if

    m.title.text = SafeString(item.title, "")
    m.year.text = getMetadataText(item)

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
    m.watchedIndicator.visible = isSeasonFullyWatched(item)
end sub

'-------------------------------------------------------------------------------
' onItemDataChanged
'-------------------------------------------------------------------------------
sub onItemDataChanged()
    if m.itemContent = invalid then return

    m.watchedIndicator.visible = isSeasonFullyWatched(m.itemContent)
end sub

'-------------------------------------------------------------------------------
' isSeasonFullyWatched
'-------------------------------------------------------------------------------
function isSeasonFullyWatched(item as dynamic) as boolean
    raw = item.raw
    if raw = invalid or raw.UserData = invalid then return false

    return raw.UserData.UnplayedItemCount = 0
end function

'-------------------------------------------------------------------------------
' getMetadataText
'-------------------------------------------------------------------------------
function getMetadataText(item as dynamic) as string
    parts = []

    year = SafeString(item.seasonYear, "")
    if year <> "" then parts.Push(year)

    episodeText = getEpisodeCountText(item.episodeCount)
    if episodeText <> "" then parts.Push(episodeText)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getEpisodeCountText
'-------------------------------------------------------------------------------
function getEpisodeCountText(count as dynamic) as string
    countText = SafeString(count, "")
    if countText = "" then return ""
    if countText = "1" then return "1 ep."

    return countText + " eps."
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    text = ""

    for each value in values
        part = SafeString(value, "")
        if part <> "" then
            if text <> "" then text = text + separator
            text = text + part
        end if
    end for

    return text
end function

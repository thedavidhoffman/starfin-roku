'-------------------------------------------------------------------------------
' updateTrickplayPreview
'-------------------------------------------------------------------------------
sub updateTrickplayPreview(position as float)
    if m.trickplay = invalid then
        m.playbackControls.thumbnailData = {}
        return
    end if

    tileBuffer = 15
    baseScale = getFiveImageTrickplayScale(m.trickplay.tileWidth, tileBuffer)
    largeScale = baseScale * 1.2
    smallScale = baseScale * 0.7
    deltaSeconds = getTrickplayPreviewDelta()
    images = []

    for slot = -2 to 2
        imagePosition = position + (deltaSeconds * slot)
        if imagePosition < 0 or imagePosition > m.playback.duration then
            images.Push({})
        else
            images.Push(buildTrickplayPreviewImage(imagePosition))
        end if
    end for

    m.playbackControls.thumbnailData = {
        layoutWidth: 1713
        gap: tileBuffer
        tileWidth: m.trickplay.tileWidth
        tileHeight: m.trickplay.tileHeight
        largeScale: largeScale
        smallScale: smallScale
        images: images
    }
end sub

'-------------------------------------------------------------------------------
' getTrickplayPreviewDelta
'-------------------------------------------------------------------------------
function getTrickplayPreviewDelta() as integer
    if m.seek <> invalid and m.seek.speedIndex >= 0 then
        delta = m.seek.speeds[m.seek.speedIndex]
        if delta < 0 then delta = 0 - delta
        return delta
    end if

    return 10
end function

'-------------------------------------------------------------------------------
' getFiveImageTrickplayScale
'-------------------------------------------------------------------------------
function getFiveImageTrickplayScale(tileWidth as dynamic, tileBuffer as integer) as float
    if tileWidth = invalid or tileWidth <= 0 then return 1.0

    progressBarWidth = 1713
    availableWidth = progressBarWidth - (tileBuffer * 4)
    if availableWidth <= 0 then return 1.0

    return availableWidth / (tileWidth * 4)
end function

'-------------------------------------------------------------------------------
' buildTrickplayPreviewImage
'-------------------------------------------------------------------------------
function buildTrickplayPreviewImage(position as float) as object
    iconIndex = Fix(position / m.trickplay.interval)
    if iconIndex < 0 then iconIndex = 0
    if iconIndex >= m.trickplay.thumbnailCount then iconIndex = m.trickplay.thumbnailCount - 1

    tilesPerSheet = m.trickplay.tileRows * m.trickplay.tileColumns
    tileIndex = Fix(iconIndex / tilesPerSheet)
    tileIconIndex = iconIndex - (tileIndex * tilesPerSheet)
    row = Fix(tileIconIndex / m.trickplay.tileColumns)
    column = tileIconIndex mod m.trickplay.tileColumns

    uri = getLocalTrickplayUri(tileIndex)
    if uri = "" then return {}

    return {
        uri: uri
        tileIndex: tileIndex
        sheetColumns: m.trickplay.tileColumns
        sheetRows: m.trickplay.tileRows
        column: column
        row: row
        canUseFastReplace: m.trickplay.canUseFastReplace
    }
end function

'-------------------------------------------------------------------------------
' startTrickplayPreload
'-------------------------------------------------------------------------------
sub startTrickplayPreload()
    if m.trickplay = invalid then return

    m.trickplayPreloadRequest = {
        action: "add"
        server: m.session.server
        token: m.session.token
        itemId: m.session.itemId
        tileWidth: m.trickplay.tileWidth
        tileCount: m.trickplay.tileCount
    }
    m.trickplayPreloadTask.request = m.trickplayPreloadRequest
    m.trickplayPreloadTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' cleanupTrickplayPreload
'-------------------------------------------------------------------------------
sub cleanupTrickplayPreload()
    if m.trickplayPreloadRequest = invalid then return

    cleanupRequest = {
        action: "remove"
        itemId: m.trickplayPreloadRequest.itemId
        tileWidth: m.trickplayPreloadRequest.tileWidth
        tileCount: m.trickplayPreloadRequest.tileCount
    }
    m.trickplayPreloadRequest = invalid
    m.trickplayPreloadTask.control = "stop"
    m.trickplayPreloadTask.request = cleanupRequest
    m.trickplayPreloadTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onTrickplayPreloadResponse
'-------------------------------------------------------------------------------
sub onTrickplayPreloadResponse()
    response = m.trickplayPreloadTask.response
    if response = invalid then return
    if response.ok <> true then return
    if SafeString(response.itemId, "") <> m.session.itemId then return

    if response.tileIndex <> invalid and m.trickplay <> invalid then
        m.trickplay.loadedTiles[response.tileIndex.ToStr()] = true
    end if

    if m.playback.isSeeking = true then updateTrickplayPreview(m.playback.previewPosition)
end sub

'-------------------------------------------------------------------------------
' getLocalTrickplayUri
'-------------------------------------------------------------------------------
function getLocalTrickplayUri(tileIndex as integer) as string
    if m.trickplay = invalid then return ""
    if m.trickplay.loadedTiles = invalid then return ""
    if m.trickplay.loadedTiles[tileIndex.ToStr()] <> true then return ""

    return "tmp:/starfin-trickplay-" + m.session.itemId + "-" + m.trickplay.tileWidth.ToStr() + "-" + tileIndex.ToStr() + ".jpg"
end function

'-------------------------------------------------------------------------------
' buildTrickplayState
'-------------------------------------------------------------------------------
function buildTrickplayState(item as dynamic, itemId as string) as dynamic
    trickplay = getItemTrickplay(item)
    if itemId = "" then
        m.log.writeDisplaySafe("Trickplay unavailable: missing itemId.")
        return invalid
    end if
    if trickplay = invalid then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": item has no Trickplay metadata.")
        return invalid
    end if

    itemTrickplay = trickplay.LookupCI(itemId)
    if itemTrickplay = invalid or itemTrickplay.Keys().Count() = 0 then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": no trickplay entry matched the item id.")
        return invalid
    end if

    widthKeys = itemTrickplay.Keys()
    data = itemTrickplay[widthKeys[0]]
    if data = invalid then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": selected trickplay width has no data.")
        return invalid
    end if
    if data.Width = invalid or data.Height = invalid then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": missing thumbnail dimensions.")
        return invalid
    end if
    if data.TileWidth = invalid or data.TileHeight = invalid then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": missing tile grid dimensions.")
        return invalid
    end if
    if data.Interval = invalid or data.Interval <= 0 then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": invalid thumbnail interval.")
        return invalid
    end if

    thumbnailCount = 0
    if data.ThumbnailCount <> invalid then thumbnailCount = data.ThumbnailCount
    if thumbnailCount <= 0 then
        m.log.writeDisplaySafe("Trickplay unavailable itemId=" + itemId + ": thumbnail count is zero.")
        return invalid
    end if

    tilesPerSheet = data.TileHeight * data.TileWidth
    tileCount = Fix((thumbnailCount - 1) / tilesPerSheet) + 1
    m.log.writeDisplaySafe("Trickplay available itemId=" + itemId + " widthKey=" + SafeString(widthKeys[0], "") + " thumbnailCount=" + SafeString(thumbnailCount, "") + " tileCount=" + SafeString(tileCount, ""))

    return {
        tileWidth: data.Width
        tileHeight: data.Height
        tileColumns: data.TileWidth
        tileRows: data.TileHeight
        interval: data.Interval / 1000
        thumbnailCount: thumbnailCount
        tileCount: tileCount
        canUseFastReplace: (data.TileHeight * data.Height) * (data.TileWidth * data.Width) < 2000000
        loadedTiles: {}
    }
end function

'-------------------------------------------------------------------------------
' getItemTrickplay
'-------------------------------------------------------------------------------
function getItemTrickplay(item as dynamic) as dynamic
    if item = invalid then return invalid
    if item.Trickplay <> invalid then return item.Trickplay
    if item.trickplay <> invalid then return item.trickplay

    return invalid
end function

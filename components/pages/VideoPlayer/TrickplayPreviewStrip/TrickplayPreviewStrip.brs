'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.thumbnailSlots = [
        {
            group: m.top.findNode("thumbnailGroup0")
            imageMask: m.top.findNode("thumbnailImageMask0")
            clip: m.top.findNode("thumbnailClip0")
            poster: m.top.findNode("thumbnailPoster0")
            background: m.top.findNode("thumbnailBackground0")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup1")
            imageMask: m.top.findNode("thumbnailImageMask1")
            clip: m.top.findNode("thumbnailClip1")
            poster: m.top.findNode("thumbnailPoster1")
            background: m.top.findNode("thumbnailBackground1")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup2")
            imageMask: m.top.findNode("thumbnailImageMask2")
            clip: m.top.findNode("thumbnailClip2")
            poster: m.top.findNode("thumbnailPoster2")
            background: m.top.findNode("thumbnailBackground2")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup3")
            imageMask: m.top.findNode("thumbnailImageMask3")
            clip: m.top.findNode("thumbnailClip3")
            poster: m.top.findNode("thumbnailPoster3")
            background: m.top.findNode("thumbnailBackground3")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup4")
            imageMask: m.top.findNode("thumbnailImageMask4")
            clip: m.top.findNode("thumbnailClip4")
            poster: m.top.findNode("thumbnailPoster4")
            background: m.top.findNode("thumbnailBackground4")
            hasImage: false
        }
    ]

    for each slot in m.thumbnailSlots
        slot.poster.observeField("loadStatus", "onThumbnailLoadStatusChanged")
    end for
end sub

'-------------------------------------------------------------------------------
' onSeekingChanged
'-------------------------------------------------------------------------------
sub onSeekingChanged()
    if m.top.isSeeking <> true then hideThumbnails()
end sub

'-------------------------------------------------------------------------------
' onThumbnailDataChanged
'-------------------------------------------------------------------------------
sub onThumbnailDataChanged()
    if m.top.isSeeking <> true then
        hideThumbnails()
        return
    end if

    data = m.top.thumbnailData
    if data = invalid or data.images = invalid or data.images.Count() = 0 then
        hideThumbnails()
        return
    end if

    for i = 0 to m.thumbnailSlots.Count() - 1
        if i < data.images.Count() then
            updateThumbnailSlot(m.thumbnailSlots[i], data.images[i])
        else
            m.thumbnailSlots[i].hasImage = false
            m.thumbnailSlots[i].group.visible = false
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' updateThumbnailSlot
'-------------------------------------------------------------------------------
sub updateThumbnailSlot(slot as object, data as dynamic)
    if data = invalid or data.uri = invalid or data.uri = "" then
        slot.hasImage = false
        slot.group.visible = false
        return
    end if

    slot.hasImage = true
    scale = data.scale
    if scale = invalid or scale <= 0 then scale = 1.0

    tileWidth = data.tileWidth * scale
    tileHeight = data.tileHeight * scale
    sheetWidth = data.sheetColumns * tileWidth
    sheetHeight = data.sheetRows * tileHeight

    y = data.y
    if y = invalid then y = 875 - 25 - tileHeight

    slot.group.translation = [data.x, y]
    slot.imageMask.translation = [0, 0]
    slot.imageMask.maskSize = [tileWidth, tileHeight]
    slot.clip.clippingRect = [0, 0, tileWidth, tileHeight]
    slot.background.width = tileWidth
    slot.background.height = tileHeight
    slot.poster.width = sheetWidth
    slot.poster.height = sheetHeight
    slot.poster.translation = [0 - (data.column * tileWidth), 0 - (data.row * tileHeight)]

    if slot.poster.uri <> data.uri then
        slot.group.visible = false
        slot.poster.uri = data.uri
    else
        slot.group.visible = LCase(SafeString(slot.poster.loadStatus, "")) = "ready"
    end if
end sub

'-------------------------------------------------------------------------------
' onThumbnailLoadStatusChanged
'-------------------------------------------------------------------------------
sub onThumbnailLoadStatusChanged()
    for each slot in m.thumbnailSlots
        if slot.hasImage = true and LCase(SafeString(slot.poster.loadStatus, "")) = "ready" then
            slot.group.visible = true
        else if LCase(SafeString(slot.poster.loadStatus, "")) = "failed" then
            slot.group.visible = false
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' hideThumbnails
'-------------------------------------------------------------------------------
sub hideThumbnails()
    for each slot in m.thumbnailSlots
        slot.hasImage = false
        slot.group.visible = false
    end for
end sub

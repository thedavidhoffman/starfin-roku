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
            posterId: "thumbnailPoster0"
            background: m.top.findNode("thumbnailBackground0")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup1")
            imageMask: m.top.findNode("thumbnailImageMask1")
            clip: m.top.findNode("thumbnailClip1")
            poster: m.top.findNode("thumbnailPoster1")
            posterId: "thumbnailPoster1"
            background: m.top.findNode("thumbnailBackground1")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup2")
            imageMask: m.top.findNode("thumbnailImageMask2")
            clip: m.top.findNode("thumbnailClip2")
            poster: m.top.findNode("thumbnailPoster2")
            posterId: "thumbnailPoster2"
            background: m.top.findNode("thumbnailBackground2")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup3")
            imageMask: m.top.findNode("thumbnailImageMask3")
            clip: m.top.findNode("thumbnailClip3")
            poster: m.top.findNode("thumbnailPoster3")
            posterId: "thumbnailPoster3"
            background: m.top.findNode("thumbnailBackground3")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup4")
            imageMask: m.top.findNode("thumbnailImageMask4")
            clip: m.top.findNode("thumbnailClip4")
            poster: m.top.findNode("thumbnailPoster4")
            posterId: "thumbnailPoster4"
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

    layout = getThumbnailLayout(data)
    for i = 0 to m.thumbnailSlots.Count() - 1
        if i < data.images.Count() then
            updateThumbnailSlot(m.thumbnailSlots[i], data.images[i], i, layout)
        else
            m.thumbnailSlots[i].hasImage = false
            m.thumbnailSlots[i].group.visible = false
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' updateThumbnailSlot
'-------------------------------------------------------------------------------
sub updateThumbnailSlot(slot as object, data as dynamic, slotIndex as integer, layout as object)
    if data = invalid or data.uri = invalid or data.uri = "" then
        slot.hasImage = false
        slot.group.visible = false
        return
    end if

    slot.hasImage = true
    scale = getThumbnailSlotScale(slotIndex, layout)

    tileWidth = layout.tileWidth * scale
    tileHeight = layout.tileHeight * scale
    sheetWidth = data.sheetColumns * tileWidth
    sheetHeight = data.sheetRows * tileHeight

    slot.group.translation = getThumbnailSlotTranslation(slotIndex, tileHeight, layout)
    slot.imageMask.translation = [0, 0]
    slot.imageMask.maskSize = [tileWidth, tileHeight]
    slot.clip.clippingRect = [0, 0, tileWidth, tileHeight]
    slot.background.width = tileWidth
    slot.background.height = tileHeight

    uriChanged = slot.poster.uri <> data.uri
    ' Trickplay previews use sprite sheets, so changing Poster.uri can swap a large image.
    ' Roku can render those large sheet swaps unreliably when reusing the same Poster node.
    ' For large sheets, recreate the Poster first; this matches Jellyfin Roku's safer path.
    if uriChanged = true and data.canUseFastReplace <> true then recreatePoster(slot)

    slot.poster.width = sheetWidth
    slot.poster.height = sheetHeight
    slot.poster.translation = [0 - (data.column * tileWidth), 0 - (data.row * tileHeight)]

    if uriChanged = true then
        slot.group.visible = false
        slot.poster.uri = data.uri
    else
        slot.group.visible = LCase(SafeString(slot.poster.loadStatus, "")) = "ready"
    end if
end sub

'-------------------------------------------------------------------------------
' getThumbnailLayout
'-------------------------------------------------------------------------------
function getThumbnailLayout(data as object) as object
    layoutWidth = data.layoutWidth
    if layoutWidth = invalid or layoutWidth <= 0 then layoutWidth = 1714

    gap = data.gap
    if gap = invalid then gap = 15

    tileWidth = data.tileWidth
    if tileWidth = invalid or tileWidth <= 0 then tileWidth = 384

    tileHeight = data.tileHeight
    if tileHeight = invalid or tileHeight <= 0 then tileHeight = 216

    largeScale = data.largeScale
    if largeScale = invalid or largeScale <= 0 then largeScale = 1.2

    smallScale = data.smallScale
    if smallScale = invalid or smallScale <= 0 then smallScale = 0.7

    return {
        layoutWidth: layoutWidth
        gap: gap
        tileWidth: tileWidth
        tileHeight: tileHeight
        largeScale: largeScale
        smallScale: smallScale
    }
end function

'-------------------------------------------------------------------------------
' getThumbnailSlotScale
'-------------------------------------------------------------------------------
function getThumbnailSlotScale(slotIndex as integer, layout as object) as float
    if slotIndex = 2 then return layout.largeScale
    return layout.smallScale
end function

'-------------------------------------------------------------------------------
' getThumbnailSlotTranslation
'-------------------------------------------------------------------------------
function getThumbnailSlotTranslation(slotIndex as integer, tileHeight as float, layout as object) as object
    largeWidth = layout.tileWidth * layout.largeScale
    smallWidth = layout.tileWidth * layout.smallScale
    largeHeight = layout.tileHeight * layout.largeScale
    totalWidth = largeWidth + (smallWidth * 4) + (layout.gap * 4)
    x = (layout.layoutWidth - totalWidth) / 2

    for i = 0 to slotIndex - 1
        x = x + (layout.tileWidth * getThumbnailSlotScale(i, layout)) + layout.gap
    end for

    y = 0
    if slotIndex <> 2 then y = (largeHeight - tileHeight) / 2

    return [x, y]
end function

'-------------------------------------------------------------------------------
' recreatePoster
'-------------------------------------------------------------------------------
sub recreatePoster(slot as object)
    slot.poster.unobserveField("loadStatus")
    slot.clip.removeChild(slot.poster)

    poster = CreateObject("roSGNode", "Poster")
    poster.id = slot.posterId
    poster.loadDisplayMode = "noScale"
    poster.observeField("loadStatus", "onThumbnailLoadStatusChanged")
    slot.clip.appendChild(poster)
    slot.poster = poster
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

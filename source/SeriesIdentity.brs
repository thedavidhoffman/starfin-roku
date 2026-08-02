'-------------------------------------------------------------------------------
' SeriesIdentity
'-------------------------------------------------------------------------------
' Normalizes TV series context passed between pages and playback flows, keeping
' stable series names and image URLs available even when later handoffs only have
' partial series data.

'-------------------------------------------------------------------------------
' SeriesIdentity_FromItem
'-------------------------------------------------------------------------------
function SeriesIdentity_FromItem(server as string, item as dynamic) as object
    if item = invalid then
        return {
            Id: ""
            Name: ""
            logoUrl: ""
            thumbUrl: ""
            backdropUrl: ""
            detailBackdropUrl: ""
        }
    end if

    return {
        Id: FirstNonEmpty([item.Id], "")
        Name: FirstNonEmpty([item.Name, item.SeriesName], "")
        logoUrl: SeriesIdentity_GetLogoUrl(server, item)
        thumbUrl: SeriesIdentity_GetImageUrl(server, item, "Thumb", 531, 300)
        backdropUrl: SeriesIdentity_GetImageUrl(server, item, "Backdrop", 531, 300)
        detailBackdropUrl: SeriesIdentity_GetDetailBackdropUrl(server, item)
    }
end function

'-------------------------------------------------------------------------------
' SeriesIdentity_GetLogoUrl
'-------------------------------------------------------------------------------
function SeriesIdentity_GetLogoUrl(server as string, item as dynamic) as string
    if item = invalid then return ""

    logoUrl = FirstNonEmpty([item.logoUrl], "")
    if logoUrl <> "" then return logoUrl

    itemId = FirstNonEmpty([item.Id, item.SeriesId], "")
    if itemId = "" then return ""

    tag = ""
    if item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
    if tag = "" then return ""

    return Url_BuildImageUrl(server, itemId, "Logo", tag, 600, 300, { format: "Png" })
end function

'-------------------------------------------------------------------------------
' SeriesIdentity_GetImageUrl
'-------------------------------------------------------------------------------
function SeriesIdentity_GetImageUrl(server as string, item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    cachedUrl = ""
    if imageType = "Thumb" then cachedUrl = FirstNonEmpty([item.thumbUrl], "")
    if imageType = "Backdrop" then cachedUrl = FirstNonEmpty([item.backdropUrl], "")
    if cachedUrl <> "" then return cachedUrl

    itemId = FirstNonEmpty([item.Id, item.SeriesId], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Thumb" and item.ImageTags <> invalid and item.ImageTags.Thumb <> invalid then tag = item.ImageTags.Thumb
    if imageType = "Backdrop" and item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""

    return Url_BuildImageUrl(server, itemId, imageType, tag, width, height, invalid)
end function

'-------------------------------------------------------------------------------
' SeriesIdentity_GetDetailBackdropUrl
'-------------------------------------------------------------------------------
function SeriesIdentity_GetDetailBackdropUrl(server as string, item as dynamic) as string
    if item = invalid then return ""

    detailBackdropUrl = FirstNonEmpty([item.detailBackdropUrl], "")
    if detailBackdropUrl <> "" then return detailBackdropUrl

    itemId = FirstNonEmpty([item.Id, item.SeriesId], "")
    if itemId = "" then return ""

    tag = ""
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""

    return Url_BuildImageUrl(server, itemId, "Backdrop", tag, 1920, 1080, invalid)
end function

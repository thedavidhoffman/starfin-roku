'-------------------------------------------------------------------------------
' MediaMetadata_FormatRating
'-------------------------------------------------------------------------------
function MediaMetadata_FormatRating(value as dynamic) as string
    if value = invalid then return ""

    rating = val(value.ToStr())
    if rating <= 0 then return ""

    return (int((rating * 10) + 0.5) / 10).ToStr()
end function

'-------------------------------------------------------------------------------
' MediaMetadata_BulletSeparator
'-------------------------------------------------------------------------------
function MediaMetadata_BulletSeparator() as string
    return "  •  "
end function

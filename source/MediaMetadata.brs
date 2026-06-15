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
' MediaMetadata_FormatRuntime
'-------------------------------------------------------------------------------
function MediaMetadata_FormatRuntime(runTimeTicks as dynamic) as string
    if runTimeTicks = invalid then return ""

    minutes = int(val(runTimeTicks.ToStr()) / 600000000)
    if minutes <= 0 then return ""

    hours = int(minutes / 60)
    remainingMinutes = minutes mod 60
    if hours > 0 then return hours.ToStr() + "h " + remainingMinutes.ToStr() + "m"
    return minutes.ToStr() + "m"
end function

'-------------------------------------------------------------------------------
' MediaMetadata_BulletSeparator
'-------------------------------------------------------------------------------
function MediaMetadata_BulletSeparator() as string
    return "  •  "
end function

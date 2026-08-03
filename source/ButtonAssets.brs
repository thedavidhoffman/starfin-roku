'-------------------------------------------------------------------------------
' ButtonAssets_GetUri
'-------------------------------------------------------------------------------
function ButtonAssets_GetUri(filename as string) as string
    resolution = "fhd"
    profile = m.global.maskAssetProfile
    if profile <> invalid and profile.resolution = "hd" then resolution = "hd"

    return "pkg:/images/buttons/" + resolution + "/" + filename
end function

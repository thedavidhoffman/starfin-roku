'-------------------------------------------------------------------------------
' ButtonAssets_GetUri
'-------------------------------------------------------------------------------
function ButtonAssets_GetUri(filename as string) as string
    return ResolutionAssets_GetUri("buttons", filename)
end function

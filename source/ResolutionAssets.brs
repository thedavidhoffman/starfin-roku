'-------------------------------------------------------------------------------
' HeaderAssets_GetUri
'-------------------------------------------------------------------------------
function HeaderAssets_GetUri(filename as string) as string
    return ResolutionAssets_GetUri("header", filename)
end function

'-------------------------------------------------------------------------------
' HomepageAssets_GetUri
'-------------------------------------------------------------------------------
function HomepageAssets_GetUri(filename as string) as string
    return ResolutionAssets_GetUri("homepage", filename)
end function

'-------------------------------------------------------------------------------
' IconAssets_GetUri
'-------------------------------------------------------------------------------
function IconAssets_GetUri(filename as string) as string
    return ResolutionAssets_GetUri("icons", filename)
end function

'-------------------------------------------------------------------------------
' ResolutionAssets_GetUri
'-------------------------------------------------------------------------------
function ResolutionAssets_GetUri(category as string, filename as string) as string
    return "pkg:/images/" + category + "/" + ResolutionProfile_GetName() + "/" + filename
end function

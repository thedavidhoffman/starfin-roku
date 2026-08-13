'-------------------------------------------------------------------------------
' MaskAssets_GetProfile
'-------------------------------------------------------------------------------
function MaskAssets_GetProfile(filename as string, fhdSize as object, hdSize as object) as object
    if ResolutionProfile_IsHd() then
        return {
            uri: ResolutionAssets_GetUri("masks", filename)
            size: hdSize
            isHd: true
        }
    end if

    return {
        uri: ResolutionAssets_GetUri("masks", filename)
        size: fhdSize
        isHd: false
    }
end function

'-------------------------------------------------------------------------------
' MaskAssets_Apply
'-------------------------------------------------------------------------------
sub MaskAssets_Apply(maskNode as object, filename as string, fhdSize as object, hdSize as object)
    profile = MaskAssets_GetProfile(filename, fhdSize, hdSize)
    maskNode.maskUri = profile.uri
    maskNode.maskSize = profile.size
end sub

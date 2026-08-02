'-------------------------------------------------------------------------------
' MaskAssets_GetProfile
'-------------------------------------------------------------------------------
function MaskAssets_GetProfile(filename as string, fhdSize as object, hdSize as object) as object
    if MaskAssets_IsHd() then
        return {
            uri: "pkg:/images/masks/hd/" + filename
            size: hdSize
            isHd: true
        }
    end if

    return {
        uri: "pkg:/images/masks/fhd/" + filename
        size: fhdSize
        isHd: false
    }
end function

'-------------------------------------------------------------------------------
' MaskAssets_IsHd
'-------------------------------------------------------------------------------
function MaskAssets_IsHd() as boolean
    profile = m.global.maskAssetProfile
    return profile <> invalid and profile.isHd = true
end function

'-------------------------------------------------------------------------------
' MaskAssets_Apply
'-------------------------------------------------------------------------------
sub MaskAssets_Apply(maskNode as object, filename as string, fhdSize as object, hdSize as object)
    profile = MaskAssets_GetProfile(filename, fhdSize, hdSize)
    maskNode.maskUri = profile.uri
    maskNode.maskSize = profile.size
end sub

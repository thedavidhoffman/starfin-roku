'-------------------------------------------------------------------------------
' MaskAssetProfile_Create
'-------------------------------------------------------------------------------
function MaskAssetProfile_Create() as object
    isHd = false
    deviceInfo = CreateObject("roDeviceInfo")
    if deviceInfo <> invalid then
        uiResolution = deviceInfo.GetUIResolution()
        if type(uiResolution) = "roAssociativeArray" then
            if uiResolution.width <> invalid and uiResolution.height <> invalid then
                if uiResolution.width >= 640 and uiResolution.height >= 360 then isHd = uiResolution.height <= 720
            end if
        end if
    end if

    resolution = "fhd"
    if isHd then resolution = "hd"

    return {
        isHd: isHd
        resolution: resolution
    }
end function

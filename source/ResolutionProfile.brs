'-------------------------------------------------------------------------------
' ResolutionProfile_Create
'-------------------------------------------------------------------------------
function ResolutionProfile_Create() as object
    deviceInfo = CreateObject("roDeviceInfo")
    uiResolution = invalid
    if deviceInfo <> invalid then uiResolution = deviceInfo.GetUIResolution()

    resolution = "fhd"
    if type(uiResolution) = "roAssociativeArray" then
        if uiResolution.width <> invalid and uiResolution.height <> invalid then
            if uiResolution.width >= 640 and uiResolution.height >= 360 and uiResolution.height <= 720 then resolution = "hd"
        end if
    end if

    return {
        isHd: resolution = "hd"
        resolution: resolution
    }
end function

'-------------------------------------------------------------------------------
' ResolutionProfile_IsHd
'-------------------------------------------------------------------------------
function ResolutionProfile_IsHd() as boolean
    return ResolutionProfile_GetName() = "hd"
end function

'-------------------------------------------------------------------------------
' ResolutionProfile_GetName
'-------------------------------------------------------------------------------
function ResolutionProfile_GetName() as string
    profile = m.global.resolutionProfile
    if profile <> invalid and profile.resolution = "hd" then return "hd"
    return "fhd"
end function

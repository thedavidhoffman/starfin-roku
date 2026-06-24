'-------------------------------------------------------------------------------
' DeviceCapabilities_BuildDeviceProfileJson
'-------------------------------------------------------------------------------
function DeviceCapabilities_BuildDeviceProfileJson() as string
    displaySize = DeviceCapabilities_GetDisplaySize()
    return Json_Object([
        Json_Pair("Name", "Starfish Roku")
        Json_NumberPair("MaxStreamingBitrate", 120000000)
        Json_NumberPair("MaxStaticBitrate", 100000000)
        Json_NumberPair("MusicStreamingTranscodingBitrate", 192000)
        Json_String("DirectPlayProfiles") + ":[" + Json_JoinParts(__DeviceCapabilities_DirectPlayProfiles()) + "]"
        Json_String("TranscodingProfiles") + ":[" + Json_JoinParts(__DeviceCapabilities_TranscodingProfiles()) + "]"
        Json_String("ContainerProfiles") + ":[]"
        Json_String("CodecProfiles") + ":[" + Json_JoinParts(__DeviceCapabilities_CodecProfiles(displaySize)) + "]"
        Json_String("SubtitleProfiles") + ":[" + Json_JoinParts(__DeviceCapabilities_SubtitleProfiles()) + "]"
    ])
end function

'-------------------------------------------------------------------------------
' DeviceCapabilities_GetDisplaySize
'-------------------------------------------------------------------------------
function DeviceCapabilities_GetDisplaySize() as object
    fallback = { width: 1920, height: 1080, source: "fallback" }
    deviceInfo = CreateObject("roDeviceInfo")
    if deviceInfo = invalid then return fallback

    displayMode = SafeString(deviceInfo.GetDisplayMode(), "")
    displaySize = __DeviceCapabilities_DisplaySizeFromText(displayMode)
    if __DeviceCapabilities_IsValidDisplaySize(displaySize) then
        displaySize.source = "displayMode"
        return displaySize
    end if

    uiResolution = SafeString(deviceInfo.GetUIResolution(), "")
    displaySize = __DeviceCapabilities_DisplaySizeFromText(uiResolution)
    if __DeviceCapabilities_IsValidDisplaySize(displaySize) then
        displaySize.source = "uiResolution"
        return displaySize
    end if

    return fallback
end function

'-------------------------------------------------------------------------------
' DeviceCapabilities_GetMaxScreenImageSize
'-------------------------------------------------------------------------------
function DeviceCapabilities_GetMaxScreenImageSize() as object
    return DeviceCapabilities_GetDisplaySize()
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_DirectPlayProfiles
'-------------------------------------------------------------------------------
function __DeviceCapabilities_DirectPlayProfiles() as object
    deviceInfo = CreateObject("roDeviceInfo")
    profiles = []
    containers = ["mp4", "hls", "mkv", "ts"]
    videoCodecs = ["h264", "mpeg4 avc", "hevc", "vp9", "mpeg2", "av1"]
    audioCodecs = ["aac", "mp3", "ac3", "eac3", "dts", "flac", "alac", "vorbis", "wma", "pcm"]
    passthroughCodecs = ["ac3", "eac3", "dts"]
    isSurround = deviceInfo.GetAudioOutputChannel() = "5.1 surround"

    for each container in containers
        supportedVideoCodecs = []
        supportedAudioCodecs = []

        for each videoCodec in videoCodecs
            if __DeviceCapabilities_CanDecodeVideo(deviceInfo, videoCodec, container) then
                __DeviceCapabilities_AddVideoCodec(supportedVideoCodecs, videoCodec)
            end if
        end for

        for each audioCodec in audioCodecs
            if __DeviceCapabilities_CanDecodeAudio(deviceInfo, audioCodec, container) or (isSurround and __DeviceCapabilities_Contains(passthroughCodecs, audioCodec)) then
                __DeviceCapabilities_AddUnique(supportedAudioCodecs, audioCodec)
            end if
        end for

        if supportedVideoCodecs.Count() > 0 then
            profiles.Push(__DeviceCapabilities_ProfileJson(__DeviceCapabilities_ContainerAliases(container), supportedVideoCodecs.Join(","), supportedAudioCodecs.Join(",")))
        end if
    end for

    return profiles
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_TranscodingProfiles
'-------------------------------------------------------------------------------
function __DeviceCapabilities_TranscodingProfiles() as object
    deviceInfo = CreateObject("roDeviceInfo")
    maxAudioChannels = "2"
    if deviceInfo.GetAudioOutputChannel() = "5.1 surround" then maxAudioChannels = "6"

    tsAudioCodecs = __DeviceCapabilities_TranscodingAudioCodecs(deviceInfo)
    tsVideoCodecs = __DeviceCapabilities_TranscodingVideoCodecs(deviceInfo, "ts")
    mp4AudioCodecs = __DeviceCapabilities_TranscodingAudioCodecs(deviceInfo)
    mp4VideoCodecs = __DeviceCapabilities_TranscodingVideoCodecs(deviceInfo, "mp4")

    return [
        Json_Object([
            Json_Pair("Container", "ts")
            Json_Pair("Context", "Streaming")
            Json_Pair("Protocol", "hls")
            Json_Pair("Type", "Video")
            Json_Pair("AudioCodec", tsAudioCodecs)
            Json_Pair("VideoCodec", tsVideoCodecs)
            Json_Pair("MaxAudioChannels", maxAudioChannels)
            Json_NumberPair("MinSegments", 1)
            Json_NumberPair("SegmentLength", 6)
            Json_BooleanPair("BreakOnNonKeyFrames", false)
        ])
        Json_Object([
            Json_Pair("Container", "mp4")
            Json_Pair("Context", "Streaming")
            Json_Pair("Protocol", "hls")
            Json_Pair("Type", "Video")
            Json_Pair("AudioCodec", mp4AudioCodecs)
            Json_Pair("VideoCodec", mp4VideoCodecs)
            Json_Pair("MaxAudioChannels", maxAudioChannels)
            Json_NumberPair("MinSegments", 1)
            Json_NumberPair("SegmentLength", 6)
            Json_BooleanPair("BreakOnNonKeyFrames", false)
        ])
    ]
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_CodecProfiles
'-------------------------------------------------------------------------------
function __DeviceCapabilities_CodecProfiles(displaySize as object) as object
    if displaySize = invalid then displaySize = { width: 1920, height: 1080 }

    return [
        Json_Object([
            Json_Pair("Type", "Video")
            Json_String("Conditions") + ":[" + Json_JoinParts([
                __DeviceCapabilities_ProfileConditionJson("LessThanEqual", "Width", displaySize.width.ToStr())
                __DeviceCapabilities_ProfileConditionJson("LessThanEqual", "Height", displaySize.height.ToStr())
            ]) + "]"
            Json_String("ApplyConditions") + ":[]"
        ])
    ]
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_ProfileConditionJson
'-------------------------------------------------------------------------------
function __DeviceCapabilities_ProfileConditionJson(conditionType as string, condition as string, value as string) as string
    return Json_Object([
        Json_Pair("Condition", conditionType)
        Json_Pair("Property", condition)
        Json_Pair("Value", value)
        Json_BooleanPair("IsRequired", true)
    ])
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_SubtitleProfiles
'-------------------------------------------------------------------------------
function __DeviceCapabilities_SubtitleProfiles() as object
    return [
        __DeviceCapabilities_SubtitleProfileJson("srt", "External")
        __DeviceCapabilities_SubtitleProfileJson("vtt", "External")
        __DeviceCapabilities_SubtitleProfileJson("ass", "Encode")
        __DeviceCapabilities_SubtitleProfileJson("ssa", "Encode")
        __DeviceCapabilities_SubtitleProfileJson("pgs", "Encode")
        __DeviceCapabilities_SubtitleProfileJson("dvdsub", "Encode")
        __DeviceCapabilities_SubtitleProfileJson("subrip", "Encode")
    ]
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_SubtitleProfileJson
'-------------------------------------------------------------------------------
function __DeviceCapabilities_SubtitleProfileJson(format as string, method as string) as string
    return Json_Object([
        Json_Pair("Format", format)
        Json_Pair("Method", method)
    ])
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_TranscodingAudioCodecs
'-------------------------------------------------------------------------------
function __DeviceCapabilities_TranscodingAudioCodecs(deviceInfo as object) as string
    codecs = []
    candidates = ["ac3", "eac3", "aac", "mp3", "vorbis", "opus", "flac", "alac", "dts"]

    for each codec in candidates
        if __DeviceCapabilities_CanDecodeAudio(deviceInfo, codec, "ts") or __DeviceCapabilities_CanDecodeAudio(deviceInfo, codec, "mp4") then
            __DeviceCapabilities_AddUnique(codecs, codec)
        end if
    end for

    if codecs.Count() = 0 then codecs.Push("aac")

    return codecs.Join(",")
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_TranscodingVideoCodecs
'-------------------------------------------------------------------------------
function __DeviceCapabilities_TranscodingVideoCodecs(deviceInfo as object, container as string) as string
    codecs = ["h264"]
    candidates = ["mpeg4 avc", "hevc", "vp9", "mpeg2", "av1"]

    for each codec in candidates
        if __DeviceCapabilities_CanDecodeVideo(deviceInfo, codec, container) then
            __DeviceCapabilities_AddVideoCodec(codecs, codec)
        end if
    end for

    return codecs.Join(",")
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_ProfileJson
'-------------------------------------------------------------------------------
function __DeviceCapabilities_ProfileJson(container as string, videoCodec as string, audioCodec as string) as string
    return Json_Object([
        Json_Pair("Container", container)
        Json_Pair("Type", "Video")
        Json_Pair("VideoCodec", videoCodec)
        Json_Pair("AudioCodec", audioCodec)
    ])
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_ContainerAliases
'-------------------------------------------------------------------------------
function __DeviceCapabilities_ContainerAliases(container as string) as string
    if container = "mp4" then return "mp4,mov,m4v"
    if container = "mkv" then return "mkv,webm"
    return container
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_CanDecodeVideo
'-------------------------------------------------------------------------------
function __DeviceCapabilities_CanDecodeVideo(deviceInfo as object, codec as string, container as string) as boolean
    result = deviceInfo.CanDecodeVideo({ Codec: codec, Container: container })
    return result <> invalid and result.Result = true
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_CanDecodeAudio
'-------------------------------------------------------------------------------
function __DeviceCapabilities_CanDecodeAudio(deviceInfo as object, codec as string, container as string) as boolean
    result = deviceInfo.CanDecodeAudio({ Codec: codec, Container: container })
    return result <> invalid and result.Result = true
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_DisplaySizeFromText
'-------------------------------------------------------------------------------
function __DeviceCapabilities_DisplaySizeFromText(value as string) as object
    text = LCase(SafeString(value, ""))
    if text = "" then return invalid

    if Instr(1, text, "2160") > 0 or Instr(1, text, "4k") > 0 or Instr(1, text, "uhd") > 0 then return { width: 3840, height: 2160 }
    if Instr(1, text, "1080") > 0 or Instr(1, text, "fhd") > 0 then return { width: 1920, height: 1080 }
    if Instr(1, text, "720") > 0 or Instr(1, text, "hd") > 0 then return { width: 1280, height: 720 }
    if Instr(1, text, "480") > 0 or Instr(1, text, "sd") > 0 then return { width: 720, height: 480 }

    return invalid
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_IsValidDisplaySize
'-------------------------------------------------------------------------------
function __DeviceCapabilities_IsValidDisplaySize(displaySize as dynamic) as boolean
    if displaySize = invalid then return false
    if displaySize.width = invalid or displaySize.height = invalid then return false
    if displaySize.width < 640 or displaySize.height < 360 then return false

    return true
end function

'-------------------------------------------------------------------------------
' __DeviceCapabilities_AddVideoCodec
'-------------------------------------------------------------------------------
sub __DeviceCapabilities_AddVideoCodec(values as object, codec as string)
    if codec = "hevc" then
        __DeviceCapabilities_AddUnique(values, "hevc")
        __DeviceCapabilities_AddUnique(values, "h265")
    else if codec = "mpeg2" then
        __DeviceCapabilities_AddUnique(values, "mpeg2video")
    else
        __DeviceCapabilities_AddUnique(values, codec)
    end if
end sub

'-------------------------------------------------------------------------------
' __DeviceCapabilities_AddUnique
'-------------------------------------------------------------------------------
sub __DeviceCapabilities_AddUnique(values as object, value as string)
    if __DeviceCapabilities_Contains(values, value) then return
    values.Push(value)
end sub

'-------------------------------------------------------------------------------
' __DeviceCapabilities_Contains
'-------------------------------------------------------------------------------
function __DeviceCapabilities_Contains(values as object, value as string) as boolean
    for each currentValue in values
        if currentValue = value then return true
    end for

    return false
end function

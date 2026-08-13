'-------------------------------------------------------------------------------
' PlaybackMode_Values
'-------------------------------------------------------------------------------
function PlaybackMode_Values() as object
    return {
        automatic: "automatic"
        automaticNoRemux: "automatic-no-remux"
        transcodeAllowRemux: "transcode-allow-remux"
        transcodeNoRemux: "transcode-no-remux"
    }
end function

'-------------------------------------------------------------------------------
' PlaybackMode_Normalize
'-------------------------------------------------------------------------------
function PlaybackMode_Normalize(value as dynamic) as string
    modes = PlaybackMode_Values()
    if value = invalid then return modes.automatic
    mode = value.ToStr()
    if mode = modes.automatic or mode = modes.automaticNoRemux or mode = modes.transcodeAllowRemux or mode = modes.transcodeNoRemux then return mode
    return modes.automatic
end function

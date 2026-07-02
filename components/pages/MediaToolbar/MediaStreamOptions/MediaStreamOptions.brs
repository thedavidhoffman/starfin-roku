'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
end sub

'-------------------------------------------------------------------------------
' openSubtitleOptions
'-------------------------------------------------------------------------------
sub openSubtitleOptions(request as dynamic)
    if request = invalid then return

    m.top.visible = true
    m.top.overlayRequested = {
        id: "subtitleOptions"
        componentName: "SubtitleOptionsDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        subtitleStreams: getRequestArray(request.subtitleStreams)
        selectedSubtitleStreamIndex: getRequestInteger(request.selectedSubtitleStreamIndex, -2)
    }
end sub

'-------------------------------------------------------------------------------
' openAudioOptions
'-------------------------------------------------------------------------------
sub openAudioOptions(request as dynamic)
    if request = invalid then return

    m.top.visible = true
    m.top.overlayRequested = {
        id: "audioOptions"
        componentName: "AudioOptionsDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        audioStreams: getRequestArray(request.audioStreams)
        selectedAudioStreamIndex: getRequestInteger(request.selectedAudioStreamIndex, -1)
    }
end sub

'-------------------------------------------------------------------------------
' closeOptions
'-------------------------------------------------------------------------------
sub closeOptions()
    m.top.visible = false
    m.top.closeRequested = true
end sub

'-------------------------------------------------------------------------------
' applySubtitleSelection
'-------------------------------------------------------------------------------
sub applySubtitleSelection(selection as dynamic)
    if selection = invalid then return

    m.top.selectedSubtitle = selection
end sub

'-------------------------------------------------------------------------------
' applyAudioSelection
'-------------------------------------------------------------------------------
sub applyAudioSelection(selection as dynamic)
    if selection = invalid then return

    m.top.selectedAudio = selection
end sub

'-------------------------------------------------------------------------------
' getRequestArray
'-------------------------------------------------------------------------------
function getRequestArray(value as dynamic) as object
    if value = invalid then return []
    return value
end function

'-------------------------------------------------------------------------------
' getRequestInteger
'-------------------------------------------------------------------------------
function getRequestInteger(value as dynamic, fallback as integer) as integer
    if value = invalid then return fallback
    return int(value)
end function

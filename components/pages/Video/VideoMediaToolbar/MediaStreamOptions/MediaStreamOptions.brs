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

    subtitleStreams = getRequestArray(request.subtitleStreams)
    m.top.visible = true
    m.top.overlayRequested = {
        id: "subtitleOptions"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Subtitles"
        options: MediaOptions_BuildSubtitleOptions(subtitleStreams)
        selectedKey: getRequestInteger(request.selectedSubtitleStreamIndex, -2).ToStr()
        emptyText: "No subtitles available."
    }
end sub

'-------------------------------------------------------------------------------
' openAudioOptions
'-------------------------------------------------------------------------------
sub openAudioOptions(request as dynamic)
    if request = invalid then return

    audioStreams = getRequestArray(request.audioStreams)
    m.top.visible = true
    m.top.overlayRequested = {
        id: "audioOptions"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Audio"
        options: MediaOptions_BuildAudioOptions(audioStreams)
        selectedKey: getRequestInteger(request.selectedAudioStreamIndex, -1).ToStr()
        emptyText: "No audio tracks available."
    }
end sub

'-------------------------------------------------------------------------------
' openChapterOptions
'-------------------------------------------------------------------------------
sub openChapterOptions(request as dynamic)
    if request = invalid then return

    m.top.visible = true
    m.top.overlayRequested = {
        id: "chapterOptions"
        componentName: "OptionPickerDialog"
        openFunction: "openOptions"
        closeField: "closeRequested"
        dialogTitle: "Chapters"
        options: MediaOptions_BuildChapterOptions(getRequestArray(request.chapters))
        selectedKey: SafeString(request.selectedChapterKey, "")
        allowDefaultSelection: false
        emptyText: "No chapters available."
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
' applyChapterSelection
'-------------------------------------------------------------------------------
sub applyChapterSelection(selection as dynamic)
    if selection = invalid then return

    m.top.selectedChapter = selection
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

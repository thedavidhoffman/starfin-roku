'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.subtitleOptions = m.top.findNode("subtitleOptions")
    m.audioOptions = m.top.findNode("audioOptions")

    m.subtitleOptions.observeField("selectedSubtitle", "onSubtitleOptionSelected")
    m.subtitleOptions.observeField("closeRequested", "onOptionsCloseRequested")
    m.audioOptions.observeField("selectedAudio", "onAudioOptionSelected")
    m.audioOptions.observeField("closeRequested", "onOptionsCloseRequested")
end sub

'-------------------------------------------------------------------------------
' openSubtitleOptions
'-------------------------------------------------------------------------------
sub openSubtitleOptions(request as dynamic)
    if request = invalid then return

    closeActiveOptions(false)
    m.top.visible = true
    m.subtitleOptions.subtitleStreams = getRequestArray(request.subtitleStreams)
    m.subtitleOptions.selectedSubtitleStreamIndex = getRequestInteger(request.selectedSubtitleStreamIndex, -2)
    m.subtitleOptions.callFunc("openOptions")
end sub

'-------------------------------------------------------------------------------
' openAudioOptions
'-------------------------------------------------------------------------------
sub openAudioOptions(request as dynamic)
    if request = invalid then return

    closeActiveOptions(false)
    m.top.visible = true
    m.audioOptions.audioStreams = getRequestArray(request.audioStreams)
    m.audioOptions.selectedAudioStreamIndex = getRequestInteger(request.selectedAudioStreamIndex, -1)
    m.audioOptions.callFunc("openOptions")
end sub

'-------------------------------------------------------------------------------
' closeOptions
'-------------------------------------------------------------------------------
sub closeOptions()
    closeActiveOptions(true)
end sub

'-------------------------------------------------------------------------------
' closeActiveOptions
'-------------------------------------------------------------------------------
sub closeActiveOptions(notify as boolean)
    if m.subtitleOptions.visible = true then m.subtitleOptions.visible = false
    if m.audioOptions.visible = true then m.audioOptions.visible = false

    m.top.visible = false
    if notify = true then m.top.closeRequested = true
end sub

'-------------------------------------------------------------------------------
' onSubtitleOptionSelected
'-------------------------------------------------------------------------------
sub onSubtitleOptionSelected()
    selection = m.subtitleOptions.selectedSubtitle
    if selection = invalid then return

    m.top.selectedSubtitle = selection
end sub

'-------------------------------------------------------------------------------
' onAudioOptionSelected
'-------------------------------------------------------------------------------
sub onAudioOptionSelected()
    selection = m.audioOptions.selectedAudio
    if selection = invalid then return

    m.top.selectedAudio = selection
end sub

'-------------------------------------------------------------------------------
' onOptionsCloseRequested
'-------------------------------------------------------------------------------
sub onOptionsCloseRequested()
    closeActiveOptions(true)
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

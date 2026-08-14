'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.propertySheet = m.top.findNode("propertySheet")
end sub

'-------------------------------------------------------------------------------
' focusInformation
'-------------------------------------------------------------------------------
sub focusInformation()
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' render
'-------------------------------------------------------------------------------
sub render()
    info = m.top.playbackInfo
    if info = invalid then info = {}

    childCount = m.propertySheet.getChildCount()
    if childCount > 0 then m.propertySheet.removeChildrenIndex(0, childCount)

    hasLiveStream = SafeString(info.liveStreamId, "") <> ""
    sectionGap = 50
    if hasLiveStream then sectionGap = 28
    transcodeReason = displayValue(info.transcodeReason)

    y = 0
    y = addSectionHeader("Transcoding Information", y)
    y = addPropertyRow("Playback mode", playbackModeText(info.playbackMode), y)
    y = addPropertyRow("Play method", playMethodText(info.playMethod), y)
    y = addPropertyRow("Reason", transcodeReason, y)
    y = addPropertyRow("Delivery format", UCase(displayValue(info.streamFormat)), y)

    y = y + sectionGap
    y = addSectionHeader("Stream Information", y)
    y = addPropertyRow("Container", UCase(displayValue(info.container)), y)
    y = addPropertyRow("Resolution", resolutionText(info), y)
    y = addPropertyRow("Video", streamText(info.videoCodec, info.videoBitrate), y)
    y = addPropertyRow("Audio", audioText(info), y)
    y = addPropertyRow("Video stream", streamTitleText(info.videoStreamTitle, info.videoStreamIndex, "Default"), y)
    y = addPropertyRow("Audio stream", streamTitleText(info.audioStreamTitle, info.audioStreamIndex, "Default"), y)
    y = addPropertyRow("Subtitle stream", streamTitleText(info.subtitleStreamTitle, info.subtitleStreamIndex, "Off"), y)

    y = y + sectionGap
    y = addSectionHeader("Session Identity", y)
    y = addPropertyRow("Item ID", displayValue(info.itemId), y)
    y = addPropertyRow("Play session ID", displayValue(info.playSessionId), y)
    y = addPropertyRow("Media source ID", displayValue(info.mediaSourceId), y)
    if hasLiveStream then
        addPropertyRow("Live stream ID", displayValue(info.liveStreamId), y)
    end if
end sub

'-------------------------------------------------------------------------------
' playMethodText
'-------------------------------------------------------------------------------
function playMethodText(value as dynamic) as string
    method = LCase(SafeString(value, ""))
    if method = "directplay" then return "Direct Play"
    if method = "directstream" then return "Direct Stream"
    if method = "transcode" then return "Transcode"
    return displayValue(value)
end function

'-------------------------------------------------------------------------------
' addSectionHeader
'-------------------------------------------------------------------------------
function addSectionHeader(title as string, y as integer) as integer
    accentColor = &hF2C27FFF
    heading = CreateObject("roSGNode", "Label")
    heading.translation = [0, y]
    heading.width = 1032
    heading.height = 32
    heading.text = UCase(title)
    heading.color = accentColor
    heading.font = "font:SmallerBoldSystemFont"
    m.propertySheet.appendChild(heading)

    rule = CreateObject("roSGNode", "Rectangle")
    rule.translation = [0, y + 34]
    rule.width = 1032
    rule.height = 2
    rule.color = accentColor
    m.propertySheet.appendChild(rule)

    return y + 42
end function

'-------------------------------------------------------------------------------
' addPropertyRow
'-------------------------------------------------------------------------------
function addPropertyRow(keyText as string, valueText as string, y as integer) as integer
    rowHeight = 36

    keyLabel = CreateObject("roSGNode", "Label")
    keyLabel.translation = [0, y]
    keyLabel.width = 280
    keyLabel.height = rowHeight - 1
    keyLabel.text = UCase(keyText)
    keyLabel.color = Color().text.light.secondary
    keyLabel.font = "font:SmallerBoldSystemFont"
    keyLabel.vertAlign = "center"
    m.propertySheet.appendChild(keyLabel)

    valueLabel = CreateObject("roSGNode", "Label")
    valueLabel.translation = [304, y]
    valueLabel.width = 728
    valueLabel.height = rowHeight - 1
    valueLabel.text = valueText
    valueLabel.color = &hD7DFEAFF
    valueLabel.font = "font:SmallerSystemFont"
    valueLabel.vertAlign = "center"
    valueLabel.wrap = false
    valueLabel.numLines = 1
    m.propertySheet.appendChild(valueLabel)

    separator = CreateObject("roSGNode", "Rectangle")
    separator.translation = [0, y + rowHeight - 1]
    separator.width = 1032
    separator.height = 1
    separator.color = &hF3F7FB1F
    m.propertySheet.appendChild(separator)

    return y + rowHeight
end function

'-------------------------------------------------------------------------------
' playbackModeText
'-------------------------------------------------------------------------------
function playbackModeText(value as dynamic) as string
    mode = LCase(SafeString(value, ""))
    modes = PlaybackMode_Values()
    if mode = LCase(modes.automatic) then return "Automatic"
    if mode = LCase(modes.automaticNoRemux) then return "Automatic — Remux Disabled"
    if mode = LCase(modes.transcodeAllowRemux) then return "Force Transcode — Remux Allowed"
    if mode = LCase(modes.transcodeNoRemux) then return "Force Transcode — Remux Disabled"
    return "Not available"
end function

'-------------------------------------------------------------------------------
' displayValue
'-------------------------------------------------------------------------------
function displayValue(value as dynamic) as string
    text = SafeString(value, "")
    if text = "" then return "Not available"
    return text
end function

'-------------------------------------------------------------------------------
' resolutionText
'-------------------------------------------------------------------------------
function resolutionText(info as object) as string
    width = Number_ToInteger(info.width, 0)
    height = Number_ToInteger(info.height, 0)
    if width <= 0 or height <= 0 then return "Not available"
    return width.ToStr() + " × " + height.ToStr()
end function

'-------------------------------------------------------------------------------
' streamText
'-------------------------------------------------------------------------------
function streamText(codec as dynamic, bitrate as dynamic) as string
    text = UCase(displayValue(codec))
    bitrateText = bitrateDisplay(bitrate)
    if bitrateText <> "" then text = text + "  •  " + bitrateText
    return text
end function

'-------------------------------------------------------------------------------
' audioText
'-------------------------------------------------------------------------------
function audioText(info as object) as string
    text = streamText(info.audioCodec, info.audioBitrate)
    channels = Number_ToInteger(info.audioChannels, 0)
    if channels > 0 then text = text + "  •  " + channels.ToStr() + " channels"
    return text
end function

'-------------------------------------------------------------------------------
' bitrateDisplay
'-------------------------------------------------------------------------------
function bitrateDisplay(value as dynamic) as string
    bitrate = Number_ToInteger(value, 0)
    if bitrate <= 0 then return ""
    if bitrate >= 1000000 then return Number_ToInteger(bitrate / 1000000, 0).ToStr() + " Mbps"
    return Number_ToInteger(bitrate / 1000, 0).ToStr() + " Kbps"
end function

'-------------------------------------------------------------------------------
' indexText
'-------------------------------------------------------------------------------
function indexText(value as dynamic, fallback as string) as string
    index = Number_ToInteger(value, -1)
    if index < 0 then return fallback
    return index.ToStr()
end function

'-------------------------------------------------------------------------------
' streamTitleText
'-------------------------------------------------------------------------------
function streamTitleText(title as dynamic, index as dynamic, fallback as string) as string
    text = SafeString(title, "")
    if text <> "" then return text
    return indexText(index, fallback)
end function

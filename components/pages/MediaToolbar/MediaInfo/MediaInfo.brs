'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.headerLabel = m.top.findNode("headerLabel")
    m.streamTitleLabel = m.top.findNode("streamTitleLabel")
    m.streamTextLabel = m.top.findNode("streamTextLabel")
    m.pageLabel = m.top.findNode("pageLabel")
    m.leftChevron = m.top.findNode("leftChevron")
    m.rightChevron = m.top.findNode("rightChevron")
    m.state = {
        pages: []
        pageIndex: 0
    }
end sub

'-------------------------------------------------------------------------------
' openMediaInfo
'-------------------------------------------------------------------------------
sub openMediaInfo()
    buildPages()
    renderPage()
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onItemChanged
'-------------------------------------------------------------------------------
sub onItemChanged()
    buildPages()
    renderPage()
end sub

'-------------------------------------------------------------------------------
' buildPages
'-------------------------------------------------------------------------------
sub buildPages()
    item = m.top.item
    m.headerLabel.text = buildHeaderText(item)
    m.state.pages = buildStreamPages(item)
    m.state.pageIndex = 0
end sub

'-------------------------------------------------------------------------------
' renderPage
'-------------------------------------------------------------------------------
sub renderPage()
    pageCount = m.state.pages.Count()
    if pageCount = 0 then
        m.streamTitleLabel.text = "Media Info"
        m.streamTextLabel.text = "No stream information available."
        m.pageLabel.text = ""
        m.leftChevron.visible = false
        m.rightChevron.visible = false
        return
    end if

    if m.state.pageIndex < 0 then m.state.pageIndex = 0
    if m.state.pageIndex >= pageCount then m.state.pageIndex = pageCount - 1

    page = m.state.pages[m.state.pageIndex]
    m.streamTitleLabel.text = page.title
    m.streamTextLabel.text = page.text
    m.pageLabel.text = (m.state.pageIndex + 1).ToStr() + " / " + pageCount.ToStr()
    m.leftChevron.visible = m.state.pageIndex > 0
    m.rightChevron.visible = m.state.pageIndex < pageCount - 1
end sub

'-------------------------------------------------------------------------------
' buildHeaderText
'-------------------------------------------------------------------------------
function buildHeaderText(item as dynamic) as string
    if item = invalid then return "Media"

    mediaSource = getFirstMediaSource(item)
    title = ""
    if mediaSource <> invalid then title = FirstNonEmpty([mediaSource.Name], "")
    if title = "" then title = FirstNonEmpty([item.Name], "Media")

    lines = [title]
    if mediaSource <> invalid then
        appendTextField(lines, "Container", mediaSource.Container)
        appendTextField(lines, "Path", mediaSource.Path)
        appendTextField(lines, "Size", formatSize(mediaSource.Size))
    end if

    return joinLines(lines)
end function

'-------------------------------------------------------------------------------
' buildStreamPages
'-------------------------------------------------------------------------------
function buildStreamPages(item as dynamic) as object
    streams = getMediaStreams(item)
    pages = []
    appendStreamPages(pages, streams, "video")
    appendStreamPages(pages, streams, "audio")
    appendStreamPages(pages, streams, "subtitle")
    return pages
end function

'-------------------------------------------------------------------------------
' appendStreamPages
'-------------------------------------------------------------------------------
sub appendStreamPages(pages as object, streams as object, streamType as string)
    for each stream in streams
        if stream = invalid then continue for
        if LCase(SafeString(stream.Type, "")) <> streamType then continue for

        pages.Push({
            title: getStreamPageTitle(streamType)
            text: buildStreamText(stream, streamType)
        })
    end for
end sub

'-------------------------------------------------------------------------------
' buildStreamText
'-------------------------------------------------------------------------------
function buildStreamText(stream as dynamic, streamType as string) as string
    lines = []

    if streamType = "video" then
        appendTextField(lines, "Title", FirstNonEmpty([stream.DisplayTitle, stream.Title], ""))
        appendTextField(lines, "Codec", stream.Codec)
        appendBoolField(lines, "AVC", stream.IsAVC)
        appendTextField(lines, "Profile", stream.Profile)
        appendTextField(lines, "Level", stream.Level)
        appendTextField(lines, "Resolution", getResolutionText(stream))
        appendTextField(lines, "Aspect ratio", stream.AspectRatio)
        appendBoolField(lines, "Anamorphic", stream.IsAnamorphic)
        appendBoolField(lines, "Interlaced", stream.IsInterlaced)
        appendTextField(lines, "Framerate", FirstNonEmpty([stream.RealFrameRate, stream.AverageFrameRate], ""))
        appendTextField(lines, "Bitrate", formatBitrate(stream.BitRate))
        appendTextField(lines, "Bit depth", formatBitDepth(stream.BitDepth))
        ' appendTextField(lines, "Video range", stream.VideoRange)
        ' appendTextField(lines, "Video range type", stream.VideoRangeType)
        ' appendTextField(lines, "Pixel format", stream.PixelFormat)
        ' appendTextField(lines, "Ref frames", stream.RefFrames)
    else if streamType = "audio" then
        appendTextField(lines, "Title", FirstNonEmpty([stream.DisplayTitle, stream.Title], ""))
        appendTextField(lines, "Language", stream.Language)
        appendTextField(lines, "Codec", stream.Codec)
        appendBoolField(lines, "AVC", stream.IsAVC)
        appendTextField(lines, "Layout", stream.ChannelLayout)
        appendTextField(lines, "Channels", formatChannels(stream.Channels))
        appendTextField(lines, "Bitrate", formatBitrate(stream.BitRate))
        appendTextField(lines, "Sample rate", formatSampleRate(stream.SampleRate))
        appendBoolField(lines, "Default", stream.IsDefault)
        appendBoolField(lines, "Forced", stream.IsForced)
        appendBoolField(lines, "External", stream.IsExternal)
    else if streamType = "subtitle" then
        appendTextField(lines, "Title", FirstNonEmpty([stream.DisplayTitle, stream.Title], ""))
        appendTextField(lines, "Language", stream.Language)
        appendTextField(lines, "Codec", stream.Codec)
        appendBoolField(lines, "AVC", stream.IsAVC)
        appendBoolField(lines, "Default", stream.IsDefault)
        appendBoolField(lines, "Forced", stream.IsForced)
        appendBoolField(lines, "External", stream.IsExternal)
    end if

    if lines.Count() = 0 then return "No details available."
    return joinLines(lines)
end function

'-------------------------------------------------------------------------------
' getFirstMediaSource
'-------------------------------------------------------------------------------
function getFirstMediaSource(item as dynamic) as dynamic
    if item = invalid then return invalid
    if item.MediaSources = invalid then return invalid
    if item.MediaSources.Count() = 0 then return invalid
    return item.MediaSources[0]
end function

'-------------------------------------------------------------------------------
' getMediaStreams
'-------------------------------------------------------------------------------
function getMediaStreams(item as dynamic) as object
    mediaSource = getFirstMediaSource(item)
    if mediaSource <> invalid and mediaSource.MediaStreams <> invalid then return mediaSource.MediaStreams
    if item <> invalid and item.MediaStreams <> invalid then return item.MediaStreams
    return []
end function

'-------------------------------------------------------------------------------
' getStreamPageTitle
'-------------------------------------------------------------------------------
function getStreamPageTitle(streamType as string) as string
    if streamType = "video" then return "Video"
    if streamType = "audio" then return "Audio"
    return "Subtitle"
end function

'-------------------------------------------------------------------------------
' appendTextField
'-------------------------------------------------------------------------------
sub appendTextField(lines as object, label as string, value as dynamic)
    text = FirstNonEmpty([value], "")
    if text = "" then return

    lines.Push(label + ": " + text)
end sub

'-------------------------------------------------------------------------------
' appendBoolField
'-------------------------------------------------------------------------------
sub appendBoolField(lines as object, label as string, value as dynamic)
    if value = invalid then return

    text = "No"
    if value = true then text = "Yes"
    lines.Push(label + ": " + text)
end sub

'-------------------------------------------------------------------------------
' getResolutionText
'-------------------------------------------------------------------------------
function getResolutionText(stream as dynamic) as string
    if stream.Width = invalid or stream.Height = invalid then return ""
    return SafeString(stream.Width, "") + "x" + SafeString(stream.Height, "")
end function

'-------------------------------------------------------------------------------
' formatSize
'-------------------------------------------------------------------------------
function formatSize(value as dynamic) as string
    if value = invalid then return ""

    bytes = value
    if bytes >= 1073741824 then return formatOneDecimal(bytes, 1073741824) + " GiB"
    if bytes >= 1048576 then return formatOneDecimal(bytes, 1048576) + " MiB"
    return SafeString(value, "") + " bytes"
end function

'-------------------------------------------------------------------------------
' formatOneDecimal
'-------------------------------------------------------------------------------
function formatOneDecimal(value as dynamic, divisor as dynamic) as string
    tenths = int(((value / divisor) * 10) + 0.5)
    whole = int(tenths / 10)
    decimal = tenths - (whole * 10)
    return whole.ToStr() + "." + decimal.ToStr()
end function

'-------------------------------------------------------------------------------
' formatBitrate
'-------------------------------------------------------------------------------
function formatBitrate(value as dynamic) as string
    if value = invalid then return ""
    if value >= 1000 then return int(value / 1000).ToStr() + " kbps"
    return SafeString(value, "") + " bps"
end function

'-------------------------------------------------------------------------------
' formatBitDepth
'-------------------------------------------------------------------------------
function formatBitDepth(value as dynamic) as string
    if value = invalid then return ""
    return SafeString(value, "") + " bit"
end function

'-------------------------------------------------------------------------------
' formatChannels
'-------------------------------------------------------------------------------
function formatChannels(value as dynamic) as string
    if value = invalid then return ""
    return SafeString(value, "") + " ch"
end function

'-------------------------------------------------------------------------------
' formatSampleRate
'-------------------------------------------------------------------------------
function formatSampleRate(value as dynamic) as string
    if value = invalid then return ""
    return SafeString(value, "") + " Hz"
end function

'-------------------------------------------------------------------------------
' joinLines
'-------------------------------------------------------------------------------
function joinLines(lines as object) as string
    text = ""
    for each line in lines
        if text <> "" then text = text + Chr(10)
        text = text + SafeString(line, "")
    end for

    return text
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    if key = "left" and m.state.pageIndex > 0 then
        m.state.pageIndex = m.state.pageIndex - 1
        renderPage()
        return true
    end if

    if key = "right" and m.state.pageIndex < m.state.pages.Count() - 1 then
        m.state.pageIndex = m.state.pageIndex + 1
        renderPage()
        return true
    end if

    return false
end function

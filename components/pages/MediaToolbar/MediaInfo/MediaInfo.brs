'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.nodes = {
        headerLabel: m.top.findNode("headerLabel")
        sourceTitleLabel: m.top.findNode("sourceTitleLabel")
        sourceTextLabel: m.top.findNode("sourceTextLabel")
        videoTitleLabel: m.top.findNode("videoTitleLabel")
        videoSummaryLabel: m.top.findNode("videoSummaryLabel")
        videoDetailsLabel: m.top.findNode("videoDetailsLabel")
        audioTitleLabel: m.top.findNode("audioTitleLabel")
        audioSummaryLabel: m.top.findNode("audioSummaryLabel")
        audioDetailsLabel: m.top.findNode("audioDetailsLabel")
        subtitleTitleLabel: m.top.findNode("subtitleTitleLabel")
        subtitleSummaryLabel: m.top.findNode("subtitleSummaryLabel")
        subtitleDetailsLabel: m.top.findNode("subtitleDetailsLabel")
        pageLabel: m.top.findNode("pageLabel")
        leftChevron: m.top.findNode("leftChevron")
        rightChevron: m.top.findNode("rightChevron")
    }
    m.state = {
        cards: {
            video: []
            audio: []
            subtitle: []
        }
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
    m.nodes.headerLabel.text = buildHeaderText(item)
    source = buildSourceSummary(item)
    m.nodes.sourceTitleLabel.text = source.title
    m.nodes.sourceTextLabel.text = source.text
    m.state.cards = buildStreamCards(item)
    m.state.pageIndex = 0
end sub

'-------------------------------------------------------------------------------
' renderPage
'-------------------------------------------------------------------------------
sub renderPage()
    pageCount = getPageCount(m.state.cards)
    if pageCount = 0 then
        renderEmptyCard("video", "Video")
        renderEmptyCard("audio", "Audio")
        renderEmptyCard("subtitle", "Subtitles")
        m.nodes.pageLabel.text = "No stream information available."
        m.nodes.leftChevron.visible = false
        m.nodes.rightChevron.visible = false
        return
    end if

    if m.state.pageIndex < 0 then m.state.pageIndex = 0
    if m.state.pageIndex >= pageCount then m.state.pageIndex = pageCount - 1

    renderCard("video", "Video", m.state.cards.video, m.state.pageIndex)
    renderCard("audio", "Audio", m.state.cards.audio, m.state.pageIndex)
    renderCard("subtitle", "Subtitles", m.state.cards.subtitle, m.state.pageIndex)
    m.nodes.pageLabel.text = getPageText(pageCount)
    m.nodes.leftChevron.visible = m.state.pageIndex > 0
    m.nodes.rightChevron.visible = m.state.pageIndex < pageCount - 1
end sub

'-------------------------------------------------------------------------------
' buildHeaderText
'-------------------------------------------------------------------------------
function buildHeaderText(item as dynamic) as string
    if item = invalid then return "Media"

    mediaSource = getFirstMediaSource(item)
    title = FirstNonEmpty([item.Name], "Media")
    if mediaSource <> invalid then title = FirstNonEmpty([mediaSource.Name, title], "Media")

    return title
end function

'-------------------------------------------------------------------------------
' buildSourceSummary
'-------------------------------------------------------------------------------
function buildSourceSummary(item as dynamic) as object
    mediaSource = getFirstMediaSource(item)
    if mediaSource = invalid then
        return {
            title: "Source"
            text: "No media source details available."
        }
    end if

    parts = []
    appendPart(parts, mediaSource.Container)
    appendPart(parts, formatSize(mediaSource.Size))
    sourceTitle = joinParts(parts, "  /  ")
    if sourceTitle = "" then sourceTitle = "Source"

    path = FirstNonEmpty([mediaSource.Path], "")
    if path = "" then path = "No source path available."

    return {
        title: sourceTitle
        text: path
    }
end function

'-------------------------------------------------------------------------------
' buildStreamCards
'-------------------------------------------------------------------------------
function buildStreamCards(item as dynamic) as object
    streams = getMediaStreams(item)
    cards = {
        video: []
        audio: []
        subtitle: []
    }
    appendStreamCards(cards, streams, "video")
    appendStreamCards(cards, streams, "audio")
    appendStreamCards(cards, streams, "subtitle")
    return cards
end function

'-------------------------------------------------------------------------------
' appendStreamCards
'-------------------------------------------------------------------------------
sub appendStreamCards(cards as object, streams as object, streamType as string)
    for each stream in streams
        if stream = invalid then continue for
        if LCase(SafeString(stream.Type, "")) <> streamType then continue for

        cards[streamType].Push(buildStreamCard(stream, streamType))
    end for
end sub

'-------------------------------------------------------------------------------
' buildStreamCard
'-------------------------------------------------------------------------------
function buildStreamCard(stream as dynamic, streamType as string) as object
    return {
        title: getStreamTitle(stream, streamType)
        summary: buildStreamSummary(stream, streamType)
        details: buildStreamDetails(stream, streamType)
    }
end function

'-------------------------------------------------------------------------------
' buildStreamDetails
'-------------------------------------------------------------------------------
function buildStreamDetails(stream as dynamic, streamType as string) as string
    lines = []

    if streamType = "video" then
        appendTextField(lines, "Codec", stream.Codec)
        appendTextField(lines, "Profile", stream.Profile)
        appendTextField(lines, "Level", stream.Level)
        appendTextField(lines, "Aspect ratio", stream.AspectRatio)
        appendBoolField(lines, "Anamorphic", stream.IsAnamorphic)
        appendBoolField(lines, "Interlaced", stream.IsInterlaced)
        appendTextField(lines, "Bitrate", formatBitrate(stream.BitRate))
        appendTextField(lines, "Bit depth", formatBitDepth(stream.BitDepth))
        appendTextField(lines, "Range", stream.VideoRange)
        appendTextField(lines, "Pixel format", stream.PixelFormat)
    else if streamType = "audio" then
        appendTextField(lines, "Language", stream.Language)
        appendTextField(lines, "Codec", stream.Codec)
        appendTextField(lines, "Layout", stream.ChannelLayout)
        appendTextField(lines, "Bitrate", formatBitrate(stream.BitRate))
        appendTextField(lines, "Sample rate", formatSampleRate(stream.SampleRate))
        appendBoolField(lines, "Default", stream.IsDefault)
        appendBoolField(lines, "Forced", stream.IsForced)
        appendBoolField(lines, "External", stream.IsExternal)
    else if streamType = "subtitle" then
        appendTextField(lines, "Language", stream.Language)
        appendTextField(lines, "Codec", stream.Codec)
        appendBoolField(lines, "Default", stream.IsDefault)
        appendBoolField(lines, "Forced", stream.IsForced)
        appendBoolField(lines, "External", stream.IsExternal)
    end if

    if lines.Count() = 0 then return "No details available."
    return joinLines(lines)
end function

'-------------------------------------------------------------------------------
' buildStreamSummary
'-------------------------------------------------------------------------------
function buildStreamSummary(stream as dynamic, streamType as string) as string
    parts = []

    if streamType = "video" then
        appendPart(parts, getResolutionText(stream))
        appendPart(parts, FirstNonEmpty([stream.RealFrameRate, stream.AverageFrameRate], ""))
        appendPart(parts, stream.Codec)
    else if streamType = "audio" then
        appendPart(parts, formatChannels(stream.Channels))
        appendPart(parts, stream.ChannelLayout)
        appendPart(parts, stream.Codec)
    else if streamType = "subtitle" then
        appendPart(parts, FirstNonEmpty([stream.Language, stream.DisplayLanguage], ""))
        appendPart(parts, stream.Codec)
        if stream.IsForced = true then appendPart(parts, "Forced")
        if stream.IsExternal = true then appendPart(parts, "External")
    end if

    summary = joinParts(parts, "  /  ")
    if summary = "" then return "Details unavailable"
    return summary
end function

'-------------------------------------------------------------------------------
' getStreamTitle
'-------------------------------------------------------------------------------
function getStreamTitle(stream as dynamic, streamType as string) as string
    title = FirstNonEmpty([stream.DisplayTitle, stream.Title], "")
    if title <> "" then return title

    if streamType = "video" then return "Video"
    if streamType = "audio" then return "Audio"
    return "Subtitle"
end function

'-------------------------------------------------------------------------------
' getPageCount
'-------------------------------------------------------------------------------
function getPageCount(cards as object) as integer
    pageCount = cards.video.Count()
    if cards.audio.Count() > pageCount then pageCount = cards.audio.Count()
    if cards.subtitle.Count() > pageCount then pageCount = cards.subtitle.Count()
    return pageCount
end function

'-------------------------------------------------------------------------------
' renderCard
'-------------------------------------------------------------------------------
sub renderCard(streamType as string, fallbackTitle as string, cards as object, pageIndex as integer)
    if cards.Count() = 0 then
        renderEmptyCard(streamType, fallbackTitle)
        return
    end if

    cardIndex = pageIndex
    if cardIndex >= cards.Count() then cardIndex = cards.Count() - 1

    card = cards[cardIndex]
    setCardText(streamType, card.title, card.summary, card.details)
end sub

'-------------------------------------------------------------------------------
' renderEmptyCard
'-------------------------------------------------------------------------------
sub renderEmptyCard(streamType as string, title as string)
    setCardText(streamType, title, "No " + LCase(title) + " stream", "Nothing to show for this media source.")
end sub

'-------------------------------------------------------------------------------
' setCardText
'-------------------------------------------------------------------------------
sub setCardText(streamType as string, title as string, summary as string, details as string)
    if streamType = "video" then
        m.nodes.videoTitleLabel.text = title
        m.nodes.videoSummaryLabel.text = summary
        m.nodes.videoDetailsLabel.text = details
    else if streamType = "audio" then
        m.nodes.audioTitleLabel.text = title
        m.nodes.audioSummaryLabel.text = summary
        m.nodes.audioDetailsLabel.text = details
    else
        m.nodes.subtitleTitleLabel.text = title
        m.nodes.subtitleSummaryLabel.text = summary
        m.nodes.subtitleDetailsLabel.text = details
    end if
end sub

'-------------------------------------------------------------------------------
' getPageText
'-------------------------------------------------------------------------------
function getPageText(pageCount as integer) as string
    if pageCount <= 1 then return "Stream set 1 / 1"
    return "Stream set " + (m.state.pageIndex + 1).ToStr() + " / " + pageCount.ToStr()
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
' appendTextField
'-------------------------------------------------------------------------------
sub appendTextField(lines as object, label as string, value as dynamic)
    text = FirstNonEmpty([value], "")
    if text = "" then return

    lines.Push(label + ": " + text)
end sub

'-------------------------------------------------------------------------------
' appendPart
'-------------------------------------------------------------------------------
sub appendPart(parts as object, value as dynamic)
    text = FirstNonEmpty([value], "")
    if text <> "" then parts.Push(text)
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
' joinParts
'-------------------------------------------------------------------------------
function joinParts(parts as object, separator as string) as string
    text = ""
    for each part in parts
        if text <> "" then text = text + separator
        text = text + SafeString(part, "")
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

    pageCount = getPageCount(m.state.cards)

    if key = "left" and m.state.pageIndex > 0 then
        m.state.pageIndex = m.state.pageIndex - 1
        renderPage()
        return true
    end if

    if key = "right" and m.state.pageIndex < pageCount - 1 then
        m.state.pageIndex = m.state.pageIndex + 1
        renderPage()
        return true
    end if

    return false
end function

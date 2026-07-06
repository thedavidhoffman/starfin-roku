'-------------------------------------------------------------------------------
' MediaOptions_GetChapters
'-------------------------------------------------------------------------------
function MediaOptions_GetChapters(item as dynamic) as object
    if item = invalid or item.Chapters = invalid then return []

    chapters = []
    for each chapter in item.Chapters
        if chapter <> invalid and chapter.StartPositionTicks <> invalid and chapter.StartPositionTicks >= 0 then chapters.Push(chapter)
    end for

    return chapters
end function

'-------------------------------------------------------------------------------
' MediaOptions_BuildSubtitleOptions
'-------------------------------------------------------------------------------
function MediaOptions_BuildSubtitleOptions(subtitleStreams as object) as object
    options = []
    options.Push({
        key: "-1"
        label: "Off"
        value: {
            isOff: true
            streamIndex: -1
            label: "Off"
        }
    })

    for i = 0 to subtitleStreams.Count() - 1
        stream = subtitleStreams[i]
        label = MediaOptions_GetSubtitleLabel(stream)
        streamIndex = MediaOptions_GetStreamIndex(stream, i)
        options.Push({
            key: streamIndex.ToStr()
            label: label
            value: {
                isOff: false
                streamIndex: streamIndex
                stream: stream
                label: label
            }
        })
    end for

    return options
end function

'-------------------------------------------------------------------------------
' MediaOptions_BuildAudioOptions
'-------------------------------------------------------------------------------
function MediaOptions_BuildAudioOptions(audioStreams as object) as object
    options = []
    for i = 0 to audioStreams.Count() - 1
        stream = audioStreams[i]
        label = MediaOptions_GetAudioLabel(stream)
        streamIndex = MediaOptions_GetStreamIndex(stream, i)
        options.Push({
            key: streamIndex.ToStr()
            label: label
            value: {
                streamIndex: streamIndex
                stream: stream
                label: label
            }
        })
    end for

    return options
end function

'-------------------------------------------------------------------------------
' MediaOptions_BuildChapterOptions
'-------------------------------------------------------------------------------
function MediaOptions_BuildChapterOptions(chapters as object) as object
    options = []
    chapterNumber = 1
    for each chapter in chapters
        if chapter = invalid or chapter.StartPositionTicks = invalid then continue for

        startPositionTicks = chapter.StartPositionTicks
        if startPositionTicks < 0 then continue for

        startPositionSeconds = PlaybackProgress_TicksToSeconds(startPositionTicks)
        label = MediaOptions_GetChapterLabel(chapter, chapterNumber, startPositionSeconds)
        key = SafeString(startPositionTicks, "")
        options.Push({
            key: key
            label: label
            value: {
                chapter: chapter
                label: label
                startPositionTicks: startPositionTicks
                startPositionSeconds: startPositionSeconds
            }
        })
        chapterNumber = chapterNumber + 1
    end for

    return options
end function

'-------------------------------------------------------------------------------
' MediaOptions_GetSubtitleLabel
'-------------------------------------------------------------------------------
function MediaOptions_GetSubtitleLabel(stream as dynamic) as string
    label = FirstNonEmpty([stream.DisplayTitle, stream.Title, stream.Language], "")
    if label <> "" then return label

    index = SafeString(stream.Index, "")
    if index <> "" then return "Subtitle " + index

    return "Subtitle"
end function

'-------------------------------------------------------------------------------
' MediaOptions_GetAudioLabel
'-------------------------------------------------------------------------------
function MediaOptions_GetAudioLabel(stream as dynamic) as string
    label = FirstNonEmpty([stream.DisplayTitle, stream.Title, stream.Language], "")
    if label <> "" then return label

    index = SafeString(stream.Index, "")
    if index <> "" then return "Audio " + index

    return "Audio Track"
end function

'-------------------------------------------------------------------------------
' MediaOptions_GetChapterLabel
'-------------------------------------------------------------------------------
function MediaOptions_GetChapterLabel(chapter as dynamic, chapterNumber as integer, startPositionSeconds as integer) as string
    label = FirstNonEmpty([chapter.Name], "")
    if label = "" then label = "Chapter " + chapterNumber.ToStr()

    timeText = DateTime_FormatPositionSeconds(startPositionSeconds)
    if timeText = "" then return label

    return label + " - " + timeText
end function

'-------------------------------------------------------------------------------
' MediaOptions_GetStreamIndex
'-------------------------------------------------------------------------------
function MediaOptions_GetStreamIndex(stream as dynamic, fallback as integer) as integer
    if stream <> invalid and stream.Index <> invalid then return int(stream.Index)
    if stream <> invalid and stream.sourceIndex <> invalid then return int(stream.sourceIndex)
    return fallback
end function

'-------------------------------------------------------------------------------
' MediaOptions_GetCurrentChapterKey
'-------------------------------------------------------------------------------
function MediaOptions_GetCurrentChapterKey(chapters as object, positionSeconds as dynamic) as string
    if chapters = invalid or chapters.Count() = 0 then return ""

    positionTicks = 0
    if positionSeconds <> invalid and positionSeconds > 0 then positionTicks = int(positionSeconds) * 10000000&

    selectedKey = ""
    for each chapter in chapters
        if chapter = invalid or chapter.StartPositionTicks = invalid then continue for
        if chapter.StartPositionTicks < 0 then continue for
        if chapter.StartPositionTicks <= positionTicks then selectedKey = SafeString(chapter.StartPositionTicks, "")
    end for

    if selectedKey <> "" then return selectedKey

    for each chapter in chapters
        if chapter = invalid or chapter.StartPositionTicks = invalid then continue for
        if chapter.StartPositionTicks >= 0 then return SafeString(chapter.StartPositionTicks, "")
    end for

    return ""
end function

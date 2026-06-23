'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("PlaybackInfoTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    requestedAudioStreamIndex = getPlaybackRequestAudioStreamIndex(request)
    requestedMediaSourceId = getPlaybackRequestMediaSourceId(request)
    requestedAudioStream = getPlaybackRequestMediaStream(request, requestedAudioStreamIndex)
    forceTranscode = shouldForceTranscodeAudio(requestedAudioStream)
    params = {
        UserId: SafeString(request.userId, "")
        StartTimeTicks: getStartPositionTicks(request)
        IsPlayback: true
        AutoOpenLiveStream: true
        MaxStreamingBitrate: "120000000"
        MaxStaticBitrate: "100000000"
        EnableDirectPlay: forceTranscode <> true
        EnableDirectStream: forceTranscode <> true
    }

    if forceTranscode = true then logForcedTranscodeReason(requestedAudioStream)
    if requestedMediaSourceId <> "" then params.MediaSourceId = requestedMediaSourceId
    if requestedAudioStreamIndex >= 0 then params.AudioStreamIndex = requestedAudioStreamIndex

    url = NormalizeServerUrl(request.server) + "/Items/" + request.itemId + "/PlaybackInfo" + Url_BuildQueryString(params)
    body = buildPlaybackInfoBody()
    logPlaybackRequest(request, url, body)

    result = HttpClient_Request(url, "POST", invalid, body, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        logPlaybackError(result)
        result.AddReplace("action", "playbackInfo")
        m.top.response = result
        return
    end if

    logPlaybackResponse(result.data)

    streamInfo = buildStreamInfo(request, result.data, requestedAudioStreamIndex)
    if streamInfo.ok <> true then
        m.log.error(streamInfo.errorMessage)
        m.top.response = streamInfo
        return
    end if

    m.log.write("Selected stream format: " + streamInfo.streamFormat)
    m.log.write("Selected stream URL: " + maskUrl(streamInfo.streamUrl))

    m.top.response = {
        ok: true
        action: "playbackInfo"
        payload: result.data
        item: request.item
        streamUrl: streamInfo.streamUrl
        streamFormat: streamInfo.streamFormat
        playSessionId: streamInfo.playSessionId
        startPositionTicks: getStartPositionTicks(request)
    }
end sub

'-------------------------------------------------------------------------------
' logPlaybackRequest
'-------------------------------------------------------------------------------
sub logPlaybackRequest(request as object, url as string, body as string)
    itemName = ""
    if request.item <> invalid then itemName = FirstNonEmpty([request.item.Name], "")

    m.log.write("PlaybackInfo request itemId=" + SafeString(request.itemId, "") + " title=" + itemName)
    m.log.write("PlaybackInfo request body:")
    m.log.writeJson(body, 2)
end sub

'-------------------------------------------------------------------------------
' logPlaybackError
'-------------------------------------------------------------------------------
sub logPlaybackError(result as object)
    m.log.error("PlaybackInfo failed status=" + SafeString(result.status, "") + " message=" + SafeString(result.errorMessage, ""))

    responseText = SafeString(result.responseText, "")
    if responseText <> "" then
        m.log.write("PlaybackInfo error response:")
        m.log.writeJson(responseText, 2)
    end if
end sub

'-------------------------------------------------------------------------------
' logPlaybackResponse
'-------------------------------------------------------------------------------
sub logPlaybackResponse(playbackInfo as dynamic)
    if playbackInfo = invalid then
        m.log.write("PlaybackInfo response parsed as invalid.")
        return
    end if

    mediaSource = firstMediaSource(playbackInfo)
    m.log.write("PlaybackInfo response PlaySessionId=" + SafeString(playbackInfo.PlaySessionId, ""))

    if mediaSource = invalid then
        m.log.write("PlaybackInfo response has no media source.")
        return
    end if

    m.log.write("PlaybackInfo media source Id=" + SafeString(mediaSource.Id, "") + " Protocol=" + SafeString(mediaSource.Protocol, "") + " Container=" + SafeString(mediaSource.Container, ""))
    m.log.write("PlaybackInfo SupportsDirectPlay=" + boolToText(mediaSource.SupportsDirectPlay) + " SupportsDirectStream=" + boolToText(mediaSource.SupportsDirectStream) + " SupportsTranscoding=" + boolToText(mediaSource.SupportsTranscoding))
    m.log.write("PlaybackInfo TranscodingUrl=" + maskUrl(SafeString(mediaSource.TranscodingUrl, "")))

    if mediaSource.MediaStreams <> invalid then
        for each mediaStream in mediaSource.MediaStreams
            streamType = SafeString(mediaStream.Type, "")
            if LCase(streamType) = "audio" or LCase(streamType) = "video" then
                m.log.write("PlaybackInfo stream Type=" + streamType + " Index=" + SafeString(mediaStream.Index, "") + " Codec=" + SafeString(mediaStream.Codec, "") + " Channels=" + SafeString(mediaStream.Channels, "") + " Default=" + boolToText(mediaStream.IsDefault))
            end if
        end for
    end if
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' buildStreamInfo
'-------------------------------------------------------------------------------
function buildStreamInfo(request as object, playbackInfo as dynamic, requestedAudioStreamIndex as integer) as object
    mediaSource = firstMediaSource(playbackInfo)
    if mediaSource = invalid then
        return { ok: false, action: "playbackInfo", errorMessage: "The selected item has no playable media source." }
    end if

    mediaSourceId = SafeString(mediaSource.Id, "")
    container = SafeString(mediaSource.Container, "")
    playSessionId = SafeString(playbackInfo.PlaySessionId, "")
    streamUrl = SafeString(mediaSource.TranscodingUrl, "")
    audioStreamIndex = getResolvedAudioStreamIndex(mediaSource, requestedAudioStreamIndex)
    if streamUrl <> "" then
        streamUrl = buildServerUrl(request.server, streamUrl)
        streamFormat = "hls"
        playbackMethod = "transcode"
    else
        streamFormat = getStreamFormat(container)
        streamUrl = NormalizeServerUrl(request.server) + "/Videos/" + request.itemId + "/stream" + Url_BuildQueryString({
            Static: true
            MediaSourceId: mediaSourceId
            AudioStreamIndex: audioStreamIndex
            Container: container
            PlaySessionId: playSessionId
            api_key: request.token
        })
        playbackMethod = "direct"
    end if

    return {
        ok: true
        streamUrl: streamUrl
        streamFormat: streamFormat
        playSessionId: playSessionId
        playbackMethod: playbackMethod
        mediaSourceId: mediaSourceId
        videoStreamIndex: getDefaultVideoStreamIndex(mediaSource)
        audioStreamIndex: audioStreamIndex
    }
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestMediaSourceId
'-------------------------------------------------------------------------------
function getPlaybackRequestMediaSourceId(request as dynamic) as string
    if request = invalid then return ""
    if request.mediaSourceId <> invalid then return SafeString(request.mediaSourceId, "")

    item = request.item
    if item = invalid or item.MediaSources = invalid or item.MediaSources.Count() = 0 then return ""
    mediaSource = item.MediaSources[0]
    if mediaSource = invalid then return ""

    return SafeString(mediaSource.Id, "")
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestAudioStreamIndex
'-------------------------------------------------------------------------------
function getPlaybackRequestAudioStreamIndex(request as dynamic) as integer
    if request = invalid then return -1
    if request.audioStreamIndex <> invalid then return int(request.audioStreamIndex)

    return getDefaultAudioStreamIndexFromStreams(getPlaybackRequestMediaStreams(request))
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestMediaStreams
'-------------------------------------------------------------------------------
function getPlaybackRequestMediaStreams(request as dynamic) as dynamic
    if request = invalid or request.item = invalid then return invalid

    item = request.item
    if item.MediaStreams <> invalid then return item.MediaStreams
    if item.mediaStreams <> invalid then return item.mediaStreams

    return invalid
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestMediaStream
'-------------------------------------------------------------------------------
function getPlaybackRequestMediaStream(request as dynamic, streamIndex as integer) as dynamic
    mediaStreams = getPlaybackRequestMediaStreams(request)
    if mediaStreams = invalid then return invalid
    if streamIndex < 0 or streamIndex >= mediaStreams.Count() then return invalid

    mediaStream = mediaStreams[streamIndex]
    if mediaStream <> invalid then mediaStream.AddReplace("arrayIndex", streamIndex)
    return mediaStream
end function

'-------------------------------------------------------------------------------
' shouldForceTranscodeAudio
'-------------------------------------------------------------------------------
function shouldForceTranscodeAudio(mediaStream as dynamic) as boolean
    if mediaStream = invalid then return false
    if LCase(SafeString(mediaStream.Type, "")) <> "audio" then return false
    if LCase(SafeString(mediaStream.Codec, "")) <> "aac" then return false
    if mediaStream.Channels = invalid then return false

    return int(mediaStream.Channels) > 2
end function

'-------------------------------------------------------------------------------
' logForcedTranscodeReason
'-------------------------------------------------------------------------------
sub logForcedTranscodeReason(mediaStream as dynamic)
    m.log.write("Forcing transcode because selected audio is multichannel AAC. Index=" + SafeString(mediaStream.arrayIndex, "") + " Channels=" + SafeString(mediaStream.Channels, "") + " Title=" + FirstNonEmpty([mediaStream.DisplayTitle, mediaStream.Title], ""))
end sub

'-------------------------------------------------------------------------------
' getDefaultAudioStreamIndexFromStreams
'-------------------------------------------------------------------------------
function getDefaultAudioStreamIndexFromStreams(mediaStreams as dynamic) as integer
    if mediaStreams = invalid then return -1

    firstAudioIndex = -1
    for i = 0 to mediaStreams.Count() - 1
        mediaStream = mediaStreams[i]
        if mediaStream = invalid then continue for
        if LCase(SafeString(mediaStream.Type, "")) = "audio" then
            streamIndex = i
            if firstAudioIndex = -1 then firstAudioIndex = streamIndex
            if mediaStream.IsDefault = true then return streamIndex
        end if
    end for

    return firstAudioIndex
end function

'-------------------------------------------------------------------------------
' buildPlaybackInfoBody
'-------------------------------------------------------------------------------
function buildPlaybackInfoBody() as string
    return Json_Object([
        Json_String("DeviceProfile") + ":" + DeviceCapabilities_BuildDeviceProfileJson()
    ])
end function

'-------------------------------------------------------------------------------
' buildServerUrl
'-------------------------------------------------------------------------------
function buildServerUrl(server as string, path as string) as string
    if Instr(1, LCase(path), "http://") = 1 or Instr(1, LCase(path), "https://") = 1 then return path
    if Left(path, 1) = "/" then return NormalizeServerUrl(server) + path

    return NormalizeServerUrl(server) + "/" + path
end function

'-------------------------------------------------------------------------------
' getDefaultAudioStreamIndex
'-------------------------------------------------------------------------------
function getDefaultAudioStreamIndex(mediaSource as dynamic) as integer
    if mediaSource = invalid or mediaSource.MediaStreams = invalid then return 1

    firstAudioIndex = -1
    for i = 0 to mediaSource.MediaStreams.Count() - 1
        mediaStream = mediaSource.MediaStreams[i]
        if mediaStream = invalid then continue for
        if LCase(SafeString(mediaStream.Type, "")) = "audio" then
            streamIndex = i
            if firstAudioIndex = -1 then firstAudioIndex = streamIndex
            if mediaStream.IsDefault = true then return streamIndex
        end if
    end for

    if firstAudioIndex <> -1 then return firstAudioIndex
    return 1
end function

'-------------------------------------------------------------------------------
' getResolvedAudioStreamIndex
'-------------------------------------------------------------------------------
function getResolvedAudioStreamIndex(mediaSource as dynamic, requestedAudioStreamIndex as integer) as integer
    if requestedAudioStreamIndex >= 0 then return requestedAudioStreamIndex

    return getDefaultAudioStreamIndex(mediaSource)
end function

'-------------------------------------------------------------------------------
' getDefaultVideoStreamIndex
'-------------------------------------------------------------------------------
function getDefaultVideoStreamIndex(mediaSource as dynamic) as integer
    if mediaSource = invalid or mediaSource.MediaStreams = invalid then return 0

    for i = 0 to mediaSource.MediaStreams.Count() - 1
        mediaStream = mediaSource.MediaStreams[i]
        if mediaStream = invalid then continue for
        if LCase(SafeString(mediaStream.Type, "")) = "video" then
            return i
        end if
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' getStartPositionTicks
'-------------------------------------------------------------------------------
function getStartPositionTicks(request as dynamic) as longinteger
    if request = invalid then return 0

    if request.startPositionTicks <> invalid then return request.startPositionTicks
    if request.StartPositionTicks <> invalid then return request.StartPositionTicks

    return PlaybackProgress_GetTicksFromItem(request.item)
end function

'-------------------------------------------------------------------------------
' firstMediaSource
'-------------------------------------------------------------------------------
function firstMediaSource(playbackInfo as dynamic) as dynamic
    if playbackInfo = invalid or playbackInfo.MediaSources = invalid then return invalid
    if playbackInfo.MediaSources.Count() = 0 then return invalid

    return playbackInfo.MediaSources[0]
end function

'-------------------------------------------------------------------------------
' getStreamFormat
'-------------------------------------------------------------------------------
function getStreamFormat(container as string) as string
    normalized = LCase(container)
    if normalized = "mov" then return "mp4"
    if normalized = "m4v" then return "mp4"
    if normalized = "" then return "mp4"

    return normalized
end function

'-------------------------------------------------------------------------------
' boolToText
'-------------------------------------------------------------------------------
function boolToText(value as dynamic) as string
    if value = true then return "true"
    if value = false then return "false"
    return ""
end function

'-------------------------------------------------------------------------------
' maskUrl
'-------------------------------------------------------------------------------
function maskUrl(url as dynamic) as string
    text = SafeString(url, "")
    if text = "" then return ""

    text = maskQueryValue(text, "api_key")
    text = maskQueryValue(text, "ApiKey")
    text = maskQueryValue(text, "token")
    text = maskQueryValue(text, "X-Emby-Token")

    return text
end function

'-------------------------------------------------------------------------------
' maskQueryValue
'-------------------------------------------------------------------------------
function maskQueryValue(url as string, name as string) as string
    queryStart = Instr(1, url, "?")
    if queryStart = 0 then return url

    lowerUrl = LCase(url)
    lowerName = LCase(name)
    searchStart = queryStart + 1

    while true
        keyStart = Instr(searchStart, lowerUrl, lowerName + "=")
        if keyStart = 0 then exit while

        isQueryKey = keyStart = queryStart + 1 or Mid(url, keyStart - 1, 1) = "&"
        if isQueryKey = true then
            valueStart = keyStart + Len(name) + 1
            valueEnd = Instr(valueStart, url, "&")
            if valueEnd = 0 then valueEnd = Len(url) + 1

            url = Left(url, valueStart - 1) + "[redacted]" + Mid(url, valueEnd)
            lowerUrl = LCase(url)
            searchStart = valueStart + Len("[redacted]")
        else
            searchStart = keyStart + Len(name) + 1
        end if
    end while

    return url
end function

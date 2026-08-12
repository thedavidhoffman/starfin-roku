'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("VideoPlaybackInfoTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    requestId = getPlaybackRequestId(request)
    validationError = validateRequest(request)
    if validationError <> invalid then
        validationError.AddReplace("requestId", requestId)
        m.top.response = validationError
        return
    end if

    requestedAudioStreamIndex = getPlaybackRequestAudioStreamIndex(request)
    requestedSubtitleStreamIndex = getPlaybackRequestSubtitleStreamIndex(request)
    displaySize = DeviceCapabilities_GetDisplaySize()
    requestedMediaSourceId = getPlaybackRequestMediaSourceId(request)
    requestedAudioStream = getPlaybackRequestMediaStream(request, requestedAudioStreamIndex)
    requestedMediaSource = getPlaybackRequestMediaSource(request)
    forceTranscode = shouldForceTranscodeAudio(requestedAudioStream, requestedMediaSource)
    forceStreamSelection = shouldForceStreamSelection(request, requestedMediaSource, requestedAudioStreamIndex)
    forceSubtitleSelection = requestedSubtitleStreamIndex >= 0
    playbackMode = getPlaybackMode(request)
    playbackFlags = getPlaybackFlags(playbackMode, forceTranscode, forceStreamSelection, forceSubtitleSelection)
    params = {
        UserId: SafeString(request.userId, "")
        StartTimeTicks: getStartPositionTicks(request)
        IsPlayback: true
        AutoOpenLiveStream: true
        MaxStreamingBitrate: "120000000"
        MaxStaticBitrate: "100000000"
        EnableDirectPlay: playbackFlags.enableDirectPlay
        EnableDirectStream: playbackFlags.enableDirectStream
        EnableTranscoding: playbackFlags.enableTranscoding
        AllowVideoStreamCopy: playbackMode <> "transcodeNoRemux"
        AllowAudioStreamCopy: true
    }

    if playbackMode = "automatic" and forceTranscode = true then logForcedTranscodeReason(requestedAudioStream)
    if playbackMode = "automatic" and forceStreamSelection = true then logForcedStreamSelection(requestedAudioStream)
    m.log.write("Device profile display cap width=" + SafeString(displaySize.width, "") + " height=" + SafeString(displaySize.height, "") + " source=" + SafeString(displaySize.source, ""))
    m.log.write("Requested streams audioStreamIndex=" + SafeString(requestedAudioStreamIndex, "") + " subtitleStreamIndex=" + SafeString(requestedSubtitleStreamIndex, ""))
    m.log.write("Requested video mode=" + playbackMode)
    if requestedMediaSourceId <> "" then params.MediaSourceId = requestedMediaSourceId
    if requestedAudioStreamIndex >= 0 then params.AudioStreamIndex = requestedAudioStreamIndex
    if requestedSubtitleStreamIndex >= -1 then params.SubtitleStreamIndex = requestedSubtitleStreamIndex

    url = request.server + "/Items/" + request.itemId + "/PlaybackInfo" + Url_BuildQueryString(params)
    body = buildPlaybackInfoBody()
    logPlaybackRequest(request, body)

    result = HttpClient_Request(url, "POST", invalid, body, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        logPlaybackError(result)
        result.AddReplace("action", "playbackInfo")
        result.AddReplace("requestId", requestId)
        m.top.response = result
        return
    end if

    logPlaybackResponse(result.data)

    streamInfo = buildStreamInfo(request, result.data, requestedAudioStreamIndex, requestedSubtitleStreamIndex, playbackFlags)
    if streamInfo.ok <> true then
        m.log.error(streamInfo.errorMessage)
        streamInfo.AddReplace("requestId", requestId)
        m.top.response = streamInfo
        return
    end if

    m.log.write("Selected stream format: " + streamInfo.streamFormat)
    m.log.write("Selected stream URL: " + maskUrl(streamInfo.streamUrl))

    m.top.response = {
        ok: true
        action: "playbackInfo"
        requestId: requestId
        payload: result.data
        item: request.item
        streamUrl: streamInfo.streamUrl
        streamFormat: streamInfo.streamFormat
        playSessionId: streamInfo.playSessionId
        playbackIdentity: buildPlaybackIdentity(request, streamInfo, firstMediaSource(result.data))
        startPositionTicks: getStartPositionTicks(request)
    }
end sub

'-------------------------------------------------------------------------------
' getPlaybackRequestId
'-------------------------------------------------------------------------------
function getPlaybackRequestId(request as dynamic) as integer
    if request = invalid then return -1
    return Number_ToInteger(request.requestId, -1)
end function

'-------------------------------------------------------------------------------
' buildPlaybackIdentity
'-------------------------------------------------------------------------------
function buildPlaybackIdentity(request as object, streamInfo as object, mediaSource as dynamic) as object
    videoStream = getMediaStreamByIndex(mediaSource, "video", streamInfo.videoStreamIndex)
    audioStream = getMediaStreamByIndex(mediaSource, "audio", streamInfo.audioStreamIndex)
    subtitleStream = getMediaStreamByIndex(mediaSource, "subtitle", streamInfo.subtitleStreamIndex)
    if videoStream = invalid then videoStream = {}
    if audioStream = invalid then audioStream = {}
    if subtitleStream = invalid then subtitleStream = {}

    return {
        itemId: SafeString(request.itemId, "")
        title: getPlaybackItemTitle(request.item)
        playSessionId: streamInfo.playSessionId
        mediaSourceId: streamInfo.mediaSourceId
        liveStreamId: streamInfo.liveStreamId
        playbackMode: getPlaybackMode(request)
        playMethod: streamInfo.playbackMethod
        canSeek: getCanSeek(request, mediaSource)
        transcodeReason: getTranscodeReason(mediaSource, streamInfo.playbackMethod)
        streamFormat: streamInfo.streamFormat
        container: SafeString(mediaSource.Container, "")
        videoStreamIndex: streamInfo.videoStreamIndex
        audioStreamIndex: streamInfo.audioStreamIndex
        subtitleStreamIndex: streamInfo.subtitleStreamIndex
        videoStreamTitle: FirstNonEmpty([videoStream.DisplayTitle, videoStream.Title], "")
        audioStreamTitle: FirstNonEmpty([audioStream.DisplayTitle, audioStream.Title], "")
        subtitleStreamTitle: FirstNonEmpty([subtitleStream.DisplayTitle, subtitleStream.Title], "")
        videoCodec: SafeString(videoStream.Codec, "")
        audioCodec: SafeString(audioStream.Codec, "")
        width: Number_ToInteger(videoStream.Width, 0)
        height: Number_ToInteger(videoStream.Height, 0)
        videoBitrate: Number_ToInteger(videoStream.BitRate, 0)
        audioBitrate: Number_ToInteger(audioStream.BitRate, 0)
        audioChannels: Number_ToInteger(audioStream.Channels, 0)
    }
end function

'-------------------------------------------------------------------------------
' getTranscodeReason
'-------------------------------------------------------------------------------
function getTranscodeReason(mediaSource as dynamic, playbackMethod as string) as string
    method = LCase(playbackMethod)
    if method = "direct" or method = "directplay" then return "Not required (direct play)"
    if mediaSource = invalid then return "Not reported by Jellyfin"

    if mediaSource.TranscodingReasons <> invalid then
        reasons = String_GetJoinedText(mediaSource.TranscodingReasons)
        if reasons <> "" then return reasons
    end if

    reason = getUrlQueryValue(SafeString(mediaSource.TranscodingUrl, ""), "TranscodeReasons")
    if reason = "" then return "Not reported by Jellyfin"
    return String_Replace(reason, ",", ", ")
end function

'-------------------------------------------------------------------------------
' getCanSeek
'-------------------------------------------------------------------------------
function getCanSeek(request as dynamic, mediaSource as dynamic) as boolean
    if isLiveTvPlaybackRequest(request) = true then return false
    if mediaSource <> invalid and mediaSource.IsInfiniteStream = true then return false

    runtimeTicks = 0
    if mediaSource <> invalid then runtimeTicks = Number_ToFloat(mediaSource.RunTimeTicks, 0)
    if runtimeTicks <= 0 and request <> invalid and request.item <> invalid then
        runtimeTicks = Number_ToFloat(request.item.RunTimeTicks, 0)
    end if

    return runtimeTicks > 0
end function

'-------------------------------------------------------------------------------
' getUrlQueryValue
'-------------------------------------------------------------------------------
function getUrlQueryValue(url as string, name as string) as string
    queryStart = Instr(1, url, "?")
    if queryStart = 0 then return ""

    lowerUrl = LCase(url)
    lowerName = LCase(name)
    valueStart = Instr(queryStart + 1, lowerUrl, lowerName + "=")
    while valueStart > 0
        if valueStart = queryStart + 1 or Mid(url, valueStart - 1, 1) = "&" then
            valueStart = valueStart + Len(name) + 1
            valueEnd = Instr(valueStart, url, "&")
            if valueEnd = 0 then valueEnd = Len(url) + 1

            value = Mid(url, valueStart, valueEnd - valueStart)
            value = String_Replace(value, "%2C", ",")
            value = String_Replace(value, "%2c", ",")
            return value
        end if

        valueStart = Instr(valueStart + Len(name) + 1, lowerUrl, lowerName + "=")
    end while

    return ""
end function

'-------------------------------------------------------------------------------
' getPlaybackItemTitle
'-------------------------------------------------------------------------------
function getPlaybackItemTitle(item as dynamic) as string
    if item = invalid then return ""
    return SafeString(item.Name, "")
end function

'-------------------------------------------------------------------------------
' getMediaStreamByIndex
'-------------------------------------------------------------------------------
function getMediaStreamByIndex(mediaSource as dynamic, streamType as string, streamIndex as integer) as dynamic
    if mediaSource = invalid or mediaSource.MediaStreams = invalid then return invalid

    for i = 0 to mediaSource.MediaStreams.Count() - 1
        mediaStream = mediaSource.MediaStreams[i]
        if mediaStream = invalid then continue for
        if LCase(SafeString(mediaStream.Type, "")) <> streamType then continue for
        if getMediaStreamIndex(mediaStream, i) = streamIndex then return mediaStream
    end for

    return invalid
end function

'-------------------------------------------------------------------------------
' getPlaybackMode
'-------------------------------------------------------------------------------
function getPlaybackMode(request as dynamic) as string
    if request = invalid or request.videoMode = invalid then return "automatic"

    mode = SafeString(request.videoMode, "")
    if mode = "automatic" or mode = "directPlay" or mode = "transcodeAllowRemux" or mode = "transcodeNoRemux" then return mode
    return "automatic"
end function

'-------------------------------------------------------------------------------
' getPlaybackFlags
'-------------------------------------------------------------------------------
function getPlaybackFlags(playbackMode as string, forceTranscode as boolean, forceStreamSelection as boolean, forceSubtitleSelection as boolean) as object
    if playbackMode = "transcodeNoRemux" then
        return {
            enableDirectPlay: false
            enableDirectStream: false
            enableTranscoding: true
        }
    end if

    if playbackMode = "directPlay" then
        return {
            enableDirectPlay: true
            enableDirectStream: false
            enableTranscoding: false
        }
    end if

    if playbackMode = "transcodeAllowRemux" or (playbackMode = "automatic" and (forceTranscode = true or forceStreamSelection = true)) then
        enableDirectStream = true
        if playbackMode = "automatic" and forceTranscode = true then enableDirectStream = false

        return {
            enableDirectPlay: false
            enableDirectStream: enableDirectStream
            enableTranscoding: true
        }
    end if

    if playbackMode = "automatic" then
        return {
            enableDirectPlay: true
            enableDirectStream: true
            enableTranscoding: true
        }
    end if

    if forceTranscode = true then
        return {
            enableDirectPlay: false
            enableDirectStream: false
            enableTranscoding: true
        }
    end if

    if forceStreamSelection = true or forceSubtitleSelection = true then
        return {
            enableDirectPlay: false
            enableDirectStream: true
            enableTranscoding: true
        }
    end if

    return {
        enableDirectPlay: true
        enableDirectStream: false
        enableTranscoding: false
    }
end function

'-------------------------------------------------------------------------------
' logPlaybackRequest
'-------------------------------------------------------------------------------
sub logPlaybackRequest(request as object, body as string)
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
    m.log.write("PlaybackInfo media source Path=" + maskUrl(SafeString(mediaSource.Path, "")))
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
    if request.server = invalid or request.server = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "playbackInfo", errorMessage: "Invalid playback item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' buildStreamInfo
'-------------------------------------------------------------------------------
function buildStreamInfo(request as object, playbackInfo as dynamic, requestedAudioStreamIndex as integer, requestedSubtitleStreamIndex as integer, playbackFlags as object) as object
    mediaSource = firstMediaSource(playbackInfo)
    if mediaSource = invalid then
        return { ok: false, action: "playbackInfo", errorMessage: "The selected item has no playable media source." }
    end if

    mediaSourceId = SafeString(mediaSource.Id, "")
    container = SafeString(mediaSource.Container, "")
    playSessionId = SafeString(playbackInfo.PlaySessionId, "")
    transcodingUrl = SafeString(mediaSource.TranscodingUrl, "")
    audioStreamIndex = getResolvedAudioStreamIndex(mediaSource, requestedAudioStreamIndex)
    directPlaySupported = mediaSource.SupportsDirectPlay = true
    directPlayAllowed = playbackFlags.enableDirectPlay = true
    transcodingAllowed = playbackFlags.enableDirectStream = true or playbackFlags.enableTranscoding = true

    if directPlayAllowed and directPlaySupported then
        streamFormat = getStreamFormat(container)
        if isLiveTvPlaybackRequest(request) = true and isHttpDirectMediaSource(mediaSource) then
            streamUrl = buildHttpDirectStreamUrl(request.server, mediaSource.Path)
        else
            streamParams = {
                Static: true
                Container: container
                PlaySessionId: playSessionId
                api_key: request.token
            }
            if isLiveTvPlaybackRequest(request) <> true and mediaSourceId <> "" then streamParams.MediaSourceId = mediaSourceId
            if audioStreamIndex >= 0 then streamParams.AudioStreamIndex = audioStreamIndex
            if requestedSubtitleStreamIndex >= -1 then streamParams.SubtitleStreamIndex = requestedSubtitleStreamIndex
            streamUrl = request.server + "/Videos/" + request.itemId + "/stream" + Url_BuildQueryString(streamParams)
        end if
        playbackMethod = "DirectPlay"
        m.log.write("Playback selection chose DirectPlay because the request allows direct play and Jellyfin reported SupportsDirectPlay=true alternativeHlsAvailable=" + boolToText(transcodingUrl <> ""))
    else if transcodingAllowed and transcodingUrl <> "" then
        streamUrl = buildServerUrl(request.server, transcodingUrl)
        if requestedSubtitleStreamIndex >= -1 then streamUrl = Url_SetQueryParam(streamUrl, "SubtitleStreamIndex", requestedSubtitleStreamIndex.ToStr())
        streamFormat = "hls"
        playbackMethod = getTranscodingPlaybackMethod(mediaSource)
        m.log.write("Playback selection chose HLS directPlayAllowed=" + boolToText(directPlayAllowed) + " supportsDirectPlay=" + boolToText(directPlaySupported) + " playbackMethod=" + playbackMethod)
    else
        mode = getPlaybackMode(request)
        if mode = "directPlay" then
            errorMessage = "Direct Play was requested, but Jellyfin reported that the selected media source does not support it."
        else if directPlayAllowed and directPlaySupported <> true then
            errorMessage = "Jellyfin did not provide a playable stream for the selected media source."
        else
            errorMessage = "Jellyfin did not provide the required transcoding stream."
        end if
        m.log.error("Playback selection failed mode=" + mode + " directPlayAllowed=" + boolToText(directPlayAllowed) + " supportsDirectPlay=" + boolToText(directPlaySupported) + " transcodingAllowed=" + boolToText(transcodingAllowed) + " transcodingUrlAvailable=" + boolToText(transcodingUrl <> ""))
        return { ok: false, action: "playbackInfo", errorMessage: errorMessage }
    end if

    return {
        ok: true
        streamUrl: streamUrl
        streamFormat: streamFormat
        playSessionId: playSessionId
        playbackMethod: playbackMethod
        mediaSourceId: mediaSourceId
        liveStreamId: SafeString(mediaSource.LiveStreamId, "")
        videoStreamIndex: getDefaultVideoStreamIndex(mediaSource)
        audioStreamIndex: audioStreamIndex
        subtitleStreamIndex: requestedSubtitleStreamIndex
    }
end function

'-------------------------------------------------------------------------------
' getTranscodingPlaybackMethod
'-------------------------------------------------------------------------------
function getTranscodingPlaybackMethod(mediaSource as dynamic) as string
    reasons = getPlaybackMethodReasons(mediaSource)
    if reasons.Count() = 0 then return "Transcode"

    for each reason in reasons
        if isDirectStreamReason(reason, mediaSource) <> true then return "Transcode"
    end for

    return "DirectStream"
end function

'-------------------------------------------------------------------------------
' isDirectStreamReason
'-------------------------------------------------------------------------------
function isDirectStreamReason(reason as dynamic, mediaSource as dynamic) as boolean
    normalized = LCase(SafeString(reason, ""))
    if normalized = "containernotsupported" then return true
    if Left(normalized, 5) = "audio" then return true
    if normalized = "secondaryaudionotsupported" then return true

    if normalized = "subtitlecodecnotsupported" then
        subtitleMethod = LCase(getUrlQueryValue(SafeString(mediaSource.TranscodingUrl, ""), "SubtitleMethod"))
        return subtitleMethod = "embed" or subtitleMethod = "external"
    end if

    return false
end function

'-------------------------------------------------------------------------------
' getPlaybackMethodReasons
'-------------------------------------------------------------------------------
function getPlaybackMethodReasons(mediaSource as dynamic) as object
    reasons = []
    if mediaSource = invalid then return reasons

    if mediaSource.TranscodingReasons <> invalid then
        for each reason in mediaSource.TranscodingReasons
            reasonText = SafeString(reason, "")
            if reasonText <> "" then reasons.Push(reasonText)
        end for
    end if
    if reasons.Count() > 0 then return reasons

    reasonText = getUrlQueryValue(SafeString(mediaSource.TranscodingUrl, ""), "TranscodeReasons")
    if reasonText = "" then return reasons

    for each reason in reasonText.Split(",")
        if reason <> "" then reasons.Push(reason)
    end for

    return reasons
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestMediaSourceId
'-------------------------------------------------------------------------------
function getPlaybackRequestMediaSourceId(request as dynamic) as string
    if request = invalid then return ""
    if request.mediaSourceId <> invalid then return SafeString(request.mediaSourceId, "")

    mediaSource = getPlaybackRequestMediaSource(request)
    if mediaSource = invalid then return ""

    return SafeString(mediaSource.Id, "")
end function

'-------------------------------------------------------------------------------
' getPlaybackRequestMediaSource
'-------------------------------------------------------------------------------
function getPlaybackRequestMediaSource(request as dynamic) as dynamic
    if request = invalid then return invalid
    item = request.item
    if item = invalid or item.MediaSources = invalid or item.MediaSources.Count() = 0 then return invalid
    mediaSource = item.MediaSources[0]
    return mediaSource
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
' getPlaybackRequestSubtitleStreamIndex
'-------------------------------------------------------------------------------
function getPlaybackRequestSubtitleStreamIndex(request as dynamic) as integer
    if request = invalid then return -1
    if request.subtitleStreamIndex <> invalid then return int(request.subtitleStreamIndex)

    return -1
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

    for i = 0 to mediaStreams.Count() - 1
        mediaStream = mediaStreams[i]
        if mediaStream = invalid then continue for
        if getMediaStreamIndex(mediaStream, i) = streamIndex then
            mediaStream.AddReplace("arrayIndex", i)
            return mediaStream
        end if
    end for

    if streamIndex < 0 or streamIndex >= mediaStreams.Count() then return invalid

    mediaStream = mediaStreams[streamIndex]
    if mediaStream <> invalid then mediaStream.AddReplace("arrayIndex", streamIndex)
    return mediaStream
end function

'-------------------------------------------------------------------------------
' shouldForceTranscodeAudio
'-------------------------------------------------------------------------------
function shouldForceTranscodeAudio(mediaStream as dynamic, mediaSource as dynamic) as boolean
    if mediaStream = invalid then return false
    if LCase(SafeString(mediaStream.Type, "")) <> "audio" then return false
    if LCase(SafeString(mediaStream.Codec, "")) <> "aac" then return false
    if mediaStream.Channels = invalid then return false
    if int(mediaStream.Channels) <= 2 then return false

    deviceInfo = CreateObject("roDeviceInfo")
    container = ""
    if mediaSource <> invalid then container = SafeString(mediaSource.Container, "")
    decodeInfo = {
        Codec: SafeString(mediaStream.Codec, "")
        ChCnt: int(mediaStream.Channels)
    }
    if container <> "" then decodeInfo.Container = container

    result = deviceInfo.CanDecodeAudio(decodeInfo)
    return result = invalid or result.Result <> true
end function

'-------------------------------------------------------------------------------
' shouldForceStreamSelection
'-------------------------------------------------------------------------------
function shouldForceStreamSelection(request as dynamic, mediaSource as dynamic, requestedAudioStreamIndex as integer) as boolean
    if request = invalid or request.audioStreamIndex = invalid then return false
    if requestedAudioStreamIndex < 0 then return false

    defaultAudioStreamIndex = getDefaultAudioStreamIndex(mediaSource)
    return requestedAudioStreamIndex <> defaultAudioStreamIndex
end function

'-------------------------------------------------------------------------------
' logForcedTranscodeReason
'-------------------------------------------------------------------------------
sub logForcedTranscodeReason(mediaStream as dynamic)
    m.log.write("Forcing transcode because selected multichannel AAC audio is not device-decodable. Index=" + SafeString(mediaStream.arrayIndex, "") + " Channels=" + SafeString(mediaStream.Channels, "") + " Title=" + FirstNonEmpty([mediaStream.DisplayTitle, mediaStream.Title], ""))
end sub

'-------------------------------------------------------------------------------
' logForcedStreamSelection
'-------------------------------------------------------------------------------
sub logForcedStreamSelection(mediaStream as dynamic)
    m.log.write("Disabling direct play because a non-default audio stream was selected. Index=" + SafeString(mediaStream.Index, "") + " Title=" + FirstNonEmpty([mediaStream.DisplayTitle, mediaStream.Title], ""))
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
            streamIndex = getMediaStreamIndex(mediaStream, i)
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
    if Left(path, 1) = "/" then return server + path

    return server + "/" + path
end function

'-------------------------------------------------------------------------------
' getDefaultAudioStreamIndex
'-------------------------------------------------------------------------------
function getDefaultAudioStreamIndex(mediaSource as dynamic) as integer
    if mediaSource = invalid or mediaSource.MediaStreams = invalid then return -1

    firstAudioIndex = -1
    for i = 0 to mediaSource.MediaStreams.Count() - 1
        mediaStream = mediaSource.MediaStreams[i]
        if mediaStream = invalid then continue for
        if LCase(SafeString(mediaStream.Type, "")) = "audio" then
            streamIndex = getMediaStreamIndex(mediaStream, i)
            if firstAudioIndex = -1 then firstAudioIndex = streamIndex
            if mediaStream.IsDefault = true then return streamIndex
        end if
    end for

    return firstAudioIndex
end function

'-------------------------------------------------------------------------------
' isLiveTvPlaybackRequest
'-------------------------------------------------------------------------------
function isLiveTvPlaybackRequest(request as dynamic) as boolean
    if request = invalid or request.item = invalid then return false

    itemType = LCase(SafeString(request.item.Type, ""))
    return itemType = "tvchannel" or itemType = "livetvchannel"
end function

'-------------------------------------------------------------------------------
' isHttpDirectMediaSource
'-------------------------------------------------------------------------------
function isHttpDirectMediaSource(mediaSource as dynamic) as boolean
    if mediaSource = invalid then return false
    if LCase(SafeString(mediaSource.Protocol, "")) <> "http" then return false

    return SafeString(mediaSource.Path, "") <> ""
end function

'-------------------------------------------------------------------------------
' buildHttpDirectStreamUrl
'-------------------------------------------------------------------------------
function buildHttpDirectStreamUrl(server as string, path as dynamic) as string
    url = SafeString(path, "")
    if url = "" then return ""

    lowerUrl = LCase(url)
    if Instr(1, lowerUrl, "http://localhost") = 1 or Instr(1, lowerUrl, "https://localhost") = 1 or Instr(1, lowerUrl, "http://127.0.0.1") = 1 or Instr(1, lowerUrl, "https://127.0.0.1") = 1 then
        routePath = getAbsoluteUrlRoutePath(url)
        if routePath <> "" then return buildServerUrl(server, routePath)
    end if

    return buildServerUrl(server, url)
end function

'-------------------------------------------------------------------------------
' getAbsoluteUrlRoutePath
'-------------------------------------------------------------------------------
function getAbsoluteUrlRoutePath(url as string) as string
    schemeEnd = Instr(1, url, "://")
    if schemeEnd = 0 then return url

    pathStart = Instr(schemeEnd + 3, url, "/")
    if pathStart = 0 then return ""

    return Mid(url, pathStart)
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
            return getMediaStreamIndex(mediaStream, i)
        end if
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' getMediaStreamIndex
'-------------------------------------------------------------------------------
function getMediaStreamIndex(mediaStream as dynamic, fallback as integer) as integer
    if mediaStream <> invalid and mediaStream.Index <> invalid then return int(mediaStream.Index)
    return fallback
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

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("PlaystateTask")
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

    endpoint = getPlaystateEndpoint(request.status)
    if endpoint = "" then
        m.top.response = { ok: false, action: "playstate", errorMessage: "Invalid playstate status." }
        return
    end if

    url = request.server + endpoint
    body = buildPlaystateBody(request)
    result = HttpClient_Request(url, "POST", invalid, body, JellyfinAuth_BuildTokenHeaders(request.token), false)
    result.AddReplace("action", "playstate")
    result.AddReplace("statusName", SafeString(request.status, ""))

    if result.ok <> true then
        m.log.error("Playstate " + SafeString(request.status, "") + " failed: " + SafeString(result.errorMessage, ""))
    end if

    m.top.response = result
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "playstate", errorMessage: "Invalid playstate request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "playstate", errorMessage: "Invalid playstate server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "playstate", errorMessage: "Invalid playstate token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "playstate", errorMessage: "Invalid playstate item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' getPlaystateEndpoint
'-------------------------------------------------------------------------------
function getPlaystateEndpoint(status as dynamic) as string
    normalized = LCase(SafeString(status, ""))
    if normalized = "start" then return "/Sessions/Playing"
    if normalized = "update" then return "/Sessions/Playing/Progress"
    if normalized = "stop" then return "/Sessions/Playing/Stopped"

    return ""
end function

'-------------------------------------------------------------------------------
' buildPlaystateBody
'-------------------------------------------------------------------------------
function buildPlaystateBody(request as object) as string
    isPaused = request.isPaused = true
    if LCase(SafeString(request.status, "")) = "stop" then isPaused = true

    parts = [
        Json_Pair("ItemId", request.itemId)
        Json_NumberPair("PositionTicks", getPositionTicks(request.position))
        Json_BooleanPair("IsPaused", isPaused)
    ]

    playSessionId = SafeString(request.playSessionId, "")
    if playSessionId <> "" then parts.Push(Json_Pair("PlaySessionId", playSessionId))

    mediaSourceId = SafeString(request.mediaSourceId, "")
    if mediaSourceId <> "" then parts.Push(Json_Pair("MediaSourceId", mediaSourceId))

    liveStreamId = SafeString(request.liveStreamId, "")
    if liveStreamId <> "" then parts.Push(Json_Pair("LiveStreamId", liveStreamId))

    parts.Push(Json_Pair("PlayMethod", SafeString(request.playMethod, "DirectPlay")))
    parts.Push(Json_BooleanPair("CanSeek", request.canSeek = true))

    return Json_Object(parts)
end function

'-------------------------------------------------------------------------------
' getPositionTicks
'-------------------------------------------------------------------------------
function getPositionTicks(position as dynamic) as longinteger
    if position = invalid then return 0

    return int(position) * 10000000&
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("LiveTvScheduleTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        if request <> invalid then
            validationError.AddReplace("channelIds", SafeString(request.channelIds, ""))
            validationError.AddReplace("startTime", SafeString(request.startTime, ""))
            validationError.AddReplace("endTime", SafeString(request.endTime, ""))
        end if
        m.top.response = validationError
        return
    end if

    body = Json_Object([
        Json_Pair("UserId", SafeString(request.userId, ""))
        Json_Pair("ChannelIds", SafeString(request.channelIds, ""))
        Json_Pair("MinEndDate", SafeString(request.startTime, ""))
        Json_Pair("MaxStartDate", SafeString(request.endTime, ""))
        Json_Pair("SortBy", "StartDate")
        Json_Pair("Fields", "Genres")
        Json_BooleanPair("EnableImages", true)
        Json_NumberPair("ImageTypeLimit", 1)
        Json_Pair("EnableImageTypes", "Primary,Backdrop,Thumb")
        Json_BooleanPair("EnableTotalRecordCount", false)
        Json_BooleanPair("EnableUserData", false)
    ])

    url = NormalizeServerUrl(request.server) + "/LiveTv/Programs"
    response = HttpClient_Request(url, "POST", invalid, body, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "liveTvSchedule")
        response.AddReplace("channelIds", SafeString(request.channelIds, ""))
        response.AddReplace("startTime", SafeString(request.startTime, ""))
        response.AddReplace("endTime", SafeString(request.endTime, ""))
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "liveTvSchedule"
        channelIds: SafeString(request.channelIds, "")
        startTime: SafeString(request.startTime, "")
        endTime: SafeString(request.endTime, "")
        payload: response.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "liveTvSchedule", errorMessage: "Invalid Live TV schedule request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "liveTvSchedule", errorMessage: "Invalid Live TV server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "liveTvSchedule", errorMessage: "Invalid Live TV token." }
    if SafeString(request.channelIds, "") = "" then return { ok: false, action: "liveTvSchedule", errorMessage: "No Live TV channels were found." }
    if SafeString(request.startTime, "") = "" or SafeString(request.endTime, "") = "" then return { ok: false, action: "liveTvSchedule", errorMessage: "Invalid Live TV guide window." }

    return invalid
end function

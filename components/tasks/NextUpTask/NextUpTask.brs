'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("NextUpTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request, "nextUp")
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    params = {
        recursive: true
        SortBy: "DatePlayed"
        SortOrder: "Descending"
        ImageTypeLimit: 1
        UserId: getUserId(request)
        EnableRewatching: getBoolean(request.enableRewatching, false)
        DisableFirstEpisode: false
        limit: getInteger(request.limit, 26)
        EnableTotalRecordCount: false
    }

    if request.nextUpDateCutoff <> invalid and request.nextUpDateCutoff <> "" then
        params.AddReplace("NextUpDateCutoff", request.nextUpDateCutoff)
    end if

    url = NormalizeServerUrl(request.server) + "/shows/nextup" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        m.top.response = withAction(response, "nextUp")
        return
    end if

    m.top.response = successResponse(request, "nextUp", response.data)
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as object, action as string) as dynamic
    if request = invalid then return { ok: false, action: action, errorMessage: "Invalid request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: action, errorMessage: "Invalid request server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: action, errorMessage: "Invalid request token." }

    return invalid
end function

'-------------------------------------------------------------------------------
' successResponse
'-------------------------------------------------------------------------------
function successResponse(request as object, action as string, payload as dynamic) as object
    return {
        ok: true
        action: action
        server: NormalizeServerUrl(request.server)
        payload: payload
    }
end function

'-------------------------------------------------------------------------------
' withAction
'-------------------------------------------------------------------------------
function withAction(response as object, action as string) as object
    if response = invalid then return { ok: false, action: action, errorMessage: "Request failed." }
    response.AddReplace("action", action)
    return response
end function

'-------------------------------------------------------------------------------
' getUserId
'-------------------------------------------------------------------------------
function getUserId(request as object) as string
    if request.userId <> invalid then return SafeString(request.userId, "")
    return ""
end function

'-------------------------------------------------------------------------------
' getInteger
'-------------------------------------------------------------------------------
function getInteger(value as dynamic, fallback as integer) as integer
    if value = invalid then return fallback
    return value.ToInt()
end function

'-------------------------------------------------------------------------------
' getBoolean
'-------------------------------------------------------------------------------
function getBoolean(value as dynamic, fallback as boolean) as boolean
    if value = invalid then return fallback
    if Type(value) = "roBoolean" or Type(value) = "Boolean" then return value

    normalized = LCase(SafeString(value, ""))
    return normalized = "true" or normalized = "1" or normalized = "yes"
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("LiveTvOnNowTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request, "liveTvOnNow")
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    params = {
        userId: getUserId(request)
        isAiring: true
        limit: getInteger(request.limit, 25)
        imageTypeLimit: 1
        enableImageTypes: "Primary, Backdrop, Thumb"
        enableTotalRecordCount: false
        fields: "ChannelInfo,PrimaryImageAspectRatio"
    }

    url = request.server + "/livetv/programs/recommended" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        m.top.response = withAction(response, "liveTvOnNow")
        return
    end if

    m.top.response = successResponse(request, "liveTvOnNow", response.data)
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as object, action as string) as dynamic
    if request = invalid then return { ok: false, action: action, errorMessage: "Invalid request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: action, errorMessage: "Invalid request server." }
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
        server: request.server
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

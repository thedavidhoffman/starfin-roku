'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("ContinueWatchingTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request, "continueWatching")
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    params = {
        recursive: true
        SortBy: "DatePlayed"
        SortOrder: "Descending"
        Filters: "IsResumable"
        MediaTypes: "Video"
        excludeItemTypes: "Book"
        Fields: "SeriesInfo"
        EnableTotalRecordCount: false
    }

    url = NormalizeServerUrl(request.server) + "/useritems/resume" + Url_BuildQueryString(params)
    m.log.write(url)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        m.top.response = withAction(response, "continueWatching")
        return
    end if

    m.top.response = successResponse(request, "continueWatching", response.data)
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

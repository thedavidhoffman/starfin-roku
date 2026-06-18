'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("FavoritesTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request, "favorites")
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    params = {
        userid: getUserId(request)
        Filters: "IsFavorite"
        Limit: getInteger(request.limit, 25)
        recursive: true
        sortby: FirstNonEmpty([request.sortBy], "SortName")
        sortOrder: FirstNonEmpty([request.sortOrder], "Ascending")
        EnableTotalRecordCount: false
    }

    itemsResponse = getJson(request, "favorites", "/items/", params)
    if itemsResponse.ok <> true then
        m.top.response = itemsResponse
        return
    end if

    peopleResponse = getJson(request, "favorites", "/persons", params)
    if peopleResponse.ok <> true then
        m.top.response = peopleResponse
        return
    end if

    m.top.response = successResponse(request, "favorites", {
        items: itemsResponse.data
        people: peopleResponse.data
    })
end sub

'-------------------------------------------------------------------------------
' getJson
'-------------------------------------------------------------------------------
function getJson(request as object, action as string, path as string, params as object) as object
    url = NormalizeServerUrl(request.server) + path + Url_BuildQueryString(params)
    m.log.write(url)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then return withAction(response, action)

    return response
end function

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

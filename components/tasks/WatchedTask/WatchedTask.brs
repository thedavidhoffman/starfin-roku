'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("WatchedTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    if request = invalid then
        m.top.response = { ok: false, errorMessage: "Invalid watched request." }
        return
    end if

    action = SafeString(request.action, "")
    if action = "MarkAsWatched" then
        m.top.response = markAsWatched(request)
    else if action = "MarkAsUnwatched" then
        m.top.response = markAsUnwatched(request)
    else
        m.top.response = { ok: false, errorMessage: "Unknown watched request action." }
    end if
end sub

'-------------------------------------------------------------------------------
' markAsWatched
'-------------------------------------------------------------------------------
function markAsWatched(request as object) as object
    validationError = validateRequest(request)
    if validationError <> invalid then return validationError

    date = CreateObject("roDateTime")
    params = {
        userId: SafeString(request.userId, "")
        DatePlayed: date.ToISOString()
        PlaybackPositionTicks: 0
    }

    url = NormalizeServerUrl(request.server) + "/UserPlayedItems/" + request.itemId + Url_BuildQueryString(params)
    result = HttpClient_Request(url, "POST", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "MarkAsWatched")
        result.AddReplace("itemId", SafeString(request.itemId, ""))
        return result
    end if

    return {
        ok: true
        action: "MarkAsWatched"
        itemId: SafeString(request.itemId, "")
        payload: result.data
    }
end function

'-------------------------------------------------------------------------------
' markAsUnwatched
'-------------------------------------------------------------------------------
function markAsUnwatched(request as object) as object
    validationError = validateRequest(request)
    if validationError <> invalid then return validationError

    params = {
        userId: SafeString(request.userId, "")
    }

    url = NormalizeServerUrl(request.server) + "/UserPlayedItems/" + request.itemId + Url_BuildQueryString(params)
    result = HttpClient_Request(url, "DELETE", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "MarkAsUnwatched")
        result.AddReplace("itemId", SafeString(request.itemId, ""))
        return result
    end if

    return {
        ok: true
        action: "MarkAsUnwatched"
        itemId: SafeString(request.itemId, "")
        payload: result.data
    }
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    action = SafeString(request.action, "")
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: action, errorMessage: "Invalid watched request server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: action, errorMessage: "Invalid watched request token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: action, errorMessage: "Invalid watched request user." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: action, errorMessage: "Invalid watched request item." }

    return invalid
end function

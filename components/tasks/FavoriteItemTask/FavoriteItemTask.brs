'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("FavoriteItemTask")
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

    action = SafeString(request.action, "")
    method = ""
    if action = "AddToFavorites" then
        method = "POST"
    else if action = "RemoveFromFavorites" then
        method = "DELETE"
    else
        m.top.response = { ok: false, action: action, errorMessage: "Unknown favorite request action." }
        return
    end if

    params = {
        userId: request.userId
    }
    url = request.server + "/UserFavoriteItems/" + request.itemId + Url_BuildQueryString(params)
    result = HttpClient_Request(url, method, invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    result.AddReplace("action", action)
    result.AddReplace("itemId", request.itemId)
    if result.ok <> true then m.log.error("Favorite update failed: " + SafeString(result.errorMessage, ""))
    m.top.response = result
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    action = ""
    if request <> invalid then action = SafeString(request.action, "")
    if request = invalid then return { ok: false, action: action, errorMessage: "Invalid favorite request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: action, errorMessage: "Invalid favorite request server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: action, errorMessage: "Invalid favorite request token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: action, errorMessage: "Invalid favorite request user." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: action, errorMessage: "Invalid favorite request item." }
    return invalid
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MovieTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        if request <> invalid then validationError.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = validationError
        return
    end if

    params = {
        userId: SafeString(request.userId, "")
        fields: "Chapters,Trickplay,Genres,People,MediaSources,MediaStreams,Overview,UserData"
    }

    url = request.server + "/Items/" + request.itemId + Url_BuildQueryString(params)
    result = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "movie")
        result.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = result
        return
    end if

    m.top.response = {
        ok: true
        action: "movie"
        itemId: SafeString(request.itemId, "")
        payload: result.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "movie", errorMessage: "Invalid movie request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "movie", errorMessage: "Invalid movie server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "movie", errorMessage: "Invalid movie token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "movie", errorMessage: "Invalid movie item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MovieDetailsTask")
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

    params = {
        userId: SafeString(request.userId, "")
        fields: "Chapters,Trickplay,Genres,People,MediaSources,MediaStreams,Overview"
    }

    url = NormalizeServerUrl(request.server) + "/Items/" + request.itemId + Url_BuildQueryString(params)
    result = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "movieDetails")
        m.top.response = result
        return
    end if

    m.top.response = {
        ok: true
        action: "movieDetails"
        itemId: SafeString(request.itemId, "")
        payload: result.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "movieDetails", errorMessage: "Invalid movie details request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "movieDetails", errorMessage: "Invalid movie details server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "movieDetails", errorMessage: "Invalid movie details token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "movieDetails", errorMessage: "Invalid movie details item." }

    return invalid
end function

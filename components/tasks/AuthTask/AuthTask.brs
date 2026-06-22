'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("AuthTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    if request = invalid then
        m.top.response = { ok: false, errorMessage: "Invalid request." }
        return
    end if

    action = request.action
    if action = "login" then
        m.top.response = login(request)
    else if action = "authorize" then
        m.top.response = authorize(request)
    ' else if action = "logout" then
    '     m.top.response = Authentication_Logout(request)
    else
        m.top.response = { ok: false, errorMessage: "Unknown request action." }
    end if
end sub

'-------------------------------------------------------------------------------
' login
'-------------------------------------------------------------------------------
function login(request as object) as object
    
    body = Json_Object([
        Json_Pair("Username", request.username)
        Json_Pair("Pw", request.password)
    ])

    loginUrl = request.server + "/Users/AuthenticateByName?format=json"
    result = HttpClient_Request(loginUrl, "POST", invalid, body, {
        Authorization: JellyfinAuth_BuildClientHeader()
    })
    
    if result.ok <> true then return result
    payload = result.data

    if payload = invalid or payload.AccessToken = invalid or payload.AccessToken = "" then
        return { ok: false, errorMessage: "The server response did not include an access token." }
    end if

    if payload.User = invalid then
        return { ok: false, errorMessage: "The server response did not include a user." }
    end if

    return {
        ok: true
        action: "login"
        server: request.server
        payload: payload
    }

end function

'-------------------------------------------------------------------------------
' authorize
'-------------------------------------------------------------------------------
function authorize(request as object) as object
    if request.server = invalid or request.server = "" then
        return { ok: false, action: "authorize", errorMessage: "Missing server for saved session." }
    end if

    if request.token = invalid or request.token = "" then
        return { ok: false, action: "authorize", authExpired: true, errorMessage: "Missing token for saved session." }
    end if

    if request.userId = invalid or request.userId = "" then
        return { ok: false, action: "authorize", authExpired: true, errorMessage: "Missing user id for saved session." }
    end if

    ' The official Jellyfin Roku app loads the saved token into session and uses
    ' AboutMe(), with a fallback AuthenticateByName call using an empty password.
    ' We validate the token directly against the current user endpoint instead.
    userUrl = NormalizeServerUrl(request.server) + "/Users/" + SafeString(request.userId, "")
    result = HttpClient_Request(userUrl, "GET", request.token, invalid, {
        Authorization: JellyfinAuth_BuildPlaybackHeader(request.token, request.userId)
    })

    if result.ok <> true then
        result.action = "authorize"
        return result
    end if

    if result.data = invalid then
        return { ok: false, action: "authorize", errorMessage: "The server response did not include a user." }
    end if

    return {
        ok: true
        action: "authorize"
        server: request.server
        token: request.token
        payload: {
            AccessToken: request.token
            User: result.data
        }
    }
end function

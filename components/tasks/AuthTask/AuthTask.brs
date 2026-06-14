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
        m.top.response = Authentication_AuthorizeToken(request)
    else if action = "logout" then
        m.top.response = Authentication_Logout(request)
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
    m.log.write(loginUrl)
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

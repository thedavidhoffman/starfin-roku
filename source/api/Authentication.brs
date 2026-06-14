'-------------------------------------------------------------------------------
' Authentication_Login
'-------------------------------------------------------------------------------
function Authentication_Login(request as object) as object

    log = CreateLogger("(API) Authentication_Login")
    log.write("Authentication_Login")

    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ' hardcoded sample login
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    return {
        ok: true
        action: "login"
        server: request.server
        payload: {
            user: {
                username: "user",
                id: "550e8400-e29b-41d4-a716-446655440000",
                token: "example.token.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzYW1wbGUtdXNlciIsImlhdCI6MTcxNzIwMDAwMH0"
            }
        }
    }

    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ' example login workflow, wire up to your needs
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    ' server = request.server
    ' body = __BuildLoginBodyJson(request)
    ' loginUrl = server + "/login"
    ' result = HttpClient_Request(loginUrl, "POST", invalid, body)

    ' log.write(loginUrl)
    ' log.write("status = " + SafeString(result.status, ""))

    ' if result.ok <> true then return result
    ' payload = result.data

    ' if payload = invalid or payload.user = invalid or payload.user.token = invalid then
    '     return { ok: false, errorMessage: "The server response did not include a token." }
    ' end if

    ' return {
    '     ok: true
    '     action: "login"
    '     server: server
    '     payload: payload
    ' }
    
end function

'-------------------------------------------------------------------------------
' __BuildLoginBodyJson
'-------------------------------------------------------------------------------
function __BuildLoginBodyJson(request as object) as string
    return Json_Object([
        Json_Pair("username", request.username)
        Json_Pair("password", request.password)
    ])
end function

'-------------------------------------------------------------------------------
' Authentication_AuthorizeToken
'-------------------------------------------------------------------------------
function Authentication_AuthorizeToken(request as object) as object

    log = CreateBufferedLogger("(API) Authentication_AuthorizeToken")

    server = request.server
    authorizeUrl = server + "/api/authorize"
    result = HttpClient_Request(authorizeUrl, "POST", request.token, "")
    log.write(authorizeUrl)
    log.write("status = " + SafeString(result.status, ""))
    if result.ok <> true then
        log.flush()
        return result
    end if

    log.flush()

    return {
        ok: true
        action: "authorize"
        server: server
        token: request.token
        payload: result.data
    }
end function

'-------------------------------------------------------------------------------
' Authentication_Logout
'-------------------------------------------------------------------------------
function Authentication_Logout(request as object) as object
    log = CreateBufferedLogger("(API) Authentication_Logout")
    server = request.server
    logoutUrl = server + "/logout"
    result = HttpClient_Request(logoutUrl, "POST", request.token, "")
    log.write(logoutUrl)
    log.write("status = " + SafeString(result.status, ""))
    if result.ok <> true and result.status <> 401 then
        log.flush()
        return result
    end if
    log.flush()
    return { ok: true, action: "logout" }
end function

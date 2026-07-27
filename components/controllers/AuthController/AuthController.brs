'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()

    m.log = CreateLogger("AuthController")
    m.log.write("init")

    m.authApiTask = m.top.findNode("authApiTask")
    m.savedSession = AuthStore_Load()
    m.isResumingSession = false

    if m.authApiTask <> invalid then m.authApiTask.observeField("response", "onAuthApiResponse")
    m.top.savedSession = m.savedSession
end sub

'-------------------------------------------------------------------------------
' onResumeRequested
'-------------------------------------------------------------------------------
sub onResumeRequested()

    m.log.write("onResumeRequested")

    if hasSavedSession() then
        m.isResumingSession = true
        runAuthApiRequest({
            action: "authorize"
            server: m.savedSession.server
            token: m.savedSession.token
            userId: m.savedSession.userId
        })
    else
        publishLoginRequired("Enter your Jellyfin server and credentials to begin.")
    end if
end sub

'-------------------------------------------------------------------------------
' onLoginRequestChanged
'-------------------------------------------------------------------------------
sub onLoginRequestChanged()

    m.log.write("onLoginRequestChanged")

    request = m.top.loginRequest
    if request = invalid then return

    m.isResumingSession = false
    runAuthApiRequest(request)
end sub

'-------------------------------------------------------------------------------
' onLogoutRequestChanged
'-------------------------------------------------------------------------------
sub onLogoutRequestChanged()

    m.log.write("onLogoutRequestChanged")

    request = m.top.logoutRequest

    if request <> invalid and request.server <> invalid and request.server <> "" and request.token <> invalid and request.token <> "" then
        runAuthApiRequest({
            action: "logout"
            server: request.server
            token: request.token
        })
    end if

    clearSavedSession()
    publishLoginRequired("Signed out.")
end sub

'-------------------------------------------------------------------------------
' clearSavedSession
'-------------------------------------------------------------------------------
sub clearSavedSession()

    m.log.write("clearSavedSession")

    AuthStore_Clear(false)
    if m.savedSession <> invalid then m.savedSession.token = ""
    m.top.savedSession = m.savedSession
end sub

'-------------------------------------------------------------------------------
' hasSavedSession
'-------------------------------------------------------------------------------
function hasSavedSession() as boolean
    if m.savedSession = invalid then return false
    if m.savedSession.token = invalid or m.savedSession.token = "" then return false
    if m.savedSession.server = invalid or m.savedSession.server = "" then return false
    if m.savedSession.userId = invalid or m.savedSession.userId = "" then return false

    return true
end function

'-------------------------------------------------------------------------------
' runAuthApiRequest
'-------------------------------------------------------------------------------
sub runAuthApiRequest(request as object)

    m.log.write("runAuthApiRequest")

    if m.authApiTask = invalid then return

    m.authApiTask.request = request
    m.authApiTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onAuthApiResponse
'-------------------------------------------------------------------------------
sub onAuthApiResponse()

    m.log.write("onAuthApiResponse")

    response = m.authApiTask.response
    if response = invalid then return

    action = getAuthResponseAction(response)
    if response.ok <> true then
        handleAuthError(response, action)
    else if action = "login" or action = "authorize" then
        m.isResumingSession = false
        storeAuthenticatedSession(response)
    end if
end sub

'-------------------------------------------------------------------------------
' getAuthResponseAction
'-------------------------------------------------------------------------------
function getAuthResponseAction(response as dynamic) as string

    m.log.write("getAuthResponseAction")

    if response <> invalid and response.action <> invalid then return response.action
    if m.authApiTask <> invalid and m.authApiTask.request <> invalid and m.authApiTask.request.action <> invalid then
        return m.authApiTask.request.action
    end if

    return ""
end function

'-------------------------------------------------------------------------------
' handleAuthError
'-------------------------------------------------------------------------------
sub handleAuthError(response as object, action as string)

    m.log.write("handleAuthError")

    if m.isResumingSession = true then
        m.isResumingSession = false
        clearSavedSession()
        publishLoginRequired("Your saved session expired. Please sign in again.")
    else if response.authExpired = true then
        publishSessionExpired(response.errorMessage)
    else if action = "login" then
        publishLoginFailed("Login failed: " + SafeString(response.errorMessage, "Unknown error."))
    end if

end sub

'-------------------------------------------------------------------------------
' storeAuthenticatedSession
'-------------------------------------------------------------------------------
sub storeAuthenticatedSession(response as object)

    m.log.write("storeAuthenticatedSession")

    m.savedSession = buildAuthenticatedSession(response)
    saveAuthenticatedSession(m.savedSession)
    m.top.savedSession = m.savedSession
    m.top.authenticatedSession = m.savedSession
end sub

'-------------------------------------------------------------------------------
' buildAuthenticatedSession
'-------------------------------------------------------------------------------
function buildAuthenticatedSession(response as object) as object

    payload = response.payload
    sessionToken = response.token
    username = ""
    userId = invalid

    if payload <> invalid and payload.AccessToken <> invalid then
        sessionToken = payload.AccessToken
    end if
    
    server = response.server

    if payload <> invalid and payload.User <> invalid then
        username = SafeString(payload.User.Name, "")
        userId = payload.User.Id
    end if

    return {
        server: server
        username: username
        token: sessionToken
        userId: userId
    }

end function

'-------------------------------------------------------------------------------
' saveAuthenticatedSession
'-------------------------------------------------------------------------------
sub saveAuthenticatedSession(session as object)
    AuthStore_Save(session.server, session.username, session.token, session.userId)
end sub

'-------------------------------------------------------------------------------
' publishLoginRequired
'-------------------------------------------------------------------------------
sub publishLoginRequired(message as string)

    m.log.write("publishLoginRequired")

    m.top.loginRequired = {
        message: message
    }
end sub

'-------------------------------------------------------------------------------
' publishLoginFailed
'-------------------------------------------------------------------------------
sub publishLoginFailed(message as string)

    m.log.write("publishLoginFailed")

    m.top.loginFailed = {
        message: message
    }
end sub

'-------------------------------------------------------------------------------
' publishSessionExpired
'-------------------------------------------------------------------------------
sub publishSessionExpired(message as dynamic)

    m.log.write("publishSessionExpired")

    clearSavedSession()

    m.top.sessionExpired = {
        message: SafeString(message, "Your session expired. Please sign in again.")
    }
end sub

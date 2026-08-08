'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()

    m.log = CreateLogger("AuthController")
    m.log.write("init")

    m.authApiTask = m.top.findNode("authApiTask")
    m.savedSession = AuthStore_Load()
    m.authState = {
        isResumingSession: false
        pendingSwitch: invalid
        logoutTasks: []
    }

    if m.authApiTask <> invalid then m.authApiTask.observeField("response", "onAuthApiResponse")
    m.top.savedSession = m.savedSession
end sub

'-------------------------------------------------------------------------------
' onResumeRequested
'-------------------------------------------------------------------------------
sub onResumeRequested()

    m.log.write("onResumeRequested")

    if hasSavedSession() then
        m.authState.isResumingSession = true
        runAuthApiRequest({
            action: "authorize"
            server: m.savedSession.server
            token: m.savedSession.token
            userId: m.savedSession.userId
        })
    else
        publishLoginRequired("Enter your Jellyfin server and credentials to begin.", true)
    end if
end sub

'-------------------------------------------------------------------------------
' onLoginRequestChanged
'-------------------------------------------------------------------------------
sub onLoginRequestChanged()

    m.log.write("onLoginRequestChanged")

    request = m.top.loginRequest
    if request = invalid then return

    m.authState.isResumingSession = false
    m.authState.pendingSwitch = invalid
    runAuthApiRequest(request)
end sub

'-------------------------------------------------------------------------------
' onLogoutRequestChanged
'-------------------------------------------------------------------------------
sub onLogoutRequestChanged()

    m.log.write("onLogoutRequestChanged")

    request = m.top.logoutRequest

    if request <> invalid and request.server <> invalid and request.server <> "" and request.token <> invalid and request.token <> "" then
        runLogoutApiRequest({
            action: "logout"
            server: request.server
            token: request.token
        })
    end if

    clearSavedSession()
    publishLoginRequired("Signed out.", true)
end sub

'-------------------------------------------------------------------------------
' onExpireActiveSessionRequested
'-------------------------------------------------------------------------------
sub onExpireActiveSessionRequested()
    request = m.top.expireActiveSessionRequested
    accountKey = SafeString(request.accountKey, "")
    if accountKey = "" or accountKey <> SafeString(m.savedSession.accountKey, "") then return
    if SafeString(m.savedSession.token, "") = "" then return
    server = SafeString(m.savedSession.server, "")
    username = SafeString(m.savedSession.username, "")
    clearSavedSession()
    m.top.sessionExpired = {
        message: SafeString(request.message, "Your session expired. Please sign in again.")
        server: server
        username: username
        accountKey: SafeString(m.savedSession.accountKey, "")
        clearRuntimeSession: true
    }
end sub

'-------------------------------------------------------------------------------
' onSwitchAccountRequestChanged
'-------------------------------------------------------------------------------
sub onSwitchAccountRequestChanged()
    request = m.top.switchAccountRequest
    if request = invalid then return

    accountKey = SafeString(request.accountKey, "")
    source = SafeString(request.source, "header")
    account = AuthStore_LoadAccount(accountKey, true)
    if account = invalid then
        publishLoginFailed("The selected account is no longer available.", { accountKey: accountKey, source: source })
        return
    end if

    m.authState.isResumingSession = false
    m.authState.pendingSwitch = {
        account: account
        accountKey: accountKey
        source: source
    }
    runAuthApiRequest({
        action: "authorize"
        server: account.server
        token: account.token
        userId: account.userId
    })
end sub

'-------------------------------------------------------------------------------
' getAccountsForServer
'-------------------------------------------------------------------------------
function getAccountsForServer(server as string) as object
    return AuthStore_ListAccounts(server)
end function

'-------------------------------------------------------------------------------
' clearSavedSession
'-------------------------------------------------------------------------------
sub clearSavedSession()

    m.log.write("clearSavedSession")

    accountKey = SafeString(m.savedSession.accountKey, "")
    if accountKey <> "" then AuthStore_RemoveToken(accountKey)
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
        m.authState.isResumingSession = false
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

    if m.authState.pendingSwitch <> invalid then
        pendingSwitch = m.authState.pendingSwitch
        account = pendingSwitch.account
        m.authState.pendingSwitch = invalid
        if response.authExpired = true then
            AuthStore_RemoveToken(account.accountKey)
            m.top.sessionExpired = {
                message: SafeString(response.errorMessage, "Your saved session expired. Please sign in again.")
                server: account.server
                username: account.username
                accountKey: pendingSwitch.accountKey
                source: pendingSwitch.source
                clearRuntimeSession: false
            }
        else
            publishLoginFailed("Account switch failed: " + SafeString(response.errorMessage, "Unknown error."), pendingSwitch)
        end if
    else if m.authState.isResumingSession = true then
        m.authState.isResumingSession = false
        if response.authExpired = true then
            server = SafeString(m.savedSession.server, "")
            username = SafeString(m.savedSession.username, "")
            clearSavedSession()
            m.top.sessionExpired = {
                message: "Your saved session expired. Please sign in again."
                server: server
                username: username
                accountKey: SafeString(m.savedSession.accountKey, "")
                clearRuntimeSession: true
            }
        else
            publishLoginRequired("Unable to resume the saved session: " + SafeString(response.errorMessage, "Unknown error."), false)
        end if
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
    m.savedSession.accountKey = AuthStore_BuildAccountKey(m.savedSession.server, m.savedSession.userId)
    m.authState.pendingSwitch = invalid
    m.top.savedSession = m.savedSession
    m.top.authenticatedSession = m.savedSession
end sub

'-------------------------------------------------------------------------------
' runLogoutApiRequest
'-------------------------------------------------------------------------------
sub runLogoutApiRequest(request as object)
    task = CreateObject("roSGNode", "AuthTask")
    task.observeField("response", "onLogoutApiResponse")
    m.top.appendChild(task)
    m.authState.logoutTasks.Push(task)
    task.request = request
    task.control = "run"
end sub

'-------------------------------------------------------------------------------
' onLogoutApiResponse
'-------------------------------------------------------------------------------
sub onLogoutApiResponse(event as object)
    task = event.getRoSGNode()
    response = event.getData()
    if response <> invalid and response.ok <> true then
        m.log.write("Logout revocation failed: " + SafeString(response.errorMessage, "Unknown error."))
    end if
    for i = m.authState.logoutTasks.Count() - 1 to 0 step -1
        if m.authState.logoutTasks[i].isSameNode(task) then
            m.authState.logoutTasks.Delete(i)
            exit for
        end if
    end for
    m.top.removeChild(task)
end sub

'-------------------------------------------------------------------------------
' buildAuthenticatedSession
'-------------------------------------------------------------------------------
function buildAuthenticatedSession(response as object) as object

    payload = response.payload
    sessionToken = response.token
    username = ""
    userId = invalid
    primaryImageTag = ""

    if payload <> invalid and payload.AccessToken <> invalid then
        sessionToken = payload.AccessToken
    end if
    
    server = response.server

    if payload <> invalid and payload.User <> invalid then
        username = SafeString(payload.User.Name, "")
        userId = payload.User.Id
        primaryImageTag = SafeString(payload.User.PrimaryImageTag, "")
    end if

    return {
        accountKey: AuthStore_BuildAccountKey(server, userId)
        server: server
        username: username
        token: sessionToken
        userId: userId
        primaryImageTag: primaryImageTag
    }

end function

'-------------------------------------------------------------------------------
' saveAuthenticatedSession
'-------------------------------------------------------------------------------
sub saveAuthenticatedSession(session as object)
    AuthStore_Save(session.server, session.username, session.token, session.userId, session.primaryImageTag)
end sub

'-------------------------------------------------------------------------------
' publishLoginRequired
'-------------------------------------------------------------------------------
sub publishLoginRequired(message as string, openSavedAccounts = false as boolean)

    m.log.write("publishLoginRequired")

    m.top.loginRequired = {
        message: message
        openSavedAccounts: openSavedAccounts
    }
end sub

'-------------------------------------------------------------------------------
' publishLoginFailed
'-------------------------------------------------------------------------------
sub publishLoginFailed(message as string, context = invalid as dynamic)

    m.log.write("publishLoginFailed")

    result = {
        message: message
    }
    if context <> invalid then
        result.accountKey = SafeString(context.accountKey, "")
        result.source = SafeString(context.source, "")
    end if
    m.top.loginFailed = result
end sub

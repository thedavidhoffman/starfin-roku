'-------------------------------------------------------------------------------
' authSyncSavedSessionToLogin
'-------------------------------------------------------------------------------
sub authSyncSavedSessionToLogin()
    m.login.savedSession = m.authController.savedSession
end sub

'-------------------------------------------------------------------------------
' authRequestResumeSession
'-------------------------------------------------------------------------------
sub authRequestResumeSession()
    m.login.visible = false
    m.authenticatedContent.visible = false
    m.authController.resumeRequested = true
end sub

'-------------------------------------------------------------------------------
' authHandleLoginRequested
'-------------------------------------------------------------------------------
sub authHandleLoginRequested()
    m.authController.loginRequest = m.login.loginRequested
end sub

'-------------------------------------------------------------------------------
' authShowLogin
'-------------------------------------------------------------------------------
sub authShowLogin(message as string)
    m.login.statusMessage = message
    navShowLoginRoute()
end sub

'-------------------------------------------------------------------------------
' authHandleExpiredSession
'-------------------------------------------------------------------------------
sub authHandleExpiredSession(message as string)
    m.authController.callFunc("clearSavedSession")
    if m.session <> invalid then m.session.token = ""
    m.login.passwordValue = ""
    authShowLogin(message)
end sub

'-------------------------------------------------------------------------------
' handleComponentError
'-------------------------------------------------------------------------------
function handleComponentError(response as dynamic) as boolean
    if response = invalid then return false

    if response.authExpired = true then
        authHandleExpiredSession(response.errorMessage)
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' authHandleLogoutPressed
'-------------------------------------------------------------------------------
sub authHandleLogoutPressed()
    themeAudioStop()
    resetDynamicPages()

    request = {
        server: ""
        token: ""
    }
    if m.session <> invalid then
        if m.session.server <> invalid then request.server = m.session.server
        if m.session.token <> invalid then request.token = m.session.token
        m.session.token = ""
    end if
    if m.authController <> invalid then m.authController.logoutRequest = request

    m.login.passwordValue = ""
end sub

'-------------------------------------------------------------------------------
' authHandleAuthenticatedSession
'-------------------------------------------------------------------------------
sub authHandleAuthenticatedSession()
    session = m.authController.authenticatedSession
    if session = invalid then return

    m.session = session
    syncHeaderUserIdentity()
    navShowApp()
end sub

'-------------------------------------------------------------------------------
' authHandleLoginRequired
'-------------------------------------------------------------------------------
sub authHandleLoginRequired()
    request = m.authController.loginRequired
    if request = invalid then return

    authShowLogin(request.message)
end sub

'-------------------------------------------------------------------------------
' authHandleLoginFailed
'-------------------------------------------------------------------------------
sub authHandleLoginFailed()
    response = m.authController.loginFailed
    if response = invalid then return

    m.login.statusMessage = response.message
end sub

'-------------------------------------------------------------------------------
' authHandleSavedSessionChanged
'-------------------------------------------------------------------------------
sub authHandleSavedSessionChanged()
    authSyncSavedSessionToLogin()
end sub

'-------------------------------------------------------------------------------
' authHandleSessionExpired
'-------------------------------------------------------------------------------
sub authHandleSessionExpired()
    response = m.authController.sessionExpired
    if response = invalid then return

    authHandleExpiredSession(response.message)
end sub

'-------------------------------------------------------------------------------
' buildSessionLoadRequest
'-------------------------------------------------------------------------------
function buildSessionLoadRequest() as object
    
    if m.session = invalid then THROW("[MainScene.buildSessionLoadRequest()] session is invalid.")
    if m.session.server = invalid then THROW("[MainScene.buildSessionLoadRequest()] session.server is invalid.")
    if m.session.token = invalid then THROW("[MainScene.buildSessionLoadRequest()] session.token is invalid.")
    
    return {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
    }

end function

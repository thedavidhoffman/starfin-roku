'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()

    initReferences()
    initValues()
    initHandlers()
    initSettings()

    authSyncSavedSessionToLogin()
    authRequestResumeSession()

end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.authenticatedContent = m.top.findNode("authenticatedContent")
    m.authController = m.top.findNode("authController")
    m.cacheController = m.top.findNode("cacheController")
    m.header = m.top.findNode("header")
    m.homePage = m.top.findNode("homePage")
    m.login = m.top.findNode("login")
    m.overlayHost = m.top.findNode("overlayHost")
    m.statusLabel = m.top.findNode("statusLabel")
    m.dynamicPageHost = m.top.findNode("dynamicPageHost")
    m.navigationController = m.top.findNode("navigationController")
end sub

'-------------------------------------------------------------------------------
' initValues
'-------------------------------------------------------------------------------
sub initValues()
    m.session = invalid
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()

    m.login.observeField("loginRequested", "authHandleLoginRequested")
    m.authController.observeField("authenticatedSession", "authHandleAuthenticatedSession")
    m.authController.observeField("loginFailed", "authHandleLoginFailed")
    m.authController.observeField("loginRequired", "authHandleLoginRequired")
    m.authController.observeField("savedSession", "authHandleSavedSessionChanged")
    m.authController.observeField("sessionExpired", "authHandleSessionExpired")
    m.homePage.observeField("selectedMovie", "movieDetailsHandleHomeMovieSelected")
    m.navigationController.observeField("currentRoute", "navHandleCurrentRouteChanged")

end sub

'===============================================================================
' Movie Details
'===============================================================================

'-------------------------------------------------------------------------------
' movieDetailsHandleHomeMovieSelected
'-------------------------------------------------------------------------------
sub movieDetailsHandleHomeMovieSelected()
    selection = m.homePage.selectedMovie
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    page = CreateObject("roSGNode", "MovieDetails")
    page.observeField("closeRequested", "movieDetailsHandleCloseRequested")
    page.observeField("playSelected", "movieDetailsHandlePlaySelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
    }

    resetDynamicPages()
    m.movieDetailsPage = page
    m.dynamicPageHost.appendChild(page)
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' movieDetailsHandlePlaySelected
'-------------------------------------------------------------------------------
sub movieDetailsHandlePlaySelected()
    selection = m.movieDetailsPage.playSelected
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    playerShow(selection)
end sub

'-------------------------------------------------------------------------------
' movieDetailsHandleCloseRequested
'-------------------------------------------------------------------------------
sub movieDetailsHandleCloseRequested()
    resetDynamicPages()
    m.homePage.visible = true
    m.header.visible = true
    m.homePage.callFunc("activate")
end sub

'===============================================================================
' Player
'===============================================================================

'-------------------------------------------------------------------------------
' playerShow
'-------------------------------------------------------------------------------
sub playerShow(selection as object)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    player = CreateObject("roSGNode", "VideoPlayer")
    player.observeField("closeRequested", "playerHandleCloseRequested")
    player.playRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
    }

    if m.movieDetailsPage <> invalid then m.movieDetailsPage.visible = false
    m.videoPlayer = player
    m.dynamicPageHost.appendChild(player)
    m.homePage.visible = false
    m.header.visible = false
    player.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' playerHandleCloseRequested
'-------------------------------------------------------------------------------
sub playerHandleCloseRequested()
    if m.videoPlayer <> invalid then
        m.dynamicPageHost.removeChild(m.videoPlayer)
        m.videoPlayer = invalid
    end if

    if m.movieDetailsPage <> invalid then
        m.movieDetailsPage.visible = true
        m.movieDetailsPage.callFunc("activate")
    else
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'-------------------------------------------------------------------------------
' initSettings
'-------------------------------------------------------------------------------
sub initSettings()
    m.displaySettings = SettingsStore_Load()
end sub

'-------------------------------------------------------------------------------
' statusSetMessage
'-------------------------------------------------------------------------------
sub statusSetMessage(message as dynamic)
    m.statusLabel.text = SafeString(message, "")
end sub

'===============================================================================
' Auth / Session
'===============================================================================

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
    m.navigationController.callFunc("reset", { id: "login" })
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

'===============================================================================
' Navigation / Header / Search
'===============================================================================

'-------------------------------------------------------------------------------
' navShowApp
'-------------------------------------------------------------------------------
sub navShowApp()
    loadRequest = buildSessionLoadRequest()
    m.homePage.loadRequest = loadRequest
    m.navigationController.callFunc("reset", { id: "app" })
end sub

'-------------------------------------------------------------------------------
' navHandleCurrentRouteChanged
'-------------------------------------------------------------------------------
sub navHandleCurrentRouteChanged()
    route = m.navigationController.currentRoute
    if route = invalid then return

    if route.id = "login" then
        navShowLoginRoute()
    else if route.id = "app" then
        navShowAppRoute()
    end if
end sub

'-------------------------------------------------------------------------------
' navShowLoginRoute
'-------------------------------------------------------------------------------
sub navShowLoginRoute()
    m.login.visible = true
    m.authenticatedContent.visible = false
    m.homePage.visible = false
    resetDynamicPages()
    m.login.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' navShowAppRoute
'-------------------------------------------------------------------------------
sub navShowAppRoute()
    m.login.visible = false
    m.authenticatedContent.visible = true
    m.homePage.visible = true
    resetDynamicPages()

    m.header.visible = true
    m.homePage.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' resetDynamicPages
'-------------------------------------------------------------------------------
sub resetDynamicPages()
    m.yourStatsPage = invalid
    m.movieDetailsPage = invalid
    m.videoPlayer = invalid
    childCount = m.dynamicPageHost.getChildCount()
    if childCount > 0 then m.dynamicPageHost.removeChildrenIndex(childCount, 0)
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


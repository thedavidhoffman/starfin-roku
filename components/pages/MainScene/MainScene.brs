'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()

    initReferences()
    initValues()
    initHandlers()

    authSyncSavedSessionToLogin()
    authRequestResumeSession()

end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.authenticatedContent = m.top.findNode("authenticatedContent")
    m.authController = m.top.findNode("authController")
    m.header = m.top.findNode("header")
    m.homePage = m.top.findNode("homePage")
    m.login = m.top.findNode("login")
    m.overlayHost = m.top.findNode("overlayHost")
    m.dynamicPageHost = m.top.findNode("dynamicPageHost")
    m.themeAudio = m.top.findNode("themeAudio")
    m.statusLabel = m.top.findNode("statusLabel")
end sub

'-------------------------------------------------------------------------------
' initValues
'-------------------------------------------------------------------------------
sub initValues()
    m.session = invalid
    m.settings = SettingsStore_Load()
    m.homeRefreshState = {
        playbackRowsDirty: false
    }
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
    m.homePage.observeField("selectedMovie", "movieHandleHomeMovieSelected")
    m.homePage.observeField("selectedSeries", "tvShowHandleHomeSeriesSelected")
    m.homePage.observeField("selectedEpisode", "tvEpisodeHandleHomeEpisodeSelected")
    m.homePage.observeField("selectedLibrary", "videoLibraryHandleHomeLibrarySelected")
    m.homePage.observeField("selectedMusicLibrary", "musicLibraryHandleHomeLibrarySelected")
    m.homePage.observeField("selectedAlbum", "musicLibraryHandleHomeAlbumSelected")
    m.homePage.observeField("selectedLiveTV", "liveTvHandleHomeSelected")
    m.homePage.observeField("selectedCollections", "collectionsHandleHomeCollectionsSelected")
    m.homePage.observeField("focusExitUp", "navHandleHomeFocusExitUp")
    m.homePage.observeField("playbackRowsRefreshCompleted", "homeHandlePlaybackRowsRefreshCompleted")
    m.header.observeField("homeSelected", "navHandleHeaderHomeSelected")
    m.header.observeField("searchSelected", "searchHandleHeaderSelected")
    m.header.observeField("downSelected", "navHandleHeaderDownSelected")
    m.header.observeField("logoutSelected", "authHandleLogoutPressed")
    m.header.observeField("overlayRequested", "navHandleHeaderOverlayRequested")
    m.overlayHost.observeField("closed", "navHandleOverlayClosed")

end sub

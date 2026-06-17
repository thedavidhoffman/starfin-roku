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
    m.homePage.observeField("selectedMovie", "movieHandleHomeMovieSelected")
    m.homePage.observeField("selectedSeries", "tvShowHandleHomeSeriesSelected")
    m.homePage.observeField("selectedLibrary", "libraryHandleHomeLibrarySelected")
    m.homePage.observeField("selectedCollections", "collectionsHandleHomeCollectionsSelected")
    m.navigationController.observeField("currentRoute", "navHandleCurrentRouteChanged")

end sub

'===============================================================================
' Collections
'===============================================================================

'-------------------------------------------------------------------------------
' collectionsHandleHomeCollectionsSelected
'-------------------------------------------------------------------------------
sub collectionsHandleHomeCollectionsSelected()
    selection = m.homePage.selectedCollections
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "Collections")
    page.observeField("closeRequested", "collectionsHandleCloseRequested")
    page.observeField("selectedCollection", "collectionsHandleCollectionSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        title: FirstNonEmpty([selection.item.Name, selection.item.name], "Collections")
        item: selection.item
    }

    resetDynamicPages()
    m.collectionsPage = page
    m.dynamicPageHost.appendChild(page)
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' collectionsHandleCollectionSelected
'-------------------------------------------------------------------------------
sub collectionsHandleCollectionSelected()
    selection = m.collectionsPage.selectedCollection
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    libraryShow({
        libraryId: selection.itemId
        collectionType: "collection"
        title: FirstNonEmpty([selection.item.Name, selection.item.name], "Collection")
        item: selection.item
    }, true)
end sub

'-------------------------------------------------------------------------------
' collectionsHandleCloseRequested
'-------------------------------------------------------------------------------
sub collectionsHandleCloseRequested()
    resetDynamicPages()
    m.homePage.visible = true
    m.header.visible = true
    m.homePage.callFunc("activate")
end sub

'===============================================================================
' Library
'===============================================================================

'-------------------------------------------------------------------------------
' libraryHandleHomeLibrarySelected
'-------------------------------------------------------------------------------
sub libraryHandleHomeLibrarySelected()
    selection = m.homePage.selectedLibrary
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    libraryShow({
        libraryId: selection.libraryId
        collectionType: selection.collectionType
        title: FirstNonEmpty([selection.item.Name, selection.item.name], "Library")
        item: selection.item
    }, false)
end sub

'-------------------------------------------------------------------------------
' libraryShow
'-------------------------------------------------------------------------------
sub libraryShow(selection as object, fromCollections as boolean)
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "Library")
    page.observeField("closeRequested", "libraryHandleCloseRequested")
    page.observeField("selectedMovie", "libraryHandleMovieSelected")
    page.observeField("selectedSeries", "libraryHandleSeriesSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        includeItemTypes: getLibraryIncludeItemTypes(SafeString(selection.collectionType, ""))
        title: SafeString(selection.title, "Library")
        item: selection.item
        fromCollections: fromCollections
    }

    if fromCollections <> true then resetDynamicPages()
    m.libraryPage = page
    m.dynamicPageHost.appendChild(page)
    if m.collectionsPage <> invalid then m.collectionsPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' getLibraryIncludeItemTypes
'-------------------------------------------------------------------------------
function getLibraryIncludeItemTypes(collectionType as string) as string
    if collectionType = "tvshows" then return "Series"
    if collectionType = "collection" then return "Movie,Series"
    return "Movie"
end function

'-------------------------------------------------------------------------------
' libraryHandleMovieSelected
'-------------------------------------------------------------------------------
sub libraryHandleMovieSelected()
    selection = m.libraryPage.selectedMovie
    if selection = invalid then return
    movieShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' libraryHandleSeriesSelected
'-------------------------------------------------------------------------------
sub libraryHandleSeriesSelected()
    selection = m.libraryPage.selectedSeries
    if selection = invalid then return
    tvShowShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' libraryHandleCloseRequested
'-------------------------------------------------------------------------------
sub libraryHandleCloseRequested()
    if m.libraryPage <> invalid then
        m.dynamicPageHost.removeChild(m.libraryPage)
        m.libraryPage = invalid
    end if

    if m.collectionsPage <> invalid then
        m.collectionsPage.visible = true
        m.collectionsPage.callFunc("activate")
    else
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'===============================================================================
' TV Show
'===============================================================================

'-------------------------------------------------------------------------------
' tvShowHandleHomeSeriesSelected
'-------------------------------------------------------------------------------
sub tvShowHandleHomeSeriesSelected()
    selection = m.homePage.selectedSeries
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    tvShowShow(selection, true)
end sub

'-------------------------------------------------------------------------------
' tvShowShow
'-------------------------------------------------------------------------------
sub tvShowShow(selection as object, shouldReset as boolean)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    page = CreateObject("roSGNode", "TVShow")
    page.observeField("closeRequested", "tvShowHandleCloseRequested")
    page.observeField("selectedSeason", "tvSeasonHandleTVShowSeasonSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
    }

    if shouldReset then resetDynamicPages()
    m.tvShowPage = page
    m.dynamicPageHost.appendChild(page)
    if m.libraryPage <> invalid then m.libraryPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' tvSeasonHandleTVShowSeasonSelected
'-------------------------------------------------------------------------------
sub tvSeasonHandleTVShowSeasonSelected()
    selection = m.tvShowPage.selectedSeason
    if selection = invalid then return
    if selection.seriesId = invalid or selection.seriesId = "" then return
    if selection.seasonId = invalid or selection.seasonId = "" then return

    page = CreateObject("roSGNode", "TVSeason")
    page.observeField("closeRequested", "tvSeasonHandleCloseRequested")
    page.observeField("selectedEpisode", "tvSeasonHandleEpisodeSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        seriesId: selection.seriesId
        seasonId: selection.seasonId
        series: selection.series
        season: selection.season
    }

    m.tvSeasonPage = page
    m.dynamicPageHost.appendChild(page)
    m.tvShowPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' tvSeasonHandleEpisodeSelected
'-------------------------------------------------------------------------------
sub tvSeasonHandleEpisodeSelected()
    selection = m.tvSeasonPage.selectedEpisode
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    playerShow(selection)
end sub

'-------------------------------------------------------------------------------
' tvSeasonHandleCloseRequested
'-------------------------------------------------------------------------------
sub tvSeasonHandleCloseRequested()
    if m.tvSeasonPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvSeasonPage)
        m.tvSeasonPage = invalid
    end if

    if m.tvShowPage <> invalid then
        m.tvShowPage.visible = true
        m.tvShowPage.callFunc("activate")
    else if m.libraryPage <> invalid then
        m.libraryPage.visible = true
        m.libraryPage.callFunc("activate")
    else
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'-------------------------------------------------------------------------------
' tvShowHandleCloseRequested
'-------------------------------------------------------------------------------
sub tvShowHandleCloseRequested()
    if m.tvShowPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvShowPage)
        m.tvShowPage = invalid
    end if

    if m.personPage <> invalid then
        m.personPage.visible = true
        m.personPage.callFunc("activate")
    else if m.libraryPage <> invalid then
        m.libraryPage.visible = true
        m.libraryPage.callFunc("activate")
    else
        resetDynamicPages()
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'===============================================================================
' Movie
'===============================================================================

'-------------------------------------------------------------------------------
' movieHandleHomeMovieSelected
'-------------------------------------------------------------------------------
sub movieHandleHomeMovieSelected()
    selection = m.homePage.selectedMovie
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    movieShow(selection, true)
end sub

'-------------------------------------------------------------------------------
' movieShow
'-------------------------------------------------------------------------------
sub movieShow(selection as object, shouldReset as boolean)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    page = CreateObject("roSGNode", "Movie")
    page.observeField("closeRequested", "movieHandleCloseRequested")
    page.observeField("playSelected", "movieHandlePlaySelected")
    page.observeField("selectedPerson", "personHandleMoviePersonSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
    }

    if shouldReset then resetDynamicPages()
    m.moviePage = page
    m.dynamicPageHost.appendChild(page)
    if m.libraryPage <> invalid then m.libraryPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' movieHandlePlaySelected
'-------------------------------------------------------------------------------
sub movieHandlePlaySelected()
    selection = m.moviePage.playSelected
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    playerShow(selection)
end sub

'===============================================================================
' Person
'===============================================================================

'-------------------------------------------------------------------------------
' personHandleMoviePersonSelected
'-------------------------------------------------------------------------------
sub personHandleMoviePersonSelected()
    selection = m.moviePage.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    personShow(selection)
end sub

'-------------------------------------------------------------------------------
' personShow
'-------------------------------------------------------------------------------
sub personShow(selection as object)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    if m.moviePage <> invalid then m.personSourceMoviePage = m.moviePage

    page = CreateObject("roSGNode", "Person")
    page.observeField("closeRequested", "personHandleCloseRequested")
    page.observeField("selectedFilmography", "filmographyHandlePersonFilmographySelected")
    page.observeField("selectedMovie", "personHandleMovieSelected")
    page.observeField("selectedSeries", "personHandleSeriesSelected")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
    }

    m.personPage = page
    m.dynamicPageHost.appendChild(page)
    if m.moviePage <> invalid then m.moviePage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' personHandleMovieSelected
'-------------------------------------------------------------------------------
sub personHandleMovieSelected()
    selection = m.personPage.selectedMovie
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    movieShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' personHandleSeriesSelected
'-------------------------------------------------------------------------------
sub personHandleSeriesSelected()
    selection = m.personPage.selectedSeries
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    tvShowShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' personHandleCloseRequested
'-------------------------------------------------------------------------------
sub personHandleCloseRequested()
    if m.personPage <> invalid then
        m.dynamicPageHost.removeChild(m.personPage)
        m.personPage = invalid
    end if

    if m.moviePage = invalid and m.personSourceMoviePage <> invalid then m.moviePage = m.personSourceMoviePage
    m.personSourceMoviePage = invalid

    if m.moviePage <> invalid then
        m.moviePage.visible = true
        m.moviePage.callFunc("activate")
    else
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'===============================================================================
' Filmography
'===============================================================================

'-------------------------------------------------------------------------------
' filmographyHandlePersonFilmographySelected
'-------------------------------------------------------------------------------
sub filmographyHandlePersonFilmographySelected()
    selection = m.personPage.selectedFilmography
    if selection = invalid then return
    if selection.personId = invalid or selection.personId = "" then return

    filmographyShow(selection)
end sub

'-------------------------------------------------------------------------------
' filmographyShow
'-------------------------------------------------------------------------------
sub filmographyShow(selection as object)
    if selection = invalid then return
    if selection.personId = invalid or selection.personId = "" then return

    page = CreateObject("roSGNode", "Filmography")
    page.observeField("closeRequested", "filmographyHandleCloseRequested")
    page.loadRequest = selection

    m.filmographyPage = page
    m.dynamicPageHost.appendChild(page)
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' filmographyHandleCloseRequested
'-------------------------------------------------------------------------------
sub filmographyHandleCloseRequested()
    if m.filmographyPage <> invalid then
        m.dynamicPageHost.removeChild(m.filmographyPage)
        m.filmographyPage = invalid
    end if

    if m.personPage <> invalid then
        m.personPage.visible = true
        m.personPage.callFunc("activate")
    else
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
end sub

'-------------------------------------------------------------------------------
' movieHandleCloseRequested
'-------------------------------------------------------------------------------
sub movieHandleCloseRequested()
    if m.moviePage <> invalid then
        m.dynamicPageHost.removeChild(m.moviePage)
        m.moviePage = invalid
    end if

    if m.personPage <> invalid then
        if m.personSourceMoviePage <> invalid then m.moviePage = m.personSourceMoviePage
        m.personPage.visible = true
        m.personPage.callFunc("activate")
    else if m.libraryPage <> invalid then
        m.libraryPage.visible = true
        m.libraryPage.callFunc("activate")
    else
        resetDynamicPages()
        m.homePage.visible = true
        m.header.visible = true
        m.homePage.callFunc("activate")
    end if
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
        playbackQueue: selection.playbackQueue
        playbackQueueIndex: selection.playbackQueueIndex
    }

    if m.moviePage <> invalid then m.moviePage.visible = false
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.visible = false
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

    if m.moviePage <> invalid then
        m.moviePage.visible = true
        m.moviePage.callFunc("activate")
    else if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.tvSeasonPage.callFunc("activate")
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
    m.collectionsPage = invalid
    m.libraryPage = invalid
    m.moviePage = invalid
    m.tvShowPage = invalid
    m.tvSeasonPage = invalid
    m.personPage = invalid
    m.personSourceMoviePage = invalid
    m.filmographyPage = invalid
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


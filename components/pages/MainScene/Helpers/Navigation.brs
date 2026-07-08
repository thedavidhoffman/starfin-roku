'-------------------------------------------------------------------------------
' navHandleHomeFocusExitUp
'-------------------------------------------------------------------------------
sub navHandleHomeFocusExitUp()
    if m.header <> invalid and m.header.visible = true then
        m.header.callFunc("focusHeader")
    end if
end sub

'-------------------------------------------------------------------------------
' navHandleHeaderDownSelected
'-------------------------------------------------------------------------------
sub navHandleHeaderDownSelected()
    focusActiveSurface()
end sub

'-------------------------------------------------------------------------------
' navHandleHeaderHomeSelected
'-------------------------------------------------------------------------------
sub navHandleHeaderHomeSelected()
    clearStatus()
    resetDynamicPages()
    showHome()
end sub

'-------------------------------------------------------------------------------
' navHandleHeaderOverlayRequested
'-------------------------------------------------------------------------------
sub navHandleHeaderOverlayRequested()
    request = m.header.overlayRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' navHandleOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleOverlayClosed()
    closed = m.overlayHost.closed
    if closed = invalid then return

    request = closed.request
    if request <> invalid and request.id = "letterGrid" then
        libraryHandleLetterGridOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "sort" then
        libraryHandleSortOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "personOverview" then
        personHandlePersonOverviewOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "description" then
        navHandleDescriptionOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "mediaInfo" then
        navHandleMediaInfoOverlayClosed(closed)
        return
    end if

    if request <> invalid and isStreamOptionsOverlayRequest(request) then
        navHandleStreamOptionsOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "settings" and m.header <> invalid and m.header.visible = true then
        applySettingsFromOverlay(closed.overlay)
        m.header.callFunc("focusHeader")
        return
    end if

    focusActiveSurface()
end sub

'-------------------------------------------------------------------------------
' isStreamOptionsOverlayRequest
'-------------------------------------------------------------------------------
function isStreamOptionsOverlayRequest(request as object) as boolean
    id = SafeString(request.id, "")
    return id = "subtitleOptions" or id = "audioOptions" or id = "chapterOptions"
end function

'-------------------------------------------------------------------------------
' navHandleDescriptionOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleDescriptionOverlayClosed(closed as object)
    request = closed.request
    if request = invalid then return

    sourcePage = SafeString(request.sourcePage, "")
    if sourcePage = "movie" and m.moviePage <> invalid then
        m.moviePage.callFunc("handleDescriptionOverlayClosed")
    else if sourcePage = "tvEpisode" and m.tvEpisodePage <> invalid then
        m.tvEpisodePage.callFunc("handleDescriptionOverlayClosed")
    else if sourcePage = "tvShow" and m.tvShowPage <> invalid then
        m.tvShowPage.callFunc("handleDescriptionOverlayClosed")
    end if
end sub

'-------------------------------------------------------------------------------
' navHandleMediaInfoOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleMediaInfoOverlayClosed(closed as object)
    request = closed.request
    if request = invalid then return

    sourcePage = SafeString(request.sourcePage, "")
    if sourcePage = "movie" and m.moviePage <> invalid then
        m.moviePage.callFunc("handleMediaInfoOverlayClosed")
    else if sourcePage = "tvEpisode" and m.tvEpisodePage <> invalid then
        m.tvEpisodePage.callFunc("handleMediaInfoOverlayClosed")
    end if
end sub

'-------------------------------------------------------------------------------
' navHandleStreamOptionsOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleStreamOptionsOverlayClosed(closed as object)
    request = closed.request
    if request = invalid then return

    sourcePage = SafeString(request.sourcePage, "")
    if sourcePage = "videoPlayer" and m.videoPlayer <> invalid then
        m.videoPlayer.callFunc("handleStreamOptionsOverlayClosed", closed)
    else if sourcePage = "movie" and m.moviePage <> invalid then
        m.moviePage.callFunc("handleStreamOptionsOverlayClosed", closed)
    else if sourcePage = "tvEpisode" and m.tvEpisodePage <> invalid then
        m.tvEpisodePage.callFunc("handleStreamOptionsOverlayClosed", closed)
    end if
end sub

'-------------------------------------------------------------------------------
' markHomePlaybackRowsDirty
'-------------------------------------------------------------------------------
sub markHomePlaybackRowsDirty()
    if m.homeRefreshState = invalid then m.homeRefreshState = { playbackRowsDirty: false }
    m.homeRefreshState.playbackRowsDirty = true
end sub

'-------------------------------------------------------------------------------
' showHome
'-------------------------------------------------------------------------------
sub showHome()
    m.homePage.visible = true
    m.header.visible = true
    m.header.callFunc("activateHomeButton")

    if m.homeRefreshState <> invalid and m.homeRefreshState.playbackRowsDirty = true then
        m.homePage.callFunc("activateBlocking")
    else
        m.homePage.callFunc("focusHome")
    end if
end sub

'-------------------------------------------------------------------------------
' homeHandlePlaybackRowsRefreshCompleted
'-------------------------------------------------------------------------------
sub homeHandlePlaybackRowsRefreshCompleted()
    if m.homeRefreshState = invalid then return
    m.homeRefreshState.playbackRowsDirty = false
end sub

'-------------------------------------------------------------------------------
' focusActiveSurface
'-------------------------------------------------------------------------------
sub focusActiveSurface()
    if m.videoPlayer <> invalid and m.videoPlayer.visible = true then
        m.videoPlayer.setFocus(true)
    else if m.filmographyPage <> invalid and m.filmographyPage.visible = true then
        m.filmographyPage.callFunc("activate")
    else if m.personPage <> invalid and m.personPage.visible = true then
        m.personPage.callFunc("activate")
    else if m.moviePage <> invalid and m.moviePage.visible = true then
        m.moviePage.callFunc("activate")
    else if m.tvEpisodePage <> invalid and m.tvEpisodePage.visible = true then
        m.tvEpisodePage.callFunc("activate")
    else if m.tvSeasonPage <> invalid and m.tvSeasonPage.visible = true then
        m.tvSeasonPage.callFunc("activate")
    else if m.tvShowPage <> invalid and m.tvShowPage.visible = true then
        m.tvShowPage.callFunc("activate")
    else if m.liveTvPage <> invalid and m.liveTvPage.visible = true then
        m.liveTvPage.callFunc("activate")
    else if m.libraryPage <> invalid and m.libraryPage.visible = true then
        m.libraryPage.callFunc("activate")
    else if m.collectionsPage <> invalid and m.collectionsPage.visible = true then
        m.collectionsPage.callFunc("activate")
    else if m.searchPage <> invalid and m.searchPage.visible = true then
        m.searchPage.callFunc("activate")
    else if m.homePage <> invalid and m.homePage.visible = true then
        m.homePage.callFunc("focusHome")
    else if m.header <> invalid and m.header.visible = true then
        m.header.callFunc("focusHeader")
    end if
end sub

'-------------------------------------------------------------------------------
' navShowApp
'-------------------------------------------------------------------------------
sub navShowApp()
    m.settings = SettingsStore_Load()
    loadRequest = buildSessionLoadRequest()
    m.homePage.loadRequest = loadRequest
    navShowAppRoute()
end sub

'-------------------------------------------------------------------------------
' applySettingsFromOverlay
'-------------------------------------------------------------------------------
sub applySettingsFromOverlay(overlay as dynamic)
    if overlay = invalid then return
    if overlay.settingsSaved <> true then return
    if overlay.savedSettings = invalid then return

    m.settings = overlay.savedSettings
    if themeAudioIsEnabled() <> true then themeAudioStop()
    fanOutSettings()
end sub

'-------------------------------------------------------------------------------
' fanOutSettings
'-------------------------------------------------------------------------------
sub fanOutSettings()
    applySettingsToPage(m.collectionsPage)
    applySettingsToPage(m.libraryPage)
    applySettingsToPage(m.moviePage)
    applySettingsToPage(m.tvShowPage)
    applySettingsToPage(m.tvSeasonPage)
    applySettingsToPage(m.tvEpisodePage)
    applySettingsToPage(m.personPage)
end sub

'-------------------------------------------------------------------------------
' applySettingsToPage
'-------------------------------------------------------------------------------
sub applySettingsToPage(page as dynamic)
    if page = invalid then return
    if m.settings = invalid then return

    page.settings = m.settings
end sub

'-------------------------------------------------------------------------------
' navShowLoginRoute
'-------------------------------------------------------------------------------
sub navShowLoginRoute()
    clearStatus()
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
    clearStatus()
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
    clearStatus()
    themeAudioStop()
    if m.liveTvPage <> invalid then m.liveTvPage.callFunc("deactivate")
    if m.libraryPage <> invalid then m.libraryPage.callFunc("deactivate")
    if m.collectionsPage <> invalid then m.collectionsPage.callFunc("deactivate")
    if m.searchPage <> invalid then m.searchPage.callFunc("deactivate")
    if m.moviePage <> invalid then m.moviePage.callFunc("deactivate")
    if m.tvShowPage <> invalid then m.tvShowPage.callFunc("deactivate")
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.callFunc("deactivate")
    if m.tvEpisodePage <> invalid then m.tvEpisodePage.callFunc("deactivate")
    if m.personPage <> invalid then m.personPage.callFunc("deactivate")
    if m.filmographyPage <> invalid then m.filmographyPage.callFunc("deactivate")
    m.yourStatsPage = invalid
    m.searchPage = invalid
    m.collectionsPage = invalid
    m.liveTvPage = invalid
    m.libraryPage = invalid
    m.moviePage = invalid
    m.tvShowPage = invalid
    m.tvSeasonPage = invalid
    m.tvEpisodePage = invalid
    m.tvEpisodeUpNextAutoPlayPage = invalid
    m.personPage = invalid
    m.personSourceMoviePage = invalid
    m.personSourceTvEpisodePage = invalid
    m.personSourceTvSeasonPage = invalid
    m.personSourceTvShowPage = invalid
    m.personSourceVideoPlayer = invalid
    m.filmographyPage = invalid
    m.videoPlayer = invalid
    m.pendingUpNextAutoPlayRequest = invalid
    m.tvEpisodeUpNextRestorePlayRequest = invalid
    childCount = m.dynamicPageHost.getChildCount()
    if childCount > 0 then m.dynamicPageHost.removeChildrenIndex(childCount, 0)
end sub

'-------------------------------------------------------------------------------
' clearStatus
'-------------------------------------------------------------------------------
sub clearStatus()
    Spinner_Hide()
    m.statusLabel.callFunc("clearMessage")
end sub

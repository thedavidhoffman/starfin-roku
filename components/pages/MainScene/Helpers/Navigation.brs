'-------------------------------------------------------------------------------
' navHandleHomeOverlayRequested
'-------------------------------------------------------------------------------
sub navHandleHomeOverlayRequested()
    request = m.homePage.overlayRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

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

    if request.id = "settings" and m.session <> invalid then request.accountKey = SafeString(m.session.accountKey, "")

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' navHandleOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleOverlayClosed()
    closed = m.overlayHost.closed
    if closed = invalid then return

    request = closed.request
    if request <> invalid and request.id = "accountPicker" then
        authHandleAccountPickerClosed(closed)
        return
    end if
    if request <> invalid and request.id = "letterGrid" then
        videoLibraryHandleLetterGridOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "sort" then
        if SafeString(request.sourcePage, "") = "musicLibrary" then
            musicLibraryHandleSortOverlayClosed(closed)
        else
            videoLibraryHandleSortOverlayClosed(closed)
        end if
        return
    end if

    if request <> invalid and request.id = "personOverview" then
        personHandlePersonOverviewOverlayClosed()
        return
    end if

    if request <> invalid and request.id = "description" then
        navHandleDescriptionOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "mediaInfo" then
        navHandleVideoMediaInfoOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "playbackInfo" then
        if m.videoPlayer <> invalid then m.videoPlayer.callFunc("handlePlaybackInfoOverlayClosed")
        return
    end if

    if request <> invalid and request.id = "mediaActions" then
        navHandleMediaActionsOverlayClosed(closed)
        return
    end if

    if request <> invalid and isStreamOptionsOverlayRequest(request) then
        navHandleStreamOptionsOverlayClosed(closed)
        return
    end if

    if request <> invalid and request.id = "settings" and m.header <> invalid and m.header.visible = true then
        if closed.overlay <> invalid and closed.overlay.resetStarfinConfirmed = true then
            authHandleResetStarfinConfirmed()
            return
        end if
        applySettingsFromOverlay(closed.overlay)
        m.header.callFunc("focusHeader")
        return
    end if

    focusActiveSurface()
end sub

'-------------------------------------------------------------------------------
' navHandleMediaActionsOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleMediaActionsOverlayClosed(closed as object)
    request = closed.request
    overlay = closed.overlay
    if request = invalid or overlay = invalid then
        focusActiveSurface()
        return
    end if

    selection = overlay.mediaActionSelected
    focusActiveSurface()
    if selection = invalid then return

    if selection.action = "GoToSeries" then
        navOpenEpisodeSeries(selection, request)
        return
    end if

    if selection.action = "GoToSeason" then
        navOpenEpisodeSeason(selection, request)
        return
    end if

    if m.mediaActionState.activeRequest <> invalid then
        Status_SetMessage("A media action is already in progress.")
        return
    end if

    actionRequest = {
        action: selection.action
        itemId: selection.itemId
        server: request.server
        token: request.token
        userId: request.userId
        sourcePage: request.sourcePage
    }
    m.mediaActionState.activeRequest = actionRequest
    m.mediaActionsController.actionRequest = actionRequest
end sub

'-------------------------------------------------------------------------------
' navOpenEpisodeSeries
'-------------------------------------------------------------------------------
sub navOpenEpisodeSeries(selection as object, request as object)
    item = selection.item
    if item = invalid then return

    seriesId = SafeString(item.SeriesId, "")
    if seriesId = "" then return

    prepareMediaActionNavigation(SafeString(request.sourcePage, ""))
    tvShowShow({
        itemId: seriesId
        item: buildEpisodeSeriesIdentity(item)
    }, false)
end sub

'-------------------------------------------------------------------------------
' navOpenEpisodeSeason
'-------------------------------------------------------------------------------
sub navOpenEpisodeSeason(selection as object, request as object)
    item = selection.item
    if item = invalid then return

    seriesId = SafeString(item.SeriesId, "")
    seasonId = SafeString(item.SeasonId, "")
    if seriesId = "" or seasonId = "" then return

    prepareMediaActionNavigation(SafeString(request.sourcePage, ""))
    tvSeasonShow({
        seriesId: seriesId
        seasonId: seasonId
        series: buildEpisodeSeriesIdentity(item)
        seriesMetadataPending: true
        season: {
            Id: seasonId
            Name: SafeString(item.SeasonName, "")
        }
        seasons: invalid
        nextSeason: invalid
    })
end sub

'-------------------------------------------------------------------------------
' buildEpisodeSeriesIdentity
'-------------------------------------------------------------------------------
function buildEpisodeSeriesIdentity(item as object) as object
    return {
        Id: SafeString(item.SeriesId, "")
        Name: SafeString(item.SeriesName, "")
        thumbUrl: ""
        backdropUrl: ""
        detailBackdropUrl: ""
    }
end function

'-------------------------------------------------------------------------------
' prepareMediaActionNavigation
'-------------------------------------------------------------------------------
sub prepareMediaActionNavigation(sourcePage as string)
    if sourcePage = "search" then
        searchHidePage()
    else if sourcePage = "videoLibrary" and m.videoLibraryPage <> invalid then
        m.videoLibraryPage.callFunc("deactivate")
    else if sourcePage = "home" then
        resetDynamicPages()
    end if
end sub

'-------------------------------------------------------------------------------
' navHandleMediaStateChanged
'-------------------------------------------------------------------------------
sub navHandleMediaStateChanged()
    change = m.mediaActionsController.mediaStateChanged
    request = m.mediaActionState.activeRequest
    m.mediaActionState.activeRequest = invalid
    if change = invalid or request = invalid then return

    routeMediaStateChange(SafeString(request.sourcePage, ""), change)
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' navHandleMediaActionFailed
'-------------------------------------------------------------------------------
sub navHandleMediaActionFailed()
    failure = m.mediaActionsController.actionFailed
    m.mediaActionState.activeRequest = invalid
    if failure = invalid then return

    Status_SetMessage(SafeString(failure.errorMessage, "Unable to update media state."))
end sub

'-------------------------------------------------------------------------------
' routeMediaStateChange
'-------------------------------------------------------------------------------
sub routeMediaStateChange(sourcePage as string, change as object)
    if sourcePage = "home" then
        m.homePage.callFunc("applyMediaStateChange", change)
    else if sourcePage = "search" and m.searchPage <> invalid then
        m.searchPage.callFunc("applyMediaStateChange", change)
    else if sourcePage = "videoLibrary" and m.videoLibraryPage <> invalid then
        m.videoLibraryPage.mediaStateChange = change
    else if sourcePage = "musicLibrary" and m.musicLibraryPage <> invalid then
        m.musicLibraryPage.callFunc("applyMediaStateChange", change)
    end if
end sub

'-------------------------------------------------------------------------------
' isStreamOptionsOverlayRequest
'-------------------------------------------------------------------------------
function isStreamOptionsOverlayRequest(request as object) as boolean
    id = SafeString(request.id, "")
    return id = "subtitleOptions" or id = "audioOptions" or id = "chapterOptions" or id = "videoOptions"
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
    else if sourcePage = "musicArtist" and m.musicArtistPage <> invalid then
        m.musicArtistPage.callFunc("handleDescriptionOverlayClosed")
    else if sourcePage = "tvEpisode" and m.tvEpisodePage <> invalid then
        m.tvEpisodePage.callFunc("handleDescriptionOverlayClosed")
    else if sourcePage = "tvShow" and m.tvShowPage <> invalid then
        m.tvShowPage.callFunc("handleDescriptionOverlayClosed")
    end if
end sub

'-------------------------------------------------------------------------------
' navHandleVideoMediaInfoOverlayClosed
'-------------------------------------------------------------------------------
sub navHandleVideoMediaInfoOverlayClosed(closed as object)
    request = closed.request
    if request = invalid then return

    sourcePage = SafeString(request.sourcePage, "")
    if sourcePage = "movie" and m.moviePage <> invalid then
        m.moviePage.callFunc("handleVideoMediaInfoOverlayClosed")
    else if sourcePage = "tvEpisode" and m.tvEpisodePage <> invalid then
        m.tvEpisodePage.callFunc("handleVideoMediaInfoOverlayClosed")
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
    else if m.musicLibraryPage <> invalid and m.musicLibraryPage.visible = true then
        m.musicLibraryPage.callFunc("activate")
    else if m.videoLibraryPage <> invalid and m.videoLibraryPage.visible = true then
        m.videoLibraryPage.callFunc("activate")
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
    m.settings = SettingsStore_Load(SafeString(m.session.accountKey, ""))
    fanOutSettings()
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
' syncHeaderUserIdentity
'-------------------------------------------------------------------------------
sub syncHeaderUserIdentity()
    if m.session = invalid then
        m.header.username = ""
        m.header.userIdentityRequest = invalid
        return
    end if

    m.header.username = SafeString(m.session.username, "")
    m.header.userIdentityRequest = {
        server: SafeString(m.session.server, "")
        userId: SafeString(m.session.userId, "")
        primaryImageTag: SafeString(m.session.primaryImageTag, "")
    }
end sub

'-------------------------------------------------------------------------------
' fanOutSettings
'-------------------------------------------------------------------------------
sub fanOutSettings()
    applySettingsToPage(m.header)
    applySettingsToPage(m.collectionsPage)
    applySettingsToPage(m.videoLibraryPage)
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
    m.homePage.callFunc("focusHome")
end sub

'-------------------------------------------------------------------------------
' resetDynamicPages
'-------------------------------------------------------------------------------
sub resetDynamicPages()
    clearStatus()
    themeAudioStop()
    m.mediaActionsController.callFunc("cancelActiveAction")
    m.mediaActionState.activeRequest = invalid
    if m.liveTvPage <> invalid then m.liveTvPage.callFunc("deactivate")
    if m.musicLibraryPage <> invalid then m.musicLibraryPage.callFunc("deactivate")
    if m.musicArtistPage <> invalid then m.musicArtistPage.callFunc("deactivate")
    if m.audioPlayerPage <> invalid then m.audioPlayerPage.callFunc("deactivate")
    if m.videoLibraryPage <> invalid then m.videoLibraryPage.callFunc("deactivate")
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
    m.musicLibraryPage = invalid
    m.musicArtistPage = invalid
    m.audioPlayerPage = invalid
    m.videoLibraryPage = invalid
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

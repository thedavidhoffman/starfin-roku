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

    themeAudioStop()
    if m.moviePage <> invalid and m.moviePage.visible = true then m.moviePage.callFunc("deactivate")
    if m.tvShowPage <> invalid and m.tvShowPage.visible = true then m.tvShowPage.callFunc("deactivate")
    if m.videoPlayer <> invalid and m.videoPlayer.visible = true then
        m.personSourceVideoPlayer = m.videoPlayer
    else if m.tvEpisodePage <> invalid and m.tvEpisodePage.visible = true then
        m.personSourceTvEpisodePage = m.tvEpisodePage
    else if m.tvSeasonPage <> invalid and m.tvSeasonPage.visible = true then
        m.personSourceTvSeasonPage = m.tvSeasonPage
    else if m.tvShowPage <> invalid and m.tvShowPage.visible = true then
        m.personSourceTvShowPage = m.tvShowPage
    else if m.moviePage <> invalid and m.moviePage.visible = true then
        m.personSourceMoviePage = m.moviePage
    end if

    page = CreateObject("roSGNode", "Person")
    page.observeField("closeRequested", "personHandleCloseRequested")
    page.observeField("selectedFilmography", "filmographyHandlePersonFilmographySelected")
    page.observeField("selectedMovie", "personHandleMovieSelected")
    page.observeField("selectedSeries", "personHandleSeriesSelected")
    page.observeField("selectedEpisode", "personHandleEpisodeSelected")
    page.observeField("overlayRequested", "personHandleOverlayRequested")
    page.settings = m.settings
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
        sourceItemType: SafeString(selection.sourceItemType, "")
        sourceItemId: SafeString(selection.sourceItemId, "")
        sourceSeriesId: SafeString(selection.sourceSeriesId, "")
        settings: m.settings
    }

    m.personPage = page
    m.dynamicPageHost.appendChild(page)
    if m.tvEpisodePage <> invalid then m.tvEpisodePage.visible = false
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.visible = false
    if m.moviePage <> invalid then m.moviePage.visible = false
    if m.tvShowPage <> invalid then m.tvShowPage.visible = false
    if m.videoPlayer <> invalid then m.videoPlayer.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' personHandleOverlayRequested
'-------------------------------------------------------------------------------
sub personHandleOverlayRequested()
    if m.personPage = invalid then return

    request = m.personPage.overlayRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' personHandlePersonOverviewOverlayClosed
'-------------------------------------------------------------------------------
sub personHandlePersonOverviewOverlayClosed(closed as object)
    if m.personPage = invalid then return

    m.personPage.callFunc("handlePersonOverviewOverlayClosed")
end sub

'-------------------------------------------------------------------------------
' personHandleTVEpisodePersonSelected
'-------------------------------------------------------------------------------
sub personHandleTVEpisodePersonSelected()
    selection = m.tvEpisodePage.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    personShow(selection)
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
' personHandleEpisodeSelected
'-------------------------------------------------------------------------------
sub personHandleEpisodeSelected()
    selection = m.personPage.selectedEpisode
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    loadRequest = buildHomeEpisodeLoadRequest(selection)
    if loadRequest = invalid then return

    tvEpisodeShow({
        loadRequest: loadRequest
    })
end sub

'-------------------------------------------------------------------------------
' personHandleCloseRequested
'-------------------------------------------------------------------------------
sub personHandleCloseRequested()
    clearStatus()
    if m.personPage <> invalid then
        m.dynamicPageHost.removeChild(m.personPage)
        m.personPage = invalid
    end if

    if m.moviePage = invalid and m.personSourceMoviePage <> invalid then m.moviePage = m.personSourceMoviePage
    if m.tvShowPage = invalid and m.personSourceTvShowPage <> invalid then m.tvShowPage = m.personSourceTvShowPage
    if m.tvSeasonPage = invalid and m.personSourceTvSeasonPage <> invalid then m.tvSeasonPage = m.personSourceTvSeasonPage
    if m.tvEpisodePage = invalid and m.personSourceTvEpisodePage <> invalid then m.tvEpisodePage = m.personSourceTvEpisodePage
    if m.videoPlayer = invalid and m.personSourceVideoPlayer <> invalid then m.videoPlayer = m.personSourceVideoPlayer
    m.personSourceMoviePage = invalid
    m.personSourceTvShowPage = invalid
    m.personSourceTvSeasonPage = invalid
    m.personSourceTvEpisodePage = invalid
    m.personSourceVideoPlayer = invalid

    if m.videoPlayer <> invalid and m.videoPlayer.visible = false then
        m.videoPlayer.visible = true
        m.header.visible = false
        m.videoPlayer.callFunc("resumeAfterPersonNavigation")
    else if m.tvEpisodePage <> invalid then
        m.tvEpisodePage.visible = true
        m.header.visible = false
        m.tvEpisodePage.callFunc("activate")
    else if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.header.visible = false
        m.tvSeasonPage.callFunc("activate")
    else if m.tvShowPage <> invalid then
        m.tvShowPage.visible = true
        m.header.visible = false
        m.tvShowPage.callFunc("activate")
    else if m.moviePage <> invalid then
        m.moviePage.visible = true
        m.header.visible = false
        m.moviePage.callFunc("activate")
    else if searchReturnToPage() then
        return
    else
        showHome()
    end if
end sub

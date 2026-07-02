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

    if m.tvEpisodePage <> invalid and m.tvEpisodePage.visible = true then
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
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
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
    m.personSourceMoviePage = invalid
    m.personSourceTvShowPage = invalid
    m.personSourceTvSeasonPage = invalid
    m.personSourceTvEpisodePage = invalid

    if m.tvEpisodePage <> invalid then
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
    else
        showHome()
    end if
end sub

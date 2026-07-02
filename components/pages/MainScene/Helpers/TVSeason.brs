'-------------------------------------------------------------------------------
' tvSeasonHandleTVShowSeasonSelected
'-------------------------------------------------------------------------------
sub tvSeasonHandleTVShowSeasonSelected()
    selection = m.tvShowPage.selectedSeason
    if selection = invalid then return
    if selection.seriesId = invalid or selection.seriesId = "" then return
    if selection.seasonId = invalid or selection.seasonId = "" then return

    tvSeasonShow(selection)
end sub

'-------------------------------------------------------------------------------
' tvSeasonShow
'-------------------------------------------------------------------------------
sub tvSeasonShow(selection as object)
    if selection = invalid then return
    if selection.seriesId = invalid or selection.seriesId = "" then return
    if selection.seasonId = invalid or selection.seasonId = "" then return

    page = CreateObject("roSGNode", "TVSeason")
    page.observeField("closeRequested", "tvSeasonHandleCloseRequested")
    page.observeField("selectedEpisodeDetails", "tvEpisodeHandleTVSeasonEpisodeSelected")
    page.observeField("seasonWatchedStateChanged", "tvShowHandleTVSeasonWatchedStateChanged")
    page.settings = m.settings
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        seriesId: selection.seriesId
        seasonId: selection.seasonId
        series: selection.series
        season: selection.season
        nextSeason: selection.nextSeason
    }

    m.tvSeasonPage = page
    m.dynamicPageHost.appendChild(page)
    if m.tvShowPage <> invalid then m.tvShowPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' tvShowHandleTVSeasonWatchedStateChanged
'-------------------------------------------------------------------------------
sub tvShowHandleTVSeasonWatchedStateChanged()
    if m.tvSeasonPage = invalid then return
    change = m.tvSeasonPage.seasonWatchedStateChanged
    if change = invalid then return

    markHomePlaybackRowsDirty()
    if m.tvShowPage <> invalid then m.tvShowPage.seasonWatchedStateChange = change
end sub

'-------------------------------------------------------------------------------
' tvSeasonHandleCloseRequested
'-------------------------------------------------------------------------------
sub tvSeasonHandleCloseRequested()
    clearStatus()
    if m.tvSeasonPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvSeasonPage)
        m.tvSeasonPage = invalid
    end if

    if m.tvShowPage <> invalid then
        m.tvShowPage.visible = true
        m.header.visible = false
        m.tvShowPage.callFunc("activate")
    else if m.libraryPage <> invalid then
        m.libraryPage.visible = true
        m.header.visible = true
        m.libraryPage.callFunc("activate")
    else
        showHome()
    end if
end sub

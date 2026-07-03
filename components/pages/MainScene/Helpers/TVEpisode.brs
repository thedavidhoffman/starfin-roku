'-------------------------------------------------------------------------------
' tvEpisodeHandleTVSeasonEpisodeSelected
'-------------------------------------------------------------------------------
sub tvEpisodeHandleTVSeasonEpisodeSelected()
    selection = m.tvSeasonPage.selectedEpisodeDetails
    if selection = invalid then return

    tvEpisodeShow(selection)
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleHomeEpisodeSelected
'-------------------------------------------------------------------------------
sub tvEpisodeHandleHomeEpisodeSelected()
    selection = m.homePage.selectedEpisode
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    loadRequest = buildHomeEpisodeLoadRequest(selection)
    if loadRequest = invalid then return

    episodeSelection = {
        loadRequest: loadRequest
    }

    resetDynamicPages()
    tvEpisodeShow(episodeSelection)
end sub

'-------------------------------------------------------------------------------
' tvEpisodeShow
'-------------------------------------------------------------------------------
sub tvEpisodeShow(selection as object)
    if selection = invalid then return
    if selection.loadRequest = invalid then return
    if selection.loadRequest.itemId = invalid or selection.loadRequest.itemId = "" then return

    page = createTVEpisodePage(selection.loadRequest, true)
    m.tvEpisodePage = page
    m.dynamicPageHost.appendChild(page)
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("resetFocus")
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' createTVEpisodePage
'-------------------------------------------------------------------------------
function createTVEpisodePage(loadRequest as object, isVisible as boolean) as object
    page = CreateObject("roSGNode", "TVEpisode")
    page.observeField("closeRequested", "tvEpisodeHandleCloseRequested")
    page.observeField("selectedEpisode", "tvEpisodeHandleEpisodeSelected")
    page.observeField("selectedPerson", "personHandleTVEpisodePersonSelected")
    page.observeField("selectedSeries", "tvEpisodeHandleSeriesSelected")
    page.observeField("selectedSeason", "tvEpisodeHandleSeasonSelected")
    page.observeField("watchedStateChanged", "tvEpisodeHandleWatchedStateChanged")
    page.observeField("playbackProgressChanged", "tvEpisodeHandlePlaybackProgressChanged")
    page.observeField("streamOptionsRequested", "tvEpisodeHandleStreamOptionsRequested")
    page.observeField("overlayRequested", "tvEpisodeHandleOverlayRequested")
    page.loadRequest = loadRequest
    page.visible = isVisible

    return page
end function

'-------------------------------------------------------------------------------
' tvEpisodeHandleOverlayRequested
'-------------------------------------------------------------------------------
sub tvEpisodeHandleOverlayRequested()
    if m.tvEpisodePage = invalid then return

    request = m.tvEpisodePage.overlayRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleStreamOptionsRequested
'-------------------------------------------------------------------------------
sub tvEpisodeHandleStreamOptionsRequested()
    if m.tvEpisodePage = invalid then return

    request = m.tvEpisodePage.streamOptionsRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' buildHomeEpisodeLoadRequest
'-------------------------------------------------------------------------------
function buildHomeEpisodeLoadRequest(selection as object) as object
    item = selection.item
    if item = invalid then return invalid

    return {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: item
        series: {
            Id: FirstNonEmpty([item.SeriesId], "")
            Name: FirstNonEmpty([item.SeriesName], "")
        }
        startPositionTicks: PlaybackProgress_GetTicksFromItem(item)
    }
end function

'-------------------------------------------------------------------------------
' tvEpisodeHandleCloseRequested
'-------------------------------------------------------------------------------
sub tvEpisodeHandleCloseRequested()
    clearStatus()
    playbackProgressChange = invalid
    if m.tvEpisodePage <> invalid then
        playbackProgressChange = m.tvEpisodePage.playbackProgressChanged
        m.dynamicPageHost.removeChild(m.tvEpisodePage)
        m.tvEpisodePage = invalid
    end if

    if m.personPage <> invalid then
        m.personPage.visible = true
        m.header.visible = false
        m.personPage.callFunc("activate")
    else if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.header.visible = false
        if playbackProgressChange <> invalid then m.tvSeasonPage.playbackProgressChange = playbackProgressChange
        m.tvSeasonPage.callFunc("activate")
    else if m.tvShowPage <> invalid then
        m.tvShowPage.visible = true
        m.header.visible = false
        m.tvShowPage.callFunc("activate")
    else
        showHome()
    end if
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleEpisodeSelected
'-------------------------------------------------------------------------------
sub tvEpisodeHandleEpisodeSelected()
    selection = m.tvEpisodePage.selectedEpisode
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    playerShow(selection)
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleSeriesSelected
'-------------------------------------------------------------------------------
sub tvEpisodeHandleSeriesSelected()
    if m.tvEpisodePage = invalid then return
    selection = m.tvEpisodePage.selectedSeries
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    clearStatus()
    if m.tvEpisodePage <> invalid then
        m.dynamicPageHost.removeChild(m.tvEpisodePage)
        m.tvEpisodePage = invalid
    end if

    if m.tvSeasonPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvSeasonPage)
        m.tvSeasonPage = invalid
    end if

    if m.tvShowPage <> invalid then
        m.tvShowPage.visible = true
        m.header.visible = false
        m.tvShowPage.callFunc("activate")
    else
        tvShowShow(selection, false)
    end if
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleSeasonSelected
'-------------------------------------------------------------------------------
sub tvEpisodeHandleSeasonSelected()
    if m.tvEpisodePage = invalid then return
    selection = m.tvEpisodePage.selectedSeason
    if selection = invalid then return
    if selection.seriesId = invalid or selection.seriesId = "" then return
    if selection.seasonId = invalid or selection.seasonId = "" then return

    clearStatus()
    playbackProgressChange = invalid
    if m.tvEpisodePage <> invalid then
        playbackProgressChange = m.tvEpisodePage.playbackProgressChanged
        m.dynamicPageHost.removeChild(m.tvEpisodePage)
        m.tvEpisodePage = invalid
    end if

    if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.header.visible = false
        if playbackProgressChange <> invalid then m.tvSeasonPage.playbackProgressChange = playbackProgressChange
        m.tvSeasonPage.callFunc("activate")
    else
        tvSeasonShow(selection)
    end if
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandleWatchedStateChanged
'-------------------------------------------------------------------------------
sub tvEpisodeHandleWatchedStateChanged()
    if m.tvEpisodePage = invalid then return
    change = m.tvEpisodePage.watchedStateChanged
    if change = invalid then return

    markHomePlaybackRowsDirty()
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.watchedStateChange = change
end sub

'-------------------------------------------------------------------------------
' tvEpisodeHandlePlaybackProgressChanged
'-------------------------------------------------------------------------------
sub tvEpisodeHandlePlaybackProgressChanged()
    if m.tvEpisodePage = invalid then return
    change = m.tvEpisodePage.playbackProgressChanged
    if change = invalid then return

    markHomePlaybackRowsDirty()
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.playbackProgressChange = change
end sub

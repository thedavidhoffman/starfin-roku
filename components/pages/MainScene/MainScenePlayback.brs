'-------------------------------------------------------------------------------
' playerShow
'-------------------------------------------------------------------------------
sub playerShow(selection as object)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    player = CreateObject("roSGNode", "VideoPlayer")
    player.observeField("closeRequested", "playerHandleCloseRequested")
    player.observeField("playbackProgressChanged", "playerHandlePlaybackProgressChanged")
    player.observeField("upNextRequested", "playerHandleUpNextRequested")
    playRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
        series: selection.series
        season: selection.season
        startPositionTicks: PlaybackProgress_GetTicksFromSelection(selection)
        playbackQueue: selection.playbackQueue
        playbackQueueIndex: selection.playbackQueueIndex
    }
    if selection.audioStreamIndex <> invalid then playRequest.AddReplace("audioStreamIndex", selection.audioStreamIndex)
    if selection.subtitleStreamIndex <> invalid then playRequest.AddReplace("subtitleStreamIndex", selection.subtitleStreamIndex)
    player.playRequest = playRequest

    if m.moviePage <> invalid then m.moviePage.visible = false
    if m.tvEpisodePage <> invalid then m.tvEpisodePage.visible = false
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.visible = false
    if m.tvEpisodeUpNextAutoPlayPage <> invalid then m.tvEpisodeUpNextAutoPlayPage.visible = false
    m.videoPlayer = player
    m.dynamicPageHost.appendChild(player)
    m.homePage.visible = false
    m.header.visible = false
    player.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' playerHandleUpNextRequested
'-------------------------------------------------------------------------------
sub playerHandleUpNextRequested()
    if m.videoPlayer = invalid then return

    request = m.videoPlayer.upNextRequested
    if request = invalid then return

    m.pendingUpNextAutoPlayRequest = request
end sub

'-------------------------------------------------------------------------------
' playerHandlePlaybackProgressChanged
'-------------------------------------------------------------------------------
sub playerHandlePlaybackProgressChanged()
    if m.videoPlayer = invalid then return

    change = m.videoPlayer.playbackProgressChanged
    if change = invalid then return

    markHomePlaybackRowsDirty()

    ' Keep sub-5% progress alive only for this navigation session; Jellyfin
    ' remains authoritative after reload because it discards early resume points.
    routeMoviePlaybackProgress(change)
    routeTVEpisodePlaybackProgress(change)
    routeTVSeasonPlaybackProgress(change)
end sub

'-------------------------------------------------------------------------------
' routeMoviePlaybackProgress
'-------------------------------------------------------------------------------
sub routeMoviePlaybackProgress(change as object)
    if m.moviePage = invalid then return

    m.moviePage.playbackProgressChange = change
end sub

'-------------------------------------------------------------------------------
' routeTVEpisodePlaybackProgress
'-------------------------------------------------------------------------------
sub routeTVEpisodePlaybackProgress(change as object)
    if m.tvEpisodePage = invalid then return

    m.tvEpisodePage.playbackProgressChange = change
end sub

'-------------------------------------------------------------------------------
' routeTVSeasonPlaybackProgress
'-------------------------------------------------------------------------------
sub routeTVSeasonPlaybackProgress(change as object)
    if m.tvSeasonPage = invalid then return

    m.tvSeasonPage.playbackProgressChange = change
end sub

'-------------------------------------------------------------------------------
' playerHandleCloseRequested
'-------------------------------------------------------------------------------
sub playerHandleCloseRequested()
    clearStatus()
    closedPlayRequest = invalid
    if m.videoPlayer <> invalid then
        closedPlayRequest = m.videoPlayer.playRequest
        capturePendingUpNextAutoPlayRequest()
        m.dynamicPageHost.removeChild(m.videoPlayer)
        m.videoPlayer = invalid
    end if

    if showTVEpisodeUpNextAutoPlayPage() then return

    prepareTVEpisodePageForClosedPlayer(closedPlayRequest)

    if m.moviePage <> invalid then
        m.moviePage.visible = true
        m.header.visible = false
        m.moviePage.callFunc("activate")
    else if m.tvEpisodePage <> invalid then
        m.tvEpisodePage.visible = true
        m.header.visible = false
        m.tvEpisodePage.callFunc("activate")
    else if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.header.visible = false
        m.tvSeasonPage.callFunc("activate")
    else
        showHome()
    end if
end sub

'-------------------------------------------------------------------------------
' capturePendingUpNextAutoPlayRequest
'-------------------------------------------------------------------------------
sub capturePendingUpNextAutoPlayRequest()
    if m.pendingUpNextAutoPlayRequest <> invalid then return
    if m.videoPlayer = invalid then return

    request = m.videoPlayer.upNextRequested
    if request = invalid then return

    m.pendingUpNextAutoPlayRequest = request
end sub

'-------------------------------------------------------------------------------
' showTVEpisodeUpNextAutoPlayPage
'-------------------------------------------------------------------------------
function showTVEpisodeUpNextAutoPlayPage() as boolean
    request = m.pendingUpNextAutoPlayRequest
    m.pendingUpNextAutoPlayRequest = invalid
    if request = invalid then return false

    page = CreateObject("roSGNode", "TVEpisodeUpNextAutoPlay")
    page.observeField("playSelected", "tvEpisodeUpNextHandlePlaySelected")
    page.observeField("cancelSelected", "tvEpisodeUpNextHandleCancelSelected")
    page.autoPlayRequest = request

    m.tvEpisodeUpNextAutoPlayPage = page
    m.dynamicPageHost.appendChild(page)
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("openAutoPlay")

    return true
end function

'-------------------------------------------------------------------------------
' tvEpisodeUpNextHandlePlaySelected
'-------------------------------------------------------------------------------
sub tvEpisodeUpNextHandlePlaySelected()
    if m.tvEpisodeUpNextAutoPlayPage = invalid then return

    request = m.tvEpisodeUpNextAutoPlayPage.autoPlayRequest
    closeTVEpisodeUpNextAutoPlayPage(false)
    if request = invalid then return

    nextItem = request.nextItem
    if nextItem = invalid then return

    playerShow({
        itemId: nextItem.itemId
        item: nextItem.item
        series: request.series
        season: request.season
        playbackQueue: request.playbackQueue
        playbackQueueIndex: request.playbackQueueIndex
    })
end sub

'-------------------------------------------------------------------------------
' prepareTVEpisodePageForClosedPlayer
'-------------------------------------------------------------------------------
sub prepareTVEpisodePageForClosedPlayer(playRequest as dynamic)
    loadRequest = buildClosedPlayerTVEpisodeLoadRequest(playRequest)
    if loadRequest = invalid then return
    if isCurrentTVEpisodePage(loadRequest.itemId) then return

    if m.tvEpisodePage <> invalid then
        m.dynamicPageHost.removeChild(m.tvEpisodePage)
        m.tvEpisodePage = invalid
    end if

    page = CreateObject("roSGNode", "TVEpisode")
    page.observeField("closeRequested", "tvEpisodeHandleCloseRequested")
    page.observeField("selectedEpisode", "tvEpisodeHandleEpisodeSelected")
    page.observeField("selectedPerson", "personHandleTVEpisodePersonSelected")
    page.observeField("selectedSeries", "tvEpisodeHandleSeriesSelected")
    page.observeField("selectedSeason", "tvEpisodeHandleSeasonSelected")
    page.observeField("watchedStateChanged", "tvEpisodeHandleWatchedStateChanged")
    page.observeField("playbackProgressChanged", "tvEpisodeHandlePlaybackProgressChanged")
    page.loadRequest = loadRequest
    page.visible = false

    m.tvEpisodePage = page
    m.dynamicPageHost.appendChild(page)
    if m.tvSeasonPage <> invalid then m.tvSeasonPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
end sub

'-------------------------------------------------------------------------------
' buildClosedPlayerTVEpisodeLoadRequest
'-------------------------------------------------------------------------------
function buildClosedPlayerTVEpisodeLoadRequest(playRequest as dynamic) as dynamic
    if isTVEpisodePlayRequest(playRequest) <> true then return invalid

    item = playRequest.item
    if item = invalid then return invalid

    itemId = SafeString(FirstNonEmpty([playRequest.itemId, item.Id], ""), "")
    if itemId = "" then return invalid

    seriesId = FirstNonEmpty([item.SeriesId], "")
    if seriesId = "" and playRequest.series <> invalid then seriesId = FirstNonEmpty([playRequest.series.Id], "")

    seasonId = FirstNonEmpty([item.SeasonId, item.ParentId], "")
    if seasonId = "" and playRequest.season <> invalid then seasonId = FirstNonEmpty([playRequest.season.Id], "")

    return {
        server: playRequest.server
        token: playRequest.token
        userId: playRequest.userId
        seriesId: seriesId
        seasonId: seasonId
        itemId: itemId
        item: item
        series: playRequest.series
        season: playRequest.season
        startPositionTicks: PlaybackProgress_GetTicksFromItem(item)
        playbackQueue: playRequest.playbackQueue
        playbackQueueIndex: playRequest.playbackQueueIndex
    }
end function

'-------------------------------------------------------------------------------
' isTVEpisodePlayRequest
'-------------------------------------------------------------------------------
function isTVEpisodePlayRequest(playRequest as dynamic) as boolean
    if playRequest = invalid then return false
    if playRequest.series <> invalid then return true

    item = playRequest.item
    if item = invalid then return false

    return LCase(FirstNonEmpty([item.Type], "")) = "episode"
end function

'-------------------------------------------------------------------------------
' isCurrentTVEpisodePage
'-------------------------------------------------------------------------------
function isCurrentTVEpisodePage(itemId as string) as boolean
    if itemId = "" then return false
    if m.tvEpisodePage = invalid then return false

    request = m.tvEpisodePage.loadRequest
    if request = invalid then return false

    return SafeString(request.itemId, "") = itemId
end function

'-------------------------------------------------------------------------------
' tvEpisodeUpNextHandleCancelSelected
'-------------------------------------------------------------------------------
sub tvEpisodeUpNextHandleCancelSelected()
    closeTVEpisodeUpNextAutoPlayPage(true)
end sub

'-------------------------------------------------------------------------------
' closeTVEpisodeUpNextAutoPlayPage
'-------------------------------------------------------------------------------
sub closeTVEpisodeUpNextAutoPlayPage(restorePreviousPage as boolean)
    if m.tvEpisodeUpNextAutoPlayPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvEpisodeUpNextAutoPlayPage)
        m.tvEpisodeUpNextAutoPlayPage = invalid
    end if

    if restorePreviousPage <> true then return

    if m.tvEpisodePage <> invalid then
        m.tvEpisodePage.visible = true
        m.header.visible = false
        m.tvEpisodePage.callFunc("activate")
    else if m.tvSeasonPage <> invalid then
        m.tvSeasonPage.visible = true
        m.header.visible = false
        m.tvSeasonPage.callFunc("activate")
    else
        showHome()
    end if
end sub

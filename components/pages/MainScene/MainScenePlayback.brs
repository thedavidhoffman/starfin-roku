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
    if m.videoPlayer <> invalid then
        capturePendingUpNextAutoPlayRequest()
        m.dynamicPageHost.removeChild(m.videoPlayer)
        m.videoPlayer = invalid
    end if

    if showTVEpisodeUpNextAutoPlayPage() then return

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

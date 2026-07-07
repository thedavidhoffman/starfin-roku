'-------------------------------------------------------------------------------
' onPlayRequestChanged
'-------------------------------------------------------------------------------
sub onPlayRequestChanged()
    request = m.top.playRequest
    if request = invalid then return

    stopPlayback()
    m.playback.startupPending = true
    Spinner_Show(0)

    m.playbackInfoTask.request = request
    m.playbackInfoTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onPlaybackInfoResponse
'-------------------------------------------------------------------------------
sub onPlaybackInfoResponse()
    response = m.playbackInfoTask.response
    if response = invalid then return

    if response.ok <> true then
        m.playback.startupPending = false
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to play this item."))
        return
    end if

    applyPlaybackResponse(response, m.top.playRequest)
end sub

'-------------------------------------------------------------------------------
' applyPlaybackResponse
'-------------------------------------------------------------------------------
sub applyPlaybackResponse(response as object, request as object)
    if response = invalid or request = invalid then return

    item = response.item
    startPositionSeconds = PlaybackProgress_TicksToSeconds(response.startPositionTicks)

    applyPlaybackSessionState(response, request, item)
    content = buildVideoContent(response, request, item, startPositionSeconds)
    resetPlaybackForStart(item, startPositionSeconds)
    updatePlaybackOverlayData(request, item)
    startVideoContent(content, response, startPositionSeconds)
end sub

'-------------------------------------------------------------------------------
' applyPlaybackSessionState
'-------------------------------------------------------------------------------
sub applyPlaybackSessionState(response as object, request as object, item as dynamic)
    m.session = {
        server: SafeString(request.server, "")
        token: SafeString(request.token, "")
        userId: SafeString(request.userId, "")
        itemId: SafeString(request.itemId, "")
        playSessionId: SafeString(response.playSessionId, "")
    }
    m.queue = {
        items: getPlaybackQueue(request.playbackQueue)
        index: getPlaybackQueueIndex(request.playbackQueueIndex)
    }
    m.context = {
        item: item
        series: request.series
        season: request.season
    }
    updatePlaybackSkipAvailability(request, item)
    m.trickplay = buildTrickplayState(item, m.session.itemId)
    startTrickplayPreload()
end sub

'-------------------------------------------------------------------------------
' updatePlaybackSkipAvailability
'-------------------------------------------------------------------------------
sub updatePlaybackSkipAvailability(request as object, item as dynamic)
    isEpisode = isTVEpisodePlayback(request, item)
    isMovie = isMoviePlayback(request, item)
    m.playbackControls.skipBackEnabled = isEpisode or isMovie
    m.playbackControls.skipForwardEnabled = isEpisode and hasQueueItemAtOffset(1)
end sub

'-------------------------------------------------------------------------------
' isMoviePlayback
'-------------------------------------------------------------------------------
function isMoviePlayback(request as dynamic, item as dynamic) as boolean
    if isTVEpisodePlayback(request, item) = true then return false
    if item = invalid then return false

    return LCase(FirstNonEmpty([item.Type], "")) = "movie"
end function

'-------------------------------------------------------------------------------
' hasQueueItemAtOffset
'-------------------------------------------------------------------------------
function hasQueueItemAtOffset(offset as integer) as boolean
    if m.queue = invalid then return false
    if m.queue.items = invalid then return false

    targetIndex = m.queue.index + offset
    return targetIndex >= 0 and targetIndex < m.queue.items.Count()
end function

'-------------------------------------------------------------------------------
' getQueueItemAtOffset
'-------------------------------------------------------------------------------
function getQueueItemAtOffset(offset as integer) as dynamic
    if hasQueueItemAtOffset(offset) <> true then return invalid

    return m.queue.items[m.queue.index + offset]
end function

'-------------------------------------------------------------------------------
' onSkipBackPressed
'-------------------------------------------------------------------------------
sub onSkipBackPressed()
    request = m.top.playRequest
    item = getCurrentPlaybackItem(request)
    if isTVEpisodePlayback(request, item) <> true and isMoviePlayback(request, item) <> true then return

    if isTVEpisodePlayback(request, item) = true and getCurrentPlaybackPosition() < 15 then
        if startQueueItemAtOffset(-1) = true then return
    end if

    restartCurrentPlayback()
end sub

'-------------------------------------------------------------------------------
' onSkipForwardPressed
'-------------------------------------------------------------------------------
sub onSkipForwardPressed()
    request = m.top.playRequest
    item = getCurrentPlaybackItem(request)

    if isTVEpisodePlayback(request, item) <> true then return
    startQueueItemAtOffset(1)
end sub

'-------------------------------------------------------------------------------
' getCurrentPlaybackItem
'-------------------------------------------------------------------------------
function getCurrentPlaybackItem(request as dynamic) as dynamic
    if m.context <> invalid and m.context.item <> invalid then return m.context.item
    if request <> invalid then return request.item

    return invalid
end function

'-------------------------------------------------------------------------------
' restartCurrentPlayback
'-------------------------------------------------------------------------------
sub restartCurrentPlayback()
    stopSeekTimers()
    targetPosition = 0
    m.playback.isSeeking = false
    m.playback.previewPosition = targetPosition
    m.playback.position = targetPosition
    m.videoPlayer.seek = targetPosition
    if m.playback.isPlaying = true then
        m.videoPlayer.control = "resume"
    else
        m.videoPlayer.control = "pause"
    end if

    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    m.playbackControls.position = targetPosition
    m.playbackControls.previewPosition = targetPosition
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' startQueueItemAtOffset
'-------------------------------------------------------------------------------
function startQueueItemAtOffset(offset as integer) as boolean
    queueItem = getQueueItemAtOffset(offset)
    if queueItem = invalid then return false
    if SafeString(queueItem.itemId, "") = "" then return false

    emitPlaybackProgress(false)
    m.top.playRequest = buildQueuePlaybackRequest(queueItem, m.queue.index + offset)
    return true
end function

'-------------------------------------------------------------------------------
' buildQueuePlaybackRequest
'-------------------------------------------------------------------------------
function buildQueuePlaybackRequest(queueItem as object, queueIndex as integer) as object
    season = m.context.season
    if queueItem.season <> invalid then season = queueItem.season

    return {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: SafeString(queueItem.itemId, "")
        item: queueItem.item
        series: m.context.series
        season: season
        startPositionTicks: 0
        playbackQueue: m.queue.items
        playbackQueueIndex: queueIndex
    }
end function

'-------------------------------------------------------------------------------
' buildVideoContent
'-------------------------------------------------------------------------------
function buildVideoContent(response as object, request as object, item as dynamic, startPositionSeconds as integer) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.url = response.streamUrl
    content.streamFormat = response.streamFormat
    content.title = getItemTitle(item)
    content.PlayStart = startPositionSeconds
    content.AddHeader("Authorization", JellyfinAuth_BuildPlaybackHeader(request.token, request.userId))

    return content
end function

'-------------------------------------------------------------------------------
' resetPlaybackForStart
'-------------------------------------------------------------------------------
sub resetPlaybackForStart(item as dynamic, startPositionSeconds as integer)
    m.playback.duration = getRuntimeSeconds(item)
    m.playback.hasEmittedFinalProgress = false
    m.playback.position = startPositionSeconds
    m.playback.previewPosition = startPositionSeconds
    resetSeekState()
    m.playbackControls.duration = m.playback.duration
    m.playbackControls.position = startPositionSeconds
    m.playbackControls.previewPosition = startPositionSeconds
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
end sub

'-------------------------------------------------------------------------------
' updatePlaybackOverlayData
'-------------------------------------------------------------------------------
sub updatePlaybackOverlayData(request as object, item as dynamic)
    updatePlaybackControlsMetadata(request, item)
    updateCast(request, item)
    updatePlaybackControlsOptions(item)
    hideCast()
end sub

'-------------------------------------------------------------------------------
' startVideoContent
'-------------------------------------------------------------------------------
sub startVideoContent(content as object, response as object, startPositionSeconds as integer)
    m.log.write("Assigning video content itemId=" + m.session.itemId + " streamFormat=" + SafeString(response.streamFormat, "") + " startPosition=" + SafeString(startPositionSeconds, ""))
    m.videoPlayer.content = content
    m.top.setFocus(true)
    disableScreenSaver()
    updateBufferingSpinner("buffering")
    m.log.write("Starting video playback itemId=" + m.session.itemId)
    m.videoPlayer.control = "play"
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' onPlaystateTimerFire
'-------------------------------------------------------------------------------
sub onPlaystateTimerFire()
    reportPlaystateUpdate()
end sub

'-------------------------------------------------------------------------------
' emitPlaybackProgress
'-------------------------------------------------------------------------------
sub emitPlaybackProgress(isFinished as boolean)
    if m.session = invalid then return
    if m.session.itemId = "" then return
    if m.playback.hasEmittedFinalProgress = true then return

    position = getCurrentPlaybackPosition()
    duration = m.playback.duration
    if duration = invalid or duration <= 0 then duration = m.videoPlayer.duration

    m.top.playbackProgressChanged = {
        itemId: m.session.itemId
        positionTicks: secondsToTicks(position)
        durationTicks: secondsToTicks(duration)
        isFinished: isFinished
        isPaused: LCase(SafeString(m.videoPlayer.state, "")) = "paused"
    }
    m.playback.hasEmittedFinalProgress = true
end sub

'-------------------------------------------------------------------------------
' secondsToTicks
'-------------------------------------------------------------------------------
function secondsToTicks(seconds as dynamic) as longinteger
    if seconds = invalid or seconds <= 0 then return 0

    return int(seconds) * 10000000&
end function

'-------------------------------------------------------------------------------
' getCurrentPlaybackPosition
'-------------------------------------------------------------------------------
function getCurrentPlaybackPosition() as float
    position = m.videoPlayer.position
    if position <> invalid and position > 0 then return position

    if m.playback <> invalid and m.playback.position <> invalid then return m.playback.position

    return 0
end function

'-------------------------------------------------------------------------------
' requestUpNextAutoPlay
'-------------------------------------------------------------------------------
sub requestUpNextAutoPlay()
    if m.queue = invalid then
        m.log.write("Skipping up-next autoplay: queue is invalid")
        return
    end if
    if m.queue.items = invalid then
        m.log.write("Skipping up-next autoplay: queue items are invalid")
        return
    end if

    nextIndex = m.queue.index + 1
    if nextIndex < 0 or nextIndex >= m.queue.items.Count() then
        m.log.write("Skipping up-next autoplay: no next item queueIndex=" + SafeString(m.queue.index, "") + " queueCount=" + SafeString(m.queue.items.Count(), ""))
        return
    end if

    currentItem = invalid
    if m.queue.index >= 0 and m.queue.index < m.queue.items.Count() then currentItem = m.queue.items[m.queue.index]

    nextItem = m.queue.items[nextIndex]
    if nextItem = invalid or SafeString(nextItem.itemId, "") = "" then
        m.log.write("Skipping up-next autoplay: next item is invalid nextIndex=" + SafeString(nextIndex, ""))
        return
    end if

    m.log.write("Requesting up-next autoplay currentIndex=" + SafeString(m.queue.index, "") + " nextIndex=" + SafeString(nextIndex, "") + " nextItemId=" + SafeString(nextItem.itemId, ""))
    m.top.upNextRequested = {
        finishedItem: currentItem
        nextItem: nextItem
        series: m.context.series
        season: getQueueItemSeason(nextItem)
        playbackQueue: m.queue.items
        playbackQueueIndex: nextIndex
        server: m.session.server
    }
end sub

'-------------------------------------------------------------------------------
' getQueueItemSeason
'-------------------------------------------------------------------------------
function getQueueItemSeason(item as dynamic) as dynamic
    if item <> invalid and item.season <> invalid then return item.season
    return m.context.season
end function

'-------------------------------------------------------------------------------
' reportPlaystateStart
'-------------------------------------------------------------------------------
sub reportPlaystateStart()
    if m.playback.hasReportedStart = true then return

    reportPlaystate("start")
    m.playback.hasReportedStart = true
end sub

'-------------------------------------------------------------------------------
' reportPlaystateUpdate
'-------------------------------------------------------------------------------
sub reportPlaystateUpdate()
    if m.playback.hasReportedStart <> true then return

    reportPlaystate("update")
end sub

'-------------------------------------------------------------------------------
' reportPlaystateStop
'-------------------------------------------------------------------------------
sub reportPlaystateStop()
    if m.playback.hasReportedStart <> true then return

    m.playstateTimer.control = "stop"
    reportPlaystate("stop")
    m.playback.hasReportedStart = false
end sub

'-------------------------------------------------------------------------------
' reportPlaystate
'-------------------------------------------------------------------------------
sub reportPlaystate(status as string)
    if m.session = invalid then return
    if m.session.server = "" or m.session.token = "" or m.session.itemId = "" then return

    position = getCurrentPlaybackPosition()
    isPaused = LCase(SafeString(m.videoPlayer.state, "")) = "paused"
    m.log.write("Playstate " + status + " itemId=" + m.session.itemId + " position=" + SafeString(position, "") + " paused=" + boolToText(isPaused))

    m.playstateTask.request = {
        server: m.session.server
        token: m.session.token
        itemId: m.session.itemId
        playSessionId: m.session.playSessionId
        status: status
        position: position
        isPaused: isPaused
    }
    m.playstateTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' boolToText
'-------------------------------------------------------------------------------
function boolToText(value as boolean) as string
    if value = true then return "true"
    return "false"
end function

'-------------------------------------------------------------------------------
' getPlaybackQueue
'-------------------------------------------------------------------------------
function getPlaybackQueue(value as dynamic) as object
    if value = invalid or Type(value) <> "roArray" then return []
    return value
end function

'-------------------------------------------------------------------------------
' getPlaybackQueueIndex
'-------------------------------------------------------------------------------
function getPlaybackQueueIndex(value as dynamic) as integer
    if value = invalid then return -1
    return int(value)
end function

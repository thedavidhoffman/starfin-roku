'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("VideoPlayer")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.playbackControls = m.top.findNode("playbackControls")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")
    m.playstateTask = m.top.findNode("playstateTask")
    m.trickplayPreloadTask = m.top.findNode("trickplayPreloadTask")
    m.controlsHideTimer = m.top.findNode("controlsHideTimer")
    m.playstateTimer = m.top.findNode("playstateTimer")
    m.fastSeekTimer = m.top.findNode("fastSeekTimer")
    m.leftSeekRepeatTimer = m.top.findNode("leftSeekRepeatTimer")
    m.rightSeekRepeatTimer = m.top.findNode("rightSeekRepeatTimer")

    m.playback = {
        isSeeking: false
        isPlaying: false
        hasReportedStart: false
        hasEmittedFinalProgress: false
        previewPosition: 0
        position: 0
        duration: 0
    }
    m.session = {
        server: ""
        token: ""
        userId: ""
        itemId: ""
        playSessionId: ""
    }
    m.queue = {
        items: []
        index: -1
    }
    m.seek = {
        speeds: [-180, -60, -30, -10, 10, 30, 60, 180]
        speedIndex: -1
        direction: ""
        isAccelerating: false
    }
    m.trickplay = invalid
    m.trickplayPreloadRequest = invalid

    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.trickplayPreloadTask.observeField("response", "onTrickplayPreloadResponse")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
    m.videoPlayer.observeField("position", "onVideoPositionChanged")
    m.videoPlayer.observeField("duration", "onVideoDurationChanged")
    m.playbackControls.observeField("previousPressed", "onPreviousPressed")
    m.playbackControls.observeField("playPausePressed", "onPlayPausePressed")
    m.playbackControls.observeField("nextPressed", "onNextPressed")
    m.playbackControls.observeField("progressLeftPressed", "onProgressLeftPressed")
    m.playbackControls.observeField("progressRightPressed", "onProgressRightPressed")
    m.playbackControls.observeField("progressLeftReleased", "onProgressLeftReleased")
    m.playbackControls.observeField("progressRightReleased", "onProgressRightReleased")
    m.playbackControls.observeField("progressRewindPressed", "onProgressRewindPressed")
    m.playbackControls.observeField("progressFastForwardPressed", "onProgressFastForwardPressed")
    m.playbackControls.observeField("progressSeekCommit", "onProgressSeekCommit")
    m.playbackControls.observeField("progressSeekCancel", "onProgressSeekCancel")
    m.controlsHideTimer.observeField("fire", "onControlsHideTimerFire")
    m.playstateTimer.observeField("fire", "onPlaystateTimerFire")
    m.fastSeekTimer.observeField("fire", "onFastSeekTimerFire")
    m.leftSeekRepeatTimer.observeField("fire", "onLeftSeekRepeatTimerFire")
    m.rightSeekRepeatTimer.observeField("fire", "onRightSeekRepeatTimerFire")
end sub

'-------------------------------------------------------------------------------
' onPlayRequestChanged
'-------------------------------------------------------------------------------
sub onPlayRequestChanged()
    request = m.top.playRequest
    if request = invalid then return

    Status_SetLoading()
    stopPlayback()

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
    m.trickplay = buildTrickplayState(item, m.session.itemId)
    startTrickplayPreload()

    content = CreateObject("roSGNode", "ContentNode")
    content.url = response.streamUrl
    content.streamFormat = response.streamFormat
    content.title = getItemTitle(item)
    startPositionSeconds = PlaybackProgress_TicksToSeconds(response.startPositionTicks)
    content.PlayStart = startPositionSeconds
    content.AddHeader("Authorization", JellyfinAuth_BuildPlaybackHeader(request.token, request.userId))

    m.playback.duration = getRuntimeSeconds(item)
    m.playback.hasEmittedFinalProgress = false
    m.playback.position = startPositionSeconds
    m.playback.previewPosition = startPositionSeconds
    resetSeekState()
    m.playbackControls.title = content.title
    m.playbackControls.duration = m.playback.duration
    m.playbackControls.position = startPositionSeconds
    m.playbackControls.previewPosition = startPositionSeconds
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}

    m.videoPlayer.content = content
    m.videoPlayer.setFocus(true)
    disableScreenSaver()
    m.videoPlayer.control = "play"
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' onVideoStateChanged
'-------------------------------------------------------------------------------
sub onVideoStateChanged()
    state = LCase(SafeString(m.videoPlayer.state, ""))
    if state = "error" then
        reportPlaystateStop()
        enableScreenSaver()
        Status_SetMessage("Unable to play this video.")
    else if state = "finished" then
        reportPlaystateStop()
        emitPlaybackProgress(true)
        stopPlayback()
        m.top.closeRequested = true
    else if state = "playing" then
        if m.playback.hasReportedStart = true then
            reportPlaystateUpdate()
        else
            reportPlaystateStart()
        end if
        m.playstateTimer.control = "start"
    else if state = "paused" then
        m.playstateTimer.control = "stop"
        reportPlaystateUpdate()
    else if state = "stopped" then
        emitPlaybackProgress(false)
        reportPlaystateStop()
        enableScreenSaver()
    end if

    m.playback.isPlaying = state = "playing" or state = "buffering"
    m.playbackControls.isPlaying = m.playback.isPlaying
end sub

'-------------------------------------------------------------------------------
' onVideoPositionChanged
'-------------------------------------------------------------------------------
sub onVideoPositionChanged()
    m.playback.position = m.videoPlayer.position
    if m.playback.isSeeking <> true then
        m.playbackControls.position = m.playback.position
    end if
end sub

'-------------------------------------------------------------------------------
' onVideoDurationChanged
'-------------------------------------------------------------------------------
sub onVideoDurationChanged()
    duration = m.videoPlayer.duration
    if duration = invalid or duration <= 0 then return

    m.playback.duration = duration
    m.playbackControls.duration = duration
end sub

'-------------------------------------------------------------------------------
' onControlsHideTimerFire
'-------------------------------------------------------------------------------
sub onControlsHideTimerFire()
    if m.playback.isSeeking = true then return
    hideControls()
end sub

'-------------------------------------------------------------------------------
' onPlaystateTimerFire
'-------------------------------------------------------------------------------
sub onPlaystateTimerFire()
    reportPlaystateUpdate()
end sub

'-------------------------------------------------------------------------------
' disableScreenSaver
'-------------------------------------------------------------------------------
sub disableScreenSaver()
    m.videoPlayer.disableScreenSaver = true
end sub

'-------------------------------------------------------------------------------
' enableScreenSaver
'-------------------------------------------------------------------------------
sub enableScreenSaver()
    m.videoPlayer.disableScreenSaver = false
end sub

'-------------------------------------------------------------------------------
' stopPlayback
'-------------------------------------------------------------------------------
sub stopPlayback()
    hideControls()
    reportPlaystateStop()
    cleanupTrickplayPreload()
    m.videoPlayer.control = "stop"
    enableScreenSaver()
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if item = invalid then return "Video"
    return FirstNonEmpty([item.Name], "Video")
end function

'-------------------------------------------------------------------------------
' getRuntimeSeconds
'-------------------------------------------------------------------------------
function getRuntimeSeconds(item as dynamic) as float
    if item = invalid then return 0

    runtimeTicks = 0
    if item.RunTimeTicks <> invalid then runtimeTicks = item.RunTimeTicks
    if runtimeTicks = 0 then return 0

    return runtimeTicks / 10000000
end function

'-------------------------------------------------------------------------------
' showControls
'-------------------------------------------------------------------------------
sub showControls(restartTimer as boolean)
    m.playbackControls.visible = true
    m.playbackControls.setFocus(true)
    if restartTimer = true then
        m.controlsHideTimer.control = "stop"
        m.controlsHideTimer.control = "start"
    else
        m.controlsHideTimer.control = "stop"
    end if
end sub

'-------------------------------------------------------------------------------
' showControlsWithProgressFocus
'-------------------------------------------------------------------------------
sub showControlsWithProgressFocus()
    showControls(false)
    m.playbackControls.callFunc("focusProgress")
end sub

'-------------------------------------------------------------------------------
' hideControls
'-------------------------------------------------------------------------------
sub hideControls()
    m.controlsHideTimer.control = "stop"
    stopSeekTimers()
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    m.playbackControls.visible = false
    m.videoPlayer.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' beginSeek
'-------------------------------------------------------------------------------
sub beginSeek(direction as integer)
    if direction < 0 then
        handleProgressSeekInput("left")
    else
        handleProgressSeekInput("right")
    end if
end sub

'-------------------------------------------------------------------------------
' adjustSeek
'-------------------------------------------------------------------------------
sub adjustSeek(direction as integer)
    if direction < 0 then
        handleProgressSeekInput("left")
    else
        handleProgressSeekInput("right")
    end if
end sub

'-------------------------------------------------------------------------------
' startSeekPreview
'-------------------------------------------------------------------------------
sub startSeekPreview()
    if m.playback.duration <= 0 then return
    if m.playback.isSeeking = true then return

    m.playback.isSeeking = true
    m.playback.previewPosition = getCurrentPlaybackPosition()
    m.videoPlayer.control = "pause"
    m.playbackControls.isSeeking = true
    m.playbackControls.previewPosition = m.playback.previewPosition
    showControlsWithProgressFocus()
end sub

'-------------------------------------------------------------------------------
' handleProgressSeekInput
'-------------------------------------------------------------------------------
sub handleProgressSeekInput(key as string)
    if m.playback.duration <= 0 then return

    if m.playback.isSeeking <> true then startSeekPreview()
    if m.playback.isSeeking <> true then return

    if key = "left" then
        startTenSecondRepeat("left")
        applySeekDelta(-10)
    else if key = "right" then
        startTenSecondRepeat("right")
        applySeekDelta(10)
    else if key = "rewind" then
        processAcceleratedSeek("left")
    else if key = "fastforward" then
        processAcceleratedSeek("right")
    end if
end sub

'-------------------------------------------------------------------------------
' startTenSecondRepeat
'-------------------------------------------------------------------------------
sub startTenSecondRepeat(direction as string)
    m.fastSeekTimer.control = "stop"
    m.leftSeekRepeatTimer.control = "stop"
    m.rightSeekRepeatTimer.control = "stop"
    m.leftSeekRepeatTimer.duration = 0.5
    m.rightSeekRepeatTimer.duration = 0.5

    if direction = "left" then
        m.seek.speedIndex = 3
        m.leftSeekRepeatTimer.control = "start"
    else
        m.seek.speedIndex = 4
        m.rightSeekRepeatTimer.control = "start"
    end if

    m.seek.direction = direction
    m.seek.isAccelerating = false
end sub

'-------------------------------------------------------------------------------
' processAcceleratedSeek
'-------------------------------------------------------------------------------
sub processAcceleratedSeek(direction as string)
    stopTenSecondRepeatTimers()

    if m.seek.isAccelerating = true and m.seek.direction <> "" and m.seek.direction <> direction then
        m.fastSeekTimer.control = "stop"
        m.seek.direction = ""
        m.seek.speedIndex = -1
        m.seek.isAccelerating = false
        return
    end if

    if direction = "left" then
        if m.seek.direction <> "left" or m.seek.speedIndex < 0 or m.seek.speedIndex > 3 then
            m.seek.speedIndex = 3
        else if m.seek.speedIndex > 0 then
            m.seek.speedIndex = m.seek.speedIndex - 1
        end if
    else
        if m.seek.direction <> "right" or m.seek.speedIndex < 4 then
            m.seek.speedIndex = 4
        else if m.seek.speedIndex < m.seek.speeds.Count() - 1 then
            m.seek.speedIndex = m.seek.speedIndex + 1
        end if
    end if

    m.seek.direction = direction
    m.seek.isAccelerating = true
    m.fastSeekTimer.control = "start"
    applySeekDelta(m.seek.speeds[m.seek.speedIndex])
end sub

'-------------------------------------------------------------------------------
' applySeekDelta
'-------------------------------------------------------------------------------
sub applySeekDelta(deltaSeconds as integer)
    if m.playback.duration <= 0 then return

    m.playback.previewPosition = clampSeconds(m.playback.previewPosition + deltaSeconds, 0, m.playback.duration)
    m.playbackControls.previewPosition = m.playback.previewPosition
    updateTrickplayPreview(m.playback.previewPosition)
end sub

'-------------------------------------------------------------------------------
' onFastSeekTimerFire
'-------------------------------------------------------------------------------
sub onFastSeekTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if
    if m.seek.speedIndex < 0 then return

    applySeekDelta(m.seek.speeds[m.seek.speedIndex])
end sub

'-------------------------------------------------------------------------------
' onLeftSeekRepeatTimerFire
'-------------------------------------------------------------------------------
sub onLeftSeekRepeatTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if

    m.leftSeekRepeatTimer.duration = 0.125
    applySeekDelta(-10)
end sub

'-------------------------------------------------------------------------------
' onRightSeekRepeatTimerFire
'-------------------------------------------------------------------------------
sub onRightSeekRepeatTimerFire()
    if m.playback.isSeeking <> true then
        stopSeekTimers()
        return
    end if

    m.rightSeekRepeatTimer.duration = 0.125
    applySeekDelta(10)
end sub

'-------------------------------------------------------------------------------
' stopTenSecondRepeatTimers
'-------------------------------------------------------------------------------
sub stopTenSecondRepeatTimers()
    m.leftSeekRepeatTimer.control = "stop"
    m.rightSeekRepeatTimer.control = "stop"
    m.leftSeekRepeatTimer.duration = 0.5
    m.rightSeekRepeatTimer.duration = 0.5
end sub

'-------------------------------------------------------------------------------
' stopTenSecondRepeat
'-------------------------------------------------------------------------------
sub stopTenSecondRepeat(direction as string)
    if direction = "left" then
        m.leftSeekRepeatTimer.control = "stop"
        m.leftSeekRepeatTimer.duration = 0.5
    else if direction = "right" then
        m.rightSeekRepeatTimer.control = "stop"
        m.rightSeekRepeatTimer.duration = 0.5
    end if

    if m.seek.isAccelerating <> true then
        m.seek.direction = ""
        m.seek.speedIndex = -1
    end if
end sub

'-------------------------------------------------------------------------------
' stopSeekTimers
'-------------------------------------------------------------------------------
sub stopSeekTimers()
    m.fastSeekTimer.control = "stop"
    stopTenSecondRepeatTimers()
    resetSeekState()
end sub

'-------------------------------------------------------------------------------
' resetSeekState
'-------------------------------------------------------------------------------
sub resetSeekState()
    m.seek.speedIndex = -1
    m.seek.direction = ""
    m.seek.isAccelerating = false
end sub

'-------------------------------------------------------------------------------
' commitSeek
'-------------------------------------------------------------------------------
sub commitSeek()
    if m.playback.isSeeking <> true then return

    stopSeekTimers()
    m.videoPlayer.seek = m.playback.previewPosition
    m.videoPlayer.control = "resume"
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' cancelSeek
'-------------------------------------------------------------------------------
sub cancelSeek()
    if m.playback.isSeeking <> true then return

    stopSeekTimers()
    m.videoPlayer.control = "resume"
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' togglePlayback
'-------------------------------------------------------------------------------
sub togglePlayback()
    if m.playback.isPlaying = true then
        m.videoPlayer.control = "pause"
        m.playback.isPlaying = false
    else
        m.videoPlayer.control = "resume"
        m.playback.isPlaying = true
    end if

    m.playbackControls.isPlaying = m.playback.isPlaying
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' onPreviousPressed
'-------------------------------------------------------------------------------
sub onPreviousPressed()
    if playQueueItem(-1) <> true then skipPlayback(-10)
end sub

'-------------------------------------------------------------------------------
' onPlayPausePressed
'-------------------------------------------------------------------------------
sub onPlayPausePressed()
    if m.playback.isSeeking = true then
        commitSeek()
    else
        togglePlayback()
    end if
end sub

'-------------------------------------------------------------------------------
' onNextPressed
'-------------------------------------------------------------------------------
sub onNextPressed()
    if playQueueItem(1) <> true then skipPlayback(10)
end sub

'-------------------------------------------------------------------------------
' onProgressLeftPressed
'-------------------------------------------------------------------------------
sub onProgressLeftPressed()
    handleProgressSeekInput("left")
end sub

'-------------------------------------------------------------------------------
' onProgressRightPressed
'-------------------------------------------------------------------------------
sub onProgressRightPressed()
    handleProgressSeekInput("right")
end sub

'-------------------------------------------------------------------------------
' onProgressLeftReleased
'-------------------------------------------------------------------------------
sub onProgressLeftReleased()
    stopTenSecondRepeat("left")
end sub

'-------------------------------------------------------------------------------
' onProgressRightReleased
'-------------------------------------------------------------------------------
sub onProgressRightReleased()
    stopTenSecondRepeat("right")
end sub

'-------------------------------------------------------------------------------
' onProgressRewindPressed
'-------------------------------------------------------------------------------
sub onProgressRewindPressed()
    handleProgressSeekInput("rewind")
end sub

'-------------------------------------------------------------------------------
' onProgressFastForwardPressed
'-------------------------------------------------------------------------------
sub onProgressFastForwardPressed()
    handleProgressSeekInput("fastforward")
end sub

'-------------------------------------------------------------------------------
' onProgressSeekCommit
'-------------------------------------------------------------------------------
sub onProgressSeekCommit()
    commitSeek()
end sub

'-------------------------------------------------------------------------------
' onProgressSeekCancel
'-------------------------------------------------------------------------------
sub onProgressSeekCancel()
    cancelSeek()
end sub

' playQueueItem
'-------------------------------------------------------------------------------
function playQueueItem(direction as integer) as boolean
    if m.queue = invalid then return false
    if m.queue.items = invalid or m.queue.items.Count() = 0 then return false

    nextIndex = m.queue.index + direction
    if nextIndex < 0 or nextIndex >= m.queue.items.Count() then return false

    item = m.queue.items[nextIndex]
    if item = invalid or item.itemId = invalid or item.itemId = "" then return false

    emitPlaybackProgress(false)
    m.top.playRequest = buildQueuePlayRequest(nextIndex, item)

    return true
end function

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
' buildQueuePlayRequest
'-------------------------------------------------------------------------------
function buildQueuePlayRequest(index as integer, item as object) as object
    return {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: item.itemId
        item: item.item
        startPositionTicks: PlaybackProgress_GetTicksFromSelection(item)
        playbackQueue: m.queue.items
        playbackQueueIndex: index
    }
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
' skipPlayback
'-------------------------------------------------------------------------------
sub skipPlayback(offsetSeconds as integer)
    if m.playback.duration <= 0 then return

    stopSeekTimers()
    targetPosition = clampSeconds(m.videoPlayer.position + offsetSeconds, 0, m.playback.duration)
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
' updateTrickplayPreview
'-------------------------------------------------------------------------------
sub updateTrickplayPreview(position as float)
    if m.trickplay = invalid then
        m.playbackControls.thumbnailData = {}
        return
    end if

    tileBuffer = 15
    baseScale = getFiveImageTrickplayScale(m.trickplay.tileWidth, tileBuffer)
    largeScale = baseScale * 1.2
    smallScale = baseScale * 0.7
    largeWidth = m.trickplay.tileWidth * largeScale
    smallWidth = m.trickplay.tileWidth * smallScale
    largeHeight = m.trickplay.tileHeight * largeScale
    totalWidth = largeWidth + (smallWidth * 4) + (tileBuffer * 4)
    nextX = 960 - (totalWidth / 2)
    centerY = 875 - 25 - largeHeight
    deltaSeconds = getTrickplayPreviewDelta()
    images = []

    for slot = -2 to 2
        imageScale = smallScale
        if slot = 0 then imageScale = largeScale

        imagePosition = position + (deltaSeconds * slot)
        if imagePosition < 0 or imagePosition > m.playback.duration then
            images.Push({})
        else
            tileHeight = m.trickplay.tileHeight * imageScale
            y = centerY + ((largeHeight - tileHeight) / 2)
            images.Push(buildTrickplayPreviewImage(imagePosition, nextX, y, imageScale))
        end if

        nextX = nextX + (m.trickplay.tileWidth * imageScale) + tileBuffer
    end for

    m.playbackControls.thumbnailData = {
        images: images
    }
end sub

'-------------------------------------------------------------------------------
' getTrickplayPreviewDelta
'-------------------------------------------------------------------------------
function getTrickplayPreviewDelta() as integer
    if m.seek <> invalid and m.seek.speedIndex >= 0 then
        delta = m.seek.speeds[m.seek.speedIndex]
        if delta < 0 then delta = 0 - delta
        return delta
    end if

    return 10
end function

'-------------------------------------------------------------------------------
' getFiveImageTrickplayScale
'-------------------------------------------------------------------------------
function getFiveImageTrickplayScale(tileWidth as dynamic, tileBuffer as integer) as float
    if tileWidth = invalid or tileWidth <= 0 then return 1.0

    progressBarWidth = 1714
    availableWidth = progressBarWidth - (tileBuffer * 4)
    if availableWidth <= 0 then return 1.0

    return availableWidth / (tileWidth * 4)
end function

'-------------------------------------------------------------------------------
' buildTrickplayPreviewImage
'-------------------------------------------------------------------------------
function buildTrickplayPreviewImage(position as float, x as float, y as float, scale as float) as object
    iconIndex = Fix(position / m.trickplay.interval)
    if iconIndex < 0 then iconIndex = 0
    if iconIndex >= m.trickplay.thumbnailCount then iconIndex = m.trickplay.thumbnailCount - 1

    tilesPerSheet = m.trickplay.tileRows * m.trickplay.tileColumns
    tileIndex = Fix(iconIndex / tilesPerSheet)
    tileIconIndex = iconIndex - (tileIndex * tilesPerSheet)
    row = Fix(tileIconIndex / m.trickplay.tileColumns)
    column = tileIconIndex mod m.trickplay.tileColumns

    uri = getLocalTrickplayUri(tileIndex)
    if uri = "" then return {}

    return {
        uri: uri
        tileIndex: tileIndex
        tileWidth: m.trickplay.tileWidth
        tileHeight: m.trickplay.tileHeight
        sheetColumns: m.trickplay.tileColumns
        sheetRows: m.trickplay.tileRows
        column: column
        row: row
        scale: scale
        x: x
        y: y
        canUseFastReplace: m.trickplay.canUseFastReplace
    }
end function

'-------------------------------------------------------------------------------
' startTrickplayPreload
'-------------------------------------------------------------------------------
sub startTrickplayPreload()
    if m.trickplay = invalid then return

    m.trickplayPreloadRequest = {
        action: "add"
        server: m.session.server
        token: m.session.token
        itemId: m.session.itemId
        tileWidth: m.trickplay.tileWidth
        tileCount: m.trickplay.tileCount
    }
    m.trickplayPreloadTask.request = m.trickplayPreloadRequest
    m.trickplayPreloadTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' cleanupTrickplayPreload
'-------------------------------------------------------------------------------
sub cleanupTrickplayPreload()
    if m.trickplayPreloadRequest = invalid then return

    cleanupRequest = {
        action: "remove"
        itemId: m.trickplayPreloadRequest.itemId
        tileWidth: m.trickplayPreloadRequest.tileWidth
        tileCount: m.trickplayPreloadRequest.tileCount
    }
    m.trickplayPreloadRequest = invalid
    m.trickplayPreloadTask.control = "stop"
    m.trickplayPreloadTask.request = cleanupRequest
    m.trickplayPreloadTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onTrickplayPreloadResponse
'-------------------------------------------------------------------------------
sub onTrickplayPreloadResponse()
    response = m.trickplayPreloadTask.response
    if response = invalid then return
    if response.ok <> true then return
    if SafeString(response.itemId, "") <> m.session.itemId then return

    if response.tileIndex <> invalid and m.trickplay <> invalid then
        m.trickplay.loadedTiles[response.tileIndex.ToStr()] = true
    end if

    if m.playback.isSeeking = true then updateTrickplayPreview(m.playback.previewPosition)
end sub

'-------------------------------------------------------------------------------
' getLocalTrickplayUri
'-------------------------------------------------------------------------------
function getLocalTrickplayUri(tileIndex as integer) as string
    if m.trickplay = invalid then return ""
    if m.trickplay.loadedTiles = invalid then return ""
    if m.trickplay.loadedTiles[tileIndex.ToStr()] <> true then return ""

    return "tmp:/starfish-trickplay-" + m.session.itemId + "-" + m.trickplay.tileWidth.ToStr() + "-" + tileIndex.ToStr() + ".jpg"
end function

'-------------------------------------------------------------------------------
' buildTrickplayState
'-------------------------------------------------------------------------------
function buildTrickplayState(item as dynamic, itemId as string) as dynamic
    trickplay = getItemTrickplay(item)
    if trickplay = invalid or itemId = "" then return invalid

    itemTrickplay = trickplay.LookupCI(itemId)
    if itemTrickplay = invalid or itemTrickplay.Keys().Count() = 0 then return invalid

    widthKeys = itemTrickplay.Keys()
    data = itemTrickplay[widthKeys[0]]
    if data = invalid then return invalid
    if data.Width = invalid or data.Height = invalid then return invalid
    if data.TileWidth = invalid or data.TileHeight = invalid then return invalid
    if data.Interval = invalid or data.Interval <= 0 then return invalid

    thumbnailCount = 0
    if data.ThumbnailCount <> invalid then thumbnailCount = data.ThumbnailCount
    if thumbnailCount <= 0 then return invalid

    tilesPerSheet = data.TileHeight * data.TileWidth
    tileCount = Fix((thumbnailCount - 1) / tilesPerSheet) + 1

    return {
        tileWidth: data.Width
        tileHeight: data.Height
        tileColumns: data.TileWidth
        tileRows: data.TileHeight
        interval: data.Interval / 1000
        thumbnailCount: thumbnailCount
        tileCount: tileCount
        canUseFastReplace: (data.TileHeight * data.Height) * (data.TileWidth * data.Width) < 2000000
        loadedTiles: {}
    }
end function

'-------------------------------------------------------------------------------
' getItemTrickplay
'-------------------------------------------------------------------------------
function getItemTrickplay(item as dynamic) as dynamic
    if item = invalid then return invalid
    if item.Trickplay <> invalid then return item.Trickplay
    if item.trickplay <> invalid then return item.trickplay

    return invalid
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

'-------------------------------------------------------------------------------
' clampSeconds
'-------------------------------------------------------------------------------
function clampSeconds(value as float, minimum as float, maximum as float) as float
    if value < minimum then return minimum
    if value > maximum then return maximum

    return value
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then
        if key = "left" then
            stopTenSecondRepeat("left")
            return true
        else if key = "right" then
            stopTenSecondRepeat("right")
            return true
        end if

        return false
    end if

    if key = "back" then
        if m.playback.isSeeking = true then
            cancelSeek()
            return true
        end if

        if m.playbackControls.visible = true then
            hideControls()
            return true
        end if

        emitPlaybackProgress(false)
        stopPlayback()
        m.top.closeRequested = true
        return true
    else if key = "left" then
        handleProgressSeekInput("left")
        return true
    else if key = "right" then
        handleProgressSeekInput("right")
        return true
    else if key = "rewind" then
        handleProgressSeekInput("rewind")
        return true
    else if key = "fastforward" then
        handleProgressSeekInput("fastforward")
        return true
    else if key = "OK" then
        if m.playback.isSeeking = true then
            commitSeek()
        else if m.playbackControls.visible = true then
            hideControls()
        else
            showControls(true)
        end if
        return true
    else if key = "play" then
        if m.playback.isSeeking = true then
            commitSeek()
        else
            togglePlayback()
        end if
        return true
    else if key = "up" or key = "down" then
        showControls(true)
        return true
    end if

    return false
end function

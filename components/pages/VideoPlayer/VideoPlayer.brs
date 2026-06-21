'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("VideoPlayer")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.playbackControls = m.top.findNode("playbackControls")
    m.statusLabel = m.top.findNode("statusLabel")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")
    m.playstateTask = m.top.findNode("playstateTask")
    m.controlsHideTimer = m.top.findNode("controlsHideTimer")
    m.playstateTimer = m.top.findNode("playstateTimer")

    m.playback = {
        isSeeking: false
        isPlaying: false
        hasReportedStart: false
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
    m.trickplay = invalid

    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
    m.videoPlayer.observeField("position", "onVideoPositionChanged")
    m.videoPlayer.observeField("duration", "onVideoDurationChanged")
    m.playbackControls.observeField("previousPressed", "onPreviousPressed")
    m.playbackControls.observeField("playPausePressed", "onPlayPausePressed")
    m.playbackControls.observeField("nextPressed", "onNextPressed")
    m.controlsHideTimer.observeField("fire", "onControlsHideTimerFire")
    m.playstateTimer.observeField("fire", "onPlaystateTimerFire")
end sub

'-------------------------------------------------------------------------------
' onPlayRequestChanged
'-------------------------------------------------------------------------------
sub onPlayRequestChanged()
    request = m.top.playRequest
    if request = invalid then return

    m.statusLabel.text = "Loading video..."
    m.statusLabel.visible = true
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
        m.statusLabel.text = SafeString(response.errorMessage, "Unable to play this item.")
        m.statusLabel.visible = true
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

    content = CreateObject("roSGNode", "ContentNode")
    content.url = response.streamUrl
    content.streamFormat = response.streamFormat
    content.title = getItemTitle(item)
    content.PlayStart = PlaybackProgress_TicksToSeconds(response.startPositionTicks)
    content.AddHeader("Authorization", JellyfinAuth_BuildPlaybackHeader(request.token, request.userId))

    m.playback.duration = getRuntimeSeconds(item)
    m.playbackControls.title = content.title
    m.playbackControls.duration = m.playback.duration
    m.playbackControls.position = 0
    m.playbackControls.previewPosition = 0
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}

    m.videoPlayer.content = content
    m.videoPlayer.setFocus(true)
    disableScreenSaver()
    m.videoPlayer.control = "play"
    m.statusLabel.visible = false
end sub

'-------------------------------------------------------------------------------
' onVideoStateChanged
'-------------------------------------------------------------------------------
sub onVideoStateChanged()
    state = LCase(SafeString(m.videoPlayer.state, ""))
    if state = "error" then
        reportPlaystateStop()
        enableScreenSaver()
        m.statusLabel.text = "Unable to play this video."
        m.statusLabel.visible = true
    else if state = "finished" then
        reportPlaystateStop()
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
' hideControls
'-------------------------------------------------------------------------------
sub hideControls()
    m.controlsHideTimer.control = "stop"
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
    if m.playback.duration <= 0 then return

    m.playback.isSeeking = true
    m.playback.previewPosition = m.videoPlayer.position
    m.videoPlayer.control = "pause"
    m.playbackControls.isSeeking = true
    showControls(false)
    adjustSeek(direction)
end sub

'-------------------------------------------------------------------------------
' adjustSeek
'-------------------------------------------------------------------------------
sub adjustSeek(direction as integer)
    if m.playback.duration <= 0 then return

    m.playback.previewPosition = clampSeconds(m.playback.previewPosition + (direction * 10), 0, m.playback.duration)
    m.playbackControls.previewPosition = m.playback.previewPosition
    updateTrickplayPreview(m.playback.previewPosition)
end sub

'-------------------------------------------------------------------------------
' commitSeek
'-------------------------------------------------------------------------------
sub commitSeek()
    if m.playback.isSeeking <> true then return

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

' playQueueItem
'-------------------------------------------------------------------------------
function playQueueItem(direction as integer) as boolean
    if m.queue = invalid then return false
    if m.queue.items = invalid or m.queue.items.Count() = 0 then return false

    nextIndex = m.queue.index + direction
    if nextIndex < 0 or nextIndex >= m.queue.items.Count() then return false

    item = m.queue.items[nextIndex]
    if item = invalid or item.itemId = invalid or item.itemId = "" then return false

    m.top.playRequest = buildQueuePlayRequest(nextIndex, item)

    return true
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

    position = m.videoPlayer.position
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

    iconIndex = Fix(position / m.trickplay.interval)
    if iconIndex < 0 then iconIndex = 0
    if iconIndex >= m.trickplay.thumbnailCount then iconIndex = m.trickplay.thumbnailCount - 1

    tilesPerSheet = m.trickplay.tileRows * m.trickplay.tileColumns
    tileIndex = Fix(iconIndex / tilesPerSheet)
    tileIconIndex = iconIndex - (tileIndex * tilesPerSheet)
    row = Fix(tileIconIndex / m.trickplay.tileColumns)
    column = tileIconIndex mod m.trickplay.tileColumns

    uri = NormalizeServerUrl(m.session.server) + "/Videos/" + m.session.itemId + "/Trickplay/" + m.trickplay.tileWidth.ToStr() + "/" + tileIndex.ToStr() + ".jpg?ApiKey=" + m.session.token
    m.playbackControls.thumbnailData = {
        uri: uri
        tileWidth: m.trickplay.tileWidth
        tileHeight: m.trickplay.tileHeight
        sheetColumns: m.trickplay.tileColumns
        sheetRows: m.trickplay.tileRows
        column: column
        row: row
        scale: getTrickplayScale(m.trickplay.tileWidth, m.trickplay.tileHeight)
    }
end sub

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

    return {
        tileWidth: data.Width
        tileHeight: data.Height
        tileColumns: data.TileWidth
        tileRows: data.TileHeight
        interval: data.Interval / 1000
        thumbnailCount: thumbnailCount
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
' getTrickplayScale
'-------------------------------------------------------------------------------
function getTrickplayScale(tileWidth as dynamic, tileHeight as dynamic) as float
    if tileWidth = invalid or tileHeight = invalid then return 1.0
    if tileWidth <= 0 or tileHeight <= 0 then return 1.0

    widthScale = 320 / tileWidth
    heightScale = 180 / tileHeight
    if widthScale < heightScale then return widthScale

    return heightScale
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
    if press = false then return false

    if key = "back" then
        if m.playback.isSeeking = true then
            cancelSeek()
            return true
        end if

        if m.playbackControls.visible = true then
            hideControls()
            return true
        end if

        stopPlayback()
        m.top.closeRequested = true
        return true
    else if key = "left" or key = "rewind" then
        if m.playback.isSeeking = true then
            adjustSeek(-1)
        else
            beginSeek(-1)
        end if
        return true
    else if key = "right" or key = "fastforward" then
        if m.playback.isSeeking = true then
            adjustSeek(1)
        else
            beginSeek(1)
        end if
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

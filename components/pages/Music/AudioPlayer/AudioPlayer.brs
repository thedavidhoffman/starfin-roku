'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.albumArtwork = m.top.findNode("albumArtwork")
    m.backdrop = m.top.findNode("backdrop")
    m.albumTitle = m.top.findNode("albumTitle")
    m.albumHeading = m.top.findNode("albumHeading")
    m.artistName = m.top.findNode("artistName")
    m.timeline = m.top.findNode("timeline")
    m.timelineFocus = m.top.findNode("timelineFocus")
    m.timelineBackground = m.top.findNode("timelineBackground")
    m.timelineProgress = m.top.findNode("timelineProgress")
    m.scrubber = m.top.findNode("scrubber")
    m.positionLabel = m.top.findNode("positionLabel")
    m.durationLabel = m.top.findNode("durationLabel")
    m.previousButton = m.top.findNode("previousButton")
    m.playPauseButton = m.top.findNode("playPauseButton")
    m.nextButton = m.top.findNode("nextButton")
    m.trackList = m.top.findNode("trackList")
    m.audio = m.top.findNode("audio")
    m.tracksTask = m.top.findNode("tracksTask")
    m.playbackInfoTask = m.top.findNode("playbackInfoTask")

    m.playerState = {
        request: invalid
        tracks: []
        currentIndex: -1
        focusArea: "tracks"
        buttonIndex: 1
        seeking: false
        seekPosition: 0.0
    }
    configureButtons()
    m.tracksTask.observeField("response", "onTracksResponse")
    m.playbackInfoTask.observeField("response", "onPlaybackInfoResponse")
    m.audio.observeField("state", "onAudioStateChanged")
    m.audio.observeField("position", "onPlaybackProgressChanged")
    m.audio.observeField("duration", "onPlaybackProgressChanged")
    m.trackList.observeField("itemSelected", "onTrackSelected")
    m.previousButton.observeField("buttonSelected", "playPrevious")
    m.playPauseButton.observeField("buttonSelected", "togglePlayback")
    m.nextButton.observeField("buttonSelected", "playNext")
end sub

'-------------------------------------------------------------------------------
' configureButtons
'-------------------------------------------------------------------------------
sub configureButtons()
    m.previousButton.icon = "pkg:/images/icons/playback-controls/skip-back-unfocused.png"
    m.previousButton.focusedIcon = "pkg:/images/icons/playback-controls/skip-back-focused.png"
    m.nextButton.icon = "pkg:/images/icons/playback-controls/skip-forward-unfocused.png"
    m.nextButton.focusedIcon = "pkg:/images/icons/playback-controls/skip-forward-focused.png"
    updatePlayPauseIcon()
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return
    m.playerState.request = request
    m.playerState.tracks = []
    m.playerState.currentIndex = -1
    album = request.item
    m.albumHeading.text = FirstNonEmpty([album.Name], "Untitled Album")
    m.albumTitle.text = ""
    m.artistName.text = getAlbumArtist(album)
    artworkUrl = getAlbumArtworkUrl(album, request)
    m.albumArtwork.uri = artworkUrl
    m.backdrop.uri = artworkUrl
    m.trackList.content = CreateObject("roSGNode", "ContentNode")
    updateTimeline(0, 0)

    m.tracksTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        albumId: request.albumId
    }
    m.tracksTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onTracksResponse
'-------------------------------------------------------------------------------
sub onTracksResponse()
    response = m.tracksTask.response
    request = m.playerState.request
    if response = invalid or request = invalid then return
    if SafeString(response.albumId, "") <> SafeString(request.albumId, "") then return
    if response.ok <> true or response.data = invalid or response.data.Items = invalid then return

    m.playerState.tracks = response.data.Items
    renderTracks()
    if m.playerState.tracks.Count() > 0 then playTrack(0)
end sub

'-------------------------------------------------------------------------------
' renderTracks
'-------------------------------------------------------------------------------
sub renderTracks()
    content = CreateObject("roSGNode", "ContentNode")
    for i = 0 to m.playerState.tracks.Count() - 1
        track = m.playerState.tracks[i]
        node = content.createChild("ContentNode")
        node.title = FirstNonEmpty([track.Name], "Untitled Track")
        node.AddFields({
            trackNumber: getTrackNumber(track, i)
            durationText: formatTime(getTrackDuration(track))
            isCurrent: i = m.playerState.currentIndex
        })
    end for
    m.trackList.content = content
end sub

'-------------------------------------------------------------------------------
' onTrackSelected
'-------------------------------------------------------------------------------
sub onTrackSelected()
    index = m.trackList.itemSelected
    if index < 0 or index >= m.playerState.tracks.Count() then return
    playTrack(index)
end sub

'-------------------------------------------------------------------------------
' playTrack
'-------------------------------------------------------------------------------
sub playTrack(index as integer)
    if index < 0 or index >= m.playerState.tracks.Count() then return
    m.audio.control = "stop"
    m.playerState.currentIndex = index
    m.playerState.seeking = false
    renderTracks()
    m.trackList.jumpToItem = index
    track = m.playerState.tracks[index]
    m.albumTitle.text = FirstNonEmpty([track.Name], "Untitled Track")
    request = m.playerState.request
    m.playbackInfoTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: SafeString(track.Id, "")
        title: FirstNonEmpty([track.Name], "Untitled Track")
    }
    m.playbackInfoTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onPlaybackInfoResponse
'-------------------------------------------------------------------------------
sub onPlaybackInfoResponse()
    response = m.playbackInfoTask.response
    track = getCurrentTrack()
    if response = invalid or track = invalid or response.ok <> true then return
    if SafeString(response.itemId, "") <> SafeString(track.Id, "") then return

    content = CreateObject("roSGNode", "ContentNode")
    content.url = SafeString(response.streamUrl, "")
    content.streamFormat = SafeString(response.streamFormat, "")
    content.title = FirstNonEmpty([track.Name], "Untitled Track")
    if content.url = "" then return
    m.audio.content = content
    m.audio.control = "play"
    updatePlayPauseIcon()
end sub

'-------------------------------------------------------------------------------
' onAudioStateChanged
'-------------------------------------------------------------------------------
sub onAudioStateChanged()
    state = LCase(SafeString(m.audio.state, ""))
    updatePlayPauseIcon()
    if state = "finished" then playNext()
end sub

'-------------------------------------------------------------------------------
' togglePlayback
'-------------------------------------------------------------------------------
sub togglePlayback()
    state = LCase(SafeString(m.audio.state, ""))
    if state = "playing" then
        m.audio.control = "pause"
    else
        m.audio.control = "resume"
    end if
    updatePlayPauseIcon()
end sub

'-------------------------------------------------------------------------------
' updatePlayPauseIcon
'-------------------------------------------------------------------------------
sub updatePlayPauseIcon()
    if m.playPauseButton = invalid then return
    if LCase(SafeString(m.audio.state, "")) = "playing" then
        m.playPauseButton.icon = "pkg:/images/icons/playback-controls/pause-unfocused.png"
        m.playPauseButton.focusedIcon = "pkg:/images/icons/playback-controls/pause-focused.png"
    else
        m.playPauseButton.icon = "pkg:/images/icons/playback-controls/play-unfocused.png"
        m.playPauseButton.focusedIcon = "pkg:/images/icons/playback-controls/play-focused.png"
    end if
end sub

'-------------------------------------------------------------------------------
' playPrevious
'-------------------------------------------------------------------------------
sub playPrevious()
    if m.playerState.currentIndex > 0 then playTrack(m.playerState.currentIndex - 1)
end sub

'-------------------------------------------------------------------------------
' playNext
'-------------------------------------------------------------------------------
sub playNext()
    if m.playerState.currentIndex < m.playerState.tracks.Count() - 1 then playTrack(m.playerState.currentIndex + 1)
end sub

'-------------------------------------------------------------------------------
' onPlaybackProgressChanged
'-------------------------------------------------------------------------------
sub onPlaybackProgressChanged()
    if m.playerState.seeking = true then return
    updateTimeline(m.audio.position, m.audio.duration)
end sub

'-------------------------------------------------------------------------------
' updateTimeline
'-------------------------------------------------------------------------------
sub updateTimeline(position as dynamic, duration as dynamic)
    positionValue = Number_ToFloat(position, 0.0)
    durationValue = Number_ToFloat(duration, 0.0)
    if durationValue < 1 then durationValue = getTrackDuration(getCurrentTrack())
    if durationValue < 1 then durationValue = 1
    if positionValue < 0 then positionValue = 0
    if positionValue > durationValue then positionValue = durationValue
    width = m.timelineBackground.width * (positionValue / durationValue)
    m.timelineProgress.width = width
    m.scrubber.translation = [width - 9, -6]
    m.positionLabel.text = formatTime(positionValue)
    m.durationLabel.text = formatTime(durationValue)
end sub

'-------------------------------------------------------------------------------
' seekBy
'-------------------------------------------------------------------------------
sub seekBy(seconds as float)
    duration = Number_ToFloat(m.audio.duration, getTrackDuration(getCurrentTrack()))
    position = Number_ToFloat(m.audio.position, 0.0) + seconds
    if position < 0 then position = 0
    if duration > 0 and position > duration then position = duration
    m.audio.seek = position
    updateTimeline(position, duration)
end sub

'-------------------------------------------------------------------------------
' focusArea
'-------------------------------------------------------------------------------
sub focusArea(area as string)
    m.playerState.focusArea = area
    m.timelineFocus.visible = area = "timeline"
    if area = "timeline" then
        m.timeline.setFocus(true)
    else if area = "buttons" then
        buttons = getButtons()
        buttons[m.playerState.buttonIndex].setFocus(true)
    else
        m.trackList.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' getButtons
'-------------------------------------------------------------------------------
function getButtons() as object
    return [m.previousButton, m.playPauseButton, m.nextButton]
end function

'-------------------------------------------------------------------------------
' getCurrentTrack
'-------------------------------------------------------------------------------
function getCurrentTrack() as dynamic
    index = m.playerState.currentIndex
    if index < 0 or index >= m.playerState.tracks.Count() then return invalid
    return m.playerState.tracks[index]
end function

'-------------------------------------------------------------------------------
' getAlbumArtworkUrl
'-------------------------------------------------------------------------------
function getAlbumArtworkUrl(album as dynamic, request as object) as string
    if album = invalid then return "pkg:/images/music/album-placeholder-340x340.png"
    tag = ""
    if album.ImageTags <> invalid then tag = SafeString(album.ImageTags.Primary, "")
    if tag = "" then return "pkg:/images/music/album-placeholder-340x340.png"
    return Url_BuildImageUrl(request.server, request.albumId, "Primary", tag, 650, 650)
end function

'-------------------------------------------------------------------------------
' getAlbumArtist
'-------------------------------------------------------------------------------
function getAlbumArtist(album as dynamic) as string
    if album = invalid then return ""
    if album.AlbumArtist <> invalid then return SafeString(album.AlbumArtist, "")
    if album.Artists <> invalid and album.Artists.Count() > 0 then return SafeString(album.Artists[0], "")
    return ""
end function

'-------------------------------------------------------------------------------
' getTrackNumber
'-------------------------------------------------------------------------------
function getTrackNumber(track as object, index as integer) as string
    disc = Number_ToInteger(track.ParentIndexNumber, 0)
    number = Number_ToInteger(track.IndexNumber, index + 1)
    if disc > 1 then return disc.ToStr() + "." + number.ToStr()
    return number.ToStr()
end function

'-------------------------------------------------------------------------------
' getTrackDuration
'-------------------------------------------------------------------------------
function getTrackDuration(track as dynamic) as float
    if track = invalid then return 0.0
    return Number_ToFloat(track.RunTimeTicks, 0.0) / 10000000.0
end function

'-------------------------------------------------------------------------------
' formatTime
'-------------------------------------------------------------------------------
function formatTime(value as dynamic) as string
    total = Number_ToInteger(value, 0)
    if total < 0 then total = 0
    minutes = Number_ToInteger(total / 60, 0)
    seconds = total mod 60
    secondText = seconds.ToStr()
    if seconds < 10 then secondText = "0" + secondText
    return minutes.ToStr() + ":" + secondText
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusArea("tracks")
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.tracksTask.control = "stop"
    m.playbackInfoTask.control = "stop"
    m.audio.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    key = LCase(key)
    area = m.playerState.focusArea
    if key = "back" then
        m.top.closeRequested = true
        return true
    else if key = "play" then
        togglePlayback()
        return true
    end if

    if area = "tracks" then
        if key = "left" then focusArea("timeline") : return true
    else if area = "timeline" then
        if key = "left" then seekBy(-10.0) : return true
        if key = "right" then seekBy(10.0) : return true
        if key = "down" then focusArea("buttons") : return true
        if key = "up" then focusArea("tracks") : return true
    else if area = "buttons" then
        if key = "left" and m.playerState.buttonIndex > 0 then m.playerState.buttonIndex-- : focusArea("buttons") : return true
        if key = "right" and m.playerState.buttonIndex < 2 then m.playerState.buttonIndex++ : focusArea("buttons") : return true
        if key = "up" then focusArea("timeline") : return true
        if key = "right" and m.playerState.buttonIndex = 2 then focusArea("tracks") : return true
    end if
    return false
end function

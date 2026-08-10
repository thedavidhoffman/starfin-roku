'-------------------------------------------------------------------------------
' initMediaSegments
'-------------------------------------------------------------------------------
sub initMediaSegments()
    m.mediaSegments = {
        itemId: ""
        intros: []
        loaded: false
        dismissedEndSeconds: -1
        activeEndSeconds: -1
    }
end sub

'-------------------------------------------------------------------------------
' resetMediaSegments
'-------------------------------------------------------------------------------
sub resetMediaSegments()
    hideSkipIntroButton()
    m.mediaSegmentsTask.control = "stop"
    initMediaSegments()
end sub

'-------------------------------------------------------------------------------
' loadMediaSegments
'-------------------------------------------------------------------------------
sub loadMediaSegments(playbackResponse as dynamic)
    if playbackResponse = invalid then return
    if m.session.itemId = "" then return
    if m.mediaSegments.itemId = m.session.itemId and m.mediaSegments.loaded = true then return

    if m.mediaSegments.itemId <> m.session.itemId then resetMediaSegments()
    if hasMediaSegments(playbackResponse.payload) <> true then return

    m.mediaSegments.itemId = m.session.itemId
    m.log.write("Loading media segments itemId=" + m.session.itemId)
    m.mediaSegmentsTask.request = {
        server: m.session.server
        token: m.session.token
        itemId: m.session.itemId
    }
    m.mediaSegmentsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' hasMediaSegments
'-------------------------------------------------------------------------------
function hasMediaSegments(playbackInfo as dynamic) as boolean
    if playbackInfo = invalid or playbackInfo.MediaSources = invalid then return false
    if playbackInfo.MediaSources.Count() = 0 then return false

    return playbackInfo.MediaSources[0].HasSegments = true
end function

'-------------------------------------------------------------------------------
' onMediaSegmentsResponse
'-------------------------------------------------------------------------------
sub onMediaSegmentsResponse()
    response = m.mediaSegmentsTask.response
    if response = invalid then return
    if SafeString(response.itemId, "") <> m.session.itemId then return

    if response.ok <> true then
        m.log.write("Unable to load media segments itemId=" + m.session.itemId + " error=" + SafeString(response.errorMessage, ""))
        return
    end if

    intros = []
    for each segment in response.segments
        if segment <> invalid and LCase(SafeString(segment.Type, "")) = "intro" then
            startSeconds = Number_ToFloat(segment.StartTicks, 0) / 10000000
            endSeconds = Number_ToFloat(segment.EndTicks, 0) / 10000000
            if endSeconds > startSeconds then
                intros.Push({ startSeconds: startSeconds, endSeconds: endSeconds })
            end if
        end if
    end for

    m.mediaSegments.intros = intros
    m.mediaSegments.loaded = true
    m.log.write("Media segments loaded itemId=" + m.session.itemId + " introCount=" + intros.Count().ToStr())
    updateSkipIntroButton(m.playback.position)
end sub

'-------------------------------------------------------------------------------
' updateSkipIntroButton
'-------------------------------------------------------------------------------
sub updateSkipIntroButton(position as dynamic)
    activeIntro = getActiveIntroSegment(Number_ToFloat(position, 0))
    if activeIntro = invalid or canShowSkipIntroButton() <> true then
        hideSkipIntroButton()
        return
    end if

    m.mediaSegments.activeEndSeconds = activeIntro.endSeconds
    if m.skipIntroButton.visible = true then return

    m.skipIntroButton.visible = true
    m.skipIntroButton.hasFocusVisual = true
    m.top.setFocus(true)
    m.log.write("Skip Intro available itemId=" + m.session.itemId + " position=" + SafeString(position, "") + " end=" + SafeString(activeIntro.endSeconds, ""))
end sub

'-------------------------------------------------------------------------------
' getActiveIntroSegment
'-------------------------------------------------------------------------------
function getActiveIntroSegment(position as float) as dynamic
    if m.mediaSegments = invalid then return invalid

    for each intro in m.mediaSegments.intros
        if position >= intro.startSeconds and position < intro.endSeconds - 5 then
            if intro.endSeconds <> m.mediaSegments.dismissedEndSeconds then return intro
        end if
    end for

    if m.mediaSegments.dismissedEndSeconds >= 0 and position >= m.mediaSegments.dismissedEndSeconds then
        m.mediaSegments.dismissedEndSeconds = -1
    end if
    return invalid
end function

'-------------------------------------------------------------------------------
' canShowSkipIntroButton
'-------------------------------------------------------------------------------
function canShowSkipIntroButton() as boolean
    if m.playback.isSeeking = true then return false
    if m.overlay.area <> "none" then return false
    return LCase(SafeString(m.videoPlayer.state, "")) = "playing"
end function

'-------------------------------------------------------------------------------
' hideSkipIntroButton
'-------------------------------------------------------------------------------
sub hideSkipIntroButton()
    if m.skipIntroButton = invalid then return

    m.skipIntroButton.visible = false
    m.skipIntroButton.hasFocusVisual = false
end sub

'-------------------------------------------------------------------------------
' dismissCurrentIntroSegment
'-------------------------------------------------------------------------------
sub dismissCurrentIntroSegment()
    if m.mediaSegments.activeEndSeconds >= 0 then
        m.mediaSegments.dismissedEndSeconds = m.mediaSegments.activeEndSeconds
    end if
    hideSkipIntroButton()
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onSkipIntroSelected
'-------------------------------------------------------------------------------
sub onSkipIntroSelected()
    targetPosition = m.mediaSegments.activeEndSeconds
    if targetPosition < 0 then return

    m.log.write("Skipping intro itemId=" + m.session.itemId + " position=" + SafeString(m.playback.position, "") + " target=" + SafeString(targetPosition, ""))
    m.mediaSegments.dismissedEndSeconds = targetPosition
    hideSkipIntroButton()
    stopSeekTimers()
    m.playback.isSeeking = false
    m.playback.position = targetPosition
    m.playback.previewPosition = targetPosition
    m.playbackControls.position = targetPosition
    m.playbackControls.previewPosition = targetPosition
    logPlaybackSeekRequest("skipIntro", targetPosition)
    m.videoPlayer.seek = targetPosition
    m.videoPlayer.control = "resume"
    m.top.setFocus(true)
    reportPlaystateUpdate()
end sub

'-------------------------------------------------------------------------------
' updateCast
'-------------------------------------------------------------------------------
sub updateCast(request as object, item as dynamic)
    people = getPeople(item)
    m.cast.server = SafeString(request.server, "")
    m.cast.people = people
    m.overlay.hasCast = m.cast.hasItems
    m.playbackControls.hasCastOptions = m.cast.hasItems
end sub

'-------------------------------------------------------------------------------
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item = invalid or item.People = invalid then return []
    return item.People
end function

'-------------------------------------------------------------------------------
' showCast
'-------------------------------------------------------------------------------
sub showCast()
    if m.cast.hasItems <> true then
        m.overlay.hasCast = false
        m.playbackControls.hasCastOptions = false
        showControls(true)
        return
    end if

    m.controlsHideTimer.control = "stop"
    m.playbackControls.callFunc("releaseFocus")
    m.playbackControls.visible = false
    m.overlay.area = "cast"
    m.overlay.hasCast = true
    m.castGradient.visible = true
    m.cast.visible = true
    m.cast.callFunc("activate")
    m.controlsHideTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' hideCast
'-------------------------------------------------------------------------------
sub hideCast(restorePlayerFocus = false as boolean)
    m.controlsHideTimer.control = "stop"
    m.cast.callFunc("deactivate")
    m.castGradient.visible = false
    m.cast.visible = false
    if m.overlay.area = "cast" then m.overlay.area = "none"
    if restorePlayerFocus = true then m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onCastAvailabilityChanged
'-------------------------------------------------------------------------------
sub onCastAvailabilityChanged()
    m.overlay.hasCast = m.cast.hasItems
    m.playbackControls.hasCastOptions = m.cast.hasItems
    if m.overlay.area = "cast" then hideCast(true)
end sub

'-------------------------------------------------------------------------------
' onCastOptionsPressed
'-------------------------------------------------------------------------------
sub onCastOptionsPressed()
    dismissSeekPreviewForCast()
    showCast()
end sub

'-------------------------------------------------------------------------------
' onPlaybackControlsFocusExitDown
'-------------------------------------------------------------------------------
sub onPlaybackControlsFocusExitDown()
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    showControls(true)
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitDown
'-------------------------------------------------------------------------------
sub onCastFocusExitDown()
    if m.overlay.area <> "cast" then return

    m.controlsHideTimer.control = "stop"
    m.cast.callFunc("activate")
    m.controlsHideTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' dismissSeekPreviewForCast
'-------------------------------------------------------------------------------
sub dismissSeekPreviewForCast()
    if m.playback.isSeeking <> true then return

    stopSeekTimers()
    resetSeekState()
    m.videoPlayer.control = "resume"
    m.playback.isSeeking = false
    m.playbackControls.isSeeking = false
    m.playbackControls.thumbnailData = {}
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    request = m.top.playRequest
    item = invalid
    if request <> invalid then item = request.item

    itemType = ""
    if item <> invalid then itemType = LCase(FirstNonEmpty([item.Type], ""))
    if itemType = "episode" then
        selection.sourceItemType = "series"
        selection.sourceSeriesId = SafeString(FirstNonEmpty([item.SeriesId], ""), "")
    else
        selection.sourceItemType = "movie"
        selection.sourceItemId = SafeString(m.session.itemId, "")
    end if

    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' pauseForPersonNavigation
'-------------------------------------------------------------------------------
sub pauseForPersonNavigation()
    state = LCase(SafeString(m.videoPlayer.state, ""))
    m.overlay.resumeAfterPersonNavigation = state = "playing" or state = "buffering"
    m.overlay.restoreCastAfterPersonNavigation = m.overlay.area = "cast"
    hideControls()
    hideCast()
    m.videoPlayer.control = "pause"
end sub

'-------------------------------------------------------------------------------
' resumeAfterPersonNavigation
'-------------------------------------------------------------------------------
sub resumeAfterPersonNavigation()
    if m.overlay.resumeAfterPersonNavigation = true then
        m.videoPlayer.control = "resume"
    end if
    restoreCast = m.overlay.restoreCastAfterPersonNavigation = true
    m.overlay.resumeAfterPersonNavigation = false
    m.overlay.restoreCastAfterPersonNavigation = false

    if restoreCast = true and m.cast.hasItems = true then
        showCast()
    else
        m.top.setFocus(true)
    end if
end sub

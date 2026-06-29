'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.playbackStateLabel = m.top.findNode("playbackStateLabel")
    m.previousButton = m.top.findNode("previousButton")
    m.playPauseButton = m.top.findNode("playPauseButton")
    m.nextButton = m.top.findNode("nextButton")
    m.trickplayPreview = m.top.findNode("trickplayPreview")
    m.progressBarGroup = m.top.findNode("progressBarGroup")
    m.progressFocusRect = m.top.findNode("progressFocusRect")
    m.progressBarBackground = m.top.findNode("progressBarBackground")
    m.progressBar = m.top.findNode("progressBar")
    m.previewBar = m.top.findNode("previewBar")
    m.scrubber = m.top.findNode("scrubber")
    m.positionLabel = m.top.findNode("positionLabel")
    m.remainingLabel = m.top.findNode("remainingLabel")

    m.controlState = {
        focusedIndex: 1
        focusArea: "buttons"
        buttons: [m.previousButton, m.playPauseButton, m.nextButton]
    }

    m.previousButton.observeField("buttonSelected", "onPreviousButtonSelected")
    m.playPauseButton.observeField("buttonSelected", "onPlayPauseButtonSelected")
    m.nextButton.observeField("buttonSelected", "onNextButtonSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' onTitleChanged
'-------------------------------------------------------------------------------
sub onTitleChanged()
    m.titleLabel.text = SafeString(m.top.title, "")
end sub

'-------------------------------------------------------------------------------
' onProgressChanged
'-------------------------------------------------------------------------------
sub onProgressChanged()
    if m.top.isSeeking = true then return
    updateProgress(m.top.position, false)
end sub

'-------------------------------------------------------------------------------
' onPreviewChanged
'-------------------------------------------------------------------------------
sub onPreviewChanged()
    if m.top.isSeeking <> true then return
    updateProgress(m.top.previewPosition, true)
end sub

'-------------------------------------------------------------------------------
' onSeekingChanged
'-------------------------------------------------------------------------------
sub onSeekingChanged()
    m.previewBar.visible = m.top.isSeeking = true
    m.trickplayPreview.isSeeking = m.top.isSeeking
    if m.top.isSeeking = true then
        updateProgress(m.top.previewPosition, true)
    else
        updateProgress(m.top.position, false)
    end if
end sub

'-------------------------------------------------------------------------------
' onPlayingChanged
'-------------------------------------------------------------------------------
sub onPlayingChanged()
    if m.top.isPlaying = true then
        m.playbackStateLabel.text = "PLAYING"
        m.playPauseButton.text = "Pause"
    else
        m.playbackStateLabel.text = "PAUSED"
        m.playPauseButton.text = "Play"
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    if m.top.isInFocusChain() = true then
        if m.controlState.focusArea = "progress" then
            focusProgress()
        else
            focusCurrentButton()
        end if
    else
        updateProgressFocus()
        updateButtonFocus()
    end if
end sub

'-------------------------------------------------------------------------------
' onPreviousButtonSelected
'-------------------------------------------------------------------------------
sub onPreviousButtonSelected()
    m.top.previousPressed = true
end sub

'-------------------------------------------------------------------------------
' onPlayPauseButtonSelected
'-------------------------------------------------------------------------------
sub onPlayPauseButtonSelected()
    m.top.playPausePressed = true
end sub

'-------------------------------------------------------------------------------
' onNextButtonSelected
'-------------------------------------------------------------------------------
sub onNextButtonSelected()
    m.top.nextPressed = true
end sub

'-------------------------------------------------------------------------------
' moveButtonFocus
'-------------------------------------------------------------------------------
sub moveButtonFocus(direction as integer)
    nextIndex = m.controlState.focusedIndex + direction
    if nextIndex < 0 then nextIndex = 0
    if nextIndex > m.controlState.buttons.Count() - 1 then nextIndex = m.controlState.buttons.Count() - 1

    m.controlState.focusedIndex = nextIndex
    focusCurrentButton()
end sub

'-------------------------------------------------------------------------------
' focusProgress
'-------------------------------------------------------------------------------
sub focusProgress()
    m.controlState.focusArea = "progress"
    m.progressBarGroup.setFocus(true)
    updateProgressFocus()
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' focusButtons
'-------------------------------------------------------------------------------
sub focusButtons()
    m.controlState.focusArea = "buttons"
    focusCurrentButton()
end sub

'-------------------------------------------------------------------------------
' focusCurrentButton
'-------------------------------------------------------------------------------
sub focusCurrentButton()
    m.controlState.focusArea = "buttons"
    button = m.controlState.buttons[m.controlState.focusedIndex]
    if button <> invalid then button.setFocus(true)
    updateProgressFocus()
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' releaseFocus
'-------------------------------------------------------------------------------
sub releaseFocus()
    m.progressBarGroup.setFocus(false)
    for each button in m.controlState.buttons
        if button <> invalid then button.setFocus(false)
    end for
    m.top.setFocus(false)
    updateProgressFocus()
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' updateButtonFocus
'-------------------------------------------------------------------------------
sub updateButtonFocus()
    for i = 0 to m.controlState.buttons.Count() - 1
        button = m.controlState.buttons[i]
        if button <> invalid then button.hasFocusVisual = i = m.controlState.focusedIndex and m.controlState.focusArea = "buttons" and m.top.isInFocusChain()
    end for
end sub

'-------------------------------------------------------------------------------
' updateProgressFocus
'-------------------------------------------------------------------------------
sub updateProgressFocus()
    m.progressFocusRect.visible = m.controlState.focusArea = "progress" and m.top.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' onThumbnailDataChanged
'-------------------------------------------------------------------------------
sub onThumbnailDataChanged()
    m.trickplayPreview.thumbnailData = m.top.thumbnailData
end sub

'-------------------------------------------------------------------------------
' updateProgress
'-------------------------------------------------------------------------------
sub updateProgress(position as dynamic, showPreview as boolean)
    duration = m.top.duration
    if duration = invalid or duration <= 0 then duration = 1

    clampedPosition = position
    if clampedPosition = invalid then clampedPosition = 0
    if clampedPosition < 0 then clampedPosition = 0
    if clampedPosition > duration then clampedPosition = duration

    progressWidth = m.progressBarBackground.width * (clampedPosition / duration)
    if showPreview = true then
        m.previewBar.width = progressWidth
    else
        m.progressBar.width = progressWidth
    end if

    m.scrubber.translation = [progressWidth - 10, -7]
    m.positionLabel.text = formatPlaybackTime(clampedPosition)
    m.remainingLabel.text = "-" + formatPlaybackTime(duration - clampedPosition)
end sub

'-------------------------------------------------------------------------------
' formatPlaybackTime
'-------------------------------------------------------------------------------
function formatPlaybackTime(totalSeconds as dynamic) as string
    seconds = Fix(totalSeconds)
    if seconds < 0 then seconds = 0

    hours = Fix(seconds / 3600)
    minutes = Fix((seconds mod 3600) / 60)
    seconds = seconds mod 60

    if hours > 0 then
        return hours.ToStr() + ":" + twoDigits(minutes) + ":" + twoDigits(seconds)
    end if

    return minutes.ToStr() + ":" + twoDigits(seconds)
end function

'-------------------------------------------------------------------------------
' twoDigits
'-------------------------------------------------------------------------------
function twoDigits(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then
        if m.controlState.focusArea = "progress" then
            if key = "left" then
                m.top.progressLeftReleased = true
                return true
            else if key = "right" then
                m.top.progressRightReleased = true
                return true
            end if
        end if

        return false
    end if

    if m.controlState.focusArea = "progress" then
        if key = "left" then
            m.top.progressLeftPressed = true
            return true
        else if key = "right" then
            m.top.progressRightPressed = true
            return true
        else if key = "rewind" then
            m.top.progressRewindPressed = true
            return true
        else if key = "fastforward" then
            m.top.progressFastForwardPressed = true
            return true
        else if key = "OK" or key = "play" then
            if m.top.isSeeking = true then
                m.top.progressSeekCommit = true
                return true
            end if

            return false
        else if key = "back" then
            if m.top.isSeeking = true then
                m.top.progressSeekCancel = true
                return true
            end if

            return false
        else if key = "down" then
            focusButtons()
            return true
        end if

        return false
    end if

    if key = "left" then
        moveButtonFocus(-1)
        return true
    else if key = "right" then
        moveButtonFocus(1)
        return true
    else if key = "up" then
        focusProgress()
        return true
    else if key = "down" then
        return true
    else if key = "play" then
        m.top.playPausePressed = true
        return true
    end if

    return false
end function

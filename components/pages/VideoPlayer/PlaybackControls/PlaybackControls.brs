'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.castButton = m.top.findNode("castButton")
    m.subtitleButton = m.top.findNode("subtitleButton")
    m.audioButton = m.top.findNode("audioButton")
    m.skipBackButton = m.top.findNode("skipBackButton")
    m.playPauseButton = m.top.findNode("playPauseButton")
    m.skipForwardButton = m.top.findNode("skipForwardButton")
    m.last5Button = m.top.findNode("last5Button")
    m.trickplayPreview = m.top.findNode("trickplayPreview")
    m.metadataLabels = {
        title: m.top.findNode("titleLabel")
        subtitle: m.top.findNode("subtitleLabel")
    }
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
        buttons: []
    }
    m.playPauseIcons = {
        play: {
            icon: "pkg:/images/icons/playback-controls/play-unfocused.png"
            focusedIcon: "pkg:/images/icons/playback-controls/play-focused.png"
        }
        pause: {
            icon: "pkg:/images/icons/playback-controls/pause-unfocused.png"
            focusedIcon: "pkg:/images/icons/playback-controls/pause-focused.png"
        }
    }
    m.trickplayPositions = {
        default: [103, 421]
        tall: [103, 360]
    }

    colors = Color()
    m.metadataLabels.title.color = colors.text.light.primary
    m.metadataLabels.subtitle.color = colors.text.light.secondary

    m.castButton.icon = "pkg:/images/icons/playback-controls/person-unfocused.png"
    m.castButton.focusedIcon = "pkg:/images/icons/playback-controls/person-focused.png"
    m.subtitleButton.icon = "pkg:/images/icons/playback-controls/subtitles-unfocused.png"
    m.subtitleButton.focusedIcon = "pkg:/images/icons/playback-controls/subtitles-focused.png"
    m.audioButton.icon = "pkg:/images/icons/playback-controls/audio-unfocused.png"
    m.audioButton.focusedIcon = "pkg:/images/icons/playback-controls/audio-focused.png"
    m.skipBackButton.icon = "pkg:/images/icons/playback-controls/skip-back-unfocused.png"
    m.skipBackButton.focusedIcon = "pkg:/images/icons/playback-controls/skip-back-focused.png"
    m.skipForwardButton.icon = "pkg:/images/icons/playback-controls/skip-forward-unfocused.png"
    m.skipForwardButton.focusedIcon = "pkg:/images/icons/playback-controls/skip-forward-focused.png"

    m.castButton.observeField("buttonSelected", "onCastButtonSelected")
    m.subtitleButton.observeField("buttonSelected", "onSubtitleButtonSelected")
    m.audioButton.observeField("buttonSelected", "onAudioButtonSelected")
    m.skipBackButton.observeField("buttonSelected", "onSkipBackButtonSelected")
    m.playPauseButton.observeField("buttonSelected", "onPlayPauseButtonSelected")
    m.skipForwardButton.observeField("buttonSelected", "onSkipForwardButtonSelected")
    m.last5Button.observeField("buttonSelected", "onLast5ButtonSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    onTitleChanged()
    onSubtitleChanged()
    onPlayingChanged()
    onOptionsChanged()
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' onTitleChanged
'-------------------------------------------------------------------------------
sub onTitleChanged()
    m.metadataLabels.title.text = SafeString(m.top.title, "")
end sub

'-------------------------------------------------------------------------------
' onSubtitleChanged
'-------------------------------------------------------------------------------
sub onSubtitleChanged()
    m.metadataLabels.subtitle.text = SafeString(m.top.subtitle, "")
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
        iconSet = m.playPauseIcons.pause
    else
        iconSet = m.playPauseIcons.play
    end if

    m.playPauseButton.icon = iconSet.icon
    m.playPauseButton.focusedIcon = iconSet.focusedIcon
end sub

'-------------------------------------------------------------------------------
' onOptionsChanged
'-------------------------------------------------------------------------------
sub onOptionsChanged()
    m.castButton.visible = m.top.hasCastOptions = true
    m.subtitleButton.visible = m.top.hasSubtitleOptions = true
    m.audioButton.visible = m.top.hasAudioOptions = true
    rebuildButtonList()
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
' onPlayPauseButtonSelected
'-------------------------------------------------------------------------------
sub onPlayPauseButtonSelected()
    m.top.playPausePressed = true
end sub

'-------------------------------------------------------------------------------
' onCastButtonSelected
'-------------------------------------------------------------------------------
sub onCastButtonSelected()
    m.top.castOptionsPressed = true
end sub

'-------------------------------------------------------------------------------
' onSubtitleButtonSelected
'-------------------------------------------------------------------------------
sub onSubtitleButtonSelected()
    m.top.subtitleOptionsPressed = true
end sub

'-------------------------------------------------------------------------------
' onAudioButtonSelected
'-------------------------------------------------------------------------------
sub onAudioButtonSelected()
    m.top.audioOptionsPressed = true
end sub

'-------------------------------------------------------------------------------
' onSkipBackButtonSelected
'-------------------------------------------------------------------------------
sub onSkipBackButtonSelected()
    m.top.progressRewindPressed = true
end sub

'-------------------------------------------------------------------------------
' onSkipForwardButtonSelected
'-------------------------------------------------------------------------------
sub onSkipForwardButtonSelected()
    m.top.progressFastForwardPressed = true
end sub

'-------------------------------------------------------------------------------
' onLast5ButtonSelected
'-------------------------------------------------------------------------------
sub onLast5ButtonSelected()
    m.top.last5Pressed = true
end sub

'-------------------------------------------------------------------------------
' moveButtonFocus
'-------------------------------------------------------------------------------
sub moveButtonFocus(direction as integer)
    rebuildButtonList()
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
    rebuildButtonList()
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
    allButtons = getAllButtons()
    for each button in allButtons
        if button <> invalid then button.setFocus(false)
    end for
    m.top.setFocus(false)
    updateProgressFocus()
    updateButtonFocus()
end sub

'-------------------------------------------------------------------------------
' getAllButtons
'-------------------------------------------------------------------------------
function getAllButtons() as object
    return [m.castButton, m.subtitleButton, m.audioButton, m.skipBackButton, m.playPauseButton, m.skipForwardButton, m.last5Button]
end function

'-------------------------------------------------------------------------------
' rebuildButtonList
'-------------------------------------------------------------------------------
sub rebuildButtonList()
    previousButtonId = ""
    if m.controlState.buttons.Count() > 0 and m.controlState.focusedIndex >= 0 and m.controlState.focusedIndex < m.controlState.buttons.Count() then
        previousButtonId = SafeString(m.controlState.buttons[m.controlState.focusedIndex].id, "")
    end if

    buttons = []
    allButtons = getAllButtons()
    for each button in allButtons
        if button <> invalid and button.visible <> false then buttons.Push(button)
    end for

    m.controlState.buttons = buttons
    if buttons.Count() = 0 then
        m.controlState.focusedIndex = 0
        return
    end if

    focusedIndex = -1
    if previousButtonId <> "" then
        for i = 0 to buttons.Count() - 1
            if SafeString(buttons[i].id, "") = previousButtonId then
                focusedIndex = i
                exit for
            end if
        end for
    end if

    if focusedIndex < 0 then focusedIndex = getDefaultButtonIndex(buttons)
    m.controlState.focusedIndex = focusedIndex
end sub

'-------------------------------------------------------------------------------
' getDefaultButtonIndex
'-------------------------------------------------------------------------------
function getDefaultButtonIndex(buttons as object) as integer
    for i = 0 to buttons.Count() - 1
        if SafeString(buttons[i].id, "") = "playPauseButton" then return i
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' updateButtonFocus
'-------------------------------------------------------------------------------
sub updateButtonFocus()
    allButtons = getAllButtons()
    for each button in allButtons
        if button <> invalid then button.hasFocusVisual = false
    end for

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
    updateTrickplayPreviewPosition(m.top.thumbnailData)
    m.trickplayPreview.thumbnailData = m.top.thumbnailData
end sub

'-------------------------------------------------------------------------------
' updateTrickplayPreviewPosition
'-------------------------------------------------------------------------------
sub updateTrickplayPreviewPosition(data as dynamic)
    if isTallTrickplayThumbnail(data) then
        m.trickplayPreview.translation = m.trickplayPositions.tall
    else
        m.trickplayPreview.translation = m.trickplayPositions.default
    end if
end sub

'-------------------------------------------------------------------------------
' isTallTrickplayThumbnail
'-------------------------------------------------------------------------------
function isTallTrickplayThumbnail(data as dynamic) as boolean
    if data = invalid then return false
    if data.tileWidth = invalid or data.tileWidth <= 0 then return false
    if data.tileHeight = invalid or data.tileHeight <= 0 then return false

    return (data.tileHeight / data.tileWidth) > (9 / 16)
end function

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
        m.top.focusExitDown = true
        return true
    else if key = "play" then
        m.top.playPausePressed = true
        return true
    end if

    return false
end function

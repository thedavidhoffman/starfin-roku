'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.playbackStateLabel = m.top.findNode("playbackStateLabel")
    m.previousButton = m.top.findNode("previousButton")
    m.playPauseButton = m.top.findNode("playPauseButton")
    m.nextButton = m.top.findNode("nextButton")
    m.thumbnailSlots = [
        {
            group: m.top.findNode("thumbnailGroup0")
            poster: m.top.findNode("thumbnailPoster0")
            background: m.top.findNode("thumbnailBackground0")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup1")
            poster: m.top.findNode("thumbnailPoster1")
            background: m.top.findNode("thumbnailBackground1")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup2")
            poster: m.top.findNode("thumbnailPoster2")
            background: m.top.findNode("thumbnailBackground2")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup3")
            poster: m.top.findNode("thumbnailPoster3")
            background: m.top.findNode("thumbnailBackground3")
            hasImage: false
        }
        {
            group: m.top.findNode("thumbnailGroup4")
            poster: m.top.findNode("thumbnailPoster4")
            background: m.top.findNode("thumbnailBackground4")
            hasImage: false
        }
    ]
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
    for each slot in m.thumbnailSlots
        slot.poster.observeField("loadStatus", "onThumbnailLoadStatusChanged")
    end for
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
    if m.top.isSeeking = true then
        updateProgress(m.top.previewPosition, true)
    else
        hideThumbnails()
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
    data = m.top.thumbnailData
    if data = invalid or data.images = invalid or data.images.Count() = 0 then
        hideThumbnails()
        return
    end if

    for i = 0 to m.thumbnailSlots.Count() - 1
        if i < data.images.Count() then
            updateThumbnailSlot(m.thumbnailSlots[i], data.images[i])
        else
            m.thumbnailSlots[i].hasImage = false
            m.thumbnailSlots[i].group.visible = false
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' updateThumbnailSlot
'-------------------------------------------------------------------------------
sub updateThumbnailSlot(slot as object, data as dynamic)
    if data = invalid or data.uri = invalid or data.uri = "" then
        slot.hasImage = false
        slot.group.visible = false
        return
    end if

    slot.hasImage = true
    scale = data.scale
    if scale = invalid or scale <= 0 then scale = 1.0

    tileWidth = data.tileWidth * scale
    tileHeight = data.tileHeight * scale
    sheetWidth = data.sheetColumns * tileWidth
    sheetHeight = data.sheetRows * tileHeight

    slot.group.translation = [data.x, 875 - 25 - tileHeight]
    slot.group.clippingRect = [0, 0, tileWidth, tileHeight]
    slot.background.width = tileWidth
    slot.background.height = tileHeight
    slot.poster.width = sheetWidth
    slot.poster.height = sheetHeight
    slot.poster.translation = [0 - (data.column * tileWidth), 0 - (data.row * tileHeight)]

    if slot.poster.uri <> data.uri then
        slot.group.visible = false
        slot.poster.uri = data.uri
    else
        slot.group.visible = LCase(SafeString(slot.poster.loadStatus, "")) = "ready"
    end if
end sub

'-------------------------------------------------------------------------------
' onThumbnailLoadStatusChanged
'-------------------------------------------------------------------------------
sub onThumbnailLoadStatusChanged()
    for each slot in m.thumbnailSlots
        if slot.hasImage = true and LCase(SafeString(slot.poster.loadStatus, "")) = "ready" then
            slot.group.visible = true
        else if LCase(SafeString(slot.poster.loadStatus, "")) = "failed" then
            slot.group.visible = false
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' hideThumbnails
'-------------------------------------------------------------------------------
sub hideThumbnails()
    for each slot in m.thumbnailSlots
        slot.hasImage = false
        slot.group.visible = false
    end for
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
    else if key = "play" then
        m.top.playPausePressed = true
        return true
    end if

    return false
end function

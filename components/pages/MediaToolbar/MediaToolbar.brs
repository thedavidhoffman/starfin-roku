'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.toolbarItems = m.top.findNode("toolbarItems")
    m.resumeButton = m.top.findNode("resumeButton")
    m.restartButton = m.top.findNode("restartButton")
    m.playButton = m.top.findNode("playButton")
    m.markWatchedButton = m.top.findNode("markWatchedButton")
    m.markUnwatchedButton = m.top.findNode("markUnwatchedButton")
    m.seriesButton = m.top.findNode("seriesButton")
    m.subtitlesButton = m.top.findNode("subtitlesButton")
    m.audioButton = m.top.findNode("audioButton")
    m.chaptersButton = m.top.findNode("chaptersButton")
    m.videoButton = m.top.findNode("videoButton")
    m.mediaInfoButton = m.top.findNode("mediaInfoButton")
    m.seasonButton = m.top.findNode("seasonButton")
    m.resumeButton.observeField("buttonSelected", "onResumeButtonSelected")
    m.restartButton.observeField("buttonSelected", "onRestartButtonSelected")
    m.playButton.observeField("buttonSelected", "onPlayButtonSelected")
    m.markWatchedButton.observeField("buttonSelected", "onMarkWatchedButtonSelected")
    m.markUnwatchedButton.observeField("buttonSelected", "onMarkUnwatchedButtonSelected")
    m.seriesButton.observeField("buttonSelected", "onSeriesButtonSelected")
    m.subtitlesButton.observeField("buttonSelected", "onSubtitlesButtonSelected")
    m.audioButton.observeField("buttonSelected", "onAudioButtonSelected")
    m.chaptersButton.observeField("buttonSelected", "onChaptersButtonSelected")
    m.videoButton.observeField("buttonSelected", "onVideoButtonSelected")
    m.mediaInfoButton.observeField("buttonSelected", "onMediaInfoButtonSelected")
    m.seasonButton.observeField("buttonSelected", "onSeasonButtonSelected")
    m.toolbarLayout = {
        collapsedWidth: 64
        defaultExpandedWidth: 168
        buttonSpacing: 12
    }
    m.focusState = {
        focusedIndex: 0
        buttons: []
        hasFocus: false
    }
    m.top.observeField("focusedChild", "onFocusChanged")
    updateToolbarButtons()
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.focusState.hasFocus = true
    m.top.setFocus(true)
    focusButton(m.focusState.focusedIndex)
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.focusState.hasFocus = false
    m.top.setFocus(false)
    layoutButtons()
end sub

'-------------------------------------------------------------------------------
' resetFocus
'-------------------------------------------------------------------------------
sub resetFocus()
    focusButton(0)
end sub

'-------------------------------------------------------------------------------
' focusButton
'-------------------------------------------------------------------------------
sub focusButton(index as integer)
    updateToolbarButtons()
    if m.focusState.buttons.Count() = 0 then return
    if index < 0 then index = 0
    if index >= m.focusState.buttons.Count() then index = m.focusState.buttons.Count() - 1

    m.focusState.focusedIndex = index
    m.focusState.hasFocus = true
    layoutButtons()
    m.focusState.buttons[index].setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    hasFocus = m.top.isInFocusChain()
    if m.focusState.hasFocus = hasFocus then return

    m.focusState.hasFocus = hasFocus
    layoutButtons()
end sub

'-------------------------------------------------------------------------------
' layoutButtons
'-------------------------------------------------------------------------------
sub layoutButtons()
    x = 0
    for i = 0 to m.focusState.buttons.Count() - 1
        button = m.focusState.buttons[i]
        button.translation = [x, 0]

        if m.focusState.hasFocus = true and i = m.focusState.focusedIndex then
            x = x + getButtonExpandedWidth(button)
        else
            x = x + m.toolbarLayout.collapsedWidth
        end if

        x = x + m.toolbarLayout.buttonSpacing
    end for
end sub

'-------------------------------------------------------------------------------
' getButtonExpandedWidth
'-------------------------------------------------------------------------------
function getButtonExpandedWidth(button as object) as integer
    if button.expandedWidth <> invalid and button.expandedWidth > 0 then
        return button.expandedWidth
    end if

    return m.toolbarLayout.defaultExpandedWidth
end function

'-------------------------------------------------------------------------------
' onWatchedStateChanged
'-------------------------------------------------------------------------------
sub onWatchedStateChanged()
    updateToolbarButtons()
end sub

'-------------------------------------------------------------------------------
' onMediaTypeChanged
'-------------------------------------------------------------------------------
sub onMediaTypeChanged()
    updateToolbarButtons()
end sub

'-------------------------------------------------------------------------------
' onStreamCountsChanged
'-------------------------------------------------------------------------------
sub onStreamCountsChanged()
    updateToolbarButtons()
end sub

'-------------------------------------------------------------------------------
' onResumePositionChanged
'-------------------------------------------------------------------------------
sub onResumePositionChanged()
    updateToolbarButtons()
end sub

'-------------------------------------------------------------------------------
' focusWatchedAction
'-------------------------------------------------------------------------------
sub focusWatchedAction()
    updateToolbarButtons()
    if m.focusState.buttons.Count() < 2 then
        focusButton(0)
        return
    end if

    focusButton(1)
end sub

'-------------------------------------------------------------------------------
' updateToolbarButtons
'-------------------------------------------------------------------------------
sub updateToolbarButtons()
    isWatched = m.top.isWatched = true
    supportsWatchedActions = m.top.supportsWatchedActions <> false
    mediaType = m.top.mediaType
    isMovie = mediaType = "movie"
    isEpisode = mediaType = "tv-episode"
    isSeason = mediaType = "tv-season"
    hasSubtitleOptions = m.top.subtitleStreamCount > 0
    hasAudioOptions = m.top.audioStreamCount > 1
    hasChapterOptions = m.top.chapterCount > 0
    hasResumeProgress = m.top.resumePositionSeconds > 0
    m.resumeButton.visible = hasResumeProgress
    m.restartButton.visible = hasResumeProgress
    m.playButton.visible = hasResumeProgress <> true
    m.resumeButton.text = "Resume"
    m.markWatchedButton.visible = supportsWatchedActions and (isWatched <> true)
    m.markUnwatchedButton.visible = supportsWatchedActions and (isWatched = true)
    m.subtitlesButton.visible = isSeason <> true and hasSubtitleOptions
    m.audioButton.visible = isSeason <> true and hasAudioOptions
    m.chaptersButton.visible = isSeason <> true and hasChapterOptions
    m.videoButton.visible = isSeason <> true and isMovie <> true
    m.mediaInfoButton.visible = isMovie or isEpisode
    m.seriesButton.visible = isMovie <> true
    m.seasonButton.visible = isMovie <> true

    streamButtons = []
    if isSeason <> true then
        if hasSubtitleOptions then streamButtons.Push(m.subtitlesButton)
        if hasAudioOptions then streamButtons.Push(m.audioButton)
        if hasChapterOptions then streamButtons.Push(m.chaptersButton)
        if isMovie <> true then streamButtons.Push(m.videoButton)
        if isMovie or isEpisode then streamButtons.Push(m.mediaInfoButton)
    end if

    if supportsWatchedActions <> true then
        m.focusState.buttons = []
    else if isWatched then
        m.focusState.buttons = []
    else
        m.focusState.buttons = []
    end if

    if hasResumeProgress then m.focusState.buttons.Push(m.resumeButton)
    if hasResumeProgress then m.focusState.buttons.Push(m.restartButton)
    if hasResumeProgress <> true then m.focusState.buttons.Push(m.playButton)
    if supportsWatchedActions = true and isWatched then
        m.focusState.buttons.Push(m.markUnwatchedButton)
    else if supportsWatchedActions = true then
        m.focusState.buttons.Push(m.markWatchedButton)
    end if

    m.focusState.buttons.Append(streamButtons)
    if isMovie <> true then m.focusState.buttons.Append([m.seriesButton, m.seasonButton])

    if m.focusState.focusedIndex >= m.focusState.buttons.Count() then
        m.focusState.focusedIndex = m.focusState.buttons.Count() - 1
    end if

    if m.focusState.focusedIndex < 0 then m.focusState.focusedIndex = 0
    layoutButtons()
end sub

'-------------------------------------------------------------------------------
' onResumeButtonSelected
'-------------------------------------------------------------------------------
sub onResumeButtonSelected()
    m.top.playSelected = true
end sub

'-------------------------------------------------------------------------------
' onRestartButtonSelected
'-------------------------------------------------------------------------------
sub onRestartButtonSelected()
    m.top.restartSelected = true
end sub

'-------------------------------------------------------------------------------
' onPlayButtonSelected
'-------------------------------------------------------------------------------
sub onPlayButtonSelected()
    m.top.playSelected = true
end sub

'-------------------------------------------------------------------------------
' onMarkWatchedButtonSelected
'-------------------------------------------------------------------------------
sub onMarkWatchedButtonSelected()
    m.top.markAsWatchedSelected = true
end sub

'-------------------------------------------------------------------------------
' onMarkUnwatchedButtonSelected
'-------------------------------------------------------------------------------
sub onMarkUnwatchedButtonSelected()
    m.top.markAsUnwatchedSelected = true
end sub

'-------------------------------------------------------------------------------
' onSeriesButtonSelected
'-------------------------------------------------------------------------------
sub onSeriesButtonSelected()
    m.top.seriesSelected = true
end sub

'-------------------------------------------------------------------------------
' onSubtitlesButtonSelected
'-------------------------------------------------------------------------------
sub onSubtitlesButtonSelected()
    m.top.subtitlesSelected = true
end sub

'-------------------------------------------------------------------------------
' onAudioButtonSelected
'-------------------------------------------------------------------------------
sub onAudioButtonSelected()
    m.top.audioSelected = true
end sub

'-------------------------------------------------------------------------------
' onChaptersButtonSelected
'-------------------------------------------------------------------------------
sub onChaptersButtonSelected()
    m.top.chaptersSelected = true
end sub

'-------------------------------------------------------------------------------
' onVideoButtonSelected
'-------------------------------------------------------------------------------
sub onVideoButtonSelected()
    m.top.videoSelected = true
end sub

'-------------------------------------------------------------------------------
' onMediaInfoButtonSelected
'-------------------------------------------------------------------------------
sub onMediaInfoButtonSelected()
    m.top.mediaInfoSelected = true
end sub

'-------------------------------------------------------------------------------
' onSeasonButtonSelected
'-------------------------------------------------------------------------------
sub onSeasonButtonSelected()
    m.top.seasonSelected = true
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "down" then
        m.top.focusExitDown = true
        return true
    end if

    if key = "left" then
        focusButton(m.focusState.focusedIndex - 1)
        return true
    end if

    if key = "right" then
        focusButton(m.focusState.focusedIndex + 1)
        return true
    end if

    return false
end function

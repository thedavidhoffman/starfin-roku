'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.toolbarItems = m.top.findNode("toolbarItems")
    m.playButton = m.top.findNode("playButton")
    m.markWatchedButton = m.top.findNode("markWatchedButton")
    m.markUnwatchedButton = m.top.findNode("markUnwatchedButton")
    m.playButton.observeField("buttonSelected", "onPlayButtonSelected")
    m.toolbarLayout = {
        collapsedWidth: 64
        defaultExpandedWidth: 168
        buttonSpacing: 12
    }
    m.focusState = {
        focusedIndex: 0
        buttons: [m.playButton, m.markWatchedButton, m.markUnwatchedButton]
    }
    layoutButtons()
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusButton(m.focusState.focusedIndex)
end sub

'-------------------------------------------------------------------------------
' focusButton
'-------------------------------------------------------------------------------
sub focusButton(index as integer)
    if index < 0 then index = 0
    if index >= m.focusState.buttons.Count() then index = m.focusState.buttons.Count() - 1

    m.focusState.focusedIndex = index
    layoutButtons()
    m.focusState.buttons[index].setFocus(true)
end sub

'-------------------------------------------------------------------------------
' layoutButtons
'-------------------------------------------------------------------------------
sub layoutButtons()
    x = 0
    for i = 0 to m.focusState.buttons.Count() - 1
        button = m.focusState.buttons[i]
        button.translation = [x, 0]

        if i = m.focusState.focusedIndex then
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
' onPlayButtonSelected
'-------------------------------------------------------------------------------
sub onPlayButtonSelected()
    m.top.playSelected = true
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

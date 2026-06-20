'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.iconPoster = m.top.findNode("iconPoster")
    m.textLabel = m.top.findNode("textLabel")
    m.layout = {
        collapsedWidth: 64
        expandedWidth: 168
        height: 58
        iconSize: 32
        iconX: 16
        iconY: 13
        textX: 60
        textY: 13
    }
    m.top.observeField("focusedChild", "onFocusChanged")
    onTextChanged()
    onIconChanged()
    onFocusVisualChanged()
end sub

'-------------------------------------------------------------------------------
' onTextChanged
'-------------------------------------------------------------------------------
sub onTextChanged()
    m.textLabel.text = SafeString(m.top.text, "")
end sub

'-------------------------------------------------------------------------------
' onIconChanged
'-------------------------------------------------------------------------------
sub onIconChanged()
    if m.top.hasFocusVisual = true and SafeString(m.top.focusedIcon, "") <> "" then
        m.iconPoster.uri = m.top.focusedIcon
    else
        m.iconPoster.uri = m.top.icon
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    m.top.hasFocusVisual = m.top.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' onFocusVisualChanged
'-------------------------------------------------------------------------------
sub onFocusVisualChanged()
    hasFocus = m.top.hasFocusVisual = true
    if hasFocus then
        m.background.uri = "pkg:/images/buttons/media-toolbar-button-focused.9.png"
        m.background.width = m.layout.expandedWidth
        m.textLabel.visible = true
    else
        m.background.uri = "pkg:/images/buttons/media-toolbar-button-unfocused.9.png"
        m.background.width = m.layout.collapsedWidth
        m.textLabel.visible = false
    end if

    m.background.height = m.layout.height
    m.iconPoster.width = m.layout.iconSize
    m.iconPoster.height = m.layout.iconSize
    m.iconPoster.translation = [m.layout.iconX, m.layout.iconY]
    m.textLabel.translation = [m.layout.textX, m.layout.textY]
    m.textLabel.width = m.layout.expandedWidth - m.layout.textX - 16
    m.textLabel.color = &h000B25FF
    onIconChanged()
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "OK" or key = "select" then
        m.top.buttonSelected = true
        return true
    end if

    return false
end function

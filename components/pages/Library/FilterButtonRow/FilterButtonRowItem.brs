'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.bg = m.top.findNode("bg")
    m.textLabel = m.top.findNode("textLabel")
    onItemContentChanged()
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.textLabel.text = SafeString(item.title, "")
    onFocusStateChanged()
end sub

'-------------------------------------------------------------------------------
' onFocusStateChanged
'-------------------------------------------------------------------------------
sub onFocusStateChanged()
    item = m.top.itemContent
    selected = item <> invalid and item.selected = true
    focused = m.top.itemHasFocus = true or m.top.focusPercent > 0.5

    m.bg.visible = selected or focused
    if selected or focused then
        m.textLabel.color = &h12112BFF
    else
        m.textLabel.color = &hFFFFFFFF
    end if
end sub

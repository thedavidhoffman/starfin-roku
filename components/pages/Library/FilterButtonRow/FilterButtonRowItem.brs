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
    m.bg.visible = false
    m.textLabel.color = &hFFFFFFFF
end sub

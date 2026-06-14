'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.label = m.top.findNode("label")
    onTextChanged()
end sub

'-------------------------------------------------------------------------------
' onTextChanged
'-------------------------------------------------------------------------------
sub onTextChanged()
    if m.label = invalid then return

    text = SafeString(m.top.text, "")
    m.label.text = text
    m.top.visible = (text <> "")
end sub

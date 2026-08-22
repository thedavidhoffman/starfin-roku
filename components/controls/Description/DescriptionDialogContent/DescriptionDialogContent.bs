'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.descriptionText = m.top.findNode("descriptionText")
    onTextChanged()
end sub

'-------------------------------------------------------------------------------
' focusFirstField
'-------------------------------------------------------------------------------
sub focusFirstField()
    focusDescriptionText()
end sub

'-------------------------------------------------------------------------------
' focusLastField
'-------------------------------------------------------------------------------
sub focusLastField()
    focusDescriptionText()
end sub

'-------------------------------------------------------------------------------
' focusDescriptionText
'-------------------------------------------------------------------------------
sub focusDescriptionText()
    if m.descriptionText <> invalid then m.descriptionText.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onTextChanged
'-------------------------------------------------------------------------------
sub onTextChanged()
    if m.descriptionText <> invalid then m.descriptionText.text = m.top.text
end sub

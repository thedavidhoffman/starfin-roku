'-------------------------------------------------------------------------------
' openGrid
'-------------------------------------------------------------------------------
sub openGrid()
    m.top.visible = true
    configureDialog()
    syncContent()
    m.top.callFunc("openDialog")
    focusLetters()
end sub

'-------------------------------------------------------------------------------
' closeGrid
'-------------------------------------------------------------------------------
sub closeGrid()
    dialog = m.top.findNode("dialog")
    if dialog <> invalid then dialog.visible = false
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' focusLetters
'-------------------------------------------------------------------------------
sub focusLetters()
    content = getLetterGridContent()
    if content <> invalid then content.callFunc("focusLetters")
end sub

'-------------------------------------------------------------------------------
' configureDialog
'-------------------------------------------------------------------------------
sub configureDialog()
    m.top.title = "Jump To..."
    m.top.dialogWidth = 540
    m.top.dialogHeight = 562
    if m.top.panelX = invalid or m.top.panelX < 0 then m.top.panelX = 72
    if m.top.panelY = invalid or m.top.panelY < 0 then m.top.panelY = 208
    m.top.contentComponentName = "LetterGridContent"
end sub

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getLetterGridContent()
    if content = invalid then return

    content.availableLetters = m.top.availableLetters
    if m.letterContent <> content then
        if m.letterContent <> invalid then m.letterContent.unobserveField("letterSelected")
        m.letterContent = content
        m.letterContent.observeField("letterSelected", "onContentLetterSelected")
    end if
end sub

'-------------------------------------------------------------------------------
' getLetterGridContent
'-------------------------------------------------------------------------------
function getLetterGridContent() as dynamic
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' onAvailableLettersChanged
'-------------------------------------------------------------------------------
sub onAvailableLettersChanged()
    content = getLetterGridContent()
    if content <> invalid then content.availableLetters = m.top.availableLetters
end sub

'-------------------------------------------------------------------------------
' onContentLetterSelected
'-------------------------------------------------------------------------------
sub onContentLetterSelected()
    if m.letterContent = invalid then return

    letter = m.letterContent.letterSelected
    if letter = invalid or letter = "" then return

    m.top.selectedLetter = letter
    m.top.letterSelected = letter
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.lettersGroup = m.top.findNode("lettersGroup")
    m.letterItems = []
    m.focusState = {
        focusedIndex: 0
        columnCount: 6
        itemSize: 64
        itemSpacing: 12
        letterCount: 26
    }
    renderLetters()
end sub

'-------------------------------------------------------------------------------
' renderLetters
'-------------------------------------------------------------------------------
sub renderLetters()
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    for i = 1 to Len(letters)
        letter = Mid(letters, i, 1)
        item = m.lettersGroup.createChild("LetterGridItem")
        item.translation = getItemTranslation(i - 1)
        itemContent = CreateObject("roSGNode", "ContentNode")
        itemContent.title = letter
        item.itemContent = itemContent
        item.isAvailable = true
        item.itemHasFocus = i = 1
        m.letterItems.Push(item)
    end for

    applyAvailableLetters()
end sub

'-------------------------------------------------------------------------------
' onAvailableLettersChanged
'-------------------------------------------------------------------------------
sub onAvailableLettersChanged()
    applyAvailableLetters()
end sub

'-------------------------------------------------------------------------------
' applyAvailableLetters
'-------------------------------------------------------------------------------
sub applyAvailableLetters()
    availableLetters = m.top.availableLetters
    if availableLetters = invalid then return

    for each item in m.letterItems
        if item = invalid or item.itemContent = invalid then continue for

        letter = SafeString(item.itemContent.title, "")
        item.isAvailable = availableLetters.DoesExist(letter) and availableLetters[letter] = true
    end for

    ensureFocusedLetterAvailable()
    updateLetterFocus()
end sub

'-------------------------------------------------------------------------------
' getItemTranslation
'-------------------------------------------------------------------------------
function getItemTranslation(index as integer) as object
    column = index mod m.focusState.columnCount
    row = Fix(index / m.focusState.columnCount)
    stride = m.focusState.itemSize + m.focusState.itemSpacing

    return [column * stride, row * stride]
end function

'-------------------------------------------------------------------------------
' focusLetters
'-------------------------------------------------------------------------------
sub focusLetters()
    m.top.setFocus(true)
    ensureFocusedLetterAvailable()
    updateLetterFocus()
end sub

'-------------------------------------------------------------------------------
' updateLetterFocus
'-------------------------------------------------------------------------------
sub updateLetterFocus()
    for i = 0 to m.letterItems.Count() - 1
        m.letterItems[i].itemHasFocus = i = m.focusState.focusedIndex
    end for
end sub

'-------------------------------------------------------------------------------
' moveFocus
'-------------------------------------------------------------------------------
function moveFocus(offset as integer) as boolean
    nextIndex = findAvailableIndexByOffset(m.focusState.focusedIndex, offset)
    if nextIndex < 0 then return true

    if nextIndex = m.focusState.focusedIndex then return true

    m.focusState.focusedIndex = nextIndex
    updateLetterFocus()
    return true
end function

'-------------------------------------------------------------------------------
' ensureFocusedLetterAvailable
'-------------------------------------------------------------------------------
sub ensureFocusedLetterAvailable()
    if isLetterIndexAvailable(m.focusState.focusedIndex) then return

    firstAvailableIndex = findFirstAvailableIndex()
    if firstAvailableIndex >= 0 then
        m.focusState.focusedIndex = firstAvailableIndex
    else
        m.focusState.focusedIndex = 0
    end if
end sub

'-------------------------------------------------------------------------------
' findFirstAvailableIndex
'-------------------------------------------------------------------------------
function findFirstAvailableIndex() as integer
    for i = 0 to m.letterItems.Count() - 1
        if isLetterIndexAvailable(i) then return i
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' findAvailableIndexByOffset
'-------------------------------------------------------------------------------
function findAvailableIndexByOffset(startIndex as integer, offset as integer) as integer
    if offset = 0 then return -1

    index = startIndex + offset
    while index >= 0 and index < m.focusState.letterCount
        if isLetterIndexAvailable(index) then return index
        index = index + offset
    end while

    return -1
end function

'-------------------------------------------------------------------------------
' isLetterIndexAvailable
'-------------------------------------------------------------------------------
function isLetterIndexAvailable(index as integer) as boolean
    if index < 0 or index >= m.letterItems.Count() then return false

    item = m.letterItems[index]
    return item <> invalid and item.isAvailable = true
end function

'-------------------------------------------------------------------------------
' selectFocusedLetter
'-------------------------------------------------------------------------------
function selectFocusedLetter() as boolean
    if m.focusState.focusedIndex < 0 or m.focusState.focusedIndex >= m.letterItems.Count() then return false

    item = m.letterItems[m.focusState.focusedIndex]
    if item = invalid or item.itemContent = invalid then return false

    letter = SafeString(item.itemContent.title, "")
    if letter = "" then return false
    if item.isAvailable <> true then return true

    m.top.selectedLetter = letter
    m.top.letterSelected = letter
    return true
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    normalizedKey = LCase(SafeString(key, ""))

    if normalizedKey = "back" then
        m.top.closeRequested = true
        return true
    end if

    if normalizedKey = "right" then
        return moveFocus(1)
    end if

    if normalizedKey = "left" then return moveFocus(-1)
    if normalizedKey = "down" then return moveFocus(m.focusState.columnCount)
    if normalizedKey = "up" then return moveFocus(0 - m.focusState.columnCount)
    if normalizedKey = "ok" or normalizedKey = "select" then return selectFocusedLetter()

    return false
end function

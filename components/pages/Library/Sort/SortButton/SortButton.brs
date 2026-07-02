'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.sortButton = m.top.findNode("sortButton")
    m.sortLabel = m.top.findNode("sortLabel")
    m.sortOrderIcon = m.top.findNode("sortOrderIcon")
    m.layout = {
        buttonWidth: 260
        iconSize: 32
        iconGap: 8
    }
    m.top.observeField("focusedChild", "onFocusChanged")
    updateSortDisplay()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' updateFocusVisual
'-------------------------------------------------------------------------------
sub updateFocusVisual()
    m.sortButton.hasFocusVisual = m.top.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' onSelectedSortChanged
'-------------------------------------------------------------------------------
sub onSelectedSortChanged()
    updateSortDisplay()
end sub

'-------------------------------------------------------------------------------
' updateSortDisplay
'-------------------------------------------------------------------------------
sub updateSortDisplay()
    selection = getSelectedSort()
    displayText = getSortDisplayText(selection)
    m.sortLabel.text = displayText
    m.sortOrderIcon.uri = getSortOrderIconUri(selection)
    applyContentLayout(displayText)
end sub

'-------------------------------------------------------------------------------
' getSelectedSort
'-------------------------------------------------------------------------------
function getSelectedSort() as object
    if m.top.selectedSort <> invalid then return m.top.selectedSort

    return {
        optionKey: "SortName:Ascending"
        sortKey: "SortName"
        sortOrder: "Ascending"
        label: "Title (A-Z)"
    }
end function

'-------------------------------------------------------------------------------
' getSortDisplayText
'-------------------------------------------------------------------------------
function getSortDisplayText(selection as object) as string
    sortKey = SafeString(selection.sortKey, "SortName")
    if sortKey = "PremiereDate" then return "Release Date"
    if sortKey = "DateCreated" then return "Date Added"

    return "Title"
end function

'-------------------------------------------------------------------------------
' getSortOrderIconUri
'-------------------------------------------------------------------------------
function getSortOrderIconUri(selection as object) as string
    if LCase(SafeString(selection.sortOrder, "Ascending")) = "descending" then
        return "pkg:/images/icons/sort/sort-arrow-up.png"
    end if

    return "pkg:/images/icons/sort/sort-arrow-down.png"
end function

'-------------------------------------------------------------------------------
' applyContentLayout
'-------------------------------------------------------------------------------
sub applyContentLayout(displayText as string)
    textWidth = getDisplayTextWidth(displayText)
    contentWidth = textWidth + m.layout.iconGap + m.layout.iconSize
    contentX = int((m.layout.buttonWidth - contentWidth) / 2)
    if contentX < 0 then contentX = 0

    m.sortLabel.translation = [contentX, 14]
    m.sortLabel.width = textWidth
    m.sortOrderIcon.translation = [contentX + textWidth + m.layout.iconGap, 12]
end sub

'-------------------------------------------------------------------------------
' getDisplayTextWidth
'-------------------------------------------------------------------------------
function getDisplayTextWidth(displayText as string) as integer
    if displayText = "Release Date" then return 138
    if displayText = "Date Added" then return 120

    return 48
end function

'-------------------------------------------------------------------------------
' openSortDialog
'-------------------------------------------------------------------------------
sub openSortDialog()
    m.top.overlayRequested = {
        id: "sort"
        componentName: "SortDialog"
        openFunction: "openSort"
        closeField: "closeRequested"
    }
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    normalizedKey = LCase(key)
    if normalizedKey = "ok" or normalizedKey = "select" then
        openSortDialog()
        return true
    end if

    if normalizedKey = "down" or normalizedKey = "back" then
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

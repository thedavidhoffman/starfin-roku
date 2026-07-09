'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.sortLabel = m.top.findNode("sortLabel")
    m.sortOrderIcon = m.top.findNode("sortOrderIcon")
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
    hasFocus = m.top.isInFocusChain()

    if hasFocus then
        m.background.uri = "pkg:/images/buttons/primary_focused.9.png"
    else
        m.background.uri = "pkg:/images/buttons/primary_unfocused.9.png"
    end if

    m.sortLabel.color = &h0F1A2AFF
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
    m.sortLabel.text = getSortDisplayText(selection)
    m.sortOrderIcon.uri = getSortOrderIconUri(selection)
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
    if sortKey = "PremiereDate" then return "Release"
    if sortKey = "DateCreated" then return "Added"

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

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.background = m.top.findNode("background")
    m.sortOrderIcon = m.top.findNode("sortOrderIcon")
    m.top.observeField("focusedChild", "onFocusChanged")
    updateFocusability()
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
    if isSortEnabled() <> true then
        m.background.uri = "pkg:/images/buttons/primary_unfocused.9.png"
        m.sortOrderIcon.opacity = 0.45
        return
    end if

    m.sortOrderIcon.opacity = 1.0
    if m.top.isInFocusChain() then
        m.background.uri = "pkg:/images/buttons/primary_focused.9.png"
    else
        m.background.uri = "pkg:/images/buttons/primary_unfocused.9.png"
    end if
end sub

'-------------------------------------------------------------------------------
' onSelectedSortChanged
'-------------------------------------------------------------------------------
sub onSelectedSortChanged()
    updateSortDisplay()
    updateFocusability()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' onSortEnabledChanged
'-------------------------------------------------------------------------------
sub onSortEnabledChanged()
    updateFocusability()
    updateSortDisplay()
    updateFocusVisual()
end sub

'-------------------------------------------------------------------------------
' updateSortDisplay
'-------------------------------------------------------------------------------
sub updateSortDisplay()
    if isSortEnabled() = true and isDescending() then
        m.sortOrderIcon.uri = "pkg:/images/icons/sort/sort-arrow-up.png"
    else
        m.sortOrderIcon.uri = "pkg:/images/icons/sort/sort-arrow-down.png"
    end if
end sub

'-------------------------------------------------------------------------------
' updateFocusability
'-------------------------------------------------------------------------------
sub updateFocusability()
    m.top.focusable = isSortEnabled()
end sub

'-------------------------------------------------------------------------------
' isSortEnabled
'-------------------------------------------------------------------------------
function isSortEnabled() as boolean
    return m.top.sortEnabled = true
end function

'-------------------------------------------------------------------------------
' isDescending
'-------------------------------------------------------------------------------
function isDescending() as boolean
    selection = getSelectedSort()
    return SafeString(selection.sortOrder, "Ascending") = "Descending"
end function

'-------------------------------------------------------------------------------
' getSelectedSort
'-------------------------------------------------------------------------------
function getSelectedSort() as object
    if m.top.selectedSort <> invalid then return m.top.selectedSort

    return {
        optionKey: "SortName"
        sortKey: "SortName"
        sortOrder: "Ascending"
        label: "Title"
    }
end function

'-------------------------------------------------------------------------------
' toggleSortOrder
'-------------------------------------------------------------------------------
sub toggleSortOrder()
    if isSortEnabled() <> true then return

    selection = getSelectedSort()
    sortOrder = "Descending"
    if SafeString(selection.sortOrder, "Ascending") = "Descending" then sortOrder = "Ascending"

    m.top.sortOrderChanged = {
        optionKey: SafeString(selection.optionKey, SafeString(selection.sortKey, "SortName"))
        sortKey: SafeString(selection.sortKey, "SortName")
        sortOrder: sortOrder
        label: SafeString(selection.label, "Title")
    }
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    normalizedKey = LCase(key)
    if isSortEnabled() <> true then return false

    if normalizedKey = "ok" or normalizedKey = "select" then
        toggleSortOrder()
        return true
    end if

    if normalizedKey = "down" or normalizedKey = "back" then
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

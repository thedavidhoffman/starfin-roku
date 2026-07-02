'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.sortList = m.top.findNode("sortList")
    m.sortList.observeField("itemSelected", "onSortListItemSelected")
    m.sortList.observeField("checkedItem", "onSortListCheckedItemChanged")
    m.state = {
        isUpdatingCheckedItem: false
        options: []
    }
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' onSelectedSortKeyChanged
'-------------------------------------------------------------------------------
sub onSelectedSortKeyChanged()
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' renderOptions
'-------------------------------------------------------------------------------
sub renderOptions()
    m.state.options = getSortOptions()
    content = CreateObject("roSGNode", "ContentNode")

    for each option in m.state.options
        child = content.createChild("ContentNode")
        child.title = option.label
        child.AddFields({
            optionKey: option.optionKey
            sortKey: option.sortKey
            sortOrder: option.sortOrder
        })
    end for

    m.sortList.content = content
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' getSortOptions
'-------------------------------------------------------------------------------
function getSortOptions() as object
    return [
        { optionKey: "SortName:Ascending", sortKey: "SortName", sortOrder: "Ascending", label: "Title (A-Z)" }
        { optionKey: "SortName:Descending", sortKey: "SortName", sortOrder: "Descending", label: "Title (Z-A)" }
        { optionKey: "PremiereDate:Ascending", sortKey: "PremiereDate", sortOrder: "Ascending", label: "Release Date (oldest to newest)" }
        { optionKey: "PremiereDate:Descending", sortKey: "PremiereDate", sortOrder: "Descending", label: "Release Date (newest to oldest)" }
        { optionKey: "DateCreated:Ascending", sortKey: "DateCreated", sortOrder: "Ascending", label: "Date Added (oldest to newest)" }
        { optionKey: "DateCreated:Descending", sortKey: "DateCreated", sortOrder: "Descending", label: "Date Added (newest to oldest)" }
    ]
end function

'-------------------------------------------------------------------------------
' updateCheckedItem
'-------------------------------------------------------------------------------
sub updateCheckedItem()
    m.state.isUpdatingCheckedItem = true
    m.sortList.checkedItem = getCheckedItemIndex()
    m.state.isUpdatingCheckedItem = false
end sub

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex() as integer
    selectedSortKey = SafeString(m.top.selectedSortKey, "SortName:Ascending")

    for i = 0 to m.state.options.Count() - 1
        if SafeString(m.state.options[i].optionKey, "") = selectedSortKey then return i
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' onSortListItemSelected
'-------------------------------------------------------------------------------
sub onSortListItemSelected()
    selectSortListIndex(m.sortList.itemSelected)
end sub

'-------------------------------------------------------------------------------
' onSortListCheckedItemChanged
'-------------------------------------------------------------------------------
sub onSortListCheckedItemChanged()
    if m.state.isUpdatingCheckedItem = true then return

    selectSortListIndex(m.sortList.checkedItem)
end sub

'-------------------------------------------------------------------------------
' selectSortListIndex
'-------------------------------------------------------------------------------
sub selectSortListIndex(selectedIndex as dynamic)
    if selectedIndex = invalid then return
    if selectedIndex < 0 or selectedIndex >= m.state.options.Count() then return

    option = m.state.options[selectedIndex]
    m.sortList.checkedItem = selectedIndex
    m.top.selectedSortKey = option.optionKey
    m.top.sortSelected = {
        optionKey: option.optionKey
        sortKey: option.sortKey
        sortOrder: option.sortOrder
        label: option.label
    }
end sub

'-------------------------------------------------------------------------------
' focusOptions
'-------------------------------------------------------------------------------
sub focusOptions()
    m.top.setFocus(true)
    m.sortList.setFocus(true)
end sub

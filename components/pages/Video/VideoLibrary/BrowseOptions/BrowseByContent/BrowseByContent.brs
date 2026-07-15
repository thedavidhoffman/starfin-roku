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
' onSortOptionsChanged
'-------------------------------------------------------------------------------
sub onSortOptionsChanged()
    renderOptions()
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
            label: option.label
        })
    end for

    m.sortList.content = content
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' getSortOptions
'-------------------------------------------------------------------------------
function getSortOptions() as object
    if m.top.sortOptions <> invalid and m.top.sortOptions.Count() > 0 then return m.top.sortOptions

    return [
        { optionKey: "SortName", sortKey: "SortName", sortOrder: "", label: "Title" }
        { optionKey: "PremiereDate", sortKey: "PremiereDate", sortOrder: "", label: "Release Date" }
        { optionKey: "DateCreated", sortKey: "DateCreated", sortOrder: "", label: "Date Added" }
        { optionKey: "Decade", sortKey: "", sortOrder: "", label: "Decade" }
        { optionKey: "Genre", sortKey: "", sortOrder: "", label: "Genre" }
        { optionKey: "Random", sortKey: "Random", sortOrder: "", label: "Random" }
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
    selectedSortKey = SafeString(m.top.selectedSortKey, "SortName")

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

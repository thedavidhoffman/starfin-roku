'-------------------------------------------------------------------------------
' openSort
'-------------------------------------------------------------------------------
sub openSort()
    configureDialog()
    syncContent()
    m.top.callFunc("openDialog")
    focusOptions()
end sub

'-------------------------------------------------------------------------------
' configureDialog
'-------------------------------------------------------------------------------
sub configureDialog()
    m.top.title = "Sort By"
    m.top.dialogWidth = 720
    m.top.dialogHeight = 495
    m.top.contentComponentName = "SortContent"
end sub

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getSortContent()
    if content = invalid then return

    content.selectedSortKey = m.top.selectedSortKey
    if m.sortContent <> content then
        if m.sortContent <> invalid then m.sortContent.unobserveField("sortSelected")
        m.sortContent = content
        m.sortContent.observeField("sortSelected", "onContentSortSelected")
    end if
end sub

'-------------------------------------------------------------------------------
' getSortContent
'-------------------------------------------------------------------------------
function getSortContent() as dynamic
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' focusOptions
'-------------------------------------------------------------------------------
sub focusOptions()
    content = getSortContent()
    if content <> invalid then content.callFunc("focusOptions")
end sub

'-------------------------------------------------------------------------------
' onSelectedSortKeyChanged
'-------------------------------------------------------------------------------
sub onSelectedSortKeyChanged()
    content = getSortContent()
    if content <> invalid then content.selectedSortKey = m.top.selectedSortKey
end sub

'-------------------------------------------------------------------------------
' onContentSortSelected
'-------------------------------------------------------------------------------
sub onContentSortSelected()
    if m.sortContent = invalid then return

    selection = m.sortContent.sortSelected
    if selection = invalid then return

    m.top.selectedSortKey = SafeString(selection.optionKey, m.top.selectedSortKey)
    m.top.sortSelected = selection
end sub

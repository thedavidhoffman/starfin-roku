'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.optionList = m.top.findNode("optionList")
    m.optionList.observeField("itemSelected", "onOptionListItemSelected")
    m.optionList.observeField("checkedItem", "onOptionListCheckedItemChanged")
    m.state = {
        isUpdatingCheckedItem: false
        pendingSelection: invalid
    }
    m.config = getDefaultConfig()
    initStyle()
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    colors = Color()
    m.emptyLabel.color = colors.text.light.secondary
end sub

'-------------------------------------------------------------------------------
' onOptionsChanged
'-------------------------------------------------------------------------------
sub onOptionsChanged()
    m.config.options = getFieldOptions()
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' onSelectedKeyChanged
'-------------------------------------------------------------------------------
sub onSelectedKeyChanged()
    m.config.selectedKey = SafeString(m.top.selectedKey, "")
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' onAllowDefaultSelectionChanged
'-------------------------------------------------------------------------------
sub onAllowDefaultSelectionChanged()
    m.config.allowDefaultSelection = m.top.allowDefaultSelection
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' onEmptyTextChanged
'-------------------------------------------------------------------------------
sub onEmptyTextChanged()
    m.config.emptyText = SafeString(m.top.emptyText, "")
    m.emptyLabel.text = getEmptyText()
end sub

'-------------------------------------------------------------------------------
' onVisibleRowCountChanged
'-------------------------------------------------------------------------------
sub onVisibleRowCountChanged()
    m.config.visibleRowCount = getVisibleRowCountValue(m.top.visibleRowCount)
    applyVisibleRowCount()
end sub

'-------------------------------------------------------------------------------
' configureOptions
'-------------------------------------------------------------------------------
sub configureOptions(config as object)
    m.config = normalizeConfig(config)
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' getDefaultConfig
'-------------------------------------------------------------------------------
function getDefaultConfig() as object
    return {
        options: []
        selectedKey: ""
        allowDefaultSelection: true
        emptyText: ""
        visibleRowCount: 1
    }
end function

'-------------------------------------------------------------------------------
' normalizeConfig
'-------------------------------------------------------------------------------
function normalizeConfig(config as dynamic) as object
    normalized = getDefaultConfig()
    if config = invalid then return normalized

    normalized.options = getConfigArray(config.options)
    normalized.selectedKey = SafeString(config.selectedKey, "")
    if config.allowDefaultSelection <> invalid then normalized.allowDefaultSelection = config.allowDefaultSelection
    normalized.emptyText = SafeString(config.emptyText, "")
    normalized.visibleRowCount = getVisibleRowCountValue(config.visibleRowCount)

    return normalized
end function

'-------------------------------------------------------------------------------
' getConfigArray
'-------------------------------------------------------------------------------
function getConfigArray(value as dynamic) as object
    if value = invalid then return []
    return value
end function

'-------------------------------------------------------------------------------
' getFieldOptions
'-------------------------------------------------------------------------------
function getFieldOptions() as object
    if m.top.options = invalid then return []
    return m.top.options
end function

'-------------------------------------------------------------------------------
' getVisibleRowCountValue
'-------------------------------------------------------------------------------
function getVisibleRowCountValue(value as dynamic) as integer
    rows = value
    if rows = invalid or rows <= 0 then rows = 1
    return rows
end function

'-------------------------------------------------------------------------------
' applyVisibleRowCount
'-------------------------------------------------------------------------------
sub applyVisibleRowCount()
    m.optionList.numRows = m.config.visibleRowCount
end sub

'-------------------------------------------------------------------------------
' renderOptions
'-------------------------------------------------------------------------------
sub renderOptions()
    content = CreateObject("roSGNode", "ContentNode")
    if hasOptions() then
        for each option in m.config.options
            addOption(content, getOptionLabel(option))
        end for
    end if

    m.optionList.content = content
    updateCheckedItem()
    m.optionList.visible = hasOptions()
    m.emptyLabel.text = getEmptyText()
    m.emptyLabel.visible = hasOptions() <> true
    applyVisibleRowCount()
    m.state.pendingSelection = getSelectionForCheckedItem()
end sub

'-------------------------------------------------------------------------------
' addOption
'-------------------------------------------------------------------------------
sub addOption(content as object, title as string)
    option = content.createChild("ContentNode")
    option.title = title
end sub

'-------------------------------------------------------------------------------
' hasOptions
'-------------------------------------------------------------------------------
function hasOptions() as boolean
    return m.config <> invalid and m.config.options <> invalid and m.config.options.Count() > 0
end function

'-------------------------------------------------------------------------------
' getOptionLabel
'-------------------------------------------------------------------------------
function getOptionLabel(option as dynamic) as string
    if option = invalid then return ""
    return SafeString(option.label, "")
end function

'-------------------------------------------------------------------------------
' getOptionKey
'-------------------------------------------------------------------------------
function getOptionKey(option as dynamic, fallback as integer) as string
    if option <> invalid and option.key <> invalid then return SafeString(option.key, "")
    return fallback.ToStr()
end function

'-------------------------------------------------------------------------------
' getEmptyText
'-------------------------------------------------------------------------------
function getEmptyText() as string
    text = SafeString(m.config.emptyText, "")
    if text <> "" then return text
    return "No options available."
end function

'-------------------------------------------------------------------------------
' updateCheckedItem
'-------------------------------------------------------------------------------
sub updateCheckedItem()
    m.state.isUpdatingCheckedItem = true
    checkedIndex = getCheckedItemIndex()
    m.optionList.checkedItem = checkedIndex
    scrollToCheckedItem(checkedIndex)
    m.state.isUpdatingCheckedItem = false
    m.state.pendingSelection = getSelectionForCheckedItem()
end sub

'-------------------------------------------------------------------------------
' scrollToCheckedItem
'-------------------------------------------------------------------------------
sub scrollToCheckedItem(checkedIndex as integer)
    if checkedIndex < 0 then return

    m.optionList.jumpToItem = checkedIndex
    m.optionList.itemFocused = checkedIndex
end sub

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex() as integer
    if hasOptions() <> true then return -1

    selectedKey = SafeString(m.config.selectedKey, "")
    if selectedKey <> "" then
        for i = 0 to m.config.options.Count() - 1
            if getOptionKey(m.config.options[i], i) = selectedKey then return i
        end for
    end if

    if m.config.allowDefaultSelection <> true then return -1

    return 0
end function

'-------------------------------------------------------------------------------
' onOptionListItemSelected
'-------------------------------------------------------------------------------
sub onOptionListItemSelected()
    selectOptionListIndex(m.optionList.itemSelected)
end sub

'-------------------------------------------------------------------------------
' onOptionListCheckedItemChanged
'-------------------------------------------------------------------------------
sub onOptionListCheckedItemChanged()
    if m.state.isUpdatingCheckedItem = true then return

    selectOptionListIndex(m.optionList.checkedItem)
end sub

'-------------------------------------------------------------------------------
' selectOptionListIndex
'-------------------------------------------------------------------------------
sub selectOptionListIndex(selectedIndex as dynamic)
    if selectedIndex = invalid then return
    if hasOptions() <> true or selectedIndex < 0 or selectedIndex >= m.config.options.Count() then return

    m.optionList.checkedItem = selectedIndex
    m.state.pendingSelection = m.config.options[selectedIndex]
end sub

'-------------------------------------------------------------------------------
' getSelectedOption
'-------------------------------------------------------------------------------
function getSelectedOption() as dynamic
    if m.state.pendingSelection = invalid then m.state.pendingSelection = getSelectionForCheckedItem()
    return m.state.pendingSelection
end function

'-------------------------------------------------------------------------------
' getSelectionForCheckedItem
'-------------------------------------------------------------------------------
function getSelectionForCheckedItem() as dynamic
    selectedIndex = getCheckedItemIndex()
    if hasOptions() <> true or selectedIndex < 0 or selectedIndex >= m.config.options.Count() then return invalid

    return m.config.options[selectedIndex]
end function

'-------------------------------------------------------------------------------
' focusOptions
'-------------------------------------------------------------------------------
sub focusOptions()
    m.top.setFocus(true)
    if hasOptions() then
        scrollToCheckedItem(getCheckedItemIndex())
        m.optionList.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' openOptions
'-------------------------------------------------------------------------------
sub openOptions()
    m.top.selectedOptionChanged = false
    configureDialog()
    syncContent()
    observeContentSelection()
    m.top.visible = true
    m.top.callFunc("openDialog")
    focusContent()
end sub

'-------------------------------------------------------------------------------
' configureDialog
'-------------------------------------------------------------------------------
sub configureDialog()
    rows = getVisibleRowCount()
    panelHeight = 208 + (rows * 52)
    panelY = int((1080 - panelHeight) / 2)

    m.top.title = getDialogTitle()
    m.top.dialogWidth = 720
    m.top.dialogHeight = panelHeight
    m.top.panelX = 600
    m.top.panelY = panelY
    m.top.contentComponentName = "OptionPickerContent"
end sub

'-------------------------------------------------------------------------------
' observeContentSelection
'-------------------------------------------------------------------------------
sub observeContentSelection()
    content = getOptionsContent()
    if content = invalid then return

    content.unobserveField("optionSelected")
    content.observeField("optionSelected", "onContentOptionSelected")
end sub

'-------------------------------------------------------------------------------
' onContentOptionSelected
'-------------------------------------------------------------------------------
sub onContentOptionSelected()
    if m.top.closeOnSelect <> true then return
    m.top.callFunc("closeDialog")
end sub

'-------------------------------------------------------------------------------
' getDialogTitle
'-------------------------------------------------------------------------------
function getDialogTitle() as string
    title = SafeString(m.top.dialogTitle, "")
    if title <> "" then return title
    return "Options"
end function

'-------------------------------------------------------------------------------
' getVisibleRowCount
'-------------------------------------------------------------------------------
function getVisibleRowCount() as integer
    rows = 1
    if hasOptions() then rows = m.top.options.Count()
    if rows > 8 then rows = 8

    return rows
end function

'-------------------------------------------------------------------------------
' hasOptions
'-------------------------------------------------------------------------------
function hasOptions() as boolean
    return m.top.options <> invalid and m.top.options.Count() > 0
end function

'-------------------------------------------------------------------------------
' syncContent
'-------------------------------------------------------------------------------
sub syncContent()
    content = getOptionsContent()
    if content = invalid then return

    content.callFunc("configureOptions", {
        options: getOptions()
        selectedKey: SafeString(m.top.selectedKey, "")
        allowDefaultSelection: m.top.allowDefaultSelection
        emptyText: SafeString(m.top.emptyText, "")
        visibleRowCount: getVisibleRowCount()
    })
end sub

'-------------------------------------------------------------------------------
' getOptions
'-------------------------------------------------------------------------------
function getOptions() as object
    if m.top.options = invalid then return []
    return m.top.options
end function

'-------------------------------------------------------------------------------
' getOptionsContent
'-------------------------------------------------------------------------------
function getOptionsContent() as dynamic
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' focusContent
'-------------------------------------------------------------------------------
sub focusContent()
    content = getOptionsContent()
    if content <> invalid then content.callFunc("focusOptions")
end sub

'-------------------------------------------------------------------------------
' onPickerConfigChanged
'-------------------------------------------------------------------------------
sub onPickerConfigChanged()
    configureDialog()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onSelectedKeyChanged
'-------------------------------------------------------------------------------
sub onSelectedKeyChanged()
    syncContent()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    content = getOptionsContent()
    if content = invalid then return

    selection = content.callFunc("getSelectedOption")
    if selection <> invalid then
        m.top.selectedOption = selection
        m.top.selectedOptionChanged = getOptionKey(selection) <> SafeString(m.top.selectedKey, "")
    end if
end sub

'-------------------------------------------------------------------------------
' getOptionKey
'-------------------------------------------------------------------------------
function getOptionKey(option as dynamic) as string
    if option = invalid then return ""
    return SafeString(option.key, "")
end function

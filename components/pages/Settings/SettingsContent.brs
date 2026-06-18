'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.settingsControls = {
        tvLibraryOptions: m.top.findNode("tvLibraryOptions")
        movieLibraryOptions: m.top.findNode("movieLibraryOptions")
        collectionDisplayOptions: m.top.findNode("collectionDisplayOptions")
        homeLibraryThumbnailsOptions: m.top.findNode("homeLibraryThumbnailsOptions")
        tmdbApiKeyInput: m.top.findNode("tmdbApiKeyInput")
    }
    m.focusState = {
        activeIndex: 0
        activeKeyboardField: invalid
    }
    m.focusNodes = [
        m.settingsControls.tvLibraryOptions
        m.settingsControls.movieLibraryOptions
        m.settingsControls.collectionDisplayOptions
        m.settingsControls.homeLibraryThumbnailsOptions
        m.settingsControls.tmdbApiKeyInput
    ]

    m.top.observeField("focusedChild", "onFocusChanged")
    initDisplayOptions(m.settingsControls.tvLibraryOptions)
    initDisplayOptions(m.settingsControls.movieLibraryOptions)
    initDisplayOptions(m.settingsControls.collectionDisplayOptions)
    initHomeLibraryThumbnailsOptions()
    loadSettingsValues()
end sub

'-------------------------------------------------------------------------------
' initDisplayOptions
'-------------------------------------------------------------------------------
sub initDisplayOptions(options as dynamic)
    if options = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    posterOption = content.createChild("ContentNode")
    posterOption.title = "Poster"
    thumbnailOption = content.createChild("ContentNode")
    thumbnailOption.title = "Thumbnail"

    options.content = content
end sub

'-------------------------------------------------------------------------------
' initHomeLibraryThumbnailsOptions
'-------------------------------------------------------------------------------
sub initHomeLibraryThumbnailsOptions()
    options = m.settingsControls.homeLibraryThumbnailsOptions
    if options = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    jellyfinOption = content.createChild("ContentNode")
    jellyfinOption.title = "Use Jellyfin images"
    starfishOption = content.createChild("ContentNode")
    starfishOption.title = "Use Starfish cards"

    options.content = content
end sub

'-------------------------------------------------------------------------------
' loadSettingsValues
'-------------------------------------------------------------------------------
sub loadSettingsValues()
    settings = SettingsStore_Load()
    if settings = invalid then return
    keys = SettingsStore_Keys()

    setDisplayOption(m.settingsControls.tvLibraryOptions, settings[keys.tvLibraryDisplay])
    setDisplayOption(m.settingsControls.movieLibraryOptions, settings[keys.movieLibraryDisplay])
    setDisplayOption(m.settingsControls.collectionDisplayOptions, settings[keys.collectionDisplay])
    setHomeLibraryThumbnailsOption(settings[keys.homeLibraryThumbnails])

    if m.settingsControls.tmdbApiKeyInput <> invalid then
        m.settingsControls.tmdbApiKeyInput.text = SettingsStore_GetSettingValue(settings, keys.tmdbApiKey)
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    if m.top.isInFocusChain() = false then return
    if anySettingsControlFocused() then
        updateTextInputFocusVisual()
        return
    end if

    focusActiveField()
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "down" and isFocusedAtLastItem(getFocusedRadioOptions()) then
        return focusField(m.focusState.activeIndex + 1, invalid)
    end if

    if key = "up" and isFocusedAtFirstItem(getFocusedRadioOptions()) then
        return focusField(m.focusState.activeIndex - 1, invalid)
    end if

    if isTextInputFocused() then
        if key = "up" then return focusField(m.focusState.activeIndex - 1, invalid)
        if key = "left" then return focusField(1, invalid)
        if key = "OK" or key = "select" then
            openKeyboardDialog()
            return true
        end if
    end if

    if key = "right" then return focusRightColumn()
    if key = "left" then return focusLeftColumn()

    return false
end function

'-------------------------------------------------------------------------------
' focusFirstField
'-------------------------------------------------------------------------------
sub focusFirstField()
    focusField(0, 0)
end sub

'-------------------------------------------------------------------------------
' focusLastField
'-------------------------------------------------------------------------------
sub focusLastField()
    focusField(m.focusNodes.Count() - 1, invalid)
end sub

'-------------------------------------------------------------------------------
' getSettingsValues
'-------------------------------------------------------------------------------
function getSettingsValues() as object
    keys = SettingsStore_Keys()
    settings = {}
    settings[keys.tvLibraryDisplay] = getDisplayOptionValue(m.settingsControls.tvLibraryOptions)
    settings[keys.movieLibraryDisplay] = getDisplayOptionValue(m.settingsControls.movieLibraryOptions)
    settings[keys.collectionDisplay] = getDisplayOptionValue(m.settingsControls.collectionDisplayOptions)
    settings[keys.homeLibraryThumbnails] = getHomeLibraryThumbnailsValue()
    settings[keys.tmdbApiKey] = getTextInputValue(m.settingsControls.tmdbApiKeyInput)
    return settings
end function

'-------------------------------------------------------------------------------
' canMoveFocusToButtons
'-------------------------------------------------------------------------------
function canMoveFocusToButtons() as boolean
    return isTextInputFocused()
end function

'-------------------------------------------------------------------------------
' focusActiveField
'-------------------------------------------------------------------------------
sub focusActiveField()
    focusField(m.focusState.activeIndex, invalid)
end sub

'-------------------------------------------------------------------------------
' focusRightColumn
'-------------------------------------------------------------------------------
function focusRightColumn() as boolean
    if m.focusState.activeIndex = 0 then return focusField(3, getFocusedItemIndex(m.settingsControls.tvLibraryOptions))
    if m.focusState.activeIndex = 1 then return focusField(4, invalid)
    if m.focusState.activeIndex = 2 then return focusField(4, invalid)

    return false
end function

'-------------------------------------------------------------------------------
' focusLeftColumn
'-------------------------------------------------------------------------------
function focusLeftColumn() as boolean
    if m.focusState.activeIndex = 3 then return focusField(0, getFocusedItemIndex(m.settingsControls.homeLibraryThumbnailsOptions))
    if m.focusState.activeIndex = 4 then return focusField(1, invalid)

    return false
end function

'-------------------------------------------------------------------------------
' focusField
'-------------------------------------------------------------------------------
function focusField(index as integer, itemIndex as dynamic) as boolean
    if m.focusNodes = invalid or m.focusNodes.Count() = 0 then return false

    if index < 0 then index = 0
    if index >= m.focusNodes.Count() then index = m.focusNodes.Count() - 1

    node = m.focusNodes[index]
    if node = invalid then return false

    m.focusState.activeIndex = index
    if itemIndex <> invalid and isRadioOptions(node) then
        if itemIndex < 0 then itemIndex = 0
        lastItemIndex = getLastItemIndex(node)
        if itemIndex > lastItemIndex then itemIndex = lastItemIndex
        node.jumpToItem = itemIndex
    end if

    node.setFocus(true)
    updateTextInputFocusVisual()
    return true
end function

'-------------------------------------------------------------------------------
' openKeyboardDialog
'-------------------------------------------------------------------------------
sub openKeyboardDialog()
    keyboardDialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    keyboardDialog.buttons = ["Save", "Cancel"]
    keyboardDialog.title = "Enter TMDB API Key"
    keyboardDialog.text = getTextInputValue(m.settingsControls.tmdbApiKeyInput)
    keyboardDialog.observeField("buttonSelected", "onKeyboardDialogButtonSelected")

    m.focusState.activeKeyboardField = "tmdbApiKey"
    scene = m.top.getScene()
    if scene <> invalid then scene.dialog = keyboardDialog
end sub

'-------------------------------------------------------------------------------
' onKeyboardDialogButtonSelected
'-------------------------------------------------------------------------------
sub onKeyboardDialogButtonSelected()
    scene = m.top.getScene()
    if scene = invalid then return

    keyboardDialog = scene.dialog
    if keyboardDialog = invalid then return

    if keyboardDialog.buttonSelected = 0 and m.focusState.activeKeyboardField = "tmdbApiKey" then
        m.settingsControls.tmdbApiKeyInput.text = keyboardDialog.text
    end if

    scene.dialog = invalid
    m.focusState.activeKeyboardField = invalid
    focusField(4, invalid)
end sub

'-------------------------------------------------------------------------------
' setDisplayOption
'-------------------------------------------------------------------------------
sub setDisplayOption(options as dynamic, value as dynamic)
    if options = invalid then return

    displayValue = "poster"
    if value <> invalid and value <> "" then displayValue = value.ToStr()

    if LCase(displayValue) = "thumbnail" then
        options.checkedItem = 1
    else
        options.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' getDisplayOptionValue
'-------------------------------------------------------------------------------
function getDisplayOptionValue(options as dynamic) as string
    if getCheckedItemIndex(options) = 1 then return "thumbnail"
    return "poster"
end function

'-------------------------------------------------------------------------------
' setHomeLibraryThumbnailsOption
'-------------------------------------------------------------------------------
sub setHomeLibraryThumbnailsOption(value as dynamic)
    options = m.settingsControls.homeLibraryThumbnailsOptions
    if options = invalid then return

    thumbnailValue = "jellyfin"
    if value <> invalid and value <> "" then thumbnailValue = value.ToStr()

    if LCase(thumbnailValue) = "starfish" then
        options.checkedItem = 1
    else
        options.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' getHomeLibraryThumbnailsValue
'-------------------------------------------------------------------------------
function getHomeLibraryThumbnailsValue() as string
    if getCheckedItemIndex(m.settingsControls.homeLibraryThumbnailsOptions) = 1 then return "starfish"
    return "jellyfin"
end function

'-------------------------------------------------------------------------------
' getTextInputValue
'-------------------------------------------------------------------------------
function getTextInputValue(input as dynamic) as string
    if input = invalid or input.text = invalid then return ""
    return input.text
end function

'-------------------------------------------------------------------------------
' updateTextInputFocusVisual
'-------------------------------------------------------------------------------
sub updateTextInputFocusVisual()
    input = m.settingsControls.tmdbApiKeyInput
    if input <> invalid then input.hasFocusVisual = input.isInFocusChain()
end sub

'-------------------------------------------------------------------------------
' anySettingsControlFocused
'-------------------------------------------------------------------------------
function anySettingsControlFocused() as boolean
    for each node in m.focusNodes
        if node <> invalid and node.isInFocusChain() then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' getFocusedRadioOptions
'-------------------------------------------------------------------------------
function getFocusedRadioOptions() as dynamic
    for each node in m.focusNodes
        if isRadioOptions(node) and node.isInFocusChain() then return node
    end for

    return invalid
end function

'-------------------------------------------------------------------------------
' isTextInputFocused
'-------------------------------------------------------------------------------
function isTextInputFocused() as boolean
    input = m.settingsControls.tmdbApiKeyInput
    return input <> invalid and input.isInFocusChain()
end function

'-------------------------------------------------------------------------------
' isRadioOptions
'-------------------------------------------------------------------------------
function isRadioOptions(node as dynamic) as boolean
    return node <> invalid and node.id <> "tmdbApiKeyInput"
end function

'-------------------------------------------------------------------------------
' isFocusedAtFirstItem
'-------------------------------------------------------------------------------
function isFocusedAtFirstItem(list as dynamic) as boolean
    return list <> invalid and list.isInFocusChain() and getFocusedItemIndex(list) <= 0
end function

'-------------------------------------------------------------------------------
' isFocusedAtLastItem
'-------------------------------------------------------------------------------
function isFocusedAtLastItem(list as dynamic) as boolean
    if list = invalid or list.isInFocusChain() = false then return false
    return getFocusedItemIndex(list) >= getLastItemIndex(list)
end function

'-------------------------------------------------------------------------------
' getFocusedItemIndex
'-------------------------------------------------------------------------------
function getFocusedItemIndex(list as dynamic) as integer
    focusedIndex = list.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0
    return focusedIndex
end function

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex(list as dynamic) as integer
    if list = invalid then return 0
    checkedIndex = list.checkedItem
    if checkedIndex = invalid or checkedIndex < 0 then return 0
    return checkedIndex
end function

'-------------------------------------------------------------------------------
' getLastItemIndex
'-------------------------------------------------------------------------------
function getLastItemIndex(list as dynamic) as integer
    if list = invalid or list.content = invalid then return 0

    lastIndex = list.content.getChildCount() - 1
    if lastIndex < 0 then return 0
    return lastIndex
end function

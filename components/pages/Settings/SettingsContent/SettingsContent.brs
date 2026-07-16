'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.settingsControls = {
        tvLibraryOptions: m.top.findNode("tvLibraryOptions")
        movieLibraryOptions: m.top.findNode("movieLibraryOptions")
        collectionCardsImageTypeOptions: m.top.findNode("collectionCardsImageTypeOptions")
        collectionItemsImageTypeOptions: m.top.findNode("collectionItemsImageTypeOptions")
        tvEpisodeListDisplayOptions: m.top.findNode("tvEpisodeListDisplayOptions")
        tmdbApiKeyInput: m.top.findNode("tmdbApiKeyInput")
        mediaShellBackgroundOptions: m.top.findNode("mediaShellBackgroundOptions")
    }
    m.focusState = {
        activeIndex: 0
        activeKeyboardField: invalid
    }
    m.settingsState = {
        values: SettingsStore_Defaults()
    }
    m.focusNodes = [
        m.settingsControls.tvLibraryOptions
        m.settingsControls.movieLibraryOptions
        m.settingsControls.collectionCardsImageTypeOptions
        m.settingsControls.collectionItemsImageTypeOptions
        m.settingsControls.tvEpisodeListDisplayOptions
        m.settingsControls.tmdbApiKeyInput
        m.settingsControls.mediaShellBackgroundOptions
    ]

    m.top.observeField("focusedChild", "onFocusChanged")
    m.settingsControls.tvLibraryOptions.observeField("itemSelected", "onTVLibraryDisplaySelected")
    m.settingsControls.movieLibraryOptions.observeField("itemSelected", "onMovieLibraryDisplaySelected")
    m.settingsControls.collectionCardsImageTypeOptions.observeField("itemSelected", "onCollectionCardsImageTypeSelected")
    m.settingsControls.collectionItemsImageTypeOptions.observeField("itemSelected", "onCollectionItemsImageTypeSelected")
    m.settingsControls.tvEpisodeListDisplayOptions.observeField("itemSelected", "onTVEpisodeListDisplaySelected")
    m.settingsControls.mediaShellBackgroundOptions.observeField("itemSelected", "onMediaShellBackgroundSelected")

    initDisplayOptions(m.settingsControls.tvLibraryOptions)
    initDisplayOptions(m.settingsControls.movieLibraryOptions)
    initDisplayOptions(m.settingsControls.collectionCardsImageTypeOptions)
    initDisplayOptions(m.settingsControls.collectionItemsImageTypeOptions)
    initTVEpisodeListDisplayOptions()
    initMediaShellBackgroundOptions()
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
' initTVEpisodeListDisplayOptions
'-------------------------------------------------------------------------------
sub initTVEpisodeListDisplayOptions()
    options = m.settingsControls.tvEpisodeListDisplayOptions
    if options = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    horizontalOption = content.createChild("ContentNode")
    horizontalOption.title = "Horizontal"
    verticalOption = content.createChild("ContentNode")
    verticalOption.title = "Vertical"

    options.content = content
end sub

'-------------------------------------------------------------------------------
' initMediaShellBackgroundOptions
'-------------------------------------------------------------------------------
sub initMediaShellBackgroundOptions()
    options = m.settingsControls.mediaShellBackgroundOptions
    if options = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    fullScreenOption = content.createChild("ContentNode")
    fullScreenOption.title = "Full Screen"
    partialScreenOption = content.createChild("ContentNode")
    partialScreenOption.title = "Partial Screen"

    options.content = content
end sub

'-------------------------------------------------------------------------------
' loadSettingsValues
'-------------------------------------------------------------------------------
sub loadSettingsValues()
    settings = SettingsStore_Load()
    if settings = invalid then return
    keys = SettingsStore_Keys()

    m.settingsState.values = {}
    m.settingsState.values[keys.tvLibraryDisplay] = SettingsStore_GetSettingValue(settings, keys.tvLibraryDisplay)
    m.settingsState.values[keys.movieLibraryDisplay] = SettingsStore_GetSettingValue(settings, keys.movieLibraryDisplay)
    m.settingsState.values[keys.collectionCardsImageType] = SettingsStore_GetSettingValue(settings, keys.collectionCardsImageType)
    m.settingsState.values[keys.collectionItemsImageType] = SettingsStore_GetSettingValue(settings, keys.collectionItemsImageType)
    m.settingsState.values[keys.tvEpisodeListDisplay] = SettingsStore_GetSettingValue(settings, keys.tvEpisodeListDisplay)
    m.settingsState.values[keys.mediaShellBackground] = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
    m.settingsState.values[keys.tmdbApiKey] = SettingsStore_GetSettingValue(settings, keys.tmdbApiKey)

    setDisplayOption(m.settingsControls.tvLibraryOptions, m.settingsState.values[keys.tvLibraryDisplay])
    setDisplayOption(m.settingsControls.movieLibraryOptions, m.settingsState.values[keys.movieLibraryDisplay])
    setDisplayOption(m.settingsControls.collectionCardsImageTypeOptions, m.settingsState.values[keys.collectionCardsImageType])
    setDisplayOption(m.settingsControls.collectionItemsImageTypeOptions, m.settingsState.values[keys.collectionItemsImageType])
    setTVEpisodeListDisplayOption(m.settingsState.values[keys.tvEpisodeListDisplay])
    setMediaShellBackgroundOption(m.settingsState.values[keys.mediaShellBackground])

    if m.settingsControls.tmdbApiKeyInput <> invalid then
        m.settingsControls.tmdbApiKeyInput.text = m.settingsState.values[keys.tmdbApiKey]
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
        if key = "down" then return focusField(m.focusState.activeIndex + 1, 0)
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
    settings[keys.tvLibraryDisplay] = SettingsStore_GetSettingValue(m.settingsState.values, keys.tvLibraryDisplay)
    settings[keys.movieLibraryDisplay] = SettingsStore_GetSettingValue(m.settingsState.values, keys.movieLibraryDisplay)
    settings[keys.collectionCardsImageType] = SettingsStore_GetSettingValue(m.settingsState.values, keys.collectionCardsImageType)
    settings[keys.collectionItemsImageType] = SettingsStore_GetSettingValue(m.settingsState.values, keys.collectionItemsImageType)
    settings[keys.tvEpisodeListDisplay] = SettingsStore_GetSettingValue(m.settingsState.values, keys.tvEpisodeListDisplay)
    settings[keys.mediaShellBackground] = SettingsStore_GetSettingValue(m.settingsState.values, keys.mediaShellBackground)
    settings[keys.tmdbApiKey] = SettingsStore_GetSettingValue(m.settingsState.values, keys.tmdbApiKey)
    return settings
end function

'-------------------------------------------------------------------------------
' onTVLibraryDisplaySelected
'-------------------------------------------------------------------------------
sub onTVLibraryDisplaySelected()
    setSelectedDisplayOptionValue(m.settingsControls.tvLibraryOptions, SettingsStore_Keys().tvLibraryDisplay)
end sub

'-------------------------------------------------------------------------------
' onMovieLibraryDisplaySelected
'-------------------------------------------------------------------------------
sub onMovieLibraryDisplaySelected()
    setSelectedDisplayOptionValue(m.settingsControls.movieLibraryOptions, SettingsStore_Keys().movieLibraryDisplay)
end sub

'-------------------------------------------------------------------------------
' onCollectionCardsImageTypeSelected
'-------------------------------------------------------------------------------
sub onCollectionCardsImageTypeSelected()
    setSelectedDisplayOptionValue(m.settingsControls.collectionCardsImageTypeOptions, SettingsStore_Keys().collectionCardsImageType)
end sub

'-------------------------------------------------------------------------------
' onCollectionItemsImageTypeSelected
'-------------------------------------------------------------------------------
sub onCollectionItemsImageTypeSelected()
    setSelectedDisplayOptionValue(m.settingsControls.collectionItemsImageTypeOptions, SettingsStore_Keys().collectionItemsImageType)
end sub

'-------------------------------------------------------------------------------
' onTVEpisodeListDisplaySelected
'-------------------------------------------------------------------------------
sub onTVEpisodeListDisplaySelected()
    selectedIndex = getSelectedItemIndex(m.settingsControls.tvEpisodeListDisplayOptions)
    if selectedIndex < 0 then return

    m.settingsControls.tvEpisodeListDisplayOptions.checkedItem = selectedIndex
    m.settingsState.values[SettingsStore_Keys().tvEpisodeListDisplay] = getTVEpisodeListDisplayValueForIndex(selectedIndex)
end sub

'-------------------------------------------------------------------------------
' onMediaShellBackgroundSelected
'-------------------------------------------------------------------------------
sub onMediaShellBackgroundSelected()
    selectedIndex = getSelectedItemIndex(m.settingsControls.mediaShellBackgroundOptions)
    if selectedIndex < 0 then return

    m.settingsControls.mediaShellBackgroundOptions.checkedItem = selectedIndex
    m.settingsState.values[SettingsStore_Keys().mediaShellBackground] = getMediaShellBackgroundValueForIndex(selectedIndex)
end sub

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
    if m.focusState.activeIndex = 0 then return focusField(4, getFocusedItemIndex(m.settingsControls.tvLibraryOptions))
    if m.focusState.activeIndex = 1 then return focusField(5, invalid)
    if m.focusState.activeIndex = 2 then return focusField(5, invalid)
    if m.focusState.activeIndex = 3 then return focusField(6, invalid)

    return false
end function

'-------------------------------------------------------------------------------
' focusLeftColumn
'-------------------------------------------------------------------------------
function focusLeftColumn() as boolean
    if m.focusState.activeIndex = 4 then return focusField(0, getFocusedItemIndex(m.settingsControls.tvEpisodeListDisplayOptions))
    if m.focusState.activeIndex = 5 then return focusField(1, invalid)
    if m.focusState.activeIndex = 6 then return focusField(3, getFocusedItemIndex(m.settingsControls.collectionItemsImageTypeOptions))

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
        tmdbApiKey = keyboardDialog.text
        if tmdbApiKey = invalid then tmdbApiKey = ""

        m.settingsControls.tmdbApiKeyInput.text = tmdbApiKey
        m.settingsState.values[SettingsStore_Keys().tmdbApiKey] = tmdbApiKey
    end if

    scene.dialog = invalid
    m.focusState.activeKeyboardField = invalid
    focusField(5, invalid)
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
' setSelectedDisplayOptionValue
'-------------------------------------------------------------------------------
sub setSelectedDisplayOptionValue(options as dynamic, key as string)
    selectedIndex = getSelectedItemIndex(options)
    if selectedIndex < 0 then return

    options.checkedItem = selectedIndex
    m.settingsState.values[key] = getDisplayOptionValueForIndex(selectedIndex)
end sub

'-------------------------------------------------------------------------------
' getDisplayOptionValueForIndex
'-------------------------------------------------------------------------------
function getDisplayOptionValueForIndex(index as integer) as string
    if index = 1 then return "thumbnail"
    return "poster"
end function

'-------------------------------------------------------------------------------
' setTVEpisodeListDisplayOption
'-------------------------------------------------------------------------------
sub setTVEpisodeListDisplayOption(value as dynamic)
    options = m.settingsControls.tvEpisodeListDisplayOptions
    if options = invalid then return

    displayValue = "horizontal"
    if value <> invalid and value <> "" then displayValue = value.ToStr()

    if LCase(displayValue) = "vertical" then
        options.checkedItem = 1
    else
        options.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' getTVEpisodeListDisplayValue
'-------------------------------------------------------------------------------
function getTVEpisodeListDisplayValue() as string
    if getCheckedItemIndex(m.settingsControls.tvEpisodeListDisplayOptions) = 1 then return "vertical"
    return "horizontal"
end function

'-------------------------------------------------------------------------------
' getTVEpisodeListDisplayValueForIndex
'-------------------------------------------------------------------------------
function getTVEpisodeListDisplayValueForIndex(index as integer) as string
    if index = 1 then return "vertical"
    return "horizontal"
end function

'-------------------------------------------------------------------------------
' setMediaShellBackgroundOption
'-------------------------------------------------------------------------------
sub setMediaShellBackgroundOption(value as dynamic)
    options = m.settingsControls.mediaShellBackgroundOptions
    if options = invalid then return

    displayValue = "full-screen"
    if value <> invalid and value <> "" then displayValue = value.ToStr()

    if LCase(displayValue) = "partial-screen" then
        options.checkedItem = 1
    else
        options.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' getMediaShellBackgroundValueForIndex
'-------------------------------------------------------------------------------
function getMediaShellBackgroundValueForIndex(index as integer) as string
    if index = 1 then return "partial-screen"
    return "full-screen"
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
' getSelectedItemIndex
'-------------------------------------------------------------------------------
function getSelectedItemIndex(list as dynamic) as integer
    if list = invalid then return -1
    selectedIndex = list.itemSelected
    if selectedIndex = invalid then return -1
    if selectedIndex > getLastItemIndex(list) then return getLastItemIndex(list)
    return selectedIndex
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

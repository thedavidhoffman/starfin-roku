'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.categoryList = m.top.findNode("categoryList")
    m.videoStreamingModeDescription = m.top.findNode("videoStreamingModeDescription")
    m.videoStreamingModeDescription.font.size = m.videoStreamingModeDescription.font.size + 3
    m.categoryPanels = [
        m.top.findNode("mediaShellPanel")
        m.top.findNode("tvPanel")
        m.top.findNode("moviePanel")
        m.top.findNode("videoPanel")
        m.top.findNode("collectionsPanel")
        m.top.findNode("playlistsPanel")
        m.top.findNode("integrationsPanel")
    ]
    m.settingsControls = {
        mediaShellBackgroundOptions: m.top.findNode("mediaShellBackgroundOptions")
        tvLibraryOptions: m.top.findNode("tvLibraryOptions")
        tvEpisodeListDisplayOptions: m.top.findNode("tvEpisodeListDisplayOptions")
        movieLibraryOptions: m.top.findNode("movieLibraryOptions")
        videoStreamingModeOptions: m.top.findNode("videoStreamingModeOptions")
        collectionCardsImageTypeOptions: m.top.findNode("collectionCardsImageTypeOptions")
        collectionItemsImageTypeOptions: m.top.findNode("collectionItemsImageTypeOptions")
        playlistImageTypeOptions: m.top.findNode("playlistImageTypeOptions")
        tmdbApiKeyInput: m.top.findNode("tmdbApiKeyInput")
    }
    m.categoryControls = [
        [m.settingsControls.mediaShellBackgroundOptions]
        [m.settingsControls.tvLibraryOptions, m.settingsControls.tvEpisodeListDisplayOptions]
        [m.settingsControls.movieLibraryOptions]
        [m.settingsControls.videoStreamingModeOptions]
        [m.settingsControls.collectionCardsImageTypeOptions, m.settingsControls.collectionItemsImageTypeOptions]
        [m.settingsControls.playlistImageTypeOptions]
        [m.settingsControls.tmdbApiKeyInput]
    ]
    m.focusState = {
        categoryIndex: 0
        controlIndex: 0
        activeKeyboardField: invalid
    }
    m.settingsState = {
        values: SettingsStore_Defaults()
    }

    initCategoryList()
    initDisplayOptions(m.settingsControls.tvLibraryOptions)
    initDisplayOptions(m.settingsControls.movieLibraryOptions)
    initDisplayOptions(m.settingsControls.collectionCardsImageTypeOptions)
    initDisplayOptions(m.settingsControls.collectionItemsImageTypeOptions)
    initDisplayOptions(m.settingsControls.playlistImageTypeOptions)
    initTVEpisodeListDisplayOptions()
    initMediaShellBackgroundOptions()
    initVideoStreamingModeOptions()

    m.categoryList.observeField("itemFocused", "onCategoryFocused")
    m.categoryList.observeField("itemSelected", "onCategorySelected")
    m.settingsControls.tvLibraryOptions.observeField("itemSelected", "onTVLibraryDisplaySelected")
    m.settingsControls.movieLibraryOptions.observeField("itemSelected", "onMovieLibraryDisplaySelected")
    m.settingsControls.collectionCardsImageTypeOptions.observeField("itemSelected", "onCollectionCardsImageTypeSelected")
    m.settingsControls.collectionItemsImageTypeOptions.observeField("itemSelected", "onCollectionItemsImageTypeSelected")
    m.settingsControls.playlistImageTypeOptions.observeField("itemSelected", "onPlaylistImageTypeSelected")
    m.settingsControls.tvEpisodeListDisplayOptions.observeField("itemSelected", "onTVEpisodeListDisplaySelected")
    m.settingsControls.mediaShellBackgroundOptions.observeField("itemSelected", "onMediaShellBackgroundSelected")
    m.settingsControls.videoStreamingModeOptions.observeField("itemSelected", "onVideoStreamingModeSelected")
    m.settingsControls.videoStreamingModeOptions.observeField("itemFocused", "onVideoStreamingModeFocused")

    loadSettingsValues()
    showCategory(0)
end sub

'-------------------------------------------------------------------------------
' initCategoryList
'-------------------------------------------------------------------------------
sub initCategoryList()
    content = CreateObject("roSGNode", "ContentNode")
    for each title in ["Media Shell", "TV", "Movie", "Video", "Collections", "Playlists", "Integrations"]
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.categoryList.content = content
end sub

'-------------------------------------------------------------------------------
' initDisplayOptions
'-------------------------------------------------------------------------------
sub initDisplayOptions(options as object)
    setOptionTitles(options, ["Poster", "Thumbnail"])
end sub

'-------------------------------------------------------------------------------
' initTVEpisodeListDisplayOptions
'-------------------------------------------------------------------------------
sub initTVEpisodeListDisplayOptions()
    setOptionTitles(m.settingsControls.tvEpisodeListDisplayOptions, ["Horizontal", "Vertical"])
end sub

'-------------------------------------------------------------------------------
' initMediaShellBackgroundOptions
'-------------------------------------------------------------------------------
sub initMediaShellBackgroundOptions()
    setOptionTitles(m.settingsControls.mediaShellBackgroundOptions, ["Full Screen", "Partial Screen"])
end sub

'-------------------------------------------------------------------------------
' initVideoStreamingModeOptions
'-------------------------------------------------------------------------------
sub initVideoStreamingModeOptions()
    setOptionTitles(m.settingsControls.videoStreamingModeOptions, ["Automatic", "Direct Play", "Force Transcode (Allow Remux)", "Force Transcode (Remux Disabled)"])
end sub

'-------------------------------------------------------------------------------
' setOptionTitles
'-------------------------------------------------------------------------------
sub setOptionTitles(options as object, titles as object)
    content = CreateObject("roSGNode", "ContentNode")
    for each title in titles
        item = content.createChild("ContentNode")
        item.title = title
    end for
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
    m.settingsState.values[keys.playlistImageType] = SettingsStore_GetSettingValue(settings, keys.playlistImageType)
    m.settingsState.values[keys.tvEpisodeListDisplay] = SettingsStore_GetSettingValue(settings, keys.tvEpisodeListDisplay)
    m.settingsState.values[keys.mediaShellBackground] = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
    m.settingsState.values[keys.videoStreamingMode] = SettingsStore_GetSettingValue(settings, keys.videoStreamingMode)
    m.settingsState.values[keys.tmdbApiKey] = SettingsStore_GetSettingValue(settings, keys.tmdbApiKey)

    setDisplayOption(m.settingsControls.tvLibraryOptions, m.settingsState.values[keys.tvLibraryDisplay])
    setDisplayOption(m.settingsControls.movieLibraryOptions, m.settingsState.values[keys.movieLibraryDisplay])
    setDisplayOption(m.settingsControls.collectionCardsImageTypeOptions, m.settingsState.values[keys.collectionCardsImageType])
    setDisplayOption(m.settingsControls.collectionItemsImageTypeOptions, m.settingsState.values[keys.collectionItemsImageType])
    setDisplayOption(m.settingsControls.playlistImageTypeOptions, m.settingsState.values[keys.playlistImageType])
    setTVEpisodeListDisplayOption(m.settingsState.values[keys.tvEpisodeListDisplay])
    setMediaShellBackgroundOption(m.settingsState.values[keys.mediaShellBackground])
    setVideoStreamingModeOption(m.settingsState.values[keys.videoStreamingMode])
    m.settingsControls.tmdbApiKeyInput.text = m.settingsState.values[keys.tmdbApiKey]
end sub

'-------------------------------------------------------------------------------
' focusFirstField
'-------------------------------------------------------------------------------
sub focusFirstField()
    m.categoryList.jumpToItem = m.focusState.categoryIndex
    m.categoryList.setFocus(true)
    updateTextInputFocusVisual()
end sub

'-------------------------------------------------------------------------------
' focusLastField
'-------------------------------------------------------------------------------
sub focusLastField()
    focusCategoryControl(m.categoryControls[m.focusState.categoryIndex].Count() - 1, invalid)
end sub

'-------------------------------------------------------------------------------
' canMoveFocusToButtons
'-------------------------------------------------------------------------------
function canMoveFocusToButtons() as boolean
    return false
end function

'-------------------------------------------------------------------------------
' onCategoryFocused
'-------------------------------------------------------------------------------
sub onCategoryFocused()
    showCategory(getListIndex(m.categoryList.itemFocused, m.categoryPanels.Count()))
end sub

'-------------------------------------------------------------------------------
' onCategorySelected
'-------------------------------------------------------------------------------
sub onCategorySelected()
    showCategory(getListIndex(m.categoryList.itemSelected, m.categoryPanels.Count()))
    focusCategoryControl(0, 0)
end sub

'-------------------------------------------------------------------------------
' showCategory
'-------------------------------------------------------------------------------
sub showCategory(index as integer)
    if index < 0 or index >= m.categoryPanels.Count() then return

    m.focusState.categoryIndex = index
    m.focusState.controlIndex = 0
    for i = 0 to m.categoryPanels.Count() - 1
        m.categoryPanels[i].visible = (i = index)
    end for
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if m.categoryList.isInFocusChain() then
        if key = "right" then return focusCategoryControl(0, 0)
        return false
    end if

    if key = "left" then
        focusFirstField()
        return true
    end if

    if isTextInputFocused() then
        if key = "OK" or key = "select" then
            openKeyboardDialog()
            return true
        end if
        return false
    end if

    focusedOptions = getFocusedRadioOptions()
    if key = "down" and isFocusedAtLastItem(focusedOptions) then
        return focusCategoryControl(m.focusState.controlIndex + 1, 0)
    end if
    if key = "up" and isFocusedAtFirstItem(focusedOptions) then
        return focusCategoryControl(m.focusState.controlIndex - 1, invalid)
    end if

    return false
end function

'-------------------------------------------------------------------------------
' focusCategoryControl
'-------------------------------------------------------------------------------
function focusCategoryControl(index as integer, itemIndex as dynamic) as boolean
    controls = m.categoryControls[m.focusState.categoryIndex]
    if index < 0 or index >= controls.Count() then return false

    node = controls[index]
    m.focusState.controlIndex = index
    if itemIndex <> invalid and node.subtype() = "RadioButtonList" then node.jumpToItem = itemIndex
    node.setFocus(true)
    updateTextInputFocusVisual()
    return true
end function

'-------------------------------------------------------------------------------
' getSettingsValues
'-------------------------------------------------------------------------------
function getSettingsValues() as object
    keys = SettingsStore_Keys()
    settings = {}
    for each key in [keys.tvLibraryDisplay, keys.movieLibraryDisplay, keys.collectionCardsImageType, keys.collectionItemsImageType, keys.playlistImageType, keys.tvEpisodeListDisplay, keys.mediaShellBackground, keys.videoStreamingMode, keys.tmdbApiKey]
        settings[key] = SettingsStore_GetSettingValue(m.settingsState.values, key)
    end for
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
' onPlaylistImageTypeSelected
'-------------------------------------------------------------------------------
sub onPlaylistImageTypeSelected()
    setSelectedDisplayOptionValue(m.settingsControls.playlistImageTypeOptions, SettingsStore_Keys().playlistImageType)
end sub

'-------------------------------------------------------------------------------
' onTVEpisodeListDisplaySelected
'-------------------------------------------------------------------------------
sub onTVEpisodeListDisplaySelected()
    selectedIndex = getSelectedItemIndex(m.settingsControls.tvEpisodeListDisplayOptions)
    if selectedIndex < 0 then return
    m.settingsControls.tvEpisodeListDisplayOptions.checkedItem = selectedIndex
    if selectedIndex = 1 then
        m.settingsState.values[SettingsStore_Keys().tvEpisodeListDisplay] = "vertical"
    else
        m.settingsState.values[SettingsStore_Keys().tvEpisodeListDisplay] = "horizontal"
    end if
end sub

'-------------------------------------------------------------------------------
' onMediaShellBackgroundSelected
'-------------------------------------------------------------------------------
sub onMediaShellBackgroundSelected()
    selectedIndex = getSelectedItemIndex(m.settingsControls.mediaShellBackgroundOptions)
    if selectedIndex < 0 then return
    m.settingsControls.mediaShellBackgroundOptions.checkedItem = selectedIndex
    if selectedIndex = 1 then
        m.settingsState.values[SettingsStore_Keys().mediaShellBackground] = "partial-screen"
    else
        m.settingsState.values[SettingsStore_Keys().mediaShellBackground] = "full-screen"
    end if
end sub

'-------------------------------------------------------------------------------
' onVideoStreamingModeSelected
'-------------------------------------------------------------------------------
sub onVideoStreamingModeSelected()
    selectedIndex = getSelectedItemIndex(m.settingsControls.videoStreamingModeOptions)
    if selectedIndex < 0 then return

    m.settingsControls.videoStreamingModeOptions.checkedItem = selectedIndex
    m.settingsState.values[SettingsStore_Keys().videoStreamingMode] = getVideoStreamingModeForIndex(selectedIndex)
end sub

'-------------------------------------------------------------------------------
' onVideoStreamingModeFocused
'-------------------------------------------------------------------------------
sub onVideoStreamingModeFocused()
    index = getListIndex(m.settingsControls.videoStreamingModeOptions.itemFocused, 4)
    m.videoStreamingModeDescription.text = getVideoStreamingModeDescription(index)
end sub

'-------------------------------------------------------------------------------
' setDisplayOption
'-------------------------------------------------------------------------------
sub setDisplayOption(options as object, value as dynamic)
    if value <> invalid and LCase(value.ToStr()) = "thumbnail" then
        options.checkedItem = 1
    else
        options.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' setSelectedDisplayOptionValue
'-------------------------------------------------------------------------------
sub setSelectedDisplayOptionValue(options as object, key as string)
    selectedIndex = getSelectedItemIndex(options)
    if selectedIndex < 0 then return
    options.checkedItem = selectedIndex
    if selectedIndex = 1 then
        m.settingsState.values[key] = "thumbnail"
    else
        m.settingsState.values[key] = "poster"
    end if
end sub

'-------------------------------------------------------------------------------
' setTVEpisodeListDisplayOption
'-------------------------------------------------------------------------------
sub setTVEpisodeListDisplayOption(value as dynamic)
    if value <> invalid and LCase(value.ToStr()) = "vertical" then
        m.settingsControls.tvEpisodeListDisplayOptions.checkedItem = 1
    else
        m.settingsControls.tvEpisodeListDisplayOptions.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' setMediaShellBackgroundOption
'-------------------------------------------------------------------------------
sub setMediaShellBackgroundOption(value as dynamic)
    if value <> invalid and LCase(value.ToStr()) = "partial-screen" then
        m.settingsControls.mediaShellBackgroundOptions.checkedItem = 1
    else
        m.settingsControls.mediaShellBackgroundOptions.checkedItem = 0
    end if
end sub

'-------------------------------------------------------------------------------
' setVideoStreamingModeOption
'-------------------------------------------------------------------------------
sub setVideoStreamingModeOption(value as dynamic)
    mode = "automatic"
    if value <> invalid and value <> "" then mode = value.ToStr()
    selectedIndex = 0
    if mode = "directPlay" then
        selectedIndex = 1
    else if mode = "transcodeAllowRemux" then
        selectedIndex = 2
    else if mode = "transcodeNoRemux" then
        selectedIndex = 3
    end if
    m.settingsControls.videoStreamingModeOptions.checkedItem = selectedIndex
    m.settingsControls.videoStreamingModeOptions.jumpToItem = selectedIndex
    m.videoStreamingModeDescription.text = getVideoStreamingModeDescription(selectedIndex)
end sub

'-------------------------------------------------------------------------------
' getVideoStreamingModeDescription
'-------------------------------------------------------------------------------
function getVideoStreamingModeDescription(index as integer) as string
    if index = 1 then return "Plays the original file without changing its container, video, or audio. Preserves the original quality and uses the least server processing, but requires the device and network to support the file."
    if index = 2 then return "Disables Direct Play. Jellyfin may repackage compatible video or audio without converting it, while transcoding anything the device cannot play. This can improve compatibility while preserving quality where possible."
    if index = 3 then return "Disables Direct Play and forces Jellyfin to convert the video to a supported format, usually H.264. This uses more server processing and may reduce quality, but can resolve playback, timing, keyframe, and seeking problems."
    return "Allows Jellyfin to choose Direct Play, remuxing, or transcoding based on the file, selected audio and subtitle tracks, device capabilities, and network limits. This is the normal playback mode and balances original quality, compatibility, and server processing."
end function

'-------------------------------------------------------------------------------
' getVideoStreamingModeForIndex
'-------------------------------------------------------------------------------
function getVideoStreamingModeForIndex(index as integer) as string
    if index = 1 then return "directPlay"
    if index = 2 then return "transcodeAllowRemux"
    if index = 3 then return "transcodeNoRemux"
    return "automatic"
end function

'-------------------------------------------------------------------------------
' openKeyboardDialog
'-------------------------------------------------------------------------------
sub openKeyboardDialog()
    keyboardDialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    keyboardDialog.buttons = ["Save", "Cancel"]
    keyboardDialog.title = "Enter TMDB API Key"
    keyboardDialog.text = m.settingsControls.tmdbApiKeyInput.text
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
    if scene = invalid or scene.dialog = invalid then return

    keyboardDialog = scene.dialog
    if keyboardDialog.buttonSelected = 0 and m.focusState.activeKeyboardField = "tmdbApiKey" then
        tmdbApiKey = keyboardDialog.text
        if tmdbApiKey = invalid then tmdbApiKey = ""
        m.settingsControls.tmdbApiKeyInput.text = tmdbApiKey
        m.settingsState.values[SettingsStore_Keys().tmdbApiKey] = tmdbApiKey
    end if

    scene.dialog = invalid
    m.focusState.activeKeyboardField = invalid
    focusCategoryControl(0, invalid)
end sub

'-------------------------------------------------------------------------------
' updateTextInputFocusVisual
'-------------------------------------------------------------------------------
sub updateTextInputFocusVisual()
    m.settingsControls.tmdbApiKeyInput.hasFocusVisual = isTextInputFocused()
end sub

'-------------------------------------------------------------------------------
' isTextInputFocused
'-------------------------------------------------------------------------------
function isTextInputFocused() as boolean
    return m.settingsControls.tmdbApiKeyInput.isInFocusChain()
end function

'-------------------------------------------------------------------------------
' getFocusedRadioOptions
'-------------------------------------------------------------------------------
function getFocusedRadioOptions() as dynamic
    for each node in m.categoryControls[m.focusState.categoryIndex]
        if node.subtype() = "RadioButtonList" and node.isInFocusChain() then return node
    end for
    return invalid
end function

'-------------------------------------------------------------------------------
' isFocusedAtFirstItem
'-------------------------------------------------------------------------------
function isFocusedAtFirstItem(list as dynamic) as boolean
    return list <> invalid and list.isInFocusChain() and getListIndex(list.itemFocused, getListItemCount(list)) = 0
end function

'-------------------------------------------------------------------------------
' isFocusedAtLastItem
'-------------------------------------------------------------------------------
function isFocusedAtLastItem(list as dynamic) as boolean
    itemCount = getListItemCount(list)
    return list <> invalid and list.isInFocusChain() and getListIndex(list.itemFocused, itemCount) = itemCount - 1
end function

'-------------------------------------------------------------------------------
' getSelectedItemIndex
'-------------------------------------------------------------------------------
function getSelectedItemIndex(list as object) as integer
    selectedIndex = list.itemSelected
    if selectedIndex = invalid or selectedIndex < 0 then return -1
    return getListIndex(selectedIndex, getListItemCount(list))
end function

'-------------------------------------------------------------------------------
' getListItemCount
'-------------------------------------------------------------------------------
function getListItemCount(list as object) as integer
    if list.content = invalid then return 0
    return list.content.getChildCount()
end function

'-------------------------------------------------------------------------------
' getListIndex
'-------------------------------------------------------------------------------
function getListIndex(value as dynamic, count as integer) as integer
    if count <= 0 then return 0
    if value = invalid or value < 0 then return 0
    if value >= count then return count - 1
    return value
end function

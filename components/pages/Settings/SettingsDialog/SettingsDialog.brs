'-------------------------------------------------------------------------------
' openSettings
'-------------------------------------------------------------------------------
sub openSettings()
    m.originalSettings = invalid
    m.top.title = "Settings"
    m.top.dialogWidth = 1560
    m.top.dialogHeight = 820
    m.top.contentComponentName = "SettingsContent"

    content = getSettingsContent()
    if content <> invalid then
        content.callFunc("loadSettingsValues")
        m.originalSettings = content.callFunc("getSettingsValues")
    end if
    m.top.callFunc("openDialog")
    if content <> invalid then content.callFunc("focusFirstField")
end sub

'-------------------------------------------------------------------------------
' getSettingsContent
'-------------------------------------------------------------------------------
function getSettingsContent() as object
    return m.top.callFunc("getContentComponent")
end function

'-------------------------------------------------------------------------------
' saveSettings
'-------------------------------------------------------------------------------
sub saveSettings()
    content = getSettingsContent()
    if content = invalid then return

    settings = content.callFunc("getSettingsValues")
    if settings = invalid then return
    if SettingsStore_AreEqual(settings, m.originalSettings) then return

    keys = SettingsStore_Keys()
    SettingsStore_Save(settings[keys.tvLibraryDisplay], settings[keys.movieLibraryDisplay], settings[keys.collectionDisplay], settings[keys.tvEpisodeListDisplay], settings[keys.tmdbApiKey])
    m.top.savedSettings = settings
    m.top.settingsSaved = true
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
    saveSettings()
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.originalSettings = invalid
    m.dialog = m.top.findNode("settingsDialog")

    if m.dialog <> invalid then
        m.dialog.observeField("closeRequested", "onDialogCloseRequested")
    end if
end sub

'-------------------------------------------------------------------------------
' openSettings
'-------------------------------------------------------------------------------
sub openSettings()
    if m.dialog = invalid then return

    content = getSettingsContent()
    if content <> invalid then
        content.callFunc("loadSettingsValues")
        m.originalSettings = content.callFunc("getSettingsValues")
    end if
    m.dialog.callFunc("openDialog")
    if content <> invalid then content.callFunc("focusFirstField")
end sub

'-------------------------------------------------------------------------------
' getSettingsContent
'-------------------------------------------------------------------------------
function getSettingsContent() as object
    if m.dialog = invalid then return invalid
    return m.dialog.callFunc("getContentComponent")
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
    SettingsStore_Save(settings[keys.tvLibraryDisplay], settings[keys.movieLibraryDisplay], settings[keys.collectionDisplay], settings[keys.homeLibraryThumbnails], settings[keys.tmdbApiKey])
    m.top.savedSettings = settings
    m.top.settingsSaved = true
end sub

'-------------------------------------------------------------------------------
' onDialogCloseRequested
'-------------------------------------------------------------------------------
sub onDialogCloseRequested()
    saveSettings()
    m.top.closeRequested = true
end sub

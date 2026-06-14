'-------------------------------------------------------------------------------
' Settings Registry Storage
'-------------------------------------------------------------------------------
' roRegistrySection is Roku's persistent key/value storage API.
'
'-------------------------------------------------------------------------------
' GetSettingsStore
'-------------------------------------------------------------------------------
function GetSettingsStore() as object
    return CreateObject("roRegistrySection", "ROKU_STARTER_APP")
end function

'-------------------------------------------------------------------------------
' SettingsStore_Keys
'-------------------------------------------------------------------------------
function SettingsStore_Keys() as object
    return {
        seriesDisplay: "series-display"
        itemDisplay: "item-display"
        gridColumns: "grid-columns"
        screensaverType: "screensaver-type"
        screensaverDelay: "screensaver-delay"
    }
end function

'-------------------------------------------------------------------------------
' SettingsStore_Defaults
'-------------------------------------------------------------------------------
function SettingsStore_Defaults() as object
    keys = SettingsStore_Keys()
    defaults = {}
    defaults[keys.seriesDisplay] = "collapse"
    defaults[keys.itemDisplay] = "grid"
    defaults[keys.gridColumns] = "6"
    defaults[keys.screensaverType] = "off"
    defaults[keys.screensaverDelay] = "1"
    return defaults
end function

'-------------------------------------------------------------------------------
' SettingsStore_Save
'-------------------------------------------------------------------------------
sub SettingsStore_Save(seriesDisplay as string, itemDisplay as string, gridColumns as string, screensaverType as string, screensaverDelay as string)
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    settingsStore.Write(keys.seriesDisplay, seriesDisplay)
    settingsStore.Write(keys.itemDisplay, itemDisplay)
    settingsStore.Write(keys.gridColumns, gridColumns)
    settingsStore.Write(keys.screensaverType, screensaverType)
    settingsStore.Write(keys.screensaverDelay, screensaverDelay)
    settingsStore.Flush()
end sub

'-------------------------------------------------------------------------------
' SettingsStore_Load
'-------------------------------------------------------------------------------
function SettingsStore_Load() as object
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    defaults = SettingsStore_Defaults()
    values = settingsStore.ReadMulti([
        keys.seriesDisplay
        keys.itemDisplay
        keys.gridColumns
        keys.screensaverType
        keys.screensaverDelay
    ])
    if values = invalid then values = {}

    settings = {}
    settings[keys.seriesDisplay] = SettingsStore_GetValue(values, keys.seriesDisplay, defaults[keys.seriesDisplay])
    settings[keys.itemDisplay] = SettingsStore_GetValue(values, keys.itemDisplay, defaults[keys.itemDisplay])
    settings[keys.gridColumns] = SettingsStore_GetValue(values, keys.gridColumns, defaults[keys.gridColumns])
    settings[keys.screensaverType] = SettingsStore_GetValue(values, keys.screensaverType, defaults[keys.screensaverType])
    settings[keys.screensaverDelay] = SettingsStore_GetValue(values, keys.screensaverDelay, defaults[keys.screensaverDelay])
    return settings
end function

'-------------------------------------------------------------------------------
' SettingsStore_Clear
'-------------------------------------------------------------------------------
sub SettingsStore_Clear()
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    settingsStore.Delete(keys.seriesDisplay)
    settingsStore.Delete(keys.itemDisplay)
    settingsStore.Delete(keys.gridColumns)
    settingsStore.Delete(keys.screensaverType)
    settingsStore.Delete(keys.screensaverDelay)
    settingsStore.Flush()
end sub

'-------------------------------------------------------------------------------
' SettingsStore_GetValue
'-------------------------------------------------------------------------------
function SettingsStore_GetValue(values as object, key as string, defaultValue as string) as string
    value = invalid
    if values <> invalid then value = values[key]
    if value = invalid or value = "" then return defaultValue
    return value
end function

'-------------------------------------------------------------------------------
' SettingsStore_GetSettingValue
'-------------------------------------------------------------------------------
function SettingsStore_GetSettingValue(settings as dynamic, key as string) as string
    defaults = SettingsStore_Defaults()
    defaultValue = ""
    if defaults[key] <> invalid then defaultValue = defaults[key]

    if settings = invalid then return defaultValue
    if settings[key] = invalid or settings[key] = "" then return defaultValue
    return settings[key].ToStr()
end function

'-------------------------------------------------------------------------------
' SettingsStore_AreEqual
'-------------------------------------------------------------------------------
function SettingsStore_AreEqual(left as dynamic, right as dynamic) as boolean
    if left = invalid or right = invalid then return false

    keys = SettingsStore_Keys()
    if SettingsStore_GetSettingValue(left, keys.seriesDisplay) <> SettingsStore_GetSettingValue(right, keys.seriesDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.itemDisplay) <> SettingsStore_GetSettingValue(right, keys.itemDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.gridColumns) <> SettingsStore_GetSettingValue(right, keys.gridColumns) then return false
    if SettingsStore_GetSettingValue(left, keys.screensaverType) <> SettingsStore_GetSettingValue(right, keys.screensaverType) then return false
    if SettingsStore_GetSettingValue(left, keys.screensaverDelay) <> SettingsStore_GetSettingValue(right, keys.screensaverDelay) then return false

    return true
end function

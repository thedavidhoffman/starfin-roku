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
        tvLibraryDisplay: "tv-library-display"
        movieLibraryDisplay: "movie-library-display"
        collectionDisplay: "collection-display"
        tvEpisodeListDisplay: "tv-ep-list-scroll"
        themeMusic: "theme-music"
        tmdbApiKey: "tmdb-api-key"
    }
end function

'-------------------------------------------------------------------------------
' SettingsStore_Defaults
'-------------------------------------------------------------------------------
function SettingsStore_Defaults() as object
    keys = SettingsStore_Keys()
    defaults = {}
    defaults[keys.tvLibraryDisplay] = "poster"
    defaults[keys.movieLibraryDisplay] = "poster"
    defaults[keys.collectionDisplay] = "poster"
    defaults[keys.tvEpisodeListDisplay] = "vertical"
    defaults[keys.themeMusic] = "off"
    defaults[keys.tmdbApiKey] = ""
    return defaults
end function

'-------------------------------------------------------------------------------
' SettingsStore_Save
'-------------------------------------------------------------------------------
sub SettingsStore_Save(tvLibraryDisplay as string, movieLibraryDisplay as string, collectionDisplay as string, tvEpisodeListDisplay as string, themeMusic as string, tmdbApiKey as string)
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    settingsStore.Write(keys.tvLibraryDisplay, tvLibraryDisplay)
    settingsStore.Write(keys.movieLibraryDisplay, movieLibraryDisplay)
    settingsStore.Write(keys.collectionDisplay, collectionDisplay)
    settingsStore.Write(keys.tvEpisodeListDisplay, tvEpisodeListDisplay)
    settingsStore.Write(keys.themeMusic, themeMusic)
    settingsStore.Write(keys.tmdbApiKey, tmdbApiKey)
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
        keys.tvLibraryDisplay
        keys.movieLibraryDisplay
        keys.collectionDisplay
        keys.tvEpisodeListDisplay
        keys.themeMusic
        keys.tmdbApiKey
    ])
    if values = invalid then values = {}

    settings = {}
    settings[keys.tvLibraryDisplay] = SettingsStore_GetValue(values, keys.tvLibraryDisplay, defaults[keys.tvLibraryDisplay])
    settings[keys.movieLibraryDisplay] = SettingsStore_GetValue(values, keys.movieLibraryDisplay, defaults[keys.movieLibraryDisplay])
    settings[keys.collectionDisplay] = SettingsStore_GetValue(values, keys.collectionDisplay, defaults[keys.collectionDisplay])
    settings[keys.tvEpisodeListDisplay] = SettingsStore_GetValue(values, keys.tvEpisodeListDisplay, defaults[keys.tvEpisodeListDisplay])
    settings[keys.themeMusic] = SettingsStore_GetValue(values, keys.themeMusic, defaults[keys.themeMusic])
    settings[keys.tmdbApiKey] = SettingsStore_GetValue(values, keys.tmdbApiKey, defaults[keys.tmdbApiKey])
    return settings
end function

'-------------------------------------------------------------------------------
' SettingsStore_Clear
'-------------------------------------------------------------------------------
sub SettingsStore_Clear()
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    settingsStore.Delete(keys.tvLibraryDisplay)
    settingsStore.Delete(keys.movieLibraryDisplay)
    settingsStore.Delete(keys.collectionDisplay)
    settingsStore.Delete(keys.tvEpisodeListDisplay)
    settingsStore.Delete(keys.themeMusic)
    settingsStore.Delete(keys.tmdbApiKey)
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
    if SettingsStore_GetSettingValue(left, keys.tvLibraryDisplay) <> SettingsStore_GetSettingValue(right, keys.tvLibraryDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.movieLibraryDisplay) <> SettingsStore_GetSettingValue(right, keys.movieLibraryDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.collectionDisplay) <> SettingsStore_GetSettingValue(right, keys.collectionDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.tvEpisodeListDisplay) <> SettingsStore_GetSettingValue(right, keys.tvEpisodeListDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.themeMusic) <> SettingsStore_GetSettingValue(right, keys.themeMusic) then return false
    if SettingsStore_GetSettingValue(left, keys.tmdbApiKey) <> SettingsStore_GetSettingValue(right, keys.tmdbApiKey) then return false

    return true
end function

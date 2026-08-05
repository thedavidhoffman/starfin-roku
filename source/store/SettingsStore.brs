'-------------------------------------------------------------------------------
' Settings Registry Storage
'-------------------------------------------------------------------------------
' roRegistrySection is Roku's persistent key/value storage API.
'
'-------------------------------------------------------------------------------
' GetSettingsStore
'-------------------------------------------------------------------------------
function GetSettingsStore() as object
    return CreateObject("roRegistrySection", "STARFIN_ROKU")
end function

'-------------------------------------------------------------------------------
' SettingsStore_Keys
'-------------------------------------------------------------------------------
function SettingsStore_Keys() as object
    return {
        tvLibraryDisplay: "tv-libray-image-type"
        movieLibraryDisplay: "movie-library-image-type"
        collectionCardsImageType: "collection-cards-image-type"
        collectionItemsImageType: "collection-items-image-type"
        playlistImageType: "playlist-image-type"
        tvEpisodeListDisplay: "tv-ep-list-scroll"
        mediaShellBackground: "media-shell-background"
        videoStreamingMode: "video-streaming-mode"
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
    defaults[keys.collectionCardsImageType] = "poster"
    defaults[keys.collectionItemsImageType] = "poster"
    defaults[keys.playlistImageType] = "thumbnail"
    defaults[keys.tvEpisodeListDisplay] = "vertical"
    defaults[keys.mediaShellBackground] = "full-screen"
    defaults[keys.videoStreamingMode] = "automatic"
    defaults[keys.tmdbApiKey] = ""
    return defaults
end function

'-------------------------------------------------------------------------------
' SettingsStore_Save
'-------------------------------------------------------------------------------
sub SettingsStore_Save(tvLibraryDisplay as string, movieLibraryDisplay as string, collectionCardsImageType as string, collectionItemsImageType as string, playlistImageType as string, tvEpisodeListDisplay as string, mediaShellBackground as string, videoStreamingMode as string, tmdbApiKey as string)
    settingsStore = GetSettingsStore()
    keys = SettingsStore_Keys()
    settingsStore.Write(keys.tvLibraryDisplay, tvLibraryDisplay)
    settingsStore.Write(keys.movieLibraryDisplay, movieLibraryDisplay)
    settingsStore.Write(keys.collectionCardsImageType, collectionCardsImageType)
    settingsStore.Write(keys.collectionItemsImageType, collectionItemsImageType)
    settingsStore.Write(keys.playlistImageType, playlistImageType)
    settingsStore.Write(keys.tvEpisodeListDisplay, tvEpisodeListDisplay)
    settingsStore.Write(keys.mediaShellBackground, mediaShellBackground)
    settingsStore.Write(keys.videoStreamingMode, videoStreamingMode)
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
        keys.collectionCardsImageType
        keys.collectionItemsImageType
        keys.playlistImageType
        keys.tvEpisodeListDisplay
        keys.mediaShellBackground
        keys.videoStreamingMode
        keys.tmdbApiKey
    ])
    if values = invalid then values = {}

    settings = {}
    settings[keys.tvLibraryDisplay] = SettingsStore_GetValue(values, keys.tvLibraryDisplay, defaults[keys.tvLibraryDisplay])
    settings[keys.movieLibraryDisplay] = SettingsStore_GetValue(values, keys.movieLibraryDisplay, defaults[keys.movieLibraryDisplay])
    settings[keys.collectionCardsImageType] = SettingsStore_GetValue(values, keys.collectionCardsImageType, defaults[keys.collectionCardsImageType])
    settings[keys.collectionItemsImageType] = SettingsStore_GetValue(values, keys.collectionItemsImageType, defaults[keys.collectionItemsImageType])
    settings[keys.playlistImageType] = SettingsStore_GetValue(values, keys.playlistImageType, defaults[keys.playlistImageType])
    settings[keys.tvEpisodeListDisplay] = SettingsStore_GetValue(values, keys.tvEpisodeListDisplay, defaults[keys.tvEpisodeListDisplay])
    settings[keys.mediaShellBackground] = SettingsStore_GetValue(values, keys.mediaShellBackground, defaults[keys.mediaShellBackground])
    settings[keys.videoStreamingMode] = SettingsStore_GetValue(values, keys.videoStreamingMode, defaults[keys.videoStreamingMode])
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
    settingsStore.Delete(keys.collectionCardsImageType)
    settingsStore.Delete(keys.collectionItemsImageType)
    settingsStore.Delete(keys.playlistImageType)
    settingsStore.Delete(keys.tvEpisodeListDisplay)
    settingsStore.Delete(keys.mediaShellBackground)
    settingsStore.Delete(keys.videoStreamingMode)
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
    if SettingsStore_GetSettingValue(left, keys.collectionCardsImageType) <> SettingsStore_GetSettingValue(right, keys.collectionCardsImageType) then return false
    if SettingsStore_GetSettingValue(left, keys.collectionItemsImageType) <> SettingsStore_GetSettingValue(right, keys.collectionItemsImageType) then return false
    if SettingsStore_GetSettingValue(left, keys.playlistImageType) <> SettingsStore_GetSettingValue(right, keys.playlistImageType) then return false
    if SettingsStore_GetSettingValue(left, keys.tvEpisodeListDisplay) <> SettingsStore_GetSettingValue(right, keys.tvEpisodeListDisplay) then return false
    if SettingsStore_GetSettingValue(left, keys.mediaShellBackground) <> SettingsStore_GetSettingValue(right, keys.mediaShellBackground) then return false
    if SettingsStore_GetSettingValue(left, keys.videoStreamingMode) <> SettingsStore_GetSettingValue(right, keys.videoStreamingMode) then return false
    if SettingsStore_GetSettingValue(left, keys.tmdbApiKey) <> SettingsStore_GetSettingValue(right, keys.tmdbApiKey) then return false

    return true
end function

'-------------------------------------------------------------------------------
' Settings Registry Storage
'-------------------------------------------------------------------------------

'-------------------------------------------------------------------------------
' __GetSettingsAccountSectionName
'-------------------------------------------------------------------------------
function __GetSettingsAccountSectionName(accountKey as string) as string
    return "STARFIN_ACCOUNT_" + accountKey
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
        displayAccountBadge: "display-account-badge"
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
    defaults[keys.displayAccountBadge] = "off"
    defaults[keys.tmdbApiKey] = ""
    return defaults
end function

'-------------------------------------------------------------------------------
' SettingsStore_AccountKeys
'-------------------------------------------------------------------------------
function SettingsStore_AccountKeys() as object
    keys = SettingsStore_Keys()
    return [keys.tvLibraryDisplay, keys.movieLibraryDisplay, keys.collectionCardsImageType, keys.collectionItemsImageType, keys.playlistImageType, keys.tvEpisodeListDisplay, keys.mediaShellBackground, keys.videoStreamingMode]
end function

'-------------------------------------------------------------------------------
' SettingsStore_Load
'-------------------------------------------------------------------------------
function SettingsStore_Load(accountKey as string) as object
    defaults = SettingsStore_Defaults()
    settings = {}
    values = {}
    if accountKey <> "" then
        accountStore = CreateObject("roRegistrySection", __GetSettingsAccountSectionName(accountKey))
        values = accountStore.ReadMulti(SettingsStore_AccountKeys())
        if values = invalid then values = {}
    end if

    for each key in SettingsStore_AccountKeys()
        settings[key] = SettingsStore_GetValue(values, key, defaults[key])
    end for
    keys = SettingsStore_Keys()
    settings[keys.displayAccountBadge] = SettingsStore_LoadGlobal(keys.displayAccountBadge)
    settings[keys.tmdbApiKey] = SettingsStore_LoadIntegration(keys.tmdbApiKey)
    return settings
end function

'-------------------------------------------------------------------------------
' SettingsStore_Save
'-------------------------------------------------------------------------------
sub SettingsStore_Save(accountKey as string, settings as object)
    if accountKey <> "" then
        accountStore = CreateObject("roRegistrySection", __GetSettingsAccountSectionName(accountKey))
        for each key in SettingsStore_AccountKeys()
            accountStore.Write(key, SettingsStore_GetSettingValue(settings, key))
        end for
        accountStore.Flush()
    end if
    keys = SettingsStore_Keys()
    SettingsStore_SaveGlobal(keys.displayAccountBadge, SettingsStore_GetSettingValue(settings, keys.displayAccountBadge))
    SettingsStore_SaveIntegration(keys.tmdbApiKey, SettingsStore_GetSettingValue(settings, keys.tmdbApiKey))
end sub

'-------------------------------------------------------------------------------
' SettingsStore_LoadGlobal
'-------------------------------------------------------------------------------
function SettingsStore_LoadGlobal(key as string) as string
    defaults = SettingsStore_Defaults()
    return SettingsStore_GetValue(CreateObject("roRegistrySection", "STARFIN_ROKU"), key, defaults[key])
end function

'-------------------------------------------------------------------------------
' SettingsStore_SaveGlobal
'-------------------------------------------------------------------------------
sub SettingsStore_SaveGlobal(key as string, value as string)
    settingsStore = CreateObject("roRegistrySection", "STARFIN_ROKU")
    settingsStore.Write(key, value)
    settingsStore.Flush()
end sub

'-------------------------------------------------------------------------------
' SettingsStore_LoadIntegration
'-------------------------------------------------------------------------------
function SettingsStore_LoadIntegration(key as string) as string
    return SettingsStore_LoadGlobal(key)
end function

'-------------------------------------------------------------------------------
' SettingsStore_SaveIntegration
'-------------------------------------------------------------------------------
sub SettingsStore_SaveIntegration(key as string, value as string)
    SettingsStore_SaveGlobal(key, value)
end sub

'-------------------------------------------------------------------------------
' SettingsStore_GetValue
'-------------------------------------------------------------------------------
function SettingsStore_GetValue(values as dynamic, key as string, defaultValue as string) as string
    value = invalid
    if values <> invalid then
        if GetInterface(values, "ifAssociativeArray") <> invalid then
            value = values[key]
        else
            value = values.Read(key)
        end if
    end if
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
    for each key in SettingsStore_Defaults()
        if SettingsStore_GetSettingValue(left, key) <> SettingsStore_GetSettingValue(right, key) then return false
    end for
    return true
end function

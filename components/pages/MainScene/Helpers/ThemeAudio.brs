'-------------------------------------------------------------------------------
' themeAudioHandleMovieRequested
'-------------------------------------------------------------------------------
sub themeAudioHandleMovieRequested()
    if m.moviePage = invalid then return

    themeAudioPlay(m.moviePage.themeRequested)
end sub

'-------------------------------------------------------------------------------
' themeAudioHandleTVShowRequested
'-------------------------------------------------------------------------------
sub themeAudioHandleTVShowRequested()
    if m.tvShowPage = invalid then return

    themeAudioPlay(m.tvShowPage.themeRequested)
end sub

'-------------------------------------------------------------------------------
' themeAudioPlay
'-------------------------------------------------------------------------------
sub themeAudioPlay(request as dynamic)
    if request = invalid then return
    if themeAudioIsEnabled() <> true then return
    if m.themeAudio = invalid then return

    m.themeAudio.callFunc("playTheme", request)
end sub

'-------------------------------------------------------------------------------
' themeAudioStop
'-------------------------------------------------------------------------------
sub themeAudioStop()
    if m.themeAudio = invalid then return

    m.themeAudio.callFunc("stopTheme")
end sub

'-------------------------------------------------------------------------------
' themeAudioIsEnabled
'-------------------------------------------------------------------------------
function themeAudioIsEnabled() as boolean
    if m.settings = invalid then return false

    keys = SettingsStore_Keys()
    return LCase(SettingsStore_GetSettingValue(m.settings, keys.themeMusic)) = "on"
end function

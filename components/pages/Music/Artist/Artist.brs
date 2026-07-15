'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.mediaShell = m.top.findNode("mediaShell")
    m.albumsRow = m.top.findNode("albumsRow")
    m.artistTask = m.top.findNode("artistTask")
    m.mediaShell.observeField("overlayRequested", "onMediaShellOverlayRequested")
    m.artistTask.observeField("response", "onArtistResponse")
    m.state = {
        request: invalid
        overview: ""
        lifecycle: AsyncLifecycle_Create()
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.state.request = request
    m.state.overview = "Loading artist overview..."
    AsyncLifecycle_Begin(m.state.lifecycle, request.itemId)
    applyBackgroundSetting(request.settings)
    renderArtist()
    renderAlbums(request.albums)

    artistId = SafeString(request.musicBrainzArtistId, "")
    if artistId = "" then
        m.state.overview = "No Wikipedia overview is available for this artist."
        renderArtist()
        return
    end if

    m.artistTask.request = { artistId: artistId }
    m.artistTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' renderAlbums
'-------------------------------------------------------------------------------
sub renderAlbums(albums as dynamic)
    if albums = invalid then albums = []

    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")
    request = m.state.request
    for each album in albums
        child = row.createChild("ContentNode")
        child.title = FirstNonEmpty([album.Name], "Untitled Album")
        child.HDPosterUrl = getAlbumArtworkUrl(album, request)
        child.AddFields({ releaseYear: getAlbumReleaseYear(album), raw: album })
    end for

    hasAlbums = row.getChildCount() > 0
    m.albumsRow.content = content
    m.albumsRow.visible = hasAlbums
end sub

'-------------------------------------------------------------------------------
' getAlbumArtworkUrl
'-------------------------------------------------------------------------------
function getAlbumArtworkUrl(album as object, request as object) as string
    itemId = SafeString(album.Id, "")
    tag = ""
    if album.ImageTags <> invalid then tag = SafeString(album.ImageTags.Primary, "")
    if itemId = "" or tag = "" then return "pkg:/images/music/album-placeholder-300x300.png"

    return Url_BuildImageUrl(request.server, itemId, "Primary", tag, 300, 300)
end function

'-------------------------------------------------------------------------------
' getAlbumReleaseYear
'-------------------------------------------------------------------------------
function getAlbumReleaseYear(album as object) as string
    year = Number_ToInteger(album.ProductionYear, 0)
    if year <= 0 then
        premiereDate = SafeString(album.PremiereDate, "")
        if Len(premiereDate) >= 4 then year = Number_ToInteger(Left(premiereDate, 4), 0)
    end if
    if year <= 0 then return ""
    return year.ToStr()
end function

'-------------------------------------------------------------------------------
' onArtistResponse
'-------------------------------------------------------------------------------
sub onArtistResponse()
    response = m.artistTask.response
    request = m.state.request
    if response = invalid or request = invalid then return
    if m.state.lifecycle.isActive <> true then return
    if SafeString(response.artistId, "") <> SafeString(request.musicBrainzArtistId, "") then return

    if response.ok = true then
        m.state.overview = SafeString(response.extract, "")
    else
        m.state.overview = "Wikipedia overview unavailable."
    end if
    renderArtist()
end sub

'-------------------------------------------------------------------------------
' renderArtist
'-------------------------------------------------------------------------------
sub renderArtist()
    request = m.state.request
    if request = invalid then return

    item = request.item
    title = "Unknown Artist"
    if item <> invalid then title = FirstNonEmpty([item.Name], title)
    m.mediaShell.mediaContent = {
        mediaType: "artist"
        title: title
        logoUrl: SafeString(request.logoUrl, "")
        logoPending: false
        backdropUrl: SafeString(request.backdropUrl, "")
        primaryInfoText: "Artist"
        secondaryInfoText: ""
        overview: m.state.overview
    }
end sub

'-------------------------------------------------------------------------------
' applyBackgroundSetting
'-------------------------------------------------------------------------------
sub applyBackgroundSetting(settings as dynamic)
    keys = SettingsStore_Keys()
    m.mediaShell.backgroundDisplay = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
end sub

'-------------------------------------------------------------------------------
' onMediaShellOverlayRequested
'-------------------------------------------------------------------------------
sub onMediaShellOverlayRequested()
    request = m.mediaShell.overlayRequested
    if request = invalid then return
    request.sourcePage = "musicArtist"
    m.top.overlayRequested = request
end sub

'-------------------------------------------------------------------------------
' handleDescriptionOverlayClosed
'-------------------------------------------------------------------------------
sub handleDescriptionOverlayClosed()
    m.mediaShell.callFunc("focusDescription")
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.state.lifecycle, m.state.request, "itemId")
    m.top.setFocus(true)
    if m.albumsRow.visible = true then
        m.albumsRow.setFocus(true)
    else
        m.mediaShell.callFunc("focusDescription")
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.state.lifecycle)
    m.artistTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    normalizedKey = LCase(key)
    if normalizedKey = "up" and m.albumsRow.isInFocusChain() then return m.mediaShell.callFunc("focusDescription")
    if normalizedKey = "down" and m.mediaShell.isInFocusChain() and m.albumsRow.visible = true then
        m.albumsRow.setFocus(true)
        return true
    end if
    if normalizedKey <> "back" then return false

    m.top.closeRequested = true
    return true
end function

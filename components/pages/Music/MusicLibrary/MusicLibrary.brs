'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MusicLibrary")
    m.titleLabel = m.top.findNode("titleLabel")
    m.albumsGrid = m.top.findNode("albumsGrid")
    m.musicLibraryTask = m.top.findNode("musicLibraryTask")
    m.musicLibraryTask.observeField("response", "onMusicLibraryResponse")
    m.albumsGrid.observeField("itemSelected", "onAlbumSelected")
    m.state = {
        request: invalid
        albums: []
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
    m.state.albums = []
    AsyncLifecycle_Begin(m.state.lifecycle, request.libraryId)
    updateTitleLabel(0)
    renderAlbums([])
    Spinner_Show(0)

    m.musicLibraryTask.request = request
    m.musicLibraryTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onMusicLibraryResponse
'-------------------------------------------------------------------------------
sub onMusicLibraryResponse()
    response = m.musicLibraryTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.state.lifecycle, response, "libraryId", "musicLibrary") <> true then return

    if response.ok <> true then
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load music library."))
        return
    end if

    m.state.albums = getItemsFromPayload(response.payload)
    renderAlbums(m.state.albums)
    updateTitleLabel(m.state.albums.Count())
    Status_ClearMessage()
    Spinner_Hide()
    focusAlbums()
end sub

'-------------------------------------------------------------------------------
' renderAlbums
'-------------------------------------------------------------------------------
sub renderAlbums(albums as object)
    content = CreateObject("roSGNode", "ContentNode")
    request = m.state.request

    for each album in albums
        if Array_IsAssocArray(album) = false then continue for

        child = content.createChild("ContentNode")
        child.title = FirstNonEmpty([album.Name], "Untitled Album")
        child.HDPosterUrl = getAlbumArtworkUrl(album, request)
        child.AddFields({
            artistName: getAlbumArtistName(album)
            raw: album
        })
    end for

    m.albumsGrid.content = content
end sub

'-------------------------------------------------------------------------------
' getAlbumArtworkUrl
'-------------------------------------------------------------------------------
function getAlbumArtworkUrl(album as dynamic, request as dynamic) as string
    if Array_IsAssocArray(album) = false then return ""
    if request = invalid then return ""

    directUrl = FirstNonEmpty([album.ImageURL, album.ImageUrl, album.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    itemId = SafeString(FirstNonEmpty([album.Id], ""), "")
    if itemId = "" then return ""

    primaryTag = ""
    if album.ImageTags <> invalid and album.ImageTags.Primary <> invalid then primaryTag = album.ImageTags.Primary
    if primaryTag = "" then return ""

    return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, 250, 250)
end function

'-------------------------------------------------------------------------------
' getAlbumArtistName
'-------------------------------------------------------------------------------
function getAlbumArtistName(album as dynamic) as string
    if Array_IsAssocArray(album) = false then return "Unknown Artist"

    artist = FirstNonEmpty([album.AlbumArtist, album.Artist], "")
    if artist <> "" then return artist

    artist = String_GetJoinedText(album.AlbumArtists)
    if artist <> "" then return artist

    artist = String_GetJoinedText(album.Artists)
    if artist <> "" then return artist

    return "Unknown Artist"
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if Array_IsAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items
    if payload.items <> invalid then return payload.items

    return []
end function

'-------------------------------------------------------------------------------
' updateTitleLabel
'-------------------------------------------------------------------------------
sub updateTitleLabel(albumCount = invalid as dynamic)
    title = "Music"
    if m.state <> invalid and m.state.request <> invalid then title = SafeString(m.state.request.title, "Music")
    if albumCount <> invalid and albumCount > 0 then title = title + " (" + albumCount.ToStr() + ")"

    m.titleLabel.text = title
end sub

'-------------------------------------------------------------------------------
' focusAlbums
'-------------------------------------------------------------------------------
sub focusAlbums()
    if m.albumsGrid.content = invalid or m.albumsGrid.content.getChildCount() = 0 then
        m.top.setFocus(true)
        return
    end if

    m.top.setFocus(true)
    m.albumsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.state.lifecycle, m.state.request, "libraryId")
    focusAlbums()
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.state.lifecycle)
    m.musicLibraryTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onAlbumSelected
'-------------------------------------------------------------------------------
sub onAlbumSelected()
    selected = m.albumsGrid.itemSelected
    if selected = invalid or selected < 0 then return
    if m.albumsGrid.content = invalid then return
    if selected >= m.albumsGrid.content.getChildCount() then return

    albumNode = m.albumsGrid.content.getChild(selected)
    if albumNode = invalid then return

    raw = albumNode.raw
    itemId = ""
    if raw <> invalid then itemId = SafeString(FirstNonEmpty([raw.Id], ""), "")
    if itemId = "" then return

    m.top.selectedAlbum = {
        itemId: itemId
        item: raw
    }
end sub

'-------------------------------------------------------------------------------
' isAlbumsGridAtFirstRow
'-------------------------------------------------------------------------------
function isAlbumsGridAtFirstRow() as boolean
    focusedIndex = m.albumsGrid.itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex < m.albumsGrid.numColumns
end function

'-------------------------------------------------------------------------------
' isFirstAlbumFocused
'-------------------------------------------------------------------------------
function isFirstAlbumFocused() as boolean
    focusedIndex = m.albumsGrid.itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex <= 0
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" and isAlbumsGridAtFirstRow() then
        m.top.focusExitUp = true
        return true
    end if

    if key = "back" then
        if isFirstAlbumFocused() <> true then
            m.albumsGrid.jumpToItem = 0
            return true
        end if

        m.top.closeRequested = true
        return true
    end if

    return false
end function

'===============================================================================
' MusicLibrary
'===============================================================================

'-------------------------------------------------------------------------------
' musicLibraryHandleHomeLibrarySelected
'-------------------------------------------------------------------------------
sub musicLibraryHandleHomeLibrarySelected()
    selection = m.homePage.selectedMusicLibrary
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    musicLibraryShow({
        libraryId: selection.libraryId
        collectionType: selection.collectionType
        title: FirstNonEmpty([selection.item.Name], "Music")
        item: selection.item
    })
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleHomeAlbumSelected
'-------------------------------------------------------------------------------
sub musicLibraryHandleHomeAlbumSelected()
    selection = m.homePage.selectedAlbum
    if selection = invalid then return

    musicAudioPlayerShow(selection, "home")
end sub

'-------------------------------------------------------------------------------
' musicLibraryShow
'-------------------------------------------------------------------------------
sub musicLibraryShow(selection as object)
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "MusicLibrary")
    page.observeField("closeRequested", "musicLibraryHandleCloseRequested")
    page.observeField("focusExitUp", "musicLibraryHandleFocusExitUp")
    page.observeField("overlayRequested", "musicLibraryHandleOverlayRequested")
    page.observeField("selectedAlbum", "musicLibraryHandleAlbumSelected")
    page.observeField("selectedArtist", "musicLibraryHandleArtistSelected")
    loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        accountKey: m.session.accountKey
        libraryId: selection.libraryId
        collectionType: SafeString(selection.collectionType, "")
        title: SafeString(selection.title, "Music")
        item: selection.item
    }

    resetDynamicPages()
    m.musicLibraryPage = page
    authAppendDynamicPage(page)
    m.homePage.visible = false
    m.header.visible = true
    page.loadRequest = loadRequest
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleFocusExitUp
'-------------------------------------------------------------------------------
sub musicLibraryHandleFocusExitUp()
    if m.header <> invalid and m.header.visible = true then
        m.header.callFunc("focusHeader")
    end if
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleOverlayRequested
'-------------------------------------------------------------------------------
sub musicLibraryHandleOverlayRequested()
    if m.musicLibraryPage = invalid then return

    request = m.musicLibraryPage.overlayRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleSortOverlayClosed
'-------------------------------------------------------------------------------
sub musicLibraryHandleSortOverlayClosed(closed as object)
    if m.musicLibraryPage = invalid then return

    overlay = closed.overlay
    if overlay <> invalid and overlay.sortSelected <> invalid then
        m.musicLibraryPage.callFunc("applySortSelection", overlay.sortSelected)
        optionKey = SafeString(overlay.sortSelected.optionKey, "")
        if optionKey = "Decade" or optionKey = "Genre" then
            if m.musicLibraryPage.callFunc("focusFilterButtonRow") = true then return
        end if
    end if

    m.musicLibraryPage.callFunc("focusBrowseByButton")
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleAlbumSelected
'-------------------------------------------------------------------------------
sub musicLibraryHandleAlbumSelected()
    if m.musicLibraryPage = invalid then return
    musicAudioPlayerShow(m.musicLibraryPage.selectedAlbum, "library")
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleArtistSelected
'-------------------------------------------------------------------------------
sub musicLibraryHandleArtistSelected()
    if m.musicLibraryPage = invalid then return
    selection = m.musicLibraryPage.selectedArtist
    if selection = invalid or SafeString(selection.itemId, "") = "" then return

    page = CreateObject("roSGNode", "MusicArtist")
    page.observeField("closeRequested", "musicArtistHandleCloseRequested")
    page.observeField("overlayRequested", "musicArtistHandleOverlayRequested")
    page.observeField("selectedAlbum", "musicArtistHandleAlbumSelected")
    page.loadRequest = {
        itemId: selection.itemId
        server: m.session.server
        musicBrainzArtistId: SafeString(selection.musicBrainzArtistId, "")
        item: selection.item
        albums: selection.albums
        backdropUrl: SafeString(selection.backdropUrl, "")
        logoUrl: SafeString(selection.logoUrl, "")
        settings: m.settings
    }

    m.musicArtistPage = page
    authAppendDynamicPage(page)
    m.musicLibraryPage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' musicArtistHandleAlbumSelected
'-------------------------------------------------------------------------------
sub musicArtistHandleAlbumSelected()
    if m.musicArtistPage = invalid then return
    musicAudioPlayerShow(m.musicArtistPage.selectedAlbum, "artist")
end sub

'-------------------------------------------------------------------------------
' musicAudioPlayerShow
'-------------------------------------------------------------------------------
sub musicAudioPlayerShow(selection as dynamic, sourcePage as string)
    if selection = invalid or SafeString(selection.itemId, "") = "" then return
    themeAudioStop()
    page = CreateObject("roSGNode", "AudioPlayer")
    page.observeField("closeRequested", "musicAudioPlayerHandleCloseRequested")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        albumId: selection.itemId
        item: selection.item
        sourcePage: sourcePage
    }
    if m.musicLibraryPage <> invalid then m.musicLibraryPage.visible = false
    if m.musicArtistPage <> invalid then m.musicArtistPage.visible = false
    if sourcePage = "home" then m.homePage.visible = false
    m.header.visible = false
    m.audioPlayerPage = page
    authAppendDynamicPage(page)
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' musicAudioPlayerHandleCloseRequested
'-------------------------------------------------------------------------------
sub musicAudioPlayerHandleCloseRequested()
    if m.audioPlayerPage = invalid then return
    request = m.audioPlayerPage.loadRequest
    m.audioPlayerPage.callFunc("deactivate")
    m.dynamicPageHost.removeChild(m.audioPlayerPage)
    m.audioPlayerPage = invalid
    if request <> invalid and request.sourcePage = "artist" and m.musicArtistPage <> invalid then
        m.musicArtistPage.visible = true
        m.musicArtistPage.callFunc("activate")
    else if m.musicLibraryPage <> invalid then
        m.musicLibraryPage.visible = true
        m.header.visible = true
        m.musicLibraryPage.callFunc("activate")
    else
        showHome()
    end if
end sub

'-------------------------------------------------------------------------------
' musicArtistHandleOverlayRequested
'-------------------------------------------------------------------------------
sub musicArtistHandleOverlayRequested()
    if m.musicArtistPage = invalid then return
    request = m.musicArtistPage.overlayRequested
    if request = invalid then return
    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' musicArtistHandleCloseRequested
'-------------------------------------------------------------------------------
sub musicArtistHandleCloseRequested()
    clearStatus()
    if m.musicArtistPage <> invalid then
        m.musicArtistPage.callFunc("deactivate")
        m.dynamicPageHost.removeChild(m.musicArtistPage)
        m.musicArtistPage = invalid
    end if

    if m.musicLibraryPage <> invalid then
        m.musicLibraryPage.visible = true
        m.header.visible = true
        m.musicLibraryPage.callFunc("activate")
    else
        showHome()
    end if
end sub

'-------------------------------------------------------------------------------
' musicLibraryHandleCloseRequested
'-------------------------------------------------------------------------------
sub musicLibraryHandleCloseRequested()
    clearStatus()
    if m.musicLibraryPage <> invalid then
        m.musicLibraryPage.callFunc("deactivate")
        m.dynamicPageHost.removeChild(m.musicLibraryPage)
        m.musicLibraryPage = invalid
    end if

    showHome()
end sub

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
' musicLibraryShow
'-------------------------------------------------------------------------------
sub musicLibraryShow(selection as object)
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "MusicLibrary")
    page.observeField("closeRequested", "musicLibraryHandleCloseRequested")
    page.observeField("focusExitUp", "musicLibraryHandleFocusExitUp")
    page.observeField("selectedAlbum", "musicLibraryHandleAlbumSelected")
    loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        collectionType: SafeString(selection.collectionType, "")
        title: SafeString(selection.title, "Music")
        item: selection.item
    }

    resetDynamicPages()
    m.musicLibraryPage = page
    m.dynamicPageHost.appendChild(page)
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
' musicLibraryHandleAlbumSelected
'-------------------------------------------------------------------------------
sub musicLibraryHandleAlbumSelected()
    ' Album detail and playback are intentionally left for the next music slice.
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

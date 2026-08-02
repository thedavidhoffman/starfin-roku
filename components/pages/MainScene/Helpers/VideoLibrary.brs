'===============================================================================
' VideoLibrary
'===============================================================================

'-------------------------------------------------------------------------------
' videoLibraryHandleHomeLibrarySelected
'-------------------------------------------------------------------------------
sub videoLibraryHandleHomeLibrarySelected()
    selection = m.homePage.selectedLibrary
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    videoLibraryShow({
        libraryId: selection.libraryId
        collectionType: selection.collectionType
        title: FirstNonEmpty([selection.item.Name], "Library")
        item: selection.item
    }, false)
end sub

'-------------------------------------------------------------------------------
' videoLibraryShow
'-------------------------------------------------------------------------------
sub videoLibraryShow(selection as object, fromCollections as boolean)
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "VideoLibrary")
    page.observeField("closeRequested", "videoLibraryHandleCloseRequested")
    page.observeField("letterGridRequested", "videoLibraryHandleLetterGridRequested")
    page.observeField("overlayRequested", "videoLibraryHandleOverlayRequested")
    page.observeField("selectedMovie", "videoLibraryHandleMovieSelected")
    page.observeField("selectedSeries", "videoLibraryHandleSeriesSelected")
    page.observeField("focusExitUp", "videoLibraryHandleFocusExitUp")
    page.observeField("thumbnailLayoutActive", "videoLibraryHandleThumbnailLayoutChanged")
    page.settings = m.settings
    loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        collectionType: SafeString(selection.collectionType, "")
        includeItemTypes: getVideoLibraryIncludeItemTypes(SafeString(selection.collectionType, ""))
        title: SafeString(selection.title, "Library")
        item: selection.item
        fromCollections: fromCollections
    }

    if fromCollections <> true then resetDynamicPages()
    m.videoLibraryPage = page
    m.header.thumbnailLibraryLayout = page.thumbnailLayoutActive
    m.dynamicPageHost.appendChild(page)
    if m.collectionsPage <> invalid then m.collectionsPage.visible = false
    m.homePage.visible = false
    m.header.visible = true
    page.loadRequest = loadRequest
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleThumbnailLayoutChanged
'-------------------------------------------------------------------------------
sub videoLibraryHandleThumbnailLayoutChanged()
    if m.videoLibraryPage = invalid then return

    m.header.thumbnailLibraryLayout = m.videoLibraryPage.thumbnailLayoutActive
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleFocusExitUp
'-------------------------------------------------------------------------------
sub videoLibraryHandleFocusExitUp()
    if m.header <> invalid and m.header.visible = true then
        m.header.callFunc("focusHeader")
    end if
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleOverlayRequested
'-------------------------------------------------------------------------------
sub videoLibraryHandleOverlayRequested()
    if m.videoLibraryPage = invalid then return

    request = m.videoLibraryPage.overlayRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleLetterGridRequested
'-------------------------------------------------------------------------------
sub videoLibraryHandleLetterGridRequested()
    if m.videoLibraryPage = invalid then return

    request = m.videoLibraryPage.letterGridRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleLetterGridOverlayClosed
'-------------------------------------------------------------------------------
sub videoLibraryHandleLetterGridOverlayClosed(closed as object)
    if m.videoLibraryPage = invalid then return

    overlay = closed.overlay
    letter = ""
    if overlay <> invalid then letter = SafeString(overlay.letterSelected, "")

    if letter <> "" then
        m.videoLibraryPage.callFunc("selectLetter", letter)
    else
        m.videoLibraryPage.callFunc("closeLetterGrid", true)
    end if
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleSortOverlayClosed
'-------------------------------------------------------------------------------
sub videoLibraryHandleSortOverlayClosed(closed as object)
    if m.videoLibraryPage = invalid then return

    overlay = closed.overlay
    if overlay <> invalid and overlay.sortSelected <> invalid then
        m.videoLibraryPage.callFunc("applySortSelection", overlay.sortSelected)
        optionKey = SafeString(overlay.sortSelected.optionKey, "")
        if optionKey = "Decade" or optionKey = "Genre" then
            if m.videoLibraryPage.callFunc("focusFilterButtonRow") = true then return
        end if
    end if

    m.videoLibraryPage.callFunc("focusBrowseByButton")
end sub

'-------------------------------------------------------------------------------
' getVideoLibraryIncludeItemTypes
'-------------------------------------------------------------------------------
function getVideoLibraryIncludeItemTypes(collectionType as string) as string
    if collectionType = "tvshows" then return "Series"
    if collectionType = "collection" then return "Movie,Series"
    return "Movie"
end function

'-------------------------------------------------------------------------------
' videoLibraryHandleMovieSelected
'-------------------------------------------------------------------------------
sub videoLibraryHandleMovieSelected()
    selection = m.videoLibraryPage.selectedMovie
    if selection = invalid then return
    if m.videoLibraryPage <> invalid then m.videoLibraryPage.callFunc("deactivate")
    movieShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleSeriesSelected
'-------------------------------------------------------------------------------
sub videoLibraryHandleSeriesSelected()
    selection = m.videoLibraryPage.selectedSeries
    if selection = invalid then return
    if m.videoLibraryPage <> invalid then m.videoLibraryPage.callFunc("deactivate")
    tvShowShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' videoLibraryHandleCloseRequested
'-------------------------------------------------------------------------------
sub videoLibraryHandleCloseRequested()
    clearStatus()
    if m.videoLibraryPage <> invalid then
        m.videoLibraryPage.callFunc("deactivate")
        m.dynamicPageHost.removeChild(m.videoLibraryPage)
        m.videoLibraryPage = invalid
    end if

    if m.collectionsPage <> invalid then
        m.collectionsPage.visible = true
        m.collectionsPage.callFunc("activate")
    else
        showHome()
    end if
end sub

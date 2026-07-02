'===============================================================================
' Library
'===============================================================================

'-------------------------------------------------------------------------------
' libraryHandleHomeLibrarySelected
'-------------------------------------------------------------------------------
sub libraryHandleHomeLibrarySelected()
    selection = m.homePage.selectedLibrary
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    libraryShow({
        libraryId: selection.libraryId
        collectionType: selection.collectionType
        title: FirstNonEmpty([selection.item.Name], "Library")
        item: selection.item
    }, false)
end sub

'-------------------------------------------------------------------------------
' libraryShow
'-------------------------------------------------------------------------------
sub libraryShow(selection as object, fromCollections as boolean)
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "Library")
    page.observeField("closeRequested", "libraryHandleCloseRequested")
    page.observeField("letterGridRequested", "libraryHandleLetterGridRequested")
    page.observeField("overlayRequested", "libraryHandleOverlayRequested")
    page.observeField("selectedMovie", "libraryHandleMovieSelected")
    page.observeField("selectedSeries", "libraryHandleSeriesSelected")
    page.settings = m.settings
    loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        collectionType: SafeString(selection.collectionType, "")
        includeItemTypes: getLibraryIncludeItemTypes(SafeString(selection.collectionType, ""))
        title: SafeString(selection.title, "Library")
        item: selection.item
        fromCollections: fromCollections
    }

    if fromCollections <> true then resetDynamicPages()
    m.libraryPage = page
    m.dynamicPageHost.appendChild(page)
    if m.collectionsPage <> invalid then m.collectionsPage.visible = false
    m.homePage.visible = false
    m.header.visible = true
    page.loadRequest = loadRequest
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' libraryHandleOverlayRequested
'-------------------------------------------------------------------------------
sub libraryHandleOverlayRequested()
    if m.libraryPage = invalid then return

    request = m.libraryPage.overlayRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' libraryHandleLetterGridRequested
'-------------------------------------------------------------------------------
sub libraryHandleLetterGridRequested()
    if m.libraryPage = invalid then return

    request = m.libraryPage.letterGridRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' libraryHandleLetterGridOverlayClosed
'-------------------------------------------------------------------------------
sub libraryHandleLetterGridOverlayClosed(closed as object)
    if m.libraryPage = invalid then return

    overlay = closed.overlay
    letter = ""
    if overlay <> invalid then letter = SafeString(overlay.letterSelected, "")

    if letter <> "" then
        m.libraryPage.callFunc("selectLetter", letter)
    else
        m.libraryPage.callFunc("closeLetterGrid", true)
    end if
end sub

'-------------------------------------------------------------------------------
' libraryHandleSortOverlayClosed
'-------------------------------------------------------------------------------
sub libraryHandleSortOverlayClosed(closed as object)
    if m.libraryPage = invalid then return

    overlay = closed.overlay
    if overlay <> invalid and overlay.sortSelected <> invalid then
        sortChanged = m.libraryPage.callFunc("applySortSelection", overlay.sortSelected)
        if sortChanged = true then m.libraryPage.callFunc("reloadLibraryForSort")
    end if

    m.libraryPage.callFunc("focusSortButton")
end sub

'-------------------------------------------------------------------------------
' getLibraryIncludeItemTypes
'-------------------------------------------------------------------------------
function getLibraryIncludeItemTypes(collectionType as string) as string
    if collectionType = "tvshows" then return "Series"
    if collectionType = "collection" then return "Movie,Series"
    return "Movie"
end function

'-------------------------------------------------------------------------------
' libraryHandleMovieSelected
'-------------------------------------------------------------------------------
sub libraryHandleMovieSelected()
    selection = m.libraryPage.selectedMovie
    if selection = invalid then return
    movieShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' libraryHandleSeriesSelected
'-------------------------------------------------------------------------------
sub libraryHandleSeriesSelected()
    selection = m.libraryPage.selectedSeries
    if selection = invalid then return
    tvShowShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' libraryHandleCloseRequested
'-------------------------------------------------------------------------------
sub libraryHandleCloseRequested()
    clearStatus()
    if m.libraryPage <> invalid then
        m.dynamicPageHost.removeChild(m.libraryPage)
        m.libraryPage = invalid
    end if

    if m.collectionsPage <> invalid then
        m.collectionsPage.visible = true
        m.collectionsPage.callFunc("activate")
    else
        showHome()
    end if
end sub

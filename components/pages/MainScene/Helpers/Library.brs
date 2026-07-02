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

'===============================================================================
' Collections
'===============================================================================

'-------------------------------------------------------------------------------
' collectionsHandleHomeCollectionsSelected
'-------------------------------------------------------------------------------
sub collectionsHandleHomeCollectionsSelected()
    selection = m.homePage.selectedCollections
    if selection = invalid then return
    if selection.libraryId = invalid or selection.libraryId = "" then return

    page = CreateObject("roSGNode", "Collections")
    page.observeField("closeRequested", "collectionsHandleCloseRequested")
    page.observeField("selectedCollection", "collectionsHandleCollectionSelected")
    page.settings = m.settings

    resetDynamicPages()
    m.collectionsPage = page
    m.dynamicPageHost.appendChild(page)
    m.homePage.visible = false
    m.header.visible = true
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        libraryId: selection.libraryId
        title: FirstNonEmpty([selection.item.Name], "Collections")
        item: selection.item
    }
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' collectionsHandleCollectionSelected
'-------------------------------------------------------------------------------
sub collectionsHandleCollectionSelected()
    selection = m.collectionsPage.selectedCollection
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    if m.collectionsPage <> invalid then m.collectionsPage.callFunc("deactivate")
    videoLibraryShow({
        libraryId: selection.itemId
        collectionType: "collection"
        title: FirstNonEmpty([selection.item.Name], "Collection")
        item: selection.item
    }, true)
end sub

'-------------------------------------------------------------------------------
' collectionsHandleCloseRequested
'-------------------------------------------------------------------------------
sub collectionsHandleCloseRequested()
    clearStatus()
    if m.collectionsPage <> invalid then m.collectionsPage.callFunc("deactivate")
    resetDynamicPages()
    showHome()
end sub

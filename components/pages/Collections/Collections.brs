'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Collections")
    m.titleLabel = m.top.findNode("titleLabel")
    m.collectionsGrid = m.top.findNode("collectionsGrid")
    m.collectionsTask = m.top.findNode("collectionsTask")

    m.collectionsTask.observeField("response", "onCollectionsResponse")
    m.collectionsGrid.observeField("itemSelected", "onCollectionSelected")
    m.pageState = {
        request: invalid
        collections: []
        navigationStack: []
        pendingDrilldown: invalid
        imageAspect: "poster"
        lifecycle: AsyncLifecycle_Create()
    }
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    m.pageState.imageAspect = getCollectionImageAspect()
    applyGridLayout(m.pageState.imageAspect)
    renderCollections(m.pageState.collections)
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    AsyncLifecycle_Begin(m.pageState.lifecycle, request.libraryId)
    m.pageState.navigationStack = []
    m.pageState.pendingDrilldown = invalid
    m.pageState.imageAspect = getCollectionImageAspect()
    m.titleLabel.text = SafeString(request.title, "Collections")
    applyGridLayout(m.pageState.imageAspect)
    Spinner_Show()
    renderCollections([])

    m.collectionsTask.request = request
    m.collectionsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onCollectionsResponse
'-------------------------------------------------------------------------------
sub onCollectionsResponse()
    response = m.collectionsTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.pageState.lifecycle, response, "libraryId", "collections") <> true then return

    if SafeString(response.mode, "load") = "drilldown" then
        handleDrilldownResponse(response)
        return
    end if

    if response.ok <> true then
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load collections."))
        return
    end if

    m.pageState.collections = filterRootCollections(getCollectionsFromPayload(response.payload))
    renderCollections(m.pageState.collections)
    Spinner_Hide()
    Status_ClearMessage()
    focusCollectionsIfActive()
end sub

'-------------------------------------------------------------------------------
' onCollectionSelected
'-------------------------------------------------------------------------------
sub onCollectionSelected()
    selected = m.collectionsGrid.itemSelected
    if selected = invalid then return
    if m.collectionsGrid.content = invalid then return

    node = m.collectionsGrid.content.getChild(selected)
    if node = invalid then return

    item = node.raw
    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if itemId = "" then return

    loadChildCollections(itemId, item)
end sub

'-------------------------------------------------------------------------------
' loadChildCollections
'-------------------------------------------------------------------------------
sub loadChildCollections(itemId as string, item as object)
    request = m.pageState.request
    if request = invalid then return

    title = FirstNonEmpty([item.Name], "Collection")
    childRequest = {
        server: request.server
        token: request.token
        userId: request.userId
        libraryId: itemId
        title: title
        item: item
        mode: "drilldown"
        recursive: false
        includeItemTypes: ""
    }

    m.pageState.pendingDrilldown = {
        itemId: itemId
        item: item
        request: childRequest
    }
    AsyncLifecycle_Begin(m.pageState.lifecycle, itemId)
    Spinner_Show(0)
    Status_ClearMessage()
    m.collectionsTask.control = "stop"
    m.collectionsTask.request = childRequest
    m.collectionsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' handleDrilldownResponse
'-------------------------------------------------------------------------------
sub handleDrilldownResponse(response as object)
    Spinner_Hide()

    pending = m.pageState.pendingDrilldown
    m.pageState.pendingDrilldown = invalid
    if pending = invalid then return

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load collection."))
        return
    end if

    collections = getCollectionsFromPayload(response.payload)
    if collections.Count() = 0 then
        Status_ClearMessage()
        openSelectedCollection(pending.itemId, pending.item)
        return
    end if

    pushCollectionNavigationState()
    m.pageState.request = pending.request
    m.pageState.collections = collections
    m.titleLabel.text = SafeString(pending.request.title, "Collections")
    renderCollections(collections)
    Status_ClearMessage()
    focusCollectionsIfActive()
end sub

'-------------------------------------------------------------------------------
' pushCollectionNavigationState
'-------------------------------------------------------------------------------
sub pushCollectionNavigationState()
    m.pageState.navigationStack.Push({
        request: m.pageState.request
        collections: m.pageState.collections
        title: SafeString(m.titleLabel.text, "Collections")
    })
end sub

'-------------------------------------------------------------------------------
' navigateBackToParentCollection
'-------------------------------------------------------------------------------
function navigateBackToParentCollection() as boolean
    if m.pageState.navigationStack = invalid then return false
    if m.pageState.navigationStack.Count() = 0 then return false

    lastIndex = m.pageState.navigationStack.Count() - 1
    previous = m.pageState.navigationStack[lastIndex]
    m.pageState.navigationStack.Delete(lastIndex)

    m.pageState.pendingDrilldown = invalid
    m.collectionsTask.control = "stop"
    m.pageState.request = previous.request
    AsyncLifecycle_Begin(m.pageState.lifecycle, previous.request.libraryId)
    m.pageState.collections = previous.collections
    m.titleLabel.text = SafeString(previous.title, "Collections")
    renderCollections(m.pageState.collections)
    Status_ClearMessage()
    focusCollectionsIfActive()
    return true
end function

'-------------------------------------------------------------------------------
' openSelectedCollection
'-------------------------------------------------------------------------------
sub openSelectedCollection(itemId as string, item as object)
    m.top.selectedCollection = {
        itemId: itemId
        item: item
    }
end sub

'-------------------------------------------------------------------------------
' renderCollections
'-------------------------------------------------------------------------------
sub renderCollections(collections as object)
    content = CreateObject("roSGNode", "ContentNode")
    imageAspect = m.pageState.imageAspect

    for each item in collections
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item, imageAspect)
        child.AddFields({
            imageAspect: imageAspect
            showSubtitle: false
            raw: item
        })
    end for

    m.collectionsGrid.content = content
    m.collectionsGrid.visible = content.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.pageState.lifecycle, m.pageState.request, "libraryId")
    m.top.setFocus(true)
    focusCollectionsIfActive()
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.pageState.lifecycle)
    m.pageState.pendingDrilldown = invalid
    m.collectionsTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' focusCollectionsIfActive
'-------------------------------------------------------------------------------
sub focusCollectionsIfActive()
    if m.collectionsGrid.visible <> true then return
    if m.collectionsGrid.content = invalid then return
    if m.collectionsGrid.content.getChildCount() = 0 then return

    m.collectionsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    if imageAspect = "wide" then
        imageUrl = getImageUrlForType(itemId, item, "Thumb", 440, 248)
        if imageUrl <> "" then return imageUrl

        imageUrl = getImageUrlForType(itemId, item, "Backdrop", 440, 248)
        if imageUrl <> "" then return imageUrl

        return getImageUrlForType(itemId, item, "Primary", 440, 248)
    end if

    return getImageUrlForType(itemId, item, "Primary", 250, 375)
end function

'-------------------------------------------------------------------------------
' getImageUrlForType
'-------------------------------------------------------------------------------
function getImageUrlForType(itemId as string, item as dynamic, imageType as string, width as integer, height as integer) as string
    tag = getImageTag(item, imageType)
    if tag = "" then return ""

    request = m.pageState.request
    if request = invalid then return ""

    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' getImageTag
'-------------------------------------------------------------------------------
function getImageTag(item as dynamic, imageType as string) as string
    if item = invalid then return ""

    if imageType = "Backdrop" then
        if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then return item.BackdropImageTags[0]
        return ""
    end if

    if item.ImageTags = invalid then return ""
    if imageType = "Primary" and item.ImageTags.Primary <> invalid then return item.ImageTags.Primary
    if imageType = "Thumb" and item.ImageTags.Thumb <> invalid then return item.ImageTags.Thumb

    return ""
end function

'-------------------------------------------------------------------------------
' getCollectionImageAspect
'-------------------------------------------------------------------------------
function getCollectionImageAspect() as string
    keys = SettingsStore_Keys()
    value = m.top.settings[keys.collectionDisplay]

    if LCase(value) = "thumbnail" then return "wide"
    return "poster"
end function

'-------------------------------------------------------------------------------
' applyGridLayout
'-------------------------------------------------------------------------------
sub applyGridLayout(imageAspect as string)
    if imageAspect = "wide" then
        m.titleLabel.translation = [23, 120]
        m.collectionsGrid.translation = [23, 208]
        m.collectionsGrid.itemSize = [465, 348]
        m.collectionsGrid.itemSpacing = [0, 11]
        m.collectionsGrid.numColumns = 4
        m.collectionsGrid.numRows = 3
        m.collectionsGrid.focusBitmapUri = "pkg:/images/library/thumbnail-focus-465x348.png"
        return
    end if

    m.titleLabel.translation = [96, 120]
    m.collectionsGrid.translation = [96, 208]
    m.collectionsGrid.itemSize = [295, 463]
    m.collectionsGrid.itemSpacing = [-11, 26]
    m.collectionsGrid.numColumns = 6
    m.collectionsGrid.numRows = 2
    m.collectionsGrid.focusBitmapUri = "pkg:/images/library/poster-focus-295x463.png"
end sub

' getCollectionsFromPayload
'-------------------------------------------------------------------------------
function getCollectionsFromPayload(payload as dynamic) as object
    return filterCollectionItems(getItemsFromPayload(payload))
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if isAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items
    return []
end function

'-------------------------------------------------------------------------------
' filterCollectionItems
'-------------------------------------------------------------------------------
function filterCollectionItems(items as object) as object
    collections = []
    for each item in items
        if isCollectionItem(item) then collections.Push(item)
    end for

    return collections
end function

'-------------------------------------------------------------------------------
' filterRootCollections
'-------------------------------------------------------------------------------
function filterRootCollections(collections as object) as object
    topCollections = []
    for each item in collections
        if hasTopTag(item) then topCollections.Push(item)
    end for

    if topCollections.Count() > 0 then return topCollections
    return collections
end function

'-------------------------------------------------------------------------------
' hasTopTag
'-------------------------------------------------------------------------------
function hasTopTag(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    if item.Tags = invalid then return false
    if Type(item.Tags) <> "roArray" then return false

    for each tag in item.Tags
        if LCase(SafeString(tag, "")) = "top" then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' isCollectionItem
'-------------------------------------------------------------------------------
function isCollectionItem(item as dynamic) as boolean
    if isAssocArray(item) = false then return false

    return LCase(SafeString(item.Type, "")) = "boxset"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if key = "back" then
        if navigateBackToParentCollection() then return true

        m.top.closeRequested = true
        return true
    end if
    return false
end function

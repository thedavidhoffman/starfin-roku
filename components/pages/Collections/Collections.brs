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
        imageAspect: "poster"
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
    m.pageState.imageAspect = getCollectionImageAspect()
    m.titleLabel.text = SafeString(request.title, "Collections")
    applyGridLayout(m.pageState.imageAspect)
    Status_SetLoading()
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

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load collections."))
        return
    end if

    m.pageState.collections = getItemsFromPayload(response.payload)
    renderCollections(m.pageState.collections)
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
    m.top.setFocus(true)
    focusCollectionsIfActive()
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

    return buildImageUrl(itemId, imageType, tag, width, height)
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
        m.collectionsGrid.itemSize = [485, 348]
        m.collectionsGrid.itemSpacing = [34, 26]
        m.collectionsGrid.numColumns = 3
        m.collectionsGrid.numRows = 2
        m.collectionsGrid.focusBitmapUri = "pkg:/images/library/library-thumbnail-focus-485x348.png"
        return
    end if

    m.collectionsGrid.itemSize = [295, 463]
    m.collectionsGrid.itemSpacing = [-11, 26]
    m.collectionsGrid.numColumns = 6
    m.collectionsGrid.numRows = 2
    m.collectionsGrid.focusBitmapUri = "pkg:/images/library/library-poster-focus-295x463.png"
end sub

'-------------------------------------------------------------------------------
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.pageState.request
    if request = invalid then return ""

    return NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if isAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items
    if payload.items <> invalid then return payload.items
    return []
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
        m.top.closeRequested = true
        return true
    end if
    return false
end function

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
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.titleLabel.text = SafeString(request.title, "Collections")
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

    for each item in collections
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item)
        child.AddFields({
            imageAspect: "poster"
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
function getItemImageUrl(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id], "")
    tag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then tag = item.ImageTags.Primary
    if itemId <> "" and tag <> "" then return buildImageUrl(itemId, "Primary", tag, 250, 375)

    return ""
end function

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

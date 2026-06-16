'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Library")
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.itemsGrid = m.top.findNode("itemsGrid")
    m.libraryTask = m.top.findNode("libraryTask")

    m.libraryTask.observeField("response", "onLibraryResponse")
    m.itemsGrid.observeField("itemSelected", "onItemSelected")
    m.pageState = {
        request: invalid
        items: []
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.titleLabel.text = SafeString(request.title, "Library")
    setStatus("Loading library...")
    renderItems([])

    m.libraryTask.request = request
    m.libraryTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onLibraryResponse
'-------------------------------------------------------------------------------
sub onLibraryResponse()
    response = m.libraryTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load library."))
        return
    end if

    m.pageState.items = getItemsFromPayload(response.payload)
    renderItems(m.pageState.items)
    setStatus("")
    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' onItemSelected
'-------------------------------------------------------------------------------
sub onItemSelected()
    selected = m.itemsGrid.itemSelected
    if selected = invalid then return
    if m.itemsGrid.content = invalid then return

    node = m.itemsGrid.content.getChild(selected)
    if node = invalid then return

    item = node.raw
    itemId = SafeString(FirstNonEmpty([item.Id, item.id, node.itemId], ""), "")
    if itemId = "" then return

    if isPlayableMovie(item) then
        m.top.selectedMovie = { itemId: itemId, item: item }
    else if isTVSeries(item) then
        m.top.selectedSeries = { itemId: itemId, item: item }
    end if
end sub

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems(items as object)
    content = CreateObject("roSGNode", "ContentNode")

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.title = getItemTitle(item)
        child.HDPosterUrl = getItemImageUrl(item)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
            itemType: SafeString(FirstNonEmpty([item.Type, item.type], ""), "")
            imageAspect: "poster"
            raw: item
        })
    end for

    m.itemsGrid.content = content
    m.itemsGrid.visible = content.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusItemsIfActive
'-------------------------------------------------------------------------------
sub focusItemsIfActive()
    if m.itemsGrid.visible <> true then return
    if m.itemsGrid.content = invalid then return
    if m.itemsGrid.content.getChildCount() = 0 then return

    m.itemsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.Name, item.name, item.title], "Untitled")
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id, item.id], "")
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
' isPlayableMovie
'-------------------------------------------------------------------------------
function isPlayableMovie(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    itemType = LCase(FirstNonEmpty([item.Type, item.type], ""))
    return itemType = "movie" or itemType = "video"
end function

'-------------------------------------------------------------------------------
' isTVSeries
'-------------------------------------------------------------------------------
function isTVSeries(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    return LCase(FirstNonEmpty([item.Type, item.type], "")) = "series"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' setStatus
'-------------------------------------------------------------------------------
sub setStatus(message as string)
    m.statusLabel.text = message
    m.statusLabel.visible = message <> ""
end sub

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

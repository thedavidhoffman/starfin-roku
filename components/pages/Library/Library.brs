'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Library")
    m.titleLabel = m.top.findNode("titleLabel")
    m.itemsGrid = m.top.findNode("itemsGrid")
    m.libraryTask = m.top.findNode("libraryTask")

    m.libraryTask.observeField("response", "onLibraryResponse")
    m.itemsGrid.observeField("itemSelected", "onItemSelected")
    m.pageState = {
        request: invalid
        items: []
        imageAspect: "poster"
    }
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    m.pageState.imageAspect = getLibraryImageAspect()
    applyGridLayout(m.pageState.imageAspect)
    renderItems(m.pageState.items)
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.imageAspect = getLibraryImageAspect()
    m.titleLabel.text = SafeString(request.title, "Library")
    applyGridLayout(m.pageState.imageAspect)
    Status_SetLoading()
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
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load library."))
        return
    end if

    m.pageState.items = getItemsFromPayload(response.payload)
    renderItems(m.pageState.items)
    Status_ClearMessage()
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
    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
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
    imageAspect = m.pageState.imageAspect

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item, imageAspect)
        child.AddFields({
            imageAspect: imageAspect
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
' getLibraryImageAspect
'-------------------------------------------------------------------------------
function getLibraryImageAspect() as string
    settings = m.top.settings
    keys = SettingsStore_Keys()
    settingKey = keys.movieLibraryDisplay

    request = m.pageState.request
    collectionType = ""
    if request <> invalid then collectionType = SafeString(request.collectionType, "")

    if collectionType = "tvshows" then
        settingKey = keys.tvLibraryDisplay
    else if collectionType = "collection" then
        settingKey = keys.collectionDisplay
    end if

    if LCase(settings[settingKey]) = "thumbnail" then return "wide"
    return "poster"
end function

'-------------------------------------------------------------------------------
' applyGridLayout
'-------------------------------------------------------------------------------
sub applyGridLayout(imageAspect as string)
    if imageAspect = "wide" then
        m.titleLabel.translation = [23, 120]
        m.itemsGrid.translation = [23, 208]
        m.itemsGrid.itemSize = [465, 348]
        m.itemsGrid.itemSpacing = [0, 11]
        m.itemsGrid.numColumns = 4
        m.itemsGrid.numRows = 3
        m.itemsGrid.focusBitmapUri = "pkg:/images/library/library-thumbnail-focus-465x348.png"
        return
    end if

    m.titleLabel.translation = [96, 120]
    m.itemsGrid.translation = [96, 208]
    m.itemsGrid.itemSize = [295, 463]
    m.itemsGrid.itemSpacing = [-11, 26]
    m.itemsGrid.numColumns = 6
    m.itemsGrid.numRows = 2
    m.itemsGrid.focusBitmapUri = "pkg:/images/library/library-poster-focus-295x463.png"
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
' isPlayableMovie
'-------------------------------------------------------------------------------
function isPlayableMovie(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    itemType = LCase(FirstNonEmpty([item.Type], ""))
    return itemType = "movie" or itemType = "video"
end function

'-------------------------------------------------------------------------------
' isTVSeries
'-------------------------------------------------------------------------------
function isTVSeries(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    return LCase(FirstNonEmpty([item.Type], "")) = "series"
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

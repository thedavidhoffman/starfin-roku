'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("HomePage")
    m.shelvesGroup = m.top.findNode("shelvesGroup")
    m.shelvesAnimation = m.top.findNode("shelvesAnimation")
    m.shelvesTranslation = m.top.findNode("shelvesTranslation")

    m.tasks = {
        libraries: m.top.findNode("librariesTask")
        continueWatching: m.top.findNode("continueWatchingTask")
        continueListening: m.top.findNode("continueListeningTask")
        nextUp: m.top.findNode("nextUpTask")
        latestMedia: m.top.findNode("latestMediaTask")
        liveTvOnNow: m.top.findNode("liveTvOnNowTask")
        myList: m.top.findNode("myListTask")
        favorites: m.top.findNode("favoritesTask")
    }

    m.tasks.libraries.observeField("response", "onLibrariesResponse")
    m.tasks.continueWatching.observeField("response", "onSectionResponse")
    m.tasks.continueListening.observeField("response", "onSectionResponse")
    m.tasks.nextUp.observeField("response", "onSectionResponse")
    m.tasks.liveTvOnNow.observeField("response", "onSectionResponse")
    m.tasks.myList.observeField("response", "onSectionResponse")
    m.tasks.favorites.observeField("response", "onSectionResponse")
    m.homeState = {
        request: invalid
        rows: {}
        rowOrder: ["libraries", "continueWatching", "continueListening", "nextUp", "liveTvOnNow", "myList", "favorites"]
        latestLibraries: {}
        latestTasks: []
        shelfNodes: []
        shelfPositions: []
        focusedShelfIndex: 0
        shelfOffsetY: 0
        refresh: {
            blocking: false
            pendingCore: {}
        }
    }
end sub

'-------------------------------------------------------------------------------
' onHomeShelfSelected
'-------------------------------------------------------------------------------
sub onHomeShelfSelected(event as object)
    selection = event.getData()
    if selection = invalid then return

    item = selection.item
    selectHomeItem(item)
end sub

'-------------------------------------------------------------------------------
' selectHomeItem
'-------------------------------------------------------------------------------
sub selectHomeItem(item as dynamic)
    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if itemId = "" then return

    if isCollectionsLibrary(item) then
        m.top.selectedCollections = {
            libraryId: itemId
            item: item
        }
    else if isMediaLibrary(item) then
        m.top.selectedLibrary = {
            libraryId: itemId
            collectionType: item.CollectionType
            item: item
        }
    else if isTVEpisode(item) then
        m.top.selectedEpisode = {
            itemId: itemId
            item: item
        }
    else if isPlayableMovie(item) then
        m.top.selectedMovie = {
            itemId: itemId
            item: item
        }
    else if isTVSeries(item) then
        m.top.selectedSeries = {
            itemId: itemId
            item: item
        }
    end if
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    refreshHomeData(false)
end sub

'-------------------------------------------------------------------------------
' activateBlocking
'-------------------------------------------------------------------------------
sub activateBlocking()
    refreshPlaybackRows(true)
end sub

'-------------------------------------------------------------------------------
' focusHome
'-------------------------------------------------------------------------------
sub focusHome()
    if m.homeState.shelfNodes.Count() > 0 then
        focusShelf(m.homeState.focusedShelfIndex)
    else
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.homeState.request = request
end sub

'-------------------------------------------------------------------------------
' refreshHomeData
'-------------------------------------------------------------------------------
sub refreshHomeData(blocking = false as boolean)
    request = m.homeState.request
    if request = invalid then
        m.top.setFocus(true)
        return
    end if

    m.homeState.refresh = {
        blocking: blocking
        pendingCore: {
            libraries: true
            continueWatching: true
            continueListening: true
            nextUp: true
            liveTvOnNow: true
            favorites: true
        }
    }
    if blocking = true then
        m.top.visible = false
        Spinner_Show()
    end if

    m.homeState.rows = {}
    m.homeState.rowOrder = ["libraries", "continueWatching", "continueListening", "nextUp", "liveTvOnNow", "myList", "favorites"]
    m.homeState.latestLibraries = {}
    m.homeState.latestTasks = []
    m.homeState.shelfNodes = []
    m.homeState.shelfPositions = []
    m.homeState.focusedShelfIndex = 0
    m.homeState.shelfOffsetY = 0

    clearRows()
    Status_SetLoading()

    runTask(m.tasks.libraries, request)
    runTask(m.tasks.continueWatching, request)
    runTask(m.tasks.continueListening, request)
    runTask(m.tasks.nextUp, request)
    runTask(m.tasks.liveTvOnNow, request)
    runTask(m.tasks.favorites, request)
end sub

'-------------------------------------------------------------------------------
' refreshPlaybackRows
'-------------------------------------------------------------------------------
sub refreshPlaybackRows(blocking = false as boolean)
    request = m.homeState.request
    if request = invalid then
        m.top.setFocus(true)
        return
    end if

    m.homeState.refresh = {
        blocking: blocking
        pendingCore: {
            continueWatching: true
            nextUp: true
        }
    }
    if blocking = true then
        m.top.visible = false
        Spinner_Show()
    end if

    runTask(m.tasks.continueWatching, request)
    runTask(m.tasks.nextUp, request)
end sub

'-------------------------------------------------------------------------------
' runTask
'-------------------------------------------------------------------------------
sub runTask(task as object, request as object)
    if task = invalid then return

    task.request = request
    task.control = "run"
end sub

'-------------------------------------------------------------------------------
' onLibrariesResponse
'-------------------------------------------------------------------------------
sub onLibrariesResponse()
    response = m.tasks.libraries.response
    if shouldIgnoreResponse(response) then
        markCoreTaskComplete("libraries")
        return
    end if

    libraries = getItemsFromPayload(response.payload)
    addRow("libraries", "My Media", libraries)
    queueLatestMediaRows(libraries)
    renderRows()
    runMyListTask(libraries)
    runLatestMediaTasks()
    markCoreTaskComplete("libraries")
end sub

'-------------------------------------------------------------------------------
' runMyListTask
'-------------------------------------------------------------------------------
sub runMyListTask(libraries as object)
    request = cloneRequest(m.homeState.request)
    request.playlistsViewId = findCollectionId(libraries, "playlists")
    if request.playlistsViewId = "" then return

    m.homeState.refresh.pendingCore.myList = true
    runTask(m.tasks.myList, request)
end sub

'-------------------------------------------------------------------------------
' onSectionResponse
'-------------------------------------------------------------------------------
sub onSectionResponse(event as object)
    response = event.getData()
    if response = invalid then return
    action = SafeString(response.action, "")
    if shouldIgnoreResponse(response) then
        markCoreTaskComplete(action)
        return
    end if

    if action = "continueWatching" then
        addRow(action, "Continue Watching", getItemsFromPayload(response.payload))
    else if action = "continueListening" then
        addRow(action, "Continue Listening", getItemsFromPayload(response.payload))
    else if action = "nextUp" then
        addRow(action, "Next Up", getItemsFromPayload(response.payload))
    else if action = "liveTvOnNow" then
        addRow(action, "On Now", getItemsFromPayload(response.payload))
    else if action = "myList" then
        addRow(action, "My List", getMyListItems(response.payload))
    else if action = "favorites" then
        addRow(action, "Favorites", getFavoriteItems(response.payload))
    end if

    renderRows()
    markCoreTaskComplete(action)
end sub

'-------------------------------------------------------------------------------
' shouldIgnoreResponse
'-------------------------------------------------------------------------------
function shouldIgnoreResponse(response as dynamic) as boolean
    if response = invalid then return true

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load a home section."))
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' queueLatestMediaRows
'-------------------------------------------------------------------------------
sub queueLatestMediaRows(libraries as object)
    latestKeys = []
    m.homeState.latestLibraries = {}

    for each item in libraries
        if isAssocArray(item) = false then continue for

        collectionType = LCase(FirstNonEmpty([item.CollectionType], ""))
        if collectionType <> "boxsets" and collectionType <> "livetv" and collectionType <> "program" then
            library = {
                id: SafeString(FirstNonEmpty([item.Id], ""), "")
                name: FirstNonEmpty([item.Name], "Library")
                collectionType: collectionType
            }

            if library.id <> "" then
                m.homeState.latestLibraries[library.id] = library
                latestKeys.Push("latest:" + library.id)
            end if
        end if
    end for

    m.homeState.rowOrder = ["libraries", "continueWatching", "continueListening", "nextUp"]
    for each key in latestKeys
        m.homeState.rowOrder.Push(key)
    end for
    m.homeState.rowOrder.Push("liveTvOnNow")
    m.homeState.rowOrder.Push("myList")
    m.homeState.rowOrder.Push("favorites")
end sub

'-------------------------------------------------------------------------------
' runLatestMediaTasks
'-------------------------------------------------------------------------------
sub runLatestMediaTasks()
    m.homeState.latestTasks = []

    for each libraryId in m.homeState.latestLibraries
        library = m.homeState.latestLibraries[libraryId]
        task = CreateObject("roSGNode", "LatestMediaTask")
        task.observeField("response", "onDynamicLatestMediaResponse")
        m.homeState.latestTasks.Push(task)

        request = cloneRequest(m.homeState.request)
        request.parentId = library.id
        runTask(task, request)
    end for
end sub

'-------------------------------------------------------------------------------
' onDynamicLatestMediaResponse
'-------------------------------------------------------------------------------
sub onDynamicLatestMediaResponse(event as object)
    response = event.getData()
    if shouldIgnoreResponse(response) then return

    parentId = SafeString(response.parentId, "")
    if parentId = "" then return
    if m.homeState.latestLibraries.DoesExist(parentId) = false then return

    library = m.homeState.latestLibraries[parentId]
    key = "latest:" + SafeString(library.id, "")
    addRow(key, "Recently Added in " + FirstNonEmpty([library.name], "Library"), getItemsFromPayload(response.payload))
    renderRows(false)
end sub

'-------------------------------------------------------------------------------
' addRow
'-------------------------------------------------------------------------------
sub addRow(key as string, title as string, items as object)
    content = buildRowContent(key, title, items)
    if content.getChildCount() = 0 then
        if m.homeState.rows.DoesExist(key) then m.homeState.rows.Delete(key)
        return
    end if

    m.homeState.rows[key] = content
end sub

'-------------------------------------------------------------------------------
' buildRowContent
'-------------------------------------------------------------------------------
function buildRowContent(key as string, title as string, items as object) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = title
    content.AddFields({ rowKey: key })
    imageAspect = getRowImageAspect(key)

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        imageUrl = getHomeItemImageUrl(key, item, imageAspect)
        child.HDPosterUrl = imageUrl
        child.AddFields({
            imageAspect: imageAspect
            showSubtitle: shouldShowHomeItemSubtitle(key)
            raw: item
        })
    end for

    return content
end function

'-------------------------------------------------------------------------------
' getRowImageAspect
'-------------------------------------------------------------------------------
function getRowImageAspect(key as string) as string
    if key = "libraries" or key = "continueWatching" or key = "nextUp" then return "wide"
    return "poster"
end function

'-------------------------------------------------------------------------------
' renderRows
'-------------------------------------------------------------------------------
sub renderRows(focusAfterRender = true as boolean)
    hadFocus = m.top.isInFocusChain()
    clearShelfNodes()

    shelfNodes = []
    shelfPositions = []
    shelfY = 0
    shelfIndex = 0

    for each key in m.homeState.rowOrder
        if m.homeState.rows.DoesExist(key) then
            layout = getRowLayout(key)
            shelf = CreateObject("roSGNode", "HomeShelf")
            shelf.rowIndex = shelfIndex
            shelf.layout = layout
            shelf.rowContent = m.homeState.rows[key]
            shelf.translation = [0, shelfY]
            shelf.canFocusExitUp = shelfIndex > 0
            shelf.observeField("selectedItem", "onHomeShelfSelected")
            shelf.observeField("focusExitUp", "onHomeShelfFocusExitUp")
            shelf.observeField("focusExitDown", "onHomeShelfFocusExitDown")

            m.shelvesGroup.appendChild(shelf)
            shelfNodes.Push(shelf)
            shelfPositions.Push({ top: shelfY, bottom: shelfY + getShelfHeight(layout) })

            shelfY = shelfY + getShelfHeight(layout) + layout.spacingAfter
            shelfIndex = shelfIndex + 1
        end if
    end for

    for i = 0 to shelfNodes.Count() - 1
        shelfNodes[i].canFocusExitDown = i < shelfNodes.Count() - 1
    end for

    m.homeState.shelfNodes = shelfNodes
    m.homeState.shelfPositions = shelfPositions
    if m.homeState.focusedShelfIndex >= shelfNodes.Count() then
        m.homeState.focusedShelfIndex = shelfNodes.Count() - 1
    end if
    if m.homeState.focusedShelfIndex < 0 then m.homeState.focusedShelfIndex = 0
    updateShelfScroll(false)

    if hasRenderedRows() then
        Status_ClearMessage()
        shouldFocus = (focusAfterRender = true or hadFocus = true)
        if shouldFocus = true and m.homeState.refresh.blocking <> true then focusShelf(m.homeState.focusedShelfIndex)
    end if
end sub

'-------------------------------------------------------------------------------
' markCoreTaskComplete
'-------------------------------------------------------------------------------
sub markCoreTaskComplete(action as string)
    if action = "" then return
    if m.homeState.refresh = invalid then return
    if m.homeState.refresh.pendingCore = invalid then return
    if m.homeState.refresh.pendingCore.DoesExist(action) = false then return

    m.homeState.refresh.pendingCore.Delete(action)
    finishBlockingRefreshIfReady()
end sub

'-------------------------------------------------------------------------------
' finishBlockingRefreshIfReady
'-------------------------------------------------------------------------------
sub finishBlockingRefreshIfReady()
    if m.homeState.refresh = invalid then return
    if m.homeState.refresh.blocking <> true then return
    if m.homeState.refresh.pendingCore <> invalid and m.homeState.refresh.pendingCore.Count() > 0 then return

    m.homeState.refresh.blocking = false
    m.top.visible = true
    Spinner_Hide()
    focusHome()
    m.top.playbackRowsRefreshCompleted = true
end sub

'-------------------------------------------------------------------------------
' getRowLayout
'-------------------------------------------------------------------------------
function getRowLayout(key as string) as object
    if key = "libraries" then
        return { width: 485, height: 306, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/homepage/home-page-my-media-thumbnail-focus-485x306.png" }
    end if

    if getRowImageAspect(key) = "wide" then
        return { width: 485, height: 348, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/homepage/home-page-thumbnail-focus-485x348.png" }
    end if

    return { width: 295, height: 463, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/homepage/home-page-poster-focus-295x463.png" }
end function

'-------------------------------------------------------------------------------
' getShelfHeight
'-------------------------------------------------------------------------------
function getShelfHeight(layout as object) as integer
    return 50 + layout.height
end function

'-------------------------------------------------------------------------------
' shouldShowHomeItemSubtitle
'-------------------------------------------------------------------------------
function shouldShowHomeItemSubtitle(key as string) as boolean
    return key <> "libraries"
end function

'-------------------------------------------------------------------------------
' onHomeShelfFocusExitUp
'-------------------------------------------------------------------------------
sub onHomeShelfFocusExitUp()
    moveShelfFocus(-1)
end sub

'-------------------------------------------------------------------------------
' onHomeShelfFocusExitDown
'-------------------------------------------------------------------------------
sub onHomeShelfFocusExitDown()
    moveShelfFocus(1)
end sub

'-------------------------------------------------------------------------------
' moveShelfFocus
'-------------------------------------------------------------------------------
function moveShelfFocus(delta as integer) as boolean
    targetIndex = m.homeState.focusedShelfIndex + delta
    if targetIndex < 0 or targetIndex >= m.homeState.shelfNodes.Count() then return false

    focusShelf(targetIndex)
    return true
end function

'-------------------------------------------------------------------------------
' focusShelf
'-------------------------------------------------------------------------------
sub focusShelf(index as integer)
    if m.homeState.shelfNodes.Count() = 0 then return
    if index < 0 then index = 0
    if index >= m.homeState.shelfNodes.Count() then index = m.homeState.shelfNodes.Count() - 1

    m.homeState.focusedShelfIndex = index
    updateShelfScroll(true)

    shelf = m.homeState.shelfNodes[index]
    if shelf <> invalid then shelf.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' updateShelfScroll
'-------------------------------------------------------------------------------
sub updateShelfScroll(animated as boolean)
    if m.homeState.shelfPositions.Count() = 0 then
        m.shelvesGroup.translation = [0, 0]
        m.homeState.shelfOffsetY = 0
        return
    end if

    index = m.homeState.focusedShelfIndex
    if index < 0 then index = 0
    if index >= m.homeState.shelfPositions.Count() then index = m.homeState.shelfPositions.Count() - 1

    position = m.homeState.shelfPositions[index]
    targetOffsetY = 0 - position.top

    setShelvesOffset(targetOffsetY, animated)
end sub

'-------------------------------------------------------------------------------
' setShelvesOffset
'-------------------------------------------------------------------------------
sub setShelvesOffset(offsetY as integer, animated as boolean)
    if offsetY = m.homeState.shelfOffsetY then return

    startTranslation = m.shelvesGroup.translation
    endTranslation = [0, offsetY]
    m.homeState.shelfOffsetY = offsetY

    if animated = true then
        m.shelvesTranslation.keyValue = [startTranslation, endTranslation]
        m.shelvesAnimation.control = "start"
    else
        m.shelvesGroup.translation = endTranslation
    end if
end sub

'-------------------------------------------------------------------------------
' clearShelfNodes
'-------------------------------------------------------------------------------
sub clearShelfNodes()
    childCount = m.shelvesGroup.getChildCount()
    if childCount > 0 then m.shelvesGroup.removeChildrenIndex(childCount, 0)
end sub

'-------------------------------------------------------------------------------
' clearRows
'-------------------------------------------------------------------------------
sub clearRows()
    clearShelfNodes()
    m.homeState.shelfNodes = []
    m.homeState.shelfPositions = []
    m.homeState.focusedShelfIndex = 0
    m.homeState.shelfOffsetY = 0
    m.shelvesGroup.translation = [0, 0]
end sub

'-------------------------------------------------------------------------------
' hasRenderedRows
'-------------------------------------------------------------------------------
function hasRenderedRows() as boolean
    return m.homeState.shelfNodes.Count() > 0
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []

    payloadType = Type(payload)
    if payloadType = "roArray" then return payload
    if isAssocArray(payload) = false then return []

    if payload.Items <> invalid then return payload.Items

    return []
end function

'-------------------------------------------------------------------------------
' getMyListItems
'-------------------------------------------------------------------------------
function getMyListItems(payload as dynamic) as object
    if isAssocArray(payload) = false then return []
    if payload.items = invalid then return []

    return getItemsFromPayload(payload.items)
end function

'-------------------------------------------------------------------------------
' getFavoriteItems
'-------------------------------------------------------------------------------
function getFavoriteItems(payload as dynamic) as object
    items = []
    if isAssocArray(payload) = false then return items

    if payload.items <> invalid then
        for each item in getItemsFromPayload(payload.items)
            items.Push(item)
        end for
    end if

    if payload.people <> invalid then
        for each person in getItemsFromPayload(payload.people)
            items.Push(person)
        end for
    end if

    return items
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getHomeItemImageUrl(key as string, item as dynamic, imageAspect as string) as string
    if key = "continueWatching" or key = "nextUp" then
        imageUrl = getResumeRowImageUrl(item, imageAspect)
        if imageUrl <> "" then return imageUrl
    end if

    imageUrl = getItemImageUrl(item, imageAspect)
    if imageUrl <> "" then return imageUrl

    return ""
end function

'-------------------------------------------------------------------------------
' getResumeRowImageUrl
'-------------------------------------------------------------------------------
function getResumeRowImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    itemType = LCase(FirstNonEmpty([item.Type], ""))
    if itemType = "episode" then return getSeriesThumbnailImageUrl(item, imageAspect)
    if itemType = "movie" or itemType = "video" then return getMovieThumbnailImageUrl(item, imageAspect)

    return ""
end function

'-------------------------------------------------------------------------------
' getMovieThumbnailImageUrl
'-------------------------------------------------------------------------------
function getMovieThumbnailImageUrl(item as dynamic, imageAspect as string) as string
    imageSize = getImageSize(imageAspect)
    itemId = FirstNonEmpty([item.Id], "")
    request = m.homeState.request
    if request = invalid then return ""

    thumbTag = getImageTag(item, "Thumb")
    if itemId <> "" and thumbTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Thumb", thumbTag, imageSize.width, imageSize.height)

    backdropTag = getBackdropImageTag(item)
    if itemId <> "" and backdropTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Backdrop", backdropTag, imageSize.width, imageSize.height)

    primaryTag = getImageTag(item, "Primary")
    if itemId <> "" and primaryTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, imageSize.width, imageSize.height)

    return ""
end function

'-------------------------------------------------------------------------------
' getSeriesThumbnailImageUrl
'-------------------------------------------------------------------------------
function getSeriesThumbnailImageUrl(item as dynamic, imageAspect as string) as string
    imageSize = getImageSize(imageAspect)
    request = m.homeState.request
    if request = invalid then return ""

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId, item.ParentThumbImageItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return Url_BuildImageUrl(request.server, parentThumbId, "Thumb", parentThumbTag, imageSize.width, imageSize.height)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesThumbTag = FirstNonEmpty([item.SeriesThumbImageTag], "")
    if seriesId <> "" and seriesThumbTag <> "" then return Url_BuildImageUrl(request.server, seriesId, "Thumb", seriesThumbTag, imageSize.width, imageSize.height)

    parentBackdropId = FirstNonEmpty([item.ParentBackdropItemId], "")
    parentBackdropTag = getParentBackdropImageTag(item)
    if parentBackdropId <> "" and parentBackdropTag <> "" then return Url_BuildImageUrl(request.server, parentBackdropId, "Backdrop", parentBackdropTag, imageSize.width, imageSize.height)

    seriesPrimaryTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesPrimaryTag <> "" then return Url_BuildImageUrl(request.server, seriesId, "Primary", seriesPrimaryTag, imageSize.width, imageSize.height)

    return ""
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    directUrl = FirstNonEmpty([item.ImageURL, item.ImageUrl, item.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    imageSize = getImageSize(imageAspect)
    itemId = FirstNonEmpty([item.Id], "")
    request = m.homeState.request
    if request = invalid then return ""

    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, imageSize.width, imageSize.height)

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId, item.ParentThumbImageItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return Url_BuildImageUrl(request.server, parentThumbId, "Thumb", parentThumbTag, imageSize.width, imageSize.height)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return Url_BuildImageUrl(request.server, seriesId, "Primary", seriesTag, imageSize.width, imageSize.height)

    return ""
end function

'-------------------------------------------------------------------------------
' getImageTag
'-------------------------------------------------------------------------------
function getImageTag(item as dynamic, imageType as string) as string
    if item = invalid or item.ImageTags = invalid then return ""

    tag = item.ImageTags[imageType]
    return FirstNonEmpty([tag], "")
end function

'-------------------------------------------------------------------------------
' getBackdropImageTag
'-------------------------------------------------------------------------------
function getBackdropImageTag(item as dynamic) as string
    if item = invalid then return ""
    if item.BackdropImageTags = invalid or item.BackdropImageTags.Count() = 0 then return ""

    return FirstNonEmpty([item.BackdropImageTags[0]], "")
end function

'-------------------------------------------------------------------------------
' getParentBackdropImageTag
'-------------------------------------------------------------------------------
function getParentBackdropImageTag(item as dynamic) as string
    if item = invalid then return ""
    if item.ParentBackdropImageTags = invalid or item.ParentBackdropImageTags.Count() = 0 then return ""

    return FirstNonEmpty([item.ParentBackdropImageTags[0]], "")
end function

'-------------------------------------------------------------------------------
' getImageSize
'-------------------------------------------------------------------------------
function getImageSize(imageAspect as string) as object
    if imageAspect = "wide" then return { width: 440, height: 248 }
    return { width: 250, height: 375 }
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
' isTVEpisode
'-------------------------------------------------------------------------------
function isTVEpisode(item as dynamic) as boolean
    if isAssocArray(item) = false then return false

    itemType = LCase(FirstNonEmpty([item.Type], ""))
    return itemType = "episode"
end function

'-------------------------------------------------------------------------------
' isTVSeries
'-------------------------------------------------------------------------------
function isTVSeries(item as dynamic) as boolean
    if isAssocArray(item) = false then return false

    itemType = LCase(FirstNonEmpty([item.Type], ""))
    return itemType = "series"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' isMediaLibrary
'-------------------------------------------------------------------------------
function isMediaLibrary(item as dynamic) as boolean
    return item.CollectionType = "movies" or item.CollectionType = "tvshows"
end function

'-------------------------------------------------------------------------------
' isCollectionsLibrary
'-------------------------------------------------------------------------------
function isCollectionsLibrary(item as dynamic) as boolean
    return item.CollectionType = "boxsets"
end function

'-------------------------------------------------------------------------------
' findCollectionId
'-------------------------------------------------------------------------------
function findCollectionId(items as object, collectionType as string) as string
    if items = invalid then return ""

    for each item in items
        if isAssocArray(item) = false then continue for
        if item.CollectionType <> invalid and LCase(item.CollectionType) = LCase(collectionType) then
            return SafeString(item.Id, "")
        end if
    end for

    return ""
end function

' cloneRequest
'-------------------------------------------------------------------------------
function cloneRequest(request as object) as object
    clone = {}
    if request = invalid then return clone

    for each key in request
        clone[key] = request[key]
    end for

    return clone
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" then
        if moveShelfFocus(-1) then return true
        m.top.focusExitUp = true
        return true
    end if

    if key = "down" then
        return moveShelfFocus(1)
    end if

    if hasRenderedRows() and m.top.isInFocusChain() = false then
        focusShelf(m.homeState.focusedShelfIndex)
        return true
    end if

    return false
end function

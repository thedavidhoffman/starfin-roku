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
    itemId = SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
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
    if hasRenderedRows() then
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
    runTask(m.tasks.myList, request)
    runTask(m.tasks.favorites, request)
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
    if shouldIgnoreResponse(response) then return

    libraries = getItemsFromPayload(response.payload)
    addRow("libraries", "My Media", libraries)
    queueLatestMediaRows(libraries)
    renderRows()
    runLatestMediaTasks()
end sub

'-------------------------------------------------------------------------------
' onSectionResponse
'-------------------------------------------------------------------------------
sub onSectionResponse(event as object)
    response = event.getData()
    if shouldIgnoreResponse(response) then return

    action = SafeString(response.action, "")
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

        collectionType = LCase(FirstNonEmpty([item.CollectionType, item.collectionType], ""))
        if collectionType <> "boxsets" and collectionType <> "livetv" and collectionType <> "program" then
            library = {
                id: SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
                name: FirstNonEmpty([item.Name, item.name], "Library")
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
    renderRows()
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
        child.title = getHomeItemTitle(key, item)
        child.description = getHomeItemSubtitle(key, item)
        imageUrl = getHomeItemImageUrl(key, item, imageAspect)
        child.HDPosterUrl = imageUrl
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
            itemType: SafeString(FirstNonEmpty([item.Type, item.type], ""), "")
            imageAspect: imageAspect
            homeTitle: child.title
            homeSubtitle: child.description
            showSubtitle: shouldShowHomeItemSubtitle(key)
            showImageBackground: shouldShowHomeItemImageBackground(key, item, imageUrl)
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
sub renderRows()
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
        focusShelf(m.homeState.focusedShelfIndex)
    end if
end sub

'-------------------------------------------------------------------------------
' getRowLayout
'-------------------------------------------------------------------------------
function getRowLayout(key as string) as object
    if key = "libraries" then
        return { width: 485, height: 306, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/masks/home-page-thumbnail-focus-485x306.png" }
    end if

    if getRowImageAspect(key) = "wide" then
        return { width: 485, height: 348, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/masks/home-page-thumbnail-focus-485x348.png" }
    end if

    return { width: 295, height: 463, itemSizeWidth: 1824, itemSpacing: -27, spacingAfter: 37, focusBitmapUri: "pkg:/images/masks/home-page-poster-focus-295x463.png" }
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
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.Name, item.name, item.SeriesName, item.Album, item.Type], "Untitled")
end function

'-------------------------------------------------------------------------------
' getItemSubtitle
'-------------------------------------------------------------------------------
function getItemSubtitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.SeriesName, item.AlbumArtist, item.Album, item.CollectionType, item.Type], "")
end function

'-------------------------------------------------------------------------------
' getHomeItemTitle
'-------------------------------------------------------------------------------
function getHomeItemTitle(key as string, item as dynamic) as string
    itemType = LCase(SafeString(FirstNonEmpty([item.Type, item.type], ""), ""))
    if itemType = "movie" then
        movieName = FirstNonEmpty([item.Name, item.name, item.title], "")
        if movieName <> "" then return movieName
    end if

    if isPlaybackProgressRow(key) then
        if itemType = "episode" then
            seriesName = getEpisodeSeriesName(item)
            if seriesName <> "" then return seriesName
        end if
    end if

    return getItemTitle(item)
end function

'-------------------------------------------------------------------------------
' isPlaybackProgressRow
'-------------------------------------------------------------------------------
function isPlaybackProgressRow(key as string) as boolean
    return key = "continueWatching" or key = "nextUp"
end function

'-------------------------------------------------------------------------------
' getEpisodeSeriesName
'-------------------------------------------------------------------------------
function getEpisodeSeriesName(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    return FirstNonEmpty([item.SeriesName, item.seriesName], "")
end function

'-------------------------------------------------------------------------------
' getHomeItemSubtitle
'-------------------------------------------------------------------------------
function getHomeItemSubtitle(key as string, item as dynamic) as string
    if key = "libraries" then return ""

    itemType = LCase(SafeString(FirstNonEmpty([item.Type, item.type], ""), ""))
    if isLatestMediaRow(key) and itemType = "series" then
        seriesYearRange = getSeriesYearRange(item)
        if seriesYearRange <> "" then return seriesYearRange
    end if

    if itemType = "movie" then
        productionYear = FirstNonEmpty([item.ProductionYear, item.productionYear], "")
        if productionYear <> "" then return SafeString(productionYear, "")
    end if

    if isPlaybackProgressRow(key) then
        if itemType = "episode" then
            episodeName = getEpisodeDisplaySubtitle(item)
            if episodeName <> "" then return episodeName
        end if
    end if

    return getItemSubtitle(item)
end function

'-------------------------------------------------------------------------------
' getEpisodeDisplaySubtitle
'-------------------------------------------------------------------------------
function getEpisodeDisplaySubtitle(item as dynamic) as string
    episodeName = FirstNonEmpty([item.Name, item.name, item.title], "")
    seasonNumber = FirstNonEmpty([item.ParentIndexNumber, item.parentIndexNumber], "")
    episodeNumber = FirstNonEmpty([item.IndexNumber, item.indexNumber], "")

    if seasonNumber = "" or episodeNumber = "" then return episodeName

    return "S" + SafeString(seasonNumber, "") + "E" + SafeString(episodeNumber, "") + " - " + episodeName
end function

'-------------------------------------------------------------------------------
' isLatestMediaRow
'-------------------------------------------------------------------------------
function isLatestMediaRow(key as string) as boolean
    return Left(key, 7) = "latest:"
end function

'-------------------------------------------------------------------------------
' getSeriesYearRange
'-------------------------------------------------------------------------------
function getSeriesYearRange(item as dynamic) as string
    productionYear = FirstNonEmpty([item.ProductionYear, item.productionYear], "")
    if productionYear = "" then return ""

    status = LCase(FirstNonEmpty([item.Status, item.status], ""))
    if status = "continuing" then return SafeString(productionYear, "") + " - Present"

    if status = "ended" then
        endYear = getYearFromDate(FirstNonEmpty([item.EndDate, item.endDate], ""))
        if endYear <> "" then return SafeString(productionYear, "") + " - " + endYear
    end if

    return ""
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getHomeItemImageUrl(key as string, item as dynamic, imageAspect as string) as string
    
    if key = "libraries" and shouldUseStarfishLibraryCards() then
        if item.CollectionType = "boxsets" then return "pkg:/images/libraries/collections.png"
        if item.CollectionType = "movies" then return "pkg:/images/libraries/movies.png"
        if item.CollectionType = "tvshows" then return "pkg:/images/libraries/tv.png"
    end if

    imageUrl = getItemImageUrl(item, imageAspect)
    if imageUrl <> "" then return imageUrl

    return ""

end function

'-------------------------------------------------------------------------------
' shouldUseStarfishLibraryCards
'-------------------------------------------------------------------------------
function shouldUseStarfishLibraryCards() as boolean
    settings = SettingsStore_Load()
    keys = SettingsStore_Keys()

    return SettingsStore_GetSettingValue(settings, keys.homeLibraryThumbnails) = "starfish"
end function

'-------------------------------------------------------------------------------
' shouldShowHomeItemImageBackground
'-------------------------------------------------------------------------------
function shouldShowHomeItemImageBackground(key as string, item as dynamic, imageUrl as string) as boolean
    return key = "libraries" and isCollectionsLibrary(item) and imageUrl = "pkg:/images/libraries/collections.png"
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    directUrl = FirstNonEmpty([item.ImageURL, item.imageURL, item.ImageUrl, item.imageUrl, item.thumbnailURL, item.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    imageSize = getImageSize(imageAspect)
    itemId = FirstNonEmpty([item.Id, item.id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return buildImageUrl(itemId, "Primary", primaryTag, imageSize.width, imageSize.height)

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId, item.ParentThumbImageItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return buildImageUrl(parentThumbId, "Thumb", parentThumbTag, imageSize.width, imageSize.height)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return buildImageUrl(seriesId, "Primary", seriesTag, imageSize.width, imageSize.height)

    return ""
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

    itemType = LCase(FirstNonEmpty([item.Type, item.type], ""))
    return itemType = "movie" or itemType = "video"
end function

'-------------------------------------------------------------------------------
' isTVSeries
'-------------------------------------------------------------------------------
function isTVSeries(item as dynamic) as boolean
    if isAssocArray(item) = false then return false

    itemType = LCase(FirstNonEmpty([item.Type, item.type], ""))
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
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.homeState.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    if tag <> "" then url = url + "?tag=" + tag + "&maxHeight=" + height.ToStr() + "&maxWidth=" + width.ToStr() + "&quality=90"
    return url
end function

'-------------------------------------------------------------------------------
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

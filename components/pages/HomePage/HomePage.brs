'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("HomePage")
    m.statusLabel = m.top.findNode("statusLabel")
    m.homeRows = m.top.findNode("homeRows")

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
    m.homeRows.observeField("rowItemSelected", "onHomeRowItemSelected")

    m.homeState = {
        request: invalid
        rows: {}
        rowOrder: ["libraries", "continueWatching", "continueListening", "nextUp", "liveTvOnNow", "myList", "favorites"]
        latestLibraries: {}
        latestTasks: []
    }
end sub

'-------------------------------------------------------------------------------
' onHomeRowItemSelected
'-------------------------------------------------------------------------------
sub onHomeRowItemSelected()
    selected = m.homeRows.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    if m.homeRows.content = invalid then return

    row = m.homeRows.content.getChild(selected[0])
    if row = invalid then return

    itemNode = row.getChild(selected[1])
    if itemNode = invalid then return

    item = itemNode.raw
    itemId = SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
    if itemId = "" then return

    if isPlayableMovie(item) then
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
        m.homeRows.setFocus(true)
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

    clearRows()
    setStatus("Loading home...")

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
        setStatus(SafeString(response.errorMessage, "Unable to load a home section."))
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
    content = buildRowContent(title, items)
    if content.getChildCount() = 0 then
        if m.homeState.rows.DoesExist(key) then m.homeState.rows.Delete(key)
        return
    end if

    m.homeState.rows[key] = content
end sub

'-------------------------------------------------------------------------------
' buildRowContent
'-------------------------------------------------------------------------------
function buildRowContent(title as string, items as object) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = title

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.title = getItemTitle(item)
        child.description = getItemSubtitle(item)
        child.HDPosterUrl = getItemImageUrl(item)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
            itemType: SafeString(FirstNonEmpty([item.Type, item.type], ""), "")
            raw: item
        })
    end for

    return content
end function

'-------------------------------------------------------------------------------
' renderRows
'-------------------------------------------------------------------------------
sub renderRows()
    content = CreateObject("roSGNode", "ContentNode")

    for each key in m.homeState.rowOrder
        if m.homeState.rows.DoesExist(key) then
            content.appendChild(m.homeState.rows[key])
        end if
    end for

    m.homeRows.content = content

    if hasRenderedRows() then
        setStatus("")
        if m.top.hasFocus() then m.homeRows.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' clearRows
'-------------------------------------------------------------------------------
sub clearRows()
    m.homeRows.content = CreateObject("roSGNode", "ContentNode")
end sub

'-------------------------------------------------------------------------------
' hasRenderedRows
'-------------------------------------------------------------------------------
function hasRenderedRows() as boolean
    if m.homeRows = invalid or m.homeRows.content = invalid then return false
    return m.homeRows.content.getChildCount() > 0
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
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    directUrl = FirstNonEmpty([item.ImageURL, item.imageURL, item.ImageUrl, item.imageUrl, item.thumbnailURL, item.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    itemId = FirstNonEmpty([item.Id, item.id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return buildImageUrl(itemId, "Primary", primaryTag)

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId, item.ParentThumbImageItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return buildImageUrl(parentThumbId, "Thumb", parentThumbTag)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return buildImageUrl(seriesId, "Primary", seriesTag)

    return ""
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
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string) as string
    request = m.homeState.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    if tag <> "" then url = url + "?tag=" + tag + "&maxHeight=375&maxWidth=250&quality=90"
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
    return false
end function

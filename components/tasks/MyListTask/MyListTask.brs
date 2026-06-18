'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = createLogger("MyListTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request, "myList")
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    userId = getUserId(request)
    viewsResponse = getJson(request, "myList", "/userviews", { userId: userId })
    if viewsResponse.ok <> true then
        m.top.response = viewsResponse
        return
    end if

    playlistsViewId = findCollectionId(viewsResponse.data, "playlists")
    if playlistsViewId = "" then
        m.top.response = successResponse(request, "myList", {
            playlist: invalid
            items: invalid
        })
        return
    end if

    playlistResponse = getJson(request, "myList", "/items/", {
        userid: userId
        includeItemTypes: "Playlist"
        nameStartsWith: "|My List|"
        parentId: playlistsViewId
    })
    if playlistResponse.ok <> true then
        m.top.response = playlistResponse
        return
    end if

    playlist = firstItem(playlistResponse.data)
    if playlist = invalid or playlist.Id = invalid then
        m.top.response = successResponse(request, "myList", {
            playlist: invalid
            items: invalid
        })
        return
    end if

    itemsResponse = getJson(request, "myList", "/items/", {
        UserId: userId
        ImageTypeLimit: 1
        EnableImageTypes: "Primary, Backdrop, Thumb"
        Limit: getInteger(request.limit, 50)
        EnableTotalRecordCount: false
        ParentId: playlist.Id
    })
    if itemsResponse.ok <> true then
        m.top.response = itemsResponse
        return
    end if

    m.top.response = successResponse(request, "myList", {
        playlist: playlist
        items: itemsResponse.data
    })
end sub

'-------------------------------------------------------------------------------
' getJson
'-------------------------------------------------------------------------------
function getJson(request as object, action as string, path as string, params as object) as object
    url = NormalizeServerUrl(request.server) + path + Url_BuildQueryString(params)
    m.log.write(url)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then return withAction(response, action)

    return response
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as object, action as string) as dynamic
    if request = invalid then return { ok: false, action: action, errorMessage: "Invalid request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: action, errorMessage: "Invalid request server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: action, errorMessage: "Invalid request token." }

    return invalid
end function

'-------------------------------------------------------------------------------
' successResponse
'-------------------------------------------------------------------------------
function successResponse(request as object, action as string, payload as dynamic) as object
    return {
        ok: true
        action: action
        server: NormalizeServerUrl(request.server)
        payload: payload
    }
end function

'-------------------------------------------------------------------------------
' withAction
'-------------------------------------------------------------------------------
function withAction(response as object, action as string) as object
    if response = invalid then return { ok: false, action: action, errorMessage: "Request failed." }
    response.AddReplace("action", action)
    return response
end function

'-------------------------------------------------------------------------------
' getUserId
'-------------------------------------------------------------------------------
function getUserId(request as object) as string
    if request.userId <> invalid then return SafeString(request.userId, "")
    return ""
end function

'-------------------------------------------------------------------------------
' getInteger
'-------------------------------------------------------------------------------
function getInteger(value as dynamic, fallback as integer) as integer
    if value = invalid then return fallback
    return value.ToInt()
end function

'-------------------------------------------------------------------------------
' findCollectionId
'-------------------------------------------------------------------------------
function findCollectionId(payload as dynamic, collectionType as string) as string
    if payload = invalid or payload.Items = invalid then return ""

    for each item in payload.Items
        if item.CollectionType <> invalid and LCase(item.CollectionType) = LCase(collectionType) then
            return SafeString(item.Id, "")
        end if
    end for

    return ""
end function

'-------------------------------------------------------------------------------
' firstItem
'-------------------------------------------------------------------------------
function firstItem(payload as dynamic) as dynamic
    if payload = invalid or payload.Items = invalid then return invalid
    if payload.Items.Count() = 0 then return invalid

    return payload.Items[0]
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("PersonTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        if request <> invalid then validationError.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = validationError
        return
    end if

    personResult = loadPerson(request)
    if personResult.ok <> true then
        personResult.AddReplace("action", "person")
        personResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = personResult
        return
    end if

    itemsResult = loadPersonItems(request)
    if itemsResult.ok <> true then
        itemsResult.AddReplace("action", "person")
        itemsResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = itemsResult
        return
    end if

    filteredItems = itemsResult.data
    excludedSeriesIds = getRelatedSeriesIds(filteredItems)
    episodeItemsResult = loadPersonEpisodeItems(request, excludedSeriesIds)
    if episodeItemsResult.ok <> true then
        episodeItemsResult.AddReplace("action", "person")
        episodeItemsResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = episodeItemsResult
        return
    end if

    m.top.response = {
        ok: true
        action: "person"
        itemId: SafeString(request.itemId, "")
        payload: {
            person: personResult.data
            items: filteredItems
            episodeItems: episodeItemsResult.data
        }
    }
end sub

'-------------------------------------------------------------------------------
' loadPerson
'-------------------------------------------------------------------------------
function loadPerson(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        fields: "Overview,ExternalUrls"
    }

    url = request.server + "/Items/" + request.itemId + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadPersonItems
'-------------------------------------------------------------------------------
function loadPersonItems(request as object) as object
    params = {
        UserId: SafeString(request.userId, "")
        PersonIds: SafeString(request.itemId, "")
        IncludeItemTypes: "Movie,Series"
        Recursive: true
        SortBy: "SortName"
        SortOrder: "Ascending"
        Fields: "PrimaryImageAspectRatio,Overview"
        ImageTypeLimit: 1
        EnableImageTypes: "Primary,Backdrop"
        Limit: 40
    }

    url = request.server + "/Users/" + request.userId + "/Items" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadPersonEpisodeItems
'-------------------------------------------------------------------------------
function loadPersonEpisodeItems(request as object, excludedSeriesIds as object) as object
    itemLimit = 40
    episodeItems = []

    params = {
        UserId: SafeString(request.userId, "")
        PersonIds: SafeString(request.itemId, "")
        IncludeItemTypes: "Episode"
        Recursive: true
        SortBy: "PremiereDate"
        SortOrder: "Descending"
        Fields: "PrimaryImageAspectRatio,Overview,SeriesName"
        ImageTypeLimit: 1
        EnableImageTypes: "Primary,Backdrop,Thumb"
        Limit: 500
    }

    url = request.server + "/Users/" + request.userId + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then return response

    items = getPayloadItems(response.data)
    if items <> invalid then
        for each item in items
            seriesId = ""
            if Array_IsAssocArray(item) then seriesId = SafeString(FirstNonEmpty([item.SeriesId], ""), "")
            if seriesId <> "" and arrayContainsString(excludedSeriesIds, seriesId) then continue for

            episodeItems.Push(item)
            if episodeItems.Count() = itemLimit then exit for
        end for
    end if

    response.AddReplace("data", episodeItems)
    return response
end function

'-------------------------------------------------------------------------------
' getRelatedSeriesIds
'-------------------------------------------------------------------------------
function getRelatedSeriesIds(payload as dynamic) as object
    seriesIds = []
    items = getPayloadItems(payload)
    if items = invalid then return seriesIds

    for each item in items
        if Array_IsAssocArray(item) = false then continue for
        if LCase(SafeString(FirstNonEmpty([item.Type], ""), "")) <> "series" then continue for

        seriesId = SafeString(FirstNonEmpty([item.Id], ""), "")
        if seriesId <> "" and arrayContainsString(seriesIds, seriesId) = false then seriesIds.Push(seriesId)
    end for

    return seriesIds
end function

'-------------------------------------------------------------------------------
' getPayloadItems
'-------------------------------------------------------------------------------
function getPayloadItems(payload as dynamic) as dynamic
    if payload = invalid then return invalid
    if Type(payload) = "roArray" then return payload
    if Array_IsAssocArray(payload) = false then return invalid

    return payload.Items
end function

'-------------------------------------------------------------------------------
' arrayContainsString
'-------------------------------------------------------------------------------
function arrayContainsString(values as object, value as string) as boolean
    if value = "" then return false

    for each current in values
        if SafeString(current, "") = value then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "person", errorMessage: "Invalid person request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "person", errorMessage: "Invalid person server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "person", errorMessage: "Invalid person token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "person", errorMessage: "Invalid person user." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "person", errorMessage: "Invalid person item." }

    return invalid
end function

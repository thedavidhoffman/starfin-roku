'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("SearchTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        if request <> invalid then validationError.AddReplace("query", String_Trim(SafeString(request.query, "")))
        m.top.response = validationError
        return
    end if

    moviesAndSeriesResult = searchItems(request, "Movie,Series", "PrimaryImageAspectRatio,Overview,Genres,UserData")
    if moviesAndSeriesResult.ok <> true then
        m.top.response = withAction(moviesAndSeriesResult, request)
        return
    end if

    episodesResult = searchItems(request, "Episode", "PrimaryImageAspectRatio,Overview,SeriesName,ParentIndexNumber,IndexNumber,UserData")
    if episodesResult.ok <> true then
        m.top.response = withAction(episodesResult, request)
        return
    end if

    peopleResult = searchPeople(request)
    if peopleResult.ok <> true then
        m.top.response = withAction(peopleResult, request)
        return
    end if

    m.top.response = {
        ok: true
        action: "search"
        query: String_Trim(SafeString(request.query, ""))
        payload: {
            moviesAndSeries: getPayloadItems(moviesAndSeriesResult.data)
            episodes: getPayloadItems(episodesResult.data)
            people: getPayloadItems(peopleResult.data)
        }
    }
end sub

'-------------------------------------------------------------------------------
' searchItems
'-------------------------------------------------------------------------------
function searchItems(request as object, includeItemTypes as string, fields as string) as object
    params = {
        UserId: SafeString(request.userId, "")
        SearchTerm: String_Trim(SafeString(request.query, ""))
        IncludeItemTypes: includeItemTypes
        Recursive: true
        Limit: 40
        Fields: fields
        EnableImageTypes: "Primary,Backdrop,Thumb"
        ImageTypeLimit: 1
        EnableTotalRecordCount: false
    }

    url = request.server + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' searchPeople
'-------------------------------------------------------------------------------
function searchPeople(request as object) as object
    params = {
        UserId: SafeString(request.userId, "")
        SearchTerm: String_Trim(SafeString(request.query, ""))
        Limit: 40
        ImageTypeLimit: 1
        EnableTotalRecordCount: false
    }

    url = request.server + "/Persons" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "search", errorMessage: "Invalid search request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "search", errorMessage: "Invalid search server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "search", errorMessage: "Invalid search token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "search", errorMessage: "Invalid search user." }
    if String_Trim(SafeString(request.query, "")) = "" then return { ok: false, action: "search", errorMessage: "Enter a search term." }

    return invalid
end function

'-------------------------------------------------------------------------------
' withAction
'-------------------------------------------------------------------------------
function withAction(response as object, request as object) as object
    if response = invalid then return { ok: false, action: "search", query: String_Trim(SafeString(request.query, "")), errorMessage: "Search failed." }

    response.AddReplace("action", "search")
    response.AddReplace("query", String_Trim(SafeString(request.query, "")))
    return response
end function

'-------------------------------------------------------------------------------
' getPayloadItems
'-------------------------------------------------------------------------------
function getPayloadItems(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if Array_IsAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items

    return []
end function


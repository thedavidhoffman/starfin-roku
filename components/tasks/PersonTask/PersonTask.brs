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
        m.top.response = validationError
        return
    end if

    personResult = loadPerson(request)
    if personResult.ok <> true then
        personResult.AddReplace("action", "person")
        m.top.response = personResult
        return
    end if

    itemsResult = loadPersonItems(request)
    if itemsResult.ok <> true then
        itemsResult.AddReplace("action", "person")
        m.top.response = itemsResult
        return
    end if

    m.top.response = {
        ok: true
        action: "person"
        itemId: SafeString(request.itemId, "")
        payload: {
            person: personResult.data
            items: itemsResult.data
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

    url = NormalizeServerUrl(request.server) + "/Items/" + request.itemId + Url_BuildQueryString(params)
    m.log.write(url)
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

    url = NormalizeServerUrl(request.server) + "/Users/" + request.userId + "/Items" + Url_BuildQueryString(params)
    m.log.write(url)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "person", errorMessage: "Invalid person request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "person", errorMessage: "Invalid person server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "person", errorMessage: "Invalid person token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "person", errorMessage: "Invalid person user." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "person", errorMessage: "Invalid person item." }

    return invalid
end function

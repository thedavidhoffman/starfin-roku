'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("CollectionsTask")
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

    params = {
        userId: SafeString(request.userId, "")
        parentId: SafeString(request.libraryId, "")
        recursive: getRecursiveValue(request)
        includeItemTypes: SafeString(request.includeItemTypes, "BoxSet")
        fields: "Genres,Overview"
        enableImageTypes: "Primary,Backdrop,Thumb"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: "SortName"
        sortOrder: "Ascending"
    }

    url = NormalizeServerUrl(request.server) + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "collections")
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "collections"
        libraryId: SafeString(request.libraryId, "")
        mode: SafeString(request.mode, "load")
        payload: response.data
    }
end sub

'-------------------------------------------------------------------------------
' getRecursiveValue
'-------------------------------------------------------------------------------
function getRecursiveValue(request as dynamic) as boolean
    if request.recursive <> invalid then return request.recursive

    return true
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "collections", errorMessage: "Invalid collections request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "collections", errorMessage: "Invalid collections server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "collections", errorMessage: "Invalid collections token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "collections", errorMessage: "Invalid collections user." }
    if request.libraryId = invalid or request.libraryId = "" then return { ok: false, action: "collections", errorMessage: "Invalid collections item." }

    return invalid
end function

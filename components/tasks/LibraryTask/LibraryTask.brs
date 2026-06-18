'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("LibraryTask")
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
        recursive: true
        includeItemTypes: SafeString(request.includeItemTypes, "")
        fields: "Genres,Overview,MediaSources,MediaStreams"
        enableImageTypes: "Primary,Backdrop,Thumb,Logo"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: "SortName"
        sortOrder: "Ascending"
    }

    url = NormalizeServerUrl(request.server) + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    m.log.write(url)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "library")
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "library"
        libraryId: SafeString(request.libraryId, "")
        payload: response.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "library", errorMessage: "Invalid library request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "library", errorMessage: "Invalid library server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "library", errorMessage: "Invalid library token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "library", errorMessage: "Invalid library user." }
    if request.libraryId = invalid or request.libraryId = "" then return { ok: false, action: "library", errorMessage: "Invalid library item." }

    return invalid
end function

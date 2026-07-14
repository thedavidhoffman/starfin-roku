'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MusicLibraryTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        if request <> invalid then validationError.AddReplace("libraryId", SafeString(request.libraryId, ""))
        m.top.response = validationError
        return
    end if

    params = {
        userId: SafeString(request.userId, "")
        parentId: SafeString(request.libraryId, "")
        recursive: true
        includeItemTypes: "MusicAlbum"
        fields: "SortName,AlbumArtist,Artists"
        enableImageTypes: "Primary"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: "SortName"
        sortOrder: "Ascending"
    }

    url = request.server + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "musicLibrary")
        response.AddReplace("libraryId", SafeString(request.libraryId, ""))
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "musicLibrary"
        libraryId: SafeString(request.libraryId, "")
        payload: response.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "musicLibrary", errorMessage: "Invalid music library request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "musicLibrary", errorMessage: "Invalid music library server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "musicLibrary", errorMessage: "Invalid music library token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "musicLibrary", errorMessage: "Invalid music library user." }
    if request.libraryId = invalid or request.libraryId = "" then return { ok: false, action: "musicLibrary", errorMessage: "Invalid music library item." }

    return invalid
end function

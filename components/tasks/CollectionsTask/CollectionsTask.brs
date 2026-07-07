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
        if request <> invalid then
            validationError.AddReplace("libraryId", SafeString(request.libraryId, ""))
            validationError.AddReplace("mode", SafeString(request.mode, "load"))
        end if
        m.top.response = validationError
        return
    end if

    params = {
        userId: SafeString(request.userId, "")
        parentId: SafeString(request.libraryId, "")
        fields: getFields(request)
        enableImageTypes: "Primary,Backdrop,Thumb"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: getSortBy(request)
        sortOrder: getSortOrder(request)
    }
    addOptionalQueryParams(params, request)

    url = NormalizeServerUrl(request.server) + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "collections")
        response.AddReplace("libraryId", SafeString(request.libraryId, ""))
        response.AddReplace("mode", SafeString(request.mode, "load"))
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
' addOptionalQueryParams
'-------------------------------------------------------------------------------
sub addOptionalQueryParams(params as object, request as object)
    if request.recursive <> invalid then params.AddReplace("recursive", request.recursive)

    includeItemTypes = SafeString(request.includeItemTypes, "")
    if includeItemTypes <> "" then params.AddReplace("includeItemTypes", includeItemTypes)
end sub

'-------------------------------------------------------------------------------
' getFields
'-------------------------------------------------------------------------------
function getFields(request as dynamic) as string
    fields = SafeString(request.fields, "")
    if fields <> "" then return fields

    return "PrimaryImageAspectRatio,SortName,Path,ChildCount,MediaSourceCount,Genres,Overview,Tags"
end function

'-------------------------------------------------------------------------------
' getSortBy
'-------------------------------------------------------------------------------
function getSortBy(request as dynamic) as string
    sortBy = SafeString(request.sortBy, "")
    if sortBy <> "" then return sortBy

    return "IsFolder,SortName"
end function

'-------------------------------------------------------------------------------
' getSortOrder
'-------------------------------------------------------------------------------
function getSortOrder(request as dynamic) as string
    sortOrder = SafeString(request.sortOrder, "")
    if sortOrder <> "" then return sortOrder

    return "Ascending"
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

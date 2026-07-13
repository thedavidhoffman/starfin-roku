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
        if request <> invalid then validationError.AddReplace("libraryId", SafeString(request.libraryId, ""))
        m.top.response = validationError
        return
    end if

    params = {
        userId: SafeString(request.userId, "")
        parentId: SafeString(request.libraryId, "")
        recursive: true
        includeItemTypes: SafeString(request.includeItemTypes, "")
        fields: "SortName,ProductionYear,PremiereDate,DateCreated,Genres"
        enableImageTypes: "Primary,Backdrop,Thumb,Logo"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: getSortBy(request)
        sortOrder: getSortOrder(request)
    }

    url = request.server + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "library")
        response.AddReplace("libraryId", SafeString(request.libraryId, ""))
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "library"
        libraryId: SafeString(request.libraryId, "")
        payload: response.data
        filterOptions: buildFilterOptions(getItemsFromPayload(response.data))
    }
end sub

'-------------------------------------------------------------------------------
' buildFilterOptions
'-------------------------------------------------------------------------------
function buildFilterOptions(items as object) as object
    filterOptions = {
        decadeOptions: []
        genreOptions: []
    }
    if items = invalid then return filterOptions

    decadeValues = []
    decadeValueByKey = {}
    genreLabels = []
    genreLabelByKey = {}

    for each item in items
        year = getItemLibraryYear(item)
        if year > 0 then
            decade = Number_ToInteger(Fix(year / 10) * 10, 0)
            decadeKey = decade.ToStr()
            if decadeValueByKey[decadeKey] = invalid then
                decadeValueByKey[decadeKey] = decade
                decadeValues.Push(decade)
            end if
        end if

        for each genre in getItemGenres(item)
            genreLabel = String_Trim(SafeString(genre, ""))
            if genreLabel = "" then continue for

            genreKey = LCase(genreLabel)
            if genreLabelByKey[genreKey] = invalid then
                genreLabelByKey[genreKey] = genreLabel
                genreLabels.Push(genreLabel)
            end if
        end for
    end for

    decadeValues.Sort()
    for each decade in decadeValues
        decadeKey = decade.ToStr()
        filterOptions.decadeOptions.Push({
            label: decadeKey
            value: decade
        })
    end for

    genreLabels.Sort()
    for each genreLabel in genreLabels
        filterOptions.genreOptions.Push({
            label: genreLabel
            value: genreLabel
        })
    end for

    return filterOptions
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if Array_IsAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items
    return []
end function

'-------------------------------------------------------------------------------
' getItemGenres
'-------------------------------------------------------------------------------
function getItemGenres(item as dynamic) as object
    if Array_IsAssocArray(item) = false then return []
    if item.Genres = invalid then return []

    return item.Genres
end function

'-------------------------------------------------------------------------------
' getItemLibraryYear
'-------------------------------------------------------------------------------
function getItemLibraryYear(item as dynamic) as integer
    if Array_IsAssocArray(item) = false then return 0

    productionYear = Number_ToInteger(item.ProductionYear, 0)
    if productionYear > 0 then return productionYear

    premiereDate = SafeString(item.PremiereDate, "")
    if Len(premiereDate) < 4 then return 0

    yearText = Left(premiereDate, 4)
    year = Number_ToInteger(yearText, 0)
    if year <= 0 then return 0

    return year
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "library", errorMessage: "Invalid library request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "library", errorMessage: "Invalid library server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "library", errorMessage: "Invalid library token." }
    if request.userId = invalid or request.userId = "" then return { ok: false, action: "library", errorMessage: "Invalid library user." }
    if request.libraryId = invalid or request.libraryId = "" then return { ok: false, action: "library", errorMessage: "Invalid library item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' getSortBy
'-------------------------------------------------------------------------------
function getSortBy(request as dynamic) as string
    sortBy = SafeString(request.sortBy, "")
    if sortBy <> "" then return sortBy

    return "SortName"
end function

'-------------------------------------------------------------------------------
' getSortOrder
'-------------------------------------------------------------------------------
function getSortOrder(request as dynamic) as string
    if SafeString(request.sortBy, "") = "Random" then return ""

    sortOrder = SafeString(request.sortOrder, "")
    if sortOrder = "Descending" then return "Descending"

    return "Ascending"
end function

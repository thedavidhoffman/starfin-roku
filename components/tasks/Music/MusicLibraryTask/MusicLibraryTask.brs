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
        fields: "SortName,AlbumArtist,Artists,ArtistItems,ProductionYear,PremiereDate,Genres"
        enableImageTypes: "Primary"
        imageTypeLimit: 1
        enableTotalRecordCount: false
        sortBy: "SortName"
        sortOrder: "Ascending"
    }
    if request.favoriteOnly = true then params.AddReplace("filters", "IsFavorite")

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
        filterOptions: buildFilterOptions(getItemsFromPayload(response.data))
    }
end sub

'-------------------------------------------------------------------------------
' buildFilterOptions
'-------------------------------------------------------------------------------
function buildFilterOptions(albums as object) as object
    filterOptions = {
        decadeOptions: []
        genreOptions: []
    }
    if albums = invalid then return filterOptions

    decadeValues = []
    decadeValueByKey = {}
    genreLabels = []
    genreLabelByKey = {}

    for each album in albums
        year = getAlbumYear(album)
        if year > 0 then
            decade = Number_ToInteger(Fix(year / 10) * 10, 0)
            decadeKey = decade.ToStr()
            if decadeValueByKey[decadeKey] = invalid then
                decadeValueByKey[decadeKey] = decade
                decadeValues.Push(decade)
            end if
        end if

        for each genre in getAlbumGenres(album)
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
    if payload.items <> invalid then return payload.items

    return []
end function

'-------------------------------------------------------------------------------
' getAlbumYear
'-------------------------------------------------------------------------------
function getAlbumYear(album as dynamic) as integer
    if Array_IsAssocArray(album) = false then return 0

    year = Number_ToInteger(album.ProductionYear, 0)
    if year > 0 then return year

    premiereDate = SafeString(album.PremiereDate, "")
    if Len(premiereDate) < 4 then return 0

    return Number_ToInteger(Left(premiereDate, 4), 0)
end function

'-------------------------------------------------------------------------------
' getAlbumGenres
'-------------------------------------------------------------------------------
function getAlbumGenres(album as dynamic) as object
    if Array_IsAssocArray(album) = false then return []
    if album.Genres = invalid then return []

    return album.Genres
end function

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

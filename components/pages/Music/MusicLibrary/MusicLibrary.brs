'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MusicLibrary")
    m.titleLabel = m.top.findNode("titleLabel")
    m.browseByButton = m.top.findNode("browseByButton")
    m.sortButton = m.top.findNode("sortButton")
    m.filterButtonRow = m.top.findNode("filterButtonRow")
    m.emptyFilterLabel = m.top.findNode("emptyFilterLabel")
    m.filterFocusTimer = m.top.findNode("filterFocusTimer")
    m.albumsGrid = m.top.findNode("albumsGrid")
    m.artistsGrid = m.top.findNode("artistsGrid")
    m.musicLibraryTask = m.top.findNode("musicLibraryTask")
    m.musicArtistsTask = m.top.findNode("musicArtistsTask")
    m.musicLibraryTask.observeField("response", "onMusicLibraryResponse")
    m.musicArtistsTask.observeField("response", "onMusicArtistsResponse")
    m.browseByButton.observeField("overlayRequested", "onSortOverlayRequested")
    m.browseByButton.observeField("focusExitDown", "onBrowseByButtonFocusExitDown")
    m.sortButton.observeField("sortOrderChanged", "onSortOrderChanged")
    m.sortButton.observeField("focusExitDown", "onSortButtonFocusExitDown")
    m.filterButtonRow.observeField("filterSelected", "onFilterButtonRowSelected")
    m.filterButtonRow.observeField("focusExitUp", "onFilterButtonRowFocusExitUp")
    m.filterButtonRow.observeField("focusExitDown", "onFilterButtonRowFocusExitDown")
    m.filterFocusTimer.observeField("fire", "onFilterFocusTimerFired")
    m.albumsGrid.observeField("itemSelected", "onAlbumSelected")
    m.artistsGrid.observeField("itemSelected", "onArtistSelected")
    m.state = {
        request: invalid
        allAlbums: []
        albums: []
        artists: []
        selectedSortKey: "Album"
        selectedSort: getDefaultSortSelection()
        activeFilterType: ""
        selectedDecade: -1
        selectedGenre: ""
        filterCache: createEmptyFilterCache()
        sortCache: createEmptySortCache()
        lifecycle: AsyncLifecycle_Create()
    }
    syncSortControls()
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.state.request = request
    m.state.allAlbums = []
    m.state.albums = []
    m.state.artists = []
    if request.favoriteOnly = true then
        m.state.selectedSortKey = "Favorites"
        m.state.selectedSort = getFavoritesSortSelection()
    else
        m.state.selectedSortKey = "Album"
        m.state.selectedSort = getDefaultSortSelection()
    end if
    m.state.activeFilterType = ""
    m.state.selectedDecade = -1
    m.state.selectedGenre = ""
    m.state.filterCache = createEmptyFilterCache()
    m.state.sortCache = createEmptySortCache()
    syncSortControls()
    hideFilterButtonRow()
    AsyncLifecycle_Begin(m.state.lifecycle, request.libraryId)
    updateTitleLabel(0)
    renderAlbums([])
    Spinner_Show(0)

    m.musicLibraryTask.request = request
    m.musicLibraryTask.control = "run"
    if request.favoriteOnly <> true then
        m.musicArtistsTask.request = request
        m.musicArtistsTask.control = "run"
    end if
end sub

'-------------------------------------------------------------------------------
' onMusicArtistsResponse
'-------------------------------------------------------------------------------
sub onMusicArtistsResponse()
    response = m.musicArtistsTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.state.lifecycle, response, "libraryId", "musicArtists") <> true then return
    if response.ok <> true then return

    m.state.artists = getItemsFromPayload(response.payload)
    if isArtistBrowseMode() then renderArtists()
end sub

'-------------------------------------------------------------------------------
' onMusicLibraryResponse
'-------------------------------------------------------------------------------
sub onMusicLibraryResponse()
    response = m.musicLibraryTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.state.lifecycle, response, "libraryId", "musicLibrary") <> true then return

    if response.ok <> true then
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load music library."))
        return
    end if

    m.state.allAlbums = getItemsFromPayload(response.payload)
    m.state.filterCache = createFilterCacheFromOptions(response.filterOptions)
    m.state.sortCache = createEmptySortCache()
    renderCurrentAlbums()
    updateTitleLabel(m.state.albums.Count())
    Status_ClearMessage()
    Spinner_Hide()
    focusAlbums()
end sub

'-------------------------------------------------------------------------------
' renderAlbums
'-------------------------------------------------------------------------------
sub renderAlbums(albums as object)
    if albums = invalid then albums = []
    m.state.albums = albums
    m.emptyFilterLabel.visible = isFavoriteBrowseActive() and albums.Count() = 0

    content = CreateObject("roSGNode", "ContentNode")
    request = m.state.request

    for each album in albums
        if Array_IsAssocArray(album) = false then continue for

        albumName = getDisplayText(FirstNonEmpty([album.Name], "Untitled Album"))
        artistName = getDisplayText(getAlbumArtistName(album))

        child = content.createChild("ContentNode")
        child.title = albumName
        child.HDPosterUrl = getAlbumArtworkUrl(album, request)
        child.AddFields({
            artistName: artistName
            primaryLabel: artistName
            secondaryLabel: albumName
            releaseYear: getAlbumReleaseYearText(album)
            raw: album
        })
    end for

    m.albumsGrid.content = content
end sub

'-------------------------------------------------------------------------------
' getAlbumReleaseYearText
'-------------------------------------------------------------------------------
function getAlbumReleaseYearText(album as dynamic) as string
    year = getAlbumYear(album)
    if year <= 0 then return ""

    return year.ToStr()
end function

'-------------------------------------------------------------------------------
' isAlbumBrowseMode
'-------------------------------------------------------------------------------
function isAlbumBrowseMode() as boolean
    return SafeString(m.state.selectedSortKey, "Album") = "Album"
end function

'-------------------------------------------------------------------------------
' renderCurrentAlbums
'-------------------------------------------------------------------------------
sub renderCurrentAlbums()
    if isArtistBrowseMode() then
        m.emptyFilterLabel.visible = false
        renderArtists()
        return
    end if

    m.artistsGrid.visible = false
    m.albumsGrid.visible = true
    renderAlbums(getVisibleAlbums())
    updateTitleLabel(m.state.albums.Count())
    m.albumsGrid.jumpToItem = 0
    m.albumsGrid.itemFocused = 0
end sub

'-------------------------------------------------------------------------------
' renderArtists
'-------------------------------------------------------------------------------
sub renderArtists()
    artists = copyAlbums(m.state.artists)
    artists.SortBy("SortName")
    if SafeString(m.state.selectedSort.sortOrder, "Ascending") = "Descending" then reverseAlbums(artists)

    content = CreateObject("roSGNode", "ContentNode")
    request = m.state.request
    for each artist in artists
        child = content.createChild("ContentNode")
        artistId = SafeString(artist.Id, "")
        child.title = FirstNonEmpty([artist.Name], "Unknown Artist")
        child.HDPosterUrl = getArtistImageUrl(artist, request, "Primary", 340, 340)
        child.AddFields({ raw: artist, itemId: artistId })
    end for

    m.artistsGrid.content = content
    m.albumsGrid.visible = false
    m.artistsGrid.visible = true
    updateTitleLabel(artists.Count())
    m.artistsGrid.jumpToItem = 0
    m.artistsGrid.itemFocused = 0
end sub

'-------------------------------------------------------------------------------
' getArtistImageUrl
'-------------------------------------------------------------------------------
function getArtistImageUrl(artist as object, request as object, imageType as string, width as integer, height as integer) as string
    itemId = SafeString(artist.Id, "")
    tag = ""
    if imageType = "Primary" and artist.ImageTags <> invalid then tag = SafeString(artist.ImageTags.Primary, "")
    if imageType = "Logo" and artist.ImageTags <> invalid then tag = SafeString(artist.ImageTags.Logo, "")
    if imageType = "Backdrop" and artist.BackdropImageTags <> invalid and artist.BackdropImageTags.Count() > 0 then tag = SafeString(artist.BackdropImageTags[0], "")
    if itemId = "" or tag = "" then return ""
    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' isArtistBrowseMode
'-------------------------------------------------------------------------------
function isArtistBrowseMode() as boolean
    return SafeString(m.state.selectedSortKey, "Album") = "Artist"
end function

'-------------------------------------------------------------------------------
' getVisibleAlbums
'-------------------------------------------------------------------------------
function getVisibleAlbums() as object
    if isDecadeFilterActive() then return getSortedDecadeAlbums(m.state.selectedDecade.ToStr())
    if isGenreFilterActive() then return getSortedGenreAlbums(m.state.selectedGenre)

    return getSortedAlbums(m.state.allAlbums)
end function

'-------------------------------------------------------------------------------
' getAlbumArtworkUrl
'-------------------------------------------------------------------------------
function getAlbumArtworkUrl(album as dynamic, request as dynamic) as string
    if Array_IsAssocArray(album) = false then return ""
    if request = invalid then return ""

    directUrl = FirstNonEmpty([album.ImageURL, album.ImageUrl, album.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    itemId = SafeString(FirstNonEmpty([album.Id], ""), "")
    if itemId = "" then return ""

    primaryTag = ""
    if album.ImageTags <> invalid and album.ImageTags.Primary <> invalid then primaryTag = album.ImageTags.Primary
    if primaryTag = "" then return ""

    return Url_BuildImageUrl(request.server, itemId, "Primary", primaryTag, 340, 340)
end function

'-------------------------------------------------------------------------------
' getAlbumArtistName
'-------------------------------------------------------------------------------
function getAlbumArtistName(album as dynamic) as string
    if Array_IsAssocArray(album) = false then return "Unknown Artist"

    artist = FirstNonEmpty([album.AlbumArtist, album.Artist], "")
    if artist <> "" then return artist

    artist = String_GetJoinedText(album.AlbumArtists)
    if artist <> "" then return artist

    artist = String_GetJoinedText(album.Artists)
    if artist <> "" then return artist

    return "Unknown Artist"
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
' getAlbumTitle
'-------------------------------------------------------------------------------
function getAlbumTitle(album as dynamic) as string
    if Array_IsAssocArray(album) = false then return ""

    return FirstNonEmpty([album.SortName, album.Name], "")
end function

'-------------------------------------------------------------------------------
' getSortText
'-------------------------------------------------------------------------------
function getSortText(text as string) as string
    normalizedText = String_Trim(text)
    if LCase(Left(normalizedText, 4)) = "the " then return Mid(normalizedText, 5)

    return normalizedText
end function

'-------------------------------------------------------------------------------
' getDisplayText
'-------------------------------------------------------------------------------
function getDisplayText(text as string) as string
    normalizedText = String_Trim(text)
    if LCase(Left(normalizedText, 4)) = "the " then return Mid(normalizedText, 5) + ", The"

    return normalizedText
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
' getSortedAlbums
'-------------------------------------------------------------------------------
function getSortedAlbums(albums as object) as object
    selection = m.state.selectedSort
    if selection = invalid then selection = getDefaultSortSelection()

    optionKey = SafeString(selection.optionKey, "Album")
    if optionKey = "Random" then return shuffleAlbums(copyAlbums(albums))

    if optionKey = "ArtistAlbum" then
        if m.state.sortCache.artistAlbum = invalid then
            m.state.sortCache.artistAlbum = copyAlbums(albums)
            sortAlbumsByArtistThenYear(m.state.sortCache.artistAlbum)
        end if
        sortedAlbums = copyAlbums(m.state.sortCache.artistAlbum)
    else
        if m.state.sortCache.album = invalid then
            m.state.sortCache.album = copyAlbums(albums)
            sortAlbumsByTitleThenArtist(m.state.sortCache.album)
        end if
        sortedAlbums = copyAlbums(m.state.sortCache.album)
    end if

    if SafeString(selection.sortOrder, "Ascending") = "Descending" then reverseAlbums(sortedAlbums)
    return sortedAlbums
end function

'-------------------------------------------------------------------------------
' sortAlbumsByTitleThenArtist
'-------------------------------------------------------------------------------
sub sortAlbumsByTitleThenArtist(albums as object)
    sortAlbumsByMode(albums, "titleArtist")
end sub

'-------------------------------------------------------------------------------
' sortAlbumsByArtistThenYear
'-------------------------------------------------------------------------------
sub sortAlbumsByArtistThenYear(albums as object)
    sortAlbumsByMode(albums, "artistYearTitle")
end sub

'-------------------------------------------------------------------------------
' sortAlbumsByYearThenTitle
'-------------------------------------------------------------------------------
sub sortAlbumsByYearThenTitle(albums as object)
    sortAlbumsByMode(albums, "yearTitleArtist")
end sub

'-------------------------------------------------------------------------------
' sortAlbumsByMode
'-------------------------------------------------------------------------------
sub sortAlbumsByMode(albums as object, mode as string)
    if albums = invalid or albums.Count() < 2 then return

    entries = []
    for each album in albums
        entries.Push({
            album: album
            artist: getSortText(getAlbumArtistName(album))
            title: getSortText(getAlbumTitle(album))
            year: getAlbumYear(album)
        })
    end for

    sortedEntries = mergeSortAlbumEntries(entries, mode)
    for i = 0 to sortedEntries.Count() - 1
        albums[i] = sortedEntries[i].album
    end for
end sub

'-------------------------------------------------------------------------------
' mergeSortAlbumEntries
'-------------------------------------------------------------------------------
function mergeSortAlbumEntries(entries as object, mode as string) as object
    sortedEntries = entries
    width = 1
    entryCount = sortedEntries.Count()

    while width < entryCount
        mergedEntries = []
        startIndex = 0
        while startIndex < entryCount
            leftIndex = startIndex
            rightIndex = startIndex + width
            leftEnd = rightIndex
            if leftEnd > entryCount then leftEnd = entryCount
            rightEnd = startIndex + (width * 2)
            if rightEnd > entryCount then rightEnd = entryCount

            while leftIndex < leftEnd or rightIndex < rightEnd
                if rightIndex >= rightEnd then
                    mergedEntries.Push(sortedEntries[leftIndex])
                    leftIndex = leftIndex + 1
                else if leftIndex >= leftEnd then
                    mergedEntries.Push(sortedEntries[rightIndex])
                    rightIndex = rightIndex + 1
                else if compareAlbumSortEntries(sortedEntries[leftIndex], sortedEntries[rightIndex], mode) <= 0 then
                    mergedEntries.Push(sortedEntries[leftIndex])
                    leftIndex = leftIndex + 1
                else
                    mergedEntries.Push(sortedEntries[rightIndex])
                    rightIndex = rightIndex + 1
                end if
            end while

            startIndex = startIndex + (width * 2)
        end while

        sortedEntries = mergedEntries
        width = width * 2
    end while

    return sortedEntries
end function

'-------------------------------------------------------------------------------
' compareAlbumSortEntries
'-------------------------------------------------------------------------------
function compareAlbumSortEntries(left as object, right as object, mode as string) as integer
    if mode = "artistYearTitle" then
        comparison = String_NaturalCompare(left.artist, right.artist)
        if comparison <> 0 then return comparison
        if left.year < right.year then return -1
        if left.year > right.year then return 1
        return String_NaturalCompare(left.title, right.title)
    end if

    if mode = "yearTitleArtist" then
        if left.year < right.year then return -1
        if left.year > right.year then return 1
        comparison = String_NaturalCompare(left.title, right.title)
        if comparison <> 0 then return comparison
        return String_NaturalCompare(left.artist, right.artist)
    end if

    comparison = String_NaturalCompare(left.title, right.title)
    if comparison <> 0 then return comparison
    return String_NaturalCompare(left.artist, right.artist)
end function

'-------------------------------------------------------------------------------
' createEmptySortCache
'-------------------------------------------------------------------------------
function createEmptySortCache() as object
    return {
        album: invalid
        artistAlbum: invalid
    }
end function

'-------------------------------------------------------------------------------
' copyAlbums
'-------------------------------------------------------------------------------
function copyAlbums(albums as object) as object
    copiedAlbums = []
    if albums = invalid then return copiedAlbums

    for each album in albums
        copiedAlbums.Push(album)
    end for

    return copiedAlbums
end function

'-------------------------------------------------------------------------------
' reverseAlbums
'-------------------------------------------------------------------------------
sub reverseAlbums(albums as object)
    if albums = invalid or albums.Count() < 2 then return

    leftIndex = 0
    rightIndex = albums.Count() - 1
    while leftIndex < rightIndex
        temp = albums[leftIndex]
        albums[leftIndex] = albums[rightIndex]
        albums[rightIndex] = temp
        leftIndex = leftIndex + 1
        rightIndex = rightIndex - 1
    end while
end sub

'-------------------------------------------------------------------------------
' shuffleAlbums
'-------------------------------------------------------------------------------
function shuffleAlbums(albums as object) as object
    if albums = invalid or albums.Count() < 2 then return albums

    for i = albums.Count() - 1 to 1 step -1
        swapIndex = Number_ToInteger(Rnd(0) * (i + 1))
        if swapIndex < 0 then swapIndex = 0
        if swapIndex > i then swapIndex = i

        temp = albums[i]
        albums[i] = albums[swapIndex]
        albums[swapIndex] = temp
    end for

    return albums
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
' createEmptyFilterCache
'-------------------------------------------------------------------------------
function createEmptyFilterCache() as object
    return {
        decadeOptions: []
        genreOptions: []
    }
end function

'-------------------------------------------------------------------------------
' createFilterCacheFromOptions
'-------------------------------------------------------------------------------
function createFilterCacheFromOptions(filterOptions as dynamic) as object
    cache = createEmptyFilterCache()
    if Array_IsAssocArray(filterOptions) = false then return cache

    if filterOptions.decadeOptions <> invalid then cache.decadeOptions = filterOptions.decadeOptions
    if filterOptions.genreOptions <> invalid then cache.genreOptions = filterOptions.genreOptions

    return cache
end function

'-------------------------------------------------------------------------------
' isDecadeFilterActive
'-------------------------------------------------------------------------------
function isDecadeFilterActive() as boolean
    return SafeString(m.state.activeFilterType, "") = "Decade"
end function

'-------------------------------------------------------------------------------
' isGenreFilterActive
'-------------------------------------------------------------------------------
function isGenreFilterActive() as boolean
    return SafeString(m.state.activeFilterType, "") = "Genre"
end function

' getSortedDecadeAlbums
'-------------------------------------------------------------------------------
function getSortedDecadeAlbums(decadeKey as string) as object
    albums = []
    targetDecade = Number_ToInteger(decadeKey, -1)
    if targetDecade < 0 then return albums

    for each album in m.state.allAlbums
        year = getAlbumYear(album)
        if year > 0 and Number_ToInteger(Fix(year / 10) * 10, 0) = targetDecade then albums.Push(album)
    end for

    sortAlbumsByYearThenTitle(albums)
    return albums
end function

'-------------------------------------------------------------------------------
' getSortedGenreAlbums
'-------------------------------------------------------------------------------
function getSortedGenreAlbums(genreLabel as string) as object
    albums = []
    targetGenre = LCase(String_Trim(genreLabel))
    if targetGenre = "" then return albums

    for each album in m.state.allAlbums
        if albumHasGenre(album, targetGenre) then albums.Push(album)
    end for

    sortAlbumsByTitleThenArtist(albums)
    return albums
end function

'-------------------------------------------------------------------------------
' albumHasGenre
'-------------------------------------------------------------------------------
function albumHasGenre(album as dynamic, targetGenre as string) as boolean
    for each genre in getAlbumGenres(album)
        if LCase(String_Trim(SafeString(genre, ""))) = targetGenre then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' updateTitleLabel
'-------------------------------------------------------------------------------
sub updateTitleLabel(albumCount = invalid as dynamic)
    title = "Music"
    if m.state <> invalid and m.state.request <> invalid then title = SafeString(m.state.request.title, "Music")
    if albumCount <> invalid and albumCount > 0 then title = title + " (" + albumCount.ToStr() + ")"

    m.titleLabel.text = title
end sub

'-------------------------------------------------------------------------------
' getMusicSortOptions
'-------------------------------------------------------------------------------
function getMusicSortOptions() as object
    return [
        { optionKey: "Album", sortKey: "Album", sortOrder: "Ascending", label: "Album" }
        { optionKey: "ArtistAlbum", sortKey: "ArtistAlbum", sortOrder: "Ascending", label: "Artist/Album" }
        { optionKey: "Artist", sortKey: "Artist", sortOrder: "Ascending", label: "Artist" }
        { optionKey: "Random", sortKey: "Random", sortOrder: "", label: "Random" }
        { optionKey: "Decade", sortKey: "", sortOrder: "", label: "Decade" }
        { optionKey: "Genre", sortKey: "", sortOrder: "", label: "Genre" }
        { optionKey: "Favorites", sortKey: "Album", sortOrder: "Ascending", label: "Favorites" }
    ]
end function

'-------------------------------------------------------------------------------
' getDefaultSortSelection
'-------------------------------------------------------------------------------
function getDefaultSortSelection() as object
    return {
        optionKey: "Album"
        sortKey: "Album"
        sortOrder: "Ascending"
        label: "Album"
    }
end function

'-------------------------------------------------------------------------------
' getFavoritesSortSelection
'-------------------------------------------------------------------------------
function getFavoritesSortSelection() as object
    return {
        optionKey: "Favorites"
        sortKey: "Album"
        sortOrder: "Ascending"
        label: "Favorites"
    }
end function

'-------------------------------------------------------------------------------
' isFavoriteBrowseActive
'-------------------------------------------------------------------------------
function isFavoriteBrowseActive() as boolean
    return m.state.request <> invalid and m.state.request.favoriteOnly = true
end function

'-------------------------------------------------------------------------------
' syncSortControls
'-------------------------------------------------------------------------------
sub syncSortControls()
    m.browseByButton.selectedSort = m.state.selectedSort
    m.sortButton.selectedSort = m.state.selectedSort
    m.sortButton.sortEnabled = canUseSortOrder(m.state.selectedSort)
end sub

'-------------------------------------------------------------------------------
' canUseSortOrder
'-------------------------------------------------------------------------------
function canUseSortOrder(selection as object) as boolean
    if selection = invalid then return false

    optionKey = SafeString(selection.optionKey, "")
    if optionKey = "Decade" or optionKey = "Genre" or optionKey = "Random" then return false

    sortKey = SafeString(selection.sortKey, "")
    return sortKey = "Album" or sortKey = "ArtistAlbum" or sortKey = "Artist"
end function

'-------------------------------------------------------------------------------
' onSortOverlayRequested
'-------------------------------------------------------------------------------
sub onSortOverlayRequested()
    request = m.browseByButton.overlayRequested
    if request = invalid then return

    request.sourcePage = "musicLibrary"
    request.selectedSortKey = m.state.selectedSortKey
    request.sortOptions = getMusicSortOptions()
    m.top.overlayRequested = request
end sub

'-------------------------------------------------------------------------------
' onSortOrderChanged
'-------------------------------------------------------------------------------
sub onSortOrderChanged()
    selection = m.sortButton.sortOrderChanged
    if selection = invalid then return
    if canUseSortOrder(m.state.selectedSort) <> true then return

    sortOrder = SafeString(selection.sortOrder, "Ascending")
    if sortOrder <> "Descending" then sortOrder = "Ascending"
    if SafeString(m.state.selectedSort.sortOrder, "Ascending") = sortOrder then return

    m.state.selectedSort.sortOrder = sortOrder
    syncSortControls()
    renderCurrentAlbums()
end sub

'-------------------------------------------------------------------------------
' applySortSelection
'-------------------------------------------------------------------------------
function applySortSelection(selection as object) as boolean
    if selection = invalid then return false

    optionKey = SafeString(selection.optionKey, "")
    if optionKey = "" then return false
    if optionKey = "Favorites" then
        if isFavoriteBrowseActive() then return false

        m.state.activeFilterType = ""
        m.state.selectedDecade = -1
        m.state.selectedGenre = ""
        hideFilterButtonRow()
        m.state.selectedSortKey = "Favorites"
        m.state.selectedSort = getFavoritesSortSelection()
        m.state.request.favoriteOnly = true
        syncSortControls()
        reloadMusicLibrary()
        return false
    end if

    wasFavoriteBrowse = isFavoriteBrowseActive()
    if wasFavoriteBrowse then
        m.state.request.favoriteOnly = false
        if optionKey = "Decade" or optionKey = "Genre" then optionKey = "Album"
    end if

    if optionKey = "Decade" then
        m.state.selectedSortKey = optionKey
        m.state.selectedSort = {
            optionKey: "Decade"
            sortKey: "Album"
            sortOrder: "Ascending"
            label: "Decade"
        }
        m.state.activeFilterType = "Decade"
        m.state.selectedDecade = getFirstDecadeFilterValue(m.state.filterCache.decadeOptions)
        syncSortControls()
        showDecadeFilterRow()
        queueFilterButtonRowFocus()
        return false
    end if

    if optionKey = "Genre" then
        m.state.selectedSortKey = optionKey
        m.state.selectedSort = {
            optionKey: "Genre"
            sortKey: "Album"
            sortOrder: "Ascending"
            label: "Genre"
        }
        m.state.activeFilterType = "Genre"
        m.state.selectedGenre = getFirstGenreFilterValue(m.state.filterCache.genreOptions)
        syncSortControls()
        showGenreFilterRow()
        queueFilterButtonRowFocus()
        return false
    end if

    m.state.activeFilterType = ""
    m.state.selectedDecade = -1
    m.state.selectedGenre = ""
    hideFilterButtonRow()

    if optionKey = "Random" then
        m.state.selectedSort = {
            optionKey: "Random"
            sortKey: "Random"
            sortOrder: ""
            label: "Random"
        }
    else if optionKey = "ArtistAlbum" then
        m.state.selectedSort = {
            optionKey: "ArtistAlbum"
            sortKey: "ArtistAlbum"
            sortOrder: "Ascending"
            label: "Artist/Album"
        }
    else if optionKey = "Artist" then
        m.state.selectedSort = {
            optionKey: "Artist"
            sortKey: "Artist"
            sortOrder: "Ascending"
            label: "Artist"
        }
    else
        m.state.selectedSort = getDefaultSortSelection()
    end if

    m.state.selectedSortKey = SafeString(m.state.selectedSort.optionKey, "Album")
    syncSortControls()
    if wasFavoriteBrowse then
        reloadMusicLibrary()
    else
        renderCurrentAlbums()
    end if
    return false
end function

'-------------------------------------------------------------------------------
' reloadMusicLibrary
'-------------------------------------------------------------------------------
sub reloadMusicLibrary()
    request = m.state.request
    if request = invalid then return

    m.state.allAlbums = []
    m.state.albums = []
    m.state.artists = []
    m.state.filterCache = createEmptyFilterCache()
    m.state.sortCache = createEmptySortCache()
    m.albumsGrid.visible = true
    m.artistsGrid.visible = false
    AsyncLifecycle_Begin(m.state.lifecycle, request.libraryId)
    updateTitleLabel(0)
    renderAlbums([])
    Spinner_Show(0)
    m.musicLibraryTask.control = "stop"
    m.musicLibraryTask.request = request
    m.musicLibraryTask.control = "run"
    m.musicArtistsTask.control = "stop"
    if request.favoriteOnly <> true then
        m.musicArtistsTask.request = request
        m.musicArtistsTask.control = "run"
    end if
end sub

'-------------------------------------------------------------------------------
' showDecadeFilterRow
'-------------------------------------------------------------------------------
sub showDecadeFilterRow()
    options = m.state.filterCache.decadeOptions
    if options = invalid then options = []
    if m.state.selectedDecade < 0 then m.state.selectedDecade = getFirstDecadeFilterValue(options)

    m.filterButtonRow.filterType = "Decade"
    m.filterButtonRow.items = options
    m.filterButtonRow.selectedValue = m.state.selectedDecade.ToStr()
    m.filterButtonRow.visible = options.Count() > 0
    updateGridLayout()
    renderCurrentAlbums()
end sub

'-------------------------------------------------------------------------------
' showGenreFilterRow
'-------------------------------------------------------------------------------
sub showGenreFilterRow()
    options = m.state.filterCache.genreOptions
    if options = invalid then options = []
    if m.state.selectedGenre = "" then m.state.selectedGenre = getFirstGenreFilterValue(options)

    m.filterButtonRow.filterType = "Genre"
    m.filterButtonRow.items = options
    m.filterButtonRow.selectedValue = m.state.selectedGenre
    m.filterButtonRow.visible = options.Count() > 0
    updateGridLayout()
    renderCurrentAlbums()
end sub

'-------------------------------------------------------------------------------
' hideFilterButtonRow
'-------------------------------------------------------------------------------
sub hideFilterButtonRow()
    m.filterButtonRow.visible = false
    m.filterButtonRow.items = []
    m.filterButtonRow.selectedValue = ""
    updateGridLayout()
end sub

'-------------------------------------------------------------------------------
' updateGridLayout
'-------------------------------------------------------------------------------
sub updateGridLayout()
    y = 208
    if m.filterButtonRow <> invalid and m.filterButtonRow.visible = true then y = 292
    m.albumsGrid.translation = [48, y]
    m.artistsGrid.translation = [48, y]
end sub

'-------------------------------------------------------------------------------
' getFirstDecadeFilterValue
'-------------------------------------------------------------------------------
function getFirstDecadeFilterValue(options as object) as integer
    if options = invalid or options.Count() = 0 then return -1

    return Number_ToInteger(options[0].value, -1)
end function

'-------------------------------------------------------------------------------
' getFirstGenreFilterValue
'-------------------------------------------------------------------------------
function getFirstGenreFilterValue(options as object) as string
    if options = invalid or options.Count() = 0 then return ""

    return SafeString(options[0].value, "")
end function

'-------------------------------------------------------------------------------
' onFilterButtonRowSelected
'-------------------------------------------------------------------------------
sub onFilterButtonRowSelected()
    selected = m.filterButtonRow.filterSelected
    if selected = invalid then return

    filterType = SafeString(selected.type, "")
    if filterType = "Decade" then
        m.state.selectedDecade = Number_ToInteger(selected.value, -1)
        m.filterButtonRow.selectedValue = m.state.selectedDecade.ToStr()
    else if filterType = "Genre" then
        m.state.selectedGenre = SafeString(selected.value, "")
        m.filterButtonRow.selectedValue = m.state.selectedGenre
    else
        return
    end if

    m.filterButtonRow.setFocus(true)
    renderCurrentAlbums()
end sub

'-------------------------------------------------------------------------------
' focusBrowseByButton
'-------------------------------------------------------------------------------
function focusBrowseByButton() as boolean
    m.top.setFocus(true)
    m.browseByButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' focusFilterButtonRow
'-------------------------------------------------------------------------------
function focusFilterButtonRow() as boolean
    if m.filterButtonRow.visible <> true then return false

    m.top.setFocus(true)
    m.filterButtonRow.callFunc("focusFirstButton")
    return true
end function

'-------------------------------------------------------------------------------
' queueFilterButtonRowFocus
'-------------------------------------------------------------------------------
sub queueFilterButtonRowFocus()
    m.filterFocusTimer.control = "stop"
    m.filterFocusTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' onFilterFocusTimerFired
'-------------------------------------------------------------------------------
sub onFilterFocusTimerFired()
    focusFilterButtonRow()
end sub

'-------------------------------------------------------------------------------
' focusSortButton
'-------------------------------------------------------------------------------
function focusSortButton() as boolean
    if m.sortButton.focusable <> true then return false

    m.top.setFocus(true)
    m.sortButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' onBrowseByButtonFocusExitDown
'-------------------------------------------------------------------------------
sub onBrowseByButtonFocusExitDown()
    if focusFilterButtonRow() <> true then focusAlbums()
end sub

'-------------------------------------------------------------------------------
' onSortButtonFocusExitDown
'-------------------------------------------------------------------------------
sub onSortButtonFocusExitDown()
    if focusFilterButtonRow() <> true then focusAlbums()
end sub

'-------------------------------------------------------------------------------
' onFilterButtonRowFocusExitUp
'-------------------------------------------------------------------------------
sub onFilterButtonRowFocusExitUp()
    focusBrowseByButton()
end sub

'-------------------------------------------------------------------------------
' onFilterButtonRowFocusExitDown
'-------------------------------------------------------------------------------
sub onFilterButtonRowFocusExitDown()
    focusAlbums()
end sub

'-------------------------------------------------------------------------------
' focusAlbums
'-------------------------------------------------------------------------------
sub focusAlbums()
    grid = getActiveGrid()
    if grid.content = invalid or grid.content.getChildCount() = 0 then
        m.top.setFocus(true)
        return
    end if

    m.top.setFocus(true)
    grid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' getActiveGrid
'-------------------------------------------------------------------------------
function getActiveGrid() as object
    if isArtistBrowseMode() then return m.artistsGrid
    return m.albumsGrid
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.state.lifecycle, m.state.request, "libraryId")
    focusAlbums()
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.state.lifecycle)
    m.musicLibraryTask.control = "stop"
    m.musicArtistsTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onAlbumSelected
'-------------------------------------------------------------------------------
sub onAlbumSelected()
    selected = m.albumsGrid.itemSelected
    if selected = invalid or selected < 0 then return
    if m.albumsGrid.content = invalid then return
    if selected >= m.albumsGrid.content.getChildCount() then return

    albumNode = m.albumsGrid.content.getChild(selected)
    if albumNode = invalid then return

    raw = albumNode.raw
    itemId = ""
    if raw <> invalid then itemId = SafeString(FirstNonEmpty([raw.Id], ""), "")
    if itemId = "" then return

    m.top.selectedAlbum = {
        itemId: itemId
        item: raw
    }
end sub

'-------------------------------------------------------------------------------
' onArtistSelected
'-------------------------------------------------------------------------------
sub onArtistSelected()
    selectedIndex = m.artistsGrid.itemSelected
    content = m.artistsGrid.content
    if content = invalid or selectedIndex < 0 or selectedIndex >= content.getChildCount() then return

    node = content.getChild(selectedIndex)
    raw = node.raw
    if raw = invalid then return

    musicBrainzArtistId = ""
    if raw.ProviderIds <> invalid then musicBrainzArtistId = SafeString(raw.ProviderIds.MusicBrainzArtist, "")
    m.top.selectedArtist = {
        itemId: SafeString(raw.Id, "")
        musicBrainzArtistId: musicBrainzArtistId
        item: raw
        albums: getAlbumsForArtist(raw)
        backdropUrl: getArtistImageUrl(raw, m.state.request, "Backdrop", 1920, 1080)
        logoUrl: getArtistImageUrl(raw, m.state.request, "Logo", 600, 300)
    }
end sub

'-------------------------------------------------------------------------------
' getAlbumsForArtist
'-------------------------------------------------------------------------------
function getAlbumsForArtist(artist as object) as object
    albums = []
    artistId = SafeString(artist.Id, "")
    artistName = LCase(String_Trim(SafeString(artist.Name, "")))

    for each album in m.state.allAlbums
        if albumMatchesArtist(album, artistId, artistName) then albums.Push(album)
    end for
    sortAlbumsByYearThenTitle(albums)
    return albums
end function

'-------------------------------------------------------------------------------
' albumMatchesArtist
'-------------------------------------------------------------------------------
function albumMatchesArtist(album as object, artistId as string, artistName as string) as boolean
    if album.ArtistItems <> invalid then
        for each artistItem in album.ArtistItems
            if artistId <> "" and SafeString(artistItem.Id, "") = artistId then return true
            if artistName <> "" and LCase(String_Trim(SafeString(artistItem.Name, ""))) = artistName then return true
        end for
    end if

    if artistName <> "" and LCase(String_Trim(SafeString(album.AlbumArtist, ""))) = artistName then return true
    if album.Artists <> invalid then
        for each name in album.Artists
            if LCase(String_Trim(SafeString(name, ""))) = artistName then return true
        end for
    end if
    return false
end function

'-------------------------------------------------------------------------------
' isAlbumsGridAtFirstRow
'-------------------------------------------------------------------------------
function isAlbumsGridAtFirstRow() as boolean
    grid = getActiveGrid()
    focusedIndex = grid.itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex < grid.numColumns
end function

'-------------------------------------------------------------------------------
' isFirstAlbumFocused
'-------------------------------------------------------------------------------
function isFirstAlbumFocused() as boolean
    focusedIndex = getActiveGrid().itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex <= 0
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if key = "options" and getActiveGrid().isInFocusChain() then return openMediaActions()

    if key = "up" and m.browseByButton.isInFocusChain() then
        m.top.focusExitUp = true
        return true
    end if

    if key = "up" and m.sortButton.isInFocusChain() then
        m.top.focusExitUp = true
        return true
    end if

    if key = "right" and m.browseByButton.isInFocusChain() then
        if focusSortButton() = true then return true
        return true
    end if

    if key = "left" and m.sortButton.isInFocusChain() then return focusBrowseByButton()

    if key = "up" and isAlbumsGridAtFirstRow() then
        if focusFilterButtonRow() = true then return true
        return focusBrowseByButton()
    end if

    if key = "back" then
        if isFirstAlbumFocused() <> true then
            getActiveGrid().jumpToItem = 0
            return true
        end if

        m.top.closeRequested = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' openMediaActions
'-------------------------------------------------------------------------------
function openMediaActions() as boolean
    grid = getActiveGrid()
    if grid.content = invalid then return false

    focusedIndex = grid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then return false

    focusedNode = grid.content.getChild(focusedIndex)
    if focusedNode = invalid or focusedNode.raw = invalid then return false

    m.top.overlayRequested = {
        id: "mediaActions"
        sourcePage: "musicLibrary"
        componentName: "MediaActionsDialog"
        openFunction: "openMediaActions"
        closeField: "closeRequested"
        item: focusedNode.raw
        server: m.state.request.server
        token: m.state.request.token
        userId: m.state.request.userId
    }
    return true
end function

'-------------------------------------------------------------------------------
' applyMediaStateChange
'-------------------------------------------------------------------------------
sub applyMediaStateChange(change as object)
    applyItemsMediaStateChange(m.state.allAlbums, change)
    applyItemsMediaStateChange(m.state.albums, change)
    applyItemsMediaStateChange(m.state.artists, change)
    if isFavoriteBrowseActive() and SafeString(change.action, "") = "favorite" and change.value <> true then
        itemId = SafeString(change.itemId, "")
        m.state.allAlbums = withoutMusicLibraryItem(m.state.allAlbums, itemId)
        m.state.albums = withoutMusicLibraryItem(m.state.albums, itemId)
        m.state.artists = withoutMusicLibraryItem(m.state.artists, itemId)
        renderCurrentAlbums()
        return
    end if

    applyGridMediaStateChange(m.albumsGrid, change)
    applyGridMediaStateChange(m.artistsGrid, change)
end sub

'-------------------------------------------------------------------------------
' withoutMusicLibraryItem
'-------------------------------------------------------------------------------
function withoutMusicLibraryItem(items as object, itemId as string) as object
    remaining = []
    for each item in items
        if SafeString(item.Id, "") <> itemId then remaining.Push(item)
    end for
    return remaining
end function

'-------------------------------------------------------------------------------
' applyItemsMediaStateChange
'-------------------------------------------------------------------------------
sub applyItemsMediaStateChange(items as object, change as object)
    for each item in items
        if SafeString(item.Id, "") = SafeString(change.itemId, "") then
            MediaState_ApplyToItem(item, change)
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' applyGridMediaStateChange
'-------------------------------------------------------------------------------
sub applyGridMediaStateChange(grid as object, change as object)
    if grid.content = invalid then return

    for i = 0 to grid.content.getChildCount() - 1
        itemNode = grid.content.getChild(i)
        item = itemNode.raw
        if item <> invalid and SafeString(item.Id, "") = SafeString(change.itemId, "") then
            updatedItem = cloneMusicLibraryItem(item)
            if MediaState_ApplyToItem(updatedItem, change) <> true then return
            itemNode.raw = updatedItem
            return
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' cloneMusicLibraryItem
'-------------------------------------------------------------------------------
function cloneMusicLibraryItem(item as object) as object
    clone = {}
    for each key in item
        clone[key] = item[key]
    end for

    userData = {}
    if item.UserData <> invalid then
        for each key in item.UserData
            userData[key] = item.UserData[key]
        end for
    end if
    clone.UserData = userData
    return clone
end function

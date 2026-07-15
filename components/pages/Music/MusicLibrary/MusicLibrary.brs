'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MusicLibrary")
    m.titleLabel = m.top.findNode("titleLabel")
    m.browseByButton = m.top.findNode("browseByButton")
    m.sortButton = m.top.findNode("sortButton")
    m.filterButtonRow = m.top.findNode("filterButtonRow")
    m.filterFocusTimer = m.top.findNode("filterFocusTimer")
    m.albumsGrid = m.top.findNode("albumsGrid")
    m.musicLibraryTask = m.top.findNode("musicLibraryTask")
    m.musicLibraryTask.observeField("response", "onMusicLibraryResponse")
    m.browseByButton.observeField("overlayRequested", "onSortOverlayRequested")
    m.browseByButton.observeField("focusExitDown", "onBrowseByButtonFocusExitDown")
    m.sortButton.observeField("sortOrderChanged", "onSortOrderChanged")
    m.sortButton.observeField("focusExitDown", "onSortButtonFocusExitDown")
    m.filterButtonRow.observeField("filterSelected", "onFilterButtonRowSelected")
    m.filterButtonRow.observeField("focusExitUp", "onFilterButtonRowFocusExitUp")
    m.filterButtonRow.observeField("focusExitDown", "onFilterButtonRowFocusExitDown")
    m.filterFocusTimer.observeField("fire", "onFilterFocusTimerFired")
    m.albumsGrid.observeField("itemSelected", "onAlbumSelected")
    m.state = {
        request: invalid
        allAlbums: []
        albums: []
        selectedSortKey: "Album"
        selectedSort: getDefaultSortSelection()
        activeFilterType: ""
        selectedDecade: -1
        selectedGenre: ""
        filterCache: createEmptyFilterCache()
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
    m.state.selectedSortKey = "Album"
    m.state.selectedSort = getDefaultSortSelection()
    m.state.activeFilterType = ""
    m.state.selectedDecade = -1
    m.state.selectedGenre = ""
    m.state.filterCache = createEmptyFilterCache()
    syncSortControls()
    hideFilterButtonRow()
    AsyncLifecycle_Begin(m.state.lifecycle, request.libraryId)
    updateTitleLabel(0)
    renderAlbums([])
    Spinner_Show(0)

    m.musicLibraryTask.request = request
    m.musicLibraryTask.control = "run"
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
    renderAlbums(getVisibleAlbums())
    updateTitleLabel(m.state.albums.Count())
    m.albumsGrid.jumpToItem = 0
    m.albumsGrid.itemFocused = 0
end sub

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
    sortedAlbums = copyAlbums(albums)
    if sortedAlbums.Count() < 2 then return sortedAlbums

    selection = m.state.selectedSort
    if selection = invalid then selection = getDefaultSortSelection()

    optionKey = SafeString(selection.optionKey, "Album")
    if optionKey = "Random" then return shuffleAlbums(sortedAlbums)
    if optionKey = "ArtistAlbum" then
        sortAlbumsByArtistThenYear(sortedAlbums)
    else
        sortAlbumsByTitleThenArtist(sortedAlbums)
    end if

    if SafeString(selection.sortOrder, "Ascending") = "Descending" then reverseAlbums(sortedAlbums)
    return sortedAlbums
end function

'-------------------------------------------------------------------------------
' sortAlbumsByTitleThenArtist
'-------------------------------------------------------------------------------
sub sortAlbumsByTitleThenArtist(albums as object)
    for i = 1 to albums.Count() - 1
        currentAlbum = albums[i]
        insertIndex = i - 1
        while insertIndex >= 0 and shouldTitleAlbumMoveRight(albums[insertIndex], currentAlbum)
            albums[insertIndex + 1] = albums[insertIndex]
            insertIndex = insertIndex - 1
        end while
        albums[insertIndex + 1] = currentAlbum
    end for
end sub

'-------------------------------------------------------------------------------
' shouldTitleAlbumMoveRight
'-------------------------------------------------------------------------------
function shouldTitleAlbumMoveRight(left as dynamic, right as dynamic) as boolean
    titleCompare = String_NaturalCompare(getSortText(getAlbumTitle(left)), getSortText(getAlbumTitle(right)))
    if titleCompare > 0 then return true
    if titleCompare < 0 then return false

    return String_NaturalCompare(getSortText(getAlbumArtistName(left)), getSortText(getAlbumArtistName(right))) > 0
end function

'-------------------------------------------------------------------------------
' sortAlbumsByArtistThenYear
'-------------------------------------------------------------------------------
sub sortAlbumsByArtistThenYear(albums as object)
    for i = 1 to albums.Count() - 1
        currentAlbum = albums[i]
        insertIndex = i - 1
        while insertIndex >= 0 and shouldArtistAlbumMoveRight(albums[insertIndex], currentAlbum)
            albums[insertIndex + 1] = albums[insertIndex]
            insertIndex = insertIndex - 1
        end while
        albums[insertIndex + 1] = currentAlbum
    end for
end sub

'-------------------------------------------------------------------------------
' shouldArtistAlbumMoveRight
'-------------------------------------------------------------------------------
function shouldArtistAlbumMoveRight(left as dynamic, right as dynamic) as boolean
    artistCompare = String_NaturalCompare(getSortText(getAlbumArtistName(left)), getSortText(getAlbumArtistName(right)))
    if artistCompare > 0 then return true
    if artistCompare < 0 then return false

    leftYear = getAlbumYear(left)
    rightYear = getAlbumYear(right)
    if leftYear > rightYear then return true
    if leftYear < rightYear then return false

    return String_NaturalCompare(getSortText(getAlbumTitle(left)), getSortText(getAlbumTitle(right))) > 0
end function

'-------------------------------------------------------------------------------
' sortAlbumsByYearThenTitle
'-------------------------------------------------------------------------------
sub sortAlbumsByYearThenTitle(albums as object)
    for i = 1 to albums.Count() - 1
        currentAlbum = albums[i]
        insertIndex = i - 1
        while insertIndex >= 0 and shouldYearAlbumMoveRight(albums[insertIndex], currentAlbum)
            albums[insertIndex + 1] = albums[insertIndex]
            insertIndex = insertIndex - 1
        end while
        albums[insertIndex + 1] = currentAlbum
    end for
end sub

'-------------------------------------------------------------------------------
' shouldYearAlbumMoveRight
'-------------------------------------------------------------------------------
function shouldYearAlbumMoveRight(left as dynamic, right as dynamic) as boolean
    leftYear = getAlbumYear(left)
    rightYear = getAlbumYear(right)
    if leftYear > rightYear then return true
    if leftYear < rightYear then return false

    titleCompare = String_NaturalCompare(getSortText(getAlbumTitle(left)), getSortText(getAlbumTitle(right)))
    if titleCompare > 0 then return true
    if titleCompare < 0 then return false

    return String_NaturalCompare(getSortText(getAlbumArtistName(left)), getSortText(getAlbumArtistName(right))) > 0
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

'-------------------------------------------------------------------------------
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
        { optionKey: "Random", sortKey: "Random", sortOrder: "", label: "Random" }
        { optionKey: "Decade", sortKey: "", sortOrder: "", label: "Decade" }
        { optionKey: "Genre", sortKey: "", sortOrder: "", label: "Genre" }
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
    return sortKey = "Album" or sortKey = "ArtistAlbum"
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
    else
        m.state.selectedSort = getDefaultSortSelection()
    end if

    m.state.selectedSortKey = SafeString(m.state.selectedSort.optionKey, "Album")
    syncSortControls()
    renderCurrentAlbums()
    return false
end function

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
    if m.albumsGrid.content = invalid or m.albumsGrid.content.getChildCount() = 0 then
        m.top.setFocus(true)
        return
    end if

    m.top.setFocus(true)
    m.albumsGrid.setFocus(true)
end sub

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
' isAlbumsGridAtFirstRow
'-------------------------------------------------------------------------------
function isAlbumsGridAtFirstRow() as boolean
    focusedIndex = m.albumsGrid.itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex < m.albumsGrid.numColumns
end function

'-------------------------------------------------------------------------------
' isFirstAlbumFocused
'-------------------------------------------------------------------------------
function isFirstAlbumFocused() as boolean
    focusedIndex = m.albumsGrid.itemFocused
    if focusedIndex = invalid then return true

    return focusedIndex <= 0
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

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
            m.albumsGrid.jumpToItem = 0
            return true
        end if

        m.top.closeRequested = true
        return true
    end if

    return false
end function

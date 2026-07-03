'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Library")
    m.titleLabel = m.top.findNode("titleLabel")
    m.sortButton = m.top.findNode("sortButton")
    m.letterGutterButton = m.top.findNode("letterGutterButton")
    m.itemsGrid = m.top.findNode("itemsGrid")
    m.libraryTask = m.top.findNode("libraryTask")

    m.libraryTask.observeField("response", "onLibraryResponse")
    m.sortButton.observeField("overlayRequested", "onSortOverlayRequested")
    m.sortButton.observeField("focusExitDown", "onSortFocusExitDown")
    m.letterGutterButton.observeField("focused", "onLetterGutterButtonFocused")
    m.letterGutterButton.observeField("buttonSelected", "onLetterGutterButtonSelected")
    m.itemsGrid.observeField("itemSelected", "onItemSelected")
    m.pageState = {
        request: invalid
        items: []
        imageAspect: "poster"
        letterGridOpen: false
        letterGridPanel: {
            x: 72
            y: 208
        }
        isThumbnailLayout: false
        availableLetters: {}
        selectedSortKey: "SortName:Ascending"
        selectedSort: invalid
        refocusSortButtonAfterLoad: false
    }
    m.sortButton.selectedSort = getDefaultSortSelection()
    m.pageState.selectedSort = getDefaultSortSelection()
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    m.pageState.imageAspect = getLibraryImageAspect()
    applyGridLayout(m.pageState.imageAspect)
    renderItems(m.pageState.items)
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.imageAspect = getLibraryImageAspect()
    if request.sortBy = invalid then request.sortBy = "SortName"
    if request.sortOrder = invalid then request.sortOrder = "Ascending"
    m.pageState.selectedSort = buildSortSelection(request.sortBy, request.sortOrder)
    m.pageState.selectedSortKey = m.pageState.selectedSort.optionKey
    m.pageState.refocusSortButtonAfterLoad = false
    m.sortButton.selectedSort = m.pageState.selectedSort
    updateTitleLabel()
    applyGridLayout(m.pageState.imageAspect)
    Spinner_Show()
    closeLetterGrid(false)
    renderItems([])

    m.libraryTask.request = request
    m.libraryTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onLibraryResponse
'-------------------------------------------------------------------------------
sub onLibraryResponse()
    response = m.libraryTask.response
    if response = invalid then return

    Spinner_Hide()

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load library."))
        return
    end if

    m.pageState.items = getItemsFromPayload(response.payload)
    renderItems(m.pageState.items)
    updateTitleLabel(m.pageState.items.Count())
    Status_ClearMessage()
    if m.pageState.refocusSortButtonAfterLoad = true then
        m.pageState.refocusSortButtonAfterLoad = false
        focusSortButton()
    else
        focusItemsIfActive()
    end if
end sub

'-------------------------------------------------------------------------------
' onItemSelected
'-------------------------------------------------------------------------------
sub onItemSelected()
    selected = m.itemsGrid.itemSelected
    if selected = invalid then return
    if m.itemsGrid.content = invalid then return

    node = m.itemsGrid.content.getChild(selected)
    if node = invalid then return

    item = node.raw
    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if itemId = "" then return

    if isPlayableMovie(item) then
        m.top.selectedMovie = { itemId: itemId, item: item }
    else if isTVSeries(item) then
        m.top.selectedSeries = { itemId: itemId, item: item }
    end if
end sub

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems(items as object)
    content = CreateObject("roSGNode", "ContentNode")
    imageAspect = m.pageState.imageAspect

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item, imageAspect)
        child.AddFields({
            imageAspect: imageAspect
            raw: item
        })
    end for

    m.itemsGrid.content = content
    m.itemsGrid.visible = content.getChildCount() > 0
    updateAvailableLetters(items)
end sub

'-------------------------------------------------------------------------------
' updateTitleLabel
'-------------------------------------------------------------------------------
sub updateTitleLabel(itemCount = invalid as dynamic)
    request = m.pageState.request
    title = "Library"
    if request <> invalid then title = SafeString(request.title, "Library")

    if itemCount <> invalid then title = title + MediaMetadata_BulletSeparator() + Number_FormatWithThousandsSeparator(itemCount) + " items"

    m.titleLabel.text = title
end sub

'-------------------------------------------------------------------------------
' updateAvailableLetters
'-------------------------------------------------------------------------------
sub updateAvailableLetters(items as object)
    availableLetters = {}

    for each item in items
        letter = getItemSortLetter(item)
        if letter <> "" then availableLetters[letter] = true
    end for

    m.pageState.availableLetters = availableLetters
end sub

'-------------------------------------------------------------------------------
' onLetterGutterButtonFocused
'-------------------------------------------------------------------------------
sub onLetterGutterButtonFocused()
    if m.letterGutterButton.focused <> true then return

    openLetterGrid()
end sub

'-------------------------------------------------------------------------------
' onLetterGutterButtonSelected
'-------------------------------------------------------------------------------
sub onLetterGutterButtonSelected()
    openLetterGrid()
end sub

'-------------------------------------------------------------------------------
' openLetterGrid
'-------------------------------------------------------------------------------
function openLetterGrid() as boolean
    m.pageState.letterGridOpen = true
    m.top.letterGridRequested = {
        id: "letterGrid"
        componentName: "LetterGridDialog"
        openFunction: "openGrid"
        closeFields: ["closeRequested", "letterSelected"]
        availableLetters: m.pageState.availableLetters
        panelX: m.pageState.letterGridPanel.x
        panelY: m.pageState.letterGridPanel.y
    }
    return true
end function

'-------------------------------------------------------------------------------
' closeLetterGrid
'-------------------------------------------------------------------------------
sub closeLetterGrid(focusItems as boolean)
    wasOpen = m.pageState <> invalid and m.pageState.letterGridOpen = true
    if m.pageState <> invalid then m.pageState.letterGridOpen = false

    if wasOpen then
        m.top.letterGridRequested = {
            id: "letterGrid"
            action: "close"
        }
    end if

    if focusItems = true then focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' selectLetter
'-------------------------------------------------------------------------------
sub selectLetter(letter as string)
    if letter = "" then return

    index = findFirstItemIndexForLetter(letter)
    if index < 0 then return

    closeLetterGrid(false)
    focusLibraryItem(index)
end sub

'-------------------------------------------------------------------------------
' onSortOverlayRequested
'-------------------------------------------------------------------------------
sub onSortOverlayRequested()
    request = m.sortButton.overlayRequested
    if request = invalid then return

    request.selectedSortKey = m.pageState.selectedSortKey
    m.top.overlayRequested = request
end sub

'-------------------------------------------------------------------------------
' applySortSelection
'-------------------------------------------------------------------------------
function applySortSelection(selection as object) as boolean
    if selection = invalid then return false

    selectedSortKey = getSelectionOptionKey(selection)
    if selectedSortKey = "" then return false
    if selectedSortKey = m.pageState.selectedSortKey then return false

    m.pageState.selectedSortKey = selectedSortKey
    m.pageState.selectedSort = selection
    m.sortButton.selectedSort = selection
    return true
end function

'-------------------------------------------------------------------------------
' getSelectionOptionKey
'-------------------------------------------------------------------------------
function getSelectionOptionKey(selection as object) as string
    optionKey = SafeString(selection.optionKey, "")
    if optionKey <> "" then return optionKey

    sortKey = SafeString(selection.sortKey, "")
    if sortKey = "" then return ""

    return sortKey + ":" + getSortOrderFromSelection(selection)
end function

'-------------------------------------------------------------------------------
' reloadLibraryForSort
'-------------------------------------------------------------------------------
sub reloadLibraryForSort()
    request = m.pageState.request
    if request = invalid then return
    if m.pageState.selectedSort = invalid then return

    request.sortBy = SafeString(m.pageState.selectedSort.sortKey, "SortName")
    request.sortOrder = getSortOrderFromSelection(m.pageState.selectedSort)
    m.pageState.request = request
    m.pageState.refocusSortButtonAfterLoad = true
    Spinner_Show()
    renderItems([])
    m.itemsGrid.jumpToItem = 0
    m.itemsGrid.itemFocused = 0

    m.libraryTask.request = request
    m.libraryTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' getSortOrderFromSelection
'-------------------------------------------------------------------------------
function getSortOrderFromSelection(selection as object) as string
    if selection <> invalid and SafeString(selection.sortOrder, "") = "Descending" then return "Descending"

    return "Ascending"
end function

'-------------------------------------------------------------------------------
' getDefaultSortSelection
'-------------------------------------------------------------------------------
function getDefaultSortSelection() as object
    return {
        optionKey: "SortName:Ascending"
        sortKey: "SortName"
        sortOrder: "Ascending"
        label: "Title (A-Z)"
    }
end function

'-------------------------------------------------------------------------------
' buildSortSelection
'-------------------------------------------------------------------------------
function buildSortSelection(sortKey as string, sortOrder as string) as object
    normalizedSortKey = SafeString(sortKey, "SortName")
    normalizedSortOrder = "Ascending"
    if sortOrder = "Descending" then normalizedSortOrder = "Descending"

    return {
        optionKey: normalizedSortKey + ":" + normalizedSortOrder
        sortKey: normalizedSortKey
        sortOrder: normalizedSortOrder
        label: getSortSelectionLabel(normalizedSortKey, normalizedSortOrder)
    }
end function

'-------------------------------------------------------------------------------
' getSortSelectionLabel
'-------------------------------------------------------------------------------
function getSortSelectionLabel(sortKey as string, sortOrder as string) as string
    if sortKey = "PremiereDate" then
        if sortOrder = "Descending" then return "Release Date (newest to oldest)"
        return "Release Date (oldest to newest)"
    end if

    if sortKey = "DateCreated" then
        if sortOrder = "Descending" then return "Date Added (newest to oldest)"
        return "Date Added (oldest to newest)"
    end if

    if sortOrder = "Descending" then return "Title (Z-A)"
    return "Title (A-Z)"
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusItemsIfActive
'-------------------------------------------------------------------------------
sub focusItemsIfActive()
    if m.itemsGrid.visible <> true then return
    if m.itemsGrid.content = invalid then return
    if m.itemsGrid.content.getChildCount() = 0 then return

    m.itemsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusLibraryItem
'-------------------------------------------------------------------------------
sub focusLibraryItem(index as integer)
    if m.itemsGrid = invalid then return
    if m.itemsGrid.content = invalid then return
    if index < 0 or index >= m.itemsGrid.content.getChildCount() then return

    m.itemsGrid.jumpToItem = index
    m.itemsGrid.itemFocused = index
    m.itemsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusSortButton
'-------------------------------------------------------------------------------
function focusSortButton() as boolean
    if m.sortButton = invalid then return false
    if m.sortButton.visible <> true then return false

    m.top.setFocus(true)
    m.sortButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' onSortFocusExitDown
'-------------------------------------------------------------------------------
sub onSortFocusExitDown()
    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusFirstLibraryItem
'-------------------------------------------------------------------------------
sub focusFirstLibraryItem()
    focusLibraryItem(0)
end sub

'-------------------------------------------------------------------------------
' focusLetterGutterButton
'-------------------------------------------------------------------------------
function focusLetterGutterButton() as boolean
    if m.letterGutterButton = invalid then return false
    if m.itemsGrid.visible <> true then return false

    m.letterGutterButton.setFocus(true)
    return openLetterGrid()
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    if imageAspect = "wide" then
        imageUrl = getImageUrlForType(itemId, item, "Thumb", 440, 248)
        if imageUrl <> "" then return imageUrl

        imageUrl = getImageUrlForType(itemId, item, "Backdrop", 440, 248)
        if imageUrl <> "" then return imageUrl

        return getImageUrlForType(itemId, item, "Primary", 440, 248)
    end if

    return getImageUrlForType(itemId, item, "Primary", 250, 375)
end function

'-------------------------------------------------------------------------------
' getImageUrlForType
'-------------------------------------------------------------------------------
function getImageUrlForType(itemId as string, item as dynamic, imageType as string, width as integer, height as integer) as string
    tag = getImageTag(item, imageType)
    if tag = "" then return ""

    request = m.pageState.request
    if request = invalid then return ""

    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' getImageTag
'-------------------------------------------------------------------------------
function getImageTag(item as dynamic, imageType as string) as string
    if item = invalid then return ""

    if imageType = "Backdrop" then
        if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then return item.BackdropImageTags[0]
        return ""
    end if

    if item.ImageTags = invalid then return ""
    if imageType = "Primary" and item.ImageTags.Primary <> invalid then return item.ImageTags.Primary
    if imageType = "Thumb" and item.ImageTags.Thumb <> invalid then return item.ImageTags.Thumb

    return ""
end function

'-------------------------------------------------------------------------------
' getLibraryImageAspect
'-------------------------------------------------------------------------------
function getLibraryImageAspect() as string
    settings = m.top.settings
    keys = SettingsStore_Keys()
    settingKey = keys.movieLibraryDisplay

    request = m.pageState.request
    collectionType = ""
    if request <> invalid then collectionType = SafeString(request.collectionType, "")

    if collectionType = "tvshows" then
        settingKey = keys.tvLibraryDisplay
    else if collectionType = "collection" then
        settingKey = keys.collectionDisplay
    end if

    if LCase(settings[settingKey]) = "thumbnail" then return "wide"
    return "poster"
end function

'-------------------------------------------------------------------------------
' findFirstItemIndexForLetter
'-------------------------------------------------------------------------------
function findFirstItemIndexForLetter(letter as string) as integer
    targetLetter = UCase(Left(letter, 1))
    if targetLetter = "" then return -1

    if m.itemsGrid <> invalid and m.itemsGrid.content <> invalid then
        for i = 0 to m.itemsGrid.content.getChildCount() - 1
            node = m.itemsGrid.content.getChild(i)
            if node <> invalid and getItemSortLetter(node.raw) = targetLetter then return i
        end for
    end if

    items = m.pageState.items
    if items = invalid then return -1

    for i = 0 to items.Count() - 1
        if getItemSortLetter(items[i]) = targetLetter then return i
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' getItemSortLetter
'-------------------------------------------------------------------------------
function getItemSortLetter(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    title = getItemAlphabetTitle(item)
    if title = "" then return ""

    firstLetter = UCase(Left(title, 1))
    if firstLetter >= "A" and firstLetter <= "Z" then return firstLetter

    return "#"
end function

'-------------------------------------------------------------------------------
' getItemAlphabetTitle
'-------------------------------------------------------------------------------
function getItemAlphabetTitle(item as object) as string
    sortName = String_Trim(SafeString(item.SortName, ""))
    if sortName <> "" then return sortName

    title = String_Trim(SafeString(item.Name, ""))
    if title = "" then return ""

    return stripLeadingSortArticle(title)
end function

'-------------------------------------------------------------------------------
' stripLeadingSortArticle
'-------------------------------------------------------------------------------
function stripLeadingSortArticle(title as string) as string
    normalized = LCase(title)

    if Left(normalized, 4) = "the " then return String_Trim(Mid(title, 5))
    if Left(normalized, 3) = "an " then return String_Trim(Mid(title, 4))
    if Left(normalized, 2) = "a " then return String_Trim(Mid(title, 3))

    return title
end function

'-------------------------------------------------------------------------------
' isItemsGridAtFirstColumn
'-------------------------------------------------------------------------------
function isItemsGridAtFirstColumn() as boolean
    if m.itemsGrid = invalid or m.itemsGrid.isInFocusChain() = false then return false

    focusedIndex = m.itemsGrid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0

    columns = m.itemsGrid.numColumns
    if columns = invalid or columns <= 0 then columns = 1

    return focusedIndex mod columns = 0
end function

'-------------------------------------------------------------------------------
' isItemsGridAtFirstRow
'-------------------------------------------------------------------------------
function isItemsGridAtFirstRow() as boolean
    if m.itemsGrid = invalid or m.itemsGrid.isInFocusChain() = false then return false

    focusedIndex = m.itemsGrid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0

    columns = m.itemsGrid.numColumns
    if columns = invalid or columns <= 0 then columns = 1

    return focusedIndex < columns
end function

'-------------------------------------------------------------------------------
' isItemsGridAtLastColumn
'-------------------------------------------------------------------------------
function isItemsGridAtLastColumn() as boolean
    if m.itemsGrid = invalid or m.itemsGrid.isInFocusChain() = false then return false

    focusedIndex = m.itemsGrid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0

    columns = m.itemsGrid.numColumns
    if columns = invalid or columns <= 0 then columns = 1

    itemCount = 0
    if m.itemsGrid.content <> invalid then itemCount = m.itemsGrid.content.getChildCount()
    if itemCount > 0 and focusedIndex = itemCount - 1 then return true

    return focusedIndex mod columns = columns - 1
end function

'-------------------------------------------------------------------------------
' isFirstLibraryItemFocused
'-------------------------------------------------------------------------------
function isFirstLibraryItemFocused() as boolean
    if m.itemsGrid = invalid then return true
    if m.itemsGrid.content = invalid then return true
    if m.itemsGrid.content.getChildCount() = 0 then return true

    focusedIndex = m.itemsGrid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0

    return focusedIndex = 0
end function

'-------------------------------------------------------------------------------
' applyGridLayout
'-------------------------------------------------------------------------------
sub applyGridLayout(imageAspect as string)
    if imageAspect = "wide" then
        m.pageState.isThumbnailLayout = true
        m.titleLabel.translation = [460, 120]
        m.itemsGrid.translation = [23, 208]
        applyLetterGutterButtonLayout(true, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
        applyLetterGridLayout(true, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
        m.itemsGrid.itemSize = [465, 348]
        m.itemsGrid.itemSpacing = [0, 11]
        m.itemsGrid.numColumns = 4
        m.itemsGrid.numRows = 3
        m.itemsGrid.focusBitmapUri = "pkg:/images/library/thumbnail-focus-465x348.png"
        return
    end if

    m.pageState.isThumbnailLayout = false
    m.titleLabel.translation = [460, 120]
    m.itemsGrid.translation = [96, 208]
    applyLetterGutterButtonLayout(false, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
    applyLetterGridLayout(false, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
    m.itemsGrid.itemSize = [295, 463]
    m.itemsGrid.itemSpacing = [-11, 26]
    m.itemsGrid.numColumns = 6
    m.itemsGrid.numRows = 2
    m.itemsGrid.focusBitmapUri = "pkg:/images/library/poster-focus-295x463.png"
end sub

'-------------------------------------------------------------------------------
' applyLetterGutterButtonLayout
'-------------------------------------------------------------------------------
sub applyLetterGutterButtonLayout(isThumbnailLayout as boolean, gridLeft as integer, gridTop as integer)
    if isThumbnailLayout = true then
        thumbnailVisualOffset = 20
        m.letterGutterButton.layoutMode = "horizontal"
        m.letterGutterButton.translation = [gridLeft + thumbnailVisualOffset, 156]
        return
    end if

    m.letterGutterButton.layoutMode = "vertical"
    m.letterGutterButton.translation = [24, gridTop]
end sub

'-------------------------------------------------------------------------------
' applyLetterGridLayout
'-------------------------------------------------------------------------------
sub applyLetterGridLayout(isThumbnailLayout as boolean, gridLeft as integer, gridTop as integer)
    if isThumbnailLayout = true then
        thumbnailVisualOffset = 20
        m.pageState.letterGridPanel = {
            x: gridLeft + thumbnailVisualOffset
            y: gridTop
        }
        return
    end if

    m.pageState.letterGridPanel = {
        x: 72
        y: gridTop
    }
end sub

' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if isAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items
    if payload.items <> invalid then return payload.items
    return []
end function

'-------------------------------------------------------------------------------
' isPlayableMovie
'-------------------------------------------------------------------------------
function isPlayableMovie(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    itemType = LCase(FirstNonEmpty([item.Type], ""))
    return itemType = "movie" or itemType = "video"
end function

'-------------------------------------------------------------------------------
' isTVSeries
'-------------------------------------------------------------------------------
function isTVSeries(item as dynamic) as boolean
    if isAssocArray(item) = false then return false
    return LCase(FirstNonEmpty([item.Type], "")) = "series"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if key = "left" and isItemsGridAtFirstColumn() then return openLetterGrid()
    if key = "up" and m.pageState.isThumbnailLayout = true and isItemsGridAtFirstRow() then return focusLetterGutterButton()
    if key = "up" and isItemsGridAtFirstRow() then return focusSortButton()
    if key = "right" and isItemsGridAtLastColumn() then return true
    if key = "back" then
        if m.pageState.letterGridOpen = true then
            closeLetterGrid(true)
            return true
        end if
        if isFirstLibraryItemFocused() <> true then
            focusFirstLibraryItem()
            return true
        end if
        m.top.closeRequested = true
        return true
    end if
    return false
end function

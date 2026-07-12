'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initHandlers()
    m.pageState = {
        request: invalid
        allItems: []
        items: []
        imageAspect: "poster"
        letterGridOpen: false
        letterGridPanel: {
            x: 72
            y: 208
        }
        isThumbnailLayout: false
        availableLetters: {}
        selectedSortKey: "SortName"
        selectedSort: invalid
        activeFilterType: ""
        selectedDecade: -1
        renderDecadeFilterOnApply: false
        decadeFilterOptions: []
        itemNodeCache: {}
        itemNodeCacheAspect: ""
        progressFocusedIndex: 0
        progressHoldKey: ""
        pendingFocusTarget: ""
        refocusBrowseByButtonAfterLoad: false
        refocusSortButtonAfterLoad: false
        lifecycle: AsyncLifecycle_Create()
    }
    m.browseByButton.selectedSort = getDefaultSortSelection()
    m.sortButton.selectedSort = getDefaultSortSelection()
    m.sortButton.sortEnabled = canUseSortOrder(getDefaultSortSelection())
    m.pageState.selectedSort = getDefaultSortSelection()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.log = CreateLogger("Library")
    m.titleLabel = m.top.findNode("titleLabel")
    m.browseByButton = m.top.findNode("browseByButton")
    m.sortButton = m.top.findNode("sortButton")
    m.letterGutterButton = m.top.findNode("letterGutterButton")
    m.filterButtonRow = m.top.findNode("filterButtonRow")
    m.itemsGrid = m.top.findNode("itemsGrid")
    m.libraryTask = m.top.findNode("libraryTask")
    m.libraryProgressIndicator = m.top.findNode("libraryProgressIndicator")
    m.libraryProgressHoldTimer = m.top.findNode("libraryProgressHoldTimer")
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.libraryTask.observeField("response", "onLibraryResponse")
    m.libraryProgressHoldTimer.observeField("fire", "onLibraryProgressHoldTimerFire")
    m.browseByButton.observeField("overlayRequested", "onSortOverlayRequested")
    m.browseByButton.observeField("focusExitDown", "onBrowseByButtonFocusExitDown")
    m.sortButton.observeField("sortOrderChanged", "onSortOrderChanged")
    m.sortButton.observeField("focusExitDown", "onSortButtonFocusExitDown")
    m.letterGutterButton.observeField("focused", "onLetterGutterButtonFocused")
    m.letterGutterButton.observeField("buttonSelected", "onLetterGutterButtonSelected")
    m.filterButtonRow.observeField("filterSelected", "onFilterButtonRowSelected")
    m.filterButtonRow.observeField("focusExitUp", "onFilterButtonRowFocusExitUp")
    m.filterButtonRow.observeField("focusExitDown", "onFilterButtonRowFocusExitDown")
    m.itemsGrid.observeField("itemSelected", "onItemSelected")
    m.itemsGrid.observeField("itemFocused", "onItemFocused")
    m.itemsGrid.observeField("navigationKeyPressed", "onItemsGridNavigationKeyPressed")
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    imageAspect = getLibraryImageAspect()
    if imageAspect <> m.pageState.imageAspect then
        m.pageState.imageAspect = imageAspect
        rebuildLibraryItemNodeCache()
    end if
    applyGridLayout(m.pageState.imageAspect)
    renderItems(getVisibleLibraryItems())
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    prepareLoadRequest(request)
    resetLibraryForLoad()
    runLibraryTask(request)
end sub

'-------------------------------------------------------------------------------
' prepareLoadRequest
'-------------------------------------------------------------------------------
sub prepareLoadRequest(request as object)
    m.pageState.request = request
    AsyncLifecycle_Begin(m.pageState.lifecycle, request.libraryId)
    m.pageState.imageAspect = getLibraryImageAspect()
    normalizeLoadRequestSort(request)
    m.pageState.selectedSort = buildSortSelection(request.sortBy, request.sortOrder)
    m.pageState.selectedSortKey = m.pageState.selectedSort.optionKey
    request.sortBy = SafeString(m.pageState.selectedSort.sortKey, "SortName")
    request.sortOrder = getSortOrderFromSelection(m.pageState.selectedSort)
end sub

'-------------------------------------------------------------------------------
' normalizeLoadRequestSort
'-------------------------------------------------------------------------------
sub normalizeLoadRequestSort(request as object)
    if request.sortBy = invalid then request.sortBy = "SortName"
    if request.sortOrder = invalid then request.sortOrder = "Ascending"
end sub

'-------------------------------------------------------------------------------
' resetLibraryForLoad
'-------------------------------------------------------------------------------
sub resetLibraryForLoad()
    resetFilterState()
    resetLibraryItemsState()
    resetLoadFocusState()
    syncSortControls()
    updateTitleLabel()
    hideFilterButtonRow()
    Spinner_Show(0)
    closeLetterGrid(false)
    renderItems([])
end sub

'-------------------------------------------------------------------------------
' resetFilterState
'-------------------------------------------------------------------------------
sub resetFilterState()
    m.pageState.activeFilterType = ""
    m.pageState.selectedDecade = -1
    m.pageState.renderDecadeFilterOnApply = false
    m.pageState.decadeFilterOptions = []
end sub

'-------------------------------------------------------------------------------
' resetLibraryItemsState
'-------------------------------------------------------------------------------
sub resetLibraryItemsState()
    m.pageState.allItems = []
    m.pageState.items = []
    clearLibraryItemNodeCache()
end sub

'-------------------------------------------------------------------------------
' resetLoadFocusState
'-------------------------------------------------------------------------------
sub resetLoadFocusState()
    m.pageState.pendingFocusTarget = ""
    m.pageState.refocusBrowseByButtonAfterLoad = false
    m.pageState.refocusSortButtonAfterLoad = false
end sub

'-------------------------------------------------------------------------------
' syncSortControls
'-------------------------------------------------------------------------------
sub syncSortControls()
    m.browseByButton.selectedSort = m.pageState.selectedSort
    m.sortButton.selectedSort = m.pageState.selectedSort
    m.sortButton.sortEnabled = canUseSortOrder(m.pageState.selectedSort)
end sub

'-------------------------------------------------------------------------------
' runLibraryTask
'-------------------------------------------------------------------------------
sub runLibraryTask(request as object)
    m.libraryTask.request = request
    m.libraryTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onLibraryResponse
'-------------------------------------------------------------------------------
sub onLibraryResponse()
    response = m.libraryTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.pageState.lifecycle, response, "libraryId", "library") <> true then return

    Spinner_Hide()

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load library."))
        return
    end if

    m.pageState.allItems = getItemsFromPayload(response.payload)
    m.pageState.decadeFilterOptions = buildDecadeFilterOptions(m.pageState.allItems)
    rebuildLibraryItemNodeCache()
    if isDecadeFilterActive() then
        showDecadeFilterRow()
    else
        renderItems(m.pageState.allItems)
    end if
    updateTitleLabel(m.pageState.items.Count())
    Status_ClearMessage()
    if m.pageState.refocusBrowseByButtonAfterLoad = true then
        m.pageState.refocusBrowseByButtonAfterLoad = false
        focusBrowseByButton()
    else if m.pageState.refocusSortButtonAfterLoad = true then
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
    if items = invalid then items = []
    m.pageState.items = items
    detachLibraryGridContent()
    content = buildLibraryContent(items)
    m.itemsGrid.content = content
    m.itemsGrid.visible = content.getChildCount() > 0
    updateAvailableLetters(items)
    updateLibraryProgressItemCount(content.getChildCount())
end sub

'-------------------------------------------------------------------------------
' detachLibraryGridContent
'-------------------------------------------------------------------------------
sub detachLibraryGridContent()
    if m.itemsGrid = invalid then return
    if m.itemsGrid.content = invalid then return

    childCount = m.itemsGrid.content.getChildCount()
    if childCount > 0 then m.itemsGrid.content.removeChildrenIndex(childCount, 0)
end sub

'-------------------------------------------------------------------------------
' buildLibraryContent
'-------------------------------------------------------------------------------
function buildLibraryContent(items as object) as object
    content = CreateObject("roSGNode", "ContentNode")
    if items = invalid then return content

    ensureLibraryItemNodeCache()
    for each item in items
        node = getCachedLibraryItemNode(item)
        if node <> invalid then content.appendChild(node)
    end for

    return content
end function

'-------------------------------------------------------------------------------
' clearLibraryItemNodeCache
'-------------------------------------------------------------------------------
sub clearLibraryItemNodeCache()
    m.pageState.itemNodeCache = {}
    m.pageState.itemNodeCacheAspect = ""
end sub

'-------------------------------------------------------------------------------
' rebuildLibraryItemNodeCache
'-------------------------------------------------------------------------------
sub rebuildLibraryItemNodeCache()
    clearLibraryItemNodeCache()
    ensureLibraryItemNodeCache()
end sub

'-------------------------------------------------------------------------------
' ensureLibraryItemNodeCache
'-------------------------------------------------------------------------------
sub ensureLibraryItemNodeCache()
    if m.pageState.itemNodeCacheAspect = m.pageState.imageAspect then return

    m.pageState.itemNodeCache = {}
    m.pageState.itemNodeCacheAspect = m.pageState.imageAspect
    items = m.pageState.allItems
    if items = invalid then return

    for each item in items
        itemId = getLibraryItemCacheKey(item)
        if itemId <> "" and m.pageState.itemNodeCache[itemId] = invalid then
            m.pageState.itemNodeCache[itemId] = createLibraryItemNode(item)
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' getCachedLibraryItemNode
'-------------------------------------------------------------------------------
function getCachedLibraryItemNode(item as dynamic) as dynamic
    itemId = getLibraryItemCacheKey(item)
    if itemId = "" then return createLibraryItemNode(item)

    ensureLibraryItemNodeCache()
    node = m.pageState.itemNodeCache[itemId]
    if node = invalid then
        node = createLibraryItemNode(item)
        m.pageState.itemNodeCache[itemId] = node
    end if

    return node
end function

'-------------------------------------------------------------------------------
' createLibraryItemNode
'-------------------------------------------------------------------------------
function createLibraryItemNode(item as dynamic) as dynamic
    if isAssocArray(item) = false then return invalid

    imageAspect = m.pageState.imageAspect
    node = CreateObject("roSGNode", "ContentNode")
    node.HDPosterUrl = getItemImageUrl(item, imageAspect)
    node.AddFields({
        imageAspect: imageAspect
        raw: item
    })
    return node
end function

'-------------------------------------------------------------------------------
' getLibraryItemCacheKey
'-------------------------------------------------------------------------------
function getLibraryItemCacheKey(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    return SafeString(FirstNonEmpty([item.Id], ""), "")
end function

'-------------------------------------------------------------------------------
' getVisibleLibraryItems
'-------------------------------------------------------------------------------
function getVisibleLibraryItems() as object
    if isDecadeFilterActive() then return getItemsSortedByLibraryYear(getItemsForDecade(m.pageState.selectedDecade))

    return getSortedLibraryItems(m.pageState.allItems)
end function

'-------------------------------------------------------------------------------
' renderCurrentLibraryItems
'-------------------------------------------------------------------------------
sub renderCurrentLibraryItems()
    renderItems(getVisibleLibraryItems())
    updateTitleLabel(m.pageState.items.Count())
    m.itemsGrid.jumpToItem = 0
    m.itemsGrid.itemFocused = 0
end sub

'-------------------------------------------------------------------------------
' isDecadeFilterActive
'-------------------------------------------------------------------------------
function isDecadeFilterActive() as boolean
    return SafeString(m.pageState.activeFilterType, "") = "Decade"
end function

'-------------------------------------------------------------------------------
' showDecadeFilterRow
'-------------------------------------------------------------------------------
sub showDecadeFilterRow()
    options = m.pageState.decadeFilterOptions
    if options = invalid then options = []
    if m.pageState.selectedDecade < 0 then m.pageState.selectedDecade = getFirstDecadeFilterValue(options)
    m.filterButtonRow.items = options
    m.filterButtonRow.selectedValue = m.pageState.selectedDecade
    m.filterButtonRow.visible = options.Count() > 0
    applyGridLayout(m.pageState.imageAspect)
    if m.pageState.selectedDecade >= 0 or m.pageState.renderDecadeFilterOnApply = true then renderItems(getVisibleLibraryItems())
    m.pageState.renderDecadeFilterOnApply = false
end sub

'-------------------------------------------------------------------------------
' getFirstDecadeFilterValue
'-------------------------------------------------------------------------------
function getFirstDecadeFilterValue(options as object) as integer
    if options = invalid or options.Count() = 0 then return -1

    return int(options[0].value)
end function

'-------------------------------------------------------------------------------
' hideFilterButtonRow
'-------------------------------------------------------------------------------
sub hideFilterButtonRow()
    m.filterButtonRow.visible = false
    m.filterButtonRow.items = []
    m.filterButtonRow.selectedValue = -1
    applyGridLayout(m.pageState.imageAspect)
end sub

'-------------------------------------------------------------------------------
' onFilterButtonRowSelected
'-------------------------------------------------------------------------------
sub onFilterButtonRowSelected()
    selected = m.filterButtonRow.filterSelected
    if selected = invalid then return
    if SafeString(selected.type, "") <> "Decade" then return

    m.pageState.selectedDecade = int(selected.value)
    m.filterButtonRow.selectedValue = m.pageState.selectedDecade
    renderItems(getVisibleLibraryItems())
    updateTitleLabel(m.pageState.items.Count())
    m.filterButtonRow.setFocus(true)
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
    m.pageState.pendingFocusTarget = ""
    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' buildDecadeFilterOptions
'-------------------------------------------------------------------------------
function buildDecadeFilterOptions(items as object) as object
    decadeMap = {}
    decades = []
    if items = invalid then return decades

    for each item in items
        year = getItemLibraryYear(item)
        if year <= 0 then continue for

        decade = int(Fix(year / 10) * 10)
        decadeKey = decade.ToStr()
        if decadeMap[decadeKey] = invalid then
            decadeMap[decadeKey] = true
            decades.Push(decade)
        end if
    end for

    decades.Sort()
    options = []
    for each decade in decades
        options.Push({
            label: decade.ToStr()
            value: decade
        })
    end for

    return options
end function

'-------------------------------------------------------------------------------
' getItemsForDecade
'-------------------------------------------------------------------------------
function getItemsForDecade(decade as integer) as object
    if decade < 0 then return m.pageState.allItems

    filteredItems = []
    for each item in m.pageState.allItems
        year = getItemLibraryYear(item)
        if year >= decade and year < decade + 10 then filteredItems.Push(item)
    end for

    return filteredItems
end function

'-------------------------------------------------------------------------------
' getSortedLibraryItems
'-------------------------------------------------------------------------------
function getSortedLibraryItems(items as object) as object
    sortedItems = copyLibraryItems(items)
    if sortedItems.Count() < 2 then return sortedItems

    selection = m.pageState.selectedSort
    if selection = invalid then selection = getDefaultSortSelection()
    sortKey = SafeString(selection.sortKey, "SortName")
    if sortKey = "" then return sortedItems

    if sortKey = "Random" then return shuffleLibraryItems(sortedItems)

    sortedItems.SortBy(sortKey)

    if getSortOrderFromSelection(selection) = "Descending" then reverseLibraryItems(sortedItems)

    return sortedItems
end function

'-------------------------------------------------------------------------------
' copyLibraryItems
'-------------------------------------------------------------------------------
function copyLibraryItems(items as object) as object
    copiedItems = []
    if items = invalid then return copiedItems

    for each item in items
        copiedItems.Push(item)
    end for

    return copiedItems
end function

'-------------------------------------------------------------------------------
' reverseLibraryItems
'-------------------------------------------------------------------------------
sub reverseLibraryItems(items as object)
    if items = invalid or items.Count() < 2 then return

    leftIndex = 0
    rightIndex = items.Count() - 1
    while leftIndex < rightIndex
        temp = items[leftIndex]
        items[leftIndex] = items[rightIndex]
        items[rightIndex] = temp
        leftIndex = leftIndex + 1
        rightIndex = rightIndex - 1
    end while
end sub

'-------------------------------------------------------------------------------
' shuffleLibraryItems
'-------------------------------------------------------------------------------
function shuffleLibraryItems(items as object) as object
    if items = invalid or items.Count() < 2 then return items

    for i = items.Count() - 1 to 1 step -1
        swapIndex = int(Rnd(0) * (i + 1))
        if swapIndex < 0 then swapIndex = 0
        if swapIndex > i then swapIndex = i

        temp = items[i]
        items[i] = items[swapIndex]
        items[swapIndex] = temp
    end for

    return items
end function

'-------------------------------------------------------------------------------
' getItemsSortedByLibraryYear
'-------------------------------------------------------------------------------
function getItemsSortedByLibraryYear(items as object) as object
    sortedItems = copyLibraryItems(items)
    if sortedItems.Count() < 2 then return sortedItems

    for i = 1 to sortedItems.Count() - 1
        currentItem = sortedItems[i]
        currentYear = getItemLibraryYear(currentItem)
        currentTitle = getItemAlphabetTitle(currentItem)
        insertIndex = i - 1

        while insertIndex >= 0 and shouldYearSortedItemMoveRight(sortedItems[insertIndex], currentYear, currentTitle)
            sortedItems[insertIndex + 1] = sortedItems[insertIndex]
            insertIndex = insertIndex - 1
        end while

        sortedItems[insertIndex + 1] = currentItem
    end for

    return sortedItems
end function

'-------------------------------------------------------------------------------
' shouldYearSortedItemMoveRight
'-------------------------------------------------------------------------------
function shouldYearSortedItemMoveRight(item as dynamic, targetYear as integer, targetTitle as string) as boolean
    itemYear = getItemLibraryYear(item)
    if itemYear > targetYear then return true
    if itemYear < targetYear then return false

    return LCase(getItemAlphabetTitle(item)) > LCase(targetTitle)
end function

'-------------------------------------------------------------------------------
' getItemLibraryYear
'-------------------------------------------------------------------------------
function getItemLibraryYear(item as dynamic) as integer
    if isAssocArray(item) = false then return 0

    productionYear = int(Val(SafeString(item.ProductionYear, "")))
    if productionYear > 0 then return productionYear

    premiereDate = SafeString(item.PremiereDate, "")
    if Len(premiereDate) < 4 then return 0

    yearText = Left(premiereDate, 4)
    year = Val(yearText)
    if year <= 0 then return 0

    return int(year)
end function

'-------------------------------------------------------------------------------
' onItemFocused
'-------------------------------------------------------------------------------
sub onItemFocused()
    updateLibraryProgressFocusedIndex()
end sub

'-------------------------------------------------------------------------------
' onItemsGridNavigationKeyPressed
'-------------------------------------------------------------------------------
sub onItemsGridNavigationKeyPressed()
    event = m.itemsGrid.navigationKeyPressed
    if event = invalid then return
    if m.pageState.imageAspect <> "poster" then return

    key = SafeString(event.key, "")
    if key <> "down" and key <> "up" then return

    if event.press = false then
        stopLibraryProgressHold(key)
        return
    end if

    startLibraryProgressHold(key)
    advanceLibraryProgressForKey(key)
end sub

'-------------------------------------------------------------------------------
' onLibraryProgressHoldTimerFire
'-------------------------------------------------------------------------------
sub onLibraryProgressHoldTimerFire()
    advanceLibraryProgressForKey(m.pageState.progressHoldKey)
end sub

'-------------------------------------------------------------------------------
' startLibraryProgressHold
'-------------------------------------------------------------------------------
sub startLibraryProgressHold(key as string)
    m.pageState.progressHoldKey = key
    m.libraryProgressHoldTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' stopLibraryProgressHold
'-------------------------------------------------------------------------------
sub stopLibraryProgressHold(key = invalid as dynamic)
    if key <> invalid and key <> "" and key <> m.pageState.progressHoldKey then return

    m.pageState.progressHoldKey = ""
    m.libraryProgressHoldTimer.control = "stop"
end sub

'-------------------------------------------------------------------------------
' advanceLibraryProgressForKey
'-------------------------------------------------------------------------------
sub advanceLibraryProgressForKey(key as string)
    if key <> "down" and key <> "up" then return
    if m.pageState.imageAspect <> "poster" then
        stopLibraryProgressHold()
        return
    end if

    itemCount = getLibraryItemCount()
    if itemCount <= 0 then
        stopLibraryProgressHold()
        return
    end if

    columns = m.itemsGrid.numColumns
    if columns = invalid or columns <= 0 then columns = 1

    focusedIndex = m.pageState.progressFocusedIndex
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = getCurrentLibraryFocusedIndex()

    if key = "down" then
        focusedIndex = focusedIndex + columns
    else if key = "up" then
        focusedIndex = focusedIndex - columns
    end if

    if focusedIndex < 0 then focusedIndex = 0
    if focusedIndex >= itemCount then focusedIndex = itemCount - 1

    m.pageState.progressFocusedIndex = focusedIndex
    m.libraryProgressIndicator.focusedIndex = focusedIndex
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
    request = m.browseByButton.overlayRequested
    if request = invalid then return

    request.selectedSortKey = m.pageState.selectedSortKey
    m.top.overlayRequested = request
end sub

'-------------------------------------------------------------------------------
' onSortOrderChanged
'-------------------------------------------------------------------------------
sub onSortOrderChanged()
    applySortOrderSelection(m.sortButton.sortOrderChanged)
end sub

'-------------------------------------------------------------------------------
' applySortSelection
'-------------------------------------------------------------------------------
function applySortSelection(selection as object) as boolean
    if selection = invalid then return false

    selection = resetSortOrder(selection)
    selectedSortKey = getSelectionOptionKey(selection)
    if selectedSortKey = "" then return false
    if selectedSortKey = "Decade" then
        if SafeString(m.pageState.selectedSortKey, "") = "Decade" then
            m.pageState.pendingFocusTarget = "filterButtonRow"
            return false
        end if

        shouldRenderLibrary = isShowingUnfilteredTitleAscendingMasterList() <> true
        m.pageState.selectedSortKey = selectedSortKey
        m.pageState.selectedSort = {
            optionKey: "Decade"
            sortKey: "SortName"
            sortOrder: "Ascending"
            label: SafeString(selection.label, "Decade")
        }
        m.pageState.activeFilterType = "Decade"
        m.pageState.selectedDecade = getFirstDecadeFilterValue(m.pageState.decadeFilterOptions)
        m.pageState.renderDecadeFilterOnApply = shouldRenderLibrary
        m.pageState.pendingFocusTarget = "filterButtonRow"
        m.browseByButton.selectedSort = m.pageState.selectedSort
        m.sortButton.selectedSort = m.pageState.selectedSort
        m.sortButton.sortEnabled = false
        closeLetterGrid(false)
        showDecadeFilterRow()
        return false
    end if

    if isDecadeFilterActive() then
        m.pageState.activeFilterType = ""
        m.pageState.selectedDecade = -1
        m.pageState.renderDecadeFilterOnApply = false
        m.pageState.pendingFocusTarget = ""
        hideFilterButtonRow()
    end if

    if selectedSortKey = m.pageState.selectedSortKey then
        if canUseSortOrder(selection) <> true then return false
        if m.pageState.selectedSort = invalid then return false
        if SafeString(m.pageState.selectedSort.sortOrder, "Ascending") <> "Descending" then return false

        m.pageState.selectedSort.sortOrder = "Ascending"
        m.browseByButton.selectedSort = m.pageState.selectedSort
        m.sortButton.selectedSort = m.pageState.selectedSort
        m.sortButton.sortEnabled = canUseSortOrder(m.pageState.selectedSort)
        renderCurrentLibraryItems()
        return false
    end if

    m.pageState.selectedSortKey = selectedSortKey
    m.pageState.selectedSort = selection
    m.browseByButton.selectedSort = selection
    m.sortButton.selectedSort = selection
    m.sortButton.sortEnabled = canUseSortOrder(selection)
    renderCurrentLibraryItems()
    return false
end function

'-------------------------------------------------------------------------------
' applySortOrderSelection
'-------------------------------------------------------------------------------
function applySortOrderSelection(selection as object) as boolean
    if selection = invalid then return false
    if m.pageState.selectedSort = invalid then return false

    sortOrder = SafeString(selection.sortOrder, "Ascending")
    if sortOrder <> "Descending" then sortOrder = "Ascending"
    if SafeString(m.pageState.selectedSort.sortOrder, "Ascending") = sortOrder then return false

    m.pageState.selectedSort.sortOrder = sortOrder
    m.browseByButton.selectedSort = m.pageState.selectedSort
    m.sortButton.selectedSort = m.pageState.selectedSort
    m.sortButton.sortEnabled = canUseSortOrder(m.pageState.selectedSort)
    renderCurrentLibraryItems()
    return false
end function

'-------------------------------------------------------------------------------
' isShowingUnfilteredTitleAscendingMasterList
'-------------------------------------------------------------------------------
function isShowingUnfilteredTitleAscendingMasterList() as boolean
    if isDecadeFilterActive() then return false
    if SafeString(m.pageState.selectedSortKey, "SortName") <> "SortName" then return false
    if m.pageState.selectedSort <> invalid and SafeString(m.pageState.selectedSort.sortOrder, "Ascending") = "Descending" then return false

    items = m.pageState.items
    allItems = m.pageState.allItems
    if items = invalid or allItems = invalid then return false
    if items.Count() <> allItems.Count() then return false

    return true
end function

'-------------------------------------------------------------------------------
' canUseSortOrder
'-------------------------------------------------------------------------------
function canUseSortOrder(selection as object) as boolean
    if selection = invalid then return false

    sortKey = SafeString(selection.sortKey, "")
    return sortKey <> "" and sortKey <> "Random"
end function

'-------------------------------------------------------------------------------
' resetSortOrder
'-------------------------------------------------------------------------------
function resetSortOrder(selection as object) as object
    if selection = invalid then return selection
    if SafeString(selection.sortKey, "") = "Random" then return selection
    if SafeString(selection.sortKey, "") = "" then return selection

    selection.sortOrder = "Ascending"
    return selection
end function

'-------------------------------------------------------------------------------
' getSelectionOptionKey
'-------------------------------------------------------------------------------
function getSelectionOptionKey(selection as object) as string
    optionKey = SafeString(selection.optionKey, "")
    if optionKey <> "" then return optionKey

    sortKey = SafeString(selection.sortKey, "")
    if sortKey = "" then return ""
    if sortKey = "Random" then return "Random"

    return sortKey + ":" + getSortOrderFromSelection(selection)
end function

'-------------------------------------------------------------------------------
' reloadLibraryForSort
'-------------------------------------------------------------------------------
sub reloadLibraryForSort(refocusTarget = invalid as dynamic)
    request = m.pageState.request
    if request = invalid then return
    if m.pageState.selectedSort = invalid then return
    if SafeString(m.pageState.selectedSort.sortKey, "") = "" then return

    request.sortBy = SafeString(m.pageState.selectedSort.sortKey, "SortName")
    request.sortOrder = getSortOrderFromSelection(m.pageState.selectedSort)
    m.pageState.request = request
    AsyncLifecycle_Begin(m.pageState.lifecycle, request.libraryId)
    m.pageState.refocusBrowseByButtonAfterLoad = refocusTarget <> "sort"
    m.pageState.refocusSortButtonAfterLoad = refocusTarget = "sort"
    Spinner_Show(0)
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
    if selection <> invalid and SafeString(selection.sortKey, "") = "Random" then return ""
    if selection <> invalid and SafeString(selection.sortOrder, "") = "Descending" then return "Descending"

    return "Ascending"
end function

'-------------------------------------------------------------------------------
' getDefaultSortSelection
'-------------------------------------------------------------------------------
function getDefaultSortSelection() as object
    return {
        optionKey: "SortName"
        sortKey: "SortName"
        sortOrder: "Ascending"
        label: "Title"
    }
end function

'-------------------------------------------------------------------------------
' buildSortSelection
'-------------------------------------------------------------------------------
function buildSortSelection(sortKey as string, sortOrder as string) as object
    normalizedSortKey = SafeString(sortKey, "SortName")
    if normalizedSortKey = "Random" then
        return {
            optionKey: "Random"
            sortKey: "Random"
            sortOrder: ""
            label: "Random"
        }
    end if

    return {
        optionKey: normalizedSortKey
        sortKey: normalizedSortKey
        sortOrder: getNormalizedSortOrder(sortOrder)
        label: getSortSelectionLabel(normalizedSortKey)
    }
end function

'-------------------------------------------------------------------------------
' getNormalizedSortOrder
'-------------------------------------------------------------------------------
function getNormalizedSortOrder(sortOrder as string) as string
    if sortOrder = "Descending" then return "Descending"
    return "Ascending"
end function

'-------------------------------------------------------------------------------
' getSortSelectionLabel
'-------------------------------------------------------------------------------
function getSortSelectionLabel(sortKey as string) as string
    if sortKey = "Random" then return "Random"
    if sortKey = "PremiereDate" then return "Release Date"
    if sortKey = "DateCreated" then return "Date Added"
    return "Title"
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.pageState.lifecycle, m.pageState.request, "libraryId")
    m.top.setFocus(true)
    if focusPendingTarget() then return

    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusPendingTarget
'-------------------------------------------------------------------------------
function focusPendingTarget() as boolean
    target = SafeString(m.pageState.pendingFocusTarget, "")
    if target = "" then return false

    m.pageState.pendingFocusTarget = ""
    if target = "filterButtonRow" then return focusFilterButtonRow()

    return false
end function

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.pageState.lifecycle)
    stopLibraryProgressHold()
    closeLetterGrid(false)
    m.libraryTask.control = "stop"
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
' focusBrowseByButton
'-------------------------------------------------------------------------------
function focusBrowseByButton() as boolean
    if canFocusBrowseByButton() <> true then return false

    m.top.setFocus(true)
    m.browseByButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' focusSortButton
'-------------------------------------------------------------------------------
function focusSortButton() as boolean
    if canFocusSortButton() <> true then return false

    m.top.setFocus(true)
    m.sortButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' canFocusBrowseByButton
'-------------------------------------------------------------------------------
function canFocusBrowseByButton() as boolean
    return m.browseByButton <> invalid and m.browseByButton.visible = true
end function

'-------------------------------------------------------------------------------
' canFocusSortButton
'-------------------------------------------------------------------------------
function canFocusSortButton() as boolean
    return m.sortButton <> invalid and m.sortButton.visible = true and m.sortButton.sortEnabled = true
end function

'-------------------------------------------------------------------------------
' requestHeaderFocus
'-------------------------------------------------------------------------------
function requestHeaderFocus() as boolean
    m.top.focusExitUp = true
    return true
end function

'-------------------------------------------------------------------------------
' onBrowseByButtonFocusExitDown
'-------------------------------------------------------------------------------
sub onBrowseByButtonFocusExitDown()
    if canFocusFilterButtonRow() then
        focusFilterButtonRow()
        return
    end if

    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' onSortButtonFocusExitDown
'-------------------------------------------------------------------------------
sub onSortButtonFocusExitDown()
    if canFocusFilterButtonRow() then
        focusFilterButtonRow()
        return
    end if

    focusItemsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusFilterButtonRow
'-------------------------------------------------------------------------------
function focusFilterButtonRow() as boolean
    if canFocusFilterButtonRow() <> true then return false

    m.top.setFocus(true)
    m.filterButtonRow.callFunc("focusFirstButton")
    return true
end function

'-------------------------------------------------------------------------------
' canFocusFilterButtonRow
'-------------------------------------------------------------------------------
function canFocusFilterButtonRow() as boolean
    if m.filterButtonRow = invalid then return false
    if m.filterButtonRow.visible <> true then return false
    items = m.filterButtonRow.items
    if items = invalid then return false

    return items.Count() > 0
end function

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
    filterRowOffset = getFilterButtonRowOffset()

    if imageAspect = "wide" then
        m.pageState.isThumbnailLayout = true
        m.titleLabel.translation = [460, 120]
        m.filterButtonRow.translation = [264, 208]
        m.itemsGrid.translation = [23, 208 + filterRowOffset]
        applyLetterGutterButtonLayout(true, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
        applyLetterGridLayout(true, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
        m.itemsGrid.itemSize = [465, 348]
        m.itemsGrid.itemSpacing = [0, 11]
        m.itemsGrid.numColumns = 4
        m.itemsGrid.numRows = 3
        m.itemsGrid.focusBitmapUri = "pkg:/images/library/thumbnail-focus-465x348.png"
        updateLibraryProgressLayout(imageAspect)
        return
    end if

    m.pageState.isThumbnailLayout = false
    m.titleLabel.translation = [460, 120]
    m.filterButtonRow.translation = [264, 208]
    m.itemsGrid.translation = [96, 208 + filterRowOffset]
    applyLetterGutterButtonLayout(false, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
    applyLetterGridLayout(false, m.itemsGrid.translation[0], m.itemsGrid.translation[1])
    m.itemsGrid.itemSize = [295, 463]
    m.itemsGrid.itemSpacing = [-11, 26]
    m.itemsGrid.numColumns = 6
    m.itemsGrid.numRows = 2
    m.itemsGrid.focusBitmapUri = "pkg:/images/library/poster-focus-295x463.png"
    updateLibraryProgressLayout(imageAspect)
end sub

'-------------------------------------------------------------------------------
' getFilterButtonRowOffset
'-------------------------------------------------------------------------------
function getFilterButtonRowOffset() as integer
    if canShowFilterButtonRowLayout() <> true then return 0

    return 84
end function

'-------------------------------------------------------------------------------
' canShowFilterButtonRowLayout
'-------------------------------------------------------------------------------
function canShowFilterButtonRowLayout() as boolean
    return m.filterButtonRow <> invalid and m.filterButtonRow.visible = true
end function

'-------------------------------------------------------------------------------
' updateLibraryProgressLayout
'-------------------------------------------------------------------------------
sub updateLibraryProgressLayout(imageAspect as string)
    if imageAspect <> "poster" then stopLibraryProgressHold()

    m.libraryProgressIndicator.layoutMode = imageAspect
    m.libraryProgressIndicator.gridLeft = int(m.itemsGrid.translation[0])
    m.libraryProgressIndicator.gridTop = int(m.itemsGrid.translation[1])
    m.libraryProgressIndicator.itemWidth = int(m.itemsGrid.itemSize[0])
    m.libraryProgressIndicator.itemSpacingX = int(m.itemsGrid.itemSpacing[0])
    m.libraryProgressIndicator.numColumns = int(m.itemsGrid.numColumns)
    m.libraryProgressIndicator.numRows = int(m.itemsGrid.numRows)
    updateLibraryProgressItemCount()
    updateLibraryProgressFocusedIndex()
end sub

'-------------------------------------------------------------------------------
' updateLibraryProgressItemCount
'-------------------------------------------------------------------------------
sub updateLibraryProgressItemCount(itemCount = invalid as dynamic)
    resolvedItemCount = 0
    if itemCount <> invalid then
        resolvedItemCount = int(itemCount)
    else if m.itemsGrid.content <> invalid then
        resolvedItemCount = m.itemsGrid.content.getChildCount()
    end if

    m.libraryProgressIndicator.itemCount = resolvedItemCount
end sub

'-------------------------------------------------------------------------------
' updateLibraryProgressFocusedIndex
'-------------------------------------------------------------------------------
sub updateLibraryProgressFocusedIndex()
    focusedIndex = getCurrentLibraryFocusedIndex()

    m.pageState.progressFocusedIndex = focusedIndex
    m.libraryProgressIndicator.focusedIndex = focusedIndex
end sub

'-------------------------------------------------------------------------------
' getCurrentLibraryFocusedIndex
'-------------------------------------------------------------------------------
function getCurrentLibraryFocusedIndex() as integer
    focusedIndex = m.itemsGrid.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then return 0

    return focusedIndex
end function

'-------------------------------------------------------------------------------
' getLibraryItemCount
'-------------------------------------------------------------------------------
function getLibraryItemCount() as integer
    if m.itemsGrid.content = invalid then return 0

    return m.itemsGrid.content.getChildCount()
end function

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
    if key = "up" and m.browseByButton.isInFocusChain() then return requestHeaderFocus()
    if key = "up" and m.sortButton.isInFocusChain() then return requestHeaderFocus()
    if key = "right" and m.browseByButton.isInFocusChain() then
        if canFocusSortButton() then return focusSortButton()
        return true
    end if
    if key = "left" and m.sortButton.isInFocusChain() then return focusBrowseByButton()
    if key = "up" and m.letterGutterButton.isInFocusChain() then return requestHeaderFocus()
    if key = "left" and isItemsGridAtFirstColumn() then return openLetterGrid()
    if key = "up" and isItemsGridAtFirstRow() and canFocusFilterButtonRow() then
        stopLibraryProgressHold("up")
        return focusFilterButtonRow()
    end if
    if key = "up" and m.pageState.isThumbnailLayout = true and isItemsGridAtFirstRow() then return requestHeaderFocus()
    if key = "up" and isItemsGridAtFirstRow() then
        stopLibraryProgressHold("up")
        if canFocusBrowseByButton() <> true then return requestHeaderFocus()
        return focusBrowseByButton()
    end if
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

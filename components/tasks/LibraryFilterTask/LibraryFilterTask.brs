'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    if request = invalid then return

    items = getFilteredItems(request)
    itemIds = []
    for each item in items
        itemId = getItemId(item)
        if itemId <> "" then itemIds.Push(itemId)
    end for

    m.top.response = {
        requestId: Number_ToInteger(request.requestId)
        itemIds: itemIds
    }
end sub

'-------------------------------------------------------------------------------
' getFilteredItems
'-------------------------------------------------------------------------------
function getFilteredItems(request as object) as object
    items = m.top.libraryItems
    filterType = SafeString(request.filterType, "")
    if filterType = "Decade" then
        decade = Number_ToInteger(request.filterValue, -1)
        return getItemsSortedByLibraryYear(getItemsForDecade(items, decade))
    else if filterType = "Genre" then
        genre = SafeString(request.filterValue, "")
        return getSortedLibraryItems(getItemsForGenre(items, genre), request)
    end if

    return getSortedLibraryItems(items, request)
end function

'-------------------------------------------------------------------------------
' getItemsForDecade
'-------------------------------------------------------------------------------
function getItemsForDecade(items as dynamic, decade as integer) as object
    filteredItems = []
    if items = invalid or decade < 0 then return filteredItems

    for each item in items
        year = getItemLibraryYear(item)
        if year >= decade and year < decade + 10 then filteredItems.Push(item)
    end for

    return filteredItems
end function

'-------------------------------------------------------------------------------
' getItemsForGenre
'-------------------------------------------------------------------------------
function getItemsForGenre(items as dynamic, genre as string) as object
    filteredItems = []
    if items = invalid or genre = "" then return filteredItems

    for each item in items
        if itemHasGenre(item, genre) then filteredItems.Push(item)
    end for

    return filteredItems
end function

'-------------------------------------------------------------------------------
' itemHasGenre
'-------------------------------------------------------------------------------
function itemHasGenre(item as dynamic, genre as string) as boolean
    genreKey = LCase(String_Trim(genre))
    if genreKey = "" then return false

    for each itemGenre in getItemGenres(item)
        if LCase(String_Trim(SafeString(itemGenre, ""))) = genreKey then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' getItemGenres
'-------------------------------------------------------------------------------
function getItemGenres(item as dynamic) as object
    if item = invalid then return []
    if item.Genres = invalid then return []

    return item.Genres
end function

'-------------------------------------------------------------------------------
' getSortedLibraryItems
'-------------------------------------------------------------------------------
function getSortedLibraryItems(items as dynamic, request as object) as object
    sortedItems = copyLibraryItems(items)
    if sortedItems.Count() < 2 then return sortedItems

    sortKey = SafeString(request.sortKey, "SortName")
    if sortKey = "" then return sortedItems

    if sortKey = "Random" then return shuffleLibraryItems(sortedItems)

    sortedItems.SortBy(sortKey)

    if SafeString(request.sortOrder, "") = "Descending" then reverseLibraryItems(sortedItems)

    return sortedItems
end function

'-------------------------------------------------------------------------------
' copyLibraryItems
'-------------------------------------------------------------------------------
function copyLibraryItems(items as dynamic) as object
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
        swapIndex = Number_ToInteger(Rnd(0) * (i + 1))
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
    if item = invalid then return 0

    productionYear = Number_ToInteger(item.ProductionYear)
    if productionYear > 0 then return productionYear

    premiereDate = SafeString(item.PremiereDate, "")
    if Len(premiereDate) < 4 then return 0

    return Number_ToInteger(Left(premiereDate, 4))
end function

'-------------------------------------------------------------------------------
' getItemAlphabetTitle
'-------------------------------------------------------------------------------
function getItemAlphabetTitle(item as dynamic) as string
    if item = invalid then return ""

    return FirstNonEmpty([item.SortName, item.Name], "")
end function

'-------------------------------------------------------------------------------
' getItemId
'-------------------------------------------------------------------------------
function getItemId(item as dynamic) as string
    if item = invalid then return ""

    return SafeString(FirstNonEmpty([item.Id], ""), "")
end function

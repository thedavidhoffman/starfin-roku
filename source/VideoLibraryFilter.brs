'-------------------------------------------------------------------------------
' VideoLibraryFilter_ByDecade
'-------------------------------------------------------------------------------
function VideoLibraryFilter_ByDecade(items as object, decade as integer) as object
    filteredItems = []
    if items = invalid or decade < 0 then return filteredItems

    for each item in items
        year = __GetVideoLibraryFilterYear(item)
        if year > 0 and Number_ToInteger(Fix(year / 10) * 10, 0) = decade then filteredItems.Push(item)
    end for

    return __SortVideoLibraryFilterItemsByYear(filteredItems)
end function

'-------------------------------------------------------------------------------
' VideoLibraryFilter_ByGenre
'-------------------------------------------------------------------------------
function VideoLibraryFilter_ByGenre(items as object, genre as string) as object
    filteredItems = []
    targetGenre = LCase(String_Trim(genre))
    if items = invalid or targetGenre = "" then return filteredItems

    for each item in items
        if __VideoLibraryFilterItemHasGenre(item, targetGenre) then filteredItems.Push(item)
    end for

    return VideoLibrarySort_ByTitle(filteredItems, "Ascending")
end function

'-------------------------------------------------------------------------------
' __GetVideoLibraryFilterYear
'-------------------------------------------------------------------------------
function __GetVideoLibraryFilterYear(item as object) as integer
    productionYear = Number_ToInteger(item.ProductionYear, 0)
    if productionYear > 0 then return productionYear

    premiereDate = SafeString(item.PremiereDate, "")
    if Len(premiereDate) < 4 then return 0

    return Number_ToInteger(Left(premiereDate, 4), 0)
end function

'-------------------------------------------------------------------------------
' __VideoLibraryFilterItemHasGenre
'-------------------------------------------------------------------------------
function __VideoLibraryFilterItemHasGenre(item as object, targetGenre as string) as boolean
    if item.Genres = invalid then return false

    for each genre in item.Genres
        if LCase(String_Trim(SafeString(genre, ""))) = targetGenre then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' __SortVideoLibraryFilterItemsByYear
'-------------------------------------------------------------------------------
function __SortVideoLibraryFilterItemsByYear(items as object) as object
    sortedItems = []
    for each item in items
        sortedItems.Push(item)
    end for

    for i = 1 to sortedItems.Count() - 1
        currentItem = sortedItems[i]
        currentYear = __GetVideoLibraryFilterYear(currentItem)
        currentTitle = __GetVideoLibraryFilterTitle(currentItem)
        insertIndex = i - 1

        while insertIndex >= 0 and __ShouldVideoLibraryFilterItemMoveRight(sortedItems[insertIndex], currentYear, currentTitle)
            sortedItems[insertIndex + 1] = sortedItems[insertIndex]
            insertIndex = insertIndex - 1
        end while

        sortedItems[insertIndex + 1] = currentItem
    end for

    return sortedItems
end function

'-------------------------------------------------------------------------------
' __GetVideoLibraryFilterTitle
'-------------------------------------------------------------------------------
function __GetVideoLibraryFilterTitle(item as object) as string
    title = String_Trim(SafeString(item.SortName, ""))
    if title = "" then title = String_Trim(SafeString(item.Name, ""))
    return LCase(title)
end function

'-------------------------------------------------------------------------------
' __ShouldVideoLibraryFilterItemMoveRight
'-------------------------------------------------------------------------------
function __ShouldVideoLibraryFilterItemMoveRight(item as object, targetYear as integer, targetTitle as string) as boolean
    itemYear = __GetVideoLibraryFilterYear(item)
    if itemYear > targetYear then return true
    if itemYear < targetYear then return false

    return __GetVideoLibraryFilterTitle(item) > targetTitle
end function

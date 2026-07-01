'-------------------------------------------------------------------------------
' EpisodeSort_BySeriesSeasonEpisode
'-------------------------------------------------------------------------------
function EpisodeSort_BySeriesSeasonEpisode(items as object) as object
    if items = invalid then return []

    sortedItems = []
    for each item in items
        sortedItems.Push(item)
    end for

    if sortedItems.Count() < 2 then return sortedItems

    for i = 0 to sortedItems.Count() - 2
        for j = i + 1 to sortedItems.Count() - 1
            if __EpisodeSort_ShouldEpisodeSortBefore(sortedItems[j], sortedItems[i]) then
                temp = sortedItems[i]
                sortedItems[i] = sortedItems[j]
                sortedItems[j] = temp
            end if
        end for
    end for

    return sortedItems
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_ShouldEpisodeSortBefore
'-------------------------------------------------------------------------------
function __EpisodeSort_ShouldEpisodeSortBefore(left as dynamic, right as dynamic) as boolean
    titleComparison = String_NaturalCompare(__EpisodeSort_GetSeriesSortTitle(left), __EpisodeSort_GetSeriesSortTitle(right))
    if titleComparison < 0 then return true
    if titleComparison > 0 then return false

    leftSeason = __EpisodeSort_GetSeasonSortNumber(left)
    rightSeason = __EpisodeSort_GetSeasonSortNumber(right)
    if leftSeason < rightSeason then return true
    if leftSeason > rightSeason then return false

    leftEpisode = __EpisodeSort_GetIndexSortNumber(left)
    rightEpisode = __EpisodeSort_GetIndexSortNumber(right)
    if leftEpisode < rightEpisode then return true
    if leftEpisode > rightEpisode then return false

    return String_NaturalCompare(__EpisodeSort_GetNameSortTitle(left), __EpisodeSort_GetNameSortTitle(right)) < 0
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_GetSeriesSortTitle
'-------------------------------------------------------------------------------
function __EpisodeSort_GetSeriesSortTitle(item as dynamic) as string
    if __EpisodeSort_IsAssocArray(item) = false then return ""

    return String_Trim(FirstNonEmpty([item.SeriesName, item.Series, item.ParentTitle, item.Album], ""))
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_GetNameSortTitle
'-------------------------------------------------------------------------------
function __EpisodeSort_GetNameSortTitle(item as dynamic) as string
    if __EpisodeSort_IsAssocArray(item) = false then return ""

    return String_Trim(FirstNonEmpty([item.Name], ""))
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_GetSeasonSortNumber
'-------------------------------------------------------------------------------
function __EpisodeSort_GetSeasonSortNumber(item as dynamic) as integer
    if __EpisodeSort_IsAssocArray(item) = false then return 999999

    return __EpisodeSort_GetNumber(FirstNonEmpty([item.ParentIndexNumber, item.SeasonNumber], ""))
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_GetIndexSortNumber
'-------------------------------------------------------------------------------
function __EpisodeSort_GetIndexSortNumber(item as dynamic) as integer
    if __EpisodeSort_IsAssocArray(item) = false then return 999999

    return __EpisodeSort_GetNumber(FirstNonEmpty([item.IndexNumber, item.EpisodeNumber], ""))
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_GetNumber
'-------------------------------------------------------------------------------
function __EpisodeSort_GetNumber(value as dynamic) as integer
    text = String_Trim(SafeString(value, ""))
    if text = "" then return 999999

    return val(text)
end function

'-------------------------------------------------------------------------------
' __EpisodeSort_IsAssocArray
'-------------------------------------------------------------------------------
function __EpisodeSort_IsAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

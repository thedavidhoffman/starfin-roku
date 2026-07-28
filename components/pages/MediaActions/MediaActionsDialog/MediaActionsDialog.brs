'-------------------------------------------------------------------------------
' openMediaActions
'-------------------------------------------------------------------------------
sub openMediaActions()
    m.top.dialogTitle = getMediaTitle()
    m.top.closeOnSelect = true
    m.top.allowDefaultSelection = false
    m.top.selectedKey = ""
    m.top.emptyText = ""
    m.top.options = [getWatchedOption(), getFavoriteOption()]

    m.top.callFunc("openOptions")
    m.top.unobserveField("selectedOption")
    m.top.observeField("selectedOption", "onMediaActionSelected")
end sub

'-------------------------------------------------------------------------------
' getMediaTitle
'-------------------------------------------------------------------------------
function getMediaTitle() as string
    if m.top.item = invalid then return "Media Actions"

    title = String_Trim(SafeString(m.top.item.Name, ""))
    if title <> "" then return title
    return "Media Actions"
end function

'-------------------------------------------------------------------------------
' getWatchedOption
'-------------------------------------------------------------------------------
function getWatchedOption() as object
    isWatched = m.top.item <> invalid and m.top.item.UserData <> invalid and m.top.item.UserData.Played = true
    if isWatched then return { key: "MarkAsUnwatched", label: "Mark as Unwatched" }
    return { key: "MarkAsWatched", label: "Mark as Watched" }
end function

'-------------------------------------------------------------------------------
' getFavoriteOption
'-------------------------------------------------------------------------------
function getFavoriteOption() as object
    isFavorite = m.top.item <> invalid and m.top.item.UserData <> invalid and m.top.item.UserData.IsFavorite = true
    if isFavorite then return { key: "RemoveFromFavorites", label: "Remove from Favorites" }
    return { key: "AddToFavorites", label: "Add to Favorites" }
end function

'-------------------------------------------------------------------------------
' onMediaActionSelected
'-------------------------------------------------------------------------------
sub onMediaActionSelected(event as object)
    option = event.getData()
    if option = invalid then return
    if m.top.item = invalid then return

    itemId = SafeString(m.top.item.Id, "")
    action = SafeString(option.key, "")
    if itemId = "" or isSupportedAction(action) <> true then return

    m.top.mediaActionSelected = {
        itemId: itemId
        action: action
    }
end sub

'-------------------------------------------------------------------------------
' isSupportedAction
'-------------------------------------------------------------------------------
function isSupportedAction(action as string) as boolean
    return action = "MarkAsWatched" or action = "MarkAsUnwatched" or action = "AddToFavorites" or action = "RemoveFromFavorites"
end function

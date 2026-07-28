' MediaActionsController consolidates media action handlers so they do not need
' to be duplicated across each page that supports media actions.

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.state = {
        activeRequest: invalid
        tasks: {
            watched: m.top.findNode("watchedTask")
            favorite: m.top.findNode("favoriteItemTask")
        }
    }
    m.state.tasks.watched.observeField("response", "onActionTaskResponse")
    m.state.tasks.favorite.observeField("response", "onActionTaskResponse")
end sub

'-------------------------------------------------------------------------------
' onActionRequestChanged
'-------------------------------------------------------------------------------
sub onActionRequestChanged()
    request = m.top.actionRequest
    if request = invalid then return

    action = SafeString(request.action, "")
    task = getTaskForAction(action)
    if task = invalid then
        m.state.activeRequest = invalid
        m.top.actionFailed = {
            itemId: SafeString(request.itemId, "")
            errorMessage: "Unsupported media action."
        }
        return
    end if

    m.state.activeRequest = request
    task.request = request
    task.control = "run"
end sub

'-------------------------------------------------------------------------------
' getTaskForAction
'-------------------------------------------------------------------------------
function getTaskForAction(action as string) as dynamic
    if action = "MarkAsWatched" or action = "MarkAsUnwatched" then return m.state.tasks.watched
    if action = "AddToFavorites" or action = "RemoveFromFavorites" then return m.state.tasks.favorite
    return invalid
end function

'-------------------------------------------------------------------------------
' cancelActiveAction
'-------------------------------------------------------------------------------
sub cancelActiveAction()
    m.state.activeRequest = invalid
    m.state.tasks.watched.control = "stop"
    m.state.tasks.favorite.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onActionTaskResponse
'-------------------------------------------------------------------------------
sub onActionTaskResponse(event as object)
    response = event.getData()
    if response = invalid then return
    request = m.state.activeRequest
    if request = invalid then return
    if SafeString(response.itemId, "") <> SafeString(request.itemId, "") then return
    if SafeString(response.action, "") <> SafeString(request.action, "") then return
    m.state.activeRequest = invalid

    if response.ok <> true then
        m.top.actionFailed = {
            itemId: SafeString(response.itemId, "")
            errorMessage: SafeString(response.errorMessage, "Unable to update media state.")
        }
        return
    end if

    result = getMediaStateResult(SafeString(response.action, ""))
    if result = invalid then
        m.top.actionFailed = {
            itemId: SafeString(response.itemId, "")
            errorMessage: "Unable to resolve media action result."
        }
        return
    end if

    m.top.mediaStateChanged = {
        itemId: SafeString(response.itemId, "")
        action: result.action
        value: result.value
    }
end sub

'-------------------------------------------------------------------------------
' getMediaStateResult
'-------------------------------------------------------------------------------
function getMediaStateResult(action as string) as dynamic
    if action = "MarkAsWatched" then return { action: "watched", value: true }
    if action = "MarkAsUnwatched" then return { action: "watched", value: false }
    if action = "AddToFavorites" then return { action: "favorite", value: true }
    if action = "RemoveFromFavorites" then return { action: "favorite", value: false }
    return invalid
end function

'-------------------------------------------------------------------------------
' AsyncLifecycle_Create
'-------------------------------------------------------------------------------
function AsyncLifecycle_Create() as object
    return {
        isActive: false
        activeRequestKey: ""
    }
end function

'-------------------------------------------------------------------------------
' AsyncLifecycle_Begin
'-------------------------------------------------------------------------------
sub AsyncLifecycle_Begin(state as object, requestKey as dynamic)
    if state = invalid then return

    state.isActive = true
    state.activeRequestKey = SafeString(requestKey, "")
end sub

'-------------------------------------------------------------------------------
' AsyncLifecycle_BeginFromField
'-------------------------------------------------------------------------------
sub AsyncLifecycle_BeginFromField(state as object, source as dynamic, keyField as string)
    if state = invalid then return
    if source = invalid then return
    if keyField = "" then return
    if source[keyField] = invalid then return

    AsyncLifecycle_Begin(state, source[keyField])
end sub

'-------------------------------------------------------------------------------
' AsyncLifecycle_Deactivate
'-------------------------------------------------------------------------------
sub AsyncLifecycle_Deactivate(state as object)
    if state = invalid then return

    state.isActive = false
    state.activeRequestKey = ""
end sub

'-------------------------------------------------------------------------------
' AsyncLifecycle_IsCurrentResponse
'-------------------------------------------------------------------------------
function AsyncLifecycle_IsCurrentResponse(state as object, response as dynamic, responseKeyField as string, expectedAction = invalid as dynamic) as boolean
    if state = invalid then return false
    if response = invalid then return false
    if state.isActive <> true then return false
    if expectedAction <> invalid and SafeString(response.action, "") <> expectedAction then return false

    responseKey = ""
    if responseKeyField <> "" and response[responseKeyField] <> invalid then responseKey = SafeString(response[responseKeyField], "")

    return responseKey <> "" and responseKey = SafeString(state.activeRequestKey, "")
end function

'-------------------------------------------------------------------------------
' AsyncLifecycle_BuildKey
'-------------------------------------------------------------------------------
function AsyncLifecycle_BuildKey(parts as object) as string
    if parts = invalid then return ""

    key = ""
    for each part in parts
        if key <> "" then key = key + "|"
        key = key + SafeString(part, "")
    end for

    return key
end function

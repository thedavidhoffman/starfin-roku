'-------------------------------------------------------------------------------
' Library View State Registry Storage
'-------------------------------------------------------------------------------

'-------------------------------------------------------------------------------
' __LibraryViewStateStore_GetAccountSectionName
'-------------------------------------------------------------------------------
function __LibraryViewStateStore_GetAccountSectionName(accountKey as string) as string
    return "STARFIN_ACCOUNT_" + accountKey
end function

'-------------------------------------------------------------------------------
' __LibraryViewStateStore_GetKey
'-------------------------------------------------------------------------------
function __LibraryViewStateStore_GetKey(libraryId as string) as string
    return "library-view-state-" + libraryId
end function

'-------------------------------------------------------------------------------
' __LibraryViewStateStore_GetKeyPrefix
'-------------------------------------------------------------------------------
function __LibraryViewStateStore_GetKeyPrefix() as string
    return "library-view-state-"
end function

'-------------------------------------------------------------------------------
' LibraryViewStateStore_Load
'-------------------------------------------------------------------------------
function LibraryViewStateStore_Load(accountKey as string, libraryId as string) as dynamic
    if accountKey = "" or libraryId = "" then return invalid

    accountStore = CreateObject("roRegistrySection", __LibraryViewStateStore_GetAccountSectionName(accountKey))
    value = accountStore.Read(__LibraryViewStateStore_GetKey(libraryId))
    if value = invalid or value = "" then return invalid

    state = ParseJson(value)
    if Array_IsAssocArray(state) = false then return invalid
    return state
end function

'-------------------------------------------------------------------------------
' LibraryViewStateStore_Save
'-------------------------------------------------------------------------------
sub LibraryViewStateStore_Save(accountKey as string, libraryId as string, state as object)
    if accountKey = "" or libraryId = "" or state = invalid then return

    value = Json_Object([
        Json_Pair("optionKey", SafeString(state.optionKey, ""))
        Json_Pair("sortKey", SafeString(state.sortKey, ""))
        Json_Pair("sortOrder", SafeString(state.sortOrder, ""))
        Json_NumberPair("selectedDecade", Number_ToInteger(state.selectedDecade, -1))
        Json_Pair("selectedGenre", SafeString(state.selectedGenre, ""))
        Json_Pair("libraryTitle", SafeString(state.libraryTitle, ""))
        Json_Pair("collectionType", SafeString(state.collectionType, ""))
    ])
    accountStore = CreateObject("roRegistrySection", __LibraryViewStateStore_GetAccountSectionName(accountKey))
    accountStore.Write(__LibraryViewStateStore_GetKey(libraryId), value)
    accountStore.Flush()
end sub

'-------------------------------------------------------------------------------
' LibraryViewStateStore_List
'-------------------------------------------------------------------------------
function LibraryViewStateStore_List(accountKey as string) as object
    states = []
    if accountKey = "" then return states

    accountStore = CreateObject("roRegistrySection", __LibraryViewStateStore_GetAccountSectionName(accountKey))
    keys = accountStore.GetKeyList()
    if keys = invalid then return states
    prefix = __LibraryViewStateStore_GetKeyPrefix()
    for each key in keys
        if Left(key, Len(prefix)) = prefix then
            libraryId = Mid(key, Len(prefix) + 1)
            state = LibraryViewStateStore_Load(accountKey, libraryId)
            if state <> invalid then
                state.libraryId = libraryId
                states.Push(state)
            end if
        end if
    end for
    states.SortBy("libraryId")
    return states
end function

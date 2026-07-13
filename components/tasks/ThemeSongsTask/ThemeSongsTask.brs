'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("ThemeSongsTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    params = {
        UserId: SafeString(request.userId, "")
        EnableTotalRecordCount: false
    }
    url = request.server + "/Items/" + SafeString(request.itemId, "") + "/ThemeSongs" + Url_BuildQueryString(params)
    result = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "themeSongs")
        m.top.response = result
        return
    end if

    items = getPayloadItems(result.data)
    themeSong = getFirstThemeSongFromItems(items)
    m.log.write("ThemeSongs response itemId=" + SafeString(request.itemId, "") + " count=" + items.Count().ToStr() + " selectedThemeSongId=" + SafeString(getThemeSongId(themeSong), ""))
    m.top.response = {
        ok: true
        action: "themeSongs"
        itemId: SafeString(request.itemId, "")
        payload: themeSong
    }
end sub

'-------------------------------------------------------------------------------
' getFirstThemeSong
'-------------------------------------------------------------------------------
function getFirstThemeSongFromItems(items as object) as dynamic
    if items.Count() = 0 then return invalid

    for each item in items
        if Array_IsAssocArray(item) then return item
    end for

    return invalid
end function

'-------------------------------------------------------------------------------
' getThemeSongId
'-------------------------------------------------------------------------------
function getThemeSongId(item as dynamic) as string
    if Array_IsAssocArray(item) = false then return ""

    return SafeString(item.Id, "")
end function

'-------------------------------------------------------------------------------
' getPayloadItems
'-------------------------------------------------------------------------------
function getPayloadItems(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if Array_IsAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items

    return []
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "themeSongs", errorMessage: "Invalid theme song request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "themeSongs", errorMessage: "Invalid theme song server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "themeSongs", errorMessage: "Invalid theme song token." }
    if SafeString(request.itemId, "") = "" then return { ok: false, action: "themeSongs", errorMessage: "Invalid theme song item." }

    return invalid
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("VideoMediaSegmentsTask")
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

    itemId = SafeString(request.itemId, "")
    url = request.server + "/MediaSegments/" + itemId
    m.log.write("Loading media segments itemId=" + itemId)
    result = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if result.ok <> true then
        result.AddReplace("action", "mediaSegments")
        result.AddReplace("itemId", itemId)
        m.top.response = result
        return
    end if

    segments = []
    if result.data <> invalid and result.data.Items <> invalid then segments = result.data.Items
    m.top.response = {
        ok: true
        action: "mediaSegments"
        itemId: itemId
        segments: segments
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "mediaSegments", itemId: "", errorMessage: "Invalid media segments request." }
    itemId = SafeString(request.itemId, "")
    if SafeString(request.server, "") = "" then return { ok: false, action: "mediaSegments", itemId: itemId, errorMessage: "Invalid media segments server." }
    if SafeString(request.token, "") = "" then return { ok: false, action: "mediaSegments", itemId: itemId, errorMessage: "Invalid media segments token." }
    if itemId = "" then return { ok: false, action: "mediaSegments", itemId: itemId, errorMessage: "Invalid media segments item." }

    return invalid
end function

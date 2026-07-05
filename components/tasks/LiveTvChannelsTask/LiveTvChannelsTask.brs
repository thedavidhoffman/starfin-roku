'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("LiveTvChannelsTask")
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
        IncludeItemTypes: "LiveTvChannel"
        SortBy: "SortName"
        SortOrder: "Ascending"
        UserId: SafeString(request.userId, "")
        EnableFavoriteSorting: true
        EnableUserData: false
        AddCurrentProgram: false
        Recursive: true
        ImageTypeLimit: 1
        EnableImageTypes: "Primary"
    }

    url = NormalizeServerUrl(request.server) + "/Items" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "liveTvChannels")
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "liveTvChannels"
        payload: response.data
    }
end sub

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "liveTvChannels", errorMessage: "Invalid Live TV request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "liveTvChannels", errorMessage: "Invalid Live TV server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "liveTvChannels", errorMessage: "Invalid Live TV token." }

    return invalid
end function

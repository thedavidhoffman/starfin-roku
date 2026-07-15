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
    if request = invalid or SafeString(request.server, "") = "" or SafeString(request.libraryId, "") = "" then
        m.top.response = { ok: false, action: "musicArtists", libraryId: "", errorMessage: "Invalid music artists request." }
        return
    end if

    params = {
        userId: SafeString(request.userId, "")
        parentId: SafeString(request.libraryId, "")
        fields: "SortName,ProviderIds"
        enableImageTypes: "Primary,Backdrop,Logo"
        imageTypeLimit: 1
        enableTotalRecordCount: false
    }
    url = request.server + "/Artists" + Url_BuildQueryString(params)
    response = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if response.ok <> true then
        response.AddReplace("action", "musicArtists")
        response.AddReplace("libraryId", SafeString(request.libraryId, ""))
        m.top.response = response
        return
    end if

    m.top.response = {
        ok: true
        action: "musicArtists"
        libraryId: SafeString(request.libraryId, "")
        payload: response.data
    }
end sub

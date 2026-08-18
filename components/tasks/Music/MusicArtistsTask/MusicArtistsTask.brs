'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("MusicArtistsTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    requestTimer = CreateObject("roTimespan")
    requestTimer.Mark()
    libraryId = ""
    if request <> invalid then libraryId = SafeString(request.libraryId, "")
    if request = invalid or SafeString(request.server, "") = "" or SafeString(request.token, "") = "" or SafeString(request.userId, "") = "" or libraryId = "" then
        m.log.error("Invalid artist request libraryId=" + libraryId)
        m.top.response = { ok: false, action: "musicArtists", libraryId: libraryId, errorMessage: "Invalid music artists request." }
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
    m.log.write("HTTP completed libraryId=" + SafeString(request.libraryId, "") + " elapsedMs=" + requestTimer.TotalMilliseconds().ToStr() + " ok=" + (response.ok = true).ToStr())
    if response.ok <> true then
        m.log.error("Artist request failed libraryId=" + SafeString(request.libraryId, "") + " message=" + SafeString(response.errorMessage, ""))
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

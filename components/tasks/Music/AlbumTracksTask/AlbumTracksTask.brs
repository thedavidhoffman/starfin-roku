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
    if request = invalid or SafeString(request.server, "") = "" or SafeString(request.token, "") = "" or SafeString(request.albumId, "") = "" then
        m.top.response = { ok: false, action: "albumTracks", errorMessage: "Invalid album tracks request." }
        return
    end if

    url = request.server + "/Users/" + SafeString(request.userId, "") + "/Items" + Url_BuildQueryString({
        ParentId: request.albumId
        IncludeItemTypes: "Audio"
        Recursive: true
        Fields: "Album,AlbumArtist,Artists,IndexNumber,ParentIndexNumber,RunTimeTicks"
        SortBy: "ParentIndexNumber,IndexNumber,SortName"
        SortOrder: "Ascending"
    })
    result = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    result.AddReplace("action", "albumTracks")
    result.AddReplace("albumId", request.albumId)
    m.top.response = result
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVShowTask")
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

    seriesResult = loadSeries(request)
    if seriesResult.ok <> true then
        seriesResult.AddReplace("action", "tvShow")
        m.top.response = seriesResult
        return
    end if

    seasonsResult = loadSeasons(request)
    if seasonsResult.ok <> true then
        seasonsResult.AddReplace("action", "tvShow")
        m.top.response = seasonsResult
        return
    end if

    m.top.response = {
        ok: true
        action: "tvShow"
        itemId: SafeString(request.itemId, "")
        payload: {
            series: seriesResult.data
            seasons: seasonsResult.data
        }
    }
end sub

'-------------------------------------------------------------------------------
' loadSeries
'-------------------------------------------------------------------------------
function loadSeries(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        fields: "Genres,People,Overview,Studios"
        enableImageTypes: "Primary,Backdrop,Thumb,Logo"
        imageTypeLimit: 1
        enableTotalRecordCount: false
    }

    url = NormalizeServerUrl(request.server) + "/Items/" + request.itemId + Url_BuildQueryString(params)
    m.log.write(url)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadSeasons
'-------------------------------------------------------------------------------
function loadSeasons(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        enableImageTypes: "Primary,Backdrop,Thumb"
        imageTypeLimit: 1
        enableTotalRecordCount: false
    }

    url = NormalizeServerUrl(request.server) + "/Shows/" + request.itemId + "/Seasons" + Url_BuildQueryString(params)
    m.log.write(url)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "tvShow", errorMessage: "Invalid series details request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details item." }

    return invalid
end function

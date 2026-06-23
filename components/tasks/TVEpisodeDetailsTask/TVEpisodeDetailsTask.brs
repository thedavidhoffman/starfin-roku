'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVEpisodeDetailsTask")
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

    episodeResult = loadEpisode(request)
    if episodeResult.ok <> true then
        episodeResult.AddReplace("action", "tvEpisodeDetails")
        episodeResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = episodeResult
        return
    end if

    series = invalid
    seriesId = SafeString(episodeResult.data.SeriesId, "")
    if seriesId <> "" then
        seriesResult = loadSeries(request, seriesId)
        if seriesResult <> invalid and seriesResult.ok = true then series = seriesResult.data
    end if

    m.top.response = {
        ok: true
        action: "tvEpisodeDetails"
        itemId: SafeString(request.itemId, "")
        payload: episodeResult.data
        series: series
    }
end sub

'-------------------------------------------------------------------------------
' loadEpisode
'-------------------------------------------------------------------------------
function loadEpisode(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        fields: "People,Overview,MediaStreams,MediaSources,UserData"
    }

    url = NormalizeServerUrl(request.server) + "/Items/" + request.itemId + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadSeries
'-------------------------------------------------------------------------------
function loadSeries(request as object, seriesId as string) as object
    params = {
        userId: SafeString(request.userId, "")
        enableImageTypes: "Logo"
        imageTypeLimit: 1
    }

    url = NormalizeServerUrl(request.server) + "/Items/" + seriesId + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "tvEpisodeDetails", errorMessage: "Invalid episode details request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "tvEpisodeDetails", errorMessage: "Invalid episode details server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "tvEpisodeDetails", errorMessage: "Invalid episode details token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "tvEpisodeDetails", errorMessage: "Invalid episode details item." }

    return invalid
end function

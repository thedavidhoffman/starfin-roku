'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVSeasonTask")
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

    seasonResult = loadSeason(request)
    if seasonResult.ok <> true then
        seasonResult.AddReplace("action", "tvSeason")
        m.top.response = seasonResult
        return
    end if

    episodesResult = loadEpisodes(request)
    if episodesResult.ok <> true then
        episodesResult.AddReplace("action", "tvSeason")
        m.top.response = episodesResult
        return
    end if

    m.top.response = {
        ok: true
        action: "tvSeason"
        seriesId: SafeString(request.seriesId, "")
        seasonId: SafeString(request.seasonId, "")
        payload: {
            season: seasonResult.data
            episodes: episodesResult.data
        }
    }
end sub

'-------------------------------------------------------------------------------
' loadSeason
'-------------------------------------------------------------------------------
function loadSeason(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        fields: "Genres,Overview,Studios"
        enableImageTypes: "Primary,Backdrop,Thumb"
        imageTypeLimit: 1
        enableTotalRecordCount: false
    }

    url = NormalizeServerUrl(request.server) + "/Items/" + request.seasonId + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadEpisodes
'-------------------------------------------------------------------------------
function loadEpisodes(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        seasonId: SafeString(request.seasonId, "")
        fields: "MediaStreams,MediaSources,Overview,Trickplay,UserData"
    }

    url = NormalizeServerUrl(request.server) + "/Shows/" + request.seriesId + "/Episodes" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "tvSeason", errorMessage: "Invalid season request." }
    if NormalizeServerUrl(request.server) = "" then return { ok: false, action: "tvSeason", errorMessage: "Invalid season server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "tvSeason", errorMessage: "Invalid season token." }
    if request.seriesId = invalid or request.seriesId = "" then return { ok: false, action: "tvSeason", errorMessage: "Invalid series item." }
    if request.seasonId = invalid or request.seasonId = "" then return { ok: false, action: "tvSeason", errorMessage: "Invalid season item." }

    return invalid
end function

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

    if SafeString(request.action, "") = "nextSeasonEpisodes" then
        executeNextSeasonEpisodesRequest(request)
        return
    end if

    seasonResult = loadSeason(request)
    if seasonResult.ok <> true then
        seasonResult.AddReplace("action", "tvSeason")
        m.top.response = seasonResult
        return
    end if

    episodesResult = loadEpisodes(request, SafeString(request.seasonId, ""))
    if episodesResult.ok <> true then
        episodesResult.AddReplace("action", "tvSeason")
        m.top.response = episodesResult
        return
    end if

    seasons = invalid
    if hasRequestSeasons(request) <> true then
        seasonsResult = loadSeasons(request)
        if seasonsResult <> invalid and seasonsResult.ok = true then seasons = seasonsResult.data
    end if

    m.top.response = {
        ok: true
        action: "tvSeason"
        seriesId: SafeString(request.seriesId, "")
        seasonId: SafeString(request.seasonId, "")
        payload: {
            season: seasonResult.data
            episodes: episodesResult.data
            seasons: seasons
        }
    }
end sub

'-------------------------------------------------------------------------------
' executeNextSeasonEpisodesRequest
'-------------------------------------------------------------------------------
sub executeNextSeasonEpisodesRequest(request as object)
    nextSeasonId = getNextSeasonId(request)
    if nextSeasonId = "" then
        m.top.response = {
            ok: true
            action: "nextSeasonEpisodes"
            payload: invalid
        }
        return
    end if

    nextEpisodesResult = loadEpisodes(request, nextSeasonId)
    if nextEpisodesResult.ok <> true then
        nextEpisodesResult.AddReplace("action", "nextSeasonEpisodes")
        m.top.response = nextEpisodesResult
        return
    end if

    m.top.response = {
        ok: true
        action: "nextSeasonEpisodes"
        seasonId: nextSeasonId
        payload: nextEpisodesResult.data
    }
end sub

'-------------------------------------------------------------------------------
' loadSeason
'-------------------------------------------------------------------------------
function loadSeason(request as object) as object
    params = {
        userId: SafeString(request.userId, "")
        fields: "Genres,People,Overview,Studios"
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
function loadEpisodes(request as object, seasonId as string) as object
    params = {
        userId: SafeString(request.userId, "")
        seasonId: seasonId
        fields: "MediaStreams,MediaSources,Overview,Trickplay,UserData"
        enableImageTypes: "Primary,Backdrop,Thumb"
        imageTypeLimit: 1
    }

    url = NormalizeServerUrl(request.server) + "/Shows/" + request.seriesId + "/Episodes" + Url_BuildQueryString(params)
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

    url = NormalizeServerUrl(request.server) + "/Shows/" + request.seriesId + "/Seasons" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' hasRequestSeasons
'-------------------------------------------------------------------------------
function hasRequestSeasons(request as object) as boolean
    if request.seasons = invalid then return false
    if Type(request.seasons) <> "roArray" then return false

    return request.seasons.Count() > 0
end function

'-------------------------------------------------------------------------------
' getNextSeasonId
'-------------------------------------------------------------------------------
function getNextSeasonId(request as object) as string
    nextSeason = request.nextSeason
    if nextSeason = invalid then return ""

    return SafeString(FirstNonEmpty([nextSeason.Id], ""), "")
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

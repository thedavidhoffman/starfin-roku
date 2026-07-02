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

    response = {
        ok: true
        action: "tvEpisodeDetails"
        itemId: SafeString(request.itemId, "")
        payload: episodeResult.data
        series: series
    }

    if request.loadPlaybackQueue = true then
        queue = loadPlaybackQueue(request, episodeResult.data)
        if queue <> invalid then
            response.AddReplace("playbackQueue", queue.items)
            response.AddReplace("playbackQueueIndex", queue.index)
            response.AddReplace("season", queue.season)
        end if
    end if

    m.top.response = response
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
' loadPlaybackQueue
'-------------------------------------------------------------------------------
function loadPlaybackQueue(request as object, episode as dynamic) as dynamic
    seriesId = SafeString(FirstNonEmpty([episode.SeriesId], ""), "")
    seasonId = SafeString(FirstNonEmpty([episode.SeasonId, episode.ParentId], ""), "")
    itemId = SafeString(FirstNonEmpty([episode.Id, request.itemId], ""), "")
    if seriesId = "" or seasonId = "" or itemId = "" then return invalid

    episodesResult = loadEpisodes(request, seriesId, seasonId)
    if episodesResult = invalid or episodesResult.ok <> true then
        m.log.write("Unable to load episode playback queue for itemId=" + itemId)
        return invalid
    end if

    episodes = getItemsFromPayload(episodesResult.data)
    if episodes.Count() = 0 then return invalid

    queueItems = buildPlaybackQueueItems(episodes, buildSeasonIdentity(episode, seasonId))
    queueIndex = getPlaybackQueueIndex(queueItems, itemId)

    return {
        items: queueItems
        index: queueIndex
        season: buildSeasonIdentity(episode, seasonId)
    }
end function

'-------------------------------------------------------------------------------
' loadEpisodes
'-------------------------------------------------------------------------------
function loadEpisodes(request as object, seriesId as string, seasonId as string) as object
    params = {
        userId: SafeString(request.userId, "")
        seasonId: seasonId
        fields: "MediaStreams,MediaSources,Overview,Trickplay,UserData"
    }

    url = NormalizeServerUrl(request.server) + "/Shows/" + seriesId + "/Episodes" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if payload.Items <> invalid then return payload.Items
    return []
end function

'-------------------------------------------------------------------------------
' buildPlaybackQueueItems
'-------------------------------------------------------------------------------
function buildPlaybackQueueItems(episodes as object, season as object) as object
    queue = []
    for each episode in episodes
        episodeId = SafeString(FirstNonEmpty([episode.Id], ""), "")
        if episodeId = "" then continue for

        queue.Push({
            itemId: episodeId
            item: episode
            season: season
            startPositionTicks: PlaybackProgress_GetTicksFromItem(episode)
        })
    end for

    return queue
end function

'-------------------------------------------------------------------------------
' getPlaybackQueueIndex
'-------------------------------------------------------------------------------
function getPlaybackQueueIndex(queue as object, itemId as string) as integer
    if queue = invalid then return 0

    for i = 0 to queue.Count() - 1
        item = queue[i]
        if item <> invalid and SafeString(item.itemId, "") = itemId then return i
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' buildSeasonIdentity
'-------------------------------------------------------------------------------
function buildSeasonIdentity(episode as dynamic, seasonId as string) as object
    seasonName = FirstNonEmpty([episode.SeasonName], "")
    if seasonName = "" and episode.ParentIndexNumber <> invalid then seasonName = "Season " + SafeString(episode.ParentIndexNumber, "")

    return {
        Id: seasonId
        Name: seasonName
    }
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

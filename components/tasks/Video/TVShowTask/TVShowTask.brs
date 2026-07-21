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
        if request <> invalid then validationError.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = validationError
        return
    end if

    seriesResult = loadSeries(request)
    if seriesResult.ok <> true then
        seriesResult.AddReplace("action", "tvShow")
        seriesResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = seriesResult
        return
    end if

    seasonsResult = loadSeasons(request)
    if seasonsResult.ok <> true then
        seasonsResult.AddReplace("action", "tvShow")
        seasonsResult.AddReplace("itemId", SafeString(request.itemId, ""))
        m.top.response = seasonsResult
        return
    end if

    resumeItem = invalid
    resumeResult = loadResumeItem(request)
    if resumeResult.ok = true then
        resumeItem = getFirstItem(resumeResult.data)
    else
        m.log.write("Unable to load series resume item: " + SafeString(resumeResult.errorMessage, "unknown error"))
    end if

    upNextItem = invalid
    upNextResult = loadUpNextItem(request)
    if upNextResult.ok = true then
        upNextItem = getFirstItem(upNextResult.data)
    else
        m.log.write("Unable to load series up-next item: " + SafeString(upNextResult.errorMessage, "unknown error"))
    end if

    playbackItem = upNextItem
    if resumeItem <> invalid then playbackItem = resumeItem
    playbackQueue = invalid
    playbackQueueIndex = 0
    if playbackItem <> invalid then
        queue = loadPlaybackQueue(request, playbackItem)
        if queue <> invalid then
            playbackQueue = queue.items
            playbackQueueIndex = queue.index
        end if
    end if

    m.top.response = {
        ok: true
        action: "tvShow"
        itemId: SafeString(request.itemId, "")
        payload: {
            series: seriesResult.data
            seasons: seasonsResult.data
            resumeItem: resumeItem
            upNextItem: upNextItem
            playbackQueue: playbackQueue
            playbackQueueIndex: playbackQueueIndex
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

    url = request.server + "/Items/" + request.itemId + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadUpNextItem
'-------------------------------------------------------------------------------
function loadUpNextItem(request as object) as object
    params = {
        UserId: SafeString(request.userId, "")
        SeriesId: SafeString(request.itemId, "")
        EnableRewatching: false
        DisableFirstEpisode: false
        Limit: 1
        Fields: "SeriesInfo"
        EnableImageTypes: "Primary,Backdrop,Thumb"
        ImageTypeLimit: 1
        EnableTotalRecordCount: false
    }

    url = request.server + "/Shows/NextUp" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' loadPlaybackQueue
'-------------------------------------------------------------------------------
function loadPlaybackQueue(request as object, episode as object) as dynamic
    seasonId = SafeString(FirstNonEmpty([episode.SeasonId, episode.ParentId], ""), "")
    itemId = SafeString(FirstNonEmpty([episode.Id], ""), "")
    if seasonId = "" or itemId = "" then return invalid

    params = {
        UserId: SafeString(request.userId, "")
        SeasonId: seasonId
        Fields: "MediaStreams,MediaSources,Overview,Trickplay,UserData"
    }
    url = request.server + "/Shows/" + request.itemId + "/Episodes" + Url_BuildQueryString(params)
    episodesResult = HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
    if episodesResult.ok <> true then
        m.log.write("Unable to load series playback queue for itemId=" + itemId)
        return invalid
    end if

    episodes = getItemsFromPayload(episodesResult.data)
    season = buildSeasonIdentity(episode, seasonId)
    queueItems = buildPlaybackQueueItems(episodes, season)
    queueIndex = getPlaybackQueueIndex(queueItems, itemId)
    if queueIndex < 0 then return invalid

    return {
        items: queueItems
        index: queueIndex
    }
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
    for i = 0 to queue.Count() - 1
        if SafeString(queue[i].itemId, "") = itemId then return i
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' buildSeasonIdentity
'-------------------------------------------------------------------------------
function buildSeasonIdentity(episode as object, seasonId as string) as object
    seasonName = FirstNonEmpty([episode.SeasonName], "")
    if seasonName = "" and episode.ParentIndexNumber <> invalid then seasonName = "Season " + SafeString(episode.ParentIndexNumber, "")

    return {
        Id: seasonId
        Name: seasonName
    }
end function

'-------------------------------------------------------------------------------
' loadResumeItem
'-------------------------------------------------------------------------------
function loadResumeItem(request as object) as object
    params = {
        UserId: SafeString(request.userId, "")
        ParentId: SafeString(request.itemId, "")
        Recursive: true
        IncludeItemTypes: "Episode"
        Filters: "IsResumable"
        SortBy: "DatePlayed"
        SortOrder: "Descending"
        Limit: 1
        Fields: "SeriesInfo"
        EnableImageTypes: "Primary,Backdrop,Thumb"
        ImageTypeLimit: 1
        EnableTotalRecordCount: false
    }

    url = request.server + "/Items" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' getFirstItem
'-------------------------------------------------------------------------------
function getFirstItem(payload as dynamic) as dynamic
    if payload = invalid or payload.Items = invalid then return invalid
    if payload.Items.Count() = 0 then return invalid

    return payload.Items[0]
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

    url = request.server + "/Shows/" + request.itemId + "/Seasons" + Url_BuildQueryString(params)
    return HttpClient_Request(url, "GET", invalid, invalid, JellyfinAuth_BuildTokenHeaders(request.token))
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return { ok: false, action: "tvShow", errorMessage: "Invalid series details request." }
    if request.server = invalid or request.server = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details server." }
    if request.token = invalid or request.token = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details token." }
    if request.itemId = invalid or request.itemId = "" then return { ok: false, action: "tvShow", errorMessage: "Invalid series details item." }

    return invalid
end function

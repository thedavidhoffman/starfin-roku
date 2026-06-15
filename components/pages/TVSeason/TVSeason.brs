'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVSeason")
    m.backdrop = m.top.findNode("backdrop")
    m.seriesLabel = m.top.findNode("seriesLabel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.episodesList = m.top.findNode("episodesList")
    m.statusLabel = m.top.findNode("statusLabel")
    m.tvSeasonTask = m.top.findNode("tvSeasonTask")

    m.tvSeasonTask.observeField("response", "onTVSeasonResponse")
    m.episodesList.observeField("rowItemSelected", "onEpisodeSelected")
    m.pageState = {
        request: invalid
        season: invalid
        episodes: []
    }
end sub

'-------------------------------------------------------------------------------
' onEpisodeSelected
'-------------------------------------------------------------------------------
sub onEpisodeSelected()
    selected = m.episodesList.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    if m.episodesList.content = invalid then return

    row = m.episodesList.content.getChild(selected[0])
    if row = invalid then return

    episodeNode = row.getChild(selected[1])
    if episodeNode = invalid then return

    episode = episodeNode.raw
    episodeId = SafeString(FirstNonEmpty([episode.Id, episode.id, episodeNode.itemId], ""), "")
    if episodeId = "" then return

    m.top.selectedEpisode = {
        itemId: episodeId
        item: episode
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.season = request.season
    setStatus("Loading season...")
    renderSeason(request.season)
    renderEpisodes([])

    m.tvSeasonTask.request = request
    m.tvSeasonTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onTVSeasonResponse
'-------------------------------------------------------------------------------
sub onTVSeasonResponse()
    response = m.tvSeasonTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load this season."))
        return
    end if

    payload = response.payload
    if payload = invalid then return

    m.pageState.season = payload.season
    m.pageState.episodes = getItemsFromPayload(payload.episodes)
    renderSeason(payload.season)
    renderEpisodes(m.pageState.episodes)
    setStatus("")
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' renderSeason
'-------------------------------------------------------------------------------
sub renderSeason(item as dynamic)
    if isAssocArray(item) = false then return

    m.seriesLabel.text = FirstNonEmpty([item.SeriesName, item.seriesName], "")
    m.titleLabel.text = getItemTitle(item)
    m.metaLabel.text = getMetaText(item)

    backdropUrl = getBackdropUrl(item)
    m.backdrop.visible = backdropUrl <> ""
    m.backdrop.uri = backdropUrl
end sub

'-------------------------------------------------------------------------------
' renderEpisodes
'-------------------------------------------------------------------------------
sub renderEpisodes(episodes as object)
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")

    for each episode in episodes
        if isAssocArray(episode) = false then continue for

        child = row.createChild("ContentNode")
        child.title = getItemTitle(episode)
        child.description = FirstNonEmpty([episode.Overview, episode.overview], "")
        child.HDPosterUrl = getImageUrl(episode, "Primary", 530, 298)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([episode.Id, episode.id], ""), "")
            itemType: SafeString(FirstNonEmpty([episode.Type, episode.type], ""), "")
            episodeNumber: getEpisodeNumberText(episode)
            episodeDate: getEpisodeDateText(episode)
            metaText: getEpisodeMetaText(episode)
            raw: episode
        })
    end for

    m.episodesList.content = content
    m.episodesList.visible = row.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusEpisodesIfActive()
end sub

'-------------------------------------------------------------------------------
' focusEpisodesIfActive
'-------------------------------------------------------------------------------
sub focusEpisodesIfActive()
    if m.episodesList.visible <> true then return
    if m.episodesList.content = invalid then return
    if m.episodesList.content.getChildCount() = 0 then return
    if m.episodesList.content.getChild(0).getChildCount() = 0 then return

    m.episodesList.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' getEpisodeNumberText
'-------------------------------------------------------------------------------
function getEpisodeNumberText(item as dynamic) as string
    indexText = FirstNonEmpty([item.IndexNumber], "")
    if indexText <> "" then return "Episode " + SafeString(indexText, "")
    return "Episode"
end function

'-------------------------------------------------------------------------------
' getEpisodeMetaText
'-------------------------------------------------------------------------------
function getEpisodeMetaText(item as dynamic) as string
    parts = []

    runtime = MediaMetadata_FormatRuntime(item.RunTimeTicks)
    if runtime <> "" then parts.Push(runtime)

    communityRating = MediaMetadata_FormatRating(FirstNonEmpty([item.CommunityRating], ""))
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    airedDate = getAiredDateText(item)
    if airedDate <> "" then parts.Push("Aired: " + airedDate)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getAiredDateText
'-------------------------------------------------------------------------------
function getAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.PremiereDate, item.AirDate, item.DateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

'-------------------------------------------------------------------------------
' getEpisodeDateText
'-------------------------------------------------------------------------------
function getEpisodeDateText(item as dynamic) as string
    airedDate = getAiredDateText(item)
    if Len(airedDate) < 10 then return airedDate

    year = Left(airedDate, 4)
    monthNumber = val(Mid(airedDate, 6, 2))
    day = val(Mid(airedDate, 9, 2))
    if monthNumber < 1 or monthNumber > 12 or day < 1 then return airedDate

    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return day.ToStr() + " " + monthNames[monthNumber - 1] + " " + year
end function

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.Name, item.name, item.title], "")
end function

'-------------------------------------------------------------------------------
' getMetaText
'-------------------------------------------------------------------------------
function getMetaText(item as dynamic) as string
    parts = []

    episodeCount = FirstNonEmpty([item.RecursiveItemCount, item.ChildCount], "")
    if episodeCount <> "" then parts.Push(SafeString(episodeCount, "") + " episodes")

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
    if year <> "" then parts.Push(year)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    return joinText(parts, "  |  ")
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getBackdropUrl
'-------------------------------------------------------------------------------
function getBackdropUrl(item as dynamic) as string
    if item = invalid then return ""
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then
        itemId = FirstNonEmpty([item.Id, item.id], "")
        return buildImageUrl(itemId, "Backdrop", item.BackdropImageTags[0], 1920, 1080)
    end if

    return getImageUrl(item, "Primary", 1920, 1080)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    itemId = FirstNonEmpty([item.Id, item.id], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Primary" and item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then tag = item.ImageTags.Primary
    if imageType = "Backdrop" and item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""

    return buildImageUrl(itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.pageState.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    return url + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []

    payloadType = Type(payload)
    if payloadType = "roArray" then return payload
    if isAssocArray(payload) = false then return []

    if payload.Items <> invalid then return payload.Items
    if payload.items <> invalid then return payload.items

    return []
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    if values = invalid then return ""

    text = ""
    for each value in values
        part = String_Trim(SafeString(value, ""))
        if part <> "" then
            if text <> "" then text = text + separator
            text = text + part
        end if
    end for

    return text
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' setStatus
'-------------------------------------------------------------------------------
sub setStatus(message as string)
    m.statusLabel.text = message
    m.statusLabel.visible = message <> ""
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    return false
end function

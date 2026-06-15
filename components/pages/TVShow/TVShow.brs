'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVShow")
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.seasonsGrid = m.top.findNode("seasonsGrid")
    m.statusLabel = m.top.findNode("statusLabel")
    m.tvShowTask = m.top.findNode("tvShowTask")

    m.tvShowTask.observeField("response", "onTVShowResponse")
    m.seasonsGrid.observeField("itemSelected", "onSeasonSelected")
    m.pageState = {
        request: invalid
        series: invalid
        seasons: []
    }
end sub

'-------------------------------------------------------------------------------
' onSeasonSelected
'-------------------------------------------------------------------------------
sub onSeasonSelected()
    selected = m.seasonsGrid.itemSelected
    if selected = invalid then return
    if m.seasonsGrid.content = invalid then return

    seasonNode = m.seasonsGrid.content.getChild(selected)
    if seasonNode = invalid then return

    season = seasonNode.raw
    seasonId = SafeString(FirstNonEmpty([season.Id, season.id, seasonNode.itemId], ""), "")
    if seasonId = "" then return

    series = m.pageState.series
    request = m.pageState.request
    if request = invalid then return

    m.top.selectedSeason = {
        seriesId: SafeString(FirstNonEmpty([request.itemId], ""), "")
        seasonId: seasonId
        series: series
        season: season
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.series = request.item
    setStatus("Loading series...")
    renderSeries(request.item)
    renderSeasons([])

    m.tvShowTask.request = request
    m.tvShowTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onTVShowResponse
'-------------------------------------------------------------------------------
sub onTVShowResponse()
    response = m.tvShowTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load this series."))
        return
    end if

    payload = response.payload
    if payload = invalid then return

    m.pageState.series = payload.series
    m.pageState.seasons = getItemsFromPayload(payload.seasons)
    renderSeries(payload.series)
    renderSeasons(m.pageState.seasons)
    setStatus("")
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' renderSeries
'-------------------------------------------------------------------------------
sub renderSeries(item as dynamic)
    if isAssocArray(item) = false then return

    m.titleLabel.text = getItemTitle(item)
    m.metaLabel.text = getMetaText(item)
    m.overviewLabel.text = FirstNonEmpty([item.Overview, item.overview], "")

    posterUrl = getImageUrl(item, "Primary", 300, 450)
    m.poster.visible = posterUrl <> ""
    m.poster.uri = posterUrl

    backdropUrl = getBackdropUrl(item)
    m.backdrop.visible = backdropUrl <> ""
    m.backdrop.uri = backdropUrl
end sub

'-------------------------------------------------------------------------------
' renderSeasons
'-------------------------------------------------------------------------------
sub renderSeasons(seasons as object)
    content = CreateObject("roSGNode", "ContentNode")

    for each season in seasons
        if isAssocArray(season) = false then continue for

        child = content.createChild("ContentNode")
        child.title = getItemTitle(season)
        child.description = getSeasonSubtitle(season)
        child.HDPosterUrl = getImageUrl(season, "Primary", 180, 270)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([season.Id, season.id], ""), "")
            itemType: SafeString(FirstNonEmpty([season.Type, season.type], ""), "")
            raw: season
        })
    end for

    m.seasonsGrid.content = content
    m.seasonsGrid.visible = content.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' focusSeasonsIfActive
'-------------------------------------------------------------------------------
sub focusSeasonsIfActive()
    if m.seasonsGrid.visible <> true then return
    if m.seasonsGrid.content = invalid then return
    if m.seasonsGrid.content.getChildCount() = 0 then return

    m.seasonsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return "Series"
    return FirstNonEmpty([item.Name, item.name, item.title], "Series")
end function

'-------------------------------------------------------------------------------
' getMetaText
'-------------------------------------------------------------------------------
function getMetaText(item as dynamic) as string
    parts = []

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
    if year <> "" then parts.Push(year)

    episodeCount = FirstNonEmpty([item.RecursiveItemCount, item.ChildCount], "")
    if episodeCount <> "" then parts.Push(SafeString(episodeCount, "") + " episodes")

    status = FirstNonEmpty([item.Status, item.status], "")
    if status <> "" then parts.Push(status)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    genres = getGenreText(item)
    if genres <> "" then parts.Push(genres)

    communityRating = FirstNonEmpty([item.CommunityRating], "")
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    return joinText(parts, "  |  ")
end function

'-------------------------------------------------------------------------------
' getSeasonSubtitle
'-------------------------------------------------------------------------------
function getSeasonSubtitle(item as dynamic) as string
    count = FirstNonEmpty([item.RecursiveItemCount, item.ChildCount], "")
    if count = "" then return ""
    return SafeString(count, "") + " episodes"
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getGenreText
'-------------------------------------------------------------------------------
function getGenreText(item as dynamic) as string
    if item.Genres = invalid then return ""
    return joinText(item.Genres, ", ")
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

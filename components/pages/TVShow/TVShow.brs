'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVShow")
    m.contentGroup = m.top.findNode("contentGroup")
    m.mediaShell = m.top.findNode("mediaShell")
    m.seasonsLabel = m.top.findNode("seasonsLabel")
    m.seasonsGrid = m.top.findNode("seasonsGrid")
    m.cast = m.top.findNode("cast")
    m.tvShowTask = m.top.findNode("tvShowTask")

    m.tvShowTask.observeField("response", "onTVShowResponse")
    m.seasonsGrid.observeField("itemSelected", "onSeasonSelected")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.pageState = {
        request: invalid
        series: invalid
        seasons: []
        focusArea: "seasons"
    }
    m.layout = {
        contentDefault: [96, 0]
        contentCastFocused: [96, -397]
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
    seasonId = SafeString(FirstNonEmpty([season.Id, seasonNode.itemId], ""), "")
    if seasonId = "" then return

    nextSeason = getNextSeason(selected)
    request = m.pageState.request
    if request = invalid then return

    m.top.selectedSeason = {
        seriesId: SafeString(FirstNonEmpty([request.itemId], ""), "")
        seasonId: seasonId
        series: SeriesIdentity_FromItem(request.server, m.pageState.series)
        season: season
        nextSeason: nextSeason
    }
end sub

'-------------------------------------------------------------------------------
' getNextSeason
'-------------------------------------------------------------------------------
function getNextSeason(selectedIndex as integer) as dynamic
    seasons = m.pageState.seasons
    if seasons = invalid then return invalid

    nextIndex = selectedIndex + 1
    if nextIndex < 0 or nextIndex >= seasons.Count() then return invalid

    return seasons[nextIndex]
end function

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.series = request.item
    m.pageState.focusArea = "seasons"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    m.cast.server = request.server
    m.cast.people = []
    Status_SetLoading()
    renderSeries(request.item, true)
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
        renderSeries(m.pageState.series, false)
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this series."))
        return
    end if

    payload = response.payload
    if payload = invalid then return

    m.pageState.series = payload.series
    m.pageState.seasons = getItemsFromPayload(payload.seasons)
    renderSeries(payload.series, false)
    renderSeasons(m.pageState.seasons)
    Status_ClearMessage()
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' renderSeries
'-------------------------------------------------------------------------------
sub renderSeries(item as dynamic, logoPending = false as boolean)
    if isAssocArray(item) = false then return

    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
        logoPending: logoPending
        title: getItemTitle(item)
        metaLine1: getMetaText(item)
        metaLine2: getGenreText(item)
        overview: FirstNonEmpty([item.Overview], "")
    }
    m.cast.people = getPeople(item)
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
        child.HDPosterUrl = getImageUrl(season, "Primary", 208, 312)
        child.AddFields({
            itemId: SafeString(FirstNonEmpty([season.Id], ""), "")
            itemType: SafeString(FirstNonEmpty([season.Type], ""), "")
            seasonYear: getSeasonYearText(season)
            episodeCount: FirstNonEmpty([season.RecursiveItemCount, season.ChildCount], "")
            raw: season
        })
    end for

    m.seasonsGrid.content = content
    m.seasonsGrid.visible = content.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' setSeasonsVisible
'-------------------------------------------------------------------------------
sub setSeasonsVisible(isVisible as boolean)
    hasSeasons = m.seasonsGrid.content <> invalid and m.seasonsGrid.content.getChildCount() > 0
    visible = isVisible and hasSeasons
    m.seasonsLabel.visible = visible
    m.seasonsGrid.visible = visible
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.pageState.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
    else
        focusSeasonsIfActive()
    end if
end sub

'-------------------------------------------------------------------------------
' focusSeasonsIfActive
'-------------------------------------------------------------------------------
sub focusSeasonsIfActive()
    if m.seasonsGrid.content = invalid then return
    if m.seasonsGrid.content.getChildCount() = 0 then return

    m.pageState.focusArea = "seasons"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
    m.seasonsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.pageState.focusArea = "cast"
    m.contentGroup.translation = m.layout.contentCastFocused
    setSeasonsVisible(false)
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    selection.sourceItemType = "series"
    selection.sourceSeriesId = SafeString(m.pageState.request.itemId, "")
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' onSeasonWatchedStateChange
'-------------------------------------------------------------------------------
sub onSeasonWatchedStateChange()
    change = m.top.seasonWatchedStateChange
    if change = invalid then return

    seasonId = SafeString(change.seasonId, "")
    if seasonId = "" then return

    updateSeasonWatchedState(m.pageState.seasons, seasonId, change)
    updateSeasonCardWatchedState(seasonId, change)
end sub

'-------------------------------------------------------------------------------
' updateSeasonWatchedState
'-------------------------------------------------------------------------------
sub updateSeasonWatchedState(seasons as dynamic, seasonId as string, change as object)
    if seasons = invalid then return

    for each season in seasons
        if isAssocArray(season) = false then continue for
        if SafeString(FirstNonEmpty([season.Id], ""), "") <> seasonId then continue for

        applySeasonWatchedState(season, change)
        return
    end for
end sub

'-------------------------------------------------------------------------------
' updateSeasonCardWatchedState
'-------------------------------------------------------------------------------
sub updateSeasonCardWatchedState(seasonId as string, change as object)
    if m.seasonsGrid.content = invalid then return

    for i = 0 to m.seasonsGrid.content.getChildCount() - 1
        child = m.seasonsGrid.content.getChild(i)
        if child = invalid then continue for
        if SafeString(child.itemId, "") <> seasonId then continue for

        raw = child.raw
        if isAssocArray(raw) then
            applySeasonWatchedState(raw, change)
            child.raw = raw
        end if

        return
    end for
end sub

'-------------------------------------------------------------------------------
' applySeasonWatchedState
'-------------------------------------------------------------------------------
sub applySeasonWatchedState(season as object, change as object)
    if season.UserData = invalid then season.UserData = {}

    unplayedItemCount = 0
    if change.unplayedItemCount <> invalid then unplayedItemCount = int(change.unplayedItemCount)
    if unplayedItemCount < 0 then unplayedItemCount = 0

    season.UserData.UnplayedItemCount = unplayedItemCount
    season.UserData.Played = unplayedItemCount = 0
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return "Series"
    return FirstNonEmpty([item.Name], "Series")
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

    status = FirstNonEmpty([item.Status], "")
    if status <> "" then parts.Push(status)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    communityRating = MediaMetadata_FormatRating(FirstNonEmpty([item.CommunityRating], ""))
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getSeasonYearText
'-------------------------------------------------------------------------------
function getSeasonYearText(item as dynamic) as string
    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))

    return SafeString(year, "")
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
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item = invalid or item.People = invalid then return []
    return item.People
end function

'-------------------------------------------------------------------------------
' getBackdropUrl
'-------------------------------------------------------------------------------
function getBackdropUrl(item as dynamic) as string
    if item = invalid then return ""
    imageSize = DeviceCapabilities_GetMaxScreenImageSize()
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then
        itemId = FirstNonEmpty([item.Id], "")
        request = m.pageState.request
        if request = invalid then return ""
        return Url_BuildImageUrl(request.server, itemId, "Backdrop", item.BackdropImageTags[0], imageSize.width, imageSize.height)
    end if

    return getImageUrl(item, "Primary", imageSize.width, imageSize.height)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Primary" and item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then tag = item.ImageTags.Primary
    if imageType = "Logo" and item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
    if imageType = "Backdrop" and item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then tag = item.BackdropImageTags[0]
    if tag = "" then return ""
    request = m.pageState.request
    if request = invalid then return ""

    options = invalid
    if imageType = "Logo" then options = { format: "Png" }
    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height, options)
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
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    if key = "down" and m.pageState.focusArea = "seasons" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
        return true
    end if

    return false
end function

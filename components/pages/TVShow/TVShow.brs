'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVShow")
    m.contentGroup = m.top.findNode("contentGroup")
    m.mediaShell = m.top.findNode("mediaShell")
    m.seasonsLabel = m.top.findNode("seasonsLabel")
    m.seasonsGrid = m.top.findNode("seasonsGrid")
    m.castDownCue = m.top.findNode("castDownCue")
    m.cast = m.top.findNode("cast")
    m.seasonsUpCue = m.top.findNode("seasonsUpCue")
    m.statusLabel = m.top.findNode("statusLabel")
    m.tvShowTask = m.top.findNode("tvShowTask")

    m.tvShowTask.observeField("response", "onTVShowResponse")
    m.seasonsGrid.observeField("itemSelected", "onSeasonSelected")
    m.cast.observeField("hasItems", "onCastHasItemsChanged")
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
' onCastHasItemsChanged
'-------------------------------------------------------------------------------
sub onCastHasItemsChanged()
    updateNavigationCues()
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
    m.pageState.focusArea = "seasons"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    updateNavigationCues()
    m.cast.server = request.server
    m.cast.people = []
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

    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
        title: getItemTitle(item)
        metaLine1: getMetaText(item)
        metaLine2: getGenreText(item)
        overview: FirstNonEmpty([item.Overview, item.overview], "")
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
            itemId: SafeString(FirstNonEmpty([season.Id, season.id], ""), "")
            itemType: SafeString(FirstNonEmpty([season.Type, season.type], ""), "")
            raw: season
        })
    end for

    m.seasonsGrid.content = content
    m.seasonsGrid.visible = content.getChildCount() > 0
    updateNavigationCues()
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
' updateNavigationCues
'-------------------------------------------------------------------------------
sub updateNavigationCues()
    hasCast = m.cast.visible = true and m.cast.hasItems = true
    m.castDownCue.visible = m.pageState.focusArea = "seasons" and hasCast
    m.seasonsUpCue.visible = m.pageState.focusArea = "cast"
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
    updateNavigationCues()
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
    updateNavigationCues()
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

    m.top.selectedPerson = selection
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

    communityRating = MediaMetadata_FormatRating(FirstNonEmpty([item.CommunityRating], ""))
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    return joinText(parts, MediaMetadata_BulletSeparator())
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
    if imageType = "Logo" and item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
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
    url = url + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    if imageType = "Logo" then url = url + "&format=Png"
    return url
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

    if key = "down" and m.pageState.focusArea = "seasons" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
        return true
    end if

    return false
end function

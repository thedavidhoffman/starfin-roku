'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TVShow")
    m.contentGroup = m.top.findNode("contentGroup")
    m.mediaShell = m.top.findNode("mediaShell")
    m.videoToolbar = m.top.findNode("videoToolbar")
    m.seasonsGrid = m.top.findNode("seasonsGrid")
    m.cast = m.top.findNode("cast")
    m.chevronFooter = m.top.findNode("chevronFooter")
    m.tvShowTask = m.top.findNode("tvShowTask")
    m.themeSongsTask = m.top.findNode("themeSongsTask")

    m.tvShowTask.observeField("response", "onTVShowResponse")
    m.themeSongsTask.observeField("response", "onThemeSongsResponse")
    m.mediaShell.observeField("overlayRequested", "onMediaShellOverlayRequested")
    m.videoToolbar.observeField("playSelected", "onVideoToolbarPlaySelected")
    m.videoToolbar.observeField("focusExitUp", "onVideoToolbarFocusExitUp")
    m.videoToolbar.observeField("focusExitDown", "onVideoToolbarFocusExitDown")
    m.seasonsGrid.observeField("itemSelected", "onSeasonSelected")
    m.cast.observeField("hasItems", "onCastAvailabilityChanged")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.pageState = {
        request: invalid
        series: invalid
        seasons: []
        playbackQueue: invalid
        playbackQueueIndex: 0
        focusArea: "videoToolbar"
        themeLookupActive: false
        lifecycle: AsyncLifecycle_Create()
    }
    m.layout = {
        contentDefault: [96, 0]
        contentCastFocused: [96, -397]
    }
end sub

'-------------------------------------------------------------------------------
' onVideoToolbarPlaySelected
'-------------------------------------------------------------------------------
sub onVideoToolbarPlaySelected()
    item = m.videoToolbar.playItem
    shouldResume = false
    if m.videoToolbar.resumeItem <> invalid then
        item = m.videoToolbar.resumeItem
        shouldResume = true
    end if

    emitEpisodeSelection(item, shouldResume)
end sub

'-------------------------------------------------------------------------------
' emitEpisodeSelection
'-------------------------------------------------------------------------------
sub emitEpisodeSelection(item as dynamic, shouldResume as boolean)
    if Array_IsAssocArray(item) = false then return

    itemId = SafeString(item.Id, "")
    if itemId = "" then return

    startPositionTicks = 0
    if shouldResume then startPositionTicks = PlaybackProgress_GetTicksFromItem(item)

    m.top.selectedEpisode = {
        itemId: itemId
        item: item
        series: SeriesIdentity_FromItem(SafeString(m.pageState.request.server, ""), m.pageState.series)
        season: {
            Id: SafeString(item.SeasonId, "")
            Name: SafeString(item.SeasonName, "")
        }
        startPositionTicks: startPositionTicks
        playbackQueue: m.pageState.playbackQueue
        playbackQueueIndex: m.pageState.playbackQueueIndex
    }
end sub

'-------------------------------------------------------------------------------
' onVideoToolbarFocusExitUp
'-------------------------------------------------------------------------------
sub onVideoToolbarFocusExitUp()
    focusMediaDescription()
end sub

'-------------------------------------------------------------------------------
' onVideoToolbarFocusExitDown
'-------------------------------------------------------------------------------
sub onVideoToolbarFocusExitDown()
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' onMediaShellOverlayRequested
'-------------------------------------------------------------------------------
sub onMediaShellOverlayRequested()
    request = m.mediaShell.overlayRequested
    if request = invalid then return

    request.sourcePage = "tvShow"
    m.top.overlayRequested = request
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
        seasons: m.pageState.seasons
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
    m.top.settings = request.settings
    applyMediaShellBackgroundSetting(request.settings)
    m.pageState.series = request.item
    m.pageState.playbackQueue = invalid
    m.pageState.playbackQueueIndex = 0
    m.pageState.themeLookupActive = false
    AsyncLifecycle_Begin(m.pageState.lifecycle, request.itemId)
    m.pageState.focusArea = "videoToolbar"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    updateFocusChevron()
    m.cast.server = request.server
    m.cast.people = []
    Spinner_Show()
    renderSeries(request.item, true)
    renderSeasons([])
    m.videoToolbar.resumeItem = invalid
    m.videoToolbar.playItem = invalid

    m.tvShowTask.request = request
    m.tvShowTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onSettingsChanged
'-------------------------------------------------------------------------------
sub onSettingsChanged()
    settings = m.top.settings
    if m.pageState <> invalid and m.pageState.request <> invalid then m.pageState.request.settings = settings
    applyMediaShellBackgroundSetting(settings)
end sub

'-------------------------------------------------------------------------------
' applyMediaShellBackgroundSetting
'-------------------------------------------------------------------------------
sub applyMediaShellBackgroundSetting(settings as dynamic)
    keys = SettingsStore_Keys()
    m.mediaShell.backgroundDisplay = SettingsStore_GetSettingValue(settings, keys.mediaShellBackground)
end sub

'-------------------------------------------------------------------------------
' onTVShowResponse
'-------------------------------------------------------------------------------
sub onTVShowResponse()
    response = m.tvShowTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.pageState.lifecycle, response, "itemId", "tvShow") <> true then return

    if response.ok <> true then
        Spinner_Hide()
        renderSeries(m.pageState.series, false)
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this series."))
        return
    end if

    payload = response.payload
    if payload = invalid then
        Spinner_Hide()
        return
    end if

    m.pageState.series = payload.series
    m.pageState.seasons = getItemsFromPayload(payload.seasons)
    m.pageState.playbackQueue = payload.playbackQueue
    m.pageState.playbackQueueIndex = Number_ToInteger(payload.playbackQueueIndex, 0)
    m.videoToolbar.resumeItem = payload.resumeItem
    m.videoToolbar.playItem = payload.upNextItem
    renderSeries(payload.series, false)
    renderSeasons(m.pageState.seasons)
    Spinner_Hide()
    Status_ClearMessage()
    if m.pageState.focusArea = "videoToolbar" then
        focusVideoToolbar()
    else
        focusSeasonsIfActive()
    end if
    loadThemeSong(payload.series)
end sub

'-------------------------------------------------------------------------------
' loadThemeSong
'-------------------------------------------------------------------------------
sub loadThemeSong(item as dynamic)
    request = m.pageState.request
    if request = invalid then return
    if isThemeMusicEnabled() <> true then
        m.log.write("Theme music playback is disabled")
        return
    end if

    m.log.write("Theme music playback is enabled")

    itemId = SafeString(FirstNonEmpty([item.Id, request.itemId], ""), "")
    if itemId = "" then return

    m.pageState.themeLookupActive = true
    m.themeSongsTask.control = "stop"
    m.themeSongsTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.themeSongsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onThemeSongsResponse
'-------------------------------------------------------------------------------
sub onThemeSongsResponse()
    response = m.themeSongsTask.response
    if response = invalid then return
    if m.pageState.lifecycle.isActive <> true then return
    if m.pageState.themeLookupActive <> true then return
    if response.ok <> true then
        m.log.write("Theme song lookup failed: " + SafeString(response.errorMessage, "Unknown error."))
        return
    end if

    themeSong = response.payload
    if Array_IsAssocArray(themeSong) = false then
        m.pageState.themeLookupActive = false
        m.log.write("Theme music enabled, but no theme song was found")
        return
    end if

    request = m.pageState.request
    if request = invalid then return
    if SafeString(response.itemId, "") <> SafeString(request.itemId, "") then return

    m.pageState.themeLookupActive = false
    themeSongId = SafeString(themeSong.Id, "")
    if themeSongId = "" then
        m.pageState.themeLookupActive = false
        return
    end if

    m.log.write("Theme song found itemId=" + themeSongId)
    m.top.themeRequested = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: themeSongId
        title: FirstNonEmpty([themeSong.Name, m.pageState.series.Name], "Theme Music")
        sourceItemId: SafeString(request.itemId, "")
    }
end sub

'-------------------------------------------------------------------------------
' renderSeries
'-------------------------------------------------------------------------------
sub renderSeries(item as dynamic, logoPending = false as boolean)
    if Array_IsAssocArray(item) = false then return

    seriesMetadataText = getMetaText(item)
    genreText = getGenreText(item)
    m.mediaShell.mediaContent = {
        backdropUrl: getBackdropUrl(item)
        logoUrl: getImageUrl(item, "Logo", 600, 300)
        logoPending: logoPending
        title: getItemTitle(item)
        primaryInfoText: seriesMetadataText
        secondaryInfoText: genreText
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
        if Array_IsAssocArray(season) = false then continue for

        child = content.createChild("ContentNode")
        child.title = getItemTitle(season)
        child.HDPosterUrl = getSeasonPosterUrl(season)
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
    updateFocusChevron()
end sub

'-------------------------------------------------------------------------------
' getSeasonPosterUrl
'-------------------------------------------------------------------------------
function getSeasonPosterUrl(season as dynamic) as string
    posterUrl = getImageUrl(season, "Primary", 208, 312)
    if posterUrl <> "" then return posterUrl

    return getImageUrl(m.pageState.series, "Primary", 208, 312)
end function

'-------------------------------------------------------------------------------
' setSeasonsVisible
'-------------------------------------------------------------------------------
sub setSeasonsVisible(isVisible as boolean)
    hasSeasons = m.seasonsGrid.content <> invalid and m.seasonsGrid.content.getChildCount() > 0
    visible = isVisible and hasSeasons
    m.seasonsGrid.visible = visible
    updateFocusChevron()
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.pageState.lifecycle, m.pageState.request, "itemId")
    if m.pageState.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
    else if m.pageState.focusArea = "videoToolbar" then
        focusVideoToolbar()
    else
        focusSeasonsIfActive()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.pageState.lifecycle)
    m.pageState.themeLookupActive = false
    m.tvShowTask.control = "stop"
    m.themeSongsTask.control = "stop"
    m.videoToolbar.callFunc("deactivate")
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
    m.videoToolbar.callFunc("deactivate")
    updateFocusChevron()
    m.top.setFocus(true)
    m.seasonsGrid.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusVideoToolbar
'-------------------------------------------------------------------------------
sub focusVideoToolbar()
    m.pageState.focusArea = "videoToolbar"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    m.cast.callFunc("deactivate")
    updateFocusChevron()
    m.top.setFocus(true)
    m.videoToolbar.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' focusMediaDescription
'-------------------------------------------------------------------------------
function focusMediaDescription() as boolean
    if m.mediaShell.callFunc("canFocusDescription") <> true then return false

    m.pageState.focusArea = "description"
    m.contentGroup.translation = m.layout.contentDefault
    setSeasonsVisible(true)
    m.cast.callFunc("deactivate")
    m.videoToolbar.callFunc("deactivate")
    updateFocusChevron()
    m.top.setFocus(true)
    return m.mediaShell.callFunc("focusDescription")
end function

'-------------------------------------------------------------------------------
' handleDescriptionOverlayClosed
'-------------------------------------------------------------------------------
sub handleDescriptionOverlayClosed()
    focusMediaDescription()
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.pageState.focusArea = "cast"
    m.contentGroup.translation = m.layout.contentCastFocused
    setSeasonsVisible(false)
    m.videoToolbar.callFunc("deactivate")
    m.cast.callFunc("activate")
    updateFocusChevron()
end sub

'-------------------------------------------------------------------------------
' onCastAvailabilityChanged
'-------------------------------------------------------------------------------
sub onCastAvailabilityChanged()
    updateFocusChevron()
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusSeasonsIfActive()
end sub

'-------------------------------------------------------------------------------
' updateFocusChevron
'-------------------------------------------------------------------------------
sub updateFocusChevron()
    hasSeasons = m.seasonsGrid.content <> invalid and m.seasonsGrid.content.getChildCount() > 0
    hasCast = m.cast.visible = true and m.cast.hasItems = true

    if m.pageState.focusArea = "seasons" and hasSeasons and hasCast then
        m.chevronFooter.direction = "down"
    else if m.pageState.focusArea = "cast" and hasCast and hasSeasons then
        m.chevronFooter.direction = "up"
    else
        m.chevronFooter.direction = ""
    end if
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
        if Array_IsAssocArray(season) = false then continue for
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
        if Array_IsAssocArray(raw) then
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
    if Array_IsAssocArray(item) = false then return "Series"
    return FirstNonEmpty([item.Name], "Series")
end function

'-------------------------------------------------------------------------------
' getMetaText
'-------------------------------------------------------------------------------
function getMetaText(item as dynamic) as string
    parts = []

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = DateTime_ToYear(item.PremiereDate)
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
    if year = "" then year = DateTime_ToYear(item.PremiereDate)

    return SafeString(year, "")
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
    if Array_IsAssocArray(payload) = false then return []

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
' isThemeMusicEnabled
'-------------------------------------------------------------------------------
function isThemeMusicEnabled() as boolean
    return false
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

    if key = "up" and m.pageState.focusArea = "seasons" then
        focusVideoToolbar()
        return true
    end if

    if key = "down" and m.pageState.focusArea = "description" then
        focusVideoToolbar()
        return true
    end if

    if key = "down" and m.pageState.focusArea = "seasons" and m.cast.visible = true and m.cast.hasItems = true then
        focusCast()
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initHandlers()
    initStyles()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.logoBanner = m.top.findNode("logoBanner")
    m.episodePoster = m.top.findNode("episodePoster")
    m.secondaryMetadata = m.top.findNode("secondaryMetadata")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.mediaToolbar = m.top.findNode("mediaToolbar")
    m.cast = m.top.findNode("cast")
    m.layout = {
        descriptionX: 755
        titleY: 288
        descriptionY: 342
    }
    m.episodeDetailsTask = m.top.findNode("episodeDetailsTask")
    m.watchedTask = m.top.findNode("watchedTask")
    m.state = {
        request: invalid
        itemId: ""
        itemContent: invalid
        playSelection: invalid
        focusArea: "toolbar"
    }
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.episodeDetailsTask.observeField("response", "onEpisodeDetailsResponse")
    m.watchedTask.observeField("response", "onWatchedTaskResponse")
    m.mediaToolbar.observeField("focusExitDown", "onMediaToolbarFocusExitDown")
    m.mediaToolbar.observeField("playSelected", "onMediaToolbarPlaySelected")
    m.mediaToolbar.observeField("markAsWatchedSelected", "onMarkAsWatchedSelected")
    m.mediaToolbar.observeField("markAsUnwatchedSelected", "onMarkAsUnwatchedSelected")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
    colors = Color()
    m.secondaryMetadata.color = colors.text.secondary
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    m.state.request = m.top.loadRequest
    m.state.itemId = ""
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    clearContent()
    if m.state.request <> invalid then
        m.cast.server = m.state.request.server
        renderLogoBanner()
        renderInitialEpisodeContent()
    else
        clearLogoBanner()
    end if
    loadItemDetails()
end sub

'-------------------------------------------------------------------------------
' renderLogoBanner
'-------------------------------------------------------------------------------
sub renderLogoBanner()
    request = m.state.request
    if request = invalid then
        clearLogoBanner()
        return
    end if

    m.logoBanner.logoUrl = getSeriesLogoUrl(request)
    m.logoBanner.title = ""
end sub

'-------------------------------------------------------------------------------
' clearLogoBanner
'-------------------------------------------------------------------------------
sub clearLogoBanner()
    m.logoBanner.title = ""
    m.logoBanner.logoUrl = ""
end sub

'-------------------------------------------------------------------------------
' getSeriesLogoUrl
'-------------------------------------------------------------------------------
function getSeriesLogoUrl(request as dynamic) as string
    if request = invalid or request.series = invalid then return ""

    logoUrl = FirstNonEmpty([request.series.logoUrl], "")
    if logoUrl <> "" then return logoUrl

    return getImageUrl(request.series, "Logo", 600, 300)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as dynamic, imageType as string, width as integer, height as integer) as string
    if item = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    tag = ""
    if imageType = "Logo" and item.ImageTags <> invalid and item.ImageTags.Logo <> invalid then tag = item.ImageTags.Logo
    if tag = "" then return ""

    return buildImageUrl(itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.state.request
    if request = invalid then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    return url + "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90&format=Png"
end function

'-------------------------------------------------------------------------------
' renderEpisodeContent
'-------------------------------------------------------------------------------
sub renderEpisodeContent(item as dynamic)
    if item = invalid then
        clearContent()
        return
    end if

    title = getDisplayTitle(item)
    m.title.text = title
    m.description.text = SafeString(item.description, "")
    m.secondaryMetadata.text = getSecondaryMetadataText(item)
    applyLayout(title)

    m.episodePoster.itemContent = item
    m.mediaToolbar.supportsWatchedActions = canMarkWatched(item)
    m.mediaToolbar.isWatched = isItemWatched(item)
end sub

'-------------------------------------------------------------------------------
' applyLayout
'-------------------------------------------------------------------------------
sub applyLayout(title as string)
    hideTitle = isSeasonNumberTitle(title)
    m.title.visible = hideTitle <> true
    if hideTitle = true then
        m.description.translation = [m.layout.descriptionX, m.layout.titleY]
    else
        m.description.translation = [m.layout.descriptionX, m.layout.descriptionY]
    end if
end sub

'-------------------------------------------------------------------------------
' isSeasonNumberTitle
'-------------------------------------------------------------------------------
function isSeasonNumberTitle(title as string) as boolean
    value = LCase(String_Trim(title))
    if Left(value, 7) <> "season " then return false

    seasonNumber = String_Trim(Mid(value, 8))
    if seasonNumber = "" then return false

    for i = 1 to Len(seasonNumber)
        char = Mid(seasonNumber, i, 1)
        if char < "0" or char > "9" then return false
    end for

    return true
end function

'-------------------------------------------------------------------------------
' getSecondaryMetadataText
'-------------------------------------------------------------------------------
function getSecondaryMetadataText(item as dynamic) as string
    if item = invalid then return ""
    if SafeString(item.itemType, "") = "SeasonSummary" then return ""

    raw = item.raw
    if raw = invalid then return ""

    parts = []

    dateText = SafeString(item.episodeDate, "")
    if dateText <> "" then parts.Push(dateText)

    runtimeText = MediaMetadata_FormatRuntime(raw.RunTimeTicks)
    if runtimeText <> "" then parts.Push(runtimeText)

    ratingText = getRatingText(raw)
    if ratingText <> "" then parts.Push(ratingText)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getRatingText
'-------------------------------------------------------------------------------
function getRatingText(item as dynamic) as string
    rating = MediaMetadata_FormatRating(item.CommunityRating)
    if rating = "" then return ""

    return "Rating " + rating
end function

'-------------------------------------------------------------------------------
' joinText
'-------------------------------------------------------------------------------
function joinText(values as dynamic, separator as string) as string
    if values = invalid then return ""

    result = ""
    for each value in values
        text = SafeString(value, "")
        if text = "" then continue for

        if result <> "" then result = result + separator
        result = result + text
    end for

    return result
end function

'-------------------------------------------------------------------------------
' getDisplayTitle
'-------------------------------------------------------------------------------
function getDisplayTitle(item as dynamic) as string
    title = SafeString(item.title, "")
    if item = invalid or SafeString(item.itemType, "") = "SeasonSummary" then return title
    if item.raw = invalid then return title

    prefix = getEpisodeTitlePrefix(item.raw)
    if prefix = "" then return title

    return prefix + title
end function

'-------------------------------------------------------------------------------
' getEpisodeTitlePrefix
'-------------------------------------------------------------------------------
function getEpisodeTitlePrefix(item as dynamic) as string
    seasonNumber = SafeString(item.ParentIndexNumber, "")
    episodeNumber = SafeString(item.IndexNumber, "")
    if seasonNumber = "" or episodeNumber = "" then return ""

    return "S" + seasonNumber + "E" + episodeNumber + ": "
end function

'-------------------------------------------------------------------------------
' loadItemDetails
'-------------------------------------------------------------------------------
sub loadItemDetails()
    request = m.state.request
    if request = invalid then return

    itemId = SafeString(request.itemId, "")
    if itemId = "" then
        m.state.itemId = ""
        m.cast.people = []
        return
    end if

    if itemId = m.state.itemId then return
    m.state.itemId = itemId
    m.cast.people = []

    m.episodeDetailsTask.request = {
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.episodeDetailsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onEpisodeDetailsResponse
'-------------------------------------------------------------------------------
sub onEpisodeDetailsResponse()
    response = m.episodeDetailsTask.response
    if response = invalid then return
    if response.ok <> true then return
    if SafeString(response.itemId, "") <> m.state.itemId then return

    applySeriesDetails(response.series)
    applyEpisodeDetails(response.payload, shouldKeepRequestPoster(response.payload))
    m.cast.people = getPeople(response.payload)
end sub

'-------------------------------------------------------------------------------
' renderInitialEpisodeContent
'-------------------------------------------------------------------------------
sub renderInitialEpisodeContent()
    request = m.state.request
    if request = invalid or request.item = invalid then return

    applyEpisodeDetails(request.item, true)
end sub

'-------------------------------------------------------------------------------
' applySeriesDetails
'-------------------------------------------------------------------------------
sub applySeriesDetails(series as dynamic)
    if series = invalid then return
    if m.state.request = invalid then return

    m.state.request.series = series
    renderLogoBanner()
end sub

'-------------------------------------------------------------------------------
' applyEpisodeDetails
'-------------------------------------------------------------------------------
sub applyEpisodeDetails(details as dynamic, useRequestPoster as boolean)
    if details = invalid then return

    item = buildEpisodeContentNode(details, useRequestPoster)
    m.state.itemContent = item
    m.state.playSelection = buildPlaySelection(details)
    renderEpisodeContent(item)
end sub

'-------------------------------------------------------------------------------
' buildEpisodeContentNode
'-------------------------------------------------------------------------------
function buildEpisodeContentNode(details as dynamic, useRequestPoster as boolean) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = FirstNonEmpty([details.Name], "")
    content.description = FirstNonEmpty([details.Overview], "")
    content.HDPosterUrl = getEpisodePosterUrl(details, useRequestPoster)
    content.AddFields({
        itemId: SafeString(FirstNonEmpty([details.Id], ""), "")
        itemType: SafeString(FirstNonEmpty([details.Type], ""), "")
        episodeNumber: getEpisodeNumberText(details)
        episodeDate: getEpisodeDateText(details)
        progressPercent: getProgressPercent(details)
        progressWidth: getProgressWidth(details)
        raw: details
    })

    return content
end function

'-------------------------------------------------------------------------------
' buildPlaySelection
'-------------------------------------------------------------------------------
function buildPlaySelection(details as dynamic) as dynamic
    request = m.state.request
    if request = invalid then return invalid

    itemId = SafeString(FirstNonEmpty([details.Id, request.itemId], ""), "")
    if itemId = "" then return invalid

    startPositionTicks = PlaybackProgress_GetTicksFromItem(details)
    if request.startPositionTicks <> invalid then startPositionTicks = request.startPositionTicks

    return {
        itemId: itemId
        item: details
        startPositionTicks: startPositionTicks
        playbackQueue: request.playbackQueue
        playbackQueueIndex: request.playbackQueueIndex
    }
end function

'-------------------------------------------------------------------------------
' getEpisodePosterUrl
'-------------------------------------------------------------------------------
function getEpisodePosterUrl(item as dynamic, useRequestPoster as boolean) as string
    if useRequestPoster then
        requestPosterUrl = getRequestPosterUrl(item)
        if requestPosterUrl <> "" then return requestPosterUrl
    end if

    itemId = FirstNonEmpty([item.Id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" and primaryTag <> "" then return buildImageUrl(itemId, "Primary", primaryTag, 619, 348)

    parentThumbId = FirstNonEmpty([item.ParentThumbItemId], "")
    parentThumbTag = FirstNonEmpty([item.ParentThumbImageTag], "")
    if parentThumbId <> "" and parentThumbTag <> "" then return buildImageUrl(parentThumbId, "Thumb", parentThumbTag, 619, 348)

    seriesId = FirstNonEmpty([item.SeriesId], "")
    seriesTag = FirstNonEmpty([item.SeriesPrimaryImageTag], "")
    if seriesId <> "" and seriesTag <> "" then return buildImageUrl(seriesId, "Primary", seriesTag, 619, 348)

    return ""
end function

'-------------------------------------------------------------------------------
' getRequestPosterUrl
'-------------------------------------------------------------------------------
function getRequestPosterUrl(item as dynamic) as string
    request = m.state.request
    if request = invalid then return ""

    requestItemId = FirstNonEmpty([request.itemId], "")
    itemId = FirstNonEmpty([item.Id], "")
    if requestItemId = "" or itemId = "" or requestItemId <> itemId then return ""

    return FirstNonEmpty([request.posterUrl], "")
end function

'-------------------------------------------------------------------------------
' shouldKeepRequestPoster
'-------------------------------------------------------------------------------
function shouldKeepRequestPoster(item as dynamic) as boolean
    return getRequestPosterUrl(item) <> ""
end function

'-------------------------------------------------------------------------------
' getEpisodeNumberText
'-------------------------------------------------------------------------------
function getEpisodeNumberText(item as dynamic) as string
    indexText = FirstNonEmpty([item.IndexNumber], "")
    if indexText <> "" then return "Episode " + SafeString(indexText, "")
    return "Episode"
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
' getAiredDateText
'-------------------------------------------------------------------------------
function getAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.PremiereDate, item.AirDate, item.DateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

'-------------------------------------------------------------------------------
' getProgressPercent
'-------------------------------------------------------------------------------
function getProgressPercent(item as dynamic) as float
    if item.UserData <> invalid and item.UserData.Played = true then return 0

    if item.UserData <> invalid and item.UserData.PlayedPercentage <> invalid then
        playedPercentage = item.UserData.PlayedPercentage
        if playedPercentage <= 0 then return 0
        if playedPercentage > 100 then return 100
        return playedPercentage
    end if

    if item.RunTimeTicks = invalid or item.RunTimeTicks <= 0 then return 0

    progressTicks = PlaybackProgress_GetTicksFromItem(item)
    if progressTicks <= 0 then return 0

    progressPercent = (progressTicks / item.RunTimeTicks) * 100
    if progressPercent > 100 then return 100

    return progressPercent
end function

'-------------------------------------------------------------------------------
' getProgressWidth
'-------------------------------------------------------------------------------
function getProgressWidth(item as dynamic) as integer
    progressPercent = getProgressPercent(item)
    if progressPercent <= 0 then return 0

    progressWidth = int(510 * (progressPercent / 100))
    if progressWidth < 1 then return 1
    if progressWidth > 510 then return 510

    return progressWidth
end function

'-------------------------------------------------------------------------------
' clearContent
'-------------------------------------------------------------------------------
sub clearContent()
    m.secondaryMetadata.text = ""
    m.title.text = ""
    m.title.visible = true
    m.description.text = ""
    m.description.translation = [m.layout.descriptionX, m.layout.descriptionY]
    m.episodePoster.itemContent = invalid
    m.mediaToolbar.supportsWatchedActions = false
    m.mediaToolbar.isWatched = false
    m.state.itemContent = invalid
    m.state.playSelection = invalid
    m.cast.people = []
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    if m.state.focusArea = "cast" and m.cast.visible = true and m.cast.hasItems = true then
        m.cast.callFunc("activate")
    else
        focusMediaToolbar()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.cast.callFunc("deactivate")
    m.top.setFocus(false)
end sub

'-------------------------------------------------------------------------------
' resetFocus
'-------------------------------------------------------------------------------
sub resetFocus()
    m.state.focusArea = "toolbar"
    m.mediaToolbar.callFunc("resetFocus")
end sub

'-------------------------------------------------------------------------------
' focusMediaToolbar
'-------------------------------------------------------------------------------
sub focusMediaToolbar()
    m.state.focusArea = "toolbar"
    m.mediaToolbar.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarFocusExitDown
'-------------------------------------------------------------------------------
sub onMediaToolbarFocusExitDown()
    m.mediaToolbar.callFunc("deactivate")
    m.state.focusArea = "cast"
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' onMediaToolbarPlaySelected
'-------------------------------------------------------------------------------
sub onMediaToolbarPlaySelected()
    if m.state.playSelection = invalid then return
    m.top.selectedEpisode = m.state.playSelection
end sub

'-------------------------------------------------------------------------------
' onMarkAsWatchedSelected
'-------------------------------------------------------------------------------
sub onMarkAsWatchedSelected()
    runWatchedTask("MarkAsWatched")
end sub

'-------------------------------------------------------------------------------
' onMarkAsUnwatchedSelected
'-------------------------------------------------------------------------------
sub onMarkAsUnwatchedSelected()
    runWatchedTask("MarkAsUnwatched")
end sub

'-------------------------------------------------------------------------------
' runWatchedTask
'-------------------------------------------------------------------------------
sub runWatchedTask(action as string)
    item = m.state.itemContent
    request = m.state.request
    if item = invalid or request = invalid then return
    if canMarkWatched(item) <> true then return

    itemId = SafeString(item.itemId, "")
    if itemId = "" then return

    m.watchedTask.request = {
        action: action
        server: request.server
        token: request.token
        userId: request.userId
        itemId: itemId
    }
    m.watchedTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onWatchedTaskResponse
'-------------------------------------------------------------------------------
sub onWatchedTaskResponse()
    response = m.watchedTask.response
    if response = invalid then return

    if response.ok <> true then
        Status_SetMessage(SafeString(response.errorMessage, "Unable to update watched state."))
        return
    end if

    item = m.state.itemContent
    if item = invalid then return

    itemId = SafeString(response.itemId, "")
    if itemId = "" or itemId <> SafeString(item.itemId, "") then return

    isWatched = SafeString(response.action, "") = "MarkAsWatched"
    updateItemWatchedState(item, isWatched)
    refreshPoster()
    m.mediaToolbar.isWatched = isWatched
    m.mediaToolbar.callFunc("focusWatchedAction")
    m.top.watchedStateChanged = {
        itemId: itemId
        isWatched: isWatched
    }
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusMediaToolbar()
end sub

'-------------------------------------------------------------------------------
' onCastPersonSelected
'-------------------------------------------------------------------------------
sub onCastPersonSelected()
    selection = m.cast.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    m.state.focusArea = "cast"
    m.top.selectedPerson = selection
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" or key = "back" then
        m.top.closeRequested = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' getPeople
'-------------------------------------------------------------------------------
function getPeople(item as dynamic) as object
    if item = invalid or item.People = invalid then return []
    return item.People
end function

'-------------------------------------------------------------------------------
' isItemWatched
'-------------------------------------------------------------------------------
function isItemWatched(item as dynamic) as boolean
    if item = invalid then return false
    if item.raw = invalid then return false
    if item.raw.UserData = invalid then return false
    if SafeString(item.itemType, "") = "SeasonSummary" then
        return item.raw.UserData.UnplayedItemCount = 0
    end if

    return item.raw.UserData.Played = true
end function

'-------------------------------------------------------------------------------
' canMarkWatched
'-------------------------------------------------------------------------------
function canMarkWatched(item as dynamic) as boolean
    if item = invalid then return false
    if SafeString(item.itemId, "") = "" then return false

    return true
end function

'-------------------------------------------------------------------------------
' updateItemWatchedState
'-------------------------------------------------------------------------------
sub updateItemWatchedState(item as dynamic, isWatched as boolean)
    if item = invalid or item.raw = invalid then return

    raw = item.raw
    if raw.UserData = invalid then raw.UserData = {}

    raw.UserData.Played = isWatched
    if SafeString(item.itemType, "") = "SeasonSummary" then
        if isWatched then
            raw.UserData.UnplayedItemCount = 0
        else
            raw.UserData.UnplayedItemCount = 1
        end if
    end if

    if isWatched then
        raw.UserData.PlayedPercentage = 0
        raw.UserData.PlaybackPositionTicks = 0
    else
        raw.UserData.PlayedPercentage = 0
    end if

    item.raw = raw
    m.state.itemContent = item
    if m.state.playSelection <> invalid then
        m.state.playSelection.item = raw
    end if
end sub

'-------------------------------------------------------------------------------
' refreshPoster
'-------------------------------------------------------------------------------
sub refreshPoster()
    m.episodePoster.callFunc("refresh")
end sub

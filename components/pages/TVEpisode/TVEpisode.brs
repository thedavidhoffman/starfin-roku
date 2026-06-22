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
        descriptionX: 666
        titleY: 288
        descriptionY: 342
    }
    m.episodeDetailsTask = m.top.findNode("episodeDetailsTask")
    m.watchedTask = m.top.findNode("watchedTask")
    m.state = {
        request: invalid
        itemId: ""
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
    if m.state.request <> invalid then
        m.cast.server = m.state.request.server
        renderLogoBanner()
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

    m.logoBanner.title = getSeriesTitle(request)
    m.logoBanner.logoUrl = getSeriesLogoUrl(request)
end sub

'-------------------------------------------------------------------------------
' clearLogoBanner
'-------------------------------------------------------------------------------
sub clearLogoBanner()
    m.logoBanner.title = ""
    m.logoBanner.logoUrl = ""
end sub

'-------------------------------------------------------------------------------
' getSeriesTitle
'-------------------------------------------------------------------------------
function getSeriesTitle(request as dynamic) as string
    if request = invalid then return ""
    if request.series <> invalid then return FirstNonEmpty([request.series.Name], "")

    return ""
end function

'-------------------------------------------------------------------------------
' getSeriesLogoUrl
'-------------------------------------------------------------------------------
function getSeriesLogoUrl(request as dynamic) as string
    if request = invalid or request.series = invalid then return ""

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
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
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
    loadItemDetails()
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
    item = m.top.itemContent
    request = m.state.request
    if item = invalid then return

    itemType = SafeString(item.itemType, "")
    if itemType = "SeasonSummary" then
        m.state.itemId = ""
        m.cast.people = getPeople(item.raw)
        return
    end if

    itemId = SafeString(item.itemId, "")
    if itemId = "" or request = invalid then
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

    m.cast.people = getPeople(response.payload)
end sub

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
    m.state.itemId = ""
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
    if m.top.playSelection = invalid then return
    m.top.selectedEpisode = m.top.playSelection
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
    item = m.top.itemContent
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

    item = m.top.itemContent
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
end sub

'-------------------------------------------------------------------------------
' refreshPoster
'-------------------------------------------------------------------------------
sub refreshPoster()
    m.episodePoster.callFunc("refresh")
end sub

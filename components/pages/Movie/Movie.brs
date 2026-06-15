'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Movie")
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.playButton = m.top.findNode("playButton")
    m.cast = m.top.findNode("cast")
    m.statusLabel = m.top.findNode("statusLabel")
    m.movieTask = m.top.findNode("movieTask")

    m.movieTask.observeField("response", "onMovieResponse")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.pageState = {
        request: invalid
        item: invalid
        focusArea: "play"
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.item = request.item
    m.cast.server = request.server
    setStatus("Loading movie...")
    renderMovie(request.item)

    m.movieTask.request = request
    m.movieTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onMovieResponse
'-------------------------------------------------------------------------------
sub onMovieResponse()
    response = m.movieTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load this movie."))
        return
    end if

    m.pageState.item = response.payload
    renderMovie(response.payload)
    setStatus("")
end sub

'-------------------------------------------------------------------------------
' renderMovie
'-------------------------------------------------------------------------------
sub renderMovie(item as dynamic)
    if isAssocArray(item) = false then return

    m.titleLabel.text = getItemTitle(item)
    m.metaLabel.text = getMetaText(item)
    m.overviewLabel.text = FirstNonEmpty([item.Overview, item.overview], "")
    m.cast.people = getPeople(item)

    posterUrl = getImageUrl(item, "Primary", 330, 495)
    m.poster.visible = posterUrl <> ""
    m.poster.uri = posterUrl

    backdropUrl = getBackdropUrl(item)
    m.backdrop.visible = backdropUrl <> ""
    m.backdrop.uri = backdropUrl
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    focusPlayButton()
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    focusPlayButton()
end sub

'-------------------------------------------------------------------------------
' focusPlayButton
'-------------------------------------------------------------------------------
sub focusPlayButton()
    m.pageState.focusArea = "play"
    m.playButton.hasFocusVisual = true
    m.cast.callFunc("deactivate")
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusCast
'-------------------------------------------------------------------------------
sub focusCast()
    if m.cast.visible <> true or m.cast.hasItems <> true then return

    m.pageState.focusArea = "cast"
    m.playButton.hasFocusVisual = false
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' playCurrentMovie
'-------------------------------------------------------------------------------
sub playCurrentMovie()
    item = m.pageState.item
    request = m.pageState.request
    if request = invalid or item = invalid then return

    itemId = SafeString(FirstNonEmpty([item.Id, item.id, request.itemId], ""), "")
    if itemId = "" then return

    m.top.playSelected = {
        itemId: itemId
        item: item
    }
end sub

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return "Movie"
    return FirstNonEmpty([item.Name, item.name, item.title], "Movie")
end function

'-------------------------------------------------------------------------------
' getMetaText
'-------------------------------------------------------------------------------
function getMetaText(item as dynamic) as string
    parts = []

    year = FirstNonEmpty([item.ProductionYear], "")
    if year = "" then year = getYearFromDate(FirstNonEmpty([item.PremiereDate], ""))
    if year <> "" then parts.Push(year)

    runtime = getRuntimeText(item.RunTimeTicks)
    if runtime <> "" then parts.Push(runtime)

    rating = FirstNonEmpty([item.OfficialRating], "")
    if rating <> "" then parts.Push(rating)

    genres = getGenreText(item)
    if genres <> "" then parts.Push(genres)

    communityRating = FirstNonEmpty([item.CommunityRating], "")
    if communityRating <> "" then parts.Push("Rating " + communityRating)

    return joinText(parts, "  |  ")
end function

'-------------------------------------------------------------------------------
' getRuntimeText
'-------------------------------------------------------------------------------
function getRuntimeText(runTimeTicks as dynamic) as string
    if runTimeTicks = invalid then return ""

    minutes = int(val(runTimeTicks.ToStr()) / 600000000)
    if minutes <= 0 then return ""

    hours = int(minutes / 60)
    remainingMinutes = minutes mod 60
    if hours > 0 then return hours.ToStr() + "h " + remainingMinutes.ToStr() + "m"
    return minutes.ToStr() + "m"
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
    if item.People = invalid then return []
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

    if key = "up" and m.cast.isInFocusChain() then
        focusPlayButton()
        return true
    end if

    if key = "down" and m.pageState.focusArea = "play" then
        focusCast()
        return true
    end if

    if (key = "OK" or key = "play") and m.pageState.focusArea = "play" then
        playCurrentMovie()
        return true
    end if

    return false
end function

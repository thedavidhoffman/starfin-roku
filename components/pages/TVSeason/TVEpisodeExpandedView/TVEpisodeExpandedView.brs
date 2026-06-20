'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.episodePoster = m.top.findNode("episodePoster")
    m.episodeNumber = m.top.findNode("episodeNumber")
    m.episodeDate = m.top.findNode("episodeDate")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.cast = m.top.findNode("cast")
    m.layout = {
        titleY: 38
        descriptionY: 92
    }
    initStyles()
    m.episodeDetailsTask = m.top.findNode("episodeDetailsTask")
    m.episodeDetailsTask.observeField("response", "onEpisodeDetailsResponse")
    m.cast.observeField("focusExitUp", "onCastFocusExitUp")
    m.cast.observeField("selectedPerson", "onCastPersonSelected")
    m.state = {
        request: invalid
        itemId: ""
    }
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
    colors = Color()
    m.episodeNumber.color = colors.text.secondary
    m.episodeDate.color = colors.text.secondary
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    m.state.request = m.top.loadRequest
    m.state.itemId = ""
    if m.state.request <> invalid then m.cast.server = m.state.request.server
    loadItemDetails()
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then
        clearContent()
        return
    end if

    title = SafeString(item.title, "")
    m.title.text = title
    m.description.text = SafeString(item.description, "")
    m.episodeNumber.text = SafeString(item.episodeNumber, "")
    m.episodeDate.text = SafeString(item.episodeDate, "")
    applyLayout(title)

    m.episodePoster.itemContent = item
    loadItemDetails()
end sub

'-------------------------------------------------------------------------------
' applyLayout
'-------------------------------------------------------------------------------
sub applyLayout(title as string)
    hideTitle = isSeasonNumberTitle(title)
    m.title.visible = hideTitle <> true
    if hideTitle = true then
        m.description.translation = [590, m.layout.titleY]
    else
        m.description.translation = [590, m.layout.descriptionY]
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
    m.episodeNumber.text = ""
    m.episodeDate.text = ""
    m.title.text = ""
    m.title.visible = true
    m.description.text = ""
    m.description.translation = [590, m.layout.descriptionY]
    m.episodePoster.itemContent = invalid
    m.state.itemId = ""
    m.cast.people = []
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    m.cast.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.cast.callFunc("deactivate")
    m.top.setFocus(false)
end sub

'-------------------------------------------------------------------------------
' onCastFocusExitUp
'-------------------------------------------------------------------------------
sub onCastFocusExitUp()
    m.top.closeRequested = true
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
' getEpisodeDurationText
'-------------------------------------------------------------------------------
function getEpisodeDurationText(item as dynamic) as string
    if item = invalid then return ""
    if item.RunTimeTicks = invalid then return ""

    minutes = int(val(item.RunTimeTicks.ToStr()) / 600000000)
    if minutes <= 0 then return ""

    hours = int(minutes / 60)
    remainingMinutes = minutes mod 60
    if hours > 0 and remainingMinutes > 0 then return hours.ToStr() + " hr " + remainingMinutes.ToStr() + " min"
    if hours > 0 then return hours.ToStr() + " hr"

    return minutes.ToStr() + " min"
end function

'-------------------------------------------------------------------------------
' getEpisodeRatingText
'-------------------------------------------------------------------------------
function getEpisodeRatingText(item as dynamic) as string
    if item = invalid then return ""
    if item.CommunityRating = invalid then return ""

    rating = val(item.CommunityRating.ToStr())
    if rating <= 0 then return ""

    rounded = int((rating * 10) + 0.5)
    whole = int(rounded / 10)
    decimal = rounded mod 10

    return whole.ToStr() + "." + decimal.ToStr()
end function

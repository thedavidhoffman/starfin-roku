'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.cast = m.top.findNode("cast")
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

    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
    loadItemDetails()
end sub

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
    m.title.text = ""
    m.description.text = ""
    m.poster.uri = ""
    m.poster.visible = false
    m.placeholder.visible = true
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

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Person")
    m.backdrop = m.top.findNode("backdrop")
    m.personImage = m.top.findNode("personImage")
    m.nameLabel = m.top.findNode("nameLabel")
    m.lifeLabel = m.top.findNode("lifeLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.relatedTitleLabel = m.top.findNode("relatedTitleLabel")
    m.relatedRows = m.top.findNode("relatedRows")
    m.personTask = m.top.findNode("personTask")

    m.personTask.observeField("response", "onPersonResponse")
    m.relatedRows.observeField("rowItemSelected", "onRelatedItemSelected")

    m.pageState = {
        request: invalid
        person: invalid
        focusArea: "person"
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.pageState.person = request.item
    clearRelated()
    setStatus("Loading person...")
    renderPerson(request.item)

    m.personTask.request = request
    m.personTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onPersonResponse
'-------------------------------------------------------------------------------
sub onPersonResponse()
    response = m.personTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load this person."))
        return
    end if

    person = response.payload.person
    m.pageState.person = person
    renderPerson(person)
    renderRelated(getItemsFromPayload(response.payload.items))
    setStatus("")
end sub

'-------------------------------------------------------------------------------
' renderPerson
'-------------------------------------------------------------------------------
sub renderPerson(person as dynamic)
    if isAssocArray(person) = false then return

    m.nameLabel.text = getPersonName(person)
    m.lifeLabel.text = getLifeText(person)
    m.overviewLabel.text = FirstNonEmpty([person.Overview, person.overview], "Biographical information for this person is not currently available.")

    imageUrl = getPersonImageUrl(person, 300, 450)
    m.personImage.visible = imageUrl <> ""
    m.personImage.uri = imageUrl

    backdropUrl = getBackdropUrl(person)
    m.backdrop.visible = backdropUrl <> ""
    m.backdrop.uri = backdropUrl
    m.relatedTitleLabel.text = "More with " + getPersonName(person)
end sub

'-------------------------------------------------------------------------------
' renderRelated
'-------------------------------------------------------------------------------
sub renderRelated(items as object)
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")

    for each item in items
        if isAssocArray(item) = false then continue for

        itemId = SafeString(FirstNonEmpty([item.Id, item.id], ""), "")
        itemType = SafeString(FirstNonEmpty([item.Type, item.type], ""), "")
        if itemId = "" then continue for

        child = row.createChild("ContentNode")
        child.title = getItemTitle(item)
        child.description = getItemSubtitle(item)
        child.HDPosterUrl = getItemImageUrl(item)
        child.AddFields({
            itemId: itemId
            itemType: itemType
            imageAspect: "poster"
            raw: item
        })
    end for

    m.relatedRows.content = content
    m.relatedRows.visible = row.getChildCount() > 0
    m.relatedTitleLabel.visible = row.getChildCount() > 0
end sub

'-------------------------------------------------------------------------------
' clearRelated
'-------------------------------------------------------------------------------
sub clearRelated()
    m.relatedRows.content = CreateObject("roSGNode", "ContentNode")
    m.relatedRows.visible = false
    m.relatedTitleLabel.visible = false
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.relatedRows.visible = true and m.pageState.focusArea = "related" then
        m.relatedRows.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' focusRelated
'-------------------------------------------------------------------------------
sub focusRelated()
    if m.relatedRows.visible <> true then return

    m.pageState.focusArea = "related"
    m.relatedRows.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusPerson
'-------------------------------------------------------------------------------
sub focusPerson()
    m.pageState.focusArea = "person"
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onRelatedItemSelected
'-------------------------------------------------------------------------------
sub onRelatedItemSelected()
    selected = m.relatedRows.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    if m.relatedRows.content = invalid then return

    row = m.relatedRows.content.getChild(selected[0])
    if row = invalid then return

    itemNode = row.getChild(selected[1])
    if itemNode = invalid then return

    selection = {
        itemId: SafeString(itemNode.itemId, "")
        item: itemNode.raw
    }
    if selection.itemId = "" then return

    itemType = LCase(SafeString(itemNode.itemType, ""))
    if itemType = "movie" or itemType = "video" then
        m.top.selectedMovie = selection
    else if itemType = "series" then
        m.top.selectedSeries = selection
    end if
end sub

'-------------------------------------------------------------------------------
' getPersonName
'-------------------------------------------------------------------------------
function getPersonName(person as dynamic) as string
    if isAssocArray(person) = false then return "Person"
    return FirstNonEmpty([person.Name, person.name, person.title], "Person")
end function

'-------------------------------------------------------------------------------
' getLifeText
'-------------------------------------------------------------------------------
function getLifeText(person as dynamic) as string
    parts = []
    birthText = formatDate(FirstNonEmpty([person.PremiereDate, person.BirthDate], ""))
    deathText = formatDate(FirstNonEmpty([person.EndDate, person.DeathDate], ""))

    if birthText <> "" then parts.Push("Born " + birthText)
    if deathText <> "" then parts.Push("Died " + deathText)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' formatDate
'-------------------------------------------------------------------------------
function formatDate(value as string) as string
    if value = "" then return ""

    date = CreateObject("roDateTime")
    date.FromISO8601String(value)
    return date.AsDateString("short-month-no-weekday")
end function

'-------------------------------------------------------------------------------
' getItemTitle
'-------------------------------------------------------------------------------
function getItemTitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""
    return FirstNonEmpty([item.Name, item.name, item.SeriesName, item.Type], "Untitled")
end function

'-------------------------------------------------------------------------------
' getItemSubtitle
'-------------------------------------------------------------------------------
function getItemSubtitle(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    year = FirstNonEmpty([item.ProductionYear], "")
    itemType = FirstNonEmpty([item.Type, item.type], "")
    if year <> "" and itemType <> "" then return year + "  " + itemType

    return FirstNonEmpty([year, itemType], "")
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if isAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items

    return []
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

    return ""
end function

'-------------------------------------------------------------------------------
' getPersonImageUrl
'-------------------------------------------------------------------------------
function getPersonImageUrl(person as dynamic, width as integer, height as integer) as string
    if isAssocArray(person) = false then return ""

    directUrl = FirstNonEmpty([person.ImageURL, person.imageURL, person.ImageUrl, person.imageUrl, person.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    itemId = FirstNonEmpty([person.Id, person.id], "")
    tag = FirstNonEmpty([person.PrimaryImageTag, person.primaryImageTag], "")
    if tag = "" and person.ImageTags <> invalid and person.ImageTags.Primary <> invalid then tag = person.ImageTags.Primary
    if itemId = "" then return ""

    return buildImageUrl(itemId, "Primary", tag, width, height)
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id, item.id], "")
    primaryTag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then primaryTag = item.ImageTags.Primary
    if itemId <> "" then return buildImageUrl(itemId, "Primary", primaryTag, 250, 375)

    return ""
end function

'-------------------------------------------------------------------------------
' buildImageUrl
'-------------------------------------------------------------------------------
function buildImageUrl(itemId as string, imageType as string, tag as string, width as integer, height as integer) as string
    request = m.pageState.request
    if request = invalid then return ""
    if itemId = "" then return ""

    url = NormalizeServerUrl(request.server) + "/Items/" + itemId + "/Images/" + imageType
    query = "?maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    if tag <> "" then query = "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    return url + query
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

    if key = "down" and m.pageState.focusArea = "person" then
        focusRelated()
        return true
    end if

    if key = "up" and m.relatedRows.isInFocusChain() then
        focusPerson()
        return true
    end if

    return false
end function

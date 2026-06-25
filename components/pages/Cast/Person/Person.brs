'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Person")
    m.bioGroup = m.top.findNode("bioGroup")
    m.personImage = m.top.findNode("personImage")
    m.nameLabel = m.top.findNode("nameLabel")
    m.lifeLabel = m.top.findNode("lifeLabel")
    m.birthPlaceLabel = m.top.findNode("birthPlaceLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.filmographyButton = m.top.findNode("filmographyButton")
    m.relatedGroup = m.top.findNode("relatedGroup")
    m.relatedTitleLabel = m.top.findNode("relatedTitleLabel")
    m.relatedRows = m.top.findNode("relatedRows")
    m.layoutAnimation = m.top.findNode("layoutAnimation")
    m.bioTranslation = m.top.findNode("bioTranslation")
    m.relatedRowsTranslation = m.top.findNode("relatedRowsTranslation")
    m.personTask = m.top.findNode("personTask")

    m.personTask.observeField("response", "onPersonResponse")
    m.relatedRows.observeField("rowItemSelected", "onRelatedItemSelected")

    m.pageState = {
        request: invalid
        person: invalid
        filmography: invalid
        focusArea: "person"
    }
    m.layout = {
        mode: "bio"
        bioDefault: [96, 92]
        bioRelatedFocused: [96, -166]
        rowsDefault: [76, 750]
        rowsRelatedFocused: [76, 492]
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
    m.pageState.filmography = invalid
    m.pageState.focusArea = "person"
    setLayoutMode("bio", false)
    clearRelated()
    Status_SetLoading()
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
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load this person."))
        return
    end if

    person = response.payload.person
    m.pageState.person = person
    renderPerson(person)
    renderRelated(getItemsFromPayload(response.payload.items))
    Status_ClearMessage()
end sub

'-------------------------------------------------------------------------------
' renderPerson
'-------------------------------------------------------------------------------
sub renderPerson(person as dynamic)
    if isAssocArray(person) = false then return

    m.nameLabel.text = getPersonName(person)
    m.lifeLabel.text = getLifeText(person)
    renderBirthPlace(person)
    m.overviewLabel.text = FirstNonEmpty([person.Overview], "Biographical information for this person is not currently available.")

    imageUrl = getPersonImageUrl(person, 400, 600)
    m.personImage.visible = imageUrl <> ""
    m.personImage.uri = imageUrl

    m.pageState.filmography = buildFilmographySelection(person, imageUrl)
    m.filmographyButton.visible = m.pageState.filmography <> invalid
    if m.filmographyButton.visible = true and m.pageState.focusArea <> "related" then
        focusFilmographyButton()
    else
        updateFocusVisual()
    end if
end sub

'-------------------------------------------------------------------------------
' renderBirthPlace
'-------------------------------------------------------------------------------
sub renderBirthPlace(person as dynamic)
    birthPlace = getBirthPlace(person)
    m.birthPlaceLabel.visible = birthPlace <> ""
    m.birthPlaceLabel.text = "Place of birth: " + birthPlace
end sub

'-------------------------------------------------------------------------------
' getBirthPlace
'-------------------------------------------------------------------------------
function getBirthPlace(person as dynamic) as string
    if isAssocArray(person) = false then return ""
    if person.ProductionLocations = invalid then return ""
    if person.ProductionLocations.Count() = 0 then return ""

    return SafeString(person.ProductionLocations[0], "")
end function

'-------------------------------------------------------------------------------
' renderRelated
'-------------------------------------------------------------------------------
sub renderRelated(items as object)
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")
    m.relatedTitleLabel.text = "More with " + getPersonName(m.pageState.person)

    for each item in items
        if isAssocArray(item) = false then continue for

        itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
        if itemId = "" then continue for

        child = row.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item)
        child.AddFields({
            imageAspect: "poster"
            raw: item
        })
    end for

    m.relatedRows.content = content
    hasItems = row.getChildCount() > 0
    m.relatedGroup.visible = hasItems
    m.relatedRows.visible = hasItems
end sub

'-------------------------------------------------------------------------------
' clearRelated
'-------------------------------------------------------------------------------
sub clearRelated()
    m.relatedRows.content = CreateObject("roSGNode", "ContentNode")
    m.relatedGroup.visible = false
    m.relatedRows.visible = false
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.relatedRows.visible = true and m.pageState.focusArea = "related" then
        setLayoutMode("related", false)
        m.relatedRows.setFocus(true)
    else if m.filmographyButton.visible = true then
        focusFilmographyButton()
    else
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' focusFilmographyButton
'-------------------------------------------------------------------------------
sub focusFilmographyButton()
    if m.filmographyButton.visible <> true then return

    m.pageState.focusArea = "filmography"
    setLayoutMode("bio", true)
    m.filmographyButton.hasFocusVisual = true
    m.filmographyButton.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusRelated
'-------------------------------------------------------------------------------
sub focusRelated()
    if m.relatedRows.visible <> true then return

    m.pageState.focusArea = "related"
    setLayoutMode("related", true)
    m.filmographyButton.hasFocusVisual = false
    m.relatedRows.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusPerson
'-------------------------------------------------------------------------------
sub focusPerson()
    if m.filmographyButton.visible = true then
        focusFilmographyButton()
    else
        m.pageState.focusArea = "person"
        setLayoutMode("bio", true)
        m.filmographyButton.hasFocusVisual = false
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' setLayoutMode
'-------------------------------------------------------------------------------
sub setLayoutMode(mode as string, animated as boolean)
    if mode <> "related" then mode = "bio"
    if m.layout.mode = mode and animated = true then return

    m.layout.mode = mode
    bioTarget = m.layout.bioDefault
    rowsTarget = m.layout.rowsDefault
    if mode = "related" then
        bioTarget = m.layout.bioRelatedFocused
        rowsTarget = m.layout.rowsRelatedFocused
    end if

    if animated = true then
        m.bioTranslation.keyValue = [m.bioGroup.translation, bioTarget]
        m.relatedRowsTranslation.keyValue = [m.relatedGroup.translation, rowsTarget]
        m.layoutAnimation.control = "start"
    else
        m.layoutAnimation.control = "stop"
        m.bioGroup.translation = bioTarget
        m.relatedGroup.translation = rowsTarget
    end if
end sub

'-------------------------------------------------------------------------------
' selectFilmography
'-------------------------------------------------------------------------------
sub selectFilmography()
    if m.pageState.filmography = invalid then return
    m.top.selectedFilmography = m.pageState.filmography
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

    item = itemNode.raw
    selection = {
        itemId: SafeString(FirstNonEmpty([item.Id], ""), "")
        item: item
    }
    if selection.itemId = "" then return

    itemType = LCase(SafeString(FirstNonEmpty([item.Type], ""), ""))
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
    return FirstNonEmpty([person.Name], "Person")
end function

'-------------------------------------------------------------------------------
' buildFilmographySelection
'-------------------------------------------------------------------------------
function buildFilmographySelection(person as dynamic, imageUrl as string) as dynamic
    tmdbId = getTmdbPersonId(person)
    if tmdbId = "" then return invalid

    return {
        personId: tmdbId
        name: getPersonName(person)
        imageUrl: imageUrl
    }
end function

'-------------------------------------------------------------------------------
' getTmdbPersonId
'-------------------------------------------------------------------------------
function getTmdbPersonId(person as dynamic) as string
    if isAssocArray(person) = false then return ""
    externalUrls = person.ExternalUrls
    if externalUrls = invalid then return ""

    for each externalUrl in externalUrls
        if isAssocArray(externalUrl) = false then continue for

        name = LCase(FirstNonEmpty([externalUrl.Name], ""))
        if name = "tmdb" then
            url = FirstNonEmpty([externalUrl.Url], "")
            return getTrailingUrlSegment(url)
        end if
    end for

    return ""
end function

'-------------------------------------------------------------------------------
' getTrailingUrlSegment
'-------------------------------------------------------------------------------
function getTrailingUrlSegment(url as string) as string
    if url = "" then return ""

    while Right(url, 1) = "/"
        url = Left(url, Len(url) - 1)
    end while

    slashIndex = 0
    for i = Len(url) to 1 step -1
        if Mid(url, i, 1) = "/" then
            slashIndex = i
            exit for
        end if
    end for

    if slashIndex = 0 then return url
    return Mid(url, slashIndex + 1)
end function

'-------------------------------------------------------------------------------
' getLifeText
'-------------------------------------------------------------------------------
function getLifeText(person as dynamic) as string
    parts = []
    birthDate = FirstNonEmpty([person.PremiereDate, person.BirthDate], "")
    deathDate = FirstNonEmpty([person.EndDate, person.DeathDate], "")
    birthText = formatDate(birthDate)
    deathText = formatDate(deathDate)
    ageText = getAgeText(birthDate, deathDate)

    if birthText <> "" then parts.Push("Born " + birthText)
    if deathText <> "" then parts.Push("Died " + deathText)
    if ageText <> "" then parts.Push(ageText)

    return joinText(parts, MediaMetadata_BulletSeparator())
end function

'-------------------------------------------------------------------------------
' getAgeText
'-------------------------------------------------------------------------------
function getAgeText(birthDate as string, deathDate as string) as string
    age = getAge(birthDate, deathDate)
    if age < 0 then return ""

    return "Age " + age.ToStr()
end function

'-------------------------------------------------------------------------------
' getAge
'-------------------------------------------------------------------------------
function getAge(birthDate as string, deathDate as string) as integer
    if Len(birthDate) < 10 then return -1

    birthYear = val(Left(birthDate, 4))
    birthMonth = val(Mid(birthDate, 6, 2))
    birthDay = val(Mid(birthDate, 9, 2))
    if birthYear <= 0 or birthMonth <= 0 or birthDay <= 0 then return -1

    endYear = 0
    endMonth = 0
    endDay = 0
    if Len(deathDate) >= 10 then
        endYear = val(Left(deathDate, 4))
        endMonth = val(Mid(deathDate, 6, 2))
        endDay = val(Mid(deathDate, 9, 2))
    else
        today = CreateObject("roDateTime")
        today.Mark()
        endYear = today.GetYear()
        endMonth = today.GetMonth()
        endDay = today.GetDayOfMonth()
    end if

    if endYear <= 0 or endMonth <= 0 or endDay <= 0 then return -1

    age = endYear - birthYear
    if endMonth < birthMonth or (endMonth = birthMonth and endDay < birthDay) then age = age - 1
    if age < 0 then return -1

    return age
end function

'-------------------------------------------------------------------------------
' formatDate
'-------------------------------------------------------------------------------
function formatDate(value as string) as string
    if value = "" then return ""

    date = CreateObject("roDateTime")
    date.FromISO8601String(value)
    monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    month = date.GetMonth()
    if month < 1 or month > 12 then return date.AsDateString("short-month-no-weekday")

    return monthNames[month - 1] + " " + date.GetDayOfMonth().ToStr() + ", " + date.GetYear().ToStr()
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
' getPersonImageUrl
'-------------------------------------------------------------------------------
function getPersonImageUrl(person as dynamic, width as integer, height as integer) as string
    if isAssocArray(person) = false then return ""

    directUrl = FirstNonEmpty([person.ImageURL, person.ImageUrl, person.PrimaryImageUrl], "")
    if directUrl <> "" then return directUrl

    itemId = FirstNonEmpty([person.Id], "")
    tag = FirstNonEmpty([person.PrimaryImageTag], "")
    if tag = "" and person.ImageTags <> invalid and person.ImageTags.Primary <> invalid then tag = person.ImageTags.Primary
    if itemId = "" then return ""

    return buildImageUrl(itemId, "Primary", tag, width, height)
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic) as string
    if isAssocArray(item) = false then return ""

    itemId = FirstNonEmpty([item.Id], "")
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
' updateFocusVisual
'-------------------------------------------------------------------------------
sub updateFocusVisual()
    hasFocusVisual = m.filmographyButton.visible = true and m.pageState.focusArea <> "related"
    m.filmographyButton.hasFocusVisual = hasFocusVisual
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

    if key = "OK" and (m.pageState.focusArea = "filmography" or (m.pageState.focusArea = "person" and m.filmographyButton.visible = true)) then
        selectFilmography()
        return true
    end if

    if key = "down" and (m.pageState.focusArea = "person" or m.pageState.focusArea = "filmography") then
        focusRelated()
        return true
    end if

    if key = "up" and m.relatedRows.isInFocusChain() then
        focusPerson()
        return true
    end if

    return false
end function

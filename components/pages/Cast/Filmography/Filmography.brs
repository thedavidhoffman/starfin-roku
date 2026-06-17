'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Filmography")
    m.personImage = m.top.findNode("personImage")
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.filmographyList = m.top.findNode("filmographyList")
    m.previewPoster = m.top.findNode("previewPoster")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.filmographyTask = m.top.findNode("filmographyTask")

    m.filmographyTask.observeField("response", "onFilmographyResponse")
    m.filmographyList.observeField("itemFocused", "onFilmographyItemFocused")
    m.pageState = {
        request: invalid
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    m.titleLabel.text = SafeString(request.name, "Filmography")
    m.personImage.uri = SafeString(request.imageUrl, "")
    m.personImage.visible = m.personImage.uri <> ""
    renderItems([])
    renderPreview(invalid)
    setStatus("Loading filmography...")

    m.filmographyTask.request = {
        personId: SafeString(request.personId, "")
    }
    m.filmographyTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onFilmographyResponse
'-------------------------------------------------------------------------------
sub onFilmographyResponse()
    response = m.filmographyTask.response
    if response = invalid then return

    if response.ok <> true then
        setStatus(SafeString(response.errorMessage, "Unable to load filmography."))
        return
    end if

    renderItems(response.payload)
    setStatus("")
    focusListIfActive()
end sub

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems(items as object)
    content = CreateObject("roSGNode", "ContentNode")

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.title = SafeString(item.title, "")
        child.AddFields({
            releaseDate: SafeString(item.release_date, "")
            character: SafeString(item.character, "")
            posterPath: SafeString(item.poster_path, "")
            overview: SafeString(item.overview, "")
            raw: item.raw
        })
    end for

    m.filmographyList.content = content
    m.filmographyList.visible = content.getChildCount() > 0
    if content.getChildCount() > 0 then renderPreview(content.getChild(0))
end sub

'-------------------------------------------------------------------------------
' onFilmographyItemFocused
'-------------------------------------------------------------------------------
sub onFilmographyItemFocused()
    if m.filmographyList.content = invalid then return

    focusedIndex = m.filmographyList.itemFocused
    if focusedIndex = invalid then return
    if focusedIndex < 0 or focusedIndex >= m.filmographyList.content.getChildCount() then return

    renderPreview(m.filmographyList.content.getChild(focusedIndex))
end sub

'-------------------------------------------------------------------------------
' renderPreview
'-------------------------------------------------------------------------------
sub renderPreview(item as dynamic)
    if item = invalid then
        m.previewPoster.uri = ""
        m.previewPoster.visible = false
        m.overviewLabel.text = ""
        return
    end if

    posterPath = SafeString(item.posterPath, "")
    if posterPath <> "" then
        m.previewPoster.uri = "https://image.tmdb.org/t/p/w342" + posterPath
        m.previewPoster.visible = true
    else
        m.previewPoster.uri = ""
        m.previewPoster.visible = false
    end if

    m.overviewLabel.text = SafeString(item.overview, "")
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    focusListIfActive()
end sub

'-------------------------------------------------------------------------------
' focusListIfActive
'-------------------------------------------------------------------------------
sub focusListIfActive()
    if m.filmographyList.visible <> true then return
    m.filmographyList.setFocus(true)
end sub

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

    return false
end function

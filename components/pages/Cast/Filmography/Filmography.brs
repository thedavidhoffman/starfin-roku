'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Filmography")
    m.titleLabel = m.top.findNode("titleLabel")
    m.filmographyList = m.top.findNode("filmographyList")
    m.previewBackground = m.top.findNode("previewBackground")
    m.previewPosterMask = m.top.findNode("previewPosterMask")
    m.previewPoster = m.top.findNode("previewPoster")
    m.movieTitleLabel = m.top.findNode("movieTitleLabel")
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
    renderItems([])
    renderPreview(invalid)
    Status_SetLoading()

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
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load filmography."))
        return
    end if

    renderItems(response.payload)
    Status_ClearMessage()
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
        m.previewBackground.visible = false
        m.previewPosterMask.visible = false
        m.previewPoster.uri = ""
        m.movieTitleLabel.text = ""
        m.overviewLabel.text = ""
        return
    end if

    m.previewBackground.visible = true
    m.movieTitleLabel.text = formatPreviewTitle(item)

    posterPath = SafeString(item.posterPath, "")
    if posterPath <> "" then
        m.previewPoster.uri = "https://image.tmdb.org/t/p/w342" + posterPath
        m.previewPosterMask.visible = true
    else
        m.previewPoster.uri = ""
        m.previewPosterMask.visible = false
    end if

    m.overviewLabel.text = SafeString(item.overview, "")
end sub

'-------------------------------------------------------------------------------
' formatPreviewTitle
'-------------------------------------------------------------------------------
function formatPreviewTitle(item as object) as string
    title = SafeString(item.title, "")
    year = releaseYear(SafeString(item.releaseDate, ""))
    if year = "" then return title

    return title + " (" + year + ")"
end function

'-------------------------------------------------------------------------------
' releaseYear
'-------------------------------------------------------------------------------
function releaseYear(releaseDate as string) as string
    if Len(releaseDate) < 4 then return ""

    return Left(releaseDate, 4)
end function

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

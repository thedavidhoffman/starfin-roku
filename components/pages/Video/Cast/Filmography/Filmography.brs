'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("Filmography")
    m.titleLabel = m.top.findNode("titleLabel")
    m.filmographyList = m.top.findNode("filmographyList")
    m.filmographyFocus = m.top.findNode("filmographyFocus")
    m.filmographyFocusAnimation = m.top.findNode("filmographyFocusAnimation")
    m.filmographyFocusTranslation = m.top.findNode("filmographyFocusTranslation")
    m.previewBackground = m.top.findNode("previewBackground")
    m.previewPosterMask = m.top.findNode("previewPosterMask")
    m.previewPoster = m.top.findNode("previewPoster")
    m.movieTitleLabel = m.top.findNode("movieTitleLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.filmographyTask = m.top.findNode("filmographyTask")

    m.filmographyTask.observeField("response", "onFilmographyResponse")
    m.pageState = {
        request: invalid
        items: []
        focusedIndex: 0
        scrollOffset: 0
        lifecycle: AsyncLifecycle_Create()
    }
    m.listLayout = {
        rowCount: 8
        rowStride: 104
        focusInsetY: 2
    }
    m.cards = [
        m.top.findNode("filmographyCard0")
        m.top.findNode("filmographyCard1")
        m.top.findNode("filmographyCard2")
        m.top.findNode("filmographyCard3")
        m.top.findNode("filmographyCard4")
        m.top.findNode("filmographyCard5")
        m.top.findNode("filmographyCard6")
        m.top.findNode("filmographyCard7")
    ]
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.pageState.request = request
    AsyncLifecycle_Begin(m.pageState.lifecycle, request.personId)
    m.pageState.items = []
    m.pageState.focusedIndex = 0
    m.pageState.scrollOffset = 0
    m.titleLabel.text = SafeString(request.name, "Filmography")
    renderItems([])
    renderPreview(invalid)
    Spinner_Show()

    m.filmographyTask.request = {
        personId: SafeString(request.personId, "")
        apiKey: SafeString(request.apiKey, "")
    }
    m.filmographyTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onFilmographyResponse
'-------------------------------------------------------------------------------
sub onFilmographyResponse()
    response = m.filmographyTask.response
    if response = invalid then return
    if AsyncLifecycle_IsCurrentResponse(m.pageState.lifecycle, response, "personId", "filmography") <> true then return

    if response.ok <> true then
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load filmography."))
        return
    end if

    renderItems(response.payload)
    Spinner_Hide()
    Status_ClearMessage()
    focusListIfActive()
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    AsyncLifecycle_Deactivate(m.pageState.lifecycle)
    m.filmographyTask.control = "stop"
end sub

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems(items as object)
    contentItems = []

    for each item in items
        if Array_IsAssocArray(item) = false then continue for

        child = CreateObject("roSGNode", "ContentNode")
        child.title = SafeString(item.title, "")
        child.AddFields({
            releaseDate: SafeString(item.release_date, "")
            character: SafeString(item.character, "")
            posterPath: SafeString(item.poster_path, "")
            overview: SafeString(item.overview, "")
            voteAverage: item.vote_average
            raw: item.raw
        })
        contentItems.Push(child)
    end for

    m.pageState.items = contentItems
    m.pageState.focusedIndex = 0
    m.pageState.scrollOffset = 0
    m.filmographyList.visible = contentItems.Count() > 0
    m.filmographyFocus.visible = contentItems.Count() > 0
    renderVisibleCards(false)

    if contentItems.Count() > 0 then
        renderPreview(contentItems[0])
    else
        renderPreview(invalid)
    end if
end sub

'-------------------------------------------------------------------------------
' moveFocus
'-------------------------------------------------------------------------------
function moveFocus(delta as integer) as boolean
    itemCount = m.pageState.items.Count()
    if itemCount = 0 then return false

    focusedIndex = m.pageState.focusedIndex + delta
    if focusedIndex < 0 then focusedIndex = 0
    if focusedIndex >= itemCount then focusedIndex = itemCount - 1
    if focusedIndex = m.pageState.focusedIndex then return true

    m.pageState.focusedIndex = focusedIndex
    updateScrollOffset()
    renderVisibleCards(true)
    renderPreview(m.pageState.items[focusedIndex])
    return true
end function

'-------------------------------------------------------------------------------
' updateScrollOffset
'-------------------------------------------------------------------------------
sub updateScrollOffset()
    if m.pageState.focusedIndex < m.pageState.scrollOffset then
        m.pageState.scrollOffset = m.pageState.focusedIndex
    else if m.pageState.focusedIndex >= m.pageState.scrollOffset + m.listLayout.rowCount then
        m.pageState.scrollOffset = m.pageState.focusedIndex - m.listLayout.rowCount + 1
    end if
end sub

'-------------------------------------------------------------------------------
' renderVisibleCards
'-------------------------------------------------------------------------------
sub renderVisibleCards(animated as boolean)
    for slot = 0 to m.cards.Count() - 1
        itemIndex = m.pageState.scrollOffset + slot
        card = m.cards[slot]

        if itemIndex < m.pageState.items.Count() then
            card.itemContent = m.pageState.items[itemIndex]
            card.itemHasFocus = itemIndex = m.pageState.focusedIndex
            card.visible = true
        else
            card.itemContent = invalid
            card.itemHasFocus = false
            card.visible = false
        end if
    end for

    focusedSlot = m.pageState.focusedIndex - m.pageState.scrollOffset
    updateFocusHighlight(focusedSlot, animated)
end sub

'-------------------------------------------------------------------------------
' updateFocusHighlight
'-------------------------------------------------------------------------------
sub updateFocusHighlight(focusedSlot as integer, animated as boolean)
    targetTranslation = [0, (focusedSlot * m.listLayout.rowStride) + m.listLayout.focusInsetY]

    if animated = true then
        m.filmographyFocusTranslation.keyValue = [m.filmographyFocus.translation, targetTranslation]
        m.filmographyFocusAnimation.control = "start"
    else
        m.filmographyFocusAnimation.control = "stop"
        m.filmographyFocus.translation = targetTranslation
    end if
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
    year = DateTime_ToYear(item.releaseDate)
    if year = "" then return title

    return title + " (" + year + ")"
end function

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    AsyncLifecycle_BeginFromField(m.pageState.lifecycle, m.pageState.request, "personId")
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
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" then return moveFocus(-1)
    if key = "down" then return moveFocus(1)
    if key = "left" then return moveFocus(-10)
    if key = "right" then return moveFocus(10)

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    return false
end function

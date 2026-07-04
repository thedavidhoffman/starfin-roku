'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.keyboard.keyGrid.keyDefinitionUri = "pkg:/components/pages/Search/search-keyboard-kdf.json"
    m.searchButton = m.top.findNode("searchButton")
    m.helpLabel = m.top.findNode("helpLabel")
    m.resultsGroup = m.top.findNode("resultsGroup")
    m.searchTask = m.top.findNode("searchTask")

    m.keyboard.observeField("text", "onKeyboardTextChanged")
    m.searchButton.observeField("buttonSelected", "onSearchButtonSelected")
    m.searchTask.observeField("response", "onSearchResponse")

    m.searchState = {
        request: invalid
        query: ""
        submittedQuery: ""
        minimumQueryLength: 3
        rowNodes: []
        focusedRowIndex: 0
        resultsOffsetY: 0
    }
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    m.searchState.request = m.top.loadRequest
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.top.setFocus(true)
    if hasRows() and m.searchState.focusedRowIndex >= 0 then
        focusRow(m.searchState.focusedRowIndex)
    else
        focusKeyboard()
    end if
end sub

'-------------------------------------------------------------------------------
' focusKeyboard
'-------------------------------------------------------------------------------
sub focusKeyboard()
    m.searchState.focusedRowIndex = -1
    m.searchButton.hasFocusVisual = false
    m.keyboard.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' focusSearchButton
'-------------------------------------------------------------------------------
sub focusSearchButton()
    m.searchState.focusedRowIndex = -1
    m.searchButton.hasFocusVisual = true
    m.searchButton.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onKeyboardTextChanged
'-------------------------------------------------------------------------------
sub onKeyboardTextChanged()
    query = String_Trim(SafeString(m.keyboard.text, ""))
    if query = m.searchState.query then return

    m.searchState.query = query
    m.searchState.submittedQuery = ""
    m.searchTask.control = "stop"
    Spinner_Hide()

    if Len(query) < m.searchState.minimumQueryLength then
        Status_ClearMessage()
        clearRows()
        m.helpLabel.visible = true
    else
        Status_ClearMessage()
    end if
end sub

'-------------------------------------------------------------------------------
' onSearchButtonSelected
'-------------------------------------------------------------------------------
sub onSearchButtonSelected()
    runSearch()
end sub

'-------------------------------------------------------------------------------
' runSearch
'-------------------------------------------------------------------------------
sub runSearch()
    query = String_Trim(SafeString(m.keyboard.text, ""))
    m.searchState.query = query
    m.searchTask.control = "stop"

    if Len(query) < m.searchState.minimumQueryLength then
        m.searchState.submittedQuery = ""
        Spinner_Hide()
        clearRows()
        Status_SetMessage("Enter at least 3 characters.")
        focusSearchButton()
        return
    end if

    request = cloneRequest(m.searchState.request)
    if request = invalid then return

    request.query = query
    m.searchState.submittedQuery = query
    Spinner_Show(0)
    Status_ClearMessage()
    m.searchTask.request = request
    m.searchTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onSearchResponse
'-------------------------------------------------------------------------------
sub onSearchResponse()
    response = m.searchTask.response
    if response = invalid then return
    if SafeString(response.query, "") <> m.searchState.submittedQuery then return

    Spinner_Hide()

    if response.ok <> true then
        clearRows()
        Status_SetMessage(SafeString(response.errorMessage, "Search failed."))
        return
    end if

    Status_ClearMessage()
    renderRows(response.payload)
end sub

'-------------------------------------------------------------------------------
' renderRows
'-------------------------------------------------------------------------------
sub renderRows(payload as dynamic)
    clearRows()
    if payload = invalid then return

    y = 0
    rowIndex = 0
    rowIndex = addSearchRow(rowIndex, y, "Movies & TV Shows", payload.moviesAndSeries, getPosterLayout())
    y = getRowsHeight()
    rowIndex = addSearchRow(rowIndex, y, "Episodes", payload.episodes, getWideLayout())
    y = getRowsHeight()
    rowIndex = addSearchRow(rowIndex, y, "People", payload.people, getPosterLayout())

    m.helpLabel.visible = hasRows() <> true
    if hasRows() then
        focusRow(0)
    else
        focusKeyboard()
    end if
end sub

'-------------------------------------------------------------------------------
' addSearchRow
'-------------------------------------------------------------------------------
function addSearchRow(rowIndex as integer, y as integer, title as string, items as dynamic, layout as object) as integer
    content = buildRowContent(title, items, layout.imageAspect)
    if content.getChildCount() = 0 then return rowIndex

    shelf = CreateObject("roSGNode", "HomeShelf")
    shelf.rowIndex = rowIndex
    shelf.layout = layout
    shelf.rowContent = content
    shelf.translation = [0, y]
    shelf.canFocusExitUp = rowIndex > 0
    shelf.canFocusExitDown = false
    shelf.observeField("selectedItem", "onSearchShelfSelected")
    shelf.observeField("focusExitUp", "onShelfFocusExitUp")
    shelf.observeField("focusExitDown", "onShelfFocusExitDown")

    m.resultsGroup.appendChild(shelf)
    m.searchState.rowNodes.Push(shelf)
    syncRowFocusExit()
    return rowIndex + 1
end function

'-------------------------------------------------------------------------------
' buildRowContent
'-------------------------------------------------------------------------------
function buildRowContent(title as string, items as dynamic, imageAspect as string) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.title = title

    if items = invalid then return content

    for each item in items
        if isAssocArray(item) = false then continue for

        child = content.createChild("ContentNode")
        child.HDPosterUrl = getItemImageUrl(item, imageAspect)
        child.AddFields({
            imageAspect: imageAspect
            showSubtitle: true
            raw: item
        })
    end for

    return content
end function

'-------------------------------------------------------------------------------
' onSearchShelfSelected
'-------------------------------------------------------------------------------
sub onSearchShelfSelected(event as object)
    selection = event.getData()
    if selection = invalid then return

    item = selection.item
    if item = invalid then return

    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if itemId = "" then return

    itemType = LCase(SafeString(FirstNonEmpty([item.Type], ""), ""))
    if itemType = "movie" or itemType = "video" then
        m.top.selectedMovie = { itemId: itemId, item: item }
    else if itemType = "series" then
        m.top.selectedSeries = { itemId: itemId, item: item }
    else if itemType = "episode" then
        m.top.selectedEpisode = { itemId: itemId, item: item }
    else if itemType = "person" then
        m.top.selectedPerson = { itemId: itemId, item: item }
    end if
end sub

'-------------------------------------------------------------------------------
' onShelfFocusExitUp
'-------------------------------------------------------------------------------
sub onShelfFocusExitUp()
    moveRowFocus(-1)
end sub

'-------------------------------------------------------------------------------
' onShelfFocusExitDown
'-------------------------------------------------------------------------------
sub onShelfFocusExitDown()
    moveRowFocus(1)
end sub

'-------------------------------------------------------------------------------
' moveRowFocus
'-------------------------------------------------------------------------------
function moveRowFocus(delta as integer) as boolean
    targetIndex = m.searchState.focusedRowIndex + delta
    if targetIndex < 0 or targetIndex >= m.searchState.rowNodes.Count() then return false

    focusRow(targetIndex)
    return true
end function

'-------------------------------------------------------------------------------
' focusRow
'-------------------------------------------------------------------------------
function focusRow(index as integer) as boolean
    if m.searchState.rowNodes.Count() = 0 then return false
    if index < 0 then index = 0
    if index >= m.searchState.rowNodes.Count() then index = m.searchState.rowNodes.Count() - 1

    m.searchState.focusedRowIndex = index
    m.searchButton.hasFocusVisual = false
    updateResultsScroll(index)
    row = m.searchState.rowNodes[index]
    if row = invalid then return false

    row.callFunc("activate")
    return true
end function

'-------------------------------------------------------------------------------
' clearRows
'-------------------------------------------------------------------------------
sub clearRows()
    childCount = m.resultsGroup.getChildCount()
    if childCount > 0 then m.resultsGroup.removeChildrenIndex(childCount, 0)

    m.searchState.rowNodes = []
    m.searchState.focusedRowIndex = -1
    m.searchState.resultsOffsetY = 0
    m.resultsGroup.translation = [0, 0]
end sub

'-------------------------------------------------------------------------------
' syncRowFocusExit
'-------------------------------------------------------------------------------
sub syncRowFocusExit()
    for i = 0 to m.searchState.rowNodes.Count() - 1
        row = m.searchState.rowNodes[i]
        if row <> invalid then
            row.canFocusExitUp = i > 0
            row.canFocusExitDown = i < m.searchState.rowNodes.Count() - 1
        end if
    end for
end sub

'-------------------------------------------------------------------------------
' hasRows
'-------------------------------------------------------------------------------
function hasRows() as boolean
    return m.searchState <> invalid and m.searchState.rowNodes <> invalid and m.searchState.rowNodes.Count() > 0
end function

'-------------------------------------------------------------------------------
' getRowsHeight
'-------------------------------------------------------------------------------
function getRowsHeight() as integer
    height = 0
    for each row in m.searchState.rowNodes
        if row = invalid then continue for
        layout = row.layout
        if layout <> invalid then height = height + 50 + layout.height + layout.spacingAfter
    end for

    return height
end function

'-------------------------------------------------------------------------------
' updateResultsScroll
'-------------------------------------------------------------------------------
sub updateResultsScroll(index as integer)
    top = getRowTop(index)
    targetOffsetY = 0 - top

    if targetOffsetY = m.searchState.resultsOffsetY then return

    m.searchState.resultsOffsetY = targetOffsetY
    m.resultsGroup.translation = [0, targetOffsetY]
end sub

'-------------------------------------------------------------------------------
' getRowTop
'-------------------------------------------------------------------------------
function getRowTop(index as integer) as integer
    top = 0
    if index <= 0 then return top

    lastIndex = index - 1
    for i = 0 to lastIndex
        row = m.searchState.rowNodes[i]
        if row = invalid then continue for
        layout = row.layout
        if layout <> invalid then top = top + 50 + layout.height + layout.spacingAfter
    end for

    return top
end function

'-------------------------------------------------------------------------------
' getPosterLayout
'-------------------------------------------------------------------------------
function getPosterLayout() as object
    return { width: 295, height: 463, itemSizeWidth: 1450, itemSpacing: -11, spacingAfter: 37, imageAspect: "poster", focusBitmapUri: "pkg:/images/homepage/home-page-poster-focus-295x463.png" }
end function

'-------------------------------------------------------------------------------
' getWideLayout
'-------------------------------------------------------------------------------
function getWideLayout() as object
    return { width: 485, height: 348, itemSizeWidth: 1450, itemSpacing: -27, spacingAfter: 37, imageAspect: "wide", focusBitmapUri: "pkg:/images/homepage/home-page-thumbnail-focus-485x348.png" }
end function

'-------------------------------------------------------------------------------
' getItemImageUrl
'-------------------------------------------------------------------------------
function getItemImageUrl(item as dynamic, imageAspect as string) as string
    if isAssocArray(item) = false then return ""

    itemId = SafeString(FirstNonEmpty([item.Id], ""), "")
    if itemId = "" then return ""

    if imageAspect = "wide" then
        imageUrl = getImageUrlForType(itemId, item, "Thumb", 440, 248)
        if imageUrl <> "" then return imageUrl

        imageUrl = getImageUrlForType(itemId, item, "Backdrop", 440, 248)
        if imageUrl <> "" then return imageUrl

        return getImageUrlForType(itemId, item, "Primary", 440, 248)
    end if

    return getImageUrlForType(itemId, item, "Primary", 250, 375)
end function

'-------------------------------------------------------------------------------
' getImageUrlForType
'-------------------------------------------------------------------------------
function getImageUrlForType(itemId as string, item as dynamic, imageType as string, width as integer, height as integer) as string
    tag = getImageTag(item, imageType)
    if tag = "" then return ""

    request = m.searchState.request
    if request = invalid then return ""

    return Url_BuildImageUrl(request.server, itemId, imageType, tag, width, height)
end function

'-------------------------------------------------------------------------------
' getImageTag
'-------------------------------------------------------------------------------
function getImageTag(item as dynamic, imageType as string) as string
    if item = invalid then return ""

    if imageType = "Backdrop" then
        if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0 then return item.BackdropImageTags[0]
        return ""
    end if

    if item.ImageTags = invalid then return ""
    if imageType = "Primary" and item.ImageTags.Primary <> invalid then return item.ImageTags.Primary
    if imageType = "Thumb" and item.ImageTags.Thumb <> invalid then return item.ImageTags.Thumb

    return ""
end function

'-------------------------------------------------------------------------------
' cloneRequest
'-------------------------------------------------------------------------------
function cloneRequest(request as dynamic) as dynamic
    if request = invalid then return invalid

    clone = {}
    for each key in request
        clone[key] = request[key]
    end for

    return clone
end function

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

    if key = "up" then
        if m.searchButton.isInFocusChain() then
            focusKeyboard()
            return true
        end if
        if hasRows() and m.searchState.focusedRowIndex >= 0 then return moveRowFocus(-1)
        m.top.focusExitUp = true
        return true
    end if

    if key = "down" and m.keyboard.isInFocusChain() then
        focusSearchButton()
        return true
    end if

    if key = "down" and hasRows() and m.searchState.focusedRowIndex >= 0 then
        return moveRowFocus(1)
    end if

    if key = "left" and hasRows() and m.searchState.focusedRowIndex >= 0 then
        focusKeyboard()
        return true
    end if

    if key = "right" and hasRows() and m.keyboard.isInFocusChain() then
        return focusRow(0)
    end if

    if key = "right" and hasRows() and m.searchButton.isInFocusChain() then
        return focusRow(0)
    end if

    if (key = "OK" or key = "select") and m.searchButton.isInFocusChain() then
        runSearch()
        return true
    end if

    if key = "back" then
        m.top.closeRequested = true
        return true
    end if

    return false
end function

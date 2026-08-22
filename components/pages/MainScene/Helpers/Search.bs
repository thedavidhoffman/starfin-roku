'===============================================================================
' Search
'===============================================================================

'-------------------------------------------------------------------------------
' searchHandleHeaderSelected
'-------------------------------------------------------------------------------
sub searchHandleHeaderSelected()
    searchShow()
end sub

'-------------------------------------------------------------------------------
' searchShow
'-------------------------------------------------------------------------------
sub searchShow()
    clearStatus()
    resetDynamicPages()

    page = CreateObject("roSGNode", "Search")
    page.observeField("closeRequested", "searchHandleCloseRequested")
    page.observeField("focusExitUp", "searchHandleFocusExitUp")
    page.observeField("selectedMovie", "searchHandleMovieSelected")
    page.observeField("selectedSeries", "searchHandleSeriesSelected")
    page.observeField("selectedEpisode", "searchHandleEpisodeSelected")
    page.observeField("selectedPerson", "searchHandlePersonSelected")
    page.observeField("overlayRequested", "searchHandleOverlayRequested")
    page.loadRequest = buildSessionLoadRequest()

    m.searchPage = page
    authAppendDynamicPage(page)
    m.homePage.visible = false
    m.header.visible = true
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' searchHandleOverlayRequested
'-------------------------------------------------------------------------------
sub searchHandleOverlayRequested()
    if m.searchPage = invalid then return

    request = m.searchPage.overlayRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' searchReturnToPage
'-------------------------------------------------------------------------------
function searchReturnToPage() as boolean
    if m.searchPage = invalid then return false

    m.searchPage.visible = true
    m.header.visible = true
    m.searchPage.callFunc("activate")
    return true
end function

'-------------------------------------------------------------------------------
' searchHidePage
'-------------------------------------------------------------------------------
sub searchHidePage()
    if m.searchPage <> invalid then
        m.searchPage.callFunc("deactivate")
        m.searchPage.visible = false
    end if
end sub

'-------------------------------------------------------------------------------
' searchHandleMovieSelected
'-------------------------------------------------------------------------------
sub searchHandleMovieSelected()
    selection = m.searchPage.selectedMovie
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    searchHidePage()
    movieShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' searchHandleSeriesSelected
'-------------------------------------------------------------------------------
sub searchHandleSeriesSelected()
    selection = m.searchPage.selectedSeries
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    searchHidePage()
    tvShowShow(selection, false)
end sub

'-------------------------------------------------------------------------------
' searchHandleEpisodeSelected
'-------------------------------------------------------------------------------
sub searchHandleEpisodeSelected()
    selection = m.searchPage.selectedEpisode
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    loadRequest = buildHomeEpisodeLoadRequest(selection)
    if loadRequest = invalid then return

    searchHidePage()
    tvEpisodeShow({
        loadRequest: loadRequest
    })
end sub

'-------------------------------------------------------------------------------
' searchHandlePersonSelected
'-------------------------------------------------------------------------------
sub searchHandlePersonSelected()
    selection = m.searchPage.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    searchHidePage()
    personShow(selection)
end sub

'-------------------------------------------------------------------------------
' searchHandleCloseRequested
'-------------------------------------------------------------------------------
sub searchHandleCloseRequested()
    clearStatus()
    if m.searchPage <> invalid then m.searchPage.callFunc("deactivate")
    resetDynamicPages()
    showHome()
end sub

'-------------------------------------------------------------------------------
' searchHandleFocusExitUp
'-------------------------------------------------------------------------------
sub searchHandleFocusExitUp()
    if m.header <> invalid and m.header.visible = true then
        m.header.callFunc("focusHeader")
    end if
end sub

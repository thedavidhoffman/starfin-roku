'-------------------------------------------------------------------------------
' tvShowHandleHomeSeriesSelected
'-------------------------------------------------------------------------------
sub tvShowHandleHomeSeriesSelected()
    selection = m.homePage.selectedSeries
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    tvShowShow(selection, true)
end sub

'-------------------------------------------------------------------------------
' tvShowShow
'-------------------------------------------------------------------------------
sub tvShowShow(selection as object, shouldReset as boolean)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    page = CreateObject("roSGNode", "TVShow")
    page.observeField("closeRequested", "tvShowHandleCloseRequested")
    page.observeField("selectedSeason", "tvSeasonHandleTVShowSeasonSelected")
    page.observeField("selectedPerson", "personHandleTVShowPersonSelected")
    page.observeField("overlayRequested", "tvShowHandleOverlayRequested")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
        settings: m.settings
    }

    if shouldReset then resetDynamicPages()
    m.tvShowPage = page
    m.dynamicPageHost.appendChild(page)
    if m.libraryPage <> invalid then m.libraryPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' tvShowHandleOverlayRequested
'-------------------------------------------------------------------------------
sub tvShowHandleOverlayRequested()
    if m.tvShowPage = invalid then return

    request = m.tvShowPage.overlayRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' personHandleTVShowPersonSelected
'-------------------------------------------------------------------------------
sub personHandleTVShowPersonSelected()
    selection = m.tvShowPage.selectedPerson
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    personShow(selection)
end sub

'-------------------------------------------------------------------------------
' tvShowHandleCloseRequested
'-------------------------------------------------------------------------------
sub tvShowHandleCloseRequested()
    clearStatus()
    if m.tvShowPage <> invalid then
        m.dynamicPageHost.removeChild(m.tvShowPage)
        m.tvShowPage = invalid
    end if

    if m.personPage <> invalid then
        m.personPage.visible = true
        m.header.visible = true
        m.personPage.callFunc("activate")
    else if m.libraryPage <> invalid then
        m.libraryPage.visible = true
        m.header.visible = true
        m.libraryPage.callFunc("activate")
    else
        resetDynamicPages()
        showHome()
    end if
end sub

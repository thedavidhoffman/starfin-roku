'-------------------------------------------------------------------------------
' movieHandleHomeMovieSelected
'-------------------------------------------------------------------------------
sub movieHandleHomeMovieSelected()
    selection = m.homePage.selectedMovie
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    movieShow(selection, true)
end sub

'-------------------------------------------------------------------------------
' movieShow
'-------------------------------------------------------------------------------
sub movieShow(selection as object, shouldReset as boolean)
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    page = CreateObject("roSGNode", "Movie")
    page.observeField("closeRequested", "movieHandleCloseRequested")
    page.observeField("playSelected", "movieHandlePlaySelected")
    page.observeField("selectedPerson", "personHandleMoviePersonSelected")
    page.observeField("streamOptionsRequested", "movieHandleStreamOptionsRequested")
    page.observeField("overlayRequested", "movieHandleOverlayRequested")
    page.observeField("themeRequested", "themeAudioHandleMovieRequested")
    page.loadRequest = {
        server: m.session.server
        token: m.session.token
        userId: m.session.userId
        itemId: selection.itemId
        item: selection.item
        settings: m.settings
    }

    if shouldReset then resetDynamicPages()
    m.moviePage = page
    m.dynamicPageHost.appendChild(page)
    if m.videoLibraryPage <> invalid then m.videoLibraryPage.visible = false
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' movieHandleOverlayRequested
'-------------------------------------------------------------------------------
sub movieHandleOverlayRequested()
    if m.moviePage = invalid then return

    request = m.moviePage.overlayRequested
    if request = invalid then return

    if SafeString(request.action, "") = "close" then
        m.overlayHost.callFunc("closeOverlay")
        return
    end if

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' movieHandleStreamOptionsRequested
'-------------------------------------------------------------------------------
sub movieHandleStreamOptionsRequested()
    if m.moviePage = invalid then return

    request = m.moviePage.streamOptionsRequested
    if request = invalid then return

    m.overlayHost.callFunc("openOverlay", request)
end sub

'-------------------------------------------------------------------------------
' movieHandlePlaySelected
'-------------------------------------------------------------------------------
sub movieHandlePlaySelected()
    selection = m.moviePage.playSelected
    if selection = invalid then return
    if selection.itemId = invalid or selection.itemId = "" then return

    themeAudioStop()
    m.moviePage.callFunc("deactivate")
    playerShow(selection)
end sub

'-------------------------------------------------------------------------------
' movieHandleCloseRequested
'-------------------------------------------------------------------------------
sub movieHandleCloseRequested()
    clearStatus()
    themeAudioStop()
    if m.moviePage <> invalid then
        m.moviePage.callFunc("deactivate")
        m.dynamicPageHost.removeChild(m.moviePage)
        m.moviePage = invalid
    end if

    if m.personPage <> invalid then
        if m.personSourceMoviePage <> invalid then m.moviePage = m.personSourceMoviePage
        m.personPage.visible = true
        m.header.visible = false
        m.personPage.callFunc("activate")
    else if m.videoLibraryPage <> invalid then
        m.videoLibraryPage.visible = true
        m.header.visible = true
        m.videoLibraryPage.callFunc("activate")
    else if searchReturnToPage() then
        return
    else
        resetDynamicPages()
        showHome()
    end if
end sub

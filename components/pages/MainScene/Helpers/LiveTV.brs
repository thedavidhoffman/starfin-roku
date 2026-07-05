'-------------------------------------------------------------------------------
' liveTvHandleHomeSelected
'-------------------------------------------------------------------------------
sub liveTvHandleHomeSelected()
    selection = m.homePage.selectedLiveTV
    if selection = invalid then return

    liveTvShow({
        title: FirstNonEmpty([selection.item.Name], "Live TV")
        item: selection.item
    })
end sub

'-------------------------------------------------------------------------------
' liveTvShow
'-------------------------------------------------------------------------------
sub liveTvShow(selection as object)
    page = CreateObject("roSGNode", "LiveTV")
    page.observeField("closeRequested", "liveTvHandleCloseRequested")
    page.observeField("playSelected", "liveTvHandlePlaySelected")

    loadRequest = buildSessionLoadRequest()
    loadRequest.title = SafeString(selection.title, "Live TV")
    loadRequest.item = selection.item

    resetDynamicPages()
    m.liveTvPage = page
    m.dynamicPageHost.appendChild(page)
    m.homePage.visible = false
    m.header.visible = true
    page.loadRequest = loadRequest
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' liveTvHandlePlaySelected
'-------------------------------------------------------------------------------
sub liveTvHandlePlaySelected()
    if m.liveTvPage = invalid then return

    selection = m.liveTvPage.playSelected
    if selection = invalid then return

    playerShow(selection)
end sub

'-------------------------------------------------------------------------------
' liveTvHandleCloseRequested
'-------------------------------------------------------------------------------
sub liveTvHandleCloseRequested()
    clearStatus()
    if m.liveTvPage <> invalid then
        m.dynamicPageHost.removeChild(m.liveTvPage)
        m.liveTvPage = invalid
    end if

    showHome()
end sub

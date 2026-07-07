'-------------------------------------------------------------------------------
' filmographyHandlePersonFilmographySelected
'-------------------------------------------------------------------------------
sub filmographyHandlePersonFilmographySelected()
    selection = m.personPage.selectedFilmography
    if selection = invalid then return
    if selection.personId = invalid or selection.personId = "" then return

    filmographyShow(selection)
end sub

'-------------------------------------------------------------------------------
' filmographyShow
'-------------------------------------------------------------------------------
sub filmographyShow(selection as object)
    if selection = invalid then return
    if selection.personId = invalid or selection.personId = "" then return

    page = CreateObject("roSGNode", "Filmography")
    page.observeField("closeRequested", "filmographyHandleCloseRequested")
    page.loadRequest = selection

    if m.personPage <> invalid then m.personPage.callFunc("deactivate")
    m.filmographyPage = page
    m.dynamicPageHost.appendChild(page)
    if m.personPage <> invalid then m.personPage.visible = false
    m.homePage.visible = false
    m.header.visible = false
    page.callFunc("activate")
end sub

'-------------------------------------------------------------------------------
' filmographyHandleCloseRequested
'-------------------------------------------------------------------------------
sub filmographyHandleCloseRequested()
    clearStatus()
    if m.filmographyPage <> invalid then
        m.filmographyPage.callFunc("deactivate")
        m.dynamicPageHost.removeChild(m.filmographyPage)
        m.filmographyPage = invalid
    end if

    if m.personPage <> invalid then
        m.personPage.visible = true
        m.header.visible = false
        m.personPage.callFunc("activate")
    else
        showHome()
    end if
end sub

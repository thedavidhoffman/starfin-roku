'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    backdropA = m.top.findNode("backdropA")
    backdropB = m.top.findNode("backdropB")
    m.backdropState = {
        activePoster: backdropA
        preloadPoster: backdropB
        activeUrl: ""
        pendingUrl: ""
    }
    m.titleLogo = m.top.findNode("titleLogo")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.metaDetailLabel = m.top.findNode("metaDetailLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")

    backdropA.observeField("loadStatus", "onBackdropLoadStatusChanged")
    backdropB.observeField("loadStatus", "onBackdropLoadStatusChanged")
    m.titleLogo.observeField("loadStatus", "onTitleLogoLoadStatusChanged")
end sub

'-------------------------------------------------------------------------------
' onMediaContentChanged
'-------------------------------------------------------------------------------
sub onMediaContentChanged()
    content = m.top.mediaContent
    if content = invalid then return

    renderBackdrop(SafeString(content.backdropUrl, ""))
    renderTitle(SafeString(content.title, ""), SafeString(content.logoUrl, ""))
    m.metaLabel.text = SafeString(content.metaLine1, "")
    m.metaDetailLabel.text = SafeString(content.metaLine2, "")
    m.overviewLabel.text = SafeString(content.overview, "")
end sub

'-------------------------------------------------------------------------------
' renderBackdrop
'-------------------------------------------------------------------------------
sub renderBackdrop(backdropUrl as string)
    if backdropUrl = "" then
        clearBackdrops()
        return
    end if

    if backdropUrl = m.backdropState.activeUrl then return
    if backdropUrl = m.backdropState.pendingUrl then return

    if m.backdropState.activeUrl = "" then
        m.backdropState.activePoster.opacity = 0.50
        m.backdropState.activePoster.visible = true
        m.backdropState.activePoster.uri = backdropUrl
        m.backdropState.activeUrl = backdropUrl
        return
    end if

    m.backdropState.preloadPoster.opacity = 0.0
    m.backdropState.preloadPoster.visible = true
    m.backdropState.pendingUrl = backdropUrl
    m.backdropState.preloadPoster.uri = backdropUrl
end sub

'-------------------------------------------------------------------------------
' clearBackdrops
'-------------------------------------------------------------------------------
sub clearBackdrops()
    m.backdropState.activePoster.visible = false
    m.backdropState.activePoster.uri = ""
    m.backdropState.activePoster.opacity = 0.50

    m.backdropState.preloadPoster.visible = false
    m.backdropState.preloadPoster.uri = ""
    m.backdropState.preloadPoster.opacity = 0.50

    m.backdropState.activeUrl = ""
    m.backdropState.pendingUrl = ""
end sub

'-------------------------------------------------------------------------------
' onBackdropLoadStatusChanged
'-------------------------------------------------------------------------------
sub onBackdropLoadStatusChanged()
    if m.backdropState.pendingUrl = "" then return
    if LCase(SafeString(m.backdropState.preloadPoster.loadStatus, "")) <> "ready" then return
    if SafeString(m.backdropState.preloadPoster.uri, "") <> m.backdropState.pendingUrl then return

    swapBackdrops()
end sub

'-------------------------------------------------------------------------------
' swapBackdrops
'-------------------------------------------------------------------------------
sub swapBackdrops()
    oldActivePoster = m.backdropState.activePoster
    newActivePoster = m.backdropState.preloadPoster

    newActivePoster.opacity = 0.50
    newActivePoster.visible = true

    oldActivePoster.visible = false
    oldActivePoster.uri = ""
    oldActivePoster.opacity = 0.50

    m.backdropState.activePoster = newActivePoster
    m.backdropState.preloadPoster = oldActivePoster
    m.backdropState.activeUrl = m.backdropState.pendingUrl
    m.backdropState.pendingUrl = ""
end sub

'-------------------------------------------------------------------------------
' renderTitle
'-------------------------------------------------------------------------------
sub renderTitle(title as string, logoUrl as string)
    hasLogo = logoUrl <> ""

    m.titleLogo.visible = hasLogo
    m.titleLabel.visible = hasLogo = false

    if hasLogo then
        m.titleLogo.width = 600
        m.titleLogo.height = 220
        m.titleLogo.translation = [0, 0]
        m.titleLogo.uri = logoUrl
        m.titleLabel.text = ""
    else
        m.titleLogo.uri = ""
        m.titleLogo.translation = [0, 0]
        m.titleLabel.text = title
    end if
end sub

'-------------------------------------------------------------------------------
' onTitleLogoLoadStatusChanged
'-------------------------------------------------------------------------------
sub onTitleLogoLoadStatusChanged()
    if LCase(SafeString(m.titleLogo.loadStatus, "")) <> "ready" then return

    bitmapWidth = m.titleLogo.bitmapWidth
    bitmapHeight = m.titleLogo.bitmapHeight
    if bitmapWidth = invalid or bitmapHeight = invalid then return
    if bitmapWidth <= 0 or bitmapHeight <= 0 then return

    maxWidth = 600
    maxHeight = 220
    logoRatio = bitmapWidth / bitmapHeight
    boxRatio = maxWidth / maxHeight

    if logoRatio > boxRatio then
        fittedWidth = maxWidth
        fittedHeight = int(maxWidth / logoRatio)
    else
        fittedHeight = maxHeight
        fittedWidth = int(maxHeight * logoRatio)
    end if

    if fittedWidth < 1 then fittedWidth = 1
    if fittedHeight < 1 then fittedHeight = 1

    m.titleLogo.width = fittedWidth
    m.titleLogo.height = fittedHeight
    m.titleLogo.translation = [0, getLogoBottomAlignedY(fittedHeight)]
end sub

'-------------------------------------------------------------------------------
' getLogoBottomAlignedY
'-------------------------------------------------------------------------------
function getLogoBottomAlignedY(logoHeight as integer) as integer
    metaTop = 230
    logoGap = 40
    y = metaTop - logoGap - logoHeight
    if y < 0 then return 0
    return y
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    backdropPrimaryBuffer = m.top.findNode("backdropPrimaryBuffer")
    backdropSecondaryBuffer = m.top.findNode("backdropSecondaryBuffer")
    m.backdropState = {
        activePoster: backdropPrimaryBuffer
        preloadPoster: backdropSecondaryBuffer
        activeUrl: ""
        pendingUrl: ""
    }
    m.logoState = {
        url: ""
        title: ""
        mediaType: ""
        fittedMediaType: ""
    }
    m.titleLogo = m.top.findNode("titleLogo")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.metaDetailLabel = m.top.findNode("metaDetailLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")

    backdropPrimaryBuffer.observeField("loadStatus", "onBackdropLoadStatusChanged")
    backdropSecondaryBuffer.observeField("loadStatus", "onBackdropLoadStatusChanged")
    m.titleLogo.observeField("loadStatus", "onTitleLogoLoadStatusChanged")
end sub

'-------------------------------------------------------------------------------
' onMediaContentChanged
'-------------------------------------------------------------------------------
sub onMediaContentChanged()
    content = m.top.mediaContent
    if content = invalid then return

    mediaType = SafeString(content.mediaType, "")
    applyContentLayout(mediaType)
    renderBackdrop(SafeString(content.backdropUrl, ""))
    renderTitle(SafeString(content.title, ""), SafeString(content.logoUrl, ""), mediaType)
    m.metaLabel.text = SafeString(content.metaLine1, "")
    m.metaDetailLabel.text = SafeString(content.metaLine2, "")
    m.overviewLabel.text = SafeString(content.overview, "")
end sub

'-------------------------------------------------------------------------------
' applyContentLayout
'-------------------------------------------------------------------------------
sub applyContentLayout(mediaType as string)
    layout = getContentLayout(mediaType)

    m.titleLabel.translation = layout.titleTranslation
    m.titleLabel.height = layout.titleHeight
    m.titleLabel.font = layout.titleFont
    m.metaLabel.translation = layout.metaTranslation
    m.metaDetailLabel.translation = layout.metaDetailTranslation
    m.overviewLabel.translation = layout.overviewTranslation
end sub

'-------------------------------------------------------------------------------
' getContentLayout
'-------------------------------------------------------------------------------
function getContentLayout(mediaType as string) as object
    if mediaType = "tv-episode" then
        return {
            titleTranslation: [0, 170]
            titleHeight: 52
            titleFont: "font:MediumBoldSystemFont"
            metaTranslation: [0, 230]
            metaDetailTranslation: [0, 265]
            overviewTranslation: [0, 319]
            logoMaxWidth: 520
            logoMaxHeight: 120
            logoAnchorTop: 170
            logoGap: 24
        }
    end if

    return {
        titleTranslation: [0, 0]
        titleHeight: 160
        titleFont: "font:LargeBoldSystemFont"
        metaTranslation: [0, 230]
        metaDetailTranslation: [0, 265]
        overviewTranslation: [0, 319]
        logoMaxWidth: 600
        logoMaxHeight: 220
        logoAnchorTop: 230
        logoGap: 40
    }
end function

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
sub renderTitle(title as string, logoUrl as string, mediaType as string)
    hasLogo = logoUrl <> ""
    showTextTitle = hasLogo = false or mediaType = "tv-episode"

    m.titleLabel.visible = showTextTitle

    if hasLogo then
        if showTextTitle then
            m.titleLabel.text = title
        else
            m.titleLabel.text = ""
        end if
        m.logoState.title = title
        m.logoState.mediaType = mediaType
        if logoUrl = m.logoState.url and SafeString(m.titleLogo.uri, "") = logoUrl then
            if m.logoState.fittedMediaType <> mediaType then onTitleLogoLoadStatusChanged()
            return
        end if

        layout = getContentLayout(mediaType)
        m.logoState.url = logoUrl
        m.logoState.fittedMediaType = ""
        m.titleLogo.visible = false
        m.titleLogo.width = layout.logoMaxWidth
        m.titleLogo.height = layout.logoMaxHeight
        m.titleLogo.translation = [0, 0]
        m.titleLogo.uri = logoUrl
    else
        m.logoState.url = ""
        m.logoState.title = ""
        m.logoState.mediaType = mediaType
        m.logoState.fittedMediaType = ""
        m.titleLogo.visible = false
        m.titleLogo.uri = ""
        m.titleLogo.translation = [0, 0]
        m.titleLabel.text = title
    end if
end sub

'-------------------------------------------------------------------------------
' onTitleLogoLoadStatusChanged
'-------------------------------------------------------------------------------
sub onTitleLogoLoadStatusChanged()
    if m.logoState.url = "" then return

    loadStatus = LCase(SafeString(m.titleLogo.loadStatus, ""))
    if loadStatus = "failed" then
        m.titleLogo.visible = false
        m.titleLabel.visible = true
        m.titleLabel.text = SafeString(m.logoState.title, "")
        return
    end if

    if loadStatus <> "ready" then return
    if SafeString(m.titleLogo.uri, "") <> m.logoState.url then return

    bitmapWidth = m.titleLogo.bitmapWidth
    bitmapHeight = m.titleLogo.bitmapHeight
    if bitmapWidth = invalid or bitmapHeight = invalid then return
    if bitmapWidth <= 0 or bitmapHeight <= 0 then return

    mediaType = SafeString(m.logoState.mediaType, "")
    layout = getContentLayout(mediaType)
    maxWidth = layout.logoMaxWidth
    maxHeight = layout.logoMaxHeight
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
    m.titleLogo.translation = [0, getLogoBottomAlignedY(fittedHeight, layout)]
    m.titleLogo.visible = true
    m.logoState.fittedMediaType = mediaType
end sub

'-------------------------------------------------------------------------------
' getLogoBottomAlignedY
'-------------------------------------------------------------------------------
function getLogoBottomAlignedY(logoHeight as integer, layout as object) as integer
    y = layout.logoAnchorTop - layout.logoGap - logoHeight
    if y < 0 then return 0
    return y
end function

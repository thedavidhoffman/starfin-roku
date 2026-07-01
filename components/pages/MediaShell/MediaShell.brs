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
    m.logoFallbackTitleLabel = m.top.findNode("logoFallbackTitleLabel")
    m.episodeTitleLabel = m.top.findNode("episodeTitleLabel")
    m.infoGroup = m.top.findNode("infoGroup")
    m.primaryInfoLabel = m.top.findNode("primaryInfoLabel")
    m.secondaryInfoLabel = m.top.findNode("secondaryInfoLabel")
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
    logoPending = content.logoPending = true
    applyContentLayout(mediaType)
    renderBackdrop(SafeString(content.backdropUrl, ""))
    renderTitle(SafeString(content.title, ""), SafeString(content.logoUrl, ""), SafeString(content.logoTitle, ""), mediaType, logoPending)
    m.primaryInfoLabel.text = SafeString(content.primaryInfoText, "")
    m.secondaryInfoLabel.text = SafeString(content.secondaryInfoText, "")
    m.overviewLabel.text = String_CollapseWhitespace(content.overview)
end sub

'-------------------------------------------------------------------------------
' applyContentLayout
'-------------------------------------------------------------------------------
sub applyContentLayout(mediaType as string)
    layout = getContentLayout(mediaType)

    m.episodeTitleLabel.translation = layout.titleTranslation
    m.episodeTitleLabel.height = layout.titleHeight
    m.episodeTitleLabel.font = layout.titleFont
    m.logoFallbackTitleLabel.translation = layout.logoTextTranslation
    m.logoFallbackTitleLabel.height = layout.logoTextHeight
    m.logoFallbackTitleLabel.font = layout.logoTextFont
    m.infoGroup.translation = layout.infoTranslation
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
            infoTranslation: [0, 230]
            logoMaxWidth: 520
            logoMaxHeight: 120
            logoAnchorTop: 170
            logoGap: 24
            logoTextTranslation: [0, 34]
            logoTextHeight: 112
            logoTextFont: "font:LargestSystemFont"
        }
    end if

    return {
        titleTranslation: [0, 0]
        titleHeight: 160
        titleFont: "font:LargeBoldSystemFont"
        infoTranslation: [0, 230]
        logoMaxWidth: 600
        logoMaxHeight: 220
        logoAnchorTop: 230
        logoGap: 40
        logoTextTranslation: [0, 0]
        logoTextHeight: 184
        logoTextFont: "font:LargestSystemFont"
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
sub renderTitle(title as string, logoUrl as string, logoTitle as string, mediaType as string, logoPending as boolean)
    hasLogo = logoUrl <> ""
    isTVEpisode = mediaType = "tv-episode"
    fallbackTitle = getLogoFallbackTitle(title, logoTitle, mediaType)
    showEpisodeTitle = isTVEpisode
    showLogoText = hasLogo = false and logoPending = false and fallbackTitle <> ""

    m.episodeTitleLabel.visible = showEpisodeTitle
    m.episodeTitleLabel.text = ""
    m.logoFallbackTitleLabel.visible = showLogoText
    m.logoFallbackTitleLabel.text = ""
    updateLogoFallbackTitlePosition(showEpisodeTitle)

    if showEpisodeTitle then m.episodeTitleLabel.text = title
    if showLogoText then m.logoFallbackTitleLabel.text = fallbackTitle

    if hasLogo then
        m.logoState.title = fallbackTitle
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
    end if
end sub

'-------------------------------------------------------------------------------
' getLogoFallbackTitle
'-------------------------------------------------------------------------------
function getLogoFallbackTitle(title as string, logoTitle as string, mediaType as string) as string
    if mediaType = "tv-episode" then return logoTitle
    return title
end function

'-------------------------------------------------------------------------------
' onTitleLogoLoadStatusChanged
'-------------------------------------------------------------------------------
sub onTitleLogoLoadStatusChanged()
    if m.logoState.url = "" then return

    loadStatus = LCase(SafeString(m.titleLogo.loadStatus, ""))
    if loadStatus = "failed" then
        m.titleLogo.visible = false
        m.logoFallbackTitleLabel.visible = SafeString(m.logoState.title, "") <> ""
        m.logoFallbackTitleLabel.text = SafeString(m.logoState.title, "")
        updateLogoFallbackTitlePosition(m.episodeTitleLabel.visible)
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
' updateLogoFallbackTitlePosition
'-------------------------------------------------------------------------------
sub updateLogoFallbackTitlePosition(hasEpisodeTitle as boolean)
    targetTranslation = m.infoGroup.translation
    gap = 24

    if hasEpisodeTitle then
        targetTranslation = m.episodeTitleLabel.translation
        gap = 8
    end if

    y = int(targetTranslation[1] - m.logoFallbackTitleLabel.height - gap)
    if y < 0 then y = 0

    m.logoFallbackTitleLabel.translation = [targetTranslation[0], y]
end sub

'-------------------------------------------------------------------------------
' getLogoBottomAlignedY
'-------------------------------------------------------------------------------
function getLogoBottomAlignedY(logoHeight as integer, layout as object) as integer
    y = layout.logoAnchorTop - layout.logoGap - logoHeight
    if y < 0 then return 0
    return y
end function

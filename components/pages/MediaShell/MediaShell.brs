'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.mediaBackgroundFull = m.top.findNode("mediaBackgroundFull")
    m.mediaBackgroundPartialGroup = m.top.findNode("mediaBackgroundPartialGroup")
    m.mediaBackgroundPartial = m.top.findNode("mediaBackgroundPartial")
    m.mediaBackgroundUrl = ""
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
    m.overviewDescription = m.top.findNode("overviewDescription")

    m.overviewDescription.observeField("overlayRequested", "onDescriptionOverlayRequested")
    m.titleLogo.observeField("loadStatus", "onTitleLogoLoadStatusChanged")
    applyBackgroundDisplay()
end sub

'-------------------------------------------------------------------------------
' onBackgroundDisplayChanged
'-------------------------------------------------------------------------------
sub onBackgroundDisplayChanged()
    applyBackgroundDisplay()
end sub

'-------------------------------------------------------------------------------
' applyBackgroundDisplay
'-------------------------------------------------------------------------------
sub applyBackgroundDisplay()
    isPartial = LCase(SafeString(m.top.backgroundDisplay, "full-screen")) = "partial-screen"
    hasBackdrop = m.mediaBackgroundUrl <> ""

    m.mediaBackgroundFull.visible = hasBackdrop and isPartial <> true
    m.mediaBackgroundPartialGroup.visible = hasBackdrop and isPartial
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
    m.overviewDescription.title = SafeString(content.title, "Description")
    m.overviewDescription.text = String_CollapseWhitespace(content.overview)
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
        clearBackdrop()
        return
    end if

    if backdropUrl = m.mediaBackgroundUrl then return

    m.mediaBackgroundFull.opacity = 0.50
    m.mediaBackgroundPartial.opacity = 0.50
    m.mediaBackgroundFull.uri = backdropUrl
    m.mediaBackgroundPartial.uri = backdropUrl
    m.mediaBackgroundUrl = backdropUrl
    applyBackgroundDisplay()
end sub

'-------------------------------------------------------------------------------
' clearBackdrop
'-------------------------------------------------------------------------------
sub clearBackdrop()
    m.mediaBackgroundFull.visible = false
    m.mediaBackgroundPartialGroup.visible = false
    m.mediaBackgroundFull.uri = ""
    m.mediaBackgroundPartial.uri = ""
    m.mediaBackgroundFull.opacity = 0.50
    m.mediaBackgroundPartial.opacity = 0.50
    m.mediaBackgroundUrl = ""
end sub

'-------------------------------------------------------------------------------
' canFocusDescription
'-------------------------------------------------------------------------------
function canFocusDescription() as boolean
    return m.overviewDescription <> invalid and m.overviewDescription.canAcceptFocus = true
end function

'-------------------------------------------------------------------------------
' focusDescription
'-------------------------------------------------------------------------------
function focusDescription() as boolean
    if canFocusDescription() <> true then return false

    m.overviewDescription.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' onDescriptionOverlayRequested
'-------------------------------------------------------------------------------
sub onDescriptionOverlayRequested()
    request = m.overviewDescription.overlayRequested
    if request = invalid then return

    m.top.overlayRequested = request
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
    if mediaType = "tv-episode" or mediaType = "tv-season" then return logoTitle
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

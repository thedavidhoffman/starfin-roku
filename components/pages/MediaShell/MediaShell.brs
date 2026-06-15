'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.titleLogo = m.top.findNode("titleLogo")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.metaDetailLabel = m.top.findNode("metaDetailLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")

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
    m.backdrop.visible = backdropUrl <> ""
    m.backdrop.uri = backdropUrl
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

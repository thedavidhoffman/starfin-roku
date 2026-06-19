'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.imageBackground = m.top.findNode("imageBackground")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    showSubtitle = item.showSubtitle <> false
    applyImageLayout(SafeString(item.imageAspect, "poster"), showSubtitle)
    m.title.text = FirstNonEmpty([item.homeTitle, item.title], "")
    m.subtitle.text = FirstNonEmpty([item.homeSubtitle, item.description], "")
    m.subtitle.visible = showSubtitle
    m.imageBackground.visible = item.showImageBackground = true
    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' applyImageLayout
'-------------------------------------------------------------------------------
sub applyImageLayout(imageAspect as string, showSubtitle as boolean)
    if imageAspect = "wide" then
        m.posterMask.maskUri = "pkg:/images/masks/home-page-thumbnail-440x248.png"
        m.posterMask.maskSize = [440, 248]
        m.poster.width = 440
        m.poster.height = 248
        m.imageBackground.width = 440
        m.imageBackground.height = 248
        m.title.width = 440
        m.title.translation = [0, 261]
        m.subtitle.width = 440
        m.subtitle.translation = [0, 296]

        if showSubtitle = true then
            m.title.height = 34
            m.title.numLines = 1
        else
            m.title.height = 48
            m.title.numLines = 2
        end if
    else
        m.posterMask.maskUri = "pkg:/images/masks/rounded-poster-250x375.png"
        m.posterMask.maskSize = [250, 375]
        m.poster.width = 250
        m.poster.height = 375
        m.imageBackground.width = 250
        m.imageBackground.height = 375
        m.title.width = 250
        m.title.translation = [0, 388]
        m.title.height = 48
        m.title.numLines = 2
        m.subtitle.width = 250
        m.subtitle.translation = [0, 426]
    end if
end sub

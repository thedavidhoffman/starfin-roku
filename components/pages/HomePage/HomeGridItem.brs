'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    applyImageLayout(SafeString(item.imageAspect, "poster"))
    m.title.text = SafeString(item.title, "")
    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' applyImageLayout
'-------------------------------------------------------------------------------
sub applyImageLayout(imageAspect as string)
    if imageAspect = "wide" then
        m.posterMask.maskUri = "pkg:/images/masks/rounded-library-350x197.png"
        m.posterMask.maskSize = [350, 197]
        m.poster.width = 350
        m.poster.height = 197
        m.title.width = 350
        m.title.translation = [0, 207]
    else
        m.posterMask.maskUri = "pkg:/images/masks/rounded-poster-250x375.png"
        m.posterMask.maskSize = [250, 375]
        m.poster.width = 250
        m.poster.height = 375
        m.title.width = 250
        m.title.translation = [0, 385]
    end if
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initStyles()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.episodeNumber = m.top.findNode("episodeNumber")
    m.episodeDate = m.top.findNode("episodeDate")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
    colors = Color()
    m.episodeNumber.color = colors.text.secondary
    m.episodeDate.color = colors.text.secondary
    m.title.color = colors.text.primary
    m.description.color = colors.text.secondary
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.episodeNumber.text = UCase(SafeString(item.episodeNumber, ""))
    m.episodeDate.text = SafeString(item.episodeDate, "")
    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' onItemHasFocusChanged
'-------------------------------------------------------------------------------
sub onItemHasFocusChanged()
    colors = Color()
    if m.top.itemHasFocus = true then
        m.episodeNumber.font = "font:TinyBoldSystemFont"
        m.episodeNumber.color = colors.text.primary
    else
        m.episodeNumber.font = "font:TinySystemFont"
        m.episodeNumber.color = colors.text.secondary
    end if
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.focusRing = m.top.findNode("focusRing")
    m.title = m.top.findNode("title")
    m.metadata = m.top.findNode("metadata")
    m.description = m.top.findNode("description")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    m.title.text = SafeString(item.title, "")
    m.metadata.text = SafeString(item.metaText, "")
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
    m.focusRing.visible = m.top.itemHasFocus = true
end sub

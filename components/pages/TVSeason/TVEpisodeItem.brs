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
    m.layout = {
        titleY: 356
        descriptionY: 398
    }
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
    isSeasonSummary = SafeString(item.itemType, "") = "SeasonSummary"

    episodeNumber = SafeString(item.episodeNumber, "")
    if item.preserveEpisodeNumberCase <> true then episodeNumber = UCase(episodeNumber)
    m.episodeNumber.text = episodeNumber
    m.episodeDate.text = SafeString(item.episodeDate, "")
    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")
    applyLayout(isSeasonSummary)

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' applyLayout
'-------------------------------------------------------------------------------
sub applyLayout(isSeasonSummary as boolean)
    m.episodeNumber.visible = true
    m.episodeDate.visible = true
    m.title.visible = isSeasonSummary <> true

    if isSeasonSummary = true then
        m.description.translation = [0, m.layout.titleY]
    else
        m.description.translation = [0, m.layout.descriptionY]
    end if
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

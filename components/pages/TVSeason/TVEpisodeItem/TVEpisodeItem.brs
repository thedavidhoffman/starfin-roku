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
    m.progressBorder = m.top.findNode("progressBorder")
    m.progressBackground = m.top.findNode("progressBackground")
    m.progressFill = m.top.findNode("progressFill")
    m.episodeNumber = m.top.findNode("episodeNumber")
    m.episodeDate = m.top.findNode("episodeDate")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.layout = {
        titleY: 356
        descriptionY: 402
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
    m.episodeNumber.text = episodeNumber
    m.episodeDate.text = SafeString(item.episodeDate, "")
    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")
    applyLayout(isSeasonSummary)
    updateProgress(item, isSeasonSummary)

    imageUrl = SafeString(item.HDPosterUrl, "")
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' updateProgress
'-------------------------------------------------------------------------------
sub updateProgress(item as object, isSeasonSummary as boolean)
    progressWidth = 0
    if item.progressWidth <> invalid then progressWidth = int(item.progressWidth)
    if progressWidth = 0 and item.progressPercent <> invalid then
        progress = item.progressPercent
        if progress > 100 then progress = 100
        if progress > 0 then progressWidth = int(510 * (progress / 100))
    end if

    visible = isSeasonSummary <> true and progressWidth > 0
    m.progressBorder.visible = visible
    m.progressBackground.visible = visible
    m.progressFill.visible = visible
    if visible <> true then
        m.progressFill.width = 0
        return
    end if

    if progressWidth > 510 then progressWidth = 510
    m.progressFill.width = progressWidth
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

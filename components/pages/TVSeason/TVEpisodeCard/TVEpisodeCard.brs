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
    m.episodePoster = m.top.findNode("episodePoster")
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
    m.episodeNumber.color = colors.text.light.secondary
    m.episodeDate.color = colors.text.light.secondary
    m.title.color = colors.text.light.primary
    m.description.color = colors.text.light.secondary
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    isSeasonSummary = SafeString(item.itemType, "") = "SeasonSummary"

    m.episodeNumber.text = getNumberText(item, isSeasonSummary)
    m.episodeDate.text = getDateText(item, isSeasonSummary)
    m.title.text = SafeString(item.title, "")
    m.description.text = SafeString(item.description, "")
    applyLayout(isSeasonSummary)
    m.episodePoster.itemContent = item
end sub

'-------------------------------------------------------------------------------
' getNumberText
'-------------------------------------------------------------------------------
function getNumberText(item as dynamic, isSeasonSummary as boolean) as string
    if isSeasonSummary then return getEpisodeCountText(item.episodeCount)

    indexText = SafeString(item.episodeIndexNumber, "")
    if indexText <> "" then return "Episode " + indexText
    return "Episode"
end function

'-------------------------------------------------------------------------------
' getDateText
'-------------------------------------------------------------------------------
function getDateText(item as dynamic, isSeasonSummary as boolean) as string
    if isSeasonSummary then return SafeString(item.seasonYear, "")

    return getEpisodeDateText(item)
end function

'-------------------------------------------------------------------------------
' getEpisodeCountText
'-------------------------------------------------------------------------------
function getEpisodeCountText(count as dynamic) as string
    countText = SafeString(count, "")
    if countText = "" then return ""

    return countText + " episodes"
end function

'-------------------------------------------------------------------------------
' getEpisodeDateText
'-------------------------------------------------------------------------------
function getEpisodeDateText(item as dynamic) as string
    airedDate = getAiredDateText(item)
    if Len(airedDate) < 10 then return airedDate

    year = Left(airedDate, 4)
    monthNumber = val(Mid(airedDate, 6, 2))
    day = val(Mid(airedDate, 9, 2))
    if monthNumber < 1 or monthNumber > 12 or day < 1 then return airedDate

    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return day.ToStr() + " " + monthNames[monthNumber - 1] + " " + year
end function

'-------------------------------------------------------------------------------
' getAiredDateText
'-------------------------------------------------------------------------------
function getAiredDateText(item as dynamic) as string
    airedDate = FirstNonEmpty([item.premiereDate, item.airDate, item.dateCreated], "")
    if Len(airedDate) >= 10 then return Left(airedDate, 10)
    return airedDate
end function

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
        m.episodeNumber.color = colors.text.light.primary
    else
        m.episodeNumber.font = "font:TinySystemFont"
        m.episodeNumber.color = colors.text.light.secondary
    end if
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.progressBorder = m.top.findNode("progressBorder")
    m.progressBackground = m.top.findNode("progressBackground")
    m.progressFill = m.top.findNode("progressFill")
    m.watchedIndicator = m.top.findNode("watchedIndicator")
end sub

'-------------------------------------------------------------------------------
' onItemContentChanged
'-------------------------------------------------------------------------------
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then
        renderImage("")
        updateProgress(invalid, false)
        updateWatchedIndicator(invalid, false)
        return
    end if

    isSeasonSummary = SafeString(item.itemType, "") = "SeasonSummary"
    renderImage(SafeString(item.HDPosterUrl, ""))
    updateProgress(item, isSeasonSummary)
    updateWatchedIndicator(item, isSeasonSummary)
end sub

'-------------------------------------------------------------------------------
' onImageUrlChanged
'-------------------------------------------------------------------------------
sub onImageUrlChanged()
    renderImage(SafeString(m.top.imageUrl, ""))
end sub

'-------------------------------------------------------------------------------
' renderImage
'-------------------------------------------------------------------------------
sub renderImage(imageUrl as string)
    m.poster.visible = imageUrl <> ""
    m.placeholder.visible = imageUrl = ""
    m.poster.uri = imageUrl
end sub

'-------------------------------------------------------------------------------
' updateProgress
'-------------------------------------------------------------------------------
sub updateProgress(item as dynamic, isSeasonSummary as boolean)
    if isItemPlayed(item) then
        m.progressBorder.visible = false
        m.progressBackground.visible = false
        m.progressFill.visible = false
        m.progressFill.width = 0
        return
    end if

    progressWidth = 0
    if item <> invalid then
        if item.progressWidth <> invalid then progressWidth = int(item.progressWidth)
        if progressWidth = 0 and item.progressPercent <> invalid then
            progress = item.progressPercent
            if progress > 100 then progress = 100
            if progress > 0 then progressWidth = int(510 * (progress / 100))
        end if
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
' updateWatchedIndicator
'-------------------------------------------------------------------------------
sub updateWatchedIndicator(item as dynamic, isSeasonSummary as boolean)
    if item = invalid then
        m.watchedIndicator.visible = false
        return
    end if

    m.watchedIndicator.visible = isItemPlayed(item)
end sub

'-------------------------------------------------------------------------------
' isItemPlayed
'-------------------------------------------------------------------------------
function isItemPlayed(item as dynamic) as boolean
    if item = invalid then return false

    raw = item.raw
    if SafeString(item.itemType, "") = "SeasonSummary" then
        return raw <> invalid and raw.UserData <> invalid and raw.UserData.UnplayedItemCount = 0
    end if

    return raw <> invalid and raw.UserData <> invalid and raw.UserData.Played = true
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.placeholder = m.top.findNode("placeholder")
    m.poster = m.top.findNode("poster")
    m.progressBar = m.top.findNode("progressBar")
    m.watchedIndicator = m.top.findNode("watchedIndicator")
    m.layout = {
        defaultWidth: 530
        defaultHeight: 298
        progressMarginX: 10
        progressBottom: 10
        progressHeight: 15
        watchedSize: 58
        watchedTop: 10
        watchedRight: 11
    }
    applyPosterLayout()
end sub

'-------------------------------------------------------------------------------
' onPosterSizeChanged
'-------------------------------------------------------------------------------
sub onPosterSizeChanged()
    applyPosterLayout()
    refresh()
end sub

'-------------------------------------------------------------------------------
' applyPosterLayout
'-------------------------------------------------------------------------------
sub applyPosterLayout()
    width = getPosterWidth()
    height = getPosterHeight()
    progressWidth = getProgressTrackWidth(width)
    progressY = height - m.layout.progressBottom - m.layout.progressHeight

    m.posterMask.maskSize = [width, height]
    m.placeholder.width = width
    m.placeholder.height = height
    m.poster.width = width
    m.poster.height = height

    m.progressBar.translation = [m.layout.progressMarginX, progressY]
    m.progressBar.barWidth = progressWidth
    m.progressBar.barHeight = m.layout.progressHeight

    m.watchedIndicator.width = m.layout.watchedSize
    m.watchedIndicator.height = m.layout.watchedSize
    m.watchedIndicator.translation = [width - m.layout.watchedRight - m.layout.watchedSize, m.layout.watchedTop]
end sub

'-------------------------------------------------------------------------------
' getPosterWidth
'-------------------------------------------------------------------------------
function getPosterWidth() as integer
    width = m.top.posterWidth
    if width = invalid or width <= 0 then return m.layout.defaultWidth

    return width
end function

'-------------------------------------------------------------------------------
' getPosterHeight
'-------------------------------------------------------------------------------
function getPosterHeight() as integer
    height = m.top.posterHeight
    if height = invalid or height <= 0 then return m.layout.defaultHeight

    return height
end function

'-------------------------------------------------------------------------------
' getProgressTrackWidth
'-------------------------------------------------------------------------------
function getProgressTrackWidth(posterWidth as integer) as integer
    width = posterWidth - (m.layout.progressMarginX * 2)
    if width < 0 then return 0

    return width
end function

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
' refresh
'-------------------------------------------------------------------------------
sub refresh()
    onItemContentChanged()
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
    trackWidth = getProgressTrackWidth(getPosterWidth())
    if isItemPlayed(item) then
        m.progressBar.visible = false
        m.progressBar.progressWidth = 0
        return
    end if

    progressWidth = 0
    if item <> invalid then
        if item.progressWidth <> invalid then progressWidth = int(item.progressWidth)
        if progressWidth = 0 and item.progressPercent <> invalid then
            progress = item.progressPercent
            if progress > 100 then progress = 100
            if progress > 0 then progressWidth = int(trackWidth * (progress / 100))
        end if
    end if

    visible = isSeasonSummary <> true and progressWidth > 0
    m.progressBar.visible = visible
    if visible <> true then
        m.progressBar.progressWidth = 0
        return
    end if

    if progressWidth > trackWidth then progressWidth = trackWidth
    m.progressBar.progressWidth = progressWidth
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

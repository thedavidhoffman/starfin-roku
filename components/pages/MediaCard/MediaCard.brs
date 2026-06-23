'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.poster = m.top.findNode("poster")
    m.progressBar = m.top.findNode("progressBar")
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
    imageAspect = SafeString(item.imageAspect, "poster")
    applyImageLayout(imageAspect, showSubtitle)
    m.title.text = getDisplayTitle(item)
    m.subtitle.text = getDisplaySubtitle(item)
    m.subtitle.visible = showSubtitle
    imageUrl = getImageUrl(item, imageAspect)
    m.poster.visible = true
    m.poster.uri = imageUrl
    updateProgress(item, imageAspect)
end sub

'-------------------------------------------------------------------------------
' getDisplayTitle
'-------------------------------------------------------------------------------
function getDisplayTitle(item as object) as string
    raw = getRawItem(item)
    if raw = invalid then return FirstNonEmpty([item.title], "Untitled")

    mediaType = LCase(SafeString(raw.Type, ""))

    if mediaType = "episode" then
        return FirstNonEmpty([raw.SeriesName, raw.Name], "Untitled")
    end if

    return FirstNonEmpty([raw.Name], "Untitled")
end function

'-------------------------------------------------------------------------------
' getDisplaySubtitle
'-------------------------------------------------------------------------------
function getDisplaySubtitle(item as object) as string
    raw = getRawItem(item)
    if raw = invalid then return FirstNonEmpty([item.description], "")

    mediaType = LCase(SafeString(raw.Type, ""))

    if mediaType = "movie" or mediaType = "video" then
        return SafeString(raw.ProductionYear, "")
    end if

    if mediaType = "series" then
        return getSeriesYearRange(raw)
    end if

    if mediaType = "episode" then
        return getEpisodeSubtitle(raw)
    end if

    return FirstNonEmpty([raw.SeriesName, raw.AlbumArtist, raw.Album, raw.CollectionType, raw.Type], "")
end function

'-------------------------------------------------------------------------------
' getSeriesYearRange
'-------------------------------------------------------------------------------
function getSeriesYearRange(item as object) as string
    productionYear = SafeString(item.ProductionYear, "")
    if productionYear = "" then return ""

    status = LCase(SafeString(item.Status, ""))
    if status = "continuing" then return productionYear + " - Present"

    if status = "ended" then
        endYear = getYearFromDate(SafeString(item.EndDate, ""))
        if endYear <> "" then return productionYear + " - " + endYear
    end if

    return productionYear
end function

'-------------------------------------------------------------------------------
' getEpisodeSubtitle
'-------------------------------------------------------------------------------
function getEpisodeSubtitle(item as object) as string
    episodeTitle = SafeString(item.Name, "")
    seasonNumber = SafeString(item.ParentIndexNumber, "")
    episodeNumber = SafeString(item.IndexNumber, "")

    if seasonNumber = "" or episodeNumber = "" then return episodeTitle

    return "S" + seasonNumber + "E" + episodeNumber + " - " + episodeTitle
end function

'-------------------------------------------------------------------------------
' getRawItem
'-------------------------------------------------------------------------------
function getRawItem(item as object) as dynamic
    if item = invalid then return invalid
    return item.raw
end function

'-------------------------------------------------------------------------------
' getYearFromDate
'-------------------------------------------------------------------------------
function getYearFromDate(value as string) as string
    if Len(value) < 4 then return ""
    return Left(value, 4)
end function

'-------------------------------------------------------------------------------
' getImageUrl
'-------------------------------------------------------------------------------
function getImageUrl(item as object, imageAspect as string) as string
    imageUrl = SafeString(item.HDPosterUrl, "")
    if imageUrl <> "" then return imageUrl

    if imageAspect = "wide" then return "pkg:/images/media-card/thumbnail-placeholder-440x248.png"
    return "pkg:/images/media-card/poster-placeholder-250x375.png"
end function

'-------------------------------------------------------------------------------
' applyImageLayout
'-------------------------------------------------------------------------------
sub applyImageLayout(imageAspect as string, showSubtitle as boolean)
    if imageAspect = "wide" then
        m.posterMask.maskUri = "pkg:/images/media-card/thumbnail-mask-440x248.png"
        m.posterMask.maskSize = [440, 248]
        m.poster.width = 440
        m.poster.height = 248
        applyProgressLayout(440, 248)
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
        m.posterMask.maskUri = "pkg:/images/media-card/poster-mask-250x375.png"
        m.posterMask.maskSize = [250, 375]
        m.poster.width = 250
        m.poster.height = 375
        applyProgressLayout(250, 375)
        m.title.width = 250
        m.title.translation = [0, 388]
        m.title.height = 48
        m.title.numLines = 2
        m.subtitle.width = 250
        m.subtitle.translation = [0, 426]
    end if
end sub

'-------------------------------------------------------------------------------
' applyProgressLayout
'-------------------------------------------------------------------------------
sub applyProgressLayout(width as integer, height as integer)
    marginX = 10
    progressHeight = 10
    progressBottom = 10
    progressWidth = width - (marginX * 2)
    progressY = height - progressBottom - progressHeight

    m.progressBar.translation = [marginX, progressY]
    m.progressBar.barWidth = progressWidth
    m.progressBar.barHeight = progressHeight
end sub

'-------------------------------------------------------------------------------
' updateProgress
'-------------------------------------------------------------------------------
sub updateProgress(item as object, imageAspect as string)
    trackWidth = getProgressTrackWidth(imageAspect)
    progressWidth = getProgressWidth(getRawItem(item), trackWidth)
    visible = progressWidth > 0

    m.progressBar.visible = visible

    if visible <> true then
        m.progressBar.progressWidth = 0
        return
    end if

    m.progressBar.progressWidth = progressWidth
end sub

'-------------------------------------------------------------------------------
' getProgressTrackWidth
'-------------------------------------------------------------------------------
function getProgressTrackWidth(imageAspect as string) as integer
    if imageAspect = "wide" then return 420
    return 230
end function

'-------------------------------------------------------------------------------
' getProgressWidth
'-------------------------------------------------------------------------------
function getProgressWidth(item as dynamic, trackWidth as integer) as integer
    progressPercent = getProgressPercent(item)
    if progressPercent <= 0 then return 0

    progressWidth = int(trackWidth * (progressPercent / 100))
    if progressWidth < 1 then return 1
    if progressWidth > trackWidth then return trackWidth

    return progressWidth
end function

'-------------------------------------------------------------------------------
' getProgressPercent
'-------------------------------------------------------------------------------
function getProgressPercent(item as dynamic) as float
    if item = invalid then return 0
    if item.UserData <> invalid and item.UserData.Played = true then return 0

    if item.UserData <> invalid and item.UserData.PlayedPercentage <> invalid then
        playedPercentage = item.UserData.PlayedPercentage
        if playedPercentage <= 0 then return 0
        if playedPercentage > 100 then return 100
        return playedPercentage
    end if

    if item.RunTimeTicks = invalid or item.RunTimeTicks <= 0 then return 0

    progressTicks = PlaybackProgress_GetTicksFromItem(item)
    if progressTicks <= 0 then return 0

    progressPercent = (progressTicks / item.RunTimeTicks) * 100
    if progressPercent > 100 then return 100

    return progressPercent
end function

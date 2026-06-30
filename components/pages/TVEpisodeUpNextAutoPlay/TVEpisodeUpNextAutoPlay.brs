'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.logoBanner = m.top.findNode("logoBanner")
    m.finishedLabel = m.top.findNode("finishedLabel")
    m.nextCountdownLabel = m.top.findNode("nextCountdownLabel")
    m.finishedCard = m.top.findNode("finishedCard")
    m.nextCard = m.top.findNode("nextCard")
    m.countdownTimer = m.top.findNode("countdownTimer")
    m.countdown = {
        remaining: 15
        active: false
        playTriggered: false
    }
    m.countdownTimer.observeField("fire", "onCountdownTimerFire")
    m.finishedLabel.text = "Just watched"
    updateCountdownLabel()
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' openAutoPlay
'-------------------------------------------------------------------------------
sub openAutoPlay()
    m.top.visible = true
    m.top.setFocus(true)
    startCountdown()
end sub

'-------------------------------------------------------------------------------
' closeAutoPlay
'-------------------------------------------------------------------------------
sub closeAutoPlay()
    stopCountdown()
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' onVisibleChanged
'-------------------------------------------------------------------------------
sub onVisibleChanged()
    if m.top.visible = true then m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onAutoPlayRequestChanged
'-------------------------------------------------------------------------------
sub onAutoPlayRequestChanged()
    request = m.top.autoPlayRequest
    if request = invalid then return

    renderSeries(request.series)
    m.finishedCard.itemContent = buildEpisodeContentNode(request.finishedItem)
    m.nextCard.itemContent = buildEpisodeContentNode(request.nextItem)
    resetCountdown()
end sub

'-------------------------------------------------------------------------------
' resetCountdown
'-------------------------------------------------------------------------------
sub resetCountdown()
    m.countdown.remaining = 15
    m.countdown.playTriggered = false
    updateCountdownLabel()
end sub

'-------------------------------------------------------------------------------
' startCountdown
'-------------------------------------------------------------------------------
sub startCountdown()
    resetCountdown()
    m.countdown.active = true
    m.countdownTimer.control = "stop"
    m.countdownTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' stopCountdown
'-------------------------------------------------------------------------------
sub stopCountdown()
    m.countdown.active = false
    m.countdownTimer.control = "stop"
end sub

'-------------------------------------------------------------------------------
' updateCountdownLabel
'-------------------------------------------------------------------------------
sub updateCountdownLabel()
    m.nextCountdownLabel.text = m.countdown.remaining.ToStr()
end sub

'-------------------------------------------------------------------------------
' onCountdownTimerFire
'-------------------------------------------------------------------------------
sub onCountdownTimerFire()
    if m.countdown.active <> true then return

    m.countdown.remaining = m.countdown.remaining - 1
    if m.countdown.remaining <= 0 then
        playNextEpisode()
        return
    end if

    updateCountdownLabel()
end sub

'-------------------------------------------------------------------------------
' playNextEpisode
'-------------------------------------------------------------------------------
sub playNextEpisode()
    if m.countdown.playTriggered = true then return

    m.countdown.playTriggered = true
    stopCountdown()
    m.top.playSelected = true
end sub

'-------------------------------------------------------------------------------
' renderSeries
'-------------------------------------------------------------------------------
sub renderSeries(series as dynamic)
    if series = invalid then
        m.logoBanner.title = ""
        m.logoBanner.logoUrl = ""
        return
    end if

    request = m.top.autoPlayRequest
    server = ""
    if request <> invalid then server = SafeString(request.server, "")

    identity = SeriesIdentity_FromItem(server, series)
    m.logoBanner.title = FirstNonEmpty([identity.Name, series.Name], "")
    m.logoBanner.logoUrl = FirstNonEmpty([identity.logoUrl, series.logoUrl], "")
end sub

'-------------------------------------------------------------------------------
' buildEpisodeContentNode
'-------------------------------------------------------------------------------
function buildEpisodeContentNode(queueItem as dynamic) as object
    content = CreateObject("roSGNode", "ContentNode")
    if queueItem = invalid then return content

    item = queueItem.item
    if item = invalid then return content

    content.title = FirstNonEmpty([item.Name], "")
    content.description = FirstNonEmpty([item.Overview], "")
    content.HDPosterUrl = getEpisodePosterUrl(item)
    content.AddFields({
        itemId: SafeString(FirstNonEmpty([item.Id, queueItem.itemId], ""), "")
        itemType: SafeString(FirstNonEmpty([item.Type], ""), "")
        episodeIndexNumber: FirstNonEmpty([item.IndexNumber], "")
        premiereDate: FirstNonEmpty([item.PremiereDate], "")
        airDate: FirstNonEmpty([item.AirDate], "")
        dateCreated: FirstNonEmpty([item.DateCreated], "")
        progressPercent: getProgressPercent(item)
        progressWidth: getProgressWidth(item)
        raw: item
    })

    return content
end function

'-------------------------------------------------------------------------------
' getEpisodePosterUrl
'-------------------------------------------------------------------------------
function getEpisodePosterUrl(item as dynamic) as string
    request = m.top.autoPlayRequest
    if request = invalid then return ""

    itemId = FirstNonEmpty([item.Id], "")
    if itemId = "" then return ""

    tag = ""
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid then tag = item.ImageTags.Primary
    if tag = "" then return ""

    return Url_BuildImageUrl(SafeString(request.server, ""), itemId, "Primary", tag, 530, 298, invalid)
end function

'-------------------------------------------------------------------------------
' getProgressPercent
'-------------------------------------------------------------------------------
function getProgressPercent(item as dynamic) as float
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

'-------------------------------------------------------------------------------
' getProgressWidth
'-------------------------------------------------------------------------------
function getProgressWidth(item as dynamic) as integer
    progressPercent = getProgressPercent(item)
    if progressPercent <= 0 then return 0

    progressWidth = int(510 * (progressPercent / 100))
    if progressWidth < 1 then return 1
    if progressWidth > 510 then return 510

    return progressWidth
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if m.top.visible <> true then return false

    if key = "OK" or key = "select" or key = "play" then
        playNextEpisode()
        return true
    else if key = "back" then
        m.top.cancelSelected = true
        closeAutoPlay()
        return true
    end if

    return true
end function

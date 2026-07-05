'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("LiveTV")
    m.guideGrid = m.top.findNode("guideGrid")
    m.previewGroup = m.top.findNode("previewGroup")
    m.emptyPreviewGroup = m.top.findNode("emptyPreviewGroup")
    m.programTitle = m.top.findNode("programTitle")
    m.programTime = m.top.findNode("programTime")
    m.programDuration = m.top.findNode("programDuration")
    m.programChannel = m.top.findNode("programChannel")
    m.programEpisode = m.top.findNode("programEpisode")
    m.programOverview = m.top.findNode("programOverview")
    m.programImage = m.top.findNode("programImage")
    m.emptyPreviewTitle = m.top.findNode("emptyPreviewTitle")
    m.emptyPreviewMessage = m.top.findNode("emptyPreviewMessage")
    m.channelsTask = m.top.findNode("channelsTask")
    m.scheduleTask = invalid
    m.scheduleBatchTimer = m.top.findNode("scheduleBatchTimer")

    now = CreateObject("roDateTime")
    now.Mark()
    m.guideGrid.contentStartTime = now.AsSeconds() - 1800
    m.guideGrid.observeField("programFocused", "onProgramFocused")
    m.guideGrid.observeField("programSelected", "onProgramSelected")
    m.channelsTask.observeField("response", "onChannelsResponse")
    m.scheduleBatchTimer.observeField("fire", "onScheduleBatchTimerFire")

    m.liveTvState = {
        request: invalid
        channels: []
        channelIndex: {}
        guideStartTime: ""
        guideEndTime: ""
        genres: {}
        isLoading: false
        hasLoaded: false
        schedule: {
            batchSize: 50
            nextIndex: 0
            lastStartIndex: 0
            lastEndIndex: 0
            initialDisplayed: false
            allLoaded: false
            backgroundLoading: false
            loggedFirstProgramData: false
        }
    }
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.liveTvState.isLoading = true then
        m.top.setFocus(true)
    else if m.liveTvState.hasLoaded = true then
        m.guideGrid.setFocus(true)
    else if m.liveTvState.request <> invalid then
        loadChannels()
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.channelsTask.control = "stop"
    stopScheduleTask()
    m.scheduleBatchTimer.control = "stop"
    m.liveTvState.isLoading = false
    m.liveTvState.schedule.backgroundLoading = false
end sub

'-------------------------------------------------------------------------------
' onLoadRequestChanged
'-------------------------------------------------------------------------------
sub onLoadRequestChanged()
    request = m.top.loadRequest
    if request = invalid then return

    m.liveTvState.request = request
    m.top.findNode("titleLabel").text = SafeString(request.title, "Live TV")
    loadChannels()
end sub

'-------------------------------------------------------------------------------
' loadChannels
'-------------------------------------------------------------------------------
sub loadChannels()
    request = m.liveTvState.request
    if request = invalid then return

    Spinner_Show(0)
    Status_ClearMessage()
    m.liveTvState.isLoading = true
    m.liveTvState.hasLoaded = false
    m.liveTvState.genres = {}
    resetScheduleState()
    m.scheduleBatchTimer.control = "stop"
    stopScheduleTask()
    m.guideGrid.visible = false
    m.guideGrid.content = CreateObject("roSGNode", "ContentNode")
    showEmptyPreview("Loading Live TV", "Fetching channels and schedule")
    m.channelsTask.request = request
    m.channelsTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onChannelsResponse
'-------------------------------------------------------------------------------
sub onChannelsResponse()
    response = m.channelsTask.response
    if response = invalid then return
    if response.ok <> true then
        m.liveTvState.isLoading = false
        Spinner_Hide()
        Status_SetMessage(SafeString(response.errorMessage, "Unable to load Live TV channels."))
        return
    end if

    channels = getItemsFromPayload(response.payload)
    content = buildGuideChannels(channels)
    m.guideGrid.content = content

    if content.getChildCount() = 0 then
        m.liveTvState.isLoading = false
        Spinner_Hide()
        showEmptyPreview("No channels found", "No Live TV channels were found.")
        Status_SetMessage("No Live TV channels were found.")
        return
    end if

    loadSchedule()
end sub

'-------------------------------------------------------------------------------
' loadSchedule
'-------------------------------------------------------------------------------
sub loadSchedule()
    channelIds = getChannelIds(m.liveTvState.channels)
    if channelIds = "" then
        m.liveTvState.isLoading = false
        Spinner_Hide()
        Status_SetMessage("No Live TV channels were found.")
        return
    end if

    m.liveTvState.guideStartTime = DateTime_ToIsoOffset(-1800)
    m.liveTvState.guideEndTime = DateTime_ToIsoOffset(24 * 60 * 60)
    m.liveTvState.schedule.nextIndex = 0

    loadNextScheduleBatch()
end sub

'-------------------------------------------------------------------------------
' loadNextScheduleBatch
'-------------------------------------------------------------------------------
sub loadNextScheduleBatch()
    channelIds = getChannelIdsForScheduleBatch()
    if channelIds = "" then
        finishAllScheduleLoading()
        return
    end if

    request = cloneRequest(m.liveTvState.request)
    request.channelIds = channelIds
    request.startTime = m.liveTvState.guideStartTime
    request.endTime = m.liveTvState.guideEndTime

    logScheduleBatch()
    stopScheduleTask()
    m.scheduleTask = CreateObject("roSGNode", "LiveTvScheduleTask")
    m.scheduleTask.observeField("response", "onScheduleResponse")
    m.scheduleTask.request = request
    m.scheduleTask.control = "run"
end sub

'-------------------------------------------------------------------------------
' onScheduleBatchTimerFire
'-------------------------------------------------------------------------------
sub onScheduleBatchTimerFire()
    loadNextScheduleBatch()
end sub

'-------------------------------------------------------------------------------
' onScheduleResponse
'-------------------------------------------------------------------------------
sub onScheduleResponse()
    response = m.scheduleTask.response
    if response = invalid then return
    if response.ok <> true then
        handleScheduleLoadError(response)
        return
    end if

    addSchedulePrograms(getItemsFromPayload(response.payload))
    if m.liveTvState.schedule.initialDisplayed <> true then
        finishInitialScheduleLoading()
    else
        logBackgroundScheduleBatchLoaded()
    end if

    m.scheduleBatchTimer.control = "stop"
    m.scheduleBatchTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' finishInitialScheduleLoading
'-------------------------------------------------------------------------------
sub finishInitialScheduleLoading()
    m.liveTvState.schedule.initialDisplayed = true
    m.liveTvState.schedule.backgroundLoading = true
    updateFocusedProgramPreview()
    m.guideGrid.visible = true
    m.liveTvState.isLoading = false
    m.liveTvState.hasLoaded = true
    Spinner_Hide()
    Status_ClearMessage()
    m.guideGrid.setFocus(true)
    m.log.write("Live TV initial schedule batch loaded; guide shown")
end sub

'-------------------------------------------------------------------------------
' finishAllScheduleLoading
'-------------------------------------------------------------------------------
sub finishAllScheduleLoading()
    m.scheduleBatchTimer.control = "stop"
    m.liveTvState.schedule.allLoaded = true
    m.liveTvState.schedule.backgroundLoading = false

    if m.liveTvState.schedule.initialDisplayed <> true then
        finishInitialScheduleLoading()
        m.liveTvState.schedule.backgroundLoading = false
    end if

    m.log.write("Live TV schedule load complete")
    logMissingFirstProgramData()
    logLiveTvGenres()
end sub

'-------------------------------------------------------------------------------
' handleScheduleLoadError
'-------------------------------------------------------------------------------
sub handleScheduleLoadError(response as object)
    message = SafeString(response.errorMessage, "Unable to load the Live TV guide.")
    m.scheduleBatchTimer.control = "stop"
    m.liveTvState.schedule.backgroundLoading = false
    m.liveTvState.isLoading = false

    if m.liveTvState.schedule.initialDisplayed <> true then
        updateFocusedProgramPreview()
        m.guideGrid.visible = true
        m.liveTvState.hasLoaded = true
        Spinner_Hide()
        m.guideGrid.setFocus(true)
        Status_SetMessage(message)
        m.log.write("Live TV initial schedule batch failed; guide shown without schedule data")
        return
    end if

    m.log.write("Live TV background schedule load stopped: " + message)
end sub

'-------------------------------------------------------------------------------
' getChannelIdsForScheduleBatch
'-------------------------------------------------------------------------------
function getChannelIdsForScheduleBatch() as string
    channels = m.liveTvState.channels
    if channels = invalid then return ""

    startIndex = m.liveTvState.schedule.nextIndex
    if startIndex >= channels.Count() then return ""

    endIndex = startIndex + m.liveTvState.schedule.batchSize
    if endIndex > channels.Count() then endIndex = channels.Count()

    ids = ""
    for i = startIndex to endIndex - 1
        channel = channels[i]
        if channel = invalid then continue for

        channelId = SafeString(channel.Id, "")
        if channelId = "" then continue for

        if ids <> "" then ids = ids + ","
        ids = ids + channelId
    end for

    m.liveTvState.schedule.lastStartIndex = startIndex
    m.liveTvState.schedule.lastEndIndex = endIndex
    m.liveTvState.schedule.nextIndex = endIndex
    return ids
end function

'-------------------------------------------------------------------------------
' logScheduleBatch
'-------------------------------------------------------------------------------
sub logScheduleBatch()
    channels = m.liveTvState.channels
    if channels = invalid then return

    startNumber = m.liveTvState.schedule.lastStartIndex + 1
    endNumber = m.liveTvState.schedule.lastEndIndex
    if endNumber < startNumber then return

    batchNumber = int(m.liveTvState.schedule.lastStartIndex / m.liveTvState.schedule.batchSize) + 1
    m.log.write("Loading Live TV schedule batch " + batchNumber.ToStr() + " channels=" + startNumber.ToStr() + "-" + endNumber.ToStr() + " of " + channels.Count().ToStr())
end sub

'-------------------------------------------------------------------------------
' logBackgroundScheduleBatchLoaded
'-------------------------------------------------------------------------------
sub logBackgroundScheduleBatchLoaded()
    channels = m.liveTvState.channels
    if channels = invalid then return

    endNumber = m.liveTvState.schedule.lastEndIndex
    if endNumber <= 0 then return

    batchNumber = int(m.liveTvState.schedule.lastStartIndex / m.liveTvState.schedule.batchSize) + 1
    m.log.write("Live TV background schedule batch " + batchNumber.ToStr() + " loaded; channels loaded=" + endNumber.ToStr() + " of " + channels.Count().ToStr())
end sub

'-------------------------------------------------------------------------------
' resetScheduleState
'-------------------------------------------------------------------------------
sub resetScheduleState()
    m.liveTvState.schedule.nextIndex = 0
    m.liveTvState.schedule.lastStartIndex = 0
    m.liveTvState.schedule.lastEndIndex = 0
    m.liveTvState.schedule.initialDisplayed = false
    m.liveTvState.schedule.allLoaded = false
    m.liveTvState.schedule.backgroundLoading = false
    m.liveTvState.schedule.loggedFirstProgramData = false
end sub

'-------------------------------------------------------------------------------
' stopScheduleTask
'-------------------------------------------------------------------------------
sub stopScheduleTask()
    if m.scheduleTask = invalid then return

    m.scheduleTask.unobserveField("response")
    m.scheduleTask.control = "stop"
    m.scheduleTask = invalid
end sub

'-------------------------------------------------------------------------------
' buildGuideChannels
'-------------------------------------------------------------------------------
function buildGuideChannels(channels as object) as object
    content = CreateObject("roSGNode", "ContentNode")
    m.liveTvState.channels = []
    m.liveTvState.channelIndex = {}

    for each channel in channels
        if isAssocArray(channel) = false then continue for

        channelId = SafeString(channel.Id, "")
        if channelId = "" then continue for

        node = content.createChild("ContentNode")
        node.Id = channelId
        node.Title = getChannelTitle(channel)
        node.HDPosterUrl = getChannelImageUrl(channel)
        node.AddFields({
            raw: channel
            channelId: channelId
        })

        m.liveTvState.channelIndex[channelId] = content.getChildCount() - 1
        m.liveTvState.channels.Push(channel)
    end for

    return content
end function

'-------------------------------------------------------------------------------
' addSchedulePrograms
'-------------------------------------------------------------------------------
sub addSchedulePrograms(programs as object)
    if m.guideGrid.content = invalid then return

    for each program in programs
        if isAssocArray(program) = false then continue for
        logFirstProgramData(program)
        collectProgramGenres(program)

        channelId = SafeString(program.ChannelId, "")
        if channelId = "" then continue for
        if m.liveTvState.channelIndex.DoesExist(channelId) = false then continue for

        channel = m.guideGrid.content.getChild(m.liveTvState.channelIndex[channelId])
        if channel = invalid then continue for

        startSeconds = DateTime_FromIsoSeconds(program.StartDate)
        endSeconds = DateTime_FromIsoSeconds(program.EndDate)
        duration = endSeconds - startSeconds
        if startSeconds <= 0 or duration <= 0 then continue for

        child = channel.createChild("ContentNode")
        child.Id = SafeString(program.Id, "")
        child.Title = FirstNonEmpty([program.Name], "Program")
        child.Description = FirstNonEmpty([program.Overview], "")
        child.PlayStart = startSeconds
        child.PlayDuration = duration
        child.AddFields({
            raw: program
            channelId: channelId
            channelName: channel.Title
            channelImage: SafeString(channel.HDPosterUrl, "")
            episodeTitle: SafeString(program.EpisodeTitle, "")
            startDate: SafeString(program.StartDate, "")
            endDate: SafeString(program.EndDate, "")
            isLive: program.IsLive
            isRepeat: program.IsRepeat
        })
    end for
end sub

'-------------------------------------------------------------------------------
' collectProgramGenres
'-------------------------------------------------------------------------------
sub collectProgramGenres(program as object)
    addGenreValues(program.Genres)
    addGenreItemValues(program.GenreItems)
    addGenreValues(program.Tags)
end sub

'-------------------------------------------------------------------------------
' addGenreValues
'-------------------------------------------------------------------------------
sub addGenreValues(values as dynamic)
    if values = invalid then return
    if Type(values) <> "roArray" then return

    for each value in values
        addGenreName(value)
    end for
end sub

'-------------------------------------------------------------------------------
' addGenreItemValues
'-------------------------------------------------------------------------------
sub addGenreItemValues(values as dynamic)
    if values = invalid then return
    if Type(values) <> "roArray" then return

    for each item in values
        if isAssocArray(item) = false then continue for
        addGenreName(item.Name)
    end for
end sub

'-------------------------------------------------------------------------------
' addGenreName
'-------------------------------------------------------------------------------
sub addGenreName(value as dynamic)
    name = String_Trim(SafeString(value, ""))
    if name = "" then return

    key = LCase(name)
    if m.liveTvState.genres.DoesExist(key) then return

    m.liveTvState.genres[key] = name
end sub

'-------------------------------------------------------------------------------
' logLiveTvGenres
'-------------------------------------------------------------------------------
sub logLiveTvGenres()
    genres = getSortedGenreNames()
    if genres.Count() = 0 then
        m.log.write("Live TV genres: none found")
        return
    end if

    m.log.write("Live TV genres: " + joinCommaTextParts(genres))
end sub

'-------------------------------------------------------------------------------
' logFirstProgramData
'-------------------------------------------------------------------------------
sub logFirstProgramData(program as object)
    if m.liveTvState.schedule.loggedFirstProgramData = true then return

    m.liveTvState.schedule.loggedFirstProgramData = true
    m.log.write("Live TV first program data: " + stringifyDiagnosticValue(program))
end sub

'-------------------------------------------------------------------------------
' logMissingFirstProgramData
'-------------------------------------------------------------------------------
sub logMissingFirstProgramData()
    if m.liveTvState.schedule.loggedFirstProgramData = true then return

    m.liveTvState.schedule.loggedFirstProgramData = true
    m.log.write("Live TV first program data: none found")
end sub

'-------------------------------------------------------------------------------
' getSortedGenreNames
'-------------------------------------------------------------------------------
function getSortedGenreNames() as object
    names = []
    genres = m.liveTvState.genres
    if genres = invalid then return names

    for each key in genres
        names.Push(genres[key])
    end for

    names.Sort()
    return names
end function

'-------------------------------------------------------------------------------
' joinCommaTextParts
'-------------------------------------------------------------------------------
function joinCommaTextParts(parts as object) as string
    if parts = invalid then return ""

    text = ""
    for each part in parts
        value = SafeString(part, "")
        if value = "" then continue for

        if text <> "" then text = text + ", "
        text = text + value
    end for

    return text
end function

'-------------------------------------------------------------------------------
' stringifyDiagnosticValue
'-------------------------------------------------------------------------------
function stringifyDiagnosticValue(value as dynamic) as string
    return stringifyDiagnosticValueAtDepth(value, 0)
end function

'-------------------------------------------------------------------------------
' stringifyDiagnosticValueAtDepth
'-------------------------------------------------------------------------------
function stringifyDiagnosticValueAtDepth(value as dynamic, depth as integer) as string
    if value = invalid then return "invalid"
    if depth > 4 then return "..."

    valueType = Type(value)
    if valueType = "roAssociativeArray" or valueType = "roSGNodeEvent" then
        return stringifyDiagnosticAssocArray(value, depth)
    end if
    if valueType = "roArray" then
        return stringifyDiagnosticArray(value, depth)
    end if
    if valueType = "Boolean" then
        if value then return "true"
        return "false"
    end if
    if valueType = "Integer" or valueType = "LongInteger" or valueType = "Float" or valueType = "Double" then
        return value.ToStr()
    end if

    return quoteDiagnosticString(SafeString(value, ""))
end function

'-------------------------------------------------------------------------------
' stringifyDiagnosticAssocArray
'-------------------------------------------------------------------------------
function stringifyDiagnosticAssocArray(value as object, depth as integer) as string
    parts = []
    keys = []
    for each key in value
        keys.Push(key)
    end for
    keys.Sort()

    for each key in keys
        parts.Push(SafeString(key, "") + ": " + stringifyDiagnosticValueAtDepth(value[key], depth + 1))
    end for

    return "{ " + joinCommaTextParts(parts) + " }"
end function

'-------------------------------------------------------------------------------
' stringifyDiagnosticArray
'-------------------------------------------------------------------------------
function stringifyDiagnosticArray(value as object, depth as integer) as string
    parts = []
    count = value.Count()
    limit = count
    if limit > 12 then limit = 12

    for i = 0 to limit - 1
        parts.Push(stringifyDiagnosticValueAtDepth(value[i], depth + 1))
    end for
    if count > limit then parts.Push("... +" + (count - limit).ToStr() + " more")

    return "[ " + joinCommaTextParts(parts) + " ]"
end function

'-------------------------------------------------------------------------------
' quoteDiagnosticString
'-------------------------------------------------------------------------------
function quoteDiagnosticString(value as string) as string
    text = value.Replace(Chr(34), "\" + Chr(34))
    return Chr(34) + text + Chr(34)
end function

'-------------------------------------------------------------------------------
' onProgramFocused
'-------------------------------------------------------------------------------
sub onProgramFocused()
    updateFocusedProgramPreview()
end sub

'-------------------------------------------------------------------------------
' updateFocusedProgramPreview
'-------------------------------------------------------------------------------
sub updateFocusedProgramPreview()
    focused = m.guideGrid.programFocusedDetails
    program = getProgramFromFocus(focused)
    if program <> invalid then
        renderProgramPreview(program)
        return
    end if

    channel = getChannelFromFocus(focused)
    if channel <> invalid then
        renderChannelPreview(channel)
        return
    end if

    showEmptyPreview("Select a channel", "No schedule information")
end sub

'-------------------------------------------------------------------------------
' renderProgramPreview
'-------------------------------------------------------------------------------
sub renderProgramPreview(program as object)
    m.previewGroup.visible = true
    m.emptyPreviewGroup.visible = false

    m.programTitle.text = FirstNonEmpty([program.Title], "Program")
    m.programTime.text = getProgramTimeText(program)
    m.programDuration.text = DateTime_FormatDurationSeconds(program.PlayDuration)
    m.programChannel.text = SafeString(program.channelName, "")
    m.programEpisode.text = getProgramEpisodeText(program)
    m.programOverview.text = FirstNonEmpty([program.Description], "")
    m.programImage.uri = getProgramImageUrl(program)
end sub

'-------------------------------------------------------------------------------
' renderChannelPreview
'-------------------------------------------------------------------------------
sub renderChannelPreview(channel as object)
    m.previewGroup.visible = true
    m.emptyPreviewGroup.visible = false

    m.programTitle.text = FirstNonEmpty([channel.Title], "Channel")
    m.programTime.text = ""
    m.programDuration.text = ""
    m.programChannel.text = ""
    m.programEpisode.text = ""
    m.programOverview.text = "No schedule information"
    m.programImage.uri = SafeString(channel.HDPosterUrl, "")
end sub

'-------------------------------------------------------------------------------
' showEmptyPreview
'-------------------------------------------------------------------------------
sub showEmptyPreview(title as string, message as string)
    m.previewGroup.visible = false
    m.emptyPreviewGroup.visible = true
    m.emptyPreviewTitle.text = title
    m.emptyPreviewMessage.text = message
end sub

'-------------------------------------------------------------------------------
' getChannelFromFocus
'-------------------------------------------------------------------------------
function getChannelFromFocus(focused as dynamic) as dynamic
    if focused = invalid then return invalid
    if m.guideGrid.content = invalid then return invalid
    if focused.focusChannelIndex = invalid then return invalid

    channelIndex = int(focused.focusChannelIndex)
    if channelIndex < 0 or channelIndex >= m.guideGrid.content.getChildCount() then return invalid

    return m.guideGrid.content.getChild(channelIndex)
end function

'-------------------------------------------------------------------------------
' getProgramTimeText
'-------------------------------------------------------------------------------
function getProgramTimeText(program as object) as string
    startText = DateTime_ToLocalShortTime(program.startDate)
    endText = DateTime_ToLocalShortTime(program.endDate)
    if startText = "" then return ""
    if endText = "" then return startText

    now = CreateObject("roDateTime")
    now.Mark()
    if program.PlayStart < now.AsSeconds() and program.PlayStart + program.PlayDuration > now.AsSeconds() then
        return "Started at " + startText
    end if

    return startText + " - " + endText
end function

'-------------------------------------------------------------------------------
' getProgramEpisodeText
'-------------------------------------------------------------------------------
function getProgramEpisodeText(program as object) as string
    raw = program.raw
    if raw = invalid then return SafeString(program.episodeTitle, "")

    parts = []
    if raw.ParentIndexNumber <> invalid and raw.IndexNumber <> invalid then
        parts.Push("S" + raw.ParentIndexNumber.ToStr() + " E" + raw.IndexNumber.ToStr())
    end if

    episodeTitle = SafeString(program.episodeTitle, "")
    if episodeTitle <> "" then parts.Push(episodeTitle)

    return joinTextParts(parts)
end function

'-------------------------------------------------------------------------------
' getProgramImageUrl
'-------------------------------------------------------------------------------
function getProgramImageUrl(program as object) as string
    request = m.liveTvState.request
    if request = invalid then return ""

    raw = program.raw
    if raw = invalid then return ""

    tag = ""
    imageType = "Primary"
    if raw.ImageTags <> invalid then
        if raw.ImageTags.Primary <> invalid then
            tag = raw.ImageTags.Primary
        else if raw.ImageTags.Thumb <> invalid then
            tag = raw.ImageTags.Thumb
            imageType = "Thumb"
        end if
    end if

    itemId = SafeString(raw.Id, "")
    if tag = "" and raw.BackdropImageTags <> invalid and raw.BackdropImageTags.Count() > 0 then
        tag = SafeString(raw.BackdropImageTags[0], "")
        imageType = "Backdrop"
    end if
    if itemId = "" or tag = "" then return SafeString(program.channelImage, "")

    return Url_BuildImageUrl(request.server, itemId, imageType, tag, 500, 375)
end function

'-------------------------------------------------------------------------------
' joinTextParts
'-------------------------------------------------------------------------------
function joinTextParts(parts as object) as string
    if parts = invalid then return ""

    text = ""
    for each part in parts
        value = SafeString(part, "")
        if value = "" then continue for

        if text <> "" then text = text + "  |  "
        text = text + value
    end for

    return text
end function

'-------------------------------------------------------------------------------
' onProgramSelected
'-------------------------------------------------------------------------------
sub onProgramSelected()
    focused = m.guideGrid.programFocusedDetails
    program = getProgramFromFocus(focused)
    if program = invalid then return

    channelId = SafeString(program.channelId, "")
    if channelId = "" and program.raw <> invalid then channelId = SafeString(program.raw.ChannelId, "")
    if channelId = "" then return

    m.top.playSelected = {
        itemId: channelId
        item: buildPlaybackItem(program, channelId)
    }
end sub

'-------------------------------------------------------------------------------
' getProgramFromFocus
'-------------------------------------------------------------------------------
function getProgramFromFocus(focused as dynamic) as dynamic
    if focused = invalid then return invalid
    if m.guideGrid.content = invalid then return invalid
    if focused.focusChannelIndex = invalid or focused.focusIndex = invalid then return invalid

    channelIndex = int(focused.focusChannelIndex)
    programIndex = int(focused.focusIndex)
    if channelIndex < 0 or programIndex < 0 then return invalid
    if channelIndex >= m.guideGrid.content.getChildCount() then return invalid

    channel = m.guideGrid.content.getChild(channelIndex)
    if channel = invalid then return invalid
    if programIndex >= channel.getChildCount() then return invalid

    return channel.getChild(programIndex)
end function

'-------------------------------------------------------------------------------
' buildPlaybackItem
'-------------------------------------------------------------------------------
function buildPlaybackItem(program as object, channelId as string) as object
    raw = program.raw
    if raw = invalid then raw = {}

    return {
        Id: channelId
        Name: FirstNonEmpty([program.channelName, program.Title], "Live TV")
        Type: "TvChannel"
        CurrentProgram: raw
    }
end function

'-------------------------------------------------------------------------------
' getChannelIds
'-------------------------------------------------------------------------------
function getChannelIds(channels as object) as string
    if channels = invalid then return ""

    ids = ""
    for each channel in channels
        channelId = SafeString(channel.Id, "")
        if channelId = "" then continue for

        if ids <> "" then ids = ids + ","
        ids = ids + channelId
    end for

    return ids
end function

'-------------------------------------------------------------------------------
' getChannelTitle
'-------------------------------------------------------------------------------
function getChannelTitle(channel as dynamic) as string
    number = SafeString(FirstNonEmpty([channel.Number, channel.ChannelNumber], ""), "")
    name = FirstNonEmpty([channel.Name], "Channel")
    if number <> "" then return number + " " + name

    return name
end function

'-------------------------------------------------------------------------------
' getChannelImageUrl
'-------------------------------------------------------------------------------
function getChannelImageUrl(channel as dynamic) as string
    request = m.liveTvState.request
    if request = invalid then return ""

    tag = ""
    if channel.ImageTags <> invalid and channel.ImageTags.Primary <> invalid then tag = channel.ImageTags.Primary
    if tag = "" then return ""

    return Url_BuildImageUrl(request.server, channel.Id, "Primary", tag, 260, 146)
end function

'-------------------------------------------------------------------------------
' getItemsFromPayload
'-------------------------------------------------------------------------------
function getItemsFromPayload(payload as dynamic) as object
    if payload = invalid then return []
    if Type(payload) = "roArray" then return payload
    if isAssocArray(payload) = false then return []
    if payload.Items <> invalid then return payload.Items

    return []
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

'-------------------------------------------------------------------------------
' cloneRequest
'-------------------------------------------------------------------------------
function cloneRequest(request as object) as object
    clone = {}
    if request = invalid then return clone

    for each key in request
        clone[key] = request[key]
    end for

    return clone
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        deactivate()
        m.top.closeRequested = true
        return true
    end if

    return false
end function

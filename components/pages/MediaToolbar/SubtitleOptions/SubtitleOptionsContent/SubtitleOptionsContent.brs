'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.subtitleList = m.top.findNode("subtitleList")
    m.subtitleList.observeField("itemSelected", "onSubtitleListItemSelected")
    m.subtitleList.observeField("checkedItem", "onSubtitleListCheckedItemChanged")
    m.state = {
        isUpdatingCheckedItem: false
        pendingSelection: invalid
    }
    initStyle()
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    colors = Color()
    m.emptyLabel.color = colors.text.light.secondary
end sub

'-------------------------------------------------------------------------------
' onSubtitleStreamsChanged
'-------------------------------------------------------------------------------
sub onSubtitleStreamsChanged()
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' onSelectedSubtitleStreamIndexChanged
'-------------------------------------------------------------------------------
sub onSelectedSubtitleStreamIndexChanged()
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' onVisibleRowCountChanged
'-------------------------------------------------------------------------------
sub onVisibleRowCountChanged()
    rows = m.top.visibleRowCount
    if rows = invalid or rows <= 0 then rows = 1
    m.subtitleList.numRows = rows
end sub

'-------------------------------------------------------------------------------
' renderOptions
'-------------------------------------------------------------------------------
sub renderOptions()
    content = CreateObject("roSGNode", "ContentNode")
    if hasSubtitleStreams() then
        addOption(content, "Off")
        for each stream in m.top.subtitleStreams
            addOption(content, getSubtitleLabel(stream))
        end for
    end if

    m.subtitleList.content = content
    updateCheckedItem()
    m.subtitleList.visible = hasSubtitleStreams()
    m.emptyLabel.visible = hasSubtitleStreams() <> true
    onVisibleRowCountChanged()
    m.state.pendingSelection = getSelectionForCheckedItem()
end sub

'-------------------------------------------------------------------------------
' addOption
'-------------------------------------------------------------------------------
sub addOption(content as object, title as string)
    option = content.createChild("ContentNode")
    option.title = title
end sub

'-------------------------------------------------------------------------------
' hasSubtitleStreams
'-------------------------------------------------------------------------------
function hasSubtitleStreams() as boolean
    return m.top.subtitleStreams <> invalid and m.top.subtitleStreams.Count() > 0
end function

'-------------------------------------------------------------------------------
' getSubtitleLabel
'-------------------------------------------------------------------------------
function getSubtitleLabel(stream as dynamic) as string
    label = FirstNonEmpty([stream.DisplayTitle, stream.Title, stream.Language], "")
    if label <> "" then return label

    index = SafeString(stream.Index, "")
    if index <> "" then return "Subtitle " + index

    return "Subtitle"
end function

'-------------------------------------------------------------------------------
' updateCheckedItem
'-------------------------------------------------------------------------------
sub updateCheckedItem()
    m.state.isUpdatingCheckedItem = true
    m.subtitleList.checkedItem = getCheckedItemIndex()
    m.state.isUpdatingCheckedItem = false
    m.state.pendingSelection = getSelectionForCheckedItem()
end sub

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex() as integer
    selectedIndex = m.top.selectedSubtitleStreamIndex
    if selectedIndex = invalid or selectedIndex < 0 then return 0
    if hasSubtitleStreams() <> true then return 0

    for i = 0 to m.top.subtitleStreams.Count() - 1
        if getStreamIndex(m.top.subtitleStreams[i], i) = selectedIndex then return i + 1
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' onSubtitleListItemSelected
'-------------------------------------------------------------------------------
sub onSubtitleListItemSelected()
    selectSubtitleListIndex(m.subtitleList.itemSelected)
end sub

'-------------------------------------------------------------------------------
' onSubtitleListCheckedItemChanged
'-------------------------------------------------------------------------------
sub onSubtitleListCheckedItemChanged()
    if m.state.isUpdatingCheckedItem = true then return

    selectSubtitleListIndex(m.subtitleList.checkedItem)
end sub

'-------------------------------------------------------------------------------
' selectSubtitleListIndex
'-------------------------------------------------------------------------------
sub selectSubtitleListIndex(selectedIndex as dynamic)
    if selectedIndex = invalid or selectedIndex <= 0 then
        m.subtitleList.checkedItem = 0
        m.state.pendingSelection = {
            isOff: true
            streamIndex: -1
            label: "Off"
        }
        return
    end if

    streamIndex = selectedIndex - 1
    if hasSubtitleStreams() <> true or streamIndex >= m.top.subtitleStreams.Count() then return

    stream = m.top.subtitleStreams[streamIndex]
    m.subtitleList.checkedItem = selectedIndex
    m.state.pendingSelection = {
        isOff: false
        streamIndex: getStreamIndex(stream, streamIndex)
        stream: stream
        label: getSubtitleLabel(stream)
    }
end sub

'-------------------------------------------------------------------------------
' getSelectedSubtitle
'-------------------------------------------------------------------------------
function getSelectedSubtitle() as dynamic
    if m.state.pendingSelection = invalid then m.state.pendingSelection = getSelectionForCheckedItem()
    return m.state.pendingSelection
end function

'-------------------------------------------------------------------------------
' getSelectionForCheckedItem
'-------------------------------------------------------------------------------
function getSelectionForCheckedItem() as dynamic
    selectedIndex = getCheckedItemIndex()
    if selectedIndex <= 0 then
        return {
            isOff: true
            streamIndex: -1
            label: "Off"
        }
    end if

    streamIndex = selectedIndex - 1
    if hasSubtitleStreams() <> true or streamIndex >= m.top.subtitleStreams.Count() then return invalid

    stream = m.top.subtitleStreams[streamIndex]
    return {
        isOff: false
        streamIndex: getStreamIndex(stream, streamIndex)
        stream: stream
        label: getSubtitleLabel(stream)
    }
end function

'-------------------------------------------------------------------------------
' getStreamIndex
'-------------------------------------------------------------------------------
function getStreamIndex(stream as dynamic, fallback as integer) as integer
    if stream <> invalid and stream.Index <> invalid then return int(stream.Index)
    if stream <> invalid and stream.sourceIndex <> invalid then return int(stream.sourceIndex)
    return fallback
end function

'-------------------------------------------------------------------------------
' focusOptions
'-------------------------------------------------------------------------------
sub focusOptions()
    m.top.setFocus(true)
    if hasSubtitleStreams() then m.subtitleList.setFocus(true)
end sub

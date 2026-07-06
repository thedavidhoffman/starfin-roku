'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.audioList = m.top.findNode("audioList")
    m.audioList.observeField("itemSelected", "onAudioListItemSelected")
    m.audioList.observeField("checkedItem", "onAudioListCheckedItemChanged")
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
' onAudioStreamsChanged
'-------------------------------------------------------------------------------
sub onAudioStreamsChanged()
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' onSelectedAudioStreamIndexChanged
'-------------------------------------------------------------------------------
sub onSelectedAudioStreamIndexChanged()
    updateCheckedItem()
end sub

'-------------------------------------------------------------------------------
' onVisibleRowCountChanged
'-------------------------------------------------------------------------------
sub onVisibleRowCountChanged()
    rows = m.top.visibleRowCount
    if rows = invalid or rows <= 0 then rows = 1
    m.audioList.numRows = rows
end sub

'-------------------------------------------------------------------------------
' renderOptions
'-------------------------------------------------------------------------------
sub renderOptions()
    content = CreateObject("roSGNode", "ContentNode")
    if hasAudioStreams() then
        for each stream in m.top.audioStreams
            addOption(content, getAudioLabel(stream))
        end for
    end if

    m.audioList.content = content
    updateCheckedItem()
    m.audioList.visible = hasAudioStreams()
    m.emptyLabel.visible = hasAudioStreams() <> true
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
' hasAudioStreams
'-------------------------------------------------------------------------------
function hasAudioStreams() as boolean
    return m.top.audioStreams <> invalid and m.top.audioStreams.Count() > 0
end function

'-------------------------------------------------------------------------------
' getAudioLabel
'-------------------------------------------------------------------------------
function getAudioLabel(stream as dynamic) as string
    label = FirstNonEmpty([stream.DisplayTitle, stream.Title, stream.Language], "")
    if label <> "" then return label

    index = SafeString(stream.Index, "")
    if index <> "" then return "Audio " + index

    return "Audio Track"
end function

'-------------------------------------------------------------------------------
' updateCheckedItem
'-------------------------------------------------------------------------------
sub updateCheckedItem()
    m.state.isUpdatingCheckedItem = true
    m.audioList.checkedItem = getCheckedItemIndex()
    m.state.isUpdatingCheckedItem = false
    m.state.pendingSelection = getSelectionForCheckedItem()
end sub

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex() as integer
    selectedIndex = m.top.selectedAudioStreamIndex
    if selectedIndex = invalid or selectedIndex < 0 then return 0
    if hasAudioStreams() <> true then return 0

    for i = 0 to m.top.audioStreams.Count() - 1
        if getStreamIndex(m.top.audioStreams[i], i) = selectedIndex then return i
    end for

    return 0
end function

'-------------------------------------------------------------------------------
' onAudioListItemSelected
'-------------------------------------------------------------------------------
sub onAudioListItemSelected()
    selectAudioListIndex(m.audioList.itemSelected)
end sub

'-------------------------------------------------------------------------------
' onAudioListCheckedItemChanged
'-------------------------------------------------------------------------------
sub onAudioListCheckedItemChanged()
    if m.state.isUpdatingCheckedItem = true then return

    selectAudioListIndex(m.audioList.checkedItem)
end sub

'-------------------------------------------------------------------------------
' selectAudioListIndex
'-------------------------------------------------------------------------------
sub selectAudioListIndex(selectedIndex as dynamic)
    if selectedIndex = invalid then return
    if hasAudioStreams() <> true or selectedIndex < 0 or selectedIndex >= m.top.audioStreams.Count() then return

    stream = m.top.audioStreams[selectedIndex]
    m.audioList.checkedItem = selectedIndex
    m.state.pendingSelection = {
        streamIndex: getStreamIndex(stream, selectedIndex)
        stream: stream
        label: getAudioLabel(stream)
    }
end sub

'-------------------------------------------------------------------------------
' getSelectedAudio
'-------------------------------------------------------------------------------
function getSelectedAudio() as dynamic
    if m.state.pendingSelection = invalid then m.state.pendingSelection = getSelectionForCheckedItem()
    return m.state.pendingSelection
end function

'-------------------------------------------------------------------------------
' getSelectionForCheckedItem
'-------------------------------------------------------------------------------
function getSelectionForCheckedItem() as dynamic
    selectedIndex = getCheckedItemIndex()
    if hasAudioStreams() <> true or selectedIndex < 0 or selectedIndex >= m.top.audioStreams.Count() then return invalid

    stream = m.top.audioStreams[selectedIndex]
    return {
        streamIndex: getStreamIndex(stream, selectedIndex)
        stream: stream
        label: getAudioLabel(stream)
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
    if hasAudioStreams() then m.audioList.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.panel = m.top.findNode("panel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.audioList = m.top.findNode("audioList")
    m.audioList.observeField("itemSelected", "onAudioListItemSelected")
    m.audioList.observeField("checkedItem", "onAudioListCheckedItemChanged")
    m.state = {
        isUpdatingCheckedItem: false
        pendingSelection: invalid
    }
    m.layout = {
        panelX: 600
        panelY: 330
        panelWidth: 720
        titleY: 390
        contentY: 462
        panelPadding: 60
        titleHeight: 48
        listRowHeight: 52
        maxRows: 8
    }
    initStyle()
    renderOptions()
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    colors = Color()
    m.titleLabel.color = colors.text.primary
    m.emptyLabel.color = colors.text.secondary
end sub

'-------------------------------------------------------------------------------
' openOptions
'-------------------------------------------------------------------------------
sub openOptions()
    m.state.pendingSelection = getSelectionForCheckedItem()
    m.top.visible = true
    m.top.setFocus(true)
    if hasAudioStreams() then
        m.audioList.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' closeOptions
'-------------------------------------------------------------------------------
sub closeOptions()
    publishPendingSelection()
    m.top.visible = false
    m.top.closeRequested = true
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
    updatePanelSize()
end sub

'-------------------------------------------------------------------------------
' addOption
'-------------------------------------------------------------------------------
sub addOption(content as object, title as string)
    option = content.createChild("ContentNode")
    option.title = title
end sub

'-------------------------------------------------------------------------------
' updatePanelSize
'-------------------------------------------------------------------------------
sub updatePanelSize()
    rows = 1
    if hasAudioStreams() then rows = m.top.audioStreams.Count()
    if rows > m.layout.maxRows then rows = m.layout.maxRows

    contentHeight = rows * m.layout.listRowHeight
    panelHeight = 208 + contentHeight
    panelY = int((1080 - panelHeight) / 2)
    titleY = panelY + m.layout.panelPadding
    contentY = titleY + m.layout.titleHeight + 24

    m.panel.translation = [m.layout.panelX, panelY]
    m.panel.width = m.layout.panelWidth
    m.panel.height = panelHeight
    m.titleLabel.translation = [m.layout.panelX + m.layout.panelPadding, titleY]
    m.emptyLabel.translation = [m.layout.panelX + m.layout.panelPadding, contentY + 8]
    m.audioList.translation = [m.layout.panelX + m.layout.panelPadding, contentY]
    m.audioList.numRows = rows
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
    if m.top.visible <> true then return

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
' publishPendingSelection
'-------------------------------------------------------------------------------
sub publishPendingSelection()
    if m.state.pendingSelection = invalid then m.state.pendingSelection = getSelectionForCheckedItem()
    if m.state.pendingSelection = invalid then return

    m.top.selectedAudio = m.state.pendingSelection
end sub

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
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" then
        closeOptions()
        return true
    end if

    return false
end function

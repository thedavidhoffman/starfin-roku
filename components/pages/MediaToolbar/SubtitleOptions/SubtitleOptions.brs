'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.panel = m.top.findNode("panel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.subtitleList = m.top.findNode("subtitleList")
    m.subtitleList.observeField("itemSelected", "onSubtitleListItemSelected")
    m.subtitleList.observeField("checkedItem", "onSubtitleListCheckedItemChanged")
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
    if hasSubtitleStreams() then
        m.subtitleList.setFocus(true)
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
    if hasSubtitleStreams() then rows = m.top.subtitleStreams.Count() + 1
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
    m.subtitleList.translation = [m.layout.panelX + m.layout.panelPadding, contentY]
    m.subtitleList.numRows = rows
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
    if m.top.visible <> true then return

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
' publishPendingSelection
'-------------------------------------------------------------------------------
sub publishPendingSelection()
    if m.state.pendingSelection = invalid then m.state.pendingSelection = getSelectionForCheckedItem()
    if m.state.pendingSelection = invalid then return

    m.top.selectedSubtitle = m.state.pendingSelection
end sub

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

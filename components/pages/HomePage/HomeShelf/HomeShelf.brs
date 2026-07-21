'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.items = m.top.findNode("items")

    m.items.observeField("rowItemSelected", "onRowItemSelected")
    m.items.observeField("focusExitUp", "onFocusExitUp")
    m.items.observeField("focusExitDown", "onFocusExitDown")
    onFocusExitAvailabilityChanged()
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.items.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onFocusExitAvailabilityChanged
'-------------------------------------------------------------------------------
sub onFocusExitAvailabilityChanged()
    if m.items = invalid then return

    m.items.canFocusExitUp = m.top.canFocusExitUp
    m.items.canFocusExitDown = m.top.canFocusExitDown
end sub

'-------------------------------------------------------------------------------
' onRowContentChanged
'-------------------------------------------------------------------------------
sub onRowContentChanged()
    rowContent = m.top.rowContent
    if rowContent = invalid then return

    m.titleLabel.text = SafeString(rowContent.title, "")

    content = CreateObject("roSGNode", "ContentNode")
    content.appendChild(rowContent)
    m.items.content = content
end sub

'-------------------------------------------------------------------------------
' onLayoutChanged
'-------------------------------------------------------------------------------
sub onLayoutChanged()
    layout = m.top.layout
    if layout = invalid then return

    m.items.itemComponentName = SafeString(layout.itemComponentName, "VideoMediaCard")
    m.items.itemSize = [layout.itemSizeWidth, layout.height]
    m.items.rowItemSize = [[layout.width, layout.height]]
    m.items.rowItemSpacing = [[layout.itemSpacing, 0]]
    m.items.focusBitmapUri = layout.focusBitmapUri
end sub

'-------------------------------------------------------------------------------
' onRowItemSelected
'-------------------------------------------------------------------------------
sub onRowItemSelected()
    selected = m.items.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    if m.items.content = invalid then return

    row = m.items.content.getChild(selected[0])
    if row = invalid then return

    itemNode = row.getChild(selected[1])
    if itemNode = invalid then return

    m.top.selectedItem = {
        rowIndex: m.top.rowIndex
        rowKey: SafeString(row.rowKey, "")
        itemIndex: selected[1]
        item: itemNode.raw
    }
end sub

'-------------------------------------------------------------------------------
' onFocusExitUp
'-------------------------------------------------------------------------------
sub onFocusExitUp()
    m.top.focusExitUp = true
end sub

'-------------------------------------------------------------------------------
' onFocusExitDown
'-------------------------------------------------------------------------------
sub onFocusExitDown()
    m.top.focusExitDown = true
end sub

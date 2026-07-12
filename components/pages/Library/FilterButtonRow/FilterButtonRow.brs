'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.leftChevron = m.top.findNode("leftChevron")
    m.rightChevron = m.top.findNode("rightChevron")
    m.top.itemComponentName = "FilterButtonRowItem"
    m.top.numRows = 1
    m.top.itemSize = [1392, 64]
    m.top.rowItemSize = [[160, 56]]
    m.top.rowItemSpacing = [[16, 0]]
    m.top.itemSpacing = [0, 0]
    m.top.showRowLabel = false
    m.top.vertFocusAnimationStyle = "fixedFocus"
    m.top.focusBitmapUri = ""
    m.top.focusFootprintBitmapUri = ""
    m.top.observeField("rowItemFocused", "onRowItemFocused")
    m.top.observeField("rowItemSelected", "onRowItemSelected")
    renderItems()
end sub

'-------------------------------------------------------------------------------
' onItemsChanged
'-------------------------------------------------------------------------------
sub onItemsChanged()
    renderItems()
end sub

'-------------------------------------------------------------------------------
' onSelectedValueChanged
'-------------------------------------------------------------------------------
sub onSelectedValueChanged()
    renderItems()
end sub

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems()
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")
    items = m.top.items
    if items = invalid then items = []

    for each item in items
        child = row.createChild("ContentNode")
        value = int(item.value)
        child.title = SafeString(item.label, value.ToStr())
        child.AddFields({
            filterType: "Decade"
            filterValue: value
            selected: value = m.top.selectedValue
        })
    end for

    m.top.content = content
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' onRowItemFocused
'-------------------------------------------------------------------------------
sub onRowItemFocused()
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' onRowItemSelected
'-------------------------------------------------------------------------------
sub onRowItemSelected()
    selected = m.top.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    if m.top.content = invalid then return

    row = m.top.content.getChild(selected[0])
    if row = invalid then return

    item = row.getChild(selected[1])
    if item = invalid then return

    value = int(item.filterValue)
    m.top.selectedValue = value
    m.top.filterSelected = {
        type: SafeString(item.filterType, "Decade")
        label: SafeString(item.title, value.ToStr())
        value: value
    }
    m.top.jumpToRowItem = selected
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' updateChevrons
'-------------------------------------------------------------------------------
sub updateChevrons()
    itemCount = getItemCount()
    if itemCount <= 8 then
        setChevronOpacity(m.leftChevron, 0)
        setChevronOpacity(m.rightChevron, 0)
        return
    end if

    focusedIndex = getFocusedItemIndex()
    leftOpacity = 0.25
    if focusedIndex > 0 then leftOpacity = 1

    rightOpacity = 0.25
    if focusedIndex < itemCount - 1 then rightOpacity = 1

    setChevronOpacity(m.leftChevron, leftOpacity)
    setChevronOpacity(m.rightChevron, rightOpacity)
end sub

'-------------------------------------------------------------------------------
' getItemCount
'-------------------------------------------------------------------------------
function getItemCount() as integer
    if m.top.content = invalid then return 0
    row = m.top.content.getChild(0)
    if row = invalid then return 0

    return row.getChildCount()
end function

'-------------------------------------------------------------------------------
' getFocusedItemIndex
'-------------------------------------------------------------------------------
function getFocusedItemIndex() as integer
    focused = m.top.rowItemFocused
    if focused = invalid or focused.Count() < 2 then return 0
    if focused[1] < 0 then return 0

    return int(focused[1])
end function

'-------------------------------------------------------------------------------
' setChevronOpacity
'-------------------------------------------------------------------------------
sub setChevronOpacity(chevron as dynamic, opacity as float)
    if chevron = invalid then return

    chevron.opacity = opacity
end sub

'-------------------------------------------------------------------------------
' focusFirstButton
'-------------------------------------------------------------------------------
sub focusFirstButton()
    if getItemCount() = 0 then renderItems()
    if getItemCount() = 0 then return

    m.top.jumpToRowItem = [0, 0]
    m.top.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" then
        m.top.focusExitUp = true
        return true
    end if

    if key = "down" then
        m.top.focusExitDown = true
        return true
    end if

    return false
end function

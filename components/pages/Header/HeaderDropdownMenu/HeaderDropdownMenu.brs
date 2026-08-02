'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    initValues()
    initStyle()
    renderItems()
    onOpenChanged()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.background = m.top.findNode("background")
    m.itemsGroup = m.top.findNode("itemsGroup")
end sub

'-------------------------------------------------------------------------------
' initValues
'-------------------------------------------------------------------------------
sub initValues()
    m.itemButtons = []
    m.itemData = []
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    palette = Color()
    if m.background <> invalid then m.background.color = &h41405AFF
    if m.top.headerBgColor = invalid or m.top.headerBgColor = 0 then m.top.headerBgColor = palette.background.header
end sub

'-------------------------------------------------------------------------------
' onItemsChanged
'-------------------------------------------------------------------------------
sub onItemsChanged()
    renderItems()
end sub

'-------------------------------------------------------------------------------
' onDimensionsChanged
'-------------------------------------------------------------------------------
sub onDimensionsChanged()
    renderItems()
end sub

'-------------------------------------------------------------------------------
' onStyleChanged
'-------------------------------------------------------------------------------
sub onStyleChanged()
    for each button in m.itemButtons
        if button <> invalid then button.headerBgColor = m.top.headerBgColor
    end for
end sub

'-------------------------------------------------------------------------------
' onOpenChanged
'-------------------------------------------------------------------------------
sub onOpenChanged()
    m.top.visible = (m.top.isOpen = true)
end sub

'-------------------------------------------------------------------------------
' openMenu
'-------------------------------------------------------------------------------
function openMenu() as boolean
    if hasItems() = false then return false

    m.top.isOpen = true
    focusFirstItem()
    return true
end function

'-------------------------------------------------------------------------------
' closeMenu
'-------------------------------------------------------------------------------
function closeMenu() as boolean
    m.top.isOpen = false
    return true
end function

'-------------------------------------------------------------------------------
' toggleMenu
'-------------------------------------------------------------------------------
function toggleMenu() as boolean
    if m.top.isOpen = true then
        closeMenu()
        return false
    end if

    return openMenu()
end function

'-------------------------------------------------------------------------------
' focusFirstItem
'-------------------------------------------------------------------------------
function focusFirstItem() as boolean
    if m.itemButtons = invalid or m.itemButtons.Count() = 0 then return false
    if m.itemButtons[0] = invalid then return false

    m.itemButtons[0].setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' focusItemById
'-------------------------------------------------------------------------------
function focusItemById(itemId as dynamic) as boolean
    idText = SafeString(itemId, "")
    if idText = "" then return focusFirstItem()

    for i = 0 to m.itemData.Count() - 1
        item = m.itemData[i]
        if item <> invalid and SafeString(item.id, "") = idText then
            if m.itemButtons[i] <> invalid then
                m.itemButtons[i].setFocus(true)
                return true
            end if
        end if
    end for

    return focusFirstItem()
end function

'-------------------------------------------------------------------------------
' focusByOffset
'-------------------------------------------------------------------------------
function focusByOffset(offset as integer) as boolean
    if m.itemButtons = invalid or m.itemButtons.Count() = 0 then return false

    currentIndex = getFocusedItemIndex()
    if currentIndex < 0 then return focusFirstItem()

    nextIndex = currentIndex + offset
    lastIndex = m.itemButtons.Count() - 1

    if nextIndex < 0 then
        nextIndex = lastIndex
    else if nextIndex > lastIndex then
        nextIndex = 0
    end if

    if m.itemButtons[nextIndex] = invalid then return false

    m.itemButtons[nextIndex].setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' isMenuFocused
'-------------------------------------------------------------------------------
function isMenuFocused() as boolean
    return getFocusedItemIndex() >= 0
end function

'-------------------------------------------------------------------------------
' renderItems
'-------------------------------------------------------------------------------
sub renderItems()
    clearItems()

    items = m.top.items
    if items = invalid then items = []

    itemHeight = int(m.top.itemHeight)
    itemSpacing = int(m.top.itemSpacing)
    itemWidth = int(m.top.itemWidth)
    if itemHeight <= 0 then itemHeight = 56
    if itemWidth <= 0 then itemWidth = 220

    index = 0
    for each item in items
        if item <> invalid and item.id <> invalid then
            button = CreateObject("roSGNode", "HeaderButton")
            button.id = "dropdownItem" + index.ToStr()
            button.translation = [0, index * (itemHeight + itemSpacing)]
            button.buttonWidth = itemWidth
            button.buttonHeight = itemHeight
            button.textAlign = "center"
            button.textInset = 0
            button.text = FirstNonEmpty([item.text], "")
            button.headerBgColor = m.top.headerBgColor
            button.observeField("buttonSelected", "onItemPressed")
            m.itemsGroup.appendChild(button)
            m.itemButtons.Push(button)
            m.itemData.Push(item)
            index = index + 1
        end if
    end for

    updateBackground(index)
end sub

'-------------------------------------------------------------------------------
' onItemPressed
'-------------------------------------------------------------------------------
sub onItemPressed()
    selected = getFocusedItem()
    if selected = invalid then return

    m.top.selectedItem = selected
end sub

'-------------------------------------------------------------------------------
' getFocusedItem
'-------------------------------------------------------------------------------
function getFocusedItem() as dynamic
    index = getFocusedItemIndex()
    if index < 0 then return invalid
    if index >= m.itemData.Count() then return invalid

    return m.itemData[index]
end function

'-------------------------------------------------------------------------------
' getFocusedItemIndex
'-------------------------------------------------------------------------------
function getFocusedItemIndex() as integer
    if m.itemButtons = invalid then return -1

    for i = 0 to m.itemButtons.Count() - 1
        button = m.itemButtons[i]
        if button <> invalid and button.isInFocusChain() then return i
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' hasItems
'-------------------------------------------------------------------------------
function hasItems() as boolean
    return m.itemButtons <> invalid and m.itemButtons.Count() > 0
end function

'-------------------------------------------------------------------------------
' updateBackground
'-------------------------------------------------------------------------------
sub updateBackground(itemCount as integer)
    if m.background = invalid then return

    menuWidth = int(m.top.menuWidth)
    itemHeight = int(m.top.itemHeight)
    itemSpacing = int(m.top.itemSpacing)
    if menuWidth <= 0 then menuWidth = 260
    if itemHeight <= 0 then itemHeight = 56
    if itemSpacing < 0 then itemSpacing = 0

    spacingHeight = 0
    if itemCount > 1 then spacingHeight = (itemCount - 1) * itemSpacing

    m.background.width = menuWidth
    m.background.height = 36 + (itemCount * itemHeight) + spacingHeight
end sub

'-------------------------------------------------------------------------------
' clearItems
'-------------------------------------------------------------------------------
sub clearItems()
    if m.itemsGroup <> invalid then
        childCount = m.itemsGroup.getChildCount()
        if childCount > 0 then m.itemsGroup.removeChildrenIndex(childCount, 0)
    end if

    m.itemButtons = []
    m.itemData = []
end sub

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.seriesOptions = m.top.findNode("seriesOptions")
    m.displayOptions = m.top.findNode("displayOptions")
    m.gridColumnsOptions = m.top.findNode("gridColumnsOptions")
    m.screensaverTypeOptions = m.top.findNode("screensaverTypeOptions")
    m.screensaverDelayOptions = m.top.findNode("screensaverDelayOptions")
    m.activeGroupIndex = 0
    m.top.observeField("focusedChild", "onFocusChanged")
    initSeriesOptions()
    initDisplayOptions()
    initGridColumnsOptions()
    initScreensaverTypeOptions()
    initScreensaverDelayOptions()
    loadSettingsValues()
end sub

'-------------------------------------------------------------------------------
' initGridColumnsOptions
'-------------------------------------------------------------------------------
sub initGridColumnsOptions()
    if m.gridColumnsOptions = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    fourOption = content.createChild("ContentNode")
    fourOption.title = "4"
    fiveOption = content.createChild("ContentNode")
    fiveOption.title = "5"
    sixOption = content.createChild("ContentNode")
    sixOption.title = "6"

    m.gridColumnsOptions.content = content
end sub

'-------------------------------------------------------------------------------
' initSeriesOptions
'-------------------------------------------------------------------------------
sub initSeriesOptions()
    if m.seriesOptions = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    collapseOption = content.createChild("ContentNode")
    collapseOption.title = "On"
    expandOption = content.createChild("ContentNode")
    expandOption.title = "Off"

    m.seriesOptions.content = content
end sub

'-------------------------------------------------------------------------------
' initDisplayOptions
'-------------------------------------------------------------------------------
sub initDisplayOptions()
    if m.displayOptions = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    listOption = content.createChild("ContentNode")
    listOption.title = "List"
    gridOption = content.createChild("ContentNode")
    gridOption.title = "Grid"

    m.displayOptions.content = content
end sub

'-------------------------------------------------------------------------------
' initScreensaverTypeOptions
'-------------------------------------------------------------------------------
sub initScreensaverTypeOptions()
    if m.screensaverTypeOptions = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    offOption = content.createChild("ContentNode")
    offOption.title = "Off"
    bounceOption = content.createChild("ContentNode")
    bounceOption.title = "Bouncing Cover"
    starfieldOption = content.createChild("ContentNode")
    starfieldOption.title = "Starfield"

    m.screensaverTypeOptions.content = content
end sub

'-------------------------------------------------------------------------------
' initScreensaverDelayOptions
'-------------------------------------------------------------------------------
sub initScreensaverDelayOptions()
    if m.screensaverDelayOptions = invalid then return

    content = CreateObject("roSGNode", "ContentNode")

    oneMinuteOption = content.createChild("ContentNode")
    oneMinuteOption.title = "1 minute"
    fiveMinuteOption = content.createChild("ContentNode")
    fiveMinuteOption.title = "5 minutes"
    fifteenMinuteOption = content.createChild("ContentNode")
    fifteenMinuteOption.title = "15 minutes"
    thirtyMinuteOption = content.createChild("ContentNode")
    thirtyMinuteOption.title = "30 minutes"

    m.screensaverDelayOptions.content = content
end sub

'-------------------------------------------------------------------------------
' loadSettingsValues
'-------------------------------------------------------------------------------
sub loadSettingsValues()
    settings = SettingsStore_Load()
    if settings = invalid then return
    keys = SettingsStore_Keys()

    if m.seriesOptions <> invalid then
        if settings[keys.seriesDisplay] = "expand" then
            m.seriesOptions.checkedItem = 1
        else
            m.seriesOptions.checkedItem = 0
        end if
    end if

    if m.displayOptions <> invalid then
        if settings[keys.itemDisplay] = "grid" then
            m.displayOptions.checkedItem = 1
        else
            m.displayOptions.checkedItem = 0
        end if
    end if

    if m.gridColumnsOptions <> invalid then
        if settings[keys.gridColumns] = "4" then
            m.gridColumnsOptions.checkedItem = 0
        else if settings[keys.gridColumns] = "5" then
            m.gridColumnsOptions.checkedItem = 1
        else
            m.gridColumnsOptions.checkedItem = 2
        end if
    end if

    if m.screensaverTypeOptions <> invalid then
        if settings[keys.screensaverType] = "bounce" then
            m.screensaverTypeOptions.checkedItem = 1
        else if settings[keys.screensaverType] = "starfield" then
            m.screensaverTypeOptions.checkedItem = 2
        else
            m.screensaverTypeOptions.checkedItem = 0
        end if
    end if

    if m.screensaverDelayOptions <> invalid then
        if settings[keys.screensaverDelay] = "1" then
            m.screensaverDelayOptions.checkedItem = 0
        else if settings[keys.screensaverDelay] = "5" then
            m.screensaverDelayOptions.checkedItem = 1
        else if settings[keys.screensaverDelay] = "15" then
            m.screensaverDelayOptions.checkedItem = 2
        else if settings[keys.screensaverDelay] = "30" then
            m.screensaverDelayOptions.checkedItem = 3
        else
            m.screensaverDelayOptions.checkedItem = 0
        end if
    end if
end sub

'-------------------------------------------------------------------------------
' onFocusChanged
'-------------------------------------------------------------------------------
sub onFocusChanged()
    if m.top.isInFocusChain() = false then return
    if isOptionsFocused(m.seriesOptions) or isOptionsFocused(m.displayOptions) or isOptionsFocused(m.gridColumnsOptions) or isOptionsFocused(m.screensaverTypeOptions) or isOptionsFocused(m.screensaverDelayOptions) then return

    focusActiveGroup()
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "down" and isFocusedAtLastItem(m.displayOptions) then
        return focusGroup(3, 0)
    end if

    if key = "down" and isFocusedAtLastItem(m.seriesOptions) then
        return focusGroup(4, 0)
    end if

    if key = "down" and isFocusedAtLastItem(m.gridColumnsOptions) then
        return focusGroup(4, 0)
    end if

    if key = "down" and isFocusedAtLastItem(m.screensaverTypeOptions) then
        return focusGroup(4, 0)
    end if

    if key = "right" and isOptionsFocused(m.displayOptions) then
        return focusGroup(1, getFocusedItemIndex(m.seriesOptions))
    end if

    if key = "right" and isOptionsFocused(m.seriesOptions) then
        return focusGroup(2, getFocusedItemIndex(m.gridColumnsOptions))
    end if

    if key = "right" and isOptionsFocused(m.screensaverTypeOptions) then
        return focusGroup(4, getFocusedItemIndex(m.screensaverDelayOptions))
    end if

    if key = "left" and isOptionsFocused(m.seriesOptions) then
        return focusGroup(0, getFocusedItemIndex(m.displayOptions))
    end if

    if key = "left" and isOptionsFocused(m.gridColumnsOptions) then
        return focusGroup(1, getFocusedItemIndex(m.seriesOptions))
    end if

    if key = "left" and isOptionsFocused(m.screensaverDelayOptions) then
        return focusGroup(3, getFocusedItemIndex(m.screensaverTypeOptions))
    end if

    if key = "up" and isFocusedAtFirstItem(m.screensaverTypeOptions) then
        return focusGroup(0, getFocusedItemIndex(m.displayOptions))
    end if

    if key = "up" and isFocusedAtFirstItem(m.screensaverDelayOptions) then
        return focusGroup(1, getFocusedItemIndex(m.seriesOptions))
    end if

    return false
end function

'-------------------------------------------------------------------------------
' focusActiveGroup
'-------------------------------------------------------------------------------
sub focusActiveGroup()
    focusGroup(m.activeGroupIndex, invalid)
end sub

'-------------------------------------------------------------------------------
' focusGroup
'-------------------------------------------------------------------------------
function focusGroup(groupIndex as integer, itemIndex as dynamic) as boolean
    options = getOptionsForGroup(groupIndex)
    if options = invalid then return false

    m.activeGroupIndex = groupIndex
    if itemIndex <> invalid then
        if itemIndex < 0 then itemIndex = 0
        lastItemIndex = getLastItemIndex(options)
        if itemIndex > lastItemIndex then itemIndex = lastItemIndex
        options.jumpToItem = itemIndex
    end if
    options.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' getOptionsForGroup
'-------------------------------------------------------------------------------
function getOptionsForGroup(groupIndex as integer) as dynamic
    if groupIndex = 1 then return m.seriesOptions
    if groupIndex = 2 then return m.gridColumnsOptions
    if groupIndex = 3 then return m.screensaverTypeOptions
    if groupIndex = 4 then return m.screensaverDelayOptions

    return m.displayOptions
end function

'-------------------------------------------------------------------------------
' focusFirstField
'-------------------------------------------------------------------------------
sub focusFirstField()
    focusGroup(0, 0)
end sub

'-------------------------------------------------------------------------------
' focusLastField
'-------------------------------------------------------------------------------
sub focusLastField()
    focusGroup(4, getLastItemIndex(m.screensaverDelayOptions))
end sub

'-------------------------------------------------------------------------------
' getSettingsValues
'-------------------------------------------------------------------------------
function getSettingsValues() as object
    keys = SettingsStore_Keys()

    if getCheckedItemIndex(m.seriesOptions) = 0 then
        seriesDisplay = "collapse"
    else
        seriesDisplay = "expand"
    end if

    if getCheckedItemIndex(m.displayOptions) = 0 then
        itemDisplay = "list"
    else
        itemDisplay = "grid"
    end if

    gridColumnsIndex = getCheckedItemIndex(m.gridColumnsOptions)
    if gridColumnsIndex = 0 then
        gridColumns = "4"
    else if gridColumnsIndex = 1 then
        gridColumns = "5"
    else
        gridColumns = "6"
    end if

    screensaverTypeIndex = getCheckedItemIndex(m.screensaverTypeOptions)
    if screensaverTypeIndex = 1 then
        screensaverType = "bounce"
    else if screensaverTypeIndex = 2 then
        screensaverType = "starfield"
    else
        screensaverType = "off"
    end if

    screensaverDelayIndex = getCheckedItemIndex(m.screensaverDelayOptions)
    if screensaverDelayIndex = 1 then
        screensaverDelay = "5"
    else if screensaverDelayIndex = 2 then
        screensaverDelay = "15"
    else if screensaverDelayIndex = 3 then
        screensaverDelay = "30"
    else
        screensaverDelay = "1"
    end if

    settings = {}
    settings[keys.seriesDisplay] = seriesDisplay
    settings[keys.itemDisplay] = itemDisplay
    settings[keys.gridColumns] = gridColumns
    settings[keys.screensaverType] = screensaverType
    settings[keys.screensaverDelay] = screensaverDelay
    return settings
end function

'-------------------------------------------------------------------------------
' canMoveFocusToButtons
'-------------------------------------------------------------------------------
function canMoveFocusToButtons() as boolean
    return isFocusedAtLastItem(m.seriesOptions) or isFocusedAtLastItem(m.screensaverDelayOptions)
end function

'-------------------------------------------------------------------------------
' isOptionsFocused
'-------------------------------------------------------------------------------
function isOptionsFocused(list as dynamic) as boolean
    return list <> invalid and list.isInFocusChain()
end function

'-------------------------------------------------------------------------------
' isFocusedAtFirstItem
'-------------------------------------------------------------------------------
function isFocusedAtFirstItem(list as dynamic) as boolean
    return list <> invalid and list.isInFocusChain() and getFocusedItemIndex(list) <= 0
end function

'-------------------------------------------------------------------------------
' isFocusedAtLastItem
'-------------------------------------------------------------------------------
function isFocusedAtLastItem(list as dynamic) as boolean
    if list = invalid or list.isInFocusChain() = false then return false
    return getFocusedItemIndex(list) >= getLastItemIndex(list)
end function

'-------------------------------------------------------------------------------
' getFocusedItemIndex
'-------------------------------------------------------------------------------
function getFocusedItemIndex(list as dynamic) as integer
    focusedIndex = list.itemFocused
    if focusedIndex = invalid or focusedIndex < 0 then focusedIndex = 0
    return focusedIndex
end function

'-------------------------------------------------------------------------------
' getCheckedItemIndex
'-------------------------------------------------------------------------------
function getCheckedItemIndex(list as dynamic) as integer
    if list = invalid then return 0
    checkedIndex = list.checkedItem
    if checkedIndex = invalid or checkedIndex < 0 then return 0
    return checkedIndex
end function

'-------------------------------------------------------------------------------
' getLastItemIndex
'-------------------------------------------------------------------------------
function getLastItemIndex(list as dynamic) as integer
    if list = invalid or list.content = invalid then return 0

    lastIndex = list.content.getChildCount() - 1
    if lastIndex < 0 then return 0
    return lastIndex
end function

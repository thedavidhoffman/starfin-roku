'-------------------------------------------------------------------------------
' PlaybackProgress_GetTicksFromSelection
'-------------------------------------------------------------------------------
function PlaybackProgress_GetTicksFromSelection(selection as dynamic) as longinteger

    if selection = invalid then return 0
    if selection.startPositionTicks <> invalid then return selection.startPositionTicks

    return PlaybackProgress_GetTicksFromItem(selection.item)

end function

'-------------------------------------------------------------------------------
' PlaybackProgress_GetTicksFromItem
'-------------------------------------------------------------------------------
function PlaybackProgress_GetTicksFromItem(item as dynamic) as longinteger

    if item = invalid then return 0
    if item.UserData = invalid then return 0
    if item.UserData.PlaybackPositionTicks <> invalid then return item.UserData.PlaybackPositionTicks

    return 0

end function

'-------------------------------------------------------------------------------
' PlaybackProgress_TicksToSeconds
'-------------------------------------------------------------------------------
function PlaybackProgress_TicksToSeconds(ticks as dynamic) as integer
    
    if ticks = invalid or ticks <= 0 then return 0

    return int(ticks / 10000000)
    
end function

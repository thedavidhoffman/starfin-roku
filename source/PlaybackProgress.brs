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

'-------------------------------------------------------------------------------
' PlaybackProgress_ApplyChangeToItem
'-------------------------------------------------------------------------------
function PlaybackProgress_ApplyChangeToItem(item as dynamic, change as dynamic) as boolean

    if item = invalid then return false
    if change = invalid then return false
    if item.UserData = invalid then item.UserData = {}

    if change.isFinished = true then
        item.UserData.Played = true
        item.UserData.PlayedPercentage = 0
        item.UserData.PlaybackPositionTicks = 0
    else
        positionTicks = __GetPlaybackProgressTicks(change.positionTicks)
        item.UserData.Played = false
        item.UserData.PlaybackPositionTicks = positionTicks
        item.UserData.PlayedPercentage = __GetPlaybackProgressPercentage(positionTicks, item.RunTimeTicks, change.durationTicks)
    end if

    return true

end function

'-------------------------------------------------------------------------------
' __GetPlaybackProgressTicks
'-------------------------------------------------------------------------------
function __GetPlaybackProgressTicks(value as dynamic) as longinteger

    if value = invalid or value <= 0 then return 0

    return value

end function

'-------------------------------------------------------------------------------
' __GetPlaybackProgressPercentage
'-------------------------------------------------------------------------------
function __GetPlaybackProgressPercentage(positionTicks as dynamic, runtimeTicks as dynamic, durationTicks as dynamic) as float

    if positionTicks = invalid or positionTicks <= 0 then return 0
    if runtimeTicks = invalid or runtimeTicks <= 0 then runtimeTicks = durationTicks
    if runtimeTicks = invalid or runtimeTicks <= 0 then return 0

    percentage = (positionTicks * 100.0) / runtimeTicks
    if percentage > 100 then return 100

    return percentage

end function

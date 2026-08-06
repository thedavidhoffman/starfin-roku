'-------------------------------------------------------------------------------
' GridFocus_GetDownTarget
'-------------------------------------------------------------------------------
function GridFocus_GetDownTarget(focusedIndex as integer, itemCount as integer, columnCount as integer) as integer
    if focusedIndex < 0 or itemCount <= 0 or columnCount <= 0 then return -1

    targetIndex = focusedIndex + columnCount
    if targetIndex < itemCount then return targetIndex

    lastRowStart = Fix((itemCount - 1) / columnCount) * columnCount
    if focusedIndex < lastRowStart then return itemCount - 1

    return -1
end function

'-------------------------------------------------------------------------------
' GridFocus_HandleDown
'-------------------------------------------------------------------------------
function GridFocus_HandleDown(grid as object, key as string, press as boolean) as boolean
    if press = false or key <> "down" then return false
    if grid.content = invalid then return false

    targetIndex = GridFocus_GetDownTarget(grid.itemFocused, grid.content.getChildCount(), grid.numColumns)
    if targetIndex < 0 or targetIndex = grid.itemFocused + grid.numColumns then return false

    grid.animateToItem = targetIndex
    return true
end function

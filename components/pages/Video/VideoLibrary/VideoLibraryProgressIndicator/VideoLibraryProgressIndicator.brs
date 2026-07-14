'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.track = m.top.findNode("track")
    m.fill = m.top.findNode("fill")
    m.layout = {
        width: 10
        height: 836
        screenWidth: 1920
        screenHeight: 1080
        xOffset: -10
        bottomMargin: 12
        minRows: 10
    }

    onProgressStateChanged()
end sub

'-------------------------------------------------------------------------------
' onProgressStateChanged
'-------------------------------------------------------------------------------
sub onProgressStateChanged()
    updateLayout()
    updateProgress()
end sub

'-------------------------------------------------------------------------------
' updateLayout
'-------------------------------------------------------------------------------
sub updateLayout()
    m.top.visible = false

    if LCase(m.top.layoutMode) <> "poster" then return

    gridLeft = int(m.top.gridLeft)
    gridTop = int(m.top.gridTop)
    columns = getPositiveInteger(m.top.numColumns, 1)

    gridRight = gridLeft + (columns * int(m.top.itemWidth)) + ((columns - 1) * int(m.top.itemSpacingX))
    x = gridRight + Fix((m.layout.screenWidth - gridRight - m.layout.width) / 2) + m.layout.xOffset
    if x < gridRight then x = gridRight

    height = m.layout.screenHeight - gridTop - m.layout.bottomMargin
    if height < 0 then height = 0

    m.layout.height = height
    m.top.translation = [x, gridTop]
    m.track.width = m.layout.width
    m.track.height = height
    m.fill.width = m.layout.width
end sub

'-------------------------------------------------------------------------------
' updateProgress
'-------------------------------------------------------------------------------
sub updateProgress()
    m.fill.height = 0

    if LCase(m.top.layoutMode) <> "poster" then
        m.top.visible = false
        return
    end if

    itemCount = int(m.top.itemCount)
    columns = getPositiveInteger(m.top.numColumns, 1)
    visibleRows = getPositiveInteger(m.top.numRows, 1)

    totalRows = Fix((itemCount + columns - 1) / columns)
    maxFocusedRow = totalRows - 1
    m.top.visible = totalRows >= m.layout.minRows and itemCount > columns * visibleRows
    if m.top.visible <> true then return

    focusedIndex = int(m.top.focusedIndex)
    if focusedIndex < 0 then focusedIndex = 0
    if focusedIndex >= itemCount then focusedIndex = itemCount - 1

    focusedRow = Fix(focusedIndex / columns)
    fillHeight = 0
    if maxFocusedRow > 0 then fillHeight = Fix((focusedRow / maxFocusedRow) * m.layout.height)

    if focusedRow = maxFocusedRow then fillHeight = m.layout.height
    if fillHeight < 0 then fillHeight = 0
    if fillHeight > m.layout.height then fillHeight = m.layout.height

    m.fill.height = fillHeight
end sub

'-------------------------------------------------------------------------------
' getPositiveInteger
'-------------------------------------------------------------------------------
function getPositiveInteger(value as dynamic, fallback as integer) as integer
    result = int(value)
    if result <= 0 then return fallback

    return result
end function

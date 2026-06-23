'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.border = m.top.findNode("border")
    m.background = m.top.findNode("background")
    m.fill = m.top.findNode("fill")
    m.layout = {
        borderPadding: 1
    }
    onLayoutChanged()
    onProgressChanged()
end sub

'-------------------------------------------------------------------------------
' onLayoutChanged
'-------------------------------------------------------------------------------
sub onLayoutChanged()
    width = getBarWidth()
    height = getBarHeight()
    padding = m.layout.borderPadding

    m.border.translation = [0 - padding, 0 - padding]
    m.border.width = width + (padding * 2)
    m.border.height = height + (padding * 2)

    m.background.width = width
    m.background.height = height

    m.fill.height = height
    onProgressChanged()
end sub

'-------------------------------------------------------------------------------
' onProgressChanged
'-------------------------------------------------------------------------------
sub onProgressChanged()
    progressWidth = int(m.top.progressWidth)
    width = getBarWidth()

    if progressWidth < 0 then progressWidth = 0
    if progressWidth > width then progressWidth = width
    if progressWidth > 0 and progressWidth < getBarHeight() then progressWidth = getBarHeight()
    if progressWidth > width then progressWidth = width

    m.fill.width = progressWidth
end sub

'-------------------------------------------------------------------------------
' getBarWidth
'-------------------------------------------------------------------------------
function getBarWidth() as integer
    width = int(m.top.barWidth)
    if width < 0 then return 0

    return width
end function

'-------------------------------------------------------------------------------
' getBarHeight
'-------------------------------------------------------------------------------
function getBarHeight() as integer
    height = int(m.top.barHeight)
    if height < 0 then return 0

    return height
end function

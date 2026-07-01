'-------------------------------------------------------------------------------
' Spinner_Show
'-------------------------------------------------------------------------------
sub Spinner_Show()
    spinner = __Spinner_GetNode()
    if spinner = invalid then return

    spinner.visible = true
    spinner.control = "start"
end sub

'-------------------------------------------------------------------------------
' Spinner_Hide
'-------------------------------------------------------------------------------
sub Spinner_Hide()
    spinner = __Spinner_GetNode()
    if spinner = invalid then return

    spinner.control = "stop"
    spinner.visible = false
end sub

'-------------------------------------------------------------------------------
' __Spinner_GetNode
'-------------------------------------------------------------------------------
function __Spinner_GetNode() as dynamic
    if m = invalid or m.top = invalid then return invalid

    scene = m.top.getScene()
    if scene = invalid then return invalid

    return scene.findNode("loadingSpinner")
end function

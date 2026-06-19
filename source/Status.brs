'-------------------------------------------------------------------------------
' SceneGraph status helper
'-------------------------------------------------------------------------------
' This helper is intended for component scripts that have access to the implicit
' SceneGraph `m` object. It is not a generic source helper for tasks or pure
' functions because it resolves the shared StatusLabel through `m.top.getScene()`.
'
'-------------------------------------------------------------------------------
' Status_SetLoading
'-------------------------------------------------------------------------------
sub Status_SetLoading()
    statusLabel = __Status_GetLabel()
    if statusLabel <> invalid then statusLabel.callFunc("setLoading")
end sub

'-------------------------------------------------------------------------------
' Status_SetMessage
'-------------------------------------------------------------------------------
sub Status_SetMessage(message as string)
    statusLabel = __Status_GetLabel()
    if statusLabel <> invalid then statusLabel.callFunc("setMessage", message)
end sub

'-------------------------------------------------------------------------------
' Status_ClearMessage
'-------------------------------------------------------------------------------
sub Status_ClearMessage()
    statusLabel = __Status_GetLabel()
    if statusLabel <> invalid then statusLabel.callFunc("clearMessage")
end sub

'-------------------------------------------------------------------------------
' __Status_GetLabel
'-------------------------------------------------------------------------------
function __Status_GetLabel() as dynamic
    if m = invalid or m.top = invalid then return invalid

    scene = m.top.getScene()
    if scene = invalid then return invalid

    return scene.findNode("statusLabel")
end function

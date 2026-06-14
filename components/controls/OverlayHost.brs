'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.activeOverlay = invalid
    m.activeRequest = invalid
end sub

'-------------------------------------------------------------------------------
' openOverlay
'-------------------------------------------------------------------------------
function openOverlay(request as dynamic) as dynamic
    if request = invalid then return invalid

    closeOverlay()

    componentName = request.componentName
    if componentName = invalid or componentName = "" then return invalid

    overlay = CreateObject("roSGNode", componentName)
    if overlay = invalid then return invalid

    closeFields = getCloseFields(request)
    for each closeField in closeFields
        if closeField <> invalid and closeField <> "" then overlay.observeField(closeField, "onOverlayClosed")
    end for

    m.top.appendChild(overlay)
    m.activeOverlay = overlay
    m.activeRequest = request

    openFunction = request.openFunction
    if openFunction <> invalid and openFunction <> "" then overlay.callFunc(openFunction)

    return overlay
end function

'-------------------------------------------------------------------------------
' getCloseFields
'-------------------------------------------------------------------------------
function getCloseFields(request as dynamic) as object
    if request <> invalid and request.closeFields <> invalid then return request.closeFields
    if request <> invalid and request.closeField <> invalid then return [request.closeField]

    return []
end function

'-------------------------------------------------------------------------------
' closeOverlay
'-------------------------------------------------------------------------------
sub closeOverlay()
    if m.activeOverlay = invalid then return

    m.top.removeChild(m.activeOverlay)
    m.activeOverlay = invalid
    m.activeRequest = invalid
end sub

'-------------------------------------------------------------------------------
' onOverlayClosed
'-------------------------------------------------------------------------------
sub onOverlayClosed()
    closedOverlay = m.activeOverlay
    closedRequest = m.activeRequest
    closeOverlay()
    m.top.closed = {
        overlay: closedOverlay
        request: closedRequest
    }
end sub

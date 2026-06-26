'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.label = m.top.findNode("label")
    m.loadingDelayTimer = m.top.findNode("loadingDelayTimer")
    m.statusState = {
        loadingPending: false
    }
    m.loadingDelayTimer.observeField("fire", "onLoadingDelayTimerFired")
    onTextChanged()
end sub

'-------------------------------------------------------------------------------
' onTextChanged
'-------------------------------------------------------------------------------
sub onTextChanged()
    setMessage(m.top.text)
end sub

'-------------------------------------------------------------------------------
' setMessage
'-------------------------------------------------------------------------------
sub setMessage(message as dynamic)
    stopLoadingDelay()
    showMessage(SafeString(message, ""))
end sub

'-------------------------------------------------------------------------------
' clearMessage
'-------------------------------------------------------------------------------
sub clearMessage()
    stopLoadingDelay()
    showMessage("")
end sub

'-------------------------------------------------------------------------------
' setLoading
'-------------------------------------------------------------------------------
sub setLoading()
    if m.loadingDelayTimer = invalid then
        showMessage("Loading...")
        return
    end if

    m.statusState.loadingPending = true
    showMessage("")
    m.loadingDelayTimer.control = "stop"
    m.loadingDelayTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' onLoadingDelayTimerFired
'-------------------------------------------------------------------------------
sub onLoadingDelayTimerFired()
    if m.statusState.loadingPending = true then
        m.statusState.loadingPending = false
        showMessage("Loading...")
    end if
end sub

'-------------------------------------------------------------------------------
' stopLoadingDelay
'-------------------------------------------------------------------------------
sub stopLoadingDelay()
    m.statusState.loadingPending = false
    if m.loadingDelayTimer <> invalid then m.loadingDelayTimer.control = "stop"
end sub

'-------------------------------------------------------------------------------
' showMessage
'-------------------------------------------------------------------------------
sub showMessage(message as string)
    if m.label = invalid then return

    m.label.text = message
    m.top.visible = (message <> "")
end sub

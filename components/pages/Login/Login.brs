'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.serverInput = m.top.findNode("serverInput")
    m.usernameInput = m.top.findNode("usernameInput")
    m.passwordInput = m.top.findNode("passwordInput")
    m.loginButton = m.top.findNode("loginButton")
    m.loginStatus = m.top.findNode("loginStatus")

    m.loginFocusNodes = [
        m.serverInput
        m.usernameInput
        m.passwordInput
        m.loginButton
    ]
   
    m.activeKeyboardField = invalid
    m.loginButton.observeField("buttonSelected", "onLoginPressed")

    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ' remove this...
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    m.top.serverValue = "http://192.168.0.178:8097"
    m.top.usernameValue = "dev"
    m.top.passwordValue = "donkeykong"
    
    preloadSavedSession()
    syncFieldsFromState()

end sub

'-------------------------------------------------------------------------------
' onServerValueChanged
'-------------------------------------------------------------------------------
sub onServerValueChanged()
    syncFieldsFromState()
end sub

'-------------------------------------------------------------------------------
' onUsernameValueChanged
'-------------------------------------------------------------------------------
sub onUsernameValueChanged()
    syncFieldsFromState()
end sub

'-------------------------------------------------------------------------------
' onPasswordValueChanged
'-------------------------------------------------------------------------------
sub onPasswordValueChanged()
    syncFieldsFromState()
end sub

'-------------------------------------------------------------------------------
' onSavedSessionChanged
'-------------------------------------------------------------------------------
sub onSavedSessionChanged()
    preloadSavedSession()
end sub

'-------------------------------------------------------------------------------
' onStatusMessageChanged
'-------------------------------------------------------------------------------
sub onStatusMessageChanged()
    if m.loginStatus <> invalid then m.loginStatus.text = m.top.statusMessage
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    syncFieldsFromState()
    focusLoginField(0)
end sub

'-------------------------------------------------------------------------------
' onLoginPressed
'-------------------------------------------------------------------------------
sub onLoginPressed()
    server = Url_NormalizeServer(m.top.serverValue)
    username = String_Trim(m.top.usernameValue)
    password = m.top.passwordValue

    if server = "" or username = "" or password = "" then
        m.top.statusMessage = "Server address, username, and password are all required."
        return
    end if

    m.top.statusMessage = "Signing in..."
    m.top.loginRequested = {
        action: "login"
        server: server
        username: username
        password: password
    }
end sub

'-------------------------------------------------------------------------------
' preloadSavedSession
'-------------------------------------------------------------------------------
sub preloadSavedSession()
    savedSession = m.top.savedSession
    if savedSession = invalid then return

    if savedSession.server <> invalid and savedSession.server <> "" then
        m.top.serverValue = savedSession.server
    end if

    if savedSession.username <> invalid and savedSession.username <> "" then
        m.top.usernameValue = savedSession.username
    end if
end sub

'-------------------------------------------------------------------------------
' syncFieldsFromState
'-------------------------------------------------------------------------------
sub syncFieldsFromState()
    if m.serverInput <> invalid then m.serverInput.text = m.top.serverValue
    if m.usernameInput <> invalid then m.usernameInput.text = m.top.usernameValue
    if m.passwordInput <> invalid then
        passwordDisplay = ""
        if m.top.passwordValue <> invalid and m.top.passwordValue <> "" then
            passwordDisplay = RepeatString(Len(m.top.passwordValue), "*")
        end if
        m.passwordInput.text = passwordDisplay
    end if
    if m.loginStatus <> invalid then m.loginStatus.text = m.top.statusMessage
end sub

'-------------------------------------------------------------------------------
' RepeatString
'-------------------------------------------------------------------------------
function RepeatString(length as integer, char as string) as string
    result = ""
    for i = 1 to length
        result = result + char
    end for
    return result
end function

'-------------------------------------------------------------------------------
' openKeyboardDialog
'-------------------------------------------------------------------------------
sub openKeyboardDialog(fieldName as string)
    keyboardDialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    keyboardDialog.buttons = ["Save", "Cancel"]
    keyboardDialog.observeField("buttonSelected", "onKeyboardDialogButtonSelected")

    if fieldName = "server" then
        keyboardDialog.title = "Enter Server Address"
        keyboardDialog.text = m.top.serverValue
    else if fieldName = "username" then
        keyboardDialog.title = "Enter Username"
        keyboardDialog.text = m.top.usernameValue
    else if fieldName = "password" then
        keyboardDialog.title = "Enter Password"
        keyboardDialog.text = m.top.passwordValue
    else
        return
    end if

    m.activeKeyboardField = fieldName
    scene = m.top.getScene()
    if scene <> invalid then
        scene.dialog = keyboardDialog
    end if
end sub

'-------------------------------------------------------------------------------
' onKeyboardDialogButtonSelected
'-------------------------------------------------------------------------------
sub onKeyboardDialogButtonSelected()
    scene = m.top.getScene()
    if scene = invalid then return

    keyboardDialog = scene.dialog
    if keyboardDialog = invalid then return

    if keyboardDialog.buttonSelected = 0 then
        if m.activeKeyboardField = "server" then
            m.top.serverValue = keyboardDialog.text
        else if m.activeKeyboardField = "username" then
            m.top.usernameValue = keyboardDialog.text
        else if m.activeKeyboardField = "password" then
            m.top.passwordValue = keyboardDialog.text
        end if
    end if

    scene.dialog = invalid

    if m.activeKeyboardField = "server" then
        focusLoginField(0)
    else if m.activeKeyboardField = "username" then
        focusLoginField(1)
    else if m.activeKeyboardField = "password" then
        focusLoginField(2)
    end if

    m.activeKeyboardField = invalid
end sub

'-------------------------------------------------------------------------------
' focusLoginField
'-------------------------------------------------------------------------------
sub focusLoginField(index as integer)
    if m.loginFocusNodes = invalid then return
    if index < 0 or index >= m.loginFocusNodes.Count() then return

    if m.serverInput <> invalid then m.serverInput.hasFocusVisual = (index = 0)
    if m.usernameInput <> invalid then m.usernameInput.hasFocusVisual = (index = 1)
    if m.passwordInput <> invalid then m.passwordInput.hasFocusVisual = (index = 2)
    if m.loginButton <> invalid then m.loginButton.hasFocusVisual = (index = 3)
    node = m.loginFocusNodes[index]
    if node <> invalid then
        node.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' getFocusedLoginFieldIndex
'-------------------------------------------------------------------------------
function getFocusedLoginFieldIndex() as integer
    if m.loginFocusNodes = invalid then return -1

    for i = 0 to m.loginFocusNodes.Count() - 1
        node = m.loginFocusNodes[i]
        if node <> invalid and node.isInFocusChain() then
            return i
        end if
    end for

    return -1
end function

'-------------------------------------------------------------------------------
' handleLoginNavigation
'-------------------------------------------------------------------------------
function handleLoginNavigation(key as string) as boolean
    focusedIndex = getFocusedLoginFieldIndex()
    if focusedIndex = -1 then
        focusLoginField(0)
        return true
    end if

    if key = "down" then
        nextIndex = focusedIndex + 1
        if nextIndex >= m.loginFocusNodes.Count() then nextIndex = 0
        focusLoginField(nextIndex)
        return true
    end if

    if key = "up" then
        nextIndex = focusedIndex - 1
        if nextIndex < 0 then nextIndex = m.loginFocusNodes.Count() - 1
        focusLoginField(nextIndex)
        return true
    end if

    if key = "OK" or key = "select" then
        if focusedIndex = 0 then
            openKeyboardDialog("server")
            return true
        else if focusedIndex = 1 then
            openKeyboardDialog("username")
            return true
        else if focusedIndex = 2 then
            openKeyboardDialog("password")
            return true
        else if focusedIndex = 3 then
            onLoginPressed()
            return true
        end if
    end if

    return false
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    return handleLoginNavigation(key)
end function

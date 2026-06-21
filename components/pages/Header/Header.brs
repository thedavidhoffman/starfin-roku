'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    rebuildFocusableHeaderButtons()
    initHandlers()

    m.usernameUpPressCount = 0

    initStyle()
    updateUserMenuButton()
    setActiveHeaderButton("home")
    closeAccountMenu()
    syncMenuOpen()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.navGroup = m.top.findNode("navGroup")
    m.homeButton = m.top.findNode("homeButton")
    m.searchButton = m.top.findNode("searchButton")
    m.settingsButton = m.top.findNode("settingsButton")
    m.userMenuButton = m.top.findNode("userMenuButton")
    m.accountDropdownMenu = m.top.findNode("accountDropdownMenu")
    m.usernameUpSequenceTimer = m.top.findNode("usernameUpSequenceTimer")
    m.focusableHeaderButtons = []
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.homeButton.observeField("buttonSelected", "onHomePressed")
    m.searchButton.observeField("buttonSelected", "onSearchPressed")
    m.settingsButton.observeField("buttonSelected", "onSettingsPressed")
    m.userMenuButton.observeField("buttonSelected", "onUserMenuPressed")
    m.accountDropdownMenu.observeField("selectedItem", "onAccountDropdownItemSelected")
    m.usernameUpSequenceTimer.observeField("fire", "onUsernameUpSequenceTimerFired")
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    palette = Color()
    headerBgColor = palette.background.header
    m.homeButton.headerBgColor = headerBgColor
    m.searchButton.headerBgColor = headerBgColor
    m.settingsButton.headerBgColor = headerBgColor
    m.userMenuButton.headerBgColor = headerBgColor
    m.accountDropdownMenu.headerBgColor = headerBgColor
    m.accountDropdownMenu.items = getAccountDropdownItems()
end sub

'-------------------------------------------------------------------------------
' focusHeader
'-------------------------------------------------------------------------------
function focusHeader() as boolean
    closeMenu()

    for each button in m.focusableHeaderButtons
        if button <> invalid then
            button.setFocus(true)
            return true
        end if
    end for

    return false
end function

'-------------------------------------------------------------------------------
' focusUserMenuButton
'-------------------------------------------------------------------------------
function focusUserMenuButton() as boolean
    closeMenu()
    if m.userMenuButton = invalid then return false

    m.userMenuButton.setFocus(true)
    return true
end function

' activateSearchButton
'-------------------------------------------------------------------------------
function activateSearchButton() as boolean
    setActiveHeaderButton("search")
    return true
end function

'-------------------------------------------------------------------------------
' activateUserMenuButton
'-------------------------------------------------------------------------------
function activateUserMenuButton() as boolean
    setActiveHeaderButton("userMenu")
    return true
end function

'-------------------------------------------------------------------------------
' isSearchButtonActive
'-------------------------------------------------------------------------------
function isSearchButtonActive() as boolean
    return m.searchButton <> invalid and m.searchButton.isActive = true
end function

'-------------------------------------------------------------------------------
' isHomeButtonFocused
'-------------------------------------------------------------------------------
function isHomeButtonFocused() as boolean
    return m.homeButton <> invalid and m.homeButton.isInFocusChain()
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean

    if press = false then return false

    if m.top.menuOpen = true then
        if key = "up" then return m.accountDropdownMenu.callFunc("focusByOffset", -1)
        if key = "down" then return m.accountDropdownMenu.callFunc("focusByOffset", 1)
    end if

    if key = "up" then return trackUsernameUpSequence()

    resetUsernameUpSequence()

    if key = "left" then
        return focusHeaderButtonByOffset(-1)
    else if key = "right" then
        return focusHeaderButtonByOffset(1)
    else if key = "down" then
        closeMenu()
        m.top.downSelected = true
        return true
    else if key = "back" then
        if m.top.menuOpen = true then
            closeMenu()
            return true
        end if

        closeMenu()
        m.top.backSelected = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' trackUsernameUpSequence
'-------------------------------------------------------------------------------
function trackUsernameUpSequence() as boolean
    if m.userMenuButton = invalid or m.userMenuButton.isInFocusChain() = false then
        resetUsernameUpSequence()
        return false
    end if

    m.usernameUpPressCount = m.usernameUpPressCount + 1
    restartUsernameUpSequenceTimer()

    if m.usernameUpPressCount >= 5 then
        resetUsernameUpSequence()
        m.top.overlayRequested = {
            id: "diagnostics"
            componentName: "DiagnosticsDialog"
            closeField: "closeRequested"
            openFunction: "openDiagnostics"
        }
    end if

    return true
end function

'-------------------------------------------------------------------------------
' restartUsernameUpSequenceTimer
'-------------------------------------------------------------------------------
sub restartUsernameUpSequenceTimer()
    if m.usernameUpSequenceTimer = invalid then return

    m.usernameUpSequenceTimer.control = "stop"
    m.usernameUpSequenceTimer.control = "start"
end sub

'-------------------------------------------------------------------------------
' resetUsernameUpSequence
'-------------------------------------------------------------------------------
sub resetUsernameUpSequence()
    m.usernameUpPressCount = 0
    if m.usernameUpSequenceTimer <> invalid then m.usernameUpSequenceTimer.control = "stop"
end sub

'-------------------------------------------------------------------------------
' onUsernameUpSequenceTimerFired
'-------------------------------------------------------------------------------
sub onUsernameUpSequenceTimerFired()
    resetUsernameUpSequence()
end sub

'-------------------------------------------------------------------------------
' focusHeaderButtonByOffset
'-------------------------------------------------------------------------------
function focusHeaderButtonByOffset(offset as integer) as boolean
    headerButtons = m.focusableHeaderButtons
    if headerButtons = invalid or headerButtons.Count() = 0 then return false

    currentIndex = getFocusedHeaderButtonIndex()
    if currentIndex < 0 then
        return focusHeader()
    end if

    nextIndex = currentIndex + offset
    lastIndex = headerButtons.Count() - 1

    if nextIndex < 0 then
        nextIndex = lastIndex
    else if nextIndex > lastIndex then
        nextIndex = 0
    end if

    closeMenu()

    nextButton = headerButtons[nextIndex]
    if nextButton = invalid then return false

    nextButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' rebuildFocusableHeaderButtons
'-------------------------------------------------------------------------------
sub rebuildFocusableHeaderButtons()
    m.focusableHeaderButtons = []

    m.focusableHeaderButtons.Push(m.homeButton)
    m.focusableHeaderButtons.Push(m.searchButton)
    m.focusableHeaderButtons.Push(m.settingsButton)
    m.focusableHeaderButtons.Push(m.userMenuButton)
end sub

'-------------------------------------------------------------------------------
' getFocusedHeaderButtonIndex
'-------------------------------------------------------------------------------
function getFocusedHeaderButtonIndex() as integer
    headerButtons = m.focusableHeaderButtons
    if headerButtons = invalid then return -1

    for i = 0 to headerButtons.Count() - 1
        button = headerButtons[i]
        if button <> invalid and button.isInFocusChain() then return i
    end for

    if isUserMenuInFocusChain() then return headerButtons.Count() - 1

    return -1
end function

'-------------------------------------------------------------------------------
' onCloseMenuRequested
'-------------------------------------------------------------------------------
sub onCloseMenuRequested()
    closeMenu()
end sub

'-------------------------------------------------------------------------------
' onUsernameChanged
'-------------------------------------------------------------------------------
sub onUsernameChanged()
    updateUserMenuButton()
end sub

'-------------------------------------------------------------------------------
' onHomePressed
'-------------------------------------------------------------------------------
sub onHomePressed()
    closeMenu()
    setActiveHeaderButton("home")
    m.top.homeSelected = true
end sub

' onSearchPressed
'-------------------------------------------------------------------------------
sub onSearchPressed()
    closeMenu()
    m.top.searchSelected = true
end sub

'-------------------------------------------------------------------------------
' onSettingsPressed
'-------------------------------------------------------------------------------
sub onSettingsPressed()
    closeMenu()
    requestSettingsOverlay()
end sub

'-------------------------------------------------------------------------------
' setActiveHeaderButton
'-------------------------------------------------------------------------------
sub setActiveHeaderButton(activeButtonName as string)
    m.homeButton.isActive = (activeButtonName = "home")
    m.searchButton.isActive = (activeButtonName = "search")
    m.settingsButton.isActive = false
    m.userMenuButton.isActive = (activeButtonName = "userMenu")
end sub

'-------------------------------------------------------------------------------
' onUserMenuPressed
'-------------------------------------------------------------------------------
sub onUserMenuPressed()
    if m.accountDropdownMenu = invalid then return

    m.accountDropdownMenu.callFunc("toggleMenu")
    syncMenuOpen()
end sub

'-------------------------------------------------------------------------------
' onAccountDropdownItemSelected
'-------------------------------------------------------------------------------
sub onAccountDropdownItemSelected()
    selectedItem = m.accountDropdownMenu.selectedItem
    if selectedItem = invalid then return

    closeMenu()
    if selectedItem.id = "logout" then
        m.top.logoutSelected = true
    end if
end sub

'-------------------------------------------------------------------------------
' requestSettingsOverlay
'-------------------------------------------------------------------------------
sub requestSettingsOverlay()
    m.top.overlayRequested = {
        id: "settings"
        componentName: "SettingsDialog"
        closeField: "closeRequested"
        openFunction: "openSettings"
    }
end sub

'-------------------------------------------------------------------------------
' closeMenu
'-------------------------------------------------------------------------------
sub closeMenu()

    wasUserMenuOpen = isAccountMenuOpen()
    
    closeAccountMenu()
    syncMenuOpen()
    
    if wasUserMenuOpen then
        m.userMenuButton.setFocus(true)
    end if

end sub

'-------------------------------------------------------------------------------
' closeAccountMenu
'-------------------------------------------------------------------------------
sub closeAccountMenu()
    if m.accountDropdownMenu <> invalid then m.accountDropdownMenu.callFunc("closeMenu")
end sub

'-------------------------------------------------------------------------------
' syncMenuOpen
'-------------------------------------------------------------------------------
sub syncMenuOpen()
    m.top.menuOpen = isAccountMenuOpen()
end sub

'-------------------------------------------------------------------------------
' isAccountMenuOpen
'-------------------------------------------------------------------------------
function isAccountMenuOpen() as boolean
    return m.accountDropdownMenu <> invalid and m.accountDropdownMenu.isOpen = true
end function

'-------------------------------------------------------------------------------
' updateUserMenuButton
'-------------------------------------------------------------------------------
sub updateUserMenuButton()
    if m.userMenuButton = invalid then return

    ' leaving this here in case we ever go back to displaying the username
    'buttonText = FirstNonEmpty([m.top.username], "Account")
    'm.userMenuButton.text = buttonText
end sub

'-------------------------------------------------------------------------------
' getAccountDropdownItems
'-------------------------------------------------------------------------------
function getAccountDropdownItems() as object
    return [
        { id: "logout", text: "Logout" }
    ]
end function

'-------------------------------------------------------------------------------
' isUserMenuInFocusChain
'-------------------------------------------------------------------------------
function isUserMenuInFocusChain() as boolean
    if m.accountDropdownMenu = invalid then return false

    return m.accountDropdownMenu.callFunc("isMenuFocused")
end function

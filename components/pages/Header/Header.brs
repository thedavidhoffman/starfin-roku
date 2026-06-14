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
    updateCurrentLibraryButton()
    setActiveHeaderButton("home")
    closeAccountMenu()
    closeLibraryMenu()
    syncMenuOpen()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.headerBg = m.top.findNode("headerBg")
    m.navGroup = m.top.findNode("navGroup")
    m.homeButton = m.top.findNode("homeButton")
    m.libraryButton = m.top.findNode("libraryButton")
    m.seriesButton = m.top.findNode("seriesButton")
    m.searchButton = m.top.findNode("searchButton")
    m.currentLibraryButton = m.top.findNode("currentLibraryButton")
    m.userMenuButton = m.top.findNode("userMenuButton")
    m.accountDropdownMenu = m.top.findNode("accountDropdownMenu")
    m.libraryDropdownMenu = m.top.findNode("libraryDropdownMenu")
    m.usernameUpSequenceTimer = m.top.findNode("usernameUpSequenceTimer")
    m.focusableHeaderButtons = []
end sub

'-------------------------------------------------------------------------------
' initHandlers
'-------------------------------------------------------------------------------
sub initHandlers()
    m.homeButton.observeField("buttonSelected", "onHomePressed")
    m.libraryButton.observeField("buttonSelected", "onLibraryPressed")
    m.seriesButton.observeField("buttonSelected", "onSeriesPressed")
    m.searchButton.observeField("buttonSelected", "onSearchPressed")
    m.currentLibraryButton.observeField("buttonSelected", "onCurrentLibraryPressed")
    m.userMenuButton.observeField("buttonSelected", "onUserMenuPressed")
    m.accountDropdownMenu.observeField("selectedItem", "onAccountDropdownItemSelected")
    m.libraryDropdownMenu.observeField("selectedItem", "onLibraryDropdownItemSelected")
    m.usernameUpSequenceTimer.observeField("fire", "onUsernameUpSequenceTimerFired")
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    palette = Color()
    headerBgColor = palette.background.header
    m.headerBg.color = headerBgColor
    m.homeButton.headerBgColor = headerBgColor
    m.libraryButton.headerBgColor = headerBgColor
    m.seriesButton.headerBgColor = headerBgColor
    m.searchButton.headerBgColor = headerBgColor
    m.currentLibraryButton.headerBgColor = headerBgColor
    m.userMenuButton.headerBgColor = headerBgColor
    m.accountDropdownMenu.headerBgColor = headerBgColor
    m.libraryDropdownMenu.headerBgColor = headerBgColor
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

'-------------------------------------------------------------------------------
' activateLibraryButton
'-------------------------------------------------------------------------------
function activateLibraryButton() as boolean
    setActiveHeaderButton("library")
    return true
end function

'-------------------------------------------------------------------------------
' activateSeriesButton
'-------------------------------------------------------------------------------
function activateSeriesButton() as boolean
    setActiveHeaderButton("series")
    return true
end function

'-------------------------------------------------------------------------------
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

    if isLibraryMenuOpen() then
        if key = "up" then return m.libraryDropdownMenu.callFunc("focusByOffset", -1)
        if key = "down" then return m.libraryDropdownMenu.callFunc("focusByOffset", 1)
    end if

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

    if hasLibraryChoices() then m.focusableHeaderButtons.Push(m.currentLibraryButton)
    m.focusableHeaderButtons.Push(m.homeButton)
    m.focusableHeaderButtons.Push(m.libraryButton)
    m.focusableHeaderButtons.Push(m.seriesButton)
    m.focusableHeaderButtons.Push(m.searchButton)
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

    if isLibraryMenuInFocusChain() and hasLibraryChoices() then return 0
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
' onLibrariesChanged
'-------------------------------------------------------------------------------
sub onLibrariesChanged()
    updateCurrentLibraryButton()
    rebuildFocusableHeaderButtons()
    updateNavGroupPosition()
    updateLibraryDropdownItems()
end sub

'-------------------------------------------------------------------------------
' onCurrentLibraryIdChanged
'-------------------------------------------------------------------------------
sub onCurrentLibraryIdChanged()
    updateCurrentLibraryButton()
    updateNavGroupPosition()
end sub

'-------------------------------------------------------------------------------
' onHomePressed
'-------------------------------------------------------------------------------
sub onHomePressed()
    closeMenu()
    setActiveHeaderButton("home")
    m.top.homeSelected = true
end sub

'-------------------------------------------------------------------------------
' onLibraryPressed
'-------------------------------------------------------------------------------
sub onLibraryPressed()
    closeMenu()
    setActiveHeaderButton("library")
    m.top.librarySelected = true
end sub

'-------------------------------------------------------------------------------
' onSeriesPressed
'-------------------------------------------------------------------------------
sub onSeriesPressed()
    closeMenu()
    setActiveHeaderButton("series")
    m.top.seriesSelected = true
end sub

'-------------------------------------------------------------------------------
' onSearchPressed
'-------------------------------------------------------------------------------
sub onSearchPressed()
    closeMenu()
    m.top.searchSelected = true
end sub

'-------------------------------------------------------------------------------
' onCurrentLibraryPressed
'-------------------------------------------------------------------------------
sub onCurrentLibraryPressed()
    if hasLibraryChoices() = false then return
    closeAccountMenu()
    if m.libraryDropdownMenu = invalid then return

    wasOpen = isLibraryMenuOpen()
    m.libraryDropdownMenu.callFunc("toggleMenu")
    syncMenuOpen()
    if wasOpen = false and isLibraryMenuOpen() then focusCurrentLibraryMenuButton()
end sub

'-------------------------------------------------------------------------------
' setActiveHeaderButton
'-------------------------------------------------------------------------------
sub setActiveHeaderButton(activeButtonName as string)
    m.homeButton.isActive = (activeButtonName = "home")
    m.libraryButton.isActive = (activeButtonName = "library")
    m.seriesButton.isActive = (activeButtonName = "series")
    m.searchButton.isActive = (activeButtonName = "search")
    m.userMenuButton.isActive = (activeButtonName = "userMenu")
end sub

'-------------------------------------------------------------------------------
' onUserMenuPressed
'-------------------------------------------------------------------------------
sub onUserMenuPressed()
    closeLibraryMenu()
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
    if selectedItem.id = "settings" then
        m.top.overlayRequested = {
            id: "settings"
            componentName: "SettingsDialog"
            closeField: "closeRequested"
            openFunction: "openSettings"
        }
    else if selectedItem.id = "yourStats" then
        m.top.yourStatsSelected = true
    else if selectedItem.id = "logout" then
        m.top.logoutSelected = true
    end if
end sub

'-------------------------------------------------------------------------------
' onLibraryDropdownItemSelected
'-------------------------------------------------------------------------------
sub onLibraryDropdownItemSelected()
    selectedItem = m.libraryDropdownMenu.selectedItem
    if selectedItem = invalid then return

    closeLibraryMenu()
    syncMenuOpen()
    m.currentLibraryButton.setFocus(true)

    m.top.currentLibrarySelected = {
        id: selectedItem.id
        name: selectedItem.text
    }
end sub

'-------------------------------------------------------------------------------
' closeMenu
'-------------------------------------------------------------------------------
sub closeMenu()

    wasLibraryMenuOpen = isLibraryMenuOpen()
    wasUserMenuOpen = isAccountMenuOpen()
    
    closeAccountMenu()
    closeLibraryMenu()
    syncMenuOpen()
    
    if wasUserMenuOpen then
        m.userMenuButton.setFocus(true)
    else if wasLibraryMenuOpen then
        m.currentLibraryButton.setFocus(true)
    end if

end sub

'-------------------------------------------------------------------------------
' closeAccountMenu
'-------------------------------------------------------------------------------
sub closeAccountMenu()
    if m.accountDropdownMenu <> invalid then m.accountDropdownMenu.callFunc("closeMenu")
end sub

'-------------------------------------------------------------------------------
' closeLibraryMenu
'-------------------------------------------------------------------------------
sub closeLibraryMenu()
    if m.libraryDropdownMenu <> invalid then m.libraryDropdownMenu.callFunc("closeMenu")
end sub

'-------------------------------------------------------------------------------
' syncMenuOpen
'-------------------------------------------------------------------------------
sub syncMenuOpen()
    m.top.menuOpen = isAccountMenuOpen() or isLibraryMenuOpen()
end sub

'-------------------------------------------------------------------------------
' isLibraryMenuOpen
'-------------------------------------------------------------------------------
function isLibraryMenuOpen() as boolean
    return m.libraryDropdownMenu <> invalid and m.libraryDropdownMenu.isOpen = true
end function

'-------------------------------------------------------------------------------
' isAccountMenuOpen
'-------------------------------------------------------------------------------
function isAccountMenuOpen() as boolean
    return m.accountDropdownMenu <> invalid and m.accountDropdownMenu.isOpen = true
end function

'-------------------------------------------------------------------------------
' hasLibraryChoices
'-------------------------------------------------------------------------------
function hasLibraryChoices() as boolean
    return m.top.libraries <> invalid and m.top.libraries.Count() > 1
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
' updateCurrentLibraryButton
'-------------------------------------------------------------------------------
sub updateCurrentLibraryButton()
    if m.currentLibraryButton = invalid then return

    m.currentLibraryButton.text = getCurrentLibraryName()
    m.currentLibraryButton.visible = hasLibraryChoices()
end sub

'-------------------------------------------------------------------------------
' getAccountDropdownItems
'-------------------------------------------------------------------------------
function getAccountDropdownItems() as object
    return [
        { id: "settings", text: "Settings" }
        { id: "yourStats", text: "Your Stats" }
        { id: "logout", text: "Logout" }
    ]
end function

'-------------------------------------------------------------------------------
' updateNavGroupPosition
'-------------------------------------------------------------------------------
sub updateNavGroupPosition()

    ' x,y translations for the navGroup based on whether we have multiple
    ' libraries (in which case the library button is displayed) or there
    ' is only one library (in which case the library button is not displayed)
    if hasLibraryChoices() then
        m.navGroup.translation = [632, 22]
    else
        m.navGroup.translation = [526, 22]
    end if

end sub

'-------------------------------------------------------------------------------
' getCurrentLibraryName
'-------------------------------------------------------------------------------
function getCurrentLibraryName() as string
    libraries = m.top.libraries
    if libraries <> invalid then
        for each library in libraries
            if library <> invalid and library.id = m.top.currentLibraryId then
                return FirstNonEmpty([library.name], "Library")
            end if
        end for

        if libraries.Count() > 0 and libraries[0] <> invalid then
            return FirstNonEmpty([libraries[0].name], "Library")
        end if
    end if

    return "Library"
end function

'-------------------------------------------------------------------------------
' updateLibraryDropdownItems
'-------------------------------------------------------------------------------
sub updateLibraryDropdownItems()
    libraries = m.top.libraries
    items = []

    if libraries <> invalid then
        for each library in libraries
            if library <> invalid and library.id <> invalid then
                items.Push({
                    id: library.id
                    text: FirstNonEmpty([library.name], "Library")
                    payload: library
                })
            end if
        end for
    end if

    if m.libraryDropdownMenu <> invalid then m.libraryDropdownMenu.items = items
end sub

'-------------------------------------------------------------------------------
' focusCurrentLibraryMenuButton
'-------------------------------------------------------------------------------
sub focusCurrentLibraryMenuButton()
    if m.libraryDropdownMenu = invalid then return

    if m.top.currentLibraryId <> invalid and m.top.currentLibraryId <> "" then
        if m.libraryDropdownMenu.callFunc("focusItemById", m.top.currentLibraryId) then return
    end if

    libraries = m.top.libraries
    if libraries <> invalid and libraries.Count() > 0 and libraries[0] <> invalid then
        if libraries[0].id <> invalid then
            if m.libraryDropdownMenu.callFunc("focusItemById", libraries[0].id) then return
        end if
    end if

    m.libraryDropdownMenu.callFunc("focusFirstItem")
end sub

'-------------------------------------------------------------------------------
' isLibraryMenuInFocusChain
'-------------------------------------------------------------------------------
function isLibraryMenuInFocusChain() as boolean
    if m.libraryDropdownMenu = invalid then return false

    return m.libraryDropdownMenu.callFunc("isMenuFocused")
end function

'-------------------------------------------------------------------------------
' isUserMenuInFocusChain
'-------------------------------------------------------------------------------
function isUserMenuInFocusChain() as boolean
    if m.accountDropdownMenu = invalid then return false

    return m.accountDropdownMenu.callFunc("isMenuFocused")
end function

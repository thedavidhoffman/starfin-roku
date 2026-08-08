'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.accountRows = m.top.findNode("accountRows")
    m.leftChevron = m.top.findNode("leftChevron")
    m.rightChevron = m.top.findNode("rightChevron")
    m.signInButton = m.top.findNode("signInButton")
    m.accountRows.observeField("rowItemSelected", "onAccountSelected")
    m.accountRows.observeField("rowItemFocused", "onAccountFocused")
    m.accountRows.observeField("focusExitDown", "onAccountRowsFocusExitDown")
    m.signInButton.observeField("buttonSelected", "onSignInSelected")
    m.accountState = {
        rowItem: [0, 0]
        windowStart: 0
    }
    m.layoutState = {
        itemWidth: 246
        itemSpacing: -15
        visibleItemCount: 3
        chevronSize: 48
    }
    layoutContent()
    renderAccounts()
end sub

'-------------------------------------------------------------------------------
' onAccountsChanged
'-------------------------------------------------------------------------------
sub onAccountsChanged()
    renderAccounts()
end sub

'-------------------------------------------------------------------------------
' renderAccounts
'-------------------------------------------------------------------------------
sub renderAccounts()
    m.accountState.windowStart = 0
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")
    accounts = m.top.accounts
    if accounts = invalid then accounts = []

    for each account in accounts
        item = row.createChild("ContentNode")
        item.title = SafeString(account.username, "Account")
        if account.isActive = true then item.description = "Active" else item.description = ""
        item.HDPosterUrl = buildAccountImageUri(account)
        item.AddFields({ account: account })
    end for

    m.accountRows.content = content
    m.accountRows.visible = row.getChildCount() > 0
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' layoutContent
'-------------------------------------------------------------------------------
sub layoutContent()
    contentWidth = Number_ToInteger(m.top.contentWidth, 800)
    itemStride = m.layoutState.itemWidth + m.layoutState.itemSpacing
    rowWidth = itemStride * m.layoutState.visibleItemCount
    rowX = Number_ToInteger((contentWidth - rowWidth) / 2, 0)
    m.accountRows.translation = [rowX, 0]
    m.accountRows.itemSize = [rowWidth, 264]
    m.leftChevron.translation = [0, 74]
    m.rightChevron.translation = [contentWidth - m.layoutState.chevronSize, 74]

    buttonWidth = m.signInButton.callFunc("getPreferredWidth", 30)
    m.signInButton.buttonWidth = buttonWidth
    buttonX = Number_ToInteger((contentWidth - buttonWidth) / 2, 0)
    m.signInButton.translation = [buttonX, 330]
end sub

'-------------------------------------------------------------------------------
' onAccountFocused
'-------------------------------------------------------------------------------
sub onAccountFocused()
    saveFocusedAccount()
    updateChevrons()
end sub

'-------------------------------------------------------------------------------
' updateChevrons
'-------------------------------------------------------------------------------
sub updateChevrons()
    overflow = getAccountOverflowState()
    m.leftChevron.visible = overflow.left
    m.rightChevron.visible = overflow.right
end sub

'-------------------------------------------------------------------------------
' getAccountOverflowState
'-------------------------------------------------------------------------------
function getAccountOverflowState() as object
    state = { left: false, right: false }
    visibleItemCount = m.layoutState.visibleItemCount

    if m.accountRows.content = invalid then return state
    if m.accountRows.content.getChildCount() = 0 then return state

    row = m.accountRows.content.getChild(0)
    if row = invalid then return state

    itemCount = row.getChildCount()
    if itemCount <= visibleItemCount then return state

    focused = m.accountRows.rowItemFocused
    finalWindowStart = itemCount - visibleItemCount
    windowStart = m.accountState.windowStart
    if windowStart = invalid then windowStart = 0

    if focused <> invalid and focused.Count() >= 2 then
        focusedIndex = focused[1]
        if focusedIndex < windowStart then
            windowStart = focusedIndex
        else if focusedIndex >= windowStart + visibleItemCount then
            windowStart = focusedIndex - visibleItemCount + 1
        end if
    end if

    if windowStart < 0 then windowStart = 0
    if windowStart > finalWindowStart then windowStart = finalWindowStart
    m.accountState.windowStart = windowStart

    state.left = windowStart > 0
    state.right = (windowStart + visibleItemCount) < itemCount
    return state
end function

'-------------------------------------------------------------------------------
' buildAccountImageUri
'-------------------------------------------------------------------------------
function buildAccountImageUri(account as object) as string
    return AccountImage_GetUri(account, 195, 195)
end function

'-------------------------------------------------------------------------------
' focusAccounts
'-------------------------------------------------------------------------------
function focusAccounts() as boolean
    m.signInButton.hasFocusVisual = false
    if m.accountRows.visible = true then
        m.accountRows.jumpToRowItem = getValidRowItem(m.accountState.rowItem)
        m.accountRows.drawFocusFeedback = true
        m.accountRows.setFocus(true)
        return true
    end if

    return focusSignInButton()
end function

'-------------------------------------------------------------------------------
' focusSignInButton
'-------------------------------------------------------------------------------
function focusSignInButton() as boolean
    m.accountRows.drawFocusFeedback = false
    m.signInButton.focusable = true
    m.signInButton.setFocus(true)
    m.signInButton.hasFocusVisual = true
    return true
end function

'-------------------------------------------------------------------------------
' onAccountRowsFocusExitDown
'-------------------------------------------------------------------------------
sub onAccountRowsFocusExitDown()
    saveFocusedAccount()
    focusSignInButton()
end sub

'-------------------------------------------------------------------------------
' onAccountSelected
'-------------------------------------------------------------------------------
sub onAccountSelected()
    selected = m.accountRows.rowItemSelected
    if selected = invalid or selected.Count() < 2 then return
    row = m.accountRows.content.getChild(selected[0])
    if row = invalid then return
    item = row.getChild(selected[1])
    if item = invalid or item.account = invalid then return
    m.accountState.rowItem = selected
    m.top.accountSelected = item.account
end sub

'-------------------------------------------------------------------------------
' onSignInSelected
'-------------------------------------------------------------------------------
sub onSignInSelected()
    m.top.signInSelected = true
end sub

'-------------------------------------------------------------------------------
' saveFocusedAccount
'-------------------------------------------------------------------------------
sub saveFocusedAccount()
    focused = getValidRowItem(m.accountRows.rowItemFocused)
    if focused <> invalid then m.accountState.rowItem = focused
end sub

'-------------------------------------------------------------------------------
' getValidRowItem
'-------------------------------------------------------------------------------
function getValidRowItem(rowItem as dynamic) as object
    if rowItem = invalid or rowItem.Count() < 2 then return [0, 0]
    if m.accountRows.content = invalid or m.accountRows.content.getChildCount() = 0 then return [0, 0]
    row = m.accountRows.content.getChild(0)
    if row = invalid or row.getChildCount() = 0 then return [0, 0]
    index = rowItem[1]
    if index < 0 then index = 0
    if index >= row.getChildCount() then index = row.getChildCount() - 1
    return [0, index]
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if m.signInButton.isInFocusChain() and key = "up" and m.accountRows.visible = true then
        m.signInButton.hasFocusVisual = false
        return focusAccounts()
    end if
    return false
end function

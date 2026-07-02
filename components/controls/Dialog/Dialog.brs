'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.dialog = m.top.findNode("dialog")
    m.panel = m.top.findNode("panel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.titleRule = m.top.findNode("titleRule")
    m.content = m.top.findNode("content")
    m.footer = m.top.findNode("footer")
    m.saveButton = m.top.findNode("saveButton")
    m.cancelButton = m.top.findNode("cancelButton")
    initStyle()
    updateDialogSize()
    updateTitle()
    updateContentComponent()
    updateButtonVisibility()
    updateButtonText()
end sub

'-------------------------------------------------------------------------------
' openDialog
'-------------------------------------------------------------------------------
sub openDialog()
    if m.dialog = invalid then return

    updateTitle()
    m.dialog.visible = true
    m.top.setFocus(true)
    focusContent()
end sub

'-------------------------------------------------------------------------------
' closeDialog
'-------------------------------------------------------------------------------
sub closeDialog()
    if m.dialog <> invalid then m.dialog.visible = false

    onCloseRequested()
    m.top.closeRequested = true
end sub

'-------------------------------------------------------------------------------
' getContentComponent
'-------------------------------------------------------------------------------
function getContentComponent() as object
    return m.contentComponent
end function

'-------------------------------------------------------------------------------
' focusContent
'-------------------------------------------------------------------------------
function focusContent() as boolean
    updateButtonFocus("")
    if m.contentComponent <> invalid and m.contentComponent.focusable = true then
        m.contentComponent.setFocus(true)
        return true
    end if

    m.top.setFocus(true)
    return false
end function

'-------------------------------------------------------------------------------
' focusSaveButton
'-------------------------------------------------------------------------------
function focusSaveButton() as boolean
    if hasButtons() = false or m.saveButton = invalid then return false

    updateButtonFocus("save")
    m.saveButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' focusCancelButton
'-------------------------------------------------------------------------------
function focusCancelButton() as boolean
    if hasButtons() = false or m.cancelButton = invalid then return false

    updateButtonFocus("cancel")
    m.cancelButton.setFocus(true)
    return true
end function

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    if m.footer <> invalid then m.footer.color = &h00000040
    if m.titleRule <> invalid then m.titleRule.color = &hF3F7FB33
end sub

'-------------------------------------------------------------------------------
' onTitleChanged
'-------------------------------------------------------------------------------
sub onTitleChanged()
    updateTitle()
end sub

'-------------------------------------------------------------------------------
' onDialogSizeChanged
'-------------------------------------------------------------------------------
sub onDialogSizeChanged()
    updateDialogSize()
end sub

'-------------------------------------------------------------------------------
' onContentComponentNameChanged
'-------------------------------------------------------------------------------
sub onContentComponentNameChanged()
    updateContentComponent()
end sub

'-------------------------------------------------------------------------------
' onShowButtonsChanged
'-------------------------------------------------------------------------------
sub onShowButtonsChanged()
    updateButtonVisibility()
    updateDialogSize()
end sub

'-------------------------------------------------------------------------------
' onButtonTextChanged
'-------------------------------------------------------------------------------
sub onButtonTextChanged()
    updateButtonText()
end sub

'-------------------------------------------------------------------------------
' updateContentComponent
'-------------------------------------------------------------------------------
sub updateContentComponent()
    if m.content = invalid then return

    if m.contentComponent <> invalid then
        m.content.removeChild(m.contentComponent)
        m.contentComponent = invalid
    end if

    componentName = m.top.contentComponentName
    if componentName = invalid or componentName = "" then return

    m.contentComponent = CreateObject("roSGNode", componentName)
    if m.contentComponent <> invalid then m.content.appendChild(m.contentComponent)
end sub

'-------------------------------------------------------------------------------
' hasButtons
'-------------------------------------------------------------------------------
function hasButtons() as boolean
    return m.top.showButtons = true
end function

'-------------------------------------------------------------------------------
' updateButtonVisibility
'-------------------------------------------------------------------------------
sub updateButtonVisibility()
    isVisible = hasButtons()
    if m.footer <> invalid then m.footer.visible = isVisible
    if m.saveButton <> invalid then m.saveButton.visible = isVisible
    if m.cancelButton <> invalid then m.cancelButton.visible = isVisible
    if isVisible = false then updateButtonFocus("")
end sub

'-------------------------------------------------------------------------------
' updateButtonText
'-------------------------------------------------------------------------------
sub updateButtonText()
    if m.saveButton <> invalid then m.saveButton.text = getButtonText(m.top.saveButtonText, "Save")
    if m.cancelButton <> invalid then m.cancelButton.text = getButtonText(m.top.cancelButtonText, "Cancel")
end sub

'-------------------------------------------------------------------------------
' getButtonText
'-------------------------------------------------------------------------------
function getButtonText(value as dynamic, defaultValue as string) as string
    if value = invalid or value = "" then return defaultValue
    return value
end function

'-------------------------------------------------------------------------------
' updateButtonFocus
'-------------------------------------------------------------------------------
sub updateButtonFocus(focusedButton as string)
    if m.saveButton <> invalid then m.saveButton.hasFocusVisual = (focusedButton = "save")
    if m.cancelButton <> invalid then m.cancelButton.hasFocusVisual = (focusedButton = "cancel")
end sub

'-------------------------------------------------------------------------------
' updateDialogSize
'-------------------------------------------------------------------------------
sub updateDialogSize()
    dialogWidth = getDialogSizeValue(m.top.dialogWidth, 1680)
    dialogHeight = getDialogSizeValue(m.top.dialogHeight, 900)
    panelX = getDialogPositionValue(m.top.panelX, int((1920 - dialogWidth) / 2))
    panelY = getDialogPositionValue(m.top.panelY, int((1080 - dialogHeight) / 2))
    contentMargin = 60
    innerWidth = dialogWidth - (contentMargin * 2)
    if innerWidth < 0 then innerWidth = dialogWidth

    if m.panel <> invalid then
        m.panel.translation = [panelX, panelY]
        m.panel.width = dialogWidth
        m.panel.height = dialogHeight
    end if

    if m.titleLabel <> invalid then
        m.titleLabel.translation = [panelX + contentMargin, panelY + 55]
        m.titleLabel.width = innerWidth
    end if

    if m.titleRule <> invalid then
        m.titleRule.translation = [panelX + contentMargin, panelY + 110]
        m.titleRule.width = innerWidth
    end if

    if m.content <> invalid then
        m.content.translation = [panelX + contentMargin, panelY + 170]
    end if

    if m.footer <> invalid then
        m.footer.translation = [panelX, panelY + dialogHeight - 120]
        m.footer.width = dialogWidth
        m.footer.height = 120
    end if

    if m.saveButton <> invalid then
        m.saveButton.translation = [panelX + contentMargin, panelY + dialogHeight - 90]
    end if

    if m.cancelButton <> invalid then
        m.cancelButton.translation = [panelX + contentMargin + 140, panelY + dialogHeight - 90]
    end if
end sub

'-------------------------------------------------------------------------------
' getDialogSizeValue
'-------------------------------------------------------------------------------
function getDialogSizeValue(value as dynamic, defaultValue as integer) as integer
    if value = invalid or value <= 0 then return defaultValue
    return value
end function

'-------------------------------------------------------------------------------
' getDialogPositionValue
'-------------------------------------------------------------------------------
function getDialogPositionValue(value as dynamic, defaultValue as integer) as integer
    if value = invalid or value < 0 then return defaultValue
    return value
end function

'-------------------------------------------------------------------------------
' updateTitle
'-------------------------------------------------------------------------------
sub updateTitle()
    if m.titleLabel = invalid then return

    if m.top.title <> invalid and m.top.title <> "" then
        m.titleLabel.text = m.top.title
    else
        m.titleLabel.text = "Dialog"
    end if
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false
    if m.dialog = invalid or m.dialog.visible = false then return false

    if key = "back" then
        closeDialog()
        return true
    end if

    if hasButtons() then
        if m.contentComponent <> invalid and m.contentComponent.isInFocusChain() then
            if key = "down" and contentCanMoveToButtons() then return focusSaveButton()
            return false
        end if

        if m.saveButton <> invalid and m.saveButton.isInFocusChain() then
            if key = "up" then return focusContentLastField()
            if key = "right" then return focusCancelButton()
            if key = "OK" or key = "select" then
                m.top.saveSelected = true
                onSaveSelected()
                return true
            end if
        end if

        if m.cancelButton <> invalid and m.cancelButton.isInFocusChain() then
            if key = "up" then return focusContentLastField()
            if key = "left" then return focusSaveButton()
            if key = "OK" or key = "select" then
                m.top.cancelSelected = true
                closeDialog()
                return true
            end if
        end if

        return false
    end if

    if key = "OK" or key = "select" then
        closeDialog()
        return true
    end if

    return true
end function

'-------------------------------------------------------------------------------
' onSaveSelected
'-------------------------------------------------------------------------------
sub onSaveSelected()
end sub

'-------------------------------------------------------------------------------
' onCloseRequested
'-------------------------------------------------------------------------------
sub onCloseRequested()
end sub

'-------------------------------------------------------------------------------
' contentCanMoveToButtons
'-------------------------------------------------------------------------------
function contentCanMoveToButtons() as boolean
    if m.contentComponent = invalid then return true

    canMove = m.contentComponent.callFunc("canMoveFocusToButtons")
    if canMove = invalid then return true
    return canMove
end function

'-------------------------------------------------------------------------------
' focusContentLastField
'-------------------------------------------------------------------------------
function focusContentLastField() as boolean
    updateButtonFocus("")
    if m.contentComponent <> invalid then
        m.contentComponent.callFunc("focusLastField")
        return true
    end if

    return focusContent()
end function

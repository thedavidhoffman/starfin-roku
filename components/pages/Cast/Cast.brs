'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.castRows = m.top.findNode("castRows")
    m.castRows.observeField("focusExitUp", "onCastRowsFocusExitUp")
    m.castRows.observeField("rowItemFocused", "onCastRowItemFocused")
    m.castRows.observeField("rowItemSelected", "onCastRowItemSelected")
    m.focusState = {
        rowItem: [0, 0]
    }
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' onCastChanged
'-------------------------------------------------------------------------------
sub onCastChanged()
    people = m.top.people
    content = CreateObject("roSGNode", "ContentNode")
    row = content.createChild("ContentNode")

    if people <> invalid then
        for each person in people
            if isAssocArray(person) = false then continue for

            personName = FirstNonEmpty([person.Name, person.name], "")
            if personName = "" then continue for

            personNode = row.createChild("ContentNode")
            personNode.title = personName
            personNode.description = getPersonSubtitle(person)
            personNode.HDPosterUrl = getPersonImageUrl(person)
            personNode.AddFields({
                itemId: FirstNonEmpty([person.Id, person.id], "")
                raw: person
            })
        end for
    end if

    m.castRows.content = content
    m.top.hasItems = row.getChildCount() > 0
    m.top.visible = m.top.hasItems
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    if m.top.hasItems = true then
        m.castRows.drawFocusFeedback = true
        restoreLastFocusedCastItem()
        m.castRows.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.castRows.setFocus(false)
    m.castRows.drawFocusFeedback = false
end sub

'-------------------------------------------------------------------------------
' onCastRowsFocusExitUp
'-------------------------------------------------------------------------------
sub onCastRowsFocusExitUp()
    m.top.focusExitUp = true
end sub

'-------------------------------------------------------------------------------
' onCastRowItemFocused
'-------------------------------------------------------------------------------
sub onCastRowItemFocused()
    saveFocusedCastItem(m.castRows.rowItemFocused)
end sub

'-------------------------------------------------------------------------------
' onCastRowItemSelected
'-------------------------------------------------------------------------------
sub onCastRowItemSelected()
    selected = m.castRows.rowItemSelected
    saveFocusedCastItem(selected)
    if selected = invalid or selected.Count() < 2 then return
    if m.castRows.content = invalid then return

    row = m.castRows.content.getChild(selected[0])
    if row = invalid then return

    itemNode = row.getChild(selected[1])
    if itemNode = invalid then return

    personId = SafeString(itemNode.itemId, "")
    if personId = "" then return

    m.top.selectedPerson = {
        itemId: personId
        item: itemNode.raw
    }
end sub

'-------------------------------------------------------------------------------
' restoreLastFocusedCastItem
'-------------------------------------------------------------------------------
sub restoreLastFocusedCastItem()
    rowItem = getValidRowItem(m.focusState.rowItem)
    if rowItem = invalid then return

    m.castRows.jumpToRowItem = rowItem
end sub

'-------------------------------------------------------------------------------
' saveFocusedCastItem
'-------------------------------------------------------------------------------
sub saveFocusedCastItem(rowItem as dynamic)
    rowItem = getValidRowItem(rowItem)
    if rowItem = invalid then return

    m.focusState.rowItem = rowItem
end sub

'-------------------------------------------------------------------------------
' getValidRowItem
'-------------------------------------------------------------------------------
function getValidRowItem(rowItem as dynamic) as dynamic
    if rowItem = invalid or rowItem.Count() < 2 then return invalid
    if m.castRows.content = invalid then return invalid

    rowIndex = rowItem[0]
    itemIndex = rowItem[1]
    if rowIndex < 0 or itemIndex < 0 then return invalid
    if rowIndex >= m.castRows.content.getChildCount() then return invalid

    row = m.castRows.content.getChild(rowIndex)
    if row = invalid then return invalid
    if itemIndex >= row.getChildCount() then return invalid

    return [rowIndex, itemIndex]
end function

'-------------------------------------------------------------------------------
' getPersonSubtitle
'-------------------------------------------------------------------------------
function getPersonSubtitle(person as object) as string
    personType = FirstNonEmpty([person.Type, person.type], "Unknown")
    role = FirstNonEmpty([person.Role, person.role], "")

    if LCase(personType) = "actor" and role <> "" then return role
    return personType
end function

'-------------------------------------------------------------------------------
' getPersonImageUrl
'-------------------------------------------------------------------------------
function getPersonImageUrl(person as object) as string
    personId = FirstNonEmpty([person.Id, person.id], "")
    tag = FirstNonEmpty([person.PrimaryImageTag, person.primaryImageTag], "")
    if personId = "" or tag = "" then return ""

    return NormalizeServerUrl(m.top.server) + "/Items/" + personId + "/Images/Primary?tag=" + tag + "&maxWidth=195&maxHeight=195&quality=90"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

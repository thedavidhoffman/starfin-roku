'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.castRows = m.top.findNode("castRows")
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
        m.castRows.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "up" then
        m.top.focusExitUp = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' getPersonSubtitle
'-------------------------------------------------------------------------------
function getPersonSubtitle(person as object) as string
    personType = FirstNonEmpty([person.Type, person.type], "Unknown")
    role = FirstNonEmpty([person.Role, person.role], "")

    if LCase(personType) = "actor" and role <> "" then return "as " + role
    return personType
end function

'-------------------------------------------------------------------------------
' getPersonImageUrl
'-------------------------------------------------------------------------------
function getPersonImageUrl(person as object) as string
    personId = FirstNonEmpty([person.Id, person.id], "")
    tag = FirstNonEmpty([person.PrimaryImageTag, person.primaryImageTag], "")
    if personId = "" or tag = "" then return ""

    return NormalizeServerUrl(m.top.server) + "/Items/" + personId + "/Images/Primary?tag=" + tag + "&maxWidth=195&maxHeight=250&quality=90"
end function

'-------------------------------------------------------------------------------
' isAssocArray
'-------------------------------------------------------------------------------
function isAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
end function

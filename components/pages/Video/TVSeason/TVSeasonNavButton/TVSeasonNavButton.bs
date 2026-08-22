'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    initReferences()
    m.state = {
        isFocused: false
    }
    m.assets = {
        restBg: "pkg:/images/buttons/tv-season-nav-button-unfocused.9.png"
        focusBg: "pkg:/images/buttons/tv-season-nav-button-focused.9.png"
    }
    updateStyles()
end sub

'-------------------------------------------------------------------------------
' initReferences
'-------------------------------------------------------------------------------
sub initReferences()
    m.bg = m.top.findNode("bg")
    m.previousChevron = m.top.findNode("previousChevron")
    m.nextChevron = m.top.findNode("nextChevron")
end sub

'-------------------------------------------------------------------------------
' onSeasonAvailabilityChanged
'-------------------------------------------------------------------------------
sub onSeasonAvailabilityChanged()
    updateStyles()
end sub

'-------------------------------------------------------------------------------
' activate
'-------------------------------------------------------------------------------
sub activate()
    m.state.isFocused = true
    m.top.setFocus(true)
    updateStyles()
end sub

'-------------------------------------------------------------------------------
' deactivate
'-------------------------------------------------------------------------------
sub deactivate()
    m.state.isFocused = false
    updateStyles()
end sub

'-------------------------------------------------------------------------------
' updateStyles
'-------------------------------------------------------------------------------
sub updateStyles()
    m.top.visible = m.top.hasPreviousSeason = true or m.top.hasNextSeason = true
    m.bg.visible = true
    if m.state.isFocused = true then
        m.bg.uri = m.assets.focusBg
    else
        m.bg.uri = m.assets.restBg
    end if

    m.previousChevron.visible = true
    m.nextChevron.visible = true

    m.previousChevron.opacity = getChevronOpacity(m.top.hasPreviousSeason = true)
    m.nextChevron.opacity = getChevronOpacity(m.top.hasNextSeason = true)
end sub

'-------------------------------------------------------------------------------
' getChevronOpacity
'-------------------------------------------------------------------------------
function getChevronOpacity(isAvailable as boolean) as float
    if m.state.isFocused = true and isAvailable = true then return 1.0
    return 0.35
end function

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "left" and m.top.hasPreviousSeason = true then
        m.top.previousSeasonSelected = true
        return true
    end if

    if key = "right" and m.top.hasNextSeason = true then
        m.top.nextSeasonSelected = true
        return true
    end if

    return false
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.episodeImageColumn = m.top.findNode("episodeImageColumn")
    m.episodeItem = m.top.findNode("episodeItem")
    m.panel = m.top.findNode("panel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.optionsList = m.top.findNode("optionsList")
    m.optionKeys = ["markWatched", "markUnwatched", "subtitles", "audio", "episodeInfo"]

    initStyles()
    initOptions()
    m.episodeItem.visible = false
    m.top.visible = false
end sub

'-------------------------------------------------------------------------------
' onEpisodeItemContentChanged
'-------------------------------------------------------------------------------
sub onEpisodeItemContentChanged()
    m.episodeItem.itemContent = m.top.episodeItemContent
    m.episodeItem.visible = m.top.episodeItemContent <> invalid
end sub

'-------------------------------------------------------------------------------
' onEpisodeImageColumnXChanged
'-------------------------------------------------------------------------------
sub onEpisodeImageColumnXChanged()
    m.episodeImageColumn.translation = [m.top.episodeImageColumnX, 0]
end sub

'-------------------------------------------------------------------------------
' onEpisodeItemXChanged
'-------------------------------------------------------------------------------
sub onEpisodeItemXChanged()
    m.episodeItem.translation = [m.top.episodeItemX, 324]
end sub

'-------------------------------------------------------------------------------
' initStyles
'-------------------------------------------------------------------------------
sub initStyles()
    colors = Color()
    m.titleLabel.color = colors.text.primary
    m.optionsList.color = colors.text.secondary
    m.optionsList.focusedColor = colors.text.primary
end sub

'-------------------------------------------------------------------------------
' initOptions
'-------------------------------------------------------------------------------
sub initOptions()
    content = CreateObject("roSGNode", "ContentNode")

    for each title in ["Mark as Watched", "Mark as Unwatched", "Subtitles", "Audio", "Episode Info"]
        item = content.createChild("ContentNode")
        item.title = title
    end for

    m.optionsList.content = content
    m.optionsList.observeField("itemSelected", "onOptionSelected")
end sub

'-------------------------------------------------------------------------------
' open
'-------------------------------------------------------------------------------
sub open()
    m.top.visible = true
    m.optionsList.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' close
'-------------------------------------------------------------------------------
sub close()
    m.top.visible = false
    m.episodeItem.visible = false
    m.top.closeRequested = true
end sub

'-------------------------------------------------------------------------------
' onOptionSelected
'-------------------------------------------------------------------------------
sub onOptionSelected()
    selectedIndex = m.optionsList.itemSelected
    if selectedIndex = invalid then return
    if selectedIndex < 0 or selectedIndex >= m.optionKeys.Count() then return

    m.top.optionSelected = {
        key: m.optionKeys[selectedIndex]
        episode: m.top.episodeContent
    }
end sub

'-------------------------------------------------------------------------------
' onKeyEvent
'-------------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "back" or key = "options" then
        close()
        return true
    end if

    return false
end function

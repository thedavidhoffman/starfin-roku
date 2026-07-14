'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.showLogo = m.top.findNode("showLogo")
    m.seriesLabel = m.top.findNode("seriesLabel")
    render()
end sub

'-------------------------------------------------------------------------------
' render
'-------------------------------------------------------------------------------
sub render()
    logoUrl = SafeString(m.top.logoUrl, "")
    m.showLogo.visible = logoUrl <> ""
    m.showLogo.uri = logoUrl
    m.seriesLabel.visible = logoUrl = ""
    m.seriesLabel.text = SafeString(m.top.title, "")
end sub

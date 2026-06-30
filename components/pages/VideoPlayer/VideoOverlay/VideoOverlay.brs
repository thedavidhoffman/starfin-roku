'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.metaLabel = m.top.findNode("metaLabel")

    colors = Color()
    m.titleLabel.color = colors.text.light.primary
    m.subtitleLabel.color = colors.text.light.primary
    m.metaLabel.color = colors.text.light.secondary

    onTitleChanged()
    onSubtitleChanged()
    onMetaChanged()
end sub

'-------------------------------------------------------------------------------
' onTitleChanged
'-------------------------------------------------------------------------------
sub onTitleChanged()
    m.titleLabel.text = SafeString(m.top.title, "")
end sub

'-------------------------------------------------------------------------------
' onSubtitleChanged
'-------------------------------------------------------------------------------
sub onSubtitleChanged()
    m.subtitleLabel.text = SafeString(m.top.subtitle, "")
end sub

'-------------------------------------------------------------------------------
' onMetaChanged
'-------------------------------------------------------------------------------
sub onMetaChanged()
    m.metaLabel.text = SafeString(m.top.meta, "")
end sub

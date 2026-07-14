'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.card = {
        accentBar: m.top.findNode("accentBar")
        titleLabel: m.top.findNode("titleLabel")
        summaryLabel: m.top.findNode("summaryLabel")
        detailsLabel: m.top.findNode("detailsLabel")
    }
    render()
end sub

'-------------------------------------------------------------------------------
' render
'-------------------------------------------------------------------------------
sub render()
    m.card.titleLabel.text = m.top.title
    m.card.summaryLabel.text = m.top.summary
    m.card.detailsLabel.text = m.top.details

    accentColor = m.top.accentColor
    if accentColor = invalid or accentColor = 0 then accentColor = &h6EC6FFFF
    summaryColor = m.top.summaryColor
    if summaryColor = invalid or summaryColor = 0 then summaryColor = &h9EE6FFFF

    m.card.accentBar.color = accentColor
    m.card.summaryLabel.color = summaryColor
end sub

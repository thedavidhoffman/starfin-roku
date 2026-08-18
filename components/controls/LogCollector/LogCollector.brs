'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.logState = {
        entries: []
        characterCount: 0
        maximumEntries: 300
        maximumCharacters: 250000
        maximumEntryLength: 8000
    }
end sub

'-------------------------------------------------------------------------------
' onAppendRequested
'-------------------------------------------------------------------------------
sub onAppendRequested()
    entry = normalizeEntry(m.top.appendRequested)
    if entry = "" then return

    m.logState.entries.Push(entry)
    m.logState.characterCount = m.logState.characterCount + Len(entry)
    while m.logState.entries.Count() > m.logState.maximumEntries or m.logState.characterCount > m.logState.maximumCharacters
        removedEntry = m.logState.entries.Shift()
        m.logState.characterCount = m.logState.characterCount - Len(removedEntry)
    end while
end sub

'-------------------------------------------------------------------------------
' getSnapshot
'-------------------------------------------------------------------------------
function getSnapshot() as object
    snapshot = []
    for each entry in m.logState.entries
        snapshot.Push(entry)
    end for
    return snapshot
end function

'-------------------------------------------------------------------------------
' clear
'-------------------------------------------------------------------------------
sub clear()
    m.logState.entries = []
    m.logState.characterCount = 0
end sub

'-------------------------------------------------------------------------------
' normalizeEntry
'-------------------------------------------------------------------------------
function normalizeEntry(value as dynamic) as string
    if value = invalid then return ""
    text = value.ToStr()
    text = text.Replace(Chr(0), "")
    text = text.Replace(Chr(13), "")
    if Len(text) > m.logState.maximumEntryLength then
        text = Left(text, m.logState.maximumEntryLength - 3) + "..."
    end if
    return text
end function

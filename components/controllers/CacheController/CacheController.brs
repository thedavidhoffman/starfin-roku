'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.cache = []
end sub

'-------------------------------------------------------------------------------
' get
'-------------------------------------------------------------------------------
function get(key as string) as dynamic
    index = findCacheIndex(key)
    if index = -1 then return invalid

    return m.cache[index].value
end function

'-------------------------------------------------------------------------------
' set
'-------------------------------------------------------------------------------
sub set(entry as object)
    if entry = invalid then return
    if entry.key = invalid or entry.key = "" then return

    index = findCacheIndex(entry.key)
    if index = -1 then
        m.cache.Push({
            key: entry.key
            value: entry.value
        })
    else
        m.cache[index].value = entry.value
    end if
end sub

'-------------------------------------------------------------------------------
' clear
'-------------------------------------------------------------------------------
sub clear(key as string)
    index = findCacheIndex(key)
    if index = -1 then return

    m.cache.Delete(index)
end sub

'-------------------------------------------------------------------------------
' findCacheIndex
'-------------------------------------------------------------------------------
function findCacheIndex(key as string) as integer
    if m.cache = invalid then return -1

    for i = 0 to m.cache.Count() - 1
        entry = m.cache[i]
        if entry <> invalid and entry.key = key then return i
    end for

    return -1
end function

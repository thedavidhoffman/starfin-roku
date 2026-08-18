'-------------------------------------------------------------------------------
' Application Registry Storage
'-------------------------------------------------------------------------------

'-------------------------------------------------------------------------------
' ApplicationStore_ClearAll
'-------------------------------------------------------------------------------
sub ApplicationStore_ClearAll()
    registry = CreateObject("roRegistry")
    for each sectionName in registry.GetSectionList()
        registry.Delete(sectionName)
    end for
    registry.Flush()
end sub

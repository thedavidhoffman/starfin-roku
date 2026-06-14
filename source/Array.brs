'-------------------------------------------------------------------------------
' Array_GetCount
'-------------------------------------------------------------------------------
function Array_GetCount(values as dynamic) as integer

    if values = invalid then return 0
    
    valueType = Type(values)
    if valueType <> "roArray" and valueType <> "roAssociativeArray" then return 0
    
    return values.Count()

end function

'-------------------------------------------------------------------------------
' StringArray_ToCommaSeparatedList
'-------------------------------------------------------------------------------
function Array_JoinStringValues(values as dynamic) as string

    if values = invalid then return ""

    result = ""
    for each value in values
        if result <> "" then result = result + ", "
        result = result + SafeString(value, "")
    end for

    return result

end function
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
' Array_IsAssocArray
'-------------------------------------------------------------------------------
function Array_IsAssocArray(value as dynamic) as boolean
    valueType = Type(value)
    return valueType = "roAssociativeArray" or valueType = "roSGNodeEvent"
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

'-------------------------------------------------------------------------------
' DateTime_GetYearFromData
'-------------------------------------------------------------------------------
function DateTime_GetYearFromData(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    if Len(text) < 4 then return ""

    return Left(text, 4)
end function

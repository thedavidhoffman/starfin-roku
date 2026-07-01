'-------------------------------------------------------------------------------
' Number_ToFloat
'-------------------------------------------------------------------------------
function Number_ToFloat(value as dynamic, fallback = 0.0 as float) as float
    if value = invalid then return fallback
    return val(value.ToStr())
end function

'-------------------------------------------------------------------------------
' Number_ToInteger
'-------------------------------------------------------------------------------
function Number_ToInteger(value as dynamic, fallback = 0 as integer) as integer
    if value = invalid then return fallback
    return int(val(value.ToStr()))
end function

'-------------------------------------------------------------------------------
' Number_FormatWithThousandsSeparator
'-------------------------------------------------------------------------------
function Number_FormatWithThousandsSeparator(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    result = ""

    while Len(text) > 3
        result = "," + Right(text, 3) + result
        text = Left(text, Len(text) - 3)
    end while

    return text + result
end function

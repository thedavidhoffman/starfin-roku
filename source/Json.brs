' JSON helpers for outbound API bodies.
'
' Roku FormatJson() lowercases object keys during serialization. Some APIs are
' case-sensitive, unlike many .NET JSON consumers where key casing may be 
' tolerated. These helpers preserve exact key casing by requiring API field
' names as explicit string literals.

'-------------------------------------------------------------------------------
' Json_String
'-------------------------------------------------------------------------------
function Json_String(value as dynamic) as string
    text = SafeString(value, "")
    text = String_Replace(text, "\", "\\")
    text = String_Replace(text, Chr(34), "\" + Chr(34))
    return Chr(34) + text + Chr(34)
end function

'-------------------------------------------------------------------------------
' Json_Pair
'-------------------------------------------------------------------------------
function Json_Pair(name as string, value as dynamic) as string
    return Json_String(name) + ":" + Json_String(value)
end function

'-------------------------------------------------------------------------------
' Json_BooleanPair
'-------------------------------------------------------------------------------
function Json_BooleanPair(name as string, value as dynamic) as string
    text = "false"
    if value = true then text = "true"
    return Json_String(name) + ":" + text
end function

'-------------------------------------------------------------------------------
' Json_NumberPair
'-------------------------------------------------------------------------------
function Json_NumberPair(name as string, value as dynamic) as string
    return Json_String(name) + ":" + Json_Number(value)
end function

'-------------------------------------------------------------------------------
' Json_ArrayPair
'-------------------------------------------------------------------------------
function Json_ArrayPair(name as string, values as dynamic) as string
    parts = []
    if values <> invalid then
        for each value in values
            parts.Push(Json_String(value))
        end for
    end if

    return Json_String(name) + ":[" + Json_JoinParts(parts) + "]"
end function

'-------------------------------------------------------------------------------
' Json_ObjectPair
'-------------------------------------------------------------------------------
function Json_ObjectPair(name as string, parts as object) as string
    return Json_String(name) + ":" + Json_Object(parts)
end function

'-------------------------------------------------------------------------------
' Json_Object
'-------------------------------------------------------------------------------
function Json_Object(parts as object) as string
    return "{" + Json_JoinParts(parts) + "}"
end function

'-------------------------------------------------------------------------------
' Json_JoinParts
'-------------------------------------------------------------------------------
function Json_JoinParts(parts as object) as string
    if parts = invalid or parts.Count() = 0 then return ""

    text = ""
    for i = 0 to parts.Count() - 1
        if i > 0 then text = text + ","
        text = text + parts[i]
    end for

    return text
end function

'-------------------------------------------------------------------------------
' Json_Number
'-------------------------------------------------------------------------------
function Json_Number(value as dynamic) as string
    if value = invalid then return "0"

    text = String_Trim(value.ToStr())
    if Instr(1, text, ",") > 0 then text = String_Replace(text, ",", "")
    if Instr(1, LCase(text), "e") > 0 then text = __Json_ExpandExponent(text)

    return text
end function

'-------------------------------------------------------------------------------
' __Json_ExpandExponent
'-------------------------------------------------------------------------------
function __Json_ExpandExponent(value as string) as string
    normalized = LCase(String_Trim(value))
    exponentIndex = Instr(1, normalized, "e")
    if exponentIndex = 0 then return normalized

    coefficient = Left(normalized, exponentIndex - 1)
    exponent = val(Mid(normalized, exponentIndex + 1))
    sign = ""

    if Left(coefficient, 1) = "-" then
        sign = "-"
        coefficient = Mid(coefficient, 2)
    else if Left(coefficient, 1) = "+" then
        coefficient = Mid(coefficient, 2)
    end if

    decimalIndex = Instr(1, coefficient, ".")
    if decimalIndex = 0 then
        digits = coefficient
        decimalPlaces = 0
    else
        digits = Left(coefficient, decimalIndex - 1) + Mid(coefficient, decimalIndex + 1)
        decimalPlaces = Len(coefficient) - decimalIndex
    end if

    decimalShift = int(exponent) - decimalPlaces
    if decimalShift >= 0 then
        for i = 1 to decimalShift
            digits = digits + "0"
        end for
        return sign + digits
    end if

    decimalPosition = Len(digits) + decimalShift
    if decimalPosition > 0 then
        return sign + Left(digits, decimalPosition) + "." + Mid(digits, decimalPosition + 1)
    end if

    leadingZeroes = "0."
    for i = 1 to Abs(decimalPosition)
        leadingZeroes = leadingZeroes + "0"
    end for

    return sign + leadingZeroes + digits
end function

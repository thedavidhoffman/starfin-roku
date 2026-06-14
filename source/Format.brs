'-------------------------------------------------------------------------------
' NormalizeServerUrl
'-------------------------------------------------------------------------------
function NormalizeServerUrl(server as string) as string
    
    if server = invalid then return ""
    
    normalized = String_Trim(server)
    
    if normalized = "" then return ""
    
    if Instr(1, LCase(normalized), "http://") <> 1 and Instr(1, LCase(normalized), "https://") <> 1 then
        normalized = "http://" + normalized
    end if
    
    while Right(normalized, 1) = "/"
        normalized = Left(normalized, Len(normalized) - 1)
    end while
    
    return normalized
    
end function

'-------------------------------------------------------------------------------
' SafeString
'-------------------------------------------------------------------------------
function SafeString(value as dynamic, fallback = "" as string) as string
    if value = invalid then return fallback
    return value.ToStr()
end function

'-------------------------------------------------------------------------------
' FirstNonEmpty
'-------------------------------------------------------------------------------
function FirstNonEmpty(values as object, fallback as string) as string
    for each value in values
        if value <> invalid then
            text = String_Trim(value.ToStr())
            if text <> "" then return text
        end if
    end for
    return fallback
end function

' FormatWithCommas
'-------------------------------------------------------------------------------
function FormatWithCommas(value as dynamic) as string
    if value = invalid then return ""

    text = String_Trim(value.ToStr())
    result = ""
    groupCount = 0

    for i = Len(text) to 1 step -1
        result = Mid(text, i, 1) + result
        groupCount = groupCount + 1

        if groupCount = 3 and i > 1 then
            result = "," + result
            groupCount = 0
        end if
    end for

    return result
end function

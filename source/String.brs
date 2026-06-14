'-------------------------------------------------------------------------------
' String_Trim
'-------------------------------------------------------------------------------
function String_Trim(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    startIndex = 0
    endIndex = Len(text) - 1

    while startIndex <= endIndex and Mid(text, startIndex + 1, 1) = " "
        startIndex = startIndex + 1
    end while

    while endIndex >= startIndex and Mid(text, endIndex + 1, 1) = " "
        endIndex = endIndex - 1
    end while

    if startIndex > endIndex then return ""
    return Mid(text, startIndex + 1, endIndex - startIndex + 1)
end function

'-------------------------------------------------------------------------------
' String_Replace
'-------------------------------------------------------------------------------
function String_Replace(value as string, oldValue as string, newValue as string) as string
    result = ""
    remaining = value
    index = Instr(1, remaining, oldValue)

    while index > 0
        result = result + Left(remaining, index - 1) + newValue
        remaining = Mid(remaining, index + Len(oldValue))
        index = Instr(1, remaining, oldValue)
    end while

    return result + remaining
end function

'-------------------------------------------------------------------------------
' String_CollapseWhitespace
'-------------------------------------------------------------------------------
function String_CollapseWhitespace(value as string) as string
    result = ""
    previousWasSpace = false

    for i = 1 to Len(value)
        char = Mid(value, i, 1)
        isSpace = (char = " " or char = Chr(10) or char = Chr(13) or char = Chr(9))

        if isSpace then
            if previousWasSpace = false then result = result + " "
            previousWasSpace = true
        else
            result = result + char
            previousWasSpace = false
        end if
    end for

    return String_Trim(result)
end function

'-------------------------------------------------------------------------------
' String_NaturalCompare
' Case-insensitive comparator for natural sorting, so numbered text sorts by
' numeric value ("Book 2" before "Book 10") instead of plain text order.
'-------------------------------------------------------------------------------
function String_NaturalCompare(leftValue as dynamic, rightValue as dynamic) as integer
    left = LCase(SafeString(leftValue, ""))
    right = LCase(SafeString(rightValue, ""))
    leftIndex = 1
    rightIndex = 1

    while leftIndex <= Len(left) and rightIndex <= Len(right)
        leftChar = Mid(left, leftIndex, 1)
        rightChar = Mid(right, rightIndex, 1)

        if String_IsDigit(leftChar) and String_IsDigit(rightChar) then
            comparison = __String_CompareNumberRuns(left, leftIndex, right, rightIndex)
            if comparison <> 0 then return comparison

            leftIndex = __String_GetDigitRunEnd(left, leftIndex) + 1
            rightIndex = __String_GetDigitRunEnd(right, rightIndex) + 1
        else
            if leftChar < rightChar then return -1
            if leftChar > rightChar then return 1

            leftIndex = leftIndex + 1
            rightIndex = rightIndex + 1
        end if
    end while

    if leftIndex <= Len(left) then return 1
    if rightIndex <= Len(right) then return -1
    return 0
end function

'-------------------------------------------------------------------------------
' __String_CompareNumberRuns
'-------------------------------------------------------------------------------
function __String_CompareNumberRuns(left as string, leftIndex as integer, right as string, rightIndex as integer) as integer
    leftEnd = __String_GetDigitRunEnd(left, leftIndex)
    rightEnd = __String_GetDigitRunEnd(right, rightIndex)
    leftNumber = __String_TrimLeadingZeroes(Mid(left, leftIndex, leftEnd - leftIndex + 1))
    rightNumber = __String_TrimLeadingZeroes(Mid(right, rightIndex, rightEnd - rightIndex + 1))

    if Len(leftNumber) < Len(rightNumber) then return -1
    if Len(leftNumber) > Len(rightNumber) then return 1

    for i = 1 to Len(leftNumber)
        leftChar = Mid(leftNumber, i, 1)
        rightChar = Mid(rightNumber, i, 1)
        if leftChar < rightChar then return -1
        if leftChar > rightChar then return 1
    end for

    leftRunLength = leftEnd - leftIndex + 1
    rightRunLength = rightEnd - rightIndex + 1
    if leftRunLength < rightRunLength then return -1
    if leftRunLength > rightRunLength then return 1
    return 0
end function

'-------------------------------------------------------------------------------
' __String_GetDigitRunEnd
'-------------------------------------------------------------------------------
function __String_GetDigitRunEnd(value as string, startIndex as integer) as integer
    index = startIndex

    while index <= Len(value) and String_IsDigit(Mid(value, index, 1))
        index = index + 1
    end while

    return index - 1
end function

'-------------------------------------------------------------------------------
' __String_TrimLeadingZeroes
'-------------------------------------------------------------------------------
function __String_TrimLeadingZeroes(value as string) as string
    index = 1

    while index < Len(value) and Mid(value, index, 1) = "0"
        index = index + 1
    end while

    return Mid(value, index)
end function

'-------------------------------------------------------------------------------
' __String_IsDigit
'-------------------------------------------------------------------------------
function String_IsDigit(value as string) as boolean
    return value >= "0" and value <= "9"
end function

'-------------------------------------------------------------------------------
' String_StripHtmlMarkup
'-------------------------------------------------------------------------------
function String_StripHtmlMarkup(value as dynamic) as string
    text = SafeString(value, "")
    text = String_Replace(text, "</p> <p>", Chr(10))
    text = String_Replace(text, "</p><p>", Chr(10))
    result = ""
    insideTag = false

    for i = 1 to Len(text)
        char = Mid(text, i, 1)
        if char = "<" then
            insideTag = true
        else if char = ">" then
            insideTag = false
            result = result + " "
        else if insideTag = false then
            result = result + char
        end if
    end for

    result = String_Replace(result, "&nbsp;", " ")
    result = String_Replace(result, "&amp;", "&")
    result = String_Replace(result, "&quot;", Chr(34))
    result = String_Replace(result, "&#39;", "'")
    result = String_Replace(result, "&apos;", "'")
    result = String_Replace(result, "&lt;", "<")
    result = String_Replace(result, "&gt;", ">")

    return String_CollapseWhitespace(result)
end function

'-------------------------------------------------------------------------------
' String_GetJoinedText
'-------------------------------------------------------------------------------
function String_GetJoinedText(values as dynamic) as string
    if values = invalid then return ""

    if Type(values) <> "roArray" and Type(values) <> "roAssociativeArray" then
        return String_Trim(values.ToStr())
    end if

    result = ""
    for each value in values
        text = String_Trim(value.ToStr())
        if text <> "" then
            if result <> "" then result = result + ", "
            result = result + text
        end if
    end for

    return result
end function

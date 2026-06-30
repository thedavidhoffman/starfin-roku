'-------------------------------------------------------------------------------
' DateTime_ToYear
'-------------------------------------------------------------------------------
function DateTime_ToYear(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    if Len(text) < 4 then return ""

    return Left(text, 4)
end function

'-------------------------------------------------------------------------------
' DateTime_ToShortDate
'-------------------------------------------------------------------------------
function DateTime_ToShortDate(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    if Len(text) < 10 then return text

    dateText = Left(text, 10)
    year = Left(dateText, 4)
    monthNumber = val(Mid(dateText, 6, 2))
    day = val(Mid(dateText, 9, 2))
    if monthNumber < 1 or monthNumber > 12 or day < 1 then return dateText

    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return monthNames[monthNumber - 1] + " " + day.ToStr() + ", " + year
end function

'-------------------------------------------------------------------------------
' DateTime_ToLongDate
'-------------------------------------------------------------------------------
function DateTime_ToLongDate(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    if text = "" then return ""

    date = CreateObject("roDateTime")
    date.FromISO8601String(text)
    monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    month = date.GetMonth()
    if month < 1 or month > 12 then return date.AsDateString("short-month-no-weekday")

    return monthNames[month - 1] + " " + date.GetDayOfMonth().ToStr() + ", " + date.GetYear().ToStr()
end function

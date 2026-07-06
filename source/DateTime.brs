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

'-------------------------------------------------------------------------------
' DateTime_FromIsoSeconds
'-------------------------------------------------------------------------------
function DateTime_FromIsoSeconds(value as dynamic) as integer
    if value = invalid then return 0

    text = value.ToStr()
    if text = "" then return 0

    date = CreateObject("roDateTime")
    date.FromISO8601String(text)
    return date.AsSeconds()
end function

'-------------------------------------------------------------------------------
' DateTime_ToIsoOffset
'-------------------------------------------------------------------------------
function DateTime_ToIsoOffset(offsetSeconds as integer) as string
    date = CreateObject("roDateTime")
    date.Mark()
    date.FromSeconds(date.AsSeconds() + offsetSeconds)
    return date.ToISOString()
end function

'-------------------------------------------------------------------------------
' DateTime_ToLocalShortTime
'-------------------------------------------------------------------------------
function DateTime_ToLocalShortTime(value as dynamic) as string
    if value = invalid then return ""

    text = value.ToStr()
    if text = "" then return ""

    date = CreateObject("roDateTime")
    date.FromISO8601String(text)
    date.ToLocalTime()

    hour = date.GetHours()
    minute = date.GetMinutes()
    suffix = "AM"
    if hour >= 12 then suffix = "PM"
    displayHour = hour mod 12
    if displayHour = 0 then displayHour = 12

    minuteText = minute.ToStr()
    if minute < 10 then minuteText = "0" + minuteText

    return displayHour.ToStr() + ":" + minuteText + " " + suffix
end function

'-------------------------------------------------------------------------------
' DateTime_FormatDurationSeconds
'-------------------------------------------------------------------------------
function DateTime_FormatDurationSeconds(seconds as dynamic) as string
    if seconds = invalid then return ""

    minutes = int(val(seconds.ToStr()) / 60)
    if minutes <= 0 then return ""

    hours = int(minutes / 60)
    remainingMinutes = minutes mod 60
    if hours > 0 then return hours.ToStr() + "h " + remainingMinutes.ToStr() + "m"

    return minutes.ToStr() + "m"
end function

'-------------------------------------------------------------------------------
' DateTime_FormatPositionSeconds
'-------------------------------------------------------------------------------
function DateTime_FormatPositionSeconds(seconds as dynamic) as string
    if seconds = invalid then return ""

    totalSeconds = int(val(seconds.ToStr()))
    if totalSeconds < 0 then totalSeconds = 0

    hours = int(totalSeconds / 3600)
    minutes = int((totalSeconds mod 3600) / 60)
    if hours > 0 then return hours.ToStr() + "h " + minutes.ToStr() + "m"

    return minutes.ToStr() + "m"
end function

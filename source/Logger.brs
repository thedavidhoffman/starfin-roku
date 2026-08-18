'-------------------------------------------------------------------------------
' Logger
'-------------------------------------------------------------------------------
' Creates a small logger object with buffered and unbuffered console paths.
' Only explicitly display-safe methods copy messages to the in-app log viewer.
' Buffered logging stores lines until log.flush() writes the full console buffer.
' The buffer exists for work that executes on its own task/thread, so related log
' statements can be grouped together instead of interleaved with other output.

'-------------------------------------------------------------------------------
' CreateLogger
'-------------------------------------------------------------------------------
function CreateLogger(label = "" as string) as object

    log = {
        label: label
        buffered: false
        collector: __Logger_GetCollector()
        write: __Logger_Write
        writeDisplaySafe: __Logger_WriteDisplaySafe
        writeConsoleOnly: __Logger_WriteConsoleOnly
        writeBracketed: __Logger_WriteBracketed
        writeJson: __Logger_WriteJson
        writeJsonDisplaySafe: __Logger_WriteJsonDisplaySafe
        writeJsonConsoleOnly: __Logger_WriteJsonConsoleOnly
        error: __Logger_Error
        errorDisplaySafe: __Logger_ErrorDisplaySafe
    }

    return log

end function

'-------------------------------------------------------------------------------
' CreateBufferedLogger
'-------------------------------------------------------------------------------
function CreateBufferedLogger(label = "" as string) as object

    log = {
        label: label
        buffered: true
        buffer: []
        collector: __Logger_GetCollector()
        write: __Logger_Write
        writeDisplaySafe: __Logger_WriteDisplaySafe
        writeConsoleOnly: __Logger_WriteConsoleOnly
        writeBracketed: __Logger_WriteBracketed
        writeJson: __Logger_WriteJson
        writeJsonDisplaySafe: __Logger_WriteJsonDisplaySafe
        writeJsonConsoleOnly: __Logger_WriteJsonConsoleOnly
        error: __Logger_Error
        errorDisplaySafe: __Logger_ErrorDisplaySafe
        flush: __Logger_Flush
    }

    return log

end function

'-------------------------------------------------------------------------------
' __Logger_Write
'-------------------------------------------------------------------------------
function __Logger_Write(message as dynamic) as object

    line = __Logger_Format(message, m.label)

    if m.buffered then
        m.buffer.Push(line)
    else
        ? line
    end if

    return m

end function

'-------------------------------------------------------------------------------
' __Logger_WriteDisplaySafe
'-------------------------------------------------------------------------------
function __Logger_WriteDisplaySafe(message as dynamic) as object
    line = __Logger_Format(message, m.label)
    ? line
    __Logger_CollectLine(m.collector, line)
    return m
end function

'-------------------------------------------------------------------------------
' __Logger_WriteConsoleOnly
'-------------------------------------------------------------------------------
function __Logger_WriteConsoleOnly(message as dynamic) as object
    ? __Logger_Format(message, m.label)
    return m
end function

'-------------------------------------------------------------------------------
' __Logger_WriteBracketed
'-------------------------------------------------------------------------------
function __Logger_WriteBracketed(array as dynamic) as object

    output = ""

    for each line in array
        output = output + "[" + line + "] "
    end for

    m.write(output)

    return m

end function

'-------------------------------------------------------------------------------
' __Logger_WriteJson
'-------------------------------------------------------------------------------
function __Logger_WriteJson(jsonText as dynamic, indent = 0 as integer) as object
    lines = __Logger_FormatJsonText(jsonText)
    prefix = __Logger_Indent(indent)

    for each line in lines
        m.write(prefix + line)
    end for

    return m
end function

'-------------------------------------------------------------------------------
' __Logger_WriteJsonDisplaySafe
'-------------------------------------------------------------------------------
function __Logger_WriteJsonDisplaySafe(jsonText as dynamic, indent = 0 as integer, heading = "" as string) as object
    lines = __Logger_FormatJsonText(jsonText)
    prefix = __Logger_Indent(indent)
    displayEntry = ""
    if heading <> "" then
        m.writeConsoleOnly(heading)
        displayEntry = __Logger_Format(heading, m.label)
    end if
    for i = 0 to lines.Count() - 1
        line = prefix + lines[i]
        m.writeConsoleOnly(line)
        if displayEntry = "" then
            displayEntry = __Logger_Format(line, m.label)
        else
            displayEntry = displayEntry + Chr(10) + line
        end if
    end for
    if displayEntry <> "" then __Logger_CollectLine(m.collector, displayEntry)
    return m
end function

'-------------------------------------------------------------------------------
' __Logger_WriteJsonConsoleOnly
'-------------------------------------------------------------------------------
function __Logger_WriteJsonConsoleOnly(jsonText as dynamic, indent = 0 as integer) as object
    lines = __Logger_FormatJsonText(jsonText)
    prefix = __Logger_Indent(indent)

    for each line in lines
        m.writeConsoleOnly(prefix + line)
    end for

    return m
end function

'-------------------------------------------------------------------------------
' __Logger_Error
'-------------------------------------------------------------------------------
function __Logger_Error(message as dynamic) as object

    message = "ERROR: " + message
    return m.write(message)

end function

'-------------------------------------------------------------------------------
' __Logger_Flush
'-------------------------------------------------------------------------------
sub __Logger_Flush()
    output = ""

    if m.buffer.Count() = 0 then
        m.buffer = []
        return
    end if

    for each line in m.buffer
        output = output + line + Chr(10)
    end for

    ' print once so buffered task logs stay grouped
    if output <> "" then ? output;
    m.buffer = []
end sub

'-------------------------------------------------------------------------------
' __Logger_GetCollector
'-------------------------------------------------------------------------------
function __Logger_GetCollector() as dynamic
    if m = invalid or m.global = invalid then return invalid
    return m.global.logCollector
end function

'-------------------------------------------------------------------------------
' __Logger_ErrorDisplaySafe
'-------------------------------------------------------------------------------
function __Logger_ErrorDisplaySafe(message as dynamic) as object
    return m.writeDisplaySafe("ERROR: " + message)
end function

'-------------------------------------------------------------------------------
' __Logger_CollectLine
'-------------------------------------------------------------------------------
sub __Logger_CollectLine(collector as dynamic, line as string)
    if collector = invalid then return
    collector.appendRequested = line
end sub

'-------------------------------------------------------------------------------
' __Logger_Format
'-------------------------------------------------------------------------------
function __Logger_Format(message as dynamic, label as dynamic) as string

    text = SafeString(message, "")
    if label <> invalid and label <> "" then text = "[" + label + "] " + text
    return __Logger_TimestampPrefix() + text

end function

'-------------------------------------------------------------------------------
' __Logger_FormatJsonText
'-------------------------------------------------------------------------------
function __Logger_FormatJsonText(jsonText as dynamic) as object
    text = SafeString(jsonText, "")
    lines = []
    if text = "" then
        lines.Push("")
        return lines
    end if

    indentLevel = 0
    currentLine = ""
    inString = false
    escapeNext = false
    quote = Chr(34)

    for i = 1 to Len(text)
        char = Mid(text, i, 1)

        if inString = true then
            currentLine = currentLine + char

            if escapeNext = true then
                escapeNext = false
            else if char = "\" then
                escapeNext = true
            else if char = quote then
                inString = false
            end if
        else if char = quote then
            inString = true
            currentLine = currentLine + char
        else if char = "{" or char = "[" then
            currentLine = __Logger_TrimRight(currentLine) + char
            lines.Push(currentLine)
            indentLevel = indentLevel + 1
            currentLine = __Logger_Indent(indentLevel)
        else if char = "}" or char = "]" then
            if __Logger_Trim(currentLine) <> "" then lines.Push(__Logger_TrimRight(currentLine))
            indentLevel = indentLevel - 1
            if indentLevel < 0 then indentLevel = 0
            currentLine = __Logger_Indent(indentLevel) + char
        else if char = "," then
            currentLine = __Logger_TrimRight(currentLine) + char
            lines.Push(currentLine)
            currentLine = __Logger_Indent(indentLevel)
        else if char = ":" then
            currentLine = __Logger_TrimRight(currentLine) + ": "
        else if __Logger_IsWhitespace(char) <> true then
            currentLine = currentLine + char
        end if
    end for

    if __Logger_Trim(currentLine) <> "" then lines.Push(__Logger_TrimRight(currentLine))

    return lines
end function

'-------------------------------------------------------------------------------
' __Logger_Indent
'-------------------------------------------------------------------------------
function __Logger_Indent(level as integer) as string
    text = ""
    for i = 1 to level
        text = text + "  "
    end for

    return text
end function

'-------------------------------------------------------------------------------
' __Logger_IsWhitespace
'-------------------------------------------------------------------------------
function __Logger_IsWhitespace(char as string) as boolean
    return char = " " or char = Chr(9) or char = Chr(10) or char = Chr(13)
end function

'-------------------------------------------------------------------------------
' __Logger_Trim
'-------------------------------------------------------------------------------
function __Logger_Trim(text as string) as string
    return __Logger_TrimLeft(__Logger_TrimRight(text))
end function

'-------------------------------------------------------------------------------
' __Logger_TrimLeft
'-------------------------------------------------------------------------------
function __Logger_TrimLeft(text as string) as string
    while Len(text) > 0 and __Logger_IsWhitespace(Left(text, 1)) = true
        text = Mid(text, 2)
    end while

    return text
end function

'-------------------------------------------------------------------------------
' __Logger_TrimRight
'-------------------------------------------------------------------------------
function __Logger_TrimRight(text as string) as string
    while Len(text) > 0 and __Logger_IsWhitespace(Right(text, 1)) = true
        text = Left(text, Len(text) - 1)
    end while

    return text
end function

'-------------------------------------------------------------------------------
' __Logger_TimestampPrefix
'-------------------------------------------------------------------------------
function __Logger_TimestampPrefix() as string
    dateTime = CreateObject("roDateTime")
    dateTime.ToLocalTime()

    return __Logger_Pad2(dateTime.GetMonth()) + "/" + __Logger_Pad2(dateTime.GetDayOfMonth()) + " " + __Logger_Pad2(dateTime.GetHours()) + ":" + __Logger_Pad2(dateTime.GetMinutes()) + ":" + __Logger_Pad2(dateTime.GetSeconds()) + " "
end function

'-------------------------------------------------------------------------------
' __Logger_Pad2
'-------------------------------------------------------------------------------
function __Logger_Pad2(value as dynamic) as string
    text = int(val(value.ToStr())).ToStr()
    if Len(text) < 2 then return "0" + text
    return text
end function

'-------------------------------------------------------------------------------
' __Logger_Pad3
'-------------------------------------------------------------------------------
function __Logger_Pad3(value as dynamic) as string
    text = int(val(value.ToStr())).ToStr()
    while Len(text) < 3
        text = "0" + text
    end while

    return text
end function

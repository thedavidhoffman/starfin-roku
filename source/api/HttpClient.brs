'-------------------------------------------------------------------------------
' HttpClient_Request
'-------------------------------------------------------------------------------
function HttpClient_Request(url as String, method as String, token as Dynamic, body as Dynamic, headers = invalid as Dynamic, displayRequest = true as Boolean) as Object

    log = CreateLogger("HttpClient_Request")

    if url = invalid or url = "" then
        message = "Invalid http request: url is invalid."
        log.errorDisplaySafe(message)
        return { ok: false, errorMessage: message }
    end if

    if method = invalid or method = "" then
        message = "Invalid http request: method is invalid."
        log.errorDisplaySafe(message)
        return { ok: false, errorMessage: message }
    end if

    normalizedMethod = UCase(method)

    ' IMPORTANT...
    ' do NOT check for invalid token here login requests don't have
    ' a token, so it's valid in that scenario for the token to be null

    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")

    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.SetMessagePort(port)
    transfer.SetUrl(url)
    transfer.AddHeader("Accept", "application/json")

    if headers <> invalid then
        for each headerName in headers
            headerValue = headers[headerName]
            if headerValue <> invalid then transfer.AddHeader(headerName, headerValue.ToStr())
        end for
    end if

    if token <> invalid and token <> "" and __HeadersInclude(headers, "Authorization") <> true then
        transfer.AddHeader("Authorization", "Bearer " + token)
    end if

    responseText = ""
    status = 0
    logUrl = __HttpClient_MaskUrl(url)
    if displayRequest then
        log.writeDisplaySafe("[" + normalizedMethod + "] " + logUrl)
    else
        log.writeConsoleOnly("[" + normalizedMethod + "] " + logUrl)
    end if
    if normalizedMethod = "POST" then
        transfer.AddHeader("Content-Type", "application/json")
        requestStarted = transfer.AsyncPostFromString(__InvalidToEmpty(body))
    else
        transfer.SetRequest(normalizedMethod)
        requestStarted = transfer.AsyncGetToString()
    end if

    if requestStarted <> true then
        message = "Unable to start the server request."
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, 0, message)
        return { ok: false, status: 0, errorMessage: message }
    end if

    msg = wait(30000, port)
    if msg = invalid then
        transfer.AsyncCancel()
        message = "The server request timed out."
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, 0, message)
        return { ok: false, status: 0, errorMessage: message }
    end if

    if type(msg) <> "roUrlEvent" then
        message = "Unexpected server response."
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, 0, message)
        return { ok: false, status: 0, errorMessage: message }
    end if

    status = msg.GetResponseCode()
    responseText = msg.GetString()
    responseHeaders = msg.GetResponseHeaders()
    contentType = __GetResponseHeader(responseHeaders, "content-type")

    if status = 0 then
        message = "Unable to reach the server."
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, status, message)
        return { ok: false, status: status, errorMessage: message }
    end if

    hasAuthenticatedRequest = (token <> invalid and token <> "") or __AuthorizationHeaderHasToken(headers)
    if status = 401 and hasAuthenticatedRequest then
        message = "Your session has expired. Please sign in again."
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, status, message)
        return { ok: false, status: status, authExpired: true, errorMessage: message }
    end if

    data = invalid
    if __IsJsonContentType(contentType) and responseText <> invalid and responseText <> "" then
        data = ParseJson(responseText)
    end if

    if status < 200 or status >= 300 then
        message = "Request failed."
        if data <> invalid then
            if data.error <> invalid then message = SafeString(data.error, message)
            if data.message <> invalid then message = SafeString(data.message, message)
        else if responseText <> invalid and String_Trim(responseText) <> "" then
            message = String_Trim(responseText)
        else if msg.GetFailureReason() <> invalid and String_Trim(msg.GetFailureReason()) <> "" then
            message = String_Trim(msg.GetFailureReason())
        end if
        __HttpClient_LogFailure(log, normalizedMethod, logUrl, status, message)
        return { ok: false, status: status, errorMessage: message, responseText: responseText }
    end if

    return { ok: true, status: status, data: data, responseText: responseText }
end function

'-------------------------------------------------------------------------------
' __HttpClient_LogFailure
'-------------------------------------------------------------------------------
sub __HttpClient_LogFailure(log as object, method as string, url as string, status as integer, message as string)
    prefix = "HTTP request failed [" + method + "] " + url + " status=" + status.ToStr()
    log.errorDisplaySafe(prefix)
    log.error(prefix + " message=" + message)
end sub

'-------------------------------------------------------------------------------
' MaskUrl
'-------------------------------------------------------------------------------
function __HttpClient_MaskUrl(url as Dynamic) as String
    text = SafeString(url, "")
    if text = "" then return ""

    text = __HttpClient_MaskUrlCredentials(text)
    text = __HttpClient_MaskQueryValue(text, "api_key")
    text = __HttpClient_MaskQueryValue(text, "token")
    text = __HttpClient_MaskQueryValue(text, "ApiKey")
    text = __HttpClient_MaskQueryValue(text, "X-Emby-Token")
    text = __HttpClient_MaskQueryValue(text, "access_token")
    text = __HttpClient_MaskQueryValue(text, "auth_token")
    text = __HttpClient_MaskQueryValue(text, "authorization")
    text = __HttpClient_MaskQueryValue(text, "password")
    text = __HttpClient_MaskQueryValue(text, "signature")

    return text
end function

'-------------------------------------------------------------------------------
' __HttpClient_MaskUrlCredentials
'-------------------------------------------------------------------------------
function __HttpClient_MaskUrlCredentials(url as string) as string
    schemeEnd = Instr(1, url, "://")
    if schemeEnd = 0 then return url

    authorityStart = schemeEnd + 3
    authorityEnd = Instr(authorityStart, url, "/")
    if authorityEnd = 0 then authorityEnd = Len(url) + 1
    credentialsEnd = Instr(authorityStart, url, "@")
    if credentialsEnd = 0 or credentialsEnd >= authorityEnd then return url

    return Left(url, authorityStart - 1) + "[redacted]@" + Mid(url, credentialsEnd + 1)
end function

'-------------------------------------------------------------------------------
' MaskQueryValue
'-------------------------------------------------------------------------------
function __HttpClient_MaskQueryValue(url as String, name as String) as String
    queryStart = Instr(1, url, "?")
    if queryStart = 0 then return url

    lowerUrl = LCase(url)
    lowerName = LCase(name)
    searchStart = queryStart + 1

    while true
        keyStart = Instr(searchStart, lowerUrl, lowerName + "=")
        if keyStart = 0 then exit while

        isQueryKey = keyStart = queryStart + 1 or Mid(url, keyStart - 1, 1) = "&"
        if isQueryKey = true then
            valueStart = keyStart + Len(name) + 1
            valueEnd = Instr(valueStart, url, "&")
            if valueEnd = 0 then valueEnd = Len(url) + 1

            url = Left(url, valueStart - 1) + "[redacted]" + Mid(url, valueEnd)
            lowerUrl = LCase(url)
            searchStart = valueStart + Len("[redacted]")
        else
            searchStart = keyStart + Len(name) + 1
        end if
    end while

    return url
end function

'-------------------------------------------------------------------------------
' HeadersInclude
'-------------------------------------------------------------------------------
function __HeadersInclude(headers as Dynamic, name as String) as Boolean
    if headers = invalid then return false

    lowerName = LCase(name)
    for each key in headers
        if LCase(key.ToStr()) = lowerName then return true
    end for

    return false
end function

'-------------------------------------------------------------------------------
' AuthorizationHeaderHasToken
'-------------------------------------------------------------------------------
function __AuthorizationHeaderHasToken(headers as Dynamic) as Boolean
    if headers = invalid then return false

    for each key in headers
        if LCase(key.ToStr()) = "authorization" then
            value = LCase(SafeString(headers[key], ""))
            return Instr(1, value, "token=") > 0
        end if
    end for

    return false
end function

'-------------------------------------------------------------------------------
' GetResponseHeader
'-------------------------------------------------------------------------------
function __GetResponseHeader(headers as Dynamic, name as String) as String
    if headers = invalid then return ""

    value = headers[name]
    if value <> invalid then return value.ToStr()

    lowerName = LCase(name)
    for each key in headers
        if LCase(key.ToStr()) = lowerName then
            value = headers[key]
            if value <> invalid then return value.ToStr()
        end if
    end for

    return ""
end function

'-------------------------------------------------------------------------------
' IsJsonContentType
'-------------------------------------------------------------------------------
function __IsJsonContentType(contentType as Dynamic) as Boolean
    normalized = LCase(SafeString(contentType, ""))
    return Instr(1, normalized, "application/json") > 0 or Instr(1, normalized, "+json") > 0
end function

'-------------------------------------------------------------------------------
' InvalidToEmpty
'-------------------------------------------------------------------------------
function __InvalidToEmpty(value as Dynamic) as String
    if value = invalid then return ""
    return value
end function

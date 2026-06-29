'-------------------------------------------------------------------------------
' Url_BuildQueryString
'-------------------------------------------------------------------------------
function Url_BuildQueryString(params as object) as string
    if params = invalid or params.Count() = 0 then return ""

    query = ""
    for each key in params
        textValue = __Url_QueryValue(params[key])
        if textValue <> "" then
            if query <> "" then query = query + "&"
            query = query + Encode_Url(key.ToStr()) + "=" + Encode_Url(textValue)
        end if
    end for

    if query = "" then return ""
    return "?" + query
end function

'-------------------------------------------------------------------------------
' Url_BuildImageUrl
'-------------------------------------------------------------------------------
function Url_BuildImageUrl(server as string, itemId as string, imageType as string, tag as string, width as integer, height as integer, options = invalid as dynamic) as string
    serverUrl = NormalizeServerUrl(server)
    if serverUrl = "" then return ""
    if itemId = "" or imageType = "" then return ""

    query = "?maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"
    if tag <> "" then query = "?tag=" + tag + "&maxWidth=" + width.ToStr() + "&maxHeight=" + height.ToStr() + "&quality=90"

    if options <> invalid then
        for each key in options
            value = __Url_QueryValue(options[key])
            if value <> "" then query = query + "&" + key.ToStr() + "=" + value
        end for
    end if

    return serverUrl + "/Items/" + itemId + "/Images/" + imageType + query
end function

'-------------------------------------------------------------------------------
' Url_SetQueryParam
'-------------------------------------------------------------------------------
function Url_SetQueryParam(url as string, name as string, value as string) as string

    ' Replaces an existing query parameter by name, or appends it when absent.

    queryStart = Instr(1, url, "?")
    if queryStart = 0 then return __Url_AddQueryParam(url, name, value)

    lowerUrl = LCase(url)
    lowerName = LCase(name)
    searchStart = queryStart + 1

    while true
        keyStart = Instr(searchStart, lowerUrl, lowerName + "=")
        if keyStart = 0 then return __Url_AddQueryParam(url, name, value)
        if keyStart = queryStart + 1 or Mid(url, keyStart - 1, 1) = "&" then
            valueStart = keyStart + Len(name) + 1
            valueEnd = Instr(valueStart, url, "&")
            if valueEnd = 0 then valueEnd = Len(url) + 1

            return Left(url, valueStart - 1) + Encode_Url(value) + Mid(url, valueEnd)
        end if

        searchStart = keyStart + Len(name) + 1
    end while

    return __Url_AddQueryParam(url, name, value)
end function

'-------------------------------------------------------------------------------
' __Url_AddQueryParam
'-------------------------------------------------------------------------------
function __Url_AddQueryParam(url as string, name as string, value as string) as string
    separator = "?"
    if Instr(1, url, "?") > 0 then separator = "&"

    return url + separator + Encode_Url(name) + "=" + Encode_Url(value)
end function

'-------------------------------------------------------------------------------
' __Url_QueryValue
'-------------------------------------------------------------------------------
function __Url_QueryValue(value as dynamic) as string
    if Type(value) = "roBoolean" or Type(value) = "Boolean" then
        if value then return "true"
        return "false"
    end if

    return SafeString(value, "")
end function

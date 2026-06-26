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
' __Url_QueryValue
'-------------------------------------------------------------------------------
function __Url_QueryValue(value as dynamic) as string
    if Type(value) = "roBoolean" or Type(value) = "Boolean" then
        if value then return "true"
        return "false"
    end if

    return SafeString(value, "")
end function

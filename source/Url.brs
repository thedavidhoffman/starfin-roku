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
' __Url_QueryValue
'-------------------------------------------------------------------------------
function __Url_QueryValue(value as dynamic) as string
    if Type(value) = "roBoolean" or Type(value) = "Boolean" then
        if value then return "true"
        return "false"
    end if

    return SafeString(value, "")
end function

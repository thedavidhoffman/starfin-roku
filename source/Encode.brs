'-------------------------------------------------------------------------------
' Encode_Base64
'-------------------------------------------------------------------------------
function Encode_Base64(value as String) as String
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(value)
    return bytes.ToBase64String()
end function

'-------------------------------------------------------------------------------
' Encode_Url
'-------------------------------------------------------------------------------
function Encode_Url(value as String) as String
    encoded = ""
    hex = "0123456789ABCDEF"

    for i = 1 to Len(value)
        char = Mid(value, i, 1)
        code = Asc(char)

        if __Encode_IsUrlUnreserved(code) then
            encoded = encoded + char
        else
            encoded = encoded + "%" + Mid(hex, int(code / 16) + 1, 1) + Mid(hex, (code mod 16) + 1, 1)
        end if
    end for

    return encoded
end function

'-------------------------------------------------------------------------------
' __Encode_IsUrlUnreserved
'-------------------------------------------------------------------------------
function __Encode_IsUrlUnreserved(code as integer) as boolean
    if code >= 65 and code <= 90 then return true
    if code >= 97 and code <= 122 then return true
    if code >= 48 and code <= 57 then return true
    if code = 45 or code = 46 or code = 95 or code = 126 then return true

    return false
end function

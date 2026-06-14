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
    transfer = CreateObject("roUrlTransfer")
    return transfer.Escape(value)
end function

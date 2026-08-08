'-------------------------------------------------------------------------------
' AccountImage_GetUri
'-------------------------------------------------------------------------------
function AccountImage_GetUri(account as object, width as integer, height as integer) as string
    placeholderUri = "pkg:/images/cast/cast-placeholder-195x195.png"
    server = Url_NormalizeServer(SafeString(account.server, ""))
    userId = SafeString(account.userId, "")
    primaryImageTag = SafeString(account.primaryImageTag, "")
    if server = "" or userId = "" or primaryImageTag = "" then return placeholderUri

    query = Url_BuildQueryString({
        tag: primaryImageTag
        maxWidth: width
        maxHeight: height
        quality: 90
        format: "Jpg"
    })
    return server + "/Users/" + userId + "/Images/Primary" + query
end function

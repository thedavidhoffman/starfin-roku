'-------------------------------------------------------------------------------
' JellyfinAuth_BuildClientHeader
'-------------------------------------------------------------------------------
function JellyfinAuth_BuildClientHeader() as string
    quote = Chr(34)
    deviceInfo = CreateObject("roDeviceInfo")
    appInfo = CreateObject("roAppInfo")

    deviceName = SafeString(deviceInfo.GetModelDisplayName(), "")
    if deviceName = "" then deviceName = SafeString(deviceInfo.GetModel(), "Roku")

    deviceId = SafeString(deviceInfo.GetChannelClientId(), "")
    if deviceId = "" then deviceId = SafeString(deviceInfo.GetModel(), "roku")

    auth = "MediaBrowser Client=" + quote + "Starfin Roku" + quote
    auth = auth + ", Device=" + quote + deviceName + quote
    auth = auth + ", Version=" + quote + SafeString(appInfo.GetVersion(), "1.0.0") + quote
    auth = auth + ", DeviceId=" + quote + deviceId + quote

    return auth
end function

'-------------------------------------------------------------------------------
' JellyfinAuth_BuildAuthorizationHeader
'-------------------------------------------------------------------------------
function JellyfinAuth_BuildAuthorizationHeader(token as dynamic, userId = invalid as dynamic) as string
    quote = Chr(34)
    auth = JellyfinAuth_BuildClientHeader()

    if userId <> invalid and userId <> "" then
        auth = auth + ", UserId=" + quote + SafeString(userId, "") + quote
    end if

    if token <> invalid and token <> "" then
        auth = auth + ", Token=" + quote + SafeString(token, "") + quote
    end if

    return auth
end function

'-------------------------------------------------------------------------------
' JellyfinAuth_BuildTokenHeaders
'-------------------------------------------------------------------------------
function JellyfinAuth_BuildTokenHeaders(token as dynamic) as object
    return {
        Authorization: JellyfinAuth_BuildAuthorizationHeader(token)
    }
end function

'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.diagnosticsText = m.top.findNode("diagnosticsText")
    updateDiagnostics()
end sub

'-------------------------------------------------------------------------------
' focusDiagnostics
'-------------------------------------------------------------------------------
sub focusDiagnostics()
    m.diagnosticsText.setFocus(true)
end sub

'-------------------------------------------------------------------------------
' updateDiagnostics
'-------------------------------------------------------------------------------
sub updateDiagnostics()
    separator = Chr(10) + Chr(10)
    m.diagnosticsText.text = getAppInfoText() + separator + getDeviceInfoText() + separator + getApplicationRegistryText()
end sub

'-------------------------------------------------------------------------------
' getAppInfoText
'-------------------------------------------------------------------------------
function getAppInfoText() as string
    appInfo = CreateObject("roAppInfo")

    return sectionText("Application Information", [
        { key: "title", value: appInfo.GetTitle() }
        { key: "version", value: appInfo.GetVersion() }
    ])
end function

'-------------------------------------------------------------------------------
' getDeviceInfoText
'-------------------------------------------------------------------------------
function getDeviceInfoText() as string
    deviceInfo = CreateObject("roDeviceInfo")

    model = deviceInfo.GetModel()
    modelDisplayName = deviceInfo.GetModelDisplayName()
    osVersion = deviceInfo.GetOSVersion()
    uiResolution = deviceInfo.GetUIResolution()
    displayMode = deviceInfo.GetDisplayMode()
    connectionInfo = deviceInfo.GetConnectionInfo()

    return sectionText("Roku Device Information", [
        { key: "model", value: modelDisplayName + " " + model }
        { key: "os version", value: osVersion }
        { key: "ui resolution", value: uiResolution }
        { key: "display mode", value: displayMode }
        { key: "connection Info", value: connectionInfo.type + " (" + LCase(connectionInfo.quality) + " quality) " + connectionInfo.ip }
    ])
end function

'-------------------------------------------------------------------------------
' getApplicationRegistryText
'-------------------------------------------------------------------------------
function getApplicationRegistryText() as string
    auth = AuthStore_Load()
    settings = SettingsStore_Load()
    keys = SettingsStore_Keys()

    return sectionText("Application Registry", [
        { key: "server", value: auth.server }
        { key: "username", value: auth.username }
        { key: "userId", value: auth.userId }
        { key: "token", value: truncateText(auth.token, 40) + "..." }
        { key: keys.tvLibraryDisplay, value: settings[keys.tvLibraryDisplay] }
        { key: keys.movieLibraryDisplay, value: settings[keys.movieLibraryDisplay] }
        { key: keys.collectionCardsImageType, value: settings[keys.collectionCardsImageType] }
        { key: keys.collectionItemsImageType, value: settings[keys.collectionItemsImageType] }
        { key: keys.tvEpisodeListDisplay, value: settings[keys.tvEpisodeListDisplay] }
        { key: keys.mediaShellBackground, value: settings[keys.mediaShellBackground] }
        { key: keys.videoStreamingMode, value: settings[keys.videoStreamingMode] }
        { key: keys.tmdbApiKey, value: truncateText(settings[keys.tmdbApiKey], 40) }
    ])
end function

'-------------------------------------------------------------------------------
' truncateText
'-------------------------------------------------------------------------------
function truncateText(value as dynamic, maxLength as integer) as string
    text = formatValue(value)
    if Len(text) <= maxLength then return text
    return Left(text, maxLength)
end function

'-------------------------------------------------------------------------------
' sectionText
'-------------------------------------------------------------------------------
function sectionText(title as string, entries as object) as string
    text = UCase(title)

    for each entry in entries
        text = text + Chr(10) + UCase(entry.key) + ": " + formatValue(entry.value)
    end for

    return text
end function

'-------------------------------------------------------------------------------
' formatValue
'-------------------------------------------------------------------------------
function formatValue(value as dynamic) as string
    if value = invalid then return "(not set)"

    valueType = Type(value)
    if valueType = "roAssociativeArray" or valueType = "roSGNodeEvent" then return formatAssocArray(value)
    if valueType = "roArray" then return formatArray(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Boolean" or valueType = "roBoolean" then
        if value then return "true"
        return "false"
    end if
    if valueType = "Integer" or valueType = "roInt" or valueType = "LongInteger" or valueType = "roLongInteger" then return StrI(value)
    if valueType = "Float" or valueType = "roFloat" or valueType = "Double" or valueType = "roDouble" then return Str(value)

    return "(unsupported " + valueType + ")"
end function

'-------------------------------------------------------------------------------
' formatAssocArray
'-------------------------------------------------------------------------------
function formatAssocArray(value as object) as string
    text = "{"
    isFirst = true

    for each key in value
        if isFirst then
            isFirst = false
        else
            text = text + ", "
        end if

        text = text + key + ": " + formatValue(value[key])
    end for

    return text + "}"
end function

'-------------------------------------------------------------------------------
' formatArray
'-------------------------------------------------------------------------------
function formatArray(value as object) as string
    text = "["
    isFirst = true

    for each item in value
        if isFirst then
            isFirst = false
        else
            text = text + ", "
        end if

        text = text + formatValue(item)
    end for

    return text + "]"
end function

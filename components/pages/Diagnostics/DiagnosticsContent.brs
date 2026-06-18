'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.appSectionTitle = m.top.findNode("appSectionTitle")
    m.appInfoKeysLabel = m.top.findNode("appInfoKeysLabel")
    m.appInfoValuesLabel = m.top.findNode("appInfoValuesLabel")
    m.cacheSectionTitle = m.top.findNode("cacheSectionTitle")
    m.cacheKeysLabel = m.top.findNode("cacheKeysLabel")
    m.cacheValuesLabel = m.top.findNode("cacheValuesLabel")
    m.deviceSectionTitle = m.top.findNode("deviceSectionTitle")
    m.deviceInfoKeysLabel = m.top.findNode("deviceInfoKeysLabel")
    m.deviceInfoValuesLabel = m.top.findNode("deviceInfoValuesLabel")
    m.registrySectionTitle = m.top.findNode("registrySectionTitle")
    m.registryKeysLabel = m.top.findNode("registryKeysLabel")
    m.registryValuesLabel = m.top.findNode("registryValuesLabel")

    initStyle()
    updateDiagnostics()
end sub

'-------------------------------------------------------------------------------
' initStyle
'-------------------------------------------------------------------------------
sub initStyle()
    setSectionTitleColor(m.appSectionTitle)
    setSectionTitleColor(m.cacheSectionTitle)
    setSectionTitleColor(m.deviceSectionTitle)
    setSectionTitleColor(m.registrySectionTitle)
    setBodyColor(m.appInfoKeysLabel)
    setBodyColor(m.appInfoValuesLabel)
    setBodyColor(m.cacheKeysLabel)
    setBodyColor(m.cacheValuesLabel)
    setBodyColor(m.deviceInfoKeysLabel)
    setBodyColor(m.deviceInfoValuesLabel)
    setBodyColor(m.registryKeysLabel)
    setBodyColor(m.registryValuesLabel)
end sub

'-------------------------------------------------------------------------------
' setSectionTitleColor
'-------------------------------------------------------------------------------
sub setSectionTitleColor(label as dynamic)
    if label <> invalid then label.color = &hF3F7FBFF
end sub

'-------------------------------------------------------------------------------
' setBodyColor
'-------------------------------------------------------------------------------
sub setBodyColor(label as dynamic)
    if label <> invalid then label.color = &hD5E0EAFF
end sub

'-------------------------------------------------------------------------------
' updateDiagnostics
'-------------------------------------------------------------------------------
sub updateDiagnostics()
    appInfoText = getAppInfoText()
    cacheText = getCacheInfoText()
    deviceInfoText = getDeviceInfoText()
    registryText = getApplicationRegistryText()

    setLabelText(m.appInfoKeysLabel, appInfoText.keys)
    setLabelText(m.appInfoValuesLabel, appInfoText.values)
    setLabelText(m.cacheKeysLabel, cacheText.keys)
    setLabelText(m.cacheValuesLabel, cacheText.values)
    setLabelText(m.deviceInfoKeysLabel, deviceInfoText.keys)
    setLabelText(m.deviceInfoValuesLabel, deviceInfoText.values)
    setLabelText(m.registryKeysLabel, registryText.keys)
    setLabelText(m.registryValuesLabel, registryText.values)
end sub

'-------------------------------------------------------------------------------
' getAppInfoText
'-------------------------------------------------------------------------------
function getAppInfoText() as object
    appInfo = CreateObject("roAppInfo")

    return keyValueText([
        { key: "title", value: appInfo.GetTitle() }
        { key: "version", value: appInfo.GetVersion() }
    ])
end function

'-------------------------------------------------------------------------------
' getCacheInfoText
'-------------------------------------------------------------------------------
function getCacheInfoText() as object
    cacheInfo = m.top.cacheInfo
    if cacheInfo = invalid or cacheInfo.Count() = 0 then
        return keyValueText([
            { key: "cache", value: "(empty)" }
        ])
    end if

    entries = []
    for each cacheEntry in cacheInfo
        if cacheEntry <> invalid then
            entries.Push({
                key: cacheEntry.key
                value: formatValue(cacheEntry.itemCount) + " items, " + formatValue(cacheEntry.size)
            })
        end if
    end for

    return keyValueText(entries)
end function

'-------------------------------------------------------------------------------
' getDeviceInfoText
'-------------------------------------------------------------------------------
function getDeviceInfoText() as object
    deviceInfo = CreateObject("roDeviceInfo")

    model = deviceInfo.GetModel()
    modelDisplayName = deviceInfo.GetModelDisplayName()
    osVersion = deviceInfo.GetOSVersion()
    uiResolution = deviceInfo.GetUIResolution()
    displayMode = deviceInfo.GetDisplayMode()
    connectionInfo = deviceInfo.GetConnectionInfo()

    return keyValueText([
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
function getApplicationRegistryText() as object
    auth = AuthStore_Load()
    settings = SettingsStore_Load()
    keys = SettingsStore_Keys()

    return keyValueText([
        { key: "server", value: auth.server }
        { key: "username", value: auth.username }
        { key: "userId", value: auth.userId }
        { key: "token", value: truncateText(auth.token, 40) + "..." }
        { key: keys.tvLibraryDisplay, value: settings[keys.tvLibraryDisplay] }
        { key: keys.movieLibraryDisplay, value: settings[keys.movieLibraryDisplay] }
        { key: keys.collectionDisplay, value: settings[keys.collectionDisplay] }
        { key: keys.homeLibraryThumbnails, value: settings[keys.homeLibraryThumbnails] }
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
' keyValueText
'-------------------------------------------------------------------------------
function keyValueText(entries as object) as object
    keys = ""
    values = ""

    for each entry in entries
        if keys <> "" then
            keys = keys + Chr(10)
            values = values + Chr(10)
        end if

        keys = keys + UCase(entry.key) + ":"
        values = values + formatValue(entry.value)
    end for

    return {
        keys: keys
        values: values
    }
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

'-------------------------------------------------------------------------------
' setLabelText
'-------------------------------------------------------------------------------
sub setLabelText(label as dynamic, text as string)
    if label <> invalid then label.text = text
end sub

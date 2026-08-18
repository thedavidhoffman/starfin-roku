'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("TrickplayPreloadTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    if request = invalid then return

    action = LCase(SafeString(request.action, "add"))
    m.log.writeDisplaySafe("Request action=" + action + " itemId=" + SafeString(request.itemId, "") + " tileWidth=" + SafeString(getTileWidth(request), "") + " tileCount=" + SafeString(getTileCount(request), ""))
    if action = "remove" then
        removeTrickplayFiles(request)
    else
        addTrickplayFiles(request)
    end if
end sub

'-------------------------------------------------------------------------------
' addTrickplayFiles
'-------------------------------------------------------------------------------
sub addTrickplayFiles(request as object)
    fileSystem = CreateObject("roFileSystem")
    tileCount = getTileCount(request)
    if tileCount <= 0 then return

    m.log.writeDisplaySafe("Preload started itemId=" + SafeString(request.itemId, "") + " tileCount=" + tileCount.ToStr())
    for tileIndex = 0 to tileCount - 1
        localUri = getLocalTrickplayUri(request, tileIndex)
        if localUri = "" then return

        if fileSystem.Exists(localUri) <> true then
            m.log.writeDisplaySafe("Downloading trickplay tile tileIndex=" + tileIndex.ToStr() + " uri=" + localUri)
            downloadTrickplayFile(request, tileIndex, localUri)
        else
            m.log.writeDisplaySafe("Using cached trickplay tile tileIndex=" + tileIndex.ToStr() + " uri=" + localUri)
        end if

        if fileSystem.Exists(localUri) = true then
            m.log.writeDisplaySafe("Trickplay tile ready tileIndex=" + tileIndex.ToStr() + " uri=" + localUri)
            m.top.response = {
                ok: true
                action: "trickplayPreload"
                itemId: SafeString(request.itemId, "")
                tileIndex: tileIndex
                uri: localUri
            }
        end if
    end for

    m.top.response = {
        ok: true
        action: "trickplayPreload"
        itemId: SafeString(request.itemId, "")
        complete: true
    }
    m.log.writeDisplaySafe("Preload complete itemId=" + SafeString(request.itemId, "") + " tileCount=" + tileCount.ToStr())
end sub

'-------------------------------------------------------------------------------
' removeTrickplayFiles
'-------------------------------------------------------------------------------
sub removeTrickplayFiles(request as object)
    fileSystem = CreateObject("roFileSystem")
    tileCount = getTileCount(request)
    if tileCount <= 0 then return

    deletedCount = 0
    m.log.writeDisplaySafe("Cleanup started itemId=" + SafeString(request.itemId, "") + " tileCount=" + tileCount.ToStr())
    for tileIndex = 0 to tileCount - 1
        localUri = getLocalTrickplayUri(request, tileIndex)
        if localUri <> "" and fileSystem.Exists(localUri) = true then
            fileSystem.Delete(localUri)
            deletedCount = deletedCount + 1
        end if
    end for
    m.log.writeDisplaySafe("Cleanup complete itemId=" + SafeString(request.itemId, "") + " deletedCount=" + deletedCount.ToStr())
end sub

'-------------------------------------------------------------------------------
' downloadTrickplayFile
'-------------------------------------------------------------------------------
sub downloadTrickplayFile(request as object, tileIndex as integer, localUri as string)
    url = getRemoteTrickplayUrl(request, tileIndex)
    if url = "" then return

    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.SetMessagePort(port)
    transfer.SetUrl(url)

    if transfer.AsyncGetToFile(localUri) <> true then
        m.log.error("Unable to start trickplay preload tileIndex=" + tileIndex.ToStr())
        return
    end if

    message = wait(30000, port)
    if message = invalid then
        transfer.AsyncCancel()
        m.log.error("Trickplay preload timed out tileIndex=" + tileIndex.ToStr())
        return
    end if

    if type(message) <> "roUrlEvent" then return

    status = message.GetResponseCode()
    if status < 200 or status >= 300 then
        m.log.error("Trickplay preload failed tileIndex=" + tileIndex.ToStr() + " status=" + status.ToStr())
    else
        m.log.writeDisplaySafe("Trickplay download complete tileIndex=" + tileIndex.ToStr() + " status=" + status.ToStr())
    end if
end sub

'-------------------------------------------------------------------------------
' getRemoteTrickplayUrl
'-------------------------------------------------------------------------------
function getRemoteTrickplayUrl(request as object, tileIndex as integer) as string
    server = request.server
    itemId = SafeString(request.itemId, "")
    token = SafeString(request.token, "")
    tileWidth = getTileWidth(request)
    if server = "" or itemId = "" or token = "" or tileWidth <= 0 then return ""

    return server + "/Videos/" + itemId + "/Trickplay/" + tileWidth.ToStr() + "/" + tileIndex.ToStr() + ".jpg?ApiKey=" + Encode_Url(token)
end function

'-------------------------------------------------------------------------------
' getLocalTrickplayUri
'-------------------------------------------------------------------------------
function getLocalTrickplayUri(request as object, tileIndex as integer) as string
    itemId = SafeString(request.itemId, "")
    tileWidth = getTileWidth(request)
    if itemId = "" or tileWidth <= 0 then return ""

    return "tmp:/starfin-trickplay-" + itemId + "-" + tileWidth.ToStr() + "-" + tileIndex.ToStr() + ".jpg"
end function

'-------------------------------------------------------------------------------
' getTileCount
'-------------------------------------------------------------------------------
function getTileCount(request as object) as integer
    if request = invalid or request.tileCount = invalid then return 0
    return int(request.tileCount)
end function

'-------------------------------------------------------------------------------
' getTileWidth
'-------------------------------------------------------------------------------
function getTileWidth(request as object) as integer
    if request = invalid or request.tileWidth = invalid then return 0
    return int(request.tileWidth)
end function

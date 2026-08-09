'-------------------------------------------------------------------------------
' Auth Registry Storage
'-------------------------------------------------------------------------------

'-------------------------------------------------------------------------------
' __GetAuthAccountSectionName
'-------------------------------------------------------------------------------
function __GetAuthAccountSectionName(accountKey as string) as string
    return "STARFIN_ACCOUNT_" + accountKey
end function

'-------------------------------------------------------------------------------
' __GetAuthStore
'-------------------------------------------------------------------------------
function __GetAuthStore() as object
    return CreateObject("roRegistrySection", "STARFIN_ROKU")
end function

'-------------------------------------------------------------------------------
' AuthStore_BuildAccountKey
'-------------------------------------------------------------------------------
function AuthStore_BuildAccountKey(server as string, userId as dynamic) as string
    normalizedServer = LCase(Url_NormalizeServer(server))
    authority = normalizedServer
    if Left(authority, 7) = "http://" then
        authority = Mid(authority, 8)
    else if Left(authority, 8) = "https://" then
        authority = Mid(authority, 9)
    end if

    authorityEnd = Len(authority) + 1
    pathStart = Instr(1, authority, "/")
    queryStart = Instr(1, authority, "?")
    fragmentStart = Instr(1, authority, "#")
    if pathStart > 0 and pathStart < authorityEnd then authorityEnd = pathStart
    if queryStart > 0 and queryStart < authorityEnd then authorityEnd = queryStart
    if fragmentStart > 0 and fragmentStart < authorityEnd then authorityEnd = fragmentStart
    authority = Left(authority, authorityEnd - 1)

    return authority + "/" + SafeString(userId, "")
end function

'-------------------------------------------------------------------------------
' AuthStore_Load
'-------------------------------------------------------------------------------
function AuthStore_Load() as object
    globalStore = __GetAuthStore()
    accountKey = SafeString(globalStore.Read("active-account-key"), "")
    if accountKey = "" then
        return {
            accountKey: ""
            server: AuthStore_GetLastServer()
            username: ""
            token: ""
            userId: ""
            primaryImageTag: ""
        }
    end if

    account = AuthStore_LoadAccount(accountKey, true)
    if account = invalid then
        AuthStore_ClearActiveAccount()
        return {
            accountKey: ""
            server: AuthStore_GetLastServer()
            username: ""
            token: ""
            userId: ""
            primaryImageTag: ""
        }
    end if

    return account
end function

'-------------------------------------------------------------------------------
' AuthStore_Save
'-------------------------------------------------------------------------------
sub AuthStore_Save(server as string, username as string, token as string, userId as dynamic, primaryImageTag = "" as string)
    accountKey = AuthStore_BuildAccountKey(server, userId)
    accountStore = CreateObject("roRegistrySection", __GetAuthAccountSectionName(accountKey))
    accountStore.Write("server", Url_NormalizeServer(server))
    accountStore.Write("username", username)
    accountStore.Write("token", token)
    accountStore.Write("user-id", SafeString(userId, ""))
    accountStore.Write("primary-image-tag", primaryImageTag)
    accountStore.Flush()

    AuthStore_SetActiveAccount(accountKey)
end sub

'-------------------------------------------------------------------------------
' AuthStore_LoadAccount
'-------------------------------------------------------------------------------
function AuthStore_LoadAccount(accountKey as string, includeToken = false as boolean) as dynamic
    if accountKey = "" then return invalid
    accountStore = CreateObject("roRegistrySection", __GetAuthAccountSectionName(accountKey))
    server = SafeString(accountStore.Read("server"), "")
    userId = SafeString(accountStore.Read("user-id"), "")
    if server = "" or userId = "" then return invalid

    account = {
        accountKey: accountKey
        server: server
        username: SafeString(accountStore.Read("username"), "")
        userId: userId
        primaryImageTag: SafeString(accountStore.Read("primary-image-tag"), "")
    }
    if includeToken then account.token = SafeString(accountStore.Read("token"), "")
    return account
end function

'-------------------------------------------------------------------------------
' AuthStore_ListAccounts
'-------------------------------------------------------------------------------
function AuthStore_ListAccounts(server as string) as object
    normalizedServer = LCase(Url_NormalizeServer(server))
    activeAccountKey = AuthStore_GetActiveAccountKey()
    accounts = []
    registry = CreateObject("roRegistry")
    for each sectionName in registry.GetSectionList()
        if LCase(Left(sectionName, 16)) = "starfin_account_" then
            accountKey = Mid(sectionName, 17)
            account = AuthStore_LoadAccount(accountKey, false)
            accountStore = CreateObject("roRegistrySection", sectionName)
            hasToken = SafeString(accountStore.Read("token"), "") <> ""
            if account <> invalid and hasToken and LCase(account.server) = normalizedServer then
                account.isActive = (accountKey = activeAccountKey)
                activeSort = "1"
                if account.isActive then activeSort = "0"
                account.sortKey = activeSort + "--" + LCase(account.username) + "--" + accountKey
                accounts.Push(account)
            end if
        end if
    end for
    accounts.SortBy("sortKey")
    for each account in accounts
        account.Delete("sortKey")
    end for
    return accounts
end function

'-------------------------------------------------------------------------------
' AuthStore_ListAllAccounts
'-------------------------------------------------------------------------------
function AuthStore_ListAllAccounts(includeToken = false as boolean) as object
    activeAccountKey = AuthStore_GetActiveAccountKey()
    accounts = []
    registry = CreateObject("roRegistry")
    for each sectionName in registry.GetSectionList()
        if LCase(Left(sectionName, 16)) = "starfin_account_" then
            accountKey = Mid(sectionName, 17)
            account = AuthStore_LoadAccount(accountKey, includeToken)
            if account <> invalid then
                account.isActive = (accountKey = activeAccountKey)
                activeSort = "1"
                if account.isActive then activeSort = "0"
                account.sortKey = activeSort + "--" + LCase(account.server) + "--" + LCase(account.username) + "--" + accountKey
                accounts.Push(account)
            end if
        end if
    end for
    accounts.SortBy("sortKey")
    for each account in accounts
        account.Delete("sortKey")
    end for
    return accounts
end function

'-------------------------------------------------------------------------------
' AuthStore_GetActiveAccountKey
'-------------------------------------------------------------------------------
function AuthStore_GetActiveAccountKey() as string
    return SafeString(__GetAuthStore().Read("active-account-key"), "")
end function

'-------------------------------------------------------------------------------
' AuthStore_GetLastServer
'-------------------------------------------------------------------------------
function AuthStore_GetLastServer() as string
    return SafeString(__GetAuthStore().Read("server"), "")
end function

'-------------------------------------------------------------------------------
' AuthStore_SetActiveAccount
'-------------------------------------------------------------------------------
sub AuthStore_SetActiveAccount(accountKey as string)
    account = AuthStore_LoadAccount(accountKey, false)
    if account = invalid then return
    authStore = __GetAuthStore()
    authStore.Write("active-account-key", accountKey)
    authStore.Write("server", account.server)
    authStore.Flush()
end sub

'-------------------------------------------------------------------------------
' AuthStore_RemoveToken
'-------------------------------------------------------------------------------
sub AuthStore_RemoveToken(accountKey as string)
    if accountKey = "" then return
    accountStore = CreateObject("roRegistrySection", __GetAuthAccountSectionName(accountKey))
    accountStore.Delete("token")
    accountStore.Flush()
    if AuthStore_GetActiveAccountKey() = accountKey then AuthStore_ClearActiveAccount()
end sub

'-------------------------------------------------------------------------------
' AuthStore_ClearActiveAccount
'-------------------------------------------------------------------------------
sub AuthStore_ClearActiveAccount()
    authStore = __GetAuthStore()
    authStore.Delete("active-account-key")
    authStore.Flush()
end sub

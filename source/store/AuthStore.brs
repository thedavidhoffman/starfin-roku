'-------------------------------------------------------------------------------
' Auth Registry Storage
'-------------------------------------------------------------------------------
' roRegistrySection is Roku's persistent key/value storage API. A registry
' section groups related values under an app-owned name, such as "STARFIN_ROKU".
' Values written with Write() can be read across app launches with Read().
' Delete() removes saved values, and Flush() commits pending writes/deletes.
' This app uses the registry to remember auth state: server, username, token,
' and user id.
'
'-------------------------------------------------------------------------------
' GetAuthStore
'-------------------------------------------------------------------------------
function GetAuthStore() as object
    return CreateObject("roRegistrySection", "STARFIN_ROKU")
end function

'-------------------------------------------------------------------------------
' AuthStore_Save
'-------------------------------------------------------------------------------
sub AuthStore_Save(server as string, username as string, token as string, userId as dynamic)
    authStore = GetAuthStore()
    authStore.Write("server", Url_NormalizeServer(server))
    authStore.Write("username", username)
    authStore.Write("token", token)
    if userId <> invalid then authStore.Write("userId", userId)
    authStore.Flush()
end sub

'-------------------------------------------------------------------------------
' AuthStore_Load
'-------------------------------------------------------------------------------
function AuthStore_Load() as object
    authStore = GetAuthStore()
    return {
        server: authStore.Read("server")
        username: authStore.Read("username")
        token: authStore.Read("token")
        userId: authStore.Read("userId")
    }
end function

'-------------------------------------------------------------------------------
' AuthStore_Clear
'-------------------------------------------------------------------------------
sub AuthStore_Clear(clearServer as boolean)
    authStore = GetAuthStore()
    authStore.Delete("token")
    authStore.Delete("userId")
    if clearServer then
        authStore.Delete("server")
        authStore.Delete("username")
    end if
    authStore.Flush()
end sub

' The test plugin substitutes only AuthStore's native factory calls. Other code
' and tests continue using real native objects, and this file is not packaged
' into production or automation builds.
function AuthStoreTestCreateObject(kind as string, name = "" as string) as dynamic
    state = getGlobalAa().authStoreRegistryFixture
    if state <> invalid then
        if kind = "roRegistry" then return state.registry
        if kind = "roRegistrySection" then return state.sections[name]
    end if
    if kind = "roRegistry" then return CreateObject(kind)
    return CreateObject(kind, name)
end function

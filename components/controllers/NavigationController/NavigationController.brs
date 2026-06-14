'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.history = []
end sub

'-------------------------------------------------------------------------------
' navigateTo
'-------------------------------------------------------------------------------
sub navigateTo(route as object)
    if isValidRoute(route) = false then return

    currentRoute = m.top.currentRoute
    if currentRoute <> invalid then m.history.Push(currentRoute)

    m.top.currentRoute = route
end sub

'-------------------------------------------------------------------------------
' replace
'-------------------------------------------------------------------------------
sub replace(route as object)
    if isValidRoute(route) = false then return

    m.top.currentRoute = route
end sub

'-------------------------------------------------------------------------------
' reset
'-------------------------------------------------------------------------------
sub reset(route as object)
    m.history = []
    if isValidRoute(route) = false then
        m.top.currentRoute = invalid
        return
    end if

    m.top.currentRoute = route
end sub

'-------------------------------------------------------------------------------
' back
'-------------------------------------------------------------------------------
function back() as boolean
    if m.history = invalid or m.history.Count() = 0 then return false

    lastIndex = m.history.Count() - 1
    m.top.currentRoute = m.history[lastIndex]
    m.history.Delete(lastIndex)
    return true
end function

'-------------------------------------------------------------------------------
' getCurrentRoute
'-------------------------------------------------------------------------------
function getCurrentRoute() as dynamic
    return m.top.currentRoute
end function

'-------------------------------------------------------------------------------
' canGoBack
'-------------------------------------------------------------------------------
function canGoBack() as boolean
    return m.history <> invalid and m.history.Count() > 0
end function

'-------------------------------------------------------------------------------
' clearHistory
'-------------------------------------------------------------------------------
sub clearHistory()
    m.history = []
end sub

'-------------------------------------------------------------------------------
' isValidRoute
'-------------------------------------------------------------------------------
function isValidRoute(route as dynamic) as boolean
    return route <> invalid and route.id <> invalid and route.id <> ""
end function

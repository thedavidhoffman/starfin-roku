sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    
    ' required for Roku app certification
    memoryMonitor = CreateObject("roAppMemoryMonitor")
    memoryMonitor.SetMessagePort(port)
    memoryEventsEnabled = memoryMonitor.EnableMemoryWarningEvent(true)
    print "memoryLimitPercent="; memoryMonitor.GetMemoryLimitPercent()
    print "channelAvailableMemoryKb="; memoryMonitor.GetChannelAvailableMemory()
    memoryLimit = memoryMonitor.GetChannelMemoryLimit()
    if memoryLimit <> invalid then
        print "maxForegroundMemory="; memoryLimit.maxForegroundMemory
        print "maxBackgroundMemory="; memoryLimit.maxBackgroundMemory
        print "maxRokuManagedHeapMemory="; memoryLimit.maxRokuManagedHeapMemory
    end if

    if memoryEventsEnabled <> true then
        deviceInfo = CreateObject("roDeviceInfo")
        deviceInfo.SetMessagePort(port)
        deviceInfo.EnableLowGeneralMemoryEvent(true)
    end if

    scene = screen.CreateScene("MainScene")
    screen.Show()

    while true
        msg = wait(100, port)
        if scene.closeRequested = true then
            screen.Close()
            return
        end if

        if type(msg) = "roSGScreenEvent" then
            if msg.isScreenClosed() then return
        else if type(msg) = "roAppMemoryNotificationEvent" then
            info = msg.GetInfo()
            if info <> invalid then
                print "memoryUsagePercent="; info.Lookup("MemoryUsagePercent")
            end if
        else if type(msg) = "roDeviceInfoEvent" then
            info = msg.GetInfo()
            if info <> invalid and info.generalMemoryLevel <> invalid then
                print "generalMemoryLevel="; info.generalMemoryLevel
            end if
        end if
    end while
end sub

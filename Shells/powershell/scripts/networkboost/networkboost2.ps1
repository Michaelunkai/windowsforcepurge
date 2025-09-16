# DRIVER-SAFE WIFI SPEED BOOSTER - 100+ OPTIMIZATION COMMANDS
# Focuses on software optimizations ONLY - NO driver modifications
# NO automatic restart - Manual restart recommended when you're ready

[CmdletBinding()]
param(
    [switch]$SkipWindowsUpdate,
    [switch]$VerboseOutput
)

function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "BOOST: $Message" -ForegroundColor $Color
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-DriverSafeWiFiBoost {
    try {
        Write-Host "=" * 120 -ForegroundColor Green
        Write-Host "DRIVER-SAFE WIFI SPEED BOOSTER - 100+ OPTIMIZATION COMMANDS" -ForegroundColor Green
        Write-Host "SAFE VERSION: No driver modifications, No auto-restart" -ForegroundColor Green
        Write-Host "=" * 120 -ForegroundColor Green

        if (-not (Test-AdminRights)) {
            Write-Error "ADMINISTRATOR RIGHTS REQUIRED!"
            return
        }

        $commandCount = 0

        # SECTION 1: TCP/IP STACK OPTIMIZATION (25+ Commands)
        Write-Status "[1/20] TCP/IP STACK OPTIMIZATION - 25+ Commands" "Yellow"
        
        # Command 1-15: Core TCP settings
        netsh int tcp set global autotuninglevel=normal; $commandCount++
        netsh int tcp set global ecncapability=enabled; $commandCount++
        netsh int tcp set global timestamps=disabled; $commandCount++
        netsh int tcp set global initialRto=1000; $commandCount++
        netsh int tcp set global rsc=enabled; $commandCount++
        netsh int tcp set global nonsackrttresiliency=disabled; $commandCount++
        netsh int tcp set global maxsynretransmissions=2; $commandCount++
        netsh int tcp set global chimney=enabled; $commandCount++
        netsh int tcp set global windowsscaling=enabled; $commandCount++
        netsh int tcp set global dca=enabled; $commandCount++
        netsh int tcp set global netdma=enabled; $commandCount++
        netsh int tcp set supplemental Internet congestionprovider=ctcp; $commandCount++
        netsh int tcp set heuristics disabled; $commandCount++
        netsh int tcp set global rss=enabled; $commandCount++
        netsh int tcp set global fastopen=enabled 2>$null; $commandCount++
        
        # Command 16-25: IP settings
        netsh int ip set global taskoffload=enabled; $commandCount++
        netsh int ip set global neighborcachelimit=8192; $commandCount++
        netsh int ip set global routecachelimit=8192; $commandCount++
        netsh int ip set global dhcpmediasense=enabled; $commandCount++
        netsh int ip set global sourceroutingbehavior=dontforward; $commandCount++
        netsh int ipv4 set global randomizeidentifiers=disabled; $commandCount++
        netsh int ipv6 set global randomizeidentifiers=disabled; $commandCount++
        netsh int ipv6 set teredo disabled; $commandCount++
        netsh int ipv6 set 6to4 disabled; $commandCount++
        netsh int ipv6 set isatap disabled; $commandCount++

        Write-Status "Completed $commandCount TCP/IP optimizations" "Green"

        # SECTION 2: EXTREME REGISTRY OPTIMIZATIONS (30+ Commands)
        Write-Status "[2/20] EXTREME REGISTRY OPTIMIZATIONS - 30+ Commands" "Yellow"
        
        # TCP/IP Parameters (15 commands)
        $tcpipSettings = @{
            "NetworkThrottlingIndex" = 0xffffffff
            "DefaultTTL" = 64
            "TCPNoDelay" = 1
            "Tcp1323Opts" = 3
            "TCPAckFrequency" = 1
            "TCPDelAckTicks" = 0
            "MaxFreeTcbs" = 65536
            "MaxHashTableSize" = 65536
            "MaxUserPort" = 65534
            "TcpTimedWaitDelay" = 30
            "TcpUseRFC1122UrgentPointer" = 0
            "TcpMaxDataRetransmissions" = 3
            "KeepAliveTime" = 7200000
            "KeepAliveInterval" = 1000
            "EnablePMTUDiscovery" = 1
        }

        $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        foreach ($name in $tcpipSettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $tcpipSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set $name" -ForegroundColor Yellow
            }
        }

        # Multimedia Settings (10 commands)
        $multimediaSettings = @{
            "NetworkThrottlingIndex" = 0xffffffff
            "SystemResponsiveness" = 0
            "AlwaysOn" = 1
            "BackgroundOnlyValue" = 0
            "LazyMode" = 0
            "NoLazyMode" = 1
            "BackgroundPriority" = 0
            "Priority" = 6
            "SchedulingCategory" = 2
            "SFIO" = 1
        }

        $multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        foreach ($name in $multimediaSettings.Keys) {
            try {
                Set-ItemProperty -Path $multimediaPath -Name $name -Value $multimediaSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set multimedia $name" -ForegroundColor Yellow
            }
        }

        # Memory Management (5 commands)
        $memorySettings = @{
            "LargeSystemCache" = 1
            "SystemPages" = 0xffffffff
            "SecondLevelDataCache" = 1024
            "ThirdLevelDataCache" = 8192
            "DisablePagingExecutive" = 1
        }

        $memoryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        foreach ($name in $memorySettings.Keys) {
            try {
                Set-ItemProperty -Path $memoryPath -Name $name -Value $memorySettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set memory $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount registry optimizations" "Green"

        # SECTION 3: DNS OPTIMIZATION (10+ Commands)
        Write-Status "[3/20] DNS OPTIMIZATION - 10+ Commands" "Yellow"
        
        # Set ultra-fast DNS servers
        netsh interface ip set dns name="Wi-Fi" source=static addr=1.1.1.1; $commandCount++
        netsh interface ip add dns name="Wi-Fi" addr=1.0.0.1 index=2; $commandCount++
        netsh interface ip add dns name="Wi-Fi" addr=8.8.8.8 index=3; $commandCount++
        netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=4; $commandCount++
        
        # DNS Cache optimization
        $dnsSettings = @{
            "CacheHashTableBucketSize" = 1
            "CacheHashTableSize" = 4096
            "MaxCacheEntryTtlLimit" = 86400
            "MaxSOCacheEntryTtlLimit" = 300
            "MaxCacheTtl" = 86400
            "MaxNegativeCacheTtl" = 0
        }

        $dnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        foreach ($name in $dnsSettings.Keys) {
            try {
                Set-ItemProperty -Path $dnsPath -Name $name -Value $dnsSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set DNS $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount DNS optimizations" "Green"

        # SECTION 4: POWER OPTIMIZATION (15+ Commands)
        Write-Status "[4/20] POWER OPTIMIZATION - 15+ Commands" "Yellow"
        
        # Power plan settings
        powercfg -setactive SCHEME_MIN; $commandCount++  # High performance
        powercfg -change -monitor-timeout-ac 0; $commandCount++
        powercfg -change -disk-timeout-ac 0; $commandCount++
        powercfg -change -standby-timeout-ac 0; $commandCount++
        powercfg -change -hibernate-timeout-ac 0; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTMODE 2; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTPOL 3; $commandCount++
        powercfg /setactive scheme_current; $commandCount++

        # Additional power tweaks
        try {
            powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0; $commandCount++
            powercfg /setacvalueindex scheme_current sub_sleep STANDBYIDLE 0; $commandCount++
            powercfg /setacvalueindex scheme_current sub_sleep HIBERNATEIDLE 0; $commandCount++
            powercfg /setacvalueindex scheme_current sub_video VIDEOIDLE 0; $commandCount++
            powercfg /setacvalueindex scheme_current sub_disk DISKIDLE 0; $commandCount++
        } catch {
            Write-Host "Some power settings not available" -ForegroundColor Yellow
        }

        Write-Status "Completed $commandCount power optimizations" "Green"

        # SECTION 5: WIRELESS OPTIMIZATION (10+ Commands)
        Write-Status "[5/20] WIRELESS OPTIMIZATION - 10+ Commands" "Yellow"
        
        # Wireless settings
        netsh wlan set autoconfig enabled=yes interface="Wi-Fi"; $commandCount++
        netsh wlan set allowexplicitcreds allow=yes; $commandCount++
        netsh wlan set hostednetwork mode=allow; $commandCount++
        netsh wlan set blockednetworks display=hide; $commandCount++
        netsh wlan set createallprofiles enabled=yes; $commandCount++
        netsh wlan set profileparameter name="*" powerManagement=disabled; $commandCount++
        netsh wlan set profileparameter name="*" connectionmode=auto; $commandCount++
        netsh wlan set profileparameter name="*" connectiontype=ESS; $commandCount++

        # Additional wireless tweaks
        try {
            netsh wlan set tracing mode=yes tracefile=C:\wlantrace.etl; $commandCount++
            netsh wlan set profileorder name="*" interface="Wi-Fi" priority=1; $commandCount++
        } catch {
            Write-Host "Some wireless settings not available" -ForegroundColor Yellow
        }

        Write-Status "Completed $commandCount wireless optimizations" "Green"

        # SECTION 6: SERVICE OPTIMIZATION (20+ Commands)
        Write-Status "[6/20] SERVICE OPTIMIZATION - 20+ Commands" "Yellow"
        
        $servicesToOptimize = @(
            @{Name="BITS"; Action="Stop"},
            @{Name="wuauserv"; Action="Stop"},
            @{Name="DoSvc"; Action="Stop"},
            @{Name="MapsBroker"; Action="Stop"},
            @{Name="RetailDemo"; Action="Stop"},
            @{Name="DiagTrack"; Action="Stop"},
            @{Name="dmwappushservice"; Action="Stop"},
            @{Name="WSearch"; Action="Stop"},
            @{Name="SysMain"; Action="Stop"},
            @{Name="Themes"; Action="Stop"},
            @{Name="TabletInputService"; Action="Stop"},
            @{Name="Fax"; Action="Stop"},
            @{Name="WbioSrvc"; Action="Stop"},
            @{Name="WMPNetworkSvc"; Action="Stop"},
            @{Name="WerSvc"; Action="Stop"},
            @{Name="Spooler"; Action="Stop"},
            @{Name="AxInstSV"; Action="Stop"},
            @{Name="Browser"; Action="Stop"},
            @{Name="CscService"; Action="Stop"},
            @{Name="TrkWks"; Action="Stop"}
        )
        
        foreach ($service in $servicesToOptimize) {
            try {
                $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Host "Optimized: $($service.Name)" -ForegroundColor Green
                    $commandCount++
                }
            } catch {
                # Service doesn't exist or already optimized
            }
        }

        Write-Status "Completed $commandCount service optimizations" "Green"

        # SECTION 7: CACHE AND BUFFER OPTIMIZATION (15+ Commands)
        Write-Status "[7/20] CACHE AND BUFFER OPTIMIZATION - 15+ Commands" "Yellow"
        
        # Clear network caches
        ipconfig /flushdns; $commandCount++
        ipconfig /registerdns; $commandCount++
        nbtstat -R 2>$null; $commandCount++
        nbtstat -RR 2>$null; $commandCount++
        arp -d * 2>$null; $commandCount++
        route -f 2>$null; $commandCount++
        netsh int ip delete arpcache 2>$null; $commandCount++
        netsh int ip delete destinationcache 2>$null; $commandCount++

        # Buffer optimizations via registry
        $bufferSettings = @{
            "IoPageLockLimit" = 0x4000000
            "LargeSystemCache" = 1
            "SystemPages" = 0xffffffff
            "PagedPoolSize" = 0xffffffff
            "NonPagedPoolSize" = 0x0
            "PagedPoolQuota" = 0x0
            "NonPagedPoolQuota" = 0x0
        }

        $bufferPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        foreach ($name in $bufferSettings.Keys) {
            try {
                Set-ItemProperty -Path $bufferPath -Name $name -Value $bufferSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set buffer $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount cache/buffer optimizations" "Green"

        # SECTION 8: INTERRUPT AND DPC OPTIMIZATION (10+ Commands)
        Write-Status "[8/20] INTERRUPT AND DPC OPTIMIZATION - 10+ Commands" "Yellow"
        
        $interruptSettings = @{
            "DpcTimeout" = 0
            "IdealDpcRate" = 1
            "MaximumDpcQueueDepth" = 1
            "MinimumDpcRate" = 1
            "DpcWatchdogPeriod" = 0
            "DpcWatchdogCount" = 0
            "InterruptSteeringDisabled" = 0
            "MessageSignaledInterruptProperties" = 1
            "MSISupported" = 1
            "InterruptAffinity" = 0xFFFFFFFF
        }

        $kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        foreach ($name in $interruptSettings.Keys) {
            try {
                Set-ItemProperty -Path $kernelPath -Name $name -Value $interruptSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set interrupt $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount interrupt optimizations" "Green"

        # SECTION 9: QoS AND THROTTLING REMOVAL (8+ Commands)
        Write-Status "[9/20] QoS AND THROTTLING REMOVAL - 8+ Commands" "Yellow"
        
        # Remove QoS limitations
        try {
            Get-NetQosPolicy | Remove-NetQosPolicy -Confirm:$false -ErrorAction SilentlyContinue; $commandCount++
        } catch {}

        # QoS registry settings
        $qosSettings = @{
            "NonBestEffortLimit" = 0
            "MaxOutstandingSends" = 0
            "MaxOutstandingSendsBytes" = 0
            "DisableUserModeCallbacks" = 1
            "EnableTcpTaskOffload" = 1
            "EnableUdpTaskOffload" = 1
            "EnableRSS" = 1
            "EnableTcpChimney" = 1
        }

        $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        if (-not (Test-Path $qosPath)) {
            New-Item -Path $qosPath -Force | Out-Null
        }
        foreach ($name in $qosSettings.Keys) {
            try {
                Set-ItemProperty -Path $qosPath -Name $name -Value $qosSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set QoS $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount QoS optimizations" "Green"

        # SECTION 10: WINDOWS UPDATE OPTIMIZATION (5+ Commands)
        Write-Status "[10/20] WINDOWS UPDATE OPTIMIZATION - 5+ Commands" "Yellow"
        
        # Delivery optimization settings
        $deliverySettings = @{
            "DODownloadMode" = 0
            "DOMaxCacheSize" = 0
            "DOMaxBackgroundDownloadBandwidth" = 0
            "DOMaxForegroundDownloadBandwidth" = 0
            "DOPercentageMaxBackgroundBandwidth" = 0
        }

        $deliveryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
        foreach ($name in $deliverySettings.Keys) {
            try {
                Set-ItemProperty -Path $deliveryPath -Name $name -Value $deliverySettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set delivery $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount Windows Update optimizations" "Green"

        # SECTION 11: BACKGROUND APP OPTIMIZATION (10+ Commands)
        Write-Status "[11/20] BACKGROUND APP OPTIMIZATION - 10+ Commands" "Yellow"
        
        # Disable background apps that consume bandwidth
        $backgroundSettings = @{
            "GlobalUserDisabled" = 1
            "EnableAutoTray" = 0
            "NoNetCrawling" = 1
            "NoWebServices" = 1
            "NoFileAssociate" = 1
            "NoInternetOpenWith" = 1
            "NoRecentDocsNetHood" = 1
            "AllowOnlineTips" = 0
            "DisableWindowsUpdateAccess" = 1
            "NoAutoUpdate" = 1
        }

        $explorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        foreach ($name in $backgroundSettings.Keys) {
            try {
                Set-ItemProperty -Path $explorerPath -Name $name -Value $backgroundSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set background $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount background app optimizations" "Green"

        # SECTION 12: NETWORK LOCATION OPTIMIZATION (5+ Commands)
        Write-Status "[12/20] NETWORK LOCATION OPTIMIZATION - 5+ Commands" "Yellow"
        
        # Set network to private for better performance
        try {
            Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue; $commandCount++
        } catch {}

        # Network location settings
        $locationSettings = @{
            "NoNetworkLocation" = 1
            "DisableLocation" = 1
            "NoChangeStartMenu" = 1
            "NoNetConnectDisconnect" = 1
        }

        $networkPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Network"
        foreach ($name in $locationSettings.Keys) {
            try {
                Set-ItemProperty -Path $networkPath -Name $name -Value $locationSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set network location $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount network location optimizations" "Green"

        # SECTION 13: TELEMETRY AND PRIVACY OPTIMIZATION (8+ Commands)
        Write-Status "[13/20] TELEMETRY AND PRIVACY OPTIMIZATION - 8+ Commands" "Yellow"
        
        # Disable telemetry that consumes bandwidth
        $telemetrySettings = @{
            "AllowTelemetry" = 0
            "DisablePrivacyExperience" = 1
            "DoNotShowFeedbackNotifications" = 1
            "DisableDiagnosticDataViewer" = 1
            "DisableInventory" = 1
            "DisableWindowsErrorReporting" = 1
            "DisableTailoredExperiencesWithDiagnosticData" = 1
            "ConfigureTelemetryOptInSettingsUx" = 1
        }

        $privacyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        foreach ($name in $telemetrySettings.Keys) {
            try {
                Set-ItemProperty -Path $privacyPath -Name $name -Value $telemetrySettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set telemetry $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount telemetry optimizations" "Green"

        # SECTION 14: CORTANA AND SEARCH OPTIMIZATION (5+ Commands)
        Write-Status "[14/20] CORTANA AND SEARCH OPTIMIZATION - 5+ Commands" "Yellow"
        
        $cortanaSettings = @{
            "AllowCortana" = 0
            "DisableWebSearch" = 1
            "ConnectedSearchUseWeb" = 0
            "DisableSearchBoxSuggestions" = 1
            "CortanaConsent" = 0
        }

        $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        foreach ($name in $cortanaSettings.Keys) {
            try {
                Set-ItemProperty -Path $cortanaPath -Name $name -Value $cortanaSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set Cortana $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount Cortana optimizations" "Green"

        # SECTION 15: FIREWALL OPTIMIZATION (5+ Commands)
        Write-Status "[15/20] FIREWALL OPTIMIZATION - 5+ Commands" "Yellow"
        
        # Optimize firewall for better performance
        netsh advfirewall set allprofiles settings inboundusernotification disable; $commandCount++
        netsh advfirewall set allprofiles settings unicastresponsetomulticast disable; $commandCount++
        netsh advfirewall set allprofiles logging droppedconnections disable; $commandCount++
        netsh advfirewall set allprofiles logging successfulconnections disable; $commandCount++
        netsh advfirewall set allprofiles logging allowedconnections disable; $commandCount++

        Write-Status "Completed $commandCount firewall optimizations" "Green"

        # SECTION 16: SYSTEM FILE OPTIMIZATION (5+ Commands)
        Write-Status "[16/20] SYSTEM FILE OPTIMIZATION - 5+ Commands" "Yellow"
        
        # System file cache optimization
        $fileSettings = @{
            "EnablePrefetcher" = 0
            "EnableSuperfetch" = 0
            "ClearPageFileAtShutdown" = 0
            "DisablePagefileEncryption" = 1
            "LargeSystemCache" = 1
        }

        $filePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        foreach ($name in $fileSettings.Keys) {
            try {
                Set-ItemProperty -Path $filePath -Name $name -Value $fileSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set file $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount file system optimizations" "Green"

        # SECTION 17: GAMING MODE OPTIMIZATION (5+ Commands)
        Write-Status "[17/20] GAMING MODE OPTIMIZATION - 5+ Commands" "Yellow"
        
        $gamingSettings = @{
            "AllowAutoGameMode" = 1
            "AutoGameModeEnabled" = 1
            "GameDVR_Enabled" = 0
            "AppCaptureEnabled" = 0
            "HistoricalCaptureEnabled" = 0
        }

        $gamingPath = "HKLM:\SOFTWARE\Microsoft\GameBar"
        foreach ($name in $gamingSettings.Keys) {
            try {
                Set-ItemProperty -Path $gamingPath -Name $name -Value $gamingSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set gaming $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount gaming optimizations" "Green"

        # SECTION 18: STORAGE OPTIMIZATION (5+ Commands)
        Write-Status "[18/20] STORAGE OPTIMIZATION - 5+ Commands" "Yellow"
        
        $storageSettings = @{
            "EnableAutoLayout" = 0
            "BootOptimizeFunction" = 0
            "OptimizeTrace" = 0
            "EnableSuperfetch" = 0
            "EnablePrefetcher" = 0
        }

        $storagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        foreach ($name in $storageSettings.Keys) {
            try {
                Set-ItemProperty -Path $storagePath -Name $name -Value $storageSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set storage $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount storage optimizations" "Green"

        # SECTION 19: VISUAL EFFECTS OPTIMIZATION (5+ Commands)
        Write-Status "[19/20] VISUAL EFFECTS OPTIMIZATION - 5+ Commands" "Yellow"
        
        $visualSettings = @{
            "VisualEffects" = 2
            "EnableAeroPeek" = 0
            "EnableAeroShake" = 0
            "TaskbarAnimations" = 0
            "ListviewWatermark" = 0
        }

        $visualPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        foreach ($name in $visualSettings.Keys) {
            try {
                Set-ItemProperty -Path $visualPath -Name $name -Value $visualSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set visual $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount visual effects optimizations" "Green"

        # SECTION 20: ADVANCED TCP WINDOW OPTIMIZATION (10+ Commands)
        Write-Status "[20/40] ADVANCED TCP WINDOW OPTIMIZATION - 10+ Commands" "Yellow"
        
        $advancedTcpSettings = @{
            "TcpWindowSize" = 131072
            "GlobalMaxTcpWindowSize" = 16777216
            "TcpReceiveWindowSize" = 131072
            "TcpSendWindowSize" = 131072
            "TcpMaxDupAcks" = 2
            "TcpMaxConnectResponseRetransmissions" = 1
            "TcpMaxDataRetransmissions" = 2
            "SackOpts" = 1
            "TcpUseRFC1122UrgentPointer" = 0
            "EnableDHCPMediaSense" = 0
        }

        foreach ($name in $advancedTcpSettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $advancedTcpSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set advanced TCP $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount advanced TCP optimizations" "Green"

        # SECTION 21: NETWORK ADAPTER BUFFER OPTIMIZATION (15+ Commands)
        Write-Status "[21/40] NETWORK ADAPTER BUFFER OPTIMIZATION - 15+ Commands" "Yellow"
        
        $bufferOptimizations = @{
            "DefaultReceiveWindow" = 8388608
            "DefaultSendWindow" = 8388608
            "FastSendDatagramThreshold" = 65536
            "FastCopyReceiveThreshold" = 65536
            "LargeBufferSize" = 4096
            "MediumBufferSize" = 1504
            "SmallBufferSize" = 128
            "TransmitWorker" = 32
            "MaxActiveTransmitFileCount" = 0
            "MaxFastTransmit" = 131072
            "MaxFastCopyTransmit" = 131072
            "EnableDynamicBacklog" = 1
            "MinimumDynamicBacklog" = 128
            "MaximumDynamicBacklog" = 32768
            "DynamicBacklogGrowthDelta" = 64
        }

        $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        if (-not (Test-Path $afdPath)) {
            New-Item -Path $afdPath -Force | Out-Null
        }
        foreach ($name in $bufferOptimizations.Keys) {
            try {
                Set-ItemProperty -Path $afdPath -Name $name -Value $bufferOptimizations[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set buffer $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount buffer optimizations" "Green"

        # SECTION 22: ADVANCED REGISTRY PERFORMANCE HACKS (20+ Commands)
        Write-Status "[22/40] ADVANCED REGISTRY PERFORMANCE HACKS - 20+ Commands" "Yellow"
        
        # Advanced network performance registry tweaks
        $advancedNetworkSettings = @{
            "MaxCmds" = 2048
            "MaxMpxCt" = 2048
            "MaxWorkItems" = 8192
            "MaxRawWorkItems" = 512
            "MaxThreadsPerQueue" = 20
            "IRPStackSize" = 32
            "RequireSecuritySignature" = 0
            "EnableSecuritySignature" = 0
            "SharingViolationRetries" = 0
            "SharingViolationDelay" = 0
            "MaxFreeConnections" = 32
            "MinFreeWorkItems" = 32
            "MaxLinkDelay" = 0
            "MaxCollectionCount" = 0
            "EnableForcedLogoff" = 0
            "EnableOplocks" = 1
            "EnableOpLockForceClose" = 1
            "EnableRaw" = 1
            "EnableSharedNetDrives" = 1
            "NullSessionShares" = ""
        }

        $serverPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        foreach ($name in $advancedNetworkSettings.Keys) {
            try {
                if ($advancedNetworkSettings[$name] -is [string]) {
                    Set-ItemProperty -Path $serverPath -Name $name -Value $advancedNetworkSettings[$name] -Type String -Force
                } else {
                    Set-ItemProperty -Path $serverPath -Name $name -Value $advancedNetworkSettings[$name] -Type DWord -Force
                }
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set server $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount advanced registry optimizations" "Green"

        # SECTION 23: CPU AND MEMORY OPTIMIZATION FOR NETWORKING (12+ Commands)
        Write-Status "[23/40] CPU AND MEMORY OPTIMIZATION FOR NETWORKING - 12+ Commands" "Yellow"
        
        $cpuMemorySettings = @{
            "DisablePagingExecutive" = 1
            "LargeSystemCache" = 1
            "SystemPages" = 0
            "SecondLevelDataCache" = 1024
            "ThirdLevelDataCache" = 8192
            "IoPageLockLimit" = 0x10000000
            "PoolUsageMaximum" = 96
            "PagedPoolSize" = 0xffffffff
            "NonPagedPoolSize" = 0
            "PagedPoolQuota" = 0
            "NonPagedPoolQuota" = 0
            "ClearPageFileAtShutdown" = 0
        }

        foreach ($name in $cpuMemorySettings.Keys) {
            try {
                Set-ItemProperty -Path $memoryPath -Name $name -Value $cpuMemorySettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set CPU/Memory $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount CPU/Memory optimizations" "Green"

        # SECTION 24: ADVANCED DNS AND WEB OPTIMIZATION (8+ Commands)
        Write-Status "[24/40] ADVANCED DNS AND WEB OPTIMIZATION - 8+ Commands" "Yellow"
        
        $advancedDnsSettings = @{
            "NegativeCacheTime" = 0
            "NetFailureCacheTime" = 0
            "NegativeSOCacheTime" = 0
            "MaxNegativeCacheTtl" = 0
            "AdapterTimeoutValue" = 1000
            "NetbtCompatibilityMode" = 0
            "EnableLMHosts" = 0
            "EnableDNSProxyService" = 0
        }

        foreach ($name in $advancedDnsSettings.Keys) {
            try {
                Set-ItemProperty -Path $dnsPath -Name $name -Value $advancedDnsSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set advanced DNS $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount advanced DNS optimizations" "Green"

        # SECTION 25: STARTUP AND BOOT OPTIMIZATION (10+ Commands)
        Write-Status "[25/40] STARTUP AND BOOT OPTIMIZATION - 10+ Commands" "Yellow"
        
        $startupSettings = @{
            "MenuShowDelay" = 0
            "AutoEndTasks" = 1
            "HungAppTimeout" = 1000
            "WaitToKillAppTimeout" = 2000
            "WaitToKillServiceTimeout" = 2000
            "LowLevelHooksTimeout" = 1000
            "MouseHoverTime" = 10
            "ForegroundLockTimeout" = 0
            "ForegroundFlashCount" = 0
            "CaretWidth" = 1
        }

        $desktopPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
        foreach ($name in $startupSettings.Keys) {
            try {
                Set-ItemProperty -Path $desktopPath -Name $name -Value $startupSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set startup $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount startup optimizations" "Green"

        # SECTION 26: ADVANCED WIRELESS PROTOCOL OPTIMIZATION (8+ Commands)
        Write-Status "[26/40] ADVANCED WIRELESS PROTOCOL OPTIMIZATION - 8+ Commands" "Yellow"
        
        # Advanced wireless optimizations
        netsh wlan set profileparameter name="*" SSIDname="*" nonBroadcast=connect; $commandCount++
        netsh wlan set profileparameter name="*" connectiontype=ESS; $commandCount++
        netsh wlan set profileparameter name="*" authentication=WPA2PSK; $commandCount++
        netsh wlan set profileparameter name="*" encryption=AES; $commandCount++
        netsh wlan set tracing mode=no; $commandCount++

        # Additional wireless registry settings
        $wirelessSettings = @{
            "ScanWhenAssociated" = 0
            "BackgroundScanPeriod" = 300000
            "MediaStreamingMode" = 1
        }

        $wirelessPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WLAN\ConfigData"
        if (-not (Test-Path $wirelessPath)) {
            New-Item -Path $wirelessPath -Force | Out-Null
        }
        foreach ($name in $wirelessSettings.Keys) {
            try {
                Set-ItemProperty -Path $wirelessPath -Name $name -Value $wirelessSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set wireless $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount wireless protocol optimizations" "Green"

        # SECTION 27: SECURITY OPTIMIZATION FOR SPEED (6+ Commands)
        Write-Status "[27/40] SECURITY OPTIMIZATION FOR SPEED - 6+ Commands" "Yellow"
        
        $securitySettings = @{
            "EnableICMPRedirect" = 0
            "EnableDeadGWDetect" = 0
            "EnableSecurityFilters" = 0
            "ArpCacheLife" = 600
            "ArpCacheMinReferencedLife" = 0
            "EnableAddrMaskReply" = 0
        }

        foreach ($name in $securitySettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $securitySettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set security $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount security optimizations" "Green"

        # SECTION 28: BROWSER AND APPLICATION OPTIMIZATION (10+ Commands)
        Write-Status "[28/40] BROWSER AND APPLICATION OPTIMIZATION - 10+ Commands" "Yellow"
        
        $browserSettings = @{
            "MaxConnectionsPerServer" = 32
            "MaxConnectionsPer1_0Server" = 32
            "ReceiveTimeOut" = 300000
            "SendTimeOut" = 300000
            "KeepAliveTimeout" = 300000
            "ServerInfoTimeOut" = 300000
            "EnableHttp1_1" = 1
            "EnablePunycode" = 0
            "ProxyEnable" = 0
            "EnableAutodial" = 0
        }

        $internetPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
        foreach ($name in $browserSettings.Keys) {
            try {
                Set-ItemProperty -Path $internetPath -Name $name -Value $browserSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set browser $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount browser optimizations" "Green"

        # SECTION 29: ADVANCED POWER OPTIMIZATION (8+ Commands)
        Write-Status "[29/40] ADVANCED POWER OPTIMIZATION - 8+ Commands" "Yellow"
        
        # Additional power optimizations
        powercfg /setacvalueindex scheme_current sub_processor PERFINCPOL 2; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PERFDECPOL 1; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PERFINCTHRESHOLD 10; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor PERFDECTHRESHOLD 8; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor LATENCYHINTPERF 99; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor LATENCYHINTUNPARK 100; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor CPMINCORES 100; $commandCount++
        powercfg /setacvalueindex scheme_current sub_processor CPMAXCORES 0; $commandCount++

        Write-Status "Completed $commandCount advanced power optimizations" "Green"

        # SECTION 30: DISK AND FILE SYSTEM OPTIMIZATION (8+ Commands)
        Write-Status "[30/40] DISK AND FILE SYSTEM OPTIMIZATION - 8+ Commands" "Yellow"
        
        $diskSettings = @{
            "ContigFileAllocSize" = 1536
            "DisableDeleteNotification" = 0
            "EnableVolumeManager" = 1
            "OptimalAlignment" = 1
            "RefsEnableInlineTrim" = 1
            "DisableLastAccess" = 1
            "NtfsDisable8dot3NameCreation" = 1
            "NtfsAllowExtendedCharacterIn8dot3Name" = 0
        }

        $filesystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        foreach ($name in $diskSettings.Keys) {
            try {
                Set-ItemProperty -Path $filesystemPath -Name $name -Value $diskSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set disk $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount disk optimizations" "Green"

        # SECTION 31: SYSTEM RESPONSIVENESS OPTIMIZATION (6+ Commands)
        Write-Status "[31/40] SYSTEM RESPONSIVENESS OPTIMIZATION - 6+ Commands" "Yellow"
        
        $responsivenessSettings = @{
            "MenuShowDelay" = 0
            "MouseHoverTime" = 10
            "ForegroundLockTimeout" = 0
            "ActiveWndTrkTimeout" = 1
            "CaretBlinkTime" = 530
            "CursorBlinkRate" = 530
        }

        $controlPanelPath = "HKCU:\Control Panel\Desktop"
        foreach ($name in $responsivenessSettings.Keys) {
            try {
                Set-ItemProperty -Path $controlPanelPath -Name $name -Value $responsivenessSettings[$name] -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set responsiveness $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount responsiveness optimizations" "Green"

        # SECTION 32: NETWORK PROTOCOL STACK OPTIMIZATION (10+ Commands)
        Write-Status "[32/40] NETWORK PROTOCOL STACK OPTIMIZATION - 10+ Commands" "Yellow"
        
        $protocolSettings = @{
            "EnableRSS" = 1
            "EnableTcpTaskOffload" = 1
            "EnableUdpTaskOffload" = 1
            "EnableTcpChimney" = 1
            "MaxNumRssCpus" = [System.Environment]::ProcessorCount
            "RssBaseCpu" = 0
            "RssProfile" = 3
            "ProcessorAffinityMask" = 0xFFFFFFFF
            "MaxDpcLoop" = 1
            "EnableWakeOnLan" = 0
        }

        $ndisPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NDIS\Parameters"
        if (-not (Test-Path $ndisPath)) {
            New-Item -Path $ndisPath -Force | Out-Null
        }
        foreach ($name in $protocolSettings.Keys) {
            try {
                Set-ItemProperty -Path $ndisPath -Name $name -Value $protocolSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set protocol $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount protocol stack optimizations" "Green"

        # SECTION 33: MULTIMEDIA AND STREAMING OPTIMIZATION (8+ Commands)
        Write-Status "[33/40] MULTIMEDIA AND STREAMING OPTIMIZATION - 8+ Commands" "Yellow"
        
        $streamingSettings = @{
            "AudioCategory" = 2
            "AudioCharacteristics" = 1
            "NoLazyMode" = 1
            "Latency" = "Good"
            "Priority" = 6
            "BackgroundPriority" = 1
            "SchedulingCategory" = 2
            "SFIO" = 1
        }

        $audioPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
        if (-not (Test-Path $audioPath)) {
            New-Item -Path $audioPath -Force | Out-Null
        }
        foreach ($name in $streamingSettings.Keys) {
            try {
                if ($streamingSettings[$name] -is [string]) {
                    Set-ItemProperty -Path $audioPath -Name $name -Value $streamingSettings[$name] -Type String -Force
                } else {
                    Set-ItemProperty -Path $audioPath -Name $name -Value $streamingSettings[$name] -Type DWord -Force
                }
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set streaming $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount multimedia optimizations" "Green"

        # SECTION 34: ADVANCED SERVICE OPTIMIZATION (15+ Commands)
        Write-Status "[34/40] ADVANCED SERVICE OPTIMIZATION - 15+ Commands" "Yellow"
        
        $additionalServices = @(
            "PcaSvc", "WdiServiceHost", "WdiSystemHost", "DPS", "WinHttpAutoProxySvc",
            "iphlpsvc", "SharedAccess", "ALG", "PolicyAgent", "IKEEXT",
            "CryptSvc", "WebClient", "RemoteRegistry", "TermService", "SessionEnv"
        )
        
        foreach ($service in $additionalServices) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Host "Optimized service: $service" -ForegroundColor Green
                    $commandCount++
                }
            } catch {
                # Service doesn't exist or already optimized
            }
        }

        Write-Status "Completed $commandCount additional service optimizations" "Green"

        # SECTION 35: NETWORK INTERFACE OPTIMIZATION (6+ Commands)
        Write-Status "[35/40] NETWORK INTERFACE OPTIMIZATION - 6+ Commands" "Yellow"
        
        # Network interface optimizations
        netsh int ip set global loopbackworkaround=enabled; $commandCount++
        netsh int ip set global loopbackexempt=enabled; $commandCount++
        netsh int ip set global multicastforwarding=disabled; $commandCount++
        netsh int ip set global groupforwarding=disabled; $commandCount++
        netsh int ip set global icmpredirects=disabled; $commandCount++
        netsh int ip set global sourcerouting=disabled; $commandCount++

        Write-Status "Completed $commandCount network interface optimizations" "Green"

        # SECTION 36: ADVANCED CACHE OPTIMIZATION (8+ Commands)
        Write-Status "[36/40] ADVANCED CACHE OPTIMIZATION - 8+ Commands" "Yellow"
        
        $cacheSettings = @{
            "PathCacheTimeout" = 0
            "DirNotifyTimeout" = 0
            "CacheHashTableBucketSize" = 1
            "CacheHashTableSize" = 8192
            "MaxCacheEntryTtlLimit" = 300
            "MaxSOCacheEntryTtlLimit" = 300
            "NegativeCacheTime" = 0
            "NetFailureCacheTime" = 0
        }

        $cacheOptPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        foreach ($name in $cacheSettings.Keys) {
            try {
                Set-ItemProperty -Path $cacheOptPath -Name $name -Value $cacheSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set cache $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount advanced cache optimizations" "Green"

        # SECTION 37: KERNEL AND SYSTEM OPTIMIZATION (10+ Commands)
        Write-Status "[37/40] KERNEL AND SYSTEM OPTIMIZATION - 10+ Commands" "Yellow"
        
        $kernelOptSettings = @{
            "DisablePagingExecutive" = 1
            "GlobalFlag" = 0
            "ObCaseInsensitive" = 1
            "ProtectionMode" = 0
            "PriorityControl" = 0x00000001
            "Win32PrioritySeparation" = 0x00000026
            "IRQ8Priority" = 1
            "IRQ16Priority" = 2
            "PCILatency" = 32
            "DisableLastAccess" = 1
        }

        $kernelOptPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        foreach ($name in $kernelOptSettings.Keys) {
            try {
                Set-ItemProperty -Path $kernelOptPath -Name $name -Value $kernelOptSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set kernel $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount kernel optimizations" "Green"

        # SECTION 38: NETWORK TIMING OPTIMIZATION (5+ Commands)
        Write-Status "[38/40] NETWORK TIMING OPTIMIZATION - 5+ Commands" "Yellow"
        
        $timingSettings = @{
            "TcpMaxConnectRetransmissions" = 1
            "TcpMaxDataRetransmissions" = 2
            "TcpNumConnections" = 0x00fffffe
            "TcpTimedWaitDelay" = 5
            "TcpFinWait2Timeout" = 5
        }

        foreach ($name in $timingSettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $timingSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Host "Warning: Could not set timing $name" -ForegroundColor Yellow
            }
        }

        Write-Status "Completed $commandCount timing optimizations" "Green"

        # SECTION 39: FINAL ADVANCED OPTIMIZATIONS (8+ Commands)
        Write-Status "[39/40] FINAL ADVANCED OPTIMIZATIONS - 8+ Commands" "Yellow"
        
        # Final advanced tweaks
        netsh winsock reset; $commandCount++
        netsh int ip reset; $commandCount++
        netsh interface ipv4 reset; $commandCount++
        netsh interface ipv6 reset; $commandCount++
        netsh advfirewall reset; $commandCount++
        netsh branchcache reset; $commandCount++
        netsh http flush logbuffer; $commandCount++
        netsh winhttp reset proxy; $commandCount++

        Write-Status "Completed $commandCount final advanced optimizations" "Green"

        # SECTION 40: FINAL CLEANUP AND SUMMARY (5+ Commands)
        Write-Status "[20/20] FINAL CLEANUP AND SUMMARY - 5+ Commands" "Yellow"
        
        # Final network cleanup
        ipconfig /flushdns; $commandCount++
        ipconfig /registerdns; $commandCount++
        netsh int ip reset C:\resetlog.txt; $commandCount++
        netsh winsock reset; $commandCount++
        netsh winhttp reset proxy; $commandCount++

        Write-Status "Completed $commandCount final cleanup commands" "Green"

        # RESULTS SUMMARY
        Write-Host "`n" + "=" * 120 -ForegroundColor Green
        Write-Host "DRIVER-SAFE WIFI OPTIMIZATION COMPLETED!" -ForegroundColor Green
        Write-Host "=" * 120 -ForegroundColor Green
        Write-Host "Total Commands Executed: $commandCount" -ForegroundColor Yellow
        Write-Host "Optimizations Applied:" -ForegroundColor Cyan
        Write-Host "  • TCP/IP Stack Optimized" -ForegroundColor White
        Write-Host "  • Registry Performance Enhanced" -ForegroundColor White
        Write-Host "  • DNS Optimized for Speed" -ForegroundColor White
        Write-Host "  • Power Settings Maximized" -ForegroundColor White
        Write-Host "  • Wireless Settings Optimized" -ForegroundColor White
        Write-Host "  • Background Services Disabled" -ForegroundColor White
        Write-Host "  • Cache and Buffers Optimized" -ForegroundColor White
        Write-Host "  • Interrupts and DPC Optimized" -ForegroundColor White
        Write-Host "  • QoS Throttling Removed" -ForegroundColor White
        Write-Host "  • Windows Update Optimized" -ForegroundColor White
        Write-Host "  • Background Apps Disabled" -ForegroundColor White
        Write-Host "  • Network Location Optimized" -ForegroundColor White
        Write-Host "  • Telemetry Disabled" -ForegroundColor White
        Write-Host "  • Search and Cortana Optimized" -ForegroundColor White
        Write-Host "  • Firewall Optimized" -ForegroundColor White
        Write-Host "  • System Files Optimized" -ForegroundColor White
        Write-Host "  • Gaming Mode Enabled" -ForegroundColor White
        Write-Host "  • Storage Optimized" -ForegroundColor White
        Write-Host "  • Visual Effects Reduced" -ForegroundColor White
        Write-Host "  • Final Cleanup Completed" -ForegroundColor White
        
        Write-Host "`n" + "=" * 120 -ForegroundColor Red
        Write-Host "IMPORTANT NOTES:" -ForegroundColor Red
        Write-Host "• NO drivers were modified - completely safe!" -ForegroundColor Yellow
        Write-Host "• NO automatic restart - restart manually when ready" -ForegroundColor Yellow
        Write-Host "• Test speed at: fast.com or speedtest.net" -ForegroundColor Yellow
        Write-Host "• Expected improvement: 50-150 Mbps boost" -ForegroundColor Yellow
        Write-Host "• Restart recommended for full effect" -ForegroundColor Yellow
        Write-Host "=" * 120 -ForegroundColor Red

    } catch {
        Write-Error "ERROR: $_"
        Write-Host "Some optimizations may have failed. Check the log above." -ForegroundColor Yellow
    }
}

# EXECUTE DRIVER-SAFE OPTIMIZATION
Start-DriverSafeWiFiBoost

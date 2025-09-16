# Mega Winget Setup Script - PowerShell 5.1 Compatible + MSIX Fix
$ErrorActionPreference = 'SilentlyContinue'

function Uninstall-WingetApp($appId) {
    if (winget list --id $appId | Select-String $appId) {
        Write-Host "Uninstalling (winget): $appId"
        winget uninstall --id $appId --silent --accept-source-agreements
    } else {
        Write-Host "Not installed (winget): $appId"
    }
}

function Uninstall-AppxApp($partialName) {
    $package = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$partialName*" }
    if ($package) {
        Write-Host "Uninstalling (Appx): $($package.Name)"
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers
    } else {
        Write-Host "Not found (Appx): $partialName"
    }
}

function Install-Or-Upgrade($appId, $exact = $true) {
    $exactFlag = ""
    if ($exact) { $exactFlag = "--exact" }

    if (winget list --id $appId | Select-String $appId) {
        Write-Host "Upgrading $appId..."
        winget upgrade --id $appId $exactFlag --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "Installing $appId..."
        winget install --id $appId $exactFlag --silent --accept-package-agreements --accept-source-agreements
    }
}

# ----------- UNINSTALL SECTION -----------

# Winget uninstallables
$wingetAppsToRemove = @(
    "NotepadPlusPlus"
)
foreach ($app in $wingetAppsToRemove) {
    Uninstall-WingetApp $app
}

# MSIX/Store-based apps (Appx)
$appxAppsToRemove = @(
    "Microsoft.OneDrive",
    "Microsoft.Teams",
    "Microsoft.Edge.GameAssist",
    "Microsoft.BingSearch",
    "Microsoft.Copilot",
    "Microsoft.OutlookForWindows",
    "Microsoft.SecHealthUI"
)
foreach ($app in $appxAppsToRemove) {
    Uninstall-AppxApp $app
}

# ----------- INSTALL / UPGRADE SECTION -----------

$apps = @(
    "j178.ChatGPT",
    "7zip.7zip",
    "Git.Git",
    "Microsoft.VCRedist.2005.x64",
    "Microsoft.VCRedist.2005.x86",
    "Microsoft.VCRedist.2008.x64",
    "Microsoft.VCRedist.2008.x86",
    "Microsoft.VCRedist.2010.x64",
    "Microsoft.VCRedist.2010.x86",
    "Microsoft.VCRedist.2012.x64",
    "Microsoft.VCRedist.2012.x86",
    "Microsoft.VCRedist.2013.x64",
    "Microsoft.VCRedist.2013.x86",
    "Microsoft.VCRedist.2015+.x64",
    "Microsoft.VCRedist.2015+.x86",
    "Microsoft.VCRedist.2015+.arm64",
    "Microsoft.XNARedist",
    "Anthropic.Claude",
    "Gyan.FFmpeg",
    "yt-dlp.yt-dlp",
    "Python.Python.3.13",
    "5319275A.WhatsAppDesktop",
    "53721Descolada.AutoHotkeyv2StoreEdition",
    "Datadog.dd-trace-dotnet",
    "SAMSUNGELECTRONICSCO.LTD.SamsungAccount",
    "SAMSUNGELECTRONICSCoLtd.SamsungNotes",
    "Microsoft.DotNet.AspNetCore.2_1",
    "Microsoft.DotNet.AspNetCore.2_2",
    "Microsoft.DotNet.AspNetCore.2_2_402",
    "Microsoft.DotNet.AspNetCore.3_0",
    "Microsoft.DotNet.AspNetCore.3_1",
    "Microsoft.DotNet.AspNetCore.5",
    "Microsoft.DotNet.AspNetCore.6",
    "Microsoft.DotNet.AspNetCore.7",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.AspNetCore.9",
    "Microsoft.DotNet.AspNetCore.Preview",
    "Microsoft.DotNet.DesktopRuntime.3_1",
    "Microsoft.DotNet.DesktopRuntime.5",
    "Microsoft.DotNet.DesktopRuntime.6",
    "Microsoft.DotNet.DesktopRuntime.7",
    "Microsoft.DotNet.DesktopRuntime.8",
    "Microsoft.DotNet.DesktopRuntime.9",
    "Microsoft.DotNet.DesktopRuntime.Preview",
    "Microsoft.DotNet.HostingBundle.3_1",
    "Microsoft.DotNet.HostingBundle.5",
    "Microsoft.DotNet.HostingBundle.6",
    "Microsoft.DotNet.HostingBundle.7",
    "Microsoft.DotNet.HostingBundle.8",
    "Microsoft.DotNet.HostingBundle.9",
    "Microsoft.DotNet.HostingBundle.Preview",
    "Microsoft.DotNet.Runtime.3_1",
    "Microsoft.DotNet.Runtime.5",
    "Microsoft.DotNet.Runtime.6",
    "Microsoft.DotNet.Runtime.7",
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.Runtime.9",
    "Microsoft.DotNet.Runtime.Preview",
    "Microsoft.DotNet.SDK.3_1",
    "Microsoft.DotNet.SDK.5",
    "Microsoft.DotNet.SDK.6",
    "Microsoft.DotNet.SDK.7",
    "Microsoft.DotNet.SDK.8",
    "Microsoft.DotNet.SDK.9",
    "Microsoft.DotNet.SDK.Preview",
    "Microsoft.DotNet.Framework.DeveloperPack.4_8_1",
    "Microsoft.DotNet.Framework.DeveloperPack.4_5_2",
    "Microsoft.DotNet.Framework.DeveloperPack.4_6_2"
)

foreach ($app in $apps) {
    Install-Or-Upgrade $app
}


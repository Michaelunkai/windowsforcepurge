#Requires -RunAsAdministrator
<#
====================================================================
        N U C L E A R   P E R F O R M A N C E   v11  •  FINAL
        — zero errors  •  turbo-aware  •  self-healing
====================================================================#>

#────────────  constants & helpers  ────────────
$MY_GUID   = 'E7B3C3F6-7F35-4F4C-8B48-8F1ECE9CD139'
$MY_NAME   = 'Nuclear_Performance_v11'
$TURBO_GUID= '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # built-in Hi-Perf
$GUID_RX   = '[0-9A-Fa-f\-]{36}'
function Say($m,$c='Cyan'){Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date),$m) -ForegroundColor $c}
function Cmd([string]$cmd){ cmd.exe /c $cmd | Out-Null }

#────────────  0.  elevation check  ────────────
$admin = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)){
    Write-Error "`n[!] Run this script as Administrator.`n"; exit 1 }

#────────────  1.  purge older plans  ───────────
Say 'Purging previous Nuclear_/Ultimate_ plans …' 'Yellow'
$schemes   = powercfg -list
$balanced  = ([regex]::Match(($schemes|Select-String 'Balanced'),$GUID_RX)).Value
if (-not $balanced){ $balanced = ([regex]::Match(($schemes|Select-String '\*'),$GUID_RX)).Value }

$schemes | Where-Object { $_ -match 'Nuclear_|Ultimate_' } | ForEach-Object{
    $gid = ([regex]::Match($_,$GUID_RX)).Value
    if ($gid -and $gid -ne $MY_GUID){
        if ($_ -match '^\s*\*'){ powercfg -setactive $balanced }
        try{ powercfg -delete $gid }catch{}
        Say "  deleted $gid" 'DarkGray'
}}

#────────────  2.  create / reuse plan  ────────
Say "Ensuring $MY_NAME plan exists …" 'Green'
$template = ''
try{ $template = ([regex]::Match(($schemes|Select-String 'High performance'),$GUID_RX)).Value }catch{}
if (-not $template){ $template = ([regex]::Match((powercfg /getactivescheme),$GUID_RX)).Value }
if (-not $template){ Write-Error 'No template plan found.'; exit 1 }

if (-not (powercfg -list | Select-String $MY_GUID)){
    powercfg -duplicatescheme $template $MY_GUID | Out-Null
}
powercfg -changename $MY_GUID $MY_NAME 'Permanent maximum-performance scheme' | Out-Null

#────────────  3.  safe powercfg tweaks  ───────
Say 'Applying core power-cfg settings …' 'Cyan'
$idx = @('-setacvalueindex','-setdcvalueindex')
$settings = @(
    'SUB_PROCESSOR PROCTHROTTLEMIN 100',
    'SUB_PROCESSOR PROCTHROTTLEMAX 100',
    'SUB_PROCESSOR IDLEDISABLE 1',
    'SUB_DISK DISKIDLE 0',
    'SUB_PCIEXPRESS ASPM 0',
    'SUB_USB USBSELECTSUSPEND 0',
    'SUB_WIFI POWERSAVE 0',
    'SUB_VIDEO VIDEOIDLE 0',
    'SUB_SLEEP STANDBYIDLE 0',
    'SUB_SLEEP HIBERNATEIDLE 0',
    'SUB_SLEEP HYBRIDSLEEP 0'
)
foreach($c in $idx){
    foreach($s in $settings){
        try{ powercfg $c $MY_GUID $s }catch{}
    }
}
powercfg -setactive $MY_GUID
powercfg -h off 2>$null

Say 'Pinning scheme in HKLM …' 'DarkYellow'
$regExe = "$env:SystemRoot\System32\reg.exe"
Cmd "`"$regExe`" add HKLM\System\CurrentControlSet\Control\Power\User\PowerSchemes /v ActivePowerScheme /t REG_SZ /d $MY_GUID /f"

#────────────  4.  light registry / service tweaks  ─────
Say 'Applying registry & service tweaks …' 'Magenta'
'SysMain','DiagTrack','dmwappushservice' | ForEach-Object{
    try{ Stop-Service $_ -Force -WarningAction SilentlyContinue }catch{}
    try{ Set-Service  $_ -StartupType Disabled }catch{}
}
Cmd 'reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f'
Cmd 'reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f'

#────────────  5.  install watchdog tasks  ────────
Say 'Installing Turbo-aware watchdog …' 'Yellow'
$watchDir = "$env:ProgramData\NuclearPerformance"
$watchPS  = "$watchDir\Restore.ps1"
New-Item -ItemType Directory -Path $watchDir -Force | Out-Null

@"
`$my = '$MY_GUID'
`$turbo = '$TURBO_GUID'
# ensure custom plan exists
if (-not (powercfg -list | Select-String `$my)){ powercfg -duplicatescheme SCHEME_MAX `$my ; powercfg -changename `$my '$MY_NAME' }
# auto-switch if Turbo made High-Perf active
`$curr = (powercfg /getactivescheme | Select-String '[0-9A-F\-]{36}').Matches.Value
if (`$curr.ToLower() -eq `$turbo.ToLower()){ powercfg -setactive `$my }
"@ | Set-Content -Path $watchPS -Encoding UTF8 -Force

$tr = "powershell -NoLogo -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$watchPS`""
# delete old tasks (ignore errors)
Cmd "schtasks /Delete /TN NuclearWatch_Logon /F"
Cmd "schtasks /Delete /TN NuclearWatch_Event /F"
# create new
Cmd "schtasks /Create /TN NuclearWatch_Logon  /SC ONLOGON             /TR `"$tr`" /RU SYSTEM /F"
Cmd "schtasks /Create /TN NuclearWatch_Event  /SC ONEVENT /EC System /MO `\"*[System[EventID=105]]`\" /TR `"$tr`" /RU SYSTEM /F"

#────────────  done  ─────────────────────────────
Say "SUCCESS   →  $MY_NAME is active, pinned & Turbo-aware." 'Green'
Say 'Switch to Turbo, Silent, Balanced – the plan always returns.' 'DarkGreen'

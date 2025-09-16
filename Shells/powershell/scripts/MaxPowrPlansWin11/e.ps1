#Requires -RunAsAdministrator
<#
══════════════════════════════════════════════════════════════════════
        N U C L E A R   P E R F O R M A N C E   v12
        permanent plan  •  turbo-aware  •  MPMP one-liner
══════════════════════════════════════════════════════════════════════
#>

# ─────────  constants & helpers  ─────────
$MY_GUID    = 'E7B3C3F6-7F35-4F4C-8B48-8F1ECE9CD139'
$MY_NAME    = 'Nuclear_Performance_v12'
$TURBO_GUID = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'     # built-in High-performance
$GUID_RX    = '[0-9A-Fa-f\-]{36}'
function Say ($m,$c='Cyan'){Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date),$m) -ForegroundColor $c}
function Cmd([string]$cmd){ cmd.exe /c $cmd | Out-Null }

# ─────────  0. elevation check  ──────────
if (-not ([Security.Principal.WindowsPrincipal] `
     [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
{ Write-Error "Run this script as Administrator."; exit 1 }

# ─────────  1. purge older custom plans  ─────────
Say 'Purging previous Nuclear_/Ultimate_ plans …' 'Yellow'
$schemes  = powercfg -list
$balanced = ([regex]::Match(($schemes|Select-String 'Balanced'),$GUID_RX)).Value
if (-not $balanced){ $balanced = ([regex]::Match(($schemes|Select-String '\*'),$GUID_RX)).Value }
$schemes | Where-Object { $_ -match 'Nuclear_|Ultimate_' } |
ForEach-Object{
    $gid = ([regex]::Match($_,$GUID_RX)).Value
    if ($gid -and $gid -ne $MY_GUID){
        if ($_ -match '^\s*\*'){ powercfg -setactive $balanced }
        try{ powercfg -delete $gid }catch{}
    }
}

# ─────────  2. create / reuse fixed-GUID plan  ───
Say 'Ensuring permanent max-performance plan exists …' 'Green'
$template = ''
try{ $template = ([regex]::Match(($schemes|Select-String 'High performance'),$GUID_RX)).Value }catch{}
if (-not $template){ $template = ([regex]::Match((powercfg /getactivescheme),$GUID_RX)).Value }
if (-not $template){ Write-Error 'No template plan found.'; exit 1 }

if (-not (powercfg -list | Select-String $MY_GUID)){
    powercfg -duplicatescheme $template $MY_GUID | Out-Null
}
powercfg -changename $MY_GUID $MY_NAME 'Permanent maximum-performance scheme' | Out-Null

# ─────────  3. safe power-cfg tweaks  ───────────
Say 'Applying core power settings …' 'Cyan'
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
foreach($c in $idx){ foreach($s in $settings){ try{ powercfg $c $MY_GUID $s }catch{} } }
powercfg -setactive $MY_GUID
powercfg -h off 2>$null

# pin in HKLM
Say 'Pinning scheme in registry …' 'DarkYellow'
Cmd "reg add HKLM\System\CurrentControlSet\Control\Power\User\PowerSchemes /v ActivePowerScheme /t REG_SZ /d $MY_GUID /f"

# ─────────  4. minimal reg / service tweaks  ────
'SysMain','DiagTrack' | %{
    try{ Stop-Service $_ -Force -ErrorAction SilentlyContinue }catch{}
    try{ Set-Service  $_ -StartupType Disabled }catch{}
}
Cmd 'reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f'

# ─────────  5. install watchdog tasks  ──────────
Say 'Installing Turbo-aware watchdog …' 'Yellow'
$dir  = "$env:ProgramData\NuclearPerformance"
$ps1  = "$dir\Restore.ps1"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
@"
`$my='$MY_GUID'; `$turbo='$TURBO_GUID'; `$name='$MY_NAME'
if (-not (powercfg -list | Select-String `$my)){
    powercfg -duplicatescheme SCHEME_MAX `$my
    powercfg -changename `$my `$name
}
`$current = (powercfg /getactivescheme | Select-String '[0-9A-F\-]{36}').Matches.Value
if (`$current.ToLower() -eq `$turbo.ToLower()){ powercfg -setactive `$my }
"@ | Set-Content $ps1 -Encoding UTF8 -Force

$taskCmd = "powershell -NoLogo -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$ps1`""
Cmd "schtasks /Delete /TN NuclearWatch_Logon /F"
Cmd "schtasks /Delete /TN NuclearWatch_Event /F"
Cmd "schtasks /Create /TN NuclearWatch_Logon /SC ONLOGON /TR `"$taskCmd`" /RU SYSTEM /F"
Cmd "schtasks /Create /TN NuclearWatch_Event /SC ONEVENT /EC System /MO `\"*[System[EventID=105]]`\" /TR `"$taskCmd`" /RU SYSTEM /F"

# ─────────  6. add MPMP to PowerShell profile  ──
Say 'Adding MPMP helper to PowerShell profile …' 'Magenta'
$profilePath = $profile.CurrentUserAllHosts
if (-not (Test-Path $profilePath)){ New-Item -ItemType File -Path $profilePath -Force | Out-Null }
$funcBlock = @"
function MPMP {
    param()
    powercfg -setactive $MY_GUID
    Write-Host 'Switched to $MY_NAME plan.' -ForegroundColor Green
}
"@
if (-not (Get-Content $profilePath -Raw | Select-String 'function MPMP')){
    Add-Content -Path $profilePath -Value "`n$funcBlock"
}
# also import into current session
Invoke-Expression $funcBlock

# ─────────  7. done  ───────────────────────────
Say "SUCCESS – $MY_NAME is active, pinned, turbo-aware." 'Green'
Say 'Type  MPMP  any time to jump back to the plan.' 'DarkGreen'

#Configure Variables
$InstallPath = "C:\Program Files\OpenSSH"
$DisablePasswordAuthentication = $True
$DisablePubkeyAuthentication = $True
$AutoStartSSHD = $true
$AutoStartSSHAGENT = $false

#Set to a local path or accessible UNC path to use existing zip and not try to download it each time
$OpenSSHLocation = $null
#$OpenSSHLocation = '\\server\c$\OpenSSH\OpenSSH-Win64.zip'

#These ones probably should not change
$GitUrl = 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/'
$GitZipName = "OpenSSH-Win64.zip" #Can use OpenSSH-Win32.zip on older systems
$ErrorActionPreference = "Stop"
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36'

# Detect Elevation:
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$UserPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$IsAdmin = $UserPrincipal.IsInRole($AdminRole)
if ($IsAdmin) {
    Write-Host "Script is running elevated." -ForegroundColor Green
}
else {
    throw "Script is not running elevated, which is required. Restart the script from an elevated prompt."
}

#Remove BuiltIn OpenSSH
$ErrorActionPreference = "SilentlyContinue"
Write-Host "Checking for Windows OpenSSH Server" -ForegroundColor Green
if ($(Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0).State -eq "Installed") {
    Write-Host "Removing Windows OpenSSH Server" -ForegroundColor Green
    Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
}
Write-Host "Checking for Windows OpenSSH Client" -ForegroundColor Green
if ($(Get-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0).State -eq "Installed") {
    Write-Host "Removing Windows OpenSSH Client" -ForegroundColor Green
    Remove-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction SilentlyContinue
}
$ErrorActionPreference = "Stop"

#Stop and remove existing services (Perhaps an existing OpenSSH install)
Write-Host "Cleaning up existing OpenSSH services" -ForegroundColor Green
if (Get-Service sshd -ErrorAction SilentlyContinue) {
    Write-Host "Stopping existing sshd service" -ForegroundColor Yellow
    Stop-Service sshd -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    sc.exe delete sshd 1>$null
}
if (Get-Service ssh-agent -ErrorAction SilentlyContinue) {
    Write-Host "Stopping existing ssh-agent service" -ForegroundColor Yellow
    Stop-Service ssh-agent -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    sc.exe delete ssh-agent 1>$null
}

# Wait for services to be fully removed
Start-Sleep -Seconds 3

if ($OpenSSHLocation.Length -eq 0) {
    #Randomize Querystring to ensure our request isn't served from a cache
    $GitUrl += "?random=" + $(Get-Random -Minimum 10000 -Maximum 99999)

    # Get Upstream URL
    Write-Host "Requesting URL for latest version of OpenSSH" -ForegroundColor Green
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [System.Net.WebRequest]::Create($GitUrl)
        $request.AllowAutoRedirect = $false
        $request.Timeout = 10 * 1000  # Increased timeout
        $request.headers.Add("Pragma", "no-cache")
        $request.headers.Add("Cache-Control", "no-cache")
        $request.UserAgent = $UserAgent
        $response = $request.GetResponse()
        if ($null -eq $response -or $null -eq $([String]$response.GetResponseHeader("Location"))) { 
            throw "Unable to download OpenSSH Archive. Sometimes you can get throttled, so just try again later." 
        }
        $OpenSSHURL = $([String]$response.GetResponseHeader("Location")).Replace('tag', 'download') + "/" + $GitZipName
        $response.Close()
    }
    catch {
        Write-Error "Failed to get OpenSSH download URL: $_"
        exit 1
    }

    # Also randomize this one...
    $OpenSSHURL += "?random=" + $(Get-Random -Minimum 10000 -Maximum 99999)
    Write-Host "Using URL" -ForegroundColor Green
    Write-Host $OpenSSHURL -ForegroundColor Green
    Write-Host

    # Download and extract archive
    Write-Host "Downloading Archive" -ForegroundColor Green
    try {
        Invoke-WebRequest -Uri $OpenSSHURL -OutFile $GitZipName -ErrorAction Stop -TimeoutSec 30 -Headers @{"Pragma" = "no-cache"; "Cache-Control" = "no-cache"; } -UserAgent $UserAgent
        Write-Host "Download Complete, now expanding and copying to destination" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download OpenSSH archive: $_"
        exit 1
    }
}
else {
    $PathInfo = [System.Uri]([string]::":FileSystem::" + $OpenSSHLocation)
    if ($PathInfo.IsUnc) {
        Copy-Item -Path $PathInfo.LocalPath -Destination $env:TEMP
        Set-Location $env:TEMP
    }
}

# Remove old installation
Write-Host "Removing old OpenSSH installation" -ForegroundColor Green
Remove-Item -Path $InstallPath -Force -Recurse -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Create installation directory
If (!(Test-Path $InstallPath)) {
    Write-Host "Creating installation directory" -ForegroundColor Green
    New-Item -Path $InstallPath -ItemType "directory" -ErrorAction Stop | Out-Null
}

# Extract OpenSSH files
Write-Host "Extracting OpenSSH files" -ForegroundColor Green
$OldEnv = [Environment]::CurrentDirectory
[Environment]::CurrentDirectory = $(Get-Location)
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($GitZipName)
    $archive.Entries | ForEach-Object {
        # Entries with an empty Name property are directories
        if ($_.Name -ne '') {
            $NewFileName = Join-Path $InstallPath $_.Name
            Remove-Item -Path $NewFileName -Force -ErrorAction SilentlyContinue
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $NewFileName, $true)
        }
    }
    $archive.Dispose()
}
catch {
    Write-Error "Failed to extract OpenSSH archive: $_"
    exit 1
}
finally {
    [Environment]::CurrentDirectory = $OldEnv
}

#Cleanup zip file if we downloaded it
if ($OpenSSHURL.Length -gt 0) { 
    Remove-Item -Path $GitZipName -Force -ErrorAction SilentlyContinue 
}

# SKIP the problematic install-sshd.ps1 and do manual installation
Write-Host "Performing manual OpenSSH service installation (bypassing problematic install-sshd.ps1)" -ForegroundColor Green
$OldLocation = Get-Location
try {
    Set-Location $InstallPath -ErrorAction Stop
    
    # Manual service creation to avoid the FileSystemRights error
    Write-Host "Creating sshd service manually" -ForegroundColor Green
    $sshdPath = Join-Path $InstallPath "sshd.exe"
    if (Test-Path $sshdPath) {
        & sc.exe create sshd binPath= "`"$sshdPath`"" DisplayName= "OpenSSH SSH Server" depend= Tcpip start= demand
        if ($LASTEXITCODE -eq 0) {
            Write-Host "sshd service created successfully" -ForegroundColor Green
        } else {
            Write-Warning "Failed to create sshd service (exit code: $LASTEXITCODE)"
        }
        
        & sc.exe description sshd "Provides secure shell access to this computer"
        
        # Create ssh-agent service
        $sshAgentPath = Join-Path $InstallPath "ssh-agent.exe"
        if (Test-Path $sshAgentPath) {
            Write-Host "Creating ssh-agent service" -ForegroundColor Green
            & sc.exe create ssh-agent binPath= "`"$sshAgentPath`"" DisplayName= "OpenSSH Authentication Agent" start= demand
            if ($LASTEXITCODE -eq 0) {
                Write-Host "ssh-agent service created successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to create ssh-agent service (exit code: $LASTEXITCODE)"
            }
            & sc.exe description ssh-agent "Agent to hold private keys used for public key authentication"
        }
    } else {
        Write-Error "sshd.exe not found in installation directory"
        exit 1
    }
    
    # Wait for services to be created
    Start-Sleep -Seconds 3
    
    # Verify services were created
    $sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($sshdService) {
        Write-Host "sshd service successfully created and detected" -ForegroundColor Green
    } else {
        Write-Error "Failed to create sshd service"
        exit 1
    }
}
catch {
    Write-Error "Error during OpenSSH service creation: $_"
    exit 1
}
finally {
    Set-Location $OldLocation
}

#Make sure your ProgramData\ssh directory exists
Write-Host "Creating SSH configuration directory" -ForegroundColor Green
If (!(Test-Path $env:ProgramData\ssh)) {
    New-Item -ItemType Directory -Force -Path $env:ProgramData\ssh -ErrorAction Stop | Out-Null
}

# Generate host keys manually
Write-Host "Generating host keys" -ForegroundColor Green
$sshKeygenPath = Join-Path $InstallPath "ssh-keygen.exe"
if (Test-Path $sshKeygenPath) {
    $hostKeyTypes = @("rsa", "dsa", "ecdsa", "ed25519")
    foreach ($keyType in $hostKeyTypes) {
        $keyPath = Join-Path $env:ProgramData\ssh "ssh_host_${keyType}_key"
        if (!(Test-Path $keyPath)) {
            Write-Host "Generating $keyType host key" -ForegroundColor Green
            & $sshKeygenPath -t $keyType -f $keyPath -N '""' -q
            if ($LASTEXITCODE -eq 0) {
                Write-Host "$keyType host key generated successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to generate $keyType host key"
            }
        }
    }
} else {
    Write-Warning "ssh-keygen.exe not found - host keys will need to be generated manually"
}

# Set proper permissions on SSH directory and files manually
Write-Host "Setting file permissions" -ForegroundColor Green
try {
    # Set permissions on SSH directory
    $sshDir = "$env:ProgramData\ssh"
    if (Test-Path $sshDir) {
        $acl = Get-Acl $sshDir
        $acl.SetAccessRuleProtection($true, $false)
        
        # System full control
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM", 
            "FullControl", 
            "ContainerInherit,ObjectInherit", 
            "None", 
            "Allow"
        )
        $acl.SetAccessRule($systemRule)
        
        # Administrators full control
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "BUILTIN\Administrators", 
            "FullControl", 
            "ContainerInherit,ObjectInherit", 
            "None", 
            "Allow"
        )
        $acl.SetAccessRule($adminRule)
        
        Set-Acl -Path $sshDir -AclObject $acl
        Write-Host "SSH directory permissions set successfully" -ForegroundColor Green
    }
    
    # Set permissions on host keys (private keys should be readable only by system and admins)
    $hostKeyFiles = Get-ChildItem -Path "$env:ProgramData\ssh\ssh_host_*_key" -ErrorAction SilentlyContinue
    foreach ($keyFile in $hostKeyFiles) {
        $acl = Get-Acl $keyFile.FullName
        $acl.SetAccessRuleProtection($true, $false)
        
        # System full control
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM", 
            "FullControl", 
            "Allow"
        )
        $acl.SetAccessRule($systemRule)
        
        # Administrators full control
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "BUILTIN\Administrators", 
            "FullControl", 
            "Allow"
        )
        $acl.SetAccessRule($adminRule)
        
        Set-Acl -Path $keyFile.FullName -AclObject $acl
    }
    
    Write-Host "Host key permissions set successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Some permission settings may have failed: $_"
}

#Setup sshd_config
Write-Host "Configure server config file" -ForegroundColor Green
$sshdConfigSource = Join-Path $InstallPath "sshd_config_default"
$sshdConfigDest = Join-Path $env:ProgramData\ssh "sshd_config"

if (Test-Path $sshdConfigSource) {
    Copy-Item -Path $sshdConfigSource -Destination $sshdConfigDest -Force -ErrorAction Stop
    Add-Content -Path $sshdConfigDest -Value "`r`nGSSAPIAuthentication yes" -ErrorAction Stop
    if ($DisablePasswordAuthentication) { 
        Add-Content -Path $sshdConfigDest -Value "PasswordAuthentication no" -ErrorAction Stop 
    }
    if ($DisablePubkeyAuthentication) { 
        Add-Content -Path $sshdConfigDest -Value "PubkeyAuthentication no" -ErrorAction Stop 
    }
    Write-Host "sshd_config configured successfully" -ForegroundColor Green
} else {
    Write-Warning "sshd_config_default not found, creating basic configuration"
    $basicConfig = @"
# Basic OpenSSH Server Configuration
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

HostKey __PROGRAMDATA__/ssh/ssh_host_rsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_dsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ecdsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ed25519_key

SyslogFacility AUTH
LogLevel INFO

AuthenticationMethods publickey password
PubkeyAuthentication yes
PasswordAuthentication yes

PermitRootLogin no
StrictModes yes
MaxAuthTries 6
MaxSessions 10

Subsystem sftp sftp-server.exe

GSSAPIAuthentication yes
"@
    
    $basicConfig | Out-File -FilePath $sshdConfigDest -Encoding UTF8
    
    if ($DisablePasswordAuthentication) { 
        Add-Content -Path $sshdConfigDest -Value "PasswordAuthentication no" -ErrorAction Stop 
    }
    if ($DisablePubkeyAuthentication) { 
        Add-Content -Path $sshdConfigDest -Value "PubkeyAuthentication no" -ErrorAction Stop 
    }
}

#Make sure your user .ssh directory exists
Write-Host "Creating user SSH directory" -ForegroundColor Green
If (!(Test-Path "~\.ssh")) {
    New-Item -ItemType Directory -Force -Path "~\.ssh" -ErrorAction Stop | Out-Null
}

#Set ssh_config
Write-Host "Configure client config file" -ForegroundColor Green
$sshConfigPath = "~\.ssh\config"
if (!(Test-Path $sshConfigPath)) {
    New-Item -ItemType File -Path $sshConfigPath -Force | Out-Null
}
Add-Content -Path $sshConfigPath -Value "`r`nGSSAPIAuthentication yes" -ErrorAction Stop

# Now configure the service
Write-Host "Configuring sshd service" -ForegroundColor Green
try {
    Set-Service -Name sshd -StartupType 'Manual' -ErrorAction Stop
    Write-Host "Service startup type set to Manual" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to set service startup type: $_"
}

#Setting autostarts
if ($AutoStartSSHD) {
    Write-Host "Setting sshd service to Automatic start" -ForegroundColor Green
    try {
        Set-Service -Name sshd -StartupType Automatic
        Write-Host "sshd service set to automatic startup" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to set sshd service to automatic startup: $_"
    }
}
if ($AutoStartSSHAGENT) {
    Write-Host "Setting ssh-agent service to Automatic start" -ForegroundColor Green
    try {
        if (Get-Service ssh-agent -ErrorAction SilentlyContinue) {
            Set-Service -Name ssh-agent -StartupType Automatic
            Write-Host "ssh-agent service set to automatic startup" -ForegroundColor Green
        } else {
            Write-Warning "ssh-agent service not found"
        }
    }
    catch {
        Write-Warning "Failed to set ssh-agent service to automatic startup: $_"
    }
}

#Add to path if it isn't already there
Write-Host "Adding OpenSSH to system PATH" -ForegroundColor Green
$existingPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
if ($existingPath -notmatch $InstallPath.Replace("\", "\\")) {
    $newpath = "$existingPath;$InstallPath"
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath -ErrorAction Stop
    Write-Host "OpenSSH added to system PATH" -ForegroundColor Green
} else {
    Write-Host "OpenSSH already in system PATH" -ForegroundColor Green
}

#Add firewall rule
Write-Host "Creating firewall rule" -ForegroundColor Green
try {
    # Remove existing rule if it exists
    Remove-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
    # Create new rule
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Stop
    Write-Host "Firewall rule created successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to create firewall rule: $_"
}

#Set Shell to powershell
Write-Host "Setting default shell to powershell" -ForegroundColor Green
try {
    if (!(Test-Path "HKLM:\SOFTWARE\OpenSSH")) {
        New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
    }
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force -ErrorAction Stop | Out-Null
    Write-Host "Default shell set to PowerShell" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to set default shell: $_"
}

#Start the service
Write-Host "Starting sshd Service" -ForegroundColor Green
try {
    Start-Service sshd -ErrorAction Stop
    Write-Host "sshd service started successfully" -ForegroundColor Green
    
    # Test service status
    $service = Get-Service -Name sshd
    Write-Host "sshd service status: $($service.Status)" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to start sshd service: $_"
    Write-Host "You may need to start the service manually after resolving any configuration issues" -ForegroundColor Yellow
}

# Create SSH alias
Write-Host "Creating SSH alias" -ForegroundColor Green
try {
    $sshExePath = Join-Path $InstallPath "ssh.exe"
    if (Test-Path $sshExePath) {
        Set-Alias -Name ssh -Value $sshExePath -Scope Global -Force
        Write-Host "SSH alias created successfully" -ForegroundColor Green
        
        # Test SSH version
        Write-Host "Testing SSH version:" -ForegroundColor Green
        try {
            & $sshExePath -V 2>&1 | Write-Host -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not get SSH version: $_"
        }
    } else {
        Write-Warning "SSH executable not found at $sshExePath"
    }
}
catch {
    Write-Warning "Failed to create SSH alias: $_"
}

# Final verification
Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host "OpenSSH Path: $InstallPath" -ForegroundColor Green
Write-Host "Config Path: $env:ProgramData\ssh\sshd_config" -ForegroundColor Green

$service = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Service Status: $($service.Status)" -ForegroundColor Green
    Write-Host "Service StartType: $($service.StartType)" -ForegroundColor Green
} else {
    Write-Host "Service Status: Not Found" -ForegroundColor Red
}

# Display connection information
Write-Host "`nConnection Information:" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "SSH Server Address: $(hostname)" -ForegroundColor Green
Write-Host "SSH Port: 22" -ForegroundColor Green
Write-Host "To connect: ssh username@$(hostname)" -ForegroundColor Green

Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
Write-Host "Note: You may need to restart your PowerShell session for PATH changes to take effect" -ForegroundColor Yellow
Write-Host "The SSH alias has been created and should be available in new PowerShell sessions." -ForegroundColor Yellow
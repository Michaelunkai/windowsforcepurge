# Revo Uninstaller Pro Auto Installation Script
# This script copies and sets up Revo Uninstaller Pro from cracked source to installed directory

param(
    [string]$SourcePath = "F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual",
    [string]$DestinationPath = "F:\backup\windowsapps\installed\RevoUninstallerPro",
    [switch]$Force
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to copy directory with progress
function Copy-DirectoryWithProgress {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    try {
        Write-ColorOutput "Copying files from source to destination..." "Yellow"
        robocopy "$Source" "$Destination" /E /COPY:DAT /R:3 /W:5 /MT:8 /NP
        
        if ($LASTEXITCODE -le 1) {
            Write-ColorOutput "Files copied successfully!" "Green"
            return $true
        } else {
            Write-ColorOutput "Error occurred during file copy. Exit code: $LASTEXITCODE" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error copying files: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main installation function
function Install-RevoUninstaller {
    Write-ColorOutput "=== Revo Uninstaller Pro 5.4 Auto Installer ===" "Cyan"
    Write-ColorOutput "Source: $SourcePath" "Gray"
    Write-ColorOutput "Destination: $DestinationPath" "Gray"
    Write-ColorOutput ""

    # Check if source directory exists
    if (-not (Test-Path $SourcePath)) {
        Write-ColorOutput "ERROR: Source directory not found: $SourcePath" "Red"
        Write-ColorOutput "Please verify the source path and try again." "Red"
        return $false
    }

    # Check if destination already exists
    if (Test-Path $DestinationPath) {
        if ($Force) {
            Write-ColorOutput "Destination exists. Force flag set - removing existing installation..." "Yellow"
            try {
                Remove-Item $DestinationPath -Recurse -Force
                Write-ColorOutput "Existing installation removed." "Green"
            }
            catch {
                Write-ColorOutput "Error removing existing installation: $($_.Exception.Message)" "Red"
                return $false
            }
        } else {
            Write-ColorOutput "WARNING: Destination directory already exists: $DestinationPath" "Yellow"
            $response = Read-Host "Do you want to overwrite it? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-ColorOutput "Installation cancelled by user." "Yellow"
                return $false
            }
            try {
                Remove-Item $DestinationPath -Recurse -Force
            }
            catch {
                Write-ColorOutput "Error removing existing installation: $($_.Exception.Message)" "Red"
                return $false
            }
        }
    }

    # Create destination directory
    try {
        Write-ColorOutput "Creating destination directory..." "Yellow"
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        Write-ColorOutput "Destination directory created." "Green"
    }
    catch {
        Write-ColorOutput "Error creating destination directory: $($_.Exception.Message)" "Red"
        return $false
    }

    # Find installer in source directory
    Write-ColorOutput "Searching for installer files in source..." "Yellow"
    $installers = @()
    $installers += Get-ChildItem -Path $SourcePath -Filter "*setup*.exe" -Recurse
    $installers += Get-ChildItem -Path $SourcePath -Filter "*install*.exe" -Recurse
    $installers += Get-ChildItem -Path $SourcePath -Filter "*.exe" -Recurse | Where-Object { $_.Name -match "revo.*setup|revo.*install" }

    if ($installers.Count -eq 0) {
        Write-ColorOutput "No installer found. Copying files as portable installation..." "Yellow"
        
        # Copy files as portable
        if (-not (Copy-DirectoryWithProgress $SourcePath $DestinationPath)) {
            return $false
        }
        
        # Look for main executable
        Write-ColorOutput "Searching for main executable..." "Yellow"
        $exeFiles = Get-ChildItem -Path $DestinationPath -Filter "*.exe" -Recurse | Where-Object { $_.Name -notmatch "setup|install|unins" }
        
        if ($exeFiles.Count -gt 0) {
            Write-ColorOutput "Found executable files:" "Green"
            foreach ($exe in $exeFiles) {
                Write-ColorOutput "  - $($exe.FullName)" "Gray"
            }
            
            # Find main executable
            $mainExe = $exeFiles | Where-Object { 
                $_.Name -match "revo" -and $_.Name -notmatch "unins|setup|install"
            } | Select-Object -First 1
            
            if (-not $mainExe -and $exeFiles.Count -gt 0) {
                $mainExe = $exeFiles[0]  # Take first exe if no specific match
            }
            
            if ($mainExe) {
                Write-ColorOutput "Main executable: $($mainExe.FullName)" "Green"
                
                # Create desktop shortcut
                if (-not $Force) {
                    $response = Read-Host "Create desktop shortcut? (Y/n)"
                    if ($response -ne 'n' -and $response -ne 'N') {
                        try {
                            $WshShell = New-Object -comObject WScript.Shell
                            $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Revo Uninstaller Pro.lnk")
                            $Shortcut.TargetPath = $mainExe.FullName
                            $Shortcut.WorkingDirectory = $mainExe.DirectoryName
                            $Shortcut.Description = "Revo Uninstaller Pro 5.4"
                            $Shortcut.Save()
                            Write-ColorOutput "Desktop shortcut created!" "Green"
                        }
                        catch {
                            Write-ColorOutput "Warning: Could not create desktop shortcut: $($_.Exception.Message)" "Yellow"
                        }
                    }
                } else {
                    # Auto-create shortcut when using -Force
                    try {
                        $WshShell = New-Object -comObject WScript.Shell
                        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Revo Uninstaller Pro.lnk")
                        $Shortcut.TargetPath = $mainExe.FullName
                        $Shortcut.WorkingDirectory = $mainExe.DirectoryName
                        $Shortcut.Description = "Revo Uninstaller Pro 5.4"
                        $Shortcut.Save()
                        Write-ColorOutput "Desktop shortcut created!" "Green"
                    }
                    catch {
                        Write-ColorOutput "Warning: Could not create desktop shortcut: $($_.Exception.Message)" "Yellow"
                    }
                }
            }
        }
    } else {
        Write-ColorOutput "Found installer(s):" "Green"
        foreach ($installer in $installers) {
            Write-ColorOutput "  - $($installer.FullName)" "Gray"
        }
        
        $selectedInstaller = $installers[0]  # Use first installer found
        Write-ColorOutput "Using installer: $($selectedInstaller.Name)" "Green"
        
        # Try different silent installation methods
        Write-ColorOutput "Running installer with silent parameters..." "Yellow"
        
        $installArgs = @(
            "/S /D=`"$DestinationPath`"",           # NSIS style
            "/SILENT /DIR=`"$DestinationPath`"",    # InnoSetup style  
            "/quiet INSTALLDIR=`"$DestinationPath`"", # MSI style
            "/s /v`"/qn INSTALLDIR=\`"$DestinationPath\`"`""  # InstallShield style
        )
        
        $installSuccess = $false
        foreach ($args in $installArgs) {
            try {
                Write-ColorOutput "Trying: $($selectedInstaller.FullName) $args" "Gray"
                $process = Start-Process $selectedInstaller.FullName -ArgumentList $args -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    Write-ColorOutput "Installation completed successfully!" "Green"
                    $installSuccess = $true
                    break
                } else {
                    Write-ColorOutput "Installation attempt failed with exit code: $($process.ExitCode)" "Yellow"
                }
            }
            catch {
                Write-ColorOutput "Installation attempt failed: $($_.Exception.Message)" "Yellow"
            }
        }
        
        if (-not $installSuccess) {
            Write-ColorOutput "Silent installation failed. Trying interactive installation..." "Yellow"
            if (-not $Force) {
                $response = Read-Host "Run installer interactively? (Y/n)"
                if ($response -ne 'n' -and $response -ne 'N') {
                    try {
                        Start-Process $selectedInstaller.FullName -Wait
                        Write-ColorOutput "Interactive installation completed!" "Green"
                    }
                    catch {
                        Write-ColorOutput "Error running installer: $($_.Exception.Message)" "Red"
                        return $false
                    }
                }
            }
        }
        
        # Check if installation was successful
        if (Test-Path $DestinationPath) {
            $exeFiles = Get-ChildItem -Path $DestinationPath -Filter "*.exe" -Recurse | Where-Object { $_.Name -notmatch "setup|install|unins" }
            if ($exeFiles.Count -gt 0) {
                $mainExe = $exeFiles | Where-Object { 
                    $_.Name -match "revo" -and $_.Name -notmatch "unins|setup|install"
                } | Select-Object -First 1
                
                if (-not $mainExe -and $exeFiles.Count -gt 0) {
                    $mainExe = $exeFiles[0]
                }
                
                if ($mainExe) {
                    Write-ColorOutput "Main executable found: $($mainExe.FullName)" "Green"
                    
                    # Create desktop shortcut
                    if (-not $Force) {
                        $response = Read-Host "Create desktop shortcut? (Y/n)"
                        if ($response -ne 'n' -and $response -ne 'N') {
                            try {
                                $WshShell = New-Object -comObject WScript.Shell
                                $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Revo Uninstaller Pro.lnk")
                                $Shortcut.TargetPath = $mainExe.FullName
                                $Shortcut.WorkingDirectory = $mainExe.DirectoryName
                                $Shortcut.Description = "Revo Uninstaller Pro 5.4"
                                $Shortcut.Save()
                                Write-ColorOutput "Desktop shortcut created!" "Green"
                            }
                            catch {
                                Write-ColorOutput "Warning: Could not create desktop shortcut: $($_.Exception.Message)" "Yellow"
                            }
                        }
                    }
                }
            }
        }
    }

    # Copy license file after installation
    Write-ColorOutput "Copying license file..." "Yellow"
    $licenseSource = Join-Path $SourcePath "revouninstallerpro5.lic"
    $licenseDestDir = "C:\ProgramData\VS Revo Group\Revo Uninstaller Pro"
    $licenseDestPath = Join-Path $licenseDestDir "revouninstallerpro5.lic"
    
    try {
        if (Test-Path $licenseSource) {
            # Create license destination directory if it doesn't exist
            if (-not (Test-Path $licenseDestDir)) {
                Write-ColorOutput "Creating license directory: $licenseDestDir" "Yellow"
                New-Item -ItemType Directory -Path $licenseDestDir -Force | Out-Null
            }
            
            # Copy license file
            Copy-Item $licenseSource $licenseDestPath -Force
            Write-ColorOutput "License file copied successfully!" "Green"
            Write-ColorOutput "  From: $licenseSource" "Gray"
            Write-ColorOutput "  To: $licenseDestPath" "Gray"
        } else {
            Write-ColorOutput "Warning: License file not found at: $licenseSource" "Yellow"
            Write-ColorOutput "You may need to activate the software manually." "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Warning: Could not copy license file: $($_.Exception.Message)" "Yellow"
        Write-ColorOutput "You may need to copy the license file manually or run as Administrator." "Yellow"
    }

    Write-ColorOutput ""
    Write-ColorOutput "=== Installation Complete ===" "Green"
    Write-ColorOutput "Revo Uninstaller Pro has been installed to: $DestinationPath" "Green"
    if (Test-Path $licenseDestPath) {
        Write-ColorOutput "License file installed - software should be activated!" "Green"
    }
    Write-ColorOutput ""
    
    return $true
}

# Run the installation
try {
    $result = Install-RevoUninstaller
    if ($result) {
        Write-ColorOutput "Installation successful!" "Green"
        exit 0
    } else {
        Write-ColorOutput "Installation failed!" "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "Unexpected error: $($_.Exception.Message)" "Red"
    exit 1
}
<#
.SYNOPSIS
    Lists every startup item on Windows (Registry, Services, Scheduled Tasks, Startup Folders).
    Sorts by CPU and RAM usage (highest to lowest).

.DESCRIPTION
    Compatible with Windows 10/11 and PowerShell 5+.
    Collects all startup entries, matches them with running processes, 
    and sorts by total CPU and memory usage.

.NOTES
    Author: ChatGPT
    Version: 1.0
#>

# Collect all startup sources
$startup = @()

# 1. Registry-based startup
try {
    $startup += Get-CimInstance Win32_StartupCommand |
        Select-Object -Property Name, Command, Location, User
} catch {
    Write-Host "Failed to retrieve registry startup entries: $_" -ForegroundColor Yellow
}

# 2. Scheduled tasks (ready or running)
try {
    $startup += Get-ScheduledTask |
        Where-Object { $_.State -eq 'Ready' -or $_.State -eq 'Running' } |
        ForEach-Object {
            [PSCustomObject]@{
                Name     = $_.TaskName
                Command  = (($_.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join '; ')
                Location = 'Task Scheduler'
                User     = $_.Principal.UserId
            }
        }
} catch {
    Write-Host "Failed to retrieve scheduled tasks: $_" -ForegroundColor Yellow
}

# 3. Services (automatic start)
try {
    $startup += Get-Service |
        Where-Object { $_.StartType -eq 'Automatic' } |
        ForEach-Object {
            [PSCustomObject]@{
                Name     = $_.DisplayName
                Command  = $_.Name
                Location = 'Service'
                User     = 'System'
            }
        }
} catch {
    Write-Host "Failed to retrieve services: $_" -ForegroundColor Yellow
}

# 4. Startup folders
try {
    $allUsersStartup = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'
    $currentUserStartup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'

    if (Test-Path $allUsersStartup) {
        $startup += Get-ChildItem -Path $allUsersStartup -ErrorAction SilentlyContinue |
            ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Location = 'Startup Folder (All Users)'
                    User     = 'All Users'
                }
            }
    }

    if (Test-Path $currentUserStartup) {
        $startup += Get-ChildItem -Path $currentUserStartup -ErrorAction SilentlyContinue |
            ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Location = 'Startup Folder (Current User)'
                    User     = $env:USERNAME
                }
            }
    }
} catch {
    Write-Host "Failed to retrieve startup folder items: $_" -ForegroundColor Yellow
}

# Get current process usage
$procInfo = Get-Process |
    Select-Object Id, ProcessName, CPU, @{Name='RAM_MB'; Expression = { [math]::Round($_.WS / 1MB, 2) } }

# Match startup commands to running processes
$final = foreach ($item in $startup) {
    $match = $procInfo | Where-Object { $item.Command -and $item.Command -match $_.ProcessName }
    if ($match) {
        [PSCustomObject]@{
            Name     = $item.Name
            Command  = $item.Command
            Location = $item.Location
            User     = $item.User
            CPU      = [math]::Round(($match | Measure-Object -Property CPU -Sum).Sum, 2)
            RAM_MB   = [math]::Round(($match | Measure-Object -Property RAM_MB -Sum).Sum, 2)
        }
    } else {
        [PSCustomObject]@{
            Name     = $item.Name
            Command  = $item.Command
            Location = $item.Location
            User     = $item.User
            CPU      = 0
            RAM_MB   = 0
        }
    }
}

# Sort by CPU then RAM
$final | Sort-Object -Property @{Expression='CPU';Descending=$true}, @{Expression='RAM_MB';Descending=$true} |
    Format-Table -AutoSize Name, CPU, RAM_MB, Location, User, Command

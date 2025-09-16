# PowerShell script to take screenshot and set as wallpaper for Windows 11
# Usage: .\screenit.ps1 or just 'screenit' if added to PATH/profile
# Enhanced version that hides terminal during screenshot

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Windows API for setting wallpaper and window management
if (-not ([System.Management.Automation.PSTypeName]'WinAPI').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    public static void SetWallpaper(string path) {
        // SPI_SETDESKWALLPAPER = 20
        // SPIF_UPDATEINIFILE = 0x01, SPIF_SENDCHANGE = 0x02
        SystemParametersInfo(20, 0, path, 0x01 | 0x02);
    }
    
    public static void HideConsole() {
        IntPtr hWnd = GetConsoleWindow();
        if (hWnd != IntPtr.Zero) {
            ShowWindow(hWnd, 0); // SW_HIDE = 0
        }
    }
    
    public static void ShowConsole() {
        IntPtr hWnd = GetConsoleWindow();
        if (hWnd != IntPtr.Zero) {
            ShowWindow(hWnd, 5); // SW_SHOW = 5
        }
    }
}
"@
}

try {
    Write-Host "Preparing to take screenshot at maximum resolution..." -ForegroundColor Green
    
    # Get the console window handle before hiding it
    $consoleWindow = [WinAPI]::GetConsoleWindow()
    
    # Hide the console window
    Write-Host "Hiding terminal window..." -ForegroundColor Yellow
    [WinAPI]::HideConsole()
    
    # Wait a moment for the window to hide
    Start-Sleep -Milliseconds 500
    
    # Get all screens and find the total desktop area for maximum resolution capture
    $allScreens = [System.Windows.Forms.Screen]::AllScreens
    $primaryScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    
    # Calculate the total desktop bounds (all monitors combined)
    $minX = ($allScreens | ForEach-Object { $_.Bounds.Left } | Measure-Object -Minimum).Minimum
    $minY = ($allScreens | ForEach-Object { $_.Bounds.Top } | Measure-Object -Minimum).Minimum
    $maxRight = ($allScreens | ForEach-Object { $_.Bounds.Right } | Measure-Object -Maximum).Maximum
    $maxBottom = ($allScreens | ForEach-Object { $_.Bounds.Bottom } | Measure-Object -Maximum).Maximum
    
    # Create total desktop rectangle
    $totalWidth = $maxRight - $minX
    $totalHeight = $maxBottom - $minY
    $desktopBounds = New-Object System.Drawing.Rectangle $minX, $minY, $totalWidth, $totalHeight
    
    Write-Host "Primary screen: $($primaryScreen.Bounds.Width)x$($primaryScreen.Bounds.Height)" -ForegroundColor Cyan
    Write-Host "Total desktop area: $($totalWidth)x$($totalHeight)" -ForegroundColor Cyan
    Write-Host "Number of displays: $($allScreens.Count)" -ForegroundColor Cyan
    
    # For wallpaper, we want to capture at the PHYSICAL display resolution
    $targetScreen = $primaryScreen.Bounds
    
    # Get actual DPI to calculate physical resolution
    $form = New-Object System.Windows.Forms.Form
    $graphics_temp = $form.CreateGraphics()
    $dpiX = $graphics_temp.DpiX
    $dpiY = $graphics_temp.DpiY
    $graphics_temp.Dispose()
    $form.Dispose()
    
    # Calculate actual physical pixel dimensions
    $physicalWidth = [int]($targetScreen.Width * $dpiX / 96)
    $physicalHeight = [int]($targetScreen.Height * $dpiY / 96)
    
    # Force to your specific resolution for high-DPI display
    $actualWidth = 2560
    $actualHeight = 1600
    
    Write-Host "Logical resolution: $($targetScreen.Width)x$($targetScreen.Height)" -ForegroundColor Yellow
    Write-Host "DPI scaling: $($dpiX)x$($dpiY) ($([int]($dpiX/96*100))%)" -ForegroundColor Cyan
    Write-Host "Physical resolution: $($physicalWidth)x$($physicalHeight)" -ForegroundColor Cyan
    Write-Host "Capturing at FORCED resolution: $($actualWidth)x$($actualHeight) pixels" -ForegroundColor Green
    
    # Create bitmap with exact screen dimensions
    $bitmap = New-Object System.Drawing.Bitmap $actualWidth, $actualHeight
    
    # Create graphics object with maximum quality settings
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Set highest quality rendering options
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    
    # Take screenshot at full physical resolution (2560x1600)
    $graphics.CopyFromScreen($targetScreen.Location, [System.Drawing.Point]::Empty, 
                           [System.Drawing.Size]::new($actualWidth, $actualHeight))
    
    # Show console window again
    [WinAPI]::ShowConsole()
    
    Write-Host "Screenshot captured successfully!" -ForegroundColor Green
    
    # Create wallpapers directory if it doesn't exist
    $wallpapersDir = "$env:USERPROFILE\Pictures\Wallpapers"
    if (!(Test-Path $wallpapersDir)) {
        New-Item -ItemType Directory -Path $wallpapersDir -Force | Out-Null
        Write-Host "Created wallpapers directory: $wallpapersDir" -ForegroundColor Cyan
    }
    
    # Generate filename with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $filename = "screenitwallpaper_$timestamp.png"
    $fullPath = Join-Path $wallpapersDir $filename
    
    # Save screenshot as PNG with maximum quality (lossless compression)
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, 100)
    
    # Get PNG codec for highest quality
    $pngCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | 
                Where-Object { $_.MimeType -eq "image/png" }
    
    if ($pngCodec) {
        $bitmap.Save($fullPath, $pngCodec, $encoderParams)
        Write-Host "Saved as high-quality PNG (lossless)" -ForegroundColor Green
    } else {
        # Fallback to standard PNG save
        $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Saved as standard PNG" -ForegroundColor Yellow
    }
    
    # Clean up graphics objects
    $graphics.Dispose()
    $bitmap.Dispose()
    
    Write-Host "Screenshot saved: $fullPath" -ForegroundColor Yellow
    
    # Set as wallpaper using Windows API
    Write-Host "Setting as Windows 11 wallpaper..." -ForegroundColor Green
    [WinAPI]::SetWallpaper($fullPath)
    
    # Wait for Windows to process the wallpaper change
    Start-Sleep -Seconds 2
    
    # Configure wallpaper settings for maximum quality and full image display
    Write-Host "Configuring wallpaper display settings for maximum quality..." -ForegroundColor Yellow
    $regPath = "HKCU:\Control Panel\Desktop"
    
    # Use Fill mode for high-resolution capture to fit screen properly
    Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value "10" -Type String  # Fill
    Write-Host "Using 'Fill' mode for high-resolution 2560x1600 display!" -ForegroundColor Green
    
    Set-ItemProperty -Path $regPath -Name "TileWallpaper" -Value "0" -Type String      # Don't tile
    Set-ItemProperty -Path $regPath -Name "Wallpaper" -Value $fullPath -Type String   # Set path
    
    # Set maximum JPEG quality for high-resolution displays
    Set-ItemProperty -Path $regPath -Name "JPEGImportQuality" -Value 100 -Type DWord -ErrorAction SilentlyContinue
    
    # Additional quality settings for Windows 11
    try {
        Set-ItemProperty -Path $regPath -Name "WallpaperOriginX" -Value 0 -Type DWord
        Set-ItemProperty -Path $regPath -Name "WallpaperOriginY" -Value 0 -Type DWord
    } catch {
        # These properties might not exist on all systems
    }
    
    # Force registry refresh and desktop update for immediate effect
    rundll32.exe user32.dll, UpdatePerUserSystemParameters
    
    # Additional refresh to ensure changes take effect
    Start-Sleep -Milliseconds 500
    [WinAPI]::SetWallpaper($fullPath)  # Set again to ensure it takes
    
    Write-Host "SUCCESS: High-resolution screenshot taken and set as wallpaper!" -ForegroundColor Green
    Write-Host "Captured at: $($actualWidth)x$($actualHeight) pixels (true physical resolution)" -ForegroundColor Cyan
    Write-Host "Logical display: $($targetScreen.Width)x$($targetScreen.Height) (with $([int]($dpiX/96*100))% scaling)" -ForegroundColor Cyan
    Write-Host "File saved at: $fullPath" -ForegroundColor Cyan
    Write-Host "Wallpaper optimized for your high-DPI display!" -ForegroundColor Green
    
} catch {
    # Ensure console is visible again in case of error
    [WinAPI]::ShowConsole()
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup any remaining objects
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
}

<#
.SYNOPSIS
    Monitors an Android phone's battery level over wireless ADB and triggers non-blocking Windows notifications for low battery (unplugged) and full charge (plugged in).

.DESCRIPTION
    This script continuously monitors an Android device connected via wireless ADB. 
    - It automatically handles wireless reconnection if the connection drops.
    - It queries the battery percentage and power source status using `adb shell dumpsys battery`.
    - If the battery falls to or below the set threshold AND the phone is unplugged, it displays a non-blocking Windows low-battery notification.
    - If the battery reaches 100% AND is still plugged into a power source, it displays a non-blocking full-charge notification.
    - Uses Windows system tray balloon/toast notifications so the script never pauses waiting for a button click.

    NOTE: This script assumes you have enabled wireless ADB following the steps mentioned in Project Rend under Settings -> Import -> Game Save - Emulator/Phone -> Connect over wifi.

.PARAMETER PhoneIP
    The local Wi-Fi IP address of your Android device (found in Wireless Debugging settings). Default is "192.168.1.50".

.PARAMETER PhonePort
    The dynamic port number assigned by wireless debugging on your phone. Default is "37483".

.PARAMETER Threshold
    The battery percentage level that triggers the low-battery warning notification. Default is 25%.

.PARAMETER CheckIntervalSeconds
    The frequency (in seconds) at which the script checks the battery status. Default is 600 seconds (10 minutes).

.EXAMPLE
    .\monitor_battery.ps1 -PhoneIP "192.168.1.105" -PhonePort "55555"
    Runs the monitor targeting a specific IP and port.
#>

param(
    [string]$PhoneIP = "192.168.1.50",
    [string]$PhonePort = "37483",
    [int]$Threshold = 25,
    [int]$CheckIntervalSeconds = 600
)

# Load Windows Forms and Drawing assemblies for non-blocking Windows notifications
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Helper function to display a non-blocking Windows notification banner
function Show-WindowsNotification {
    param(
        [string]$Title,
        [string]$Message,
        [System.Windows.Forms.ToolTipIcon]$IconType = [System.Windows.Forms.ToolTipIcon]::Info
    )

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    if ($IconType -eq [System.Windows.Forms.ToolTipIcon]::Warning) {
        $notify.Icon = [System.Drawing.SystemIcons]::Warning
    }
    $notify.BalloonTipIcon = $IconType
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Message
    $notify.Visible = $true

    # Trigger the non-blocking Windows notification (timeout parameter is ignored in Win10/11, handled by OS)
    $notify.ShowBalloonTip(5000)

    # Brief pause before disposing the tray icon handle so Windows registers the toast cleanly
    Start-Sleep -Milliseconds 500
    $notify.Dispose()
}

Write-Host "Starting Android Battery Monitor (Non-Blocking Alerts)..." -ForegroundColor Cyan
Write-Host "Target: $PhoneIP`:$PhonePort | Threshold: $Threshold% | Interval: ${CheckIntervalSeconds}s" -ForegroundColor DarkCyan

<#
.SYNOPSIS
    Tests if the device is connected via ADB and attempts an automatic reconnection if dropped.
#>
function Test-And-Reconnect {
    # 1. Fast check if already connected and active
    if ((adb devices) -match "$PhoneIP`:$PhonePort\s+device") {
        return $true
    }

    # 2. Attempt connection and capture output instantly
    Write-Host "[*] Reconnecting to $PhoneIP`:$PhonePort..." -ForegroundColor Yellow
    $connectOutput = adb connect "$PhoneIP`:$PhonePort" 2>&1

    # 3. Check if connection was successful right away
    if ($connectOutput -match "connected") {
        Write-Host "[+] Successfully reconnected!" -ForegroundColor Green
        return $true
    }

    # 4. Fallback double-check via devices list
    Start-Sleep -Seconds 1
    if ((adb devices) -match "$PhoneIP`:$PhonePort\s+device") {
        Write-Host "[+] Successfully reconnected!" -ForegroundColor Green
        return $true
    }

    Write-Host "[-] Reconnection failed. Will retry in the next cycle." -ForegroundColor Red
    return $false
}

# Main execution loop
while ($true) {
    # Ensure device is connected before querying battery
    if (Test-And-Reconnect) {
        # Fetch raw battery status dump from Android
        $batteryOutput = adb -s "$PhoneIP`:$PhonePort" shell dumpsys battery
        $levelLine = $batteryOutput | Select-String "level:"

        if ($levelLine -match '\d+') {
            [int]$batteryLevel = $Matches[0]
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] Current Battery Level: $batteryLevel%" -ForegroundColor Green

            # Check power source status for active charging
            $isPowered = ($batteryOutput -match "AC powered:\s+true") -or 
                         ($batteryOutput -match "USB powered:\s+true") -or 
                         ($batteryOutput -match "Wireless powered:\s+true")

            # Check if battery is low AND phone is NOT charging (unplugged)
            if ($batteryLevel -le $Threshold) {
                if (-not $isPowered) {
                    Write-Host "[!] Battery is low ($batteryLevel%!) and phone is unplugged." -ForegroundColor Red
                    
                    Show-WindowsNotification `
                        -Title "Low Battery Warning" `
                        -Message "Your Android phone battery is at $batteryLevel%! Please plug it in." `
                        -IconType ([System.Windows.Forms.ToolTipIcon]::Warning)

                    # Sleep for 10 minutes after an alert triggers to avoid spamming notifications
                    Start-Sleep -Seconds 600
                } else {
                    Write-Host "[i] Battery is low ($batteryLevel%), but phone is currently charging. Skipping alert." -ForegroundColor DarkGray
                }
            }
            # Check if battery is fully charged (100%) AND phone IS charging
            elseif ($batteryLevel -ge 100) {
                if ($isPowered) {
                    Write-Host "[!] Battery is fully charged (100%) and still plugged in!" -ForegroundColor Green
                    
                    Show-WindowsNotification `
                        -Title "Battery Fully Charged" `
                        -Message "Your Android phone battery is fully charged (100%) and still plugged in! You can unplug it." `
                        -IconType ([System.Windows.Forms.ToolTipIcon]::Info)

                    # Sleep for 10 minutes after an alert triggers to avoid spamming notifications
                    Start-Sleep -Seconds 600
                } else {
                    Write-Host "[i] Battery is at 100%, but phone is not charging (unplugged). Skipping alert." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "[?] Connected, but could not read battery level." -ForegroundColor Yellow
        }
    }

    # Wait for the specified interval before checking again
    Start-Sleep -Seconds $CheckIntervalSeconds
}

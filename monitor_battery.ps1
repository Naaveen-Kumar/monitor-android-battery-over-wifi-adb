<#
.SYNOPSIS
    Monitors an Android phone's battery level over wireless ADB and triggers Windows alerts for low battery and fully charged (only if actively plugged in/charging).

.DESCRIPTION
    This script continuously monitors an Android device connected via wireless ADB. 
    - It automatically handles wireless reconnection if the connection drops.
    - It queries the battery percentage and power source status using `adb shell dumpsys battery`.
    - If the battery falls to or below the set threshold, it opens a native Windows low-battery warning popup.
    - If the battery reaches 100% AND is still plugged into a power source, it opens a fully charged notification popup.
    - If the battery is at 100% but the phone is unplugged (not charging), it skips the popup to prevent alert spam.
    - It can be run invisibly in the background using Windows Terminal or PowerShell.

    NOTE: This script assumes you have enabled wireless ADB following the steps mentioned in Project Rend under Settings -> Import -> Game Save - Emulator/Phone -> Connect over wifi.

.PARAMETER PhoneIP
    The local Wi-Fi IP address of your Android device (found in Wireless Debugging settings). Default is "192.168.1.50".

.PARAMETER PhonePort
    The dynamic port number assigned by wireless debugging on your phone. Default is "37483".

.PARAMETER Threshold
    The battery percentage level that triggers the low-battery warning popup. Default is 25%.

.PARAMETER CheckIntervalSeconds
    The frequency (in seconds) at which the script checks the battery status. Default is 600 seconds (10 minutes).

.EXAMPLE
    .\monitor_battery.ps1 -PhoneIP "192.168.1.105" -PhonePort "55555"
    Runs the monitor targeting a specific IP and port.

.EXAMPLE
    powershell -WindowStyle Hidden -File "D:\monitor_battery.ps1" -PhonePort "45678"
    Runs the script invisibly in the background with a custom port.
#>

param(
    [string]$PhoneIP = "192.168.1.50",
    [string]$PhonePort = "37483",
    [int]$Threshold = 25,
    [int]$CheckIntervalSeconds = 600
)

# Load Windows Forms assembly so we can trigger native Windows popup notification dialogs
[Windows.Forms.MessageBox, System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089] | Out-Null

Write-Host "Starting Android Battery Monitor (Optimized)..." -ForegroundColor Cyan
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
            [int]$batteryLevel = $Matches[0]; $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] Current Battery Level: $batteryLevel%" -ForegroundColor Green

            # Check if battery has dropped below or equal to the low alert threshold
            if ($batteryLevel -le $Threshold) {
                Write-Host "[!] Battery is low ($batteryLevel%!)" -ForegroundColor Red
                
                # Trigger Windows GUI Popup Warning Box for Low Battery
                [System.Windows.Forms.MessageBox]::Show(
                    "Your Android phone battery is at $batteryLevel%! Please plug it in.", 
                    "Low Battery Warning", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )

                # Sleep for 10 minutes after an alert triggers to avoid spamming warnings
                Start-Sleep -Seconds 600
            }
            # Check if battery is fully charged (100%)
            elseif ($batteryLevel -ge 100) {
                # Verify if any power source (AC, USB, or Wireless) is actively connected
                $isPowered = ($batteryOutput -match "AC powered:\s+true") -or 
                             ($batteryOutput -match "USB powered:\s+true") -or 
                             ($batteryOutput -match "Wireless powered:\s+true")

                if ($isPowered) {
                    Write-Host "[!] Battery is fully charged (100%) and still plugged in!" -ForegroundColor Green
                    
                    # Trigger Windows GUI Popup Info Box for Full Charge
                    [System.Windows.Forms.MessageBox]::Show(
                        "Your Android phone battery is fully charged (100%) and still plugged in! You can unplug it.", 
                        "Battery Fully Charged", 
                        [System.Windows.Forms.MessageBoxButtons]::OK, 
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )

                    # Sleep for 10 minutes after an alert triggers to avoid spamming warnings
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

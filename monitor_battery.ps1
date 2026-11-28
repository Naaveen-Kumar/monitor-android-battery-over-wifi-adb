<#
.SYNOPSIS
    Connects to an Android device over wireless ADB and launches the battery monitor script in a visible terminal window.

.DESCRIPTION
    This launcher script takes your Android device's wireless ADB port as an argument, establishes
    the ADB connection using a specified ADB server port, and starts `monitor_battery.ps1` in a
    visible PowerShell window so you can monitor live battery level logs.

.PARAMETER PhonePort
    The dynamic port number assigned by wireless debugging on your Android phone. This parameter is mandatory.

.PARAMETER PhoneIP
    The local Wi-Fi IP address of your Android device. Default is "192.168.1.50".

.PARAMETER AdbServerPort
    The port used by the local ADB server (`adb -P`). Default is 17537.

.PARAMETER MonitorScriptPath
    Full path to the battery monitoring script to launch. Default is "D:\monitor_battery.ps1".

.EXAMPLE
    powershell -File "D:\start_battery_monitor.ps1" -PhonePort 41235
    Connects to the default phone IP on port 41235 and opens the live battery monitor window.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$PhonePort,

    [string]$PhoneIP = "192.168.1.50",

    [int]$AdbServerPort = 17537,

    [string]$MonitorScriptPath = "D:\monitor_battery.ps1"
)

# Combine IP and port into a single ADB target address
$target = "$PhoneIP`:$PhonePort"

# 1. Connect to the Android device via ADB on the configured server port
Write-Host "Connecting to $target on ADB server port $AdbServerPort..." -ForegroundColor Cyan
adb -P $AdbServerPort connect $target

# 2. Launch the battery monitor script in a visible PowerShell window
Write-Host "Starting live battery monitor..." -ForegroundColor Green
& $MonitorScriptPath -PhoneIP $PhoneIP -PhonePort $PhonePort

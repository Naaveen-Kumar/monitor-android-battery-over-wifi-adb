# Android Wireless Battery Monitor (PowerShell)

A lightweight pair of PowerShell scripts that monitor an Android device's battery over wireless ADB and trigger native Windows popup alerts when the battery gets low or finishes charging.

## Prerequisites

1. **ADB (Android Debug Bridge):** Installed and added to your Windows `PATH`.
2. **Wireless ADB Enabled:** Enable wireless debugging on your Android phone following the steps in **Project Rend** under:  
   `Settings -> Import -> Game Save - Emulator/Phone -> Connect over wifi`

## Files Included

* **`start_battery_monitor.ps1`** — Launcher script that connects to your phone via ADB and starts the monitoring loop.
* **`monitor_battery.ps1`** — Core script that checks battery percentage and charging status every 10 minutes (default) and displays Windows popup warnings.

## Alert Behavior

* **Low Battery Alert (≤ 25%):** Triggers only when the phone is **unplugged** (not charging).
* **Full Charge Alert (100%):** Triggers only when the phone is **still plugged in** (charging) so you know when to unplug it.
* **Auto-Reconnect:** Automatically attempts to reconnect over Wi-Fi if the ADB session drops between checks.

## Usage

Open Windows Terminal or PowerShell and run the launcher script with your phone's current Wireless Debugging port:

    powershell -File "D:\start_battery_monitor.ps1" -PhonePort 41235

### Optional Parameters

If your phone's local IP address differs from the default (`192.168.1.50`), pass `-PhoneIP` as well:

    powershell -File "D:\start_battery_monitor.ps1" -PhoneIP "192.168.1.105" -PhonePort 41235

You can also customize the threshold or check interval by running `monitor_battery.ps1` directly:

    .\monitor_battery.ps1 -PhoneIP "192.168.1.105" -PhonePort "41235" -Threshold 20 -CheckIntervalSeconds 300

## Viewing Built-in Help

Both scripts include full PowerShell comment-based help. To inspect all parameters and examples in your terminal, run:

    Get-Help D:\start_battery_monitor.ps1 -Detailed
    Get-Help D:\monitor_battery.ps1 -Detailed

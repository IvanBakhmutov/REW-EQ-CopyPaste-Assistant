# ============================================
# Module: Mouse and Keyboard Control Utilities for REW-EQ-CopyPaste-Assistant
# Description: Provides mouse & keyboard control utilities
# Author: Ivan Bakhmutov
# Date: 2024-06-10
# ============================================

# --- Mouse wrapper functions ---
<#function Invoke-MouseMoveBy {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::MoveBy($X, $Y)
}#>

function Invoke-MouseClickLeftAt {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    Move-CursorToPosition -X $X -Y $Y # Move cursor to the specified position
    [MouseControl]::ClickAt($X, $Y)   # Perform the left click
}

function Invoke-MouseClickRightAt {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    Move-CursorToPosition -X $X -Y $Y # Move cursor to the specified position
    [MouseControl]::RightClick()         # Perform the right click
}

<#function Invoke-MouseClickRelative {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::ClickRelative($X, $Y) # Perform the relative click
}#>

function Invoke-MouseRightClick {
    [CmdletBinding()]
    param ()
    [MouseControl]::RightClick()
}

function Invoke-MouseLeftClick {
    [CmdletBinding()]
    param ()
    [MouseControl]::LeftClick()
}

function Invoke-MouseScrollUp {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y,
        [int]$Amount = 120
    )
    Move-CursorToPosition -X $X -Y $Y # Move cursor to the specified position
    [MouseControl]::ScrollUp($Amount) # Perform the scroll up action
}

function Invoke-MouseScrollDown {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y,
        [int]$Amount = 120
    )
    Move-CursorToPosition -X $X -Y $Y # Move cursor to the specified position
    [MouseControl]::ScrollDown($Amount) # Perform the scroll down action
}

function Move-CursorToPosition {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::SetCursorPos($X, $Y) # Move cursor to the specified position
}

# --- Keyboard wrapper function ---
function Invoke-KeyStroke {
    <#
    .SYNOPSIS
        Sends a key or key combination to the active window.
    .EXAMPLE
        Invoke-KeyStroke "Hello world"
    .EXAMPLE
        Invoke-KeyStroke "^a"   # Ctrl+A
    .EXAMPLE
        Invoke-KeyStroke "%{TAB}"   # Alt+Tab
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Keys
    )
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Get-MousePosition {
    $point = New-Object MouseControl+POINT
    [MouseControl]::GetCursorPos([ref]$point) | Out-Null
    return $point.X, $point.Y
}

function Wait-HotkeyInput {
    param(
        [int]$timeoutSecs = 60,
        [string[]]$KeysToMonitor # Array of key names to monitor (e.g., "F1", "F2")
    )



    # Map key names to virtual key codes
    $keyNameToCode = @{
        "F1" = 112; "F2" = 113; "F3" = 114; "F4" = 115; "F5" = 116;
        "F6" = 117; "F7" = 118; "F8" = 119; "F9" = 120; "F10" = 121;
        "F11" = 122; "F12" = 123
    }

    # Convert key names to virtual key codes
    $keyCodesToMonitor = $KeysToMonitor | ForEach-Object { $keyNameToCode[$_] }

    $UserActionStartTime = Get-Date
    $s_prev = "" # Initialize previous state

    while ($UserActionStartTime.AddSeconds($timeoutSecs) -gt (Get-Date)) {
        $keys = @()
        foreach ($k in $keyCodesToMonitor) {
            $null = [User32]::GetAsyncKeyState($k) # Flush keyboard buffers
            if ([User32]::GetAsyncKeyState($k)) {
                switch ($k) {
                    112 { $keys += "F1" }
                    113 { $keys += "F2" }
                    114 { $keys += "F3" }
                    115 { $keys += "F4" }
                    116 { $keys += "F5" }
                    117 { $keys += "F6" }
                    118 { $keys += "F7" }
                    119 { $keys += "F8" }
                    120 { $keys += "F9" }
                    121 { $keys += "F10" }
                    122 { $keys += "F11" }
                    123 { $keys += "F12" }
                }
            }
        }
        $s = $keys -join ", "
        # Only return when a key is detected and it's different from the previous state
        if (($s -ne "") -and ($s -ne $s_prev)) {
            $s_prev = $s
            return $s
        }
        $s_prev = $s
        Start-Sleep -Milliseconds 50
    }
}


<#
function Wait-HotkeyInput {
    [CmdletBinding()]
    param(
        [int]$TimeoutSecs = 60,
        [string[]]$KeysToMonitor
    )

    # Load WinForms (optional, but harmless)
    Add-Type -AssemblyName System.Windows.Forms

    # Load User32 API if not defined
    if (-not ("User32" -as [Type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class User32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@
    }

    # Key mapping (extend if needed)
    $KeyNameToCode = @{
        "F1" = 112; "F2" = 113; "F3" = 114; "F4" = 115;
        "F5" = 116; "F6" = 117; "F7" = 118; "F8" = 119;
        "F9" = 120; "F10" = 121; "F11" = 122; "F12" = 123;
    }

    # Validate requested keys
    foreach ($key in $KeysToMonitor) {
        if (-not $KeyNameToCode.ContainsKey($key)) {
            throw "Unknown key: '$key'. Supported keys: $($KeyNameToCode.Keys -join ', ')"
        }
    }

    # Build reverse map (virtual-key → key-name)
    $CodeToName = @{}
    foreach ($pair in $KeyNameToCode.GetEnumerator()) {
        $CodeToName[$pair.Value] = $pair.Key
    }

    # Convert key names → virtual codes once
    $KeyCodes = $KeysToMonitor | ForEach-Object { $KeyNameToCode[$_] }

    # Timeout setup
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Track previous key-down states
    $PrevKeysDown = @()

    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSecs) {

        $KeysDown = foreach ($code in $KeyCodes) {
            $state = [User32]::GetAsyncKeyState($code)

            # High bit (0x8000) = key is physically down
            if ($state -band 0x8000) {
                $CodeToName[$code]
            }
        }

        # Detect fresh press (transition: up → down)
        $NewKeys = $KeysDown | Where-Object { $_ -notin $PrevKeysDown }

        if ($NewKeys.Count -gt 0) {
        return $NewKeys
          #  return [PSCustomObject]@{
          #      Timestamp = Get-Date
          #      Keys      = $NewKeys
          #      AllDown   = $KeysDown
          #  }
        }

        $PrevKeysDown = $KeysDown
        Start-Sleep -Milliseconds 20
    }

    return $null  # Timed out
}
#>
<#
# Add global hotkey registration using Windows API
if (-not ("HotKeyManager" -as [type])) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public static class HotKeyManager
    {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    }
"@
}

function Register-GlobalHotkey {
    param (
        [int]$HotkeyId,
        [UInt32]$Modifiers, # e.g., MOD_ALT = 0x1, MOD_CONTROL = 0x2
        [UInt32]$VirtualKeyCode # e.g., 0x70 for F1
    )
    $result = [HotKeyManager]::RegisterHotKey([IntPtr]::Zero, $HotkeyId, $Modifiers, $VirtualKeyCode)
    if (-not $result) {
        $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($errorCode -eq 1409) {
            # ERROR_HOTKEY_ALREADY_REGISTERED
            Write-Host "Hotkey already registered. Attempting to unregister and re-register..." -ForegroundColor Yellow
            [HotKeyManager]::UnregisterHotKey([IntPtr]::Zero, $HotkeyId) | Out-Null
            $result = [HotKeyManager]::RegisterHotKey([IntPtr]::Zero, $HotkeyId, $Modifiers, $VirtualKeyCode)
            if ($result) {
                Write-Host "Successfully re-registered hotkey with ID $HotkeyId" -ForegroundColor Green
            }
            else {
                $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                Write-Host "Failed to re-register hotkey. Error code: $errorCode" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Failed to register hotkey. Error code: $errorCode" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Successfully registered hotkey with ID $HotkeyId" -ForegroundColor Green
    }
}

function Unregister-GlobalHotkey {
    param (
        [int]$HotkeyId
    )
    $result = [HotKeyManager]::UnregisterHotKey([IntPtr]::Zero, $HotkeyId)
    if (-not $result) {
        $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "Failed to unregister hotkey. Error code: $errorCode" -ForegroundColor Red
    }
    else {
        Write-Host "Successfully unregistered hotkey with ID $HotkeyId" -ForegroundColor Green
    }
}

# Example usage:
# Register-GlobalHotkey -HotkeyId 1 -Modifiers 0 -VirtualKeyCode 0x70 # F1
# Unregister-GlobalHotkey -HotkeyId 1
#> 

# --- Exported Functions ---
Export-ModuleMember -Function `
   # Invoke-MouseMoveBy,
    Invoke-MouseClickLeftAt,
    Invoke-MouseClickRightAt,
   # Invoke-MouseClickRelative,
    Invoke-MouseLeftClick,
    Invoke-MouseRightClick,
    Invoke-MouseScrollUp,
    Invoke-MouseScrollDown,
    Move-CursorToPosition,
    Invoke-KeyStroke,
    Get-MousePosition,
    Wait-HotkeyInput,
   # Register-GlobalHotkey,
   # Unregister-GlobalHotkey
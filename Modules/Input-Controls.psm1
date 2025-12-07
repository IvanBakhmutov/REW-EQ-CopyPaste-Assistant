# ============================================
# Module: InputControls
# Description: Mouse and Keyboard Control Utilities for REW-EQ-CopyPaste-Assistant. Provides mouse & keyboard control utilities
# Author: Ivan Bakhmutov
# Date: 2025-12-07
# ============================================

# --- Mouse wrapper functions ---
function Invoke-MouseRightClick {
    [CmdletBinding()]
    param ()
    [MouseControl]::RightClick() # Right click
}

function Invoke-MouseLeftClick {
    [CmdletBinding()]
    param ()
    [MouseControl]::LeftClick() # Left click
}

function Invoke-MouseScrollUp {
    [CmdletBinding()]
    param (
        [int]$Amount = 120
    )
    [MouseControl]::ScrollUp($Amount) # Perform the scroll up action
}

function Invoke-MouseScrollDown {
    [CmdletBinding()]
    param (
        [int]$Amount = 120
    )
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

# --- Exported Functions ---
Export-ModuleMember -Function `
    Invoke-MouseLeftClick,
    Invoke-MouseRightClick,
    Invoke-MouseScrollUp,
    Invoke-MouseScrollDown,
    Move-CursorToPosition,
    Invoke-KeyStroke,
    Get-MousePosition,
    Wait-HotkeyInput
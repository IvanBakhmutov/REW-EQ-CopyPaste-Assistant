# ============================================
# Module: Mouse and Keyboard Control Utilities for REW-EQ-CopyPaste-Assistant
# Description: Provides mouse & keyboard control utilities
# Author: Ivan Bakhmutov
# Date: 2025-11-25
# ============================================

# Ensure .NET types are defined only once
if (-not ("MouseControl" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MouseControl {
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    private const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    private const uint MOUSEEVENTF_LEFTUP = 0x04;
    private const uint MOUSEEVENTF_RIGHTDOWN = 0x08;
    private const uint MOUSEEVENTF_RIGHTUP = 0x10;
    private const uint MOUSEEVENTF_WHEEL = 0x0800;

    public static void MoveBy(int dx, int dy) {
        POINT pos;
        GetCursorPos(out pos);
        SetCursorPos(pos.X + dx, pos.Y + dy);
    }

    public static void ClickAt(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ClickRelative(int dx, int dy) {
        POINT pos;
        GetCursorPos(out pos);
        SetCursorPos(pos.X + dx, pos.Y + dy);
        mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void RightClick() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void LeftClick() {
        mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ScrollUp(int amount) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, (uint)amount, UIntPtr.Zero);
    }

    public static void ScrollDown(int amount) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, unchecked((uint)-amount), UIntPtr.Zero);
    }
}
"@
}

# --- Load SendKeys support (for keyboard input) ---
Add-Type -AssemblyName System.Windows.Forms

# --- Mouse wrapper functions ---
function Invoke-MouseMoveBy {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::MoveBy($X, $Y)
}

function Invoke-MouseClickLeftAt {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    Move-CursorToPosition -X $X -Y $S # Move cursor to the specified position
    [MouseControl]::ClickAt($X, $Y)     # Perform the left click
}

function Invoke-MouseClickRightAt {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    Move-CursorToPosition -X $X -Y $S # Move cursor to the specified position
    [MouseControl]::RightClick()         # Perform the right click
}

function Invoke-MouseClickRelative {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::ClickRelative($X, $Y) # Perform the relative click
}

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
        [int]$Amount = 120
    )
    [MouseControl]::ScrollUp($Amount)
}

function Invoke-MouseScrollDown {
    [CmdletBinding()]
    param (
        [int]$Amount = 120
    )
    [MouseControl]::ScrollDown($Amount)
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

    Add-Type -AssemblyName System.Windows.Forms

    if (-not ("User32" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@
    }

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
        Start-Sleep -Milliseconds 100
    }
}

# --- Exported Functions ---
Export-ModuleMember -Function `
    Invoke-MouseMoveBy,
    Invoke-MouseClickLeftAt,
    Invoke-MouseClickRightAt,
    Invoke-MouseClickRelative,
    Invoke-MouseLeftClick,
    Invoke-MouseRightClick,
    Invoke-MouseScrollUp,
    Invoke-MouseScrollDown,
    Move-CursorToPosition,
    Invoke-KeyStroke,
    Get-MousePosition,
    Wait-HotkeyInput
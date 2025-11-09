# ============================================
# Module: Mouse and Keyboard Control Utilities for REW-EQ-CopyPaste-Assistant
# Description: Provides mouse & keyboard control utilities
# Author: Ivan Bakhmutov
# Date: 2024-06-10
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

function Invoke-MouseClickAt {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::ClickAt($X, $Y)
}

function Invoke-MouseClickRelative {
    [CmdletBinding()]
    param (
        [int]$X,
        [int]$Y
    )
    [MouseControl]::ClickRelative($X, $Y)
}

function Invoke-MouseRightClick {
    [CmdletBinding()]
    param ()
    [MouseControl]::RightClick()
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

# --- Exported Functions ---
Export-ModuleMember -Function `
    Invoke-MouseMoveBy,
    Invoke-MouseClickAt,
    Invoke-MouseClickRelative,
    Invoke-MouseRightClick,
    Invoke-MouseScrollUp,
    Invoke-MouseScrollDown,
    Invoke-KeyStroke

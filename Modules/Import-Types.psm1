# ============================================
# Module: Import-Types
# Description: Supplemental Types Import Module
# Author: Ivan Bakhmutov
# Date: 2025-12-07
# ============================================


function Import-Types {
    Add-Type -AssemblyName PresentationCore, PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue

    # Minimize parent cmd.exe window
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

    # Ensure .NET types are defined only once
    if (-not ([type]::GetType("MouseControl"))) {
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

    public static void HoldLeftButton() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ReleaseLeftButton() {
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void HoldRightButton() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ReleaseRightButton() {
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, UIntPtr.Zero);
    }
}
"@
    }

    # --- Load SendKeys support (for keyboard input) ---
   # Add-Type -AssemblyName 

    if (-not ([type]::GetType("User32"))) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@
    }

   # Add-Type -AssemblyName System.Windows.Forms

    # Window to foreground API
    if (-not ([type]::GetType("NativeMethods"))) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeMethods {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static readonly IntPtr HWND_TOP = new IntPtr(0);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
}
"@ -ErrorAction Stop
    }

    # ---------------------------------------------------------
    # Blur API for Win7 (Aero)
    # ---------------------------------------------------------
    if (-not ([type]::GetType("Win7Blur"))) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win7Blur {
    [StructLayout(LayoutKind.Sequential)]
    public struct DWM_BLURBEHIND {
        public uint dwFlags;
        public bool fEnable;
        public IntPtr hRgnBlur;
        public bool fTransitionOnMaximized;
    }

    public const uint DWM_BB_ENABLE = 0x1;

    [DllImport("dwmapi.dll")]
    public static extern int DwmEnableBlurBehindWindow(IntPtr hwnd, ref DWM_BLURBEHIND bb);
}
"@
    }

    # ---------------------------------------------------------
    # Accent Blur for Win10/11
    # ---------------------------------------------------------
    if (-not ([type]::GetType("Win10Blur"))) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public enum AccentState {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
}

[StructLayout(LayoutKind.Sequential)]
public struct AccentPolicy {
    public AccentState AccentState;
    public int AccentFlags;
    public int GradientColor;
    public int AnimationId;
}

[StructLayout(LayoutKind.Sequential)]
public struct WindowCompositionAttributeData {
    public int Attribute;
    public IntPtr Data;
    public int SizeOfData;
}

public static class Win10Blur {
    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
}
"@
    }
}

Export-ModuleMember -Function Import-Types
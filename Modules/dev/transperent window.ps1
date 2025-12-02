function Show-PopupGUI {
    param (
        [Parameter(Mandatory = $true)][string]$ResourcesDir
    )

    # ---------------------------------------------------------
    # Decide OS version
    # ---------------------------------------------------------
    $winMajor = [Environment]::OSVersion.Version.Major
    $winBuild = [Environment]::OSVersion.Version.Build


    # ---------------------------------------------------------
    # WPF UI
    # ---------------------------------------------------------
    [xml]$xaml = (Get-Content "$ResourcesDir\PopupGUI.xml" -Raw -Encoding utf8)

    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $grid   = $window.FindName("MainGrid")
    $button = $window.FindName("ExitBTN")

    # ---------------------------------------------------------
    # Drag behavior - ONLY in MouseDown, remove the general window handler
    # ---------------------------------------------------------
    $grid.Add_MouseDown({
        if ($_.LeftButton -eq "Pressed") {
            $window.DragMove()
        }
    })
Add-Type -AssemblyName System.Windows.Forms
        # Set focus to Notepad window


    # Button click
    $button.Add_Click({
        Start-Sleep -Seconds 5 # Wait for 5 seconds

        # Emulate typing "hello world"
        [System.Windows.Forms.SendKeys]::SendWait("hello world")
    })

    # Register global hotkey
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public static class HotKeyManager {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    }
"@

    # ---------------------------------------------------------
    # Apply blur + shadow after hwnd exists
    # ---------------------------------------------------------
    # Deregister hotkey if already registered
    $hotkeyId = 1
    try {
        [HotKeyManager]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
    } catch {
        # Ignore errors if the hotkey was not registered
    }

    $window.Add_SourceInitialized({
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle

        # Register global hotkey
        $modifiers = 0x0 # No modifiers
        $virtualKey = 0x75 # F6 key

        $result = [HotKeyManager]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $modifiers, $virtualKey)
        if (-not $result) {
            $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Host "Failed to register hotkey. Error code: $errorCode" -ForegroundColor Red
        } else {
            Write-Host "Successfully registered hotkey (F6)" -ForegroundColor Green
        }

        # Add a message loop to listen for the hotkey
        $source = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
        $source.AddHook({
            param ($hwnd, $msg, $wParam, $lParam, $handled)
            if ($msg -eq 0x0312 -and $wParam -eq $hotkeyId) { # WM_HOTKEY
                Write-Host "Hotkey pressed!" -ForegroundColor Green

                # Update TextBlock content with the current date and time
                $textBlock = $window.FindName("TextBlockName") # Replace "TextBlockName" with the actual name of your TextBlock
                if ($textBlock -ne $null) {
                    $textBlock.Text = (Get-Date).ToString("F")
                    Write-Host "TextBlock updated with current date and time." -ForegroundColor Green
                } else {
                    Write-Host "TextBlock not found." -ForegroundColor Red
                }
                $handled = $true
            }
            return 0
        })

        # Ensure hotkey is unregistered when the window is closed
        $window.Add_Closed({
            [HotKeyManager]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
        })
    })

    # Ensure hotkey is deregistered at the end
    $window.Add_Closed({
        try {
            [HotKeyManager]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
        } catch {
            # Ignore errors if the hotkey was not registered
        }
    })

    # Windows 7 Aero Glass
    if ($winMajor -eq 6 -and $winBuild -lt 9200) {
        $bb = New-Object Win7Blur+DWM_BLURBEHIND
        $bb.dwFlags = [Win7Blur]::DWM_BB_ENABLE
        $bb.fEnable = $true
        [Win7Blur]::DwmEnableBlurBehindWindow($hwnd, [ref]$bb) | Out-Null
    }
    # Windows 10 / 11 Acrylic / Blur
    elseif ($winMajor -ge 10) {
        $accent = New-Object AccentPolicy
        $accent.AccentState = [AccentState]::ACCENT_ENABLE_BLURBEHIND
        # For acrylic use: ACCENT_ENABLE_ACRYLICBLURBEHIND

        $accentSize = [System.Runtime.InteropServices.Marshal]::SizeOf($accent)
        $accentPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($accentSize)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($accent, $accentPtr, $false)

        $data = New-Object WindowCompositionAttributeData
        $data.Attribute = 19 # WCA_ACCENT_POLICY
        $data.SizeOfData = $accentSize
        $data.Data = $accentPtr

        [Win10Blur]::SetWindowCompositionAttribute($hwnd, [ref]$data) | Out-Null

        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($accentPtr)
    }
    # Alternative to SendKeys.SendWait using keybd_event
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public static class KeyboardSimulator {
            [DllImport("user32.dll", SetLastError = true)]
            public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
            public const int KEYEVENTF_KEYDOWN = 0x0000;
            public const int KEYEVENTF_KEYUP = 0x0002;
        }
"@

        # Function to simulate typing "hello world"
        function Simulate-Typing {
            param ([string]$Text)

            foreach ($char in $Text.ToCharArray()) {
                $vk = [byte][System.Text.Encoding]::ASCII.GetBytes($char)[0] # Get ASCII value of the character
                [KeyboardSimulator]::keybd_event($vk, 0, [KeyboardSimulator]::KEYEVENTF_KEYDOWN, 0)
                [KeyboardSimulator]::keybd_event($vk, 0, [KeyboardSimulator]::KEYEVENTF_KEYUP, 0)
                Start-Sleep -Milliseconds 50 # Small delay between keystrokes
            }
        }

        # Simulate typing "hello world"
        Simulate-Typing -Text "hello world"

    # Run
    $window.ShowDialog() | Out-Null
    Return $null
}

Show-PopupGUI "resources"
Add-Type -AssemblyName PresentationFramework

# ---------------------------------------------------------
# Decide OS version
# ---------------------------------------------------------
$winMajor = [Environment]::OSVersion.Version.Major
$winBuild = [Environment]::OSVersion.Version.Build

# ---------------------------------------------------------
# Blur API for Win7 (Aero)
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# Accent Blur for Win10/11
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# WPF UI
# ---------------------------------------------------------
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        WindowStyle='none'
        AllowsTransparency='True'
        Background='Transparent'
        Width='272' Height='170'
        Topmost='True'
        ShowInTaskbar='False'
        Title='Universal Blur Window'>
    <Border Name='WindowBorder'

            BorderBrush='#3383D487'
            BorderThickness='1'>

        <Grid Name='MainGrid' Background="White">
            <Button Name='MyButton'
                    Width='80'
                    Height='25'
                    HorizontalAlignment='Right'
                    VerticalAlignment='Bottom'
                    Content='Exit' Margin="0,0,10,10"/>
            <Label Content="REW EQ CopyPaste Assistant" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" FontWeight="Bold"/>
            <TextBlock Name='MSG' HorizontalAlignment="Left" Margin="10,41,0,0" TextWrapping="Wrap" Text="Message text" VerticalAlignment="Top" Height="85" Width="247"/>
            <Image Margin="10,126,228,10"/>
        </Grid>
    </Border>
</Window>

"@

# Load XAML safely (fixes the New-Object XmlNodeReader error)
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)

$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)
$grid   = $window.FindName("MainGrid")
$button = $window.FindName("MyButton")
$MSG = $window.FindName("MSG")

# ---------------------------------------------------------
# Drag behavior
# ---------------------------------------------------------
$grid.Add_MouseDown({
    if ($_.LeftButton -eq "Pressed") {
        $window.DragMove()
    }
})

# Attach to the window itself, not just Grid
$window.Add_MouseDown({
    if ($_.LeftButton -eq "Pressed") {
        try { $window.DragMove() } catch {}
    }
})


# Button click
$button.Add_Click({
    [System.Windows.MessageBox]::Show("Button clicked!")
$window.close()
})

# Hover opacity
$window.Opacity = 0.5
$window.Add_MouseEnter({ $window.Opacity = 1.0 })
$window.Add_MouseLeave({
    if (-not $window.IsMouseOver) { $window.Opacity = 0.5 }
})

# ---------------------------------------------------------
# Apply blur + shadow after hwnd exists
# ---------------------------------------------------------
$window.Add_SourceInitialized({
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle

    # Apply shadow
  #  [ShadowHelper]::ApplyShadow($hwnd)

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
})
$message = "init"

$messages = @("one", "two", "three", "exit")

# Run the foreach loop in a Task
[System.Threading.Tasks.Task]::Run({
    foreach ($message in $messages) {
        Start-Sleep -Seconds 5

        # Update the UI using the Dispatcher
        $window.Dispatcher.Invoke([action] {
            $MSG.Text = $message
        }, [Windows.Threading.DispatcherPriority]::Render)
    }

    # Close the window after the loop
    $window.Dispatcher.Invoke([action] {
        $window.Close()
    }, [Windows.Threading.DispatcherPriority]::Render)
})

$window.Show() | Out-Null
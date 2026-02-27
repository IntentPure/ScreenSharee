Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================= NATIVE CLICK =================

if (-not ([System.Management.Automation.PSTypeName]'InputSimulator').Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class InputSimulator {
    [DllImport("user32.dll")]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT {
        public uint type;
        public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    const uint INPUT_MOUSE = 0;
    const uint LEFTDOWN  = 0x0002;
    const uint LEFTUP    = 0x0004;
    const uint RIGHTDOWN = 0x0008;
    const uint RIGHTUP   = 0x0010;

    public static void LeftClick() {
        INPUT[] i = new INPUT[2];
        i[0].type = INPUT_MOUSE;
        i[0].mi.dwFlags = LEFTDOWN;
        i[1].type = INPUT_MOUSE;
        i[1].mi.dwFlags = LEFTUP;
        SendInput(2, i, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void RightClick() {
        INPUT[] i = new INPUT[2];
        i[0].type = INPUT_MOUSE;
        i[0].mi.dwFlags = RIGHTDOWN;
        i[1].type = INPUT_MOUSE;
        i[1].mi.dwFlags = RIGHTUP;
        SendInput(2, i, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KeyState {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static bool IsDown(int key) {
        return (GetAsyncKeyState(key) & 0x8000) != 0;
    }
}
"@

# ================= STATE =================

$global:leftEnabled = $false
$global:rightEnabled = $false
$global:leftCPS = 10
$global:rightCPS = 10

# ================= FORM =================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sneaky Clicker"
$form.Size = New-Object System.Drawing.Size(350,260)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.KeyPreview = $true

# -------- LEFT SECTION --------

$leftLabel = New-Object System.Windows.Forms.Label
$leftLabel.Text = "Left CPS:"
$leftLabel.Top = 20
$leftLabel.Left = 20
$form.Controls.Add($leftLabel)

$leftValue = New-Object System.Windows.Forms.Label
$leftValue.Text = "10"
$leftValue.Top = 20
$leftValue.Left = 100
$form.Controls.Add($leftValue)

$leftSlider = New-Object System.Windows.Forms.TrackBar
$leftSlider.Minimum = 1
$leftSlider.Maximum = 50
$leftSlider.Value = 10
$leftSlider.Width = 280
$leftSlider.Left = 20
$leftSlider.Top = 45
$form.Controls.Add($leftSlider)

# -------- RIGHT SECTION --------

$rightLabel = New-Object System.Windows.Forms.Label
$rightLabel.Text = "Right CPS:"
$rightLabel.Top = 110
$rightLabel.Left = 20
$form.Controls.Add($rightLabel)

$rightValue = New-Object System.Windows.Forms.Label
$rightValue.Text = "10"
$rightValue.Top = 110
$rightValue.Left = 100
$form.Controls.Add($rightValue)

$rightSlider = New-Object System.Windows.Forms.TrackBar
$rightSlider.Minimum = 1
$rightSlider.Maximum = 50
$rightSlider.Value = 10
$rightSlider.Width = 280
$rightSlider.Left = 20
$rightSlider.Top = 135
$form.Controls.Add($rightSlider)

# -------- STATUS --------

$status = New-Object System.Windows.Forms.Label
$status.Text = "F6 = Toggle Left | F7 = Toggle Right"
$status.Dock = "Bottom"
$status.Height = 30
$status.TextAlign = "MiddleCenter"
$form.Controls.Add($status)

# ================= TIMERS =================

$leftTimer = New-Object System.Windows.Forms.Timer
$rightTimer = New-Object System.Windows.Forms.Timer

$leftTimer.Add_Tick({
    if ($global:leftEnabled -and [KeyState]::IsDown(0x01)) {
        [InputSimulator]::LeftClick()
    }
})

$rightTimer.Add_Tick({
    if ($global:rightEnabled -and [KeyState]::IsDown(0x02)) {
        [InputSimulator]::RightClick()
    }
})

# ================= EVENTS =================

$leftSlider.Add_ValueChanged({
    $global:leftCPS = $leftSlider.Value
    $leftValue.Text = $global:leftCPS
    $leftTimer.Interval = [math]::Max(1,[int](1000 / $global:leftCPS))
})

$rightSlider.Add_ValueChanged({
    $global:rightCPS = $rightSlider.Value
    $rightValue.Text = $global:rightCPS
    $rightTimer.Interval = [math]::Max(1,[int](1000 / $global:rightCPS))
})

$form.Add_KeyDown({

    if ($_.KeyCode -eq "F6") {
        $global:leftEnabled = -not $global:leftEnabled
        if ($global:leftEnabled) {
            $leftTimer.Interval = [math]::Max(1,[int](1000 / $global:leftCPS))
            $leftTimer.Start()
            $status.Text = "Left ENABLED (Hold Left Mouse)"
        }
        else {
            $leftTimer.Stop()
            $status.Text = "Left DISABLED"
        }
    }

    if ($_.KeyCode -eq "F7") {
        $global:rightEnabled = -not $global:rightEnabled
        if ($global:rightEnabled) {
            $rightTimer.Interval = [math]::Max(1,[int](1000 / $global:rightCPS))
            $rightTimer.Start()
            $status.Text = "Right ENABLED (Hold Right Mouse)"
        }
        else {
            $rightTimer.Stop()
            $status.Text = "Right DISABLED"
        }
    }

})

$form.Add_FormClosing({
    $leftTimer.Stop()
    $rightTimer.Stop()
})

[void]$form.ShowDialog()

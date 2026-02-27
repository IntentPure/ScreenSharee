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
    const uint LEFTDOWN = 0x0002;
    const uint LEFTUP   = 0x0004;
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

# ================= STATE =================

$leftActive = $false
$rightActive = $false
$leftCPS = 10
$rightCPS = 10

# ================= FORM =================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sneaky Clicker"
$form.Size = New-Object System.Drawing.Size(280,200)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.KeyPreview = $true

# Labels
$label = New-Object System.Windows.Forms.Label
$label.Text = "F1 = Left | F2 = Right"
$label.Dock = "Top"
$label.TextAlign = "MiddleCenter"
$form.Controls.Add($label)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Idle"
$status.Dock = "Bottom"
$status.TextAlign = "MiddleCenter"
$form.Controls.Add($status)

# ================= TIMERS =================

$leftTimer = New-Object System.Windows.Forms.Timer
$rightTimer = New-Object System.Windows.Forms.Timer

$leftTimer.Add_Tick({
    [InputSimulator]::LeftClick()
})

$rightTimer.Add_Tick({
    [InputSimulator]::RightClick()
})

# ================= HOTKEY HANDLING =================

$form.Add_KeyDown({

    if ($_.KeyCode -eq "F1") {

        $leftActive = -not $leftActive

        if ($leftActive) {
            $leftTimer.Interval = [math]::Max(1,[int](1000 / $leftCPS))
            $leftTimer.Start()
            $status.Text = "Left Clicking ON"
        }
        else {
            $leftTimer.Stop()
            $status.Text = "Left Clicking OFF"
        }
    }

    if ($_.KeyCode -eq "F2") {

        $rightActive = -not $rightActive

        if ($rightActive) {
            $rightTimer.Interval = [math]::Max(1,[int](1000 / $rightCPS))
            $rightTimer.Start()
            $status.Text = "Right Clicking ON"
        }
        else {
            $rightTimer.Stop()
            $status.Text = "Right Clicking OFF"
        }
    }

})

$form.Add_FormClosing({
    $leftTimer.Stop()
    $rightTimer.Stop()
})

[void]$form.ShowDialog()

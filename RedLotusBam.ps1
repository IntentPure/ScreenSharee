Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Native {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

    public const int VK_LBUTTON = 0x01;
    public const int VK_RBUTTON = 0x02;

    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP   = 0x0004;
    public const uint RIGHTDOWN = 0x0008;
    public const uint RIGHTUP   = 0x0010;

    public static bool IsDown(int key) {
        return (GetAsyncKeyState(key) & 0x8000) != 0;
    }

    public static void LeftClick() {
        mouse_event(LEFTDOWN,0,0,0,UIntPtr.Zero);
        mouse_event(LEFTUP,0,0,0,UIntPtr.Zero);
    }

    public static void RightClick() {
        mouse_event(RIGHTDOWN,0,0,0,UIntPtr.Zero);
        mouse_event(RIGHTUP,0,0,0,UIntPtr.Zero);
    }
}
"@

# ================= STATE =================

$leftEnabled = $false
$rightEnabled = $false
$leftCPS = 10
$rightCPS = 10

$leftStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$rightStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ================= FORM =================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sneaky Clicker"
$form.Size = New-Object System.Drawing.Size(350,260)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.KeyPreview = $true

# LEFT UI
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

# RIGHT UI
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

$status = New-Object System.Windows.Forms.Label
$status.Text = "F6 = Toggle Left | F7 = Toggle Right"
$status.Dock = "Bottom"
$status.Height = 30
$status.TextAlign = "MiddleCenter"
$form.Controls.Add($status)

# ================= SLIDER EVENTS =================

$leftSlider.Add_ValueChanged({
    $leftCPS = $leftSlider.Value
    $leftValue.Text = $leftCPS
})

$rightSlider.Add_ValueChanged({
    $rightCPS = $rightSlider.Value
    $rightValue.Text = $rightCPS
})

# ================= TOGGLE KEYS =================

$form.Add_KeyDown({

    if ($_.KeyCode -eq "F6") {
        $leftEnabled = -not $leftEnabled
        $status.Text = "Left: $leftEnabled | Right: $rightEnabled"
    }

    if ($_.KeyCode -eq "F7") {
        $rightEnabled = -not $rightEnabled
        $status.Text = "Left: $leftEnabled | Right: $rightEnabled"
    }

})

# ================= MAIN LOOP (Reliable) =================

[System.Windows.Forms.Application]::Add_Idle({

    if ($leftEnabled -and [Native]::IsDown(0x01)) {
        $interval = 1000 / $leftCPS
        if ($leftStopwatch.ElapsedMilliseconds -ge $interval) {
            [Native]::LeftClick()
            $leftStopwatch.Restart()
        }
    }

    if ($rightEnabled -and [Native]::IsDown(0x02)) {
        $interval = 1000 / $rightCPS
        if ($rightStopwatch.ElapsedMilliseconds -ge $interval) {
            [Native]::RightClick()
            $rightStopwatch.Restart()
        }
    }

})

[void]$form.ShowDialog()

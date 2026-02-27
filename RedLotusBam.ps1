Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
    const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    const uint MOUSEEVENTF_LEFTUP = 0x0004;
    const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    const uint MOUSEEVENTF_RIGHTUP = 0x0010;

    public static void LeftClick() {
        INPUT[] inputs = new INPUT[2];
        inputs[0].type = INPUT_MOUSE;
        inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        inputs[1].type = INPUT_MOUSE;
        inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
        SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void RightClick() {
        INPUT[] inputs = new INPUT[2];
        inputs[0].type = INPUT_MOUSE;
        inputs[0].mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
        inputs[1].type = INPUT_MOUSE;
        inputs[1].mi.dwFlags = MOUSEEVENTF_RIGHTUP;
        SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
}

public class GlobalHotkey {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static bool IsKeyPressed(int vKey) {
        return (GetAsyncKeyState(vKey) & 0x8000) != 0;
    }
}
"@
}

# ================= VARIABLES =================

$script:leftClickActive = $false
$script:rightClickActive = $false
$script:leftClickKey = 0
$script:rightClickKey = 0
$script:capturingLeftKey = $false
$script:capturingRightKey = $false
$script:leftTimer = $null
$script:rightTimer = $null
$script:keyCheckTimer = $null
$script:leftCPS = 10
$script:rightCPS = 10

# ================= UI =================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sneaky Clicker"
$form.Size = New-Object System.Drawing.Size(300, 260)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.KeyPreview = $true
$form.TopMost = $true

# ================= LEFT CLICK TOGGLE =================

function Toggle-LeftClick {

    $script:leftClickActive = -not $script:leftClickActive

    if ($script:leftClickActive) {

        $interval = [math]::Max(1, [int](1000 / $script:leftCPS))

        if ($script:leftTimer) {
            $script:leftTimer.Stop()
            $script:leftTimer.Dispose()
        }

        $script:leftTimer = New-Object System.Windows.Forms.Timer
        $script:leftTimer.Interval = $interval

        $script:leftTimer.Add_Tick({
            if ([GlobalHotkey]::IsKeyPressed(0x01)) {
                [InputSimulator]::LeftClick()
            }
        })

        $script:leftTimer.Start()
        Write-Host "Left clicking active"
    }
    else {
        if ($script:leftTimer) {
            $script:leftTimer.Stop()
        }
        Write-Host "Left clicking stopped"
    }
}

# ================= RIGHT CLICK TOGGLE =================

function Toggle-RightClick {

    $script:rightClickActive = -not $script:rightClickActive

    if ($script:rightClickActive) {

        $interval = [math]::Max(1, [int](1000 / $script:rightCPS))

        if ($script:rightTimer) {
            $script:rightTimer.Stop()
            $script:rightTimer.Dispose()
        }

        $script:rightTimer = New-Object System.Windows.Forms.Timer
        $script:rightTimer.Interval = $interval

        $script:rightTimer.Add_Tick({
            if ([GlobalHotkey]::IsKeyPressed(0x02)) {
                [InputSimulator]::RightClick()
            }
        })

        $script:rightTimer.Start()
        Write-Host "Right clicking active"
    }
    else {
        if ($script:rightTimer) {
            $script:rightTimer.Stop()
        }
        Write-Host "Right clicking stopped"
    }
}

# ================= SIMPLE HOTKEY CHECK =================

$script:keyCheckTimer = New-Object System.Windows.Forms.Timer
$script:keyCheckTimer.Interval = 50
$script:leftKeyWasPressed = $false
$script:rightKeyWasPressed = $false

# Default toggle keys (can change if wanted)
$script:leftClickKey = 0x70   # F1
$script:rightClickKey = 0x71  # F2

$script:keyCheckTimer.Add_Tick({

    $leftPressed = [GlobalHotkey]::IsKeyPressed($script:leftClickKey)
    if ($leftPressed -and -not $script:leftKeyWasPressed) {
        Toggle-LeftClick
        $script:leftKeyWasPressed = $true
    }
    elseif (-not $leftPressed) {
        $script:leftKeyWasPressed = $false
    }

    $rightPressed = [GlobalHotkey]::IsKeyPressed($script:rightClickKey)
    if ($rightPressed -and -not $script:rightKeyWasPressed) {
        Toggle-RightClick
        $script:rightKeyWasPressed = $true
    }
    elseif (-not $rightPressed) {
        $script:rightKeyWasPressed = $false
    }
})

$script:keyCheckTimer.Start()

$form.Add_FormClosing({
    if ($script:leftTimer) { $script:leftTimer.Stop(); $script:leftTimer.Dispose() }
    if ($script:rightTimer) { $script:rightTimer.Stop(); $script:rightTimer.Dispose() }
    if ($script:keyCheckTimer) { $script:keyCheckTimer.Stop(); $script:keyCheckTimer.Dispose() }
})

Write-Host "Sneaky Clicker started"
Write-Host "F1 = Toggle Left Click"
Write-Host "F2 = Toggle Right Click"

[void]$form.ShowDialog()

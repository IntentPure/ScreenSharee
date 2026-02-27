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
$script:isDraggingLeft = $false
$script:isDraggingRight = $false

$script:keyMap = @{
    'F1' = 0x70; 'F2' = 0x71; 'F3' = 0x72; 'F4' = 0x73; 'F5' = 0x74; 'F6' = 0x75
    'F7' = 0x76; 'F8' = 0x77; 'F9' = 0x78; 'F10' = 0x79; 'F11' = 0x7A; 'F12' = 0x7B
    'A' = 0x41; 'B' = 0x42; 'C' = 0x43; 'D' = 0x44; 'E' = 0x45; 'F' = 0x46
    'G' = 0x47; 'H' = 0x48; 'I' = 0x49; 'J' = 0x4A; 'K' = 0x4B; 'L' = 0x4C
    'M' = 0x4D; 'N' = 0x4E; 'O' = 0x4F; 'P' = 0x50; 'Q' = 0x51; 'R' = 0x52
    'S' = 0x53; 'T' = 0x54; 'U' = 0x55; 'V' = 0x56; 'W' = 0x57; 'X' = 0x58
    'Y' = 0x59; 'Z' = 0x5A
    'D0' = 0x30; 'D1' = 0x31; 'D2' = 0x32; 'D3' = 0x33; 'D4' = 0x34
    'D5' = 0x35; 'D6' = 0x36; 'D7' = 0x37; 'D8' = 0x38; 'D9' = 0x39
    'Space' = 0x20; 'Shift' = 0x10; 'Control' = 0x11; 'Alt' = 0x12
    'XButton1' = 0x05; 'XButton2' = 0x06
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sneaky Clicker"
$form.Size = New-Object System.Drawing.Size(300, 280)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.KeyPreview = $true
$form.TopMost = $true

$buttonClose = New-Object System.Windows.Forms.Button
$buttonClose.Text = "×"
$buttonClose.Location = New-Object System.Drawing.Point(260, 5)
$buttonClose.Size = New-Object System.Drawing.Size(25, 25)
$buttonClose.FlatStyle = "Flat"
$buttonClose.FlatAppearance.BorderSize = 0
$buttonClose.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$buttonClose.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$buttonClose.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$buttonClose.Add_MouseEnter({ $buttonClose.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80) })
$buttonClose.Add_MouseLeave({ $buttonClose.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150) })
$buttonClose.Add_Click({
    if ($script:leftTimer) { $script:leftTimer.Stop(); $script:leftTimer.Dispose() }
    if ($script:rightTimer) { $script:rightTimer.Stop(); $script:rightTimer.Dispose() }
    if ($script:keyCheckTimer) { $script:keyCheckTimer.Stop(); $script:keyCheckTimer.Dispose() }
    $form.Close()
})
$form.Controls.Add($buttonClose)

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Sneaky Clicker"
$labelTitle.Location = New-Object System.Drawing.Point(70, 15)
$labelTitle.Size = New-Object System.Drawing.Size(160, 25)
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$labelTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($labelTitle)

$labelLeftClick = New-Object System.Windows.Forms.Label
$labelLeftClick.Text = "Left click"
$labelLeftClick.Location = New-Object System.Drawing.Point(30, 65)
$labelLeftClick.Size = New-Object System.Drawing.Size(70, 20)
$labelLeftClick.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$labelLeftClick.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$form.Controls.Add($labelLeftClick)

$buttonLeftKey = New-Object System.Windows.Forms.Button
$buttonLeftKey.Text = "none"
$buttonLeftKey.Location = New-Object System.Drawing.Point(105, 63)
$buttonLeftKey.Size = New-Object System.Drawing.Size(60, 24)
$buttonLeftKey.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonLeftKey.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$buttonLeftKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$buttonLeftKey.FlatStyle = "Flat"
$buttonLeftKey.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$buttonLeftKey.Add_Click({
    $buttonLeftKey.Text = "Press..."
    $buttonLeftKey.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $script:capturingLeftKey = $true
    $labelStatus.Text = "Press a key for left click..."
})
$form.Controls.Add($buttonLeftKey)

$labelLeftCount = New-Object System.Windows.Forms.Label
$labelLeftCount.Text = "10 CPS"
$labelLeftCount.Location = New-Object System.Drawing.Point(175, 65)
$labelLeftCount.Size = New-Object System.Drawing.Size(90, 20)
$labelLeftCount.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelLeftCount.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$labelLeftCount.TextAlign = "MiddleRight"
$form.Controls.Add($labelLeftCount)

$panelLeftBar = New-Object System.Windows.Forms.Panel
$panelLeftBar.Location = New-Object System.Drawing.Point(30, 95)
$panelLeftBar.Size = New-Object System.Drawing.Size(235, 10)
$panelLeftBar.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$panelLeftBar.Cursor = [System.Windows.Forms.Cursors]::Hand

$panelLeftBar.Add_MouseDown({
    param($sender, $e)
    $script:isDraggingLeft = $true
    $clickX = [math]::Max(0, [math]::Min(235, $e.X))
    $newCPS = [math]::Max(1, [math]::Min(200, [int](($clickX / 235.0) * 200) + 1))
    $script:leftCPS = $newCPS
    $labelLeftCount.Text = "$($script:leftCPS) CPS"
    $newWidth = [int](235 * ($script:leftCPS / 200.0))
    $panelLeftProgress.Width = $newWidth
})

$panelLeftBar.Add_MouseMove({
    param($sender, $e)
    if ($script:isDraggingLeft) {
        $clickX = [math]::Max(0, [math]::Min(235, $e.X))
        $newCPS = [math]::Max(1, [math]::Min(200, [int](($clickX / 235.0) * 200) + 1))
        $script:leftCPS = $newCPS
        $labelLeftCount.Text = "$($script:leftCPS) CPS"
        $newWidth = [int](235 * ($script:leftCPS / 200.0))
        $panelLeftProgress.Width = $newWidth
    }
})

$panelLeftBar.Add_MouseUp({
    param($sender, $e)
    $script:isDraggingLeft = $false
})

$form.Add_MouseUp({
    $script:isDraggingLeft = $false
    $script:isDraggingRight = $false
})

$form.Controls.Add($panelLeftBar)

$panelLeftProgress = New-Object System.Windows.Forms.Panel
$panelLeftProgress.Location = New-Object System.Drawing.Point(0, 0)
$panelLeftProgress.Size = New-Object System.Drawing.Size(12, 10)
$panelLeftProgress.BackColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$panelLeftProgress.Enabled = $false  # Disabilita eventi sulla barra bianca
$panelLeftBar.Controls.Add($panelLeftProgress)

$labelRightClick = New-Object System.Windows.Forms.Label
$labelRightClick.Text = "Right click"
$labelRightClick.Location = New-Object System.Drawing.Point(30, 135)
$labelRightClick.Size = New-Object System.Drawing.Size(70, 20)
$labelRightClick.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$labelRightClick.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$form.Controls.Add($labelRightClick)

$buttonRightKey = New-Object System.Windows.Forms.Button
$buttonRightKey.Text = "none"
$buttonRightKey.Location = New-Object System.Drawing.Point(105, 133)
$buttonRightKey.Size = New-Object System.Drawing.Size(60, 24)
$buttonRightKey.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonRightKey.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$buttonRightKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$buttonRightKey.FlatStyle = "Flat"
$buttonRightKey.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$buttonRightKey.Add_Click({
    $buttonRightKey.Text = "Press..."
    $buttonRightKey.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $script:capturingRightKey = $true
    $labelStatus.Text = "Press a key for right click..."
})
$form.Controls.Add($buttonRightKey)

$labelRightCount = New-Object System.Windows.Forms.Label
$labelRightCount.Text = "10 CPS"
$labelRightCount.Location = New-Object System.Drawing.Point(175, 135)
$labelRightCount.Size = New-Object System.Drawing.Size(90, 20)
$labelRightCount.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelRightCount.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$labelRightCount.TextAlign = "MiddleRight"
$form.Controls.Add($labelRightCount)

$panelRightBar = New-Object System.Windows.Forms.Panel
$panelRightBar.Location = New-Object System.Drawing.Point(30, 165)
$panelRightBar.Size = New-Object System.Drawing.Size(235, 10)
$panelRightBar.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$panelRightBar.Cursor = [System.Windows.Forms.Cursors]::Hand

$panelRightBar.Add_MouseDown({
    param($sender, $e)
    $script:isDraggingRight = $true
    $clickX = [math]::Max(0, [math]::Min(235, $e.X))
    $newCPS = [math]::Max(1, [math]::Min(30, [int](($clickX / 235.0) * 30) + 1))
    $script:rightCPS = $newCPS
    $labelRightCount.Text = "$($script:rightCPS) CPS"
    $newWidth = [int](235 * ($script:rightCPS / 30.0))
    $panelRightProgress.Width = $newWidth
})

$panelRightBar.Add_MouseMove({
    param($sender, $e)
    if ($script:isDraggingRight) {
        $clickX = [math]::Max(0, [math]::Min(235, $e.X))
        $newCPS = [math]::Max(1, [math]::Min(30, [int](($clickX / 235.0) * 30) + 1))
        $script:rightCPS = $newCPS
        $labelRightCount.Text = "$($script:rightCPS) CPS"
        $newWidth = [int](235 * ($script:rightCPS / 30.0))
        $panelRightProgress.Width = $newWidth
    }
})

$panelRightBar.Add_MouseUp({
    param($sender, $e)
    $script:isDraggingRight = $false
})

$form.Controls.Add($panelRightBar)

$panelRightProgress = New-Object System.Windows.Forms.Panel
$panelRightProgress.Location = New-Object System.Drawing.Point(0, 0)
$panelRightProgress.Size = New-Object System.Drawing.Size(78, 10)
$panelRightProgress.BackColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$panelRightProgress.Enabled = $false  # Disabilita eventi sulla barra bianca
$panelRightBar.Controls.Add($panelRightProgress)

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = ""
$labelStatus.Location = New-Object System.Drawing.Point(30, 195)
$labelStatus.Size = New-Object System.Drawing.Size(240, 15)
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$form.Controls.Add($labelStatus)

$labelVersion = New-Object System.Windows.Forms.Label
$labelVersion.Text = "v1.5"
$labelVersion.Location = New-Object System.Drawing.Point(10, 220)
$labelVersion.Size = New-Object System.Drawing.Size(50, 20)
$labelVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelVersion.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$form.Controls.Add($labelVersion)

function Toggle-LeftClick {
    $script:leftClickActive = -not $script:leftClickActive
    if ($script:leftClickActive) {
        $buttonLeftKey.BackColor = [System.Drawing.Color]::FromArgb(80, 180, 80)
        $labelStatus.Text = "LEFT CLICKING ACTIVE!"
        $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
        
        $interval = [math]::Max(1, [int](1000 / $script:leftCPS))
        if ($script:leftTimer) {
            $script:leftTimer.Stop()
            $script:leftTimer.Dispose()
        }
        $script:leftTimer = New-Object System.Windows.Forms.Timer
        $script:leftTimer.Interval = $interval
$script:rightTimer.Add_Tick({
    # Only click if physical RIGHT mouse button is held
    if ([GlobalHotkey]::IsKeyPressed(0x02)) {
        [InputSimulator]::RightClick()
        $script:leftTimer.Start()
    } else {
        $buttonLeftKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
        $labelStatus.Text = "Left clicking stopped"
        $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
        if ($script:leftTimer) {
            $script:leftTimer.Stop()
        }
    }
}

function Toggle-RightClick {
    $script:rightClickActive = -not $script:rightClickActive
    if ($script:rightClickActive) {
        $buttonRightKey.BackColor = [System.Drawing.Color]::FromArgb(80, 180, 80)
        $labelStatus.Text = "RIGHT CLICKING ACTIVE!"
        $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
        
        $interval = [math]::Max(1, [int](1000 / $script:rightCPS))
        if ($script:rightTimer) {
            $script:rightTimer.Stop()
            $script:rightTimer.Dispose()
        }
        $script:rightTimer = New-Object System.Windows.Forms.Timer
        $script:rightTimer.Interval = $interval
$script:rightTimer.Add_Tick({
    # Only click if physical RIGHT mouse button is held
    if ([GlobalHotkey]::IsKeyPressed(0x02)) {
        [InputSimulator]::RightClick()
    }
})
        $script:rightTimer.Start()
    } else {
        $buttonRightKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
        $labelStatus.Text = "Right clicking stopped"
        $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
        if ($script:rightTimer) {
            $script:rightTimer.Stop()
        }
    }
}

$form.Add_KeyDown({
    param($sender, $e)
    if ($script:capturingLeftKey) {
        $keyString = $e.KeyCode.ToString()
        if ($script:keyMap.ContainsKey($keyString)) {
            $script:leftClickKey = $script:keyMap[$keyString]
            $buttonLeftKey.Text = $keyString
            $buttonLeftKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
            $labelStatus.Text = "Left key set: $keyString"
            $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
            $script:capturingLeftKey = $false
            $script:ignoreNextLeftPress = $true
        }
    } elseif ($script:capturingRightKey) {
        $keyString = $e.KeyCode.ToString()
        if ($script:keyMap.ContainsKey($keyString)) {
            $script:rightClickKey = $script:keyMap[$keyString]
            $buttonRightKey.Text = $keyString
            $buttonRightKey.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
            $labelStatus.Text = "Right key set: $keyString"
            $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
            $script:capturingRightKey = $false
            $script:ignoreNextRightPress = $true
        }
    }
})

$script:keyCheckTimer = New-Object System.Windows.Forms.Timer
$script:keyCheckTimer.Interval = 50
$script:leftKeyWasPressed = $false
$script:rightKeyWasPressed = $false
$script:ignoreNextLeftPress = $false
$script:ignoreNextRightPress = $false

$script:keyCheckTimer.Add_Tick({
    if ($script:leftClickKey -ne 0) {
        $isPressed = [GlobalHotkey]::IsKeyPressed($script:leftClickKey)
        if ($isPressed -and -not $script:leftKeyWasPressed) {
            if (-not $script:ignoreNextLeftPress) {
                Toggle-LeftClick
            } else {
                $script:ignoreNextLeftPress = $false
            }
            $script:leftKeyWasPressed = $true
        } elseif (-not $isPressed) {
            $script:leftKeyWasPressed = $false
        }
    }
    
    if ($script:rightClickKey -ne 0) {
        $isPressed = [GlobalHotkey]::IsKeyPressed($script:rightClickKey)
        if ($isPressed -and -not $script:rightKeyWasPressed) {
            if (-not $script:ignoreNextRightPress) {
                Toggle-RightClick
            } else {
                $script:ignoreNextRightPress = $false
            }
            $script:rightKeyWasPressed = $true
        } elseif (-not $isPressed) {
            $script:rightKeyWasPressed = $false
        }
    }
})

$script:keyCheckTimer.Start()

$form.Add_FormClosing({
    if ($script:leftTimer) { $script:leftTimer.Stop(); $script:leftTimer.Dispose() }
    if ($script:rightTimer) { $script:rightTimer.Stop(); $script:rightTimer.Dispose() }
    if ($script:keyCheckTimer) { $script:keyCheckTimer.Stop(); $script:keyCheckTimer.Dispose() }
})

Write-Host "Sneaky Clicker v1.5 started successfully!"
Write-Host "Drag the CPS bars to adjust the click speed!"
[void]$form.ShowDialog()
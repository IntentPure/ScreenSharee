Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host @"
Made with love by lily<3
"@ -ForegroundColor Cyan

if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    
    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    
    public const int MOUSEEVENTF_LEFTDOWN = 0x02;
    public const int MOUSEEVENTF_LEFTUP = 0x04;
    public const int MOUSEEVENTF_RIGHTDOWN = 0x08;
    public const int MOUSEEVENTF_RIGHTUP = 0x10;
    
    public const int VK_LBUTTON = 0x01;
    public const int VK_RBUTTON = 0x02;
}
"@
}

$script:isEnabled = $false
$script:cps = 10
$script:randomization = 0
$script:mainTimer = $null
$script:hotkeyTimer = $null
$script:hotkeyVK = 0x75  
$script:hotkeyName = "F6"
$script:leftLastClick = [DateTime]::MinValue
$script:rightLastClick = [DateTime]::MinValue
$script:capturingHotkey = $false

function Test-KeyPressed {
    param([int]$VirtualKey)
    $state = [Win32]::GetAsyncKeyState($VirtualKey)
    return ($state -band 0x8000) -ne 0
}

function Invoke-Click {
    param([string]$Button)
    
    if ($Button -eq "Left") {
        [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    } else {
        [Win32]::mouse_event([Win32]::MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
        [Win32]::mouse_event([Win32]::MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
    }
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Lilith Clicker"
$form.Size = New-Object System.Drawing.Size(420, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$form.ForeColor = [System.Drawing.Color]::White

# Variables for dragging
$script:isDragging = $false
$script:dragStart = New-Object System.Drawing.Point(0, 0)

# Variables for dragging
$script:isDragging = $false
$script:dragStart = New-Object System.Drawing.Point(0, 0)

# Custom Title Bar
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.Size = New-Object System.Drawing.Size(420, 35)
$titleBar.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
$titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($titleBar)

# Title Bar Label
$titleBarLabel = New-Object System.Windows.Forms.Label
$titleBarLabel.Location = New-Object System.Drawing.Point(10, 0)
$titleBarLabel.Size = New-Object System.Drawing.Size(300, 35)
$titleBarLabel.Text = "Lilith Clicker"
$titleBarLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$titleBarLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$titleBarLabel.TextAlign = "MiddleLeft"
$titleBarLabel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$titleBar.Controls.Add($titleBarLabel)

# Minimize Button
$minimizeButton = New-Object System.Windows.Forms.Button
$minimizeButton.Location = New-Object System.Drawing.Point(340, 0)
$minimizeButton.Size = New-Object System.Drawing.Size(40, 35)
$minimizeButton.Text = "_"
$minimizeButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$minimizeButton.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$minimizeButton.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
$minimizeButton.FlatStyle = "Flat"
$minimizeButton.FlatAppearance.BorderSize = 0
$minimizeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$minimizeButton.Add_Click({
    $form.WindowState = "Minimized"
})
$minimizeButton.Add_MouseEnter({
    $minimizeButton.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
})
$minimizeButton.Add_MouseLeave({
    $minimizeButton.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
})
$titleBar.Controls.Add($minimizeButton)

# Close Button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = New-Object System.Drawing.Point(380, 0)
$closeButton.Size = New-Object System.Drawing.Size(40, 35)
$closeButton.Text = "X"
$closeButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$closeButton.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$closeButton.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
$closeButton.FlatStyle = "Flat"
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$closeButton.Add_Click({
    $form.Close()
})
$closeButton.Add_MouseEnter({
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
})
$closeButton.Add_MouseLeave({
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
})
$titleBar.Controls.Add($closeButton)

# Dragging functionality for title bar
$titleBar.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:isDragging = $true
        $script:dragStart = $e.Location
    }
})

$titleBar.Add_MouseMove({
    param($sender, $e)
    if ($script:isDragging) {
        $newLocation = $form.Location
        $newLocation.X += $e.X - $script:dragStart.X
        $newLocation.Y += $e.Y - $script:dragStart.Y
        $form.Location = $newLocation
    }
})

$titleBar.Add_MouseUp({
    param($sender, $e)
    $script:isDragging = $false
})

# Dragging functionality for title bar label (so dragging works on text too)
$titleBarLabel.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:isDragging = $true
        $offsetX = $e.X + $titleBarLabel.Location.X
        $script:dragStart = New-Object System.Drawing.Point($offsetX, $e.Y)
    }
})

$titleBarLabel.Add_MouseMove({
    param($sender, $e)
    if ($script:isDragging) {
        $newLocation = $form.Location
        $offsetX = $script:dragStart.X - $titleBarLabel.Location.X
        $newLocation.X += $e.X - $offsetX
        $newLocation.Y += $e.Y - $script:dragStart.Y
        $form.Location = $newLocation
    }
})

$titleBarLabel.Add_MouseUp({
    param($sender, $e)
    $script:isDragging = $false
})

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(0, 50)
$titleLabel.Size = New-Object System.Drawing.Size(420, 40)
$titleLabel.Text = "LILITH CLICKER"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$titleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($titleLabel)

# Subtitle
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Location = New-Object System.Drawing.Point(0, 90)
$subtitleLabel.Size = New-Object System.Drawing.Size(420, 20)
$subtitleLabel.Text = "--- <3 ---"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
$subtitleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($subtitleLabel)

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(50, 130)
$statusPanel.Size = New-Object System.Drawing.Size(320, 80)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
$form.Controls.Add($statusPanel)

# Status Indicator
$statusIndicator = New-Object System.Windows.Forms.Panel
$statusIndicator.Location = New-Object System.Drawing.Point(125, 15)
$statusIndicator.Size = New-Object System.Drawing.Size(12, 12)
$statusIndicator.BackColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$statusPanel.Controls.Add($statusIndicator)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(145, 10)
$statusLabel.Size = New-Object System.Drawing.Size(150, 22)
$statusLabel.Text = "DISABLED"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$statusLabel.TextAlign = "MiddleLeft"
$statusPanel.Controls.Add($statusLabel)

$hotkeyLabel = New-Object System.Windows.Forms.Label
$hotkeyLabel.Location = New-Object System.Drawing.Point(10, 45)
$hotkeyLabel.Size = New-Object System.Drawing.Size(300, 25)
$hotkeyLabel.Text = "Hotkey: F6 | Made by lily"
$hotkeyLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$hotkeyLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$hotkeyLabel.TextAlign = "MiddleCenter"
$statusPanel.Controls.Add($hotkeyLabel)

# Toggle Button
$toggleButton = New-Object System.Windows.Forms.Button
$toggleButton.Location = New-Object System.Drawing.Point(110, 230)
$toggleButton.Size = New-Object System.Drawing.Size(200, 50)
$toggleButton.Text = "START (F6)"
$toggleButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$toggleButton.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$toggleButton.ForeColor = [System.Drawing.Color]::White
$toggleButton.FlatStyle = "Flat"
$toggleButton.FlatAppearance.BorderSize = 0
$toggleButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$toggleFunction = {
    $script:isEnabled = -not $script:isEnabled
    if ($script:isEnabled) {
        $toggleButton.Text = "STOP ($($script:hotkeyName))"
        $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
        $statusLabel.Text = "ACTIVE"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
        $statusIndicator.BackColor = [System.Drawing.Color]::FromArgb(100, 220, 120)
        $script:leftLastClick = [DateTime]::MinValue
        $script:rightLastClick = [DateTime]::MinValue
        $script:mainTimer.Start()
    } else {
        $toggleButton.Text = "START ($($script:hotkeyName))"
        $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $statusLabel.Text = "DISABLED"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
        $statusIndicator.BackColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
        $script:mainTimer.Stop()
    }
}

$toggleButton.Add_Click($toggleFunction)
$form.Controls.Add($toggleButton)

# Separator Line
$separator1 = New-Object System.Windows.Forms.Panel
$separator1.Location = New-Object System.Drawing.Point(50, 300)
$separator1.Size = New-Object System.Drawing.Size(320, 1)
$separator1.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$form.Controls.Add($separator1)

# Hotkey Group
$hotkeyGroupLabel = New-Object System.Windows.Forms.Label
$hotkeyGroupLabel.Location = New-Object System.Drawing.Point(50, 315)
$hotkeyGroupLabel.Size = New-Object System.Drawing.Size(150, 22)
$hotkeyGroupLabel.Text = "Toggle Hotkey"
$hotkeyGroupLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$hotkeyGroupLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$form.Controls.Add($hotkeyGroupLabel)

$hotkeyTextbox = New-Object System.Windows.Forms.TextBox
$hotkeyTextbox.Location = New-Object System.Drawing.Point(220, 313)
$hotkeyTextbox.Size = New-Object System.Drawing.Size(150, 28)
$hotkeyTextbox.Text = "F6"
$hotkeyTextbox.Font = New-Object System.Drawing.Font("Consolas", 11)
$hotkeyTextbox.BackColor = [System.Drawing.Color]::FromArgb(48, 48, 48)
$hotkeyTextbox.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$hotkeyTextbox.BorderStyle = "FixedSingle"
$hotkeyTextbox.ReadOnly = $true
$hotkeyTextbox.TextAlign = "Center"
$hotkeyTextbox.Add_Click({
    $hotkeyTextbox.Text = "Press key..."
    $hotkeyTextbox.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $script:capturingHotkey = $true
    $hotkeyTextbox.Focus()
})
$hotkeyTextbox.Add_KeyDown({
    param($sender, $e)
    if ($script:capturingHotkey) {
        $vk = $e.KeyValue
        if ($vk -ne 1 -and $vk -ne 2 -and $vk -ne 4) {
            $script:hotkeyVK = $vk
            $script:hotkeyName = $e.KeyCode.ToString()
            $hotkeyTextbox.Text = $script:hotkeyName
            $hotkeyTextbox.BackColor = [System.Drawing.Color]::FromArgb(48, 48, 48)
            $hotkeyLabel.Text = "Hotkey: $($script:hotkeyName) | Made by lily"
            $toggleButton.Text = if ($script:isEnabled) { "STOP ($($script:hotkeyName))" } else { "START ($($script:hotkeyName))" }
        }
        $script:capturingHotkey = $false
        $e.SuppressKeyPress = $true
        $e.Handled = $true
    }
})
$form.Controls.Add($hotkeyTextbox)

# CPS Control
$cpsLabel = New-Object System.Windows.Forms.Label
$cpsLabel.Location = New-Object System.Drawing.Point(50, 355)
$cpsLabel.Size = New-Object System.Drawing.Size(200, 22)
$cpsLabel.Text = "Clicks Per Second"
$cpsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cpsLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$form.Controls.Add($cpsLabel)

$cpsValue = New-Object System.Windows.Forms.Label
$cpsValue.Location = New-Object System.Drawing.Point(320, 355)
$cpsValue.Size = New-Object System.Drawing.Size(50, 22)
$cpsValue.Text = "10"
$cpsValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cpsValue.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$cpsValue.TextAlign = "MiddleRight"
$form.Controls.Add($cpsValue)

$cpsSlider = New-Object System.Windows.Forms.TrackBar
$cpsSlider.Location = New-Object System.Drawing.Point(50, 380)
$cpsSlider.Size = New-Object System.Drawing.Size(320, 45)
$cpsSlider.Minimum = 1
$cpsSlider.Maximum = 50
$cpsSlider.Value = 10
$cpsSlider.TickFrequency = 5
$cpsSlider.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$cpsSlider.Add_ValueChanged({
    $script:cps = $cpsSlider.Value
    $cpsValue.Text = $script:cps.ToString()
})
$form.Controls.Add($cpsSlider)

# Randomization Control
$randLabel = New-Object System.Windows.Forms.Label
$randLabel.Location = New-Object System.Drawing.Point(50, 425)
$randLabel.Size = New-Object System.Drawing.Size(200, 22)
$randLabel.Text = "Randomization"
$randLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$randLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$form.Controls.Add($randLabel)

$randValue = New-Object System.Windows.Forms.Label
$randValue.Location = New-Object System.Drawing.Point(305, 425)
$randValue.Size = New-Object System.Drawing.Size(65, 22)
$randValue.Text = "0%"
$randValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$randValue.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$randValue.TextAlign = "MiddleRight"
$form.Controls.Add($randValue)

$randSlider = New-Object System.Windows.Forms.TrackBar
$randSlider.Location = New-Object System.Drawing.Point(50, 450)
$randSlider.Size = New-Object System.Drawing.Size(320, 45)
$randSlider.Minimum = 0
$randSlider.Maximum = 100
$randSlider.Value = 0
$randSlider.TickFrequency = 10
$randSlider.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$randSlider.Add_ValueChanged({
    $script:randomization = $randSlider.Value
    $randValue.Text = "$($script:randomization)%"
})
$form.Controls.Add($randSlider)

# Debug Label
$debugLabel = New-Object System.Windows.Forms.Label
$debugLabel.Location = New-Object System.Drawing.Point(50, 495)
$debugLabel.Size = New-Object System.Drawing.Size(320, 20)
$debugLabel.Text = "Ready"
$debugLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
$debugLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$form.Controls.Add($debugLabel)

# Main Timer
$script:mainTimer = New-Object System.Windows.Forms.Timer
$script:mainTimer.Interval = 1
$script:mainTimer.Add_Tick({
    if (-not $script:isEnabled) { return }

    $isLeftDown = Test-KeyPressed -VirtualKey ([Win32]::VK_LBUTTON)
    $isRightDown = Test-KeyPressed -VirtualKey ([Win32]::VK_RBUTTON)
    
    $now = [DateTime]::Now
    
    $randomPercent = $script:randomization / 100.0
    $randomMultiplier = 1.0 + ((Get-Random -Minimum -100 -Maximum 101) / 100.0) * $randomPercent
    $actualCps = [Math]::Max(0.5, $script:cps * $randomMultiplier)
    $intervalMs = 1000.0 / $actualCps
    
    $debugLabel.Text = "L:$isLeftDown R:$isRightDown | Actual CPS: $([Math]::Round($actualCps, 1))"

    if ($isLeftDown) {
        $elapsed = ($now - $script:leftLastClick).TotalMilliseconds
        if ($script:leftLastClick -eq [DateTime]::MinValue -or $elapsed -ge $intervalMs) {
            Invoke-Click -Button "Left"
            $script:leftLastClick = $now

            $randomMultiplier = 1.0 + ((Get-Random -Minimum -100 -Maximum 101) / 100.0) * $randomPercent
            $actualCps = [Math]::Max(0.5, $script:cps * $randomMultiplier)
            $intervalMs = 1000.0 / $actualCps
        }
    } else {
        $script:leftLastClick = [DateTime]::MinValue
    }

    if ($isRightDown) {
        $elapsed = ($now - $script:rightLastClick).TotalMilliseconds
        if ($script:rightLastClick -eq [DateTime]::MinValue -or $elapsed -ge $intervalMs) {
            Invoke-Click -Button "Right"
            $script:rightLastClick = $now

            $randomMultiplier = 1.0 + ((Get-Random -Minimum -100 -Maximum 101) / 100.0) * $randomPercent
            $actualCps = [Math]::Max(0.5, $script:cps * $randomMultiplier)
            $intervalMs = 1000.0 / $actualCps
        }
    } else {
        $script:rightLastClick = [DateTime]::MinValue
    }
})

# Hotkey Timer
$script:hotkeyTimer = New-Object System.Windows.Forms.Timer
$script:hotkeyTimer.Interval = 20
$script:lastHotkeyDown = $false
$script:hotkeyTimer.Add_Tick({
    if ($script:hotkeyVK -eq 1 -or $script:hotkeyVK -eq 2) { return }
    
    $isDown = Test-KeyPressed -VirtualKey $script:hotkeyVK
    
    if ($isDown -and -not $script:lastHotkeyDown) {
        & $toggleFunction
    }
    
    $script:lastHotkeyDown = $isDown
})
$script:hotkeyTimer.Start()

$form.Add_FormClosing({
    if ($script:mainTimer) { $script:mainTimer.Stop(); $script:mainTimer.Dispose() }
    if ($script:hotkeyTimer) { $script:hotkeyTimer.Stop(); $script:hotkeyTimer.Dispose() }
})

$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()

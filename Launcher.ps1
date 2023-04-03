Add-Type -AssemblyName PresentationFramework,WindowsBase,System.Xaml
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Edge { Start-Process msedge -ArgumentList "--edge-frame", "--app=$($args[0])" -WindowStyle Hidden }
function RDP { & "mstsc.exe" "$env:userprofile\Documents\VMs\$args" }

$window = New-Object System.Windows.Window -Property @{
    Title                 = "Launcher"
    Width                 = 200
    Height                = 200
    WindowStartupLocation = "Manual"
    Left                  = [System.Windows.SystemParameters]::PrimaryScreenWidth - 210
    Top                   = [System.Windows.SystemParameters]::PrimaryScreenHeight - 250
    ResizeMode            = "NoResize"
    WindowStyle           = "None"
    Topmost               = $true
    AllowsTransparency    = $true
    ShowInTaskbar         = $False
}

$grid = New-Object System.Windows.Controls.Grid

for ($i = 0; $i -lt 3; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
}

$buttonConfigs = Get-Content -Raw -Path "launcher_options.json" | ConvertFrom-Json
# $buttonConfigs = (Invoke-WebRequest -Uri "bit.ly/Automatech-ButtonJSON").Content | ConvertFrom-Json


$buttons = foreach ($config in $buttonConfigs) {
    $image = New-Object System.Windows.Controls.Image -Property @{
        Stretch = "UniformToFill"
        Source = if ($config.Image.Base64) {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $memoryStream = New-Object System.IO.MemoryStream
            $memoryStream.Write([System.Convert]::FromBase64String($config.Image.Base64), 0, [System.Convert]::FromBase64String($config.Image.Base64).Length)
            $memoryStream.Position = 0
            $bitmap.BeginInit()
            $bitmap.StreamSource = $memoryStream
            $bitmap.CacheOption = "OnLoad"
            $bitmap.EndInit()
            $bitmap
        } else {
            $config.Image.Path
        }
    }

    $button = New-Object System.Windows.Controls.Button -Property @{
        Content = $image
        Cursor = [System.Windows.Input.Cursors]::Hand
        Background = $config.Background
        BorderThickness = New-Object System.Windows.Thickness $config.BorderThickness
        BorderBrush = $config.BorderBrush
        ToolTip = $config.ToolTip
    }

    $button.Add_Click([Scriptblock]::Create($config.Action))
    $button
}

for ($i = 0; $i -lt $buttons.Count; $i++) {
    $grid.Children.Add($buttons[$i])
    [System.Windows.Controls.Grid]::SetRow($buttons[$i], [math]::Floor($i / 3))
    [System.Windows.Controls.Grid]::SetColumn($buttons[$i], $i % 3)
}

# create a system tray icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$iconBytes = [System.Convert]::FromBase64String($base64Icon)
$iconStream = New-Object System.IO.MemoryStream -ArgumentList (,$iconBytes)
$loadedIcon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::FromStream($iconStream)).GetHicon())
$notifyIcon.Icon = $loadedIcon
# $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Visible = $true
$notifyIcon.Text = "WebGui"

$notifyIcon.Add_Click({
    if ($_.Button -eq 'Left') {
        $window.Topmost = -not $window.Topmost
    } elseif ($_.Button -eq 'Right') {
        $window.Close()
    }
})

$notifyIcon.Add_DoubleClick({
    if ($_.Button -eq 'Left') {
        if ($window.WindowState -eq [System.Windows.WindowState]::Normal) {
            $window.WindowState = [System.Windows.WindowState]::Minimized
        } else {
            $window.WindowState = [System.Windows.WindowState]::Normal
        }
    }
})

$window.Add_Closed({
    $notifyIcon.Dispose()
})




$grid.Background = "Transparent"
$window.Background = "Transparent"
$window.Content = $grid
$window.ShowDialog() | Out-Null

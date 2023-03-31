Add-Type -AssemblyName PresentationFramework

function Edge { Start-Process msedge -ArgumentList "--edge-frame", "--app=$($args[0])" -WindowStyle Hidden }
function RDP { & "mstsc.exe" "$env:userprofile\Documents\VMs\$args" }

$window = New-Object System.Windows.Window -Property @{
    Title                 = "Run"
    Width                 = 200
    Height                = 200
    # WindowStartupLocation = "CenterScreen"
    WindowStartupLocation = "Manual"
    Left                  = [System.Windows.SystemParameters]::PrimaryScreenWidth - $window.Width - 1
    Top                   = [System.Windows.SystemParameters]::PrimaryScreenHeight - $window.Height - 50
    ResizeMode            = "NoResize"
    WindowStyle           = "None"
    Topmost               = $true
}

$grid = New-Object System.Windows.Controls.Grid

for ($i = 0; $i -lt 3; $i++) {
    $rowDefinition = New-Object System.Windows.Controls.RowDefinition
    $grid.RowDefinitions.Add($rowDefinition)
    $columnDefinition = New-Object System.Windows.Controls.ColumnDefinition
    $grid.ColumnDefinitions.Add($columnDefinition)
}

# $buttonConfigs = (Invoke-WebRequest -Uri "bit.ly/Automatech-ButtonJSON").Content | ConvertFrom-Json
$buttonConfigs = Get-Content -Raw -Path "launcher_options.json" | ConvertFrom-Json
$buttons = @()
$buttons = foreach ($config in $buttonConfigs) {
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $config.Name
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $button.Background = $config.Background
    $button.BorderThickness = New-Object System.Windows.Thickness $config.BorderThickness
    $image = New-Object System.Windows.Controls.Image
    $image.Stretch = "UniformToFill"
    $imageUri = "https://raw.githubusercontent.com/<username>/<repository>/<branch>/<path-to-image-file>"
    $imageUri = $imageUri -replace "<username>", $config.Image.Username `
        -replace "<repository>", $config.Image.Repository `
        -replace "<branch>", $config.Image.Branch `
        -replace "<path-to-image-file>", $config.Image.Path
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.UriSource = New-Object System.Uri($imageUri)
    $bitmap.EndInit()
    $image.Source = $bitmap
    $button.Content = $image
    $button.BorderBrush = $config.BorderBrush
    $button.ToolTip = $config.ToolTip
    $action = [Scriptblock]::Create($config.Action)
    $button.Add_Click($action)
    $button
}

$grid.Children.Clear()
for ($i = 0; $i -lt $buttons.Count; $i++) {
    $grid.Children.Add($buttons[$i])
    [System.Windows.Controls.Grid]::SetRow($buttons[$i], [math]::Floor($i / 3))
    [System.Windows.Controls.Grid]::SetColumn($buttons[$i], $i % 3)
}
$grid.Background = "Transparent"
$window.Background = "Transparent"

$window.Content = $grid
$window.ShowDialog() | Out-Null

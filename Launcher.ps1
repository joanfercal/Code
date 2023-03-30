Add-Type -AssemblyName PresentationFramework

function Edge {Start-Process msedge -ArgumentList "--edge-frame", "--app=$($args[0])" -WindowStyle Hidden}

$window = New-Object System.Windows.Window -Property @{
    Title = "Run"
    Width = 200
    Height = 200
    # WindowStartupLocation = "CenterScreen"
    WindowStartupLocation = "Manual"
    Left = [System.Windows.SystemParameters]::PrimaryScreenWidth - $window.Width - 1
    Top = [System.Windows.SystemParameters]::PrimaryScreenHeight - $window.Height - 50
    ResizeMode="NoResize"
    WindowStyle = "None"
    Topmost = $true
}

$grid = New-Object System.Windows.Controls.Grid

for ($i = 0; $i -lt 3; $i++) {
    $rowDefinition = New-Object System.Windows.Controls.RowDefinition
    $grid.RowDefinitions.Add($rowDefinition)
    $columnDefinition = New-Object System.Windows.Controls.ColumnDefinition
    $grid.ColumnDefinitions.Add($columnDefinition)
}

$buttonConfigs = @(
    @{Name = "Installer"; Image = "unnamed.png"; Action = {Invoke-WebRequest -useb bit.ly/Automatech-Installer | Invoke-Expression}}
    @{Name = "Uninstaller"; Image = "unnamed.png"; Action = {Invoke-WebRequest -useb bit.ly/Automatech-Uninstaller | Invoke-Expression}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://chat.openai.com/'}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "PVE"; Image = "unnamed.png"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "Close"; Image = "unnamed.png"; Action = {$window.Close()}}
)

$buttons = @()
$buttonConfigs.ForEach({
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $_.Name
    $button.Add_Click($_.Action)
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $button.Background = "Transparent"
    $button.BorderThickness = New-Object System.Windows.Thickness 0
    $image = New-Object System.Windows.Controls.Image
    $image.Source = $_.Image
    $image.Stretch = [System.Windows.Media.Stretch]::UniformToFill
    $button.Content = $image
    $buttons += $button
    $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
})

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

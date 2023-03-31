Add-Type -AssemblyName PresentationFramework
function Edge {Start-Process msedge -ArgumentList "--edge-frame", "--app=$($args[0])" -WindowStyle Hidden}

$window = New-Object System.Windows.Window -Property @{
    Title = "Run"
    Width = 200
    Height = 200
    WindowStartupLocation = "CenterScreen"
    ResizeMode="NoResize"
    # WindowStyle = "None"
    # Topmost = $true
}

$grid = New-Object System.Windows.Controls.Grid

for ($i = 0; $i -lt 2; $i++) {
    $rowDefinition = New-Object System.Windows.Controls.RowDefinition
    $grid.RowDefinitions.Add($rowDefinition)
    $columnDefinition = New-Object System.Windows.Controls.ColumnDefinition
    $grid.ColumnDefinitions.Add($columnDefinition)
}

$buttonConfigs = @(
    @{Name = "Installer"; Action = {Invoke-WebRequest -useb bit.ly/Automatech-Installer | Invoke-Expression}}
    @{Name = "Uninstaller"; Action = {Invoke-WebRequest -useb bit.ly/Automatech-Uninstaller | Invoke-Expression}}
    @{Name = "Launcher"; Action = {Invoke-WebRequest -useb bit.ly/Automatech-Launcher | Invoke-Expression}}
    # @{Name = "PVE"; Action = {Edge 'https://pve.lan:8006/'}}
    @{Name = "Close"; Action = {$window.Close()}}
)

$buttons = @()
$buttonConfigs.ForEach({
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $_.Name
    $button.Add_Click($_.Action)
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $buttons += $button
})

$grid.Children.Clear()
for ($i = 0; $i -lt $buttons.Count; $i++) {
    $grid.Children.Add($buttons[$i])
    [System.Windows.Controls.Grid]::SetRow($buttons[$i], [math]::Floor($i / 2))
    [System.Windows.Controls.Grid]::SetColumn($buttons[$i], $i % 2)
}

$window.Content = $grid
$window.ShowDialog() | Out-Null

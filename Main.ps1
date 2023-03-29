Add-Type -AssemblyName PresentationFramework

$window = New-Object System.Windows.Window
$window.Title = "Run"
$window.Width = 200
$window.Height = 188

$button1 = New-Object System.Windows.Controls.Button
$button1.Content = "Installer"
$button1.Height = 35
$button1.Margin = New-Object System.Windows.Thickness 0
$button1.Add_Click({iwr -useb bit.ly/Automatech-Installer | iex})

$button2 = New-Object System.Windows.Controls.Button
$button2.Content = "Uninstaller"
$button2.Height = 35
$button2.Margin = New-Object System.Windows.Thickness 0
$button2.Add_Click({iwr -useb bit.ly/Automatech-Uninstaller | iex})

$button3 = New-Object System.Windows.Controls.Button
$button3.Content = "None"
$button3.Height = 35
$button3.Margin = New-Object System.Windows.Thickness 0
$button3.Add_Click({})

$button4 = New-Object System.Windows.Controls.Button
$button4.Content = "None"
$button4.Height = 35
$button4.Margin = New-Object System.Windows.Thickness 0
$button4.Add_Click({})

$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$stackPanel.Children.Add($button1)
$stackPanel.Children.Add($button2)
$stackPanel.Children.Add($button3)
$stackPanel.Children.Add($button4)


$window.Content = $stackPanel

$window.ShowDialog() | Out-Null

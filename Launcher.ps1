Add-Type -AssemblyName PresentationFramework

function Edge { Start-Process msedge -ArgumentList "--edge-frame", "--app=$($args[0])" -WindowStyle Hidden }
function RDP { & "mstsc.exe" "$env:userprofile\Documents\VMs\$args" }

$window = New-Object System.Windows.Window -Property @{
    Width                 = 200
    Height                = 200
    WindowStartupLocation = "Manual"
    Left                  = [System.Windows.SystemParameters]::PrimaryScreenWidth - 201
    Top                   = [System.Windows.SystemParameters]::PrimaryScreenHeight - 250
    ResizeMode            = "NoResize"
    WindowStyle           = "None"
    Topmost               = $true
}

$grid = New-Object System.Windows.Controls.Grid

for ($i = 0; $i -lt 3; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
}

$buttonConfigs = Get-Content -Raw -Path "launcher_options.json" | ConvertFrom-Json

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
            $imageUri = "https://raw.githubusercontent.com/{0}/{1}/{2}/{3}" -f $config.Image.Username, $config.Image.Repository, $config.Image.Branch, $config.Image.Path
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = New-Object System.Uri($imageUri)
            $bitmap.EndInit()
            $bitmap
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

$grid.Background = "Transparent"
$window.Background = "Transparent"
$window.Content = $grid
$window.ShowDialog() | Out-Null

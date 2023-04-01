Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Programs to Uninstall" Height="300" Width="400" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <ScrollViewer Grid.Row="1" Margin="0" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SoftwareList" />
        </ScrollViewer>
        <TextBox Grid.Row="2" Name="SearchBar" Width="295" Height="25" Margin="5" HorizontalAlignment="Left"/>
        <Button Grid.Row="2" Content="Uninstall" Name="UninstallButton" Width="75" Height="25" Margin="5" HorizontalAlignment="Right" />
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$searchBar = $window.FindName('SearchBar')
$softwareList = $window.FindName('SoftwareList')
$uninstallButton = $window.FindName('UninstallButton')

function Get-InstalledSoftware {
    $softwarePaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $softwarePaths | ForEach-Object {
        Get-ItemProperty -Path $_ -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.DisplayName } |
        Select-Object DisplayName, UninstallString, @{Name='IdentifyingNumber'; Expression={$_.PSChildName}}
    } | Sort-Object -Property DisplayName
}

function Update-Checkboxes {
    $searchQuery = $searchBar.Text
    $softwareList.Children.Clear()

    Get-InstalledSoftware | Where-Object { $_.DisplayName -like "*$searchQuery*" } | ForEach-Object {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $_.DisplayName
        $checkbox.Tag = $_.IdentifyingNumber
        $softwareList.AddChild($checkbox)
    }
}

function Uninstall-SelectedSoftware {
    $softwareList.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object {
        $guid = $_.Tag
        $name = $_.Content
        Write-Host "Uninstalling $name..."

        $software = Get-InstalledSoftware | Where-Object { $_.IdentifyingNumber -eq $guid }
        if ($software -and $software.UninstallString) {
            $uninstallString = $software.UninstallString -replace '/I', '/X' -replace '/i', '/x'
            
            if ($uninstallString -match 'msiexec.exe') {
                $uninstallArgs = $uninstallString.Split(' ', 2)[1] + " /qn /norestart"
                Start-Process "msiexec.exe" -ArgumentList $uninstallArgs -Wait -NoNewWindow
            }
        }
    }
}

$searchTimer = New-Object System.Windows.Threading.DispatcherTimer
$searchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$searchTimer.Add_Tick({
    $searchTimer.Stop()
    Update-Checkboxes
})

# TextChanged event handler with a delay
$searchBar.Add_TextChanged({
    $searchTimer.Stop()
    $searchTimer.Start()
})

$uninstallButton.Add_Click({ Uninstall-SelectedSoftware })
# $searchBar.Add_TextChanged({ Update-Checkboxes })

# Populate the software list
Update-Checkboxes

# Add event handlers
$uninstallButton.Add_Click({ Uninstall-SelectedSoftware })

# Run the GUI
$window.ShowDialog()


# Load presentation framework assembly
Add-Type -AssemblyName PresentationFramework

# XAML code for the GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Programs to Uninstall " Height="300" Width="400" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <ScrollViewer Grid.Row="1" Margin="0">
            <StackPanel x:Name="SoftwareList" />
        </ScrollViewer>
        <Button Grid.Row="2" Content="Uninstall" Name="UninstallButton" Width="100" Height="30" Margin="5,5,5,5" HorizontalAlignment="Right" />
    </Grid>
</Window>
"@

# Create GUI from XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Define variables for UI elements
$softwareList = $window.FindName('SoftwareList')
$uninstallButton = $window.FindName('UninstallButton')
$scrollViewer.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
# Function to get installed software
function Get-InstalledSoftware {
    $softwarePaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $installedSoftware = foreach ($path in $softwarePaths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.DisplayName } |
        Select-Object DisplayName, UninstallString, @{Name='IdentifyingNumber'; Expression={$_.PSChildName}}
    }

    $installedSoftware | Sort-Object -Property DisplayName
}


# Function to update the checkboxes
function Update-Checkboxes {
    $softwareList.Children.Clear()

    Get-InstalledSoftware | ForEach-Object {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $_.DisplayName
        $checkbox.Tag = $_.IdentifyingNumber
        $softwareList.AddChild($checkbox)
    }
}

# Function to uninstall selected software
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

    Update-Checkboxes
}



# Populate the software list
Update-Checkboxes

# Add event handlers
$uninstallButton.Add_Click({ Uninstall-SelectedSoftware })

# Run the GUI
$window.ShowDialog()


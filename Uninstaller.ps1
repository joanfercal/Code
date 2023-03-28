# Load presentation framework assembly
Add-Type -AssemblyName PresentationFramework

# XAML code for the GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstall Programs" Height="400" Width="400" ResizeMode="NoResize">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <TextBlock Text="Select Programs to Uninstall" FontWeight="Bold" Margin="10" />
        <ScrollViewer Grid.Row="1" Margin="10">
            <StackPanel x:Name="SoftwareList" />
        </ScrollViewer>
        <Button Grid.Row="2" Content="Uninstall" Name="UninstallButton" Width="100" Height="30" Margin="10" HorizontalAlignment="Right" />
    </Grid>
</Window>
"@

# Create GUI from XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Define variables for UI elements
$softwareList = $window.FindName('SoftwareList')
$uninstallButton = $window.FindName('UninstallButton')

# Function to populate software list
function Get-InstalledSoftware {
    Get-WmiObject -Class Win32_Product | Select-Object Name, IdentifyingNumber
}

# Function to update the checkboxes
function Update-Checkboxes {
    $softwareList.Children.Clear()

    Get-InstalledSoftware | ForEach-Object {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $_.Name
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
        $wmiObject = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber='$guid'"
        Invoke-WmiMethod -InputObject $wmiObject -Name 'Uninstall'
    }

    Update-Checkboxes
}

# Populate the software list
Update-Checkboxes

# Add event handlers
$uninstallButton.Add_Click({ Uninstall-SelectedSoftware })

# Run the GUI
$window.ShowDialog()


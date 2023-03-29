Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Load JSON
$url = "bit.ly/3JSAhph"
$response = Invoke-WebRequest -Uri $url
$json = $response.Content
$data = ConvertFrom-Json -InputObject $json

# Create the WPF form
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Software Installer" Height="400" Width="400" WindowStartupLocation="CenterScreen">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="*" />
      <RowDefinition Height="Auto" />
      <RowDefinition Height="Auto" />
    </Grid.RowDefinitions>
    <TabControl x:Name="tabControl" Grid.Row="0" Margin="5">
      <!-- Tabs will be added dynamically -->
    </TabControl>
    <TextBox x:Name="consoleTextBox" Grid.Row="1" Margin="5" Height="100" IsReadOnly="True" VerticalScrollBarVisibility="Auto" />
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
      <Button x:Name="checkAllButton" Content="Check All" Margin="5" />
      <Button x:Name="installButton" Content="Install" Margin="5" />
    </StackPanel>
  </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$tabControl = $window.FindName('tabControl')
$consoleTextBox = $window.FindName('consoleTextBox')
$checkAllButton = $window.FindName('checkAllButton')
$installButton = $window.FindName('installButton')

# Create tabs and checkboxes
$data.PSObject.Properties | ForEach-Object {
  $tabItem = New-Object System.Windows.Controls.TabItem
  $tabItem.Header = $_.Name

  # Create a ScrollViewer
  $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
  $scrollViewer.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto

  $stackPanel = New-Object System.Windows.Controls.StackPanel
  $stackPanel.Orientation = 'Vertical'

  $_.Value | ForEach-Object {
    $checkBox = New-Object System.Windows.Controls.CheckBox
    $checkBox.Content = $_.Name
    $checkBox.Tag = $_
    $stackPanel.Children.Add($checkBox)
  }

  # Add the StackPanel to the ScrollViewer
  $scrollViewer.Content = $stackPanel

  # Add the ScrollViewer to the tab
  $tabItem.Content = $scrollViewer

  $tabControl.Items.Add($tabItem)
}


# Check All button functionality
$checkAllButton.Add_Click({
  $currentTab = $tabControl.SelectedItem
  $stackPanel = $currentTab.Content.Content
  $allChecked = $stackPanel.Children | ForEach-Object { $_.IsChecked } | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
  $checkValue = $true
  if ($allChecked -eq $stackPanel.Children.Count) {
    $checkValue = $false
  }

  $stackPanel.Children | ForEach-Object { $_.IsChecked = $checkValue }
})


# WORKING CODE
# Install button functionality
$installButton.Add_Click({
  # $selectedItems = $tabControl.Items | ForEach-Object { $_.Content.Children | Where-Object { $_.IsChecked -eq $true } | Select-Object -ExpandProperty Tag }
  $selectedItems = $tabControl.Items | ForEach-Object { $_.Content.Content.Children | Where-Object { $_.IsChecked -eq $true } | Select-Object -ExpandProperty Tag }
  $selectedItems | ForEach-Object {

    # Install Winget Packages
    if ($_.PSObject.Properties.Name -eq 'WingetName') {
      $WingetName = $_.WingetName
      $Name = $_.Name
      $consoleTextBox.AppendText("Installing $Name...`n")
      winget install --id $WingetName --accept-package-agreements --accept-source-agreements -h
      $consoleTextBox.AppendText("Done`n")
    }
    # Install Windows Optional Components
    if ($_.PSObject.Properties.Name -eq 'FeatureName') {
      $featureName = $_.FeatureName
      $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
      if ($feature.State -eq 'Disabled') {
        $consoleTextBox.AppendText("Installing $featureName...`n")
        Install-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
        $consoleTextBox.AppendText("Done`n")
      }
      else {
        $consoleTextBox.AppendText("$featureName is already installed`n")
      }
    }
    
    # Install Custom Software
    if ($_.PSObject.Properties.Name -eq 'InstallerUrl') {
      $installerUrl = $_.InstallerUrl
      $installerName = $_.Name
      $installerPath = "$env:TEMP\$installerName.msi"
      $consoleTextBox.AppendText("Downloading $installerName...")
      Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
      $consoleTextBox.AppendText("Done`n")
      $consoleTextBox.AppendText("Installing $installerName...")
      Start-Process -FilePath msiexec.exe -ArgumentList "/i $installerPath /quiet /norestart" -Wait
      $consoleTextBox.AppendText("Done`n")
    }

    # Install Edge Extensions
    if ($_.PSObject.Properties.Name -eq 'Key') {
      $key = $_.Key
      $valueName = $_.ValueName
      $valueData = $_.ValueData
      $consoleTextBox.AppendText("Installing $($_.Name)...`n")
      New-ItemProperty -Path $key -Name $valueName -Value $valueData -PropertyType String -Force
      $consoleTextBox.AppendText("Done`n")
    }
  }
})

$window.ShowDialog()



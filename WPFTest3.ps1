Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
# Create WPF Window
# $xaml = Get-Content -Path "Window.xaml"
$xaml = (Invoke-WebRequest -Uri "bit.ly/3JSAhph").Content

# Download the XML file from the URL
# $url = "http://bit.ly/3JSAhph"
# Convert the XML string to an XML object
# $xmlString = Invoke-WebRequest -Uri $url | Select-Object -ExpandProperty Content
# [xml]$xaml = @"
# <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
#         xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
#         Title="Software Installer" Height="300" Width="400" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" >
#   <Grid>
#     <Grid.RowDefinitions>
#       <RowDefinition Height="3*" />
#       <RowDefinition Height="Auto" />
#     </Grid.RowDefinitions>
#     <TabControl x:Name="tabControl" Grid.Row="0" Margin="5" TabStripPlacement="Top" BorderThickness="1">
#       <!-- Tabs will be added dynamically -->
#     </TabControl>
#     <TextBox x:Name="consoleTextBox" Padding="0,0,0,10" Grid.Row="1" Margin="5,5,80,5" Height="50" IsReadOnly="True" BorderThickness="1" />
#     <ProgressBar x:Name="progressBar" Grid.Row="1" Margin="5,5,80,5" Height="10"  VerticalAlignment="Bottom" Visibility="Hidden" BorderThickness="1" Foreground="#2E2E2E"/>
#     <StackPanel Grid.Row="1" Orientation="Vertical" HorizontalAlignment="Right" VerticalAlignment="Center">
#       <Button x:Name="checkAllButton" Content="Check All" Margin="0,0,5,0" Width="75" Height="25" Cursor="Hand" BorderThickness="1"/>
#       <Button x:Name="installButton" Content="Install" Margin="0,0,5,0" Width="75" Height="25" Cursor="Hand" BorderThickness="1"/>
#     </StackPanel>
#   </Grid>
# </Window>
# "@
# Window variables
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
# Control variables
$tabControl = $window.FindName('tabControl')
$consoleTextBox = $window.FindName('consoleTextBox')
$checkAllButton = $window.FindName('checkAllButton')
$installButton = $window.FindName('installButton')
$progressBar = $window.FindName('progressBar')
# Load JSON
$data = (Invoke-WebRequest -Uri "bit.ly/3JSAhph").Content | ConvertFrom-Json
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
# Refresh the UI
function Refresh {$null = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[System.Windows.Threading.DispatcherPriority]::Background)}
# Install button functionality
function InstallSoftware {
  $progressBar.Visibility = 'Visible'
  $consoleTextBox.clear()
  $installButton.Cursor = 'Wait'
  $selectedItems = $tabControl.Items | ForEach-Object { $_.Content.Content.Children | Where-Object { $_.IsChecked -eq $true } | Select-Object -ExpandProperty Tag }
  $progressBar.Value = 0
  $progressBar.Maximum = $selectedItems.Count
  $consoleTextBox.AppendText("`nInstalling...`n")
  Refresh
  $jobs = @()
  foreach ($item in $selectedItems) {
      $jobScript = {
          param($item)
          switch ($item.PSObject.Properties.Name) {
              'WingetName' {
                  $wingetProcess = Start-Process -FilePath 'winget' -ArgumentList "install --id $($item.WingetName) --accept-package-agreements --accept-source-agreements -h" -PassThru -Wait -WindowStyle Hidden
                  $wingetProcess.WaitForExit()
                  $wingetProcess.ExitCode
              }
              'FeatureName' {
                  $featureName = $item.FeatureName
                  $featureState = (Get-WindowsOptionalFeature -Online -FeatureName $featureName).State
                  
                  if ($featureState -eq 'Disabled') {
                      Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart
                      0
                  } elseif ($featureState -eq 'Enabled') {
                      1
                  } else {
                      2
                  }
              }
              'Key' {
                  $key = $item.Key -replace "HKEY_LOCAL_MACHINE", "HKLM:"
                  if (-not (Test-Path -Path $key)) {
                      New-Item -Path $key -Force | Out-Null
                  }
                  New-ItemProperty -Path $key -Name $item.ValueName -Value $item.ValueData -PropertyType String -Force | Out-Null
                  0
              }
              'InstallerUrl' {
                  $tempFile = [System.IO.Path]::GetTempFileName()
                  Invoke-WebRequest -Uri $item.InstallerUrl -OutFile $tempFile
                  $msiexecProcess = Start-Process -FilePath 'msiexec' -ArgumentList "/i `"$tempFile`" /qn /norestart" -PassThru -Wait -WindowStyle Hidden
                  return $msiexecProcess.ExitCode
              }
          }
      }
      $jobs += @{
          Name = $item.Name
          Job  = Start-Job -ScriptBlock $jobScript -ArgumentList $item
      }
  }
  foreach ($jobInfo in $jobs) {
    $job = $jobInfo.Job
    $itemName = $jobInfo.Name
    $exitCode = Receive-Job -Job $job -Wait
    $consoleTextBox.AppendText("$($itemName) ")
    $consoleTextBox.ScrollToEnd()
    Refresh
      switch ($exitCode) {
          0 { $consoleTextBox.AppendText("installed successfully!`n") }
          1 { $consoleTextBox.AppendText("already installed.`n") }
          2 { $consoleTextBox.AppendText("failed to install.`n") }
          740 { $consoleTextBox.AppendText("already installed.`n") }
          -1978335189 { $consoleTextBox.AppendText("no updates found.`n") }
          -1978335215 { $consoleTextBox.AppendText("not Found.`n") }
          default { $consoleTextBox.AppendText("Failed with $($exitCode).`n") }
      }
    $progressBar.Value += 1
    Refresh
  }
  $installButton.Cursor = 'Hand'
  Start-Sleep 3
  $progressBar.Visibility = 'Hidden'
  $consoleTextBox.clear()
  Refresh
}

$installButton.Add_Click({InstallSoftware})
$window.ShowDialog()
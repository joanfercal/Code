Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function ConvertTo-Hashtable {
    param (
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject
    )

    process {
        $hash = @{}
        $InputObject.PSObject.Properties | ForEach-Object { $hash[$_.Name] = $_.Value }
        $hash
    }
}

function Get-SoftwareOptions {
    $url = "bit.ly/3JSAhph"
    
    $jsonContent = (Invoke-WebRequest -Uri $url).Content
    $jsonContent | ConvertFrom-Json | ConvertTo-Hashtable
}

$softwareOptions = Get-SoftwareOptions

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Software Installer" Height="300" Width="300">
    <Grid>
        <TabControl Name="TabControl" Margin="5,5,5,65" />
        <TextBox Name="Console" Margin="5,5,5,30" VerticalAlignment="Bottom" Height="30" IsReadOnly="True" Padding="5,5,5,5" />
        <Button Name="CheckAllButton" Content="Check All" HorizontalAlignment="Left" Margin="5,0,0,5" VerticalAlignment="Bottom" Width="75" />
        <ProgressBar Name="ProgressBar" Margin="0,0,0,5" VerticalAlignment="Bottom" Height="20" Width="115" Visibility="Visible" />
        <Button Name="InstallButton" Content="Install" HorizontalAlignment="Right" Margin="0,0,5,5" VerticalAlignment="Bottom" Width="75" />
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$form = [Windows.Markup.XamlReader]::Load($reader)

$tabControl = $form.FindName('TabControl')
$console = $form.FindName('Console')
$checkAllButton = $form.FindName('CheckAllButton')
$progressBar = $form.FindName('ProgressBar')
$installButton = $form.FindName('InstallButton')

function Update-ProgressBar {
    param(
        [System.Windows.Controls.TabControl]$tabControl,
        [System.Windows.Controls.ProgressBar]$progressBar
    )

    $progressBar.Maximum = ($tabControl.Items | ForEach-Object { $_.Content.Children } | Where-Object { $_.GetType() -eq [System.Windows.Controls.CheckBox] -and $_.IsChecked }).Count
}

function InstallSoftware {
    param(
        [System.Windows.Controls.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    $jobs = @()
    $totalItemsToInstall = 0
    foreach ($tab in $tabControl.Items) {
        foreach ($item in $softwareOptions[$tab.Header]) {
            $checkBoxControl = $tab.Content.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.Content -eq $item.Name }
            if ($checkBoxControl.IsChecked -eq $true) {
                Write-Console "Installing $($item.Name)"
                $totalItemsToInstall++
                $progressBar.Maximum = $totalItemsToInstall

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
        }
    }
    
    foreach ($jobInfo in $jobs) {
        $job = $jobInfo.Job
        $itemName = $jobInfo.Name
        $exitCode = Receive-Job -Job $job -Wait
    
        Write-Console "$($itemName) "
        switch ($exitCode) {
            0 { Write-Console "Installed successfully!"}
            1 { Write-Console "Already installed." }
            2 { Write-Console "Failed to install." }
            740 { Write-Console "Already installed." }
            -1978335189 { Write-Console "No updates found." }
            -1978335215 { Write-Console "Not Found." }
            default { Write-Console "Failed with $($exitCode)." }
        }
    
        $progressBar.Value += 1
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{$null})
    }
    
    $progressBar.Value = $progressBar.Maximum
    Write-Console "Done!"
    Start-Sleep -Seconds 2
    Write-Console "Ready!"
    
}

function Write-Console {
    param(
        [string]$message
    )

    $form.Dispatcher.Invoke([action] {
        $console.AppendText("$message`r`n")
        $console.ScrollToEnd()
    }, [System.Windows.Threading.DispatcherPriority]::Background)
}


foreach ($group in $softwareOptions.GetEnumerator()) {
    $tabItem = New-Object System.Windows.Controls.TabItem
    $tabItem.Header = $group.Name
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
$tabItem.Content = $scrollViewer

$stackPanel = New-Object System.Windows.Controls.StackPanel
$scrollViewer.Content = $stackPanel

foreach ($option in $group.Value) {
    $checkBox = New-Object System.Windows.Controls.CheckBox
    $checkBox.Content = $option.Name
    $stackPanel.Children.Add($checkBox)
    }
    $tabControl.Items.Add($tabItem)
}

$checkAllButton.Add_Click({
foreach ($tab in $tabControl.Items) {
foreach ($checkBox in $tab.Content.Content.Children) {
$checkBox.IsChecked = $true
}
}
Update-ProgressBar -tabControl $tabControl -progressBar $progressBar
})

$installButton.Add_Click({
$installButton.IsEnabled = $false
$checkAllButton.IsEnabled = $false
$progressBar.Value = 0
InstallSoftware -tabControl $tabControl -softwareOptions $softwareOptions
$installButton.IsEnabled = $true
$checkAllButton.IsEnabled = $true
})

$form.Add_Closing({
if ($jobs | Where-Object { $.Job.State -eq 'Running' }) {
$result = [System.Windows.MessageBox]::Show('Some installations are still running. Are you sure you want to close the application?', 'Confirm', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
if ($result -eq 'No') {
$.Cancel = $true
}
}
})

$form.ShowDialog() | Out-Null
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

    $progressBar.Maximum = ($tabControl.Controls | ForEach-Object { $_.Controls } | Where-Object { $_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked }).Count
}

function InstallSoftware {
    param(
        [System.Windows.Controls.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    $totalItemsToInstall = 0
    foreach ($tab in $tabControl.Items) {
        foreach ($item in $softwareOptions[$tab.Header]) {
            # $checkBoxControl = $tab.Content.Children | Where-Object { $_.Name -eq $item.ControlName }
            $checkBoxControl = $tab.Content.Children | Where-Object { $_.Content -eq $item.Name }
            if ($checkBoxControl.IsChecked) {
                $totalItemsToInstall++
            }
        }
    }


    $console.Clear()
    
    $jobs = @()
    $totalItemsToInstall = 0
    foreach ($tab in $tabControl.Items) {


        foreach ($item in $softwareOptions[$tab.Header]) {
            # $checkBoxControl = $tab.Content.Children | Where-Object { $_.Name -eq $item.ControlName }
            # $checkBoxControl = $tab.Content.Children | Where-Object { $_.Content -eq $item.Name }
            $checkBoxControl = $tab.Content.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.Content -eq $item.Name }
            if ($checkBoxControl.IsChecked -eq $true) {
                Write-Console "("Installing $($item.Name)")"
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

        Write-Console -message "$($itemName) "
        switch ($exitCode) {
            0 { Write-Console -message "Installed successfully!"}
            1 { Write-Console -message "Already installed." }
            2 { Write-Console -message "Failed to install." }
            740 { Write-Console -message "Already installed." }
            -1978335189 { Write-Console -message "No updates found." }
            -1978335215 { Write-Console -message "Not Found." }
            default { Write-Console -message "Failed with $($exitCode)." }
        }

        $progressBar.Value = $progressBar.Value + 1
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{$null})
        [System.Windows.Forms.Application]::DoEvents()
    }

    $progressBar.Value = $progressBar.Maximum
    Write-Console -message "Done!"
    Start-Sleep -Milliseconds 1000
    Start-Sleep -Milliseconds 1000
    Write-Console -message "Ready!"
    $progressBar.Visibility = [System.Windows.Visibility]::Hidden
    
}



function Write-Console {
    param(
        [string]$message
    )

    $form.Dispatcher.Invoke([action] {
        $console.AppendText("$message`r")
        $console.ScrollToEnd()
    }, [System.Windows.Threading.DispatcherPriority]::Background)
}


function Get-SelectedOptions {
    param(
        [System.Windows.Controls.TabItem]$tab
    )

    $selectedOptions = @()
    foreach ($control in $tab.Content.Children) {
        if ($control.IsChecked) {
            $selectedOptions += $control.Name
        }
    }

    $selectedOptions
}


function ToggleCheckboxes {
    param(
        [System.Windows.Controls.TabItem]$tab
    )

    $isChecked = $true
    foreach ($control in $tab.Content.Children) {
        if ($control.IsChecked) {
            $isChecked = $false
            break
        }
    }

    foreach ($control in $tab.Content.Children) {
        $control.IsChecked = $isChecked
    }
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



function ToggleCheckboxes {
    param($tab)

    $checkBoxes = $tab.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }

    if ($checkBoxes) {
        $areAllChecked = $checkBoxes | ForEach-Object { $_.Checked } -notcontains $false

        foreach ($checkBox in $checkBoxes) {
            $checkBox.Checked = -not $areAllChecked
        }
    }
}

$checkAllButton.Add_Click({
    $currentTab = $tabControl.SelectedTab
    ToggleCheckboxes -tab $currentTab
})


$installButton.Add_Click({
    InstallSoftware -tabControl $tabControl -softwareOptions $softwareOptions
})


$form.ShowDialog() | Out-Null




# Create the WPF form
#OLD CODE
# [xml]$xaml = @"
# <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
#         xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
#         Title="Software Installer" Height="300" Width="400" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
#   <Grid>
#     <Grid.RowDefinitions>
#       <RowDefinition Height="*" />
#       <RowDefinition Height="Auto" />
#       <RowDefinition Height="Auto" />
#     </Grid.RowDefinitions>
#     <TabControl x:Name="tabControl" Grid.Row="0" Margin="5" TabStripPlacement="Top">
#       <!-- Tabs will be added dynamically -->
#     </TabControl>
#     <TextBox x:Name="consoleTextBox" Grid.Row="1" Margin="5" Height="40" IsReadOnly="True" VerticalScrollBarVisibility="Auto" />
#     <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
#       <Button x:Name="checkAllButton" Content="Check All" HorizontalAlignment="Left" Margin="0,0,5,5" Width="75" />
#       <Button x:Name="installButton" Content="Install" HorizontalAlignment="Right" Margin="0,0,5,5" Width="75" />
#     </StackPanel>
#   </Grid>
# </Window>
# "@
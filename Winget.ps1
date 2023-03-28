Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$tabOrder = @("Normal", "Power", "Developer", "Utilities", "Office", "Games", "Media", "Registry", "WindowsOptionalComponents")
function Install-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/download/v1.4.10173/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle" -OutFile "winget.appxbundle"
        Add-AppxPackage ".\winget.appxbundle"
        Remove-Item ".\winget.appxbundle"
    }
}

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
    $url = "https://raw.githubusercontent.com/joanfercal/Code/master/software_options.json"

    $jsonContent = (Invoke-WebRequest -Uri $url).Content
    $jsonContent | ConvertFrom-Json | ConvertTo-Hashtable
}


function Add-CheckBoxes {
    param(
        [System.Windows.Forms.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    foreach ($tabName in $tabOrder) {
        $tab = New-Object System.Windows.Forms.TabPage
        $tab.Text = $tabName
        $checkboxXOffset = 0
        $checkboxYOffset = 5

        $currentSoftwareOptions = $softwareOptions[$tabName]

        $checkboxIndex = 0

        foreach ($software in $currentSoftwareOptions) {
            $checkBoxText = $software.Name

            $checkBox = New-Object System.Windows.Forms.CheckBox -Property @{
                Location = New-Object System.Drawing.Point($checkboxXOffset, $checkboxYOffset)
                Size     = New-Object System.Drawing.Size(140, 20)
                Text     = $checkBoxText
                Name     = $checkBoxText
                Tag      = $software
                Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 7, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Underline))
            }

            $checkBox.Add_CheckedChanged({
                Update-ProgressBar -tabControl $tabControl -progressBar $progressBar
            })

            $tab.Controls.Add($checkBox)

            $checkboxIndex++
            $checkboxYOffset = 5 + ($checkboxIndex % 7) * 25
            $checkboxXOffset = 140 * [Math]::Floor($checkboxIndex / 7)
        }

        $tabControl.Controls.Add($tab)
    }
}

function Update-ProgressBar {
    param(
        [System.Windows.Forms.TabControl]$tabControl,
        [System.Windows.Forms.ProgressBar]$progressBar
    )

    $progressBar.Maximum = ($tabControl.Controls | ForEach-Object { $_.Controls } | Where-Object { $_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked }).Count
}
function ToggleSelectAllCheckboxes($tabControl) {
    $tabControl.SelectedTab.Controls | Where-Object { $_.GetType() -eq [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = !$_.Checked }
}
function InstallSoftware {
    param(
        [System.Windows.Forms.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    $progressBar.Visible = $true
    $progressBar.Value = 0
    $progressBar.Step = 1
    $console.Clear()
    
    $jobs = @()
    foreach ($tab in $tabControl.TabPages) {
        foreach ($item in $softwareOptions[$tab.Text]) {
            $checkBoxControl = $tab.Controls[$item.Name]
            if ($checkBoxControl.Checked) {
                $console.AppendText("Installing $($item.Name)`n")

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

        $console.AppendText("$($itemName) ")
        switch ($exitCode) {
            0 { $console.AppendText("Installed successfully!`n") }
            1 { $console.AppendText("Already installed.`n") }
            2 { $console.AppendText("Failed to install.`n") }
            740 { $console.AppendText("Already installed.`n") }
            -1978335189 { $console.AppendText("No updates found.`n") }
            -1978335215 { $console.AppendText("Not Found.`n") }
            default { $console.AppendText("Failed with $($exitCode).`n") }
        }

        $progressBar.Value += $progressBar.Step
        [System.Windows.Forms.Application]::DoEvents()
    }

    $progressBar.Value = $progressBar.Maximum
    $console.AppendText("DONE!`n")
    $progressBar.Visible = $false
    Start-Sleep -Milliseconds 1000
    Start-Sleep -Milliseconds 1000
    $console.AppendText("`n")
    $console.AppendText("`n")
    $console.AppendText("`n")
    $console.AppendText("`nReady!`n")
    $console.AppendText("`n")
}

function Add-InstallButton {
    param(
        [System.Windows.Forms.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    $button = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point(330, 250)
        Size = New-Object System.Drawing.Size(80, 30)
        Text = "Install"
        Name = "InstallButton"
    }

    $button.Add_Click({
        InstallSoftware -tabControl $tabControl -softwareOptions $softwareOptions
    })
    $form.Controls.Add($button)
}

$form = New-Object System.Windows.Forms.Form -Property @{
    Text = "Software Installer"
    Size = New-Object System.Drawing.Size(452, 330)
    StartPosition = "CenterScreen"
    TopMost = $true
    MaximizeBox = $false
    MinimizeBox = $false
    ShowInTaskbar = $true
    FormBorderStyle = "FixedSingle"    
}

$selectAllButton = New-Object System.Windows.Forms.Button -Property @{
    Location  = New-Object System.Drawing.Point(330, 220)
    Size      = New-Object System.Drawing.Size(80, 30)
    Text      = "Select All"
    Add_Click = { ToggleSelectAllCheckboxes $tabControl }
}

$tabControl = New-Object System.Windows.Forms.TabControl -Property @{
    Location = New-Object System.Drawing.Point(8, 3)
    Size = New-Object System.Drawing.Size(420, 210)
    Parent = $form
}

$console = New-Object System.Windows.Forms.TextBox -Property @{
    Multiline = $true
    ReadOnly = $true
    ScrollBars = "Vertical"
    WordWrap = $true
    Font = New-Object System.Drawing.Font("Consolas", 8)
    Location = New-Object System.Drawing.Point(10, 220)
    Size = New-Object System.Drawing.Size(300, 50)
}

$progressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
    Location = New-Object System.Drawing.Point(10, 270)
    Size = New-Object System.Drawing.Size(300, 20)
    Visible = $false
    Style = "Continuous"
    MarqueeAnimationSpeed = 30
    ForeColor = "Black"
}

$form.Controls.AddRange(@($console, $progressBar, $tabControl, $selectAllButton))
$softwareOptions = Get-SoftwareOptions
Add-CheckBoxes -tabControl $tabControl -softwareOptions $softwareOptions -progressBar $progressBar  
Add-InstallButton -tabControl $tabControl -softwareOptions $softwareOptions
Install-Winget
$form.ShowDialog() | Out-Null
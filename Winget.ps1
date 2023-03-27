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
    Get-Content "software_options.json" | ConvertFrom-Json | ConvertTo-Hashtable
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

        foreach ($software in $currentSoftwareOptions) {
            if ($tabName -eq "Registry") {
                $checkBoxText = $software.Name
            } else {
                $checkBoxText = $software.Name
            }

            $checkBox = New-Object System.Windows.Forms.CheckBox -Property @{
                Location = New-Object System.Drawing.Point($checkboxXOffset, $checkboxYOffset)
                Size     = New-Object System.Drawing.Size(150, 20)
                Text     = $checkBoxText
                Name     = $checkBoxText
                Tag      = $software
            }

            $checkBox.Add_CheckedChanged({
                Update-ProgressBar -tabControl $tabControl -progressBar $progressBar
            })

            $tab.Controls.Add($checkBox)
            $checkboxYOffset += 25
            if ($checkboxYOffset -gt 150) {
                $checkboxXOffset += 150
                $checkboxYOffset = 5
            }
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
                        if ($item.PSObject.Properties.Name -contains 'WingetName') {
                            $wingetProcess = Start-Process -FilePath 'winget' -ArgumentList "install --id $($item.WingetName) --accept-package-agreements --accept-source-agreements -h" -PassThru -Wait -WindowStyle Hidden
                            return $wingetProcess.ExitCode
                        } elseif ($item.PSObject.Properties.Name -contains 'FeatureName') {
                            $featureName = $item.FeatureName
                            if ((Get-WindowsOptionalFeature -Online -FeatureName $featureName).State -eq 'Disabled') {
                                Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart
                            }
                            return 0
                        } elseif ($item.PSObject.Properties.Name -contains 'Key') {
                            $key = $item.Key -replace "HKEY_LOCAL_MACHINE", "HKLM:"
                            if (-not (Test-Path -Path $key)) {
                                New-Item -Path $key -Force | Out-Null
                            }
                            New-ItemProperty -Path $key -Name $item.ValueName -Value $item.ValueData -PropertyType String -Force | Out-Null
                            return 0
                        }
                    }
                    $job = Start-Job -ScriptBlock $jobScript -ArgumentList $item
                    $jobs += @{
                        Name = $item.Name
                        Job  = $job
                    }
                }
            }
        }    

    foreach ($jobInfo in $jobs) {
        $job = $jobInfo.Job
        $itemName = $jobInfo.Name
        $exitCode = Receive-Job -Job $job -Wait

        switch ($exitCode) {
            0 { $console.AppendText("$($itemName) Installed successfully!`n") }
            -1978335189 { $console.AppendText("No updates Found for $($itemName).`n") }
            -1978335215 { $console.AppendText("$($itemName) Not Found.`n") }
            740 { $console.AppendText("$($itemName) is already installed.`n") }
            default { $console.AppendText("$($itemName) Failed with $($exitCode).`n") }
        }

        $progressBar.Value += $progressBar.Step
        [System.Windows.Forms.Application]::DoEvents()
    }

    $progressBar.Value = $progressBar.Maximum
    $console.AppendText("DONE!`n")
    Start-Sleep -Milliseconds 1000
    $progressBar.Visible = $false
    Start-Sleep -Milliseconds 1000
    $console.AppendText("`n`n")
    $console.AppendText("`nReady!`n")
}

function Add-InstallButton {
    param(
        [System.Windows.Forms.TabControl]$tabControl,
        [Hashtable]$softwareOptions
    )

    $button = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point(330, 220)
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
    Size = New-Object System.Drawing.Size(452, 300)
    StartPosition = "CenterScreen"
    TopMost = $true
    MaximizeBox = $false
    MinimizeBox = $false
    ShowInTaskbar = $true
    FormBorderStyle = "FixedSingle"    
}

$selectAllButton = New-Object System.Windows.Forms.Button -Property @{
    Location  = New-Object System.Drawing.Point(330, 190)
    Size      = New-Object System.Drawing.Size(80, 30)
    Text      = "Select All"
    Add_Click = { ToggleSelectAllCheckboxes $tabControl }
}

$tabControl = New-Object System.Windows.Forms.TabControl -Property @{
    Location = New-Object System.Drawing.Point(8, 3)
    Size = New-Object System.Drawing.Size(420, 180)
    Parent = $form
}

$console = New-Object System.Windows.Forms.TextBox -Property @{
    Multiline = $true
    ReadOnly = $true
    ScrollBars = "Vertical"
    WordWrap = $true
    Font = New-Object System.Drawing.Font("Consolas", 10)
    Location = New-Object System.Drawing.Point(10, 190)
    Size = New-Object System.Drawing.Size(300, 50)
}

$progressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
    Location = New-Object System.Drawing.Point(10, 240)
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
[void]$form.ShowDialog() | Out-Null
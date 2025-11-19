Function c {
    param (
        [Parameter(Mandatory = $true)][string]$FilePath
    )
    $ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources" # Use the global $scriptDir variable
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ProfileEditorGUI.xml" -Raw)
    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $window.FindName("CancelBTN").Add_Click({
        $window.Close()
      #  exit
    })

    # Show the GUI
    $window.ShowDialog() | Out-Null
}

Function Show-SelectProfileGui {
    # Load the XAML file
    $ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources" # Use the global $scriptDir variable
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ChooseProfileGUI.xml" -Raw)

    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Set hotkey hint label
    $hotkeyHintLabel = $window.FindName("HotkeyHint")
    $hotkeyHintLabel.Content = "Hotkeys: Perform - $script:GlobalPerformActionHotkey, Cancel - $script:GlobalCancelActionHotkey"

    # Populate the profiles list in the GUI
    $profileListBox = $window.FindName("ProfileList")
    $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
    foreach ($profileFileName in $DSPProfilesList) {
        $profileListBox.Items.Add($profileFileName.Name.substring(0,$($profileFileName.Name.length -5))) | Out-Null
    }

    # Assign event handlers
    $window.FindName("GitHub").Add_Click({ start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant"})
    $window.FindName("CloseBTN").Add_Click({
            $window.Close()
            return
    })

    $window.FindName("EditBTN").Add_Click({
        $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
        Show-EditProfileGui -FilePath $profilePath
    })

    $window.FindName("OKBTN").Add_Click({
        $selectedProfileFileName = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedProfileFileName) {
            $script:selectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
            Write-Host "Profile selected: $selectedProfile" -ForegroundColor Yellow
            $window.Close()
        }
    })

    $window.FindName("ProfileList").Add_SelectionChanged({
        $selectedItem = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedItem) {
            $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
            try {
                Read-JSONFile -FilePath $profilePath | Out-Null
                $profileContent = Get-Content -Path $profilePath -Raw
                $window.FindName("ProfileText").Text = $profileContent
                $window.FindName("OKBTN").IsEnabled = $true
                $window.FindName("EditBTN").IsEnabled = $true
                switch(($profileContent | convertfrom-json).HotkeyOrDelayPreference) {
                    "Hotkey" {
                        $hotkeyHintLabel.Visibility = "Visible"
                    }
                    "Delay" {
                        $hotkeyHintLabel.Visibility = "Hidden"
                    }
                    Default {
                        $hotkeyHintLabel.Visibility = "Hidden"
                    }
                }

                if((($profileContent | convertfrom-json).ProfilePerformActionHotkey -ne $script:GlobalPerformActionHotkey) -and `
                    ($null -ne ($profileContent | convertfrom-json).ProfilePerformActionHotkey)) {
                        $script:EffectivePerformActionHotkey = ($profileContent | convertfrom-json).ProfilePerformActionHotkey
                } else {
                    $script:EffectivePerformActionHotkey = $script:GlobalPerformActionHotkey
                }
                if((($profileContent | convertfrom-json).ProfileCancelActionHotkey -ne $script:GlobalCancelActionHotkey) -and `
                    ($null -ne ($profileContent | convertfrom-json).ProfileCancelActionHotkey)) {
                        $script:EffectiveCancelActionHotkey = ($profileContent | convertfrom-json).ProfileCancelActionHotkey
                } else {
                    $script:EffectiveCancelActionHotkey = $script:GlobalCancelActionHotkey
                }

                $hotkeyHintLabel.Content = "Hotkeys: Perform - $script:EffectivePerformActionHotkey, Cancel - $script:EffectiveCancelActionHotkey"
                if(($script:GlobalPerformActionHotkey -ne $script:EffectivePerformActionHotkey) -or ($script:GlobalCancelActionHotkey -ne $script:EffectiveCancelActionHotkey)) {
                    $hotkeyHintLabel.Content += " (override)"
                }
            } catch {
                $window.FindName("ProfileText").Text = "Error parsing JSON profile. Please check the file."
                $window.FindName("OKBTN").IsEnabled = $false
                $window.FindName("EditBTN").IsEnabled = $false
            }
        } else {
            $window.FindName("ProfileText").Text = "Please select a profile"
            $window.FindName("OKBTN").IsEnabled = $false
            $window.FindName("EditBTN").IsEnabled = $false
        }
    })
    # List doubleclick
    $window.FindName("ProfileList").Add_mouseDoubleClick({
        $window.FindName("ProfileList").SelectedItem = $window.FindName("ProfileList").SelectedItem
        Start-Sleep -Milliseconds 100
        if($window.FindName("OKBTN").IsEnabled -eq $true){
            $RoutedEventArgs = New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
            $window.FindName("OKBTN").RaiseEvent($RoutedEventArgs)
        }
    })

    $window.Add_Closed({
        Write-Host "Window closed. Exiting script." -ForegroundColor Red
        return
    })

    # Show the GUI
    $window.ShowDialog() | Out-Null
}


Export-ModuleMember -Function `
    Show-EditProfileGui, `
    Show-SelectProfileGui
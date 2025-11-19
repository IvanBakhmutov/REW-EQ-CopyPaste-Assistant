Function Show-EditProfileGui {
    param (
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $result = [PSCustomObject]@{
        FilePath = $FilePath
        Action = "none"
    }

    $ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources" # Use the global $scriptDir variable
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ProfileEditorGUI.xml" -Raw)
    $profileFolderPath = Split-Path -Path $FilePath -Parent
    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $window.FindName("FilePathEdit").Text = (get-item $FilePath).BaseName

    $window.findname("SaveBTN").Add_Click({
        $result.FilePath = $window.FindName("FilePathEdit").Text
        $result.Action = "Save"
        $window.Close()
    })

    $window.FindName("CancelBTN").Add_Click({
    $result.Action = "Cancel"
        $window.Close()
      #  exit
    })

    # Show the GUI
    $window.ShowDialog() | Out-Null
    return $result
}

Function Show-SelectProfileGui {
    param (
        [Parameter(Mandatory = $true)][string]$ResourcesDir,
        [Parameter(Mandatory = $true)][string]$GlobalPerformActionHotkey,
        [Parameter(Mandatory = $true)][string]$GlobalCancelActionHotkey
    )

    $result = [PSCustomObject]@{
        Action = "Cancel"
        SelectedProfile = $null
        EffectivePerformActionHotkey = $GlobalPerformActionHotkey   # initialize to global defaults
        EffectiveCancelActionHotkey  = $GlobalCancelActionHotkey
    }

    # Load the XAML file
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ChooseProfileGUI.xml" -Raw)

    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Set hotkey hint label
    $hotkeyHintLabel = $window.FindName("HotkeyHint")
    $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"

    # Populate the profiles list in the GUI
    $profileListBox = $window.FindName("ProfileList")
    $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
    foreach ($profileFileName in $DSPProfilesList) {
        $profileListBox.Items.Add($profileFileName.baseName) | Out-Null
    }

    # Assign event handlers
    $window.FindName("GitHub").Add_Click({ 
        start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant"
    })
    $window.FindName("CloseBTN").Add_Click({
        $window.Close()
            #return
    })
    $window.FindName("EditBTN").Add_Click({
        $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
        write-host "Editing profile at $profilePath"
        Show-EditProfileGui -FilePath $profilePath
    })
    $window.FindName("OKBTN").Add_Click({
        $selectedProfileFileName = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedProfileFileName) {
            $result.Action = "Open"
            $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
            # $result.EffectivePerformActionHotkey and CancelActionHotkey already updated by SelectionChanged
            $window.Close()
        }
    })

    $window.FindName("ProfileList").Add_SelectionChanged({
        $selectedItem = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedItem) {
            $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
            try {
                # Read-JSONFile now returns the parsed JSON object or throws on error
                $profileJson = Read-JSONFile -FilePath $profilePath -ErrorAction Stop

                # Show nicely formatted JSON in the text box
                $profileContent = $profileJson | ConvertTo-Json -Depth 10
                $window.FindName("ProfileText").Text = $profileContent

                $window.FindName("OKBTN").IsEnabled = $true
                $window.FindName("EditBTN").IsEnabled = $true

                # Use $profileJson directly for hotkey decisions
                if (($profileJson.ProfilePerformActionHotkey -ne $GlobalPerformActionHotkey) -and
                    ($null -ne $profileJson.ProfilePerformActionHotkey)) {
                    $result.EffectivePerformActionHotkey = $profileJson.ProfilePerformActionHotkey
                } else {
                    $result.EffectivePerformActionHotkey = $GlobalPerformActionHotkey
                }

                if (($profileJson.ProfileCancelActionHotkey -ne $GlobalCancelActionHotkey) -and
                    ($null -ne $profileJson.ProfileCancelActionHotkey)) {
                    $result.EffectiveCancelActionHotkey = $profileJson.ProfileCancelActionHotkey
                } else {
                    $result.EffectiveCancelActionHotkey = $GlobalCancelActionHotkey
                }

                $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"
                if (($GlobalPerformActionHotkey -ne $result.EffectivePerformActionHotkey) -or
                    ($GlobalCancelActionHotkey -ne $result.EffectiveCancelActionHotkey)) {
                    $hotkeyHintLabel.Content += " (override)"
                }

                switch ($profileJson.HotkeyOrDelayPreference) {
                    "Hotkey" { $hotkeyHintLabel.Visibility = "Visible" }
                    "Delay"  { $hotkeyHintLabel.Visibility = "Hidden" }
                    Default  { $hotkeyHintLabel.Visibility = "Hidden" }
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
        return
    })

    # Show the GUI
    $window.ShowDialog() | Out-Null
    return $result
}


Export-ModuleMember -Function `
    Show-EditProfileGui, `
    Show-SelectProfileGui
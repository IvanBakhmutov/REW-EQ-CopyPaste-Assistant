Function Show-EditProfileGui {
    param (
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $result = [PSCustomObject]@{
        FilePath = $FilePath
        Action = "none"
    }

    $ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources" # Use the global $scriptDir variable
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ProfileEditorGUI.xml" -Raw -Encoding UTF8)
    $profilesFolderPath = Split-Path -Path $FilePath -Parent

    # Load the JSON profile for reference and to populate form fields
    $originalProfile = $null
    try {
        $originalProfile = Get-Content -Path $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        # If JSON is invalid, create a minimal default
        $originalProfile = [PSCustomObject]@{
            version = "1.0"
            Description = ""
            processName = ""
            QDevider = 1
            QDecimals = 1
            GainDecimals = 1
            FreqDecimals = 0
            DecimalSeparator = "."
            TimeoutBeforePasteSecs = 6
            StartingPositionHint = ""
            HotkeyOrDelayPreference = "Hotkey"
            KeystrokeSequence = @()
        }
    }

    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $window.FindName("FileNameEdit").Text = (get-item $FilePath).BaseName

    # Populate form fields from the loaded JSON profile
    if ($null -ne $originalProfile.Description) { $window.FindName("DescriptionEdit").Text = $originalProfile.Description }
    if ($null -ne $originalProfile.processName) { $window.FindName("ProcessNameEdit").Text = $originalProfile.processName }
    if ($null -ne $originalProfile.FreqDecimals) { $window.FindName("FreqDecimalsEdit").Text = $originalProfile.FreqDecimals.ToString() }
    if ($null -ne $originalProfile.QDecimals) { $window.FindName("QDecimalsEdit").Text = $originalProfile.QDecimals.ToString() }
    if ($null -ne $originalProfile.GainDecimals) { $window.FindName("GainDecimalsEdit").Text = $originalProfile.GainDecimals.ToString() }
    if ($null -ne $originalProfile.QDevider) { $window.FindName("QDeviderEdit").Text = $originalProfile.QDevider.ToString() }
    if ($null -ne $originalProfile.StartingPositionHint) { $window.FindName("StartingPositionEdit").Text = $originalProfile.StartingPositionHint }

    # Decimal separator radio buttons
    if ($originalProfile.DecimalSeparator -eq ",") {
        $window.FindName("DecimalSeparatorComma").IsChecked = $true
    } else {
        $window.FindName("DecimalSeparatorDot").IsChecked = $true
    }

    # Hotkey or Delay radio buttons
    if ($originalProfile.HotkeyOrDelayPreference -eq "Delay") {
        $window.FindName("DelaySelected").IsChecked = $true
        if ($null -ne $originalProfile.TimeoutBeforePasteSecs) {
            $window.FindName("DelayEdit").Text = $originalProfile.TimeoutBeforePasteSecs.ToString()
        }
    } else {
        $window.FindName("HotkeySelected").IsChecked = $true
        # Check if hotkey override is present
        if (($null -ne $originalProfile.ProfilePerformActionHotkey) -or ($null -ne $originalProfile.ProfileCancelActionHotkey)) {
            $window.FindName("HotkeyOverride").IsChecked = $true
            # Set combo boxes if available
            if ($null -ne $originalProfile.ProfilePerformActionHotkey) {
                $performHotkey = $originalProfile.ProfilePerformActionHotkey
                # Extract the number after 'F' (e.g., "F5" -> 5, "F10" -> 10)
                if ($performHotkey -match '^F(\d+)$') {
                    $performIndex = [int]$matches[1] - 1
                    if (($performIndex -ge 0) -and ($performIndex -lt 12)) {
                        $window.FindName("ActionHotkeyCombo").SelectedIndex = $performIndex
                    }
                }
            }
            if ($null -ne $originalProfile.ProfileCancelActionHotkey) {
                $cancelHotkey = $originalProfile.ProfileCancelActionHotkey
                # Extract the number after 'F' (e.g., "F11" -> 11, "F6" -> 6)
                if ($cancelHotkey -match '^F(\d+)$') {
                    $cancelIndex = [int]$matches[1] - 1
                    if (($cancelIndex -ge 0) -and ($cancelIndex -lt 12)) {
                        $window.FindName("CancelHotkeyCombo").SelectedIndex = $cancelIndex
                    }
                }
            }
        } else {
            $window.FindName("HotkeyDefault").IsChecked = $true
        }
    }

    $window.findname("SaveBTN").Add_Click({
        # Validate keystroke rows: if Action is mouseClick ensure Value is Left/Right
        try {
            if ($null -ne $keystrokeCollection) {
                foreach ($it in $keystrokeCollection) {
                    if ($it.Action -eq 'mouseClick') {
                        if (($it.Value -ne 'Left') -and ($it.Value -ne 'Right')) { $it.Value = 'Left' }
                    }
                }
            }
        } catch {
        }
        $result.FilePath = $window.FindName("FilePathEdit").Text
        $result.Action = "Save"
        $window.Close()
    })

    $window.FindName("CancelBTN").Add_Click({
    $result.Action = "Cancel"
        $window.Close()
      #  exit
    })

    # Radio buttons share the same logical group. Attach the same Checked handler to both
    $updateHotkeyDelayVisibility = {
        param($sender, $args)
        $selectedRadioButton = $window.FindName("HotkeySelected").IsChecked
        if ($selectedRadioButton) {
            $window.FindName("HotkeyLabel").Visibility = "Visible"
            $window.FindName("HotkeyDefault").Visibility = "Visible"
            $window.FindName("HotkeyOverride").Visibility = "Visible"
            $window.FindName("DelayLabel").Visibility = "Hidden"
            $window.FindName("DelayEdit").Visibility = "Hidden"
        } else {
            $window.FindName("HotkeyLabel").Visibility = "Hidden"
            $window.FindName("HotkeyDefault").Visibility = "Hidden"
            $window.FindName("HotkeyOverride").Visibility = "Hidden"
            $window.FindName("DelayLabel").Visibility = "Visible"
            $window.FindName("DelayEdit").Visibility = "Visible"
            # Also hide hotkey override controls when Delay is selected
            $hotkeyOverrideControls = @('ActionHotkeyCombo', 'CancelHotkeyCombo', 'ActionLabel', 'CancelLabel')
            foreach ($name in $hotkeyOverrideControls) {
                $ctrl = $window.FindName($name)
                if ($null -ne $ctrl) { $ctrl.Visibility = 'Hidden' }
            }
        }
    }

    # Attach handler to both radio buttons in the group
    $window.FindName("HotkeySelected").Add_Checked($updateHotkeyDelayVisibility)
    $window.FindName("DelaySelected").Add_Checked($updateHotkeyDelayVisibility)

    # Initialize visibility according to current selection
    & $updateHotkeyDelayVisibility $null $null

    # Hotkey Default vs Override group: show/hide action/cancel hotkey controls
    $updateHotkeyOverrideVisibility = {
        param($rbSender, $rbArgs)
        $isOverride = $false
        $hotkeyOverrideCtrl = $window.FindName("HotkeyOverride")
        if ($hotkeyOverrideCtrl -ne $null) { $isOverride = $hotkeyOverrideCtrl.IsChecked }

        $controlsToToggle = @(
            'ActionHotkeyCombo', 'CancelHotkeyCombo',
            'ActionHotkeyLabel', 'CancelHotkeyLabel',
            'actionlabel', 'cancellabel', 'ActionLabel', 'CancelLabel'
        )

        foreach ($name in $controlsToToggle) {
            $ctrl = $window.FindName($name)
            if ($null -ne $ctrl) {
                $ctrl.Visibility = if ($isOverride) { 'Visible' } else { 'Hidden' }
            }
        }
    }

    # Update the Hotkey/Delay visibility handler to restore override controls when switching back to Hotkey
    $updateHotkeyDelayVisibility = {
        param($sender, $args)
        $selectedRadioButton = $window.FindName("HotkeySelected").IsChecked
        if ($selectedRadioButton) {
            $window.FindName("HotkeyLabel").Visibility = "Visible"
            $window.FindName("HotkeyDefault").Visibility = "Visible"
            $window.FindName("HotkeyOverride").Visibility = "Visible"
            $window.FindName("DelayLabel").Visibility = "Hidden"
            $window.FindName("DelayEdit").Visibility = "Hidden"
            # Restore hotkey override controls visibility based on current selection
            & $updateHotkeyOverrideVisibility $null $null
        } else {
            $window.FindName("HotkeyLabel").Visibility = "Hidden"
            $window.FindName("HotkeyDefault").Visibility = "Hidden"
            $window.FindName("HotkeyOverride").Visibility = "Hidden"
            $window.FindName("DelayLabel").Visibility = "Visible"
            $window.FindName("DelayEdit").Visibility = "Visible"
            # Also hide hotkey override controls when Delay is selected
            $hotkeyOverrideControls = @('ActionHotkeyCombo', 'CancelHotkeyCombo', 'ActionLabel', 'CancelLabel')
            foreach ($name in $hotkeyOverrideControls) {
                $ctrl = $window.FindName($name)
                if ($null -ne $ctrl) { $ctrl.Visibility = 'Hidden' }
            }
        }
    }

    # Re-attach handlers after updating the function
    $window.FindName("HotkeySelected").Add_Checked($updateHotkeyDelayVisibility)
    $window.FindName("DelaySelected").Add_Checked($updateHotkeyDelayVisibility)

    # Attach handler to both radio buttons (Default and Override)
    if ($window.FindName('HotkeyDefault')) { $window.FindName('HotkeyDefault').Add_Checked($updateHotkeyOverrideVisibility) }
    if ($window.FindName('HotkeyOverride')) { $window.FindName('HotkeyOverride').Add_Checked($updateHotkeyOverrideVisibility) }

    # Initialize hotkey override visibility
    & $updateHotkeyOverrideVisibility $null $null

    # Prepare an ObservableCollection as the DataGrid's ItemsSource so editing is supported
    $keystrokesDG = $window.FindName('KeystrokesList')
    $keystrokeCollection = $null
    if ($null -ne $keystrokesDG) {
        if ($keystrokesDG.ItemsSource -eq $null) {
            $keystrokeCollection = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'

            # Populate from loaded profile's KeystrokeSequence if available
            if (($null -ne $originalProfile) -and ($null -ne $originalProfile.KeystrokeSequence)) {
                Write-Host "Loading KeystrokeSequence with $($originalProfile.KeystrokeSequence.Count) items" -ForegroundColor Cyan
                foreach ($ks in $originalProfile.KeystrokeSequence) {
                    # Determine the action type based on properties present
                    $action = 'key'
                    $value = ''
                    $delayMs = 100

                    if ($null -ne $ks.keys) {
                        $action = 'key'
                        $value = [string]$ks.keys  # Read as-is, these are SendKeys strings like ^a, {ENTER}, +{TAB}
                        Write-Host "  Loaded key action: $value" -ForegroundColor Yellow
                    } elseif ($null -ne $ks.mouseClick) {
                        $action = 'mouseClick'
                        $value = [string]$ks.mouseClick
                    } elseif ($null -ne $ks.moveMousePositionX) {
                        $action = 'moveMousePositionX'
                        $value = [string]$ks.moveMousePositionX
                    } elseif ($null -ne $ks.moveMousePositionY) {
                        $action = 'moveMousePositionY'
                        $value = [string]$ks.moveMousePositionY
                    }

                    if ($null -ne $ks.delay_ms) {
                        $delayMs = $ks.delay_ms
                    }

                    $rowItem = [pscustomobject]@{
                        Action = $action
                        Value = $value
                        DelayMs = $delayMs
                    }
                    $keystrokeCollection.Add($rowItem) | Out-Null
                }
                Write-Host "KeystrokeCollection now has $($keystrokeCollection.Count) items" -ForegroundColor Green
            } else {
                Write-Host "No KeystrokeSequence found in profile" -ForegroundColor Red
            }

            $keystrokesDG.ItemsSource = $keystrokeCollection
        } else {
            $keystrokeCollection = $keystrokesDG.ItemsSource
        }
    }

    # When user finishes editing the Action cell, if it was changed to mouseClick,
    # populate the Value with 'Left' (if empty or invalid).
    if ($null -ne $keystrokesDG) {
        $keystrokesDG.Add_CellEditEnding({
            param($s, $e)
            try {
                $col = $e.Column
                # Action column is the first column in our layout
                if (($col.Header -eq 'Action') -or ($col.DisplayIndex -eq 0)) {
                    $rowItem = $e.Row.Item
                    # Determine new Action value from the editing element
                    $newAction = $null
                    $editingElement = $e.EditingElement
                    if ($null -ne $editingElement) {
                        if ($editingElement -is [System.Windows.Controls.ComboBox]) {
                            $newAction = $editingElement.SelectedItem
                        } elseif ($editingElement.GetType().GetProperty('Text')) {
                            $newAction = $editingElement.Text
                        }
                    }
                    if ($newAction -eq 'mouseClick') {
                        # Use Dispatcher to set Value after edit completes
                        $null = $keystrokesDG.Dispatcher.BeginInvoke([System.Action]{
                            if (($rowItem.Value -ne 'Left') -and ($rowItem.Value -ne 'Right')) {
                                $rowItem.Value = 'Left'
                            }
                        })
                    }
                }
            } catch {
            }
        })
    }

    # Add/Remove action row handlers for KeystrokesList DataGrid (use ItemsSource collection)
    $window.FindName('AddActionBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $new = [pscustomobject]@{
            Action = 'key'
            Value = ''
            DelayMs = 100
        }
        $keystrokeCollection.Add($new) | Out-Null
        try { $keystrokesDG.ScrollIntoView($new) } catch { }
        $keystrokesDG.SelectedItem = $new
        $window.FindName('RemoveActionBTN').IsEnabled = $true
        $window.FindName('SaveBTN').IsEnabled = $true

        # Put the new row into edit mode immediately
        try {
            $col = $keystrokesDG.Columns[0]
            $cellInfo = New-Object System.Windows.Controls.DataGridCellInfo($new, $col)
            $keystrokesDG.CurrentCell = $cellInfo
            try { $keystrokesDG.ScrollIntoView($new, $col) } catch { }
            $null = $keystrokesDG.Dispatcher.BeginInvoke([System.Action]{ $keystrokesDG.BeginEdit() })
        } catch {
            # best-effort, ignore if BeginEdit isn't available
        }
    })

    $window.FindName('RemoveActionBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $sel = $keystrokesDG.SelectedItem
        if ($null -ne $sel) {
            $keystrokeCollection.Remove($sel) | Out-Null
            $window.FindName('SaveBTN').IsEnabled = $true
        }
    })

    # Move selected action up by 1 position
    $window.FindName('MoveActionUpBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $sel = $keystrokesDG.SelectedItem
        if ($null -eq $sel) { return }
        $idx = $keystrokeCollection.IndexOf($sel)
        if ($idx -gt 0) {
            $keystrokeCollection.Move($idx, $idx - 1)
            $keystrokesDG.SelectedItem = $sel
            $window.FindName('SaveBTN').IsEnabled = $true
        }
    })

    # Move selected action down by 1 position
    $window.FindName('MoveActionDownBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $sel = $keystrokesDG.SelectedItem
        if ($null -eq $sel) { return }
        $idx = $keystrokeCollection.IndexOf($sel)
        if ($idx -lt ($keystrokeCollection.Count - 1)) {
            $keystrokeCollection.Move($idx, $idx + 1)
            $keystrokesDG.SelectedItem = $sel
            $window.FindName('SaveBTN').IsEnabled = $true
        }
    })

    # Move selected action to the top of the list
    $window.FindName('MoveActionToTopBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $sel = $keystrokesDG.SelectedItem
        if ($null -eq $sel) { return }
        $idx = $keystrokeCollection.IndexOf($sel)
        if ($idx -gt 0) {
            $keystrokeCollection.Move($idx, 0)
            $keystrokesDG.SelectedItem = $sel
            $window.FindName('SaveBTN').IsEnabled = $true
        }
    })

    # Move selected action to the end of the list
    $window.FindName('MoveActionToEndBTN').Add_Click({
        if ($null -eq $keystrokeCollection) { return }
        $sel = $keystrokesDG.SelectedItem
        if ($null -eq $sel) { return }
        $idx = $keystrokeCollection.IndexOf($sel)
        if ($idx -lt ($keystrokeCollection.Count - 1)) {
            $keystrokeCollection.Move($idx, $keystrokeCollection.Count - 1)
            $keystrokesDG.SelectedItem = $sel
            $window.FindName('SaveBTN').IsEnabled = $true
        }
    })

    # Enable/disable Remove button depending on selection
    if ($null -ne $keystrokesDG) {
        $keystrokesDG.Add_SelectionChanged({
            $window.FindName('RemoveActionBTN').IsEnabled = ($keystrokesDG.SelectedItem -ne $null)
        })
        # initialize state
        $window.FindName('RemoveActionBTN').IsEnabled = ($keystrokesDG.SelectedItem -ne $null)
    }

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
        $selectedProfileFileName = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedProfileFileName) {
            $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
        }
        Show-EditProfileGui -FilePath $result.SelectedProfile
    })
    $window.FindName("OKBTN").Add_Click({
        $selectedProfileFileName = $window.FindName("ProfileList").SelectedItem
        if ($null -ne $selectedProfileFileName) {
            $result.Action = "Open"
            $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
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
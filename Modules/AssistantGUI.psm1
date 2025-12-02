# ============================================
# Module: AssistantGUI
# Description: GUI module for REW-EQ-CopyPaste-Assistant
# Author: Ivan Bakhmutov
# Date: 2025-11-30
# ============================================

Function Show-EditProfileGui {
    param (
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ResourcesDir
    )

    $result = [PSCustomObject]@{
        FilePath = $FilePath
        Action   = "none"
    }

    #$ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources" # Use the global $scriptDir variable
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ProfileEditorGUI.xml" -Raw -Encoding UTF8)
    $profilesFolderPath = Split-Path -Path $FilePath -Parent

    # Load the JSON profile for reference and to populate form fields
    $originalProfile = $null
    try {
        $originalProfile = Get-Content -Path $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        # If JSON is invalid, create a minimal default
        $originalProfile = [PSCustomObject]@{
            version                 = "1.0"
            Description             = ""
            processName             = ""
            QDivider                = 1
            QDecimals               = 1
            GainDecimals            = 1
            FreqDecimals            = 0
            DecimalSeparator        = "."
            TimeoutBeforePasteSecs  = 6
            StartingPositionHint    = ""
            HotkeyOrDelayPreference = "Hotkey"
            KeystrokeSequence       = @()
            AdminRightsRequired     = "false"
        }
    }

    # Parse the XAML to create the GUI
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $ProfileSelectGUI = [Windows.Markup.XamlReader]::Load($reader)

    $ProfileSelectGUI.FindName("FileNameEdit").Text = (get-item $FilePath).BaseName

    # Populate form fields from the loaded JSON profile
    if ($null -ne $originalProfile.Description) { $ProfileSelectGUI.FindName("DescriptionEdit").Text = $originalProfile.Description }
    if ($null -ne $originalProfile.processName) { $ProfileSelectGUI.FindName("ProcessNameEdit").Text = $originalProfile.processName }
    if ($null -ne $originalProfile.FreqDecimals) { $ProfileSelectGUI.FindName("FreqDecimalsEdit").Text = $originalProfile.FreqDecimals.ToString() }
    if ($null -ne $originalProfile.QDecimals) { $ProfileSelectGUI.FindName("QDecimalsEdit").Text = $originalProfile.QDecimals.ToString() }
    if ($null -ne $originalProfile.GainDecimals) { $ProfileSelectGUI.FindName("GainDecimalsEdit").Text = $originalProfile.GainDecimals.ToString() }
    if ($null -ne $originalProfile.QDivider) { $ProfileSelectGUI.FindName("QDividerEdit").Text = $originalProfile.QDivider.ToString() }
    if ($null -ne $originalProfile.StartingPositionHint) { $ProfileSelectGUI.FindName("StartingPositionEdit").Text = $originalProfile.StartingPositionHint }

    # Decimal separator radio buttons
    if ($originalProfile.DecimalSeparator -eq ",") {
        $ProfileSelectGUI.FindName("DecimalSeparatorComma").IsChecked = $true
    }
    else {
        $ProfileSelectGUI.FindName("DecimalSeparatorDot").IsChecked = $true
    }

    # Hotkey or Delay radio buttons
    if ($originalProfile.HotkeyOrDelayPreference -eq "Delay") {
        $ProfileSelectGUI.FindName("DelaySelected").IsChecked = $true
        if ($null -ne $originalProfile.TimeoutBeforePasteSecs) {
            $ProfileSelectGUI.FindName("DelayEdit").Text = $originalProfile.TimeoutBeforePasteSecs.ToString()
        }
    }
    else {
        $ProfileSelectGUI.FindName("HotkeySelected").IsChecked = $true
        # Check if hotkey override is present
        if (($null -ne $originalProfile.ProfilePerformActionHotkey) -or ($null -ne $originalProfile.ProfileCancelActionHotkey)) {
            $ProfileSelectGUI.FindName("HotkeyOverride").IsChecked = $true
            # Set combo boxes if available
            if ($null -ne $originalProfile.ProfilePerformActionHotkey) {
                $performHotkey = $originalProfile.ProfilePerformActionHotkey
                # Extract the number after 'F' (e.g., "F5" -> 5, "F10" -> 10)
                if ($performHotkey -match '^F(\d+)$') {
                    $performIndex = [int]$matches[1] - 1
                    if (($performIndex -ge 0) -and ($performIndex -lt 12)) {
                        $ProfileSelectGUI.FindName("ActionHotkeyCombo").SelectedIndex = $performIndex
                    }
                }
            }
            if ($null -ne $originalProfile.ProfileCancelActionHotkey) {
                $cancelHotkey = $originalProfile.ProfileCancelActionHotkey
                # Extract the number after 'F' (e.g., "F11" -> 11, "F6" -> 6)
                if ($cancelHotkey -match '^F(\d+)$') {
                    $cancelIndex = [int]$matches[1] - 1
                    if (($cancelIndex -ge 0) -and ($cancelIndex -lt 12)) {
                        $ProfileSelectGUI.FindName("CancelHotkeyCombo").SelectedIndex = $cancelIndex
                    }
                }
            }
        }
        else {
            $ProfileSelectGUI.FindName("HotkeyDefault").IsChecked = $true
        }
    }
    # Load AdminRightsRequired value from JSON and set checkbox
    if ($null -ne $originalProfile.AdminRightsRequired -and $originalProfile.AdminRightsRequired -eq "true") {
        $ProfileSelectGUI.FindName("AdminRightsRequiredCHBX").IsChecked = $true
    } else {
        $ProfileSelectGUI.FindName("AdminRightsRequiredCHBX").IsChecked = $false
    }

    $ProfileSelectGUI.FindName("Help").Add_Click({
            start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant/blob/main/Documentation/DSPProfileFileFormat.md"
        })
    $ProfileSelectGUI.findname("SaveBTN").Add_Click({
            # Validate keystroke rows: if Action is MouseClick ensure Value is Left/Right
            try {
                if ($null -ne $keystrokeCollection) {
                    foreach ($it in $keystrokeCollection) {
                        if ($it.Action -eq 'MouseClick') {
                            if (($it.Value -ne 'Left') -and ($it.Value -ne 'Right')) { $it.Value = 'Left' }
                        }
                    }
                }
            }
            catch {
            }

            # Build the profile object from form data
            $profileObject= [ordered]@{
                version = "1.0"
            }

            # Basic fields
            if ($ProfileSelectGUI.FindName("DescriptionEdit").Text) {
                $profileObject.Description = $ProfileSelectGUI.FindName("DescriptionEdit").Text
            }
            if ($ProfileSelectGUI.FindName("ProcessNameEdit").Text) {
                $profileObject.processName = $ProfileSelectGUI.FindName("ProcessNameEdit").Text
            }

            # Decimals
            try { $profileObject.QDivider = [int]$ProfileSelectGUI.FindName("QDividerEdit").Text } catch { $profileObject.QDivider = 1 }
            try { $profileObject.QDecimals = [int]$ProfileSelectGUI.FindName("QDecimalsEdit").Text } catch { $profileObject.QDecimals = 1 }
            try { $profileObject.GainDecimals = [int]$ProfileSelectGUI.FindName("GainDecimalsEdit").Text } catch { $profileObject.GainDecimals = 1 }
            try { $profileObject.FreqDecimals = [int]$ProfileSelectGUI.FindName("FreqDecimalsEdit").Text } catch { $profileObject.FreqDecimals = 0 }

            # Decimal separator
            if ($ProfileSelectGUI.FindName("DecimalSeparatorComma").IsChecked) {
                $profileObject.DecimalSeparator = ","
            }
            else {
                $profileObject.DecimalSeparator = "."
            }

            # Starting position hint
            if ($ProfileSelectGUI.FindName("StartingPositionEdit").Text) {
                $profileObject.StartingPositionHint = $ProfileSelectGUI.FindName("StartingPositionEdit").Text
            }
            if ($ProfileSelectGUI.FindName("AdminRightsRequiredCHBX").IsChecked) {
                $profileObject.AdminRightsRequired = "true"
            } else {
                $profileObject.AdminRightsRequired = "false"
            }
            # Hotkey or Delay preference
            if ($ProfileSelectGUI.FindName("DelaySelected").IsChecked) {
                $profileObject.HotkeyOrDelayPreference = "Delay"
                try { $profileObject.TimeoutBeforePasteSecs = [int]$ProfileSelectGUI.FindName("DelayEdit").Text } catch { $profileObject.TimeoutBeforePasteSecs = 6 }
            }
            else {
                $profileObject.HotkeyOrDelayPreference = "Hotkey"
                # Only include hotkey overrides if Override radio is checked
                if ($ProfileSelectGUI.FindName("HotkeyOverride").IsChecked) {
                    $actionIdx = $ProfileSelectGUI.FindName("ActionHotkeyCombo").SelectedIndex
                    $cancelIdx = $ProfileSelectGUI.FindName("CancelHotkeyCombo").SelectedIndex
                    if (($actionIdx -ge 0) -and ($actionIdx -lt 12)) {
                        $profileObject.ProfilePerformActionHotkey = "F$($actionIdx + 1)"
                    }
                    if (($cancelIdx -ge 0) -and ($cancelIdx -lt 12)) {
                        $profileObject.ProfileCancelActionHotkey = "F$($cancelIdx + 1)"
                    }
                }
            }

            # Build KeystrokeSequence from DataGrid
            $profileObject.KeystrokeSequence = @()
            if ($null -ne $keystrokeCollection) {
                foreach ($row in $keystrokeCollection) {
                    $ksItem = [ordered]@{}
                    switch ($row.Action) {
                        'Keys' {
                            # Use the JSON property 'Keys' (keystroke SendKeys string)
                            $ksItem.Keys = [string]$row.Value
                        }
                        'MouseClick' {
                            $ksItem.MouseClick = [string]$row.Value
                        }
                        'MouseChangePositionX' {
                            $ksItem.MouseChangePositionX = [string]$row.Value
                        }
                        'MouseChangePositionY' {
                            $ksItem.MouseChangePositionY = [string]$row.Value
                        }
                    }
                    try { $ksItem.Delay_ms = [int]$row.DelayMs } catch { $ksItem.Delay_ms = 100 }
                    $profileObject.KeystrokeSequence += $ksItem
                }
            }

            # Save to file
            try {
                $jsonContent = $profileObject| ConvertTo-Json -Depth 10
                Set-Content -Path $FilePath -Value $jsonContent -Encoding UTF8 -Force
                $result.Action = "Saved"
                $ProfileSelectGUI.Close()
            }
            catch {
                [System.Windows.MessageBox]::Show("Error saving profile: $($_.Exception.Message)", "Save Error",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
       })

    # Save As - open SaveFileDialog in the profiles folder, require user confirmation
    $ProfileSelectGUI.FindName('SaveAsBTN').Add_Click({
            # Validate keystroke rows: if Action is MouseClick ensure Value is Left/Right
            try {
                if ($null -ne $keystrokeCollection) {
                    foreach ($it in $keystrokeCollection) {
                        if ($it.Action -eq 'MouseClick') {
                            if (($it.Value -ne 'Left') -and ($it.Value -ne 'Right')) { $it.Value = 'Left' }
                        }
                    }
                }
            }
            catch {
            }

            # Build the profile object from form data (same as Save)
            $profileObject= [ordered]@{
                version = "1.0"
            }

            if ($ProfileSelectGUI.FindName("DescriptionEdit").Text) {
                $profileObject.Description = $ProfileSelectGUI.FindName("DescriptionEdit").Text
            }
            if ($ProfileSelectGUI.FindName("ProcessNameEdit").Text) {
                $profileObject.processName = $ProfileSelectGUI.FindName("ProcessNameEdit").Text
            }

            try { $profileObject.QDivider = [int]$ProfileSelectGUI.FindName("QDividerEdit").Text } catch { $profileObject.QDivider = 1 }
            try { $profileObject.QDecimals = [int]$ProfileSelectGUI.FindName("QDecimalsEdit").Text } catch { $profileObject.QDecimals = 1 }
            try { $profileObject.GainDecimals = [int]$ProfileSelectGUI.FindName("GainDecimalsEdit").Text } catch { $profileObject.GainDecimals = 1 }
            try { $profileObject.FreqDecimals = [int]$ProfileSelectGUI.FindName("FreqDecimalsEdit").Text } catch { $profileObject.FreqDecimals = 0 }

            if ($ProfileSelectGUI.FindName("DecimalSeparatorComma").IsChecked) {
                $profileObject.DecimalSeparator = ","
            }
            else {
                $profileObject.DecimalSeparator = "."
            }

            if ($ProfileSelectGUI.FindName("StartingPositionEdit").Text) {
                $profileObject.StartingPositionHint = $ProfileSelectGUI.FindName("StartingPositionEdit").Text
            }

            if ($ProfileSelectGUI.FindName("DelaySelected").IsChecked) {
                $profileObject.HotkeyOrDelayPreference = "Delay"
                try { $profileObject.TimeoutBeforePasteSecs = [int]$ProfileSelectGUI.FindName("DelayEdit").Text } catch { $profileObject.TimeoutBeforePasteSecs = 6 }
            }
            else {
                $profileObject.HotkeyOrDelayPreference = "Hotkey"
                if ($ProfileSelectGUI.FindName("HotkeyOverride").IsChecked) {
                    $actionIdx = $ProfileSelectGUI.FindName("ActionHotkeyCombo").SelectedIndex
                    $cancelIdx = $ProfileSelectGUI.FindName("CancelHotkeyCombo").SelectedIndex
                    if (($actionIdx -ge 0) -and ($actionIdx -lt 12)) {
                        $profileObject.ProfilePerformActionHotkey = "F$($actionIdx + 1)"
                    }
                    if (($cancelIdx -ge 0) -and ($cancelIdx -lt 12)) {
                        $profileObject.ProfileCancelActionHotkey = "F$($cancelIdx + 1)"
                    }
                }
            }

            $profileObject.KeystrokeSequence = @()
            if ($null -ne $keystrokeCollection) {
                foreach ($row in $keystrokeCollection) {
                    $ksItem = [ordered]@{}
                    switch ($row.Action) {
                        'Keys' { $ksItem.Keys = [string]$row.Value }
                        'MouseClick' { $ksItem.MouseClick = [string]$row.Value }
                        'MouseChangePositionX' { $ksItem.MouseChangePositionX = [string]$row.Value }
                        'MouseChangePositionY' { $ksItem.MouseChangePositionY = [string]$row.Value }
                    }
                    try { $ksItem.Delay_ms = [int]$row.DelayMs } catch { $ksItem.Delay_ms = 100 }
                    $profileObject.KeystrokeSequence += $ksItem
                }
            }

            # Show SaveFileDialog in the same folder with prepopulated filename
            try {
                $sfd = New-Object Microsoft.Win32.SaveFileDialog
                $sfd.InitialDirectory = $profilesFolderPath
                $sfd.Filter = "JSON files (*.json)|*.json"
                $base = (Get-Item $FilePath).BaseName
                $sfd.FileName = "$base - copy.json"
                $dlgRes = $sfd.ShowDialog()
                if ($dlgRes -eq $true) {
                    try {
                        $jsonContent = $profileObject| ConvertTo-Json -Depth 10
                        Set-Content -Path $sfd.FileName -Value $jsonContent -Encoding UTF8 -Force
                        $result.Action = "SavedAs"
                        # expose new filepath to caller so caller can refresh and select it
                        $result.FilePath = $sfd.FileName
                        $ProfileSelectGUI.Close()
                    }
                    catch {
                        [System.Windows.MessageBox]::Show("Error saving profile: $($_.Exception.Message)", "Save As Error",
                            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    }
                }
                else {
                    # User cancelled Save As — keep editor open
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Error showing Save dialog: $($_.Exception.Message)", "Save As Error",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
    $ProfileSelectGUI.FindName("CancelBTN").Add_Click({
            $result.Action = "Cancel"
            $ProfileSelectGUI.Close()
            #  exit
        })

    # Change tracking - enable Save button when any field is modified
    $enableSaveButton = {
        $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
    }

    # Track text changes in TextBox controls
    $textBoxes = @('FileNameEdit', 'DescriptionEdit', 'ProcessNameEdit', 'FreqDecimalsEdit',
        'QDecimalsEdit', 'GainDecimalsEdit', 'QDividerEdit', 'StartingPositionEdit', 'DelayEdit')
    foreach ($name in $textBoxes) {
        $ctrl = $ProfileSelectGUI.FindName($name)
        if ($null -ne $ctrl) {
            $ctrl.Add_TextChanged($enableSaveButton)
        }
    }

    # track checkbox changes
    $checkBoxes = @('AdminRightsRequiredCHBX')
    foreach ($name in $checkBoxes) {
        $ctrl = $ProfileSelectGUI.FindName($name)
        if ($null -ne $ctrl) {
            $ctrl.Add_Checked($enableSaveButton)
            $ctrl.Add_Unchecked($enableSaveButton)
        }
    }

    # Track radio button changes
    $radioButtons = @('DecimalSeparatorDot', 'DecimalSeparatorComma', 'HotkeySelected',
        'DelaySelected', 'HotkeyDefault', 'HotkeyOverride')
    foreach ($name in $radioButtons) {
        $ctrl = $ProfileSelectGUI.FindName($name)
        if ($null -ne $ctrl) {
            $ctrl.Add_Checked($enableSaveButton)
        }
    }

    # Track combo box changes
    $comboBoxes = @('ActionHotkeyCombo', 'CancelHotkeyCombo')
    foreach ($name in $comboBoxes) {
        $ctrl = $ProfileSelectGUI.FindName($name)
        if ($null -ne $ctrl) {
            $ctrl.Add_SelectionChanged($enableSaveButton)
        }
    }

    # Radio buttons share the same logical group. Attach the same Checked handler to both
    $updateHotkeyDelayVisibility = {
        param($sender, $args)
        $selectedRadioButton = $ProfileSelectGUI.FindName("HotkeySelected").IsChecked
        if ($selectedRadioButton) {
            $ProfileSelectGUI.FindName("HotkeyLabel").Visibility = "Visible"
            $ProfileSelectGUI.FindName("HotkeyDefault").Visibility = "Visible"
            $ProfileSelectGUI.FindName("HotkeyOverride").Visibility = "Visible"
            $ProfileSelectGUI.FindName("DelayLabel").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("DelayEdit").Visibility = "Hidden"
        }
        else {
            $ProfileSelectGUI.FindName("HotkeyLabel").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("HotkeyDefault").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("HotkeyOverride").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("DelayLabel").Visibility = "Visible"
            $ProfileSelectGUI.FindName("DelayEdit").Visibility = "Visible"
            # Also hide hotkey override controls when Delay is selected
            $hotkeyOverrideControls = @('ActionHotkeyCombo', 'CancelHotkeyCombo', 'ActionLabel', 'CancelLabel')
            foreach ($name in $hotkeyOverrideControls) {
                $ctrl = $ProfileSelectGUI.FindName($name)
                if ($null -ne $ctrl) { $ctrl.Visibility = 'Hidden' }
            }
        }
    }

    # Attach handler to both radio buttons in the group
    $ProfileSelectGUI.FindName("HotkeySelected").Add_Checked($updateHotkeyDelayVisibility)
    $ProfileSelectGUI.FindName("DelaySelected").Add_Checked($updateHotkeyDelayVisibility)

    # Initialize visibility according to current selection
    & $updateHotkeyDelayVisibility $null $null

    # Hotkey Default vs Override group: show/hide action/cancel hotkey controls
    $updateHotkeyOverrideVisibility = {
        param($rbSender, $rbArgs)
        $isOverride = $false
        $hotkeyOverrideCtrl = $ProfileSelectGUI.FindName("HotkeyOverride")
        if ($null -ne $hotkeyOverrideCtrl) { $isOverride = $hotkeyOverrideCtrl.IsChecked }

        $controlsToToggle = @(
            'ActionHotkeyCombo', 'CancelHotkeyCombo',
            'ActionHotkeyLabel', 'CancelHotkeyLabel',
            'actionlabel', 'cancellabel', 'ActionLabel', 'CancelLabel'
        )

        foreach ($name in $controlsToToggle) {
            $ctrl = $ProfileSelectGUI.FindName($name)
            if ($null -ne $ctrl) {
                $ctrl.Visibility = if ($isOverride) { 'Visible' } else { 'Hidden' }
            }
        }
    }

    # Update the Hotkey/Delay visibility handler to restore override controls when switching back to Hotkey
    $updateHotkeyDelayVisibility = {
        param($sender, $args)
        $selectedRadioButton = $ProfileSelectGUI.FindName("HotkeySelected").IsChecked
        if ($selectedRadioButton) {
            $ProfileSelectGUI.FindName("HotkeyLabel").Visibility = "Visible"
            $ProfileSelectGUI.FindName("HotkeyDefault").Visibility = "Visible"
            $ProfileSelectGUI.FindName("HotkeyOverride").Visibility = "Visible"
            $ProfileSelectGUI.FindName("DelayLabel").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("DelayEdit").Visibility = "Hidden"
            # Restore hotkey override controls visibility based on current selection
            & $updateHotkeyOverrideVisibility $null $null
        }
        else {
            $ProfileSelectGUI.FindName("HotkeyLabel").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("HotkeyDefault").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("HotkeyOverride").Visibility = "Hidden"
            $ProfileSelectGUI.FindName("DelayLabel").Visibility = "Visible"
            $ProfileSelectGUI.FindName("DelayEdit").Visibility = "Visible"
            # Also hide hotkey override controls when Delay is selected
            $hotkeyOverrideControls = @('ActionHotkeyCombo', 'CancelHotkeyCombo', 'ActionLabel', 'CancelLabel')
            foreach ($name in $hotkeyOverrideControls) {
                $ctrl = $ProfileSelectGUI.FindName($name)
                if ($null -ne $ctrl) { $ctrl.Visibility = 'Hidden' }
            }
        }
    }

    # Re-attach handlers after updating the function
    $ProfileSelectGUI.FindName("HotkeySelected").Add_Checked($updateHotkeyDelayVisibility)
    $ProfileSelectGUI.FindName("DelaySelected").Add_Checked($updateHotkeyDelayVisibility)

    # Attach handler to both radio buttons (Default and Override)
    if ($ProfileSelectGUI.FindName('HotkeyDefault')) { $ProfileSelectGUI.FindName('HotkeyDefault').Add_Checked($updateHotkeyOverrideVisibility) }
    if ($ProfileSelectGUI.FindName('HotkeyOverride')) { $ProfileSelectGUI.FindName('HotkeyOverride').Add_Checked($updateHotkeyOverrideVisibility) }

    # Initialize hotkey override visibility
    & $updateHotkeyOverrideVisibility $null $null

    # Prepare an ObservableCollection as the DataGrid's ItemsSource so editing is supported
    $keystrokesDG = $ProfileSelectGUI.FindName('KeystrokesList')
    $keystrokeCollection = $null
    if ($null -ne $keystrokesDG) {
        if ($null -eq $keystrokesDG.ItemsSource) {
            $keystrokeCollection = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'

            # Populate from loaded profile's KeystrokeSequence if available
            if (($null -ne $originalProfile) -and ($null -ne $originalProfile.KeystrokeSequence)) {
                #Write-Host "Loading KeystrokeSequence with $($originalProfile.KeystrokeSequence.Count) items" -ForegroundColor Cyan
                foreach ($ks in $originalProfile.KeystrokeSequence) {
                    # Determine the action type based on properties present
                    $action = 'Keys'
                    $value = ''
                    $delayMs = 100

                    if ($null -ne $ks.Keys) {
                        $action = 'Keys'
                        $value = [string]$ks.Keys  # Read as-is, these are SendKeys strings like ^a, {ENTER}, +{TAB}
                    }
                    elseif ($null -ne $ks.MouseClick) {
                        $action = 'MouseClick'
                        $value = [string]$ks.MouseClick
                    }
                    elseif ($null -ne $ks.MouseChangePositionX) {
                        $action = 'MouseChangePositionX'
                        $value = [string]$ks.MouseChangePositionX
                    }
                    elseif ($null -ne $ks.MouseChangePositionY) {
                        $action = 'MouseChangePositionY'
                        $value = [string]$ks.MouseChangePositionY
                    }

                    if ($null -ne $ks.Delay_ms) {
                        $delayMs = $ks.Delay_ms
                    }

                    $rowItem = [pscustomobject]@{
                        Action  = $action
                        Value   = $value
                        DelayMs = $delayMs
                    }
                    $keystrokeCollection.Add($rowItem) | Out-Null
                }
                # Write-Host "KeystrokeCollection now has $($keystrokeCollection.Count) items" -ForegroundColor Green
            }
            else {
                Write-Host "No KeystrokeSequence found in profile" -ForegroundColor Red
            }

            $keystrokesDG.ItemsSource = $keystrokeCollection
        }
        else {
            $keystrokeCollection = $keystrokesDG.ItemsSource
        }
    }

    # When user finishes editing the Action cell, reset the Value based on the new action type
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
                            }
                            elseif ($editingElement.GetType().GetProperty('Text')) {
                                $newAction = $editingElement.Text
                            }
                        }

                        # Reset Value based on the new action type
                        if ($null -ne $newAction) {
                            $null = $keystrokesDG.Dispatcher.BeginInvoke([System.Action] {
                                    switch ($newAction) {
                                        'MouseClick' {
                                            # Default to Left for mouse click
                                            $rowItem.Value = 'Left'
                                        }
                                        'MouseChangePositionX' {
                                            # Default to 0 for mouse move
                                            $rowItem.Value = '0'
                                        }
                                        'MouseChangePositionY' {
                                            # Default to 0 for mouse move
                                            $rowItem.Value = '0'
                                        }
                                        'Keys' {
                                            # Reset to empty for key action
                                            $rowItem.Value = ''
                                        }
                                    }
                                })
                        }
                    }
                }
                catch {
                }
            })
    }

    # Add/Remove action row handlers for KeystrokesList DataGrid (use ItemsSource collection)
    $ProfileSelectGUI.FindName('AddActionBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $new = [pscustomobject]@{
                Action  = 'Keys'
                Value   = ''
                DelayMs = 100
            }
            $keystrokeCollection.Add($new) | Out-Null
            try { $keystrokesDG.ScrollIntoView($new) } catch { }
            $keystrokesDG.SelectedItem = $new
            $ProfileSelectGUI.FindName('RemoveActionBTN').IsEnabled = $true
            $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true

            # Put the new row into edit mode immediately
            try {
                $col = $keystrokesDG.Columns[0]
                $cellInfo = New-Object System.Windows.Controls.DataGridCellInfo($new, $col)
                $keystrokesDG.CurrentCell = $cellInfo
                try { $keystrokesDG.ScrollIntoView($new, $col) } catch { }
                $null = $keystrokesDG.Dispatcher.BeginInvoke([System.Action] { $keystrokesDG.BeginEdit() })
            }
            catch {
                # best-effort, ignore if BeginEdit isn't available
            }
        })

    $ProfileSelectGUI.FindName('RemoveActionBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $sel = $keystrokesDG.SelectedItem
            if ($null -ne $sel) {
                $keystrokeCollection.Remove($sel) | Out-Null
                $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
            }
        })

    # Move selected action up by 1 position
    $ProfileSelectGUI.FindName('MoveActionUpBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $sel = $keystrokesDG.SelectedItem
            if ($null -eq $sel) { return }
            $idx = $keystrokeCollection.IndexOf($sel)
            if ($idx -gt 0) {
                $keystrokeCollection.Move($idx, $idx - 1)
                $keystrokesDG.SelectedItem = $sel
                $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
            }
        })

    # Move selected action down by 1 position
    $ProfileSelectGUI.FindName('MoveActionDownBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $sel = $keystrokesDG.SelectedItem
            if ($null -eq $sel) { return }
            $idx = $keystrokeCollection.IndexOf($sel)
            if ($idx -lt ($keystrokeCollection.Count - 1)) {
                $keystrokeCollection.Move($idx, $idx + 1)
                $keystrokesDG.SelectedItem = $sel
                $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
            }
        })

    # Move selected action to the top of the list
    $ProfileSelectGUI.FindName('MoveActionToTopBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $sel = $keystrokesDG.SelectedItem
            if ($null -eq $sel) { return }
            $idx = $keystrokeCollection.IndexOf($sel)
            if ($idx -gt 0) {
                $keystrokeCollection.Move($idx, 0)
                $keystrokesDG.SelectedItem = $sel
                $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
            }
        })

    # Move selected action to the end of the list
    $ProfileSelectGUI.FindName('MoveActionToEndBTN').Add_Click({
            if ($null -eq $keystrokeCollection) { return }
            $sel = $keystrokesDG.SelectedItem
            if ($null -eq $sel) { return }
            $idx = $keystrokeCollection.IndexOf($sel)
            if ($idx -lt ($keystrokeCollection.Count - 1)) {
                $keystrokeCollection.Move($idx, $keystrokeCollection.Count - 1)
                $keystrokesDG.SelectedItem = $sel
                $ProfileSelectGUI.FindName('SaveBTN').IsEnabled = $true
            }
        })

    # Enable/disable Remove button depending on selection
    if ($null -ne $keystrokesDG) {
        $keystrokesDG.Add_SelectionChanged({
                $ProfileSelectGUI.FindName('RemoveActionBTN').IsEnabled = ($null -ne $keystrokesDG.SelectedItem)
            })
        # initialize state
        $ProfileSelectGUI.FindName('RemoveActionBTN').IsEnabled = ($null -ne $keystrokesDG.SelectedItem)
    }

    # Show the GUI
    $ProfileSelectGUI.ShowDialog() | Out-Null
    return $result
}

Function Show-SelectProfileGui {
    param (
        [Parameter(Mandatory = $true)][string]$ResourcesDir,
        [Parameter(Mandatory = $true)][string]$GlobalPerformActionHotkey,
        [Parameter(Mandatory = $true)][string]$GlobalCancelActionHotkey,
        [Parameter(Mandatory = $true)][string]$DSPProfilesDir,
        [Parameter(Mandatory = $true)][string]$ModulesDir,
        [Parameter(Mandatory = $false)][string]$LastSelectedProfile,
        [Parameter(Mandatory = $true)][string]$AssistantVersion
    )

    function Get-OverviewText {
        param(
            [Parameter(Mandatory = $true)]$profileContent
        )
        $result = "Description: $($profileContent.description)`n`n" + `
         "DSP Software Process Name: $($profileContent.processName)`n`n" + `
         "Starting Position Hint: $($profileContent.StartingPositionHint)`n"
        return $result
    }

    function Get-ProfileContent {
        param (
            [Parameter(Mandatory = $true)]$selectedItem,
            [Parameter(Mandatory = $true)]$DSPProfilesDir,
            [Parameter(Mandatory = $true)]$ProfileEditGUI,
            [Parameter(Mandatory = $true)]$result,
            [Parameter(Mandatory = $true)]$GlobalPerformHotkey,
            [Parameter(Mandatory = $true)]$GlobalCancelHotkey
        )
        if ($null -ne $selectedItem) {
            $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
            try {
                # Read-JSONFile now returns the parsed JSON object or throws on error
                $profileJson = Read-JSONFile -FilePath $profilePath -ErrorAction Stop

                # Show nicely formatted JSON in the text box
                $profileContent = $profileJson | ConvertTo-Json -Depth 10
                $ProfileEditGUI.FindName("ProfileText").Text = $profileContent
                $ProfileEditGUI.FindName('ProfileOverview').Text = Get-OverviewText -profileContent $profileJson
                $result.processName = $profileJson.processName
                if ($null -ne $profileJson.AdminRightsRequired) {
                    $result.AdminRightsRequired = $profileJson.AdminRightsRequired
                }
                else {
                    $result.AdminRightsRequired = "false"
                }
                $ProfileEditGUI.FindName("OKBTN").IsEnabled = $true
                $ProfileEditGUI.FindName("EditBTN").IsEnabled = $true

                # Use $profileJson directly for hotkey decisions
                if (($profileJson.ProfilePerformActionHotkey -ne $GlobalPerformHotkey) -and
                    ($null -ne $profileJson.ProfilePerformActionHotkey)) {
                    $result.EffectivePerformActionHotkey = $profileJson.ProfilePerformActionHotkey
                }
                else {
                    $result.EffectivePerformActionHotkey = $GlobalPerformHotkey
                }

                if (($profileJson.ProfileCancelActionHotkey -ne $GlobalCancelHotkey) -and
                    ($null -ne $profileJson.ProfileCancelActionHotkey)) {
                    $result.EffectiveCancelActionHotkey = $profileJson.ProfileCancelActionHotkey
                }
                else {
                    $result.EffectiveCancelActionHotkey = $GlobalCancelActionHotkey
                }

                $hotkeyHintLabel = $ProfileEditGUI.FindName("HotkeyHint")
                $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"
                if (($GlobalPerformHotkey -ne $result.EffectivePerformActionHotkey) -or
                    ($GlobalCancelActionHotkey -ne $result.EffectiveCancelActionHotkey)) {
                    $hotkeyHintLabel.Content += " (override)"
                }

                switch ($profileJson.HotkeyOrDelayPreference) {
                    "Hotkey" { $hotkeyHintLabel.Visibility = "Visible" }
                    "Delay" { $hotkeyHintLabel.Visibility = "Hidden" }
                    Default { $hotkeyHintLabel.Visibility = "Hidden" }
                }
            }
            catch {
                $ProfileEditGUI.FindName("ProfileText").Text = "Error parsing JSON profile. Please check the file"
                $ProfileEditGUI.FindName("ProfileOverview").Text = "Error parsing JSON profile. Please check the file"
                $ProfileEditGUI.FindName("OKBTN").IsEnabled = $false
                $ProfileEditGUI.FindName("EditBTN").IsEnabled = $false
            }
        }
        else {
            $ProfileEditGUI.FindName("ProfileText").Text = "Please select a profile"
            $ProfileEditGUI.FindName("ProfileOverview").Text = "Please select a profile"
            $ProfileEditGUI.FindName("OKBTN").IsEnabled = $false
            $ProfileEditGUI.FindName("EditBTN").IsEnabled = $false
        }
    }

    $result = [PSCustomObject]@{
        Action                       = "Cancel"
        SelectedProfile              = $null
        EffectivePerformActionHotkey = $GlobalPerformActionHotkey   # initialize to global defaults
        EffectiveCancelActionHotkey  = $GlobalCancelActionHotkey
        ProcessName                  = $null
        ProcessStatus                = $null
        REWStatus                    = $null
        AdminRightsRequired          = "false"
    }

    # Load the XAML file
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ChooseProfileGUI.xml" -Raw -Encoding UTF8)

    # Parse the XAML to create the GUI
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $ProfileEditGUI = [Windows.Markup.XamlReader]::Load($reader)

    # Set hotkey hint label
    $ProfileEditGUI.FindName("HotkeyHint").Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"
    $ProfileEditGUI.FindName("Version").Text = "Version $AssistantVersion"

    #Region Check updates
    try {
        # Set a timeout for the request
        $webRequestOptions = @{
            Uri         = "https://raw.githubusercontent.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant/refs/heads/main/Resources/version"
            Method      = "Get"
            TimeoutSec  = 10
            ErrorAction = "Stop"
        }
        $LatestVersion = Invoke-RestMethod @webRequestOptions

        # Validate the version format (e.g., "1.0.0")
        if ($LatestVersion -notmatch "^\d+\.\d+\.\d+$") {
            throw "Invalid version format retrieved: $LatestVersion"
        }
    } catch {
        # Log the error and set a default value
        Write-Host "Failed to retrieve the latest version number: $($_.Exception.Message)" -ForegroundColor Red
        $LatestVersion = "Unknown"
    }

    if($LatestVersion -ne "Unknown"){
        try {
            # Read the version from the local file
            $localVersionPath = Join-Path -Path $ResourcesDir -ChildPath "version"
            if (Test-Path -Path $localVersionPath) {
                $LocalVersion = Get-Content -Path $localVersionPath -Raw -Encoding UTF8
                if ($LocalVersion -notmatch "^\d+\.\d+\.\d+$") {
                    throw "Invalid version format in local file: $LocalVersion"
                }

                # Compare the local version with the latest version
                if ($LocalVersion -lt $LatestVersion) {
                    Write-Host "A newer version ($LatestVersion) is available." -ForegroundColor Yellow
                    $ProfileEditGUI.FindName("Version").Text = "Version $AssistantVersion (update available)"
                } elseif ($LocalVersion -gt $LatestVersion) {
                    Write-Host "Tool version ($LocalVersion) is ahead of the latest update online ($LatestVersion)." -ForegroundColor DarkRed
                } else {
                    $ProfileEditGUI.FindName("Version").Text = "Version $AssistantVersion (Latest)"
                    Write-Host "Tool version is up-to-date." -ForegroundColor Cyan
                }
            } else {
                Write-Host "Tool version file not found." -ForegroundColor Red
            }
        } catch {
            Write-Host "Error checking updates: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    #Endregion

    # Placeholder for another dispatcher timer for hints array including version check
    # to be shown on the hint label
    # maybe check rew version as well
    #

    # Populate the profiles list in the GUI
    if (-not ($script:DSPProfilesList -is [System.Array])) { $script:DSPProfilesList = @() }
    $script:DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
    $ProfileEditGUI.FindName("ProfileList").ItemsSource = $script:DSPProfilesList.BaseName

    # Select last used profile and manually trigger SelectionChanged event
    if ($null -ne $LastSelectedProfile -and $ProfileEditGUI.FindName("ProfileList").ItemsSource -contains $LastSelectedProfile) {
        $ProfileEditGUI.FindName("ProfileList").SelectedItem = $LastSelectedProfile
        Get-ProfileContent -selectedItem $LastSelectedProfile -DSPProfilesDir $DSPProfilesDir -ProfileEditGUI $ProfileEditGUI -result $result -GlobalPerformHotkey $GlobalPerformActionHotkey -GlobalCancelHotkey $GlobalCancelActionHotkey
    }

    #Region process checks
    $BGProcessCheck = New-Object Windows.Threading.DispatcherTimer
    $BGProcessCheck.Interval = [TimeSpan]::FromMilliseconds(300)
    $BGProcessCheck.Add_Tick({
            if ($null -eq $result.ProcessName) {
                $ProfileEditGUI.FindName("ProcessStatus").foreground = "gray"
                $result.ProcessName = "n/a"
                $result.ProcessStatus = "Not Running"
            }
            elseif ($result.ProcessName -eq "Generic") {
                $ProfileEditGUI.FindName("ProcessStatus").foreground = "Blue"
                $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Generic profile selected, no process check performed. Bring the DSP software to the foreground manually."
                $result.ProcessName = "Generic"
                $result.ProcessStatus = "Running"
            }
            else {
                # find DSP Software processes with window
                $DSPProcess = Get-Process | Where-Object {
                    $_.ProcessName -like $result.ProcessName -and $_.ProcessName -ne "conhost" -and $_.MainWindowHandle -ne [IntPtr]::Zero
                }

                if ($null -eq $DSPProcess) {
                    $ProfileEditGUI.FindName("ProcessStatus").foreground = "Red"
                    $ProfileEditGUI.FindName("ProcessStatus").tooltip = "No matching processes found for $($result.ProcessName)"
                    #$result.ProcessName = "n/a"
                    $result.ProcessStatus = "Not Running"
                }
                elseif ($DSPProcess.Count -gt 1) {
                    $ProfileEditGUI.FindName("ProcessStatus").foreground = "Red"
                    $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Expected 1 process, found: $($DSPProcess.Count)"
                    #$result.ProcessName = "n/a"
                    $result.ProcessStatus = "Multiple Instances Found"
                }
                else {
                    if ($result.AdminRightsRequired -eq "true") {
                        if (Get-RunningAsAdminFlag) {
                            $ProfileEditGUI.FindName("ProcessStatus").foreground = "Lime"
                            $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Found process: $($DSPProcess.ProcessName)"
                            $result.ProcessName = $DSPProcess.ProcessName
                            $result.ProcessStatus = "Running"
                        }
                        else {
                            $ProfileEditGUI.FindName("ProcessStatus").foreground = "Purple"
                            $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Admin rights are required to interact with $($DSPProcess.ProcessName). Please restart the Assistant with elevated privileges."
                            $result.ProcessName = $DSPProcess.ProcessName
                            $result.ProcessStatus = "Admin Rights Required"
                        }
                    }
                    else {
                        $ProfileEditGUI.FindName("ProcessStatus").foreground = "Lime"
                        $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Found process: $($DSPProcess.ProcessName)"
                        $result.ProcessName = $DSPProcess.ProcessName
                        $result.ProcessStatus = "Running"
                    }
                }
            }


            $REWProcess = Get-Process | Where-Object {
                $_.ProcessName -like "roomeqwizard" -and $_.ProcessName -ne "conhost" -and $_.MainWindowHandle -ne [IntPtr]::Zero
            }

            if ($null -eq $REWProcess) {
                $ProfileEditGUI.FindName("REWStatus").foreground = "Red"
                $ProfileEditGUI.FindName("REWStatus").tooltip = "REW is not running (click PLAY button to launch REW in API mode)"
                $result.REWStatus = "Not Running"
                $ProfileEditGUI.FindName("RunREWBTN").visibility = "Visible"
            }
            else {
                $rewWMIprocess = Get-WmiObject Win32_Process -Filter "name='roomeqwizard.exe'"
                if ($null -ne $rewWMIprocess) {
                    $checkpREWargs = $rewWMIprocess | Select-Object CommandLine
                    if ($checkpREWargs.CommandLine -notmatch "-api") {
                        $ProfileEditGUI.FindName("REWStatus").foreground = "Orange"
                        $ProfileEditGUI.FindName("REWStatus").tooltip = "Found process: $($REWProcess.ProcessName). API mode is not enabled."
                        $result.REWStatus = "API Not Enabled"
                        $ProfileEditGUI.FindName("RunREWBTN").visibility = "Hidden"
                    }
                    else {
                        $ProfileEditGUI.FindName("REWStatus").foreground = "Lime"
                        $ProfileEditGUI.FindName("REWStatus").tooltip = "Found process: $($REWProcess.ProcessName). API mode is enabled."
                        $result.REWStatus = "Running"
                        $ProfileEditGUI.FindName("RunREWBTN").visibility = "Hidden"
                    }
                }
            }


        })
    $BGProcessCheck.Start()
    #Endregion

    #Region Assign event handlers
        # Search box text changed handler to filter the profiles list
    $ProfileEditGUI.FindName("SearchEDIT").Add_TextChanged({
            param($searchSender, $searchArgs)
            $searchText = $searchSender.Text.ToLower()
            $filteredProfiles = @()
            foreach ($profileFile in $script:DSPProfilesList) {
                if ($profileFile.BaseName.ToLower().Contains($searchText)) {
                    $filteredProfiles += $profileFile.BaseName
                }
            }
            $ProfileEditGUI.FindName("ProfileList").ItemsSource = $filteredProfiles
        })

        # Search box clear click handler
    $ProfileEditGUI.FindName("ClearSearchBTN").Add_Click({
            $ProfileEditGUI.FindName("SearchEDIT").Text = ""
            $script:DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
            $ProfileEditGUI.FindName("ProfileList").ItemsSource = $script:DSPProfilesList.BaseName
        })

        # Run REW button click handler
    $ProfileEditGUI.FindName("RunREWBTN").Add_Click({
            if ($result.REWStatus -eq "Not Running") {
                # Locate the installation directory of Room EQ Wizard from the registry
                $installPath = $null
                try {
                    $registryBasePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                    $registryKeys = Get-ChildItem -Path $registryBasePath

                    foreach ($key in $registryKeys) {
                        $urlInfoAbout = (Get-ItemProperty -Path $key.PSPath -Name "URLInfoAbout" -ErrorAction SilentlyContinue).URLInfoAbout
                        if ($urlInfoAbout -eq "https://www.roomeqwizard.com") {
                            $installPath = (Get-ItemProperty -Path $key.PSPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                            break
                        }
                    }

                    if (-Not $installPath) {
                        throw "Room EQ Wizard installation directory not found in the registry."
                    }
                }
                catch {
                    [System.Windows.MessageBox]::Show("Failed to locate Room EQ Wizard installation directory in the registry: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return
                }

                $rewExecutable = Join-Path -Path $installPath -ChildPath "RoomEQWizard.exe"

                if (-Not (Test-Path -Path $rewExecutable)) {
                    [System.Windows.MessageBox]::Show("Room EQ Wizard executable not found at $installPath. Please verify the installation path.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return
                }

                # Start Room EQ Wizard with the -api command-line parameter
                try {
                    Start-Process -FilePath $rewExecutable -ArgumentList "-api"
                }
                catch {
                    [System.Windows.MessageBox]::Show("Failed to start Room EQ Wizard: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        })

        # GitHub button click handler
    $ProfileEditGUI.FindName("GitHub").Add_Click({
            start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant"
        })

        # Donate button click handler
    $ProfileEditGUI.FindName("Donate").Add_Click({
            start-process "https://paypal.me/IvanBakhmutovDonate"
        })

        # Close button click handler
    $ProfileEditGUI.FindName("CloseBTN").Add_Click({
            $BGProcessCheck.Stop()
            $ProfileEditGUI.Close()
            #return
        })

        # New profile click handler
    $ProfileEditGUI.FindName("NewProfileBTN").Add_Click({
            # Prompt user to save a new profile file
            $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialog.InitialDirectory = $DSPProfilesDir
            $saveFileDialog.Filter = "JSON files (*.json)|*.json"
            $saveFileDialog.Title = "Save New Profile"
            $saveFileDialog.FileName = "NewProfile.json"
            $BGProcessCheck.stop()
            if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $newProfilePath = $saveFileDialog.FileName

                # Populate the new file with default values
                $defaultProfile = [PSCustomObject]@{
                    version                 = "1.0"
                    Description             = "New Profile"
                    processName             = "---DSP Software Name---"
                    QDivider                = 1
                    QDecimals               = 1
                    GainDecimals            = 1
                    FreqDecimals            = 0
                    DecimalSeparator        = "."
                    TimeoutBeforePasteSecs  = 6
                    StartingPositionHint    = "Please select 1 band Freq box and hit hotkey"
                    HotkeyOrDelayPreference = "Hotkey"
                    KeystrokeSequence       = @()
                }
                $defaultProfile | ConvertTo-Json -Depth 10 | Set-Content -Path $newProfilePath -Encoding UTF8

                # Open the new profile in the editing GUI
                $editResult = Show-EditProfileGui -FilePath $newProfilePath -ResourcesDir $ResourcesDir

                # If the profile was saved, refresh the list and select the new item
                if ($null -ne $editResult -and ($editResult.Action -eq 'Saved' -or $editResult.Action -eq 'SavedAs')) {
                    $newProfileName = (get-item $editResult.FilePath | Select-Object -ExpandProperty basename)
                    $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json" | Select-Object -ExpandProperty BaseName
                    $ProfileEditGUI.FindName("SearchEDIT").Text = $newProfileName
                    $ProfileEditGUI.FindName("ProfileList").ItemsSource = [array]$newProfileName
                    Get-ProfileContent -selectedItem $newProfileName -DSPProfilesDir $DSPProfilesDir -ProfileEditGUI $ProfileEditGUI -result $result -GlobalPerformHotkey $GlobalPerformActionHotkey -GlobalCancelHotkey $GlobalCancelActionHotkey
                }
            }
            $BGProcessCheck.start()
        })

        # Profile selection changed handler
    $ProfileEditGUI.FindName("EditBTN").Add_Click({
            $selectedProfileFileName = $ProfileEditGUI.FindName("ProfileList").SelectedItem
            if ($null -ne $selectedProfileFileName) {
                $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
            }
            $BGProcessCheck.Stop()
            $editResult = Show-EditProfileGui -FilePath $result.SelectedProfile -ResourcesDir $ResourcesDir
            $BGProcessCheck.Start()
            # If the profile was saved (overwritten or saved as new), refresh the list and select the saved item
            if ($null -ne $editResult -and ($editResult.Action -eq 'Saved' -or $editResult.Action -eq 'SavedAs')) {
                # reload available profiles

                $script:DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
                $searchText = $ProfileEditGUI.FindName('SearchEDIT').Text.ToLower()
                [array]$filteredProfiles = @()
                    foreach ($profileFile in $script:DSPProfilesList) {
                        if ($profileFile.BaseName.ToLower().Contains($searchText)) {
                            $filteredProfiles += $profileFile.BaseName
                        }
                    }
                    $ProfileEditGUI.FindName("ProfileList").ItemsSource = $filteredProfiles
                # determine the base name of saved file and select it
                try {
                    $savedPath = $editResult.FilePath
                    if ($null -eq $savedPath) { $savedPath = $result.SelectedProfile }
                    $savedBase = (Get-Item -LiteralPath $savedPath).BaseName
                    $ProfileEditGUI.FindName('ProfileList').SelectedItem = $savedBase

                    # update profile preview and hotkey hint using the same logic as SelectionChanged
                    $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($savedBase).json"
                    $profileJson = Read-JSONFile -FilePath $profilePath -ErrorAction Stop
                    $ProfileEditGUI.FindName('ProfileText').Text = ($profileJson | ConvertTo-Json -Depth 10)
                    $ProfileEditGUI.FindName('ProfileOverview').Text = Get-OverviewText -profileContent $profileJson

                    # Update effective hotkeys and hint label
                    if (($profileJson.ProfilePerformActionHotkey -ne $GlobalPerformActionHotkey) -and ($null -ne $profileJson.ProfilePerformActionHotkey)) {
                        $result.EffectivePerformActionHotkey = $profileJson.ProfilePerformActionHotkey
                    }
                    else { $result.EffectivePerformActionHotkey = $GlobalPerformActionHotkey }
                    if (($profileJson.ProfileCancelActionHotkey -ne $GlobalCancelActionHotkey) -and ($null -ne $profileJson.ProfileCancelActionHotkey)) {
                        $result.EffectiveCancelActionHotkey = $profileJson.ProfileCancelActionHotkey
                    }
                    else { $result.EffectiveCancelActionHotkey = $GlobalCancelActionHotkey }
                    $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"
                    if (($GlobalPerformActionHotkey -ne $result.EffectivePerformActionHotkey) -or ($GlobalCancelActionHotkey -ne $result.EffectiveCancelActionHotkey)) { $hotkeyHintLabel.Content += " (override)" }

                    # enable buttons
                    $ProfileEditGUI.FindName('OKBTN').IsEnabled = $true
                    $ProfileEditGUI.FindName('EditBTN').IsEnabled = $true
                }
                catch {
                    # ignore selection refresh errors
                }
            }
        })

        # OK button click handler
    $ProfileEditGUI.FindName("OKBTN").Add_Click({
            $selectedProfileFileName = $ProfileEditGUI.FindName("ProfileList").SelectedItem

            # check if REW is running with API enabled
            if ($result.REWStatus -eq "Not Running") {
                $ButtonType = [System.Windows.MessageBoxButton]::OK
                $MessageIcon = [System.Windows.MessageBoxImage]::Error
                $MessageBody = "Room EQ Wizard (REW) is not running. Please start REW. You can click the 'PLAY' button to launch REW in API mode automatically."
                $MessageTitle = "REW Not Running or API Not Enabled"
                [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon) | Out-Null
                return
            } elseif ($result.REWStatus -eq "API Not Enabled") {
                $ButtonType = [System.Windows.MessageBoxButton]::OK
                $MessageIcon = [System.Windows.MessageBoxImage]::Warning
                $MessageBody = "Room EQ Wizard (REW) is running but API mode is not enabled. You will have to click 'Copy the filter settings to the clipboard' button or press Alt-C and proceed with paste procedure in your DSP software."
                $MessageTitle = "REW API Not Enabled"
                [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon) | Out-Null
            }

            # Check if process is running
            if ($result.ProcessStatus -ne "Running") {
                $ButtonType = [System.Windows.MessageBoxButton]::OK
                $MessageIcon = [System.Windows.MessageBoxImage]::Error
                $MessageBody = "The target DSP software process is not running. Please start the software and try again."
                $MessageTitle = "DSP Software Not Running"
                [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon) | Out-Null
                return
            }

            # Check for admin rights if required by the selected profile
            if ($result.AdminRightsRequired -eq "true") {
                if (-not (Get-RunningAsAdminFlag)) {

                    $ButtonType = [System.Windows.MessageBoxButton]::OK
                    $MessageIcon = [System.Windows.MessageBoxImage]::Error
                    $MessageBody = "Selected DSP profile requires administrative privileges. Please run the script as an administrator."
                    $MessageTitle = "Administrative Privileges Required"
                    [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon) | Out-Null
                    return
                }
            }
            if ($null -ne $selectedProfileFileName) {
                $result.Action = "Open"
                $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
                $BGProcessCheck.Stop()
                $ProfileEditGUI.Close()
            }
        })

        # List selection changed handler
    $ProfileEditGUI.FindName("ProfileList").Add_SelectionChanged({
            $selectedItem = $ProfileEditGUI.FindName("ProfileList").SelectedItem
            if ($null -ne $selectedItem) {
                Get-ProfileContent -selectedItem $selectedItem -DSPProfilesDir $DSPProfilesDir -ProfileEditGUI $ProfileEditGUI -result $result -GlobalPerformHotkey $GlobalPerformActionHotkey -GlobalCancelHotkey $GlobalCancelActionHotkey
            }
        })

        # List doubleclick
    $ProfileEditGUI.FindName("ProfileList").Add_mouseDoubleClick({
            $ProfileEditGUI.FindName("ProfileList").SelectedItem = $ProfileEditGUI.FindName("ProfileList").SelectedItem
            Start-Sleep -Milliseconds 100
            if ($ProfileEditGUI.FindName("OKBTN").IsEnabled -eq $true) {
                $RoutedEventArgs = New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                $ProfileEditGUI.FindName("OKBTN").RaiseEvent($RoutedEventArgs)
            }
        })

        # Add Closed event to clean up
    $ProfileEditGUI.Add_Closed({
            return
        })
    #EndRegion
    # Show the GUI
    $ProfileEditGUI.ShowDialog() | Out-Null
    return $result
}



function Show-PopupGUI {
    param (
        [Parameter(Mandatory = $true)][string]$ResourcesDir,
        [Parameter(Mandatory = $true)]$DSPConfig,
        [Parameter(Mandatory = $true)]$GlobalConfig
    )
    Add-Type -AssemblyName PresentationFramework

    # ---------------------------------------------------------
    # Decide OS version
    # ---------------------------------------------------------
    $winMajor = [Environment]::OSVersion.Version.Major
    $winBuild = [Environment]::OSVersion.Version.Build

    # ---------------------------------------------------------
    # Blur API for Win7 (Aero)
    # ---------------------------------------------------------
    if (-not ([System.Management.Automation.PSTypeName]'Win7Blur').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win7Blur {
    [StructLayout(LayoutKind.Sequential)]
    public struct DWM_BLURBEHIND {
        public uint dwFlags;
        public bool fEnable;
        public IntPtr hRgnBlur;
        public bool fTransitionOnMaximized;
    }

    public const uint DWM_BB_ENABLE = 0x1;

    [DllImport("dwmapi.dll")]
    public static extern int DwmEnableBlurBehindWindow(IntPtr hwnd, ref DWM_BLURBEHIND bb);
}
"@
    }

    # ---------------------------------------------------------
    # Accent Blur for Win10/11
    # ---------------------------------------------------------
    if (-not ([System.Management.Automation.PSTypeName]'Win10Blur').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public enum AccentState {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
}

[StructLayout(LayoutKind.Sequential)]
public struct AccentPolicy {
    public AccentState AccentState;
    public int AccentFlags;
    public int GradientColor;
    public int AnimationId;
}

[StructLayout(LayoutKind.Sequential)]
public struct WindowCompositionAttributeData {
    public int Attribute;
    public IntPtr Data;
    public int SizeOfData;
}

public static class Win10Blur {
    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
}
"@
    }

    # ---------------------------------------------------------
    # WPF UI
    # ---------------------------------------------------------
    [xml]$xaml = (Get-Content "$ResourcesDir\PopupGUI.xml" -Raw -Encoding utf8)

    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

# Position the window at the bottom-right corner of the screen, avoiding the taskbar
$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
$taskbarHeight = [System.Windows.SystemParameters]::WindowCaptionHeight + [System.Windows.SystemParameters]::ResizeFrameHorizontalBorderHeight

$window.Left = $screenWidth - $window.Width - 10  # 10px margin from the right edge
$window.Top = $screenHeight - $window.Height - $taskbarHeight - 30  # 30px margin from the bottom edge

    $grid   = $window.FindName("MainGrid")
    $button = $window.FindName("ExitBTN")
    $MessageTextBlock = $window.FindName("MessageTextBlock")

    # ---------------------------------------------------------
    # Drag behavior - ONLY in MouseDown, remove the general window handler
    # ---------------------------------------------------------
    $grid.Add_MouseDown({
        if ($_.LeftButton -eq "Pressed") {
            $window.DragMove()
        }
    })

    # Button click
    $button.Add_Click({
        #[System.Windows.MessageBox]::Show("Finished!")
        $window.close()
        exit
    })

    # Hover opacity
    $window.Opacity = 0.5
    $window.Add_MouseEnter({ $window.Opacity = 1.0 })
    $window.Add_MouseLeave({
        if (-not $window.IsMouseOver) { $window.Opacity = 0.5 }
    })

    # ---------------------------------------------------------
    # Apply blur + shadow after hwnd exists
    # ---------------------------------------------------------
    $window.Add_SourceInitialized({
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle

        # Apply shadow
    #  [ShadowHelper]::ApplyShadow($hwnd)

        # Windows 7 Aero Glass
        if ($winMajor -eq 6 -and $winBuild -lt 9200) {
            $bb = New-Object Win7Blur+DWM_BLURBEHIND
            $bb.dwFlags = [Win7Blur]::DWM_BB_ENABLE
            $bb.fEnable = $true
            [Win7Blur]::DwmEnableBlurBehindWindow($hwnd, [ref]$bb) | Out-Null
        }
        # Windows 10 / 11 Acrylic / Blur
        elseif ($winMajor -ge 10) {
            $accent = New-Object AccentPolicy
            $accent.AccentState = [AccentState]::ACCENT_ENABLE_BLURBEHIND
            # For acrylic use: ACCENT_ENABLE_ACRYLICBLURBEHIND

            $accentSize = [System.Runtime.InteropServices.Marshal]::SizeOf($accent)
            $accentPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($accentSize)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($accent, $accentPtr, $false)

            $data = New-Object WindowCompositionAttributeData
            $data.Attribute = 19 # WCA_ACCENT_POLICY
            $data.SizeOfData = $accentSize
            $data.Data = $accentPtr

            [Win10Blur]::SetWindowCompositionAttribute($hwnd, [ref]$data) | Out-Null

            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($accentPtr)
        }
    })
#################################################################################################################
if ($null -ne $DSPConfig.processName) {
    if ($DSPConfig.processName -eq "Generic") {
        $ProcessName = "Generic"
    }
    else {
        $ProcessName = $DSPConfig.processName
    }
}
else {
    $ProcessName = "Generic"
}
if ($null -ne $DSPConfig.QDivider) {
    $QDivider = $DSPConfig.QDivider
}
if ($null -ne $DSPConfig.DecimalSeparator) {
    $DecimalSeparator = $DSPConfig.DecimalSeparator
}
else {
    $DecimalSeparator = $GlobalConfig.DecimalSeparator
}
if ($null -ne $DSPConfig.FreqDecimals) {
    $FreqDecimals = $DSPConfig.FreqDecimals
}
else {
    $FreqDecimals = $GlobalConfig.FreqDecimals
}
if ($null -ne $DSPConfig.QDecimals) {
    $QDecimals = $DSPConfig.QDecimals
}
else {
    $QDecimals = $GlobalConfig.QDecimals
}
if ($null -ne $DSPConfig.GainDecimals) {
    $GainDecimals = $DSPConfig.GainDecimals
}
else {
    $GainDecimals = $GlobalConfig.GainDecimals
}
if ($null -ne $DSPConfig.HotkeyOrDelayPreference) {
    $HotkeyOrDelayPreference = $DSPConfig.HotkeyOrDelayPreference
}
else {
    $HotkeyOrDelayPreference = $GlobalConfig.HotkeyOrDelayPreference
}
if ($null -ne $DSPConfig.TimeoutBeforePasteSecs) {
    $TimeoutBeforePasteSecs = $DSPConfig.TimeoutBeforePasteSecs
}
else {
    $TimeoutBeforePasteSecs = $GlobalConfig.TimeoutBeforePasteSecs
}
$StartingPositionHint = $DSPConfig.StartingPositionHint

Write-Host "`nUsing DSP Profile: $($DSPConfig.Description)" -ForegroundColor Green


if ($ProcessName -eq "Generic") {
    Write-Host "Using Generic profile. DSP software will not automatically shown in foreground." -ForegroundColor Yellow
    #Show-Notification -Title "REW EQ CopyPaste Assistant" -Message "Using Generic profile.`nWaiting for EQ data from REW in clipboard"
    $MessageTextBlock.Text = "Using Generic profile. DSP software will not automatically shown in foreground.`n`nWaiting for EQ data from REW in clipboard"
}
else {
    Write-Host "Found DSP process: $($ProfileSelectionResult.ProcessName)" -ForegroundColor Green
    # Show-Notification -Title "REW EQ CopyPaste Assistant" -Message "Found $($DSPConfig.Description) process: $($ProfileSelectionResult.ProcessName)`nWaiting for EQ data from REW in clipboard"
    $MessageTextBlock.Text = "Found $($DSPConfig.Description) process: $($ProfileSelectionResult.ProcessName)`n`nWaiting for EQ data from REW in clipboard"
}

#Write-Host "Hint: When finished with EQ close PowerShell window or hit ctrl-c and confirm exit" -ForegroundColor Yellow
Write-Host "Hotkey Or Delay Preference: $HotkeyOrDelayPreference" -ForegroundColor Cyan
Write-Host "Waiting for EQ data from REW in clipboard  " -ForegroundColor Yellow -NoNewline


$HotkeyIdPerform = 1
$HotkeyIdCancel = 2
Register-GlobalHotkey -HotkeyId $HotkeyIdPerform -Modifiers 0 -VirtualKeyCode ([System.Windows.Forms.Keys]::$EffectivePerformActionHotkey)
Register-GlobalHotkey -HotkeyId $HotkeyIdCancel -Modifiers 0 -VirtualKeyCode ([System.Windows.Forms.Keys]::$EffectiveCancelActionHotkey)




        $spinner = @('|', '/', '-', '\')
        $script:spinnerindex = 0

    $MainDispatcher = New-Object Windows.Threading.DispatcherTimer
    $MainDispatcher.Interval = [TimeSpan]::FromMilliseconds(300)
    $MainDispatcher.Add_Tick({






        # Check clipboard content
        $bufferHeader = $null
        $buffer = get-clipboard
        $bufferHeader = $($buffer -split "`n")[0]
        if ($bufferHeader -in "Configurable_PEQ", "Generic", "Extended") {

            [array]$bands = Read-EQText `
                -Text ($buffer | Out-String) `
                -QDivider $QDivider `
                -FreqDecimals $FreqDecimals `
                -QDecimals $QDecimals `
                -GainDecimals $GainDecimals `
                -DecimalSeparator $DecimalSeparator
        $MouseX = $null
        $MouseY = $null
        $keyToSend = $null
        $UserHasConfirmedAction = $false
        

                Set-Clipboard "Data has been read. Waiting for user confirmation to paste..."

            Write-host "`nFound EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. Confirm in dialog to paste it to DSP  " -ForegroundColor Yellow -NoNewline

            if ($ProcessName -ne "Generic") {
                Show-DSPWindowToFront -processName $ProcessName | Out-Null
            }

            if (($null -ne $DSPConfig.HotkeyOrDelayPreference) -and ($DSPConfig.HotkeyOrDelayPreference -eq "Hotkey")) {
                #Show-Notification -Title "REW EQ CopyPaste Assistant - Confirm" `
                #    -Message "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. $StartingPositionHint`nPress '$EffectivePerformActionHotkey' to proceed or '$EffectiveCancelActionHotkey' to cancel."
                $MessageTextBlock.Text = "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. $StartingPositionHint`nPress '$EffectivePerformActionHotkey' to proceed or '$EffectiveCancelActionHotkey' to cancel."
                $MessageTextBlock.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Render, [action]{} )
                Write-Host "Waiting for user to press '$EffectivePerformActionHotkey' to proceed or '$EffectiveCancelActionHotkey' to cancel. Timeout in $($GlobalConfig.HotkeyTimeoutSecs) seconds..." -ForegroundColor Yellow
                $hotkeyResult = $(Wait-HotkeyInput -TimeoutSecs $GlobalConfig.HotkeyTimeoutSecs -KeysToMonitor $($EffectivePerformActionHotkey, $EffectiveCancelActionHotkey) )
                switch ($hotkeyResult) {
                    "$EffectivePerformActionHotkey" {
                        $UserHasConfirmedAction = $true
                    }
                    "$EffectiveCancelActionHotkey" {
                        $UserHasConfirmedAction = $false
                    }
                    $null {
                        Write-Host "`nHotkey timeout reached after $($GlobalConfig.HotkeyTimeoutSecs) seconds. Paste action cancelled.  " -ForegroundColor Yellow -NoNewline
                        $MessageTextBlock.Text = "Hotkey timeout reached after $($GlobalConfig.HotkeyTimeoutSecs) seconds. Paste action cancelled."
                        $UserHasConfirmedAction = $false
                    }
                }
            }
           else {
                #Show-Notification -Title "REW EQ CopyPaste Assistant - Confirm" `
                #    -Message "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. Confirm in dialog to paste it to DSP"
                $MessageTextBlock.Text = "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. Confirm in dialog to paste it to DSP"
                Write-Host "Waiting for user confirmation dialog to proceed with paste..." -ForegroundColor Yellow
                $UserHasConfirmedAction = Show-ConfirmationDialog -StartingPositionHint $StartingPositionHint
            }
 
            if ($UserHasConfirmedAction -eq $true) {
                Write-Host "Proceeding with pasting EQ settings..." -ForegroundColor Yellow

                if ((($null -ne $DSPConfig.HotkeyOrDelayPreference) -and ($DSPConfig.HotkeyOrDelayPreference -ne "Hotkey")) `
                        -or (($null -eq $DSPConfig.HotkeyOrDelayPreference))) {
                    write-host "Waiting $($TimeoutBeforePasteSecs) seconds before auto-paste. $($DSPConfig.StartingPositionHint)" -ForegroundColor Yellow
                    Start-Sleep -Seconds $TimeoutBeforePasteSecs
                }

                # Check if mouse actions are defined in the profile
                $hasMouseAction = $DSPConfig.KeystrokeSequence | Where-Object {
                    $_.PSObject.Properties.Name -match '^mouse'
                }
                if ($null -ne $hasMouseAction) {
                    Write-Host "Mouse actions detected in profile. Make sure the DSP window is visible and not covered by other windows." -ForegroundColor Yellow
                    #Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste started" `
                    #     -Message "Make sure the DSP window is visible and not covered by other windows."
                    $MessageTextBlock.text = "CopyPaste started...`n`nMake sure the DSP window is visible and not covered by other windows."
                    $MouseX, $MouseY = Get-MousePosition
                    Write-Host "Current mouse position: X=$MouseX, Y=$MouseY" -foregroundColor blue
                }
                else {
                    Write-Host "No mouse actions detected in profile. Proceeding with keyboard input only." -ForegroundColor Yellow
                    #Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste started" -Message "Keyboard input started." -Timeout 1000
                    $MessageTextBlock.text = "CopyPaste started...`n`nKeyboard input started."
                }

                # Start pasting EQ bands with configured keystrokes and mouse actions
                foreach ($band in $bands) {
                    foreach ($KeySet in $DSPConfig.KeystrokeSequence) {
                        switch ($KeySet.PSObject.Properties.Name) {
                            "MouseChangePositionY" {
                                $MouseY += [int]$KeySet.MouseChangePositionY
                                Start-Sleep -Milliseconds $KeySet.Delay_ms
                                Write-Host -ForegroundColor Blue "New MouseY: $MouseY"
                            }
                            "MouseChangePositionX" {
                                $MouseX += [int]$KeySet.MouseChangePositionX
                                Start-Sleep -Milliseconds $KeySet.Delay_ms
                                Write-Host -ForegroundColor Blue "New MouseX: $MouseX"
                            }
                            "MouseClick" {
                                switch ($KeySet.MouseClick.ToLower()) {
                                    "left" {
                                        Invoke-MouseClickLeftAt -X $MouseX -Y $MouseY | Out-Null
                                        Start-Sleep -Milliseconds $KeySet.Delay_ms
                                        Write-Host -ForegroundColor Blue "Left click at X:$MouseX Y:$MouseY"
                                    }
                                    "right" {
                                        Invoke-MouseClickRightAt -X $MouseX -Y $MouseY | Out-Null
                                        Start-Sleep -Milliseconds $KeySet.Delay_ms
                                        Write-Host -ForegroundColor Blue "Right click at X:$MouseX Y:$MouseY"
                                    }
                                }
                            }
                            "MouseScrollUp" {
                                Invoke-MouseScrollUp -Amount $KeySet.MouseScrollUp
                                Start-Sleep -Milliseconds $KeySet.Delay_ms
                                Write-Host -ForegroundColor Blue "Mouse scroll up by $($KeySet.MouseScrollUp)"
                            }
                            "Invoke-MouseScrollDown" {
                                Invoke-MouseScrollDown -Amount $KeySet.MouseScrollDown
                                Start-Sleep -Milliseconds $KeySet.Delay_ms
                                Write-Host -ForegroundColor Blue "Mouse scroll down by $($KeySet.MouseScrollDown)"
                            }
                            "Keys" {
                                $keyToSend = $KeySet.Keys.Replace("FREQ", $band.freq).Replace("QVALUE", $band.Q).Replace("GAIN", $band.Gain).Replace("BANDNUMBER", $band.bandNumber)
                                Invoke-KeyStroke -Keys $keyToSend
                                Start-Sleep -Milliseconds $KeySet.Delay_ms
                                Write-Host -ForegroundColor Blue "Sent keystrokes: $keyToSend"
                            }
                        }
                    }
                }

                # Show transposed table of pasted bands
                # Show-TransposedTable -bands $bands | Format-Table -AutoSize
                Write-Host "Finished paste. Waiting for new data in clipboard  " -ForegroundColor Yellow -NoNewline
                #Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste finished" -Message "Waiting for new data in clipboard"
                $MessageTextBlock.text = "Finished paste.`n`nWaiting for new data in clipboard."
            }
            else {
                Write-Host "Cancelled by user or timedout. Waiting for new data in clipboard  " -ForegroundColor Yellow -NoNewline
                #Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste canceled" -Message "Cancelled by user or timedout. Waiting for new data in clipboard"
                $MessageTextBlock.text = "Cancelled by user or timedout.`n`nWaiting for new data in clipboard."
                Set-Clipboard "Canceled"
            }

        }
        Write-Host -NoNewline ("`b" + $spinner[$spinnerindex])
        #Write-Host $($script:spinnerindex)
        $script:spinnerindex = ($script:spinnerindex + 1) % $spinner.Length
    })  # Close the Add_Tick scriptblock
    $MainDispatcher.Start()

#################################################################################################################
    # Run

$window.Add_Closed({
    Unregister-GlobalHotkey -HotkeyId $HotkeyIdPerform
    Unregister-GlobalHotkey -HotkeyId $HotkeyIdCancel
})

    $window.ShowDialog() | Out-Null
    $MainDispatcher.Stop()
    Return $null
}

Export-ModuleMember -Function `
    Show-EditProfileGui, `
    Show-SelectProfileGui, `
    Show-PopupGUI
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
            QDevider                = 1
            QDecimals               = 1
            GainDecimals            = 1
            FreqDecimals            = 0
            DecimalSeparator        = "."
            TimeoutBeforePasteSecs  = 6
            StartingPositionHint    = ""
            HotkeyOrDelayPreference = "Hotkey"
            KeystrokeSequence       = @()
        }
    }

    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $ProfileSelectGUI = [Windows.Markup.XamlReader]::Load($reader)

    $ProfileSelectGUI.FindName("FileNameEdit").Text = (get-item $FilePath).BaseName

    # Populate form fields from the loaded JSON profile
    if ($null -ne $originalProfile.Description) { $ProfileSelectGUI.FindName("DescriptionEdit").Text = $originalProfile.Description }
    if ($null -ne $originalProfile.processName) { $ProfileSelectGUI.FindName("ProcessNameEdit").Text = $originalProfile.processName }
    if ($null -ne $originalProfile.FreqDecimals) { $ProfileSelectGUI.FindName("FreqDecimalsEdit").Text = $originalProfile.FreqDecimals.ToString() }
    if ($null -ne $originalProfile.QDecimals) { $ProfileSelectGUI.FindName("QDecimalsEdit").Text = $originalProfile.QDecimals.ToString() }
    if ($null -ne $originalProfile.GainDecimals) { $ProfileSelectGUI.FindName("GainDecimalsEdit").Text = $originalProfile.GainDecimals.ToString() }
    if ($null -ne $originalProfile.QDevider) { $ProfileSelectGUI.FindName("QDeviderEdit").Text = $originalProfile.QDevider.ToString() }
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
    $ProfileSelectGUI.FindName("Help").Add_Click({
            start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant/blob/main/DSPProfileFileFormat.md"
        })
    $ProfileSelectGUI.findname("SaveBTN").Add_Click({
            # Validate keystroke rows: if Action is mouseClick ensure Value is Left/Right
            try {
                if ($null -ne $keystrokeCollection) {
                    foreach ($it in $keystrokeCollection) {
                        if ($it.Action -eq 'mouseClick') {
                            if (($it.Value -ne 'Left') -and ($it.Value -ne 'Right')) { $it.Value = 'Left' }
                        }
                    }
                }
            }
            catch {
            }

            # Build the profile object from form data
            $profile = [ordered]@{
                version = "1.0"
            }

            # Basic fields
            if ($ProfileSelectGUI.FindName("DescriptionEdit").Text) {
                $profile.Description = $ProfileSelectGUI.FindName("DescriptionEdit").Text
            }
            if ($ProfileSelectGUI.FindName("ProcessNameEdit").Text) {
                $profile.processName = $ProfileSelectGUI.FindName("ProcessNameEdit").Text
            }

            # Decimals
            try { $profile.QDevider = [int]$ProfileSelectGUI.FindName("QDeviderEdit").Text } catch { $profile.QDevider = 1 }
            try { $profile.QDecimals = [int]$ProfileSelectGUI.FindName("QDecimalsEdit").Text } catch { $profile.QDecimals = 1 }
            try { $profile.GainDecimals = [int]$ProfileSelectGUI.FindName("GainDecimalsEdit").Text } catch { $profile.GainDecimals = 1 }
            try { $profile.FreqDecimals = [int]$ProfileSelectGUI.FindName("FreqDecimalsEdit").Text } catch { $profile.FreqDecimals = 0 }

            # Decimal separator
            if ($ProfileSelectGUI.FindName("DecimalSeparatorComma").IsChecked) {
                $profile.DecimalSeparator = ","
            }
            else {
                $profile.DecimalSeparator = "."
            }

            # Starting position hint
            if ($ProfileSelectGUI.FindName("StartingPositionEdit").Text) {
                $profile.StartingPositionHint = $ProfileSelectGUI.FindName("StartingPositionEdit").Text
            }

            # Hotkey or Delay preference
            if ($ProfileSelectGUI.FindName("DelaySelected").IsChecked) {
                $profile.HotkeyOrDelayPreference = "Delay"
                try { $profile.TimeoutBeforePasteSecs = [int]$ProfileSelectGUI.FindName("DelayEdit").Text } catch { $profile.TimeoutBeforePasteSecs = 6 }
            }
            else {
                $profile.HotkeyOrDelayPreference = "Hotkey"
                # Only include hotkey overrides if Override radio is checked
                if ($ProfileSelectGUI.FindName("HotkeyOverride").IsChecked) {
                    $actionIdx = $ProfileSelectGUI.FindName("ActionHotkeyCombo").SelectedIndex
                    $cancelIdx = $ProfileSelectGUI.FindName("CancelHotkeyCombo").SelectedIndex
                    if (($actionIdx -ge 0) -and ($actionIdx -lt 12)) {
                        $profile.ProfilePerformActionHotkey = "F$($actionIdx + 1)"
                    }
                    if (($cancelIdx -ge 0) -and ($cancelIdx -lt 12)) {
                        $profile.ProfileCancelActionHotkey = "F$($cancelIdx + 1)"
                    }
                }
            }

            # Build KeystrokeSequence from DataGrid
            $profile.KeystrokeSequence = @()
            if ($null -ne $keystrokeCollection) {
                foreach ($row in $keystrokeCollection) {
                    $ksItem = [ordered]@{}
                    switch ($row.Action) {
                        'keys' {
                            # Use the JSON property 'keys' (keystroke SendKeys string)
                            $ksItem.keys = [string]$row.Value
                        }
                        'mouseClick' {
                            $ksItem.mouseClick = [string]$row.Value
                        }
                        'mouseChangePositionX' {
                            $ksItem.mouseChangePositionX = [string]$row.Value
                        }
                        'mouseChangePositionY' {
                            $ksItem.mouseChangePositionY = [string]$row.Value
                        }
                    }
                    try { $ksItem.delay_ms = [int]$row.DelayMs } catch { $ksItem.delay_ms = 100 }
                    $profile.KeystrokeSequence += $ksItem
                }
            }

            # Save to file
            try {
                $jsonContent = $profile | ConvertTo-Json -Depth 10
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
            # Validate keystroke rows: if Action is mouseClick ensure Value is Left/Right
            try {
                if ($null -ne $keystrokeCollection) {
                    foreach ($it in $keystrokeCollection) {
                        if ($it.Action -eq 'mouseClick') {
                            if (($it.Value -ne 'Left') -and ($it.Value -ne 'Right')) { $it.Value = 'Left' }
                        }
                    }
                }
            }
            catch {
            }

            # Build the profile object from form data (same as Save)
            $profile = [ordered]@{
                version = "1.0"
            }

            if ($ProfileSelectGUI.FindName("DescriptionEdit").Text) {
                $profile.Description = $ProfileSelectGUI.FindName("DescriptionEdit").Text
            }
            if ($ProfileSelectGUI.FindName("ProcessNameEdit").Text) {
                $profile.processName = $ProfileSelectGUI.FindName("ProcessNameEdit").Text
            }

            try { $profile.QDevider = [int]$ProfileSelectGUI.FindName("QDeviderEdit").Text } catch { $profile.QDevider = 1 }
            try { $profile.QDecimals = [int]$ProfileSelectGUI.FindName("QDecimalsEdit").Text } catch { $profile.QDecimals = 1 }
            try { $profile.GainDecimals = [int]$ProfileSelectGUI.FindName("GainDecimalsEdit").Text } catch { $profile.GainDecimals = 1 }
            try { $profile.FreqDecimals = [int]$ProfileSelectGUI.FindName("FreqDecimalsEdit").Text } catch { $profile.FreqDecimals = 0 }

            if ($ProfileSelectGUI.FindName("DecimalSeparatorComma").IsChecked) {
                $profile.DecimalSeparator = ","
            }
            else {
                $profile.DecimalSeparator = "."
            }

            if ($ProfileSelectGUI.FindName("StartingPositionEdit").Text) {
                $profile.StartingPositionHint = $ProfileSelectGUI.FindName("StartingPositionEdit").Text
            }

            if ($ProfileSelectGUI.FindName("DelaySelected").IsChecked) {
                $profile.HotkeyOrDelayPreference = "Delay"
                try { $profile.TimeoutBeforePasteSecs = [int]$ProfileSelectGUI.FindName("DelayEdit").Text } catch { $profile.TimeoutBeforePasteSecs = 6 }
            }
            else {
                $profile.HotkeyOrDelayPreference = "Hotkey"
                if ($ProfileSelectGUI.FindName("HotkeyOverride").IsChecked) {
                    $actionIdx = $ProfileSelectGUI.FindName("ActionHotkeyCombo").SelectedIndex
                    $cancelIdx = $ProfileSelectGUI.FindName("CancelHotkeyCombo").SelectedIndex
                    if (($actionIdx -ge 0) -and ($actionIdx -lt 12)) {
                        $profile.ProfilePerformActionHotkey = "F$($actionIdx + 1)"
                    }
                    if (($cancelIdx -ge 0) -and ($cancelIdx -lt 12)) {
                        $profile.ProfileCancelActionHotkey = "F$($cancelIdx + 1)"
                    }
                }
            }

            $profile.KeystrokeSequence = @()
            if ($null -ne $keystrokeCollection) {
                foreach ($row in $keystrokeCollection) {
                    $ksItem = [ordered]@{}
                    switch ($row.Action) {
                        'keys' { $ksItem.keys = [string]$row.Value }
                        'mouseClick' { $ksItem.mouseClick = [string]$row.Value }
                        'mouseChangePositionX' { $ksItem.mouseChangePositionX = [string]$row.Value }
                        'mouseChangePositionY' { $ksItem.mouseChangePositionY = [string]$row.Value }
                    }
                    try { $ksItem.delay_ms = [int]$row.DelayMs } catch { $ksItem.delay_ms = 100 }
                    $profile.KeystrokeSequence += $ksItem
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
                        $jsonContent = $profile | ConvertTo-Json -Depth 10
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
        'QDecimalsEdit', 'GainDecimalsEdit', 'QDeviderEdit', 'StartingPositionEdit', 'DelayEdit')
    foreach ($name in $textBoxes) {
        $ctrl = $ProfileSelectGUI.FindName($name)
        if ($null -ne $ctrl) {
            $ctrl.Add_TextChanged($enableSaveButton)
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
        if ($hotkeyOverrideCtrl -ne $null) { $isOverride = $hotkeyOverrideCtrl.IsChecked }

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
        if ($keystrokesDG.ItemsSource -eq $null) {
            $keystrokeCollection = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'

            # Populate from loaded profile's KeystrokeSequence if available
            if (($null -ne $originalProfile) -and ($null -ne $originalProfile.KeystrokeSequence)) {
                #Write-Host "Loading KeystrokeSequence with $($originalProfile.KeystrokeSequence.Count) items" -ForegroundColor Cyan
                foreach ($ks in $originalProfile.KeystrokeSequence) {
                    # Determine the action type based on properties present
                    $action = 'keys'
                    $value = ''
                    $delayMs = 100

                    if ($null -ne $ks.keys) {
                        $action = 'keys'
                        $value = [string]$ks.keys  # Read as-is, these are SendKeys strings like ^a, {ENTER}, +{TAB}
                    }
                    elseif ($null -ne $ks.mouseClick) {
                        $action = 'mouseClick'
                        $value = [string]$ks.mouseClick
                    }
                    elseif ($null -ne $ks.mouseChangePositionX) {
                        $action = 'mouseChangePositionX'
                        $value = [string]$ks.mouseChangePositionX
                    }
                    elseif ($null -ne $ks.mouseChangePositionY) {
                        $action = 'mouseChangePositionY'
                        $value = [string]$ks.mouseChangePositionY
                    }

                    if ($null -ne $ks.delay_ms) {
                        $delayMs = $ks.delay_ms
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
                                        'mouseClick' {
                                            # Default to Left for mouse click
                                            $rowItem.Value = 'Left'
                                        }
                                        'mouseChangePositionX' {
                                            # Default to 0 for mouse move
                                            $rowItem.Value = '0'
                                        }
                                        'mouseChangePositionY' {
                                            # Default to 0 for mouse move
                                            $rowItem.Value = '0'
                                        }
                                        'keys' {
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
                Action  = 'keys'
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
                $ProfileSelectGUI.FindName('RemoveActionBTN').IsEnabled = ($keystrokesDG.SelectedItem -ne $null)
            })
        # initialize state
        $ProfileSelectGUI.FindName('RemoveActionBTN').IsEnabled = ($keystrokesDG.SelectedItem -ne $null)
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
        [Parameter(Mandatory = $true)][string]$ModulesDir
    )

    $result = [PSCustomObject]@{
        Action                       = "Cancel"
        SelectedProfile              = $null
        EffectivePerformActionHotkey = $GlobalPerformActionHotkey   # initialize to global defaults
        EffectiveCancelActionHotkey  = $GlobalCancelActionHotkey
        ProcessName                  = $null
        ProcessStatus                = $null
        REWStatus                    = $null
        AdminRightsRequired         =  "false"
    }

    # Load the XAML file
    [xml]$xaml = (Get-Content -Path "$ResourcesDir\ChooseProfileGUI.xml" -Raw -Encoding UTF8)

    # Parse the XAML to create the GUI
    Add-Type -AssemblyName PresentationFramework
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $ProfileEditGUI = [Windows.Markup.XamlReader]::Load($reader)

    # Set hotkey hint label
    $hotkeyHintLabel = $ProfileEditGUI.FindName("HotkeyHint")
    $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"

    # Populate the profiles list in the GUI
    $profileListBox = $ProfileEditGUI.FindName("ProfileList")
    $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
    foreach ($profileFileName in $DSPProfilesList) {
        $profileListBox.Items.Add($profileFileName.baseName) | Out-Null
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
                    $result.ProcessName = "n/a"
                    $result.ProcessStatus = "Not Running"
                }
                elseif ($DSPProcess.Count -gt 1) {
                    $ProfileEditGUI.FindName("ProcessStatus").foreground = "Red"
                    $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Expected 1 process, found: $($DSPProcess.Count)"
                    $result.ProcessName = "n/a"
                    $result.ProcessStatus = "Multiple Instances Found"
                }
                else {
                    if($result.AdminRightsRequired -eq "true"){ 
                        if(Get-RunningAsAdminFlag) {
                            $ProfileEditGUI.FindName("ProcessStatus").foreground = "Lime"
                            $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Found process: $($DSPProcess.ProcessName)"
                            $result.ProcessName = $DSPProcess.ProcessName
                            $result.ProcessStatus = "Running"
                        } else {
                            $ProfileEditGUI.FindName("ProcessStatus").foreground = "Purple"
                            $ProfileEditGUI.FindName("ProcessStatus").tooltip = "Admin rights are required to interact with $($DSPProcess.ProcessName). Please restart the Assistant with elevated privileges."
                            $result.ProcessName = $DSPProcess.ProcessName
                            $result.ProcessStatus = "Admin Rights Required"
                        }
                    } else {
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
                $ProfileEditGUI.FindName("REWStatus").tooltip = "REW is not running"
            }
            else {
                $rewWMIprocess = Get-WmiObject Win32_Process -Filter "name='roomeqwizard.exe'"
                if ($null -ne $rewWMIprocess) {
                    $checkpREWargs = $rewWMIprocess | Select-Object CommandLine
                    if ($checkpREWargs.CommandLine -notmatch "-api") {
                        $ProfileEditGUI.FindName("REWStatus").foreground = "Orange"
                        $ProfileEditGUI.FindName("REWStatus").tooltip = "Found process: $($REWProcess.ProcessName). API mode is not enabled."
                    }
                    else {
                        $ProfileEditGUI.FindName("REWStatus").foreground = "Lime"
                        $ProfileEditGUI.FindName("REWStatus").tooltip = "Found process: $($REWProcess.ProcessName). API mode is enabled."
                    }
                }
            }


        })
    $BGProcessCheck.Start()
    #Endregion
    # Assign event handlers
    $ProfileEditGUI.FindName("GitHub").Add_Click({
            start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant"
        })
    $ProfileEditGUI.FindName("Donate").Add_Click({
            start-process "https://paypal.me/IvanBakhmutovDonate"
        })
    $ProfileEditGUI.FindName("CloseBTN").Add_Click({
            $BGProcessCheck.Stop()
            $ProfileEditGUI.Close()
            #return
        })
    $ProfileEditGUI.FindName("NewProfileBTN").Add_Click({
        # Prompt user to save a new profile file
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.InitialDirectory = $DSPProfilesDir
        $saveFileDialog.Filter = "JSON files (*.json)|*.json"
        $saveFileDialog.Title = "Save New Profile"
        $saveFileDialog.FileName = "NewProfile.json"

        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $newProfilePath = $saveFileDialog.FileName

            # Populate the new file with default values
            $defaultProfile = [PSCustomObject]@{
                version                 = "1.0"
                Description             = "New Profile"
                processName             = "<DSP Software Name>"
                QDevider                = 1
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
            $editResult = Show-EditProfileGui -FilePath $newProfilePath

            # If the profile was saved, refresh the list and select the new item
            if ($null -ne $editResult -and ($editResult.Action -eq 'Saved' -or $editResult.Action -eq 'SavedAs')) {
                $ProfileEditGUI.FindName('ProfileList').Items.Clear()
                $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
                foreach ($profileFileName in $DSPProfilesList) {
                    $ProfileEditGUI.FindName('ProfileList').Items.Add($profileFileName.BaseName) | Out-Null
                }

                $savedBase = (Get-Item -LiteralPath $newProfilePath).BaseName
                $ProfileEditGUI.FindName('ProfileList').SelectedItem = $savedBase
            }
        }
    })
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
                $ProfileEditGUI.FindName('ProfileList').Items.Clear()
                $DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
                foreach ($profileFileName in $DSPProfilesList) { $ProfileEditGUI.FindName('ProfileList').Items.Add($profileFileName.BaseName) | Out-Null }

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
    $ProfileEditGUI.FindName("OKBTN").Add_Click({
            $selectedProfileFileName = $ProfileEditGUI.FindName("ProfileList").SelectedItem
            if($result.AdminRightsRequired -eq "true"){
               <#if (-not Get-RunningAsAdminFlag) {
                    try {
                        Add-Type -AssemblyName PresentationCore,PresentationFramework -ErrorAction SilentlyContinue
                        $ButtonType   = [System.Windows.MessageBoxButton]::OK
                        $MessageIcon  = [System.Windows.MessageBoxImage]::Error
                        $MessageBody  = "Selected DSP profile requires administrative privileges. Please run the script as an administrator."
                        $MessageTitle = "Administrative Privileges Required"
                        [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon) | Out-Null
                    }
                    catch {
                        Write-Host "Selected DSP profile requires administrative privileges. Please run the script as an administrator." -ForegroundColor Red
                    }
                }#>
            }
            if ($null -ne $selectedProfileFileName) {
                $result.Action = "Open"
                $result.SelectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
                $BGProcessCheck.Stop()
                $ProfileEditGUI.Close()
            }
        })

    $ProfileEditGUI.FindName("ProfileList").Add_SelectionChanged({
            $selectedItem = $ProfileEditGUI.FindName("ProfileList").SelectedItem
            if ($null -ne $selectedItem) {
                $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
                try {
                    # Read-JSONFile now returns the parsed JSON object or throws on error
                    $profileJson = Read-JSONFile -FilePath $profilePath -ErrorAction Stop

                    # Show nicely formatted JSON in the text box
                    $profileContent = $profileJson | ConvertTo-Json -Depth 10
                    $ProfileEditGUI.FindName("ProfileText").Text = $profileContent
                    $result.processName = $profileJson.processName
                    if($null -ne $profileJson.AdminRightsRequired) {
                        $result.AdminRightsRequired = $profileJson.AdminRightsRequired
                    } else {
                        $result.AdminRightsRequired = "false"
                    }
                    $ProfileEditGUI.FindName("OKBTN").IsEnabled = $true
                    $ProfileEditGUI.FindName("EditBTN").IsEnabled = $true

                    # Use $profileJson directly for hotkey decisions
                    if (($profileJson.ProfilePerformActionHotkey -ne $GlobalPerformActionHotkey) -and
                        ($null -ne $profileJson.ProfilePerformActionHotkey)) {
                        $result.EffectivePerformActionHotkey = $profileJson.ProfilePerformActionHotkey
                    }
                    else {
                        $result.EffectivePerformActionHotkey = $GlobalPerformActionHotkey
                    }

                    if (($profileJson.ProfileCancelActionHotkey -ne $GlobalCancelActionHotkey) -and
                        ($null -ne $profileJson.ProfileCancelActionHotkey)) {
                        $result.EffectiveCancelActionHotkey = $profileJson.ProfileCancelActionHotkey
                    }
                    else {
                        $result.EffectiveCancelActionHotkey = $GlobalCancelActionHotkey
                    }

                    $hotkeyHintLabel.Content = "Hotkeys: Perform - $($result.EffectivePerformActionHotkey), Cancel - $($result.EffectiveCancelActionHotkey)"
                    if (($GlobalPerformActionHotkey -ne $result.EffectivePerformActionHotkey) -or
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
                    $ProfileEditGUI.FindName("ProfileText").Text = "Error parsing JSON profile. Please check the file."
                    $ProfileEditGUI.FindName("OKBTN").IsEnabled = $false
                    $ProfileEditGUI.FindName("EditBTN").IsEnabled = $false
                }
            }
            else {
                $ProfileEditGUI.FindName("ProfileText").Text = "Please select a profile"
                $ProfileEditGUI.FindName("OKBTN").IsEnabled = $false
                $ProfileEditGUI.FindName("EditBTN").IsEnabled = $false
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

    $ProfileEditGUI.Add_Closed({
            return
        })

    # Show the GUI
    $ProfileEditGUI.ShowDialog() | Out-Null
    return $result
}


Export-ModuleMember -Function `
    Show-EditProfileGui, `
    Show-SelectProfileGui
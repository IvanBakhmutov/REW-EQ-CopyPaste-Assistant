## DSP Profile file format

### Keystrokes and mouse actions

There are four action types supported in the KeystrokeSequence: `MouseClick`, `MouseChangePositionX`, `MouseChangePositionY`, and `Keys`.

`Keys` emulates keyboard input. Four keywords — `FREQ`, `GAIN`, `QVALUE` and `BANDNUMBER` — will be replaced with the actual values for the current band before the keys are sent. `BANDNUMBER` is unique to Zapco ADSP software where you have to type band number, but may be used in other software as well. Common navigation key codes (used by many DSP UIs) include: `{ENTER}`, `{TAB}`, `{LEFT}`, `{RIGHT}`, `{UP}`, `{DOWN}`.<br>
To send modifier combinations use SendKeys notation:<br>
`^` = Ctrl (example: `^a` is Ctrl+A to select all),<br>
`+` = Shift (example: `+{TAB}` is Shift+Tab),<br>
`%` = Alt (example: `%{F4}` is Alt+F4 - this is just an example, don't put it in your DSP profile)<br>
For a complete list of SendKeys codes see the Microsoft docs: [learn.microsoft.com](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys?view=windowsdesktop-9.0) <br><br>
`MouseChangePositionX` and `MouseChangePositionY` accept integer values. Values are relative to the current cursor position: positive numbers move the cursor right/down, and negative numbers move it left/up (screen origin is top-left).<br><br>
When the Windows display scale is not 100%, the assistant now automatically adjusts these offsets based on the detected scale factor (for example 125% or 150%). This means profiles that were calibrated for 100% scaling generally keep working on scaled displays without requiring manual edits.<br><br>
`MouseClick` accepts two values: `left` and `right`.<br><br>
`MouseClickHold` accepts two values: `left` and `right`.<br><br>
`MouseClickRelease` accepts two values: `left` and `right`.<br><br>
`MouseScroll` - mouse wheel scrolling. The value can include `FREQ`, `GAIN`, `QVALUE`, and `BANDNUMBER`, which will be replaced with actual values. The number of steps per scroll is specified after a `;` character. If the step number is not provided, it defaults to `1`. For example, if the action value in the profile is `GAIN;0.5` and the `Gain (dB)` in REW for a given filter is 3.2, the tool will replace the `GAIN` keyword with 3.2, divide it by 0.5, and round the result to the nearest integer: `round(3.2/0.5, 0) = 6`. Since the result is positive, it will perform 6 scroll-up actions. Another example: if the profile value is `GAIN;0.2` and the filter value in REW is -4, the result will be 20 scroll-down actions. Pay attention to dalay_ms - DSP software may not process fast scrolling and this may lead to less values. You'll have to increase the delay in case of inaccuracies.<br>

### Settings of DSP software

`processName` can be set to `Generic` this will allow to run the script without specific DSP app selected. In this case DSP software will not be automatically moved to foreground and you will have to bring it forward manually.<br>

`QDivider` is used to adjust Q values when the predefined generic EQ profiles with Q/WB format in the REW app do not match the Q format used in the DSP. Default value is 1, leave it default unless you know what you are doing.<br>

### Sample DSP profile with comments

| Json element | Description |
| :---- | ---- |
| `{` | |
| `"Description": "<Human readable name of the app and DSPs it can work with>",` | *Display message of a selected DSP profile when the script is running; does not affect functionality.* |
| `"processName": "<Windows process name, wildcards accepted>",` | *Once you run your DSP software, open Task Manager → Details and find its process name.<br>Even though you launch SomeDSPApp.exe, the actual process name may differ<br>(for instance, you might see SomeDSPConfigV4 in the list of tasks).<br>This happens because the executable you run may act as a wrapper or archive<br>that extracts and launches another binary internally.<br>So, what will work is just SomeDSP* * |
| `"QDivider": 1,` | *A Divider of a Q value: 1 if Q should remain the same;<br>>1 will divide REW Q and paste smaller values in the DSP;<br><1 pastes greater values.* |
| `"FreqDecimals": 1,` | *Number of decimal places for Frequency values.* |
| `"QDecimals": 1,` | *Number of decimal places for Q values.* |
| `"GainDecimals": 1,` | *Number of decimal places for Gain values.* |
| `"DecimalSeparator": ".",` | *Decimal separator used in the DSP software (e.g., `.` or `,`).*|
| `"TimeoutBeforePasteSecs": 6,` | *How much time the script waits before sending keystrokes.*|
| `"StartingPositionHint": "Please select 1 band Freq box",` | *A hint message — I'm guessing some DSPs may have a different first parameter than Freq.<br>Just a message; does not affect functionality.* |
| `"HotkeyOrDelayPreference": "Hotkey",` | *Determines whether the script uses hotkeys or a delay to confirm actions.* |
| `"ProfilePerformActionHotkey": "F5",` | *Hotkey to confirm the paste action. Used to override a hotkey from global config.* |
| `"ProfileCancelActionHotkey": "F6",` | *Hotkey to cancel the paste action. Used to override a hotkey from global config.* |
| `"AdminRightsRequired": true,` | *Should be True if the DSP software requires admin priveledges.* |
| `"KeystrokeSequence": [` | *Array of keystrokes, with delays between them.* |
| `{` | |
| `"keys": "FREQ{ENTER}{DOWN}QVALUE{ENTER}{DOWN}GAIN{ENTER}",` | *Described above* |
| `"delay_ms": 200` | |
| `},` | |
| `{` | |
| `"mouseClick": "left",` | *Simulates a left mouse click. Options are left and right.* |
| `"delay_ms": 50` | |
| `},` | |
| `{` | |
| `"MouseChangePositionY": "+25",` | *Moves the mouse cursor N pixels up/down. Coordinates of the screen start from top left.* |
| `"delay_ms": 10` | |
| `}` | |
| `{` | |
| `"MouseChangePositionX": "-10",` | *Moves the mouse cursor N pixels left/right. Coordinates of the screen start from top left.* |
| `"delay_ms": 10` | |
| `}` | |
| `]` | |
| `}` | |
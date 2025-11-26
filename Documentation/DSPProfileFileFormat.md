## DSP Profile file format

There are four action types supported in the KeystrokeSequence: `mouseClick`, `mouseChangePositionX`, `mouseChangePositionY`, and `keys`.

`mouseChangePositionX` and `mouseChangePositionY` accept integer values. Values are relative to the current cursor position: positive numbers move the cursor right/down, and negative numbers move it left/up (screen origin is top-left).  
`mouseClick` accepts two values: `left` and `right`.  
`keys` emulates keyboard input. Four keywords — `FREQ`, `GAIN`, `QVALUE` and `BANDNUMBER` — will be replaced with the actual values for the current band before the keys are sent. `BANDNUMBER` is unique to Zapco ADSP software where you have to type band number, but may be used in other software as well. Common navigation key codes (used by many DSP UIs) include: `{ENTER}`, `{TAB}`, `{LEFT}`, `{RIGHT}`, `{UP}`, `{DOWN}`.  
To send modifier combinations use SendKeys notation:  
`^` = Ctrl (example: `^a` is Ctrl+A to select all),  
`+` = Shift (example: `+{TAB}` is Shift+Tab),  
`%` = Alt (example: `%{F4}` is Alt+F4 - this is just an example, don't put it in your DSP profile)  

For a complete list of SendKeys codes see the Microsoft docs: [learn.microsoft.com](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys?view=windowsdesktop-9.0)*  

`processName` can be set to `Generic` this will allow to run the script without specific DSP app selected. In this case DSP software will not be automatically moved to foreground and you will have to bring it forward manually.  

`QDivider` is used to adjust Q values when the predefined generic EQ profiles with Q/WB format in the REW app do not match the Q format used in the DSP. Default value is 1, leave it default unless you know what you are doing.

Sample DSP profile with comments:  

| Json element | Description |
| :---- | ---- |
| `{` | |
| `"Description": "<Human readable name of the app and DSPs it can work with>",` | *Display message of a selected DSP profile when the script is running; does not affect functionality.*  |
| `"processName": "<Windows process name, wildcards accepted>",` | *Once you run your DSP software, open Task Manager → Details and find its process name.<br>Even though you launch SomeDSPApp.exe, the actual process name may differ<br>(for instance, you might see SomeDSPConfigV4 in the list of tasks).<br>This happens because the executable you run may act as a wrapper or archive<br>that extracts and launches another binary internally.<br>So, what will work is just SomeDSP* *  |
| `"QDivider": 1,` | *A Divider of a Q value: 1 if Q should remain the same;<br>>1 will divide REW Q and paste smaller values in the DSP;<br><1 pastes greater values.* |
| `"FreqDecimals": 1,` | *Number of decimal places for Frequency values.*  |
| `"QDecimals": 1,` | *Number of decimal places for Q values.*  |
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
| `"mouseClick": "left",` | *Simulates a left mouse click. Options are left and right.*  |
| `"delay_ms": 50` | |
| `},` | |
| `{` | |
| `"mouseChangePositionY": "+25",` | *Moves the mouse cursor N pixels up/down. Coordinates of the screen start from top left.*  |
| `"delay_ms": 10` | |
| `}` | |
| `{` | |
| `"mouseChangePositionX": "-10",` | *Moves the mouse cursor N pixels left/right. Coordinates of the screen start from top left.* |
| `"delay_ms": 10` | |
| `}` | |
| `]` | |
| `}` | |
## DSP Profile file format

`{`  
`"version": "1.0",` *// not used yet, ignored so far.*  
`"Description": "<Human readable name of the app, for simplicity>",` *// A display message of a selected DSP profile when the script is running; does not affect functionality.*  
`"processName": "<Windows process name, wildcards accepted>",` *// Once you run your DSP software, open Task Manager → Details and find its process name.  
// Even though you launch SomeDSPApp.exe, the actual process name may differ  
// (for instance, you might see SomeDSPConfigV4 in the list of tasks).  
// This happens because the executable you run may act as a wrapper or archive  
// that extracts and launches another binary internally.  
// So, what will work is just SomeDSP* *  
`"QDevider": 1,` *// A divider of a Q value: 1 if Q should remain the same;  
// >1 will divide REW Q and paste smaller values in the DSP;  
// <1 pastes greater values.*  
`"QDecimals": 1,` *// Number of decimal places for Q values.*  
`"GainDecimals": 1,` *// Number of decimal places for Gain values.*  
`"DecimalSeparator": ".",` *// Decimal separator used in the DSP software (e.g., `.` or `,`).*  
`"TimeoutBeforePasteSecs": 6,` *// How much time the script waits before sending keystrokes.*  
`"StartingPositionHint": "Please select 1 band Freq box",` *// A hint message — I'm guessing some DSPs may have a different first parameter than Freq.  
// Just a message; does not affect functionality.*  
`"HotkeyOrDelayPreference": "Hotkey",` *// Determines whether the script uses hotkeys or a delay to confirm actions.*  
`"ProfilePerformActionHotkey": "F5",` *// Hotkey to confirm the paste action. Used to override a hotkey from global config.*  
`"ProfileCancelActionHotkey": "F6",` *// Hotkey to cancel the paste action. Used to override a hotkey from global config.*  
`"KeystrokeSequence": [` *// Array of keystrokes, with delays between them.*  
`{`  
`"keys": "FREQ{ENTER}{DOWN}QVALUE{ENTER}{DOWN}GAIN{ENTER}",`*// 3 keywords here FREQ, GAIN and QVALUE will be replaced with actual values for selected band. Keys like ENTER, TAB or DOWN are in curly brackets, full list - [learn.microsoft.com](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys?view=windowsdesktop-9.0)*  
`"delay_ms": 200`  
`},`  
`{`  
`"mouseClick": "left",` *// Simulates a left mouse click.*  
`"delay_ms": 50`  
`},`  
`{`  
`"mouseChangePositionY": "+25",` *// Moves the mouse cursor N pixels up/down. Coordinates of the screen start from top left.*  
`"delay_ms": 10`  
`}`  
`{`  
`"mouseChangePositionX": "-10",` *// Moves the mouse cursor N pixels left/right. Coordinates of the screen start from top left.*  
`"delay_ms": 10`  
`}`  
`]`  
`}`
# REW-EQ-CopyPaste-Assistant

# Description

Room EQ Wizard EQ Copy-Paste Assistant script for unlisted DSP brands.

Room EQ Wizard (REW) includes several predefined profiles for popular DSP models, and some DSP software allows you to paste EQ settings directly from REW. However, many DSP applications don’t support this feature, requiring you to enter the values manually. This is where this assistant script comes in. It assists with the EQ copy-paste procedure from REW software into your DSP app's EQ settings. You just need to run it in the background while working with REW EQ settings and ensure your DSP software is running. When you are ready with EQ filters, hit the "Copy" button in the EQ filters section of REW. This tool will then prompt you to confirm if you want to paste the copied data into your DSP app. After your confirmation, it will bring the DSP process to the foreground, and you will need to click on the first band where the keystroke sequence will start to paste the data.

The script uses its own profiles (in JSON format), which store the DSP software application name (wildcards `*` are accepted), the keystroke sequence for inputting the data into the DSP, and the Q divider. The Q divider is used to adjust Q values when the predefined generic EQ profiles with Q/WB format in the REW app do not match the Q format used in the DSP. Check the examples in the `./DSPProfiles` folder. Keystroke sequences can contain `{ENTER}`, `{RIGHT}`, `{LEFT}`, `{UP}`, `{DOWN}`, `{TAB}`, etc., depending on how navigation through EQ bands is implemented in your DSP software.

This is just an initial version of the tool. Experiment with it, create your own DSP profiles, and have fun!
Once you tested your own DSP profile please share it in the Discussion section of the repository so it will be added to the repo.

If the PowerShell execution policy on your Windows machine is set to "Restricted," you can run the `.bat` file, which will execute the PowerShell process and run the script. Otherwise, you can run the `.ps1` file directly. The choice is yours.

A demo video [https://youtu.be/s-LkXFBM7A4](https://youtu.be/s-LkXFBM7A4)

Special thanks to Denis GS for the ideas and collaboration!

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
`"TimeoutBeforePasteSecs": 6,` *// How much time the script waits before sending keystrokes.*  
`"StartingPositionHint": "Please select 1 band Freq box",` *// A hint message — I'm guessing some DSPs may have a different first parameter than Freq.  
// Just a message; does not affect functionality.*  
`"KeystrokeSequence": [` *// Array of keystrokes, with delays between them.*  
`{`  
`"keys": "FREQ{ENTER}{DOWN}QVALUE{ENTER}{DOWN}GAIN{ENTER}",`  
`"delay_ms": 200`  
`},`  
`{`  
`"keys": "{RIGHT}{UP}{UP}",`  
`"delay_ms": 200`  
`}`  
`]`  
`}`  

## Change log

06-11-2025:
Changed the QDevider value in the ESXToolkit.json profile to 1, as tests in the car showed that the actual Q format is RBJ Q (Half Gain). The visual EQ graph in ESX Toolkit may be misleading. It seems the GUI developers might not have consulted the hardware team regarding the algorithm used to generate the graph.

For proper AutoEQ in REW that works correctly with your DSP, you need to determine the minimum and maximum values for Frequency, Q, and Gain, and then create a configurable EQ in REW.

Let’s take ESX Toolkit as an example:
<p align="center">
    <img src="Resources/ESXToolkit-EQ-ranges.png" alt="ESXToolkit EQ ranges" width=300 />
    <img src="Resources/Configurable_PEQ-for-ESXToolkit.png" alt="Configurable_PEQ for ESXToolkit" width=481 />
</p>
In a such case REW will calculate EQ using correct EQ settings which suit for ESX Toolkit. 

Side note: ESX Toolkit won’t allow you to enter values outside the supported range. For example, if you’re adjusting the Gain of a selected band and try to input -13, it will accept -1 and then stop—you won’t be able to type the 3, and the value will remain -1 (since the minimum allowed value is -12).
This is why a configurable EQ in REW is necessary; otherwise, the tool would paste incorrect settings into the DSP.
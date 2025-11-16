# REW-EQ-CopyPaste-Assistant

[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


# Description

Room EQ Wizard EQ Copy-Paste Assistant script for DSP software which not captures EQ settings from clipboard.

Room EQ Wizard (REW) includes several predefined profiles for popular DSP models, and some DSP software allows you to paste EQ settings directly from REW. However, many DSP applications don’t support this feature, requiring you to enter the values manually. This is where this assistant script comes in. It assists with the EQ copy-paste procedure from REW software into your DSP app's EQ settings. You just need to run it in the background while working with REW EQ settings and ensure your DSP software is running. When you are ready with EQ filters, hit the "Copy" button in the EQ filters section of REW. This tool will then prompt you to confirm if you want to paste the copied data into your DSP app. After your confirmation, it will bring the DSP process to the foreground, and you will need to click on the first band where the keystroke sequence will start to paste the data.
Isn't it better to do manipulations with imported DSP settings file directly? The answer is - no. You shouldn’t mess with an imported DSP settings file — it’s safer that way and helps avoid file corruption. Just watch what’s being passed to the settings. Some DSP files aren’t plain text; for example, ESX settings files are password-protected and look binary inside.

This is just an initial version of the tool. Experiment with it, create your own DSP profiles, and have fun!
Strong suggestion, when you create profile for a DSP which doesn't fully support keyboard navigation and you are dealing with mouse moves and clicks and you would like to share your profile with others - leave the DSP app in its native resolution, don't make it maximized to a full screen (on different devices screen resolution may vary).
Once you tested your own DSP profile please share it in the Discussion section of the repository so it will be added to the repo.

If the PowerShell execution policy on your Windows machine is set to "Restricted," you can run the `.bat` file, which will execute the PowerShell process and run the script. Otherwise, you can run the `.ps1` file directly. The choice is yours.

A demo video <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png?20240107144800" alt="YouTube icon" height=12/> [watch on YouTube](https://youtu.be/s-LkXFBM7A4)

Special thanks to Denis GS for the ideas and collaboration!

Support this project <img src="https://upload.wikimedia.org/wikipedia/commons/b/b7/PayPal_Logo_Icon_2014.svg" alt="PayPal icon" height=12/> **[PayPal](https://paypal.me/IvanBakhmutovDonate)**

### Tested profiles

Some DSP profiles were already tested and added to `./DSPProfiles`
| Brand | DSP Software | DSP devices |
| :---- | ---- | ---- |
| ESX | ESX Toolkit | D66SP, QM66SP, D68SP, VE900.7SP, QL810SP, QL812SP, VE1300.11SP, QE812SP |
| Hellion | Hellion DSP software | (to be verified) |
| Musway | MUSWAY DSP V1.08 | M4+, M6, M6v2, DSP68PRO |
| Musway | MUSWAY TUNEST_PC_V1.* | M4, M4+V3, M4+V4, M6V3, M6V4, D8V3, D8V4, DSP68, TUNE12, M6PRO, M12, M5, M10, M8 |
| Nakamichi | Nakamichi-K | NDSK4265AU |
| Nakamichi | Nakamichi-K | NDSK4065AU, NDSK4165AU |
| Nakamichi | Nakamichi-K | NDSK4085AU, NDSK4185AU, NDSK4285AU |
| Phoenix | Phoenix Gold DSP software | (to be verified) |
| Sennuopu | Sennuopu DP-X680 PC Software EN | DP-X680 |
| Zapco | PC Program (Windows) for ADSP series | ADSP-Z8 IV AT, ADSP-Z8 IV-6AT, ADSP-Z12 IV-10A, ADSP-Z16 IV-12A |
| Awave | DSP PC Tool | DSPA6, DSP12DMAX, DSP16DMAX, DSPA6II, DSP6V5,  DSPM6, DSPA8D, DSPA10II, DSP10D, DSP10DMAX, DSPT10, DSP8.1, DSPA12, DSPA12D, DSPA12D PRO, DSP12DMAXII, DSPA16D, DSPA16DMAXII,DSPA24D |

## DSP Profile file format

The script uses its own profiles (in JSON format), which store the DSP software application name (wildcards `*` are accepted), the keystroke sequence for inputting the data into the DSP, and the Q divider. The Q divider is used to adjust Q values when the predefined generic EQ profiles with Q/WB format in the REW app do not match the Q format used in the DSP. Check the examples in the `./DSPProfiles` folder. Keystroke sequences can contain mouse actions or key actions like`{ENTER}`, `{RIGHT}`, `{LEFT}`, `{UP}`, `{DOWN}`, `{TAB}`, etc., depending on how navigation through EQ bands is implemented in your DSP software. [More details](DSPProfileFileFormat.md)

## Change log

### 16-11-2025:

Added Awave DSP profile for variety of models.

Tests with Zapco DSP software showed we need a new variable for each band with the band number. The keyword for it in keystrokes is `BANDNUMBER`. The reason - with Zapco software you have to select band by typing its number (handy, innit?). So I updated the main script to work with the new variable, updated the module which parses data from REW. During testing also noticed weird behaviour as in the DSP software decimals number and step settings, so I eventually come up with the following Configurable PEQ in REW:  
<img src="Resources/ZAPCO ADSP-Z16 IV-12A.png" alt="Configurable_PEQ for Zapco ADSP" width=481 />  
And only after this it started to work fine. So for now ADSP series is fine.

### 14-11-2025:
MUSWAY TUNEST_PC_V1.* Profile added, DSPs list: M4 / M4+V3 / M4+V4 / M6V3 / M6V4 / D8V3/ D8V4 / DSP68 / TUNE12 / M6PRO / M12 / M5 / M10 / M8

Added 3 separate profiles for Nakamichi-K DSP software:  
Nakamichi-K 31-Band EQ with ONLY GAINS (NDSK4265AU)  
Nakamichi-K 15-Band EQ (NDSK4065AU / NDSK4165AU)  
Nakamichi-K 31-Band EQ (NDSK4085AU / NDSK4185AU / NDSK4285AU)  
For Nakamichi keep eye what it performs, I tried to implement some workarounds in the profile. Timeouts tweaking may be needed in your case.

### 13-11-2025:
Hotkeys now as an option to start input (delay option remains in the script, but now it depends on how profile is configured).

Global config with default values.

Musway DSP v1.08 profile added (M4+ / M6 / M6v2 / DSP68PRO) <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png?20240107144800" alt="YouTube icon" height=12/> [watch on YouTube](https://youtu.be/70nI_DrytnA?si=IY8tHfrHuXiwoZ2I)

### 12-11-2025:
GUI for profile selection added. Event notification popups added. GUI demo <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png?20240107144800" alt="YouTube icon" height=12/> [watch on YouTube](https://www.youtube.com/watch?v=ccjcXb-yxC0)

Increased Phoenix Gold timeout before input as DSP software for some reason restores windowed mode instead of staying in maximized mode.

### 11-11-2025:
Tested Phoenix Gold software with mouse'n'keyboard input <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png?20240107144800" alt="YouTube icon" height=12/> [watch on YouTube](https://www.youtube.com/watch?v=EdCybWHxmO4)

### 10-11-2025:
Back on track - account has been unblocked.

Implemented psm modules and floating point rounding, configurable decimal separator.

Testing in excel was not a bad idea, currently testing mouse operations, this will cover majority of DSPs.

### 09-11-2025:
Working on new features and testing the tool with variety of DSP software. I'll open donates just not to miss the train, absolutely not necessary from your end, but I will be happy.

### 08-11-2025:
Great news! I’ve received positive feedback — a few people have already tested the tool, and the responses are encouraging.

There are, however, some questions regarding certain DSP software (**Awave**, **Musway**, and **Nakamichi**). In these programs, navigating through bands with the `{TAB}` key doesn’t move to the next setting within the same band; instead, it jumps to the next band. For example, it loops through all Freq values first, then all Q values, and finally all Gain values. To handle this behavior properly, some adjustments in the code will be needed.

Another thing worth mentioning: in some DSPs, when you place the cursor in a field (for example, Freq), the text inside isn’t automatically selected. As a result, typing or pasting will append characters to the existing text instead of replacing it. To avoid this, you can send the `^a` keystroke (which corresponds to Ctrl+A) to select all text in the field before typing or pasting.

### 06-11-2025:
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
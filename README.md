# REW-EQ-CopyPaste-Assistant
Room EQ Wizard EQ Copy-Paste Assistant script for unlisted DSP brands.

Room EQ Wizard (REW) has several predefined profiles for popular DSP models, allowing EQ settings to be easily copied to the DSP software directly from REW. However, for unlisted models, this assistant script comes into play. It assists with the EQ copy-paste procedure from REW software into your DSP app's EQ settings. You just need to run it in the background while working with REW EQ settings and ensure your DSP software is running. When you are ready with EQ filters, hit the "Copy" button in the EQ filters section of REW. This tool will then prompt you to confirm if you want to paste the copied data into your DSP app. After your confirmation, it will bring the DSP process to the foreground, and you will need to click on the first band where the keystroke sequence will start to paste the data.

The script uses its own profiles (in JSON format), which store the DSP software application name (wildcards `*` are accepted), the keystroke sequence for inputting the data into the DSP, and the Q divider. The Q divider is used to adjust Q values when the predefined generic EQ profiles with Q/WB format in the REW app do not match the Q format used in the DSP. Check the examples in the `./DSPProfiles` folder. Keystroke sequences can contain `{ENTER}`, `{RIGHT}`, `{LEFT}`, `{UP}`, `{DOWN}`, `{TAB}`, etc., depending on how navigation through EQ bands is implemented in your DSP software.

This is just an initial version of the tool. Experiment with it, create your own DSP profiles, and have fun!

If the PowerShell execution policy on your Windows machine is set to "Restricted," you can run the `.bat` file, which will execute the PowerShell process and run the script. Otherwise, you can run the `.ps1` file directly. The choice is yours.

A demo video [https://youtu.be/s-LkXFBM7A4](https://youtu.be/s-LkXFBM7A4)

Special thanks to Denis GS for the ideas and collaboration!

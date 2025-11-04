# REW-EQ-CopyPaste-Assistant
Room Eq Wizard EQ Copy-Paste assistant script for unlisted DSP brands.


REW has several predefined profiles for popular DSP models, so EQ settings can be easily copied to
the DSP software directly from REW. 
But for unlisted models this assistant script comes to play. Assists with EQ copy paste procedure 
from Room EQ Wizard (REW) software into your DSP EQ settings.
It uses its own profiles (json format) where is stored DSP Software application name (wildcards *
are accepted), keystroke sequence how to input the data to DSP, and Q devider. The last one is 
used for adjustment of Q values when predefined generic EQ profiles with Q/WB format in REW is not
matching with Q format used in the DSP. Check examples in DSPProfiles folder.

This is just initial version of the tool. Play with it, create your own DSP profile, have fun!

If in your Windows machine PowerShell execution policy set to restricted you can run .bat file and
it will run powerhsell process and run the script. Otherwise you can run .ps1 file directly, it is
up to you.

Thanks for Denis GS the ideas and collaboration!

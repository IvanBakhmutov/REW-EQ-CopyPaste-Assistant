# Items to do

## Finished
- ~~GUI for editing profiles~~
- ~~Update json file help in readme~~
- ~~Double click on selected profile in the list to open it~~
- ~~JSON profile file format validation on load, as a function in the module~~
- ~~AdminRightsRequired check for some DSP brands~~
- ~~Freq decimals in configs~~
- ~~Generic profile. Script update to handle it~~
- ~~admin flag in profile edit gui needs to be added~~
- ~~Transposed output isn't showing all bands, to be fixed - removed~~
- ~~Mouse pointer highlight before copypaste - not needed~~
- ~~Review logic behind hotkey or delay choice global vs dsp config~~
- ~~Review console and popup messages, some popup messages removed~~
- ~~Remove "True" word output in console when a mouse pointer operation happens, check why keystroke output is missing~~
- ~~Configurable PEQ guidelines for each profile in a separate text box~~
- ~~Mouse/KB action names with capital letters~~
- ~~Profile search filter.~~
- ~~Right pane with 2 tabs: 1. Welcome when started and Overview when profile selected, 2. profile plain text~~
- ~~Store the last selected profile and select it on the next startup~~
- ~~Version check on startup~~
- ~~Floating small semi-transperent window to show notifications instead of windows pop-ups with stop tool button~~
- ~~Test the tool and transperancy of the main window on Win7/8.1/10/11~~
- ~~Pictures on buttons instead of characters, icon/logo for the tool~~
- ~~Windows should appear in the center of the screen~~
- ~~Mouse Scroll up/down actions to be added~~
- ~~BUG: hotkeys hint not updated on Profile Choose GUI after a new profile saved~~
- ~~Reported issue with confirmation dialog (in parallels desktop)~~
- ~~Add flags in config to skip REW and DSP processes check. Implemented in ver 0.5.3~~

## Immediate plans

- Mouse drag actions to be implemented, functions for this are already created
- Profile Editor extra button switch for DSP process name, custom/generic

## Future plans

- New DSP profiles

## Ideas to be reviewed
- Folders with brand names for DSP profiles?
- Experimental: (for the future to consider as still cannot see use case) - Direct integration with REW API (roomeqwizard.exe -api) to get EQ bands, so no copy to clipboard would be needed. [proof of concept](Modules/dev/REW-API-Experimental.ps1)<br>
    Breakdown of the idea: the tool checks "Get-WmiObject Win32_Process -Filter "name='roomeqwizard.exe'" | Select-Object CommandLine" if it has -api argument. If it is - direct api connection:<br>
    In case if it it running with -api arg, then<br>
    - Check API connectivity on the tool startup, notification if roomeqwizard.exe runs in API enabled mode
    - GET /measurements/selected-uuid
    - GET /measurements/{id}/filters
    - Filter EQ bands leaving only ones with PK filters
    - wait for hotkey and then proceed with DSP software inputs<br>
Otherwise - backward compatibility with manual hit copy button on EQ window and then proceeding with hotkeys/delays.
- Check all suitable processes if there are any matches with DSP software and suggest options

## DSP profiles list to check
 ~~ESX~~,<br>
 ~~Musway~~,<br>
 ~~Nakamichi~~,<br>
 ~~Zapco ADSP~~,<br>
 ~~Phoenix Gold~~,<br>
 ~~Awave~~,<br>
 ~~Onkyo R-MS~~,<br>
 ~~Awave DSP (Awave DSP PC Software)~~,<br>
 ~~Best Balance DSP (Best Balance DSP Tool)~~,<br>
 ~~Sennuopu DSP (Sennuopu DSP Tool)~~,<br>
 ~~Down4Sound (JP DSP) (JP DSP PC Software)~~,<br>
Audison (bit One, bit Nove, Forza) (Audison bit Tune / bit One Software / AF Forza DSP Tool),<br>
Mosconi / Gladen (6to8, PRO, Aerospace) (Mosconi DSP Tool),<br>
Rockford Fosgate (DSR1, 3sixty.3) (Rockford Fosgate PerfectTune / 3sixty Software),<br>
ARC Audio (PS8 / PS8-Pro) (ARC Audio PS8 Software),<br>
JL Audio (TwK-88, VXi series) (JL Audio TüN), - not possible to automate<br>
AudioControl (DM-608, DM-810) (DM Smart DSP),<br>
Light Audio (Light Audio DSP Software),<br>
MadBit (MadBit DSP Tool),<br>
Контур DSP (Контур DSP Software),<br>
Tonemix DSP (Tonemix DSP Software),<br>
URAL (новые DSP) (URAL DSP PC Tool),<br>
Ground Zero DSP (GZ DSP PC Software), - 3 DPSs covered, the rest later<br>
Hertz H8 DSP (Hertz H8 DSP Software),<br>
Focal (FSP-8 and others) (Focal FSP-8 DSP Tool),<br>
Stetsom / Banda DSP (Stetsom DSP Software / Banda DSP Manager),<br>
JIB DSP (JIB DSP Software),<br>
Zapco HDSP,<br>
Mobridge (https://mobridge.us/mobridge-dsp/),<br>
JIB DSP,<br>
Goldhorn<br>
and others

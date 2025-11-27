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
- ~~ Right pane with 2 tabs: 1. Welcome when started and Overview when profile selected, 2. profile plain text~~
## Immediate plans

- Reported issue with confirmation dialog (in parallels desktop)
- Store the last selected profile and select it on the next startup.

## Future plans
- Experimental: Direct integration with REW API (roomeqwizard.exe -api) to get EQ bands, so no copy to clipboard would be needed.  [proof of concept](Modules/REW-API-Experimental.ps1)  
    Breakdown of the idea: the tool checks "Get-WmiObject Win32_Process -Filter "name='roomeqwizard.exe'" | Select-Object CommandLine" if it has -api argument. If it is - direct api connection:  
    In case if it it running with -api arg, then  
    - Check API connectivity on the tool startup, notification if roomeqwizard.exe runs in API enabled mode
    - GET /measurements/selected-uuid
    - GET /measurements/{id}/filters
    - Filter EQ bands leaving only ones with PK filters
    - wait for hotkey and then proceed with DSP software inputs  
Otherwise - backward compatibility with manual hit copy button on EQ window and then proceeding with hotkeys/delays.
- Experimental: Try to make this script to connect to REW API to set default Configurable PEQ with DSP model specific options http://127.0.0.1:4735/eq/default-equaliser
  
## Ideas to be reviewed
- Folders with brand names for DSP profiles?

## DSP profiles list to check
 ~~ESX~~,  
 ~~Musway~~,  
 ~~Nakamichi~~,  
 ~~Zapco ADSP~~,  
 ~~Phoenix Gold~~,  
 ~~Awave~~,  
 ~~Onkyo R-MS~~,  
 ~~Awave DSP (Awave DSP PC Software)~~,  
 ~~Best Balance DSP (Best Balance DSP Tool)~~,  
Audison (bit One, bit Nove, Forza) (Audison bit Tune / bit One Software / AF Forza DSP Tool),  
Mosconi / Gladen (6to8, PRO, Aerospace) (Mosconi DSP Tool),  
Rockford Fosgate (DSR1, 3sixty.3) (Rockford Fosgate PerfectTune / 3sixty Software),  
ARC Audio (PS8 / PS8-Pro) (ARC Audio PS8 Software),  
JL Audio (TwK-88, VXi серия) (JL Audio TüN),  
AudioControl (DM-608, DM-810) (DM Smart DSP),  
Down4Sound (JP DSP) (JP DSP PC Software),  
Light Audio (Light Audio DSP Software),  
MadBit (MadBit DSP Tool),  
Контур DSP (Контур DSP Software),  
Tonemix DSP (Tonemix DSP Software),  
URAL (новые DSP) (URAL DSP PC Tool),  
Sennuopu DSP (Sennuopu DSP Tool),  
Ground Zero DSP (GZ DSP PC Software),  
Hertz H8 DSP (Hertz H8 DSP Software),  
Focal (FSP-8 and others) (Focal FSP-8 DSP Tool),  
Stetsom / Banda DSP (Stetsom DSP Software / Banda DSP Manager),  
JIB DSP (JIB DSP Software),  
Zapco HDSP,  
Mobridge (https://mobridge.us/mobridge-dsp/),  
JIB DSP,  
Goldhorn  
and others

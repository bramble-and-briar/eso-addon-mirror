Chat Palette 1.0.0
By @TheGreyWolf98. No external dependencies.

Open /chatcolours, /chatcolors or /palette.
D-pad selects channel; LT/RT pages.
A opens the hex editor: select the field, enter six hexadecimal digits
(optional #), then select Apply colour. Example: #FF3333.
LB/RB chooses a preset; X applies it to the selected channel.
Y resets that channel to ESO's default and removes its shared override.
B closes. Invalid input does not change a colour.

Supported channels: Say, Yell, Zone, Group, incoming and outgoing whispers,
Guild 1-5, Officers 1-5, Emotes and System.
Only edited channels become account-wide overrides; other channels are untouched.
Overrides save per account/server and reapply after character login or zone
activation. Guild/officer colours follow slots 1-5, not individual guild names.
Check new chat messages after applying colours; existing messages may retain their
original colours. Colours affect your own display, not how others see messages.
Disabling the addon does not restore colours already applied. Use Y to reset
individual channels before disabling if you want ESO defaults.

Xbox testing confirmed custom colours and persistence on a newly created character.
Uses dedicated chat-category colour APIs, with no external libraries.

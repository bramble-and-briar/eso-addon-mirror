Apostrophe Name Fix 0.2.0

Purpose
ESO can supply a unit name containing a literal backslash before an apostrophe,
while supplying a clean version of the same name through chat events. This
addon filters GetRawUnitName and GetUnitName for all unit tags, including
player, group members, and reticle targets. It removes one or more consecutive
backslashes immediately before an ASCII apostrophe. It leaves ordinary
apostrophes, accents, other backslashes, and name descriptors such as ^Mx intact.

Installation
Place the ApostropheNameFix folder directly in your ESO live/AddOns directory.
It should contain ApostropheNameFix.txt and ApostropheNameFix.lua.
Reload the UI with /reloadui and check that Apostrophe Name Fix is enabled.
If a newly added folder is not discovered, restart ESO and enable the addon.
There are no dependencies and no saved variables. API version: 101051.

Commands
/anf                  Show status and the count of corrected getter results.
/anf check            Compare original/current names with apostrophes in your
                      player and group unit data, including byte values.
/anf check group7     Inspect a particular unit; group indices can change.
/anf check player     Inspect your own character.
/anf check reticleover Inspect the unit under your reticle.
/anf off              Disable normalization for this UI session and refresh.
/anf on               Enable normalization and refresh.
/anf refresh          Rebuild the roster and refresh built-in unit-frame names.
/anf share            Prepare an editable draft containing a temporary /script
                      fix someone without the addon can paste on their client.
/anf travel           Prepare a native account-based travel command for others
                      to travel to you while grouped.
/anf travel group7    Prepare that travel command for a particular group member.
                      Also accepts player or reticleover.

Helping players without the addon
See SHARING.txt for the exact temporary script and sharing instructions.
Both sharing commands only fill the chat entry in your current channel. You
choose whether to copy the draft elsewhere or press Enter to send it. The
recipient explicitly runs the command; received chat text is never executed.
The temporary patch lasts until logout or UI reload. The travel command uses
the account name and needs neither an addon nor Lua, but does not fix labels.

Live verification
1. Run /anf check. An affected name should show BS=1 (or higher) in 'before'
   and BS=0 in 'after', with the apostrophe (byte 39) and descriptor preserved.
2. Open the group window and inspect the character name.
3. Try the normal group-menu Travel to Player action yourself.
4. Use /anf off and /anf on for an immediate comparison.
   Off is session-only: a UI reload enables the patch again.
The addon never initiates travel or sends chat messages.

How it works
The addon captures the current getters and wraps their return values at file
load. It calls GROUP_LIST_MANAGER:RefreshData() and UNIT_FRAMES:UpdateNames()
on player activation and after toggling, so the built-in roster and travel
menu use newly read names. Disabling normalization leaves pass-through wrappers
installed to preserve any later addon hooks. To remove the wrappers completely,
disable the addon in ESO and reload the UI.

Scope and limits
Each player who wants persistent correction needs to install it. Alternatively,
they can run the temporary patch for their current UI session. This changes
Lua-facing unit names, not server data. It does not rewrite chat events, @account names,
guild/friend name APIs, house APIs, or outgoing travel calls. Addons that captured
old getter functions before this addon loaded, or cache their own name data,
may bypass it; there is no guaranteed load order between unrelated addons.
Old rendered chat lines are not rewritten. Housing uses separate account-name
APIs and is not claimed fixed by this patch. If replacing these API globals
causes protected-function errors in an untested UI path, disable this addon and
reload the UI to remove the wrappers completely.

Evidence and sources
Observed: group and own-player raw names contained byte 92 before byte 39;
group chat and emote sender names did not. The clean formatters preserved the
correct chat name.
Group roster reads both patched getters:
https://github.com/esoui/esoui/blob/live/esoui/ingame/group/zo_grouplist_manager.lua
Travel to Player reads the cached characterName:
https://github.com/esoui/esoui/blob/live/esoui/ingame/group/keyboard/zo_grouplist_keyboard.lua
Roster refresh rebuilds the list and marks views dirty:
https://github.com/esoui/esoui/blob/live/esoui/ingame/contacts/socialmanager.lua
Built-in unit-frame name refresh:
https://github.com/esoui/esoui/blob/live/esoui/ingame/unitframes/unitframes.lua

Validation
Lua 5.1 mock tests cover name preservation, repeated escapes, all-unit scope,
getter arguments/return shape, nested getters, roster refresh, reversible
toggles, coexistence with later wrappers, and local-only diagnostics. Sharing
tests cover draft limits, no automatic sending/travel, and the exact temporary
script on a client without this addon, including repeated execution.
The user verified version 0.1.0 in the running game: the two affected UI views
displayed the corrected name and normal right-click Travel to Player succeeded.
Version 0.2.0 retains that patch and adds sharing helpers. The sharing UI and
temporary script have mock validation but still need recipient-side live testing.

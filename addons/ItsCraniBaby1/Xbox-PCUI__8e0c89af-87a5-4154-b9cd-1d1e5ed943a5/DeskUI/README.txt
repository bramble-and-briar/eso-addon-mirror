DeskUI 0.6.0 - Expanded PC-Style Menus
======================================
Experimental mouse-and-keyboard interface for ESO Xbox Play Anywhere on Windows.
API 101050/101051. No external libraries, downloaded fonts or textures required.

OPENING / REPLACING THE ORIGINAL MENUS
Alt opens/closes DeskUI. Supported default menu shortcuts now open DeskUI by
default, using the existing bindings for Inventory, Character, Skills, Champion,
Journal, Collections, Map, Group, Friends, Guilds, Mail and Help. Rebinding the
original action should carry through automatically. Pressing the same category
shortcut again closes DeskUI. Alt still works if shortcut replacement is off.

System > Settings > Replace supported menu shortcuts turns replacement off/on.
Emergency commands: /deskui shortcuts off and /deskui shortcuts on.
Replacement suspends in DeskUI search boxes and outside the HUD/DeskUI scenes;
text focus and native dialogs are checked before routing an action. Original
Esc/system behavior and unsupported menu shortcuts are retained. This is menu
routing, not modification of game files or replacement of every game interaction.
Actual Xbox shortcut inheritance/focus handling needs an in-game check.

The Original button at upper right deliberately opens the current category's
native menu for actions not yet rebuilt. If that bridge is unavailable, turn
replacement off and use the normal menu key. System > Original inventory also
remains available. Vendor/crafting/trade/loot interactions remain native.

NEW BROWSE / DETAIL PAGES
Skills: skill types > discovered lines > abilities, descriptions and status.
Champion: disciplines > stars, saved points and current descriptions. Read-only
list/detail view; the animated constellation canvas is not reconstructed.
Collections: Collectibles, Stories, Housing, Outfit Styles and Tales of Tribute
Patrons use separate category specializations. Browse categories/subcategories,
unlock details and descriptions. Hidden locked entries respect native flags.
Friends: Friends/Ignored pages show status, character details and notes.
Guilds: Home/Roster/Ranks pages let you choose a guild and inspect its data.
Group & Activity Finder: current Group roster, roles and member details.
Mail: opens a shared mailbox session and lists personal inbox messages. Select
Read message to request a body; this may mark it read. Late responses are matched
to the requested message. Leaving/closing DeskUI releases its mailbox session.
Help: Tutorials and Emotes list titles, descriptions and emote chat commands.
Journal: adds Antiquities category/lead/recovery summaries and unlocked Cadwell
Silver/Gold zone objectives alongside Quests, Lore Library and Achievements.
Map: read-only tiles and player marker for ESO's currently selected map. Does
not alter shared map selection. No pan/zoom, map selection, quest/POI pins,
waypoint setting or fast travel yet.

Pages share the PC-inspired icon bar, child navigation, textured borders,
selected-row artwork, fonts, searchable lists and scrollable details. Each page
retains its browsing path. Root categories remember their last visited subpage.
Drag headers to move panels; /deskui reset restores default positions.

WHAT IS STILL NATIVE / UNFINISHED
New browse pages do not spend skill/Champion points, respec, slot abilities,
activate collectibles, teleport, edit ranks/notes, send messages, invite/kick
players, queue for activities, send/delete mail or take attachments. Use Original
for these functions. Guild inbox broadcasts are not included in the personal
mail viewer. Scrying and the full Antiquities codex reader remain native.
Scribing, Set Items, guild tools/heraldry/history, activity queues, customer
support, Leaderboards, Rumors, stores, Crown Crates, Tamriel Tomes, Alliance War
and Notifications are not rebuilt. Unimplemented tabs/categories stay dimmed.
Settings covers DeskUI preferences/basic audio; full settings and keybindings
remain in ESO's Esc menu. Exact screen-specific PC artwork/geometry, full native
tooltips and the framed 3D character preview remain in development.

EXISTING FEATURES
Backpack Items search/filter/sort with ten categories and equipped comparisons.
Inventory actions and other inventory modes remain native. Rings compare with
Ring 1, weapons with the active bar. Values are vendor prices, not market prices.
Level/Champion progression, draggable saved panels, quest assisting, collected
lorebook text, achievement criteria, audio controls and native logout confirmation
remain included. Account CP does not change an under-50 character's level label.

COMMANDS / SAVING
/deskui toggles. /deskui journal, /deskui quests, /deskui settings open those pages.
/deskui diag prints version/capabilities. /deskui reset resets panel positions.
Positions/preferences use DeskUI_Saved. Reload/log out normally to save them;
force-closing ESO can lose recent changes. Do not upload saved-variable files.

UPLOADING / CHECKING
Select E:\DeskUI in the directory-only uploader, not the ZIP. Include all 12
files, including new Menus.lua and Map.lua, alongside DeskUI.addon.
Create version 0.6.0 under the existing add-on, update/download it in ESO and
fully restart. /deskui diag should report 0.6.0.

Local Lua 5.1 mock-runtime checks cover expanded browsing, hidden/locked data,
progression, stale guild paths, mail request/selection/session safety, map fallback,
shortcut settings/focus/dialog/scene guards, native-menu escape, and prior features.
The required engine function names/signatures were checked against the published
API 101051 source. Manifest/XML/package file structure and exact contents are
checked. This does not establish that every API/art asset/action-layer behavior
works on Xbox. Actual rendering, inheritance of keys, focus, mail and persistence
need an in-game test. Previews use sample data and placeholder artwork.
If something fails, record the full error and /deskui diag output. Alt and the
shortcut-off command provide recovery; disabling DeskUI restores native behavior.

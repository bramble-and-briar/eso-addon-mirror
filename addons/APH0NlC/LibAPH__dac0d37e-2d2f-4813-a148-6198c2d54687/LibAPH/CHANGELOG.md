LibAPH - Changelog
====================

Version: 2026.10.18.01.41 (26101801)
---------------------------

Menus
  - Changed where menus open: beside their window, on the side with the most room where the whole menu fits, so they stay on screen.
  - Fixed submenus opening off screen: they now open on the left when there is no room on the right.
  - Fixed controller focus leaving the visible part of a menu. Moving past the last or first visible row now scrolls the menu along.

Controller & Console
  - Added a shared controller layer: one add-on window has the buttons at a time, opening another takes them over, and closing it hands them back to the window used before. Buttons the window does not use go to the game, and dialogs always get theirs.
  - Added controller button hints that wrap without overlapping, follow the window while it is resized, and draw just above the add-on's own windows so window text never covers them.
  - Fixed keys in LibAPH's own layer firing while a dialog is on screen. They now give way, so text fields can always be selected and typed in.
  - Fixed the hint text in empty edit boxes on console, which now uses the gamepad font.

Status Line & Memory Display
  - Added a one-line status text for the top right of the screen or under another control such as the compass, where lines from several add-ons stack instead of overlapping.
  - Added a display of Lua and add-on pool memory at the top right, on PC and console.
  - Fixed Cyrillic and Japanese text not showing in the status window, which now uses the game's font faces.

Memory Cleanup
  - Added a low-memory callback on console, fired when the game warns that add-on memory is low, plus a check of how close the add-on memory is to its limit.
  - Added a shared low-memory rescue on console: it cleans in small steps every frame until add-on memory is back under 65% of the limit, adds a Deep Clean above 80% when the steps fall behind, and keeps going in combat. Only the add-on that calls it starts it, and a second add-on joins the running one.
  - Updated cleanup results to say why the cleanup ran (for example "lowmem" for the console's Low Add-On memory warning).

Saved Data
  - Added packing for long number lists in saved data, which makes them several times smaller.
  - Added seals for finished results, so a number edited in the saved file shows as changed.
  - Added crash copies, which keep unfinished work through a crash or disconnect and tell the add-on on the next load what cut it off.

Text & Graphs
  - Added text fitting: wrap text to fit, shrink one-line text until it fits, and keep text above graph lines.
  - Improved list rows and search results, which shrink their font instead of cutting off long names.
  - Added graphs, drawn from pooled pieces, with round axis steps and time ticks.

Game Settings & Travel
  - Added FPS cap controls that read and set the cap and keep Limit Background FPS and Idle Power Reduction off while an add-on measures.
  - Added a count of running add-ons and libraries.
  - Added house travel: a list of houses to travel to, and a jump with a callback when it fails.

Settings Menu
  - Added the settings panel as a menu (checkboxes, choices, typed numbers, buttons that ask first) for players without the settings libraries.

Technical Style & Logic
  - Improved work spread over frames. It stops before the game's per-frame add-on CPU limit on every platform that has one, and slows down while the add-on memory pool is nearly full.
  - Added a time-left check for long steps, so one large piece of work no longer runs past the limit.

Version: 2026.10.07.17.24 (26100717)
---------------------------

  - Slash commands can be shown or hidden.
  - Other add-ons can run the Auto Lua Memory Cleaner cleanup methods, and Auto Lua Memory Cleaner shows those cleanups.

Version: 2026.10.07.07.01 (26100707)
---------------------------

  - Fixed shrinking button text falling back to the default font at its smallest sizes; it now steps down through the game's own fonts.
  - Profiles can now be remembered per character.
  - Menu entries can show a tooltip beside the menu when you point at them.
  - Long lists of choices can be grouped into scrollable submenus, with the current choice marked.

Version: 2026.10.06.07.36 (26100607)
---------------------------

  - Initial public release.
# kozy-eso BuildPort

Copy the `KozyEsoBuildPort` folder to `Documents\Elder Scrolls Online\live\AddOns\`, enable it (allow
out-of-date addons if needed), then type `/kozyexport` in game. Your browser opens the Build Editor import page.

- Key binding (assigned in the game, addons cannot set keys themselves): Esc > Settings > Controls > Add-Ons > kozy-eso BuildPort > "Open build in kozy-eso".
- Settings panel (Settings > Add-ons) and the addon itself require the library LibAddonMenu-2.0 (install it from ESOUI).
- `/kozyexport dump` saves the scribing catalogue and skill lines to SavedVariables (type /reloadui afterwards).
- `/kozyexport api <text>` lists game API functions containing the text (e.g. `/kozyexport api scrib`).
- `/kozyexport debug` prints the raw payload and any API error in the chat (use it to report problems).
- If the browser does not open or the link is too long, the last payload is saved in
  `SavedVariables\KozyEsoBuildPort.lua` after `/reloadui`; paste it on https://kozy-eso.com/build-editor/import.
- English game client only (names are matched in English).

Upgrading from the old `KozyBuildExport` folder: delete that folder from `AddOns` first.

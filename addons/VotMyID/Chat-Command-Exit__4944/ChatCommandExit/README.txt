Chat Command Exit — version 1.1.4

AI disclosure
This addon was developed with AI-assisted code generation. The author has tested the commands in ESO. The addon uses only built-in ESO API functions and has no external dependencies.

Commands
/groupout   — leave the current group.
/dangeout   — alias for /dengeout (compatibility with the spelling used in the published description).
/dungeonout — English alias for /dangeout.
/gdtout     — leave the group first, then request instance exit after a 1-second delay.

No startup chat messages are displayed.

Credits and sources
The command behavior uses the built-in ESO API functions GroupLeave() and ExitInstanceImmediately(). No source code from another addon was copied. The code and packaging were prepared with AI assistance (ChatGPT / OpenAI).

Installation/update
Extract the ChatCommandExit folder into:
Documents\Elder Scrolls Online\live\AddOns\

Changelog
1.1.4
- Made the addon table local; no addon-specific global variable is created.
- Deferred slash-command registration until EVENT_ADD_ON_LOADED for this addon.
- Removed startup chat output.
- Added /gdtout combined command with a 1-second delay between leaving group and exiting instance.
- Added /dangeout compatibility alias.
- Added AI disclosure and credits.

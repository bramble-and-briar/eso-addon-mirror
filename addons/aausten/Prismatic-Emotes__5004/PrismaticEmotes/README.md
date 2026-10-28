# PrismaticEmotes

**Version:** 1.0.0 (first stable release)  
**Game:** The Elder Scrolls Online (PC/Mac, keyboard chat)  
**ESO API:** 101051 (Update 51 / Season One)  
**External dependencies:** None (pChat optional)

PrismaticEmotes automatically assigns a readable, persistent color to each character who writes a roleplay emote. Colors are stored locally and account-wide. With optional mention highlighting enabled (the default), a previously encountered character's full name is also highlighted in their assigned color when mentioned in another emote.

## Installation

Unzip into your ESO AddOns folder so the manifest is located at:

```
Documents/Elder Scrolls Online/live/AddOns/PrismaticEmotes/PrismaticEmotes.txt
```

On Linux/Proton, locate the ESO prefix's `Documents/Elder Scrolls Online/live/AddOns` directory (or the directory to which you have symlinked it). The ZIP contains a top-level `PrismaticEmotes` folder. Enable the addon in ESO's Add-Ons menu, then use `/reloadui` if the game was already running.

## Example

Before:

```
Leiadriel Milandris watches the travelers crossing the bridge.
Eirnich turns toward Leiadriel Milandris.
```

After: Leiadriel's name and her emote body use her assigned color; Eirnich's name and his own emote body use his separate color. When Eirnich mentions Leiadriel, her name is highlighted in her color, while the rest stays Eirnich's color.

## Commands

| Command | Action |
|---|---|
| `/pe help` | Show available commands |
| `/pe status` | Show settings and formatter status |
| `/pe on` / `/pe off` | Enable or disable chat recoloring |
| `/pe mode both` | Color author and emote body (default) |
| `/pe mode author` | Only color the author; mentions still configurable |
| `/pe mode body` | Color emote body only; mentions still configurable |
| `/pe mentions on` / `/pe mentions off` | Enable or disable full-name mention highlighting (on by default) |
| `/pe color "Leiadriel Milandris" #89C3F7` | Give a character a manually selected color |
| `/pe auto "Leiadriel Milandris"` | Restore their automatically assigned color |
| `/pe list` | Show up to 20 known characters and their colors |
| `/pe forget "Leiadriel Milandris"` | Forget one character's color |
| `/pe forget all` | Forget all saved colors (immediate; no confirmation) |
| `/pe preview` | Show a three-character preview in chat (does not save assignments) |
| `/pe rehook` | Reattach after another addon replaced our chat formatter |

`/prismaticemotes` is an alias of `/pe`.

Mention highlighting is **on by default**. Use `/pe mentions off` to disable it or `/pe mentions on` to enable it again. This toggle does not change author/emote-body coloring or remove saved character colors.

### Custom character colors

Use the character's full name followed by a six-digit RGB hex color:

```text
/pe color "Leiadriel Milandris" #89C3F7
/pe color M'aiq-do #E69BBD
/pe color "Élodie d'Aubépine" 76DCEB
```

Double quotes around the name are optional, even for names with spaces. Everything before the final color token is treated as the name; internal spaces, apostrophes, hyphens, accented letters, and other punctuation are preserved literally. The color accepts uppercase or lowercase hex digits, with or without `#`. Empty names, unclosed double quotes, and invalid colors show usage without changing saved colors.

You can set a color before encountering the character. Overrides are saved account-wide and apply to subsequent emotes and recognized mentions; they do not recolor existing chat messages. Use `/pe auto "Leiadriel Milandris"` to restore the original automatic color, or `/pe forget "Leiadriel Milandris"` to remove the saved assignment. Both commands accept the same optional double quotes.

## Behavior and design

- **Player-written text emotes only**: `/e`, `/me`, and `/emote` use ESO's `CHAT_CHANNEL_EMOTE`. Animated emotes such as `/dance`, NPC speech, normal chat channels, and whispers are not recolored.
- **Automatic colors**: New characters are hashed into a curated palette, avoiding already assigned exact colors. Once used up, additional pastel RGB colors are generated. Colors are persistent within the account; they are not global or synchronized with other clients.
- **Character-name normalization**: ESO's internal grammatical suffixes, such as `^Fx` and `^Mx`, are removed before names are saved, listed, or matched. Existing saved names are migrated automatically on login or `/reloadui`, retaining their colors and automatic restore values. Duplicate entries are merged, preferring manual overrides; the existing clean-name entry wins ties. No `/pe forget all` reset is needed.
- **Mention recognition**: A character must have appeared as the author of an emote (or been manually assigned a color) before mentions of them can be recognized. Names are matched as complete names with ASCII case folding; complex language-specific case conversions and nicknames are not implemented.
- **Chat integration**: The addon wraps the currently registered `EVENT_CHAT_MESSAGE_CHANNEL` formatter **after** `EVENT_PLAYER_ACTIVATED`, allowing pChat's formatter to run first. We preserve the original formatter's return values, link destinations, timestamps, narration and channel metadata.
- **Conservative formatting**: Recoloring the body requires finding its original text verbatim in the existing formatter's output. If another addon rewrites the body, PrismaticEmotes leaves that portion unchanged. Link destinations and texture/color markup are never searched for character-name mentions.
- **Fail-open**: A formatting exception logs one warning and returns the previous addon's original formatted text.
- **Privacy**: Nothing is transmitted or shared with other players. All settings live in ESO's SavedVariables.

## Limitations / known issues

- A third-party addon that registers a chat formatter **after** PrismaticEmotes may replace its wrapper. Try `/pe rehook`; this is a shared ESO chat-formatter limitation, not something we can guarantee against for every addon/load order.
- Author names shown via player hyperlinks are color-wrapped without editing hyperlink targets. ESO's client decides final link rendering; validate with your active chat addons in-game.
- Text containing complex embedded formatting can override the surrounding message color. Item links remain intact and their visible text is not treated as character-name mentions.
- The palette favors dark-theme readability but does not guarantee accessible contrast for all chat backgrounds or vision profiles.
- Account-wide `characters` assignments may grow with very large roleplay histories; there is no automatic expiry.
- No in-game settings panel or color picker; use slash commands.

## Development and tests

Source files are loaded in this order: `Core.lua`, `Palette.lua`, `Markup.lua`, `Chat.lua`, `Commands.lua`. The pure color/markup modules and a simulated chat router can be exercised **without ESO** with a Lua interpreter:

```sh
cd PrismaticEmotes
texlua tests/run.lua
```

The automated tests cover deterministic/persistent colors, collision avoidance, overrides, links, mentions, name boundaries, ESO grammatical suffixes and saved-name migration, formatting fallbacks, pChat-like formatter preservation, enable/disable behavior, and commands with quoted/unquoted names, spaces, punctuation, accented letters, and invalid inputs.

**Validation:** Version 1.0.0 has also been live-tested in-game with other players. The automated tests use an offline mock of the ESO API and do not certify every game-client or chat-addon combination; different setups may still require their own in-game checks.

## Building a release ZIP

The release packager is adapted from RoleplayPostSupport's `tools/package.py`. Run it from the development checkout with Python 3.9+ and a Lua interpreter installed:

```sh
python3 tools/package.py
# Or choose a specific Lua executable (Lua 5.1 preferred):
python3 tools/package.py --lua lua5.1
```

It automatically looks for `lua5.1`, `lua`, `luajit`, then `texlua`. It runs the Python packaging regressions and `tests/run.lua` before building; a test failure stops packaging. No Python packages, downloads, or network access are required.

The manifest's `## Version` determines the output names. For version 1.0.0, the outputs are:

- `dist/PrismaticEmotes-1.0.0.zip`
- `dist/PrismaticEmotes-1.0.0.zip.sha256`

The ZIP contains a single `PrismaticEmotes/` installer folder with exactly seven files: `PrismaticEmotes.txt`, the five runtime Lua modules, and `README.md`. Tests, tools, Git/editor files, caches, local builds, and previous archives are excluded using an explicit allowlist. Extract the ZIP into your ESO `AddOns/` directory; it creates the correct `AddOns/PrismaticEmotes/PrismaticEmotes.txt` layout.

The packager validates manifest metadata/load order and UTF-8 source files, refuses symlinked package files, and verifies ZIP integrity and byte-for-byte readback. Fixed timestamps, stable permissions, and sorted members make builds reproducible for unchanged files. When adding runtime modules, update `SOURCES` in `tools/package.py` together with the manifest.

Run the packaging tests separately with:

```sh
python3 -m unittest discover -s tests -p '*_spec.py'
```

## ESOUI description

`ESOUI.bbcode` contains the short addon description ready to paste into the ESOUI listing. It is publishing material and is not included in the install ZIP.

## Helpful references

- [Official ESO text emote documentation](https://help.elderscrollsonline.com/app/answers/detail/a_id/6084/)
- [ESOUI discussion: safely wrapping chat message formatters](https://www.esoui.com/forums/showthread.php?t=11576)
- [pChat compatibility documentation](https://www.esoui.com/downloads/info93.html)
- [ESO Update 51 API version](https://www.esoui.com/forums/showthread.php?t=11716)

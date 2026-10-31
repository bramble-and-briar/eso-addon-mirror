# PrismaticEmotes

**Version:** 1.0.2 (chat-delivery and release hardening)\
**Game:** The Elder Scrolls Online (PC/Mac, keyboard chat)  
**ESO API:** 101051 (Update 51 / Season One)  
**External dependencies:** None (pChat optional)

PrismaticEmotes gives each character a readable, persistent color in player-written text emotes (`/e`, `/me`, and `/emote`). Color character names, emote text, or both (the default), with automatic colors or your own per-character overrides. Mention highlighting is on by default: known characters' full names and unambiguous first names are highlighted in their assigned colors when mentioned in another emote.

Settings and colors are saved locally, account-wide **per server**, keeping NA, EU, and PTS separate. No required dependencies; optional pChat support preserves its copy-text links. All coloring is local to your chat and does not change what other players see.

## Installation

Unzip into your ESO AddOns folder so the manifest is located at:

```
Documents/Elder Scrolls Online/live/AddOns/PrismaticEmotes/PrismaticEmotes.txt
```

On Linux/Proton, locate the ESO prefix's `Documents/Elder Scrolls Online/live/AddOns` directory (or the directory to which you have symlinked it). The ZIP contains a top-level `PrismaticEmotes` folder. Enable the addon in ESO's Add-Ons menu, then use `/reloadui` if the game was already running.

## Saved data and servers

All settings and learned/manual character colors are account-wide **per server**. NA, EU, and PTS use separate profiles selected by ESO's `GetWorldName()`. Characters on the same account and server share their settings; changing a color, toggling mentions, or using `/pe forget all` affects only the current server.

When upgrading from shared saved data, the old data is copied once to the **first server you log into after upgrading**, unless that server already has a profile. Existing server profiles always win; other servers start with defaults. The old shared `Default` data remains as a backup. Because the legacy registry has no server information, it cannot be automatically split by origin.

## Example

Before:

```
Leiadriel Milandris watches the travelers crossing the bridge.
Eirnich turns toward Leiadriel Milandris.
Varvyn nods to Leiadriel.
```

After: Leiadriel's name and her emote body use her assigned color; Eirnich's name and his own emote body use his separate color. Both `Leiadriel Milandris` in Eirnich's emote and `Leiadriel` in Varvyn's emote are highlighted in Leiadriel's color, while the surrounding text keeps its author's color.

## Commands

| Command | Action |
|---|---|
| `/pe help` | Show available commands |
| `/pe status` | Show settings and formatter status |
| `/pe on` / `/pe off` | Enable or disable chat recoloring |
| `/pe mode both` | Color author and emote body (default) |
| `/pe mode author` | Only color the author; mentions still configurable |
| `/pe mode body` | Color emote body only; mentions still configurable |
| `/pe mentions on` / `/pe mentions off` | Enable or disable full-name and first-name mention highlighting (on by default) |
| `/pe color "Leiadriel Milandris" #89C3F7` | Give a character a manually selected color |
| `/pe auto "Leiadriel Milandris"` | Restore their automatically assigned color |
| `/pe list` | Show up to 20 known characters and their colors |
| `/pe forget "Leiadriel Milandris"` | Forget one character's color |
| `/pe forget all` | Forget all saved colors (immediate; no confirmation) |
| `/pe preview` | Show a three-character preview in chat (does not save assignments) |
| `/pe rehook` | Reattach after another addon replaced our chat formatter |

`/prismaticemotes` is an alias of `/pe`. Each alias is registered only if it is unclaimed. If another addon already uses `/pe`, use `/prismaticemotes` instead; all `/pe` examples also accept the longer alias.

Mention highlighting is **on by default**. Use `/pe mentions off` to disable it or `/pe mentions on` to enable it again. This toggle does not change author/emote-body coloring or remove saved character colors.

### Custom character colors

Use the character's full name followed by a six-digit RGB hex color:

```text
/pe color "Leiadriel Milandris" #89C3F7
/pe color M'aiq-do #E69BBD
/pe color "Élodie d'Aubépine" 76DCEB
```

Double quotes around the name are optional, even for names with spaces. Everything before the final color token is treated as the name; internal spaces, apostrophes, hyphens, accented letters, and other punctuation are preserved literally. The color accepts uppercase or lowercase hex digits, with or without `#`. Empty names, unclosed double quotes, and invalid colors show usage without changing saved colors.

You can set a color before encountering the character. Overrides are saved account-wide for the current server and apply to subsequent emotes and recognized mentions; they do not recolor existing chat messages. Use `/pe auto "Leiadriel Milandris"` to restore the original automatic color, or `/pe forget "Leiadriel Milandris"` to remove the saved assignment. Both commands accept the same optional double quotes.

## Behavior and design

- **Player-written text emotes only**: `/e`, `/me`, and `/emote` use ESO's `CHAT_CHANNEL_EMOTE`. Animated emotes such as `/dance`, NPC speech, normal chat channels, and whispers are not recolored.
- **Automatic colors**: New characters are hashed into a curated palette, avoiding already assigned exact colors. Once used up, additional pastel RGB colors are generated. Colors are persistent within the account on each server; they are not shared between servers or synchronized with other clients.
- **Character-name normalization**: ESO's internal grammatical suffixes, such as `^Fx` and `^Mx`, are removed before names are saved, listed, or matched. Existing saved names are migrated automatically on login or `/reloadui`, retaining their colors and automatic restore values. Duplicate entries are merged, preferring manual overrides; the existing clean-name entry wins ties. No `/pe forget all` reset is needed.
- **Mention recognition**: A character must have appeared as the author of an emote (or been manually assigned a color) before mentions of them can be recognized. Full names and unambiguous first names are matched with ASCII case folding; complex language-specific case conversions and arbitrary nicknames are not implemented. Full-name matches take priority over shorter first-name matches.
- **First-name matching**: Only the first part before one or more spaces becomes a first-name match: `Leiadriel Milandris` also matches `Leiadriel`, but not `Milandris`. Apostrophes and hyphens stay inside name parts: `Ra'zirr Moonwalker` also matches `Ra'zirr`, not `Ra`, while `Bears-Ill-Tidings` does not produce a `Bears` match. First names do not match fragments inside other apostrophized or hyphenated names. If multiple saved characters share a first name, that shortened name is not highlighted; an exact saved full name always retains its own color. These extra matches are derived from saved characters and do not create additional saved color assignments.
- **Chat integration**: The addon wraps the currently registered `EVENT_CHAT_MESSAGE_CHANNEL` formatter **after** `EVENT_PLAYER_ACTIVATED`, allowing pChat's formatter to run first. The previous formatter is called once with unchanged event arguments; only its displayed message is recolored. Return counts, non-display return values, link destinations, timestamps, narration, and channel metadata are preserved.
- **pChat copy links**: With pChat's copy-text option enabled, color codes are placed outside complete copy links, never inside their captions. Copy captions may be split into smaller links that retain the exact original row/channel destination, preserving pChat's stored-message copy target. Full-name and first-name mentions can span pChat's text chunks. In author-only mode, the surrounding pChat text color is restored after a highlighted mention.
- **Conservative formatting**: Body recoloring requires matching the original text exactly after projecting out recognized pChat copy-link wrappers. Native hyperlinks, textures, URL links, and unknown link types remain intact and are not searched for mentions. Partial copy-caption matches, malformed markup, and other body transformations are left unchanged rather than guessed.
- **Fail-open**: The entire PrismaticEmotes post-processing stage is protected, including settings access, palette assignment, mention-cache generation, and markup formatting. On failure, the previous formatter's full original return tuple is preserved. A warning is attempted once per UI session, and even a broken error reporter cannot interrupt delivery. Errors raised by the previous formatter itself are not swallowed or retried.
- **Privacy**: Nothing is transmitted or shared with other players. All settings live in ESO's SavedVariables.

## Limitations / known issues

- A third-party addon that registers a chat formatter **after** PrismaticEmotes may replace its wrapper. Try `/pe rehook`; this is a shared ESO chat-formatter limitation, not something we can guarantee against for every addon/load order.
- Author names shown via player hyperlinks are color-wrapped without editing hyperlink targets. ESO's client decides final link rendering; validate with your active chat addons in-game.
- Text containing complex embedded formatting can override the surrounding message color. Item links remain intact and their visible text is not treated as character-name mentions.
- The palette favors dark-theme readability but does not guarantee accessible contrast for all chat backgrounds or vision profiles.
- Each server's account-wide `characters` registry may grow with very large roleplay histories; there is no automatic expiry.
- No in-game settings panel or color picker; use slash commands.

## Changelog

Release notes and Git provenance are maintained per version, with a combined BBCode copy for ESOUI:

- [All versions, newest first (ESOUI BBCode)](changelogs/ESOUI.bbcode)
- [1.0.2](changelogs/1.0.2.md)
- [1.0.1](changelogs/1.0.1.md)
- [1.0.0](changelogs/1.0.0.md)
- [0.1.0 development history](changelogs/0.1.0.md)

These files are source/ESOUI publishing material and are excluded from the installer. Historical notes distinguish version-introduction commits from later same-version work; commit dates are not claimed as publication dates. Version 1.0.2 promotes the previously unreleased hardening work without adding it retrospectively to earlier releases.

### 1.0.2

- Avoid slash-command collisions by registering `/pe` and `/prismaticemotes` only when each alias is unclaimed.
- Protect the entire chat post-processing stage and error reporting, preserving original chat delivery and metadata when PrismaticEmotes fails.
- Reject invalid formatting results without swallowing or retrying errors from the previous formatter.
- Add per-version changelogs, standalone release verification, stricter archive checks, and explicit protection against overwriting different existing releases.

### 1.0.1

- Separate account-wide settings and color registries by server, preserving legacy shared data for the first server visited and retaining a backup.
- Keep color markup outside pChat copy-link captions to avoid visible color-code leakage.
- Support body and mention colors across pChat's copy-link chunks without changing copy targets or native links.
- Restore the surrounding pChat text color after mentions when body coloring is disabled.

## Development and tests

Source files are loaded in this order: `Core.lua`, `Palette.lua`, `Markup.lua`, `Chat.lua`, `Commands.lua`. The pure color/markup modules and a simulated chat router can be exercised **without ESO** with a Lua interpreter:

```sh
cd PrismaticEmotes
texlua tests/run.lua
```

The automated tests cover server/account isolation and one-time shared-data migration, deterministic/persistent colors, collision avoidance, overrides, links, full-name and first-name mentions, ambiguous first names, name boundaries, ESO grammatical suffixes and saved-name migration, formatting fallbacks, source-backed pChat copy-link fixtures, cross-chunk mentions, outer-color restoration, formatter argument/return preservation, enable/disable behavior, and commands with quoted/unquoted names, spaces, punctuation, accented letters, and invalid inputs.

**Validation:** The original 1.0.0 release was live-tested with other players. The author has also verified the pChat compatibility changes and server-specific saved-data migration in-game. Offline regression coverage supplements those checks using [pChat 10.0.7.6's copy-link serializer](https://github.com/Baertram/pChat/blob/a31dad341ce01a575a78d43492ce85bdafb65258/pChat/MessageFormatters.lua#L267-L438) and native-style SavedVars proxies. The fixture version identifies the source used for offline tests, not a claim about the exact pChat version or every server/configuration used in live testing.

### Editor setup (Zed / LuaLS)

Open `PrismaticEmotes` as the workspace root. `.luarc.json` selects ESO's Lua 5.1 runtime and loads the focused, editor-only ESO API declarations in `types/esoui.lua`. No external SDK download is required. The saved-variable annotations in `Core.lua` describe this addon's own settings and character registry.

Undefined-global and other diagnostics remain enabled. Test doubles and generated artifacts are excluded from the normal production workspace scan so their mock globals do not redefine ESO APIs; opened ignored files are still checked. This does not exclude tests from the automated test runner.

The declarations are not runtime shims: never execute them or add them to `PrismaticEmotes.txt`. The release allowlist excludes `types/` and `.luarc.json`. See [the editor binding notes](types/README.md) for scope and references.

## Building a release ZIP

The release packager is adapted from RoleplayPostSupport's `tools/package.py`. Run it from the development checkout with Python 3.9+ and a Lua interpreter installed:

```sh
python3 tools/package.py
# Or choose a specific Lua executable (Lua 5.1 preferred):
python3 tools/package.py --lua lua5.1
```

It automatically looks for `lua5.1`, `lua`, `luajit`, then `texlua`. It runs the Python packaging regressions and `tests/run.lua` before building; a test failure stops packaging. No Python packages, downloads, or network access are required.

Verify existing release ZIPs without rebuilding them or requiring Lua:

```sh
python3 tools/package.py --verify dist/PrismaticEmotes-1.0.2.zip
```

Pass additional ZIP paths to verify multiple retained releases in one command. Verification checks CRC, the seven-member installer allowlist, regular-file types, UTF-8 text, embedded manifest/runtime versions, archive filenames, and SHA-256 sidecars. It rejects duplicate/unsafe/hidden/binary members and malformed metadata, including more than two API versions. Historical releases are checked against their own embedded data, not against the current checkout.

Identical rebuilds leave existing archives and checksums untouched. If a release file already exists with different bytes, the build refuses to replace it: bump the release version, or intentionally replace it with `python3 tools/package.py --overwrite`. Existing releases are not rewritten merely because the checkout now contains unreleased changes.

This addon's `## AddOnVersion` encodes `major.minor.patch` as `major * 10000 + minor * 100 + patch`, with two-digit minor and patch components: `1.0.2` uses `10002`. Keep minor and patch below 100 when using this scheme. This numeric metadata is independent of the saved-variable schema version.

The manifest's `## Version` determines the output names. For version 1.0.2, the outputs are:

- `dist/PrismaticEmotes-1.0.2.zip`
- `dist/PrismaticEmotes-1.0.2.zip.sha256`

The ZIP contains a single `PrismaticEmotes/` installer folder with exactly seven files: `PrismaticEmotes.txt`, the five runtime Lua modules, and `README.md`. Tests, tools, changelogs, Git/editor files, caches, local builds, and previous archives are excluded using an explicit allowlist. Extract the ZIP into your ESO `AddOns/` directory; it creates the correct `AddOns/PrismaticEmotes/PrismaticEmotes.txt` layout.

The packager validates manifest metadata/load order and UTF-8 source files, refuses symlinked package files, and verifies ZIP integrity and byte-for-byte readback. Fixed timestamps, stable permissions, and sorted members make builds reproducible for unchanged files. When adding runtime modules, update `SOURCES` in `tools/package.py` together with the manifest.

Run the packaging tests separately with:

```sh
python3 -m unittest discover -s tests -p '*_spec.py'
```

## ESOUI publishing text

- **Description:** [`ESOUI.bbcode`](ESOUI.bbcode) contains the addon overview, features, commands, compatibility, and saved-data behavior for the listing's description field.
- **Change Log:** [`changelogs/ESOUI.bbcode`](changelogs/ESOUI.bbcode) contains all versioned changelogs, newest first, including upgrade notes and source history. The `0.1.0` entry is explicitly development history, not evidence of a published release.

Paste each file's contents into the matching ESOUI field, keeping the release history separate from the description. Both BBCode files are publishing material and are excluded from the install ZIP. When updating per-version notes, update the combined BBCode changelog as well.

## Helpful references

- [Official ESO text emote documentation](https://help.elderscrollsonline.com/app/answers/detail/a_id/6084/)
- [ESOUI discussion: safely wrapping chat message formatters](https://www.esoui.com/forums/showthread.php?t=11576)
- [pChat compatibility documentation](https://www.esoui.com/downloads/info93.html)
- [ESO Update 51 API version](https://www.esoui.com/forums/showthread.php?t=11716)

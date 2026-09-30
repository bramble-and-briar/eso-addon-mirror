# Roleplay Post Support

RoleplayPostSupport is a Lua 5.1 keyboard-chat composer for The Elder Scrolls Online, targeting **ESO APIs 101050 and 101051**. Write a long roleplay post, preview its chunks, and prepare each chunk in ESO's normal editable chat input. **You press Enter to send every message. The addon never sends, retries, or simulates input.** After an unambiguous outgoing echo, it can automatically **prepare** the next chunk, not send it. Optional named sessions record your and selected participants' observed messages across all supported player chat channels, including whispers, for later review.

The author has tested earlier addon behavior in-game and confirmed that ESO preserves zero-width characters through experience with Tongues; that is not confirmation of the new v1.2.0 marker protocol. The source baseline is ESO **12.0.8 / API 101050**, `live` commit `f76cf16c4e5be7b234d15dc7f676febffa64c5bb` dated **2026-08-10**; ESO `master` is stale for this baseline. pChat source was inspected at **10.0.7.4**, commit `3a433e33fe8fcffbe24497374e4f98d75217eaef`. See [API verification and pinned citations](docs/API-VERIFICATION.md) and the [testing checklist](docs/TESTING.md).

## Install

1. Extract the release archive `RoleplayPostSupport-1.2.2.zip` into the active ESO user-data `AddOns` directory (normally `Documents/Elder Scrolls Online/live/AddOns` on Windows; use your actual user-data location for other installations).
2. Confirm the resulting layout is `AddOns/RoleplayPostSupport/RoleplayPostSupport.txt`, with the seven `RoleplayPostSupport*.lua` files and `README.md` beside the manifest, the English default and German/French catalogs in `lang/`, and the API/testing guides in `docs/`. The zip contains only the `RoleplayPostSupport/` installer folder and retains its `lang/` and `docs/` subfolders; do not flatten them or add an extra nested project folder. Standalone tests and development tools are not needed in-game.
3. Enable **Roleplay Post Support** in ESO's Add-Ons menu and log in or reload the UI. No external libraries or pChat are required by this addon.
4. Use keyboard mode and enter `/rps`. Opening the main window automatically enables cursor mode, including when opened from either indicator. Normal UI refreshes do not force cursor mode back on, and closing the window does not force it off. Gamepad-preferred mode is deliberately rejected for queue preparation, even if keyboard chat is otherwise available.

**Repository only:** the generated archive is `dist/RoleplayPostSupport-1.2.2.zip`, with checksum `dist/RoleplayPostSupport-1.2.2.zip.sha256`. `dist/` is not included in the installed addon. For a source installation, create `AddOns/RoleplayPostSupport/` and copy `RoleplayPostSupport.txt`, all seven root `RoleplayPostSupport*.lua` modules, the whole shipped `lang/` folder (`default.lua`, `de.lua`, and `fr.lua`), `README.md`, and only `docs/API-VERIFICATION.md` and `docs/TESTING.md` into it, preserving the `lang/` and `docs/` subfolders. The manifest and seven modules stay at the addon root; the catalogs stay under `lang/`. Do not copy local research HTML.

The manifest declares `101050 101051`, and both versions are accepted by the startup compatibility check. Other client API versions produce a warning. The pinned source research is based on API 101050. Settings and archives are initialized during this addon's `EVENT_ADD_ON_LOADED`; chat/UI setup waits for the first `EVENT_PLAYER_ACTIVATED`. The addon/runtime namespace is `RoleplayPostSupport`; its UI title is **Roleplay Post Support**. A shared footer at the bottom of both Compose and Sessions displays **Version 1.2.2**, sourced from `A.version`.

### Replacing an older LongRPPost installation

Remove or disable the old `AddOns/LongRPPost/` installation before enabling Roleplay Post Support; do not run both addons together. While ESO is closed, back up `SavedVariables/LongRPPostSavedVariables.lua` before changing or removing old data.

The renamed addon uses `RoleplayPostSupportSavedVariables` and the file `SavedVariables/RoleplayPostSupportSavedVariables.lua`. **It does not automatically import old settings or session archives. There is no automatic migration.** Expect fresh settings and an empty archive for the renamed addon unless it already has its own saved data. Keep the old backup if you need its settings/history; removing the old addon folder does not migrate or remove that SavedVariables file.

## Localization and translator workflow

**English is the default**, in `lang/default.lua`, with **German and French overrides supplied** in `lang/de.lua` and `lang/fr.lua`; there is no duplicate `en.lua`. ESO loads the English fallback first, then optionally `lang/$(language).lua` for the UI text language. A missing locale file is allowed; missing entries in a partial translation keep their English defaults. Localization changes display text, not runtime state or the persistence schema; the release UI version is **1.2.2**.

To contribute a future translation:

1. Use the 168 `RPS_` IDs and complete templates in `lang/default.lua` as the reference. Add a new two-letter locale file such as `lang/es.lua`, overriding only translated entries with `SafeAddString(RPS_UI_COMPOSE_TAB, '...', 1)` (replace `...` with the translated label). Use version **1 or newer**, at least the current version of that entry. Do not recreate IDs with `ZO_CreateStringId`, rename the fallback, or duplicate it as `en.lua`. The manifest already has the optional language slot.
2. Retain the **count, type, and order** of `%s` and `%d` placeholders. Use `%%` for a literal percent in entries formatted with arguments; no-argument entries are returned unchanged. Preserve Lua backslash escapes (including `\n` line breaks) and ESO color markup such as `|cFF4444` / `|r`. These are `string.format` templates, not `<<1>>` / `zo_strformat` templates.
3. Translate whole display templates, including warnings and history headings, not user message bodies, character/account/session names, user continuation markers, or the invisible wire tag. `/rps` and its subcommands and machine trace codes stay unchanged. Sessions' `snake_case` error codes remain stable internally and are mapped to readable localized text only in the UI.
4. Run `python3 tests/run.py` and the Python tooling tests below, then follow the [manual locale checks](docs/TESTING.md#localization-and-locale-fallback), checking formatting and label fit. Packaging includes actual two-letter locale files automatically and deterministically, never a literal `$(language).lua` file.

See the public [ESOUI localization guide](https://wiki.esoui.com/How_to_add_localization_support) for default/optional language loading and versioned string overrides.

## Compose and send manually

1. Open `/rps`, choose **Compose**, and select a destination from the **To:** dropdown: Say, Emote, Group / Party, Whisper, and Guild/Officer slots 1–5. Zone and Yell are not offered by the composer. Group membership and guild write requirements are checked when preparing. Changing the dropdown only selects the route for a new batch; it does not change native chat or reroute an active queue.
2. For Whisper, enter an exact character or `@account` name. An explicit known account is least ambiguous; nicknames are not resolved. Other destinations ignore the target field.
3. Paste or type into **Compose**. It is memory-only, with a practical editor cap of 1,000,000 input characters; this is not a chat-message limit. Wheel scrolling and Escape-to-blur come from the native editor templates.
4. Adjust settings if needed, then click **Apply**. **Preview** and **Prepare / Start** use applied settings, not uncommitted settings-field edits.
5. Click **Preview** and use its arrow buttons to inspect the readable chunks, without the addon's invisible wire tag. The preview editor is for review/copy only: changing it does not change the composer or queued text.
6. Make sure native chat contains no unrelated draft, then click **Prepare / Start**. This splits the current composer text anew, prefixes every prepared chunk with the shared invisible tag, and prepares the first chunk at the chosen destination. Tagging applies whether or not a session is recording or its addon-only filter is enabled. Starting another queue is refused while one is active.
7. Inspect the actual native text and destination. You may edit the staged chunk there. **Press ESO's normal Enter yourself.** The addon captures the actual submitted text rather than assuming it still equals the preview.
8. Wait for a matching outgoing chat event. The next chunk is prepared shortly afterward if the queue is still active, unpaused, and native input is safe to use. Inspect it and press Enter yourself again.
9. Once **every chunk in the batch has been confirmed**, Compose and its preview clear automatically, ready for a new post. This also applies to single-chunk posts. If you edit Compose while the batch is active—even if you restore the original text—the draft is preserved. Cancel, manual Finish, skipped/unconfirmed chunks, and timeouts do not clear it; a late final confirmation can clear it once all chunks are confirmed. Session history is unaffected.

**Do not repeatedly send the same composed post.** Reusing identical chunk text at the same destination during the current UI session can trigger **“Repeated/ambiguous submission”** and require manual advancement. ESO provides no message ID to distinguish that send from a delayed earlier echo. The repeated message may already have been sent: this safeguard stops automatic advancement, not the player's native send. Automatic composer clearing prevents accidentally restarting a completed unchanged draft; clearing Compose does **not** reset the repeated-text safeguard. The fixed shared tag is not a unique message ID and does not solve repeated fingerprints. Use different text for subsequent posts and tests, and check chat before using recovery controls.

Edits made in native chat do not reflow the remaining chunks or update the composer. An outgoing event confirms only that matching outgoing chat was observed, not recipient delivery or reading.

### Settings and splitting

| Setting | Default / behavior |
| --- | --- |
| Max chars | Current runtime chat input limit on first initialization. An integer no greater than that limit; includes the four-scalar wire tag and continuation markers. Minimum 5 with empty continuation markers; default continuations require additional room. |
| Prefix | `+ `, applied to every chunk after the first. |
| Suffix | ` +`, applied to every chunk before the last. |
| Sentences | ON. Prefer newline boundaries, then a simple sentence-ending heuristic, then whitespace, then a hard cut. OFF removes only sentence preference. |
| Debug | OFF; `/rps debug` toggles status diagnostics without message contents. |

A single chunk has no continuation markers, but is still tagged when prepared. Empty continuation markers are allowed, but the applied budget must accommodate the wire tag, continuation markers, and body text. `A.Preview` splits within `min(applied max, runtime limit) - 4` Unicode scalars, reserving continuation space normally inside that readable budget; `A.Start` adds the tag to each resulting chunk. Invalid saved chat preferences are reset at activation to the current limit and default markers/sentence setting, preserving archives.

The shared wire prefix is exactly **four U+200B ZERO WIDTH SPACE characters**: **12 UTF-8 bytes, 4 Unicode scalars**, not NUL bytes. Before splitting copied input, Preview/Start strip **one exact leading tag**; they do not remove arbitrary or embedded zero-width characters or repeatedly strip tags.

**No numeric native/server message limit has been verified from the inspected sources.** The addon reads `MAX_TEXT_CHAT_INPUT_CHARACTERS` and the active edit control's `GetMaxInputChars()`, uses the smaller valid positive value when both exist, and refuses preparation when no valid limit is available. The splitter counts **Unicode scalar values**, not UTF-8 bytes or grapheme clusters. The adapter then checks that ESO staged the **exact text and destination**, detecting truncation or rejected staging rather than assuming success. These checks do not establish server length semantics.

Whitespace normalization is deliberately lossy: outer whitespace is trimmed, interior Unicode whitespace becomes single ASCII spaces, and selected split-boundary spaces are removed. Newlines influence boundary preference but are not emitted into chat. Non-breaking spaces lose that property. Sentence detection is a punctuation heuristic, not language parsing. UTF-8 sequences are validated and never cut mid-sequence; combining marks and multi-codepoint emoji can still be separated at a hard cut. No Unicode composition normalization occurs.

Pipe markup (`|`, including ESO links/colors), invalid UTF-8, forbidden control characters, and chunks beginning with a slash command are rejected. Continuation markers must not contain newlines or control characters. `Chat.Prepare` checks the body after stripping one exact leading tag for empty text or a leading slash command; native readback and queue matching still use the exact raw wire text, including any tag. This is a plain-text composer, not a link-preserving chat editor.

## Queue controls and recovery

The separate **RP Post [current/total]** indicator shows the current reason and provides Pause/Resume, Previous, Next/Finish, Cancel, and Open.

| Command | Action |
| --- | --- |
| `/rps` | Toggle the main window. |
| `/rps pause` | Pause queue association/progression; leave native input alone. |
| `/rps resume` | Explicitly prepare the current chunk at the original queued destination, if no unresolved submission remains and input is safe. |
| `/rps next` | Skip the current position and prepare the next, or finish at the end. Does not mark skipped chunks as sent. |
| `/rps previous` | Prepare the preceding original chunk. It may already have been sent: check chat before sending again. |
| `/rps cancel` | Cancel the queue; leave native input untouched. Does not stop session recording. |
| `/rps debug` | Toggle diagnostics and temporary chat-tracking traces; no message bodies, names, or whisper targets. |
| `/rps test` | Run an in-client splitter-only smoke test. Does not prepare input, start a queue, or send. |

Prefer the indicator buttons for recovery; typing slash commands itself interacts with native input. Closing the main window does not cancel a queue or stop recording.

For advancement problems, enable `/rps debug` **before starting a batch**. Local chat lines prefixed `[RPS TRACE ...]` show numbered events, millisecond frame time, batch/chunk IDs, submission eligibility, history callbacks, native input closure, matching echoes, and pause reasons. These temporary traces do not change queue behavior or send chat. See the [trace reproduction steps](docs/TESTING.md#temporary-chat-tracking-traces). Toggle debug off after collecting the trace; the existing debug preference persists across UI reloads.

- Escape, focus loss/native input closure, external input reopening, observed destination changes, or zoning can pause the queue. Remaining chunks retain their original destination; the addon does not silently adopt a newly selected channel or whisper target. Resume is an explicit request to restore the queued route.
- Preparation refuses to overwrite nonempty input unless it still exactly matches text and destination owned by this addon. An edited chunk or unrelated draft must be sent or cleared by you before preparation can proceed.
- An unresolved submission blocks Resume. After **10 seconds** without an unambiguous echo, the queue pauses, but the attempt is retained. A late unique matching echo can still resolve it; if paused, the next chunk waits for explicit Resume.
- **Check chat before using Next or Previous. Never blindly resend after a timeout.** Next retires the uncertain attempt and moves on without claiming it was sent. Previous is an explicit navigation action and can prepare already-sent text. Cancel cannot retract a message.
- Repeated text at the same destination can be ambiguous because ESO supplies no message ID. Retired submission fingerprints are retained in memory for this UI lifetime; repeated attempts require manual review. Once fingerprint capacity is exhausted, later attempts use manual-only recovery. Reload clears this memory, not the server's possibility of delayed chat.
- Cancel does not clear the native text; ordinary keyboard Escape can clear it. A failed first staging can leave an active paused queue: resolve the reason and Resume, or Cancel.
- Drafts, queued chunks, attempts, and current recording state are **not persisted**. Reload/logout discards them; there is no automatic queue restoration or retry. Keep important unsent writing elsewhere before reloading. Zoning pauses an active in-memory queue and turns recording off.

## Optional session archives

Recording is separate from the queue and is **off by default**.

1. On **Sessions**, enter a name and click **Create named session**. The new session is selected with recording off. Creation retains the current Compose destination/whisper target as metadata only, not as a capture scope.
2. Review the all-player-chat notice: recording spans all supported player chat channels, **including whispers**, regardless of Compose's destination or the session's stored route.
3. Enter exact character or `@account` names, separated by commas/newlines, and click **Save participants**. An asterisk marks unsaved edits. Recording uses the saved filter; its Start button does not save participant edits implicitly.
4. Choose **Record addon-marked only: OFF/ON**. OFF is the default for every new session and for legacy sessions with no flag. ON requires the exact leading tag for every otherwise eligible sender, including you and incoming participant whispers. It does not admit outsiders or excluded channels. The setting is saved per session; changing it while recording affects future messages only, without stopping recording or rewriting existing history.
5. Click **Recording: OFF - Start**. A separate red recording indicator remains visible even when the main window is hidden or the queue has finished/cancelled. Use its **Stop** button or the Sessions toggle to stop.
6. Browse sessions with Previous/Next and history with the arrow buttons (ten records per page). Click **Oldest first / Newest first** beside the history controls to switch display order. **Oldest first is the default**: page 1 contains the oldest retained messages, `<` shows older records, and `>` moves toward newer ones. **Newest first** reverses the display: page 1 contains the latest messages, `>` shows older records, and `<` returns toward newer ones. Selecting a session, switching display order, or recording a new message follows the latest entry—at the bottom of the last page in oldest-first mode (including wrapped lines), or at the top of page 1 in newest-first mode. The display preference is saved across sessions and UI reloads; it does not change recording or archived data. Unrelated UI refreshes preserve your page, scroll position, and temporary review edits. History edits are for review/copy only, not changes to saved records; new arrivals and display-order changes replace those temporary edits. Delete requires a second **Confirm delete** click; changing tab/session or hiding the window cancels confirmation.

Message timestamps and session creation time display as **`YYYY-MM-DD HH:MM:SS`** in the viewer's local runtime timezone. Formatting uses the saved timestamp, not the current clock; missing/invalid values or unavailable date formatting show `Unknown time`. Stored timestamps and chronological archive order remain unchanged.

Eligible raw events span the existing source-verified player channels: Say, Emote, Yell, Group, Zone, Guild/Officer slots, language channels, and incoming/outgoing whispers. Own outgoing messages are eligible even with an empty participant list, **including whispers to anyone**, not just named participants or the stored session target. With addon-only ON these outgoing whispers still record when tagged, but unmarked messages are excluded. Other senders, including incoming whisper senders, must match a saved participant. Names are trimmed/formatted and compared case-insensitively without guessing character/account aliases or removing `@`. Bystanders, system/monster channels, and customer-service events are excluded. With addon-only OFF, recording includes eligible ordinary manual chat, not just queued posts; ON additionally requires the tag. Capture is not limited to the currently visible chat tab.

The tag is a **shared convention, not authentication or proof of addon origin**. Removing it from native input excludes that message from addon-only capture; copy/paste or another addon can mimic it. Older RPS versions do not mark messages. Participants need **RPS 1.2.0+ or the same exact convention** for addon-only capture; participant/channel checks still apply.

Existing RoleplayPostSupport sessions gain this all-channel capture behavior without migration when you explicitly start recording; old records are unchanged. v1.2.0 requires no SavedVariables version bump or migration: missing legacy `addonOnly` means OFF. Stored session routes, including legacy routes no longer valid for sending, do not restrict capture or prevent recording from starting. Recording never automatically resumes. This does not import older LongRPPost data.

Queue destination matching is unchanged: archive eligibility on another channel or with another whisper correspondent does not acknowledge or reroute a queued send. Only local outgoing messages with an unambiguous queue-correlated observation at the captured route receive `postId`/`index`/`count` metadata. A tag alone does not supply this metadata, including on other clients' posts. Metadata is not delivery proof. No draft, preview, staged-but-unsent chunk, or historical pChat replay is intentionally imported as an archive record; the archive listens to raw chat events, not pChat's stored history.

### Privacy, persistence, and retention

- Archives and settings use `RoleplayPostSupportSavedVariables`, account-wide and separated by `GetWorldName()` (server/world). Characters on the same account/world share them. Session selection and recording state are not saved.
- Saved data includes applied settings, debug preference, the shared history display preference (`historyNewestFirst`, default `false`), main-window position, session name/ID/creation time/destination/target, saved participant names, the per-session boolean `addonOnly`, and captured records: text with one exact leading tag stripped, boolean `addonMarked`, character/account identities, actual event channel, timestamp, outgoing flag, whisper target, and optional local queue post/chunk metadata. All newly recorded messages use this tag stripping and classification even with addon-only OFF; unmarked text remains unchanged, and existing records are not rewritten or backfilled. New non-whisper records have no target (`nil`). For incoming and outgoing whispers, the target is the actual correspondent from the event (formatted `fromDisplayName` preferred, otherwise formatted `fromName`), never the stored session target. Outgoing whisper records still identify the local player as sender.
- **Broader privacy scope:** compared with fixed-route recording, starting any session now captures eligible chat across channels, including your outgoing whispers to anyone and named participants' incoming whispers. An empty participant list does not exclude your outgoing whispers; addon-only ON still captures tagged whispers to anyone and is not a privacy or consent boundary. Review consent and stop recording before unrelated private conversations; choosing a Compose route or stored session target does not narrow capture.
- Data is local **plaintext, not encrypted**. There is no addon upload/telemetry/export service; ESO still transmits messages you manually send, and other addons may independently log them. OS backups or cloud-synced user-data folders can retain copies. Record only with participants' consent; do not share SavedVariables or screenshots containing private RP without permission.
- Up to **50 sessions** can be created. Each keeps the newest **2,000 messages**; adding another drops the oldest and increments its `dropped` counter. Raw messages over **8,192 bytes** are ignored, not truncated; this archive safeguard is not an ESO chat limit and does not increment the retention-drop counter. There is no age-based expiry or automatic deletion of old sessions.
- Selection changes, successful deletion, player deactivation/zoning, and a new UI load disarm recording. Queue Cancel and window close do not.
- Delete removes the selected session and history from the saved table. ESO controls flushing SavedVariables on normal lifecycle boundaries. For a full reset, exit ESO and remove `SavedVariables/RoleplayPostSupportSavedVariables.lua` from the active user-data directory, plus any backups you intend to remove. This resets settings/archives, not other addons' logs, and is not secure erasure. Do not edit that file while ESO is running.

## Implementation map

The manifest and all seven implementation modules live together in the repository root, with catalogs under `lang/`. Load order is bootstrap `RoleplayPostSupport.lua`, `lang/default.lua`, optional `lang/$(language).lua`, `RoleplayPostSupport_Localization.lua`, then the existing five modules in their unchanged order: Splitter, Sessions, Queue, Chat, UI. The release zip preserves that layout inside the single `RoleplayPostSupport/` installer folder.

| File | Responsibility |
| --- | --- |
| [RoleplayPostSupport.txt](RoleplayPostSupport.txt) | Manifest, API target, SavedVariables declaration, load order. |
| [RoleplayPostSupport.lua](RoleplayPostSupport.lua) | Addon-loaded persistence setup; first-activation UI/chat setup; settings, commands, notifications. |
| [lang/default.lua](lang/default.lua) | English catalog: creates 168 `RPS_` IDs with `ZO_CreateStringId` and registers each with `SafeAddVersion(id, 1)`; optional locale files override them with `SafeAddString`. |
| [lang/de.lua](lang/de.lua), [lang/fr.lua](lang/fr.lua) | German and French catalogs: each maps the same 168 keys to version-1 overrides using `SafeAddString(_G["RPS_" .. key], value, 1)`. |
| [RoleplayPostSupport_Localization.lua](RoleplayPostSupport_Localization.lua) | `A.L(key, ...)` resolves `RPS_` IDs through `GetString`, then calls `string.format` only when arguments are supplied. |
| [RoleplayPostSupport_Splitter.lua](RoleplayPostSupport_Splitter.lua) | UTF-8 validation, normalization, marker budgeting and chunk boundaries; depends on the localization helper but not chat/UI. |
| [RoleplayPostSupport_Chat.lua](RoleplayPostSupport_Chat.lua) | Runtime limit/destination checks, exact input staging, submission observers, raw-event entry point. |
| [RoleplayPostSupport_Queue.lua](RoleplayPostSupport_Queue.lua) | In-memory queue, immutable pending attempt, conservative echo matching, pauses and navigation. |
| [RoleplayPostSupport_Sessions.lua](RoleplayPostSupport_Sessions.lua) | Opt-in all-player-channel capture with own/participant filtering, local archive schema and bounded retention. |
| [RoleplayPostSupport_UI.lua](RoleplayPostSupport_UI.lua) | Keyboard composer, preview, sessions/history, queue and recording indicators. |

The implementation observes stock methods but leaves chat routing/formatting to ESO and installed chat addons. It uses `SecurePostHook` and an observational `ZO_PreHook`; the latter is a wrapping helper, so this is **not** a literal “no function replacement” design. See [API verification](docs/API-VERIFICATION.md) for the exact hooks, evidence, and compatibility boundaries.

## Repository layout (development checkout only)

```text
RoleplayPostSupport.txt           Root addon manifest; loads root modules and lang catalogs
RoleplayPostSupport.lua           Bootstrap first; lifecycle, settings and /rps commands
lang/default.lua                 English fallback
lang/de.lua                      German overrides
lang/fr.lua                      French overrides
RoleplayPostSupport_Localization.lua  Shared GetString/string.format helper
RoleplayPostSupport_Splitter.lua
RoleplayPostSupport_Queue.lua
RoleplayPostSupport_Chat.lua
RoleplayPostSupport_Sessions.lua
RoleplayPostSupport_UI.lua
README.md                        User guide and repository development guide
docs/API-VERIFICATION.md          Pinned API evidence and remaining limitations
docs/TESTING.md                   Automated and in-game testing checklist
tests/                           Isolated Lua specs and Python runner
tools/package.py                 Test, package, integrity-check and checksum
types/esoui.lua                   Editor-only API declarations; never packaged
.luarc.json                      Lua 5.1 + types library; excludes development artifacts/mocks
dist/                            Generated installable zip and SHA-256
```

The 1.2.2 installer contains exactly **14 file members**: the root manifest, seven adjacent `RoleplayPostSupport*.lua` modules, three catalogs (`lang/default.lua`, `lang/de.lua`, and `lang/fr.lua`), and `README.md`, `docs/API-VERIFICATION.md`, and `docs/TESTING.md`. Future actual two-letter locale files add one member each; `lang/$(language).lua` is a manifest substitution, never a literal packaged file. Downloaded wiki HTML is reference material and is excluded from the package. `tests/`, `tools/`, `types/`, configuration, and generated `.build/` and `dist/` artifacts are development-only, not paths inside the installed addon. Editor binding documentation is at `types/README.md` in the development checkout.

The former `research-chat/` and `research-scratch/` folders were temporary upstream-source downloads for API investigation, never runtime dependencies. Those snapshots and the redundant draft report have been removed; useful findings and pinned authoritative source links remain in [API verification](docs/API-VERIFICATION.md). Testing and packaging do not require those downloads.

## Development checks and reproducible packaging (repository only)

Run these commands from the development repository root, not from the installed addon folder. Python 3.11+ and either a Lua executable or a supported installed Lua shared library are required for the complete development checks and packager. No Python packages, automatic downloads, or network access are needed for testing/packaging.

```sh
python3 tests/run.py                         # reports selected runtime
python3 tests/run.py --lua lua5.1            # use your installed Lua 5.1 executable
python3 -m unittest discover -s tests -p '*_spec.py'  # packaging/runner regressions
python3 tools/package.py --lua lua5.1         # runs all tests, then builds dist/
```

The runner syntax-checks root modules and actual `lang/*.lua` files, not the manifest's literal language placeholder. `tests/localization_fixture.lua` mocks ESO's real string API signatures and loads the actual catalog/helper for standalone specs, including the splitter; it is not a production fallback. `tests/localization_spec.lua` covers all 168 catalog keys, missing-locale/partial fallback, equal/newer and rejected older overrides, formatting, and raw-data preservation. A local Lua 5.1 build can be supplied by path. The packager uses fixed ZIP timestamps, sorted members and stable permissions; it refuses to package after test failure and validates manifest/source coverage and archive readback. Its output is `dist/RoleplayPostSupport-1.2.2.zip` and the accompanying `.zip.sha256`, with only the `RoleplayPostSupport/` installer folder inside the zip. LuaLS discovers `.luarc.json` automatically, including `workspace.library: ["types"]`; undefined-global diagnostics are not disabled.

After changes, run development checks for the current tree and use the [testing checklist](docs/TESTING.md) for in-game regression testing.

# RoleplayPostSupport ESOUI editor bindings

[esoui.lua](esoui.lua) contains hand-maintained LuaLS (`---@meta`) declarations for the ESOUI API used by the seven `RoleplayPostSupport*.lua` modules in the repository root beside `RoleplayPostSupport.txt`, plus `lang/default.lua`, the supplied German/French catalogs (`lang/de.lua`, `lang/fr.lua`), and future optional locale catalogs. They provide completion, hover signatures, and static checking, not runtime implementations or a complete ESO SDK.

## LuaLS configuration

Open `RoleplayPostSupport` as the workspace root so LuaLS discovers the root [.luarc.json](../.luarc.json). The configuration:

- Selects Lua 5.1 and loads `types` as a workspace-relative library.
- Disables third-party library auto-detection; upstream ESO sources are reference material, not additional bindings.
- Excludes development artifacts and test doubles from workspace analysis, along with editor/VCS directories. This prevents unopened generated files and mocks from entering normal production workspace analysis. The former `research-chat/` and `research-scratch/` downloads were temporary investigation material, never runtime dependencies, and have been removed; they are not required editor libraries.
- Uses `diagnostics.ignoredFiles: "Opened"` so opened test files are checked and previously published warnings can refresh. It does **not** disable `undefined-global` or whitelist arbitrary globals; production files still receive normal diagnostics.

LuaLS may use definitions from explicitly opened test files despite workspace exclusions. Test doubles should retain real API signatures where applicable; deliberate guards that are not API implementations are installed dynamically. Opened tests receive fresh diagnostics instead of keeping warnings frozen under `ignoredFiles: "Disable"`. Excluding unopened fixtures from the production scan does not disable their runtime tests. Restart the language server only if it still retains diagnostics for deleted files.

## Scope and sources

The declarations cover controls, virtual edit templates and native combo boxes, window/event managers, saved variables, slash commands, chat destinations and text-entry observation, hooks, timing, player identity/formatting helpers, and the string registry APIs `ZO_CreateStringId`, `SafeAddVersion`, `SafeAddString`, and `GetString`. Channel constants include the guild, officer, and zone-language names resolved dynamically through `_G` by the implementation. Constants are typed without inventing numeric values; in particular, the chat length limit comes from the client.

New declarations were checked against ESO API 101050 documentation and stock UI source:

Pinned authoritative sources are retained in [API verification](../docs/API-VERIFICATION.md#pinned-source-citations), independent of the removed downloads:

- **E7, E8, E12, E16:** API documentation for control/window methods, native hooks, identity/time functions, enum names, and events.
- **E1–E5:** `sharedchatsystem.lua` and its XML for `TextEntry` accessors/history, chat-system methods, `StartChatInput(text, channel, target)`, and the runtime input-limit constant.
- **E9, E10, E13:** `chathandlers.lua` and `chatdata.lua` for channel requirements, active-system selection, and route updates.
- **E6, E16:** `zo_hook.lua` and `globalapi.lua` for `ZO_PreHook` and `zo_callLater` signatures/returns.
- **E16:** keyboard edit templates, `localization.lua` for `zo_strformat`, and `debugutils.lua` for variadic `d`.
- [Compose channel dropdown](../docs/API-VERIFICATION.md#compose-channel-dropdown): pinned native combo-box templates and base/keyboard implementations for item creation, selection callbacks, ordering, and enablement.
- [ESOUI localization guide](https://wiki.esoui.com/How_to_add_localization_support): default/optional language loading, addon-prefixed numeric string IDs, version registration, equal/newer `SafeAddString` overrides, and `GetString` lookup. This public guide is a separate localization reference, not part of the pinned API 101050 source snapshot.

The pinned ESOUI live revision is `f76cf16c4e5be7b234d15dc7f676febffa64c5bb` (12.0.8). Source verification does not establish in-client behavior or compatibility with a different API version.

`StartChatInput` prepares native input; it has no success return value and does not send. `SubmitTextEntry` is declared because the implementation observes it through hooks, not to authorize calling it to send. `ZO_GetChatSystem` describes an initialized player UI; these bindings do not make it safe to access UI objects before initialization.

`CreateControl` conservatively returns `Control` because its concrete type depends on a numeric enum. Known edit/button/backdrop template names have specific overloads. A generic add-on factory can erase that subtype information: for example, the label factory in [RoleplayPostSupport_UI.lua](../RoleplayPostSupport_UI.lua) may need a `LabelControl` annotation at its call site. Do not add label-only methods to the base `Control` type just to silence that diagnostic.

## Localization surface

The manifest loads bootstrap `RoleplayPostSupport.lua` first, followed by `lang/default.lua`, optional `lang/$(language).lua`, and `RoleplayPostSupport_Localization.lua`, then the five existing modules in their unchanged order (Splitter, Sessions, Queue, Chat, UI). The default catalog creates 168 `RPS_` IDs with `ZO_CreateStringId` and registers version 1 with `SafeAddVersion`. English is the default; German and French overrides are supplied in `lang/de.lua` and `lang/fr.lua`, each mapping the same 168 keys through `SafeAddString(_G["RPS_" .. key], value, 1)`. There is no duplicate `en.lua`. A missing locale file is allowed, and partial `SafeAddString` overrides retain English for omitted entries. Future actual two-letter locale files are packaged deterministically; the literal language placeholder is not a file.

`A.L(key, ...)` uses `GetString` and applies Lua `string.format` only when arguments are present. Templates retain `%s`/`%d` count, type, and order, `%%` for literal percent signs in formatted entries, Lua backslash/newline escapes, and ESO color markup; `zo_strformat` is for existing name-specific formatting, not these templates. Runtime-generated `RPS_` IDs belong to the catalog, not duplicate definitions in the editor bindings. See the [translator workflow](../README.md#localization-and-translator-workflow) for future overrides.

User messages, names, continuation markers, wire tags, `/rps` subcommands, and machine trace codes are not translated. Sessions' stable `snake_case` error codes are mapped only by the UI to readable text. Localization does not change runtime state or the persistence schema; the release UI version is 1.2.2.

## Runtime separation and validation

Keep all files in `types/` out of the root `RoleplayPostSupport.txt` manifest and the `RoleplayPostSupport/` installer folder in the release zip. Do not execute `esoui.lua` in ESO or in tests: its empty functions and nil constants are editor declarations, not mocks. The `RoleplayPostSupport` runtime namespace and `RoleplayPostSupportSavedVariables` are defined by the implementation, not duplicated here. See the [root user/development guide](../README.md), [API verification](../docs/API-VERIFICATION.md), and [testing checklist](../docs/TESTING.md).

Standalone tests instead use `tests/localization_fixture.lua`, which mocks the real string API signatures and versioned registry, then loads the real catalog/helper. Even the splitter now requires this localization setup, though it has no chat/UI dependency. `tests/localization_spec.lua` covers all 168 keys, fallback, override versions, formatting, and raw-data preservation. The runner syntax-checks actual `lang/*.lua` files as well as root modules, never the literal manifest placeholder. Neither mocks nor editor declarations replace ESO APIs in production.

With `lua-language-server` available on `PATH`, run a fresh check from the repository root:

```sh
lua-language-server --check=. --configpath=.luarc.json --checklevel=Hint
```

For an isolated check, pass `--logpath` and `--metapath` pointing to a temporary directory outside the workspace and remove it afterward. Do not put generated standard-library metadata inside `types` or an ignored directory: LuaLS can analyze it as project code or exclude it altogether, producing spurious diagnostics.

Extend the bindings only for APIs actually used by the add-on, checking the target client's documentation/source. Preserve undefined-global diagnostics and report implementation issues rather than weakening the declarations to conceal them. Static analysis is not an ESO runtime test.

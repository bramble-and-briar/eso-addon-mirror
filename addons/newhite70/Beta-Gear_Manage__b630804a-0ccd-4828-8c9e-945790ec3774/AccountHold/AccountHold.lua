-- AccountHold.lua
-- Namespace, EVENT_ADD_ON_LOADED gate, lifecycle, SavedVariables wiring.
-- Every other module hangs off the AccountHold table.

AccountHold        = AccountHold or {}
AccountHold.name   = "AccountHold"
-- Version follows the Microsoft date-based scheme Major.Minor.YYMMDD.Revision.
-- Major stays 0 while the addon is pre-release / in testing (bump to 1 at GA).
-- Keep this in sync with `## Version` in AccountHold.addon on every release.
AccountHold.version= "0.1.261017.0"
AccountHold.svName = "AccountHoldSV"
AccountHold.svVer  = 1

-- Forward-declare the UI namespace so each ui/*.lua file can attach its own
-- sub-module (InventoryTabKeyboard, InventoryTabGamepad, HoldDialog, etc.)
-- The orchestrator methods (Initialize / OnContainerOpened / OnContainerClosed)
-- are defined further down so they exist before any module reads them.
AccountHold.UI = AccountHold.UI or {}

-- ---------------------------------------------------------------------------
-- Defaults — every key the addon will read MUST appear here.
-- Persisted via ZO_SavedVars; console players cannot hand-edit, so any new
-- key in a future version must be added to defaults AND handled in
-- UpgradeSavedVars below.
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    -- NOTE: intentionally NO `version` key here. ZO_SavedVars reserves and
    -- manages `version` for its own schema version (see AccountHold.svVer);
    -- putting our own value here collided with it. The addon's data-shape
    -- migration counter lives under `dataVersion` and is managed solely by
    -- UpgradeSavedVars — it is deliberately NOT seeded as a default so that
    -- installs predating the counter are detected as the legacy baseline and
    -- migrated exactly once.
    characters = {},          -- [characterId] = { name, class, race, lastFullScan, backpack = {}, worn = {} }
    accountBank = { lastFullScan = 0, items = {} },
    guildBanks = {},          -- [guildId] = { name, lastFullScan, items = {} }
    houseStorage = {},        -- [houseId]  = { [bagId] = { lastFullScan, items = {} } }
    holds = {},               -- [holdId]   = hold record (see Holds.lua)
    nextHoldId = 1,
    -- Epic 0005 — player-curated wishlist. Array of
    -- { id, kind = "set"|"item", setId?, itemSignature?, addedAt }.
    priorities = {},
    nextPriorityId = 1,
    -- Epic 0002 — saved gear builds. [buildId] = { id, name, slots = { [slot] = setId },
    -- createdAt, updatedAt, ahCharacterId?, loadout?, auto = { enabled, rules } }.
    -- loadout/auto are written by src/BuildEquip.lua (dataVersion 7).
    builds = {},
    nextBuildId = 1,
    -- Epic 0002 — per-character equip state: [characterId] = { lastEquipped,
    -- pendingExport = { buildId, armoryIndex, armoryName, at } }.
    buildEquip = {},
    -- Diagnostic ring buffer (Xbox / console can't see Lua errors otherwise).
    -- Each entry: { ts = unix_seconds, level = "info"|"warn"|"error", msg = "..." }.
    -- Capped to DIAGNOSTICS_MAX entries; oldest are evicted FIFO. Surfaced
    -- through the Settings panel so console players can read what happened.
    diagnostics = { entries = {} },
    settings = {
        scanOnLogin              = true,
        scanIntervalMinutes      = 15,
        scanCraftBag             = true,
        -- Show each item's location as a sub label UNDER the item in the
        -- gamepad Quartermaster blade. Defaults OFF: the location is always on
        -- the tooltip, and repeating it on every row makes a long list noisy at
        -- TV distance. Kept as a switch rather than removed, at the player's
        -- request, so either presentation is one toggle away.
        showRowLocation          = false,
        -- When each shared container should be (re)scanned. These let the
        -- player control exactly when scanning happens. All default true so
        -- the account index stays fresh out of the box; disable any of them
        -- to stop the addon walking that container on open.
        scanOnBankOpen           = true,
        scanOnGuildBankOpen      = true,
        scanOnHouseStorageOpen   = true,
        -- When true, every completed scan prints a chat line with the item
        -- count (the "it works, N items" message). Off by default so normal
        -- play isn't spammed; turn it on to confirm scanning is happening.
        announceScanResults      = false,
        autoPromptOnLogin        = true,
        autoPromptAtBank         = true,
        autoPromptAtGuildBank    = true,
        autoPromptAtHouseStorage = true,
        -- P1 #8: independent toggles for the at-container action panel.
        -- The autoPrompt* flags above silence the chat / center-screen
        -- announcement; these silence the on-screen action panel. They
        -- default to true so existing behaviour is preserved.
        showActionPanelAtBank         = true,
        showActionPanelAtGuildBank    = true,
        showActionPanelAtHouseStorage = true,
        confirmEachMove          = false,
        autoEquipOnReceive       = false,
        notificationStyle        = "both",  -- "chat" | "centerScreen" | "both"
        holdRetentionDays        = 7,
        -- P1 #7: per-account default deposit route used by the Place-Hold
        -- dialog. "account_bank" | "guildbank:<id>" | "house:<id>:<bagId>".
        defaultPreferredRoute       = "account_bank",
        -- Reserved for future destinations (workbench, fence, etc).
        -- Today the only meaningful value is "backpack".
        defaultRetrievalDestination = "backpack",
        debugLogging         = false,
        firstLoadBannerShown = false,
        -- Epic 0001 per-feature access gates. Maps a feature key (see
        -- src/Features.lua REGISTRY) to a user override boolean. A user may
        -- only NARROW access here (turn an allowed feature off); an absent key
        -- defaults to enabled, and a stored value can never bypass the
        -- code/config gate. See config/FeatureAccess.lua for the maintainer
        -- allowlists and src/Features.lua for the resolution order.
        features             = {},
    },
}

-- ---------------------------------------------------------------------------
-- Logging helpers
-- ---------------------------------------------------------------------------

function AccountHold:Debug(fmt, ...)
    if not self.sv or not self.sv.settings or not self.sv.settings.debugLogging then return end
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(string.format("|c888888[AH]|r %s", msg))
    end
end

function AccountHold:Log(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(string.format("|cFFD700[Quartermaster]|r %s", msg))
    end
end

-- Localized string with a guaranteed fallback.
--
-- Modules built by separate contributors must not each edit localization/en.lua
-- (it is a single shared file and concurrent edits collide), so they declare the
-- string they want plus an English fallback and the id is added centrally later.
-- This also means a module keeps working if its string is never registered: it
-- renders the fallback rather than an empty label or a raw "SI_..." token.
--
-- `id` may be the SI_* identifier as a STRING (the usual case here, since the
-- global may not exist yet) or the registered global itself.
function AccountHold.L(id, fallback)
    if type(GetString) == "function" then
        -- Prefer the registered global when the id was passed by name.
        local resolved = id
        if type(id) == "string" and type(_G) == "table" and _G[id] ~= nil then
            resolved = _G[id]
        end
        local ok, value = pcall(GetString, resolved)
        if ok and type(value) == "string" and value ~= "" then
            -- GetString echoes an unrecognised string argument straight back,
            -- so an unregistered id would return the literal "SI_..." token.
            -- Treat that as "not registered" and use the fallback instead.
            if not (type(id) == "string" and value == id) then
                return value
            end
        end
    end
    return fallback or (type(id) == "string" and id) or ""
end

-- ---------------------------------------------------------------------------
-- Diagnostics (P-Xbox).
-- Console (Xbox/PS5) has no /script console and no Lua-error window, so any
-- error in module init is invisible to the player. Diagnostic() always
-- prints to chat (independent of debugLogging) AND persists into a capped
-- ring buffer in SavedVariables that the Settings panel can read back.
-- ---------------------------------------------------------------------------
local DIAGNOSTICS_MAX = 50

function AccountHold:Diagnostic(level, fmt, ...)
    -- Defensive against being called before SavedVariables are wired.
    if not self.sv then
        -- Best-effort chat output even without SV — at least the user sees
        -- the message in the current session.
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            local m = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
            CHAT_ROUTER:AddSystemMessage(
                string.format("|cFFAA55[Quartermaster/%s]|r %s",
                    tostring(level or "info"), m))
        end
        return
    end
    local msg   = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    local entry = {
        ts    = (GetTimeStamp and GetTimeStamp()) or 0,
        level = tostring(level or "info"),
        msg   = msg,
    }

    self.sv.diagnostics            = self.sv.diagnostics            or { entries = {} }
    self.sv.diagnostics.entries    = self.sv.diagnostics.entries    or {}
    local ents = self.sv.diagnostics.entries
    ents[#ents + 1] = entry
    -- Evict oldest while over cap. Use table.remove to keep dense indexing
    -- so the Settings panel can paginate without nil-skipping.
    while #ents > DIAGNOSTICS_MAX do
        table.remove(ents, 1)
    end

    -- Mirror to chat. errors / warnings are loud (always shown); info
    -- messages respect the existing debugLogging gate so we don't spam the
    -- chat window during normal operation.
    if entry.level == "error" or entry.level == "warn" then
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            local color = (entry.level == "error") and "FF6666" or "FFCC55"
            CHAT_ROUTER:AddSystemMessage(
                string.format("|c%s[Quartermaster/%s]|r %s",
                    color, entry.level, msg))
        end
    elseif self.sv.settings and self.sv.settings.debugLogging then
        self:Debug("%s", msg)
    end
end

-- safeCall — pcall-wrap a sub-module Initialize so a single throw can't
-- abort the whole UI chain (which is how the user ended up with "scan
-- works, nothing else does" on Xbox: a silent error in an early UI module
-- left every later module uninitialised).
function AccountHold:safeCall(label, fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then
        self:Diagnostic("error", "%s init failed: %s", label, tostring(err))
    end
    return ok
end

-- DumpDiagnostics — print the diagnostics ring buffer to chat. This is the
-- Xbox/PS5 way to read what the addon actually did during init: the LHAS
-- settings panel may not be available on console (the embedded library is
-- optional), so we expose the same surface through the gamepad gear scene
-- keystrip. Always prints at least one line so the player gets feedback.
function AccountHold:DumpDiagnostics()
    local entries = (self.sv and self.sv.diagnostics and self.sv.diagnostics.entries) or {}
    if #entries == 0 then
        self:Log(GetString(SI_ACCOUNTHOLD_DIAG_EMPTY) ~= ""
            and GetString(SI_ACCOUNTHOLD_DIAG_EMPTY)
            or "No Quartermaster diagnostics recorded.")
        return
    end
    self:Log(GetString(SI_ACCOUNTHOLD_DIAG_HEADER) ~= ""
        and GetString(SI_ACCOUNTHOLD_DIAG_HEADER)
        or "Recent Quartermaster diagnostics")
    -- Stamp the build into the dump. A pasted diagnostic line is useless if we
    -- cannot tell WHICH build produced it -- the ring buffer also survives a
    -- /reloadui, so an entry can easily predate the fix being tested.
    self:Log("build %s | account %s",
        tostring(self.version), tostring(self:CurrentAccountName() or "?"))
    for _, e in ipairs(entries) do
        local color = "FFFFFF"
        if e.level == "error" then color = "FF6666"
        elseif e.level == "warn" then color = "FFCC55" end
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(string.format(
                "  |c%s[%s]|r %s", color, tostring(e.level or "?"), tostring(e.msg or "")))
        end
    end
end

-- ---------------------------------------------------------------------------
-- SavedVariables
-- ---------------------------------------------------------------------------

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

local function ensureDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = deepCopy(v)
        elseif type(v) == "table" and type(target[k]) == "table" then
            ensureDefaults(target[k], v)
        end
    end
end

-- Current addon data-shape version. This is the addon's OWN migration counter,
-- stored under sv.dataVersion — deliberately separate from the `version` key
-- ZO_SavedVars reserves for its schema version (AccountHold.svVer). Writing our
-- counter into sv.version previously collided with ZO's reserved key (which can
-- trigger a data reset on a perceived schema mismatch). Bump this and add a
-- matching `if dv < N then ... end` block below for each new migration.
local DATA_VERSION = 7

function AccountHold:UpgradeSavedVars()
    local sv = self.sv
    -- Installs written before dataVersion existed have no counter; treat them
    -- as the legacy baseline (0) so every idempotent block below runs exactly
    -- once and then dataVersion is persisted. We never read or write
    -- sv.version — ZO_SavedVars owns that key.
    local dv = sv.dataVersion or 0

    -- dv 1 → 2: drop dead settings (holdButtonDurationMs, buttonBindings)
    -- whose values were stored, surfaced, but never read. Removing them avoids
    -- surfacing stale UI that lies about the addon's behaviour.
    if dv < 2 then
        if sv.settings then
            sv.settings.holdButtonDurationMs = nil
            sv.settings.buttonBindings       = nil
        end
    end
    -- dv 2 → 3: introduce the per-character allowRequest permission (which
    -- characters may place holds / be a reservation target). Existing character
    -- records predate the flag; default every known character to allowed so
    -- behaviour is unchanged until the player opts a character out from the
    -- Settings panel.
    if dv < 3 then
        for _, rec in pairs(sv.characters or {}) do
            if type(rec) == "table" then
                if rec.allowRequest == nil then rec.allowRequest = true end
            end
        end
    end
    -- dv 3 → 4: Epic 0001 per-feature access gates. Ensure the settings.features
    -- override map exists (also seeded by ensureDefaults on fresh installs)
    -- WITHOUT touching any existing setting (users may only narrow access).
    if dv < 4 then
        if sv.settings then
            sv.settings.features = sv.settings.features or {}
        end
    end

    -- dv 4 → 5: `scanCraftBag` became FUNCTIONAL. It previously had no reader at
    -- all -- Index:Query merged the craft bag unconditionally -- so whatever is
    -- stored (default false) never reflected a real choice, and every existing
    -- player has effectively been running with the craft bag INCLUDED. Honouring
    -- the stored value as-is would therefore make craft-bag rows silently vanish
    -- for everyone on upgrade. Force it on once; the player can now turn it off
    -- and have that actually take effect.
    if dv < 5 then
        if sv.settings then
            sv.settings.scanCraftBag = true
        end
    end

    -- dv 5 → 6: epics 0002 (builds) and 0005 (priorities) introduce two new
    -- top-level collections plus their id counters. Seeded here rather than
    -- relying on ensureDefaults alone so an existing install gets well-formed
    -- empty tables — console players cannot hand-edit SavedVariables, so every
    -- shape a module will index into must exist before that module runs.
    if dv < 6 then
        if type(sv.priorities) ~= "table" then sv.priorities = {} end
        if type(sv.nextPriorityId) ~= "number" then sv.nextPriorityId = 1 end
        if type(sv.builds) ~= "table" then sv.builds = {} end
        if type(sv.nextBuildId) ~= "number" then sv.nextBuildId = 1 end
    end

    -- dv 6 → 7: the Quartermaster Armory can now equip builds and auto-equip
    -- them (src/BuildEquip.lua). Every EXISTING build is preserved untouched —
    -- id, name, set plan, owner tag — and gains an auto-equip block that is
    -- explicitly OFF with no conditions, so an upgrade can never start swapping
    -- gear on its own. `loadout` is deliberately NOT invented: a build only
    -- becomes equippable when the player saves what they are wearing into it
    -- (or imports it from the in-game Armory). The per-character equip state
    -- table is seeded so nothing indexes nil.
    if dv < 7 then
        if type(sv.builds) ~= "table" then sv.builds = {} end
        for _, rec in pairs(sv.builds) do
            if type(rec) == "table" then
                if type(rec.auto) ~= "table" then rec.auto = {} end
                rec.auto.enabled = false
                if type(rec.auto.rules) ~= "table" then rec.auto.rules = {} end
            end
        end
        if type(sv.buildEquip) ~= "table" then sv.buildEquip = {} end
    end

    -- Persist the current counter. AccountHold.svVer (the ZO schema version) is
    -- intentionally NOT changed, so no player data is wiped. Loads already at
    -- DATA_VERSION skip every block above and simply re-stamp the same value.
    sv.dataVersion = DATA_VERSION
end

local function loadSavedVariables()
    AccountHold.sv = ZO_SavedVars:NewAccountWide(
        AccountHold.svName,
        AccountHold.svVer,
        nil,                  -- no namespace key
        deepCopy(DEFAULTS)
    )
    ensureDefaults(AccountHold.sv, DEFAULTS)
    AccountHold:UpgradeSavedVars()
end

-- ---------------------------------------------------------------------------
-- Character identity helper
-- ---------------------------------------------------------------------------

function AccountHold:GetCharacterId()
    -- GetCurrentCharacterId returns the unique 64-bit id (as a string-y value
    -- on console) for the currently-played character. Stable across sessions.
    return GetCurrentCharacterId()
end

function AccountHold:GetCharacterRecord(characterId)
    local currentId = self:GetCharacterId()
    characterId = characterId or currentId
    -- The "player" unit only describes the character currently logged in. Any
    -- other id belongs to an offline alt, whose stored identity must never be
    -- overwritten with this character's name/class/race.
    local isCurrent = (characterId == currentId)
    local rec = self.sv.characters[characterId]
    if not rec then
        rec = {
            name         = isCurrent and (GetUnitName("player") or "?") or "?",
            class        = isCurrent and (GetUnitClass("player") or "?") or "?",
            race         = isCurrent and (GetUnitRace("player") or "?") or "?",
            lastFullScan = 0,
            -- Per-character permission (brief: "the player should be able to
            -- determine which of their characters can request items"). Every
            -- character can always act as holding space / deposit; only the
            -- ability to REQUEST is configurable. nil is treated as allowed,
            -- so pre-existing records keep working; this explicit default lets
            -- the Settings panel show a concrete on/off state.
            allowRequest = true,
            backpack     = {},
            worn         = {},
        }
        self.sv.characters[characterId] = rec
    elseif isCurrent then
        -- keep current display name fresh
        rec.name  = GetUnitName("player") or rec.name
        rec.class = GetUnitClass("player") or rec.class
        rec.race  = GetUnitRace("player") or rec.race
    end
    return rec
end

-- ---------------------------------------------------------------------------
-- Per-character permissions
-- A character may be allowed to REQUEST items (place holds / be the target of
-- a reservation). Every character can always act as holding space (a source
-- other characters pull reserved items from) — depositing is universal. The
-- flag defaults to allowed when unset so upgrades and freshly-seen characters
-- keep working. Configurable from the Settings panel.
-- ---------------------------------------------------------------------------

-- nil is treated as allowed (true) so records written before v3 still work.
function AccountHold:CanRequest(characterId)
    characterId = characterId or self:GetCharacterId()
    local rec = self.sv and self.sv.characters and self.sv.characters[characterId]
    if not rec then return true end
    return rec.allowRequest ~= false
end

function AccountHold:SetCharacterPermission(characterId, key, value)
    if not (self.sv and self.sv.characters) then return end
    local rec = self.sv.characters[characterId]
    if not rec then return end
    if key == "allowRequest" then
        rec[key] = value and true or false
    end
end

-- Ordered list of every character the addon knows about, for the Settings
-- panel and the hold dialog's target picker. Sorted by display name.
function AccountHold:ListKnownCharacters()
    local out = {}
    if self.sv and self.sv.characters then
        for id, rec in pairs(self.sv.characters) do
            out[#out + 1] = {
                id           = id,
                name         = rec.name or tostring(id),
                allowRequest = rec.allowRequest ~= false,
            }
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- Characters that are allowed to be the target of a reservation. Used by the
-- hold dialog's "reserve for <character>" picker.
function AccountHold:ListRequestableCharacters()
    local out = {}
    for _, c in ipairs(self:ListKnownCharacters()) do
        if c.allowRequest then out[#out + 1] = c end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Private-beta access control
--
-- The whole-add-on allowlist now lives in config/FeatureAccess.lua and is
-- resolved by src/Features.lua (Epic 0001). AUTHORIZED_ACCOUNTS was migrated to
-- the `addon` gate there; legacy semantics are preserved (an absent/malformed
-- config or an empty allowlist is INERT/OPEN so the author is never locked
-- out). IsAuthorized stays as the outer gate but delegates to
-- Features:IsAddonEnabled — per-feature gates are then evaluated only for
-- authorized accounts via Features:IsEnabled.
--
-- This is a rollout control, NOT a security boundary: the allowlist ships as
-- readable Lua source.
-- ---------------------------------------------------------------------------

-- The player's ESO account @UserID, or nil when unavailable (e.g. test harness
-- with no ESO globals). GetDisplayName() is the authoritative cross-platform
-- local identity (on Xbox it is the gamertag decorated as "@<gamertag>").
function AccountHold:CurrentAccountName()
    if type(GetDisplayName) ~= "function" then return nil end
    local ok, name = pcall(GetDisplayName)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- Is the current account allowed to use the add-on's features? Backward-
-- compatible delegator to Features:IsAddonEnabled. Fails OPEN if the Features
-- module failed to load, so a load-time error can never lock the author out.
function AccountHold:IsAuthorized()
    if self.Features and self.Features.IsAddonEnabled then
        return self.Features:IsAddonEnabled()
    end
    return true
end

-- Locked (unauthorized) init path: build only a minimal "Features Disabled"
-- settings panel and show the beta banner. No other module is initialized, so
-- no scanning, hooks, keybinds, tooltips, or bank tab are ever created.
function AccountHold:_InitializeLocked()
    if self.Settings and self.Settings.Initialize then
        self:safeCall("Settings(locked)", self.Settings.Initialize, self.Settings, self)
    end
    self:_ShowBetaBanner()
    self:Diagnostic("info", "AccountHold locked: account %s is not on the beta allowlist.",
        tostring(self:CurrentAccountName() or "?"))
end

-- Show the "[BETA TEST IN PROGRESS]" message in chat and (best-effort) as a
-- center-screen announcement. Fully guarded so a missing API can't error.
--
-- The chat line carries the EXPLANATION as well as the banner. The banner alone
-- ("[BETA TEST IN PROGRESS]") doesn't tell a player why the add-on did nothing,
-- and the explanatory text otherwise only exists in the locked settings panel —
-- which needs LibHarvensAddonSettings/LAM2 and therefore does not render at all
-- when no settings library is present (notably on console). Chat is the one
-- surface a locked account is guaranteed to see, so it must be self-contained.
-- The center-screen announcement stays short: CSA_CATEGORY_LARGE_TEXT is a
-- single large line, not a paragraph.
function AccountHold:_ShowBetaBanner()
    local banner = GetString(SI_ACCOUNTHOLD_BETA_BANNER)
    local detail = GetString(SI_ACCOUNTHOLD_FEATURES_DISABLED)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        pcall(function()
            local line = banner
            if detail and detail ~= "" then line = banner .. " " .. detail end
            CHAT_ROUTER:AddSystemMessage(line)
        end)
    end
    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        pcall(function()
            CENTER_SCREEN_ANNOUNCE:AddMessage(
                EVENT_BROADCAST or 0, CSA_CATEGORY_LARGE_TEXT or 1, nil, banner)
        end)
    end
end

function AccountHold:Initialize()
    -- Session marker, FIRST. The diagnostics ring buffer lives in
    -- SavedVariables and therefore survives /reloadui and full restarts, so a
    -- pasted warning can easily predate the build being tested. This line makes
    -- session boundaries and the exact build unambiguous in a dump.
    self:Diagnostic("info", "=== session start: build %s ===", tostring(self.version))

    -- Validate the maintainer feature-access config early. Non-throwing; logs
    -- concise diagnostics for malformed entries and does NOT require
    -- SavedVariables, so it runs safely before the authorization decision.
    if self.Features and self.Features.Validate then
        self:safeCall("Features:Validate", self.Features.Validate, self.Features)
    end

    -- Private-beta access gate. Unauthorized accounts get a locked experience
    -- (beta banner + "Features Disabled" settings panel) and NOTHING else — no
    -- scanning, holds, bank tab, keybinds, tooltips, or event hooks are ever
    -- installed, so the add-on cannot touch the game for them. IsAuthorized
    -- delegates to Features:IsAddonEnabled (loaded via config/FeatureAccess.lua
    -- + src/Features.lua before this point in the manifest).
    if not self:IsAuthorized() then
        self.locked = true
        self:_InitializeLocked()
        return
    end
    self.locked = false
    -- Order matters: each module reads earlier ones. Each call is wrapped
    -- in safeCall so a throw in one module doesn't silently abort the rest
    -- of the chain — that was the underlying cause of the original
    -- "scan runs, no popups, nothing to validate" Xbox report.
    local function init(label, mod)
        if mod and mod.Initialize then
            self:safeCall(label, mod.Initialize, mod, self)
        end
    end
    init("Index",    self.Index)
    init("Holds",    self.Holds)
    init("Notify",   self.Notify)
    init("Mover",    self.Mover)
    init("Scanner",  self.Scanner)
    init("Input",    self.Input)
    -- Epic 0002 / 0005 model modules. Ordered after Index (they read it) and
    -- before UI (which renders them). Each is inert until its feature gate is
    -- flipped on, so wiring them here is safe while `available = false`.
    init("BuildCreator", self.BuildCreator)
    -- Equip / auto-equip / Armory export engine. After BuildCreator (it reads
    -- the build records). Registers its events once; every handler re-checks
    -- the `buildCreator` gate, so it is inert while the feature is off.
    init("BuildEquip",   self.BuildEquip)
    init("Priorities",   self.Priorities)
    init("Travel",       self.Travel)
    -- Diagnostic only, and inert unless switched on in settings. Installed
    -- after Travel because its node descriptions call into it.
    init("TravelTrace",  self.TravelTrace)
    init("UI",       self.UI)
    init("Settings", self.Settings)

    -- Fallback command surface for the retrigger (F2) and re-open-review
    -- (F4) actions. The bank keystrip exposes these too, but on the gamepad
    -- bank scene its UI_SHORTCUT slots may already be owned by the base
    -- game; these chat commands are guaranteed reachable regardless.
    if SLASH_COMMANDS then
        SLASH_COMMANDS["/qmretry"] = function()
            if self.Mover then self.Mover:RetryPending() end
        end
        SLASH_COMMANDS["/qmreview"] = function()
            if self.UI and self.UI.BankActionPanel and self.UI.BankActionPanel.Reopen then
                self.UI.BankActionPanel:Reopen()
            end
        end
        -- Diagnostics were previously only reachable from the Settings panel or
        -- the gear-scene keystrip, so on PC there was no quick way to find out
        -- WHY something didn't appear. Every install guard writes a reason to
        -- the ring buffer; this prints it.
        SLASH_COMMANDS["/qmdiag"] = function()
            self:DumpDiagnostics()
        end
        -- Reports whether each optional feature is available/allowed/enabled,
        -- which is the first question to answer when a feature is missing.
        SLASH_COMMANDS["/qmfeatures"] = function()
            local F = self.Features
            if not F then self:Log("Features module unavailable."); return end
            -- Print the RAW name, the NORMALIZED name, and the normalized
            -- allowlist. A single invisible mismatch here (spacing, casing, a
            -- platform returning a different identity) switches EVERY gated
            -- feature off at once, and every one of them then looks
            -- individually broken.
            local raw  = self:CurrentAccountName()
            local norm = F:NormalizeAccount(raw)
            self:Log("Account raw:        [%s]", tostring(raw))
            self:Log("Account normalized: [%s]", tostring(norm))
            self:Log("Add-on gate: %s", tostring(F:IsAddonEnabled()))

            local cfg = self.FeatureAccessConfig or {}
            local root = cfg.addon or cfg.root
            if type(root) == "table" then
                self:Log("Add-on mode=%s allow=%d", tostring(root.mode),
                    (type(root.allow) == "table") and #root.allow or -1)
                for _, v in ipairs((type(root.allow) == "table") and root.allow or {}) do
                    local n = F:NormalizeAccount(v)
                    self:Log("   allow [%s] -> [%s]%s", tostring(v), tostring(n),
                        (n == norm) and "  <== MATCHES YOU" or "")
                end
            end

            for _, key in ipairs(F.ORDER or {}) do
                local reg  = (F.REGISTRY or {})[key] or {}
                local fcfg = ((cfg.features or {})[key]) or {}
                self:Log("  %s: implemented=%s allowed=%s enabled=%s (mode=%s)",
                    key, tostring(reg.available == true),
                    tostring(F:IsAllowed(key)), tostring(F:IsEnabled(key)),
                    tostring(fcfg.mode))
                for _, v in ipairs((type(fcfg.allow) == "table") and fcfg.allow or {}) do
                    local n = F:NormalizeAccount(v)
                    self:Log("     allow [%s] -> [%s]%s", tostring(v), tostring(n),
                        (n == norm) and "  <== MATCHES YOU" or "")
                end
            end
        end
        -- The Priorities chain has five stages and a failure at any one of them
        -- looks identical to the player: an empty list. This walks every stage
        -- and names the one that broke, so nobody has to guess again.
        SLASH_COMMANDS["/qmpriorities"] = function()
            self:Log("--- Quartermaster Priorities diagnostic (build %s) ---", self.version)

            -- 1. Feature gate.
            local F = self.Features
            if F then
                self:Log("1. gate: available=%s allowed=%s enabled=%s",
                    tostring((F.REGISTRY or {}).priorities
                             and F.REGISTRY.priorities.available),
                    tostring(F:IsAllowed("priorities")),
                    tostring(F:IsEnabled("priorities")))
                if not F:IsEnabled("priorities") then
                    self:Log("   -> BLOCKED here. Account '%s' is not permitted.",
                        tostring(self:CurrentAccountName() or "?"))
                    return
                end
            end

            -- 2. The wishlist itself.
            local P = self.Priorities
            if not P then self:Log("2. Priorities module MISSING."); return end
            local okList, list = pcall(P.List, P)
            if not okList or type(list) ~= "table" then
                self:Log("2. wishlist: FAILED to read (%s)", tostring(list))
                return
            end
            self:Log("2. wishlist: %d entry(s)", #list)
            if #list == 0 then
                self:Log("   -> Nothing is marked wanted. Collections > Item Sets,")
                self:Log("      highlight a SET PIECE in the grid, press Y, 'Add to Priorities'.")
                return
            end

            -- 3. Each wanted set, and crucially whether we know where it drops.
            local SS = self.SetSources
            local known, unknown = 0, 0
            for _, rec in ipairs(list) do
                local label = rec.itemSignature
                if rec.kind == "set" and type(GetItemSetName) == "function" then
                    local okName, n = pcall(GetItemSetName, rec.setId)
                    if okName and type(n) == "string" and n ~= "" then label = n end
                end
                local src = "?"
                if SS and SS.IsUnknown and rec.kind == "set" then
                    local okU, isUnknown = pcall(SS.IsUnknown, SS, rec.setId)
                    if okU then
                        src = isUnknown and "NO SOURCE DATA" or "has source data"
                        if isUnknown then unknown = unknown + 1 else known = known + 1 end
                    end
                end
                self:Log("   - %s (setId=%s) : %s",
                    tostring(label or "?"), tostring(rec.setId or "-"), src)
            end
            self:Log("3. sources: %d known, %d without data", known, unknown)
            if unknown > 0 then
                self:Log("   -> Sets without data cannot produce a dungeon. Only %d sets",
                    (self.SetSourcesData and #self.SetSourcesData or 0))
                self:Log("      are mapped so far; the rest show as 'Source unknown'.")
            end

            -- 4. The plan.
            local okPlan, plan = pcall(P.BuildPlan, P)
            if not okPlan or type(plan) ~= "table" then
                self:Log("4. plan: FAILED to build (%s)", tostring(plan))
                return
            end
            self:Log("4. plan: %d activity(s)", #plan)
            for _, act in ipairs(plan) do
                self:Log("   - %s [%s] outstanding=%s",
                    tostring(act.activityName or "?"),
                    tostring(act.activityType or "?"),
                    tostring(act.outstanding or 0))
            end

            -- 5. What the blade will actually render.
            local screen = self.UI and self.UI.PrioritiesScreenGamepad
            if screen and screen.Rows then
                local okRows, rows = pcall(screen.Rows, screen)
                if okRows and type(rows) == "table" then
                    self:Log("5. blade rows: %d (this is what the menu shows)", #rows)
                    for _, r in ipairs(rows) do
                        self:Log("   - %s", tostring(r.name or "?"))
                    end
                else
                    self:Log("5. blade rows: FAILED (%s)", tostring(rows))
                end
            else
                self:Log("5. blade module MISSING.")
            end
            self:Log("--- end diagnostic ---")
        end
        -- Guaranteed entry point for the Armory, independent of the pause menu.
        -- The Armory was fully built and completely invisible because nothing
        -- called Show(); a command that always works is cheap insurance against
        -- that class of failure recurring.
        SLASH_COMMANDS["/qmarmory"] = function()
            local F = self.Features
            if F then
                self:Log("Armory gate: available=%s allowed=%s enabled=%s",
                    tostring((F.REGISTRY or {}).buildCreator
                             and F.REGISTRY.buildCreator.available),
                    tostring(F:IsAllowed("buildCreator")),
                    tostring(F:IsEnabled("buildCreator")))
            end
            local A = self.UI and self.UI.ArmoryGamepad
            if type(A) ~= "table" then
                self:Log("Armory module NOT loaded (check the manifest).")
                return
            end
            if type(A.Show) ~= "function" then
                self:Log("Armory module loaded but exposes no Show().")
                return
            end
            local ok, shown = pcall(A.Show, A)
            self:Log("Armory:Show() -> ok=%s shown=%s", tostring(ok), tostring(shown))
        end
        -- Same insurance for the dungeon finder.
        SLASH_COMMANDS["/qmdungeons"] = function()
            local D = self.UI and self.UI.DungeonFinderGamepad
            if type(D) ~= "table" then
                self:Log("Dungeon finder NOT loaded (check the manifest).")
                return
            end
            if type(D.Show) ~= "function" then
                self:Log("Dungeon finder loaded but exposes no Show().")
                return
            end
            local ok, shown = pcall(D.Show, D)
            self:Log("DungeonFinder:Show() -> ok=%s shown=%s", tostring(ok), tostring(shown))
        end
        -- Single command that answers "is it actually there?" for every
        -- surface. This add-on has repeatedly shipped features that loaded,
        -- passed tests, and were invisible in game -- because a module can
        -- fail to INSTALL without failing to LOAD. Reports both, per surface,
        -- with the recorded reason.
        SLASH_COMMANDS["/qmstatus"] = function()
            self:Log("--- Quartermaster surface status (build %s) ---", self.version)
            local UI = self.UI or {}

            local function report(label, mod, installedFn, failureFn)
                if type(mod) ~= "table" then
                    self:Log("  %-22s MODULE NOT LOADED (manifest?)", label)
                    return
                end
                local ok, installed = pcall(installedFn, mod)
                local state = (ok and installed) and "INSTALLED" or "not installed"
                local why = ""
                if not (ok and installed) and failureFn then
                    local okW, w = pcall(failureFn, mod)
                    if okW and w and w ~= "" then why = " (" .. tostring(w) .. ")" end
                end
                self:Log("  %-22s %s%s", label, state, why)
            end

            report("Priorities menu", UI.PrioritiesMenuGamepad,
                function(m) return m._installed end)
            report("Item Sets Y action", UI.PrioritiesSetsBookGamepad,
                function(m) return m._installed end)
            report("Armory dialog", UI.ArmoryGamepad,
                function(m) return m._registered end)
            report("Dungeon finder dialog", UI.DungeonFinderGamepad,
                function(m) return m._registered end)
            report("Dungeon finder TAB", UI.DungeonFinderTabGamepad,
                function(m) return m._hooked end,
                function(m) return m._lastFailure end)
            report("Inventory blade", UI.InventoryTabGamepad,
                function(m) return m._blade ~= nil or m._Blade ~= nil end)
            report("Bank tab", UI.BankTabGamepad,
                function(m) return m._keybinds ~= nil end)

            -- The host objects those integrations need. If a host is absent the
            -- integration cannot install no matter how correct our code is.
            self:Log("  hosts: ACTIVITY_FINDER_ROOT=%s DUNGEON_FINDER=%s MENU_ENTRIES=%s ESO_DIALOGS=%s",
                tostring(type(_G.ZO_ACTIVITY_FINDER_ROOT_GAMEPAD) ~= "nil"),
                tostring(type(_G.GAMEPAD_DUNGEON_FINDER) ~= "nil"
                         or type(_G.DUNGEON_FINDER_GAMEPAD) ~= "nil"),
                tostring(type(_G.ZO_MENU_ENTRIES) == "table"),
                tostring(type(_G.ESO_Dialogs) == "table"))
            self:Log("--- end status ---")
        end
    end

    -- One-time chat banner; never on subsequent reloadui.
    if not self.sv.settings.firstLoadBannerShown then
        self:Log(GetString(SI_ACCOUNTHOLD_LOAD_BANNER):format(self.version))
        -- On gamepad/console, the addon does NOT add a third inventory tab —
        -- the entry point is a keystrip button on the gamepad inventory
        -- screen. Tell the player how to reach it so they can validate the
        -- install actually worked. (PC keyboard players see the third tab.)
        if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
            self:Log(GetString(SI_ACCOUNTHOLD_LOAD_BANNER_GAMEPAD))
        end
        self.sv.settings.firstLoadBannerShown = true
    end
    self:Diagnostic("info", "AccountHold v%s initialized (gamepad=%s, console=%s).",
        self.version,
        tostring(IsInGamepadPreferredMode and IsInGamepadPreferredMode() or false),
        tostring(IsConsoleUI and IsConsoleUI() or false))
end

-- ---------------------------------------------------------------------------
-- UI orchestrator. Each ui/*.lua sub-module exposes its own :Initialize;
-- the orchestrator simply calls them in order. Container open/close events
-- from the Scanner are fanned out to the BankActionPanel only — the
-- InventoryTab modules listen to Index change callbacks instead.
-- ---------------------------------------------------------------------------

function AccountHold.UI:Initialize(addonRef)
    self.addon = addonRef
    -- Each sub-module is wrapped so a single bad init can't poison the rest
    -- of the UI chain. The error is reported through Diagnostic() so it is
    -- visible in chat AND persisted to the diagnostics ring buffer for
    -- console players who can't see Lua errors any other way.
    local function init(label, mod)
        if mod and mod.Initialize then
            addonRef:safeCall("UI." .. label, mod.Initialize, mod, addonRef)
        end
    end
    init("HoldDialog",            self.HoldDialog)
    init("InventoryTabKeyboard",  self.InventoryTabKeyboard)
    init("InventoryTabGamepad",   self.InventoryTabGamepad)
    init("BankActionPanel",       self.BankActionPanel)
    init("BankTabGamepad",        self.BankTabGamepad)
    -- Epic 0005. The screen must exist before the menu entry, because the menu
    -- install fails closed if its target screen didn't build — an entry that
    -- points at nothing would be a dead row in the Collections submenu.
    init("PrioritiesScreenGamepad", self.PrioritiesScreenGamepad)
    init("PrioritiesMenuGamepad",   self.PrioritiesMenuGamepad)
    -- The Item Sets book action is deliberately INDEPENDENT of the two above:
    -- it only appends a row to an existing base-game dialog, so it works even
    -- when the custom scene cannot be built. That is what lets a player fill
    -- the wishlist regardless of the screen's state.
    init("PrioritiesSetsBookGamepad", self.PrioritiesSetsBookGamepad)
    -- Epic 0002. Independent of the Priorities screen: it registers its own
    -- parametric dialog and reads BuildCreator directly, so nothing here
    -- depends on the custom scene that failed on hardware.
    init("ArmoryGamepad", self.ArmoryGamepad)
    -- Epic 0005 follow-up. The Priorities X button opens this instead of
    -- queueing blind. Registers its own parametric dialog, so it is independent
    -- of the custom scene that failed on hardware.
    init("DungeonFinderGamepad", self.DungeonFinderGamepad)
    -- The native Dungeon Finder integration: adds a third row alongside
    -- Random / Specific Dungeons. Independent of the standalone dialog above,
    -- which remains as a fallback.
    init("DungeonFinderSceneGamepad", self.DungeonFinderSceneGamepad)
    -- Epic 0008 QoL. Attaches a hold-to-clear keybind to the gamepad
    -- Collections book via that scene's StateChange callback. Independent of
    -- everything above: it registers no scene, appends no row, and NEGOTIATES
    -- its keybind slot rather than claiming one, so a failure here removes only
    -- itself. Y is deliberately not a candidate -- it is already claimed in
    -- three of the collections book's four keybind groups
    -- (docs/research/API_REFERENCE.md).
    init("CollectionsClearAllGamepad", self.CollectionsClearAllGamepad)
    -- EVENT_ADD_ON_LOADED is the earliest possible moment and does not
    -- guarantee the gamepad main menu is stood up. Both installs fail closed,
    -- so retry once the player is actually in the world; both are idempotent,
    -- so a successful first attempt makes this a no-op.
    if self.PrioritiesMenuGamepad and self.PrioritiesMenuGamepad.ScheduleRetry then
        addonRef:safeCall("UI.PrioritiesMenuGamepad.retry",
            self.PrioritiesMenuGamepad.ScheduleRetry, self.PrioritiesMenuGamepad, addonRef)
    end
    if self.PrioritiesSetsBookGamepad and self.PrioritiesSetsBookGamepad.ScheduleRetry then
        addonRef:safeCall("UI.PrioritiesSetsBookGamepad.retry",
            self.PrioritiesSetsBookGamepad.ScheduleRetry, self.PrioritiesSetsBookGamepad, addonRef)
    end
    if self.ArmoryGamepad and self.ArmoryGamepad.ScheduleRetry then
        addonRef:safeCall("UI.ArmoryGamepad.retry",
            self.ArmoryGamepad.ScheduleRetry, self.ArmoryGamepad, addonRef)
    end
    if self.DungeonFinderGamepad and self.DungeonFinderGamepad.ScheduleRetry then
        addonRef:safeCall("UI.DungeonFinderGamepad.retry",
            self.DungeonFinderGamepad.ScheduleRetry, self.DungeonFinderGamepad, addonRef)
    end
    if self.DungeonFinderSceneGamepad and self.DungeonFinderSceneGamepad.ScheduleRetry then
        addonRef:safeCall("UI.DungeonFinderSceneGamepad.retry",
            self.DungeonFinderSceneGamepad.ScheduleRetry, self.DungeonFinderSceneGamepad, addonRef)
    end
end

function AccountHold.UI:OnContainerOpened(bagId)
    if self.BankActionPanel and self.BankActionPanel.OnContainerOpened then
        self.BankActionPanel:OnContainerOpened(bagId)
    end
end

function AccountHold.UI:OnContainerClosed(kind)
    if self.BankActionPanel and self.BankActionPanel.OnContainerClosed then
        self.BankActionPanel:OnContainerClosed(kind)
    end
end

-- ---------------------------------------------------------------------------
-- WipeData(scope) — user-invokable reset, surfaced from the Settings panel.
-- Console players cannot edit the SavedVariables file by hand, so this is
-- the only way for them to start fresh after a corrupt scan.
--
-- scope = "snapshot" : characters / accountBank / guildBanks / houseStorage
-- scope = "holds"    : holds + nextHoldId only
-- scope = "all"      : everything except settings (which the user explicitly
--                      configured) and firstLoadBannerShown — including
--                      priorities and saved builds
-- ---------------------------------------------------------------------------
function AccountHold:WipeData(scope)
    if not self.sv then return end
    local sv = self.sv

    if scope == "snapshot" or scope == "all" then
        sv.characters   = {}
        sv.accountBank  = deepCopy(DEFAULTS.accountBank)
        sv.guildBanks   = {}
        sv.houseStorage = {}
        if self.Index and self.Index.Invalidate then self.Index:Invalidate() end
    end

    if scope == "holds" or scope == "all" then
        sv.holds      = {}
        sv.nextHoldId = 1
    end

    if scope == "all" then
        sv.priorities     = {}
        sv.nextPriorityId = 1
        sv.builds         = {}
        sv.nextBuildId    = 1
        sv.buildEquip     = {}
    end

    -- After a wipe, repopulate the current character record so the live
    -- character at minimum has a placeholder.
    self:GetCharacterRecord()

    -- Notify any UI tabs to redraw.
    if self.UI and self.UI.InventoryTabKeyboard
       and self.UI.InventoryTabKeyboard.Refresh then
        self.UI.InventoryTabKeyboard:Refresh()
    end

    self:Log(GetString(SI_ACCOUNTHOLD_WIPE_DONE):format(tostring(scope)))
end

-- ---------------------------------------------------------------------------
-- EVENT_ADD_ON_LOADED gate
-- ---------------------------------------------------------------------------

local function onAddOnLoaded(eventCode, addonName)
    if addonName ~= AccountHold.name then return end
    EVENT_MANAGER:UnregisterForEvent(AccountHold.name, EVENT_ADD_ON_LOADED)

    loadSavedVariables()
    AccountHold:Initialize()
end

EVENT_MANAGER:RegisterForEvent(AccountHold.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)

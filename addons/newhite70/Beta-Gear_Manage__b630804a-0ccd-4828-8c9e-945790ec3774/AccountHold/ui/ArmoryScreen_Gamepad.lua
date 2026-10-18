-- AccountHold/ui/ArmoryScreen_Gamepad.lua
--
-- The Quartermaster Armory: the GAMEPAD surface for epic 0002's build model
-- (src/BuildCreator.lua). Pick a character, pick a build, assign a SET to each
-- of the 14 gear slots, see what you do not own yet, IMPORT a build straight
-- out of the in-game Armory, and push everything the build still needs onto the
-- Priorities wishlist with one button.
--
-- WHY THIS IS A DIALOG AND NOT A SCENE -- read this before "improving" it
-- ----------------------------------------------------------------------
-- Three separate attempts at a custom gamepad SCENE for this add-on have now
-- failed on real Xbox hardware, always the same way: a top-level window plus a
-- ZO_GamepadVerticalItemParametricScrollList built from CreateControlFromVirtual
-- at add-on-load time never appears, and it fails SILENTLY -- no Lua error a
-- console player could ever see. By contrast the parametric gamepad DIALOG in
-- ui/PrioritiesSetsBook_Gamepad.lua worked first time on the same hardware.
--
-- So this module owns NO controls, NO XML, NO scene and NO fragment. It
-- registers one custom dialog whose list template, scroll list, header, keybind
-- strip and input handling are all built by the base game
-- (zo_genericdialog_gamepad.lua:648-704), which is code that demonstrably works
-- on console because the base UI uses it everywhere.
--
-- WHY ONE DIALOG AND NOT ONE PER LEVEL
-- ------------------------------------
-- A dialog cannot simply "open the next dialog": ZO_Dialogs_ShowDialog bails out
-- when a dialog is already displayed and only queues when canQueue is set
-- (zo_dialog.lua:434-440), and a gamepad dialog releases ASYNCHRONOUSLY -- the
-- hide animation finishes first and only then does the queue drain
-- (zo_dialog.lua:909-911, :977-981). Chaining show/release across that boundary
-- is exactly the kind of timing-sensitive construct that has already failed
-- three times here.
--
-- Instead this is a single dialog with an in-module navigation STACK. Moving a
-- level rewrites our own parametricList and calls the base rebuild helper
-- (zo_genericdialog_gamepad.lua:782) on the dialog that is already open. There
-- is no second window, no queue, no animation race, and B pops one level rather
-- than tearing everything down.
--
-- EXPORT TO THE IN-GAME ARMORY -- what is and is not possible
-- -----------------------------------------------------------
-- (An earlier revision of this header claimed export was impossible because
-- "every function that could equip gear is protected". That was wrong:
-- RequestEquipItem / RequestUnequipItem carry no *protected* marker
-- (ESOUIDocumentation.txt@6639eb2:14951-14953) and the base game calls them
-- straight from inventory UI code (inventoryslot.lua:1110, :1137).)
--
-- SaveArmoryBuild(buildIndex) (doc:20370) is also unprotected, but it takes
-- ONLY a slot index, snapshots what the character is wearing RIGHT NOW, and
-- the server refuses it unless the player is at an Armory Station
-- (ARMORY_BUILD_SAVE_RESULT_NO_INTERACTION, doc:8198). So "export" is real but
-- has two halves: src/BuildEquip.lua equips the Quartermaster build, then
-- offers to save it into the chosen slot the next time the player opens an
-- Armory Station (EVENT_OPEN_ARMORY_MENU). No add-on can write arbitrary data
-- into an Armory slot without the character wearing it.
--
-- QUICKSLOTS. A build cannot be put on the quickslot wheel: the wheel accepts
-- only ITEM / COLLECTIBLE / QUEST_ITEM / EMOTE / QUICK_CHAT actions
-- (assignableutilitywheel_shared.lua:4-12) and SelectSlotItem /
-- SelectSlotSimpleAction are *protected* (doc:14321-14323). The equivalent
-- offered here is the one-press "Quick equip" list at the top of this screen
-- and the X (Equip Build) button.
--
-- IMPORT is fully possible: every read-side Armory function is unprotected,
-- and an import now also copies the build's gear, bars and stars so it can be
-- equipped straight away.
--
-- BASE-GAME CONTRACT -- every line read from esoui/esoui @ master
-- --------------------------------------------------------------
--   globalvars.lua:7                        ESO_Dialogs = {}
--   zo_dialog.lua:1207-1209                 RegisterCustomDialog -> ESO_Dialogs[name] = info
--   zo_dialog.lua:352-378                   ZO_Dialogs_ShowGamepadDialog
--   zo_dialog.lua:358-371                   allowShowOnNextScene retry
--   zo_dialog.lua:373-376                   noChoiceCallback: the show was dropped
--   zo_dialog.lua:81-98                     ZO_Dialogs_IsShowing / FindDialog
--   zo_dialog.lua:435-440                   a second show is dropped unless canQueue
--   zo_dialog.lua:446-449                   the dialog is a CONTROL (userdata)
--   zo_dialog.lua:482-483                   dialog.info / dialog.data, on every show
--   zo_dialog.lua:488                       dialog:GetNamedChild -- control method
--   zo_dialog.lua:604-605                   dialogInfo.setup(dialog, data, textParams)
--   zo_dialog.lua:891-893                   ZO_Dialogs_ReleaseDialogOnButtonPress
--   zo_dialog.lua:909-911                   gamepad dialogs hide ASYNCHRONOUSLY
--   zo_dialog.lua:1247-1256                 blockDialogReleaseOnPress -> WE release
--   zo_genericdialog_gamepad.lua:59-69      button `text` may be string/id/function
--   zo_genericdialog_gamepad.lua:149-159    DIALOG_PRIMARY / DIALOG_NEGATIVE
--   zo_genericdialog_gamepad.lua:187-223    button visible/enabled may be functions
--   zo_genericdialog_gamepad.lua:277-279    ZO_GenericGamepadDialog_RefreshKeybinds
--   zo_genericdialog_gamepad.lua:408-438    ZO_GenericGamepadDialog_RefreshText
--   zo_genericdialog_gamepad.lua:692        dialog.setupFunc for PARAMETRIC dialogs
--   zo_genericdialog_gamepad.lua:745        data.setup is called UNCONDITIONALLY
--   zo_genericdialog_gamepad.lua:749        dialog:GetNamedChild -- control method
--   zo_genericdialog_gamepad.lua:782-852    RebuildEntryList: the rebuild we drive
--   zo_genericdialog_gamepad.lua:785        ipairs over dialog.info.parametricList
--   zo_genericdialog_gamepad.lua:791-795    `visible` is read from templateData
--   zo_genericdialog_gamepad.lua:801-807    `text` may be function -- ENTRY LEVEL ONLY
--   zo_genericdialog_gamepad.lua:815-819    templateData keys are copied RAW
--   zo_genericdialog_gamepad.lua:825-838    header template fixed by first-seen template
--   zo_keybindstrip.lua                     DIALOG_PRIMARY 1, DIALOG_NEGATIVE 2,
--                                           DIALOG_SECONDARY 3, DIALOG_TERTIARY 4,
--                                           DIALOG_RESET 5
--   ingame/globals/bindings.xml             <Action name="DIALOG_SECONDARY"> exists
--   itemsetcollectionsmanager.lua:82-210    the dialog this one is modelled on
--
-- ESO API surface used (ESOUIDocumentation.txt, verified line by line)
-- -------------------------------------------------------------------
--   :20803  GetNumUnlockedArmoryBuilds()                        -> integer
--   :7418   MAX_NUM_ARMORY_BUILDS                               (global)
--   :18095  GetArmoryBuildName(buildIndex)                      -> string
--   :18119  GetArmoryBuildEquipSlotInfo(buildIndex, equipSlot)
--           -> ArmoryBuildEquipSlotState, Bag bagId, integer slotIndex   (:18120)
--   :7371   ArmoryBuildEquipSlotState: EMPTY/INACCESSIBLE/MISSING/VALID
--   :18896  GetItemLink(bagId, slotIndex, linkStyle)            -> string
--   :18980  GetItemLinkSetInfo(itemLink, equipped)
--           -> hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, ...
--   :18134  IsItemInArmory(bagId, slotIndex)                    -> bool (:18135)
--   :12383  GetCharacterInfo(index) -> name,...,id (7th, :12384)
--   :17894  GetItemSetName(itemSetId)                           -> string
--   :4518   EquipSlot enum (EQUIP_SLOT_HEAD ... EQUIP_SLOT_BACKUP_OFF)
--   :18122  SaveArmoryBuild(buildIndex)                         -- NOT USED, see above
--
-- Also read, from esoui/ingame/armory/armorybuilddata.lua: the base game's own
-- ZO_ArmoryBuildData:GetEquipSlotInfo DOWNGRADES VALID to INACCESSIBLE for every
-- bank and house-bank bag before its restore UI sees it. The raw API does not,
-- and GetItemLink still reads those bags, which is why the importer below has a
-- second pass rather than dropping every non-VALID slot.
--
-- The planner model (Contract E) stores SET assignments per gear slot. The
-- EQUIPPABLE part of a build -- exact gear, both bars, champion stars, food --
-- is the `loadout` owned by src/BuildEquip.lua. Build icon, attributes, mundus,
-- curse and outfit are still not modelled.
--
-- ESO runs Lua 5.1: no goto, no //, no bitwise operators. This file must LOAD
-- under tests/zos_mock.lua with none of the ZO_* globals present, so every
-- global is resolved BY NAME at call time and every base-game touch is pcall'd.

AccountHold = AccountHold or {}
AccountHold.UI = AccountHold.UI or {}
AccountHold.UI.ArmoryGamepad = AccountHold.UI.ArmoryGamepad or {}

local Armory = AccountHold.UI.ArmoryGamepad

-- Our dialog. A string key in ESO_Dialogs, never an index into anything.
local DIALOG_NAME = "ACCOUNTHOLD_ARMORY_GAMEPAD"
-- One template for every row. zo_genericdialog_gamepad.lua:825-827 makes the
-- FIRST entry using a template define the header template for ALL of them, so a
-- single template keeps every section header consistent.
--
-- ZO_GamepadItemSubEntryTemplate is what the REAL in-game Armory uses for its
-- build list and its gear list (ingame/armory/gamepad/armory_gamepad.lua:303,
-- :412, :514-517), and it is proven to work inside a PARAMETRIC DIALOG by
-- ingame/crafting/gamepad/consolidatedsmithingsets_gamepad.lua:494. It is
-- defined in ingame/gamepad/gamepadtemplates/gamepadtemplates.xml and inherits
-- ZO_GamepadSubMenuEntryTemplate (zo_gamepadtemplatescommon.xml:278-291), whose
-- label is ZO_GamepadSubMenuEntryLabelTemplate (:188-191): ZoFontGamepad34, NO
-- modifyTextType, and an Icon / SubStatusIcon / StackCount child.
--
-- The value this screen shipped with -- ZO_GamepadFullWidthLeftLabelEntryTemplate
-- -- inherits ZO_GamepadMenuEntryLabelTemplate (:212-215), which declares
-- modifyTextType="UPPERCASE" and has no icon at all. THAT is why every row on
-- this screen was shouted in capitals with no artwork. It is kept as the
-- fallback (it is what itemsetcollectionsmanager.lua:143 uses for a dialog
-- ACTION row, so it is a legitimate native look) and Armory.Refresh demotes to
-- it if the sub-entry template cannot be instantiated.
local TEMPLATE          = "ZO_GamepadItemSubEntryTemplate"
local TEMPLATE_FALLBACK = "ZO_GamepadFullWidthLeftLabelEntryTemplate"
-- Which character a Quartermaster build belongs to. Stored as an ADDITIVE,
-- string-keyed field on the build record so BuildCreator's schema is untouched
-- (its normalization pass only ever rewrites id/name/slots/createdAt/updatedAt,
-- src/BuildCreator.lua:336-345) and the tag dies with the build on delete.
local OWNER_KEY   = "ahCharacterId"

Armory._DIALOG_NAME = DIALOG_NAME
Armory._TEMPLATE    = TEMPLATE
Armory._TEMPLATE_FALLBACK = TEMPLATE_FALLBACK
Armory._OWNER_KEY   = OWNER_KEY

-- The template actually in use. Only ever demoted, never promoted back.
function Armory.EntryTemplate()
    return Armory._TEMPLATE
end

function Armory.DemoteTemplate()
    if Armory._TEMPLATE == TEMPLATE_FALLBACK then return false end
    Armory._TEMPLATE = TEMPLATE_FALLBACK
    return true
end

local PAGE_CHARACTERS = "characters"
local PAGE_BUILDS     = "builds"
local PAGE_BUILD      = "build"
local PAGE_SLOT       = "slot"
local PAGE_NAME       = "name"
local PAGE_CONFIRM    = "confirm"
local PAGE_IMPORT     = "import"
local PAGE_EXPORT     = "export"
local PAGE_EXPORT_SLOT = "exportSlot"
local PAGE_AUTO       = "auto"
local PAGE_FOOD       = "food"

Armory.PAGE_CHARACTERS = PAGE_CHARACTERS
Armory.PAGE_BUILDS     = PAGE_BUILDS
Armory.PAGE_BUILD      = PAGE_BUILD
Armory.PAGE_SLOT       = PAGE_SLOT
Armory.PAGE_NAME       = PAGE_NAME
Armory.PAGE_CONFIRM    = PAGE_CONFIRM
Armory.PAGE_IMPORT     = PAGE_IMPORT
Armory.PAGE_EXPORT     = PAGE_EXPORT
Armory.PAGE_EXPORT_SLOT = PAGE_EXPORT_SLOT
Armory.PAGE_AUTO       = PAGE_AUTO
Armory.PAGE_FOOD       = PAGE_FOOD

-- ---------------------------------------------------------------------------
-- Guarded primitives
-- ---------------------------------------------------------------------------

local function L(id, fallback)
    if AccountHold and type(AccountHold.L) == "function" then
        local ok, s = pcall(AccountHold.L, id, fallback)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return fallback
end

-- Resolve a global BY NAME at call time. Never cache the value: a constant's
-- numeric value is not published and can move between API versions, and a
-- function may not exist at all on the harness or an older client. Same
-- doctrine as src/Index.lua and src/BuildCreator.lua.
local function gfn(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "function" then return v end
    return nil
end

local function gconst(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "number" then return v end
    return nil
end

local function gtable(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "table" then return v end
    return nil
end

-- Call a base-game function with every argument, returning nil on ANY failure.
-- Fail closed: a missing or throwing API means "we know nothing", never a
-- guess.
--
-- EIGHT results, not six. This used to capture six and it silently truncated
-- the two longest signatures this file depends on:
--   ESOUIDocumentation.txt:12383-12384  GetCharacterInfo -> name, gender, level,
--       classId, raceId, alliance, ID (7th), locationId (8th)
--   ESOUIDocumentation.txt:18980-18981  GetItemLinkSetInfo -> hasSet, setName,
--       numBonuses, numNormalEquipped, maxEquipped, setId (6th), numPerfected (7th)
-- With six results GetCharacterInfo's `id` was ALWAYS nil, so the entire
-- secondary character source in CharacterRows silently produced nothing.
local function callGame(name, ...)
    local f = gfn(name)
    if not f then return nil end
    local ok, a, b, c, d, e, g, h, i = pcall(f, ...)
    if not ok then return nil end
    return a, b, c, d, e, g, h, i
end

-- A base-game CONTROL, not a Lua table.
--
-- THIS IS THE BUG THAT MADE THE WHOLE SCREEN INERT. ESO's UI controls are
-- `userdata` with a metatable that permits arbitrary field assignment, which is
-- why the base game can write dialog.info / dialog.entryList / dialog.setupFunc
-- onto one. ZO_Dialogs_ShowDialog hands the dialog CONTROL to every callback
-- (zo_dialog.lua:449 dialog = ZO_GenericGamepadDialog_GetControl(...), :488
-- dialog:GetNamedChild("Title"), :605 dialogInfo.setup(dialog, ...)) and
-- GenericParametricListGamepadDialogTemplate_InitializeEntryList calls
-- dialog:GetNamedChild("EntryList") (zo_genericdialog_gamepad.lua:749), so on a
-- REAL client `type(dialog) == "userdata"` and never "table".
--
-- Refresh() used to gate on type(dialog) == "table". Under tests/zos_mock.lua a
-- stub dialog is a plain table so it passed; in game it was userdata so Refresh
-- returned false BEFORE rebuilding, and the on-screen list never changed again
-- after the first draw. Import, Export and every other navigation row became a
-- visual no-op. ui/PrioritiesScreen_Gamepad.lua:426 already gets this right.
local function isControl(v)
    local t = type(v)
    return t == "userdata" or t == "table"
end
Armory._IsControl = isControl

local function addonRef()
    if type(Armory.addon) == "table" then return Armory.addon end
    if type(AccountHold) == "table" then return AccountHold end
    return nil
end

local function diag(level, fmt, ...)
    local a = addonRef()
    if a and type(a.Diagnostic) == "function" then
        pcall(a.Diagnostic, a, level, "[armory] " .. fmt, ...)
    end
end

-- Console players cannot read Lua errors and the chat window is easy to miss,
-- so every completed action confirms through the same alert surface the rest of
-- the add-on uses.
local function alert(msg)
    if type(msg) ~= "string" or msg == "" then return end
    local N = AccountHold and AccountHold.Notify
    if type(N) == "table" and type(N.Alert) == "function" then
        if pcall(N.Alert, N, msg) then return end
    end
    local a = addonRef()
    if a and type(a.Log) == "function" then pcall(a.Log, a, "%s", msg) end
end

-- EVERY refusal in this file goes through here.
--
-- This add-on has repeatedly shipped features that were built, reachable and
-- silently inert. A refusal that only writes a diagnostic is indistinguishable
-- from "nothing happened" to a player on a controller, so a refusal ALWAYS
-- raises a player-visible alert naming the reason as well.
--
-- `key` de-duplicates only CONSECUTIVE identical refusals, so a rebuild loop
-- that fails every frame cannot bury the chat window; the diagnostic still
-- fires every single time, so nothing is actually lost.
Armory._lastRefusal = nil
local function refuse(key, level, message, diagFmt, ...)
    diag(level or "warn", diagFmt or "%s", ...)
    if type(message) ~= "string" or message == "" then return false end
    if Armory._lastRefusal ~= key then
        Armory._lastRefusal = key
        alert(message)
    end
    return false
end

local function clearRefusal()
    Armory._lastRefusal = nil
end

local function model()
    local bc = AccountHold and AccountHold.BuildCreator
    if type(bc) == "table" then return bc end
    return nil
end

-- Invoke a model method, returning nil rather than throwing into a rebuild loop.
local function modelCall(name, ...)
    local bc = model()
    if not bc or type(bc[name]) ~= "function" then return nil end
    local ok, v = pcall(bc[name], bc, ...)
    if not ok then
        diag("warn", "BuildCreator:%s failed: %s", name, tostring(v))
        return nil
    end
    return v
end

-- The equip engine (src/BuildEquip.lua). Same contract as modelCall: a missing
-- engine or a throw yields nil, reported, never an error inside a rebuild.
local function equipCall(name, ...)
    local be = AccountHold and AccountHold.BuildEquip
    if type(be) ~= "table" or type(be[name]) ~= "function" then return nil end
    local ok, a, b, c = pcall(be[name], be, ...)
    if not ok then
        diag("error", "BuildEquip:%s failed: %s", name, tostring(a))
        alert(L("SI_ACCOUNTHOLD_ARMORY_EQUIP_ERROR",
            "The Quartermaster Armory hit an error. Details are in the diagnostics."))
        return nil
    end
    return a, b, c
end
Armory._EquipCall = equipCall

local function positiveInt(v)
    local n = tonumber(v)
    if n and n > 0 then return n end
    return nil
end

-- string.format that can never throw into a rebuild loop. Declared here rather
-- than beside the row formatters because the import reporter above needs it too
-- and Lua 5.1 resolves upvalues lexically.
local function fmt(pattern, ...)
    local ok, s = pcall(string.format, pattern, ...)
    if ok then return s end
    return pattern
end

-- Character ids are id64-ish values that arrive as numbers on PC and strings on
-- console, and SavedVariables can round-trip either form. Compare them as
-- STRINGS everywhere so a build never detaches from its character because the
-- id came back with a different Lua type.
local function charKey(v)
    if v == nil then return nil end
    return tostring(v)
end

-- ---------------------------------------------------------------------------
-- Feature gates
-- ---------------------------------------------------------------------------
-- `available` is the ship-time posture (src/Features.lua REGISTRY) and decides
-- whether the surface exists at all; IsEnabled is the runtime gate and can
-- change from the settings panel without a reload, so it is re-checked on every
-- Show rather than cached.

function Armory.IsAvailable()
    local f = AccountHold and AccountHold.Features
    if type(f) ~= "table" or type(f.REGISTRY) ~= "table" then return true end
    local reg = f.REGISTRY.buildCreator
    if type(reg) ~= "table" then return true end
    return reg.available ~= false
end

function Armory.IsEnabled()
    local f = AccountHold and AccountHold.Features
    if type(f) ~= "table" or type(f.IsEnabled) ~= "function" then return true end
    local ok, v = pcall(f.IsEnabled, f, "buildCreator")
    return (ok and v) and true or false
end

-- ---------------------------------------------------------------------------
-- Navigation stack -- pure, ZO-free, testable
-- ---------------------------------------------------------------------------
-- A page is a plain table: { page = <PAGE_*>, ... }. The stack is the whole of
-- the UI's state; nothing else is remembered between rebuilds, so a page can
-- never render against data captured at a different level.

Armory._nav = { { page = PAGE_CHARACTERS } }

function Armory.NavTop(stack)
    if type(stack) ~= "table" then return nil end
    local n = #stack
    if n == 0 then return nil end
    return stack[n]
end

function Armory.NavPush(stack, page)
    if type(stack) ~= "table" or type(page) ~= "table" then return false end
    stack[#stack + 1] = page
    return true
end

-- Returns true when a level was actually popped. The ROOT is never popped: the
-- caller treats `false` as "there is nothing above this, close the dialog".
function Armory.NavPop(stack)
    if type(stack) ~= "table" then return false end
    if #stack <= 1 then return false end
    stack[#stack] = nil
    return true
end

function Armory.NavReset(stack)
    if type(stack) ~= "table" then return end
    for i = #stack, 1, -1 do stack[i] = nil end
    stack[1] = { page = PAGE_CHARACTERS }
end

local function top()
    return Armory.NavTop(Armory._nav) or { page = PAGE_CHARACTERS }
end

local function push(page)
    Armory.NavPush(Armory._nav, page)
end

-- ---------------------------------------------------------------------------
-- Build ownership -- which character a Quartermaster build belongs to
-- ---------------------------------------------------------------------------

function Armory.CurrentCharacterKey()
    local a = addonRef()
    if a and type(a.GetCharacterId) == "function" then
        local ok, id = pcall(a.GetCharacterId, a)
        if ok and id ~= nil then return charKey(id) end
    end
    local id = callGame("GetCurrentCharacterId")
    if id ~= nil then return charKey(id) end
    return nil
end

function Armory.CurrentCharacterName()
    local key = Armory.CurrentCharacterKey()
    if key then
        for _, c in ipairs(Armory.CharacterRows()) do
            if c.key == key then return c.name end
        end
    end
    local n = callGame("GetUnitName", "player")
    if type(n) == "string" and n ~= "" then return n end
    return L("SI_ACCOUNTHOLD_ARMORY_THIS_CHARACTER", "this character")
end

function Armory.BuildOwner(buildId)
    local rec = modelCall("GetBuild", buildId)
    if type(rec) ~= "table" then return nil end
    local ok, v = pcall(function() return rec[OWNER_KEY] end)
    if not ok or v == nil then return nil end
    return charKey(v)
end

-- Append-only: writes ONE string-keyed field and never touches anything else on
-- the record. `characterKey` nil clears the tag.
--
-- BuildCreator:GetBuild returns the LIVE record out of SavedVariables
-- (BuildCreator.lua:443-453 -- it returns `record`, not a copy), so this write
-- lands in the saved table and survives /reloadui. That survival depends on
-- BuildCreator:Initialize (:326-348) normalising known fields WITHOUT stripping
-- unknown ones, which is an implementation detail rather than a stated contract.
-- So we do not assume it: the tag is read back immediately and a failure is
-- reported loudly instead of producing a build that quietly loses its owner.
function Armory.SetBuildOwner(buildId, characterKey)
    local rec = modelCall("GetBuild", buildId)
    if type(rec) ~= "table" then
        diag("warn", "SetBuildOwner: no build record for %s.", tostring(buildId))
        return false
    end
    local want = charKey(characterKey)
    local ok = pcall(function() rec[OWNER_KEY] = want end)
    if not ok then
        return refuse("owner:write", "error",
            L("SI_ACCOUNTHOLD_ARMORY_OWNER_FAILED",
              "The build was saved but could not be filed under your character."),
            "SetBuildOwner: writing %s onto build %s threw.", OWNER_KEY, tostring(buildId))
    end
    if Armory.BuildOwner(buildId) ~= want then
        return refuse("owner:lost", "error",
            L("SI_ACCOUNTHOLD_ARMORY_OWNER_FAILED",
              "The build was saved but could not be filed under your character."),
            "SetBuildOwner: build %s did not keep its %s tag (wanted %s, got %s).",
            tostring(buildId), OWNER_KEY, tostring(want), tostring(Armory.BuildOwner(buildId)))
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Row builders -- pure with respect to the UI framework, so they are testable
-- ---------------------------------------------------------------------------

local function allBuilds()
    local list = modelCall("ListBuilds")
    local out = {}
    if type(list) ~= "table" then return out end
    for i = 1, #list do
        local b = list[i]
        if type(b) == "table" and b.id ~= nil then
            out[#out + 1] = {
                id        = b.id,
                name      = (type(b.name) == "string" and b.name ~= "" and b.name)
                            or L("SI_ACCOUNTHOLD_BUILD_UNNAMED", "Unnamed Build"),
                updatedAt = tonumber(b.updatedAt) or 0,
                owner     = Armory.BuildOwner(b.id),
            }
        end
    end
    return out
end
Armory.AllBuilds = allBuilds

-- Every character the add-on has ever seen, each with how many builds are tagged
-- to it. sv.characters is the add-on's OWN record set (AccountHold.lua:35,
-- :369-396) and is the primary source: it is populated by this account's own
-- scans, so it is correct on console where GetNumCharacters/GetCharacterInfo are
-- only guaranteed at character select. Those two APIs
-- (ESOUIDocumentation.txt:12380, :12383) are merged in as a SECONDARY source so
-- a never-yet-scanned character still appears.
function Armory.CharacterRows()
    local rows, seen = {}, {}
    local a = addonRef()

    if a and type(a.ListKnownCharacters) == "function" then
        local ok, list = pcall(a.ListKnownCharacters, a)
        if ok and type(list) == "table" then
            for i = 1, #list do
                local c = list[i]
                if type(c) == "table" and c.id ~= nil then
                    local key = charKey(c.id)
                    if not seen[key] then
                        seen[key] = true
                        rows[#rows + 1] = {
                            key  = key,
                            id   = c.id,
                            name = (type(c.name) == "string" and c.name ~= "" and c.name) or key,
                        }
                    end
                end
            end
        end
    end

    local num = callGame("GetNumCharacters")
    if type(num) == "number" and num > 0 then
        for i = 1, num do
            -- :12384 -- name, gender, level, classId, raceId, alliance, id, locationId.
            -- `id` is the SEVENTH result; callGame used to hand back only six,
            -- so this whole branch silently produced nil ids and added nothing.
            -- level (3rd) and classId (4th) are read for the row's class icon
            -- and level sub-label, exactly the two things a native gamepad
            -- character list shows next to a name.
            local name, _, level, classId, _, _, id = callGame("GetCharacterInfo", i)
            local key = charKey(id)
            if key and not seen[key] then
                seen[key] = true
                rows[#rows + 1] = {
                    key     = key,
                    id      = id,
                    name    = (type(name) == "string" and name ~= "" and name) or key,
                    level   = tonumber(level),
                    classId = tonumber(classId),
                }
            end
        end
    end

    local current = Armory.CurrentCharacterKey()

    -- The character you are playing ALWAYS gets a row.
    --
    -- Import tags the new build to the current character (it is the only Armory
    -- an add-on can read), so if that character had no row -- which is exactly
    -- what happens on a fresh install, because AccountHold:GetCharacterRecord
    -- only writes sv.characters on a scan or a wipe (AccountHold.lua:369-396,
    -- :869) -- the imported build appeared under NO heading at all and looked
    -- like it had vanished. Never let a build exist with nowhere to be seen.
    if current and not seen[current] then
        seen[current] = true
        local name = callGame("GetUnitName", "player")
        -- GetUnitClassId / GetUnitLevel are the live-character equivalents of
        -- GetCharacterInfo's 4th and 3rd results (used the same way in
        -- ingame/skills/playerskillsdata.lua and zo_grouplist_manager.lua).
        local classId = callGame("GetUnitClassId", "player")
        local level   = callGame("GetUnitLevel", "player")
        rows[#rows + 1] = {
            key     = current,
            id      = current,
            name    = (type(name) == "string" and name ~= "" and name) or current,
            level   = tonumber(level),
            classId = tonumber(classId),
        }
    end

    local counts = {}
    for _, b in ipairs(allBuilds()) do
        if b.owner then counts[b.owner] = (counts[b.owner] or 0) + 1 end
    end

    -- A build tagged to a character this client cannot name still has to be
    -- reachable. Give the unknown owner its own row rather than dropping it.
    for owner in pairs(counts) do
        if not seen[owner] then
            seen[owner] = true
            rows[#rows + 1] = { key = owner, id = owner, name = owner, isUnknown = true }
        end
    end


    for _, r in ipairs(rows) do
        r.buildCount = counts[r.key] or 0
        r.isCurrent  = (current ~= nil and r.key == current) and true or false
    end

    table.sort(rows, function(x, y)
        local lx, ly = string.lower(x.name or ""), string.lower(y.name or "")
        if lx ~= ly then return lx < ly end
        return tostring(x.key) < tostring(y.key)
    end)
    return rows
end

-- Builds tagged to one character. `characterKey` nil means the UNTAGGED bucket:
-- builds made before this screen existed (or by a test) have no owner, and
-- hiding them would look exactly like data loss to a console player who cannot
-- inspect SavedVariables.
function Armory.BuildRows(characterKey)
    local want = charKey(characterKey)
    local out = {}
    for _, b in ipairs(allBuilds()) do
        if b.owner == want then
            local pieces  = modelCall("GetPieces", b.id)
            local missing = modelCall("GetMissingPieces", b.id)
            out[#out + 1] = {
                id       = b.id,
                name     = b.name,
                owner    = b.owner,
                assigned = (type(pieces) == "table") and #pieces or 0,
                missing  = (type(missing) == "table") and #missing or 0,
            }
        end
    end
    return out
end

function Armory.CountUntaggedBuilds()
    local n = 0
    for _, b in ipairs(allBuilds()) do
        if b.owner == nil then n = n + 1 end
    end
    return n
end

-- This character's builds that can actually be equipped (they have a saved
-- loadout), for the one-press Quick equip list.
function Armory.QuickEquipRows(characterKey)
    local want = charKey(characterKey)
    local out = {}
    if want == nil then return out end
    local pending = equipCall("GetPending")
    for _, b in ipairs(allBuilds()) do
        if b.owner == want and equipCall("HasLoadout", b.id) then
            local auto = equipCall("GetAuto", b.id)
            out[#out + 1] = {
                id       = b.id,
                name     = b.name,
                equipped = equipCall("IsEquipped", b.id) and true or false,
                auto     = (type(auto) == "table" and auto.enabled) and true or false,
                pending  = (type(pending) == "table" and pending.buildId == b.id) and true or false,
            }
        end
    end
    return out
end

-- The 14 gear slots in canonical order, each carrying whatever the build has
-- assigned. Slots with no assignment are still returned -- an empty slot is a
-- thing the player has to act on, so it must be visible.
function Armory.SlotRows(buildId)
    local slots = modelCall("GetSlots")
    if type(slots) ~= "table" then return {} end

    local byslot = {}
    local pieces = modelCall("GetPieces", buildId)
    if type(pieces) == "table" then
        for i = 1, #pieces do
            local p = pieces[i]
            if type(p) == "table" and p.slot then byslot[p.slot] = p end
        end
    end

    local out = {}
    for i = 1, #slots do
        local s = slots[i]
        if type(s) == "table" and s.key then
            local p = byslot[s.key]
            out[#out + 1] = {
                slot            = s.key,
                label           = s.label or s.key,
                setId           = p and p.setId or nil,
                setName         = p and p.setName or nil,
                owned           = (p and p.owned) and true or false,
                state           = p and p.state or nil,
                reconstructable = (p and p.reconstructable) and true or false,
                sourceUnknown   = (p and p.sourceUnknown) and true or false,
                locationLabel   = p and p.locationLabel or nil,
            }
        end
    end
    return out
end

-- Distinct set ids in a build. `missingOnly` restricts to pieces the player does
-- not own yet, which is what the Priorities wishlist is for.
function Armory.SetIdsForBuild(buildId, missingOnly)
    local pieces = missingOnly and modelCall("GetMissingPieces", buildId)
                                or modelCall("GetPieces", buildId)
    local seen, out = {}, {}
    if type(pieces) ~= "table" then return out end
    for i = 1, #pieces do
        local p = pieces[i]
        local setId = (type(p) == "table") and positiveInt(p.setId) or nil
        if setId and not seen[setId] then
            seen[setId] = true
            out[#out + 1] = setId
        end
    end
    table.sort(out)
    return out
end

function Armory.SetName(setId, fallbackName)
    setId = positiveInt(setId)
    if not setId then return nil end
    local n = callGame("GetItemSetName", setId)
    if type(n) == "string" and n ~= "" then return n end
    if type(fallbackName) == "string" and fallbackName ~= "" then return fallbackName end
    return string.format(L("SI_ACCOUNTHOLD_BUILD_SET_UNKNOWN", "Set #%d"), setId)
end

-- Sets the player can pick from for a slot.
--
-- There is no free-text keyboard on Xbox in this context, and ESO exposes no
-- "enumerate every set id" API, so a picker HAS to be assembled from sets we can
-- already name. Three sources, de-duplicated by set id:
--   1. Index:GetKnownSets() -- sets the account actually owns pieces of.
--   2. Priorities -- sets the player has already told us they want.
--   3. Sets already assigned to any build -- so a set stays pickable after the
--      last piece of it is used up or transferred away.
function Armory.CandidateSets()
    local byId, out = {}, {}

    local function add(setId, name, count)
        setId = positiveInt(setId)
        if not setId then return end
        local rec = byId[setId]
        if rec then
            if count and count > (rec.count or 0) then rec.count = count end
            return
        end
        rec = { setId = setId, name = Armory.SetName(setId, name), count = count or 0 }
        byId[setId] = rec
        out[#out + 1] = rec
    end

    local idx = AccountHold and AccountHold.Index
    if type(idx) == "table" and type(idx.GetKnownSets) == "function" then
        local ok, sets = pcall(idx.GetKnownSets, idx)
        if ok and type(sets) == "table" then
            for i = 1, #sets do
                local s = sets[i]
                if type(s) == "table" then add(s.setId, s.name, tonumber(s.count) or 0) end
            end
        end
    end

    local P = AccountHold and AccountHold.Priorities
    if type(P) == "table" and type(P.List) == "function" then
        local ok, list = pcall(P.List, P)
        if ok and type(list) == "table" then
            for i = 1, #list do
                local rec = list[i]
                if type(rec) == "table" then add(rec.setId) end
            end
        end
    end

    for _, b in ipairs(allBuilds()) do
        local rec = modelCall("GetBuild", b.id)
        if type(rec) == "table" and type(rec.slots) == "table" then
            for _, setId in pairs(rec.slots) do add(setId) end
        end
    end

    table.sort(out, function(x, y)
        local lx, ly = string.lower(x.name or ""), string.lower(y.name or "")
        if lx ~= ly then return lx < ly end
        return (x.setId or 0) < (y.setId or 0)
    end)
    return out
end

-- ---------------------------------------------------------------------------
-- Priorities bridge
-- ---------------------------------------------------------------------------

local function kindSet()
    local P = AccountHold and AccountHold.Priorities
    if type(P) == "table" and type(P.KIND_SET) == "string" then return P.KIND_SET end
    return "set"
end

function Armory.SetIdsInPriorities()
    local out = {}
    local P = AccountHold and AccountHold.Priorities
    if type(P) ~= "table" or type(P.List) ~= "function" then return out end
    local ok, list = pcall(P.List, P)
    if not ok or type(list) ~= "table" then return out end
    for i = 1, #list do
        local rec = list[i]
        if type(rec) == "table" and rec.kind == kindSet() then
            local setId = positiveInt(rec.setId)
            if setId then out[setId] = true end
        end
    end
    return out
end

-- Push every set the build still NEEDS onto the wishlist.
--
-- Priorities:Add returns the pre-existing record when the set is already listed
-- (src/Priorities.lua:153-154), so it cannot tell us whether anything was
-- actually added. Snapshot membership first and diff -- otherwise the player is
-- told "8 added" every single time they press X.
--
-- Returns { total, added, present, failed }, never nil.
function Armory.PrioritizeBuild(buildId)
    local result = { total = 0, added = 0, present = 0, failed = 0 }
    local setIds = Armory.SetIdsForBuild(buildId, true)
    result.total = #setIds
    if result.total == 0 then return result end

    local P = AccountHold and AccountHold.Priorities
    if type(P) ~= "table" or type(P.Add) ~= "function" then
        result.failed = result.total
        diag("warn", "Priorities module unavailable; nothing prioritised.")
        return result
    end

    local before = Armory.SetIdsInPriorities()
    for i = 1, #setIds do
        local setId = setIds[i]
        if before[setId] then
            result.present = result.present + 1
        else
            local ok, rec = pcall(P.Add, P, { kind = kindSet(), setId = setId })
            if ok and type(rec) == "table" then
                result.added = result.added + 1
            else
                result.failed = result.failed + 1
            end
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Import from the in-game Armory
-- ---------------------------------------------------------------------------
-- EquipSlot -> Quartermaster slot key. A pure NAME->NAME map, never numbers:
-- EQUIP_SLOT_* values are not published and could be renumbered, and this table
-- is persisted nowhere, so resolving by name at call time costs nothing and
-- cannot rot. Costume / poison / backup poison / wrist / ranged / class slots
-- are absent on purpose -- they carry no set bonus and the model has no slot for
-- them (src/BuildCreator.lua:88-124).
Armory.EQUIP_SLOT_MAP = {
    EQUIP_SLOT_HEAD        = "head",
    EQUIP_SLOT_SHOULDERS   = "shoulders",
    EQUIP_SLOT_CHEST       = "chest",
    EQUIP_SLOT_HAND        = "hands",
    EQUIP_SLOT_WAIST       = "waist",
    EQUIP_SLOT_LEGS        = "legs",
    EQUIP_SLOT_FEET        = "feet",
    EQUIP_SLOT_NECK        = "neck",
    EQUIP_SLOT_RING1       = "ring1",
    EQUIP_SLOT_RING2       = "ring2",
    EQUIP_SLOT_MAIN_HAND   = "mainHand",
    EQUIP_SLOT_OFF_HAND    = "offHand",
    EQUIP_SLOT_BACKUP_MAIN = "backupMain",
    EQUIP_SLOT_BACKUP_OFF  = "backupOff",
}

-- Resolved pairs { equipSlot = <number>, slot = <key> } for the constants this
-- client actually exposes, in canonical model order so an import always walks
-- the slots the same way. A constant this client does not define is SKIPPED, not
-- guessed -- exactly how src/BuildCreator.lua:131-144 resolves EquipTypes.
function Armory.ResolveEquipSlots()
    local out = {}
    local order = model() and model().SLOT_ORDER or nil
    local rank = {}
    if type(order) == "table" then
        for i = 1, #order do rank[order[i]] = i end
    end
    for name, slot in pairs(Armory.EQUIP_SLOT_MAP) do
        local v = gconst(name)
        if v ~= nil then
            out[#out + 1] = { equipSlot = v, slot = slot, rank = rank[slot] or 99 }
        end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.slot < b.slot
    end)
    return out
end

-- Does this client expose the read side of the Armory at all? Distinguishes
-- "you have no Armory builds" from "this client cannot see the Armory", which
-- are the two very different reasons the import page can be empty.
function Armory.HasArmoryApi()
    return (gfn("GetNumUnlockedArmoryBuilds") ~= nil)
       and (gfn("GetArmoryBuildEquipSlotInfo") ~= nil)
end

-- How many Armory build slots this account has unlocked. Returns 0 when the
-- Armory API is absent so every caller degrades to "nothing to import".
function Armory.NumArmoryBuilds()
    local n = callGame("GetNumUnlockedArmoryBuilds")
    if type(n) ~= "number" or n < 0 then return 0 end
    local cap = gconst("MAX_NUM_ARMORY_BUILDS")
    if cap and n > cap then n = cap end
    return n
end

function Armory.ArmoryBuildRows()
    local out = {}
    local n = Armory.NumArmoryBuilds()
    for i = 1, n do
        local name = callGame("GetArmoryBuildName", i)
        if type(name) ~= "string" or name == "" then
            name = string.format(L("SI_ACCOUNTHOLD_ARMORY_UNNAMED_BUILD", "Armory Build %d"), i)
        end
        out[#out + 1] = { index = i, name = name }
    end
    return out
end

-- Read one in-game Armory build's gear and reduce it to { slotKey = setId }.
--
-- GetArmoryBuildEquipSlotInfo (ESOUIDocumentation.txt:18119) hands back a state
-- plus the bag/slot the saved item currently lives in (:18120), so the SET is
-- resolved the same way the rest of this add-on resolves it: item link
-- (:18896) -> GetItemLinkSetInfo (:18980).
--
-- TWO PASSES, and the second one is the point.
--
-- Pass 1 takes ARMORY_BUILD_EQUIP_SLOT_STATE_VALID slots (:7371). That is the
-- normal path and needs no corroboration.
--
-- Pass 2 exists because a state that is not VALID does NOT mean the item is
-- unreadable. esoui/ingame/armory/armorybuilddata.lua:GetEquipSlotInfo shows the
-- base game DOWNGRADING VALID to INACCESSIBLE itself for every bank and house
-- bank bag, purely so its own restore UI refuses; the raw API still returns a
-- real bagId/slotIndex and GetItemLink still reads it. If we skipped every
-- non-VALID slot, a player whose gear is banked would import a build with zero
-- slots and be told it "worked". So pass 2 re-reads those slots and accepts one
-- ONLY when IsItemInArmory(bagId, slotIndex) (:18134-18135) independently
-- confirms the item sitting there really is part of an Armory build. That check
-- is what keeps this fail-closed: a stale bag/slot whose item was destroyed and
-- replaced will not be in any Armory build, so it is refused rather than
-- imported as the wrong set. Where IsItemInArmory does not exist, pass 2 is
-- skipped entirely.
--
-- Returns, and every field is always present so the caller can always explain
-- itself:
--   slots      { [slotKey] = setId }
--   names      { [setId] = setName }
--   assigned   slots that resolved to a set
--   recovered  how many of those came from pass 2
--   skipped    slots that did not resolve
--   walked     how many equip slots we actually asked about
--   mapped     how many EQUIP_SLOT_* constants this client publishes
--   reasons    { [reason] = count } -- why each skipped slot was skipped
--   fatal      a reason string when the read could not even start
function Armory.ReadArmoryBuildSlots(buildIndex)
    local result = {
        slots = {}, names = {},
        assigned = 0, recovered = 0, skipped = 0, walked = 0, mapped = 0,
        reasons = {},
    }

    local function skip(reason)
        result.skipped = result.skipped + 1
        result.reasons[reason] = (result.reasons[reason] or 0) + 1
    end

    buildIndex = positiveInt(buildIndex)
    if not buildIndex then
        result.fatal = "badIndex"
        return result
    end
    if not gfn("GetArmoryBuildEquipSlotInfo") then
        result.fatal = "noApi"
        diag("warn", "GetArmoryBuildEquipSlotInfo unavailable; import not possible.")
        return result
    end

    local pairsList = Armory.ResolveEquipSlots()
    result.mapped = #pairsList
    if result.mapped == 0 then
        result.fatal = "noSlotConstants"
        diag("warn", "No EQUIP_SLOT_* constants resolved; the slot map is empty.")
        return result
    end

    -- :7371 -- when the client does not publish the enum we cannot compare
    -- states at all, so every slot that yields a bag/slot goes down the pass-1
    -- path. Still fail-closed on DATA: only a real set id is ever stored.
    local VALID     = gconst("ARMORY_BUILD_EQUIP_SLOT_STATE_VALID")
    local EMPTY     = gconst("ARMORY_BUILD_EQUIP_SLOT_STATE_EMPTY")
    local MISSING   = gconst("ARMORY_BUILD_EQUIP_SLOT_STATE_MISSING")
    local INACCESS  = gconst("ARMORY_BUILD_EQUIP_SLOT_STATE_INACCESSIBLE")
    local linkStyle = gconst("LINK_STYLE_DEFAULT")

    local function stateReason(state)
        if EMPTY ~= nil and state == EMPTY then return "empty" end
        if MISSING ~= nil and state == MISSING then return "missing" end
        if INACCESS ~= nil and state == INACCESS then return "inaccessible" end
        return "state"
    end

    -- :18896 -- GetItemLink(bagId, slotIndex, linkStyle). The base game itself
    -- calls it with only two arguments (armorybuilddata.lua
    -- GetEquipSlotItemLinkInfo), so a client without LINK_STYLE_DEFAULT is fine.
    local function setFromBagSlot(bagId, slotIndex)
        local link
        if linkStyle ~= nil then
            link = callGame("GetItemLink", bagId, slotIndex, linkStyle)
        else
            link = callGame("GetItemLink", bagId, slotIndex)
        end
        if type(link) ~= "string" or link == "" then return nil, nil, "noLink" end
        -- :18980 -- hasSet, setName, numBonuses, numNormalEquipped, maxEquipped,
        -- setId, numPerfectedEquipped. `equipped` false: we want the set the item
        -- belongs to, not the player's live bonus count.
        local hasSet, name, _, _, _, id = callGame("GetItemLinkSetInfo", link, false)
        if not hasSet then return nil, nil, "noSet" end
        local setId = positiveInt(id)
        if not setId then return nil, nil, "noSet" end
        return setId, (type(name) == "string" and name ~= "") and name or nil, nil
    end

    local function take(slotKey, setId, setName, viaRecovery)
        result.slots[slotKey] = setId
        if setName then result.names[setId] = setName end
        result.assigned = result.assigned + 1
        if viaRecovery then result.recovered = result.recovered + 1 end
    end

    local deferred = {}

    for _, pair in ipairs(pairsList) do
        result.walked = result.walked + 1
        local state, bagId, slotIndex = callGame("GetArmoryBuildEquipSlotInfo", buildIndex, pair.equipSlot)
        if bagId == nil or slotIndex == nil then
            skip((state == nil) and "noResponse" or stateReason(state))
        elseif VALID == nil or state == VALID then
            local setId, setName, why = setFromBagSlot(bagId, slotIndex)
            if setId then take(pair.slot, setId, setName, false) else skip(why or "noSet") end
        else
            deferred[#deferred + 1] = {
                slot = pair.slot, bagId = bagId, slotIndex = slotIndex,
                reason = stateReason(state),
            }
        end
    end

    local isItemInArmory = gfn("IsItemInArmory")
    for i = 1, #deferred do
        local d = deferred[i]
        local claimed = false
        if isItemInArmory then
            -- :18134-18135 -- IsItemInArmory(bagId, slotIndex) -> isInAnyBuild.
            local inArmory = callGame("IsItemInArmory", d.bagId, d.slotIndex)
            if inArmory == true then
                local setId, setName, why = setFromBagSlot(d.bagId, d.slotIndex)
                if setId then
                    take(d.slot, setId, setName, true)
                    claimed = true
                else
                    skip(why or "noSet")
                    claimed = true
                end
            end
        end
        if not claimed then skip(d.reason) end
    end

    return result
end

-- Turn a read/import result into one sentence a player can act on.
--
-- Pure: no ZO globals, no model. This is the surface the smoke tests assert,
-- because "Import did nothing and said nothing" is the bug this whole file
-- exists to stop happening again.
function Armory.FormatImportReport(res)
    if type(res) ~= "table" then
        return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_FAILED", "Import failed.")
    end

    if res.fatal == "noApi" then
        return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_NO_API",
            "This client does not expose the Armory API, so nothing can be imported.")
    end
    if res.fatal == "noSlotConstants" then
        return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_NO_SLOTS",
            "This client does not expose the gear slot constants, so nothing can be imported.")
    end
    if res.fatal == "badIndex" then
        return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_FAILED", "Import failed.")
    end

    local reasons = (type(res.reasons) == "table") and res.reasons or {}
    local assigned = res.assigned or 0
    local skipped  = res.skipped or 0

    if assigned == 0 then
        if (reasons.empty or 0) >= (res.walked or 0) and (res.walked or 0) > 0 then
            return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_EMPTY_BUILD",
                "That Armory build has no gear saved in it.")
        end
        if (reasons.inaccessible or 0) > 0 then
            return fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_INACCESSIBLE",
                "Nothing imported: %d slot(s) hold gear the Armory says it cannot reach right now (usually banked). Try again at an Armory Station."),
                reasons.inaccessible)
        end
        if (reasons.missing or 0) > 0 then
            return fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_MISSING",
                "Nothing imported: %d slot(s) point at gear you no longer have."),
                reasons.missing)
        end
        if (reasons.noLink or 0) > 0 then
            return fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_NO_LINK",
                "Nothing imported: %d slot(s) named an item this client could not read."),
                reasons.noLink)
        end
        if (reasons.noSet or 0) > 0 then
            return fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_NO_SET",
                "Nothing imported: %d slot(s) hold gear that is not part of any set."),
                reasons.noSet)
        end
        return L("SI_ACCOUNTHOLD_ARMORY_IMPORT_EMPTY",
            "That Armory build has no gear this add-on can read.")
    end

    local base
    if res.name then
        base = fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORTED", "Imported \"%s\" - %d slots."),
            tostring(res.name), assigned)
    else
        base = fmt(L("SI_ACCOUNTHOLD_ARMORY_READ_OK", "Read %d slot(s) from the Armory."), assigned)
    end
    if (res.recovered or 0) > 0 then
        base = base .. " " .. fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_RECOVERED",
            "%d came from bags the Armory reported as out of reach."), res.recovered)
    end
    if skipped > 0 then
        base = base .. " " .. fmt(L("SI_ACCOUNTHOLD_ARMORY_IMPORT_SKIPPED",
            "%d slot(s) skipped (%s)."), skipped, Armory.FormatSkipReasons(reasons))
    end
    return base
end

-- "3 empty, 1 not part of a set" -- a stable, sorted, translatable breakdown.
function Armory.FormatSkipReasons(reasons)
    if type(reasons) ~= "table" then return "" end
    local labels = {
        empty        = L("SI_ACCOUNTHOLD_ARMORY_SKIP_EMPTY",        "empty"),
        missing      = L("SI_ACCOUNTHOLD_ARMORY_SKIP_MISSING",      "gear no longer owned"),
        inaccessible = L("SI_ACCOUNTHOLD_ARMORY_SKIP_INACCESSIBLE", "out of reach"),
        state        = L("SI_ACCOUNTHOLD_ARMORY_SKIP_STATE",        "unusable"),
        noResponse   = L("SI_ACCOUNTHOLD_ARMORY_SKIP_NO_RESPONSE",  "no answer from the Armory"),
        noLink       = L("SI_ACCOUNTHOLD_ARMORY_SKIP_NO_LINK",      "item unreadable"),
        noSet        = L("SI_ACCOUNTHOLD_ARMORY_SKIP_NO_SET",       "not part of a set"),
    }
    local keys = {}
    for k in pairs(reasons) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        if (reasons[k] or 0) > 0 then
            parts[#parts + 1] = fmt("%d %s", reasons[k], labels[k] or k)
        end
    end
    return table.concat(parts, ", ")
end

-- Create a Quartermaster build from an in-game Armory build.
--
-- The in-game Armory belongs to the CHARACTER YOU ARE PLAYING -- there is no API
-- to read another character's Armory -- so the new build is always tagged to the
-- current character regardless of which character page you came from.
--
-- Returns the read result, extended with { buildId, name, error }. `error` is a
-- player-readable string when nothing was created. `message` is ALWAYS set: the
-- caller must never have to invent an explanation.
function Armory.ImportArmoryBuild(buildIndex)
    local index = positiveInt(buildIndex)
    if not index then
        local out = { assigned = 0, skipped = 0, reasons = {}, fatal = "badIndex" }
        out.error   = Armory.FormatImportReport(out)
        out.message = out.error
        return out
    end

    local out = Armory.ReadArmoryBuildSlots(index)
    diag("info",
        "Import read: build %d, %d equip slots mapped, %d walked, %d resolved (%d recovered), %d skipped [%s].",
        index, out.mapped or 0, out.walked or 0, out.assigned or 0, out.recovered or 0,
        out.skipped or 0, Armory.FormatSkipReasons(out.reasons))

    if (out.assigned or 0) == 0 then
        out.error   = Armory.FormatImportReport(out)
        out.message = out.error
        return out
    end

    local name = callGame("GetArmoryBuildName", index)
    if type(name) ~= "string" or name == "" then
        name = string.format(L("SI_ACCOUNTHOLD_ARMORY_UNNAMED_BUILD", "Armory Build %d"), index)
    end

    local buildId = modelCall("CreateBuild", name)
    if buildId == nil then
        out.error = L("SI_ACCOUNTHOLD_ARMORY_IMPORT_NO_ROOM",
            "Could not create a build. You may have reached the build limit.")
        out.message = out.error
        return out
    end

    -- The model is the only judge of what actually landed, so recount from
    -- SetSlot's return rather than trusting the read.
    local stored = 0
    for _, pair in ipairs(Armory.ResolveEquipSlots()) do
        local setId = out.slots[pair.slot]
        if setId then
            if modelCall("SetSlot", buildId, pair.slot, setId) then
                stored = stored + 1
            else
                out.skipped = (out.skipped or 0) + 1
                out.reasons.rejected = (out.reasons.rejected or 0) + 1
            end
        end
    end
    out.assigned = stored

    Armory.SetBuildOwner(buildId, Armory.CurrentCharacterKey())

    local rec = modelCall("GetBuild", buildId)
    out.buildId = buildId
    out.name    = (type(rec) == "table" and rec.name) or name

    if stored == 0 then
        -- Everything the read found was refused by the model. Do not leave an
        -- empty shell behind pretending to be an import.
        modelCall("DeleteBuild", buildId)
        out.buildId = nil
        out.name    = nil
        out.error   = L("SI_ACCOUNTHOLD_ARMORY_IMPORT_REJECTED",
            "The Armory gear was read but the build model refused every slot.")
        out.message = out.error
        return out
    end

    out.message = Armory.FormatImportReport(out)
    -- Also copy the Armory build's exact gear, bars and stars so the imported
    -- build is equippable at once (src/BuildEquip.lua, GetArmoryBuildSlotBoundId
    -- doc:20358). A failure here never undoes the set plan that already landed.
    local okLo, counts = equipCall("ImportLoadoutFromArmory", buildId, index)
    if okLo then
        out.loadout = counts
        out.message = out.message .. " " .. L("SI_ACCOUNTHOLD_ARMORY_IMPORT_LOADOUT",
            "Its gear, skills and champion stars were saved too, so it can be equipped from here.")
    end
    diag("info", "Imported Armory build %d as %q (%d slots).", index, tostring(out.name), stored)
    return out
end

-- ---------------------------------------------------------------------------
-- Row icons
-- ---------------------------------------------------------------------------
-- Every path was read out of esoui/esoui@master. A texture path that does not
-- resolve draws an empty square on a TV, so an element with no verified art
-- gets nil and ZO_SharedGamepadEntryIconSetup never shows the multi-icon (it
-- only calls icon:Show() inside `if numIcons > 0`).
--
--   gp_playerMenu_icon_character  ingame/contacts/gamepad/notifications_gamepad.lua
--                                 (NOTIFICATION_TYPE_POINTS_RESET)
--   gp_playerMenu_icon_skills / _champion  armory_gamepad.lua:431-451
--   newBuild_Icon                 armory_gamepad.lua:416
--   gp_playerMenu_icon_itemSetCollections
--                                 ingame/collections/itemsetcollectionsdata.lua
--                                 ZO_ItemSetCollectionSummaryCategoryData:GetGamepadIcon
--   ESO_Icon_Warning              ingame/contacts/keyboard/notifications_keyboard.lua
local ICON_CHARACTER = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_character.dds"
local ICON_BUILD     = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_skills.dds"
local ICON_NEW_BUILD = "EsoUI/Art/Armory/newBuild_Icon.dds"
local ICON_SET       = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_itemSetCollections.dds"
local ICON_WARNING   = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"

Armory._ICON_CHARACTER = ICON_CHARACTER
Armory._ICON_BUILD     = ICON_BUILD
Armory._ICON_NEW_BUILD = ICON_NEW_BUILD
Armory._ICON_SET       = ICON_SET
Armory._ICON_WARNING   = ICON_WARNING

-- ZO_GetGamepadClassIcon(classId) -- publicallingames/globals/sharedtextures.lua.
-- Optional everywhere: a client without it, or a row with no classId (a build
-- tagged to a character this client cannot see), falls back to the player-menu
-- character icon rather than to nothing.
function Armory.ClassIcon(classId)
    classId = tonumber(classId)
    if classId then
        local fn = gfn("ZO_GetGamepadClassIcon") or gfn("GetGamepadClassIcon")
        if fn then
            local ok, icon = pcall(fn, classId)
            if ok and type(icon) == "string" and icon ~= "" then return icon end
        end
    end
    return ICON_CHARACTER
end

-- The icon the base game itself uses for a set: its Item Set Collection
-- category gamepad icon, or failing that the icon of the set's first piece.
-- Both routes are copied from ingame/collections/itemsetcollectionsdata.lua
-- (ZO_ItemSetCollectionCategoryData:GetGamepadIcon and
-- ZO_ItemSetCollectionPieceData:GetIcon / :InternalCreateItemLink).
function Armory.SetIcon(setId)
    setId = tonumber(setId)
    if not setId then return ICON_SET end

    local categoryId = callGame("GetItemSetCollectionCategoryId", setId)
    if categoryId ~= nil then
        local icon = callGame("GetItemSetCollectionCategoryGamepadIcon", categoryId)
        if type(icon) == "string" and icon ~= "" then return icon end
    end

    local link = Armory.SetPieceLink(setId)
    if link then
        local icon = callGame("GetItemLinkIcon", link)
        if type(icon) == "string" and icon ~= "" then return icon end
    end

    return ICON_SET
end

-- A real item link for a set, used both for the icon and for display-quality
-- colouring. nil when this client has no Item Set Collections API, which is the
-- normal case on very old clients and always the case in the harness.
function Armory.SetPieceLink(setId)
    setId = tonumber(setId)
    if not setId then return nil end
    local pieceId = callGame("GetItemSetCollectionPieceInfo", setId, 1)
    if pieceId == nil then return nil end
    local link = callGame("GetItemSetCollectionPieceItemLink", pieceId,
                          gconst("LINK_STYLE_DEFAULT"), gconst("ITEM_TRAIT_TYPE_NONE"))
    if type(link) == "string" and link ~= "" then return link end
    return nil
end

-- The empty-slot artwork the character sheet and the real Armory both use:
-- ZO_Character_GetEmptyEquipSlotTexture(equipSlot)
-- (publicallingames/character/character_utils.lua), called exactly as
-- armory_gamepad.lua does for a slot with nothing in it. Our slot keys are
-- names, so the EQUIP_SLOT_* constant is resolved through the same name map the
-- importer uses -- never a hard-coded number.
function Armory.SlotIcon(slotKey)
    if type(slotKey) ~= "string" then return nil end
    local fn = gfn("ZO_Character_GetEmptyEquipSlotTexture")
    if not fn then return nil end
    for _, pair in ipairs(Armory.ResolveEquipSlots()) do
        if pair.slot == slotKey then
            local ok, icon = pcall(fn, pair.equipSlot)
            if ok and type(icon) == "string" and icon ~= "" then return icon end
            return nil
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Row text -- pure formatting, testable without any UI
-- ---------------------------------------------------------------------------

function Armory.FormatCharacterRow(row)
    if type(row) ~= "table" then return "" end
    local name = row.name or "?"
    if row.isCurrent then
        name = fmt(L("SI_ACCOUNTHOLD_ARMORY_CURRENT_CHAR", "%s (current)"), name)
    elseif row.isUnknown then
        -- A build tagged to a character this client cannot name. Say so instead
        -- of showing a bare id64 and letting the player think it is corrupt.
        name = fmt(L("SI_ACCOUNTHOLD_ARMORY_UNKNOWN_CHAR", "%s (character not on this account?)"), name)
    end
    if (row.buildCount or 0) == 1 then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_CHAR_ONE", "%s  -  1 build"), name)
    end
    return fmt(L("SI_ACCOUNTHOLD_ARMORY_CHAR_MANY", "%s  -  %d builds"), name, row.buildCount or 0)
end

function Armory.FormatBuildRow(row)
    if type(row) ~= "table" then return "" end
    local name = row.name or "?"
    if (row.assigned or 0) == 0 then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_BUILD_EMPTY", "%s  -  no sets assigned"), name)
    end
    if (row.missing or 0) == 0 then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_BUILD_COMPLETE", "%s  -  %d slots, complete"),
            name, row.assigned or 0)
    end
    return fmt(L("SI_ACCOUNTHOLD_ARMORY_BUILD_MISSING", "%s  -  %d slots, %d missing"),
        name, row.assigned or 0, row.missing or 0)
end

function Armory.FormatSlotRow(row)
    if type(row) ~= "table" then return "" end
    local label = row.label or row.slot or "?"
    if not row.setId then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_SLOT_EMPTY", "%s  -  empty"), label)
    end
    local setName = row.setName or Armory.SetName(row.setId)
    local state
    if row.owned then
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_OWNED", "owned")
    elseif row.reconstructable then
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_RECON", "reconstructable")
    else
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_MISSING", "missing")
    end
    return fmt(L("SI_ACCOUNTHOLD_ARMORY_SLOT_SET", "%s  -  %s (%s)"), label, setName, state)
end

function Armory.FormatSetRow(row)
    if type(row) ~= "table" then return "" end
    local name = row.name or Armory.SetName(row.setId)
    if (row.count or 0) > 0 then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_SET_OWNED", "%s  -  %d owned"), name, row.count)
    end
    return name
end

function Armory.FormatPrioritizeResult(res)
    if type(res) ~= "table" then return "" end
    if (res.total or 0) == 0 then
        return L("SI_ACCOUNTHOLD_ARMORY_PRIO_NONE",
            "Nothing to add - you already own every piece in this build.")
    end
    if (res.added or 0) == 0 then
        return L("SI_ACCOUNTHOLD_ARMORY_PRIO_ALL_PRESENT",
            "Every set this build needs is already in Priorities.")
    end
    if (res.present or 0) > 0 then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_PRIO_SOME",
            "Added %d set(s) to Priorities; %d were already there."), res.added, res.present)
    end
    return fmt(L("SI_ACCOUNTHOLD_ARMORY_PRIO_ADDED", "Added %d set(s) to Priorities."), res.added)
end

-- ---------------------------------------------------------------------------
-- Native row shape -- name on the main label, detail on sub-labels
-- ---------------------------------------------------------------------------
-- The Format*Row functions above fold everything onto one line with "  -  "
-- separators. That is what the player saw and objected to, and it is also the
-- only thing a client with no ZO_GamepadEntryData can render -- so they stay,
-- as the fallback.
--
-- These functions produce the NATIVE shape instead: a short mixed-case name for
-- the main label and each piece of detail as its own sub-label, exactly like
-- armory_gamepad.lua:404-421 (build rows: name only) and :492-517 (gear rows:
-- item name only, state carried by colour and icon).
--
-- All of them are PURE: no ZO_* global, no state, no side effects. Every one is
-- callable from the harness with nothing loaded.

function Armory.CharacterRowLabels(row)
    if type(row) ~= "table" then return "?", {} end
    local name = row.name or "?"
    local subs = {}
    if row.isCurrent then
        subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_CURRENT", "Currently playing")
    elseif row.isUnknown then
        subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_UNKNOWN_CHAR",
                            "Not a character on this account")
    end
    if type(row.level) == "number" and row.level > 0 then
        subs[#subs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_LEVEL", "Level %d"), row.level)
    end
    local count = row.buildCount or 0
    if count == 1 then
        subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_ONE_BUILD", "1 build")
    else
        subs[#subs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_MANY_BUILDS", "%d builds"), count)
    end
    return name, subs
end

function Armory.BuildRowLabels(row)
    if type(row) ~= "table" then return "?", {} end
    local name = row.name or "?"
    local subs = {}
    local assigned, missing = row.assigned or 0, row.missing or 0
    if assigned == 0 then
        subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_NO_SETS", "No sets assigned")
    else
        subs[#subs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_SLOTS", "%d slot(s) planned"), assigned)
        if missing == 0 then
            subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_COMPLETE", "Complete")
        else
            subs[#subs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_MISSING", "%d still to find"), missing)
        end
    end
    return name, subs
end

-- Gear rows follow armory_gamepad.lua:492-517 exactly: the SLOT is the row's
-- identity when it is empty, the SET is the row's identity when something is
-- planned for it, and the slot name then moves to a sub-label. That is the
-- difference between reading a gear list and reading a table of key/value
-- pairs.
function Armory.SlotRowLabels(row)
    if type(row) ~= "table" then return "?", {} end
    local label = row.label or row.slot or "?"
    if not row.setId then
        return label, { L("SI_ACCOUNTHOLD_ARMORY_SUB_EMPTY", "Empty") }
    end
    local setName = row.setName or "?"
    local state
    if row.owned then
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_OWNED", "owned")
    elseif row.reconstructable then
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_RECON", "reconstructable")
    else
        state = L("SI_ACCOUNTHOLD_ARMORY_STATE_MISSING", "missing")
    end
    local subs = { label, state }
    if type(row.locationLabel) == "string" and row.locationLabel ~= "" then
        subs[#subs + 1] = row.locationLabel
    end
    return setName, subs
end

function Armory.SetRowLabels(row)
    if type(row) ~= "table" then return "?", {} end
    local name = row.name or "?"
    local subs = {}
    if (row.count or 0) > 0 then
        subs[#subs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_OWNED", "%d owned"), row.count)
    else
        subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_NONE_OWNED", "None owned yet")
    end
    return name, subs
end

-- ---------------------------------------------------------------------------
-- Pages -- pure descriptor builders
-- ---------------------------------------------------------------------------
-- A descriptor is plain data: { id, text, header, action, ... }. Nothing in here
-- knows about ZO_GamepadEntryData, so every page can be asserted in the mock
-- harness, which has no UI globals at all.

local BACK_TEXT_ID   = "SI_ACCOUNTHOLD_ARMORY_BACK"
local BACK_TEXT_FALL = "Back"

local function backRow(list)
    list[#list + 1] = {
        id   = "back",
        text = L(BACK_TEXT_ID, BACK_TEXT_FALL),
        name = L(BACK_TEXT_ID, BACK_TEXT_FALL),
        action = "back",
    }
end

-- An informational row. Nothing happens when A is pressed, so it is drawn
-- disabled: ZO_SharedGamepadEntry_OnSetup dims a row whose entryData reports
-- enabled == false (zo_gamepadtemplatescommon.lua, ZO_SharedGamepadEntryLabelSetup
-- and ZO_SharedGamepadEntryIconColorize both branch on data.enabled). A row that
-- looks pressable and then does nothing is the bug the player reported on the
-- export page.
local function infoRow(list, id, text, subLabels)
    list[#list + 1] = {
        id        = id,
        text      = text,
        name      = text,
        subLabels = subLabels,
        action    = "noop",
        info      = true,
    }
end

local function pageCharacters()
    local out = {}

    -- QUICK EQUIP -- the closest console-legal thing to "a build on a
    -- quickslot" (see the header): this character's equippable builds, one A
    -- press each, at the very top of the screen.
    local current = Armory.CurrentCharacterKey()
    if current then
        local quick = Armory.QuickEquipRows(current)
        local qHeader = fmt(L("SI_ACCOUNTHOLD_ARMORY_HDR_QUICK", "Quick equip - %s"), Armory.CurrentCharacterName())
        for i = 1, #quick do
            local q = quick[i]
            local subs = {}
            if q.equipped then
                subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_EQUIPPED", "Equipped")
            else
                subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_PRESS_EQUIP", "Press A to equip")
            end
            if q.auto then subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_ON", "Auto-equip on") end
            if q.pending then subs[#subs + 1] = L("SI_ACCOUNTHOLD_ARMORY_SUB_QUEUED", "Queued until out of combat") end
            out[#out + 1] = {
                id        = "quick:" .. tostring(q.id),
                text      = fmt(L("SI_ACCOUNTHOLD_ARMORY_QUICK_ROW", "Equip %s"), q.name),
                name      = q.name,
                subLabels = subs,
                icon      = ICON_BUILD,
                header    = (i == 1) and qHeader or nil,
                action    = "equipBuild",
                buildId   = q.id,
            }
        end
    end

    local rows = Armory.CharacterRows()
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_CHARACTERS", "Characters")
    if #rows == 0 then
        infoRow(out, "nochars", L("SI_ACCOUNTHOLD_ARMORY_NO_CHARS",
            "No characters known yet. Log in on a character to register it."))
        out[#out].header = header
    end
    for i = 1, #rows do
        local r = rows[i]
        local name, subs = Armory.CharacterRowLabels(r)
        out[#out + 1] = {
            id           = "char:" .. tostring(r.key),
            text         = Armory.FormatCharacterRow(r),
            name         = name,
            subLabels    = subs,
            icon         = r.isUnknown and ICON_WARNING or Armory.ClassIcon(r.classId),
            header       = (i == 1) and header or nil,
            action       = "openBuilds",
            characterKey = r.key,
            characterName = r.name,
        }
    end

    local untagged = Armory.CountUntaggedBuilds()
    if untagged > 0 then
        out[#out + 1] = {
            id            = "char:untagged",
            text          = fmt(L("SI_ACCOUNTHOLD_ARMORY_UNASSIGNED", "Unassigned builds  -  %d"), untagged),
            name          = L("SI_ACCOUNTHOLD_ARMORY_UNASSIGNED_TITLE", "Unassigned builds"),
            subLabels     = { fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_MANY_BUILDS", "%d builds"), untagged) },
            icon          = ICON_CHARACTER,
            header        = L("SI_ACCOUNTHOLD_ARMORY_HDR_OTHER", "Other"),
            action        = "openBuilds",
            characterKey  = nil,
            characterName = L("SI_ACCOUNTHOLD_ARMORY_UNASSIGNED_TITLE", "Unassigned builds"),
        }
    end

    out[#out + 1] = {
        id     = "armory:import",
        text   = L("SI_ACCOUNTHOLD_ARMORY_IMPORT", "Import from the in-game Armory"),
        name   = L("SI_ACCOUNTHOLD_ARMORY_IMPORT", "Import from the in-game Armory"),
        subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_IMPORT",
                        "Copy a build you already saved at an Armory Station") },
        icon   = ICON_NEW_BUILD,
        header = L("SI_ACCOUNTHOLD_ARMORY_HDR_ARMORY", "In-game Armory"),
        action = "openImport",
    }
    -- Export is real now, in two halves (see the header): equip the build here,
    -- save it at an Armory Station. This row explains the flow and shows any
    -- export still waiting for a station.
    local pendingExport = equipCall("GetPendingExport")
    out[#out + 1] = {
        id     = "armory:export",
        text   = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_ROW", "Save a build into the in-game Armory"),
        name   = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_ROW", "Save a build into the in-game Armory"),
        subLabels = { pendingExport
            and fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_EXPORT_PENDING", "Waiting for an Armory Station (slot %d)"),
                    tonumber(pendingExport.armoryIndex) or 0)
            or L("SI_ACCOUNTHOLD_ARMORY_SUB_HOW", "How it works") },
        icon   = ICON_NEW_BUILD,
        action = "openExport",
    }
    return out
end

local function pageBuilds(page)
    local out = {}
    local rows = Armory.BuildRows(page.characterKey)
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_BUILDS", "Builds")
    if #rows == 0 then
        infoRow(out, "nobuilds", L("SI_ACCOUNTHOLD_ARMORY_NO_BUILDS",
            "No builds yet. Create one below."))
        out[1].header = header
    end
    for i = 1, #rows do
        local r = rows[i]
        local name, subs = Armory.BuildRowLabels(r)
        out[#out + 1] = {
            id        = "build:" .. tostring(r.id),
            text      = Armory.FormatBuildRow(r),
            name      = name,
            subLabels = subs,
            icon      = ICON_BUILD,
            header    = (i == 1) and header or nil,
            action    = "openBuild",
            buildId   = r.id,
        }
    end

    out[#out + 1] = {
        id     = "builds:create",
        text   = L("SI_ACCOUNTHOLD_ARMORY_CREATE", "Create a build"),
        name   = L("SI_ACCOUNTHOLD_ARMORY_CREATE", "Create a build"),
        icon   = ICON_NEW_BUILD,
        header = L("SI_ACCOUNTHOLD_ARMORY_HDR_ACTIONS", "Actions"),
        action = "openCreate",
    }
    out[#out + 1] = {
        id     = "builds:import",
        text   = L("SI_ACCOUNTHOLD_ARMORY_IMPORT", "Import from the in-game Armory"),
        name   = L("SI_ACCOUNTHOLD_ARMORY_IMPORT", "Import from the in-game Armory"),
        icon   = ICON_NEW_BUILD,
        action = "openImport",
    }
    backRow(out)
    return out
end

local function pageBuild(page)
    local out = {}

    -- LOADOUT -- what Equip puts on, laid out like the native Armory station's
    -- middle panel: Skills (both bars), Champion, then Weapons / Apparel.
    local loHeader = L("SI_ACCOUNTHOLD_ARMORY_HDR_LOADOUT", "Equipment saved in this build")
    local d = equipCall("DescribeLoadout", page.buildId)
    if type(d) ~= "table" then
        infoRow(out, "loadout:none", L("SI_ACCOUNTHOLD_ARMORY_NO_LOADOUT",
            "Nothing saved to equip yet. Press Y (Save Build) to save what you are wearing now."))
        out[#out].header = loHeader
    else
        local function listRow(id, label, names, emptyText, header)
            local subs = {}
            if #names == 0 then subs[1] = emptyText
            else for i = 1, #names do subs[#subs + 1] = names[i] end end
            infoRow(out, id, fmt("%s: %s", label, (#names == 0) and emptyText or table.concat(names, ", ")), subs)
            out[#out].name = label
            out[#out].icon = ICON_BUILD
            out[#out].header = header
        end
        listRow("loadout:front", L("SI_ACCOUNTHOLD_ARMORY_FRONT_BAR", "Skills - front bar"),
            d.bars.primary or {}, L("SI_ACCOUNTHOLD_ARMORY_SUB_EMPTY", "Empty"), loHeader)
        listRow("loadout:back", L("SI_ACCOUNTHOLD_ARMORY_BACK_BAR", "Skills - back bar"),
            d.bars.backup or {}, L("SI_ACCOUNTHOLD_ARMORY_SUB_EMPTY", "Empty"))
        listRow("loadout:cp", L("SI_ACCOUNTHOLD_ARMORY_CHAMPION", "Champion"),
            d.cp or {}, L("SI_ACCOUNTHOLD_ARMORY_SUB_EMPTY", "Empty"))
        local gearSubs = { fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_GEAR_HERE", "%d of %d on this character"),
                               d.gearHere or 0, d.gearSaved or 0) }
        if type(d.missing) == "table" and #d.missing > 0 then
            gearSubs[#gearSubs + 1] = fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_GEAR_MISSING", "Not found: %s"),
                table.concat(d.missing, ", "))
        end
        infoRow(out, "loadout:gear", fmt(L("SI_ACCOUNTHOLD_ARMORY_GEAR_SAVED", "Weapons & apparel: %d saved"),
            d.gearSaved or 0), gearSubs)
        out[#out].icon = ICON_SET
    end
    -- Food is pickable even before a loadout exists.
    local foodName = (type(d) == "table") and d.food or nil
    out[#out + 1] = {
        id        = "loadout:food",
        text      = fmt(L("SI_ACCOUNTHOLD_ARMORY_FOOD_ROW", "Food: %s"),
                        foodName or L("SI_ACCOUNTHOLD_ARMORY_NONE", "none")),
        name      = fmt(L("SI_ACCOUNTHOLD_ARMORY_FOOD_ROW", "Food: %s"),
                        foodName or L("SI_ACCOUNTHOLD_ARMORY_NONE", "none")),
        subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_FOOD", "Eaten when this build is equipped") },
        icon      = ICON_BUILD,
        action    = "openFood",
        buildId   = page.buildId,
    }

    local rows = Armory.SlotRows(page.buildId)
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_GEAR", "Gear")
    for i = 1, #rows do
        local r = rows[i]
        -- Resolve the set name OUTSIDE the pure label builder, exactly as
        -- FormatSlotRow does, so SlotRowLabels stays ZO-free and testable.
        if r.setId and (type(r.setName) ~= "string" or r.setName == "") then
            r.setName = Armory.SetName(r.setId)
        end
        local name, subs = Armory.SlotRowLabels(r)
        -- armory_gamepad.lua:492-517: a filled slot shows the ITEM's icon and
        -- is coloured by DISPLAY quality; an empty slot shows the character
        -- sheet's empty-slot artwork.
        local icon, link
        if r.setId then
            link = Armory.SetPieceLink(r.setId)
            icon = Armory.SetIcon(r.setId)
        else
            icon = Armory.SlotIcon(r.slot)
        end
        out[#out + 1] = {
            id        = "slot:" .. tostring(r.slot),
            text      = Armory.FormatSlotRow(r),
            name      = name,
            subLabels = subs,
            icon      = icon,
            itemLink  = link,
            header    = (i == 1) and header or nil,
            action    = "openSlot",
            buildId   = page.buildId,
            slot      = r.slot,
        }
    end
    if #rows == 0 then
        infoRow(out, "noslots", L("SI_ACCOUNTHOLD_ARMORY_NO_SLOTS",
            "This build could not be read."))
        out[#out].header = header
    end

    -- AUTO-EQUIP -- off unless the player turns it on and adds a condition.
    local auto = equipCall("GetAuto", page.buildId)
    local nRules = (type(auto) == "table" and type(auto.rules) == "table") and #auto.rules or 0
    local autoOn = type(auto) == "table" and auto.enabled
    out[#out + 1] = {
        id        = "build:auto",
        text      = autoOn and fmt(L("SI_ACCOUNTHOLD_ARMORY_AUTO_ON_ROW", "Auto-equip: On (%d condition(s))"), nRules)
                           or L("SI_ACCOUNTHOLD_ARMORY_AUTO_OFF_ROW", "Auto-equip: Off"),
        name      = autoOn and fmt(L("SI_ACCOUNTHOLD_ARMORY_AUTO_ON_ROW", "Auto-equip: On (%d condition(s))"), nRules)
                           or L("SI_ACCOUNTHOLD_ARMORY_AUTO_OFF_ROW", "Auto-equip: Off"),
        subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_AUTO", "Zones, dungeons, trials and boss fights") },
        icon      = ICON_BUILD,
        header    = L("SI_ACCOUNTHOLD_ARMORY_HDR_AUTO", "Auto-equip"),
        action    = "openAuto",
        buildId   = page.buildId,
    }

    local actionsHeader = L("SI_ACCOUNTHOLD_ARMORY_HDR_ACTIONS", "Actions")
    local hasLoadout = equipCall("HasLoadout", page.buildId) and true or false
    if hasLoadout then
        out[#out + 1] = {
            id      = "build:equip",
            text    = L("SI_ACCOUNTHOLD_ARMORY_EQUIP", "Equip this build"),
            name    = L("SI_ACCOUNTHOLD_ARMORY_EQUIP", "Equip this build"),
            subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_EQUIP", "Gear, skills, champion stars and food") },
            icon    = ICON_BUILD,
            header  = actionsHeader,
            action  = "equipBuild",
            buildId = page.buildId,
        }
    end
    out[#out + 1] = {
        id      = "build:capture",
        text    = L("SI_ACCOUNTHOLD_ARMORY_CAPTURE", "Save what I am wearing to this build"),
        name    = L("SI_ACCOUNTHOLD_ARMORY_CAPTURE", "Save what I am wearing to this build"),
        subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_CAPTURE", "Gear, both skill bars and champion stars") },
        icon    = ICON_NEW_BUILD,
        header  = (not hasLoadout) and actionsHeader or nil,
        action  = "captureLoadout",
        buildId = page.buildId,
    }
    if hasLoadout then
        out[#out + 1] = {
            id      = "build:export",
            text    = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_TO", "Save to an in-game Armory slot"),
            name    = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_TO", "Save to an in-game Armory slot"),
            subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_EXPORT_TO", "Equips it, then saves at the next Armory Station") },
            icon    = ICON_NEW_BUILD,
            action  = "openExportSlot",
            buildId = page.buildId,
        }
    end
    out[#out + 1] = {
        id      = "build:prioritize",
        text    = L("SI_ACCOUNTHOLD_ARMORY_PRIORITIZE", "Add missing sets to Priorities"),
        name    = L("SI_ACCOUNTHOLD_ARMORY_PRIORITIZE", "Add missing sets to Priorities"),
        icon    = ICON_SET,
        action  = "prioritize",
        buildId = page.buildId,
    }
    out[#out + 1] = {
        id      = "build:rename",
        text    = L("SI_ACCOUNTHOLD_ARMORY_RENAME", "Rename this build"),
        name    = L("SI_ACCOUNTHOLD_ARMORY_RENAME", "Rename this build"),
        icon    = ICON_BUILD,
        action  = "openRename",
        buildId = page.buildId,
    }

    local current = Armory.CurrentCharacterKey()
    if current and Armory.BuildOwner(page.buildId) ~= current then
        out[#out + 1] = {
            id      = "build:assign",
            text    = fmt(L("SI_ACCOUNTHOLD_ARMORY_ASSIGN", "Assign to %s"), Armory.CurrentCharacterName()),
            name    = fmt(L("SI_ACCOUNTHOLD_ARMORY_ASSIGN", "Assign to %s"), Armory.CurrentCharacterName()),
            icon    = ICON_CHARACTER,
            action  = "assignOwner",
            buildId = page.buildId,
        }
    end

    out[#out + 1] = {
        id      = "build:delete",
        text    = L("SI_ACCOUNTHOLD_ARMORY_DELETE", "Delete this build"),
        name    = L("SI_ACCOUNTHOLD_ARMORY_DELETE", "Delete this build"),
        icon    = ICON_WARNING,
        action  = "openConfirmDelete",
        buildId = page.buildId,
    }
    backRow(out)
    return out
end

local function pageSlot(page)
    local out = {}
    local assigned
    for _, r in ipairs(Armory.SlotRows(page.buildId)) do
        if r.slot == page.slot then assigned = r end
    end

    if assigned and assigned.setId then
        out[#out + 1] = {
            id      = "slot:clear",
            text    = L("SI_ACCOUNTHOLD_ARMORY_CLEAR_SLOT", "Clear this slot"),
            name    = L("SI_ACCOUNTHOLD_ARMORY_CLEAR_SLOT", "Clear this slot"),
            icon    = Armory.SlotIcon(page.slot),
            header  = L("SI_ACCOUNTHOLD_ARMORY_HDR_ASSIGNED", "Assigned"),
            action  = "clearSlot",
            buildId = page.buildId,
            slot    = page.slot,
        }
    end

    local sets = Armory.CandidateSets()
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_SETS", "Sets")
    if #sets == 0 then
        infoRow(out, "nosets", L("SI_ACCOUNTHOLD_ARMORY_NO_SETS",
            "No sets known yet. Scan a character, or add sets from Collections - Item Sets."))
        out[#out].header = header
    end
    for i = 1, #sets do
        local s = sets[i]
        local name, subs = Armory.SetRowLabels(s)
        out[#out + 1] = {
            id        = "set:" .. tostring(s.setId),
            text      = Armory.FormatSetRow(s),
            name      = name,
            subLabels = subs,
            icon      = Armory.SetIcon(s.setId),
            itemLink  = Armory.SetPieceLink(s.setId),
            header    = (i == 1) and header or nil,
            action    = "assignSet",
            buildId   = page.buildId,
            slot      = page.slot,
            setId     = s.setId,
        }
    end
    backRow(out)
    return out
end

local function pageName(page)
    local out = {}
    local names = modelCall("GetSuggestedNames")
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_NAME", "Choose a name")
    if type(names) ~= "table" or #names == 0 then
        names = { L("SI_ACCOUNTHOLD_BUILD_UNNAMED", "Unnamed Build") }
    end
    for i = 1, #names do
        out[#out + 1] = {
            id       = "name:" .. tostring(i),
            text     = names[i],
            name     = names[i],
            icon     = ICON_BUILD,
            header   = (i == 1) and header or nil,
            action   = (page.mode == "rename") and "applyRename" or "applyCreate",
            buildId  = page.buildId,
            newName  = names[i],
            characterKey = page.characterKey,
        }
    end
    backRow(out)
    return out
end

local function pageConfirm(page)
    local out = {}
    local rec = modelCall("GetBuild", page.buildId)
    local name = (type(rec) == "table" and rec.name) or "?"
    if page.kind == "capture" then
        out[#out + 1] = {
            id      = "confirm:capture",
            text    = fmt(L("SI_ACCOUNTHOLD_ARMORY_CONFIRM_CAPTURE", "Replace \"%s\" with what I am wearing"), name),
            name    = fmt(L("SI_ACCOUNTHOLD_ARMORY_CONFIRM_CAPTURE", "Replace \"%s\" with what I am wearing"), name),
            subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_CONFIRM_CAPTURE",
                            "The gear, skills and stars saved in it now are overwritten") },
            icon    = ICON_WARNING,
            header  = L("SI_ACCOUNTHOLD_ARMORY_HDR_CONFIRM", "Are you sure?"),
            action  = "confirmCapture",
            buildId = page.buildId,
        }
        out[#out + 1] = {
            id     = "confirm:no",
            text   = L("SI_ACCOUNTHOLD_ARMORY_CANCEL", "Cancel"),
            name   = L("SI_ACCOUNTHOLD_ARMORY_CANCEL", "Cancel"),
            action = "back",
        }
        return out
    end
    out[#out + 1] = {
        id      = "confirm:yes",
        text    = fmt(L("SI_ACCOUNTHOLD_ARMORY_CONFIRM_DELETE", "Delete \"%s\""), name),
        name    = fmt(L("SI_ACCOUNTHOLD_ARMORY_CONFIRM_DELETE", "Delete \"%s\""), name),
        icon    = ICON_WARNING,
        header  = L("SI_ACCOUNTHOLD_ARMORY_HDR_CONFIRM", "Are you sure?"),
        action  = "deleteBuild",
        buildId = page.buildId,
    }
    out[#out + 1] = {
        id     = "confirm:no",
        text   = L("SI_ACCOUNTHOLD_ARMORY_CANCEL", "Cancel"),
        name   = L("SI_ACCOUNTHOLD_ARMORY_CANCEL", "Cancel"),
        action = "back",
    }
    return out
end

local function pageImport()
    local out = {}
    local rows = Armory.ArmoryBuildRows()
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_IMPORT", "Your Armory builds")
    if #rows == 0 then
        -- "Nothing here" has two very different causes and the player has to be
        -- told which one it is, or this page is another silent dead end.
        local text
        if not Armory.HasArmoryApi() then
            text = L("SI_ACCOUNTHOLD_ARMORY_NO_ARMORY_API",
                "This client does not expose the Armory to add-ons, so nothing can be imported.")
            diag("warn", "Import page: the Armory API is not present on this client.")
        else
            text = L("SI_ACCOUNTHOLD_ARMORY_NO_ARMORY",
                "No unlocked Armory builds found on this character. Unlock one at an Armory Station first.")
            diag("info", "Import page: GetNumUnlockedArmoryBuilds reported 0 builds.")
        end
        infoRow(out, "noarmory", text)
        out[1].header = header
    end
    for i = 1, #rows do
        local r = rows[i]
        out[#out + 1] = {
            id         = "armorybuild:" .. tostring(r.index),
            text       = fmt("%d. %s", r.index, r.name),
            name       = r.name,
            subLabels  = { fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_ARMORY_SLOT", "Armory slot %d"), r.index) },
            icon       = ICON_NEW_BUILD,
            header     = (i == 1) and header or nil,
            action     = "importBuild",
            buildIndex = r.index,
        }
    end
    backRow(out)
    return out
end

-- How saving into the in-game Armory works, plus any export still waiting for
-- an Armory Station. The four statements are informational (drawn disabled);
-- the only actions are Cancel (when something is pending) and Back.
local function pageExport()
    local out = {}
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT", "Saving to the in-game Armory")
    infoRow(out, "export:1", L("SI_ACCOUNTHOLD_ARMORY_EXPORT_1",
        "1. Open one of your builds and choose \"Save to an in-game Armory slot\"."))
    out[1].header = header
    out[1].icon   = ICON_NEW_BUILD
    infoRow(out, "export:2", L("SI_ACCOUNTHOLD_ARMORY_EXPORT_2",
        "2. Quartermaster equips that build on this character - only ever out of combat."))
    infoRow(out, "export:3", L("SI_ACCOUNTHOLD_ARMORY_EXPORT_3",
        "3. Open any Armory Station. Quartermaster asks to save the build into the slot you picked; press A to save."))
    infoRow(out, "export:4", L("SI_ACCOUNTHOLD_ARMORY_EXPORT_4",
        "Why the extra step: ESO's SaveArmoryBuild only works at an Armory Station and saves what you are wearing, so the build has to be on you first."))
    local p = equipCall("GetPendingExport")
    if type(p) == "table" then
        local rec = modelCall("GetBuild", p.buildId)
        infoRow(out, "export:pending", fmt(L("SI_ACCOUNTHOLD_ARMORY_EXPORT_PENDING",
            "Waiting: \"%s\" into Armory slot %d."), (type(rec) == "table" and rec.name) or "?",
            tonumber(p.armoryIndex) or 0))
        out[#out].header = L("SI_ACCOUNTHOLD_ARMORY_HDR_PENDING", "Pending")
        out[#out + 1] = {
            id     = "export:cancel",
            text   = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_CANCEL", "Cancel the pending save"),
            name   = L("SI_ACCOUNTHOLD_ARMORY_EXPORT_CANCEL", "Cancel the pending save"),
            icon   = ICON_WARNING,
            action = "cancelExport",
        }
    end
    backRow(out)
    return out
end

-- Pick the in-game Armory slot a build should be saved into.
local function pageExportSlot(page)
    local out = {}
    local rows = Armory.ArmoryBuildRows()
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT_SLOT", "Choose an Armory slot")
    if #rows == 0 then
        infoRow(out, "noarmory", Armory.HasArmoryApi()
            and L("SI_ACCOUNTHOLD_ARMORY_NO_ARMORY",
                "No unlocked Armory builds found on this character. Unlock one at an Armory Station first.")
            or L("SI_ACCOUNTHOLD_ARMORY_NO_ARMORY_API_SAVE",
                "This client does not expose the Armory API, so nothing can be saved into it."))
        out[#out].header = header
    end
    for i = 1, #rows do
        local r = rows[i]
        out[#out + 1] = {
            id         = "exportslot:" .. tostring(r.index),
            text       = fmt("%d. %s", r.index, r.name),
            name       = r.name,
            subLabels  = { fmt(L("SI_ACCOUNTHOLD_ARMORY_SUB_ARMORY_SLOT", "Armory slot %d"), r.index),
                           L("SI_ACCOUNTHOLD_ARMORY_SUB_OVERWRITE", "Will be overwritten after you confirm at a station") },
            icon       = ICON_NEW_BUILD,
            header     = (i == 1) and header or nil,
            action     = "exportToArmory",
            buildId    = page.buildId,
            buildIndex = r.index,
        }
    end
    backRow(out)
    return out
end

local function ruleText(rule)
    if type(rule) ~= "table" then return "?" end
    local zone = rule.zoneName or (rule.zoneId and fmt("#%d", rule.zoneId)) or "?"
    if rule.kind == "zone" then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_ZONE", "When I enter %s"), zone)
    elseif rule.kind == "anyBoss" then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_ANY_BOSS", "When any boss appears in %s"), zone)
    end
    local bossName = rule.name
    local BE = AccountHold and AccountHold.BuildEquip
    if BE and type(BE._PlainName) == "function" then bossName = BE._PlainName(bossName) end
    if rule.zoneName then
        return fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_BOSS_IN", "When %s appears (%s)"), tostring(bossName), zone)
    end
    return fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_BOSS", "When %s appears"), tostring(bossName))
end
Armory.RuleText = ruleText

-- Auto-equip conditions. Console has no free text, so a condition is added FROM
-- WHERE THE PLAYER IS: the zone they are standing in, or a boss on screen.
local function pageAuto(page)
    local out = {}
    local auto = equipCall("GetAuto", page.buildId)
    if type(auto) ~= "table" then auto = { enabled = false, rules = {} } end
    local rules = type(auto.rules) == "table" and auto.rules or {}

    infoRow(out, "auto:info", L("SI_ACCOUNTHOLD_ARMORY_AUTO_INFO",
        "Auto-equip never acts in combat. A swap that triggers mid-fight waits until combat ends."))
    out[#out].header = L("SI_ACCOUNTHOLD_ARMORY_HDR_AUTO", "Auto-equip")
    if equipCall("HasLoadout", page.buildId) then
        out[#out + 1] = {
            id      = "auto:toggle",
            text    = auto.enabled and L("SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_OFF", "Turn auto-equip off")
                                    or L("SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_ON", "Turn auto-equip on"),
            name    = auto.enabled and L("SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_OFF", "Turn auto-equip off")
                                    or L("SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_ON", "Turn auto-equip on"),
            subLabels = { auto.enabled and L("SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_IS_ON", "Currently on")
                                        or L("SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_IS_OFF", "Currently off") },
            icon    = ICON_BUILD,
            action  = "toggleAuto",
            buildId = page.buildId,
        }
    else
        infoRow(out, "auto:noloadout", L("SI_ACCOUNTHOLD_ARMORY_AUTO_NEEDS_LOADOUT",
            "Save what you are wearing to this build first - there is nothing to equip yet."))
    end

    local condHeader = L("SI_ACCOUNTHOLD_ARMORY_HDR_CONDITIONS", "Conditions")
    if #rules == 0 then
        infoRow(out, "auto:norules", L("SI_ACCOUNTHOLD_ARMORY_AUTO_NO_RULES",
            "No conditions yet. Add one below while you are in the place you want."))
        out[#out].header = condHeader
    end
    for i = 1, #rules do
        out[#out + 1] = {
            id        = "auto:rule:" .. tostring(i),
            text      = ruleText(rules[i]),
            name      = ruleText(rules[i]),
            subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_REMOVE", "Press A to remove") },
            icon      = ICON_WARNING,
            header    = (i == 1) and condHeader or nil,
            action    = "removeRule",
            buildId   = page.buildId,
            ruleIndex = i,
        }
    end

    local addHeader = L("SI_ACCOUNTHOLD_ARMORY_HDR_ADD", "Add a condition")
    local zoneId, zoneName = equipCall("CurrentZone")
    local first = true
    local function addRow(id, rule)
        out[#out + 1] = {
            id      = id,
            text    = ruleText(rule),
            name    = ruleText(rule),
            subLabels = { L("SI_ACCOUNTHOLD_ARMORY_SUB_ADD", "Press A to add") },
            icon    = ICON_NEW_BUILD,
            header  = first and addHeader or nil,
            action  = "addRule",
            buildId = page.buildId,
            rule    = rule,
        }
        first = false
    end
    if type(zoneId) == "number" then
        addRow("auto:add:zone", { kind = "zone", zoneId = zoneId, zoneName = zoneName })
        addRow("auto:add:anyboss", { kind = "anyBoss", zoneId = zoneId, zoneName = zoneName })
    end
    local bosses = equipCall("CurrentBosses")
    if type(bosses) == "table" and #bosses > 0 then
        for i = 1, #bosses do
            addRow("auto:add:boss:" .. i, { kind = "boss", name = bosses[i], zoneId = zoneId, zoneName = zoneName })
        end
    else
        infoRow(out, "auto:nobosses", L("SI_ACCOUNTHOLD_ARMORY_AUTO_NO_BOSS",
            "To add a specific boss, open this page while that boss's health bar is on screen."))
        if first then out[#out].header = addHeader; first = false end
    end
    backRow(out)
    return out
end

-- Food picker: food and drink in this character's backpack.
local function pageFood(page)
    local out = {}
    local header = L("SI_ACCOUNTHOLD_ARMORY_HDR_FOOD", "Food and drink in your backpack")
    local lo = equipCall("GetLoadout", page.buildId)
    if type(lo) == "table" and type(lo.food) == "table" then
        out[#out + 1] = {
            id      = "food:clear",
            text    = L("SI_ACCOUNTHOLD_ARMORY_FOOD_CLEAR", "No food for this build"),
            name    = L("SI_ACCOUNTHOLD_ARMORY_FOOD_CLEAR", "No food for this build"),
            icon    = ICON_WARNING,
            header  = L("SI_ACCOUNTHOLD_ARMORY_HDR_ASSIGNED", "Assigned"),
            action  = "clearFood",
            buildId = page.buildId,
        }
    end
    local list = equipCall("ListFood")
    if type(list) ~= "table" or #list == 0 then
        infoRow(out, "food:none", L("SI_ACCOUNTHOLD_ARMORY_FOOD_NONE",
            "No food or drink in your backpack. Carry the one you want, then come back."))
        out[#out].header = header
        list = {}
    end
    for i = 1, #list do
        local f = list[i]
        out[#out + 1] = {
            id      = "food:" .. tostring(f.itemId),
            text    = f.name,
            name    = f.name,
            itemLink = f.link,
            icon    = ICON_BUILD,
            header  = (i == 1) and header or nil,
            action  = "setFood",
            buildId = page.buildId,
            itemId  = f.itemId,
            foodLink = f.link,
            foodName = f.name,
        }
    end
    backRow(out)
    return out
end

-- The single entry point every page goes through. Always returns an array,
-- never nil, so a rebuild can never iterate over garbage.
function Armory.PageEntries(page)
    if type(page) ~= "table" then return {} end
    local ok, rows
    if page.page == PAGE_CHARACTERS then
        ok, rows = pcall(pageCharacters, page)
    elseif page.page == PAGE_BUILDS then
        ok, rows = pcall(pageBuilds, page)
    elseif page.page == PAGE_BUILD then
        ok, rows = pcall(pageBuild, page)
    elseif page.page == PAGE_SLOT then
        ok, rows = pcall(pageSlot, page)
    elseif page.page == PAGE_NAME then
        ok, rows = pcall(pageName, page)
    elseif page.page == PAGE_CONFIRM then
        ok, rows = pcall(pageConfirm, page)
    elseif page.page == PAGE_IMPORT then
        ok, rows = pcall(pageImport, page)
    elseif page.page == PAGE_EXPORT then
        ok, rows = pcall(pageExport, page)
    elseif page.page == PAGE_EXPORT_SLOT then
        ok, rows = pcall(pageExportSlot, page)
    elseif page.page == PAGE_AUTO then
        ok, rows = pcall(pageAuto, page)
    elseif page.page == PAGE_FOOD then
        ok, rows = pcall(pageFood, page)
    else
        return {}
    end
    if not ok or type(rows) ~= "table" then
        diag("error", "page %q failed to build: %s", tostring(page.page), tostring(rows))
        return { { id = "error", text = L("SI_ACCOUNTHOLD_ARMORY_PAGE_ERROR",
            "This page could not be built."), action = "back" } }
    end
    return rows
end

function Armory.PageTitle(page)
    if type(page) ~= "table" then return L("SI_ACCOUNTHOLD_ARMORY_TITLE", "Quartermaster Armory") end
    local p = page.page
    if p == PAGE_BUILDS then
        return page.characterName or L("SI_ACCOUNTHOLD_ARMORY_HDR_BUILDS", "Builds")
    elseif p == PAGE_BUILD then
        local rec = modelCall("GetBuild", page.buildId)
        return (type(rec) == "table" and rec.name) or L("SI_ACCOUNTHOLD_ARMORY_HDR_BUILDS", "Builds")
    elseif p == PAGE_SLOT then
        local label = modelCall("GetSlotLabel", page.slot)
        return (type(label) == "string" and label) or tostring(page.slot)
    elseif p == PAGE_NAME then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_NAME", "Choose a name")
    elseif p == PAGE_CONFIRM then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_CONFIRM", "Are you sure?")
    elseif p == PAGE_IMPORT then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_IMPORT", "Your Armory builds")
    elseif p == PAGE_EXPORT then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT", "Saving to the in-game Armory")
    elseif p == PAGE_EXPORT_SLOT then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT_SLOT", "Choose an Armory slot")
    elseif p == PAGE_AUTO then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_AUTO", "Auto-equip")
    elseif p == PAGE_FOOD then
        return L("SI_ACCOUNTHOLD_ARMORY_HDR_FOOD_TITLE", "Food")
    end
    return L("SI_ACCOUNTHOLD_ARMORY_TITLE", "Quartermaster Armory")
end

function Armory.PageBody(page)
    if type(page) ~= "table" then return "" end
    local p = page.page
    if p == PAGE_CHARACTERS then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_CHARACTERS",
            "Create builds, save what you are wearing into them, and equip them with one press. Plan the sets each character still needs.")
    elseif p == PAGE_BUILD then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_BUILD",
            "X equips this build. Y saves what you are wearing into it.")
    elseif p == PAGE_SLOT then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_SLOT",
            "Pick the set you want in this slot.")
    elseif p == PAGE_NAME then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_NAME",
            "There is no text entry here on console, so pick a name from the list. You can rename the build later.")
    elseif p == PAGE_IMPORT then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_IMPORT",
            "This reads the Armory of the character you are playing and creates a matching Quartermaster build.")
    elseif p == PAGE_EXPORT then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_EXPORT",
            "Quartermaster equips the build first, then saves it at the next Armory Station you open - after you confirm.")
    elseif p == PAGE_EXPORT_SLOT then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_EXPORT_SLOT",
            "Pick the in-game Armory slot. Nothing is overwritten until you confirm at an Armory Station.")
    elseif p == PAGE_AUTO then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_AUTO",
            "Equip this build automatically when you enter a zone, dungeon or trial, or when a boss appears. Off unless you turn it on.")
    elseif p == PAGE_FOOD then
        return L("SI_ACCOUNTHOLD_ARMORY_BODY_FOOD",
            "This food is eaten each time you equip the build yourself. Auto-equip does not re-eat it when the same build is put back on.")
    end
    return ""
end

-- ---------------------------------------------------------------------------
-- Actions -- what pressing A on a row does
-- ---------------------------------------------------------------------------
-- Every handler returns one of:
--   "rebuild" -- the page changed, redraw the open dialog
--   "close"   -- release the dialog
--   nil       -- nothing happened, leave the dialog exactly as it is
-- Handlers mutate the nav stack and the model and NOTHING else, so they run
-- unchanged (and are asserted) under the mock harness.

local ACTIONS = {}

ACTIONS.noop = function() return nil end

ACTIONS.back = function()
    if Armory.NavPop(Armory._nav) then return "rebuild" end
    return "close"
end

ACTIONS.openBuilds = function(desc)
    push({ page = PAGE_BUILDS, characterKey = desc.characterKey, characterName = desc.characterName })
    return "rebuild"
end

ACTIONS.openBuild = function(desc)
    push({ page = PAGE_BUILD, buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.openSlot = function(desc)
    push({ page = PAGE_SLOT, buildId = desc.buildId, slot = desc.slot })
    return "rebuild"
end

ACTIONS.openCreate = function()
    local page = top()
    push({ page = PAGE_NAME, mode = "create", characterKey = page.characterKey })
    return "rebuild"
end

ACTIONS.openRename = function(desc)
    push({ page = PAGE_NAME, mode = "rename", buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.openConfirmDelete = function(desc)
    push({ page = PAGE_CONFIRM, buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.openImport = function()
    push({ page = PAGE_IMPORT })
    return "rebuild"
end

-- Saving into the in-game Armory is real now (see the header): this page
-- explains the two halves and shows anything still waiting for a station.
ACTIONS.openExport = function()
    diag("info", "Export help opened.")
    push({ page = PAGE_EXPORT })
    return "rebuild"
end

ACTIONS.openExportSlot = function(desc)
    if not equipCall("HasLoadout", desc.buildId) then
        alert(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_LOADOUT",
            "Save a loadout to this build first - the Armory stores what you are wearing."))
        return nil
    end
    push({ page = PAGE_EXPORT_SLOT, buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.exportToArmory = function(desc)
    local ok = equipCall("RequestExport", desc.buildId, desc.buildIndex)
    if not ok then return "rebuild" end
    Armory.NavPop(Armory._nav)            -- back to the build
    return "rebuild"
end

ACTIONS.cancelExport = function()
    equipCall("CancelExport")
    alert(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FORGOTTEN", "Export cancelled. Nothing was saved."))
    return "rebuild"
end

-- One press. The engine refuses (and says why) when the gate is off, the build
-- belongs to another character or has nothing saved; in combat it queues.
ACTIONS.equipBuild = function(desc)
    if desc.buildId == nil then return nil end
    equipCall("Equip", desc.buildId, { reason = "manual" })
    return "rebuild"
end

local function doCapture(buildId)
    local ok, counts = equipCall("CaptureLoadout", buildId)
    if ok and type(counts) == "table" then
        local rec = modelCall("GetBuild", buildId)
        alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_CAPTURED",
            "Saved what you are wearing to \"%s\": %d gear, %d skills, %d champion stars."),
            (type(rec) == "table" and rec.name) or "?", counts.gear or 0, counts.skills or 0, counts.cp or 0))
        return true
    end
    return false
end

-- Y (Save Build). Overwriting an existing loadout asks first, like the native
-- Armory's save confirmation (armorydialogs.lua ARMORY_BUILD_SAVE_CONFIRM_DIALOG).
ACTIONS.captureLoadout = function(desc)
    local buildId = desc.buildId or Armory.CurrentBuildId()
    if buildId == nil then return nil end
    if equipCall("HasLoadout", buildId) then
        push({ page = PAGE_CONFIRM, kind = "capture", buildId = buildId })
        return "rebuild"
    end
    doCapture(buildId)
    return "rebuild"
end

ACTIONS.confirmCapture = function(desc)
    doCapture(desc.buildId)
    Armory.NavPop(Armory._nav)            -- leave the confirm page
    return "rebuild"
end

ACTIONS.openAuto = function(desc)
    push({ page = PAGE_AUTO, buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.toggleAuto = function(desc)
    local auto = equipCall("GetAuto", desc.buildId)
    local on = not (type(auto) == "table" and auto.enabled)
    if not equipCall("SetAutoEnabled", desc.buildId, on) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_AUTO_FAILED", "Could not change auto-equip for that build."))
        return nil
    end
    local n = (type(auto) == "table" and type(auto.rules) == "table") and #auto.rules or 0
    if on and n == 0 then
        alert(L("SI_ACCOUNTHOLD_ARMORY_AUTO_ON_EMPTY",
            "Auto-equip is on, but it has no conditions yet, so it will not do anything until you add one."))
    elseif on then
        alert(L("SI_ACCOUNTHOLD_ARMORY_AUTO_ON", "Auto-equip is on for this build."))
    else
        alert(L("SI_ACCOUNTHOLD_ARMORY_AUTO_OFF", "Auto-equip is off for this build."))
    end
    return "rebuild"
end

ACTIONS.addRule = function(desc)
    if not equipCall("AddRule", desc.buildId, desc.rule) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_RULE_FAILED", "Could not add that condition (the list may be full)."))
        return nil
    end
    alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_ADDED", "Added: %s."), ruleText(desc.rule)))
    return "rebuild"
end

ACTIONS.removeRule = function(desc)
    local auto = equipCall("GetAuto", desc.buildId)
    local rule = type(auto) == "table" and type(auto.rules) == "table" and auto.rules[desc.ruleIndex] or nil
    if not equipCall("RemoveRule", desc.buildId, desc.ruleIndex) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_RULE_REMOVE_FAILED", "Could not remove that condition."))
        return nil
    end
    alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_RULE_REMOVED", "Removed: %s."), ruleText(rule)))
    return "rebuild"
end

ACTIONS.openFood = function(desc)
    push({ page = PAGE_FOOD, buildId = desc.buildId })
    return "rebuild"
end

ACTIONS.setFood = function(desc)
    if not equipCall("SetFood", desc.buildId, desc.itemId, desc.foodLink, desc.foodName) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_FOOD_FAILED", "Could not set the food for that build."))
        return nil
    end
    Armory.NavPop(Armory._nav)
    return "rebuild"
end

ACTIONS.clearFood = function(desc)
    equipCall("SetFood", desc.buildId, nil)
    Armory.NavPop(Armory._nav)
    return "rebuild"
end

ACTIONS.applyCreate = function(desc)
    local buildId = modelCall("CreateBuild", desc.newName)
    if buildId == nil then
        alert(L("SI_ACCOUNTHOLD_ARMORY_CREATE_FAILED",
            "Could not create a build. You may have reached the build limit."))
        return nil
    end
    -- A build created from a character's page belongs to that character; one
    -- created from the unassigned bucket stays unassigned.
    Armory.SetBuildOwner(buildId, desc.characterKey)
    Armory.NavPop(Armory._nav)            -- leave the name picker
    push({ page = PAGE_BUILD, buildId = buildId })
    local rec = modelCall("GetBuild", buildId)
    alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_CREATED", "Created \"%s\"."),
        (type(rec) == "table" and rec.name) or desc.newName))
    return "rebuild"
end

ACTIONS.applyRename = function(desc)
    if not modelCall("RenameBuild", desc.buildId, desc.newName) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_RENAME_FAILED", "Could not rename that build."))
        return nil
    end
    Armory.NavPop(Armory._nav)
    return "rebuild"
end

ACTIONS.assignOwner = function(desc)
    local key = Armory.CurrentCharacterKey()
    if not key then return nil end
    if not Armory.SetBuildOwner(desc.buildId, key) then return nil end
    alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_ASSIGNED", "Assigned to %s."), Armory.CurrentCharacterName()))
    return "rebuild"
end

ACTIONS.deleteBuild = function(desc)
    local rec = modelCall("GetBuild", desc.buildId)
    local name = (type(rec) == "table" and rec.name) or "?"
    if not modelCall("DeleteBuild", desc.buildId) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_DELETE_FAILED", "Could not delete that build."))
        return nil
    end
    -- Pop the confirm page AND the build page: the build they were looking at no
    -- longer exists, so landing back on it would render an empty shell.
    Armory.NavPop(Armory._nav)
    Armory.NavPop(Armory._nav)
    alert(fmt(L("SI_ACCOUNTHOLD_ARMORY_DELETED", "Deleted \"%s\"."), name))
    return "rebuild"
end

ACTIONS.assignSet = function(desc)
    if not modelCall("SetSlot", desc.buildId, desc.slot, desc.setId) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_ASSIGN_FAILED", "Could not assign that set."))
        return nil
    end
    Armory.NavPop(Armory._nav)
    return "rebuild"
end

ACTIONS.clearSlot = function(desc)
    if not modelCall("SetSlot", desc.buildId, desc.slot, nil) then
        alert(L("SI_ACCOUNTHOLD_ARMORY_ASSIGN_FAILED", "Could not assign that set."))
        return nil
    end
    Armory.NavPop(Armory._nav)
    return "rebuild"
end

ACTIONS.prioritize = function(desc)
    local buildId = desc.buildId or top().buildId
    if buildId == nil then return nil end
    alert(Armory.FormatPrioritizeResult(Armory.PrioritizeBuild(buildId)))
    return "rebuild"
end

ACTIONS.importBuild = function(desc)
    local res = Armory.ImportArmoryBuild(desc.buildIndex)
    -- Loud either way. An import that finds nothing used to alert a single
    -- generic sentence; an import that found something alerted a count with no
    -- account of what it left behind. Both now report builds walked, slots
    -- resolved and every slot skipped WITH ITS REASON, to chat and to the
    -- diagnostic ring buffer the Settings panel can read back.
    alert(res.message or Armory.FormatImportReport(res))
    if res.error or res.buildId == nil then
        diag("warn", "Import of Armory build %s produced no build: %s",
            tostring(desc.buildIndex), tostring(res.error))
        return "rebuild"
    end
    Armory.NavPop(Armory._nav)            -- leave the import list
    push({ page = PAGE_BUILD, buildId = res.buildId })
    return "rebuild"
end

-- Never throws: this runs inside the base game's dialog button callback.
function Armory.Dispatch(desc)
    if type(desc) ~= "table" then return nil end
    local handler = ACTIONS[desc.action]
    if type(handler) ~= "function" then return nil end
    local ok, res = pcall(handler, desc)
    if not ok then
        diag("error", "action %q failed: %s", tostring(desc.action), tostring(res))
        return nil
    end
    return res
end

Armory._ACTIONS = ACTIONS

-- ---------------------------------------------------------------------------
-- Descriptor -> parametricList entry
-- ---------------------------------------------------------------------------

-- Build a real ZO_GamepadEntryData for a descriptor: mixed-case name on the
-- main label, each detail on its own sub-label, an icon, and display-quality
-- colouring where a genuine item link exists.
--
-- Verified construction, copied from the base game rather than invented:
--   ZO_GamepadEntryData:New(text, icon)   zo_gamepadentrydata.lua:10-11
--   :AddSubLabel(sub)                     :366-371  (there is NO SetSubLabels)
--   :SetSubLabelColors(colour)            :324
--   :SetShowUnselectedSublabels(true)     :379
--       -- the last two together are InitializeTradingHouseVisualData:48-52
--   :SetFontScaleOnSelection(false)       :35  "item entries don't grow on
--       selection" -- only menu/category rows scale
--   :SetIconTintOnSelection(true)         armory_gamepad.lua:305, :412
--   :SetIconDisabledTintOnSelection(true) armory_gamepad.lua:306
--   :SetNameColors(:GetColorsBasedOnQuality(displayQuality))  :32, :209-214
--   :SetEnabled(false) for a row that does nothing
--
-- ONE icon, never two: the icon goes in the constructor and AddIcon is never
-- also called, because a ZO_MultiIcon holding two textures CYCLES between them.
--
-- FAILS CLOSED. Any missing global, missing method or throw returns nil and
-- RenderEntries falls back to the flat text entry this screen already shipped.
function Armory.MakeEntryData(desc, sharedSetup)
    if type(desc) ~= "table" then return nil end
    local entryDataClass = gtable("ZO_GamepadEntryData")
    if not entryDataClass or type(entryDataClass.New) ~= "function" then return nil end

    local built
    local ok = pcall(function()
        local data = entryDataClass:New(desc.name or desc.text or "?", desc.icon)
        if type(data) ~= "table" then return end

        local function try(method, ...)
            if type(data[method]) == "function" then pcall(data[method], data, ...) end
        end

        if type(desc.subLabels) == "table" then
            for i = 1, #desc.subLabels do
                local sub = desc.subLabels[i]
                if type(sub) == "string" and sub ~= "" then try("AddSubLabel", sub) end
            end
        end
        local normal = gtable("ZO_NORMAL_TEXT")
        if normal then try("SetSubLabelColors", normal) end
        try("SetShowUnselectedSublabels", true)
        try("SetFontScaleOnSelection", false)
        try("SetIconTintOnSelection", true)
        try("SetIconDisabledTintOnSelection", true)
        if desc.info then try("SetEnabled", false) end

        -- DISPLAY quality, never functional quality (sharedinventory.lua:649,651).
        if type(desc.itemLink) == "string" and desc.itemLink ~= ""
           and type(data.GetColorsBasedOnQuality) == "function"
           and type(data.SetNameColors) == "function" then
            local quality = callGame("GetItemLinkDisplayQuality", desc.itemLink)
            if quality ~= nil then
                pcall(function() data:SetNameColors(data:GetColorsBasedOnQuality(quality)) end)
            end
        end

        -- A PREMADE entryData is used verbatim: zo_genericdialog_gamepad.lua
        -- only copies templateData onto the entry data when it BUILDS one
        -- (:801-819). setup and callback therefore have to live on the entry
        -- data itself, or :745 calls a nil setup and the whole rebuild throws.
        data.setup = sharedSetup
        data.callback = function(dialog) Armory.OnEntrySelected(desc, dialog) end
        data.accountHoldArmoryDesc = desc
        built = data
    end)

    if ok then return built end
    return nil
end

-- Turn page descriptors into entries the base rebuild loop understands.
-- `sharedSetup` is ZO_SharedGamepadEntry_OnSetup; it is passed in rather than
-- looked up so this stays callable (and assertable) with a stub.
function Armory.RenderEntries(descriptors, sharedSetup)
    local out = {}
    if type(descriptors) ~= "table" then return out end
    local template = Armory.EntryTemplate()
    for i = 1, #descriptors do
        local desc = descriptors[i]
        if type(desc) == "table" then
            local entry = {
                template = template,
                -- zo_genericdialog_gamepad.lua:801-807. A plain string, because
                -- the whole list is rebuilt on every navigation and on every
                -- model change -- there is no state a text function could see
                -- that this string does not already reflect. IGNORED when
                -- entryData is present (:800), so it is the fallback rendering
                -- for a client with no ZO_GamepadEntryData.
                text     = desc.text or "",
                icon     = desc.icon,
                header   = desc.header,
                templateData = {
                    -- :745 calls this UNCONDITIONALLY. An entry without it
                    -- throws inside the base rebuild loop.
                    setup    = sharedSetup,
                    callback = function(dialog)
                        Armory.OnEntrySelected(desc, dialog)
                    end,
                },
            }
            entry.templateData.accountHoldArmoryDesc = desc
            entry.entryData = Armory.MakeEntryData(desc, sharedSetup)
            out[#out + 1] = entry
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Dialog plumbing
-- ---------------------------------------------------------------------------

-- The info table the base rebuild loop will walk. ZO_Dialogs_RegisterCustomDialog
-- stores OUR table straight into ESO_Dialogs (zo_dialog.lua:1207-1209) and
-- ZO_Dialogs_ShowDialog copies that same reference onto dialog.info
-- (zo_dialog.lua:482), so all three handles are the same object. ESO_Dialogs is
-- read first because it is the one the game actually dereferences; the local
-- reference is the fallback for a client (or harness) that keeps its registry
-- somewhere else.
local function dialogInfo()
    local dialogs = gtable("ESO_Dialogs")
    if dialogs and type(dialogs[DIALOG_NAME]) == "table" then
        return dialogs[DIALOG_NAME]
    end
    if type(Armory._info) == "table" then return Armory._info end
    return nil
end

-- Replace our OWN parametricList in place. The base rebuild loop re-walks
-- dialog.info.parametricList with ipairs on every rebuild
-- (zo_genericdialog_gamepad.lua:785), so swapping the contents and asking for a
-- rebuild is all a level change needs. Nothing here touches base-game data.
function Armory.PopulateList()
    local info = dialogInfo()
    if not info or type(info.parametricList) ~= "table" then
        return refuse("populate:noinfo", "error",
            L("SI_ACCOUNTHOLD_ARMORY_NO_DIALOG", "The Armory could not open on this client."),
            "PopulateList: the registered dialog info is missing; the list cannot be built.")
    end

    local sharedSetup = gfn("ZO_SharedGamepadEntry_OnSetup")
    if not sharedSetup then
        return refuse("populate:nosetup", "error",
            L("SI_ACCOUNTHOLD_ARMORY_NO_DIALOG", "The Armory could not open on this client."),
            "PopulateList: ZO_SharedGamepadEntry_OnSetup is unavailable; every row would throw in the base rebuild loop (zo_genericdialog_gamepad.lua:745).")
    end

    local entries = Armory.RenderEntries(Armory.PageEntries(top()), sharedSetup)
    local list = info.parametricList
    for i = #list, 1, -1 do list[i] = nil end
    for i = 1, #entries do list[i] = entries[i] end
    clearRefusal()
    return true
end

-- The live dialog CONTROL, or nil.
--
-- `setup` captures it on every show (zo_dialog.lua:604-605), but a rebuild can
-- also be driven from a keybind callback that was handed the control directly,
-- and ZO_Dialogs_FindDialog (zo_dialog.lua:93-98) is the authoritative recovery
-- path when we somehow hold neither.
function Armory.DialogControl(dialog)
    if isControl(dialog) then return dialog end
    if isControl(Armory._dialog) then return Armory._dialog end
    local find = gfn("ZO_Dialogs_FindDialog")
    if find then
        local ok, ctrl = pcall(find, DIALOG_NAME)
        if ok and isControl(ctrl) then
            Armory._dialog = ctrl
            return ctrl
        end
    end
    return nil
end

-- Redraw the dialog that is already open. Called after every navigation and
-- after every model change, so the list can never show stale data.
--
-- THIS FUNCTION IS WHY THE WHOLE SCREEN WAS INERT. It used to require
-- type(dialog) == "table"; the base game passes a CONTROL, which is `userdata`
-- (see isControl above), so on a real client it returned false BEFORE the
-- rebuild. The nav stack moved, our parametricList was swapped out, and the
-- visible list never changed -- so Import, Export and every other row looked
-- like it did nothing. tests/zos_mock.lua stubs dialogs as plain tables, which
-- is exactly why nothing caught it.
function Armory.Refresh(dialog)
    if not Armory.PopulateList() then return false end

    local ctrl = Armory.DialogControl(dialog)
    if not ctrl then
        return refuse("refresh:nodialog", "error",
            L("SI_ACCOUNTHOLD_ARMORY_LOST_DIALOG",
              "The Armory screen lost its window and could not redraw. Close it with B and open it again."),
            "Refresh: no dialog control available (neither the argument, the captured handle, nor ZO_Dialogs_FindDialog).")
    end

    local page = top()
    local refreshText = gfn("ZO_GenericGamepadDialog_RefreshText")
    if refreshText then
        -- zo_genericdialog_gamepad.lua:408 -- (dialog, title, mainText, ...)
        pcall(refreshText, ctrl, Armory.PageTitle(page), Armory.PageBody(page))
    end

    -- zo_genericdialog_gamepad.lua:782 -- the exact primitive we want. It is a
    -- global in the live client, but a client (or a harness) that does not
    -- export it still has the SAME code reachable through the control's own
    -- setupFunc (:692 assigns ZO_GenericParametricListGamepadDialogTemplate_Setup,
    -- which calls RebuildEntryList at :736). Falling back is strictly better
    -- than refusing to redraw, which is the failure mode this file exists to
    -- eliminate.
    local rebuild = gfn("ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList")
    local rebuildArgs = ctrl
    if not rebuild then
        local gotFn, setupFunc = pcall(function() return ctrl.setupFunc end)
        if gotFn and type(setupFunc) == "function" then
            rebuild = setupFunc
        end
    end
    if not rebuild then
        return refuse("refresh:norebuild", "error",
            L("SI_ACCOUNTHOLD_ARMORY_NO_REBUILD",
              "This client cannot redraw the Armory list. Close it with B and open it again."),
            "Refresh: neither ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList (zo_genericdialog_gamepad.lua:782) nor dialog.setupFunc (:692) is available.")
    end

    local ok, err = pcall(rebuild, rebuildArgs)
    if not ok and Armory.DemoteTemplate() then
        diag("warn", "Armory redraw failed with the styled template (%s); retrying plain. %s",
            tostring(TEMPLATE), tostring(err))
        if Armory.PopulateList() then
            ok, err = pcall(rebuild, rebuildArgs)
        end
    end
    if not ok then
        return refuse("refresh:rebuildthrew", "error",
            L("SI_ACCOUNTHOLD_ARMORY_REBUILD_FAILED",
              "The Armory list could not be redrawn. Close it with B and open it again."),
            "Refresh: RebuildEntryList failed: %s", tostring(err))
    end

    -- The X button appears only on pages that have a build, so the strip has to
    -- be re-evaluated whenever the level changes
    -- (zo_genericdialog_gamepad.lua:277-279).
    local refreshKeybinds = gfn("ZO_GenericGamepadDialog_RefreshKeybinds")
    if refreshKeybinds then pcall(refreshKeybinds, ctrl) end

    -- A rebuild clears and re-commits the list; make sure it is still taking
    -- input. Guarded because these are methods on a base-game object, and the
    -- object is userdata, so no type(...) == "table" test may ever appear here.
    pcall(function()
        local list = ctrl.entryList
        if list ~= nil and type(list.Activate) == "function" then
            if type(list.IsActive) ~= "function" or not list:IsActive() then
                list:Activate()
            end
        end
    end)
    clearRefusal()
    return true
end

local function release()
    local f = gfn("ZO_Dialogs_ReleaseDialogOnButtonPress")
    if f then pcall(f, DIALOG_NAME) end
end

-- A on a row. blockDialogReleaseOnPress = true means A does NOT close the
-- dialog (zo_dialog.lua:1254), so every outcome is handled explicitly here.
--
-- A "rebuild" that cannot be drawn is the exact shape of the bug the player
-- reported, so it is reported rather than swallowed: Refresh already alerts,
-- and the diagnostic below names the action that was lost.
function Armory.OnEntrySelected(desc, dialog)
    local result = Armory.Dispatch(desc)
    if result == "rebuild" then
        if not Armory.Refresh(dialog) then
            diag("error", "action %q changed state but the screen could not be redrawn.",
                tostring(type(desc) == "table" and desc.action or "?"))
        end
    elseif result == "close" then
        release()
    end
end

-- The build the X button acts on: whichever level we are at that knows one.
function Armory.CurrentBuildId()
    local stack = Armory._nav
    if type(stack) ~= "table" then return nil end
    for i = #stack, 1, -1 do
        local p = stack[i]
        if type(p) == "table" and p.buildId ~= nil then return p.buildId end
    end
    return nil
end

function Armory.Register()
    if Armory._registered then return true end

    local register = gfn("ZO_Dialogs_RegisterCustomDialog")
    if not register then
        diag("warn", "ZO_Dialogs_RegisterCustomDialog unavailable - Armory NOT registered.")
        return false
    end

    local gamepadDialogs = gtable("GAMEPAD_DIALOGS")
    if not gamepadDialogs or gamepadDialogs.PARAMETRIC == nil then
        diag("warn", "GAMEPAD_DIALOGS.PARAMETRIC unavailable - Armory NOT registered.")
        return false
    end

    -- zo_genericdialog_gamepad.lua:745 -- an entry with no setup throws inside
    -- the base rebuild loop, so no shared setup helper means no dialog at all.
    if not gfn("ZO_SharedGamepadEntry_OnSetup") then
        diag("warn", "ZO_SharedGamepadEntry_OnSetup unavailable - Armory NOT registered.")
        return false
    end

    local info = {
        gamepadInfo = {
            dialogType = gamepadDialogs.PARAMETRIC,
            -- ZO_Dialogs_ShowGamepadDialog drops the request outright if no
            -- scene is showing yet (zo_dialog.lua:356-377). A console player
            -- opening this from a menu can easily land mid-transition, and a
            -- silently-dropped request is precisely the failure this add-on has
            -- already shipped three times. This makes the base game re-issue the
            -- show once the next scene is up (:358-371).
            allowShowOnNextScene = true,
        },

        -- Show a second Armory rather than dropping it when some other dialog is
        -- already up (zo_dialog.lua:435-440). The queue drains on hide
        -- (:977-981).
        canQueue = true,

        -- zo_dialog.lua:1247-1256 -- WE decide when this closes, so B can pop a
        -- level instead of tearing the whole screen down.
        blockDialogReleaseOnPress = true,

        title    = { text = L("SI_ACCOUNTHOLD_ARMORY_TITLE", "Quartermaster Armory") },
        mainText = { text = "" },

        -- Reached in TWO different situations (zo_dialog.lua:373-376 and
        -- :961-962) and they must not be confused:
        --   1. The show request could not be honoured at all: no scene was
        --      showing AND no next scene was pending, so allowShowOnNextScene
        --      had nothing to hang the retry on. `setup` never ran, so
        --      _showPending is still true. THIS is the failure the player saw
        --      as "Armory show request was dropped".
        --   2. The dialog opened and was later released without a button press.
        --      That is an ordinary close and must stay silent.
        -- A console player has no error log, so case 1 alone made this feature
        -- "do nothing". Say it on screen.
        noChoiceCallback = function()
            if not Armory._showPending then
                Armory._dialog = nil
                return
            end
            Armory._showPending = false
            Armory._showDropped = true
            refuse("show:dropped", "warn",
                L("SI_ACCOUNTHOLD_ARMORY_DROPPED",
                  "The Armory could not open because no screen was showing. Close the menu, then try again."),
                "Armory show request was dropped -- no scene was showing and no next scene was pending (zo_dialog.lua:373-376).")
        end,

        setup = function(dialog)
            Armory._dialog      = dialog
            Armory._showPending = false
            local page = top()
            local refreshText = gfn("ZO_GenericGamepadDialog_RefreshText")
            if refreshText then
                pcall(refreshText, dialog, Armory.PageTitle(page), Armory.PageBody(page))
            end
            -- The list must be populated BEFORE setupFunc runs: setupFunc walks
            -- dialog.info.parametricList immediately
            -- (zo_genericdialog_gamepad.lua:736).
            Armory.PopulateList()
            -- zo_genericdialog_gamepad.lua:692 -- a PARAMETRIC dialog only ever
            -- builds its list when the info table's setup calls setupFunc.
            -- Omitting this opens an empty dialog; that exact bug already cost a
            -- release, so its absence is reported, never ignored.
            --
            -- Read through pcall: `dialog` is userdata and indexing it is a
            -- metatable call, and this whole function runs inside the base
            -- game's show path (zo_dialog.lua:604-605) where a throw would abort
            -- the show with no message at all.
            local gotFn, setupFunc = pcall(function() return dialog.setupFunc end)
            if gotFn and type(setupFunc) == "function" then
                local ok, err = pcall(setupFunc, dialog)
                if not ok and Armory.DemoteTemplate() then
                    -- A client that lacks ZO_GamepadItemSubEntryTemplate would
                    -- throw inside AddDataTemplate and leave the player with an
                    -- empty screen. Styling is never worth that: drop to the
                    -- plain full-width template this file shipped with, rebuild
                    -- and try once more.
                    diag("warn", "Armory list failed with the styled template (%s); retrying plain. %s",
                        tostring(TEMPLATE), tostring(err))
                    Armory.PopulateList()
                    ok, err = pcall(setupFunc, dialog)
                end
                if not ok then
                    refuse("setup:threw", "error",
                        L("SI_ACCOUNTHOLD_ARMORY_SETUP_FAILED",
                          "The Armory opened but could not draw its list."),
                        "Armory setupFunc failed: %s", tostring(err))
                end
            else
                refuse("setup:nosetupfunc", "error",
                    L("SI_ACCOUNTHOLD_ARMORY_SETUP_FAILED",
                      "The Armory opened but could not draw its list."),
                    "Armory dialog has no setupFunc; a PARAMETRIC dialog renders empty without it (zo_genericdialog_gamepad.lua:692).")
            end
        end,

        -- Rebuilt wholesale on every navigation; registered empty so the very
        -- first Show cannot race the first PopulateList.
        parametricList = {},

        buttons = {
            {
                keybind  = "DIALOG_PRIMARY",
                text     = L("SI_ACCOUNTHOLD_ARMORY_SELECT", "Select"),
                callback = function(dialog)
                    pcall(function()
                        local targetData = dialog and dialog.entryList
                            and dialog.entryList:GetTargetData()
                        if targetData and targetData.callback then
                            targetData.callback(dialog)
                        end
                    end)
                end,
            },
            {
                keybind  = "DIALOG_NEGATIVE",
                text     = L(BACK_TEXT_ID, BACK_TEXT_FALL),
                callback = function(dialog)
                    local popped = false
                    pcall(function() popped = Armory.NavPop(Armory._nav) end)
                    if popped then
                        Armory.Refresh(dialog)
                    else
                        release()
                    end
                end,
            },
            {
                -- X on a gamepad. ingame/globals/bindings.xml declares the
                -- DIALOG_SECONDARY action; zo_keybindstrip.lua orders it third
                -- after DIALOG_PRIMARY and DIALOG_NEGATIVE. Claiming it through
                -- the dialog's own buttons array means the BASE GAME owns the
                -- descriptor and resolves the collisions. This add-on has
                -- already crashed a console session once by pushing its own
                -- descriptor onto a base-game keybind strip that already owned
                -- the binding (docs/backlog/0005-priorities-tracker.md:118-123,
                -- AccountHold/README.md "Xbox / PS5 quick reference"), so we
                -- never touch KEYBIND_STRIP here.
                keybind = "DIALOG_SECONDARY",
                -- X = Equip Build, exactly as on the native Armory station
                -- (armory_gamepad.lua:157-158 puts SI_ARMORY_RESTORE_BUILD_ACTION on
                -- UI_SHORTCUT_SECONDARY). Shown only when the build in scope
                -- has something saved to equip. Prioritize moved to a row.
                text    = L("SI_ACCOUNTHOLD_ARMORY_EQUIP_SHORT", "Equip Build"),
                visible = function()
                    local ok, v = pcall(function()
                        local id = Armory.CurrentBuildId()
                        return id ~= nil and equipCall("HasLoadout", id) and true or false
                    end)
                    return (ok and v) and true or false
                end,
                callback = function(dialog)
                    local ok, err = pcall(function()
                        local buildId = Armory.CurrentBuildId()
                        if buildId == nil then return end
                        Armory.Dispatch({ action = "equipBuild", buildId = buildId })
                    end)
                    if not ok then diag("error", "X (Equip Build) failed: %s", tostring(err)) end
                    Armory.Refresh(dialog)
                end,
            },
            {
                -- Y = Save Build (armory_gamepad.lua:178-179, SI_ARMORY_SAVE_BUILD_ACTION
                -- on UI_SHORTCUT_TERTIARY). DIALOG_TERTIARY is Y on Xbox
                -- (docs/research/API_REFERENCE.md, hardware-confirmed).
                keybind = "DIALOG_TERTIARY",
                text    = L("SI_ACCOUNTHOLD_ARMORY_SAVE_SHORT", "Save Build"),
                visible = function()
                    local ok, v = pcall(function() return Armory.CurrentBuildId() ~= nil end)
                    return (ok and v) and true or false
                end,
                callback = function(dialog)
                    local ok, err = pcall(function()
                        local buildId = Armory.CurrentBuildId()
                        if buildId == nil then return end
                        Armory.Dispatch({ action = "captureLoadout", buildId = buildId })
                    end)
                    if not ok then diag("error", "Y (Save Build) failed: %s", tostring(err)) end
                    Armory.Refresh(dialog)
                end,
            },
        },

        -- Closed by any route (B at the root, DIALOG_CLOSE, a scene change):
        -- forget where we were so the next Show always opens at the top.
        finishedCallback = function()
            Armory._dialog = nil
            Armory.NavReset(Armory._nav)
        end,
    }

    local ok, err = pcall(register, DIALOG_NAME, info)
    if not ok then
        diag("error", "Armory dialog registration failed: %s", tostring(err))
        return false
    end

    Armory._registered = true
    Armory._info       = info
    diag("info", "Armory dialog '%s' registered.", DIALOG_NAME)
    return true
end

-- ---------------------------------------------------------------------------
-- Scene state -- why a show request can be dropped
-- ---------------------------------------------------------------------------
-- ZO_Dialogs_ShowGamepadDialog only shows when SCENE_MANAGER:GetCurrentScene()
-- is showing (zo_dialog.lua:354-357); otherwise it needs a NEXT scene to hang
-- allowShowOnNextScene on (:358-371), and with neither it invokes
-- noChoiceCallback and the request is simply gone (:373-376).
--
-- Returns sceneShowing (bool), nextScenePending (bool), known (bool). `known`
-- is false when SCENE_MANAGER is not the shape we expect -- in which case we do
-- NOT refuse, we just cannot pre-warn.
function Armory.SceneReadiness()
    local sm = gtable("SCENE_MANAGER")
    if not sm or type(sm.GetCurrentScene) ~= "function" then
        return false, false, false
    end

    local showing = false
    local ok, scene = pcall(sm.GetCurrentScene, sm)
    if ok and scene ~= nil and type(scene) == "table" and type(scene.IsShowing) == "function" then
        local ok2, isShowing = pcall(scene.IsShowing, scene)
        showing = (ok2 and isShowing) and true or false
    elseif ok and scene ~= nil then
        -- A scene object we cannot interrogate still counts as "there is one".
        showing = true
    end

    local nextPending = false
    if type(sm.GetNextScene) == "function" then
        local ok3, nextScene = pcall(sm.GetNextScene, sm)
        nextPending = (ok3 and nextScene ~= nil) and true or false
    end

    return showing, nextPending, true
end

-- True when this dialog is on screen right now (zo_dialog.lua:81-91).
function Armory.IsShowing()
    local f = gfn("ZO_Dialogs_IsShowing")
    if not f then return nil end
    local ok, v = pcall(f, DIALOG_NAME)
    if not ok then return nil end
    return v and true or false
end

-- ---------------------------------------------------------------------------
-- PUBLIC ENTRY POINT
-- ---------------------------------------------------------------------------
-- AccountHold.UI.ArmoryGamepad:Show()
--
-- Returns true when the dialog was actually asked to show. Every refusal path
-- both logs a diagnostic (console players can dump those) and raises an alert
-- (so a player who pressed a button always gets an answer).
function Armory:Show()
    clearRefusal()

    if not Armory.IsAvailable() then
        return refuse("show:unavailable", "warn",
            L("SI_ACCOUNTHOLD_ARMORY_UNAVAILABLE", "The Armory is not available in this version."),
            "Feature 'buildCreator' is not available in this build.")
    end
    if not Armory.IsEnabled() then
        return refuse("show:disabled", "info",
            L("SI_ACCOUNTHOLD_ARMORY_DISABLED",
              "The Armory is switched off. Turn it on in the add-on settings."),
            "Feature 'buildCreator' is switched off for this account.")
    end
    if not model() then
        return refuse("show:nomodel", "error",
            L("SI_ACCOUNTHOLD_ARMORY_NO_MODEL", "The Armory could not start."),
            "BuildCreator model missing - Armory cannot open.")
    end

    if not Armory.Register() then
        return refuse("show:noregister", "error",
            L("SI_ACCOUNTHOLD_ARMORY_NO_DIALOG", "The Armory could not open on this client."),
            "Armory dialog is not registered; the gamepad dialog framework was not available.")
    end

    -- This is a GAMEPAD parametric dialog: GAMEPAD_DIALOGS.PARAMETRIC only
    -- renders down the isGamepad path (zo_dialog.lua:446-449). Showing it in
    -- keyboard mode would produce an empty box, which is worse than a clear
    -- refusal.
    --
    -- IsInGamepadPreferredMode is the ONLY test that matters here. IsConsoleUI
    -- is deliberately not consulted: this player runs the gamepad UI on PC, and
    -- treating console==false as "keyboard" has already caused several bugs in
    -- this project.
    local gamepad = gfn("IsInGamepadPreferredMode")
    if gamepad then
        local ok, on = pcall(gamepad)
        if ok and not on then
            return refuse("show:keyboard", "info",
                L("SI_ACCOUNTHOLD_ARMORY_GAMEPAD_ONLY",
                  "The Armory is a gamepad screen. Switch to gamepad mode to use it."),
                "Armory requested in keyboard mode; refusing to show a gamepad dialog.")
        end
    end

    Armory.NavReset(Armory._nav)
    -- Populate BEFORE the show so the first rebuild has rows even if `setup`
    -- were ever to be skipped.
    if not Armory.PopulateList() then return false end

    -- Pre-warn on the exact condition that drops the request. The caller (the
    -- pause-menu entry) already waits for a scene, but Show() is public and can
    -- be reached from anywhere, so it has to be able to explain itself.
    local sceneShowing, nextPending, known = Armory.SceneReadiness()
    if known and not sceneShowing then
        if nextPending then
            diag("info", "No scene showing yet; relying on allowShowOnNextScene (zo_dialog.lua:358-371).")
        else
            -- Not a refusal yet: the show is still attempted, because
            -- SceneReadiness can only ever be a best-effort read of base-game
            -- state. noChoiceCallback is what actually confirms the drop.
            diag("warn", "No scene showing and no next scene pending; the show request may be dropped.")
        end
    end

    Armory._showPending = true
    Armory._showDropped = false

    local show = gfn("ZO_Dialogs_ShowGamepadDialog")
    if show then
        local ok, err = pcall(show, DIALOG_NAME, {})
        if ok then
            -- ZO_Dialogs_ShowGamepadDialog returns nothing and swallows the
            -- failure, so "it did not throw" is NOT "it opened".
            --
            -- noChoiceCallback fires synchronously on the drop path
            -- (zo_dialog.lua:373-376), so this is the authoritative answer and
            -- it has already alerted.
            if Armory._showDropped then return false end

            -- Otherwise ask the dialog system directly (zo_dialog.lua:81-91)
            -- and only accept silence when a retry is genuinely pending.
            local showing = Armory.IsShowing()
            if showing == false and Armory._showPending then
                local _, stillPending = Armory.SceneReadiness()
                -- canQueue is set, so "some other dialog is up" means we were
                -- queued and will drain on its hide (zo_dialog.lua:435-440,
                -- :977-981). That is a deferral, not a drop.
                local queuedBehind = false
                local anyDialog = gfn("ZO_Dialogs_IsShowingDialog")
                if anyDialog then
                    local okAny, someDialog = pcall(anyDialog)
                    queuedBehind = (okAny and someDialog) and true or false
                end
                if not stillPending and not queuedBehind then
                    return refuse("show:silent", "error",
                        L("SI_ACCOUNTHOLD_ARMORY_DROPPED",
                          "The Armory could not open because no screen was showing. Close the menu, then try again."),
                        "ZO_Dialogs_ShowGamepadDialog returned without showing and nothing is queued.")
                end
                diag("info", "Armory show deferred (nextScene=%s, queuedBehindDialog=%s).",
                    tostring(stillPending), tostring(queuedBehind))
            end
            return true
        end
        diag("error", "ZO_Dialogs_ShowGamepadDialog failed: %s", tostring(err))
    end

    local showAny = gfn("ZO_Dialogs_ShowDialog")
    if showAny then
        local IS_GAMEPAD = true
        local ok, err = pcall(showAny, DIALOG_NAME, {}, nil, IS_GAMEPAD)
        if ok then return true end
        diag("error", "ZO_Dialogs_ShowDialog failed: %s", tostring(err))
    end

    return refuse("show:nodialogapi", "error",
        L("SI_ACCOUNTHOLD_ARMORY_NO_DIALOG", "The Armory could not open on this client."),
        "Neither ZO_Dialogs_ShowGamepadDialog nor ZO_Dialogs_ShowDialog could show the Armory.")
end

-- Convenience for a caller that already has a build in hand (e.g. a future
-- Priorities cross-link). Never required by the entry point above.
function Armory:ShowBuild(buildId)
    if not self:Show() then return false end
    if modelCall("GetBuild", buildId) == nil then return true end
    push({ page = PAGE_BUILD, buildId = buildId })
    Armory.Refresh()
    return true
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function Armory:Initialize(addonRefIn)
    self.addon = addonRefIn

    if not Armory.IsAvailable() then
        diag("info", "Feature 'buildCreator' unavailable - Armory dialog NOT registered.")
        return
    end
    -- Registration is idempotent and costs nothing at runtime, so it happens at
    -- load; Show() re-attempts it anyway if the base UI was not ready yet.
    Armory.Register()
end

-- EVENT_ADD_ON_LOADED is the earliest possible moment and does not guarantee the
-- gamepad dialog framework is stood up. Registration fails closed, so retry once
-- the player is in the world; it is idempotent, so a successful first attempt
-- makes this a no-op. Mirrors PrioritiesSetsBook_Gamepad:ScheduleRetry.
function Armory:ScheduleRetry(addonRefIn)
    -- EVENT_MANAGER is engine userdata on hardware; test for the METHOD, never
    -- for type == "table", or the retry silently never registers.
    if EVENT_MANAGER == nil then return end
    local okReg, reg = pcall(function() return EVENT_MANAGER.RegisterForEvent end)
    if not okReg or type(reg) ~= "function" then
        return
    end
    if not EVENT_PLAYER_ACTIVATED then return end
    local name = ((addonRefIn and addonRefIn.name) or "AccountHold") .. "_ArmoryRetry"
    pcall(function()
        EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
            if Armory._registered then
                pcall(function() EVENT_MANAGER:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED) end)
                return
            end
            pcall(function() Armory:Initialize(addonRefIn) end)
        end)
    end)
end

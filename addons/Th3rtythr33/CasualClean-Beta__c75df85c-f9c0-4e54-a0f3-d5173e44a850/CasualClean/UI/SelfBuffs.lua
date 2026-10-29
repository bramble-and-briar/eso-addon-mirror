-- =============================================================================
-- CasualClean -- UI/SelfBuffs.lua
-- =============================================================================
-- Per-effect show/hide for the game's own self buff bar, with a settings page
-- that lists every effect the bar has ever shown, icon and name, each with a
-- checkbox.
--
-- NOT A SECOND BUFF BAR. The first idea was to duplicate ZOS's self-buff
-- display and filter the copy. ZOS's source offers something better: every
-- buff-bar style (ZO_BuffDebuffCenterOutStyle, ...SpiralOutStyle,
-- ...ExpiresInStyle in esoui/ingame/buffdebuff/buffdebuffstyles.lua) begins
-- its UpdateContainer with
--
--     ZO_BuffDebuffStyleObject.UpdateContainer(self, containerObject)
--
-- a call through the CLASS table, after which it reads self.sortedBuffs and
-- self.sortedDebuffs to acquire one icon control per entry. The base method
-- has already applied the player's own Buffs & Debuffs settings (self buffs,
-- debuffs, long effects, permanent effects) and sorted the lists. So a
-- ZO_PostHook on the base class runs at exactly the right moment: after the
-- lists are final, before any icon exists. In that window this module
--
--   1. RECORDS every entry for the player container (ability id, name, icon,
--      buff or debuff) into a capped catalogue in SavedVariables, and
--   2. REMOVES entries whose ability id the player has hidden.
--
-- ZOS then draws the bar exactly as it always does: same icons, timers,
-- stacks, fading, HUD-editor position, and every style. Nothing is drawn
-- here, there is no second control tree to keep in step, and the target
-- (reticleover) container is never touched.
--
-- HOOKING THE CLASS, not an instance, is ESOUI's guidance and matters here:
-- three style instances share the base method through their metatables.
-- ZO_PostHook has no undo, so the master switch is honoured inside the hook.
--
-- KEYS. Real effects are keyed by abilityId. Artificial effects (ESO Plus,
-- battleground status and the like, from ZO_GetNextActiveArtificialEffectIdIter)
-- have no ability id and are keyed by the NEGATIVE effectId so the two
-- spaces cannot collide. Both are plain numbers, fine as SavedVariables keys.
--
-- THE CATALOGUE is capped (MAX_SEEN) and evicts the least recently seen
-- entry, so a player who has met every buff in the game cannot grow the
-- saved file without bound; "last seen" is written at most once a minute per
-- effect so an in-combat bar refresh is not a saved-variables write storm.
--
-- THE SETTINGS PAGE. A drill-down section "Self Buffs" holds a master
-- checkbox, a Clear button, and then one checkbox per catalogued effect,
-- label = inline icon markup (zo_iconFormat, the same thing LHAS itself uses
-- for its icon picker rows) plus the name. The rows are appended to the
-- panel last, so their indexes are stable, and rebuilt from the catalogue
-- whenever this addon is selected in the Add-Ons menu
-- ("LibHarvensAddonSettings_AddonSelected", fired with the panel as its
-- second argument) and the catalogue changed since the last build.
-- LHAS's AddSettings(params, index) / RemoveSettings(index, count) handle a
-- currently shown panel themselves (CleanUpIfSelected + CreateControls).
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.SelfBuffs = {}
local B = CC.SelfBuffs

-- On by default: it changes nothing until an effect is unticked.
B.DEFAULT_ENABLED = true
B.MAX_SEEN = 150
local LAST_SEEN_WRITE_INTERVAL_S = 60
local ICON_SIZE = 32

local hookInstalled = false
local hookState = "not attempted"
local panel = nil              -- the LHAS AddonSettings object, once attached
local headIndex = nil          -- index of our ST_SECTION row on the panel
local HEAD_ROWS = 4            -- section, master checkbox, reload button, forget button
local tailRowCount = 0         -- rows after the head: two list sections plus their effect rows
local FORGET_DIALOG = "CASUALCLEAN_FORGET_EFFECTS"
local catalogueDirty = false   -- rows need rebuilding
local seenCount = 0
local lastSeenWritten = {}     -- key -> timestamp of the last "s" write (runtime only)

local function sv()
    return CC.sv
end

function B.GetEnabled()
    local s = sv()
    if s and s.selfBuffsFilter ~= nil then
        return s.selfBuffsFilter
    end
    return B.DEFAULT_ENABLED
end

-- Per-effect choice, three-way by decision (Matt, 2026-10-28): 1 = show,
-- 0 = hide, absent = unset. An unset effect follows the "Show unset" switch
-- of its kind (buffs / debuffs), which defaults to shown.
B.CHOICE_SHOW, B.CHOICE_HIDE = 1, 0
local function Choice()
    local s = sv()
    if not s then return {} end
    if type(s.selfBuffsChoice) ~= "table" then s.selfBuffsChoice = {} end
    return s.selfBuffsChoice
end

local function ShowUnsetField(isDebuff)
    return isDebuff and "selfBuffsShowUnsetDebuffs" or "selfBuffsShowUnsetBuffs"
end

function B.GetShowUnset(isDebuff)
    local s = sv()
    local field = ShowUnsetField(isDebuff)
    if s and s[field] ~= nil then
        return s[field]
    end
    return true
end

local function Seen()
    local s = sv()
    if not s then return {} end
    if type(s.selfBuffsSeen) ~= "table" then s.selfBuffsSeen = {} end
    return s.selfBuffsSeen
end

local function CountSeen()
    local n = 0
    for _ in pairs(Seen()) do n = n + 1 end
    return n
end

-- -----------------------------------------------------------------------------
-- Catalogue
-- -----------------------------------------------------------------------------
local function KeyOf(data)
    if data.isArtificial then
        return data.effectId and -data.effectId or nil
    end
    return data.abilityId
end

local function EvictOldest(seen)
    local oldestKey, oldestTime = nil, nil
    for key, entry in pairs(seen) do
        local t = tonumber(entry.s) or 0
        if not oldestTime or t < oldestTime then
            oldestKey, oldestTime = key, t
        end
    end
    if oldestKey ~= nil then
        seen[oldestKey] = nil
        seenCount = seenCount - 1
    end
end

local function Record(key, data)
    local seen = Seen()
    local now = GetTimeStamp()
    local entry = seen[key]
    if not entry then
        while seenCount >= B.MAX_SEEN do
            EvictOldest(seen)
        end
        seen[key] = {
            n = data.buffName or "",
            i = data.iconFilename or "",
            d = (data.effectType == BUFF_EFFECT_TYPE_DEBUFF) and 1 or 0,
            a = data.isArtificial and 1 or 0,
            s = now,
        }
        seenCount = seenCount + 1
        lastSeenWritten[key] = now
        catalogueDirty = true
        return
    end
    local name, icon = data.buffName or "", data.iconFilename or ""
    if entry.n ~= name or entry.i ~= icon then
        entry.n, entry.i = name, icon
        catalogueDirty = true
    end
    local last = lastSeenWritten[key] or 0
    if now - last >= LAST_SEEN_WRITE_INTERVAL_S then
        entry.s = now
        lastSeenWritten[key] = now
    end
end

-- -----------------------------------------------------------------------------
-- The hook
-- -----------------------------------------------------------------------------
local function IsHiddenByChoice(choice, key, isDebuff)
    local c = choice[key]
    if c == B.CHOICE_HIDE then return true end
    if c == B.CHOICE_SHOW then return false end
    return not B.GetShowUnset(isDebuff)
end

local function FilterList(list, choice, filterOn, isDebuff)
    for i = #list, 1, -1 do
        local data = list[i]
        local key = KeyOf(data)
        if key ~= nil then
            Record(key, data)
            if filterOn and IsHiddenByChoice(choice, key, isDebuff) then
                table.remove(list, i)
            end
        end
    end
end

-- Runs after ZO_BuffDebuffStyleObject.UpdateContainer has filled and sorted
-- the style's lists, before the concrete style turns them into icons.
local function AfterUpdateContainer(style, containerObject)
    if not (containerObject and containerObject.GetUnitTag) then
        return
    end
    if containerObject:GetUnitTag() ~= "player" then
        return
    end
    local filterOn = B.GetEnabled()
    local choice = Choice()
    if type(style.sortedBuffs) == "table" then
        FilterList(style.sortedBuffs, choice, filterOn, false)
    end
    if type(style.sortedDebuffs) == "table" then
        FilterList(style.sortedDebuffs, choice, filterOn, true)
    end
end

local function InstallHook()
    if hookInstalled then
        return
    end
    local class = _G["ZO_BuffDebuffStyleObject"]
    if type(ZO_PostHook) ~= "function" or type(class) ~= "table" or type(class.UpdateContainer) ~= "function" then
        hookState = "ZO_BuffDebuffStyleObject.UpdateContainer or ZO_PostHook missing"
        return
    end
    ZO_PostHook(class, "UpdateContainer", AfterUpdateContainer)
    hookInstalled = true
    hookState = "installed"
end

-- Ask ZOS to rebuild the player's bar now, so a toggle shows at once instead
-- of on the next effect change. Update() is the container's public rebuild.
local function RefreshBar()
    local bd = _G["BUFF_DEBUFF"]
    local byTag = bd and bd.containerObjectsByUnitTag
    local container = byTag and byTag["player"]
    if container and container.Update then
        container:Update()
    end
end

-- -----------------------------------------------------------------------------
-- Settings rows
-- -----------------------------------------------------------------------------
local function KindLabel(entry)
    if entry.a == 1 then return "Artificial effect" end
    if entry.d == 1 then return "Debuff" end
    return "Buff"
end

-- Buffs and debuffs are listed on separate pages (Matt, 2026-10-28: one
-- page with everything was getting too long). The kind is the effect type
-- the game gave it, artificial effects included (ESO Plus is a buff), which
-- is also the list ZOS's base style sorted it into.
local function IsDebuff(entry)
    return entry.d == 1
end

-- LHAS console dropdown contract, verified against 2.2.0 Console/Settings.lua:
-- a ZO_GamepadHorizontalListRow (left/right cycles); items are {name=, data=};
-- getFunction returns the item NAME; setFunction receives (control, itemName,
-- itemData); default is the item NAME (ResetToDefaults matches on it). Its
-- equality test also compares item .data, so every data must be distinct and
-- non-nil or a lookup of "Show" would match the first item with nil data.
local CHOICE_UNSET = -1
local CHOICE_ITEMS = {
    { name = "Unset", data = CHOICE_UNSET },
    { name = "Show",  data = B.CHOICE_SHOW },
    { name = "Hide",  data = B.CHOICE_HIDE },
}
local CHOICE_NAME_BY_DATA = {}
for _, item in ipairs(CHOICE_ITEMS) do CHOICE_NAME_BY_DATA[item.data] = item.name end

local function ChoiceName(c)
    return CHOICE_NAME_BY_DATA[c] or CHOICE_ITEMS[1].name
end

-- Returns 1, 0 or nil (unset) from whichever of the two arguments LHAS sent.
local function ResolveChoice(itemName, itemData)
    local data = type(itemData) == "table" and itemData.data or nil
    if data == nil then
        for _, item in ipairs(CHOICE_ITEMS) do
            if item.name == itemName then data = item.data end
        end
    end
    if data == B.CHOICE_SHOW or data == B.CHOICE_HIDE then
        return data
    end
    return nil
end

local function EffectRows(wantDebuffs)
    local list = {}
    for key, entry in pairs(Seen()) do
        if wantDebuffs == nil or IsDebuff(entry) == wantDebuffs then
            list[#list + 1] = { key = key, entry = entry }
        end
    end
    table.sort(list, function(a, b)
        local an, bn = string.lower(a.entry.n or ""), string.lower(b.entry.n or "")
        if an ~= bn then return an < bn end
        return a.key < b.key
    end)
    local rows = {}
    local choice = Choice()
    for _, item in ipairs(list) do
        local key, entry = item.key, item.entry
        local icon = entry.i ~= "" and zo_iconFormat(entry.i, ICON_SIZE, ICON_SIZE) .. " " or ""
        rows[#rows + 1] = {
            type = LibHarvensAddonSettings.ST_DROPDOWN,
            label = icon .. (entry.n ~= "" and entry.n or ("effect " .. tostring(key))),
            tooltip = string.format("%s, id %d. Show or Hide pins this effect on or off your self buff bar; " ..
                "Unset follows the \"Show unset\" switch at the top of this page.", KindLabel(entry), key),
            items = CHOICE_ITEMS,
            default = CHOICE_ITEMS[1].name,
            getFunction = function() return ChoiceName(choice[key]) end,
            setFunction = function(_, itemName, itemData)
                choice[key] = ResolveChoice(itemName, itemData)
                RefreshBar()
            end,
        }
    end
    return rows
end

local function CountKind(wantDebuffs)
    local n = 0
    for _, entry in pairs(Seen()) do
        if IsDebuff(entry) == wantDebuffs then n = n + 1 end
    end
    return n
end

-- One drill-down section per kind. On console the section title is not
-- shown on its own page, so each label names the feature as well as the kind.
local function ListSectionRow(wantDebuffs)
    local kind = wantDebuffs and "Debuffs" or "Buffs"
    return {
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Buff Filtering: " .. kind,
        tooltip = function()
            local n = CountKind(wantDebuffs)
            if n == 0 then
                return string.format("No %s collected yet. They are added as your self buff bar shows them.", string.lower(kind))
            end
            return string.format("%d %s collected. Set one to Hide to keep it off your self buff bar, or to Show to pin it on.", n, string.lower(kind))
        end,
    }
end

-- Top of each list: what the unset effects of that kind do.
local function ShowUnsetRow(isDebuff)
    local kind = isDebuff and "debuffs" or "buffs"
    return {
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Show unset " .. kind,
        tooltip = "What happens to the " .. kind .. " below that are left at Unset. Ticked: shown, as the game shows them. " ..
                  "Unticked: hidden. An effect set to Show or Hide ignores this.",
        getFunction = function() return B.GetShowUnset(isDebuff) end,
        setFunction = function(value) B.SetShowUnset(isDebuff, value) end,
        default = true,
    }
end

local function TailRows()
    local rows = {}
    for _, isDebuff in ipairs({ false, true }) do
        rows[#rows + 1] = ListSectionRow(isDebuff)
        rows[#rows + 1] = ShowUnsetRow(isDebuff)
        for _, row in ipairs(EffectRows(isDebuff)) do rows[#rows + 1] = row end
    end
    return rows
end

local function RebuildRows()
    if not (panel and headIndex) then
        return
    end
    local start = headIndex + HEAD_ROWS
    if tailRowCount > 0 then
        panel:RemoveSettings(start, tailRowCount)
    end
    local rows = TailRows()
    panel:AddSettings(rows, start)
    tailRowCount = #rows
    catalogueDirty = false
end

-- Forget asks first (Matt, 2026-10-28). Same dialog shape as LHAS's own
-- "LibHarvensAddonSettings_Defaults" dialog and UnderPressure's TTD reset,
-- both of which run on console. Without the dialog system nothing is
-- forgotten: the button is a request, ClearSeen is the action.
local function RegisterForgetDialog()
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then
        return
    end
    ZO_Dialogs_RegisterCustomDialog(FORGET_DIALOG, {
        canQueue = true,
        gamepadInfo = {
            dialogType = type(GAMEPAD_DIALOGS) == "table" and GAMEPAD_DIALOGS.BASIC or nil,
        },
        title = { text = "Casual Clean: Buff Filtering" },
        mainText = {
            text = function()
                return string.format("Forget all %d collected effects?\n\nThe buff and debuff lists will be emptied. " ..
                    "Effects are added again as your self buff bar shows them, and your Show and Hide choices are kept.",
                    seenCount)
            end,
        },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Forget", callback = function() B.ClearSeen() end },
            { keybind = "DIALOG_NEGATIVE", text = "Cancel" },
        },
    })
end

function B.ForgetAll()
    if type(ZO_Dialogs_ShowPlatformDialog) == "function" then
        ZO_Dialogs_ShowPlatformDialog(FORGET_DIALOG)
    elseif type(ZO_Dialogs_ShowGamepadDialog) == "function" then
        ZO_Dialogs_ShowGamepadDialog(FORGET_DIALOG)
    end
end

local function HeadRows()
    local LHAS = LibHarvensAddonSettings
    return {
        {
            -- Named "Buff Filtering" in the settings by decision (2026-10-27);
            -- the module and file keep the SelfBuffs name.
            type = LHAS.ST_SECTION,
            label = "Buff Filtering",
            tooltip = "Choose which effects appear on your self buff bar. Every effect the bar has shown is listed with its icon, buffs and debuffs on their own pages below.",
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Hide unticked effects from the self buff bar",
            tooltip = "Master switch. Off shows the bar exactly as the game does; your choices on the pages below are kept for when you turn it back on. " ..
                      "Effects are still collected while this is off.",
            getFunction = function() return B.GetEnabled() end,
            setFunction = function(value) B.SetEnabled(value) end,
            default = B.DEFAULT_ENABLED,
        },
        {
            -- Added 2026-10-28: on console the list did not pick up effects
            -- collected since the last reload, so the reload is offered here
            -- rather than left to a slash command. ReloadUI("ingame") is the
            -- public native ZOS's own gamepad mod browser calls.
            type = LHAS.ST_BUTTON,
            label = "Reload the UI",
            tooltip = "Reload may be needed to show new entries in the buff list.",
            buttonText = "Reload",
            clickHandler = function() B.ReloadUI() end,
        },
        {
            type = LHAS.ST_BUTTON,
            label = "Forget all collected effects",
            tooltip = "Asks for confirmation, then empties the buff and debuff lists. Effects reappear as the bar shows them again, and your Show and Hide choices are kept.",
            buttonText = "Forget",
            clickHandler = function() B.ForgetAll() end,
        },
    }
end

function B.ReloadUI()
    if type(ReloadUI) == "function" then
        ReloadUI("ingame")
    end
end

-- Called by Settings.lua once the panel exists, AFTER its own rows are
-- added, so this section is last and its indexes never move.
function B.AttachToPanel(addonSettings)
    panel = addonSettings
    local _, indexes = panel:AddSettings(HeadRows())
    headIndex = indexes and indexes[1] or (#panel.settings - HEAD_ROWS + 1)
    tailRowCount = 0
    RebuildRows()
    if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback then
        CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, selected)
            if selected == panel and catalogueDirty then
                RebuildRows()
            end
        end)
    end
end

-- -----------------------------------------------------------------------------
-- Public surface
-- -----------------------------------------------------------------------------
function B.SetEnabled(value)
    local s = sv()
    if s then
        s.selfBuffsFilter = value and true or false
    end
    RefreshBar()
end

function B.SetShowUnset(isDebuff, value)
    local s = sv()
    if s then
        s[ShowUnsetField(isDebuff)] = value and true or false
    end
    RefreshBar()
end

function B.ClearSeen()
    local s = sv()
    if s then
        s.selfBuffsSeen = {}
    end
    seenCount = 0
    lastSeenWritten = {}
    catalogueDirty = true
    RebuildRows()
    RefreshBar()
end

function B.Init()
    -- 1.8.0 builds before 2026-10-28 stored hidden flags in selfBuffsHidden;
    -- fold them into the three-way choice table once and drop the old key.
    local s = sv()
    if s and type(s.selfBuffsHidden) == "table" then
        local choice = Choice()
        for key, flag in pairs(s.selfBuffsHidden) do
            if flag and choice[key] == nil then
                choice[key] = B.CHOICE_HIDE
            end
        end
        s.selfBuffsHidden = nil
    end
    seenCount = CountSeen()
    InstallHook()
    RegisterForgetDialog()
end

-- For `/casualclean buffs`.
function B.GetReport()
    local shownCount, hiddenCount = 0, 0
    for _, c in pairs(Choice()) do
        if c == B.CHOICE_HIDE then
            hiddenCount = hiddenCount + 1
        elseif c == B.CHOICE_SHOW then
            shownCount = shownCount + 1
        end
    end
    local out = {}
    out[#out + 1] = string.format("enabled=%s hook=%s seen=%d/%d show=%d hide=%d unsetBuffs=%s unsetDebuffs=%s panel=%s rows=%d dirty=%s",
        tostring(B.GetEnabled()), hookState, seenCount, B.MAX_SEEN, shownCount, hiddenCount,
        B.GetShowUnset(false) and "shown" or "hidden", B.GetShowUnset(true) and "shown" or "hidden",
        tostring(panel ~= nil), tailRowCount, tostring(catalogueDirty))
    for _, wantDebuffs in ipairs({ false, true }) do
        out[#out + 1] = string.format("  %s: %d", wantDebuffs and "debuffs" or "buffs", CountKind(wantDebuffs))
        for _, row in ipairs(EffectRows(wantDebuffs)) do
            local plain = row.label:gsub("|t[^|]*|t ?", "")
            out[#out + 1] = string.format("    [%-5s] %s", row.getFunction(), plain)
        end
    end
    return out
end

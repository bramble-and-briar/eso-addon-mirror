-- WDH_Hud.lua
-- Crosshair display (phase 2)
--
-- Two displays with the same content:
--   1. Interaction (nodes, containers, corpses, critters)
--      SecurePostHook on RETICLE:TryHandlingInteraction. The game calls it every frame
--      while no loot window is open (see ZO_Reticle:UpdateInteractText in the UI source).
--      The label is attached to RETICLE.interact and hides together with the interaction prompt.
--   2. Living targets (enemies, animals, NPCs under the crosshair, "reticleover")
--      SecurePostHook on RETICLE:UpdateInteractText; afterwards it is known whether the interaction
--      prompt is visible. Only if it is not, the display for the living target appears.
--      Only unambiguous records (name + zone) are shown, no collective loots (#aoe).
--
-- Both displays are hidden in combat. The text is only rebuilt
-- when the target or the data changes.
--
-- Sorting: highest quality first, then the largest count.
-- Percent = share of loots that contained the entry at least once.

local WDH = WhatDropsHere
local CAT = WDH.Categories
local WDH_STRINGS, WDH_SLOT_NAMES = WDH.L, WDH.SLOT_NAMES
local Hud = {}
WDH.Hud = Hud

-- Display state: label + the target the text currently belongs to
local function NewView()
    return {
        label     = nil,
        shownKey  = nil,   -- key of the target the text currently belongs to
        hasText   = false, -- whether there is data for this target
        dirty     = true,  -- data changed, rebuild the text
    }
end

local interactView = NewView()
local unitView     = NewView()

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function Settings()
    return WDH.Settings()
end

local function Percent(hits, loots)
    if loots <= 0 then return 0 end
    return zo_round(hits / loots * 100)
end

local function ApplyFont(label)
    label:SetFont(IsInGamepadPreferredMode() and "ZoFontGamepad22" or "ZoFontWinH5")
end

local function AddEntry(entries, quality, text, n)
    entries[#entries + 1] = { quality = quality, text = text, n = n }
end

local function SortEntries(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    return a.n > b.n
end

local function CreateLabel(name, parent)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetHidden(true)
    ApplyFont(label)
    return label
end

-- -----------------------------------------------------------------------------
-- Building the text
-- -----------------------------------------------------------------------------

local function BuildText(rec, minQuality)
    local maxLines   = Settings().hudMaxLines
    local entries    = {}

    for setId, s in pairs(rec.sets) do
        local quality = WDH.BestQuality(s.q)
        if quality >= minQuality then
            local slots = {}
            for slot in pairs(s.slots or {}) do
                slots[#slots + 1] = WDH_SLOT_NAMES[slot] or slot
            end
            table.sort(slots)
            AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_SET,
                WDH.ColorByQuality(quality, WDH.SetName(setId)), table.concat(slots, ", "),
                s.n, Percent(s.hits, rec.loots)), s.n)
        end
    end

    -- Items by name: category mode DETAIL always, DETAIL_Q from the "Show names from" quality up.
    -- Whatever is not shown by name appears below in its category.
    local nameQuality = Settings().nameQuality
    local catHasItems = {}  -- category has stored items
    local hiddenBest  = {}  -- best quality of the items not shown by name
    for id, s in pairs(rec.items) do
        local cat = s.cat
        if cat ~= "SET" then
            local quality = WDH.BestQuality(s.q)
            -- Older items without a category were only stored individually, so show them by name
            local mode   = cat and CAT.ModeOf(cat) or CAT.MODE_DETAIL
            local byName = mode == CAT.MODE_DETAIL or (mode == CAT.MODE_DETAIL_Q and quality >= nameQuality)
            if cat then catHasItems[cat] = true end
            if byName then
                if quality >= minQuality then
                    AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_ITEM,
                        WDH.ColorByQuality(quality, WDH.ItemName(id)), s.n, Percent(s.hits, rec.loots)), s.n)
                end
            elseif cat then
                hiddenBest[cat] = math.max(hiddenBest[cat] or quality, quality)
            end
        end
    end

    -- Categories: COUNT always, otherwise only if some of it is not shown by name
    -- (or older versions stored no items for it)
    for key, s in pairs(rec.cats) do
        local mode = CAT.ModeOf(key)
        local show = mode ~= CAT.MODE_SET
            and (mode == CAT.MODE_COUNT or hiddenBest[key] ~= nil or not catHasItems[key])
        if show then
            local quality = hiddenBest[key] or WDH.BestQuality(s.q)
            if quality >= minQuality then
                AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_ITEM,
                    WDH.ColorByQuality(quality, WDH.CatName(key)), s.n, Percent(s.hits, rec.loots)), s.n)
            end
        end
    end

    table.sort(entries, SortEntries)

    local header = string.format(WDH_STRINGS.HUD_HEADER, rec.loots)
    if rec.gold > 0 then
        header = header .. string.format(WDH_STRINGS.HUD_GOLD, zo_round(rec.gold / rec.loots))
    end

    local lines = { header }
    for i = 1, math.min(#entries, maxLines) do
        lines[#lines + 1] = entries[i].text
    end
    if #entries > maxLines then
        lines[#lines + 1] = string.format(WDH_STRINGS.HUD_MORE, #entries - maxLines, zo_strlower(rec.name))
    end
    return table.concat(lines, "\n")
end

-- -----------------------------------------------------------------------------
-- Updating
-- -----------------------------------------------------------------------------

-- Display threshold per source type (rec.type, see DetermineSourceType in WhatDropsHere.lua)
local TYPE_SETTING = {
    enemy     = "showEnemy",
    container = "showContainer",
    resource  = "showResource",
    other     = "showOther",
    theft     = "showTheft",
    excavation = "showExcavation",
}

-- Minimum quality for displaying this source, nil = display off for this type.
-- Older records without a type: lowest enabled threshold.
local function MinQuality(rec)
    local settings = Settings()
    local key = TYPE_SETTING[rec.type]
    if key then
        local quality = settings[key]
        if quality == WDH.SHOW_OFF then return nil end
        return quality
    end
    local lowest
    for _, k in pairs(TYPE_SETTING) do
        local quality = settings[k]
        if quality ~= WDH.SHOW_OFF and (lowest == nil or quality < lowest) then lowest = quality end
    end
    return lowest
end

-- Shows the statistics for name (or hides the label if name is nil or there is no data).
-- isOwned: target belongs to someone -> theft record instead of the normal one
local function ShowFor(view, name, isOwned)
    if not name or name == "" then
        view.label:SetHidden(true)
        return
    end
    name = zo_strformat("<<C:1>>", name)
    local key = WDH.RecordKey(name, isOwned)
    if view.dirty or key ~= view.shownKey then
        view.shownKey, view.dirty = key, false
        local rec = WDH.FindRecord(WDH.CurrentZoneId(), key)
        local minQuality = rec and MinQuality(rec)
        view.hasText = minQuality ~= nil
        if view.hasText then
            ApplyFont(view.label)
            view.label:SetText(BuildText(rec, minQuality))
        end
    end
    view.label:SetHidden(not view.hasText)
end

local function HudAllowed()
    return Settings().hud and not IsUnitInCombat("player")
end

-- Post-hook for ZO_Reticle:TryHandlingInteraction(interactionPossible, currentFrameTimeSeconds)
local function OnTryHandlingInteraction(_, interactionPossible)
    if not HudAllowed() or not interactionPossible then
        interactView.label:SetHidden(true)
        return
    end
    local _, name, _, isOwned = GetGameCameraInteractableActionInfo()
    ShowFor(interactView, name, isOwned)
end

-- Living target under the crosshair (not a player, not dead)
local function LivingTargetName()
    if not DoesUnitExist("reticleover") then return nil end
    if IsUnitPlayer("reticleover") or IsUnitDead("reticleover") then return nil end
    return GetUnitName("reticleover")
end

-- Post-hook for ZO_Reticle:UpdateInteractText(currentFrameTimeSeconds)
local function OnUpdateInteractText()
    -- Living targets always count as enemies (or animals/NPCs): both switches must be on
    if not HudAllowed() or Settings().showEnemy == WDH.SHOW_OFF or not Settings().hudUnits
       or not RETICLE.interact:IsHidden() then
        unitView.label:SetHidden(true)
        return
    end
    ShowFor(unitView, LivingTargetName())
end

-- -----------------------------------------------------------------------------
-- Interface
-- -----------------------------------------------------------------------------

function Hud:Invalidate()
    interactView.dirty = true
    unitView.dirty     = true
end

function Hud:Init()
    -- Below the additional info (e.g. lock level), which itself sits below the key prompt
    interactView.label = CreateLabel("WhatDropsHereHud", RETICLE.interact)
    interactView.label:SetAnchor(TOPLEFT, RETICLE.additionalInfo, BOTTOMLEFT, 0, 6)

    -- Living targets: at the same spot where the interaction text usually is.
    -- Parent is the reticle container, because RETICLE.interact is hidden then.
    unitView.label = CreateLabel("WhatDropsHereHudUnit", RETICLE.control)
    unitView.label:SetAnchor(TOPLEFT, RETICLE.interact, BOTTOMLEFT, 0, 4)

    SecurePostHook(RETICLE, "TryHandlingInteraction", OnTryHandlingInteraction)
    SecurePostHook(RETICLE, "UpdateInteractText", OnUpdateInteractText)
end

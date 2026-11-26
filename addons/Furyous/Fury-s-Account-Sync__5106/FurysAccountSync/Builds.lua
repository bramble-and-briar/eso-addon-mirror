-- Fury's Account Sync - character builds
-- Save the skill bars, champion point stars and quickslot wheel of the character you're on under a
-- name, then load that build onto any character on any account on this PC. You choose which parts
-- to load. Whatever the character can't use (another class's skills, a morph it doesn't have, a
-- star it hasn't unlocked, an item it doesn't carry) is skipped and listed.

local AS = FurysAccountSync

local BARS          = {
    { category = HOTBAR_CATEGORY_PRIMARY },
    { category = HOTBAR_CATEGORY_BACKUP },
}
local FIRST_SKILL   = 3      -- slots 3 to 7 are skills, 8 is the ultimate
local LAST_SKILL    = 8
local CP_SLOTS      = 12
local STEP_MS       = 120    -- pause between slot changes so the server keeps up
local QUICK_SLOTS   = 8      -- the quickslot wheel: slots 1 to 8 of its own hotbar category
local GEAR_WAIT     = 3      -- extra pauses after each piece of gear; the server takes them one at a time

-- Worn gear a build keeps, in the order it is put on.
local GEAR_SLOTS = {
    { slot = EQUIP_SLOT_HEAD,        name = "Head" },
    { slot = EQUIP_SLOT_SHOULDERS,   name = "Shoulders" },
    { slot = EQUIP_SLOT_CHEST,       name = "Chest" },
    { slot = EQUIP_SLOT_HAND,        name = "Hands" },
    { slot = EQUIP_SLOT_WAIST,       name = "Waist" },
    { slot = EQUIP_SLOT_LEGS,        name = "Legs" },
    { slot = EQUIP_SLOT_FEET,        name = "Feet" },
    { slot = EQUIP_SLOT_NECK,        name = "Necklace" },
    { slot = EQUIP_SLOT_RING1,       name = "Ring 1" },
    { slot = EQUIP_SLOT_RING2,       name = "Ring 2" },
    { slot = EQUIP_SLOT_MAIN_HAND,   name = "Front bar main hand" },
    { slot = EQUIP_SLOT_OFF_HAND,    name = "Front bar off hand" },
    { slot = EQUIP_SLOT_BACKUP_MAIN, name = "Back bar main hand" },
    { slot = EQUIP_SLOT_BACKUP_OFF,  name = "Back bar off hand" },
}

local function AbilityName(id)
    return zo_strformat("<<C:1>>", GetAbilityName(id))
end

------------------------------------------------------------------------------
-- Save
------------------------------------------------------------------------------
local function ReadBars()
    local bars = {}
    for _, bar in ipairs(BARS) do
        local category = bar.category
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(category)
        local slots = {}
        for slot = FIRST_SKILL, LAST_SKILL do
            local data = hotbar:GetSlotData(slot)
            if data and not data:IsEmpty() and data.GetEffectiveAbilityId then
                slots[slot] = data:GetEffectiveAbilityId()
            else
                slots[slot] = 0
            end
        end
        bars[category] = slots
    end
    return bars
end

local function ReadCP()
    local stars = {}
    for slot = 1, CP_SLOTS do
        stars[slot] = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) or 0
    end
    return stars
end

local function ReadQuick()
    local quick = {}
    for slot = 1, QUICK_SLOTS do
        local slotType = GetSlotType(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if slotType == ACTION_TYPE_ITEM then
            local link = GetSlotItemLink(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            local itemId = GetItemLinkItemId(link)
            if itemId > 0 then
                quick[slot] = { kind = "item", id = itemId, link = link }
            end
        elseif slotType == ACTION_TYPE_COLLECTIBLE then
            quick[slot] = { kind = "collectible", id = GetSlotBoundId(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) }
        elseif slotType ~= ACTION_TYPE_NOTHING then
            quick[slot] = { kind = "action", type = slotType, id = GetSlotBoundId(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) }
        end
    end
    return quick
end

local function ReadGear()
    local gear = {}
    for _, g in ipairs(GEAR_SLOTS) do
        local link = GetItemLink(BAG_WORN, g.slot)
        if link ~= "" then gear[g.slot] = link end
    end
    return gear
end

-- Same item, trait and quality: close enough to wear when the exact piece isn't in the bag.
local function SameKind(a, b)
    return GetItemLinkItemId(a) == GetItemLinkItemId(b)
       and GetItemLinkTraitInfo(a) == GetItemLinkTraitInfo(b)
       and GetItemLinkFunctionalQuality(a) == GetItemLinkFunctionalQuality(b)
end

-- The bag slot of the wanted piece: the exact one first, then one of the same kind. taken holds
-- bag slots already promised to another gear slot (two of the same ring).
local function FindGear(link, taken)
    local close
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if not taken[slot] then
            local have = GetItemLink(BAG_BACKPACK, slot)
            if have ~= "" then
                if have == link then return slot end
                if not close and SameKind(have, link) then close = slot end
            end
        end
    end
    return close
end

function AS.SaveBuild(name)
    name = zo_strtrim(name or "")
    if name == "" then
        AS.Msg("Type a name for the build first.")
        return false
    end
    local className = GetUnitClass("player")
    AS.SV().builds[name] = {
        by    = GetDisplayName(),
        char  = GetUnitName("player"),
        class = zo_strformat("<<1>>", className),
        time  = GetTimeStamp(),
        bars  = ReadBars(),
        cp    = ReadCP(),
        quick = ReadQuick(),
        gear  = ReadGear(),
    }
    AS.Msg("Saved build \"" .. name .. "\" from " .. GetUnitName("player") .. ".")
    AS.RefreshWindow()
    return true
end

function AS.DeleteBuild(name)
    if AS.SV().builds[name] then
        AS.SV().builds[name] = nil
        AS.Msg("Deleted build \"" .. name .. "\".")
    end
    AS.RefreshWindow()
end

function AS.BuildNames()
    local names = {}
    for name in pairs(AS.SV().builds) do names[#names + 1] = name end
    table.sort(names)
    return names
end

------------------------------------------------------------------------------
-- Load
------------------------------------------------------------------------------
-- Works out what each saved skill becomes on this character: the same ability, this character's
-- own morph of it, or nothing (not unlocked, another class, scribed).
local function ResolveSkill(abilityId)
    local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
    if not progression then return nil, "scribed or unknown" end
    local skill = progression:GetSkillData()
    if not skill or not skill:IsPurchased() then return nil, "not unlocked here" end
    local current = skill:GetCurrentProgressionData()
    if current and current ~= progression then
        return current:GetAbilityId(), "your own morph"
    end
    return abilityId
end

local function FindItem(itemId)
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slot) == itemId then return slot end
    end
    return nil
end

-- Runs a list of steps one after another with a short pause, then calls done.
local function RunSteps(steps, done)
    local index = 0
    local function nextStep()
        index = index + 1
        local step = steps[index]
        if not step then
            if done then done() end
            return
        end
        step()
        zo_callLater(nextStep, STEP_MS)
    end
    nextStep()
end

function AS.LoadBuild(name)
    local build = AS.SV().builds[name]
    if not build then
        AS.Msg("Pick a build first.")
        return false
    end
    if IsUnitInCombat("player") then
        AS.Msg("Builds can't be loaded in combat.")
        return false
    end
    local parts = AS.SV().buildParts
    if not (parts.skills or parts.cp or parts.quick or parts.gear) then
        AS.Msg("Nothing is ticked to load. Tick skill bars, champion stars, quickslots or gear first.")
        return false
    end
    local steps, report, skipped = {}, {}, {}
    local function skip(text) skipped[#skipped + 1] = text end

    if parts.skills then
        local slotted = 0
        for _, bar in ipairs(BARS) do
            local category = bar.category
            local saved = build.bars and build.bars[category]
            if saved then
                local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(category)
                for slot = FIRST_SKILL, LAST_SKILL do
                    local abilityId = saved[slot] or 0
                    if abilityId > 0 then
                        local useId, note = ResolveSkill(abilityId)
                        if useId then
                            slotted = slotted + 1
                            if note then skip(AbilityName(abilityId) .. ": slotted " .. note .. " (" .. AbilityName(useId) .. ")") end
                            steps[#steps + 1] = function() hotbar:AssignSkillToSlotByAbilityId(slot, useId) end
                        else
                            skip(AbilityName(abilityId) .. ": " .. note)
                        end
                    end
                end
            end
        end
        report[#report + 1] = slotted .. " skills"
    end

    if parts.quick and build.quick then
        local placed = 0
        for slot, q in pairs(build.quick) do
            if q.kind == "item" then
                local bagSlot = FindItem(q.id)
                if bagSlot then
                    placed = placed + 1
                    steps[#steps + 1] = function()
                        AS.Call("SelectSlotItem", BAG_BACKPACK, bagSlot, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    end
                else
                    skip(zo_strformat("<<t:1>>", q.link or "item") .. ": not in this character's bag")
                end
            elseif q.kind == "collectible" then
                if IsCollectibleUnlocked(q.id) then
                    placed = placed + 1
                    steps[#steps + 1] = function()
                        AS.Call("SelectSlotSimpleAction", ACTION_TYPE_COLLECTIBLE, q.id, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    end
                else
                    skip(zo_strformat("<<1>>", GetCollectibleName(q.id)) .. ": not owned on this account")
                end
            else
                skip("Quickslot " .. slot .. ": only items and collectibles are loaded")
            end
        end
        report[#report + 1] = placed .. " quickslots"
    end

    if parts.gear then
        local worn, taken = 0, {}
        for _, g in ipairs(GEAR_SLOTS) do
            local link = build.gear and build.gear[g.slot]
            if link then
                local wearing = GetItemLink(BAG_WORN, g.slot)
                if wearing == link or (wearing ~= "" and SameKind(wearing, link)) then
                    worn = worn + 1
                else
                    local bagSlot = FindGear(link, taken)
                    if bagSlot then
                        taken[bagSlot] = true
                        worn = worn + 1
                        steps[#steps + 1] = function() AS.Call("EquipItem", BAG_BACKPACK, bagSlot, g.slot) end
                        for _ = 1, GEAR_WAIT do steps[#steps + 1] = function() end end
                    else
                        skip(g.name .. ": " .. zo_strformat("<<t:1>>", link) .. " is not in this character's bag")
                    end
                end
            end
        end
        if not build.gear then skip("Gear: this build was saved before builds kept gear. Save it again to add it") end
        report[#report + 1] = worn .. " pieces of gear"
    end

    if parts.cp and build.cp then
        local stars = {}
        for slot = 1, CP_SLOTS do
            local starId = build.cp[slot] or 0
            if starId > 0 then
                if GetNumPointsSpentOnChampionSkill(starId) > 0
                   and CanChampionSkillTypeBeSlotted(GetChampionSkillType(starId)) then
                    stars[#stars + 1] = { slot, starId }
                else
                    skip(zo_strformat("<<C:1>>", GetChampionSkillName(starId)) .. ": star not unlocked here")
                end
            end
        end
        if #stars > 0 then
            steps[#steps + 1] = function()
                PrepareChampionPurchaseRequest()
                for _, star in ipairs(stars) do
                    AddHotbarSlotToChampionPurchaseRequest(star[1], star[2])
                end
                AS.cpPending = true
                SendChampionPurchaseRequest()
            end
        end
        report[#report + 1] = #stars .. " champion stars"
    end

    AS.Msg("Loading \"" .. name .. "\": " .. table.concat(report, ", ") .. ".")
    RunSteps(steps, function()
        local lines = { "|c5CC2FFLoaded \"" .. name .. "\"|r  |cECEAF8" .. table.concat(report, ", ") .. "|r", "" }
        if #skipped == 0 then
            lines[#lines + 1] = "|c5EE6A0Everything fit.|r"
        else
            lines[#lines + 1] = "|cFFC857Skipped or changed (" .. #skipped .. "):|r"
            for _, text in ipairs(skipped) do lines[#lines + 1] = "  |cECEAF8" .. text .. "|r" end
        end
        AS.ShowReport(table.concat(lines, "\n"))
        if #skipped == 1 then
            AS.Msg("1 part of the build didn't fit this character. The window lists it.")
        elseif #skipped > 1 then
            AS.Msg(#skipped .. " parts of the build didn't fit this character. The window lists them.")
        end
    end)
    return true
end

EVENT_MANAGER:RegisterForEvent(AS.name .. "Builds", EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
    if not AS.cpPending then return end
    AS.cpPending = false
    if result ~= CHAMPION_PURCHASE_SUCCESS then
        AS.Msg("The game didn't take the champion stars (" .. GetString("SI_CHAMPIONPURCHASERESULT", result) ..
            "). Changing stars has a short cooldown; try again in a moment.")
    end
end)

------------------------------------------------------------------------------
-- A build as one line of text, to copy to another PC or hand to a friend
------------------------------------------------------------------------------
-- FASB1;name;class;P=ids;B=ids;C=ids;Q=slot:kind:id,...;G=slot:link fields,...
-- Item links are kept as their number fields only, joined with "_", so the text holds no link
-- characters and survives a chat box, a note or a forum post.
local function LinkToFields(link)
    local fields = link:match("|H%d:item:([%d:%-]+)|h")
    if not fields then return nil end
    return (fields:gsub(":", "_"))
end

local function FieldsToLink(fields)
    return "|H1:item:" .. fields:gsub("_", ":") .. "|h|h"
end

local function Numbers(list, first, last)
    local out = {}
    for i = first, last do out[#out + 1] = tostring(list and list[i] or 0) end
    return table.concat(out, ",")
end

function AS.BuildToText(name)
    local b = AS.SV().builds[name]
    if not b then return nil end
    local clean = function(text) return (tostring(text or ""):gsub("[;|]", " ")) end
    local parts = { "FASB1", clean(name), clean(b.class) }
    parts[#parts + 1] = "P=" .. Numbers(b.bars and b.bars[HOTBAR_CATEGORY_PRIMARY], FIRST_SKILL, LAST_SKILL)
    parts[#parts + 1] = "B=" .. Numbers(b.bars and b.bars[HOTBAR_CATEGORY_BACKUP], FIRST_SKILL, LAST_SKILL)
    parts[#parts + 1] = "C=" .. Numbers(b.cp, 1, CP_SLOTS)
    local quick = {}
    for slot = 1, QUICK_SLOTS do
        local q = b.quick and b.quick[slot]
        if q and q.kind == "item" and q.link and LinkToFields(q.link) then
            quick[#quick + 1] = slot .. ":i:" .. LinkToFields(q.link)
        elseif q and q.kind == "collectible" then
            quick[#quick + 1] = slot .. ":c:" .. tostring(q.id)
        end
    end
    parts[#parts + 1] = "Q=" .. table.concat(quick, ",")
    local gear = {}
    for index, g in ipairs(GEAR_SLOTS) do
        local link = b.gear and b.gear[g.slot]
        local fields = link and LinkToFields(link)
        if fields then gear[#gear + 1] = index .. ":" .. fields end
    end
    parts[#parts + 1] = "G=" .. table.concat(gear, ",")
    return table.concat(parts, ";")
end

local function SplitNumbers(text, first)
    local out, index = {}, first
    for value in text:gmatch("[^,]+") do
        out[index] = tonumber(value) or 0
        index = index + 1
    end
    return out
end

-- Returns the build's name and the build, or nil and what is wrong with the text.
function AS.BuildFromText(text)
    text = zo_strtrim(text or "")
    local fields = {}
    for field in (text .. ";"):gmatch("(.-);") do fields[#fields + 1] = field end
    if fields[1] ~= "FASB1" or #fields < 3 then
        return nil, "That isn't a build text. It starts with FASB1; and comes from \"Show as text\" in this window."
    end
    local name = zo_strtrim(fields[2])
    if name == "" then return nil, "The build text has no name in it." end
    local build = { by = "text", char = "shared", class = fields[3], time = GetTimeStamp(),
                    bars = {}, cp = {}, quick = {}, gear = {} }
    for i = 4, #fields do
        local key, value = fields[i]:match("^(%u)=(.*)$")
        if key == "P" then
            build.bars[HOTBAR_CATEGORY_PRIMARY] = SplitNumbers(value, FIRST_SKILL)
        elseif key == "B" then
            build.bars[HOTBAR_CATEGORY_BACKUP] = SplitNumbers(value, FIRST_SKILL)
        elseif key == "C" then
            build.cp = SplitNumbers(value, 1)
        elseif key == "Q" then
            for slot, kind, id in value:gmatch("(%d+):(%a):([%d_%-]+)") do
                if kind == "i" then
                    local link = FieldsToLink(id)
                    build.quick[tonumber(slot)] = { kind = "item", id = GetItemLinkItemId(link), link = link }
                elseif kind == "c" then
                    build.quick[tonumber(slot)] = { kind = "collectible", id = tonumber(id) }
                end
            end
        elseif key == "G" then
            for index, link in value:gmatch("(%d+):([%d_%-]+)") do
                local g = GEAR_SLOTS[tonumber(index)]
                if g then build.gear[g.slot] = FieldsToLink(link) end
            end
        end
    end
    return name, build
end

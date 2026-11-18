-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: DariansUtilities/abilities/Stacks.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
Util.Ability = Util.Ability or { }
Util.Stacks = Util.Stacks or {}
local Stacks = Util.Stacks
Stacks.morphs = {}

local MORPH_IDS = {
    ["FS"] = 114108,
    ["GF"] = 61902,
}

function Stacks:CheckMorph(value)
    local morph = ""
    local _,index,_,_,_,_ = GetAbilityProgressionXPInfoFromAbilityId(MORPH_IDS[value])

    local _,morphId,_ = GetAbilityProgressionInfo(index)
    if value == "FS" then
        if morphId == 1 then morph = "VS"
        elseif morphId == 2 then morph = "RS"
        else morph = "FS"
        end
        Stacks:UpdateMorphData(value, morph)
    elseif value == "GF" then
        if morphId == 1 then
            morph = "RF"
            WeavePulse.StackTracker.SKILL_ATTRIBUTES.GF.activation = 4
        elseif morphId == 2 then
            morph = "MR"
            WeavePulse.StackTracker.SKILL_ATTRIBUTES.GF.activation = 5
        else
            morph = "GF"
            WeavePulse.StackTracker.SKILL_ATTRIBUTES.GF.activation = 5
        end
        Stacks:UpdateMorphData(value, morph)
    end
    return morph
end

local IDS = {
    ["Crux"] = 184220,
    ["BA"] = 203447,
    ["MW"] = 122658,
    ["GF"] = {
        ["GF"] = 122585,
        ["MR"] = 122586,
        ["RF"] = 122587,
    },
    ["FS"] = {
        ["FS"] = 114131,
        ["RS"] = 117638,
        ["VS"] = 117625,
    },
    ["FI"] = 91416,
}

function Stacks:UpdateMorphData(ability, morph)

        local morphUpdated = false

        if ability == "FS" then
            if self.morphs.FS and self.morphs.FS ~= morph then
                self.morphs.FS = morph
                morphUpdated = true
            end
            if morphUpdated and WeavePulse and WeavePulse.StackTracker then
                if WeavePulse.StackTracker.UI and WeavePulse.StackTracker.UI.FS then
                    WeavePulse.StackTracker.UI.FS.indicator.ApplyIcon()
                end
                WeavePulse.StackTracker:Unregister("FS")
            end
        elseif ability == "GF" then
            if self.morphs.GF and self.morphs.GF ~= morph then
                self.morphs.GF = morph
                morphUpdated = true
            end
            if morphUpdated and WeavePulse and WeavePulse.StackTracker then
                if WeavePulse.StackTracker.UI and WeavePulse.StackTracker.UI.GF then
                    WeavePulse.StackTracker.UI.GF.indicator.ApplyIcon()
                end
                WeavePulse.StackTracker:Unregister("GF")
            end
        end

end

function Stacks:StoreAbilitiesOnActionBar()
    local actionSlots = {}

    local function IsAlreadyInList(id)
        for i, entry in ipairs(actionSlots) do
            if entry.id == id then return true end
        end
        return false
    end

    for j = 0, 1 do
        for i = 3, 8 do
            local actionSlot = {}
            local slotType = GetSlotType(i, j)

            if slotType then
                actionSlot.place = tostring(i .. j)
                if slotType == ACTION_TYPE_CRAFTED_ABILITY then
                    actionSlot.id = GetAbilityIdForCraftedAbilityId(GetSlotBoundId(i, j))
                else
                    actionSlot.id = GetSlotBoundId(i, j)
                end
                if (actionSlot.id ~= 0) and not IsAlreadyInList(actionSlot.id) then
                    actionSlot.icon = GetAbilityIcon(actionSlot.id)
                    actionSlot.name = Util.Text.CropZOSString(GetAbilityName(actionSlot.id), "ability")
                    local sType, index = GetSpecificSkillAbilityKeysByAbilityId(actionSlot.id)
                    actionSlot.skillLine = GetSkillLineId(sType, index)

                    table.insert(actionSlots, actionSlot)
                    if not Util.Ability.cache[actionSlot.id] then Util.Ability:ForId(actionSlot.id) end
                end
            end
        end
    end

    return actionSlots
end

function Stacks:GetCurrentNumStacksOnPlayer(skill)
    local stacks = {
        ["Crux"] = 0,
        ["BA"] = 0,
        ["MW"] = 0,
        ["GF"] = 0,
        ["FS"] = 0,
        ["FI"] = 0,
    }

    local abilityToCheck
    if skill == "GF" and Stacks.morphs.GF then
        abilityToCheck = IDS.GF[Stacks.morphs.GF]
    elseif skill == "FS" and Stacks.morphs.FS then
        abilityToCheck = IDS.FS[Stacks.morphs.FS]
    elseif not (skill == "GF" or skill == "FS") then
        abilityToCheck = IDS[skill]
    else
        return 0
    end
    if abilityToCheck then
        for i=1,GetNumBuffs("player") do
            local name,_,_,_,stack,_,_,_,_,statusEffectType,abilityId = GetUnitBuffInfo("player", i)
            if abilityId == abilityToCheck then
                if skill == "FI" then
                    stacks[skill] = 1
                    break
                end
                stacks[skill] = stack
            break
            end
        end
    end

    return stacks[skill]
end

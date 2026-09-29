--- BuffTracker.lua
BuffTracker = BuffTracker or {}
local Utils = BuffTracker.Utils
BuffTracker.defaultAccountSettings = {
    offsetX = 0,
    offsetY = 0,
    fontSize = 40,
    maxItems = 6,
    debug = false,
    sorting = 0,
}
BuffTracker.defaultSettings = {
    enabled = true,
    majorBuffs = {{
        abilityId = 28708,
        threshold = 10,
        keepshowing = false
    }, -- Empower
    {
        abilityId = 93123,
        threshold = 0,
        keepshowing = false
    }, -- Major Aegis
    {
        abilityId = 36973,
        threshold = 0,
        keepshowing = false
    }, -- Major Berserk
    {
        abilityId = 23673,
        threshold = 0,
        keepshowing = false
    }, -- Major Brutality / Increase Power
    {
        abilityId = 66902,
        threshold = 0,
        keepshowing = false
    }, -- Major Courage
    {
        abilityId = 32748,
        threshold = 0,
        keepshowing = false
    }, -- Major Endurance
    {
        abilityId = 49264,
        threshold = 0,
        keepshowing = false
    }, -- Major Evasion
    {
        abilityId = 23216,
        threshold = 0,
        keepshowing = false
    }, -- Major Expedition
    {
        abilityId = 40225,
        threshold = 0,
        keepshowing = false
    }, -- Major Force
    {
        abilityId = 29011,
        threshold = 0,
        keepshowing = false
    }, -- Major Fortitude
    {
        abilityId = 61709,
        threshold = 0,
        keepshowing = false
    }, -- Major Heroism
    {
        abilityId = 45224,
        threshold = 0,
        keepshowing = false
    }, -- Major Intellect
    {
        abilityId = 55033,
        threshold = 0,
        keepshowing = false
    }, -- Major Mending
    -- {
    --     abilityId = 47193,
    --     threshold = 0,
    --     keepshowing = false
    -- }, -- Major Prophecy
    {
        abilityId = 22233,
        threshold = 0,
        keepshowing = false
    }, -- Major Protection
    {
        abilityId = 22236,
        threshold = 0,
        keepshowing = false
    }, -- Major Resolve
    {
        abilityId = 45241,
        threshold = 0,
        keepshowing = false
    }, -- Major Savagery
    {
        abilityId = 93109,
        threshold = 0,
        keepshowing = false
    }, -- Major Slayer
    -- {
    --     abilityId = 33317,
    --     threshold = 0,
    --     keepshowing = false
    -- }, -- Major Sorcery
    {
        abilityId = 42197,
        threshold = 0,
        keepshowing = false
    }, -- Major Vitality
    {
        abilityId = 260600,
        threshold = 10,
        keepshowing = false
    }
    }, -- Damage Shield

    majorDebuffs = {
    {
        abilityId = 28307,
        threshold = 0,
        keepshowing = false
    }, -- Major Breach
    {
        abilityId = 145977,
        threshold = 0,
        keepshowing = false
    }, -- Major Brittle
    {
        abilityId = 111354,
        threshold = 0,
        keepshowing = false
    }, -- Major Cowardice
    {
        abilityId = 24686,
        threshold = 0,
        keepshowing = false
    }, -- Major Defile
    {
        abilityId = 21754,
        threshold = 0,
        keepshowing = false
    }, -- Major Maim
    {
        abilityId = 106754,
        threshold = 0,
        keepshowing = false
    }, -- Major Vulnerability
    {
        abilityId = 260596,
        threshold = 0,
        keepshowing = false
    } -- Heal Absorption
    },

    minorBuffs = {{
        abilityId = 76618,
        threshold = 0,
        keepshowing = false
    }, -- Minor Aegis
    {
        abilityId = 61744,
        threshold = 0,
        keepshowing = false
    }, -- Minor Berserk
    {
        abilityId = 61662,
        threshold = 0,
        keepshowing = false
    }, -- Minor Brutality
    {
        abilityId = 121878,
        threshold = 0,
        keepshowing = false
    }, -- Minor Courage
    {
        abilityId = 61715,
        threshold = 0,
        keepshowing = false
    }, -- Minor Evasion
    {
        abilityId = 34741,
        threshold = 0,
        keepshowing = false
    }, -- Minor Expedition
    {
        abilityId = 61746,
        threshold = 0,
        keepshowing = false
    }, -- Minor Force
    {
        abilityId = 26213,
        threshold = 0,
        keepshowing = false
    }, -- Minor Fortitude
    {
        abilityId = 61708,
        threshold = 0,
        keepshowing = false
    }, -- Minor Heroism
    {
        abilityId = 26216,
        threshold = 0,
        keepshowing = false
    }, -- Minor Intellect
    {
        abilityId = 80020,
        threshold = 0,
        keepshowing = false
    }, -- Minor Lifesteal
    {
        abilityId = 26809,
        threshold = 0,
        keepshowing = false
    }, -- Minor Magickasteal
    {
        abilityId = 29096,
        threshold = 0,
        keepshowing = false
    }, -- Minor Mending
    -- {
    --     abilityId = 61691,
    --     threshold = 0,
    --     keepshowing = false
    -- }, -- Minor Prophecy
    {
        abilityId = 35739,
        threshold = 0,
        keepshowing = false
    }, -- Minor Protection
    {
        abilityId = 37247,
        threshold = 0,
        keepshowing = false
    }, -- Minor Resolve
    {
        abilityId = 61666,
        threshold = 0,
        keepshowing = false
    }, -- Minor Savagery
    {
        abilityId = 76617,
        threshold = 0,
        keepshowing = false
    }, -- Minor Slayer
    -- {
    --     abilityId = 61685,
    --     threshold = 0,
    --     keepshowing = false
    -- }, -- Minor Sorcery
    {
        abilityId = 88490,
        threshold = 0,
        keepshowing = false
    }, -- Minor Toughness
    {
        abilityId = 61549,
        threshold = 0,
        keepshowing = false
    }, -- Minor Vitality
    {
        abilityId = 263403,
        threshold = 0,
        keepshowing = false
    } -- Minor Vexation
    },

    minorDebuffs = {{
        abilityId = 38688,
        threshold = 0,
        keepshowing = false
    }, -- Minor Breach
    {
        abilityId = 145975,
        threshold = 0,
        keepshowing = false
    }, -- Minor Brittle
    {
        abilityId = 46202,
        threshold = 0,
        keepshowing = false
    }, -- Minor Cowardice
    {
        abilityId = 21927,
        threshold = 0,
        keepshowing = false
    }, -- Minor Defile
    {
        abilityId = 47202,
        threshold = 0,
        keepshowing = false
    }, -- Minor Enervation  
    {
        abilityId = 29308,
        threshold = 0,
        keepshowing = false
    }, -- Minor Maim
    {
        abilityId = 39168,
        threshold = 0,
        keepshowing = false
    }, -- Minor Mangle
    {
        abilityId = 134149,
        threshold = 0,
        keepshowing = false
    }, -- Minor Timidity
    {
        abilityId = 47204,
        threshold = 0,
        keepshowing = false
    }, -- Minor Uncertainty
    {
        abilityId = 42062,
        threshold = 0,
        keepshowing = false
    } -- Minor Vulnerability
    },

    cooldowns = {{
        abilityId = 135924,
        threshold = 22,
        keepshowing = false
    } -- Roaring Opportunist Cooldown
    },

    seteffects = {
    { 
      abilityId = 137126,
      threshold = 0,
      keepshowing = false
    }, -- Dragon's Appetite
    { 
      abilityId = 67296,
      threshold = 0,
      keepshowing = false
    }, -- Essence Thief
    { 
      abilityId = 252050,
      threshold = 0,
      keepshowing = false
    }, -- Huntsman's Warmask
    {
        abilityId = 61771,
        threshold = 0,
        keepshowing = false
    }, -- Powerful Assault
    {
      abilityId = 166721,
      threshold = 0,
      keepshowing = false
    }, -- Rallying Cry
    {
      abilityId = 220787,
      threshold = 0,
      keepshowing = false
    }, -- Sliver (of the Null Arca)
    {
      abilityId = 76949,
      threshold = 0,
      keepshowing = false
    }, -- Warrior's Fury
    {
      abilityId = 163098,
      threshold = 0,
      keepshowing = false
    }, -- Wretched Vitality
    },

    trials = {{
        trial = "Dreadsail Reef",
        enabled = false
    }, {
        trial = "Kyne's Aegis",
        enabled = false
    }, {
        trial = "Maw of Lorkhaj",
        enabled = false
    }, {
        trial = "Debugger Effects",
        enabled = false
    }},

    allOtherBuffs = 0,
    allOtherDebuffs = 0
}
BuffTracker.opacityCycle = 1.0
BuffTracker.trialAbilities = {}
BuffTracker.trackedBuffs = {}
BuffTracker.amountOfControls = 0
BuffTracker.amountofDebuffControls = 0
BuffTracker.sortingfunctions = {
    [BUFFTRACKER_SORTING_EXPIRE_ASC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        return a.remaining < b.remaining
    end,
    [BUFFTRACKER_SORTING_EXPIRE_DESC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        return a.remaining > b.remaining
    end,
    [BUFFTRACKER_SORTING_NAME_ASC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
    end,
    [BUFFTRACKER_SORTING_NAME_DESC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        return GetAbilityName(a.abilityId) > GetAbilityName(b.abilityId)
    end,
    [BUFFTRACKER_SORTING_TYPE_EXPIRE_ASC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        if a.effectType ~= b.effectType then
            return a.effectType < b.effectType
        else
            return a.remaining < b.remaining
        end
    end,
    [BUFFTRACKER_SORTING_TYPE_EXPIRE_DESC] = function(a, b)
        if a.priority and not b.priority then
            return true
        end
        if b.priority and not a.priority then
            return false
        end
        if a.effectType ~= b.effectType then
            return a.effectType < b.effectType
        else
            return a.remaining > b.remaining
        end
    end
}
local BUFF_EFFECT_TYPE_TRIAL_MECHANIC = 99
local BUFF_EFFECT_TYPE_COOLDOWN = 100
local roNPCooldown = 135924 -- Roaring Opportunist Cooldown
local roPCooldown = 137985 -- Roaring Opportunist Proc
local roDefaultsSeconds = 22 -- Default cooldown duration in seconds for Roaring Opportunist

local function CheckForCommonName(abilityId)
    local lang = GetCVar and GetCVar("Language.2") or "en"
    local commonNames = BuffTracker.commonEffectNames[lang] or BuffTracker.commonEffectNames["en"]
    local name = commonNames[abilityId] or nil
    return name
end

local function GetScale()
    return BuffTracker.savedVars.fontSize
end

-- Finds a buff or debuff by its ability ID in the provided table.
-- If the ability ID is in the alternateEffectIds table, it uses the alternate ID.
-- Returns the buff or debuff table if found, otherwise returns nil.
--- @param tab table The table to search in.
--- @param abilityId number The ability ID to search for.
--- @return table|nil The buff or debuff table if found, otherwise nil.
local function findByAbilityId(tab, abilityId)
    if not tab then
        return nil
    end

    if BuffTracker.alternateEffectIds[abilityId] then
        abilityId = BuffTracker.alternateEffectIds[abilityId]
        if BuffTracker.savedVars.debug then
            d("findByAbilityId: Using alternate ID for " .. abilityId)
        end
    end
    for _, ability in ipairs(tab) do
        if ability.abilityId == abilityId then
            if BuffTracker.savedVars.debug then
                d("findByAbilityId: Found ability with ID " .. abilityId)
            end
            return ability
        end
    end
    return nil
end

local function CreateControl(i)
    if i > BuffTracker.amountOfControls then
        local index = BuffTracker.amountOfControls + 1
        local lineControl = CreateControlFromVirtual("$(parent)Line" .. tostring(index), -- name
        BuffTrackerContainer, -- parent
        "BuffTracker_Line_Template", -- template
        "") -- suffix
        if (index == 1) then
            lineControl:SetAnchor(CENTER, BuffTrackerContainer, CENTER, 0, 0)
        else
            local prevControl = BuffTrackerContainer:GetNamedChild("Line" .. tostring(index - 1))
            lineControl:SetAnchor(TOP, prevControl, BOTTOM, 0, GetScale() * 4 / 9)
        end
        BuffTracker.amountOfControls = index
    elseif i > 1 then
        for j = 2, i do
            local lineControl = BuffTrackerContainer:GetNamedChild("Line" .. tostring(j))
            local prevControl = BuffTrackerContainer:GetNamedChild("Line" .. tostring(j - 1))
            lineControl:SetAnchor(TOP, prevControl, BOTTOM, 0, GetScale() * 4 / 9)
        end
    end
end

local function CreateControlDebuff(i)
    if i > BuffTracker.amountOfDebuffControls then
        local index = BuffTracker.amountOfDebuffControls + 1
        local lineControl = CreateControlFromVirtual("$(parent)Line" .. tostring(index), -- name
        DebuffTrackerContainer, -- parent
        "BuffTracker_Line_Template", -- template
        "") -- suffix
        if (index == 1) then
            lineControl:SetAnchor(CENTER, DebuffTrackerContainer, CENTER, 0, 0)
        else
            local prevControl = DebuffTrackerContainer:GetNamedChild("Line" .. tostring(index - 1))
            lineControl:SetAnchor(TOP, prevControl, BOTTOM, 0, GetScale() * 4 / 9)
        end
        BuffTracker.amountOfDebuffControls = index
    elseif i > 1 then
        for j = 2, i do
            local lineControl = DebuffTrackerContainer:GetNamedChild("Line" .. tostring(j))
            local prevControl = DebuffTrackerContainer:GetNamedChild("Line" .. tostring(j - 1))
            lineControl:SetAnchor(TOP, prevControl, BOTTOM, 0, GetScale() * 4 / 9)
        end
    end
end

local function hideControls(startIndex)
  if ( BuffTracker.amountOfControls == nil or startIndex == nil ) then return end
    if startIndex >= BuffTracker.amountOfControls then
        return
    end
    for i = startIndex + 1, BuffTracker.amountOfControls do
        local lineControl = BuffTrackerContainer:GetNamedChild("Line" .. tostring(i))
        lineControl:SetHidden(true)
    end
end

local function hideControlsDebuff(startIndex)
  if ( BuffTracker.amountOfDebuffControls == nil or startIndex == nil ) then return end
    if startIndex >= BuffTracker.amountOfDebuffControls then
        return
    end
    for i = startIndex + 1, BuffTracker.amountOfDebuffControls do
        local lineControl = DebuffTrackerContainer:GetNamedChild("Line" .. tostring(i))
        lineControl:SetHidden(true)
    end
end

BuffTracker.hideControls = hideControls
BuffTracker.hideControlsDebuff = hideControlsDebuff

local function UpdateDisplay()
    local now = GetFrameTimeSeconds()
    local toShow = {}
    local toShowDebuffs = {}

    for abilityId, buffData in pairs(BuffTracker.trackedBuffs) do
        if buffData.endTime or (buffData.keepshowing and IsUnitInCombat("player")) then
            local remain = Utils.SecondsRemaining(buffData.endTime)
            if (buffData.keepshowing and IsUnitInCombat("player")) or (remain <= (buffData.threshold or 60) and remain > 0) then
                if BuffTracker.savedVars.useSeperateOffsets and buffData.effectType == BUFF_EFFECT_TYPE_DEBUFF then
                  table.insert(toShowDebuffs, {
                      abilityId = abilityId,
                      remaining = remain,
                      iconName = buffData.iconName,
                      effectType = buffData.effectType,
                      priority = buffData.priority, 
                      stackCount = buffData.stackCount,
                      flash = (remain <= 0 and buffData.keepshowing),
                  })
                else 
                  table.insert(toShow, {
                      abilityId = abilityId,
                      remaining = remain,
                      iconName = buffData.iconName,
                      effectType = buffData.effectType,
                      priority = buffData.priority, 
                      stackCount = buffData.stackCount,
                      flash = (remain <= 0 and buffData.keepshowing),
                  })
                end
            end
        else
          if BuffTracker.savedVars.useSeperateOffsets and buffData.effectType == BUFF_EFFECT_TYPE_DEBUFF then  
            table.insert(toShowDebuffs, {
                abilityId = abilityId,
                remaining = -1,
                iconName = buffData.iconName,
                effectType = buffData.effectType,
                priority = buffData.priority,
                stackCount = buffData.stackCount,
                flash = false
            })
          else
            table.insert(toShow, {
                abilityId = abilityId,
                remaining = -1,
                iconName = buffData.iconName,
                effectType = buffData.effectType,
                priority = buffData.priority,
                stackCount = buffData.stackCount,
                flash = false
            })
          end
        end
    end

    if (not toShow or #toShow == 0) then
        hideControls(0)
        return
    end

    if (not toShowDebuffs or #toShowDebuffs == 0) then
        hideControlsDebuff(0)
    end

    -- d("ToShow: " .. Utils.PrintObject(toShow))

    -- Sort the buffs by remaining time, with priority buffs first
    table.sort(toShow, BuffTracker.sortingfunctions[BuffTracker.savedVars.sorting])
    table.sort(toShowDebuffs, BuffTracker.sortingfunctions[BuffTracker.savedVars.sorting])

    local itemsToShow = math.min(BuffTracker.savedVars.maxItems, #toShow)
    for i = 1, itemsToShow do
        local entry = toShow[i]
        BuffTracker.DisplayNotification(i, entry.abilityId, entry.iconName, entry.remaining, entry.effectType, entry.stackCount, entry.flash)
    end

    if #toShow < BuffTracker.amountOfControls then
        hideControls(#toShow)
    end

    local debuffItemsToShow = math.min(BuffTracker.savedVars.maxItems, #toShowDebuffs)
    for i = 1, debuffItemsToShow do
        local entry = toShowDebuffs[i]
        BuffTracker.DisplayNotification(i, entry.abilityId, entry.iconName, entry.remaining, entry.effectType, entry.stackCount, entry.flash)
    end

    if #toShowDebuffs < BuffTracker.amountOfControls then
        hideControlsDebuff(#toShowDebuffs)
    end

end

function BuffTracker.DisplayNotification(index, abilityId, icon, remaining, effectType, stackCount, flash)
    -- d("Displaying notification for abilityId: " .. abilityId .. ", remaining: " .. remaining)
    local scale = GetScale()
    CreateControl(index)
    local lineControl
    if  BuffTracker.savedVars.useSeperateOffsets and effectType == BUFF_EFFECT_TYPE_DEBUFF then
        lineControl = DebuffTrackerContainer:GetNamedChild("Line" .. tostring(index))
    else
        lineControl = BuffTrackerContainer:GetNamedChild("Line" .. tostring(index))
    end
    local buffName = GetAbilityName(abilityId)
    local commonName = CheckForCommonName(abilityId)
    if commonName then
        buffName = commonName .. " (" .. buffName .. ")"
    end

    lineControl:SetHeight(scale)
    local alertFont = string.format("$(GAMEPAD_BOLD_FONT)|%d|soft-shadow-thick", math.floor(scale * 8 / 9))
    local alertColor = ZO_ColorDef:New(1, 1, 1, 1) -- Default white color
    local labelControl = lineControl:GetNamedChild("Label")
    labelControl:SetFont(alertFont)
    local colorToUse = {1, 1, 1, 1} -- Default white color
    if flash then
        colorToUse = {1, 0, 0, BuffTracker.opacityCycle} -- Red with opacity cycle for debuffs that should keep showing in combat
    elseif effectType == BUFF_EFFECT_TYPE_DEBUFF then
        colorToUse = {1, 0, 0, 1} -- Red for debuffs
    elseif effectType == BUFF_EFFECT_TYPE_BUFF then
        colorToUse = {0, 0.8, 0, 1} -- Green for buffs
    elseif effectType == BUFF_EFFECT_TYPE_TRIAL_MECHANIC then
        colorToUse = {0.3, 0.3, 1, 1} -- Blue for trial mechanics
    elseif effectType == BUFF_EFFECT_TYPE_COOLDOWN then
        colorToUse = {0.6, 0, 0.8, 1} -- Purple for cooldowns
    end
    labelControl:SetColor(unpack(colorToUse))
    labelControl:SetDimensions(1200, scale)
    local labelString = ""
    if ( stackCount and stackCount > 1 ) then
        labelString = zo_strformat("<<1>> x<<2>>", buffName, stackCount);
    else
        labelString = zo_strformat("<<1>>", buffName)
    end
    if BuffTracker.savedVars.debug then 
        labelString = string.format("%s (%d)", labelString, abilityId)
    end
    labelControl:SetText(labelString)
    labelControl:SetWidth(labelControl:GetTextWidth())

    local timerLabel = lineControl:GetNamedChild("Timer")
    if remaining < 0 then
        timerLabel:SetHidden(true)
    else
        timerLabel:SetHidden(false)
        timerLabel:SetFont(alertFont)
        timerLabel:SetText(string.format("%.1f", remaining))
        timerLabel:SetDimensions(600, scale)
        timerLabel:SetWidth(timerLabel:GetTextWidth())
        timerLabel:SetAnchor(LEFT, labelControl, RIGHT, scale * 5 / 18)
        if (remaining > 3.0) then
          if flash then
            timerLabel:SetColor(1, 1, 0, BuffTracker.opacityCycle)
          else 
            timerLabel:SetColor(1, 1, 0, 1)
          end
        elseif (remaining > 1.0) then
            if flash then
              timerLabel:SetColor(1, 0.5, 0, BuffTracker.opacityCycle)
            else 
              timerLabel:SetColor(1, 0.5, 0, 1)
            end
        else
          if flash then 
            timerLabel:SetColor(1, 0, 0, BuffTracker.opacityCycle)
          else 
            timerLabel:SetColor(1, 0, 0, 1)
          end
        end
    end

    local iconControl = lineControl:GetNamedChild("Icon")
    if icon then
        iconControl:SetHidden(false)
        iconControl:SetTexture(icon)
        iconControl:SetDimensions(scale, scale)
        iconControl:SetAnchor(RIGHT, labelControl, LEFT, -scale * 2 / 9, 3)
    else
        iconControl:SetHidden(true)
    end

    lineControl:SetHidden(false)
end

local function OnEffectChanged(eventCode, changeType, effectSlot, buffName, unitTag, startTime, endTime, stackCount,
    iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)
    if not BuffTracker.charVars.enabled then
        return
    end
    if BuffTracker.savedVars.debug then
        d("OnEffectChanged: " .. buffName .. " (" .. abilityId .. ") - changeType = " .. changeType ..
              " - effectType = " .. effectType)
    end

    local buff =  findByAbilityId(BuffTracker.charVars.majorBuffs, abilityId) or
                  findByAbilityId(BuffTracker.charVars.minorBuffs, abilityId) or
                  findByAbilityId(BuffTracker.charVars.majorDebuffs, abilityId) or
                  findByAbilityId(BuffTracker.charVars.minorDebuffs, abilityId) or
                  findByAbilityId(BuffTracker.charVars.seteffects, abilityId) or
                  findByAbilityId(BuffTracker.charVars.cooldowns, abilityId) or
                  findByAbilityId(BuffTracker.charVars.trialAbilities, abilityId)

    if not buff then
        if BuffTracker.charVars.allOtherBuffs > 0 and effectType == BUFF_EFFECT_TYPE_BUFF then
            buff = {
                abilityId = abilityId,
                threshold = BuffTracker.charVars.allOtherBuffs
            }
        elseif BuffTracker.charVars.allOtherDebuffs > 0 and effectType == BUFF_EFFECT_TYPE_DEBUFF then
            buff = {
                abilityId = abilityId,
                threshold = BuffTracker.charVars.allOtherDebuffs
            }
        else
            return
        end
    end

    if not buff.threshold or buff.threshold == 0 then
        return
    end -- Ignore buffs/debuffs with no threshold

    if BuffTracker.savedVars.debug then
        d("Found effect: " .. buffName .. " (" .. abilityId .. ")")
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType ==
        EFFECT_RESULT_FULL_REFRESH or EFFECT_RESULT_TRANSFER then
        if effectType == BUFF_EFFECT_TYPE_BUFF then
            BuffTracker.trackedBuffs[buff.abilityId] = {
                endTime = endTime,
                threshold = buff.threshold,
                iconName = iconName,
                effectType = effectType,
                priority = false,
                stackCount = stackCount,
                keepshowing = buff.keepshowing
            }
        elseif effectType == BUFF_EFFECT_TYPE_DEBUFF then
            BuffTracker.trackedBuffs[buff.abilityId] = {
                endTime = endTime,
                threshold = buff.threshold,
                iconName = iconName,
                effectType = effectType,
                priority = false,
                stackCount = stackCount,
                keepshowing = buff.keepshowing
            }
        end
    elseif changeType == EFFECT_RESULT_FADED then
      if buff.keepshowing and buff.keepshowing == false then BuffTracker.trackedBuffs[buff.abilityId] = nil end -- remove buffs that should not keep showing when the have faded.
    end
    if BuffTracker.savedVars.debug then
        d("BuffTracker.trackedBuffs: " .. Utils.PrintObject(BuffTracker.trackedBuffs))
    end
end

local function OnCombatEvent(eventCode, changeType, isError, aName, aGraphic, aActionSlotType, sName, sType, tName,
    tType, hitValue, pType, dType, log, sUnitId, tUnitId, abilityId)
    if not BuffTracker.charVars.enabled then
        return
    end
    local abilityName = GetAbilityName(abilityId)

    -- Logging of combat events
    if BuffTracker.savedVars.debug then
        local changeTypeName = "Unknown"
        if changeType == ACTION_RESULT_BEGIN then
            changeTypeName = "Begin"
        elseif changeType == ACTION_RESULT_EFFECT_GAINED then
            changeTypeName = "Effect Gained"
        elseif changeType == ACTION_RESULT_EFFECT_GAINED_DURATION then
            changeTypeName = "Effect Gained Duration"
        elseif changeType == ACTION_RESULT_EFFECT_FADED then
            changeTypeName = "Effect Faded"
        else
            changeTypeName = "Other Effect (" .. changeType .. ")"
        end
        if changeType ~= ACTION_RESULT_EFFECT_FADED then
            d("Combat Event: " .. abilityName .. "(" .. abilityId .. ") - changeType = " .. changeTypeName ..
                  " - hitValue = " .. (hitValue or "n/a") .. " - " .. (tName or "Unknown Source") .. " - tUnitId = " ..
                  (tUnitId or "n/a"))
        end
    end

    local effect = findByAbilityId(BuffTracker.trialAbilities, abilityId)
    if BuffTracker.savedVars.debug then
        d("Found Effect: " .. Utils.PrintObject(effect))
    end
    if not effect then
        return
    end

    if changeType == ACTION_RESULT_BEGIN or changeType == ACTION_RESULT_EFFECT_GAINED_DURATION then
        if BuffTracker.savedVars.debug then
            d("Action Result Begin or Effect Gained Duration for abilityId: " .. abilityId)
        end
        BuffTracker.trackedBuffs[effect.abilityId] = {
            endTime = GetFrameTimeSeconds() + hitValue,
            threshold = effect.threshold,
            iconName = nil,
            effectType = BUFF_EFFECT_TYPE_TRIAL_MECHANIC,
            priority = true
        }
    elseif changeType == ACTION_RESULT_EFFECT_GAINED then
        if BuffTracker.savedVars.debug then
            d("Action Result Effect Gained for abilityId: " .. abilityId)
        end
        BuffTracker.trackedBuffs[effect.abilityId] = {
            endTime = GetFrameTimeSeconds() + hitValue,
            threshold = effect.threshold,
            iconName = nil,
            effectType = BUFF_EFFECT_TYPE_TRIAL_MECHANIC,
            priority = true
        }
    elseif changeType == ACTION_RESULT_EFFECT_FADED then
        BuffTracker.trackedBuffs[effect.abilityId] = nil
        if BuffTracker.savedVars.debug then
            d("Action Result Effect Faded for abilityId: " .. abilityId)
        end
    end

    if BuffTracker.savedVars.debug then
        d("BuffTracker.trackedBuffs: " .. Utils.PrintObject(BuffTracker.trackedBuffs))
    end
end

local function roCooldown(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId,
    overflow)
    if BuffTracker.savedVars.debug then
        d("Roaring Opportunist Cooldown: abilityId = " .. abilityId .. " - abilityName = " .. (abilityName or "n/a") ..
              " - result = " .. result .. " - hitValue = " .. (hitValue or "n/a"))
    end
    local effect = findByAbilityId(BuffTracker.charVars.cooldowns, abilityId)
    if not effect then
        return
    end

    BuffTracker.trackedBuffs[roNPCooldown] = {
        endTime = GetFrameTimeSeconds() + roDefaultsSeconds,
        threshold = effect.threshold,
        iconName = nil,
        effectType = BUFF_EFFECT_TYPE_COOLDOWN,
        priority = true
    }
    if BuffTracker.savedVars.debug then
        d("BuffTracker.trackedBuffs: " .. Utils.PrintObject(BuffTracker.trackedBuffs))
    end
end

local function OnPlayerActivated()
    if BuffTracker.savedVars.debug then
        d("OnPlayerActivated called")
    end
    EVENT_MANAGER:UnregisterForEvent("BuffTrackerInit", EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForUpdate("BuffTrackerUpdate", 100, UpdateDisplay)
    BuffTracker.trialAbilities = BuffTracker:GenerateTrialEffects()
end

function BuffTracker:GenerateTrialEffects()
    if BuffTracker.savedVars.debug then
        d("GenerateTrialEffects called")
    end
    local trialAbilities = {}
    for _, trial in ipairs(BuffTracker.charVars.trials) do
        if trial.enabled then
            local trialName = trial.trial
            for _, effect in ipairs(BuffTracker.trialEffects[trialName]) do
                table.insert(trialAbilities, effect)
            end
        end
    end
    if BuffTracker.savedVars.debug then
        d("Generated trial abilities: " .. Utils.PrintObject(trialAbilities))
    end
    return trialAbilities
end

function BuffTracker.RegisterSlashCommands()
    SLASH_COMMANDS["/bt_tracked"] = function()
        if BuffTracker.savedVars.debug then
            d("Currently tracked buffs/debuffs:")
            for abilityId, buffData in pairs(BuffTracker.trackedBuffs) do
                local name = GetAbilityName(abilityId)
                local remain = buffData.endTime and Utils.SecondsRemaining(buffData.endTime) or -1
                d(string.format("- %s (%d): remaining = %.1f, effectType = %d, priority = %s", name, abilityId, remain,
                    tostring(buffData.effectType), tostring(buffData.priority)))
            end
        end
    end
end

local function updateChangedIds()
  for _, buff in ipairs(BuffTracker.charVars.majorBuffs) do
      if BuffTracker.alternateEffectIds[buff.abilityId] ~= buff.abilityId then
          buff.abilityId = BuffTracker.alternateEffectIds[buff.abilityId]
      end
      if not buff.keepshowing then
          buff.keepshowing = false
      end
  end
  for _, buff in ipairs(BuffTracker.charVars.minorBuffs) do
      if BuffTracker.alternateEffectIds[buff.abilityId] ~= buff.abilityId then
          buff.abilityId = BuffTracker.alternateEffectIds[buff.abilityId]
      end
      if not buff.keepshowing then
          buff.keepshowing = false
      end
  end
  for _, debuff in ipairs(BuffTracker.charVars.majorDebuffs) do
      if BuffTracker.alternateEffectIds[debuff.abilityId] ~= debuff.abilityId then
          debuff.abilityId = BuffTracker.alternateEffectIds[debuff.abilityId]
      end
      if not debuff.keepshowing then
          debuff.keepshowing = false
      end
  end
  for _, debuff in ipairs(BuffTracker.charVars.minorDebuffs) do
      if BuffTracker.alternateEffectIds[debuff.abilityId] ~= debuff.abilityId then
          debuff.abilityId = BuffTracker.alternateEffectIds[debuff.abilityId]
      end
      if not debuff.keepshowing then
         debuff.keepshowing = false
      end
  end
  for _, effect in ipairs(BuffTracker.charVars.seteffects) do
      if BuffTracker.alternateEffectIds[effect.abilityId] ~= effect.abilityId then
          effect.abilityId = BuffTracker.alternateEffectIds[effect.abilityId]  
      end
      if not effect.keepshowing then
          effect.keepshowing = false
      end
  end
  for _, effect in ipairs(BuffTracker.charVars.cooldowns) do
      if BuffTracker.alternateEffectIds[effect.abilityId] ~= effect.abilityId then
          effect.abilityId = BuffTracker.alternateEffectIds[effect.abilityId]  
      end
      if not effect.keepshowing then
          effect.keepshowing = false
      end
  end
end

local function removeMinorBuff(id)
  for i = #BuffTracker.charVars.minorBuffs, 1, -1 do
      local minorBuff = BuffTracker.charVars.minorBuffs[i]
      if minorBuff.abilityId == id then 
        table.remove(BuffTracker.charVars.minorBuffs, i) -- Remove from minor buffs
      end
  end
end
local function removeMajorBuff(id)
  for i = #BuffTracker.charVars.majorBuffs, 1, -1 do
      local majorBuff = BuffTracker.charVars.majorBuffs[i]
      if majorBuff.abilityId == id then 
        table.remove(BuffTracker.charVars.majorBuffs, i) -- Remove from major buffs
      end
  end
end
local function removeMinorDebuff(id)
  for i = #BuffTracker.charVars.minorDebuffs, 1, -1 do
      local minorDebuff = BuffTracker.charVars.minorDebuffs[i]
      if minorDebuff.abilityId == id then 
        table.remove(BuffTracker.charVars.minorDebuffs, i) -- Remove from minor debuffs
      end
  end
end

local function removeMajorDebuff(id)
  for i = #BuffTracker.charVars.majorDebuffs, 1, -1 do
      local majorDebuff = BuffTracker.charVars.majorDebuffs[i]
      if majorDebuff.abilityId == id then 
        table.remove(BuffTracker.charVars.majorDebuffs, i) -- Remove from minor buffs
      end
  end
end

local function bugFixes()
    -- Fix for version 1.0.3: Remove Minor Breach and Minor Vulnerability from minor buffs
    -- This is a workaround for the issue where these buffs were incorrectly categorized as minor buffs
    if not BuffTracker.charVars.minorBuffs then
        return
    end
    if not BuffTracker.charVars.minorDebuffs then
        return
    end
    if not BuffTracker.charVars.charVersion then
        if BuffTracker.savedVars.debug then
            d("BuffTracker: Applying bug fix for version 1.0.3")
        end
        -- Remove Minor Breach and Minor Vulnerability from minor buffs if they exist
        local minorBreach = nil
        local minorVulnerability = nil
        for i = #BuffTracker.charVars.minorBuffs, 1, -1 do
            local minorBuff = BuffTracker.charVars.minorBuffs[i]
            if minorBuff.abilityId == 38688 then
                table.remove(BuffTracker.charVars.minorBuffs, i) -- Remove from minor buffs
                minorBreach = minorBuff
            elseif minorBuff.abilityId == 42062 then
                table.remove(BuffTracker.charVars.minorBuffs, i) -- Remove from minor buffs
                minorVulnerability = minorBuff
            end
        end

        -- Add Minor Breach and Minor Vulnerability to minor debuffs if they don't already exist
        local containsMinorBreach = false
        local containsMinorVulnerability = false
        for _, minorDebuff in ipairs(BuffTracker.charVars.minorDebuffs) do
            if minorDebuff.abilityId == 38688 then
                containsMinorBreach = true
            elseif minorDebuff.abilityId == 42062 then
                containsMinorVulnerability = true
            end
        end
        if not containsMinorBreach then
            table.insert(BuffTracker.charVars.minorDebuffs, minorBreach) -- Add Minor Breach to minor debuffs
        end
        if not containsMinorVulnerability then
            table.insert(BuffTracker.charVars.minorDebuffs, minorVulnerability) -- Add Minor Vulnerability to minor debuffs
        end

        --- Remove Minor Vulnerability from minor debuffs if it exists more than once
        local minorVulnerabilityIndex = nil
        for i = #BuffTracker.charVars.minorDebuffs, 1, -1 do
            local minorDebuff = BuffTracker.charVars.minorDebuffs[i]
            if minorDebuff.abilityId == 42062 and not minorVulnerabilityIndex then
                minorVulnerabilityIndex = i
            elseif minorDebuff.abilityId == 42062 and minorVulnerabilityIndex then
                table.remove(BuffTracker.charVars.minorDebuffs, i) -- Remove from minor debuffs
            end
        end

        table.sort(BuffTracker.charVars.minorDebuffs, function(a, b)
            return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
        end)

        BuffTracker.charVars.charVersion = "1.0.3" -- Set version to 1.0.3 to indicate the fix has been applied
    end
    if BuffTracker.charVars.charVersion <= "1.2.0" then
        if BuffTracker.savedVars.debug then
            d("BuffTracker: Applying bug fix for version 1.2.1")
        end
        -- Fix for version 1.2.0: Remove duplicate entry of 
        for pos, effect in ipairs(BuffTracker.charVars.seteffects) do
            if effect.abilityId == 61763 then
              table.remove(BuffTracker.charVars.seteffects, pos)
            end
        end

        BuffTracker.charVars.charVersion = "1.2.1" -- Set version to 1.2.1 to indicate the fix has been applied
    end
    if BuffTracker.charVars.charVersion <= "1.2.6" then
        BuffTracker.savedVars.useSeperateOffsets = false
        BuffTracker.savedVars.offsetXDebuff = 0
        BuffTracker.savedVars.offsetYDebuff = 0
        BuffTracker.charVars.charVersion = "1.2.6" -- Set version to 1.2.6 to indicate the fix has been applied
    end
    if BuffTracker.charVars.charVersion <= "1.3.0" then
       -- Fix for version 1.3.0: Remove old effects
        removeMajorBuff(22233) -- Remove Major Prophecy
        removeMajorBuff(33317) -- Remove Major Sorcery        
        removeMinorBuff(61691) -- Remove Minor Prophecy
        removeMinorBuff(61685) -- Remove Minor Sorcery
        BuffTracker.charVars.charVersion = "1.3.0"
        d("BuffTracker: Removed major/minor prophecy and major/minor sorcery.")
    end
    -- Set to current version
    BuffTracker.charVars.charVersion = BuffTracker.version
end

function BuffTracker.cycleOpacity()
    BuffTracker.opacityCycle = BuffTracker.opacityCycle - 0.333
    if BuffTracker.opacityCycle <= 0.0 then
        BuffTracker.opacityCycle = 1.0
    end
end

local function addNewEffects()
  local addition = false
  for _, buff in ipairs(BuffTracker.defaultSettings.majorBuffs) do
      local exists = false
      for _, existingBuff in ipairs(BuffTracker.charVars.majorBuffs) do
          if existingBuff.abilityId == buff.abilityId then
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.majorBuffs, buff)
      end
  end
  if addition then
      table.sort(BuffTracker.charVars.majorBuffs, function(a, b)
          return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
      end)
  end
  local addition = false
  for _, buff in ipairs(BuffTracker.defaultSettings.minorBuffs) do
      local exists = false
      for _, existingBuff in ipairs(BuffTracker.charVars.minorBuffs) do
          if existingBuff.abilityId == buff.abilityId then
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.minorBuffs, buff)
      end
  end
  if addition then
      table.sort(BuffTracker.charVars.minorBuffs, function(a, b)
          return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
      end)
  end
  local addition = false
  for _, debuff in ipairs(BuffTracker.defaultSettings.majorDebuffs) do
      local exists = false
      for _, existingDebuff in ipairs(BuffTracker.charVars.majorDebuffs) do
          if existingDebuff.abilityId == debuff.abilityId then
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.majorDebuffs, debuff)
      end
  end
  if addition then
      table.sort(BuffTracker.charVars.majorDebuffs, function(a, b)
          return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
      end)
  end
  for _, debuff in ipairs(BuffTracker.defaultSettings.minorDebuffs) do
      local exists = false
      for _, existingDebuff in ipairs(BuffTracker.charVars.minorDebuffs) do
          if existingDebuff.abilityId == debuff.abilityId then
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.minorDebuffs, debuff)
      end
  end 
  local addition = false
  for _, effect in ipairs(BuffTracker.defaultSettings.seteffects) do
      local exists = false
      for _, existingEffect in ipairs(BuffTracker.charVars.seteffects) do
          if existingEffect.abilityId == effect.abilityId then
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.seteffects, effect)
          addition = true
      end
  end
  if addition then
      table.sort(BuffTracker.charVars.seteffects, function(a, b)
          return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
      end)
  end
  local addition = false
  for _, effect in ipairs(BuffTracker.defaultSettings.cooldowns) do
      local exists = false
      for _, existingEffect in ipairs(BuffTracker.charVars.cooldowns) do
          if existingEffect.abilityId == effect.abilityId then    
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.cooldowns, effect)
      end
  end 
  if addition then
      table.sort(BuffTracker.charVars.cooldowns, function(a, b)
          return GetAbilityName(a.abilityId) < GetAbilityName(b.abilityId)
      end)
  end
  local addition = false
  for _, trial in ipairs(BuffTracker.defaultSettings.trials) do
      local exists = false
      for _, existingTrial in ipairs(BuffTracker.charVars.trials) do
          if existingTrial.trial == trial.trial then    
              exists = true
              break
          end
      end
      if not exists then
          table.insert(BuffTracker.charVars.trials, trial)
      end
  end
  if addition then
      table.sort(BuffTracker.charVars.trials, function(a, b)
          return a.trial < b.trial
      end)
  end
end

function BuffTracker:Initialize()
    BuffTracker.savedVars = ZO_SavedVars:NewAccountWide("BuffTrackerSavedVars", 1, nil,
        BuffTracker.defaultAccountSettings)
    BuffTracker.charVars = ZO_SavedVars:NewCharacterIdSettings("BuffTrackerCharVars", 1, nil,
        BuffTracker.defaultSettings)

    addNewEffects()
    bugFixes()
    updateChangedIds()

    BuffTracker.CreateSettings()
    BuffTracker.RegisterSlashCommands()

    BuffTrackerContainer:SetAnchor(CENTER, GuiRoot, CENTER, BuffTracker.savedVars.offsetX, BuffTracker.savedVars.offsetY)

    EVENT_MANAGER:RegisterForEvent("BuffTracker_Effect_Changed", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent("BuffTracker_Effect_Changed", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG,
        "player")
    -- EVENT_MANAGER:RegisterForEvent("BuffTracker_Combat_Player", EVENT_COMBAT_EVENT, OnCombatEvent)
    -- EVENT_MANAGER:AddFilterForEvent("BuffTracker_Combat_Player", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    -- EVENT_MANAGER:RegisterForEvent("BuffTracker_Combat_Group", EVENT_COMBAT_EVENT, OnCombatEvent)
    -- EVENT_MANAGER:AddFilterForEvent("BuffTracker_Combat_Group", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
    EVENT_MANAGER:RegisterForEvent("BuffTrackerInit", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent("BuffTracker_ROCooldown", EVENT_COMBAT_EVENT, roCooldown)
    EVENT_MANAGER:AddFilterForEvent("BuffTracker_ROCooldown", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID,
        roNPCooldown, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent("BuffTracker_ROCooldown", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID,
        roPCooldown, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForUpdate("BuffTracker_Opacity_Cycle", 250, BuffTracker.cycleOpacity)

end

EVENT_MANAGER:RegisterForEvent("BuffTracker_Loaded", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == "BuffTracker" then
        BuffTracker:Initialize()
        EVENT_MANAGER:UnregisterForEvent("BuffTracker_Loaded", EVENT_ADD_ON_LOADED)
    end
end)

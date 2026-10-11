
-- local localizedNames = {
--     ["de"] = "unersättlicher Hunger",
--     ["en"] = "Insatiable Hunger",
--     ["es"] = "hambre insaciable",
--     ["fr"] = "Faim insatiable",
--     ["jp"] = "満たされぬ飢え",
--     ["ru"] = "Ненасытный голод",
--     ["zh"] = "无尽渴求",
--     ["ze"] = "无尽渴求",
-- }

local addonName = "InsatiableHungerBlocker"
local hungerIconFilename = "/esoui/art/icons/ability_werewolf_007.dds"
local hungerSkillId = 33208
local feedingFreezySkillId = 58775
local lastActiveTime = 0
local isCombatActive = false
local reviveUntil = 0
local wasPositivelyActive = false
local db
local SV_NAME = "InsatiableHungerBlocker_SV"
local defaults = {
    timeout = 2000,
    dungeonOnly = true,
    pounceEnabled = true,
    pounceBossOnly = true,
    feedingpriority = false,
}

local function ShouldHide()
    local hasSynergy, _, iconFilename = GetCurrentSynergyInfo()
    return hasSynergy and iconFilename == hungerIconFilename and (not db.dungeonOnly or IsUnitInDungeon("player"))
end

local function IsPositivelyActive()
    return IsUnitDeadOrReincarnating("player") or IsUnitSwimming("player") or GetGameTimeMilliseconds() < reviveUntil
end

local function OnCombatEvent(_, result, _, _, _, _, _, _, targetName)
    if IsUnitInCombat("player") and targetName ~= GetRawUnitName("player") and
       (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        lastActiveTime = GetGameTimeMilliseconds()
    end
end

local function OnSoulGemResurrectionStart(_, duration)
    reviveUntil = GetGameTimeMilliseconds() + (duration or db.timeout)
end

local function OnSoulGemResurrectionEnd()
    reviveUntil = 0
end

local function RestoreInsatiableHungeSynergyrInfo()
    if ShouldHide() then
        SHARED_INFORMATION_AREA:SetHidden(SYNERGY, isCombatActive)
        if not isCombatActive then
            -- the value of synergy info could be empty or wrong since they are hidden when they should be updated, so we need to set the text and icon back
            -- SYNERGY.action:SetText(localizedNames[GetCVar("language.2")] or localizedNames["en"])
            SYNERGY.action:SetText(LocalizeString("<<1>>", GetAbilityName(hungerSkillId)))
            SYNERGY.icon:SetTexture(hungerIconFilename)
        end
    end
end

local function CombatIdleCheck()
    local now = GetGameTimeMilliseconds()
    local positivelyActive = IsPositivelyActive()
    if positivelyActive or wasPositivelyActive then
        lastActiveTime = now
    end
    wasPositivelyActive = positivelyActive

    local isActivating = (now - lastActiveTime) < db.timeout

    if isCombatActive ~= isActivating then
        isCombatActive = isActivating
        RestoreInsatiableHungeSynergyrInfo()
    end
end

local function SetTimeout(timeout)
    db.timeout = timeout
    EVENT_MANAGER:UnregisterForUpdate(addonName)
    EVENT_MANAGER:RegisterForUpdate(addonName, db.timeout / 2, CombatIdleCheck)
end

local function OnCombatStateChange(_, inCombat)
    if inCombat then
        wasPositivelyActive = IsPositivelyActive()
        if wasPositivelyActive then
            lastActiveTime = GetGameTimeMilliseconds()
        end
        isCombatActive = (GetGameTimeMilliseconds() - lastActiveTime) < db.timeout
        RestoreInsatiableHungeSynergyrInfo()
        EVENT_MANAGER:RegisterForUpdate(addonName, db.timeout / 2, CombatIdleCheck)
    else
        isCombatActive = false
        reviveUntil = 0
        wasPositivelyActive = false
        lastActiveTime = 0
        EVENT_MANAGER:UnregisterForUpdate(addonName)
        RestoreInsatiableHungeSynergyrInfo()
    end
end

local function IsPounceAbility(slotNum)
    local abilityId = GetSlotBoundId(slotNum)
    return abilityId == 32632 or abilityId == 39104 or abilityId == 39105
end

local function OnPlayerInit()
    EVENT_MANAGER:UnregisterForEvent(addonName .. "_INIT", EVENT_PLAYER_ACTIVATED)

    SetSynergyPriorityOverride(hungerSkillId, 10)
    if db.feedingpriority then
        SetSynergyPriorityOverride(feedingFreezySkillId, 4)
    end
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_PLAYER_COMBAT_STATE, OnCombatStateChange)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_START_SOUL_GEM_RESURRECTION,
        OnSoulGemResurrectionStart)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_END_SOUL_GEM_RESURRECTION,
        OnSoulGemResurrectionEnd)
    EVENT_MANAGER:AddFilterForEvent(addonName, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
        REGISTER_FILTER_IS_ERROR, false)

    ZO_PreHook(SYNERGY, "OnSynergyAbilityChanged", function()
        if ShouldHide() and isCombatActive then
            SHARED_INFORMATION_AREA:SetHidden(SYNERGY, true)
            return true
        end
    end)

    ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
        local slotNum = tonumber(debug.traceback():match('ACTION_BUTTON_(%d)'))
        if db.pounceEnabled and (not db.pounceBossOnly or GetUnitName("boss1") ~= "") and IsPounceAbility(slotNum) then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT10)
            return true
        end
    end)
end

local function PrintUsage()
    CHAT_ROUTER:AddSystemMessage(GetString(IHB_USAGE))
    CHAT_ROUTER:AddSystemMessage("/ihb timeout {milliseconds}")
    CHAT_ROUTER:AddSystemMessage("/ihb overlandtoggle")
    CHAT_ROUTER:AddSystemMessage("/ihb pouncetoggle")
    CHAT_ROUTER:AddSystemMessage("/ihb pouncebosstoggle")
    CHAT_ROUTER:AddSystemMessage("/ihb feedingpriority")
end

local function PrintSettings()
    CHAT_ROUTER:AddSystemMessage(GetString(IHB_SETTINGS_STATUS))
    CHAT_ROUTER:AddSystemMessage(string.format("%s: %dms", GetString(IHB_TIMEOUT), db.timeout))
    CHAT_ROUTER:AddSystemMessage(string.format("%s: %s", GetString(IHB_DUNGEON_ONLY), GetString(db.dungeonOnly and IHB_ENABLED or IHB_DISABLED)))
    CHAT_ROUTER:AddSystemMessage(string.format("%s: %s", GetString(IHB_BLOCK_POUNCE), GetString(db.pounceEnabled and IHB_ENABLED or IHB_DISABLED)))
    CHAT_ROUTER:AddSystemMessage(string.format("/ %s: %s", GetString(IHB_POUNCE_BOSS_ONLY), GetString(db.pounceBossOnly and IHB_ENABLED or IHB_DISABLED)))
    CHAT_ROUTER:AddSystemMessage(string.format("%s: %s", GetString(IHB_FEEDING_PRIORITY), GetString(db.feedingpriority and IHB_ENABLED or IHB_DISABLED)))
end

local function CreateMenu()
    if not LibAddonMenu2 then return end

    local panelData = {
        type = "panel",
        name = "Insatiable Hunger Blocker",
        displayName = "|c2e5c8cI|r|c355e88n|r|c3d6183s|r|c44637fa|r|c4b667bt|r|c526877i|r|c5a6a72a|r|c616d6eb|r|c686f6al|r|c6f7266e|r |c777461H|r|c7e775du|r|c857959n|r|c8d7b54g|r|c947e50e|r|c9b804cr|r |ca28348B|r|caa8543l|r|cb1873fo|r|cb88a3bc|r|cbf8c37k|r|cc78f32e|r|cce912er|r",
        author = "|c215895Lykeion|r",
        version = "|ccc922f1.14|r",
        slashCommand = "/ihb",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "|c999999" .. GetString(IHB_MENU_DESCRIPTION) .. "|r",
        },
        {
            type = "slider",
            name = GetString(IHB_TIMEOUT),
            tooltip = GetString(IHB_TIMEOUT_TOOLTIP),
            min = 500,
            max = 3000,
            step = 100,
            default = defaults.timeout,
            getFunc = function()
                return db.timeout
            end,
            setFunc = function(value)
                SetTimeout(value)
            end,
        },
        {
            type = "checkbox",
            name = GetString(IHB_DUNGEON_ONLY),
            tooltip = GetString(IHB_DUNGEON_ONLY_TOOLTIP),
            default = defaults.dungeonOnly,
            getFunc = function()
                return db.dungeonOnly
            end,
            setFunc = function(value)
                db.dungeonOnly = value
            end,
        },
        {
            type = "checkbox",
            name = GetString(IHB_BLOCK_POUNCE),
            tooltip = GetString(IHB_BLOCK_POUNCE_TOOLTIP),
            default = defaults.pounceEnabled,
            getFunc = function()
                return db.pounceEnabled
            end,
            setFunc = function(value)
                db.pounceEnabled = value
            end,
        },
        {
            type = "checkbox",
            name = "/ " .. GetString(IHB_POUNCE_BOSS_ONLY),
            default = defaults.pounceBossOnly,
            disabled = function()
                return not db.pounceEnabled
            end,
            getFunc = function()
                return db.pounceBossOnly
            end,
            setFunc = function(value)
                db.pounceBossOnly = value
            end,
        },
        {
            type = "checkbox",
            name = GetString(IHB_FEEDING_PRIORITY),
            tooltip = GetString(IHB_FEEDING_PRIORITY_TOOLTIP),
            default = defaults.feedingpriority,
            getFunc = function()
                return db.feedingpriority
            end,
            setFunc = function(value)
                db.feedingpriority = value
                if value then
                    SetSynergyPriorityOverride(feedingFreezySkillId, 4)
                else
                    ClearSynergyPriorityOverride(feedingFreezySkillId)
                end
            end,
        },
    }

    LibAddonMenu2:RegisterAddonPanel(addonName .. "Options", panelData)
    LibAddonMenu2:RegisterOptionControls(addonName .. "Options", optionsData)
end

local function OnLoaded(_, name)
    if name ~= addonName then return end
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(addonName .. "_INIT", EVENT_PLAYER_ACTIVATED, OnPlayerInit)

    local worldName = GetWorldName()
    db = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, defaults, worldName)
    CreateMenu()

    SLASH_COMMANDS["/ihb"] = function(commands)
        local args = {}
        for command in string.gmatch(commands, "%S+") do
            table.insert(args, command)
        end

        if #args == 0 then
            PrintUsage()
            PrintSettings()
            return
        end

        if args[1] == "timeout" then
            local timeout = tonumber(args[2])
            if not timeout then
                CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_INVALID_NUMBER), args[2]))
            elseif timeout < 500 then
                CHAT_ROUTER:AddSystemMessage(GetString(IHB_TIMEOUT_TOO_SHORT))
            else
                SetTimeout(timeout)
                CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_TIMEOUT_SET), timeout))
            end
        elseif args[1] == "overlandtoggle" then
            db.dungeonOnly = not db.dungeonOnly
            CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_DUNGEON_ONLY_MODE), GetString(db.dungeonOnly and IHB_ENABLED or IHB_DISABLED)))
        elseif args[1] == "feedingpriority" then
            db.feedingpriority = not db.feedingpriority
            if db.feedingpriority then
                SetSynergyPriorityOverride(feedingFreezySkillId, 4)
            else
                ClearSynergyPriorityOverride(feedingFreezySkillId)
            end
            CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_FEEDING_PRIORITY_MSG), GetString(db.feedingpriority and IHB_ENABLED or IHB_DISABLED)))
        elseif args[1] == "pouncetoggle" then
            db.pounceEnabled = not db.pounceEnabled
            CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_POUNCE_MSG), GetString(db.pounceEnabled and IHB_ENABLED or IHB_DISABLED)))
        elseif args[1] == "pouncebosstoggle" then
            if not db.pounceEnabled then
                CHAT_ROUTER:AddSystemMessage(GetString(IHB_POUNCE_BOSS_ONLY_DISABLED))
            else
                db.pounceBossOnly = not db.pounceBossOnly
                CHAT_ROUTER:AddSystemMessage(string.format(GetString(IHB_POUNCE_BOSS_ONLY_MSG), GetString(db.pounceBossOnly and IHB_ENABLED or IHB_DISABLED)))
            end
        end
    end
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, OnLoaded)

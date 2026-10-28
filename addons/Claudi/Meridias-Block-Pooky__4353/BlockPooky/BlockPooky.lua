--[[
    BlockPooky - Main Module

    The core BlockPooky addon provides PvP awareness through block warnings and combat notifications.
    This is the main initialization and event handling module that coordinates all other components.

    Key Features:
    - Detects incoming pull abilities and warns the player to block
    - Provides multiple notification channels (UI, sound, chat, CSA)
    - Group integration for pull warnings via LibGroupBroadcast
    - Customizable trigger abilities and notification settings

    Event Flow:
    1. Monitors EVENT_COMBAT_EVENT for ACTION_RESULT_EFFECT_GAINED (pull effects such as
       Dark Convergence / Rush of Agony) and for damage dealt to the player by a configured
       trigger (gap closers such as Critical Rush only ever deal damage)
    2. Checks if the ability ID or name matches configured triggers
    3. Validates source is not player/companion/group member
    4. Applies cooldown to prevent spam
    5. Triggers multi-channel warning system
--]]

--[[ basic initialization -------------------------------------------------------------------------------------------]]
BlockPooky = BlockPooky or {}
-- Addon version information
BlockPooky.version = 2.23
BlockPooky.svVersion = 1.8 -- SavedVariables version for config migration
BlockPooky.name = "BlockPooky"
BlockPooky.msgText = "BLOCK Pooky!"
-- Runtime state tracking
BlockPooky.isActive = false
-- Message templates for customization
BlockPooky.defaultMessages = {
    blockWarning = "BLOCK Pooky!",
    blockingHint = "Pooky BLOCKING!",
    vigorHint = "VIGOR!",
    dcReady = "DC Ready!",
    roaReady = "ROA Ready!",
    mountReady = "Pooky you can MOUNT!",
    ccImmunity = "CC Immunity",
    ccStun = "STUNNED!",
    ccFear = "FEARED!",
    ccDisorient = "DISORIENTED!",
    negateWarning = "MOVE Pooky! You're in a Negate!",
    allMounted = "All Pookies Mounted!",
    allCanMount = "All Pookies can Mount!",
    pookyUnmounted = "Pooky unmounted!"
}
local BlockPooky = BlockPooky

--[[
    Predefined Trigger Abilities

    These arrays contain ability IDs that should trigger block warnings.
    Uses one representative ID per ability to get the localized name via GetAbilityName().
    ESO abilities often have multiple IDs for the same ability, so we pick one reliable ID.
--]]
BlockPooky.predefinedTriggerAbilities = {
    -- effects
    159279, -- Agonie
    159385, -- Konvergenz
    -- skills
    20492,  -- feuriger Griff (Fiery Grip)
    20496,  -- unerbittlicher Griff (Unreleting Grip)
    20499,  -- Ketten der Verwüstung (Chains of Devastation)
    40336,  -- Silberne Leine (silver leash)
    18346,  -- Teleportationsschlag (Teleport Strike)
    25494,  -- Lotusfächer (Lotus Fan)
    25485,  -- Hinterhalt (Ambush)
    21061,  -- krit. Toben (Stampede)
    28448,  -- krit. Stürmen (Critical Charge)
    38782   -- krit. Preschen (Critical Rush)
}
BlockPooky.predefinedPullAbilities = {
    -- effects
    159279, -- Agonie
    159385, -- Konvergenz
}

---Runtime lookup tables rebuilt from config by BlockPooky.RebuildTriggerAbilities()
---CustomTriggerAbilities: cleaned ability name -> true (effect-based matching)
---TriggerAbilityIds: ability ID -> true (ID matching for effect and damage events)
BlockPooky.CustomTriggerAbilities = {}
BlockPooky.TriggerAbilityIds = {}

local BlockPooky_lastPookyWarning = 0
local BlockPooky_lastGroupMessage = 0
local BlockPooky_grpMsgActive = false
local BlockPooky_groupProtocolName = "BlockPookyWarnings"
local BlockPooky_groupProtocolId = 251
local BlockPooky_groupProtocol = nil
local BlockPooky_groupHandler = nil
local BlockPooky_groupNoticeShown = {}
BlockPooky.groupMessagingNotices = {
    prefix = "Group sync",
    incomingWarningPrefix = "WARNING: Incoming ",
    incomingWarningSuffix = "! from ",
    defaultWarningType = "pull",
    defaultSourceName = "group",
    noProtocol = "unavailable right now. Your own local warnings still work.",
    protocolDisabled = "disabled in LibGroupBroadcast settings.",
    sendFailed = "could not send a warning to your group.",
    missingLGB = "LibGroupBroadcast is missing or disabled. Group sync is unavailable.",
    handlerRegisterFailed = "could not start group sync.",
    protocolFinalizeFailed = "group sync setup is incomplete.",
}

local BlockPooky_chat = LibChatMessage(BlockPooky.name, "BP") -- long and short tag to identify who is printing the message
local BlockPooky_LGB = LibGroupBroadcast


--[[ helper functions ------------------------------------------------------------------------------------------------]]

---Removes ESO's color code suffixes from ability/unit names
---ESO sometimes appends color codes like "^n" or "^p" to names, this strips them
---@param name string|nil the name to clean
---@return string cleaned name without color codes
function BlockPooky.CleanupName(name)
    if name then return name:gsub("%^%a%a?$", "") end
    return name or ""
end

---Checks if a given name is in the current group
---@param name string the name to check
---@return boolean true if the name is a group member
function BlockPooky.IsInGroup(name)
    return BlockPooky.group[name]
end

---Checks if the player is currently in Cyrodiil (AvA zone)
---@return boolean true if in a PvP zone
function BlockPooky.IsInCyro()
    return GetMapContentType() == MAP_CONTENT_AVA
end

---Gets the cleaned ability name for a given ability ID
---@param id number the ability ID
---@return string the cleaned ability name
function BlockPooky.CleanAbilityName(id)
    return BlockPooky.CleanupName(GetAbilityName(id))
end

---Checks whether a lookup table maps the given key to true
---@param set table the lookup table
---@param element any the key to check
---@return boolean true if the key is present with value true
local function BlockPooky_IsIn(set, element)
    return set[element] == true
end

function BlockPooky.NotifyGroupMessagingIssue(key, message)
    if BlockPooky_groupNoticeShown[key] then
        return
    end
    BlockPooky_groupNoticeShown[key] = true
    if BlockPooky_chat then
        BlockPooky_chat:Print(BlockPooky.groupMessagingNotices.prefix .. ": " .. message)
    end
end

function BlockPooky.SendWarning(warningType, abilityId)
    if not BlockPooky_groupProtocol then
        BlockPooky.NotifyGroupMessagingIssue("noProtocol", BlockPooky.groupMessagingNotices.noProtocol)
        return false
    end

    if BlockPooky_groupProtocol.IsEnabled and not BlockPooky_groupProtocol:IsEnabled() then
        BlockPooky.NotifyGroupMessagingIssue("protocolDisabled", BlockPooky.groupMessagingNotices.protocolDisabled)
        return false
    end

    local success = BlockPooky_groupProtocol:Send({
        warningType = warningType or BlockPooky.groupMessagingNotices.defaultWarningType,
        abilityId = abilityId or 0,
    })
    if not success then
        BlockPooky.NotifyGroupMessagingIssue("sendFailed", BlockPooky.groupMessagingNotices.sendFailed)
    end
    return success
end

function BlockPooky.OnGroupPullWarning(unitTag, data)
    if not BlockPooky.config.groupMessaging then
        return
    end
    if GetGameTimeMilliseconds() - BlockPooky_lastPookyWarning > BlockPooky.config.cooldown then
        local abilityName
        if data and data.abilityId and data.abilityId > 0 then
            abilityName = BlockPooky.CleanAbilityName(data.abilityId)
        end
        if not abilityName or abilityName == "" then
            abilityName = (data and data.warningType and data.warningType ~= "") and data.warningType
                or BlockPooky.groupMessagingNotices.defaultWarningType
        end

        local sourceName = BlockPooky.groupMessagingNotices.defaultSourceName
        if unitTag then
            local senderName = GetUnitName(unitTag)
            if senderName and senderName ~= "" then
                sourceName = BlockPooky.CleanupName(senderName)
            end
        end

        BlockPooky_lastPookyWarning = GetGameTimeMilliseconds()
        BlockPooky.WarnThePooky(abilityName, sourceName)
    end
end

--[[ ui -------------------------------------------------------------------------------------------------------------]]


function BlockPooky.SetColor()
    if BlockPooky.config.color ~= nil then
        BlockPookyIndicatorLabel:SetColor(unpack(BlockPooky.config.color))
    end
end

function BlockPooky.SetBlockingColor()
    if BlockPooky.config.blocking.color ~= nil then
        BlockingPookyIndicatorLabel:SetColor(unpack(BlockPooky.config.blocking.color))
    end
end

---Update all UI frame text labels to match current config
function BlockPooky.UpdateUILabels()
    BlockPookyIndicatorLabel:SetText(BlockPooky.config.messages.blockWarning)
    BlockingPookyIndicatorLabel:SetText(BlockPooky.config.messages.blockingHint)
    VigorIndicatorLabel:SetText(BlockPooky.config.messages.vigorHint)
end

---intialize the UI frame thingy
function BlockPooky.InitUI()
    BlockPooky.RestorePosition()
    BlockPooky.setBlockPookyFont()
    BlockPooky.SetColor()
    BlockPooky.UpdateUILabels()
    EVENT_MANAGER:RegisterForUpdate(BlockPooky.name .. "TickUpdate", 1000, function(gameTimeMs)
        BlockPooky.UpdateBlock(gameTimeMs)
        BlockPooky.UpdateHoTDisplay()
    end, false)
    BlockPooky.SetUseBlocking()
    BlockPooky.CallbackManager = ZO_CallbackObject:New()
    BlockPookyIndicator:SetHidden(not BlockPooky.config.lockedUI)
    BlockingPookyIndicator:SetHidden(not BlockPooky.config.lockedUI)
    VigorIndicator:SetHidden(not BlockPooky.config.lockedUI)
    BlockPooky.SetBlockingColor()
    BlockPooky.SetVigorHintColor()
    BlockPooky.initCCBarUI()
    BlockPooky.initCCDebuffUI()
    BlockPooky.InitCooldownBarUIs()
end

---lock or unlock the UI frame
---@param locked boolean
function BlockPooky.SetUiLock(locked)
    BlockPooky.config.lockedUI = locked
    BlockPookyIndicator:SetHidden(not locked)
    BlockingPookyIndicator:SetHidden(not locked)
    VigorIndicator:SetHidden(not locked)
    if BlockPooky.hotBar then
        BlockPooky.hotBar:SetHidden(not locked)
    end
    if BlockPooky.ccBar then
        BlockPooky.ccBar:SetHidden(not locked)
    end
    if BlockPooky.ccDebuffBar then
        BlockPooky.ccDebuffBar:SetHidden(not locked)
    end
    if BlockPooky.mountLight then
        BlockPooky.mountLight:SetHidden(not locked)
    end
    BlockPooky.CooldownBarsSetHidden(not locked)
    if BlockPooky.negateWarning then
        BlockPooky.negateWarning:SetHidden(not locked)
    end
end

--[[ Implementations ------------------------------------------------------------------------------------------------]]

---update the blook pooky ui frame eith the block hint
---@param gameTimeMs number
function BlockPooky.UpdateBlock(gameTimeMs)
    local hideMessage = gameTimeMs - BlockPooky_lastPookyWarning > BlockPooky.config.cooldown
    if hideMessage then
        if BlockPooky.isActive then
            BlockPookyIndicator:SetHidden(true)
            BlockPooky.isActive = false
        end
    else
        if not BlockPooky.isActive then
            BlockPookyIndicator:SetHidden(false)
            BlockPooky.isActive = true
        end
    end
end

function BlockPooky.StopBlockPooky(gameTimeMs)
    if BlockPooky.isActive then
        BlockPookyIndicator:SetHidden(true)
        BlockPooky.isActive = false
        -- BlockPooky_lastPookyWarning = gameTimeMs
    end
end

function BlockPooky.OnIndicatorMoveStop()
    BlockPooky.config.left = BlockPookyIndicator:GetLeft()
    BlockPooky.config.top = BlockPookyIndicator:GetTop()
    --d("move saved " .. BlockPooky.config.left .. " : " ..  BlockPooky.config.top)
end

function BlockPooky.ResetBlockPosition()
    if BlockPookyIndicator:GetAnchor() ~= nil then
        BlockPookyIndicator:ClearAnchors()
    end
    BlockPookyIndicator:SetAnchor(BOTTOM, GuiRoot, CENTER, 0, -40)
    BlockPooky.OnIndicatorMoveStop()
end

function BlockPooky.ResetBlockingPosition()
    if BlockingPookyIndicator:GetAnchor() ~= nil then
        BlockingPookyIndicator:ClearAnchors()
    end
    BlockingPookyIndicator:SetAnchor(BOTTOM, GuiRoot, CENTER, 0, -80)
    BlockPooky.OnBlockingIndicatorMoveStop()
end

function BlockPooky.ResetPosition()
    BlockPooky.ResetBlockPosition()
    BlockPooky.ResetBlockingPosition()
    BlockPooky.ResetHintsPosition()
    BlockPooky.ResetCCBarPosition()
    BlockPooky.ResetCCDebuffPosition()
    BlockPooky.ResetCooldownBarsPosition()
    BlockPooky.ResetNegateWarningPosition()
    if BlockPooky.ResetHoTBarPosition then
        BlockPooky.ResetHoTBarPosition()
    end
end

function BlockPooky.RestorePosition()
    local left = BlockPooky.config.left
    local top = BlockPooky.config.top
    if (left ~= nil and top ~= nil and left > 0 and top > 0) then
        if BlockPookyIndicator:GetAnchor() ~= nil then
            BlockPookyIndicator:ClearAnchors()
        end
        BlockPookyIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        BlockPooky.ResetBlockPosition()
    end
    -- blocking
    left = BlockPooky.config.blocking.left
    top = BlockPooky.config.blocking.top
    if (left ~= nil and top ~= nil and left > 0 and top > 0) then
        if BlockingPookyIndicator:GetAnchor() ~= nil then
            BlockingPookyIndicator:ClearAnchors()
        end
        BlockingPookyIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        BlockPooky.ResetBlockingPosition()
    end
    -- others
    BlockPooky.RestoreHintsPosition()
    BlockPooky.RestoreCCBarPosition()
    BlockPooky.RestoreCCDebuffPosition()
    BlockPooky.RestoreCooldownBarsPosition()
    BlockPooky.RestoreNegateWarningPosition()
    if BlockPooky.LoadHoTBarPosition then
        BlockPooky.LoadHoTBarPosition()
    end
end

function BlockPooky.setBlockPookyFont()
    local font = CreateFont("BlockPookyFont")
    font:SetFont("$(BOLD_FONT)|" .. BlockPooky.config.fontSize .. "|soft-shadow-thin")
    local bigfont = CreateFont("BlockPookyBigFont")
    bigfont:SetFont("$(BOLD_FONT)|" .. BlockPooky.config.bigFontSize .. "|soft-shadow-thin")
end

function BlockPooky.Test()
    if GetGameTimeMilliseconds() - BlockPooky_lastPookyWarning > BlockPooky.config.cooldown then
        BlockPooky_lastPookyWarning = GetGameTimeMilliseconds()
        BlockPooky.WarnThePooky("TEST", "ME")
    end
    if BlockPooky.IsInGroup and BlockPooky.config.groupMessaging then
        BlockPooky.SendWarning("pull", 0)
    end
end

--[[ addon initialization -------------------------------------------------------------------------------------------]]

---load the group members if grouped
---the casts of the loaded group member will be ignored then
function BlockPooky.LoadGroupMembers()
    BlockPooky.grouped = IsUnitGrouped("player")
    BlockPooky.group = {}
    if BlockPooky.grouped then
        for i = 1, GROUP_SIZE_MAX do
            local groupMemberTag = GetGroupUnitTagByIndex(i)
            if groupMemberTag then
                local groupMemberName = GetUnitName(groupMemberTag)
                if groupMemberName then
                    BlockPooky.group[groupMemberName] = true
                end
            end
        end
    end
    BlockPooky.UpdateMountPollRegistration()
end

---Rebuilds the trigger lookups from config. Called on load and on every menu change so
---edits apply immediately (no /reloadui needed).
---Names stay the key for effect-based detection, but ability IDs are matched as well:
---morph/rank differences or a localized effect name that differs from GetAbilityName()
---can otherwise never match. The ID set also drives damage-based detection.
function BlockPooky.RebuildTriggerAbilities()
    local customIds = BlockPooky.config.customAbilityIds or {}
    local enabledTriggers = BlockPooky.config.triggerAbilities or {}

    BlockPooky.CustomTriggerAbilities = {}
    for idx = #customIds, 1, -1 do
        local customName = BlockPooky.CleanAbilityName(customIds[idx])
        if customName ~= "" then
            BlockPooky.CustomTriggerAbilities[customName] = true
        end
    end

    BlockPooky.TriggerAbilityIds = {}
    for idx = #BlockPooky.predefinedTriggerAbilities, 1, -1 do
        local id = BlockPooky.predefinedTriggerAbilities[idx]
        if BlockPooky_IsIn(enabledTriggers, BlockPooky.CleanAbilityName(id)) then
            BlockPooky.TriggerAbilityIds[id] = true
        end
    end
    for idx = #customIds, 1, -1 do
        BlockPooky.TriggerAbilityIds[customIds[idx]] = true
    end
end

function BlockPooky.InitGroupMessaging()
    if BlockPooky_grpMsgActive then
        return
    end
    if not BlockPooky_LGB then
        BlockPooky.NotifyGroupMessagingIssue("missingLGB", BlockPooky.groupMessagingNotices.missingLGB)
        return
    end

    if not BlockPooky_groupHandler then
        BlockPooky_groupHandler = BlockPooky_LGB:RegisterHandler(BlockPooky.name)
    end
    if not BlockPooky_groupHandler then
        BlockPooky.NotifyGroupMessagingIssue("handlerRegisterFailed",
            BlockPooky.groupMessagingNotices.handlerRegisterFailed)
        return
    end

    if not BlockPooky_groupProtocol then
        local protocol = BlockPooky_groupHandler:DeclareProtocol(
            BlockPooky_groupProtocolId,
            BlockPooky_groupProtocolName
        )
        -- Payload stays tiny: a 1-bit warning type + a 21-bit ability ID. The
        -- receiver derives the localized ability name from the ID and the source
        -- from the sender's unit tag, so no strings ever cross the wire.
        protocol:AddField(BlockPooky_LGB.CreateEnumField("warningType", { "pull", "generic" }))
        protocol:AddField(BlockPooky_LGB.CreateNumericField("abilityId", {
            defaultValue = 0,
            minValue = 0,
            maxValue = 2000000,
        }))
        protocol:OnData(function(unitTag, data)
            BlockPooky.OnGroupPullWarning(unitTag, data)
        end)
        if protocol:Finalize({
                isRelevantInCombat = true,
                replaceQueuedMessages = false,
            }) then
            BlockPooky_groupProtocol = protocol
        else
            BlockPooky.NotifyGroupMessagingIssue("protocolFinalizeFailed",
                BlockPooky.groupMessagingNotices.protocolFinalizeFailed)
        end
    end

    BlockPooky_grpMsgActive = BlockPooky_groupProtocol ~= nil
    if BlockPooky_grpMsgActive and BlockPooky_groupProtocol and BlockPooky_groupProtocol.IsEnabled and not BlockPooky_groupProtocol:IsEnabled() then
        BlockPooky.NotifyGroupMessagingIssue("protocolDisabled", BlockPooky.groupMessagingNotices.protocolDisabled)
    end
end

function BlockPooky.StopGroupMessaging()
    if not BlockPooky_grpMsgActive then
        return
    end
    BlockPooky_grpMsgActive = false
end

---EVENT_COMBAT_EVENT adapter for the damage-based trigger registrations
---@param eventCode number
---@param result number
---@param isError boolean
---@param abilityName string
---@param abilityGraphic number
---@param abilityActionSlotType number
---@param sourceName string
---@param sourceType number
---@param targetName string
---@param targetType number
---@param hitValue number
---@param powerType number
---@param damageType number
---@param combatLog boolean
---@param sourceUnitId number
---@param targetUnitId number
---@param abilityId number
local function BlockPooky_OnTriggerDamageEvent(
    eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType,
    combatLog, sourceUnitId, targetUnitId, abilityId
)
    BlockPooky.OnTriggerDamage(abilityName, sourceName, abilityId)
end

--- main addon initialization
function BlockPooky.Initialize()
    BlockPooky.player = BlockPooky.CleanupName(GetUnitName("player")):lower()
    BlockPooky.dcAbilityName = BlockPooky.CleanupName(GetAbilityName(159385))
    BlockPooky.roaAbilityName = BlockPooky.CleanupName(GetAbilityName(159279))
    BlockPooky.companionName = GetUnitName("companion"):lower()
    BlockPooky.LoadGroupMembers()
    BlockPooky.InitUI()
    BlockPooky.InitAddonMenu()
    BlockPooky.RebuildTriggerAbilities()
    if BlockPooky.config.groupMessaging then
        BlockPooky.InitGroupMessaging()
    end

    -- Apply combat visuals if enabled
    if BlockPooky.config.combatVisualsEnabled then
        BlockPooky.SetMaxAOEBrightness(BlockPooky.config.MaxAOEBrightness or 500)
        BlockPooky.SetMaxOutlineThickness(BlockPooky.config.MaxOutlineThickness or 2000)
        BlockPooky.SetMaxTargetOutlineIntensity(BlockPooky.config.MaxTargetOutlineIntensity or 2000)
    end
    -- Apply AOERGB if enabled
    if BlockPooky.config.AOERGBEnabled then
        if BlockPooky.SetAOERGBState then
            BlockPooky.SetAOERGBState(true, true)
        end
        if BlockPooky.config.AOERGBDefaultColor and SetSetting then
            SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_MONSTER_TELLS_ENEMY_COLOR,
                BlockPooky.config.AOERGBDefaultColor)
        end
        -- Speed and turbo are handled by SetAOERGBState if needed
    end

    -- [[register combat event]]
    EVENT_MANAGER:RegisterForEvent(BlockPooky.name, EVENT_COMBAT_EVENT, function(...) BlockPooky.OnCombat(...) end)
    -- Filter combat events at C level for performance: only ACTION_RESULT_EFFECT_GAINED, exclude errors
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT,
        ACTION_RESULT_EFFECT_GAINED)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)

    -- [[register damage-based trigger detection]]
    -- Damage results are separate registrations because ESO ANDs multiple result filters.
    -- The player-target filter keeps this free outside of hits that actually land on us.
    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "TriggerDamage", EVENT_COMBAT_EVENT,
        BlockPooky_OnTriggerDamageEvent)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamage", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamage", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamage", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false)

    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "TriggerDamageCrit", EVENT_COMBAT_EVENT,
        BlockPooky_OnTriggerDamageEvent)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamageCrit", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamageCrit", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_CRITICAL_DAMAGE)
    EVENT_MANAGER:AddFilterForEvent(BlockPooky.name .. "TriggerDamageCrit", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false)

    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "GroupUpdate", EVENT_GROUP_UPDATE,
        function(...) BlockPooky.OnGroupUpdate(...) end)
    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "CombatNotification", EVENT_PLAYER_COMBAT_STATE,
        function(...) BlockPooky.OnCombatNotification(...) end)
    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "CompanionActivated", EVENT_COMPANION_ACTIVATED,
        function() BlockPooky.companionName = GetUnitName("companion") end)
    EVENT_MANAGER:RegisterForEvent(BlockPooky.name .. "CompanionDeactivated", EVENT_COMPANION_DEACTIVATED,
        function() BlockPooky.companionName = "" end)
    if BlockPooky.config.CCImmunityHint then
        -- Single source of truth: CCEventRegisterUpdate() registers/unregisters ALL CC
        -- immunity events (effect watcher + potion consumption). Previously this block
        -- re-registered "CCWatcher" and "InventoryUpdate" a second time, which double-fired
        -- OnSlotUpdate for backpack changes and left a stale registration after disabling.
        BlockPooky.CCEventRegisterUpdate()
    end
    if BlockPooky.config.showCCDebuff then
        BlockPooky.CCDebuffEventRegisterUpdate()
    end
    BlockPooky.InitCooldownBarEvents()
    BlockPooky.InitNegateWarning()
    BlockPooky.InitThreatAlert()
    BlockPooky.SetThreatAlertTexture()
    BlockPooky.InitStaminaLow()
    BlockPooky.SetStaminaLowTexture()
    BlockPooky.InitHoTBarUI()
    BlockPooky.InitHoTTracker()
    BlockPooky.InitMountLightUI()
    -- DC/ROA/Vigor hints have their own self-registered events; sync them to the toggles.
    BlockPooky.HintsEventRegisterUpdate()
    -- Synchronize ALL UI elements (including bars) to the saved lock state.
    -- Without this, only the text indicators are shown on load while bars like the
    -- HoT counter stay hidden even though the UI is in repositioning (lock) mode.
    BlockPooky.SetUiLock(BlockPooky.config.lockedUI)
    --
    SLASH_COMMANDS["/blockpookytest"] = BlockPooky.Test
    SLASH_COMMANDS["/blockpookytestimmo"] = function() BlockPooky.TriggerPotionImmunity() end
    SLASH_COMMANDS["/blockpookytestcc"] = function() BlockPooky.TestCCDebuff() end
    SLASH_COMMANDS["/blockpookyccdebug"] = function() BlockPooky.ToggleCCDebuffDebug() end
end

--[[ ui interaction -------------------------------------------------------------------------------------------------]]

---show a CSA Message to the Pooky
---@param message string
function BlockPooky.MessageThePooky(message)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
    params:SetCSAType(CSA_CATEGORY_LARGE_TEXT)
    params:SetText(message or BlockPooky.config.messages.blockWarning)
    params:SetLifespanMS(BlockPooky.config.msgLifeSpan)
    params:SetPriority(1)
    params:MarkShowImmediately()
    CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
end

--[[ user interaction -----------------------------------------------------------------------------------------------]]

---warn the Pooky as configured
---@param abilityName string
function BlockPooky.WarnThePooky(abilityName, sourceName)
    -- ui frame
    if BlockPooky.config.useFrame then
        BlockPooky.UpdateBlock(BlockPooky_lastPookyWarning)
    end
    -- screen warning
    if BlockPooky.config.useCSA then
        BlockPooky.MessageThePooky(BlockPooky.config.messages.blockWarning)
    end
    -- play sound
    if BlockPooky.config.playSound then
        PlaySound(SOUNDS.DUEL_START)
    end
    -- chat warning
    if BlockPooky.config.chatWarn then
        BlockPooky_chat:Print(BlockPooky.groupMessagingNotices.incomingWarningPrefix ..
            abilityName .. BlockPooky.groupMessagingNotices.incomingWarningSuffix .. sourceName)
    end
end

--[[ event handling -------------------------------------------------------------------------------------------------]]

---OnAddonLoaded Event Handler
---@param event any
---@param addonName string
function BlockPooky.OnAddOnLoaded(event, addonName)
    if addonName == BlockPooky.name then
        EVENT_MANAGER:UnregisterForEvent(BlockPooky.name, EVENT_ADD_ON_LOADED)
        local defaultConfig = {
            lockedUI = false,
            useCSA = true,
            playSound = true,
            useFrame = true,
            chatWarn = true,
            left = 0,
            top = 0,
            cooldown = 5000,
            color = { 0.627, 0.129, 0.157, 1.0 },
            grpmsg_cooldown = 2000,
            msgLifeSpan = 1000,
            dcHint = false,
            roaHint = false,
            vigorHint = false,
            triggerAbilities = {},
            customAbilityIds = {},
            fontSize = 45,
            bigFontSize = 80,
            blocking = {
                left = 0,
                top = 0,
                show = true,
                color = { 0.980, 0.655, 0.0, 1.0 }
            },
            vigorUI = {
                left = 0,
                top = 0,
                cooldown = 4000,
                color = { 0.0, 0.533, 1.0, 1.0 }
            },
            groupMessaging = true,
            ccBarPosition = {
                left = 0,
                top = 0
            },
            ccBarColor = { 0, 1, 0, 1 },
            ccBarSoftColor = { 0, 0.75, 1, 1 },
            CCImmunityHint = true,
            showCCDebuff = true,
            ccDebuffCSA = true,
            ccDebuffPosition = {
                left = 0,
                top = 0
            },
            ccDebuffColors = {
                stun      = { 0.894, 0.133, 0.090, 1 },
                fear      = { 0.561, 0.035, 0.925, 1 },
                disorient = { 0.031, 0.627, 1.0, 1 },
                silence   = { 0.0, 1.0, 1.0, 1 },
                stagger   = { 1.0, 0.949, 0.129, 1 },
            },
            msgPullAbilitiesOnly = true,
            pullAbilities = {},
            cooldownbar = {},
            investigate = false,
            investigateEffects = false,
            investigateDamage = false,
            negate = {
                show = false,
                left = 0,
                top = 0,
                color = { 1, 0, 0, 1 }
            },
            threatalert = {
                show = false,
                pvpOnly = true,
                texture = "reddot.dds",
                alpha = 0.3,
                color = { 1, 0, 0, 0.12 },
                duration = 8000,
                cooldown = 5000,
                abilities = { 159385, 159279 }, -- Dark Convergence, Rush of Agony (user can remove these)
                customAbilities = {},
                showLabel = true,               -- show ability name / custom text on the overlay
                labels = {}                     -- per-ability custom text: labels[abilityId] = "custom text"
            },
            staminalow = {
                show = false,
                threshold = 5000,
                minAlpha = 0.3,
                maxAlpha = 0.72,
                texture = "staminawarn.dds"
            },
            -- Combat Visuals defaults
            combatVisualsEnabled = false,
            MaxAOEBrightness = 500,
            MaxOutlineThickness = 2000,
            MaxTargetOutlineIntensity = 2000,
            -- RGB AOE Visuals defaults
            AOERGBEnabled = false,
            AOERGBDefaultColor = "ff0000",
            AOERGBSpeed = 50,
            AOERGBTurbo = 1,
            -- Customizable Messages
            messages = {
                blockWarning = "BLOCK Pooky!",
                blockingHint = "Pooky BLOCKING!",
                vigorHint = "VIGOR!",
                dcReady = "DC Ready!",
                roaReady = "ROA Ready!",
                mountReady = "Pooky you can MOUNT!",
                ccImmunity = "CC Immunity",
                ccStun = "STUNNED!",
                ccFear = "FEARED!",
                ccDisorient = "DISORIENTED!",
                negateWarning = "MOVE Pooky! You're in a Negate!",
                allMounted = "All Pookies Mounted!",
                allCanMount = "All Pookies can Mount!",
                pookyUnmounted = "Pooky unmounted!"
            },
            -- HoT Tracking defaults
            showHoTCounter = false,
            hotBarPosition = {
                left = 0,
                top = 0
            },
            -- Group Mount Notifications defaults
            groupMountNotify = false,
            -- Mount Traffic Light defaults
            showMountLight = false,
            mountLightPosition = {
                left = 0,
                top = 0
            }
        }
        for idx = #BlockPooky.predefinedTriggerAbilities, 1, -1 do
            -- d(\"this: \" .. BlockPooky.CleanAbilityName(BlockPooky.predefinedTriggerAbilities[idx]))
            defaultConfig.triggerAbilities[BlockPooky.CleanAbilityName(BlockPooky.predefinedTriggerAbilities[idx])] = true
        end
        for idx = #BlockPooky.predefinedPullAbilities, 1, -1 do
            defaultConfig.pullAbilities[BlockPooky.CleanAbilityName(BlockPooky.predefinedPullAbilities[idx])] = true
        end
        local defaultToonConfig = {
            cooldownbar = {}
        }

        BlockPooky.toonConfig = ZO_SavedVars:New(BlockPooky.name .. "Config", BlockPooky.svVersion, "config",
            defaultToonConfig)
        BlockPooky.config = ZO_SavedVars:NewAccountWide(BlockPooky.name .. "Config", BlockPooky.svVersion, "config",
            defaultConfig)
        BlockPooky.Initialize()
    end
end

---COMBAT EVENT Handler
---@param eventCode any
---@param result any
---@param isError any
---@param abilityName any
---@param abilityGraphic any
---@param abilityActionSlotType any
---@param sourceName any
---@param sourceType any
---@param targetName any
---@param targetType any
---@param hitValue any
---@param powerType any
---@param damageType any
---@param combat_log any
---@param sourceUnitId any
---@param targetUnitId any
---@param abilityId any
function BlockPooky.OnCombat(
    eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType,
    combat_log, sourceUnitId, targetUnitId, abilityId
)
    --[[ Warn the Pooky to block!
        Note: Event is pre-filtered to ACTION_RESULT_EFFECT_GAINED and non-errors at C level via AddFilterForEvent.
        Note: DC/ROA/Vigor cast tracking does NOT live here anymore - those hints have
        their own dedicated EVENT_COMBAT_EVENT handlers in BlockPooky_hints.lua
        (registered only while the respective hint toggle is on).

        (1) check if it is one of the "pull abilities"
        (2) check source is not the player himself
        (3) check source is not a known group member
        (4) use a message cooldown
        (5) Warn the Pooky to BLOCK!
        (6) send group warnings to grouped players

    --]]
    -- (1)
    local cleanAbilityName = BlockPooky.CleanupName(abilityName)
    local cleanSourceName = BlockPooky.CleanupName(sourceName):lower()
    if BlockPooky.config.investigate and cleanSourceName ~= '' then
        d(string.format("Ability? Name: %s | ID: %d | Source: %s", cleanAbilityName, abilityId, cleanSourceName))
    end
    -- (1) name match for effect names, ID match for morph/rank and localized-name differences
    local isTriggerAbility = BlockPooky_IsIn(BlockPooky.config.triggerAbilities, cleanAbilityName)
        or BlockPooky_IsIn(BlockPooky.CustomTriggerAbilities, cleanAbilityName)
        or BlockPooky_IsIn(BlockPooky.TriggerAbilityIds, abilityId)
    if isTriggerAbility then
        -- (2)
        if (cleanSourceName ~= "" and cleanSourceName ~= BlockPooky.player and cleanSourceName ~= BlockPooky.companionName) then
            -- (3)
            if BlockPooky.grouped == false or BlockPooky.group[cleanSourceName] ~= true then
                -- (4)
                if GetGameTimeMilliseconds() - BlockPooky_lastPookyWarning > BlockPooky.config.cooldown then
                    BlockPooky_lastPookyWarning = GetGameTimeMilliseconds()
                    -- (5)
                    BlockPooky.WarnThePooky(cleanAbilityName, cleanSourceName)
                end
            end
            if BlockPooky.grouped then
                local cleanTargetName = BlockPooky.CleanupName(targetName)
                if BlockPooky.IsInGroup(cleanTargetName) and cleanTargetName ~= BlockPooky.player then
                    if GetGameTimeMilliseconds() - BlockPooky_lastGroupMessage > BlockPooky.config.grpmsg_cooldown then
                        BlockPooky_chat:Print("Pooky " .. cleanTargetName .. " hit by (" .. cleanAbilityName .. ")")
                    end
                end
                if BlockPooky.config.groupMessaging and cleanTargetName == BlockPooky.player then
                    if BlockPooky.config.msgPullAbilitiesOnly == false or BlockPooky_IsIn(BlockPooky.config.pullAbilities, cleanAbilityName) then
                        BlockPooky.SendWarning("pull", abilityId)
                    end
                end
            end
        end
    end
end

---Warns when a configured trigger deals damage to the player.
---Gap closers (Critical Rush, Critical Charge, Stampede, ...) never raise
---ACTION_RESULT_EFFECT_GAINED, so OnCombat can never see them. This handler is registered
---twice with C-level filters for player-target damage; ESO has no "enemy cast started"
---event for other players, so the warning fires when the hit lands, not before it.
---@param abilityName string
---@param sourceName string
---@param abilityId number
function BlockPooky.OnTriggerDamage(abilityName, sourceName, abilityId)
    local cleanAbilityName = BlockPooky.CleanupName(abilityName)
    local cleanSourceName = BlockPooky.CleanupName(sourceName):lower()
    if BlockPooky.config.investigateDamage then
        d(string.format("Damage? Name: %s | ID: %d | Source: %s", cleanAbilityName, abilityId, cleanSourceName))
    end
    if not BlockPooky_IsIn(BlockPooky.TriggerAbilityIds, abilityId) then
        return
    end
    if cleanSourceName == "" or cleanSourceName == BlockPooky.player or cleanSourceName == BlockPooky.companionName then
        return
    end
    if BlockPooky.grouped and BlockPooky.group[cleanSourceName] == true then
        return
    end
    if GetGameTimeMilliseconds() - BlockPooky_lastPookyWarning <= BlockPooky.config.cooldown then
        return
    end
    BlockPooky_lastPookyWarning = GetGameTimeMilliseconds()
    BlockPooky.WarnThePooky(cleanAbilityName, cleanSourceName)
end

---reload group members when group is updated
function BlockPooky.OnGroupUpdate()
    BlockPooky.LoadGroupMembers()
end

function BlockPooky.OnCombatNotification(eventCode, inCombat)
    if BlockPooky.grouped and not inCombat and not IsMounted() and BlockPooky.IsInCyro() then
        BlockPooky.MessageThePooky(BlockPooky.config.messages.mountReady)
        BlockPooky.lastMountReady = GetGameTimeMilliseconds()
    end
end

--[[ group mount notifications ---------------------------------------------------------------------------------------]]
---Group-wide mount status messages shown while the player is in a group.
---Uses the same lightweight polling approach as dedicated group-mount addons:
---ESO has no event for OTHER players' mount state, so we poll it on a timer.
---To keep this cheap, the poll is only registered while grouped (it powers both
---the group-wide messages and the personal "can mount" reminder), and only
---iterates the actual group size (not all 24 slots).

---Whether the mount poll update is currently registered
BlockPooky.mountPollRegistered = false
---Last known mount state per group member: [characterName] = mounted (boolean)
BlockPooky.mountStates = {}
---Edge-detection arms so "all mounted" / "all can mount" fire only on transitions
BlockPooky.allMountedArmed = false
BlockPooky.allCanMountArmed = false
---Edge-detection arm for the player's own "can mount" reminder (group mode)
BlockPooky.playerCanMountArmed = false
---Last time "Pooky you can MOUNT!" was shown (prevents double-firing with OnCombatNotification)
BlockPooky.lastMountReady = 0

---Register/unregister the group mount poll based on group state.
---The poll only runs while the player is grouped (the group-wide messages are
---additionally gated by config.groupMountNotify), so it costs nothing when solo.
function BlockPooky.UpdateMountPollRegistration()
    -- The poll runs whenever the player is grouped: it powers both the group-wide
    -- messages (gated by config.groupMountNotify) and the personal "Pooky you can
    -- MOUNT!" reminder. It costs nothing when solo.
    local wantPoll = BlockPooky.grouped and BlockPooky.config ~= nil
    if wantPoll and not BlockPooky.mountPollRegistered then
        EVENT_MANAGER:RegisterForUpdate(BlockPooky.name .. "MountPoll", 500,
            function() BlockPooky.CheckGroupMountStates() end, false)
        BlockPooky.mountPollRegistered = true
    elseif not wantPoll and BlockPooky.mountPollRegistered then
        EVENT_MANAGER:UnregisterForUpdate(BlockPooky.name .. "MountPoll")
        BlockPooky.mountPollRegistered = false
        BlockPooky.mountStates = {}
        BlockPooky.allMountedArmed = false
        BlockPooky.allCanMountArmed = false
        BlockPooky.playerCanMountArmed = false
        BlockPooky.SetMountLightState(BlockPooky.MOUNT_LIGHT_OFF)
    end
end

---Poll group members' mount states and fire the group mount notifications.
---Fires (only while grouped):
---  allMounted     when every online same-zone group member is mounted
---  allCanMount    when every online same-zone group member is off mount and out of combat
---  pookyUnmounted when a group member (not the player) dismounts
function BlockPooky.CheckGroupMountStates()
    if not BlockPooky.grouped then return end
    if not BlockPooky.config then return end

    -- Personal "Pooky you can MOUNT!" reminder for group mode. OnCombatNotification
    -- already shows it right after leaving combat; this covers the "standing around
    -- grouped" case. Edge-triggered plus a short cooldown avoids spam/double-firing.
    local playerCanMount = not IsMounted() and not IsUnitInCombat("player")
    if playerCanMount and BlockPooky.IsInCyro() then
        if BlockPooky.playerCanMountArmed
            and GetGameTimeMilliseconds() - BlockPooky.lastMountReady > 1500 then
            BlockPooky.MessageThePooky(BlockPooky.config.messages.mountReady)
            BlockPooky.lastMountReady = GetGameTimeMilliseconds()
        end
        BlockPooky.playerCanMountArmed = false
    else
        BlockPooky.playerCanMountArmed = true
    end

    local groupSize = GetGroupSize()

    local myZone = GetUnitZoneIndex("player")
    local myName = GetUnitName("player")

    local mountedCount = 0
    local activeMembers = 0
    local allMounted = true
    local allCanMount = true

    for i = 1, groupSize do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and DoesUnitExist(unitTag) then
            local unitName = GetUnitName(unitTag)
            -- Only consider members that are online and in the same zone
            if IsUnitOnline(unitTag) and GetUnitZoneIndex(unitTag) == myZone then
                local mountedState = GetTargetMountedStateInfo(unitName)
                local mounted = mountedState ~= nil and mountedState ~= MOUNTED_STATE_NOT_MOUNTED
                local isMe = (unitName == myName)
                local wasMounted = BlockPooky.mountStates[unitName]

                activeMembers = activeMembers + 1
                if mounted then
                    mountedCount = mountedCount + 1
                else
                    -- A group member (not the player) just dismounted
                    if not isMe and wasMounted == true
                        and BlockPooky.config.messages.pookyUnmounted
                        and BlockPooky.config.messages.pookyUnmounted ~= "" then
                        BlockPooky.MessageThePooky(BlockPooky.config.messages.pookyUnmounted)
                    end
                end
                allMounted = allMounted and mounted
                allCanMount = allCanMount and not mounted and not IsUnitInCombat(unitTag)
                BlockPooky.mountStates[unitName] = mounted
            else
                -- Offline or in another zone: not part of "all Pookies". Forget their
                -- state so they can't trigger a false "unmounted" when they reappear.
                BlockPooky.mountStates[unitName] = nil
            end
        end
    end

    -- Optional mount traffic light: green = all mounted, yellow = all can mount,
    -- red = at least one Pooky unmounted (someone can't mount right now / mixed)
    if activeMembers > 1 then
        if allMounted and mountedCount == activeMembers then
            BlockPooky.SetMountLightState(BlockPooky.MOUNT_LIGHT_GREEN)
        elseif allCanMount then
            BlockPooky.SetMountLightState(BlockPooky.MOUNT_LIGHT_YELLOW)
        else
            BlockPooky.SetMountLightState(BlockPooky.MOUNT_LIGHT_RED)
        end
    else
        BlockPooky.SetMountLightState(BlockPooky.MOUNT_LIGHT_OFF)
    end

    -- Group-wide messages only while enabled
    if not BlockPooky.config.groupMountNotify then return end
    if groupSize <= 1 then return end -- no "all Pookies" with just yourself

    -- "All Pookies Mounted" fires on the transition into all-mounted
    if activeMembers > 1 and allMounted and mountedCount == activeMembers then
        if BlockPooky.allMountedArmed
            and BlockPooky.config.messages.allMounted
            and BlockPooky.config.messages.allMounted ~= "" then
            BlockPooky.MessageThePooky(BlockPooky.config.messages.allMounted)
            BlockPooky.allMountedArmed = false
        end
    else
        BlockPooky.allMountedArmed = true
    end

    -- "All Pookies can Mount" fires on the transition into everyone-can-mount
    if activeMembers > 1 and allCanMount then
        if BlockPooky.allCanMountArmed
            and BlockPooky.config.messages.allCanMount
            and BlockPooky.config.messages.allCanMount ~= "" then
            BlockPooky.MessageThePooky(BlockPooky.config.messages.allCanMount)
            BlockPooky.allCanMountArmed = false
        end
    else
        BlockPooky.allCanMountArmed = true
    end
end

--[[ mount traffic light ---------------------------------------------------------------------------------------------]]
---Optional single "traffic light" shown while grouped: one colored square that
---reflects the group mount readiness. Piggybacks on the existing mount poll, so
---it adds no extra timer.

---Traffic light states (only one light is shown at a time)
BlockPooky.MOUNT_LIGHT_OFF = 0
BlockPooky.MOUNT_LIGHT_GREEN = 1
BlockPooky.MOUNT_LIGHT_YELLOW = 2
BlockPooky.MOUNT_LIGHT_RED = 3

---Create the optional mount traffic light (a single colored square)
function BlockPooky.InitMountLightUI()
    if not BlockPooky.mountLight then
        BlockPooky.mountLight = CreateControl(BlockPooky.name .. "MountLight", GuiRoot, CT_TOPLEVELCONTROL)
        if not BlockPooky.mountLight then return end
        BlockPooky.mountLight:SetDimensions(22, 22)
        BlockPooky.mountLight:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
        BlockPooky.mountLight:SetHidden(true)
        BlockPooky.mountLight:SetMovable(true)
        BlockPooky.mountLight:SetMouseEnabled(true)
        BlockPooky.mountLight:SetHandler("OnMoveStop", function()
            BlockPooky.SaveMountLightPosition()
        end)
    end

    if not BlockPooky.mountLightBackdrop then
        BlockPooky.mountLightBackdrop = CreateControl(BlockPooky.name .. "MountLightBackdrop", BlockPooky.mountLight,
            CT_BACKDROP)
        if not BlockPooky.mountLightBackdrop then return end
        BlockPooky.mountLightBackdrop:SetAnchorFill(BlockPooky.mountLight)
        BlockPooky.mountLightBackdrop:SetEdgeColor(0, 0, 0, 0.8)
        BlockPooky.mountLightBackdrop:SetCenterColor(0.4, 0.4, 0.4, 0.9)
    end

    BlockPooky.LoadMountLightPosition()
end

function BlockPooky.SaveMountLightPosition()
    if BlockPooky.config and BlockPooky.mountLight then
        local left, top = BlockPooky.mountLight:GetLeft(), BlockPooky.mountLight:GetTop()
        BlockPooky.config.mountLightPosition = { left = left, top = top }
    end
end

function BlockPooky.LoadMountLightPosition()
    if not BlockPooky.mountLight then return end
    if BlockPooky.mountLight:GetAnchor() ~= nil then
        BlockPooky.mountLight:ClearAnchors()
    end
    if BlockPooky.config and BlockPooky.config.mountLightPosition then
        BlockPooky.mountLight:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, BlockPooky.config.mountLightPosition.left,
            BlockPooky.config.mountLightPosition.top)
    else
        BlockPooky.mountLight:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
    end
end

function BlockPooky.ResetMountLightPosition()
    if BlockPooky.mountLight then
        if BlockPooky.mountLight:GetAnchor() ~= nil then
            BlockPooky.mountLight:ClearAnchors()
        end
        BlockPooky.mountLight:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
        BlockPooky.SaveMountLightPosition()
    end
end

---Set the mount traffic light color (only one light is shown at a time).
---@param state number one of BlockPooky.MOUNT_LIGHT_*
function BlockPooky.SetMountLightState(state)
    if not BlockPooky.mountLight or not BlockPooky.mountLightBackdrop then return end

    -- While repositioning, keep the light visible (grey) so it can be moved
    if BlockPooky.config and BlockPooky.config.lockedUI then
        BlockPooky.mountLightBackdrop:SetCenterColor(0.5, 0.5, 0.5, 0.9)
        BlockPooky.mountLight:SetHidden(false)
        return
    end

    if not BlockPooky.config or not BlockPooky.config.showMountLight then
        BlockPooky.mountLight:SetHidden(true)
        return
    end

    local r, g, b
    if state == BlockPooky.MOUNT_LIGHT_GREEN then
        r, g, b = 0.2, 1.0, 0.2
    elseif state == BlockPooky.MOUNT_LIGHT_YELLOW then
        r, g, b = 1.0, 1.0, 0.2
    elseif state == BlockPooky.MOUNT_LIGHT_RED then
        r, g, b = 1.0, 0.25, 0.25
    else
        BlockPooky.mountLight:SetHidden(true)
        return
    end

    BlockPooky.mountLightBackdrop:SetCenterColor(r, g, b, 0.95)
    BlockPooky.mountLight:SetHidden(false)
end

--[[ MAIN -----------------------------------------------------------------------------------------------------------]]

EVENT_MANAGER:RegisterForEvent(BlockPooky.name, EVENT_ADD_ON_LOADED, function(...) BlockPooky.OnAddOnLoaded(...) end)

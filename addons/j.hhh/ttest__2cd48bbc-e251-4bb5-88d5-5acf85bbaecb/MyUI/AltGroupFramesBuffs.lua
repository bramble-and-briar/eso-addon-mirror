--[[
Alternative Group Frames Buff Tracker - Console adaptation
Version 1.4.1

Tracks selected active buffs beside Alternative Group Frames. All buff toggles
are disabled by default. Timers show whole seconds and stacks appear in the
bottom-right corner. Icons inherit the main group-frame scale.

Based on the buff list and behavior of the upstream Alternative Group Frames
Buff Tracker by BulDeZir and Glande-Pas.
]]

local NAME = "AltGroupFramesBuffs"
local PANEL_ID = "ALTGF_BuffTrackerSettings"
local UPDATE_NAME = NAME .. "Update"
local ICON_SIZE = 40
local ICON_GAP = 3
local ICON_BORDER = 2
local PERIODIC_RESCAN_MS = 1000
local TIMER_UPDATE_MS = 200

local PILLAGER_ACTIVE_ID = 172055
local PILLAGER_COOLDOWN_ID = 172056
local PILLAGER_COOLDOWN_SECONDS = 45

local TRACKED_BUFFS = {
    { id = 61744, fallbackName = "Minor Berserk", category = "Offensive and group buffs" },
    { id = 61745, fallbackName = "Major Berserk", category = "Offensive and group buffs" },
    { id = 147417, fallbackName = "Minor Courage", category = "Offensive and group buffs", allowInvalidDuration = true },
    { id = 109966, fallbackName = "Major Courage", category = "Offensive and group buffs" },
    { id = 93109, fallbackName = "Major Slayer", category = "Offensive and group buffs" },
    { id = 61747, fallbackName = "Major Force", category = "Offensive and group buffs" },
    { id = 61771, fallbackName = "Powerful Assault", category = "Offensive and group buffs" },
    { id = 40224, fallbackName = "War Horn", category = "Offensive and group buffs" },
    { id = 38564, fallbackName = "Aggressive Horn", category = "Offensive and group buffs" },
    { id = 40221, fallbackName = "Sturdy Horn", category = "Offensive and group buffs" },
    { id = PILLAGER_ACTIVE_ID, fallbackName = "Pillager's Profit", category = "Offensive and group buffs" },
    { id = 263873, fallbackName = "Ability 263873", category = "Offensive and group buffs" },
    { id = 263672, fallbackName = "Ability 263672", category = "Offensive and group buffs" },

    {
        id = PILLAGER_COOLDOWN_ID,
        fallbackName = "Pillager's Profit Cooldown",
        category = "Cooldowns",
        tracking = "combat",
        duration = PILLAGER_COOLDOWN_SECONDS,
        iconAbilityId = PILLAGER_ACTIVE_ID,
        useFallbackName = true,
    },

    { id = 61693, fallbackName = "Minor Resolve", category = "Defensive and utility buffs" },
    { id = 61694, fallbackName = "Major Resolve", category = "Defensive and utility buffs" },
    { id = 61715, fallbackName = "Minor Evasion", category = "Defensive and utility buffs" },
    { id = 61716, fallbackName = "Major Evasion", category = "Defensive and utility buffs" },
    { id = 61735, fallbackName = "Minor Expedition", category = "Defensive and utility buffs" },
    { id = 61736, fallbackName = "Major Expedition", category = "Defensive and utility buffs" },
    { id = 61708, fallbackName = "Minor Heroism", category = "Defensive and utility buffs" },
    { id = 61709, fallbackName = "Major Heroism", category = "Defensive and utility buffs" },
    { id = 88490, fallbackName = "Minor Toughness", category = "Defensive and utility buffs" },
    { id = 61691, fallbackName = "Minor Prophecy", category = "Defensive and utility buffs" },
    { id = 61666, fallbackName = "Minor Savagery", category = "Defensive and utility buffs" },
    { id = 61662, fallbackName = "Minor Brutality", category = "Defensive and utility buffs" },
    { id = 61685, fallbackName = "Minor Sorcery", category = "Defensive and utility buffs" },
    { id = 61737, fallbackName = "Empower", category = "Defensive and utility buffs" },
}

local TRACKED_BY_ID = {}
for _, definition in ipairs(TRACKED_BUFFS) do
    TRACKED_BY_ID[definition.id] = definition
end

local BuffTracker = ZO_Object:Subclass()

local function SafeUnitTag(unitTag)
    return tostring(unitTag or "unknown"):gsub("[^%w_]", "_")
end

local function GetDisplayName(definition)
    local name = ""
    if not definition.useFallbackName and type(GetAbilityName) == "function" then
        name = GetAbilityName(definition.nameAbilityId or definition.id) or ""
    end
    if not name or name == "" then
        name = definition.fallbackName
    end
    return name
end

local function GetDisplayIcon(definition)
    local iconAbilityId = definition.iconAbilityId or definition.id
    local icon = type(GetAbilityIcon) == "function" and GetAbilityIcon(iconAbilityId) or ""
    if not icon or icon == "" then
        icon = "/esoui/art/icons/icon_missing.dds"
    end
    return icon
end

local function FormatSettingName(definition)
    local icon = GetDisplayIcon(definition)
    local name = GetDisplayName(definition)
    if type(zo_iconFormat) == "function" then
        return zo_iconFormat(icon, 24, 24) .. " " .. name
    end
    return name
end

local function EnsureSavedSettings(manager)
    if type(manager.SAVEVARS.BUFF_TRACKER) ~= "table" then
        manager.SAVEVARS.BUFF_TRACKER = {}
    end

    local settings = manager.SAVEVARS.BUFF_TRACKER
    if settings.ENABLED == nil then
        settings.ENABLED = true
    end
    if type(settings.TRACK) ~= "table" then
        settings.TRACK = {}
    end

    -- Remove obsolete keys if the supported list changes in a later build.
    for abilityId in pairs(settings.TRACK) do
        if TRACKED_BY_ID[tonumber(abilityId)] == nil then
            settings.TRACK[abilityId] = nil
        end
    end

    return settings
end

function BuffTracker:New(manager)
    local object = ZO_Object.New(self)
    object:Initialize(manager)
    return object
end

function BuffTracker:Initialize(manager)
    self.manager = manager
    self.settings = EnsureSavedSettings(manager)
    self.frames = {}
    self.pillagerCooldowns = {}
    self.nextPeriodicRescan = 0

    self:RegisterSettingsPanel()
    self:RegisterCallbacks()
    self:RegisterEffectEvents()
    self:RegisterCombatEvents()

    manager:ForEach(function(frame)
        self:AttachFrame(frame)
    end)

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, TIMER_UPDATE_MS, function()
        self:OnUpdate()
    end)
end

function BuffTracker:IsEnabled()
    return self.settings.ENABLED == true
end

function BuffTracker:HasAnySelection()
    for _, enabled in pairs(self.settings.TRACK) do
        if enabled == true then
            return true
        end
    end
    return false
end

function BuffTracker:RegisterSettingsPanel()
    local LAM2 = LibAddonMenu2
    if not LAM2 then
        d("[Alternative Group Frames Buffs] LibAddonMenu-2.0 was not loaded; buff settings are unavailable.")
        return
    end

    -- Integrated into My UI, so there is no independent Add-ons panel.

    local options = {
        {
            type = "description",
            text = "Choose which buffs and cooldowns appear beside the group frames. All trackers are disabled by default and settings are account-wide. Pillager's Profit uptime and its 45-second cooldown can be enabled independently.",
        },
        {
            type = "checkbox",
            name = "Enable buff tracker",
            tooltip = "Shows selected active buffs beside every group member, including your own frame.",
            default = true,
            getFunc = function()
                return self.settings.ENABLED
            end,
            setFunc = function(value)
                self.settings.ENABLED = value == true
                self:RefreshAll(true)
            end,
        },
    }

    local currentCategory = nil
    for _, definition in ipairs(TRACKED_BUFFS) do
        if definition.category ~= currentCategory then
            currentCategory = definition.category
            options[#options + 1] = {
                type = "header",
                name = currentCategory,
            }
        end

        local abilityId = definition.id
        local settingName = FormatSettingName(definition)
        options[#options + 1] = {
            type = "checkbox",
            name = settingName,
            tooltip = definition.tracking == "combat"
                and "Show the 45-second Pillager's Profit cooldown on each affected group member."
                or "Show this buff while it is active on a tracked group member.",
            width = "full",
            default = false,
            disabled = function()
                return not self.settings.ENABLED
            end,
            getFunc = function()
                return self.settings.TRACK[abilityId] == true
            end,
            setFunc = function(value)
                self.settings.TRACK[abilityId] = value == true
                self:RefreshAll(true)
            end,
        }
    end

    options[#options + 1] = {
        type = "button",
        name = "Turn off all trackers",
        tooltip = "Disables every individual buff and cooldown without disabling the tracker itself.",
        func = function()
            for _, definition in ipairs(TRACKED_BUFFS) do
                self.settings.TRACK[definition.id] = false
            end
            self:RefreshAll(true)
        end,
    }

    if BUI and BUI.SettingsBridge and BUI.SettingsBridge.AddGroupedSection then
        BUI.SettingsBridge.AddGroupedSection("BUI_BanditUI", {
            id = "MyUIAltGroupFramesBuffs", name = "Group Frames Buffs", order = 16,
            options = options, nestedGroup = "Alternative Groupframes",
        })
    end
end

function BuffTracker:RegisterCallbacks()
    CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.UNIT_FRAME_CREATED, function(frame)
        self:AttachFrame(frame)
    end)

    CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.UNIT_FRAME_ACTIVATED, function(frame)
        self:AttachFrame(frame)
        self:RefreshFrame(frame, true)
    end)

    CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.UNIT_FRAME_DEACTIVATED, function(frame)
        local frameState = self.frames[frame]
        if frameState then
            frameState.container:SetHidden(true)
        end
    end)

    CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.UNIT_FRAME_DATA_CHANGED, function(frame)
        self:AttachFrame(frame)
        self:RefreshFrame(frame, true)
    end)
end

local function NormalizeUnitName(name)
    name = tostring(name or "")
    name = name:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(name)
end

function BuffTracker:GetFrameIdentity(frame)
    return tostring(frame and frame.unitIdentity or "")
end

function BuffTracker:FindFrameForCombatTarget(targetUnitId, targetName)
    local wantedId = tonumber(targetUnitId)
    local wantedName = NormalizeUnitName(targetName)

    for frame in pairs(self.frames) do
        if frame:IsActive() then
            local unitTag = frame:GetUnitTag()
            if wantedId and wantedId ~= 0 and type(GetUnitId) == "function" then
                local unitId = tonumber(GetUnitId(unitTag))
                if unitId and unitId == wantedId then
                    return frame
                end
            end

            if wantedName ~= "" then
                local candidates = {
                    frame.characterName,
                    frame.accountName,
                    type(GetUnitName) == "function" and GetUnitName(unitTag) or nil,
                    type(GetRawUnitName) == "function" and GetRawUnitName(unitTag) or nil,
                    type(GetUnitDisplayName) == "function" and GetUnitDisplayName(unitTag) or nil,
                }
                for _, candidate in ipairs(candidates) do
                    if NormalizeUnitName(candidate) == wantedName then
                        return frame
                    end
                end
            end
        end
    end

    return nil
end

function BuffTracker:GetPillagerCooldown(frame)
    local data = self.pillagerCooldowns[frame]
    if not data then
        return nil
    end

    local now = GetFrameTimeSeconds()
    if data.identity ~= self:GetFrameIdentity(frame) or data.endTime <= now then
        self.pillagerCooldowns[frame] = nil
        return nil
    end

    return data
end

function BuffTracker:StartPillagerCooldown(frame)
    if not frame
        or not frame:IsActive()
        or not self:IsEnabled()
        or self.settings.TRACK[PILLAGER_COOLDOWN_ID] ~= true then
        return false
    end

    local identity = self:GetFrameIdentity(frame)
    if identity == "" then
        return false
    end

    local now = GetFrameTimeSeconds()
    local existing = self.pillagerCooldowns[frame]
    if existing and existing.identity == identity and existing.endTime > now then
        -- The direct combat event and the visible 10-second uptime effect can
        -- both report the same proc. Never extend a cooldown for duplicates.
        return false
    end

    local definition = TRACKED_BY_ID[PILLAGER_COOLDOWN_ID]
    self.pillagerCooldowns[frame] = {
        abilityId = PILLAGER_COOLDOWN_ID,
        name = GetDisplayName(definition),
        icon = GetDisplayIcon(definition),
        startTime = now,
        endTime = now + PILLAGER_COOLDOWN_SECONDS,
        stackCount = 0,
        permanent = false,
        cooldown = true,
        identity = identity,
    }

    self:RefreshFrame(frame, true)
    return true
end

function BuffTracker:RegisterEffectEvents()
    local function OnEffectChanged(
        _,
        changeType,
        effectSlot,
        effectName,
        unitTag,
        beginTime,
        endTime,
        stackCount,
        iconName,
        buffType,
        effectType,
        abilityType,
        statusEffectType,
        unitName,
        unitId,
        abilityId,
        sourceType
    )
        abilityId = tonumber(abilityId)

        -- The cooldown itself (172056) is not exposed through
        -- EVENT_EFFECT_CHANGED. The visible 10-second ultimate-generation
        -- effect is a console-safe fallback that starts the same 45-second
        -- cooldown if the direct combat event is unavailable or missed.
        if abilityId == PILLAGER_ACTIVE_ID
            and self.settings.TRACK[PILLAGER_COOLDOWN_ID] == true
            and changeType ~= EFFECT_RESULT_FADED then
            local cooldownFrame = self.manager.unitFrames and self.manager.unitFrames[unitTag]
            self:StartPillagerCooldown(cooldownFrame)
        end

        if not self:IsEnabled() or not abilityId or self.settings.TRACK[abilityId] ~= true then
            return
        end

        local frame = self.manager.unitFrames and self.manager.unitFrames[unitTag]
        if frame and frame:IsActive() then
            self:RefreshFrame(frame, true)
        end
    end

    local function Register(namespace, filterType, filterValue)
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED, filterType, filterValue)
    end

    Register(NAME .. "GroupEffects", REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    Register(NAME .. "PlayerEffects", REGISTER_FILTER_UNIT_TAG, "player")
    Register(NAME .. "CompanionEffects", REGISTER_FILTER_UNIT_TAG, "companion")
end

function BuffTracker:RegisterCombatEvents()
    local namespace = NAME .. "PillagerCooldown"

    local function OnCombatEvent(
        _,
        result,
        isError,
        abilityName,
        abilityGraphic,
        abilityActionSlotType,
        sourceName,
        sourceType,
        targetName,
        targetType,
        hitValue,
        powerType,
        damageType,
        log,
        sourceUnitId,
        targetUnitId,
        abilityId,
        overflow
    )
        if not self:IsEnabled()
            or self.settings.TRACK[PILLAGER_COOLDOWN_ID] ~= true
            or isError == true
            or (abilityId ~= nil and tonumber(abilityId) ~= PILLAGER_COOLDOWN_ID) then
            return
        end

        local gained = result == ACTION_RESULT_EFFECT_GAINED
            or result == ACTION_RESULT_EFFECT_GAINED_DURATION
        if not gained then
            return
        end

        local frame = self:FindFrameForCombatTarget(targetUnitId, targetName)
        if frame then
            self:StartPillagerCooldown(frame)
        end
    end

    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(
        namespace,
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID,
        PILLAGER_COOLDOWN_ID
    )
end

function BuffTracker:CreateIcon(frameState, index)
    local parent = frameState.container
    local baseName = parent:GetName() .. "Icon" .. index
    local control = WINDOW_MANAGER:CreateControl(baseName, parent, CT_CONTROL)
    control:SetDimensions(ICON_SIZE, ICON_SIZE)
    control:SetMouseEnabled(false)

    local background = WINDOW_MANAGER:CreateControl(baseName .. "Background", control, CT_TEXTURE)
    background:SetAnchorFill(control)
    background:SetColor(0, 0, 0, 0.92)
    background:SetDrawLevel(0)

    local texture = WINDOW_MANAGER:CreateControl(baseName .. "Texture", control, CT_TEXTURE)
    texture:SetAnchor(TOPLEFT, control, TOPLEFT, ICON_BORDER, ICON_BORDER)
    texture:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -ICON_BORDER, -ICON_BORDER)
    texture:SetDrawLevel(1)

    local timer = WINDOW_MANAGER:CreateControl(baseName .. "Timer", control, CT_LABEL)
    timer:SetAnchorFill(control)
    timer:SetFont("$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thick")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetDrawLevel(3)

    local stacks = WINDOW_MANAGER:CreateControl(baseName .. "Stacks", control, CT_LABEL)
    stacks:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -2, -1)
    stacks:SetFont("$(GAMEPAD_BOLD_FONT)|16|soft-shadow-thick")
    stacks:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stacks:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    stacks:SetDrawLevel(4)

    local iconState = {
        control = control,
        texture = texture,
        timer = timer,
        stacks = stacks,
        data = nil,
        lastTimerText = nil,
        lastStackText = nil,
    }

    frameState.icons[index] = iconState
    return iconState
end

function BuffTracker:AttachFrame(frame)
    if self.frames[frame] then
        return self.frames[frame]
    end

    local unitTag = SafeUnitTag(frame:GetUnitTag())
    local container = WINDOW_MANAGER:CreateControl(
        "ALTGF_BuffContainer_" .. unitTag,
        frame:GetControl(),
        CT_CONTROL
    )
    container:SetAnchor(LEFT, frame:GetControl(), RIGHT, ICON_GAP, 0)
    container:SetDimensions((ICON_SIZE + ICON_GAP) * #TRACKED_BUFFS, ICON_SIZE)
    container:SetMouseEnabled(false)
    container:SetHidden(true)

    local frameState = {
        frame = frame,
        container = container,
        icons = {},
        visibleCount = 0,
        needsRescan = true,
    }
    self.frames[frame] = frameState
    frame.buffTrackerContainer = container
    return frameState
end

function BuffTracker:HideUnusedIcons(frameState, firstUnused)
    for index = firstUnused, #frameState.icons do
        local iconState = frameState.icons[index]
        iconState.data = nil
        iconState.control:SetHidden(true)
    end
end

function BuffTracker:CollectActiveBuffs(frame)
    local unitTag = frame:GetUnitTag()
    local activeById = {}
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return activeById
    end

    local now = GetFrameTimeSeconds()
    local count = tonumber(GetNumBuffs(unitTag)) or 0
    for buffIndex = 1, count do
        local buffName,
            timeStarted,
            timeEnding,
            buffSlot,
            stackCount,
            iconFilename,
            buffType,
            effectType,
            abilityType,
            statusEffectType,
            abilityId,
            canClickOff,
            castByPlayer = GetUnitBuffInfo(unitTag, buffIndex)

        abilityId = tonumber(abilityId)
        local definition = abilityId and TRACKED_BY_ID[abilityId]
        if definition and definition.tracking ~= "combat" and self.settings.TRACK[abilityId] == true then
            local startTime = tonumber(timeStarted) or 0
            local endTimeValue = tonumber(timeEnding) or 0
            local permanent = type(IsAbilityPermanent) == "function" and IsAbilityPermanent(abilityId) or false
            local hasValidTime = endTimeValue > now
            local shouldShow = hasValidTime or permanent or definition.allowInvalidDuration == true

            if shouldShow then
                local existing = activeById[abilityId]
                local candidate = {
                    abilityId = abilityId,
                    name = (buffName and buffName ~= "") and buffName or GetDisplayName(definition),
                    icon = (iconFilename and iconFilename ~= "") and iconFilename or GetDisplayIcon(definition),
                    startTime = startTime,
                    endTime = endTimeValue,
                    stackCount = math.max(0, tonumber(stackCount) or 0),
                    permanent = permanent,
                    allowInvalidDuration = definition.allowInvalidDuration == true,
                }

                if not existing
                    or candidate.endTime > existing.endTime
                    or candidate.stackCount > existing.stackCount then
                    activeById[abilityId] = candidate
                end
            end
        end
    end

    if self.settings.TRACK[PILLAGER_COOLDOWN_ID] == true then
        local cooldown = self:GetPillagerCooldown(frame)
        if cooldown then
            activeById[PILLAGER_COOLDOWN_ID] = cooldown
        end
    end

    return activeById
end

function BuffTracker:ApplyIconData(iconState, data, position)
    iconState.data = data
    iconState.control:ClearAnchors()
    iconState.control:SetAnchor(LEFT, iconState.control:GetParent(), LEFT, (position - 1) * (ICON_SIZE + ICON_GAP), 0)
    iconState.texture:SetTexture(data.icon)
    if data.cooldown then
        iconState.texture:SetColor(0.62, 0.62, 0.62, 1)
        iconState.timer:SetColor(1, 0.38, 0.22, 1)
    else
        iconState.texture:SetColor(1, 1, 1, 1)
        iconState.timer:SetColor(1, 1, 1, 1)
    end
    iconState.control:SetHidden(false)
    iconState.lastTimerText = nil
    iconState.lastStackText = nil
    self:UpdateIconText(iconState, GetFrameTimeSeconds())
end

function BuffTracker:UpdateIconText(iconState, now)
    local data = iconState.data
    if not data then
        return false
    end

    local timerText = ""
    local expired = false
    if not data.permanent and data.endTime > data.startTime and data.endTime > 0 then
        local remaining = data.endTime - now
        if remaining <= 0 then
            expired = true
        else
            timerText = tostring(math.ceil(remaining))
        end
    end

    if timerText ~= iconState.lastTimerText then
        iconState.timer:SetText(timerText)
        iconState.lastTimerText = timerText
    end

    local stackText = data.stackCount > 1 and tostring(data.stackCount) or ""
    if stackText ~= iconState.lastStackText then
        iconState.stacks:SetText(stackText)
        iconState.lastStackText = stackText
    end

    return expired
end

function BuffTracker:RefreshFrame(frame, force)
    local frameState = self:AttachFrame(frame)
    frameState.needsRescan = false

    if not self:IsEnabled() or not self:HasAnySelection() or not frame:IsActive() then
        frameState.visibleCount = 0
        frameState.container:SetHidden(true)
        self:HideUnusedIcons(frameState, 1)
        return
    end

    local activeById = self:CollectActiveBuffs(frame)
    local position = 0
    for _, definition in ipairs(TRACKED_BUFFS) do
        local data = activeById[definition.id]
        if data then
            position = position + 1
            local iconState = frameState.icons[position] or self:CreateIcon(frameState, position)
            self:ApplyIconData(iconState, data, position)
        end
    end

    frameState.visibleCount = position
    self:HideUnusedIcons(frameState, position + 1)
    frameState.container:SetHidden(position == 0)
end

function BuffTracker:RefreshAll(force)
    for frame in pairs(self.frames) do
        self:RefreshFrame(frame, force)
    end
end

function BuffTracker:OnUpdate()
    if not self:IsEnabled() or not self:HasAnySelection() then
        return
    end

    local now = GetFrameTimeSeconds()
    local doPeriodicRescan = now >= self.nextPeriodicRescan
    if doPeriodicRescan then
        self.nextPeriodicRescan = now + (PERIODIC_RESCAN_MS / 1000)
    end

    for frame, frameState in pairs(self.frames) do
        if frame:IsActive() then
            local expired = false
            for index = 1, frameState.visibleCount do
                local iconState = frameState.icons[index]
                if iconState and self:UpdateIconText(iconState, now) then
                    expired = true
                end
            end

            if expired or doPeriodicRescan or frameState.needsRescan then
                self:RefreshFrame(frame, true)
            end
        end
    end
end

CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.MANAGER_CREATED, function(manager)
    ALT_GROUP_FRAMES_BUFFS = BuffTracker:New(manager)
end)

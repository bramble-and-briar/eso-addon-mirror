BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

Addon.HUD = Addon.HUD or {}
local HUD = Addon.HUD

local PROMPT_SIZE = 63
local SLOT_STEP = PROMPT_SIZE + 4
local TIMER_HEIGHT = 22
local BINDING_MARKUP_SIZE = 100

local BANNER_BEARER_SHIELD_TEXTURES = {
    [ALLIANCE_ALDMERI_DOMINION] = "EsoUI/Art/Icons/gear_alliance_shield_a.dds",
    [ALLIANCE_DAGGERFALL_COVENANT] = "EsoUI/Art/Icons/gear_alliance_shield_c.dds",
    [ALLIANCE_EBONHEART_PACT] = "EsoUI/Art/Icons/gear_alliance_shield_p.dds",
}

local function RemainingMs(record, now)
    if not record or not record.active then return 0 end
    return math.max(0, (tonumber(record.endTimeMs) or 0) - now)
end

local function SlotEnabled(hotbar, slot)
    if not Addon.sv then return false end
    local tableName = hotbar == HOTBAR_CATEGORY_PRIMARY and "frontSlots" or "backSlots"
    local settings = Addon.sv[tableName]
    return type(settings) == "table" and settings[slot] ~= false
end

local function IsInsideDisplayWindow(remainMs)
    if Addon.sv and Addon.sv.hudFullCountdown == true then return true end
    local seconds = tonumber(Addon.sv and Addon.sv.hudCountdownSeconds) or 10
    seconds = math.max(3, math.min(60, seconds))
    return remainMs <= seconds * 1000
end

local function GetBindingMarkup(slot)
    local actionNames = {
        "GAMEPAD_ACTION_BUTTON_" .. tostring(slot),
        "ACTION_BUTTON_" .. tostring(slot),
    }
    for _, actionName in ipairs(actionNames) do
        if type(ZO_Keybindings_GetHighestPriorityBindingStringFromAction) == "function" then
            local text = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
                actionName,
                KEYBIND_TEXT_OPTIONS_FULL_NAME,
                KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP,
                true,
                false,
                BINDING_MARKUP_SIZE
            )
            if text and text ~= "" then return text end
        end

        if type(GetHighestPriorityActionBindingInfoFromNameAndInputDevice) == "function"
            and PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD ~= nil then
            local key = GetHighestPriorityActionBindingInfoFromNameAndInputDevice(
                actionName,
                PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
            )
            if key and key ~= KEY_INVALID and type(ZO_Keybindings_GenerateIconKeyMarkup) == "function" then
                return ZO_Keybindings_GenerateIconKeyMarkup(key, BINDING_MARKUP_SIZE, false)
            end
        end
    end
    return "S" .. tostring(slot - 2)
end

local function CreatePrompt(name, parent, y)
    local prompt = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    prompt:SetDimensions(PROMPT_SIZE, PROMPT_SIZE)
    prompt:SetAnchor(TOP, parent, TOP, 0, y)
    prompt:SetCenterColor(0, 0, 0, 0.78)
    prompt:SetEdgeColor(1, 1, 1, 0.75)
    prompt:SetEdgeTexture(nil, 1, 1, 1)
    prompt:SetHidden(true)

    local icon = WINDOW_MANAGER:CreateControl(name .. "Icon", prompt, CT_TEXTURE)
    icon:SetDimensions(PROMPT_SIZE - 3, PROMPT_SIZE - 3)
    icon:SetAnchor(CENTER, prompt, CENTER, 0, 0)
    icon:SetHidden(true)

    local binding = WINDOW_MANAGER:CreateControl(name .. "Binding", prompt, CT_LABEL)
    binding:SetDimensions(PROMPT_SIZE, PROMPT_SIZE)
    binding:SetAnchor(CENTER, prompt, CENTER, 0, -4)
    binding:SetFont("ZoFontGamepad42")
    binding:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    binding:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    binding:SetHidden(true)

    local timerBox = WINDOW_MANAGER:CreateControl(name .. "TimerBox", prompt, CT_BACKDROP)
    timerBox:SetDimensions(PROMPT_SIZE, TIMER_HEIGHT)
    timerBox:SetAnchor(BOTTOM, prompt, BOTTOM, 0, 0)
    timerBox:SetCenterColor(0, 0, 0, 0.78)
    timerBox:SetEdgeColor(0, 0, 0, 0)

    local timer = WINDOW_MANAGER:CreateControl(name .. "Timer", timerBox, CT_LABEL)
    timer:SetDimensions(PROMPT_SIZE, TIMER_HEIGHT)
    timer:SetAnchor(CENTER, timerBox, CENTER, 0, 0)
    timer:SetFont("ZoFontGamepadBold18")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return {
        prompt = prompt,
        icon = icon,
        binding = binding,
        timerBox = timerBox,
        timer = timer,
    }
end

local function CreateSide(name, anchorPoint, relativePoint, x, y)
    local slotCount = Addon.Config.lastSlot - Addon.Config.firstSlot + 1
    local root = WINDOW_MANAGER:CreateTopLevelWindow(name)
    root:SetDimensions(PROMPT_SIZE, (slotCount + 1) * SLOT_STEP)
    root:SetAnchor(anchorPoint, GuiRoot, relativePoint, x, y)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    if root.SetDrawTier then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer then root:SetDrawLayer(DL_OVERLAY) end

    local prompts = {}
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        prompts[slot] = CreatePrompt(
            name .. "Prompt" .. tostring(slot),
            root,
            (slot - Addon.Config.firstSlot) * SLOT_STEP
        )
    end

    local cadence = CreatePrompt(name .. "Cadence", root, slotCount * SLOT_STEP)
    return { root = root, prompts = prompts, cadence = cadence }
end

local function HideSide(side)
    if not side then return end
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        side.prompts[slot].prompt:SetHidden(true)
    end
    side.cadence.prompt:SetHidden(true)
    side.root:SetHidden(true)
end

function HUD:Initialize()
    if self.initialized or not WINDOW_MANAGER or not GuiRoot then return end

    self.left = CreateSide(
        "BackBarTimerLeft",
        LEFT,
        LEFT,
        tonumber(Addon.sv.leftInset) or 500,
        tonumber(Addon.sv.leftY) or -50
    )
    self.right = CreateSide(
        "BackBarTimerRight",
        RIGHT,
        RIGHT,
        -(tonumber(Addon.sv.rightInset) or 700),
        tonumber(Addon.sv.rightY) or -50
    )
    self.initialized = true
    self:ApplySettings()
end

function HUD:ApplySettings()
    if not self.initialized then return end
    local scale = math.max(0.5, math.min(3.0, tonumber(Addon.sv.hudScale) or 1.0))
    self.left.root:SetScale(scale)
    self.right.root:SetScale(scale)

    self.left.root:ClearAnchors()
    self.left.root:SetAnchor(LEFT, GuiRoot, LEFT,
        tonumber(Addon.sv.leftInset) or 500, tonumber(Addon.sv.leftY) or -50)
    self.right.root:ClearAnchors()
    self.right.root:SetAnchor(RIGHT, GuiRoot, RIGHT,
        -(tonumber(Addon.sv.rightInset) or 700), tonumber(Addon.sv.rightY) or -50)
end

function HUD:Hide()
    if not self.initialized then return end
    HideSide(self.left)
    HideSide(self.right)
end

function HUD:GetAllianceTexture()
    local alliance = type(GetUnitAlliance) == "function" and GetUnitAlliance("player") or nil
    local texture = alliance and BANNER_BEARER_SHIELD_TEXTURES[alliance]
    if texture then return texture end
    if alliance and type(ZO_GetAllianceIcon) == "function" then return ZO_GetAllianceIcon(alliance) end
    if alliance and type(ZO_GetAllianceSymbolIcon) == "function" then return ZO_GetAllianceSymbolIcon(alliance) end
    return "EsoUI/Art/CharacterWindow/gearSlot_offHand.dds"
end

function HUD:GetFrontWeaponTexture()
    if type(GetWornItemInfo) == "function" then
        local hasItem, icon = GetWornItemInfo(BAG_WORN, EQUIP_SLOT_MAIN_HAND)
        if hasItem and icon and icon ~= "" then return icon end
    end
    return "EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds"
end

function HUD:ShowSkillPrompt(entry, record, remainMs)
    if remainMs <= Addon.Config.hudWarningMs then
        entry.icon:SetTexture(record.icon)
        entry.icon:SetHidden(false)
        entry.binding:SetHidden(true)
        entry.timer:SetText(string.format("%.1f", math.max(0, remainMs) / 1000))
    else
        entry.binding:SetText(GetBindingMarkup(record.slot))
        entry.binding:SetHidden(false)
        entry.icon:SetHidden(true)
        entry.timer:SetText(tostring(math.ceil(remainMs / 1000)))
    end
    entry.timerBox:SetHidden(false)
    entry.prompt:SetHidden(false)
end

function HUD:ShowCadencePrompt(entry, kind)
    entry.icon:SetTexture(kind == "block" and self:GetAllianceTexture() or self:GetFrontWeaponTexture())
    entry.icon:SetHidden(false)
    entry.binding:SetHidden(true)
    entry.timerBox:SetHidden(true)
    entry.prompt:SetHidden(false)
end

function HUD:ShowCadenceCountdown(entry, remainMs)
    entry.binding:SetText(tostring(math.max(1, math.ceil(remainMs / 1000))))
    entry.binding:SetHidden(false)
    entry.icon:SetHidden(true)
    entry.timerBox:SetHidden(true)
    entry.prompt:SetHidden(false)
end

function HUD:RefreshSide(side, hotbar, now, cadenceKind, cadenceEnabled,
        cadencePulseUntil, cadenceNextCueTimeMs)
    local hasContent = false
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        local entry = side.prompts[slot]
        local record = Addon.State:GetRecord(hotbar, slot)
        local qualifying = record
            and (tonumber(record.durationMs) or 0) >= Addon.Config.minimumDurationMs
        local remain = SlotEnabled(hotbar, slot) and qualifying and RemainingMs(record, now) or 0

        if remain > 0 and IsInsideDisplayWindow(remain) then
            hasContent = true
            self:ShowSkillPrompt(entry, record, remain)
        else
            entry.prompt:SetHidden(true)
        end
    end

    if cadenceEnabled and cadencePulseUntil and cadencePulseUntil > now then
        hasContent = true
        self:ShowCadencePrompt(side.cadence, cadenceKind)
    elseif cadenceEnabled and Addon.State.cadenceRunning
        and cadenceNextCueTimeMs and cadenceNextCueTimeMs > now then
        hasContent = true
        self:ShowCadenceCountdown(side.cadence, cadenceNextCueTimeMs - now)
    else
        side.cadence.prompt:SetHidden(true)
    end
    side.root:SetHidden(not hasContent)
end

function HUD:Refresh(now)
    if not self.initialized then self:Initialize() end
    if not self.initialized then return end
    if not Addon.sv or Addon.sv.mode ~= "hud" or Addon.State.menuOpen then
        self:Hide()
        return
    end

    now = tonumber(now) or GetFrameTimeMilliseconds()
    self:RefreshSide(self.left, HOTBAR_CATEGORY_BACKUP, now,
        "block", Addon.sv.blockCadence, Addon.State.blockPulseUntilMs,
        Addon.State.cadenceNextCueTimeMs)
    self:RefreshSide(self.right, HOTBAR_CATEGORY_PRIMARY, now,
        "light", Addon.sv.lightCadence, Addon.State.lightPulseUntilMs,
        Addon.State.cadenceNextCueTimeMs)
end


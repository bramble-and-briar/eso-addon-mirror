local ADDON_NAME = "NirnsteelUI"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local LootHistory = {}
Nirnsteel_UI.LootHistory = LootHistory

local KEYBOARD_TEMPLATE_NAME = "Nirnsteel_LootHistory_KeyboardEntry"
local GAMEPAD_TEMPLATE_NAME = "Nirnsteel_LootHistory_GamepadEntry"
local KEYBOARD_STOCK_TEMPLATE_NAME = "ZO_LootHistory_KeyboardEntry"
local GAMEPAD_STOCK_TEMPLATE_NAME = "ZO_LootHistory_GamepadEntry"
local PATCH_UPDATE_NAME = "Nirnsteel_UI_LootHistory_WaitForHistory"
local MAX_PATCH_ATTEMPTS = 80
local PATCH_RETRY_MS = 250
local DEFAULT_LOOT_HISTORY_ANCHOR_OFFSET_X = 180
local DEFAULT_LOOT_HISTORY_ANCHOR_OFFSET_Y = -230
local STOCK_KEYBOARD_LOOT_HISTORY_ANCHOR_OFFSET_X = 0
local STOCK_KEYBOARD_LOOT_HISTORY_ANCHOR_OFFSET_Y = -84
local STOCK_KEYBOARD_LOOT_HISTORY_CONTROL_OFFSET_Y = -95
local STOCK_GAMEPAD_LOOT_HISTORY_ANCHOR_OFFSET_X = 0
local STOCK_GAMEPAD_LOOT_HISTORY_ANCHOR_OFFSET_Y = -120
local STOCK_GAMEPAD_LOOT_HISTORY_CONTROL_OFFSET_Y = -120
local LOOT_SOUND_THROTTLE_MS = 90
local SEQUENTIAL_REVEAL_DELAY_MS = 260
local LOOT_ENTRY_SPACING_Y = 5
local STOCK_LOOT_ENTRY_SPACING_Y = -1
local STOCK_CONTAINER_SHOW_TIME_MS = 3600
local STOCK_PERSISTENT_CONTAINER_SHOW_TIME_MS = 7000
local DEBUG_MIX_ITEM_COUNT = 7
local DEFAULT_LOOT_HISTORY_SCALE = 100
local MIN_LOOT_HISTORY_SCALE = 60
local MAX_LOOT_HISTORY_SCALE = 180

local QUALITY_STYLE =
{
    [ITEM_DISPLAY_QUALITY_TRASH] = { 0.18, 0.18 },
    [ITEM_DISPLAY_QUALITY_NORMAL] = { 0.22, 0.20 },
    [ITEM_DISPLAY_QUALITY_MAGIC] = { 0.30, 0.28 },
    [ITEM_DISPLAY_QUALITY_ARCANE] = { 0.42, 0.42 },
    [ITEM_DISPLAY_QUALITY_ARTIFACT] = { 0.78, 0.72 },
    [ITEM_DISPLAY_QUALITY_LEGENDARY] = { 1.00, 0.95 },
    [ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE] = { 1.00, 0.95 },
}

local lastLootSoundMS = -LOOT_SOUND_THROTTLE_MS
local debugItemId = 900000
local originalAddXpEntry
local entryControls = setmetatable({}, { __mode = "k" })

local HISTORY_DESCRIPTORS =
{
    {
        key = "Keyboard",
        templateName = KEYBOARD_TEMPLATE_NAME,
        stockTemplateName = KEYBOARD_STOCK_TEMPLATE_NAME,
        getHistory = function() return LOOT_HISTORY_KEYBOARD end,
        stockPoint = BOTTOMRIGHT,
        stockAnchorOffsetX = STOCK_KEYBOARD_LOOT_HISTORY_ANCHOR_OFFSET_X,
        stockAnchorOffsetY = STOCK_KEYBOARD_LOOT_HISTORY_ANCHOR_OFFSET_Y,
        stockControlOffsetY = STOCK_KEYBOARD_LOOT_HISTORY_CONTROL_OFFSET_Y,
    },
    {
        key = "Gamepad",
        templateName = GAMEPAD_TEMPLATE_NAME,
        stockTemplateName = GAMEPAD_STOCK_TEMPLATE_NAME,
        getHistory = function() return LOOT_HISTORY_GAMEPAD end,
        stockPoint = BOTTOMLEFT,
        stockAnchorOffsetX = STOCK_GAMEPAD_LOOT_HISTORY_ANCHOR_OFFSET_X,
        stockAnchorOffsetY = STOCK_GAMEPAD_LOOT_HISTORY_ANCHOR_OFFSET_Y,
        stockControlOffsetY = STOCK_GAMEPAD_LOOT_HISTORY_CONTROL_OFFSET_Y,
    },
}

local function GetConfiguredRegularLootSound()
    local regularSoundKey = "TRIBUTE_AGENT_HEALED"
    if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetLootHistory then
        regularSoundKey = Nirnsteel_UI.Settings:GetLootHistory().regularSoundKey or regularSoundKey
    end
    return SOUNDS[regularSoundKey] or SOUNDS.TRIBUTE_AGENT_HEALED
end

local function IsLegendaryItemEntry(data)
    return data
        and data.entryType == LOOT_ENTRY_TYPE_ITEM
        and data.displayQuality == ITEM_DISPLAY_QUALITY_LEGENDARY
end

local function PlayLootFeedbackSound(data)
    if Nirnsteel_UI.Settings and not Nirnsteel_UI.Settings:AreLootHistorySoundsEnabled() then
        return
    end

    local nowMS = GetFrameTimeMilliseconds()
    if nowMS - lastLootSoundMS >= LOOT_SOUND_THROTTLE_MS then
        if IsLegendaryItemEntry(data) then
            PlaySound(SOUNDS.ANTIQUITIES_FANFARE_COMPLETED)
        else
            PlaySound(GetConfiguredRegularLootSound())
        end
        lastLootSoundMS = nowMS
    end
end

local DEBUG_ITEMS =
{
    { name = "Rawhide Scraps", icon = "EsoUI/Art/Icons/crafting_leather_scraps.dds", quality = ITEM_DISPLAY_QUALITY_NORMAL },
    { name = "Jora", icon = "EsoUI/Art/Icons/crafting_runecrafter_potency_rune_001.dds", quality = ITEM_DISPLAY_QUALITY_NORMAL },
    { name = "Dwarven Oil", icon = "EsoUI/Art/Icons/crafting_smith_potion_vendor_002.dds", quality = ITEM_DISPLAY_QUALITY_MAGIC },
    { name = "Sapphire", icon = "EsoUI/Art/Icons/crafting_jewelry_base_sapphire_r1.dds", quality = ITEM_DISPLAY_QUALITY_MAGIC },
    { name = "Grain Solvent", icon = "EsoUI/Art/Icons/crafting_smith_potion_vendor_003.dds", quality = ITEM_DISPLAY_QUALITY_ARCANE },
    { name = "Elegant Lining", icon = "EsoUI/Art/Icons/crafting_cloth_component_004.dds", quality = ITEM_DISPLAY_QUALITY_ARTIFACT },
    { name = "Dreugh Wax", icon = "EsoUI/Art/Icons/crafting_forester_weapon_component_004.dds", quality = ITEM_DISPLAY_QUALITY_LEGENDARY },
}

local function GetLootHistory()
    LootHistory:PatchHistories()
    return LOOT_HISTORY_KEYBOARD or LOOT_HISTORY_GAMEPAD
end

local function CreateDebugItemData(name, icon, displayQuality, stackCount)
    debugItemId = debugItemId + 1

    return {
        text = name,
        icon = icon,
        stackCount = stackCount or 1,
        color = GetItemQualityColor(displayQuality),
        itemId = debugItemId,
        displayQuality = displayQuality,
        quality = displayQuality,
        isCraftBagItem = false,
        isStolen = false,
        entryType = LOOT_ENTRY_TYPE_ITEM,
        iconOverlayText = ZO_LootHistory_Shared.GetStackCountStringFromData,
        showIconOverlayText = ZO_LootHistory_Shared.ShouldShowStackCountStringFromData,
    }
end

local function AddDebugLootData(data)
    local lootHistory = GetLootHistory()
    if not lootHistory then
        d("Nirnsteel UI: loot history is not ready yet.")
        return
    end

    local lootEntry = lootHistory:CreateLootEntry(data)
    lootHistory:InsertOrQueue(lootEntry)
end

function LootHistory:DebugLegendary()
    AddDebugLootData(CreateDebugItemData("Nirnsteel Debug Legendary", "EsoUI/Art/Icons/gear_breton_1hsword_d.dds", ITEM_DISPLAY_QUALITY_LEGENDARY, 1))
end

function LootHistory:DebugMixedItems()
    for i = 1, DEBUG_MIX_ITEM_COUNT do
        local item = DEBUG_ITEMS[math.random(#DEBUG_ITEMS)]
        AddDebugLootData(CreateDebugItemData(item.name, item.icon, item.quality, math.random(1, 3)))
    end
end

function LootHistory:PreviewRegularSound()
    PlaySound(GetConfiguredRegularLootSound())
end

local DEBUG_COMMANDS =
{
    ["/nslootlegendary"] = function()
        LootHistory:DebugLegendary()
    end,
    ["/nslootmix"] = function()
        LootHistory:DebugMixedItems()
    end,
}

local function IsDebugModeEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function LootHistory:RefreshDebugCommands()
    RegisterDebugCommands()
end

local function GetLootHistoryPosition()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetLootHistoryPosition()
    end

    return { x = DEFAULT_LOOT_HISTORY_ANCHOR_OFFSET_X, y = DEFAULT_LOOT_HISTORY_ANCHOR_OFFSET_Y }
end

local function GetLootHistoryScaleMultiplier()
    local scale = DEFAULT_LOOT_HISTORY_SCALE
    if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetLootHistory then
        scale = tonumber(Nirnsteel_UI.Settings:GetLootHistory().scale) or scale
    end

    return math.min(math.max(scale, MIN_LOOT_HISTORY_SCALE), MAX_LOOT_HISTORY_SCALE) / 100
end

local function GetBaseLootHistoryScale(lootHistory)
    if lootHistory.nirnsteelBaseScale == nil then
        lootHistory.nirnsteelBaseScale = lootHistory.control:GetScale()
    end

    return lootHistory.nirnsteelBaseScale
end

local function IsLootHistoryModuleEnabled()
    return not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:IsLootHistoryEnabled()
end

local function IsLegacyStyleEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetLootHistory
        and Nirnsteel_UI.Settings:GetLootHistory().legacyStyle == true
end

local function IsMirroredLayoutEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetLootHistory
        and Nirnsteel_UI.Settings:GetLootHistory().mirrorLayout == true
end

local MIRRORED_ANCHOR_POINTS =
{
    [LEFT] = RIGHT, [RIGHT] = LEFT,
    [TOPLEFT] = TOPRIGHT, [TOPRIGHT] = TOPLEFT,
    [BOTTOMLEFT] = BOTTOMRIGHT, [BOTTOMRIGHT] = BOTTOMLEFT,
}

local function MirrorControlAnchors(control)
    if not control then return end
    local anchors = {}
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relativeTo, relativePoint, x, y = control:GetAnchor(index)
        if valid then
            table.insert(anchors, {
                MIRRORED_ANCHOR_POINTS[point] or point, relativeTo,
                MIRRORED_ANCHOR_POINTS[relativePoint] or relativePoint, -(x or 0), y or 0,
            })
        end
    end
    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do
        control:SetAnchor(unpack(anchor, 1, 5))
    end
end

local function SetEntryMirrored(control, mirrored)
    mirrored = mirrored == true
    if (control.nirnsteelMirrored == true) == mirrored then return end

    -- Mirror the row geometry while keeping text, item art, and stack counts
    -- readable. Flipping twice restores the original anchors and textures.
    for _, name in ipairs({ "Bg", "Icon", "Label", "IconFrame", "Glass",
        "RarityGlow", "RarityBurst", "RarityAccent", "TopEdge" }) do
        MirrorControlAnchors(control:GetNamedChild(name))
    end
    MirrorControlAnchors(control.statusIcon)
    local background = control:GetNamedChild("Bg")
    local highlight = background and background:GetNamedChild("Highlight")
    MirrorControlAnchors(highlight)
    for _, name in ipairs({ "Bg", "Glass", "RarityGlow", "RarityBurst", "RarityAccent", "TopEdge" }) do
        local texture = control:GetNamedChild(name)
        if texture then
            local left, right, top, bottom = texture:GetTextureCoords()
            texture:SetTextureCoords(right, left, top, bottom)
        end
    end
    if highlight then
        local left, right, top, bottom = highlight:GetTextureCoords()
        highlight:SetTextureCoords(right, left, top, bottom)
    end
    control:GetNamedChild("Label"):SetHorizontalAlignment(mirrored and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
    control.nirnsteelMirrored = mirrored
end

local function GetLegacyTemplateName(descriptor)
    return (descriptor.templateName:gsub("Nirnsteel_LootHistory_", "Nirnsteel_LootHistory_Legacy_"))
end

local function GetEntryTemplateName(descriptor)
    return IsLegacyStyleEnabled() and GetLegacyTemplateName(descriptor) or descriptor.templateName
end

local function GetEntrySpacing()
    return IsLegacyStyleEnabled() and STOCK_LOOT_ENTRY_SPACING_Y or LOOT_ENTRY_SPACING_Y
end

local function SafeSetColor(control, colorDef, alpha)
    if control and colorDef then
        local r, g, b = colorDef:UnpackRGB()
        control:SetColor(r, g, b, alpha)
    end
end

local function GetEntryQualityStyle(data)
    local quality = data and (data.displayQuality or data.quality)
    local style = quality and QUALITY_STYLE[quality]
    if style then
        return quality, style[1], style[2]
    end

    if data and data.entryType == LOOT_ENTRY_TYPE_ITEM then
        return ITEM_DISPLAY_QUALITY_NORMAL, 0.24, 0.22
    end

    return nil, 0.26, 0.20
end

local function GetPulseTimelineName(data)
    if data and data.entryType == LOOT_ENTRY_TYPE_ITEM then
        if data.displayQuality == ITEM_DISPLAY_QUALITY_LEGENDARY or data.displayQuality == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
            return "Nirnsteel_LootHistory_LegendaryPulse"
        elseif data.displayQuality == ITEM_DISPLAY_QUALITY_ARTIFACT then
            return "Nirnsteel_LootHistory_EpicPulse"
        end
    end

    return "Nirnsteel_LootHistory_RarityPulse"
end

local function PlayRarityPulse(control, data)
    local timelineName = GetPulseTimelineName(data)
    if control.nirnsteelLegacyStyle then
        timelineName = timelineName:gsub("Nirnsteel_LootHistory_", "Nirnsteel_LootHistory_Legacy_")
    end
    if control.rarityPulseTimelineName ~= timelineName then
        control.rarityPulseTimelineName = timelineName
        control.rarityPulseTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual(timelineName, control)
    end

    control.rarityPulseTimeline:PlayFromStart()
end

local function QueueRarityPulse(control, data)
    control.nirnsteelPulseToken = (control.nirnsteelPulseToken or 0) + 1
    local pulseToken = control.nirnsteelPulseToken

    zo_callLater(function()
        if control.nirnsteelPulseToken == pulseToken and not control:IsHidden() then
            PlayRarityPulse(control, data)
            PlayLootFeedbackSound(data)
        end
    end, 160)
end

local function ApplyLegacyVisualStyle(control, data)
    local _, glowAlpha, frameAlpha = GetEntryQualityStyle(data)

    if data and data.color then
        SafeSetColor(control.rarityGlow, data.color, glowAlpha)
        SafeSetColor(control.rarityBurst, data.color, glowAlpha)
        SafeSetColor(control.iconFrame, data.color, frameAlpha)
    elseif control.rarityGlow then
        control.rarityGlow:SetColor(1, 1, 1, glowAlpha)
        control.rarityBurst:SetColor(1, 1, 1, glowAlpha)
        control.iconFrame:SetColor(1, 1, 1, frameAlpha)
    end

    if control.background then
        if data and data.backgroundColor then
            local r, g, b = data.backgroundColor:UnpackRGB()
            control.background:SetColor(r, g, b, 0.86)
        else
            control.background:SetColor(0.025, 0.025, 0.025, 0.86)
        end
    end

    if control.glass then
        control.glass:SetColor(1, 1, 1, 0.14)
    end

    if control.rarityGlow and control.rarityBurst then
        QueueRarityPulse(control, data)
    end
end

local function PositionStatusIcon(control)
    -- All secondary markers (craft bag, leads, collections, stolen items, etc.)
    -- share this control. Keep them independent of the item's scale animation.
    local statusIcon = control.statusIcon
    statusIcon:SetParent(control)
    statusIcon:ClearAnchors()
    -- Keep a 4px gap outside the shield's wing on either side of the row.
    statusIcon:SetAnchor(CENTER, control.iconFrame, CENTER, control.nirnsteelMirrored and 52 or -52, -2)
    statusIcon:SetDimensions(20, 20)
    statusIcon:SetDrawTier(DT_MEDIUM)
    statusIcon:SetDrawLayer(DL_OVERLAY)
end

local function ApplyVisualStyle(control, data)
    if control.nirnsteelLegacyStyle then
        ApplyLegacyVisualStyle(control, data)
        return
    end
    PositionStatusIcon(control)
    local _, glowAlpha = GetEntryQualityStyle(data)

    if data and data.color then
        SafeSetColor(control.rarityGlow, data.color, glowAlpha)
        SafeSetColor(control.rarityBurst, data.color, glowAlpha)
        SafeSetColor(control.rarityAccent, data.color, 0.85)
    elseif control.rarityGlow then
        control.rarityGlow:SetColor(1, 1, 1, glowAlpha)
        control.rarityBurst:SetColor(1, 1, 1, glowAlpha)
        control.rarityAccent:SetColor(0.65, 0.72, 0.80, 0.65)
    end

    local r, g, b = 0.72, 0.64, 0.45
    if data and data.color then
        r, g, b = data.color:UnpackRGB()
    end
    for _, inlay in ipairs(control.ornamentInlays) do
        inlay:SetCenterColor(r * 0.75 + 0.25, g * 0.75 + 0.22, b * 0.75 + 0.16, 0.85)
    end

    if control.background then
        if data and data.backgroundColor then
            local r, g, b = data.backgroundColor:UnpackRGB()
            control.background:SetColor(r, g, b, 0.86)
        else
            control.background:SetColor(0.055 + r * 0.055, 0.045 + g * 0.055, 0.035 + b * 0.055, 0.88)
        end
    end

    if control.glass then
        control.glass:SetColor(1, 0.86, 0.62, 0.10)
    end

    if control.rarityGlow and control.rarityBurst then
        QueueRarityPulse(control, data)
    end
end

local function CopyTemplateBehavior(stream, templateName, stockTemplateName)
    if not stream or not stream.templates then
        return false
    end

    local stockTemplate = stream.templates[stockTemplateName]
    if not stockTemplate then
        return false
    end

    if stream.templates[templateName] and stream.templates[templateName].nirnsteelTemplate then
        return true
    end

    local wrappedTemplate =
    {
        equalityCheck = stockTemplate.equalityCheck,
        equalitySetup = stockTemplate.equalitySetup,
        headerTemplateName = stockTemplate.headerTemplateName,
        headerSetup = stockTemplate.headerSetup,
        headerEqualityCheck = stockTemplate.headerEqualityCheck,
        nirnsteelTemplate = true,
    }

    wrappedTemplate.setup = function(control, data)
        -- Stock setup always runs in its original layout before mirroring.
        SetEntryMirrored(control, false)
        stockTemplate.setup(control, data)
        ApplyVisualStyle(control, data)
        entryControls[control] = true
        SetEntryMirrored(control, IsMirroredLayoutEnabled())
    end

    stream:AddTemplate(templateName, wrappedTemplate)
    return true
end

local function UsesHUDEditor()
    return Nirnsteel_UI.HUDEditor and Nirnsteel_UI.HUDEditor:IsAvailable()
end

local function RestoreHUDAnchor(control)
    local element = HUD_MANAGER:GetKeyboardElementForControl(control) or HUD_MANAGER:GetGamepadElementForControl(control)
    if element and HUD_MANAGER.savedVars then element:RevertOffsetModifications() end
end

local function ApplyLootHistoryAnchor(lootHistory)
    local control = lootHistory and lootHistory.control
    if not control then
        return
    end

    local position = GetLootHistoryPosition()
    control:SetScale(GetBaseLootHistoryScale(lootHistory) * GetLootHistoryScaleMultiplier())
    control:ClearAnchors()
    control:SetAnchor(BOTTOMRIGHT, GuiRoot, CENTER, position.x, position.y)
    if UsesHUDEditor() then
        local platform = lootHistory == LOOT_HISTORY_GAMEPAD and "gamepad" or "keyboard"
        Nirnsteel_UI.HUDEditor:Apply("lootHistory_" .. platform,control,{
            native=true, platform=platform, position=position, enabled=IsLootHistoryModuleEnabled,
        })
    end
end

local function ScheduleNextReveal(stream)
    if stream.nirnsteelRevealScheduled then
        return
    end

    stream.nirnsteelRevealScheduled = true
    zo_callLater(function()
        stream.nirnsteelRevealScheduled = false
        if not stream.paused then
            stream:DisplayBatches()
        end
    end, SEQUENTIAL_REVEAL_DELAY_MS)
end

local function InstallSequentialReveal(stream)
    if not stream or stream.nirnsteelSequentialReveal then
        return
    end

    stream.nirnsteelSequentialReveal = true
    stream.nirnsteelOriginalDisplayBatches = stream.DisplayBatches

    stream.DisplayBatches = function(self)
        local nowMS = GetFrameTimeMilliseconds()
        if self.nirnsteelNextRevealMS and nowMS < self.nirnsteelNextRevealMS then
            ScheduleNextReveal(self)
            return
        end

        while self:CanDisplayMore() do
            local currentBatch = self.queuedBatches[1]
            if not currentBatch then
                return
            end

            local iterator = currentBatch.iterator
            if not iterator or iterator < 1 then
                table.remove(self.queuedBatches, 1)
            elseif self:CanDisplayEntry() then
                local hasCurrentEntries = self.currentNumDisplayedEntries > 0
                local control = self:DisplayEntry(currentBatch[iterator].templateName, currentBatch[iterator].entry, 0, hasCurrentEntries)
                self.bottomEntry = control

                currentBatch.iterator = iterator - 1
                if currentBatch.iterator < 1 then
                    table.remove(self.queuedBatches, 1)
                end

                self.control:SetAlpha(1)
                self.containerStartTimeMs = nowMS
                self.doesContainsEntries = true
                self.nirnsteelNextRevealMS = nowMS + SEQUENTIAL_REVEAL_DELAY_MS
                ScheduleNextReveal(self)
                return
            else
                return
            end
        end
    end
end

local function RestoreSequentialReveal(stream)
    if stream and stream.nirnsteelSequentialReveal and stream.nirnsteelOriginalDisplayBatches then
        stream.DisplayBatches = stream.nirnsteelOriginalDisplayBatches
        stream.nirnsteelOriginalDisplayBatches = nil
        stream.nirnsteelSequentialReveal = nil
        stream.nirnsteelRevealScheduled = nil
        stream.nirnsteelNextRevealMS = nil
    end
end

local function GetMover()
    if LootHistory.mover then
        return LootHistory.mover
    end

    local wm = WINDOW_MANAGER
    local mover = wm:CreateTopLevelWindow("Nirnsteel_UI_LootHistoryMover")
    mover:SetDimensions(360, 64)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = wm:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.04, 0.04, 0.04, 0.55)
    backdrop:SetEdgeColor(0.85, 0.72, 0.25, 0.9)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = wm:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, 0)
    label:SetFont("ZoFontGameBold")
    label:SetText("Nirnsteel Loot History")
    label:SetColor(0.95, 0.82, 0.35, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetRight() - (GuiRoot:GetWidth() / 2)
        local y = control:GetBottom() - (GuiRoot:GetHeight() / 2)
        if Nirnsteel_UI.Settings then
            Nirnsteel_UI.Settings:SetLootHistoryPosition(x, y)
        end
        LootHistory:ApplySettings()
    end)

    LootHistory.mover = mover
    return mover
end

local function ApplyMoverState()
    if UsesHUDEditor() then
        if LootHistory.mover then LootHistory.mover:SetHidden(true) end
        return
    end
    local mover = GetMover()
    local unlocked = IsLootHistoryModuleEnabled() and Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsLootHistoryUnlocked()
    local position = GetLootHistoryPosition()

    mover:SetScale(GetLootHistoryScaleMultiplier())
    mover:ClearAnchors()
    mover:SetAnchor(BOTTOMRIGHT, GuiRoot, CENTER, position.x, position.y)
    mover:SetHidden(not unlocked)
end

local function RestoreStockHistory(lootHistory, descriptor)
    if not lootHistory then
        return
    end

    lootHistory.entryTemplate = descriptor.stockTemplateName
    if lootHistory.control then
        lootHistory.control:SetScale(GetBaseLootHistoryScale(lootHistory))
        if UsesHUDEditor() then
            RestoreHUDAnchor(lootHistory.control)
        else
            lootHistory.control:ClearAnchors()
            lootHistory.control:SetAnchor(descriptor.stockPoint, GuiRoot, descriptor.stockPoint, 0, descriptor.stockControlOffsetY)
        end
    end

    if lootHistory.lootStream then
        RestoreSequentialReveal(lootHistory.lootStream)
        lootHistory.lootStream.anchor = (UsesHUDEditor() and lootHistory.lootStream.nirnsteelNativeAnchor)
            or ZO_Anchor:New(descriptor.stockPoint, GuiRoot, descriptor.stockPoint, descriptor.stockAnchorOffsetX, descriptor.stockAnchorOffsetY)
        lootHistory.lootStream:SetAdditionalEntrySpacingY(STOCK_LOOT_ENTRY_SPACING_Y)
        lootHistory.lootStream:SetContainerShowTime(STOCK_CONTAINER_SHOW_TIME_MS)
    end

    if lootHistory.lootStreamPersistent then
        RestoreSequentialReveal(lootHistory.lootStreamPersistent)
        lootHistory.lootStreamPersistent.anchor = (UsesHUDEditor() and lootHistory.lootStreamPersistent.nirnsteelNativeAnchor)
            or ZO_Anchor:New(descriptor.stockPoint, GuiRoot, descriptor.stockPoint, descriptor.stockAnchorOffsetX, descriptor.stockAnchorOffsetY)
        lootHistory.lootStreamPersistent:SetAdditionalEntrySpacingY(STOCK_LOOT_ENTRY_SPACING_Y)
        lootHistory.lootStreamPersistent:SetContainerShowTime(STOCK_PERSISTENT_CONTAINER_SHOW_TIME_MS)
    end

    ApplyMoverState()
end

function LootHistory:ApplySettingsToHistory(lootHistory, descriptor)
    if not lootHistory then
        return false
    end

    if not IsLootHistoryModuleEnabled() then
        RestoreStockHistory(lootHistory, descriptor)
        return true
    end

    lootHistory.entryTemplate = GetEntryTemplateName(descriptor)
    ApplyLootHistoryAnchor(lootHistory)

    local position = GetLootHistoryPosition()
    if lootHistory.lootStream then
        InstallSequentialReveal(lootHistory.lootStream)
        lootHistory.lootStream.anchor = (UsesHUDEditor() and lootHistory.lootStream.nirnsteelNativeAnchor)
            or ZO_Anchor:New(BOTTOMRIGHT, GuiRoot, CENTER, position.x, position.y)
        lootHistory.lootStream:SetContainerShowTime(3100)
        lootHistory.lootStream:SetAdditionalEntrySpacingY(GetEntrySpacing())
    end

    if lootHistory.lootStreamPersistent then
        InstallSequentialReveal(lootHistory.lootStreamPersistent)
        lootHistory.lootStreamPersistent.anchor = (UsesHUDEditor() and lootHistory.lootStreamPersistent.nirnsteelNativeAnchor)
            or ZO_Anchor:New(BOTTOMRIGHT, GuiRoot, CENTER, position.x, position.y)
        lootHistory.lootStreamPersistent:SetContainerShowTime(5600)
        lootHistory.lootStreamPersistent:SetAdditionalEntrySpacingY(GetEntrySpacing())
    end

    ApplyMoverState()
    return true
end

function LootHistory:ApplySettings()
    local applied = false
    for _, descriptor in ipairs(HISTORY_DESCRIPTORS) do
        applied = self:ApplySettingsToHistory(descriptor.getHistory(), descriptor) or applied
    end

    if applied then
        ApplyMoverState()
    end
    for control in pairs(entryControls) do
        SetEntryMirrored(control, IsLootHistoryModuleEnabled() and IsMirroredLayoutEnabled())
    end
end

function LootHistory:RefreshSettings()
    self:PatchHistories()
    self:ApplySettings()
end

local function InstallExperienceFilter()
    if originalAddXpEntry then
        return
    end

    originalAddXpEntry = ZO_LootHistory_Shared.AddXpEntry
    ZO_LootHistory_Shared.AddXpEntry = function(self, ...)
        if Nirnsteel_UI.Settings
            and Nirnsteel_UI.Settings:IsLootHistoryEnabled()
            and Nirnsteel_UI.Settings:ShouldFilterLootHistoryExperience() then
            return
        end

        return originalAddXpEntry(self, ...)
    end
end

function LootHistory:PatchHistory(lootHistory, descriptor)
    if not lootHistory or lootHistory.nirnsteelPatched then
        return lootHistory and lootHistory.nirnsteelPatched
    end

    -- U51 streams are anchored to their movable native HUD control.
    for _,stream in ipairs({lootHistory.lootStream,lootHistory.lootStreamPersistent}) do
        stream.nirnsteelNativeAnchor = stream.nirnsteelNativeAnchor or stream.anchor
    end
    local normalPatched = CopyTemplateBehavior(lootHistory.lootStream, descriptor.templateName, descriptor.stockTemplateName)
    local persistentPatched = CopyTemplateBehavior(lootHistory.lootStreamPersistent, descriptor.templateName, descriptor.stockTemplateName)
    local legacyNormalPatched = CopyTemplateBehavior(lootHistory.lootStream, GetLegacyTemplateName(descriptor), descriptor.stockTemplateName)
    local legacyPersistentPatched = CopyTemplateBehavior(lootHistory.lootStreamPersistent, GetLegacyTemplateName(descriptor), descriptor.stockTemplateName)
    if not normalPatched or not persistentPatched or not legacyNormalPatched or not legacyPersistentPatched then
        return false
    end

    lootHistory.entryTemplate = GetEntryTemplateName(descriptor)
    InstallExperienceFilter()
    ApplyLootHistoryAnchor(lootHistory)

    if lootHistory.lootStream then
        InstallSequentialReveal(lootHistory.lootStream)
        lootHistory.lootStream:SetContainerShowTime(3100)
        lootHistory.lootStream:SetAdditionalEntrySpacingY(GetEntrySpacing())
    end

    if lootHistory.lootStreamPersistent then
        InstallSequentialReveal(lootHistory.lootStreamPersistent)
        lootHistory.lootStreamPersistent:SetContainerShowTime(5600)
        lootHistory.lootStreamPersistent:SetAdditionalEntrySpacingY(GetEntrySpacing())
    end

    lootHistory.nirnsteelPatched = true
    return true
end

function LootHistory:PatchHistories()
    local allReadyAndPatched = true
    local patchedAny = false

    for _, descriptor in ipairs(HISTORY_DESCRIPTORS) do
        local lootHistory = descriptor.getHistory()
        if lootHistory then
            local wasPatched = lootHistory.nirnsteelPatched == true
            if self:PatchHistory(lootHistory, descriptor) then
                patchedAny = patchedAny or not wasPatched
            else
                allReadyAndPatched = false
            end
        else
            allReadyAndPatched = false
        end
    end

    if patchedAny then
        self:ApplySettings()
    end

    return allReadyAndPatched
end

function LootHistory:PatchKeyboardHistory()
    local patched = self:PatchHistory(LOOT_HISTORY_KEYBOARD, HISTORY_DESCRIPTORS[1])
    if patched then
        self:ApplySettings()
    end
    return patched
end

function LootHistory:StartPatchWhenReady()
    local attempts = 0
    EVENT_MANAGER:RegisterForUpdate(PATCH_UPDATE_NAME, PATCH_RETRY_MS, function()
        attempts = attempts + 1
        if self:PatchHistories() or attempts >= MAX_PATCH_ATTEMPTS then
            EVENT_MANAGER:UnregisterForUpdate(PATCH_UPDATE_NAME)
        end
    end)
end

-- Native geometry keeps the metalwork crisp at every loot-history scale.
local function CreateLootOrnament(parent, width, height, x, y, points, color, level)
    local shape = WINDOW_MANAGER:CreateControl(nil, parent, CT_POLYGON)
    shape:SetDimensions(width, height)
    shape:SetAnchor(CENTER, parent, CENTER, x, y)
    shape:SetMouseEnabled(false)
    shape:SetDrawLayer(DL_BACKGROUND)
    shape:SetDrawLevel(level + 10)
    shape:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
    shape:SetSmoothingEnabled(false)
    for _, point in ipairs(points) do
        shape:AddPoint(point[1], point[2])
    end
    shape:SetCenterColor(unpack(color))
    return shape
end

local function InitializeVisualControls(control)
    control.rarityGlow = control:GetNamedChild("RarityGlow")
    control.rarityBurst = control:GetNamedChild("RarityBurst")
    control.glass = control:GetNamedChild("Glass")
    control.iconFrame = control:GetNamedChild("IconFrame")
    control.rarityAccent = control:GetNamedChild("RarityAccent")
    local frame = control.iconFrame
    local wingOffsetX = 33
    PositionStatusIcon(control)
    local shield = { {0.18, 0}, {0.82, 0}, {1, 0.18}, {1, 0.77}, {0.5, 1}, {0, 0.77}, {0, 0.18} }
    local diamond = { {0.5, 0}, {1, 0.5}, {0.5, 1}, {0, 0.5} }
    CreateLootOrnament(frame, 62, 62, 0, 2, shield, {0.01, 0.012, 0.015, 0.8}, 0)
    CreateLootOrnament(frame, 58, 58, 0, 0, shield, {0.52, 0.44, 0.29, 1}, 1)
    CreateLootOrnament(frame, 54, 54, 0, 0, shield, {0.17, 0.20, 0.22, 1}, 2)
    CreateLootOrnament(frame, 48, 48, 0, -1, shield, {0.025, 0.032, 0.038, 1}, 3)
    control.ornamentInlays = {}
    for _, y in ipairs({ -27, 26 }) do
        table.insert(control.ornamentInlays,
            CreateLootOrnament(frame, 7, 7, 0, y, diamond, {1, 0.8, 0.4, 1}, 4))
    end
    -- Small swept wings connect the shield to the ribbon, without boxing the row.
    for _, side in ipairs({ -1, 1 }) do
        local wing = { {0, 0.5}, {1, 0}, {0.75, 0.5}, {1, 1} }
        if side == 1 then
            wing = { {0, 0}, {1, 0.5}, {0, 1}, {0.25, 0.5} }
        end
        table.insert(control.ornamentInlays,
            CreateLootOrnament(frame, 10, 25, side * wingOffsetX, 0, wing, {0.7, 0.6, 0.4, 1}, 2))
    end
end

function Nirnsteel_UI_LootHistory_Entry_OnInitialized(control)
    ZO_LootHistory_Shared_OnInitialized(control)
    InitializeVisualControls(control)
end

function Nirnsteel_UI_LootHistory_GamepadEntry_OnInitialized(control)
    ZO_LootHistory_Shared_OnInitialized(control)
    if ZO_LootHistory_GamepadEntry_OnInitialized then
        ZO_LootHistory_GamepadEntry_OnInitialized(control)
    end
    InitializeVisualControls(control)
end

function Nirnsteel_UI_LootHistory_Legacy_Entry_OnInitialized(control)
    ZO_LootHistory_Shared_OnInitialized(control)
    control.nirnsteelLegacyStyle = true
    control.rarityGlow = control:GetNamedChild("RarityGlow")
    control.rarityBurst = control:GetNamedChild("RarityBurst")
    control.glass = control:GetNamedChild("Glass")
    control.iconFrame = control:GetNamedChild("IconFrame")
end

function Nirnsteel_UI_LootHistory_Legacy_GamepadEntry_OnInitialized(control)
    ZO_LootHistory_Shared_OnInitialized(control)
    if ZO_LootHistory_GamepadEntry_OnInitialized then
        ZO_LootHistory_GamepadEntry_OnInitialized(control)
    end
    control.nirnsteelLegacyStyle = true
    control.rarityGlow = control:GetNamedChild("RarityGlow")
    control.rarityBurst = control:GetNamedChild("RarityBurst")
    control.glass = control:GetNamedChild("Glass")
    control.iconFrame = control:GetNamedChild("IconFrame")
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    LootHistory:StartPatchWhenReady()
    RegisterDebugCommands()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

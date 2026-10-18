SoraSorcReticleTracker = {}
local SSRT = SoraSorcReticleTracker

local ADDON_NAME = "SoraSorcReticleTracker"
local SAVED_VARS = "SoraSorcReticleTrackerSavedVariables"
local SAVED_VARS_VERSION = 2

local CRYSTAL_FRAGMENTS_PROC_EFFECT_ID = 46327
local BOUND_ARMAMENTS_ABILITY_ID = 24165
local BOUND_ARMAMENTS_STACK_EFFECT_ID = 203447

local MAELSTROM_MERCILESS_CHARGE = {
    [369] = true,
    [522] = true,
}
local MAELSTROM_CRUSHING_WALL = {
    [373] = true,
    [526] = true,
}
local MAELSTROM_THUNDEROUS_VOLLEY = {
    [372] = true,
    [525] = true,
}

local STAMPEDE_IDS = {
    [38794] = true,
    [38791] = true,
}
local BLOCKADE_IDS = {
    [39011] = true,
    [39012] = true,
    [39018] = true,
    [39028] = true,
    [39053] = true,
    [39073] = true,
}
local UNSTABLE_WALL_IDS = {
    [39052] = true,
    [39045] = true,
    [39061] = true,
    [39067] = true,
    [39071] = true,
}
local ENDLESS_HAIL_IDS = {
    [38692] = true,
    [38689] = true,
}

local STAMPEDE_TEXTURE_TOKEN = "ability_2handed_003_a"
local ENDLESS_HAIL_TEXTURE_TOKEN = "ability_bow_003_a"
local BLOCKADE_TEXTURE_TOKEN = "ability_destructionstaff_002a"
local UNSTABLE_WALL_TEXTURE_TOKEN = "ability_destructionstaff_002b"

local ARMORY_ICON_FORMAT = "EsoUI/Art/Armory/BuildIcons/buildIcon_%d.dds"
local CRYSTAL_ARMORY_ICON_INDEX = 20
local BOUND_ARMORY_ICON_INDEX = 39

local SLOT_FIRST = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_LAST = SLOT_FIRST + 4
local defaults = {
    crystalOffsetX = -78,
    crystalOffsetY = 0,
    boundOffsetX = 78,
    boundOffsetY = 0,

    crystalIconSize = 78,
    crystalTextSize = 35,

    boundIconSize = 94,
    boundTextSize = 35,

    maelstromEnabled = true,
    maelstromStampedeEnabled = true,
    maelstromWallEnabled = true,
    maelstromHailEnabled = true,
    maelstromOffsetX = 0,
    maelstromOffsetY = 96,
    maelstromTextSize = 28,
}


SSRT.crystalActive = false
SSRT.crystalEndTime = 0
SSRT.boundStacks = 0
SSRT.maelstromKind = nil
SSRT.maelstromSlot = nil
SSRT.maelstromTexture = nil
SSRT.moveTarget = nil

local function Chat(text)
    d("|c66ccff[SoraSorcReticleTracker]|r " .. tostring(text))
end

local function BuildFont(size)
    return string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(size))
end

local function GetArmoryIconTexture(index)
    return string.format(ARMORY_ICON_FORMAT, index)
end

local function ApplyIconTextures()
    if SSRT.crystalIcon then
        local texture = GetArmoryIconTexture(CRYSTAL_ARMORY_ICON_INDEX)
        SSRT.crystalGlowOuter:SetTexture(texture)
        SSRT.crystalGlowMid:SetTexture(texture)
        SSRT.crystalIcon:SetTexture(texture)
    end

    if SSRT.boundIcon then
        local texture = GetArmoryIconTexture(BOUND_ARMORY_ICON_INDEX)
        SSRT.boundGlowOuter:SetTexture(texture)
        SSRT.boundGlowMid:SetTexture(texture)
        SSRT.boundIcon:SetTexture(texture)
    end
end

local function SetBoundStackColor(stacks)
    if not SSRT.boundStack then return end
    if stacks >= 4 then
        SSRT.boundStack:SetColor(1.00, 0.22, 0.18, 1.00)
    elseif stacks == 3 then
        SSRT.boundStack:SetColor(1.00, 0.78, 0.08, 1.00)
    else
        SSRT.boundStack:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function ApplyCrystalPosition()
    SSRT.crystalWindow:ClearAnchors()
    SSRT.crystalWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.crystalOffsetX,
        SSRT.sv.crystalOffsetY
    )
end

local function ApplyBoundPosition()
    SSRT.boundWindow:ClearAnchors()
    SSRT.boundWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.boundOffsetX,
        SSRT.sv.boundOffsetY
    )
end


local function ApplyMaelstromPosition()
    SSRT.maelstromWindow:ClearAnchors()
    SSRT.maelstromWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.maelstromOffsetX,
        SSRT.sv.maelstromOffsetY
    )
end

local function SaveControlOffset(controlName)
    local control
    if controlName == "crystal" then
        control = SSRT.crystalWindow
    elseif controlName == "bound" then
        control = SSRT.boundWindow
    else
        control = SSRT.maelstromWindow
    end

    local x, y = control:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    if not (x and y and gx and gy) then return end

    if controlName == "crystal" then
        SSRT.sv.crystalOffsetX = zo_round(x - gx)
        SSRT.sv.crystalOffsetY = zo_round(y - gy)
        ApplyCrystalPosition()
    elseif controlName == "bound" then
        SSRT.sv.boundOffsetX = zo_round(x - gx)
        SSRT.sv.boundOffsetY = zo_round(y - gy)
        ApplyBoundPosition()
    else
        SSRT.sv.maelstromOffsetX = zo_round(x - gx)
        SSRT.sv.maelstromOffsetY = zo_round(y - gy)
        ApplyMaelstromPosition()
    end
end

local function ApplyVisualSettings()
    -- Crystal
    local crystalSize = SSRT.sv.crystalIconSize
    local crystalWindowSize = math.max(126, crystalSize + 44)
    SSRT.crystalWindow:SetDimensions(crystalWindowSize, crystalWindowSize)

    SSRT.crystalGlowOuter:SetDimensions(crystalSize + 30, crystalSize + 30)
    SSRT.crystalGlowMid:SetDimensions(crystalSize + 14, crystalSize + 14)
    SSRT.crystalIcon:SetDimensions(crystalSize, crystalSize)

    SSRT.crystalTimer:SetDimensions(crystalSize + 16, crystalSize + 16)
    SSRT.crystalTimer:SetFont(BuildFont(SSRT.sv.crystalTextSize))
    SSRT.crystalTimer:ClearAnchors()
    SSRT.crystalTimer:SetAnchor(CENTER, SSRT.crystalWindow, CENTER, 0, 0)

    -- Bound
    local boundSize = SSRT.sv.boundIconSize
    local boundWindowSize = math.max(132, boundSize + 52)
    SSRT.boundWindow:SetDimensions(boundWindowSize, boundWindowSize)

    SSRT.boundGlowOuter:SetDimensions(boundSize + 30, boundSize + 30)
    SSRT.boundGlowMid:SetDimensions(boundSize + 14, boundSize + 14)
    SSRT.boundIcon:SetDimensions(boundSize, boundSize)

    SSRT.boundStack:SetDimensions(boundSize + 16, boundSize + 16)
    SSRT.boundStack:SetFont(BuildFont(SSRT.sv.boundTextSize))
    SSRT.boundStack:ClearAnchors()
    SSRT.boundStack:SetAnchor(CENTER, SSRT.boundWindow, CENTER, 0, 0)

    -- Maelstrom back-bar timer: text only.
    local maelstromTextSize = SSRT.sv.maelstromTextSize
    local maelstromWindowWidth = math.max(72, maelstromTextSize * 2.5)
    local maelstromWindowHeight = math.max(54, maelstromTextSize * 1.8)
    SSRT.maelstromWindow:SetDimensions(maelstromWindowWidth, maelstromWindowHeight)
    SSRT.maelstromTimer:SetDimensions(maelstromWindowWidth, maelstromWindowHeight)
    SSRT.maelstromTimer:SetFont(BuildFont(maelstromTextSize))
    SSRT.maelstromTimer:ClearAnchors()
    SSRT.maelstromTimer:SetAnchor(CENTER, SSRT.maelstromWindow, CENTER, 0, 0)

    SetBoundStackColor(SSRT.boundStacks or 0)
    ApplyIconTextures()
end

local function SetMoveTarget(target)
    SSRT.moveTarget = target

    local crystalActive = target == "crystal"
    local boundActive = target == "bound"
    local maelstromActive = target == "maelstrom"

    SSRT.crystalWindow:SetMouseEnabled(crystalActive)
    SSRT.crystalWindow:SetMovable(crystalActive)
    SSRT.boundWindow:SetMouseEnabled(boundActive)
    SSRT.boundWindow:SetMovable(boundActive)
    SSRT.maelstromWindow:SetMouseEnabled(maelstromActive)
    SSRT.maelstromWindow:SetMovable(maelstromActive)

    SSRT.crystalDragBackdrop:SetHidden(not crystalActive)
    SSRT.boundDragBackdrop:SetHidden(not boundActive)
    SSRT.maelstromDragBackdrop:SetHidden(not maelstromActive)

    if crystalActive then
        SSRT.crystalWindow:SetHidden(false)
        SSRT.crystalTimer:SetText("6")
        SSRT.crystalActive = true
        SSRT.crystalEndTime = GetFrameTimeSeconds() + 6
        Chat("Crystal move mode ON")
    elseif boundActive then
        SSRT.boundWindow:SetHidden(false)
        SSRT.boundStacks = 5
        SSRT.boundStack:SetText("5")
        SetBoundStackColor(5)
        Chat("Bound move mode ON")
    elseif maelstromActive then
        SSRT.maelstromWindow:SetHidden(false)
        SSRT.maelstromTimer:SetText("5")
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
        Chat("Maelstrom timer move mode ON")
    else
        Chat("Move mode OFF")
    end
end

local function ResetPositions()
    SSRT.sv.crystalOffsetX = defaults.crystalOffsetX
    SSRT.sv.crystalOffsetY = defaults.crystalOffsetY
    SSRT.sv.boundOffsetX = defaults.boundOffsetX
    SSRT.sv.boundOffsetY = defaults.boundOffsetY
    SSRT.sv.maelstromOffsetX = defaults.maelstromOffsetX
    SSRT.sv.maelstromOffsetY = defaults.maelstromOffsetY

    ApplyCrystalPosition()
    ApplyBoundPosition()
    ApplyMaelstromPosition()
end

local function CreateCrystalWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SSRTCrystalWindow")
    SSRT.crystalWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.02, 0.12, 0.16, 0.22)
    dragBackdrop:SetEdgeColor(0.20, 0.80, 1.00, 0.75)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.crystalDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.08, 0.75, 1.00, 0.18)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.crystalGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.18, 0.90, 1.00, 0.42)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.crystalGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.60, 0.93, 1.00, 1.00)
    SSRT.crystalIcon = icon

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.crystalTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("crystal")
    end)

    SSRT.crystalFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.crystalFragment)
    HUD_UI_SCENE:AddFragment(SSRT.crystalFragment)
end

local function CreateBoundWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SSRTBoundWindow")
    SSRT.boundWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.12, 0.04, 0.18, 0.20)
    dragBackdrop:SetEdgeColor(0.72, 0.36, 1.00, 0.80)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.boundDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.45, 0.08, 1.00, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.boundGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.68, 0.28, 1.00, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.boundGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.88, 0.72, 1.00, 1.00)
    SSRT.boundIcon = icon

    local stack = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    stack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stack:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stack:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.boundStack = stack

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("bound")
    end)

    SSRT.boundFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.boundFragment)
    HUD_UI_SCENE:AddFragment(SSRT.boundFragment)
end


local function CreateMaelstromWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SSRTMaelstromWindow")
    SSRT.maelstromWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.10, 0.08, 0.02, 0.22)
    dragBackdrop:SetEdgeColor(1.00, 0.74, 0.20, 0.78)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.maelstromDragBackdrop = dragBackdrop

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.maelstromTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("maelstrom")
    end)

    SSRT.maelstromFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.maelstromFragment)
    HUD_UI_SCENE:AddFragment(SSRT.maelstromFragment)
end

local function ScanCrystalProc()
    local now = GetFrameTimeSeconds()
    local active = false
    local endTime = 0

    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, buffEndTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if abilityId == CRYSTAL_FRAGMENTS_PROC_EFFECT_ID then
            active = true
            endTime = tonumber(buffEndTime) or 0
            break
        end
    end

    SSRT.crystalActive = active and endTime > now
    SSRT.crystalEndTime = SSRT.crystalActive and endTime or 0
end

local function IsBoundArmamentsSlot(slotIndex, hotbarCategory)
    local abilityId = GetSlotBoundId(slotIndex, hotbarCategory)
    if abilityId == BOUND_ARMAMENTS_ABILITY_ID then
        return true
    end
    if abilityId and abilityId ~= 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        return GetEffectiveAbilityIdForAbilityOnHotbar(abilityId, hotbarCategory) == BOUND_ARMAMENTS_ABILITY_ID
    end
    return false
end

local function ScanBoundBuffStacks()
    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if abilityId == BOUND_ARMAMENTS_STACK_EFFECT_ID then
            return math.max(0, tonumber(stackCount) or 0)
        end
    end
    return 0
end

local function ScanBoundStacks()
    local best = 0
    local categories = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }

    if type(GetActionSlotEffectStackCount) == "function" then
        for _, hotbarCategory in ipairs(categories) do
            for slotIndex = SLOT_FIRST, SLOT_LAST do
                if IsBoundArmamentsSlot(slotIndex, hotbarCategory) then
                    local stacks = tonumber(GetActionSlotEffectStackCount(slotIndex, hotbarCategory)) or 0
                    if stacks > best then
                        best = stacks
                    end
                end
            end
        end
    end

    if best <= 0 then
        best = ScanBoundBuffStacks()
    end

    SSRT.boundStacks = math.max(0, best)
end

local function GetEquippedSetId(equipSlot)
    local itemLink = GetItemLink(BAG_WORN, equipSlot, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then return 0 end

    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink)
    if not hasSet then return 0 end
    return tonumber(setId) or 0
end

local function GetBackbarArenaKind()
    local setId = GetEquippedSetId(EQUIP_SLOT_BACKUP_MAIN)
    if setId == 0 then
        setId = GetEquippedSetId(EQUIP_SLOT_BACKUP_OFF)
    end

    if MAELSTROM_MERCILESS_CHARGE[setId] and SSRT.sv.maelstromStampedeEnabled then
        return "stampede"
    end

    if MAELSTROM_CRUSHING_WALL[setId] and SSRT.sv.maelstromWallEnabled then
        return "wall"
    end

    if MAELSTROM_THUNDEROUS_VOLLEY[setId] and SSRT.sv.maelstromHailEnabled then
        return "hail"
    end

    return nil
end

local function IdMatches(id, idSet)
    return id ~= nil and id ~= 0 and idSet[id] == true
end

local function TextureMatches(texture, token)
    if not texture or texture == "" or not token then return false end
    return zo_strlower(texture):find(token, 1, true) ~= nil
end

local function GetSlotIds(slotIndex)
    local hotbarCategory = HOTBAR_CATEGORY_BACKUP
    local boundId = GetSlotBoundId(slotIndex, hotbarCategory) or 0
    local effectiveId = boundId

    if boundId ~= 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        effectiveId = GetEffectiveAbilityIdForAbilityOnHotbar(boundId, hotbarCategory) or boundId
    end

    return boundId, effectiveId
end

local function IsTrackedMaelstromSkill(slotIndex, kind)
    local boundId, effectiveId = GetSlotIds(slotIndex)
    local texture = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_BACKUP) or ""

    if kind == "stampede" then
        return IdMatches(boundId, STAMPEDE_IDS)
            or IdMatches(effectiveId, STAMPEDE_IDS)
            or TextureMatches(texture, STAMPEDE_TEXTURE_TOKEN)
    elseif kind == "wall" then
        return IdMatches(boundId, BLOCKADE_IDS)
            or IdMatches(effectiveId, BLOCKADE_IDS)
            or IdMatches(boundId, UNSTABLE_WALL_IDS)
            or IdMatches(effectiveId, UNSTABLE_WALL_IDS)
            or TextureMatches(texture, BLOCKADE_TEXTURE_TOKEN)
            or TextureMatches(texture, UNSTABLE_WALL_TEXTURE_TOKEN)
    elseif kind == "hail" then
        return IdMatches(boundId, ENDLESS_HAIL_IDS)
            or IdMatches(effectiveId, ENDLESS_HAIL_IDS)
            or TextureMatches(texture, ENDLESS_HAIL_TEXTURE_TOKEN)
    end

    return false
end

local function RefreshMaelstromBinding()
    SSRT.maelstromKind = nil
    SSRT.maelstromSlot = nil
    SSRT.maelstromTexture = nil

    if not SSRT.sv.maelstromEnabled then
        return
    end

    local kind = GetBackbarArenaKind()
    if not kind then
        return
    end

    for slotIndex = SLOT_FIRST, SLOT_LAST do
        if IsTrackedMaelstromSkill(slotIndex, kind) then
            SSRT.maelstromKind = kind
            SSRT.maelstromSlot = slotIndex
            SSRT.maelstromTexture = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_BACKUP)
            return
        end
    end
end

local function ReadMaelstromTimer()
    if not SSRT.sv.maelstromEnabled
        or not SSRT.maelstromKind
        or not SSRT.maelstromSlot then
        return 0, 0
    end

    local remainingMs = GetActionSlotEffectTimeRemaining(
        SSRT.maelstromSlot,
        HOTBAR_CATEGORY_BACKUP
    ) or 0

    local durationMs = GetActionSlotEffectDuration(
        SSRT.maelstromSlot,
        HOTBAR_CATEGORY_BACKUP
    ) or 0

    if remainingMs <= 0 and GetActiveHotbarCategory() == HOTBAR_CATEGORY_BACKUP then
        remainingMs = GetActionSlotEffectTimeRemaining(SSRT.maelstromSlot) or 0
        durationMs = GetActionSlotEffectDuration(SSRT.maelstromSlot) or durationMs
    end

    return math.max(0, remainingMs), math.max(0, durationMs)
end

local function RefreshState()
    ScanCrystalProc()
    ScanBoundStacks()
    RefreshMaelstromBinding()
end

local function FormatCrystalTime(seconds)
    seconds = math.max(0, seconds)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end


local function FormatMaelstromTime(milliseconds)
    local seconds = math.max(0, milliseconds / 1000)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end


local function SetMaelstromTimerColor(milliseconds)
    local seconds = math.max(0, milliseconds / 1000)

    if seconds <= 2 then
        SSRT.maelstromTimer:SetColor(1.00, 0.24, 0.18, 1.00)
    elseif seconds <= 5 then
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
    else
        SSRT.maelstromTimer:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function UpdateUI()
    local now = GetFrameTimeSeconds()

    if SSRT.moveTarget ~= "crystal" then
        if SSRT.crystalActive and SSRT.crystalEndTime > now then
            SSRT.crystalWindow:SetHidden(false)
            SSRT.crystalTimer:SetText(FormatCrystalTime(SSRT.crystalEndTime - now))
        else
            SSRT.crystalWindow:SetHidden(true)
        end
    else
        SSRT.crystalWindow:SetHidden(false)
        SSRT.crystalTimer:SetText("6")
    end

    if SSRT.moveTarget ~= "bound" then
        if (SSRT.boundStacks or 0) > 0 then
            SSRT.boundWindow:SetHidden(false)
            SSRT.boundStack:SetText(tostring(SSRT.boundStacks))
            SetBoundStackColor(SSRT.boundStacks)
        else
            SSRT.boundWindow:SetHidden(true)
        end
    else
        SSRT.boundWindow:SetHidden(false)
        SSRT.boundStack:SetText("5")
        SetBoundStackColor(5)
    end

    if SSRT.moveTarget ~= "maelstrom" then
        local remainingMs = ReadMaelstromTimer()

        if remainingMs > 0 then
            SSRT.maelstromWindow:SetHidden(false)
            SSRT.maelstromTimer:SetText(FormatMaelstromTime(remainingMs))
            SetMaelstromTimerColor(remainingMs)
        else
            SSRT.maelstromWindow:SetHidden(true)
        end
    else
        SSRT.maelstromWindow:SetHidden(false)
        SSRT.maelstromTimer:SetText("5")
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
    end
end

local function RegisterSettings()
    local LAM = LibAddonMenu2
    local panelName = ADDON_NAME .. "Options"

    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Sora Sorc Reticle Tracker",
        displayName = "Sora Sorc Reticle Tracker",
        author = "Sora",
        version = "0.5.1",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "header",
            name = "Crystal Fragments",
        },
        {
            type = "slider",
            name = "Crystal icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.crystalIconSize end,
            setFunc = function(value)
                SSRT.sv.crystalIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.crystalIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Crystal timer size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.crystalTextSize end,
            setFunc = function(value)
                SSRT.sv.crystalTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.crystalTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Crystal Fragments",
            func = function() SetMoveTarget("crystal") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset Crystal position",
            func = function()
                SSRT.sv.crystalOffsetX = defaults.crystalOffsetX
                SSRT.sv.crystalOffsetY = defaults.crystalOffsetY
                ApplyCrystalPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Bound Armaments",
        },
        {
            type = "slider",
            name = "Bound icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.boundIconSize end,
            setFunc = function(value)
                SSRT.sv.boundIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.boundIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Bound stack text size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.boundTextSize end,
            setFunc = function(value)
                SSRT.sv.boundTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.boundTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Bound Armaments",
            func = function() SetMoveTarget("bound") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset Bound position",
            func = function()
                SSRT.sv.boundOffsetX = defaults.boundOffsetX
                SSRT.sv.boundOffsetY = defaults.boundOffsetY
                ApplyBoundPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Maelstrom back-bar timer",
        },
        {
            type = "checkbox",
            name = "Enable Maelstrom timer",
            tooltip = "Shows the tracked back-bar ground skill timer only when the matching Maelstrom arena weapon is equipped on the backup weapon bar.",
            getFunc = function() return SSRT.sv.maelstromEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromEnabled = value
                RefreshMaelstromBinding()
            end,
            default = defaults.maelstromEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Merciless Charge — Stampede",
            getFunc = function() return SSRT.sv.maelstromStampedeEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromStampedeEnabled = value
                RefreshMaelstromBinding()
            end,
            default = defaults.maelstromStampedeEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Crushing Wall — Blockade / Unstable Wall",
            getFunc = function() return SSRT.sv.maelstromWallEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromWallEnabled = value
                RefreshMaelstromBinding()
            end,
            default = defaults.maelstromWallEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Thunderous Volley — Endless Hail",
            getFunc = function() return SSRT.sv.maelstromHailEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromHailEnabled = value
                RefreshMaelstromBinding()
            end,
            default = defaults.maelstromHailEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = "Maelstrom timer text size",
            min = 14,
            max = 52,
            step = 1,
            getFunc = function() return SSRT.sv.maelstromTextSize end,
            setFunc = function(value)
                SSRT.sv.maelstromTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.maelstromTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Maelstrom timer",
            func = function() SetMoveTarget("maelstrom") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset Maelstrom position",
            func = function()
                SSRT.sv.maelstromOffsetX = defaults.maelstromOffsetX
                SSRT.sv.maelstromOffsetY = defaults.maelstromOffsetY
                ApplyMaelstromPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "General",
        },
        {
            type = "button",
            name = "Stop move mode",
            func = function() SetMoveTarget(nil) end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset all positions",
            func = function() ResetPositions() end,
            width = "half",
        },
    })
end

local function HandleSlash(text)
    text = zo_strlower((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if text == "crystal" or text == "cmove" then
        SetMoveTarget("crystal")
    elseif text == "bound" or text == "bmove" then
        SetMoveTarget("bound")
    elseif text == "maelstrom" or text == "mmove" then
        SetMoveTarget("maelstrom")
    elseif text == "stop" then
        SetMoveTarget(nil)
    elseif text == "reset" then
        ResetPositions()
        Chat("All positions reset.")
    else
        Chat("/ssrt crystal  /ssrt bound  /ssrt maelstrom  /ssrt stop  /ssrt reset")
    end
end

local function OnCrystalEffectChanged(_, changeType, _, _, unitTag, _, endTime, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or abilityId ~= CRYSTAL_FRAGMENTS_PROC_EFFECT_ID then
        return
    end

    if changeType == EFFECT_RESULT_FADED then
        SSRT.crystalActive = false
        SSRT.crystalEndTime = 0
    else
        SSRT.crystalActive = true
        SSRT.crystalEndTime = tonumber(endTime) or 0
    end
end

local function OnBoundEffectChanged(_, _, _, _, unitTag, _, _, stackCount, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or abilityId ~= BOUND_ARMAMENTS_STACK_EFFECT_ID then
        return
    end

    SSRT.boundStacks = math.max(0, tonumber(stackCount) or 0)
end

local function OnPlayerActivated()
    zo_callLater(RefreshState, 300)
end

local function OnActionStateChanged()
    zo_callLater(function()
        ScanBoundStacks()
        RefreshMaelstromBinding()
    end, 50)
end

local function OnWornInventoryChanged()
    zo_callLater(RefreshMaelstromBinding, 100)
end

local function Initialize()
    SSRT.sv = ZO_SavedVars:NewAccountWide(
        SAVED_VARS,
        SAVED_VARS_VERSION,
        GetWorldName(),
        defaults
    )

    CreateCrystalWindow()
    CreateBoundWindow()
    CreateMaelstromWindow()
    ApplyCrystalPosition()
    ApplyBoundPosition()
    ApplyMaelstromPosition()
    ApplyVisualSettings()
    RegisterSettings()

    SLASH_COMMANDS["/ssrt"] = HandleSlash

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Crystal", EVENT_EFFECT_CHANGED, OnCrystalEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Crystal",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, CRYSTAL_FRAGMENTS_PROC_EFFECT_ID,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Bound", EVENT_EFFECT_CHANGED, OnBoundEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Bound",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, BOUND_ARMAMENTS_STACK_EFFECT_ID,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOT_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActionStateChanged)

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "Gear",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        OnWornInventoryChanged
    )
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Gear",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_WORN
    )

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Display", 100, UpdateUI)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "BoundFallback", 500, ScanBoundStacks)

    zo_callLater(RefreshState, 500)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Ultimate module, migrated from SRT v1.7.54 TEST.
-- HUD behavior is inherited, not retested in game in this new addon.
local SSRT = SoraReticleTracker
SSRT.Ultimate = SSRT.Ultimate or {}

local ULTIMATE_FRONT_COLOR = {
    fill = {0.95, 0.48, 0.08, 0.82},
    edge = {1.00, 0.66, 0.18, 0.98},
    glow = {1.00, 0.74, 0.28, 0.55},
    readyText = {1.00, 0.47, 0.06, 1.00}, -- stronger orange, readable with black outline
}
local ULTIMATE_BACK_COLOR = {
    fill = {0.56, 0.24, 0.90, 0.82},
    edge = {0.82, 0.52, 1.00, 0.98},
    glow = {0.90, 0.66, 1.00, 0.55},
    readyText = {0.67, 0.28, 0.95, 1.00}, -- stronger violet, readable with black outline
}
local ULTIMATE_SHARED_COLOR = {
    -- Preserve the proven rounded base frame even if the optional gradient
    -- texture is unavailable in a particular ESO client. The gradient is
    -- applied as a separate layer above this fallback base.
    fill = {0.49, 0.22, 0.46, 0.93},
    edge = {1.00, 0.61, 0.86, 0.98},
    glow = {0.96, 0.62, 0.89, 0.52},
    readyText = {1.00, 0.48, 0.80, 1.00},
    idleText = {1.00, 0.75, 0.88, 1.00},
}
local ULTIMATE_SIGNET_COLOR = {
    fill = {0.30, 0.22, 0.24, 0.86},
    edge = {0.73, 0.42, 0.46, 0.96},
    glow = {0.82, 0.44, 0.48, 0.32},
    readyText = {0.94, 0.76, 0.79, 1.00},
}
-- Shattered Paths Signet (mythic set ID, not an item ID).
-- Confirm set 848 with GetItemSetInfo(848) on the live ESO client before release.
local SHATTERED_PATHS_SIGNET_SET_ID = 848


local function GetUltimateCurrentValue()
    if not GetUnitPower then return 0 end
    local ok, current = pcall(function() return GetUnitPower("player", POWERTYPE_ULTIMATE) end)
    current = ok and current or 0
    return math.floor((tonumber(current) or 0) + 0.5)
end

local function GetUltimateSlotInfoForCategory(category)
    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX or 7
    category = category or HOTBAR_CATEGORY_PRIMARY
    local slotIndex = ultimateSlot + 1
    local abilityId = GetSlotBoundId and (GetSlotBoundId(slotIndex, category) or 0) or 0
    if abilityId == 0 then
        slotIndex = ultimateSlot
        abilityId = GetSlotBoundId and (GetSlotBoundId(slotIndex, category) or 0) or 0
    end
    return slotIndex, category, abilityId or 0
end

local function TryGetUltimateAbilityCost(abilityId)
    if not abilityId or abilityId == 0 or not GetAbilityCost then return 0 end
    local function Extract(ok, a, b, c)
        if not ok then return 0 end
        if type(a) == "number" and a > 0 then return math.floor(a + 0.5) end
        if type(b) == "number" and b > 0 then return math.floor(b + 0.5) end
        if type(c) == "number" and c > 0 then return math.floor(c + 0.5) end
        return 0
    end
    if COMBAT_MECHANIC_FLAGS_ULTIMATE ~= nil then
        local ok, a, b, c = pcall(GetAbilityCost, abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE)
        local cost = Extract(ok, a, b, c)
        if cost > 0 then return cost end
    end
    local ok, a, b, c = pcall(GetAbilityCost, abilityId)
    return Extract(ok, a, b, c)
end

local function TryGetUltimateSlotCost(slotIndex, category)
    if not slotIndex or not category or not GetSlotAbilityCost then return 0 end
    local ok, a, b, c = pcall(GetSlotAbilityCost, slotIndex, category)
    if not ok then return 0 end
    if type(a) == "number" and a > 0 then return math.floor(a + 0.5) end
    if type(b) == "number" and b > 0 then return math.floor(b + 0.5) end
    if type(c) == "number" and c > 0 then return math.floor(c + 0.5) end
    return 0
end

-- Ultimate Pair's existing Warden bear warning: a missing bear exposes a
-- zero-cost bear Ultimate while the assigned slot retains its bear icon.
local function IsWardenBearIcon(icon)
    icon = string.lower(tostring(icon or ""))
    return icon:find("ability_warden_018", 1, true) ~= nil
end

local function GetPetMissingText()
    return (SSRT.L and SSRT.L.petMissing) or "NO PET"
end

local function GetUltimateInfoForCategory(category)
    local slotIndex, hotbarCategory, abilityId = GetUltimateSlotInfoForCategory(category)
    local cost = TryGetUltimateAbilityCost(abilityId)
    if cost <= 0 then cost = TryGetUltimateSlotCost(slotIndex, hotbarCategory) end
    local name = ""
    if slotIndex and hotbarCategory and GetSlotName then
        local ok, result = pcall(GetSlotName, slotIndex, hotbarCategory)
        if ok and result then name = result end
    end
    if (not name or name == "") and abilityId ~= 0 and GetAbilityName then
        local ok, result = pcall(GetAbilityName, abilityId)
        if ok and result then name = result end
    end
    local icon = ""
    if slotIndex and hotbarCategory and GetSlotTexture then
        local ok, result = pcall(GetSlotTexture, slotIndex, hotbarCategory)
        if ok and result then icon = result end
    end
    if icon == "" and abilityId ~= 0 and GetAbilityIcon then
        local ok, result = pcall(GetAbilityIcon, abilityId)
        if ok and result then icon = result end
    end
    return abilityId or 0, cost or 0, name or "", icon or ""
end

local function FormatUltimateCompact(current, cost)
    current = math.floor((tonumber(current) or 0) + 0.5)
    cost = math.floor((tonumber(cost) or 0) + 0.5)
    if cost <= 0 then
        return string.format("%d/???", current)
    end
    return string.format("%d/%d", current, cost)
end

local function RefreshUltimateSignetEquipped()
    local equipped = false
    local count = GetBagSize(BAG_WORN) or 0
    for slotIndex = 0, count - 1 do
        local itemLink = GetItemLink(BAG_WORN, slotIndex, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            -- Set ID is the sixth return value of GetItemLinkSetInfo.
            -- This works independent of the localized item/set name.
            local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, true)
            if hasSet and setId == SHATTERED_PATHS_SIGNET_SET_ID then
                equipped = true
                break
            end
        end
    end
    SSRT.ultimateSignetEquipped = equipped
end


local function ApplyUltimatePosition()
    if not SSRT.ultimateWindow then return end
    SSRT.ultimateWindow:ClearAnchors()
    SSRT.ultimateWindow:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv.ultimateOffsetX or 0, SSRT.sv.ultimateOffsetY or 0)
end


local function SetUltimateFrameColor(row, edgeColor)
    if not row then return end
    row.frame:SetColor(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4] or 1)
end

local function ApplyUltimateVisualSettings()
    if not SSRT.ultimateWindow or not SSRT.ultimateRows then return end
    local scale = math.max(60, math.min(160, SSRT.sv.ultimateScale or 100)) / 100
    -- Same compact dimensions for Ultimate values and short missing-pet notice.
    local rowWidth = zo_round(146 * scale)
    local rowHeight = zo_round(34 * scale)
    local rowGap = zo_round(8 * scale)
    local fontSize = zo_round(24 * scale)
    -- Wider glow footprint plus a fully transparent texture edge: no horizontal hard cut.
    local glowPadX = zo_round(24 * scale)
    local glowPadY = zo_round(10 * scale)
    SSRT.ultimateWindow:SetDimensions(rowWidth, rowHeight * 2 + rowGap)
    for i, row in ipairs(SSRT.ultimateRows) do
        row.container:SetDimensions(rowWidth, rowHeight)
        row.container:ClearAnchors()
        row.container:SetAnchor(TOP, SSRT.ultimateWindow, TOP, 0, (i - 1) * (rowHeight + rowGap))
        row.glow:SetDimensions(rowWidth + 2 * glowPadX, rowHeight + 2 * glowPadY)
        row.label:SetDimensions(rowWidth - zo_round(10 * scale), rowHeight)
        row.textGlow:SetDimensions(rowWidth - zo_round(6 * scale), rowHeight)
        local rimExtra = zo_round(2 * scale)
        row.readyFrame:SetDimensions(rowWidth + rimExtra * 2, rowHeight + rimExtra * 2)
        -- Keep the original rounded frame; only the colored face becomes a fill gauge.
        row.progress:SetDimensions(rowWidth, rowHeight)
        row.sharedGradient:SetDimensions(rowWidth, rowHeight)
        row.normalFont = string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(fontSize))
        row.warningFont = string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(math.max(14, fontSize * 0.74)))
        row.label:SetFont(row.normalFont)
        row.textGlow:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(fontSize + 2 * scale)))
    end
end


local function CreateUltimateRow(parent)
    local row = {}
    local container = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row.container = container

    -- Rounded frame, softened exterior halo and gently illuminated face.
    -- All four textures have real transparent corners; no segmented square borders.
    local glow = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    glow:SetAnchor(CENTER, container, CENTER, 0, 0)
    glow:SetTexture("SoraReticleTracker/textures/ultimate_soft_glow.dds")
    glow:SetBlendMode(TEX_BLEND_MODE_ADD)
    glow:SetHidden(true)
    row.glow = glow

    local bg = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    bg:SetAnchorFill(container)
    bg:SetTexture("SoraReticleTracker/textures/ultimate_round_fill.dds")
    row.bg = bg

    -- Use the SAME rounded texture as the original background, cropped rather
    -- than stretched. This keeps the left rounded edge and preserves the frame.
    local progress = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    progress:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    progress:SetTexture("SoraReticleTracker/textures/ultimate_round_fill.dds")
    progress:SetTextureCoords(0, 1, 0, 1)
    progress:SetHidden(true)
    row.progress = progress

    -- The base fill and frame always use the known-good rounded textures.
    -- Shared Ultimates layer their gradient over this base, rather than
    -- replacing both base textures (which could make the entire box vanish).
    local sharedGradient = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    sharedGradient:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    sharedGradient:SetTexture("SoraReticleTracker/textures/ultimate_shared_round_fill.dds")
    sharedGradient:SetColor(1, 1, 1, 0.86)
    sharedGradient:SetHidden(true)
    row.sharedGradient = sharedGradient

    local mist = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    mist:SetAnchorFill(container)
    mist:SetTexture("SoraReticleTracker/textures/ultimate_surface_mist.dds")
    mist:SetBlendMode(TEX_BLEND_MODE_ADD)
    mist:SetHidden(true)
    row.mist = mist

    local frame = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    frame:SetAnchorFill(container)
    frame:SetTexture("SoraReticleTracker/textures/ultimate_round_outline.dds")
    row.frame = frame

    -- A thin, pulsing outline extension ONLY when this ULT is affordable.
    -- The original frame is retained unchanged below it.
    local readyFrame = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    readyFrame:SetAnchor(CENTER, container, CENTER, 0, 0)
    readyFrame:SetTexture("SoraReticleTracker/textures/ultimate_round_outline.dds")
    readyFrame:SetHidden(true)
    row.readyFrame = readyFrame

    -- A faint larger label behind the original number gives the charged
    -- text a soft halo without moving or replacing the readable number.
    local textGlow = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    textGlow:SetAnchor(CENTER, container, CENTER, 0, 0)
    textGlow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    textGlow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    textGlow:SetDrawLayer(DL_OVERLAY)
    textGlow:SetHidden(true)
    row.textGlow = textGlow

    local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    label:SetAnchor(CENTER, container, CENTER, 0, 0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)
    label:SetDrawLayer(DL_OVERLAY)
    row.label = label
    return row
end

local function CreateUltimateWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTUltimateWindow")
    SSRT.ultimateWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(8)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.08, 0.08, 0.14, 0.18)
    dragBackdrop:SetEdgeColor(0.90, 0.90, 1.00, 0.55)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.ultimateDragBackdrop = dragBackdrop
    SSRT.ultimateRows = { CreateUltimateRow(window), CreateUltimateRow(window) }
    window:SetHandler("OnMoveStop", function()
        local x, y = window:GetCenter()
        local gx, gy = GuiRoot:GetCenter()
        if x and y and gx and gy and SSRT.sv then
            SSRT.sv.ultimateOffsetX = zo_round(x - gx)
            SSRT.sv.ultimateOffsetY = zo_round(y - gy)
            ApplyUltimatePosition()
        end
    end)
    SSRT.ultimateFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.ultimateFragment)
    HUD_UI_SCENE:AddFragment(SSRT.ultimateFragment)
end


-- Gauge is strictly a visual layer: no change to cost lookup, bar switching,
-- Signet lock, Warden bear warning or the existing ready glow.
local function SetUltimateProgress(row, current, cost, palette, signetLock)
    if not row or not row.progress then return end
    local ratio = (tonumber(cost) or 0) > 0 and (tonumber(current) or 0) / cost or 0
    ratio = math.max(0, math.min(1, ratio))
    local scale = math.max(60, math.min(160, SSRT.sv.ultimateScale or 100)) / 100
    local width = zo_round(146 * scale)
    local height = zo_round(34 * scale)
    local fillWidth = math.floor(width * ratio + 0.5)
    if fillWidth < 1 then
        row.progress:SetHidden(true)
        row.sharedGradient:SetHidden(true)
        return
    end
    row.progress:SetHidden(false)
    row.progress:SetDimensions(fillWidth, height)
    row.progress:SetTextureCoords(0, ratio, 0, 1)
    -- Below 50%: quiet tint; 50-99%: normal palette; ready: bright tint.
    local c = signetLock and ULTIMATE_SIGNET_COLOR or palette
    if ratio >= 1 then
        row.progress:SetColor(c.edge[1], c.edge[2], c.edge[3], 0.96)
    elseif ratio >= 0.5 then
        row.progress:SetColor(c.fill[1], c.fill[2], c.fill[3], 0.92)
    else
        row.progress:SetColor(c.fill[1] * 0.64, c.fill[2] * 0.64, c.fill[3] * 0.64, 0.84)
    end
    -- Shared ULT retains its pink gradient only WITHIN the charged portion.
    -- The original fallback progress remains visible if gradient is unavailable.
    local shared = palette == ULTIMATE_SHARED_COLOR and not signetLock
    row.sharedGradient:SetHidden(not shared)
    if shared then
        row.sharedGradient:SetDimensions(fillWidth, height)
        row.sharedGradient:SetTextureCoords(0, ratio, 0, 1)
        row.sharedGradient:SetAlpha(ratio >= 1 and 1 or (ratio >= 0.5 and 0.74 or 0.42))
    end
end

-- Keep the gauge and its glow unchanged. Only the number changes color:
-- gray normally, yellow from 90% charge, red when the ULT cost is reached.
-- Preserve the separate muted Signet-lock number color.
local function SetUltimateChargeText(row, current, cost, palette, signetLock, missingPet, valueText)
    if not row or not row.label then return end
    if missingPet then
        row.label:SetColor(0.72, 0.72, 0.74, 0.88)
        row.textGlow:SetHidden(true)
        row.readyFrame:SetHidden(true)
        return
    end

    cost = tonumber(cost) or 0
    current = tonumber(current) or 0
    local ratio = cost > 0 and math.max(0, math.min(1, current / cost)) or 0
    local ready = cost > 0 and current >= cost
    local c = signetLock and ULTIMATE_SIGNET_COLOR or palette
    local textColor
    if signetLock then
        textColor = c.readyText
    elseif ready then
        textColor = {1.00, 0.24, 0.18} -- red: ULT available
    elseif ratio >= 0.90 then
        textColor = {1.00, 0.80, 0.12} -- yellow: almost available
    else
        textColor = {0.70, 0.70, 0.73} -- gray: charging
    end
    row.label:SetColor(textColor[1], textColor[2], textColor[3], 0.82 + 0.18 * ratio)

    row.textGlow:SetHidden(not ready)
    row.readyFrame:SetHidden(not ready)
    if ready then
        local t = (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0)
        local pulse = 0.5 + 0.5 * math.sin(t / 340)
        row.textGlow:SetText(valueText)
        row.textGlow:SetColor(c.readyText[1], c.readyText[2], c.readyText[3], 1)
        row.textGlow:SetAlpha(0.18 + 0.17 * pulse)
        row.readyFrame:SetColor(c.edge[1], c.edge[2], c.edge[3], 1)
        row.readyFrame:SetAlpha(0.27 + 0.18 * pulse)
    end
end

local function UpdateUltimateDisplay()
    local window = SSRT.ultimateWindow
    if not window then return end
    if not SSRT.sv.ultimateEnabled then window:SetHidden(true); return end
    -- Optional display-only Signet mode. Leave charges, bar swap logic,
    -- input control and existing Signet lock visuals untouched.
    if SSRT.sv.ultimateHideWithSignet == true and SSRT.ultimateSignetEquipped == true then
        window:SetHidden(true)
        return
    end
    local showFront = SSRT.sv.ultimateFrontEnabled ~= false
    local showBack = SSRT.sv.ultimateBackEnabled ~= false
    if not showFront and not showBack then window:SetHidden(true); return end
    local current = GetUltimateCurrentValue()
    local active = GetActiveHotbarCategory and GetActiveHotbarCategory() or HOTBAR_CATEGORY_PRIMARY
    -- A single enabled row follows the weapon-bar ROLE, not a permanent
    -- PRIMARY/BACKUP slot.  If only Back is enabled, show the *currently
    -- inactive* Ultimate (purple when it is physically Backup, orange when
    -- it is physically Primary after a weapon swap).  Front-only is the
    -- inverse: show the currently active Ultimate.  Both-enabled is the
    -- original two-row view.  This is display-only: Signet lock still checks
    -- the actual equipped bar below.
    local singleBarView = showFront ~= showBack
    local rows = {}
    if singleBarView then
        local equippedCategory = (active == HOTBAR_CATEGORY_BACKUP) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
        local otherCategory = (equippedCategory == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
        local shownCategory = showBack and otherCategory or equippedCategory
        local id, cost, name, icon = GetUltimateInfoForCategory(shownCategory)
        rows[1] = { kind = shownCategory == HOTBAR_CATEGORY_PRIMARY and "front" or "back",
            abilityId = id, cost = cost, name = name, icon = icon,
            active = true, actuallyEquipped = shownCategory == equippedCategory }
    else
        for _, category in ipairs({HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP}) do
            local id, cost, name, icon = GetUltimateInfoForCategory(category)
            local equipped = active == category
            rows[#rows + 1] = { kind = category == HOTBAR_CATEGORY_PRIMARY and "front" or "back",
                abilityId = id, cost = cost, name = name, icon = icon,
                active = equipped, actuallyEquipped = equipped }
        end
    end
    table.sort(rows, function(a, b)
        if a.active ~= b.active then return not a.active end
        return a.kind == "back"
    end)
    local missingPet = false
    for _, data in ipairs(rows) do
        if data.cost <= 0 and IsWardenBearIcon(data.icon) then
            missingPet = true
            break
        end
    end
    if SSRT.ultimatePetWarning ~= missingPet then
        SSRT.ultimatePetWarning = missingPet
        ApplyUltimateVisualSettings()
    end
    if missingPet then
        rows = {{ kind = "back", abilityId = -1, cost = 0, missingPet = true, active = true, mergedDuplicate = true }}
    end
    if #rows == 2 then
        local a, b = rows[1], rows[2]
        local sameCost = a.cost == b.cost
        local sameById = a.abilityId ~= 0 and a.abilityId == b.abilityId
        local sameByName = a.name ~= "" and a.name == b.name and sameCost
        local sameByIcon = a.icon ~= "" and a.icon == b.icon and sameCost
        if sameById or sameByName or sameByIcon then
            rows = { rows[2] }
            rows[1].mergedDuplicate = true
            rows[1].active = true
        end
    end
    local signetEquipped = SSRT.ultimateSignetEquipped == true
    local visibleCount = 0
    for i, data in ipairs(rows) do
        if data and (data.abilityId ~= 0 or data.cost > 0 or data.missingPet) then
            visibleCount = visibleCount + 1
            local row = SSRT.ultimateRows[visibleCount]
            local palette = data.mergedDuplicate and ULTIMATE_SHARED_COLOR or (data.kind == "front" and ULTIMATE_FRONT_COLOR or ULTIMATE_BACK_COLOR)
            local ready = not data.missingPet and data.cost > 0 and current >= data.cost
            local activeReady = ready and data.active
            -- Signet visuals describe real equipped-bar behavior, not a preview
            -- of the other bar. A single-bar view must not fake castability.
            local signetLock = signetEquipped and ready and data.actuallyEquipped and not data.missingPet
            local sharedGradient = data.mergedDuplicate and not data.missingPet and not signetLock
            row.container:SetHidden(false)
            -- Keep the old frame and readiness highlight; darken just the
            -- uncharged portion of the existing background texture.
            local c = signetLock and ULTIMATE_SIGNET_COLOR or palette
            row.bg:SetColor(c.fill[1] * 0.14, c.fill[2] * 0.14, c.fill[3] * 0.14, 0.78)
            SetUltimateFrameColor(row, c.edge)
            SetUltimateProgress(row, current, data.missingPet and 0 or data.cost, palette, signetLock)
            -- Keep pending Ultimates in view, but visually subdued.  Bright
            -- borders and the existing glow activate only at the real cost.
            local visualReady = ready or data.missingPet
            row.bg:SetAlpha(visualReady and 1.0 or 0.68)
            row.frame:SetAlpha(visualReady and 1.0 or 0.48)
            local valueText = data.missingPet and GetPetMissingText() or FormatUltimateCompact(current, data.cost)
            row.label:SetFont(data.missingPet and (row.warningFont or row.normalFont) or row.normalFont)
            row.label:SetText(valueText)
            SetUltimateChargeText(row, current, data.cost, palette, signetLock, data.missingPet, valueText)
            local pulse = 0.84 + 0.16 * math.sin(GetFrameTimeMilliseconds() / 320)
            local mistPulse = 0.78 + 0.12 * math.sin(GetFrameTimeMilliseconds() / 460)
            if activeReady then
                if signetLock then
                    row.glow:SetColor(ULTIMATE_SIGNET_COLOR.glow[1], ULTIMATE_SIGNET_COLOR.glow[2], ULTIMATE_SIGNET_COLOR.glow[3], ULTIMATE_SIGNET_COLOR.glow[4])
                    row.glow:SetAlpha(0.22 + 0.06 * math.sin(GetFrameTimeMilliseconds() / 520))
                    row.glow:SetHidden(false)
                    row.mist:SetColor(ULTIMATE_SIGNET_COLOR.glow[1], ULTIMATE_SIGNET_COLOR.glow[2], ULTIMATE_SIGNET_COLOR.glow[3], 0.70)
                    row.mist:SetAlpha(0.36 + 0.08 * math.sin(GetFrameTimeMilliseconds() / 610))
                    row.mist:SetHidden(false)
                else
                    -- Keep the original proven soft glow and mist textures.
                    -- For shared Ultimates tint them rose-pink; the visible
                    -- orange/pink/purple gradient lives in its own overlay.
                    row.glow:SetColor(palette.glow[1], palette.glow[2], palette.glow[3], palette.glow[4])
                    row.mist:SetColor(palette.glow[1], palette.glow[2], palette.glow[3], 0.90)
                    row.glow:SetAlpha(pulse)
                    row.glow:SetHidden(false)
                    row.mist:SetAlpha(mistPulse)
                    row.mist:SetHidden(false)
                end
            else
                row.glow:SetHidden(true)
                row.mist:SetHidden(true)
            end
        end
    end
    for i = visibleCount + 1, #(SSRT.ultimateRows or {}) do
        local row = SSRT.ultimateRows[i]
        row.container:SetHidden(true)
        row.glow:SetHidden(true)
        row.mist:SetHidden(true)
        row.progress:SetHidden(true)
        row.sharedGradient:SetHidden(true)
        row.textGlow:SetHidden(true)
        row.readyFrame:SetHidden(true)
    end
    local scale = math.max(60, math.min(160, SSRT.sv.ultimateScale or 100)) / 100
    local oneRowHeight = zo_round(34 * scale)
    local fullHeight = oneRowHeight * 2 + zo_round(8 * scale)
    window:SetDimensions(zo_round(146 * scale), visibleCount == 1 and oneRowHeight or fullHeight)
    window:SetHidden(visibleCount == 0)
end


local function Preview()
    SSRT.ultimatePetWarning = false
    SSRT.ultimateWindow:SetHidden(false)
    ApplyUltimateVisualSettings()
    local showFront = SSRT.sv.ultimateFrontEnabled ~= false
    local showBack = SSRT.sv.ultimateBackEnabled ~= false
    local oneRow = showFront ~= showBack
    local active = GetActiveHotbarCategory and GetActiveHotbarCategory() or HOTBAR_CATEGORY_PRIMARY
    local firstIsBack = oneRow and ((showBack and active == HOTBAR_CATEGORY_PRIMARY) or (showFront and active == HOTBAR_CATEGORY_BACKUP))
    for i, row in ipairs(SSRT.ultimateRows or {}) do
        local palette = (oneRow and (firstIsBack and ULTIMATE_BACK_COLOR or ULTIMATE_FRONT_COLOR))
            or (i == 1 and ULTIMATE_BACK_COLOR or ULTIMATE_FRONT_COLOR)
        row.container:SetHidden((not showFront and not showBack) or (oneRow and i ~= 1))
        -- Demonstrate a partial row and a fully charged row in edit mode.
        local previewReady = oneRow and i == 1 or (not oneRow and i == 2)
        local previewCost = oneRow and (firstIsBack and 250 or 125) or (i == 1 and 250 or 125)
        local previewCurrent = previewReady and previewCost or 120
        local previewText = FormatUltimateCompact(previewCurrent, previewCost)
        row.label:SetFont(row.normalFont)
        row.label:SetText(previewText)
        row.bg:SetColor(palette.fill[1] * 0.14, palette.fill[2] * 0.14, palette.fill[3] * 0.14, 0.78)
        SetUltimateFrameColor(row, palette.edge)
        SetUltimateProgress(row, previewCurrent, previewCost, palette, false)
        SetUltimateChargeText(row, previewCurrent, previewCost, palette, false, false, previewText)
        row.glow:SetColor(palette.glow[1], palette.glow[2], palette.glow[3], 0.9)
        row.glow:SetHidden(not previewReady)
        row.mist:SetColor(palette.glow[1], palette.glow[2], palette.glow[3], 0.90)
        row.mist:SetHidden(not previewReady)
    end
    if oneRow then
        local scale = math.max(60, math.min(160, SSRT.sv.ultimateScale or 100)) / 100
        SSRT.ultimateWindow:SetDimensions(zo_round(146 * scale), zo_round(34 * scale))
    end
end

SSRT.Ultimate.ApplyPosition = ApplyUltimatePosition
SSRT.Ultimate.ApplyVisualSettings = ApplyUltimateVisualSettings
SSRT.Ultimate.CreateWindow = CreateUltimateWindow
SSRT.Ultimate.UpdateDisplay = UpdateUltimateDisplay
SSRT.Ultimate.RefreshSignet = RefreshUltimateSignetEquipped
SSRT.Ultimate.Preview = Preview

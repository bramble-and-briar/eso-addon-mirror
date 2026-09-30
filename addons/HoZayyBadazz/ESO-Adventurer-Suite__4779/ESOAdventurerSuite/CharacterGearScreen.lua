-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Suite-native enhanced desktop Character / Equipment presentation.
-- v0.29.448

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.CharacterGearScreen = EPC.CharacterGearScreen or {}
local G = EPC.CharacterGearScreen

local NS = "ESOAdventurerSuite_CharacterGearScreen029355"
local REF_W, REF_H = 2560, 1440
local MIN_SCALE, MAX_SCALE = 0.60, 1.12
local DEFAULT_SLOT_SIZE = 68
-- v0.29.207: the original source layout was authored around ultrawide screens.
-- The Suite now fits the equipment cluster into the actual free center area between
-- desktop chat/left UI and the inventory/right panel instead of assuming full-screen room.
local SAFE_LEFT_FRACTION = 0.17
local SAFE_RIGHT_FRACTION = 0.69
local SAFE_MARGIN = 24
local COMPACT_LABEL_WIDTH = 360
local DETAILED_LABEL_WIDTH = 420
local WEAPON_Y = 425
local OUTFIT_ICON = "EsoUI/Art/Dye/dyes_tabicon_dye_down.dds"
local COSTUME_ICON = "EsoUI/Art/Dye/dyes_tabicon_costumedye_down.dds"

local PLAYER_SLOTS = {
    { slot=EQUIP_SLOT_HEAD, control="ZO_CharacterEquipmentSlotsHead", x=-575, y=-535, side="right", outfit=OUTFIT_SLOT_HEAD },
    { slot=EQUIP_SLOT_SHOULDERS, control="ZO_CharacterEquipmentSlotsShoulder", x=-575, y=-335, side="right", outfit=OUTFIT_SLOT_SHOULDERS },
    { slot=EQUIP_SLOT_HAND, control="ZO_CharacterEquipmentSlotsGlove", x=-575, y=-135, side="right", outfit=OUTFIT_SLOT_HANDS },
    { slot=EQUIP_SLOT_RING1, control="ZO_CharacterEquipmentSlotsRing1", x=-575, y=65, side="right" },
    { slot=EQUIP_SLOT_LEGS, control="ZO_CharacterEquipmentSlotsLeg", x=-575, y=265, side="right", outfit=OUTFIT_SLOT_LEGS },
    { slot=EQUIP_SLOT_NECK, control="ZO_CharacterEquipmentSlotsNeck", x=575, y=-535, side="left" },
    { slot=EQUIP_SLOT_CHEST, control="ZO_CharacterEquipmentSlotsChest", x=575, y=-335, side="left", outfit=OUTFIT_SLOT_CHEST },
    { slot=EQUIP_SLOT_WAIST, control="ZO_CharacterEquipmentSlotsBelt", x=575, y=-135, side="left", outfit=OUTFIT_SLOT_WAIST },
    { slot=EQUIP_SLOT_RING2, control="ZO_CharacterEquipmentSlotsRing2", x=575, y=65, side="left" },
    { slot=EQUIP_SLOT_FEET, control="ZO_CharacterEquipmentSlotsFoot", x=575, y=265, side="left", outfit=OUTFIT_SLOT_FEET },
    { slot=EQUIP_SLOT_MAIN_HAND, control="ZO_CharacterEquipmentSlotsMainHand", weaponCol=-1, weaponRow=-1, side="left", weaponOutfit=1 },
    { slot=EQUIP_SLOT_OFF_HAND, control="ZO_CharacterEquipmentSlotsOffHand", weaponCol=1, weaponRow=-1, side="right", weaponOutfit=2 },
    { slot=EQUIP_SLOT_BACKUP_MAIN, control="ZO_CharacterEquipmentSlotsBackupMain", weaponCol=-1, weaponRow=1, side="left", weaponOutfit=3 },
    { slot=EQUIP_SLOT_BACKUP_OFF, control="ZO_CharacterEquipmentSlotsBackupOff", weaponCol=1, weaponRow=1, side="right", weaponOutfit=4 },
    { slot=EQUIP_SLOT_POISON, control="ZO_CharacterEquipmentSlotsPoison", weaponCol=0, weaponRow=-1, side="left", poison=true },
    { slot=EQUIP_SLOT_BACKUP_POISON, control="ZO_CharacterEquipmentSlotsBackupPoison", weaponCol=0, weaponRow=1, side="left", poison=true },
}

local COMPANION_SLOTS = {
    { slot=EQUIP_SLOT_HEAD, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsHead", x=-575, y=-535, side="right", outfit=OUTFIT_SLOT_HEAD },
    { slot=EQUIP_SLOT_SHOULDERS, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsShoulder", x=-575, y=-335, side="right", outfit=OUTFIT_SLOT_SHOULDERS },
    { slot=EQUIP_SLOT_HAND, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsGlove", x=-575, y=-135, side="right", outfit=OUTFIT_SLOT_HANDS },
    { slot=EQUIP_SLOT_RING1, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsRing1", x=-575, y=65, side="right" },
    { slot=EQUIP_SLOT_LEGS, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsLeg", x=-575, y=265, side="right", outfit=OUTFIT_SLOT_LEGS },
    { slot=EQUIP_SLOT_NECK, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsNeck", x=575, y=-535, side="left" },
    { slot=EQUIP_SLOT_CHEST, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsChest", x=575, y=-335, side="left", outfit=OUTFIT_SLOT_CHEST },
    { slot=EQUIP_SLOT_WAIST, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsBelt", x=575, y=-135, side="left", outfit=OUTFIT_SLOT_WAIST },
    { slot=EQUIP_SLOT_RING2, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsRing2", x=575, y=65, side="left" },
    { slot=EQUIP_SLOT_FEET, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsFoot", x=575, y=265, side="left", outfit=OUTFIT_SLOT_FEET },
    { slot=EQUIP_SLOT_MAIN_HAND, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsMainHand", weaponCol=-1, weaponRow=0, side="left", weaponOutfit=1 },
    { slot=EQUIP_SLOT_OFF_HAND, control="ZO_CompanionCharacterWindow_Keyboard_TopLevelEquipmentSlotsOffHand", weaponCol=1, weaponRow=0, side="right", weaponOutfit=2 },
}

local DURABILITY_SLOTS = {
    [EQUIP_SLOT_HEAD]=true, [EQUIP_SLOT_SHOULDERS]=true, [EQUIP_SLOT_CHEST]=true,
    [EQUIP_SLOT_HAND]=true, [EQUIP_SLOT_WAIST]=true, [EQUIP_SLOT_LEGS]=true, [EQUIP_SLOT_FEET]=true,
}
local WEAPON_SLOTS = {
    [EQUIP_SLOT_MAIN_HAND]=true, [EQUIP_SLOT_OFF_HAND]=true,
    [EQUIP_SLOT_BACKUP_MAIN]=true, [EQUIP_SLOT_BACKUP_OFF]=true,
}
local COSTUME_SLOTS = {
    [EQUIP_SLOT_HEAD]=true, [EQUIP_SLOT_SHOULDERS]=true, [EQUIP_SLOT_CHEST]=true,
    [EQUIP_SLOT_HAND]=true, [EQUIP_SLOT_WAIST]=true, [EQUIP_SLOT_LEGS]=true, [EQUIP_SLOT_FEET]=true,
}

local function Safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f, g
end

local function SafeNumber(fn, fallback, ...)
    -- Capture only the first return value before calling tonumber(). Passing all
    -- Safe() returns directly into tonumber() can accidentally make return #2 the
    -- numeric base argument (for example GetActiveCompanionLevelInfo()).
    local value = Safe(fn, fallback, ...)
    local n = tonumber(value)
    if n == nil then return tonumber(fallback) or 0 end
    return n
end

local function Clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function CaptureControlState(control)
    if not control then return nil end
    local state = { control = control, anchors = {} }
    if control.GetNumAnchors and control.GetAnchor then
        local count = SafeNumber(control.GetNumAnchors, 0, control) or 0
        for i = 1, count do
            local point, relativeTo, relativePoint, x, y = Safe(control.GetAnchor, nil, control, i)
            if point then state.anchors[#state.anchors + 1] = {point, relativeTo, relativePoint, x or 0, y or 0} end
        end
    end
    state.width = SafeNumber(control.GetWidth, nil, control)
    state.height = SafeNumber(control.GetHeight, nil, control)
    state.scale = SafeNumber(control.GetScale, nil, control)
    state.hidden = Safe(control.IsHidden, nil, control)
    state.mouseEnabled = Safe(control.IsMouseEnabled, nil, control)
    return state
end

local function RestoreControlState(state)
    if not state or not state.control then return end
    local control = state.control
    if control.ClearAnchors and control.SetAnchor and state.anchors then
        pcall(control.ClearAnchors, control)
        for _, a in ipairs(state.anchors) do
            pcall(control.SetAnchor, control, a[1], a[2], a[3], a[4], a[5])
        end
    end
    if state.scale and control.SetScale then pcall(control.SetScale, control, state.scale) end
    if state.width and state.height and control.SetDimensions then pcall(control.SetDimensions, control, state.width, state.height) end
    if state.hidden ~= nil and control.SetHidden then pcall(control.SetHidden, control, state.hidden) end
    if state.mouseEnabled ~= nil and control.SetMouseEnabled then pcall(control.SetMouseEnabled, control, state.mouseEnabled) end
end

local function RestoreCapturedControlState(states, control)
    if not states or not control then return false end
    for _, state in ipairs(states) do
        if state and state.control == control then
            RestoreControlState(state)
            return true
        end
    end
    return false
end

local function LayoutScale()
    local w, h = 1920, 1080
    if GuiRoot and GuiRoot.GetDimensions then
        local ok, rw, rh = pcall(GuiRoot.GetDimensions, GuiRoot)
        if ok and tonumber(rw) and tonumber(rh) then w, h = rw, rh end
    end
    return Clamp(math.min(w / REF_W, h / REF_H), MIN_SCALE, MAX_SCALE)
end

local function RootDimensions()
    local w, h = 1920, 1080
    if GuiRoot and GuiRoot.GetDimensions then
        local ok, rw, rh = pcall(GuiRoot.GetDimensions, GuiRoot)
        if ok and tonumber(rw) and tonumber(rh) and rw > 0 and rh > 0 then w, h = rw, rh end
    end
    return w, h
end

local function VisibleLeft(control)
    if not control or (control.IsHidden and control:IsHidden()) or not control.GetLeft then return nil end
    local ok, left = pcall(control.GetLeft, control)
    left = ok and tonumber(left) or nil
    if left and left > 0 then return left end
    return nil
end


local function ControlName(control)
    if not control or not control.GetName then return nil end
    local ok, name = pcall(control.GetName, control)
    return ok and name or nil
end

function G:HideCompanionNativeChildren()
    local root = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevel")
    if not root or not root.GetNumChildren or not root.GetChild then return end
    local keep = {}
    for _, slotData in ipairs(COMPANION_SLOTS) do
        keep[slotData.control] = true
    end
    keep["ZO_CompanionCharacterWindow_Keyboard_TopLevel"] = true

    local count = SafeNumber(root.GetNumChildren, 0, root) or 0
    self._hiddenCompanionChildren = self._hiddenCompanionChildren or {}
    for i = 1, count do
        local child = Safe(root.GetChild, nil, root, i)
        local name = ControlName(child)
        if child and name and not keep[name] then
            self._hiddenCompanionChildren[name] = true
            if child.SetHidden then pcall(child.SetHidden, child, true) end
        end
    end
end

local BuildAdaptiveLayoutImpl

function G:BuildAdaptiveLayout(...)

    return BuildAdaptiveLayoutImpl(self, ...)

end

BuildAdaptiveLayoutImpl = function(self, isCompanion)
    local w, h = RootDimensions()
    local scale = LayoutScale()
    local adaptive = EPC.saved.characterGearAdaptiveLayout029207 ~= false
    local safeLeft, safeRight
    if isCompanion and adaptive then
        -- v0.29.222: keep the companion layout centered more naturally between
        -- the left/right gear icons while still leaving room for the native
        -- companion information panel farther to the right.
        safeLeft = w * 0.07
        safeRight = w * 0.67
    else
        safeLeft = adaptive and (w * SAFE_LEFT_FRACTION) or (w * 0.18)
        safeRight = adaptive and (w * SAFE_RIGHT_FRACTION) or (w * 0.82)
    end

    if adaptive then
        local inventory = rawget(_G, "ZO_PlayerInventory")
        local invLeft = VisibleLeft(inventory)
        if invLeft then safeRight = math.min(safeRight, invLeft - SAFE_MARGIN) end
    end

    safeLeft = Clamp(safeLeft, 24, w - 420)
    safeRight = Clamp(safeRight, safeLeft + 720, w - 24)
    local centerX = (safeLeft + safeRight) * 0.5
    local available = safeRight - safeLeft
    local density = tostring(EPC.saved.characterGearDensity029207 or "compact")
    if density ~= "compact" and density ~= "detailed" and density ~= "icons" then density = "compact" end
    local baseLabel = density == "detailed" and DETAILED_LABEL_WIDTH or COMPACT_LABEL_WIDTH
    if density == "icons" then baseLabel = 24 end
    local labelWidth = Clamp(baseLabel * math.max(scale, 0.92), 240, density == "detailed" and 420 or 360)
    local slotSize = Clamp(EPC.saved.characterGearSlotSize029206, 64, 128) * scale
    local reserve = density == "icons" and 52 or (labelWidth + slotSize * 0.55 + 18)
    local half = available * 0.5
    local spread = Clamp(math.min(470 * scale, half - reserve), 270 * scale, 470 * scale)
    if density == "icons" then spread = Clamp(math.min(470 * scale, half - 70), 265 * scale, 470 * scale) end

    -- Five armor/jewelry rows. The old 200px vertical jumps made the top and
    -- bottom labels collide with headers/keybind strips at 1440p.
    local rowStep = Clamp(150 * scale, 108, 164)
    -- v0.29.460: leave the weapon area alone and shift only the armor/jewelry
    -- ring upward so the whole gear cluster sits higher around the character.
    -- v0.29.461: push the non-weapon gear ring further upward around the character.
    -- v0.29.462: move the non-weapon gear ring just a bit higher again.
    local topY = -2 * rowStep - 105 * scale
    local weaponY = Clamp(WEAPON_Y * scale, 315, math.max(330, h * 0.34))

    return {
        w=w, h=h, scale=scale, safeLeft=safeLeft, safeRight=safeRight,
        centerX=centerX, centerY=h*0.5, available=available, spread=spread,
        labelWidth=labelWidth, density=density, rowStep=rowStep, topY=topY,
        weaponY=weaponY, slotSize=slotSize,
    }
end

local function ShouldShowStats(layout)
    local mode = tostring(EPC.saved.characterGearStatsMode029207 or "auto")
    if mode == "show" then return true end
    if mode == "hide" then return false end
    -- Auto: on standard 16:9/1440p layouts the inventory + gear cluster already
    -- consume the center/right area. Keep the full native stat list off that canvas.
    return (layout.w or 0) >= 3200 and (layout.available or 0) >= 1350
end

local function CreateLabel(name, parent, font)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    c:SetFont(font or "ZoFontGameSmall")
    c:SetMouseEnabled(false)
    c:SetDrawLayer(DL_OVERLAY)
    c:SetDrawLevel(8)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return c
end

local function CreateTexture(name, parent, texture)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    c:SetTexture(texture)
    c:SetMouseEnabled(false)
    c:SetDrawLayer(DL_OVERLAY)
    c:SetDrawLevel(8)
    return c
end


-- v0.29.224: contained left-side stats card for both Player and Companion.
-- This intentionally does not re-enable the full-screen native black backdrop.
local GEAR_STATS_ROWS = {
    { label="Maximum Magicka", power="POWERTYPE_MAGICKA" },
    { label="Magicka Recovery", stat="STAT_MAGICKA_REGEN_COMBAT" },
    { label="Maximum Health", power="POWERTYPE_HEALTH" },
    { label="Health Recovery", stat="STAT_HEALTH_REGEN_COMBAT" },
    { label="Maximum Stamina", power="POWERTYPE_STAMINA" },
    { label="Stamina Recovery", stat="STAT_STAMINA_REGEN_COMBAT" },
    { spacer=true },
    { label="Spell Damage", stat="STAT_SPELL_POWER", fallback="STAT_WEAPON_AND_SPELL_DAMAGE" },
    { label="Spell Critical", stat="STAT_SPELL_CRITICAL", critical=true },
    { label="Spell Penetration", stat="STAT_SPELL_PENETRATION", fallback="STAT_OFFENSIVE_PENETRATION" },
    { label="Weapon Damage", stat="STAT_WEAPON_POWER", fallback="STAT_ATTACK_POWER", fallback2="STAT_WEAPON_AND_SPELL_DAMAGE" },
    { label="Weapon Critical", stat="STAT_CRITICAL_STRIKE", critical=true },
    { label="Physical Penetration", stat="STAT_PHYSICAL_PENETRATION", fallback="STAT_OFFENSIVE_PENETRATION" },
    { spacer=true },
    { label="Spell Resistance", stat="STAT_SPELL_RESIST" },
    { label="Physical Resistance", stat="STAT_PHYSICAL_RESIST" },
    { label="Critical Resistance", stat="STAT_CRITICAL_RESISTANCE" },
}

local function GearReadPowerMax(unitTag, powerName)
    local powerType = rawget(_G, powerName or "")
    if powerType == nil or type(GetUnitPower) ~= "function" then return 0 end
    local current, maximum = Safe(GetUnitPower, 0, unitTag, powerType)
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then maximum = tonumber(current) or 0 end
    return maximum
end

local function GearReadPlayerStat(statName)
    local stat = rawget(_G, statName or "")
    if stat == nil or type(GetPlayerStat) ~= "function" then return 0 end
    local bonus = rawget(_G, "STAT_BONUS_OPTION_APPLY_BONUS") or rawget(_G, "STAT_BONUS_OPTION_DONT_APPLY_BONUS") or 0
    return SafeNumber(GetPlayerStat, 0, stat, bonus) or 0
end

local function GearReadUnitStat(unitTag, statName)
    if unitTag == "player" then return GearReadPlayerStat(statName) end
    local stat = rawget(_G, statName or "")
    if stat == nil then return 0 end
    local fn = rawget(_G, "GetUnitEffectiveStat")
    if type(fn) == "function" then
        return SafeNumber(fn, 0, unitTag, stat) or 0
    end
    return 0
end

local function GearReadRow(unitTag, row)
    if row.power then return GearReadPowerMax(unitTag, row.power) end
    local value = GearReadUnitStat(unitTag, row.stat)
    if value <= 0 and row.fallback then value = GearReadUnitStat(unitTag, row.fallback) end
    if value <= 0 and row.fallback2 then value = GearReadUnitStat(unitTag, row.fallback2) end
    return tonumber(value) or 0
end

local function GearFormatInteger(value)
    value = tonumber(value) or 0
    if value <= 0 then return "—" end
    value = math.floor(value + 0.5)
    local s = tostring(value)
    while true do
        local n, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        s = n
        if count == 0 then break end
    end
    return s
end

local function GearFormatCritical(value)
    value = tonumber(value) or 0
    if value <= 0 then return "—" end
    if type(GetCriticalStrikeChance) == "function" then
        local chance = SafeNumber(GetCriticalStrikeChance, 0, value) or 0
        if chance > 0 then return string.format("%.1f%%", chance) end
    end
    return GearFormatInteger(value)
end

-- The player stats footer uses ESO's own native Mundus row template rather
-- than a Suite-drawn item/buff icon.  ZO_MundusStonesStatsEntry contains the
-- localized MUNDUS header and ZO_StatsMundusIcon controls used by the stock
-- keyboard Character Stats screen.
local function RefreshNativeMundusRow(row)
    if not row then return end
    if type(ZO_SharedStats_SetupMundusIconControls) ~= "function" then
        row:SetHidden(true)
        return
    end

    local icons = { row.mundus1, row.mundus2 }
    if not icons[1] then
        row:SetHidden(true)
        return
    end

    -- The shared helper also marks derived-stat rows on ESO's normal stats
    -- page.  Our compact card has no ZO_StatEntry rows, so supply a harmless
    -- sink that preserves the helper's native icon/effect setup without
    -- mutating or depending on the stock stats list.
    local sinkEntry = {
        SetHasMundusEffect = function() end,
        UpdateStatValue = function() end,
        ShowComparisonValue = function() end,
        HideComparisonValue = function() end,
    }
    local sinkControl = { statEntry = sinkEntry }
    local function GetDerivedStatSink() return sinkControl end

    local ok = pcall(ZO_SharedStats_SetupMundusIconControls, icons, LEFT, 5, GetDerivedStatSink)
    row:SetHidden(not ok)
end

function G:EnsureGearStatsCard()
    if self.gearStatsCard then return self.gearStatsCard end
    local wm=WINDOW_MANAGER
    local panel=wm:CreateTopLevelWindow(NS .. "GearStatsCard")
    panel:SetDimensions(270, 540)
    panel:SetMouseEnabled(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    if panel.SetDrawTier and rawget(_G,"DT_HIGH") then panel:SetDrawTier(DT_HIGH) end
    panel:SetDrawLayer(DL_CONTROLS)
    panel:SetDrawLevel(5)
    panel:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self.StartMoving then self:StartMoving() end
    end)
    panel:SetHandler("OnMouseUp", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if self.StopMovingOrResizing then self:StopMovingOrResizing() end
        local left = self.GetLeft and tonumber(self:GetLeft()) or nil
        local top = self.GetTop and tonumber(self:GetTop()) or nil
        if left and top and EPC.saved then
            EPC.saved.characterGearStatsX029355 = left
            EPC.saved.characterGearStatsY029355 = top
            EPC.saved.characterGearStatsMoved029355 = true
        end
    end)

    local bg=wm:CreateControl(nil,panel,CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.01,0.012,0.016,0.76)
    bg:SetEdgeColor(0.30,0.28,0.20,0.72)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds",1,1,1)

    local title=CreateLabel(NS.."GearStatsTitle",panel,"$(BOLD_FONT)|18|soft-shadow-thick")
    title:SetAnchor(TOPLEFT,panel,TOPLEFT,14,9)
    title:SetDimensions(242,26)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    panel.title=title

    panel.statRows={}
    local y=42
    for i,row in ipairs(GEAR_STATS_ROWS) do
        if row.spacer then
            local div=wm:CreateControl(nil,panel,CT_TEXTURE)
            div:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
            div:SetColor(0.72,0.62,0.38,0.58)
            div:SetAnchor(TOPLEFT,panel,TOPLEFT,12,y+5)
            div:SetDimensions(246,1)
            y=y+18
        else
            local left=CreateLabel(NS.."GearStatsL"..i,panel,"$(BOLD_FONT)|14|soft-shadow-thick")
            local right=CreateLabel(NS.."GearStatsR"..i,panel,"$(BOLD_FONT)|14|soft-shadow-thick")
            left:SetAnchor(TOPLEFT,panel,TOPLEFT,14,y)
            left:SetDimensions(166,21)
            left:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            left:SetColor(0.91,0.88,0.70,1)
            left:SetText(row.label)
            right:SetAnchor(TOPRIGHT,panel,TOPRIGHT,-14,y)
            right:SetDimensions(78,21)
            right:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            right:SetColor(1,1,1,1)
            panel.statRows[#panel.statRows+1]={meta=row,value=right}
            y=y+24
        end
    end

    local div=wm:CreateControl(nil,panel,CT_TEXTURE)
    div:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
    div:SetColor(0.72,0.62,0.38,0.72)
    div:SetAnchor(BOTTOMLEFT,panel,BOTTOMLEFT,12,-58)
    div:SetDimensions(246,1)
    panel.footerDivider=div

    local footerTitle=CreateLabel(NS.."GearStatsFooterTitle",panel,"$(BOLD_FONT)|16|soft-shadow-thick")
    footerTitle:SetAnchor(BOTTOMLEFT,panel,BOTTOMLEFT,14,-49)
    footerTitle:SetDimensions(242,21)
    footerTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    panel.footerTitle=footerTitle

    local footerValue=CreateLabel(NS.."GearStatsFooterValue",panel,"$(MEDIUM_FONT)|13|soft-shadow-thick")
    footerValue:SetAnchor(BOTTOMLEFT,panel,BOTTOMLEFT,14,-27)
    footerValue:SetDimensions(242,22)
    footerValue:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    footerValue:SetColor(0.70,0.90,1,1)
    panel.footerValue=footerValue

    -- Reuse ESO's native Mundus presentation directly.  This is the same
    -- virtual row used by ZO_CharacterWindowStats: localized MUNDUS heading
    -- plus the native glowing Mundus boon symbol(s).
    local nativeMundus=nil
    if type(CreateControlFromVirtual)=="function" then
        local ok,control=pcall(CreateControlFromVirtual,NS.."GearStatsNativeMundus",panel,"ZO_MundusStonesStatsEntry")
        if ok then nativeMundus=control end
    end
    if nativeMundus then
        nativeMundus:ClearAnchors()
        nativeMundus:SetAnchor(BOTTOMLEFT,panel,BOTTOMLEFT,12,-43)
        nativeMundus:SetDimensions(246,28)
        nativeMundus:SetHidden(true)
    end
    panel.nativeMundus=nativeMundus

    panel:SetHidden(true)
    self.gearStatsCard=panel
    return panel
end

local RefreshGearStatsCardImpl

function G:RefreshGearStatsCard(...)

    return RefreshGearStatsCardImpl(self, ...)

end

RefreshGearStatsCardImpl = function(self, isCompanion)
    local panel=self:EnsureGearStatsCard()
    local _,h=RootDimensions()
    local cardH=math.min(540,math.max(500,h-170))
    panel:SetDimensions(270,cardH)
    panel:ClearAnchors()
    -- Keep the user's exact dragged GuiRoot position. This also avoids applying
    -- our gear-layout scale on top of PerfectPixel/ESO UI scaling.
    local moved = EPC.saved and EPC.saved.characterGearStatsMoved029355 == true
    local savedX = moved and tonumber(EPC.saved.characterGearStatsX029355) or nil
    local savedY = moved and tonumber(EPC.saved.characterGearStatsY029355) or nil
    if savedX and savedY then
        panel:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,savedX,savedY)
    else
        panel:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,22,math.max(56,(h-cardH)*0.46 - 22))
    end
    panel.title:SetText(isCompanion and "COMPANION STATS" or "CHARACTER STATS")
    local tag=isCompanion and "companion" or "player"
    for _,entry in ipairs(panel.statRows) do
        local v=GearReadRow(tag,entry.meta)
        entry.value:SetText(entry.meta.critical and GearFormatCritical(v) or GearFormatInteger(v))
    end
    if isCompanion then
        if panel.nativeMundus then panel.nativeMundus:SetHidden(true) end
        if panel.footerDivider then panel.footerDivider:SetHidden(false) end
        panel.footerTitle:SetHidden(false)
        panel.footerTitle:SetText("COMPANION")
        local name=type(GetUnitName)=="function" and tostring(Safe(GetUnitName,"","companion") or "") or ""
        local level=type(GetActiveCompanionLevelInfo)=="function" and SafeNumber(GetActiveCompanionLevelInfo,0) or 0
        if name=="" then name="Active companion" end
        panel.footerValue:SetHidden(false)
        panel.footerValue:SetText(level>0 and zo_strformat("<<1>>  •  Level <<2>>",name,level) or name)
    else
        -- Player footer: show ESO's actual Mundus row.  Do not place a second
        -- Suite title/value/icon over it; the virtual control already owns the
        -- localized header, native symbol, glow/effect and tooltip behavior.
        if panel.footerDivider then panel.footerDivider:SetHidden(true) end
        panel.footerTitle:SetHidden(true)
        panel.footerValue:SetHidden(true)
        panel.footerValue:SetText("")
        if panel.nativeMundus then
            panel.nativeMundus:SetHidden(false)
            RefreshNativeMundusRow(panel.nativeMundus)
        end
    end
    panel:SetHidden(false)
end

function G:HideGearStatsCard()
    if self.gearStatsCard then self.gearStatsCard:SetHidden(true) end
end

-- Shift the native Companion information border/panel to the right as one area.
-- The equipment root itself stays centered around the actual companion model.
local function GearShiftControlX(control,dx)
    local controlType=type(control)
    if controlType~="userdata" and controlType~="table" then return false end
    if not control.GetNumAnchors or not control.GetAnchor then return false end
    local count=SafeNumber(control.GetNumAnchors,0,control) or 0
    if count<=0 then return false end
    local anchors={}
    for i=1,count do
        local point,relativeTo,relativePoint,x,y=Safe(control.GetAnchor,nil,control,i)
        if point then anchors[#anchors+1]={point,relativeTo,relativePoint,tonumber(x) or 0,tonumber(y) or 0} end
    end
    if #anchors==0 then return false end
    local okClear=pcall(control.ClearAnchors,control)
    if not okClear then return false end
    for _,a in ipairs(anchors) do
        local okAnchor=pcall(control.SetAnchor,control,a[1],a[2],a[3],a[4]+dx,a[5])
        if not okAnchor then return false end
    end
    return true
end

local function GearCompanionInfoCandidate(control,name,w)
    local controlType=type(control)
    if controlType~="userdata" and controlType~="table" then return false end
    if not control.GetLeft or not control.GetWidth then return false end
    name=tostring(name or "")
    if name=="" or name=="ZO_CompanionCharacterWindow_Keyboard_TopLevel" then return false end
    if name:find("EquipmentSlots",1,true) or name:find("PaperDoll",1,true) then return false end
    if not name:find("Companion",1,true) then return false end
    local parent=control.GetParent and Safe(control.GetParent,nil,control) or nil
    if parent and parent~=GuiRoot then return false end
    local left=SafeNumber(control.GetLeft,0,control) or 0
    local width=SafeNumber(control.GetWidth,0,control) or 0
    return left>=w*0.43 and width>=120
end

function G:ShiftCompanionInfoPanelRight(layout)
    if self.companionInfoShiftApplied then return end
    local w=(layout and layout.w) or select(1,RootDimensions())
    local dx=Clamp(w*0.12,170,235)
    local targets,seen={},{}
    local function add(c)
        local ct=type(c)
        if ct~="userdata" and ct~="table" then return end
        if not c.GetNumAnchors or not c.GetAnchor then return end
        if not seen[c] then seen[c]=true; targets[#targets+1]=c end
    end
    -- v0.29.225 SECURITY/TAINT FIX:
    -- Never enumerate _G here. ESO exposes protected/private entries in the
    -- global environment (for example PlayDefaultQuickChat), and touching them
    -- from insecure addon code can taint the call stack. Only inspect a small,
    -- explicit whitelist of known UI controls.
    local controlNames={
        "ZO_SharedRightPanelBackground",
        "ZO_CompanionCharacter_Keyboard",
        "ZO_CompanionCharacter_Keyboard_TopLevel",
        "ZO_Companion_Keyboard",
        "ZO_CompanionCharacterOverview_Keyboard",
        "ZO_CompanionCharacterInfo_Keyboard",
        "ZO_CompanionCharacterWindow_Keyboard",
        "ZO_CompanionCharacterWindow_Keyboard_TopLevel",
    }
    for _,name in ipairs(controlNames) do
        local control=rawget(_G,name)
        if control and (name=="ZO_SharedRightPanelBackground" or GearCompanionInfoCandidate(control,name,w)) then
            add(control)
        end
    end
    self.companionInfoOriginal={}
    for _,c in ipairs(targets) do
        if c and c~=rawget(_G,"ZO_CompanionCharacterWindow_Keyboard_TopLevel") then
            local state=CaptureControlState(c)
            if state and GearShiftControlX(c,dx) then self.companionInfoOriginal[#self.companionInfoOriginal+1]=state end
        end
    end
    self.companionInfoShiftApplied=true
end

function G:RestoreCompanionInfoPanel()
    if self.companionInfoOriginal then
        for _,state in ipairs(self.companionInfoOriginal) do RestoreControlState(state) end
    end
    self.companionInfoOriginal=nil
    self.companionInfoShiftApplied=false
end

local WORKSPACE_VIGNETTE_TEXTURE = "ESOAdventurerSuite/Art029125/character_gear_vignette.dds"

local function EnsureWorkspaceBackdrop(self)
    -- v0.29.216: backdrop removed by request. The Character Gear screen now
    -- relies on larger icons and fonts for readability instead of a dark panel.
    return nil
end

function G:HideWorkspaceBackdrop()
    if self.workspaceBackdrop and self.workspaceBackdrop.SetHidden then
        self.workspaceBackdrop:SetHidden(true)
    end
end

function G:LayoutWorkspaceBackdrop(layout)
    self:HideWorkspaceBackdrop()
end

local function EnsureSlotBackdrop(slot)
    if slot.EASGearBackdrop then return slot.EASGearBackdrop end
    local bg = WINDOW_MANAGER:CreateControl(slot:GetName() .. "EASGearBackdrop", slot, CT_BACKDROP)
    bg:SetMouseEnabled(false)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)
    slot.EASGearBackdrop = bg
    return bg
end

local function LayoutSlotBackdrop(slot, hasItem, edgeR, edgeG, edgeB, edgeA)
    if not slot then return end
    local bg = EnsureSlotBackdrop(slot)
    local pad = math.max(4, math.floor((slot:GetWidth() or 64) * 0.08))
    bg:ClearAnchors()
    bg:SetAnchor(TOPLEFT, slot, TOPLEFT, -pad, -pad)
    bg:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, pad, pad)
    if hasItem then
        local rr, gg, bb = tonumber(edgeR), tonumber(edgeG), tonumber(edgeB)
        if rr and gg and bb then
            bg:SetCenterColor(0.04 + rr * 0.18, 0.045 + gg * 0.18, 0.06 + bb * 0.18, 0.97)
        else
            bg:SetCenterColor(0.05, 0.06, 0.09, 0.92)
        end
        bg:SetEdgeColor(rr or 0.78, gg or 0.67, bb or 0.38, 1)
    else
        bg:SetCenterColor(0.035, 0.045, 0.07, 0.78)
        bg:SetEdgeColor(0.46, 0.48, 0.56, 0.44)
    end
    bg:SetHidden(false)
end

local function HideSlotBackdrop(slot)
    if slot and slot.EASGearBackdrop then
        slot.EASGearBackdrop:SetHidden(true)
    end
end

local function EnsureBorder(slot)
    if slot.EASGearBorderLines then return slot.EASGearBorderLines, slot.EASGearGlowLines, slot.EASGearHaloLines end

    -- v0.29.228 rarity glow boost:
    -- Use THREE visible layers on GuiRoot: a bright solid border, a strong glow,
    -- and a larger outer halo so rarity colors pop immediately.
    local lines, glowLines, haloLines = {}, {}, {}
    local baseName = slot:GetName() or (NS .. "AnonymousGearSlot")
    for i = 1, 4 do
        local halo = WINDOW_MANAGER:CreateControl(baseName .. "EASGearRarityHalo" .. i, GuiRoot, CT_TEXTURE)
        halo:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
        halo:SetMouseEnabled(false)
        if halo.SetDrawTier and rawget(_G, "DT_HIGH") then halo:SetDrawTier(DT_HIGH) end
        halo:SetDrawLayer(DL_OVERLAY)
        halo:SetDrawLevel(90)
        haloLines[i] = halo

        local glow = WINDOW_MANAGER:CreateControl(baseName .. "EASGearRarityGlow" .. i, GuiRoot, CT_TEXTURE)
        glow:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
        glow:SetMouseEnabled(false)
        if glow.SetDrawTier and rawget(_G, "DT_HIGH") then glow:SetDrawTier(DT_HIGH) end
        glow:SetDrawLayer(DL_OVERLAY)
        glow:SetDrawLevel(95)
        glowLines[i] = glow

        local line = WINDOW_MANAGER:CreateControl(baseName .. "EASGearRarityFrame" .. i, GuiRoot, CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
        line:SetMouseEnabled(false)
        if line.SetDrawTier and rawget(_G, "DT_HIGH") then line:SetDrawTier(DT_HIGH) end
        line:SetDrawLayer(DL_OVERLAY)
        line:SetDrawLevel(100)
        lines[i] = line
    end
    slot.EASGearBorderLines = lines
    slot.EASGearGlowLines = glowLines
    slot.EASGearHaloLines = haloLines
    return lines, glowLines, haloLines
end

local function LayoutBorder(slot, r, g, b, a)
    local lines, glowLines, haloLines = EnsureBorder(slot)
    local width = tonumber(slot:GetWidth()) or 64

    -- Even larger pads and thicker glow so the effect is obvious.
    local pad = math.max(7, math.floor(width * 0.11))
    local thickness = math.max(7, math.floor(width / 12))
    local glowPad = pad + math.max(5, math.floor(width * 0.07))
    local glowThickness = thickness + math.max(8, math.floor(width / 8))
    local haloPad = glowPad + math.max(4, math.floor(width * 0.06))
    local haloThickness = glowThickness + math.max(8, math.floor(width / 7))

    local top, right, bottom, left = lines[1], lines[2], lines[3], lines[4]
    local gTop, gRight, gBottom, gLeft = glowLines[1], glowLines[2], glowLines[3], glowLines[4]
    local hTop, hRight, hBottom, hLeft = haloLines[1], haloLines[2], haloLines[3], haloLines[4]

    local function anchorHorizontal(control, topEdge, extraPad, h)
        control:ClearAnchors()
        if topEdge then
            control:SetAnchor(TOPLEFT, slot, TOPLEFT, -extraPad, -extraPad)
            control:SetAnchor(TOPRIGHT, slot, TOPRIGHT, extraPad, -extraPad)
        else
            control:SetAnchor(BOTTOMLEFT, slot, BOTTOMLEFT, -extraPad, extraPad)
            control:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, extraPad, extraPad)
        end
        control:SetHeight(h)
    end

    local function anchorVertical(control, leftEdge, extraPad, w)
        control:ClearAnchors()
        if leftEdge then
            control:SetAnchor(TOPLEFT, slot, TOPLEFT, -extraPad, -extraPad)
            control:SetAnchor(BOTTOMLEFT, slot, BOTTOMLEFT, -extraPad, extraPad)
        else
            control:SetAnchor(TOPRIGHT, slot, TOPRIGHT, extraPad, -extraPad)
            control:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, extraPad, extraPad)
        end
        control:SetWidth(w)
    end

    anchorHorizontal(top, true, pad, thickness)
    anchorHorizontal(bottom, false, pad, thickness)
    anchorVertical(left, true, pad, thickness)
    anchorVertical(right, false, pad, thickness)

    anchorHorizontal(gTop, true, glowPad, glowThickness)
    anchorHorizontal(gBottom, false, glowPad, glowThickness)
    anchorVertical(gLeft, true, glowPad, glowThickness)
    anchorVertical(gRight, false, glowPad, glowThickness)

    anchorHorizontal(hTop, true, haloPad, haloThickness)
    anchorHorizontal(hBottom, false, haloPad, haloThickness)
    anchorVertical(hLeft, true, haloPad, haloThickness)
    anchorVertical(hRight, false, haloPad, haloThickness)

    -- Stronger brightness push while preserving the rarity hue.
    local rr = math.min(1, (tonumber(r) or 1) * 1.32 + 0.14)
    local gg = math.min(1, (tonumber(g) or 1) * 1.32 + 0.14)
    local bb = math.min(1, (tonumber(b) or 1) * 1.32 + 0.14)

    for _, halo in ipairs(haloLines) do
        halo:SetColor(rr, gg, bb, 0.22)
        halo:SetHidden(false)
    end
    for _, glow in ipairs(glowLines) do
        glow:SetColor(rr, gg, bb, 0.52)
        glow:SetHidden(false)
    end
    for _, line in ipairs(lines) do
        line:SetColor(rr, gg, bb, 1)
        line:SetHidden(false)
    end
end

local function HideBorder(slot)
    if slot and slot.EASGearBorderLines then
        for _, line in ipairs(slot.EASGearBorderLines) do line:SetHidden(true) end
    end
    if slot and slot.EASGearGlowLines then
        for _, line in ipairs(slot.EASGearGlowLines) do line:SetHidden(true) end
    end
    if slot and slot.EASGearHaloLines then
        for _, line in ipairs(slot.EASGearHaloLines) do line:SetHidden(true) end
    end
end

local function EnsureDecor(slot)
    if slot.EASGearCondition then return end
    local name = slot:GetName()
    -- v0.29.235: reduce the text that sits INSIDE gear icons so the artwork is
    -- easier to see. External gear labels remain unchanged.
    slot.EASGearCondition = CreateLabel(name .. "EASGearCondition", slot, "$(BOLD_FONT)|14|soft-shadow-thick")
    slot.EASGearCondition:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    slot.EASGearLevel = CreateLabel(name .. "EASGearLevel", slot, "$(BOLD_FONT)|13|soft-shadow-thick")
    slot.EASGearLevel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    slot.EASGearName = CreateLabel(name .. "EASGearName", slot, "$(BOLD_FONT)|20|soft-shadow-thick")
    slot.EASGearType = CreateLabel(name .. "EASGearType", slot, "$(MEDIUM_FONT)|17|soft-shadow-thick")
    slot.EASGearSet = CreateLabel(name .. "EASGearSet", slot, "$(MEDIUM_FONT)|16|soft-shadow-thick")
    if slot.EASGearName.SetMaxLineCount then slot.EASGearName:SetMaxLineCount(2) end
    if slot.EASGearType.SetMaxLineCount then slot.EASGearType:SetMaxLineCount(1) end
    if slot.EASGearSet.SetMaxLineCount then slot.EASGearSet:SetMaxLineCount(2) end
    slot.EASGearTextBackdrop = WINDOW_MANAGER:CreateControl(name .. "EASGearTextBackdrop", slot, CT_BACKDROP)
    slot.EASGearTextBackdrop:SetDrawLayer(DL_OVERLAY)
    slot.EASGearTextBackdrop:SetDrawLevel(7)
    slot.EASGearTextBackdrop:SetMouseEnabled(false)
    slot.EASGearTextBackdrop:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    slot.EASGearTextBackdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-TooltipBorder.dds", 16, 4, 4)
    slot.EASGearTextBackdrop:SetCenterColor(0, 0, 0, 0.34)
    slot.EASGearTextBackdrop:SetEdgeColor(0.06, 0.06, 0.06, 0.62)
    slot.EASGearTextBackdrop:SetHidden(true)
    slot.EASGearOutfit = CreateTexture(name .. "EASGearOutfit", slot, OUTFIT_ICON)
    slot.EASGearCostume = CreateTexture(name .. "EASGearCostume", slot, COSTUME_ICON)
    slot.EASGearOutfit:SetDimensions(20, 20)
    slot.EASGearCostume:SetDimensions(20, 20)
end

local function HideDecor(slot)
    if not slot then return end
    for _, key in ipairs({"EASGearCondition","EASGearLevel","EASGearName","EASGearType","EASGearSet","EASGearTextBackdrop","EASGearOutfit","EASGearCostume"}) do
        local c = slot[key]
        if c then c:SetHidden(true) end
    end
    HideBorder(slot)
end

local function HideSlotPresentation(slot)
    HideDecor(slot)
    HideSlotBackdrop(slot)
end

local function LayoutTextBackdrop(slot, isWeaponCell, textSide)
    local bg = slot and slot.EASGearTextBackdrop or nil
    local nameLabel = slot and slot.EASGearName or nil
    local typeLabel = slot and slot.EASGearType or nil
    local setLabel = slot and slot.EASGearSet or nil
    if not bg or not nameLabel or nameLabel:IsHidden() then
        if bg then bg:SetHidden(true) end
        return
    end

    local bottom = nameLabel
    if isWeaponCell then
        if typeLabel and not typeLabel:IsHidden() then
            bottom = typeLabel
        elseif setLabel and not setLabel:IsHidden() then
            bottom = setLabel
        end
    else
        if setLabel and not setLabel:IsHidden() then
            bottom = setLabel
        elseif typeLabel and not typeLabel:IsHidden() then
            bottom = typeLabel
        end
    end

    local function measuredWidth(label)
        if not label or label.IsHidden and label:IsHidden() then return 0 end
        if type(label.GetTextWidth) == "function" then
            local ok, value = pcall(label.GetTextWidth, label)
            if ok then return tonumber(value) or 0 end
        end
        return tonumber(label.GetWidth and label:GetWidth()) or 0
    end

    local maxTextWidth = math.max(measuredWidth(nameLabel), measuredWidth(typeLabel), measuredWidth(setLabel))
    local maxLabelWidth = math.max(tonumber(nameLabel.GetWidth and nameLabel:GetWidth()) or 0, 1)
    local desiredWidth = Clamp(maxTextWidth + 18, 84, maxLabelWidth)

    bg:ClearAnchors()
    -- v0.29.457: fit the backdrop to the actual visible text width instead of
    -- the full reserved label block. This removes the overly long outside edge
    -- that could stretch far away from the text on armor/jewelry side labels.
    if isWeaponCell or textSide == "center" then
        bg:SetAnchor(TOPLEFT, nameLabel, TOPLEFT, -6, -4)
        bg:SetAnchor(BOTTOMRIGHT, bottom, BOTTOMRIGHT, 6, 5)
    elseif textSide == "left" then
        bg:SetAnchor(TOPRIGHT, nameLabel, TOPRIGHT, 6, -4)
        bg:SetAnchor(BOTTOMLEFT, bottom, BOTTOMRIGHT, -desiredWidth - 6, 5)
    else
        bg:SetAnchor(TOPLEFT, nameLabel, TOPLEFT, -6, -4)
        bg:SetAnchor(BOTTOMRIGHT, bottom, BOTTOMLEFT, desiredWidth + 6, 5)
    end
    -- v0.29.463: darken the name backdrops a bit more so item names remain easy
    -- to read over bright sand, dark water, shadows, and busy scene detail.
    if isWeaponCell then
        bg:SetCenterColor(0, 0, 0, 0.82)
        bg:SetEdgeColor(0.26, 0.26, 0.26, 0.98)
    else
        bg:SetCenterColor(0, 0, 0, 0.70)
        bg:SetEdgeColor(0.18, 0.18, 0.18, 0.88)
    end
    bg:SetHidden(false)
end

local function GetBag(isCompanion)
    if isCompanion and BAG_COMPANION_WORN then return BAG_COMPANION_WORN end
    return BAG_WORN
end

local function ItemTypeText(link, slotId)
    if not link or link == "" then return "" end
    local equipType = Safe(GetItemLinkEquipType, 0, link)
    if WEAPON_SLOTS[slotId] then
        local wt = Safe(GetItemLinkWeaponType, 0, link)
        if wt and wt ~= 0 then
            local a = Safe(GetString, "", "SI_EQUIPTYPE", equipType) or ""
            local b = Safe(GetString, "", "SI_WEAPONTYPE", wt) or ""
            return zo_strformat("<<1>> <<2>>", a, b)
        end
    end
    local at = Safe(GetItemLinkArmorType, 0, link)
    if at and at ~= 0 then
        local a = Safe(GetString, "", "SI_EQUIPTYPE", equipType) or ""
        local b = Safe(GetString, "", "SI_ARMORTYPE", at) or ""
        return zo_strformat("<<1>> <<2>>", a, b)
    end
    return Safe(GetString, "", "SI_EQUIPTYPE", equipType) or ""
end

local function GetLevelText(bag, slot, unitTag)
    if bag == BAG_WORN then
        local cp = Safe(GetItemRequiredChampionPoints, 0, bag, slot) or 0
        if cp > 0 then
            local current = Safe(GetUnitChampionPoints, 0, unitTag or "player") or 0
            return "CP" .. tostring(cp), current - cp, cp >= 160
        end
        local level = Safe(GetItemRequiredLevel, 0, bag, slot) or 0
        if level > 0 then
            local current = Safe(GetUnitLevel, 1, unitTag or "player") or 1
            return tostring(level), current - level, false
        end
    end
    return "", 0, false
end

local function LowColor(label, value, threshold)
    if value <= threshold * 0.5 then label:SetColor(1, 0.24, 0.20, 1)
    elseif value <= threshold then label:SetColor(1, 0.90, 0.18, 1)
    else label:SetColor(1, 1, 1, 1) end
end

local function DifferenceColor(label, difference, threshold)
    if difference >= threshold * 2 then label:SetColor(1, 0.24, 0.20, 1)
    elseif difference >= threshold then label:SetColor(1, 0.90, 0.18, 1)
    else label:SetColor(1, 1, 1, 1) end
end

local function HasAppearanceOverride(slotData, actorCategory, weaponOutfitSlots)
    if not GetEquippedOutfitIndex or not GetOutfitSlotInfo then return false end
    local outfitIndex = Safe(GetEquippedOutfitIndex, 0, actorCategory) or 0
    if outfitIndex <= 0 then return false end
    local outfitSlot = slotData.outfit
    if slotData.weaponOutfit and weaponOutfitSlots then outfitSlot = weaponOutfitSlots[slotData.weaponOutfit] end
    if not outfitSlot then return false end
    local collectible = Safe(GetOutfitSlotInfo, 0, actorCategory, outfitIndex, outfitSlot) or 0
    return collectible > 0
end

local function AppearanceState(actorCategory)
    local state = { costume=false, hat=false }
    if type(GetActiveCollectibleByType) == "function" then
        local costumeType = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_COSTUME")
        local hatType = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_HAT")
        if costumeType then state.costume = (Safe(GetActiveCollectibleByType, 0, costumeType, actorCategory) or 0) > 0 end
        if hatType then state.hat = (Safe(GetActiveCollectibleByType, 0, hatType, actorCategory) or 0) > 0 end
    end
    return state
end

local function WeaponOutfitSlots(actorCategory)
    if type(GetOutfitSlotsForEquippedWeapons) ~= "function" then return {} end
    local a,b,c,d = Safe(GetOutfitSlotsForEquippedWeapons, nil, actorCategory)
    return {a,b,c,d}
end

function G:IsEnabled()
    return EPC.saved and EPC.saved.characterGearScreenEnabled029206 ~= false
end

function G:IsPlayerSceneShowing()
    local inv = self.inventoryScene
    if inv and inv.IsShowing and inv:IsShowing() then return true end
    local chr = self.characterScene
    if chr and chr.IsShowing and chr:IsShowing() then return true end
    return false
end

function G:IsCompanionSceneShowing()
    local scene = rawget(_G, "COMPANION_CHARACTER_KEYBOARD_SCENE")
    return scene and scene.IsShowing and scene:IsShowing() or false
end

local function RefreshSlotBase029500(self, slotData, isCompanion)
    local control = rawget(_G, slotData.control)
    if not control then return end
    EnsureDecor(control)
    local bag = GetBag(isCompanion)
    local itemName = Safe(GetItemName, "", bag, slotData.slot) or ""
    local hasItem = itemName ~= ""
    LayoutSlotBackdrop(control, hasItem)
    if not hasItem then HideDecor(control); return end

    local saved = EPC.saved
    local quality = Safe(GetItemDisplayQuality, nil, bag, slotData.slot)
    local backdropR, backdropG, backdropB, backdropA = nil, nil, nil, nil
    if saved.characterGearShowQuality029206 ~= false and quality then
        local color = Safe(GetItemQualityColor, nil, quality)
        if color and color.UnpackRGBA then
            local r,g,b,a = color:UnpackRGBA()
            LayoutBorder(control, r,g,b,a)
            backdropR, backdropG, backdropB, backdropA = r, g, b, a
        else
            LayoutBorder(control, 1,1,1,1)
            backdropR, backdropG, backdropB, backdropA = 1, 1, 1, 1
        end
    else
        HideBorder(control)
    end
    LayoutSlotBackdrop(control, true, backdropR, backdropG, backdropB, backdropA)

    local cond = control.EASGearCondition
    cond:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
    cond:ClearAnchors(); cond:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -3, 1)
    cond:SetDimensions(control:GetWidth() - 4, 18)
    cond:SetHidden(true)
    local repairThreshold = Clamp(saved.characterGearRepairThreshold029206, 1, 100)
    local chargeThreshold = Clamp(saved.characterGearChargeThreshold029206, 1, 100)
    if not isCompanion and saved.characterGearShowCondition029206 ~= false then
        local hasDurability = Safe(DoesItemHaveDurability, false, bag, slotData.slot) == true
        if hasDurability then
            local condition = SafeNumber(GetItemCondition, 100, bag, slotData.slot) or 100
            cond:SetText(tostring(math.floor(condition + 0.5)) .. "%")
            LowColor(cond, condition, repairThreshold)
            cond:SetHidden(false)
        elseif WEAPON_SLOTS[slotData.slot] and Safe(IsItemChargeable, false, bag, slotData.slot) == true then
            local current, maximum = Safe(GetChargeInfoForItem, 0, bag, slotData.slot)
            current, maximum = tonumber(current) or 0, tonumber(maximum) or 0
            if maximum > 0 then
                local pct = zo_clamp(math.floor(current / maximum * 100 + 0.5), 0, 100)
                cond:SetText(tostring(pct) .. "%")
                LowColor(cond, pct, chargeThreshold)
                cond:SetHidden(false)
            end
        end
    end

    local level = control.EASGearLevel
    level:SetFont("$(BOLD_FONT)|13|soft-shadow-thick")
    level:ClearAnchors(); level:SetAnchor(TOPRIGHT, control, TOPRIGHT, -3, -1)
    level:SetDimensions(control:GetWidth() - 4, 17)
    local levelText, difference, maxCp = GetLevelText(bag, slotData.slot, isCompanion and "companion" or "player")
    level:SetText(levelText)
    if maxCp then level:SetColor(0.35, 0.85, 1, 1) else DifferenceColor(level, difference, Clamp(saved.characterGearLevelWarning029206,1,10)) end
    level:SetHidden(isCompanion or saved.characterGearShowLevel029206 == false or levelText == "" or slotData.poison == true)

    local link = Safe(GetItemLink, "", bag, slotData.slot, LINK_STYLE_DEFAULT or 0) or ""
    local layout = self.currentLayout or self:BuildAdaptiveLayout(isCompanion)
    local density = layout.density or "compact"
    local detailVisible = saved.characterGearShowDetails029206 ~= false and not slotData.poison and density ~= "icons"
    -- v0.29.230: keep the larger gear text overall, but dial the companion
    -- labels back slightly so they do not dominate the companion layout.
    -- v0.29.448: external gear text must scale with the same adaptive layout
    -- as the slot controls. Previously a 1680x945/1080p-style UI shrank the
    -- equipment boxes but kept 24-26px labels, making the whole gear screen look
    -- zoomed and causing weapon text to spill into neighboring cells.
    local requestedFontSize = Clamp((tonumber(saved.characterGearFontSize029206) or 20) + 4, 18, 32)
    local textScale = Clamp(tonumber(layout.scale) or 1, 0.68, 1.0)
    local fontSize = math.floor(requestedFontSize * textScale + 0.5)
    fontSize = Clamp(fontSize, 16, 28)
    if isCompanion then
        fontSize = math.max(15, fontSize - 1)
    end
    if density == "compact" then
        fontSize = math.min(fontSize, isCompanion and 21 or 22)
    end
    local detailFont = string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize)
    local subFont = string.format("$(MEDIUM_FONT)|%d|soft-shadow-thick", math.max(isCompanion and 14 or 16, fontSize - 2))
    local nameLabel, typeLabel, setLabel = control.EASGearName, control.EASGearType, control.EASGearSet
    nameLabel:SetFont(detailFont); typeLabel:SetFont(subFont); setLabel:SetFont(subFont)
    local width = layout.labelWidth or (COMPACT_LABEL_WIDTH * math.max(LayoutScale(), 0.88))
    local isWeaponCell = slotData.weaponCol ~= nil and not isCompanion
    -- v0.29.448: player weapon labels live inside their own grid column instead
    -- of expanding sideways. This prevents Off Hand text from drawing over the
    -- poison/potion cell and keeps future populated utility slots readable.
    if isWeaponCell then
        local weaponScale = tonumber(layout.scale) or 1
        local weaponSlotPx = Clamp(saved.characterGearSlotSize029206, 64, 128) * weaponScale
        local colGap = weaponSlotPx + math.max(34, 54 * weaponScale)
        width = Clamp(colGap - 12, 88, 170)
    end

    local nameHeight = isWeaponCell and (fontSize + 5) or ((fontSize + 5) * 2)
    local typeHeight = fontSize + 7
    local setHeight = isWeaponCell and (math.max(10, fontSize - 2) + 5) or ((math.max(10, fontSize - 2) + 5) * 2)
    nameLabel:SetDimensions(width, nameHeight); typeLabel:SetDimensions(width, typeHeight); setLabel:SetDimensions(width, setHeight)
    if nameLabel.SetMaxLineCount then pcall(nameLabel.SetMaxLineCount, nameLabel, isWeaponCell and 1 or 2) end
    if setLabel.SetMaxLineCount then pcall(setLabel.SetMaxLineCount, setLabel, isWeaponCell and 1 or 2) end
    nameLabel:ClearAnchors(); typeLabel:ClearAnchors(); setLabel:ClearAnchors()

    local textSide = "center"
    if isWeaponCell then
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        typeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        setLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        -- v0.29.449: every player-weapon label now lives BELOW its box. This
        -- guarantees the text never covers the weapon art or the neighboring
        -- poison/utility cells, even when the off-hand or set name is long.
        nameLabel:SetAnchor(TOP, control, BOTTOM, 0, 5)
        setLabel:SetAnchor(TOP, nameLabel, BOTTOM, 0, -1)
        typeLabel:SetAnchor(TOP, density == "detailed" and setLabel or nameLabel, BOTTOM, 0, -1)
    else
        local outwardSide = slotData.side
        if slotData.weaponCol == nil then
            if (slotData.x or 0) < 0 then
                outwardSide = "left"
            elseif (slotData.x or 0) > 0 then
                outwardSide = "right"
            end
        end
        textSide = outwardSide or "right"
        local labelGap = slotData.weaponCol ~= nil and 26 or 10
        if outwardSide == "left" then
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); typeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); setLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            nameLabel:SetAnchor(TOPRIGHT, control, TOPLEFT, -labelGap, -4)
            typeLabel:SetAnchor(TOPRIGHT, nameLabel, BOTTOMRIGHT, 0, -2)
            setLabel:SetAnchor(TOPRIGHT, density == "detailed" and typeLabel or nameLabel, BOTTOMRIGHT, 0, -2)
        else
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT); typeLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT); setLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            nameLabel:SetAnchor(TOPLEFT, control, TOPRIGHT, labelGap, -4)
            typeLabel:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, 0, -2)
            setLabel:SetAnchor(TOPLEFT, density == "detailed" and typeLabel or nameLabel, BOTTOMLEFT, 0, -2)
        end
    end
    nameLabel:SetText(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName))
    if quality then
        local qc = Safe(GetItemQualityColor, nil, quality)
        if qc and qc.UnpackRGBA then nameLabel:SetColor(qc:UnpackRGBA()) else nameLabel:SetColor(1,1,1,1) end
    end
    typeLabel:SetText(ItemTypeText(link, slotData.slot))
    typeLabel:SetColor(1,1,1,1)
    typeLabel:SetHidden(not detailVisible or density ~= "detailed")
    local hasSet, setName, _, normalEquipped, maxEquipped, _, perfectedEquipped = false, "", 0,0,0,0,0
    if link ~= "" and type(GetItemLinkSetInfo) == "function" then
        hasSet, setName, _, normalEquipped, maxEquipped, _, perfectedEquipped = GetItemLinkSetInfo(link)
    end
    if hasSet and tonumber(maxEquipped) and maxEquipped > 0 then
        local count = math.min((tonumber(normalEquipped) or 0) + (tonumber(perfectedEquipped) or 0), maxEquipped)
        setLabel:SetText(zo_strformat("<<1>>  <<2>>/<<3>>", setName or "Set", count, maxEquipped))
        setLabel:SetColor(0.98,0.99,1,1)
        setLabel:SetHidden(not detailVisible or saved.characterGearShowSetCount029206 == false)
    else setLabel:SetHidden(true) end
    nameLabel:SetHidden(not detailVisible)
    if density ~= "detailed" then typeLabel:SetHidden(true) end
    LayoutTextBackdrop(control, isWeaponCell, textSide)

    local actorCategory = isCompanion and rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_COMPANION") or rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_PLAYER")
    local outfitSlots = actorCategory and WeaponOutfitSlots(actorCategory) or {}
    local appearance = actorCategory and AppearanceState(actorCategory) or {costume=false,hat=false}
    local outfit = actorCategory and HasAppearanceOverride(slotData, actorCategory, outfitSlots)
    local costume = COSTUME_SLOTS[slotData.slot] and (appearance.costume or (slotData.slot == EQUIP_SLOT_HEAD and appearance.hat))
    local outfitIcon, costumeIcon = control.EASGearOutfit, control.EASGearCostume
    outfitIcon:ClearAnchors(); costumeIcon:ClearAnchors()

    -- v0.29.233: weapon appearance indicators get their own dedicated row above
    -- or below the weapon slot instead of hugging the slot edge. This keeps the
    -- marker visually separate from the weapon box and the bar-swap icon.
    if slotData.weaponCol ~= nil then
        -- v0.29.235: weapon appearance is represented in a dedicated utility
        -- cell in the 4-wide weapon grid, so do not float tiny badges around
        -- individual weapon boxes anymore.
        outfitIcon:SetHidden(true)
        costumeIcon:SetHidden(true)
    elseif slotData.side == "left" then
        outfitIcon:SetDimensions(20, 20)
        costumeIcon:SetDimensions(20, 20)
        outfitIcon:SetAnchor(BOTTOMRIGHT, control, BOTTOMLEFT, -8, 0)
        costumeIcon:SetAnchor(BOTTOMRIGHT, outfitIcon, BOTTOMLEFT, -4, 0)
    else
        outfitIcon:SetDimensions(20, 20)
        costumeIcon:SetDimensions(20, 20)
        outfitIcon:SetAnchor(BOTTOMLEFT, control, BOTTOMRIGHT, 8, 0)
        costumeIcon:SetAnchor(BOTTOMLEFT, outfitIcon, BOTTOMRIGHT, 4, 0)
    end
    if slotData.weaponCol == nil then
        outfitIcon:SetHidden(not outfit)
        costumeIcon:SetHidden(not costume)
    end
end

-- Architecture ownership: one stable public RefreshSlot entry point. Later
-- presentation layers replace only the internal implementation chain.
local RefreshSlotImpl = RefreshSlotBase029500

function G:RefreshSlot(...)
    return RefreshSlotImpl(self, ...)
end

local function PlayerWeaponGridMetrics(layout, slotSize, scale)
    local slotPx = slotSize * scale
    local colGap = slotPx + math.max(34, 54 * scale)
    -- v0.29.461: restore a bit more breathing room between the two weapon rows
    -- to stop top-row labels/icons from colliding with the lower row, while
    -- keeping the whole weapon block compact enough to avoid the footer.
    local rowGap = slotPx + math.max(68, 84 * scale)
    local baseCenter = layout.centerY + layout.weaponY - math.max(18, 24 * scale)
    local maxCenter = layout.h - math.max(138, 168 * scale)
    local armorBottomCenter = layout.centerY + layout.topY + 4 * layout.rowStep
    local minCenter = armorBottomCenter + slotPx + rowGap * 0.14 + math.max(0, 4 * scale)
    local centerY = math.min(math.max(baseCenter, minCenter), maxCenter)
    return slotPx, colGap, rowGap, centerY
end

local ApplySlotLayoutImpl

function G:ApplySlotLayout(...)

    return ApplySlotLayoutImpl(self, ...)

end

ApplySlotLayoutImpl = function(self, slotData, slotSize, scale, isCompanion)
    local c = rawget(_G, slotData.control)
    if not c then return end
    local layout = self.currentLayout or self:BuildAdaptiveLayout(isCompanion)
    local x, y
    if slotData.weaponCol ~= nil then
        local slotPx = slotSize * scale
        if isCompanion then
            local gap = slotPx + 22 * scale
            x = layout.centerX + slotData.weaponCol * gap
            if (slotData.weaponCol or 0) > 0 then
                -- v0.29.223: pull the right-side companion gear farther away from
                -- the divider/info panel without moving the companion off center.
                x = x - (34 * scale)
            end
            y = layout.centerY + layout.weaponY
        else
            -- v0.29.235: 4-wide weapon grid. Columns 1-3 are Main/Off/Poison;
            -- column 4 is reserved for utility cells (Appearance / Bar Swap).
            -- The entire grid stays lower than the armor rows but remains clear
            -- of ESO's bottom action prompt.
            local _, colGap, rowGap, centerY = PlayerWeaponGridMetrics(layout, slotSize, scale)
            local gridColBySlot = {
                [EQUIP_SLOT_MAIN_HAND]=1,
                [EQUIP_SLOT_OFF_HAND]=2,
                [EQUIP_SLOT_POISON]=3,
                [EQUIP_SLOT_BACKUP_MAIN]=1,
                [EQUIP_SLOT_BACKUP_OFF]=2,
                [EQUIP_SLOT_BACKUP_POISON]=3,
            }
            local gridRowBySlot = {
                [EQUIP_SLOT_MAIN_HAND]=1,
                [EQUIP_SLOT_OFF_HAND]=1,
                [EQUIP_SLOT_POISON]=1,
                [EQUIP_SLOT_BACKUP_MAIN]=2,
                [EQUIP_SLOT_BACKUP_OFF]=2,
                [EQUIP_SLOT_BACKUP_POISON]=2,
            }
            local col = gridColBySlot[slotData.slot] or 2
            local row = gridRowBySlot[slotData.slot] or 1
            x = layout.centerX + (col - 2.5) * colGap
            y = centerY + (row == 1 and -0.5 or 0.5) * rowGap
        end
    else
        local rowBySlot = {
            [EQUIP_SLOT_HEAD]=0, [EQUIP_SLOT_NECK]=0,
            [EQUIP_SLOT_SHOULDERS]=1, [EQUIP_SLOT_CHEST]=1,
            [EQUIP_SLOT_HAND]=2, [EQUIP_SLOT_WAIST]=2,
            [EQUIP_SLOT_RING1]=3, [EQUIP_SLOT_RING2]=3,
            [EQUIP_SLOT_LEGS]=4, [EQUIP_SLOT_FEET]=4,
        }
        local row = rowBySlot[slotData.slot] or 2
        local sideSign = (slotData.x or 0) < 0 and -1 or 1
        x = layout.centerX + sideSign * layout.spread
        if isCompanion and sideSign > 0 then
            x = x - (34 * scale)
        end
        y = layout.centerY + layout.topY + row * layout.rowStep
    end
    c:SetScale(1)
    c:SetHidden(false)
    c:ClearAnchors()
    c:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
    c:SetDimensions(slotSize * scale, slotSize * scale)
    LayoutSlotBackdrop(c, Safe(GetItemName, "", GetBag(isCompanion), slotData.slot) ~= "")
    local highlight = c.GetNamedChild and c:GetNamedChild("Highlight") or nil
    if highlight then
        local hs = slotSize * scale * 1.58
        highlight:SetDimensions(hs, hs); highlight:ClearAnchors(); highlight:SetAnchor(CENTER, c, CENTER)
    end
    self:RefreshSlot(slotData, isCompanion)
end

function G:CapturePlayerState()
    if self.playerOriginal then return end
    local states = {}
    local function add(control) if control then states[#states + 1] = CaptureControlState(control) end end
    add(rawget(_G, "ZO_Character"))
    add(rawget(_G, "ZO_CharacterAccessoriesSection"))
    add(rawget(_G, "ZO_CharacterWeaponsSection"))
    add(rawget(_G, "ZO_CharacterHeaderSection"))
    add(rawget(_G, "ZO_CharacterHeaderSectionTitle"))
    add(rawget(_G, "ZO_CharacterHeaderSectionDivider"))
    add(rawget(_G, "ZO_CharacterApparelSectionText"))
    add(rawget(_G, "ZO_CharacterEquipmentSlotsCostume"))
    local nativeBg = rawget(_G, "ZO_SharedWideLeftPanelBackground")
    add(nativeBg)
    if nativeBg and nativeBg.GetNamedChild then
        add(nativeBg:GetNamedChild("Left"))
        add(nativeBg:GetNamedChild("Right"))
    end
    add(rawget(_G, "ZO_CharacterPaperDoll"))
    add(rawget(_G, "ZO_CharacterWeaponSwap"))
    add(rawget(_G, "ZO_CharacterWindowStats"))
    for _, d in ipairs(PLAYER_SLOTS) do add(rawget(_G, d.control)) end
    self.playerOriginal = states
end

function G:CaptureCompanionState()
    if self.companionOriginal then return end
    local states = {}
    local function add(control) if control then states[#states + 1] = CaptureControlState(control) end end
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevel"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelTitle"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelHeaderDivider"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelApparelSectionText"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelPaperDoll"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelAccessoriesSection"))
    add(rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelWeaponsSection"))
    local thinBg = rawget(_G, "ZO_SharedThinLeftPanelBackground")
    add(thinBg)
    if thinBg and thinBg.GetNamedChild then
        add(thinBg:GetNamedChild("Left"))
        add(thinBg:GetNamedChild("Right"))
    end
    for _, d in ipairs(COMPANION_SLOTS) do add(rawget(_G, d.control)) end
    local root = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevel")
    if root and root.GetNumChildren and root.GetChild then
        local count = SafeNumber(root.GetNumChildren, 0, root) or 0
        for i = 1, count do
            local child = Safe(root.GetChild, nil, root, i)
            if child then add(child) end
        end
    end
    self.companionOriginal = states
end

function G:RestorePlayerState()
    if self.playerOriginal then for _, state in ipairs(self.playerOriginal) do RestoreControlState(state) end end
    for _, d in ipairs(PLAYER_SLOTS) do HideSlotPresentation(rawget(_G, d.control)) end
    if ZO_CharacterPaperDoll then ZO_CharacterPaperDoll:SetColor(1,1,1,1) end
end

-- Player cleanup is owned by the final lifecycle-safe implementation below.

local function CleanupCompanionSceneBase029365(self)
    self:HideGearStatsCard()
    self:RestoreCompanionInfoPanel()
    -- v0.29.220: companion scene gets the same hard cleanup as the player
    -- Character scene. Restore shared/native state first, then hide only the
    -- Companion-scene-owned controls so nothing leaks onto normal gameplay.
    self:RestoreCompanionState()
    self:HideWorkspaceBackdrop()
    local controls = {
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevel"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelTitle"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelHeaderDivider"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelApparelSectionText"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelPaperDoll"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelAccessoriesSection"),
        rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelWeaponsSection"),
        rawget(_G, "ZO_SharedThinLeftPanelBackground"),
    }
    for _, control in ipairs(controls) do
        if control and control.SetHidden then pcall(control.SetHidden, control, true) end
    end
    for _, d in ipairs(COMPANION_SLOTS) do
        local c = rawget(_G, d.control)
        HideSlotPresentation(c)
        if c and c.SetHidden then pcall(c.SetHidden, c, true) end
    end
end

function G:RestoreCompanionState()
    self:RestoreCompanionInfoPanel()
    if self.companionOriginal then for _, state in ipairs(self.companionOriginal) do RestoreControlState(state) end end
    self._hiddenCompanionChildren = nil
    for _, d in ipairs(COMPANION_SLOTS) do HideSlotPresentation(rawget(_G, d.control)) end
end

function G:RestoreAll()
    self:HideWeaponUtilityCells()
    self:RestorePlayerState()
    self:RestoreCompanionState()
    self:HideWorkspaceBackdrop()
    self:HideGearStatsCard()
    if self.inventoryScene and self.distanceFragment and self.cameraFragmentAdded then
        pcall(self.inventoryScene.RemoveFragment, self.inventoryScene, self.distanceFragment)
        self.cameraFragmentAdded = false
    end
end

local function EnsureWeaponUtilityCell(self, key, iconTexture)
    self.weaponUtilityCells = self.weaponUtilityCells or {}
    local cell = self.weaponUtilityCells[key]
    if cell then return cell end

    cell = WINDOW_MANAGER:CreateTopLevelWindow(NS .. "WeaponUtility" .. key)
    cell:SetMouseEnabled(false)
    cell:SetClampedToScreen(true)
    if cell.SetDrawTier and rawget(_G,"DT_HIGH") then cell:SetDrawTier(DT_HIGH) end
    cell:SetDrawLayer(DL_CONTROLS)
    cell:SetDrawLevel(40)

    local bg = WINDOW_MANAGER:CreateControl(nil, cell, CT_BACKDROP)
    bg:SetAnchorFill(cell)
    bg:SetCenterColor(0.035, 0.045, 0.07, 0.92)
    bg:SetEdgeColor(0.72, 0.64, 0.40, 0.82)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 3)
    cell.bg = bg

    local icon = WINDOW_MANAGER:CreateControl(nil, cell, CT_TEXTURE)
    icon:SetAnchor(CENTER, cell, CENTER)
    icon:SetTexture(iconTexture or OUTFIT_ICON)
    icon:SetColor(1,1,1,1)
    icon:SetMouseEnabled(false)
    icon:SetDrawLayer(DL_OVERLAY)
    icon:SetDrawLevel(50)
    cell.icon = icon

    cell:SetHidden(true)
    self.weaponUtilityCells[key] = cell
    return cell
end

local HideWeaponUtilityCellsImpl

function G:HideWeaponUtilityCells(...)

    return HideWeaponUtilityCellsImpl(self, ...)

end

HideWeaponUtilityCellsImpl = function(self)
    if not self.weaponUtilityCells then return end
    for _, cell in pairs(self.weaponUtilityCells) do
        if cell and cell.SetHidden then cell:SetHidden(true) end
    end
end

local LayoutWeaponUtilityCellsImpl

function G:LayoutWeaponUtilityCells(...)

    return LayoutWeaponUtilityCellsImpl(self, ...)

end

LayoutWeaponUtilityCellsImpl = function(self, layout, slotSize, scale)
    if not layout then return end
    local slotPx, colGap, rowGap, centerY = PlayerWeaponGridMetrics(layout, slotSize, scale)
    -- v0.29.459: the detached utility column created an awkward empty gap to the
    -- right of the weapon rows. Keep it outside the core drag area, but bring it
    -- much closer to the rest of the grid so the layout feels intentional.
    local desiredUtilityX = layout.centerX + 1.55 * colGap
    local maxUtilityX = (layout.safeRight or (layout.w * 0.78)) - slotPx * 0.54
    local utilityX = math.min(desiredUtilityX, maxUtilityX)
    local topY = centerY - rowGap * 0.5
    local bottomY = centerY + rowGap * 0.5

    local appearance = EnsureWeaponUtilityCell(self, "Appearance", OUTFIT_ICON)
    appearance:SetDimensions(slotPx, slotPx)
    appearance:ClearAnchors()
    appearance:SetAnchor(CENTER, GuiRoot, TOPLEFT, utilityX, topY)
    appearance.icon:SetDimensions(slotPx * 0.58, slotPx * 0.58)

    -- The appearance cell is a real button now, not just a decorative icon.
    -- Clicking it opens ESO's Outfit Styles screen. It is positioned outside
    -- the character rotation canvas so it no longer blocks click-drag rotation.
    appearance:SetMouseEnabled(true)
    appearance:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or upInside == false then return end
        if not SCENE_MANAGER then return end
        local outfitScene = SCENE_MANAGER:GetScene("outfitStylesBook")
        if outfitScene then
            SCENE_MANAGER:Show("outfitStylesBook")
            return
        end
        local collectionsScene = SCENE_MANAGER:GetScene("collectionsBook")
        if collectionsScene then SCENE_MANAGER:Show("collectionsBook") end
    end)

    local actorCategory = rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_PLAYER")
    local outfitSlots = actorCategory and WeaponOutfitSlots(actorCategory) or {}
    local hasWeaponAppearance = false
    if actorCategory then
        for _, slotData in ipairs(PLAYER_SLOTS) do
            if slotData.weaponOutfit and HasAppearanceOverride(slotData, actorCategory, outfitSlots) then
                hasWeaponAppearance = true
                break
            end
        end
    end
    if hasWeaponAppearance then
        appearance.bg:SetEdgeColor(0.35, 0.85, 1.00, 1)
        appearance.icon:SetColor(0.55, 0.92, 1.00, 1)
    else
        appearance.bg:SetEdgeColor(0.58, 0.58, 0.62, 0.78)
        appearance.icon:SetColor(0.80, 0.80, 0.82, 0.92)
    end
    appearance:SetHidden(false)

    local swapCell = EnsureWeaponUtilityCell(self, "Swap", "EsoUI/Art/ActionBar/abilityFrame64_up.dds")
    swapCell:SetDimensions(slotPx, slotPx)
    swapCell:ClearAnchors()
    swapCell:SetAnchor(CENTER, GuiRoot, TOPLEFT, utilityX, bottomY)
    swapCell.icon:SetHidden(true) -- native ZO_CharacterWeaponSwap is centered here instead
    swapCell.bg:SetEdgeColor(0.72, 0.64, 0.40, 0.86)
    swapCell:SetHidden(false)

    if ZO_CharacterWeaponSwap then
        local swapScale = Clamp(slotSize / 64, 0.74, 1.20) * scale * 0.78
        ZO_CharacterWeaponSwap:SetScale(swapScale)
        ZO_CharacterWeaponSwap:ClearAnchors()
        ZO_CharacterWeaponSwap:SetAnchor(CENTER, swapCell, CENTER, 0, 0)
        ZO_CharacterWeaponSwap:SetHidden(false)
    end
end

function G:EnsurePlayerFramingFragment()
    local fragment = rawget(_G, "FRAME_PLAYER_FRAGMENT")
    if not fragment then return end
    local scenes = { self.inventoryScene, self.characterScene }
    for _, scene in ipairs(scenes) do
        if scene and scene.IsShowing and scene:IsShowing() and scene.HasFragment and scene.AddFragment then
            local has = false
            local ok, value = pcall(scene.HasFragment, scene, fragment)
            if ok then has = value == true end
            if not has then pcall(scene.AddFragment, scene, fragment) end
        end
    end
end

function G:ApplyPlayerLayout()
    if not self:IsEnabled() then return end
    if not rawget(_G, "ZO_Character") then return end
    self:CapturePlayerState()
    local layout = self:BuildAdaptiveLayout(false)
    self.currentLayout = layout
    self:LayoutWorkspaceBackdrop(layout)
    local scale = layout.scale
    local slotSize = Clamp(EPC.saved.characterGearSlotSize029206, 64, 128)

    local root = ZO_Character
    -- v0.29.236: do NOT collapse/reparent the native Character root to 1x1.
    -- ESO uses its native Character/framing controls for mouse interaction with
    -- the 3D player. Preserve that state, while our gear slots remain anchored
    -- directly to GuiRoot and can still use the Suite layout.
    RestoreCapturedControlState(self.playerOriginal, root)
    root:SetHidden(false)
    if root.SetMouseEnabled then root:SetMouseEnabled(true) end
    self:EnsurePlayerFramingFragment()

    -- v0.29.217: remove ESO's native wide-left black gradient while the
    -- enhanced Character Gear screen is active. Its original state was captured
    -- in CapturePlayerState() and is restored when the scene closes.
    local nativeWideLeft = rawget(_G, "ZO_SharedWideLeftPanelBackground")
    if nativeWideLeft then nativeWideLeft:SetHidden(true) end

    if ZO_CharacterAccessoriesSection then ZO_CharacterAccessoriesSection:SetHidden(true) end
    if ZO_CharacterWeaponsSection then ZO_CharacterWeaponsSection:SetHidden(true) end
    -- Keep the face/upper-body area completely clear. ESO can refresh the apparel
    -- status label independently of the parent section, so hide each native header
    -- child explicitly every time the Suite reapplies this scene layout.
    if ZO_CharacterHeaderSection then
        ZO_CharacterHeaderSection:SetHidden(true)
        ZO_CharacterHeaderSection:SetScale(1)
        ZO_CharacterHeaderSection:ClearAnchors()
    end
    local headerTitle = rawget(_G, "ZO_CharacterHeaderSectionTitle")
    local headerDivider = rawget(_G, "ZO_CharacterHeaderSectionDivider")
    local apparelText = rawget(_G, "ZO_CharacterApparelSectionText")
    if headerTitle then headerTitle:SetHidden(true) end
    if headerDivider then headerDivider:SetHidden(true) end
    if apparelText then apparelText:SetHidden(true) end
    -- Obsolete native costume/style slot: the Suite already exposes appearance
    -- state on the real equipment slots, and this legacy control can otherwise
    -- sit underneath the movable stats card.
    local obsoleteCostumeSlot = rawget(_G, "ZO_CharacterEquipmentSlotsCostume")
    if obsoleteCostumeSlot then obsoleteCostumeSlot:SetHidden(true) end

    -- v0.29.208: remove the redundant orange/paper-doll silhouette. The real
    -- framed 3D player is the only character shown in the center of the gear UI.
    if ZO_CharacterPaperDoll then
        ZO_CharacterPaperDoll:SetHidden(true)
        ZO_CharacterPaperDoll:SetColor(1,1,1,1)
    end

    -- The full native attribute list was the large block crossing the character and
    -- right-side gear in the reported 2560x1440 layout. Auto mode keeps it off on
    -- standard-width screens; ultrawide users can retain it, and Show/Hide is explicit.
    local stats = rawget(_G, "ZO_CharacterWindowStats")
    if stats then stats:SetHidden(true) end
    self:RefreshGearStatsCard(false)

    for _, slotData in ipairs(PLAYER_SLOTS) do self:ApplySlotLayout(slotData, slotSize, scale, false) end

    -- v0.29.235: appearance and bar swap now occupy the fourth column of the
    -- 4-wide weapon grid, one dedicated cell per row.
    self:LayoutWeaponUtilityCells(layout, slotSize, scale)

    -- Damaged-item warnings remain on the actual equipment slots/condition text.
    -- The removed silhouette is no longer used as a warning surface.
    self:ApplyCamera(layout)
end

local ApplyCompanionLayoutImpl

function G:ApplyCompanionLayout(...)

    return ApplyCompanionLayoutImpl(self, ...)

end

ApplyCompanionLayoutImpl = function(self)
    if not self:IsEnabled() then return end
    if EPC.saved.characterGearCompanion029206 == false then self:RestoreCompanionState(); return end
    if not rawget(_G, "COMPANION_CHARACTER_KEYBOARD_SCENE") then return end

    self:CaptureCompanionState()
    local layout = self:BuildAdaptiveLayout(true)
    self.currentLayout = layout
    self:LayoutWorkspaceBackdrop(layout)
    local scale = layout.scale
    local slotSize = Clamp(EPC.saved.characterGearSlotSize029206, 64, 128)

    local root = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevel")
    if root then
        -- Preserve ESO's native companion interaction surface. Collapsing this
        -- root to 1x1 removed the mouse region used by the companion preview.
        RestoreCapturedControlState(self.companionOriginal, root)
        root:SetHidden(false)
        if root.SetMouseEnabled then root:SetMouseEnabled(true) end
    end
    self:ShiftCompanionInfoPanelRight(layout)
    self:RefreshGearStatsCard(true)

    -- Match the clean player gear screen: remove ESO's companion thin-left
    -- panel and native title/apparel header while this enhanced scene is open.
    local thinBg = rawget(_G, "ZO_SharedThinLeftPanelBackground")
    if thinBg then thinBg:SetHidden(true) end
    local title = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelTitle")
    local divider = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelHeaderDivider")
    local apparel = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelApparelSectionText")
    if title then title:SetHidden(true) end
    if divider then divider:SetHidden(true) end
    if apparel then apparel:SetHidden(true) end

    local accessories = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelAccessoriesSection")
    local weapons = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelWeaponsSection")
    if accessories then accessories:SetHidden(true) end
    if weapons then weapons:SetHidden(true) end

    -- v0.29.236: do not blanket-hide every unknown companion child. Some of
    -- those native controls participate in mouse interaction/character rotation.
    -- Known visual panels are already hidden explicitly above.

    -- The white silhouette is redundant and was explicitly rejected. Keep the
    -- real companion model only.
    local doll = rawget(_G, "ZO_CompanionCharacterWindow_Keyboard_TopLevelPaperDoll")
    if doll then
        doll:SetHidden(true)
        if doll.SetAlpha then doll:SetAlpha(0) end
    end

    for _, slotData in ipairs(COMPANION_SLOTS) do
        self:ApplySlotLayout(slotData, slotSize, scale, true)
        local c = rawget(_G, slotData.control)
        if c then c:SetHidden(false) end
    end
end

function G:ApplyCamera(layout)
    if self.inventoryScene and self.distanceFragment and not self.cameraFragmentAdded then
        pcall(self.inventoryScene.AddFragment, self.inventoryScene, self.distanceFragment)
        self.cameraFragmentAdded = true
    end
    if not self:IsPlayerSceneShowing() then return end

    layout = layout or self.currentLayout or self:BuildAdaptiveLayout(false)
    local baseDistance = Clamp(EPC.saved.characterGearCameraDistance029206, 1.0, 2.95)
    -- Reuse the old figure-size control for the REAL 3D character now that the
    -- paper doll is removed. Higher size = closer framing.
    local characterSize = Clamp(EPC.saved.characterGearFigureScale029206, 0.65, 1.80)
    local distance = Clamp(baseDistance / characterSize, 1.0, 2.95)

    if self.distanceFragment then self.distanceFragment.lookAtDistanceFactor = distance end

    -- Frame the real player in the actual center of the free character canvas,
    -- not the physical center of the monitor. This uses the left-side space that
    -- was previously empty while respecting the inventory boundary on the right.
    if type(SetFrameLocalPlayerTarget) == "function" and type(NormalizeUICanvasPoint) == "function" then
        local targetX = tonumber(layout.centerX) or ((layout.w or 1920) * 0.5)
        local targetY = (tonumber(layout.h) or 1080) * 0.58
        local ok, nx, ny = pcall(NormalizeUICanvasPoint, targetX, targetY)
        if ok and nx and ny then pcall(SetFrameLocalPlayerTarget, nx, ny) end
    end

    if type(SetFrameLocalPlayerLookAtDistanceFactor) == "function" then pcall(SetFrameLocalPlayerLookAtDistanceFactor, distance) end
    if type(RequestReframeLocalPlayerInGameCamera) == "function" then pcall(RequestReframeLocalPlayerInGameCamera) end
end

function G:Refresh()
    if not self:IsEnabled() then self:RestoreAll(); return end
    local shown = false
    if self:IsPlayerSceneShowing() then self:ApplyPlayerLayout(); shown = true end
    if self:IsCompanionSceneShowing() then self:ApplyCompanionLayout(); shown = true end
    if not shown then
        self:HideWorkspaceBackdrop()
        self:HideGearStatsCard()
    end
end

function G:RequestRefresh(delay)
    if self.refreshPending then return end
    self.refreshPending = true
    zo_callLater(function()
        G.refreshPending = false
        G:Refresh()
    end, tonumber(delay) or 50)
end

function G:HideAllDecor()
    self:HideWeaponUtilityCells()
    for _, d in ipairs(PLAYER_SLOTS) do HideDecor(rawget(_G,d.control)) end
    for _, d in ipairs(COMPANION_SLOTS) do HideDecor(rawget(_G,d.control)) end
end

function G:SetupScenes()
    if not SCENE_MANAGER then return end
    self.inventoryScene = SCENE_MANAGER:GetScene("inventory")
    self.characterScene = SCENE_MANAGER:GetScene("character")
    local function hook(scene)
        if not scene or scene.EASCharacterGear029206 then return end
        scene.EASCharacterGear029206 = true
        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then
                G:EnsurePlayerFramingFragment()
                G:RequestRefresh(20)
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
                G:CleanupPlayerScene()
            end
        end)
    end
    hook(self.inventoryScene); hook(self.characterScene)

    local companionScene = rawget(_G, "COMPANION_CHARACTER_KEYBOARD_SCENE")
    if companionScene and not companionScene.EASCharacterGear029206 then
        companionScene.EASCharacterGear029206 = true
        companionScene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then
                G:RequestRefresh(20)
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
                G:CleanupCompanionScene()
            end
        end)
    end

    if self.inventoryScene and not self.distanceFragment and type(ZO_CharacterFramingLookAtDistance) == "table" and ZO_CharacterFramingLookAtDistance.New then
        self.distanceFragment = ZO_CharacterFramingLookAtDistance:New(Clamp(EPC.saved.characterGearCameraDistance029206,1.0,2.95))
        if self.distanceFragment then self.inventoryScene:AddFragment(self.distanceFragment); self.cameraFragmentAdded = true end
        if rawget(_G,"FRAME_PLAYER_FRAGMENT") then self.inventoryScene:AddFragment(FRAME_PLAYER_FRAGMENT) end
    end
end

function G:RegisterEvents()
    local em = EVENT_MANAGER
    if not em then return end
    local function reg(event, suffix)
        if event then em:RegisterForEvent(NS .. suffix, event, function() G:RequestRefresh(40) end) end
    end
    reg(rawget(_G,"EVENT_INVENTORY_SINGLE_SLOT_UPDATE"), "Slot")
    reg(rawget(_G,"EVENT_INVENTORY_FULL_UPDATE"), "Full")
    reg(rawget(_G,"EVENT_ACTIVE_WEAPON_PAIR_CHANGED"), "Weapon")
    reg(rawget(_G,"EVENT_ARMORY_BUILD_RESTORE_RESPONSE"), "Armory")
    reg(rawget(_G,"EVENT_COLLECTIBLE_UPDATED"), "Collectible")
    reg(rawget(_G,"EVENT_COMPANION_ACTIVATED"), "CompanionOn")
    reg(rawget(_G,"EVENT_COMPANION_DEACTIVATED"), "CompanionOff")
end

local ResetDefaultsImpl

function G:ResetDefaults(...)

    return ResetDefaultsImpl(self, ...)

end

ResetDefaultsImpl = function(self)
    local d = EPC.defaults
    local s = EPC.saved
    local keys = {
        "characterGearScreenEnabled029206","characterGearCompanion029206","characterGearSlotSize029206",
        "characterGearFontSize029206","characterGearShowQuality029206","characterGearShowCondition029206",
        "characterGearShowLevel029206","characterGearShowDetails029206","characterGearShowSetCount029206",
        "characterGearRepairThreshold029206","characterGearChargeThreshold029206","characterGearLevelWarning029206",
        "characterGearFigureScale029206","characterGearHeaderScale029206","characterGearCameraDistance029206",
        "characterGearColorFigureWarning029206",
        "characterGearAdaptiveLayout029207","characterGearDensity029207","characterGearStatsMode029207",
        "characterGearStatsX029355","characterGearStatsY029355","characterGearStatsMoved029355",
    }
    for _, k in ipairs(keys) do s[k] = d[k] end
    self:RequestRefresh(10)
end

function G:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:SetupScenes()
    self:RegisterEvents()
    zo_callLater(function() G:SetupScenes(); G:RequestRefresh(10) end, 500)
end


-- v0.29.365 - disabling the Suite gear presentation must restore the native
-- Character UI immediately, not only after a scene reload.
function G:SetEnabled029365(enabled)
    if enabled then
        self:RequestRefresh(0)
        return
    end
    self.refreshPending = false
    self:RestoreAll()
    if self:IsPlayerSceneShowing() then
        local showControls={
            rawget(_G,"ZO_Character"),rawget(_G,"ZO_CharacterAccessoriesSection"),rawget(_G,"ZO_CharacterWeaponsSection"),
            rawget(_G,"ZO_CharacterHeaderSection"),rawget(_G,"ZO_CharacterPaperDoll"),rawget(_G,"ZO_CharacterWeaponSwap"),
            rawget(_G,"ZO_CharacterWindowStats"),rawget(_G,"ZO_SharedWideLeftPanelBackground")
        }
        for _,c in ipairs(showControls) do if c and c.SetHidden then pcall(c.SetHidden,c,false) end end
        for _,d in ipairs(PLAYER_SLOTS) do local c=rawget(_G,d.control); if c and c.SetHidden then pcall(c.SetHidden,c,false) end end
        if type(ZO_Character_UpdateAll)=="function" then pcall(ZO_Character_UpdateAll) end
        if type(ZO_Character_UpdateWindow)=="function" then pcall(ZO_Character_UpdateWindow) end
    end
    if self:IsCompanionSceneShowing() then
        for _,d in ipairs(COMPANION_SLOTS) do local c=rawget(_G,d.control); if c and c.SetHidden then pcall(c.SetHidden,c,false) end end
        local root=rawget(_G,"ZO_CompanionCharacterWindow_Keyboard_TopLevel"); if root and root.SetHidden then pcall(root.SetHidden,root,false) end
    end
end



-- v0.29.365 follow-up: companion cleanup restores native state when disabled.
local CleanupCompanionSceneImpl
function G:CleanupCompanionScene(...)
    return CleanupCompanionSceneImpl(self, ...)
end
CleanupCompanionSceneImpl = function(self)
    if not self:IsEnabled() then self:RestoreAll(); return end
    return CleanupCompanionSceneBase029365(self)
end

-- ============================================================================
-- v0.29.372 - Safe Character/Inventory scene cleanup.
-- ESO owns visibility of its Character controls.  The Suite may alter anchors,
-- decoration and camera framing while the scene is active, but it must never
-- hard-hide ESO scene controls during stacked transitions (Inventory ->
-- Character -> UI-mode/Alt).  Doing so can leave the entire active UI blank
-- until a reload or another scene rebuilds those controls.
-- ============================================================================
function G:IsPlayerSceneActiveOrTransitioning029372(excludeScene)
    local scenes = { self.inventoryScene, self.characterScene }
    for _, scene in ipairs(scenes) do
        if scene and scene ~= excludeScene then
            local state = nil
            if type(scene.GetState) == "function" then
                local ok, value = pcall(scene.GetState, scene)
                if ok then state = value end
            end
            if state == SCENE_SHOWING or state == SCENE_SHOWN then return true end
            if type(scene.IsShowing) == "function" then
                local ok, showing = pcall(scene.IsShowing, scene)
                if ok and showing == true then return true end
            end
        end
    end
    return false
end

function G:CleanupPlayerScene029372(sourceScene)
    if not self:IsEnabled() then
        self:RestoreAll()
        return
    end

    -- If Inventory is handing off to Character (or vice versa), do not tear
    -- down the shared Character presentation between the two scenes.
    if self:IsPlayerSceneActiveOrTransitioning029372(sourceScene) then
        self:RequestRefresh(0)
        return
    end

    self:HideGearStatsCard()
    self:HideWeaponUtilityCells()
    self:RestorePlayerState()
    self:HideWorkspaceBackdrop()

    -- Deliberately do NOT SetHidden(true) on ZO_Character, its sections,
    -- paper doll, stats, weapon swap or equipment controls here.  Those are
    -- native scene-owned controls and ESO's fragments decide their visibility.
    -- We only remove Suite decoration/presentation from the equipment slots.
    for _, d in ipairs(PLAYER_SLOTS) do
        HideSlotPresentation(rawget(_G, d.control))
    end
end

-- Re-registering scene callbacks is unnecessary because the existing callback
-- closures resolve G:CleanupPlayerScene dynamically.  Keep a small UI-mode
-- reconciliation hook so Alt/UI-mode changes during an active Character scene
-- immediately re-apply the layout instead of leaving a transition frame stale.
if EVENT_MANAGER and rawget(_G, "EVENT_GAME_CAMERA_UI_MODE_CHANGED") then
    EPC.Runtime:UnregisterEvent("CharacterGearScreen","UIModeSafe029372")
    EPC.Runtime:RegisterEvent("CharacterGearScreen","UIModeSafe029372",EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
        if G:IsEnabled() and G:IsPlayerSceneShowing() then
            G:RequestRefresh(0)
        end
    end)
end

-- ============================================================================
-- v0.29.374 - Character Gear lifecycle ownership hardening.
-- Keep native Character controls suppressed only while the Suite presentation
-- owns Inventory/Character.  Once both player scenes are fully inactive, hide
-- every GuiRoot-anchored gear/native Character control so nothing leaks onto
-- gameplay.  This is deferred so menu-to-menu handoffs are never torn down
-- during SCENE_HIDING.
-- ============================================================================
function G:HardHideInactivePlayerControls029374()
    if self:IsPlayerSceneActiveOrTransitioning029372(nil) then return false end

    self:HideGearStatsCard()
    self:HideWeaponUtilityCells()
    self:HideWorkspaceBackdrop()

    local controls = {
        rawget(_G, "ZO_Character"),
        rawget(_G, "ZO_CharacterAccessoriesSection"),
        rawget(_G, "ZO_CharacterWeaponsSection"),
        rawget(_G, "ZO_CharacterHeaderSection"),
        rawget(_G, "ZO_CharacterHeaderSectionTitle"),
        rawget(_G, "ZO_CharacterHeaderSectionDivider"),
        rawget(_G, "ZO_CharacterApparelSectionText"),
        rawget(_G, "ZO_CharacterEquipmentSlotsCostume"),
        rawget(_G, "ZO_CharacterPaperDoll"),
        rawget(_G, "ZO_CharacterWeaponSwap"),
        rawget(_G, "ZO_CharacterWindowStats"),
        rawget(_G, "ZO_SharedWideLeftPanelBackground"),
    }
    for _, control in ipairs(controls) do
        if control and control.SetHidden then pcall(control.SetHidden, control, true) end
    end
    for _, d in ipairs(PLAYER_SLOTS) do
        local c = rawget(_G, d.control)
        HideSlotPresentation(c)
        if c and c.SetHidden then pcall(c.SetHidden, c, true) end
    end
    return true
end

function G:ScheduleInactivePlayerCleanup029374()
    self.cleanupGeneration029374 = (tonumber(self.cleanupGeneration029374) or 0) + 1
    local generation = self.cleanupGeneration029374
    local function finalize()
        if not G or generation ~= G.cleanupGeneration029374 then return end
        if G:IsPlayerSceneActiveOrTransitioning029372(nil) then
            -- Another player scene took ownership during the handoff. Reapply
            -- the Suite layout instead of hiding controls beneath it.
            if G:IsEnabled() then G:RequestRefresh(0) end
            return
        end
        G:HardHideInactivePlayerControls029374()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(finalize, 0)
        zo_callLater(finalize, 35)
    else
        finalize()
    end
end

-- Final player cleanup now has two phases: restore Suite mutations immediately,
-- then hard-hide scene controls only after ESO confirms there is no Inventory or
-- Character scene left to own them.
function G:CleanupPlayerScene()
    if not self:IsEnabled() then
        self:RestoreAll()
        self:ScheduleInactivePlayerCleanup029374()
        return
    end

    if self:IsPlayerSceneActiveOrTransitioning029372(nil) then
        self:RequestRefresh(0)
        return
    end

    self:HideGearStatsCard()
    self:HideWeaponUtilityCells()
    self:RestorePlayerState()
    self:HideWorkspaceBackdrop()
    for _, d in ipairs(PLAYER_SLOTS) do HideSlotPresentation(rawget(_G, d.control)) end
    self:ScheduleInactivePlayerCleanup029374()
end

-- ESO can refresh its native stats/paper-doll controls on UI-mode changes while
-- the Character scene remains open. Reassert Suite ownership after that event;
-- when no player scene is active, run the final gameplay cleanup instead.
if EVENT_MANAGER and rawget(_G, "EVENT_GAME_CAMERA_UI_MODE_CHANGED") then
    EPC.Runtime:UnregisterEvent("CharacterGearScreen","CharacterLifecycle029374")
    EPC.Runtime:RegisterEvent("CharacterGearScreen","CharacterLifecycle029374",EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
        if not G then return end
        if G:IsEnabled() and G:IsPlayerSceneShowing() then
            G:RequestRefresh(0)
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if G and G:IsEnabled() and G:IsPlayerSceneShowing() then G:ApplyPlayerLayout() end
                end, 25)
            end
        else
            G:ScheduleInactivePlayerCleanup029374()
        end
    end)
end


-- Character/Companion Gear absorbed correction layers

-- BEGIN ABSORBED: CharacterGearWeaponTextFix.lua
-- ESO Adventurer Suite
-- v0.29.555 - Character Gear weapon text hard column clamp.
-- Measures the actual weapon/poison cell spacing at runtime and prevents item/set
-- labels from drawing into neighboring columns at any supported UI scale.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen then return end

local G = EPC.CharacterGearScreen

local WEAPON_SLOT_029555 = {
    [EQUIP_SLOT_MAIN_HAND] = true,
    [EQUIP_SLOT_OFF_HAND] = true,
    [EQUIP_SLOT_BACKUP_MAIN] = true,
    [EQUIP_SLOT_BACKUP_OFF] = true,
}

local PLAYER_WEAPON_CONTROLS_029555 = {
    "ZO_CharacterEquipmentSlotsMainHand",
    "ZO_CharacterEquipmentSlotsOffHand",
    "ZO_CharacterEquipmentSlotsPoison",
    "ZO_CharacterEquipmentSlotsBackupMain",
    "ZO_CharacterEquipmentSlotsBackupOff",
    "ZO_CharacterEquipmentSlotsBackupPoison",
}

local function Safe029555(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a, b, c, d, e, f, g
end

local function Center029555(control)
    if not control or type(control.GetCenter) ~= "function" then return nil, nil end
    local ok, x, y = pcall(control.GetCenter, control)
    if not ok then return nil, nil end
    return tonumber(x), tonumber(y)
end

local function Width029555(control)
    if not control or type(control.GetWidth) ~= "function" then return 0 end
    local ok, value = pcall(control.GetWidth, control)
    return ok and (tonumber(value) or 0) or 0
end

local function MeasuredColumnWidth029555(control, fallback)
    local x, y = Center029555(control)
    if not x or not y then return fallback end

    local ownW = Width029555(control)
    local rowTolerance = math.max(18, ownW * 0.75)
    local nearest = nil

    for _, controlName in ipairs(PLAYER_WEAPON_CONTROLS_029555) do
        local other = rawget(_G, controlName)
        if other and other ~= control then
            local ox, oy = Center029555(other)
            if ox and oy and math.abs(oy - y) <= rowTolerance then
                local distance = math.abs(ox - x)
                if distance > 1 and (not nearest or distance < nearest) then
                    nearest = distance
                end
            end
        end
    end

    if nearest then
        -- Six pixels of breathing room on each side guarantees adjacent centered
        -- labels never touch, even with soft-shadow glyphs.
        return math.max(58, math.min(fallback, math.floor(nearest - 12)))
    end
    return fallback
end

local function ConfigureSingleLine029555(label, width, fontSize)
    if not label then return end
    if type(label.SetDimensions) == "function" then
        pcall(label.SetDimensions, label, width, fontSize + 6)
    end
    if type(label.SetHorizontalAlignment) == "function" then
        pcall(label.SetHorizontalAlignment, label, TEXT_ALIGN_CENTER)
    end
    if type(label.SetVerticalAlignment) == "function" then
        pcall(label.SetVerticalAlignment, label, TEXT_ALIGN_CENTER)
    end
    if type(label.SetMaxLineCount) == "function" then
        pcall(label.SetMaxLineCount, label, 1)
    end
    if type(label.SetWrapMode) == "function" then
        local mode = rawget(_G, "TEXT_WRAP_MODE_ELLIPSIS") or rawget(_G, "TEXT_WRAP_MODE_TRUNCATE")
        if mode ~= nil then pcall(label.SetWrapMode, label, mode) end
    end
end

local function RefreshWeaponText029555(self, slotData, isCompanion)
    if isCompanion or type(slotData) ~= "table" or not WEAPON_SLOT_029555[slotData.slot] then return end

    local control = rawget(_G, slotData.control or "")
    if not control or not control.EASGearName or not control.EASGearSet then return end

    local saved = EPC.saved or {}
    local layout = self.currentLayout
    local scale = type(layout) == "table" and tonumber(layout.scale) or 1
    scale = math.max(0.68, math.min(1.0, scale or 1))

    local slotWidth = Width029555(control)
    if slotWidth <= 0 then
        slotWidth = (tonumber(saved.characterGearSlotSize029206) or 68) * scale
    end

    -- Start near one icon-width, then cap against the real neighboring centers.
    -- This is intentionally much tighter than the old 104-154px block that was
    -- visibly overlapping Main Hand / Off Hand text in the live EQ screen.
    local desiredWidth = math.floor(math.max(66, math.min(112, slotWidth + 18)) + 0.5)
    local width = MeasuredColumnWidth029555(control, desiredWidth)

    local nameFontSize = math.floor(math.max(13, math.min(17, 17 * scale)) + 0.5)
    local setFontSize = math.floor(math.max(12, math.min(15, 15 * scale)) + 0.5)

    control.EASGearName:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", nameFontSize))
    control.EASGearSet:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", setFontSize))
    ConfigureSingleLine029555(control.EASGearName, width, nameFontSize)
    ConfigureSingleLine029555(control.EASGearSet, width, setFontSize)

    -- Each weapon owns a self-contained two-line block directly below its icon.
    control.EASGearName:ClearAnchors()
    control.EASGearName:SetAnchor(TOP, control, BOTTOM, 0, 4)
    control.EASGearSet:ClearAnchors()
    control.EASGearSet:SetAnchor(TOP, control.EASGearName, BOTTOM, 0, 0)

    -- Put set progress first so the useful N/N information remains visible even
    -- when a long localized set name must be ellipsized inside the narrow column.
    local link = Safe029555(GetItemLink, "", BAG_WORN, slotData.slot, LINK_STYLE_DEFAULT or 0) or ""
    if link ~= "" and type(GetItemLinkSetInfo) == "function" then
        local hasSet, setName, _, normalEquipped, maxEquipped, _, perfectedEquipped = Safe029555(GetItemLinkSetInfo, false, link)
        maxEquipped = tonumber(maxEquipped) or 0
        if hasSet and maxEquipped > 0 then
            local count = math.min((tonumber(normalEquipped) or 0) + (tonumber(perfectedEquipped) or 0), maxEquipped)
            local setText = tostring(setName or "Set")
            control.EASGearSet:SetText(string.format("%d/%d • %s", count, maxEquipped, setText))
            control.EASGearSet:SetColor(0.98, 0.99, 1, 1)
            control.EASGearSet:SetHidden(saved.characterGearShowDetails029206 == false or saved.characterGearShowSetCount029206 == false)
        end
    end
end

if type(G.RefreshSlot) == "function" and not G._weaponTextFix029555 then
    G._weaponTextFix029555 = true
    local BaseRefreshSlot029555 = RefreshSlotImpl
    RefreshSlotImpl = function(self, slotData, isCompanion)
        BaseRefreshSlot029555(self, slotData, isCompanion)
        RefreshWeaponText029555(self, slotData, isCompanion)
    end
end

-- END ABSORBED: CharacterGearWeaponTextFix.lua

-- BEGIN ABSORBED: CharacterGearArmorTextSpacingFix.lua
-- ESO Adventurer Suite
-- v0.29.500 - tighten armor/jewelry item-name to set-name spacing.
-- Keeps long names readable while removing the empty reserved second line from
-- ordinary one-line gear names. Weapon-grid spacing is intentionally untouched.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen then return end
local G = EPC.CharacterGearScreen

if G._easArmorTextSpacing029500 then return end
G._easArmorTextSpacing029500 = true

if type(BaseRefreshSlot029500) ~= "function" then return end

local function TightenArmorText029500(slotData)
    if type(slotData) ~= "table" or slotData.weaponCol ~= nil then return end
    local controlName = slotData.control
    local control = controlName and rawget(_G, controlName) or nil
    if not control then return end

    local nameLabel = control.EASGearName
    local setLabel = control.EASGearSet
    if not nameLabel or not setLabel then return end
    if nameLabel.IsHidden and nameLabel:IsHidden() then return end

    local width = tonumber(nameLabel.GetWidth and nameLabel:GetWidth()) or 0
    local currentHeight = tonumber(nameLabel.GetHeight and nameLabel:GetHeight()) or 0
    if width <= 0 or currentHeight <= 0 then return end

    local textHeight = nil
    if type(nameLabel.GetTextHeight) == "function" then
        local ok, measured = pcall(nameLabel.GetTextHeight, nameLabel)
        if ok then textHeight = tonumber(measured) end
    end

    -- ESO labels may report a zero/empty text height for a frame immediately
    -- after SetText. Fall back to a conservative one-line height derived from
    -- the existing two-line reservation instead of guessing a font metric.
    if not textHeight or textHeight <= 0 then
        textHeight = math.max(18, math.floor(currentHeight * 0.52 + 0.5))
    end

    -- Preserve genuine two-line item names, but eliminate unused vertical space
    -- for the common one-line case. The small padding keeps glyph descenders and
    -- soft shadows from being clipped.
    local desiredHeight = math.max(20, math.min(currentHeight, math.ceil(textHeight + 3)))
    if math.abs(desiredHeight - currentHeight) >= 2 and type(nameLabel.SetHeight) == "function" then
        pcall(nameLabel.SetHeight, nameLabel, desiredHeight)
    end
end

do
    local BaseRefreshSlotArmor029500 = RefreshSlotImpl
    RefreshSlotImpl = function(self, slotData, isCompanion)
        BaseRefreshSlotArmor029500(self, slotData, isCompanion)
        TightenArmorText029500(slotData)
    end
end

-- END ABSORBED: CharacterGearArmorTextSpacingFix.lua

-- BEGIN ABSORBED: CompanionGearLayoutFix.lua
-- ESO Adventurer Suite
-- v0.29.481 - companion gear ring geometry correction
-- Keeps the companion on a dedicated left-side canvas and places every gear
-- slot around that canvas instead of allowing the right column to cross the
-- companion model or ESO's native right-side information panel.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen then return end

local G = EPC.CharacterGearScreen

local function Clamp029481(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Dedicated companion canvas. Player Character geometry is left untouched.
if type(G.BuildAdaptiveLayout) == "function" and not G._companionLeftCanvas029481 then
    local BuildAdaptiveLayoutBase029481 = BuildAdaptiveLayoutImpl
    BuildAdaptiveLayoutImpl = function(self, isCompanion)
        local layout = BuildAdaptiveLayoutBase029481(self, isCompanion)
        if not isCompanion or type(layout) ~= "table" then return layout end

        local w = tonumber(layout.w) or 1920
        local h = tonumber(layout.h) or 1080
        local scale = tonumber(layout.scale) or 1

        -- The model + gear ring owns the left half only. The visual center is
        -- deliberately left of screen center because ESO's Companion details,
        -- Equipment and Rapport content occupy the right half.
        layout.centerX = w * 0.25
        layout.centerY = h * 0.50
        layout.safeLeft = math.max(18, w * 0.025)
        layout.safeRight = math.min(w * 0.515, w - 24)
        layout.available = math.max(680 * scale, layout.safeRight - layout.safeLeft)

        -- The old ~200px spread put Necklace/Cuirass/Girdle directly over the
        -- companion. Use a true outer ring at normal 16:9 resolutions.
        layout.spread = Clamp029481(w * 0.155, 225 * scale, 285 * scale)
        layout.labelWidth = Clamp029481(190 * math.max(scale, 0.90), 165, 205)

        -- Five armor/jewelry rows stay vertically wrapped around the model.
        layout.rowStep = Clamp029481(132 * scale, 104, 145)
        layout.topY = -(2 * layout.rowStep) - (92 * scale)

        -- Main/off hand form a compact row below the companion, not inside the
        -- native right-side panel.
        layout.weaponY = Clamp029481(h * 0.315, 292, 352)
        return layout
    end
    G._companionLeftCanvas029481 = true
end

-- Explicitly re-anchor Companion slots after the legacy renderer runs. This is
-- intentional: CharacterGearScreen.lua still contains an older companion-only
-- right-column -34px correction that was correct for the previous layout but
-- now pulls the gear back onto the model. These final anchors are canonical.
if type(G.ApplySlotLayout) == "function" and not G._companionSlotRing029481 then
    local ApplySlotLayoutBase029481 = ApplySlotLayoutImpl
    ApplySlotLayoutImpl = function(self, slotData, slotSize, scale, isCompanion)
        if not isCompanion or type(slotData) ~= "table" then
            return ApplySlotLayoutBase029481(self, slotData, slotSize, scale, isCompanion)
        end

        local result = ApplySlotLayoutBase029481(self, slotData, slotSize, scale, true)
        local control = slotData.control and rawget(_G, slotData.control) or nil
        local layout = self.currentLayout or (self.BuildAdaptiveLayout and self:BuildAdaptiveLayout(true))
        if not control or not layout then return result end

        local x, y
        if slotData.weaponCol ~= nil then
            local slotPx = (tonumber(slotSize) or 68) * (tonumber(scale) or 1)
            local gap = slotPx + math.max(36, 48 * (tonumber(scale) or 1))
            x = layout.centerX + (tonumber(slotData.weaponCol) or 0) * gap * 0.70
            y = layout.centerY + layout.weaponY
        else
            local rowBySlot = {
                [EQUIP_SLOT_HEAD]=0, [EQUIP_SLOT_NECK]=0,
                [EQUIP_SLOT_SHOULDERS]=1, [EQUIP_SLOT_CHEST]=1,
                [EQUIP_SLOT_HAND]=2, [EQUIP_SLOT_WAIST]=2,
                [EQUIP_SLOT_RING1]=3, [EQUIP_SLOT_RING2]=3,
                [EQUIP_SLOT_LEGS]=4, [EQUIP_SLOT_FEET]=4,
            }
            local row = rowBySlot[slotData.slot] or 2
            local sideSign = (tonumber(slotData.x) or 0) < 0 and -1 or 1
            x = layout.centerX + sideSign * layout.spread
            y = layout.centerY + layout.topY + row * layout.rowStep
        end

        if control.SetScale then control:SetScale(1) end
        if control.ClearAnchors then control:ClearAnchors() end
        if control.SetAnchor then control:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y) end
        if control.SetDimensions then
            local px = (tonumber(slotSize) or 68) * (tonumber(scale) or 1)
            control:SetDimensions(px, px)
        end
        if control.SetHidden then control:SetHidden(false) end

        -- Refresh labels after the final anchor so all external text follows the
        -- corrected slot position without stale coordinates from the old ring.
        if self.RefreshSlot then self:RefreshSlot(slotData, true) end
        return result
    end
    G._companionSlotRing029481 = true
end

if G.IsCompanionSceneShowing and G:IsCompanionSceneShowing() and G.RequestRefresh then
    G:RequestRefresh(0)
end

-- END ABSORBED: CompanionGearLayoutFix.lua

-- BEGIN ABSORBED: CharacterGearScreenCompanionFix.lua
-- ESO Adventurer Suite
-- v0.29.481 - independent Character/Companion stats positions plus corrected
-- companion interaction-camera framing for the dedicated left-side gear ring.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen then return end

local G = EPC.CharacterGearScreen

local function RootDimensions029481()
    local w, h = 1920, 1080
    if GuiRoot and GuiRoot.GetDimensions then
        local ok, rw, rh = pcall(GuiRoot.GetDimensions, GuiRoot)
        if ok and tonumber(rw) and tonumber(rh) and rw > 0 and rh > 0 then
            w, h = rw, rh
        end
    end
    return w, h
end

local function SaveStatsCardPosition029481(panel)
    if not panel or not EPC.saved then return end
    local left = panel.GetLeft and tonumber(panel:GetLeft()) or nil
    local top = panel.GetTop and tonumber(panel:GetTop()) or nil
    if not left or not top then return end

    if panel.easIsCompanion029480 == true then
        EPC.saved.characterGearCompanionStatsX029480 = left
        EPC.saved.characterGearCompanionStatsY029480 = top
        EPC.saved.characterGearCompanionStatsMoved029480 = true
    else
        EPC.saved.characterGearStatsX029355 = left
        EPC.saved.characterGearStatsY029355 = top
        EPC.saved.characterGearStatsMoved029355 = true
    end
end

local function InstallIndependentStatsDrag029481(panel)
    if not panel or panel._easIndependentStatsDrag029481 then return end
    panel._easIndependentStatsDrag029481 = true

    panel:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and control.StartMoving then control:StartMoving() end
    end)
    panel:SetHandler("OnMouseUp", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if control.StopMovingOrResizing then control:StopMovingOrResizing() end
        SaveStatsCardPosition029481(control)
    end)
end

local function ReanchorStatsCard029481(panel, isCompanion)
    if not panel or not EPC.saved then return end
    panel.easIsCompanion029480 = isCompanion == true
    InstallIndependentStatsDrag029481(panel)

    local w, h = RootDimensions029481()
    local cardH = panel.GetHeight and tonumber(panel:GetHeight()) or 540
    local moved, x, y
    if isCompanion then
        moved = EPC.saved.characterGearCompanionStatsMoved029480 == true
        x = moved and tonumber(EPC.saved.characterGearCompanionStatsX029480) or nil
        y = moved and tonumber(EPC.saved.characterGearCompanionStatsY029480) or nil
    else
        moved = EPC.saved.characterGearStatsMoved029355 == true
        x = moved and tonumber(EPC.saved.characterGearStatsX029355) or nil
        y = moved and tonumber(EPC.saved.characterGearStatsY029355) or nil
    end

    panel:ClearAnchors()
    if x and y then
        panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        -- Character keeps the historic far-left default. Companion gets its own
        -- safe default near the center divider but outside the gear/model ring.
        local defaultX = isCompanion and math.floor(w * 0.505) or 22
        local defaultY = isCompanion and math.max(150, h * 0.36) or math.max(56, (h-cardH)*0.46 - 22)
        panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, defaultX, defaultY)
    end
end

if type(G.RefreshGearStatsCard) == "function" and not G._independentStatsPosition029481 then
    local RefreshGearStatsCardBase029481 = RefreshGearStatsCardImpl
    RefreshGearStatsCardImpl = function(self, isCompanion, ...)
        local result = RefreshGearStatsCardBase029481(self, isCompanion, ...)
        if self.gearStatsCard then ReanchorStatsCard029481(self.gearStatsCard, isCompanion == true) end
        return result
    end
    G._independentStatsPosition029481 = true
end

local function ApplyCompanionInteractionFraming029481(layout)
    if type(SetFrameInteractionTarget) ~= "function" or type(NormalizeUICanvasPoint) ~= "function" then return false end

    local w, h = RootDimensions029481()
    layout = layout or G.currentLayout or (G.BuildAdaptiveLayout and G:BuildAdaptiveLayout(true))
    if not layout then return false end

    local targetX = tonumber(layout.centerX) or (w * 0.25)
    local targetY = tonumber(layout.centerY) or (h * 0.50)
    targetY = targetY + math.max(4, h * 0.012)

    local okDesired, desiredX, desiredY = pcall(NormalizeUICanvasPoint, targetX, targetY)
    if not okDesired or desiredX == nil or desiredY == nil then return false end

    -- IMPORTANT: ESO's Companion Character scene uses
    -- FRAME_INTERACTION_STANDARD_RIGHT_PANEL_MEDIUM_LEFT_PANEL_FRAGMENT.
    -- The previous patch incorrectly used the plain standard-right-panel
    -- baseline, leaving the companion model offset even though the gear moved.
    local baseX, baseY = 0.5, 0.5
    local mediumLeft = rawget(_G, "ZO_SharedMediumLeftPanelBackground")
    local rightBg = rawget(_G, "ZO_SharedRightBackground")
    local topBg = rawget(_G, "ZO_TopBarBackground")
    local keybindBg = rawget(_G, "ZO_KeybindStripMungeBackgroundTexture")

    if mediumLeft and rightBg and topBg and keybindBg
        and mediumLeft.GetRight and rightBg.GetLeft and topBg.GetBottom and keybindBg.GetTop then
        local okBase, normalizedBaseX, normalizedBaseY = pcall(function()
            local bx = zo_lerp(mediumLeft:GetRight(), rightBg:GetLeft(), 0.45)
            local by = zo_lerp(topBg:GetBottom(), keybindBg:GetTop(), 0.55)
            return NormalizeUICanvasPoint(bx, by)
        end)
        if okBase and normalizedBaseX ~= nil and normalizedBaseY ~= nil then
            baseX, baseY = normalizedBaseX, normalizedBaseY
        end
    end

    -- Same conversion used by ESO's ZO_InteractionFramingFragment, now against
    -- the correct Companion scene baseline.
    local frameX = 0.5 - baseX + desiredX
    local frameY = 0.5 - baseY + desiredY
    pcall(SetFrameInteractionTarget, frameX, frameY)
    return true
end

function G:ApplyCompanionCamera029481(layout)
    local applied = ApplyCompanionInteractionFraming029481(layout)
    if applied and type(zo_callLater) == "function" then
        local expectedLayout = layout
        for _, delay in ipairs({0, 35, 90}) do
            zo_callLater(function()
                if G and G.IsCompanionSceneShowing and G:IsCompanionSceneShowing() then
                    ApplyCompanionInteractionFraming029481(expectedLayout or G.currentLayout)
                end
            end, delay)
        end
    end
end

if type(G.ApplyCompanionLayout) == "function" and not G._companionCameraCenter029481 then
    local ApplyCompanionLayoutBase029481 = ApplyCompanionLayoutImpl
    ApplyCompanionLayoutImpl = function(self, ...)
        local result = ApplyCompanionLayoutBase029481(self, ...)
        self:ApplyCompanionCamera029481(self.currentLayout)
        return result
    end
    G._companionCameraCenter029481 = true
end

if type(G.CleanupCompanionScene) == "function" and not G._companionCameraCleanup029481 then
    local CleanupCompanionSceneBase029481 = CleanupCompanionSceneImpl
    CleanupCompanionSceneImpl = function(self, ...)
        local result = CleanupCompanionSceneBase029481(self, ...)
        if type(SetFrameInteractionTarget) == "function" then pcall(SetFrameInteractionTarget, 0.5, 0.5) end
        return result
    end
    G._companionCameraCleanup029481 = true
end

if type(G.ResetDefaults) == "function" and not G._companionStatsReset029481 then
    local ResetDefaultsBase029481 = ResetDefaultsImpl
    ResetDefaultsImpl = function(self, ...)
        local result = ResetDefaultsBase029481(self, ...)
        if EPC.saved then
            EPC.saved.characterGearCompanionStatsX029480 = nil
            EPC.saved.characterGearCompanionStatsY029480 = nil
            EPC.saved.characterGearCompanionStatsMoved029480 = nil
        end
        return result
    end
    G._companionStatsReset029481 = true
end

-- END ABSORBED: CharacterGearScreenCompanionFix.lua

-- BEGIN ABSORBED: CharacterWeaponSwapVisibilityFix.lua
-- ESO Adventurer Suite
-- v0.29.549 - Character weapon-swap transparent-center visibility fix.
-- Keep a Suite border around the Primary/Backup switch, but remove the opaque
-- center fill so ESO's native toggle, number, arrow and description can never
-- be visually buried behind the decorative cell.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen then return end

local G = EPC.CharacterGearScreen

local function RaiseControl029549(control, level)
    if not control then return end
    if control.SetDrawTier and rawget(_G, "DT_HIGH") then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if control.SetDrawLayer and rawget(_G, "DL_OVERLAY") then
        pcall(control.SetDrawLayer, control, DL_OVERLAY)
    elseif control.SetDrawLayer and rawget(_G, "DL_CONTROLS") then
        pcall(control.SetDrawLayer, control, DL_CONTROLS)
    end
    if control.SetDrawLevel then
        pcall(control.SetDrawLevel, control, tonumber(level) or 900)
    end
end

local function LowerBackdrop029549(control)
    if not control then return end
    if control.SetDrawTier and rawget(_G, "DT_HIGH") then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if control.SetDrawLayer then
        if rawget(_G, "DL_BACKGROUND") ~= nil then
            pcall(control.SetDrawLayer, control, DL_BACKGROUND)
        elseif rawget(_G, "DL_CONTROLS") ~= nil then
            pcall(control.SetDrawLayer, control, DL_CONTROLS)
        end
    end
    if control.SetDrawLevel then pcall(control.SetDrawLevel, control, 1) end
end

local function ForceWhite029549(control)
    if not control then return end
    if control.SetColor then pcall(control.SetColor, control, 1, 1, 1, 1) end
    if control.SetAlpha then pcall(control.SetAlpha, control, 1) end
end

local function StyleSwapChildren029549(control, swap, depth)
    if not control or not swap or (tonumber(depth) or 0) > 6 then return end
    depth = (tonumber(depth) or 0) + 1

    if control ~= swap then
        RaiseControl029549(control, 940 + depth)
        ForceWhite029549(control)

        local isLabel = control.SetHorizontalAlignment and control.SetVerticalAlignment and control.SetText
        if isLabel then
            if control.ClearAnchors and control.SetAnchor then
                pcall(control.ClearAnchors, control)
                pcall(control.SetAnchor, control, CENTER, swap, CENTER, 0, 0)
            end
            pcall(control.SetHorizontalAlignment, control, TEXT_ALIGN_CENTER)
            pcall(control.SetVerticalAlignment, control, TEXT_ALIGN_CENTER)
            if swap.GetWidth and swap.GetHeight and control.SetDimensions then
                local okW, w = pcall(swap.GetWidth, swap)
                local okH, h = pcall(swap.GetHeight, swap)
                if okW and okH and tonumber(w) and tonumber(h) then
                    pcall(control.SetDimensions, control, w, h)
                end
            end
        end
    end

    if control.GetNumChildren and control.GetChild then
        local okCount, count = pcall(control.GetNumChildren, control)
        count = okCount and tonumber(count) or 0
        for i = 1, count do
            local okChild, child = pcall(control.GetChild, control, i)
            if okChild and child and child ~= control and child ~= swap then
                StyleSwapChildren029549(child, swap, depth)
            end
        end
    end
end

local function RaiseUtilityText029549(cell)
    if not cell then return end
    local candidates = {
        cell.label, cell.text, cell.nameLabel, cell.description,
        cell.descriptionLabel, cell.title, cell.value,
    }
    for _, control in ipairs(candidates) do
        if control then
            RaiseControl029549(control, 970)
            ForceWhite029549(control)
        end
    end
end

local function FixWeaponSwap029549()
    local swap = rawget(_G, "ZO_CharacterWeaponSwap")
    if not swap then return false end

    if G.weaponUtilityCells and G.weaponUtilityCells.Swap then
        local cell = G.weaponUtilityCells.Swap
        RaiseControl029549(cell, 200)

        if cell.bg then
            if cell.bg.SetHidden then pcall(cell.bg.SetHidden, cell.bg, false) end
            if cell.bg.SetAlpha then pcall(cell.bg.SetAlpha, cell.bg, 1) end
            -- No opaque center: the native ESO control and any description text
            -- remain visible regardless of sibling/scene composition order.
            if cell.bg.SetCenterColor then pcall(cell.bg.SetCenterColor, cell.bg, 0, 0, 0, 0) end
            if cell.bg.SetEdgeColor then pcall(cell.bg.SetEdgeColor, cell.bg, 0.82, 0.76, 0.58, 0.96) end
            LowerBackdrop029549(cell.bg)
        end

        if cell.icon and cell.icon.SetHidden then pcall(cell.icon.SetHidden, cell.icon, true) end
        RaiseUtilityText029549(cell)
    end

    RaiseControl029549(swap, 930)
    ForceWhite029549(swap)
    StyleSwapChildren029549(swap, swap, 0)
    if swap.SetHidden then pcall(swap.SetHidden, swap, false) end
    return true
end

if type(G.LayoutWeaponUtilityCells) == "function" and not G._weaponSwapVisibility029549 then
    local base = LayoutWeaponUtilityCellsImpl
    LayoutWeaponUtilityCellsImpl = function(self, ...)
        local result = base(self, ...)
        FixWeaponSwap029549()
        return result
    end
    G._weaponSwapVisibility029549 = true
end

FixWeaponSwap029549()

if G.IsPlayerSceneShowing and G:IsPlayerSceneShowing() and G.RequestRefresh then
    G:RequestRefresh(0)
end

-- END ABSORBED: CharacterWeaponSwapVisibilityFix.lua

-- BEGIN ABSORBED: CharacterAppearanceSlotFix.lua
-- ESO Adventurer Suite
-- v0.29.682 - Restore ESO's native Appearance / Disguise equipment slot.
-- The customized Character Gear layout previously hid ZO_CharacterEquipmentSlotsCostume
-- and replaced it with a Collections-only button.  That removed ESO's native path
-- for interacting with an equipped disguise.  Keep the Suite layout, but mount the
-- real native slot inside the Suite Appearance utility cell so normal ESO click,
-- tooltip and unequip/context behavior remain authoritative.

local EPC = ESOProgressionCoach
if not EPC or not EPC.CharacterGearScreen or not WINDOW_MANAGER then return end
local G = EPC.CharacterGearScreen
local wm = WINDOW_MANAGER
local NS = (EPC.name or "ESOAdventurerSuite") .. "_CharacterAppearanceSlot029682"

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function raise(control, level)
    if not control then return end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" then
        local layer = rawget(_G, "DL_OVERLAY") or rawget(_G, "DL_CONTROLS")
        if layer ~= nil then pcall(control.SetDrawLayer, control, layer) end
    end
    if type(control.SetDrawLevel) == "function" then
        pcall(control.SetDrawLevel, control, tonumber(level) or 850)
    end
end

local function ensureLabel(cell)
    if not cell then return nil end
    if cell.easNativeAppearanceLabel029682 then return cell.easNativeAppearanceLabel029682 end

    local label = wm:CreateControl(NS .. "Label", cell, CT_LABEL)
    label:SetAnchor(TOP, cell, BOTTOM, 0, 2)
    label:SetDimensions(150, 20)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(1, 0.82, 0.26, 1)
    label:SetText("Appearance")
    label:SetMouseEnabled(false)
    raise(label, 860)
    cell.easNativeAppearanceLabel029682 = label
    return label
end

local function restoreNativeAppearanceSlot()
    local cell = G.weaponUtilityCells and G.weaponUtilityCells.Appearance
    local slot = rawget(_G, "ZO_CharacterEquipmentSlotsCostume")
    if not cell or not slot then return false end

    -- The Suite shell becomes presentation-only.  The native ESO slot owns all
    -- mouse interaction so disguises can be removed exactly as they can with the
    -- addon disabled.  Never synthesize an unequip action here.
    if type(cell.SetMouseEnabled) == "function" then pcall(cell.SetMouseEnabled, cell, false) end
    if cell.icon and type(cell.icon.SetHidden) == "function" then pcall(cell.icon.SetHidden, cell.icon, true) end
    if cell.bg then
        if type(cell.bg.SetCenterColor) == "function" then pcall(cell.bg.SetCenterColor, cell.bg, 0.025, 0.030, 0.040, 0.90) end
        if type(cell.bg.SetEdgeColor) == "function" then pcall(cell.bg.SetEdgeColor, cell.bg, 0.72, 0.64, 0.40, 0.88) end
    end

    local width = tonumber(safeCall(cell.GetWidth, cell)) or 68
    local height = tonumber(safeCall(cell.GetHeight, cell)) or width
    local size = math.max(48, math.min(128, math.min(width, height)))

    if type(slot.SetScale) == "function" then pcall(slot.SetScale, slot, 1) end
    if type(slot.ClearAnchors) == "function" then pcall(slot.ClearAnchors, slot) end
    if type(slot.SetAnchor) == "function" then pcall(slot.SetAnchor, slot, CENTER, cell, CENTER, 0, 0) end
    if type(slot.SetDimensions) == "function" then pcall(slot.SetDimensions, slot, size, size) end
    if type(slot.SetMouseEnabled) == "function" then pcall(slot.SetMouseEnabled, slot, true) end
    if type(slot.SetHidden) == "function" then pcall(slot.SetHidden, slot, false) end
    raise(slot, 855)

    -- Keep the old "Equipped Apparel Hidden" status text suppressed as requested
    -- by the custom Character Gear design.  A small Suite label identifies the
    -- restored native slot without resurrecting that unwanted native message.
    local apparelText = rawget(_G, "ZO_CharacterApparelSectionText")
    if apparelText and type(apparelText.SetHidden) == "function" then pcall(apparelText.SetHidden, apparelText, true) end
    local label = ensureLabel(cell)
    if label then
        label:SetHidden(false)
        raise(label, 860)
    end

    G.nativeAppearanceSlot029682 = slot
    return true
end

if type(G.LayoutWeaponUtilityCells) == "function" and not G._nativeAppearanceSlotFix029682 then
    local baseLayoutWeaponUtilityCells = LayoutWeaponUtilityCellsImpl
    LayoutWeaponUtilityCellsImpl = function(self, ...)
        local result = baseLayoutWeaponUtilityCells(self, ...)
        restoreNativeAppearanceSlot()
        return result
    end
    G._nativeAppearanceSlotFix029682 = true
end

-- Hide the detached native slot whenever the Suite utility cells are hidden.
-- RestorePlayerState() immediately restores ESO's original geometry/state when
-- the Character scene closes or the feature is disabled.
if type(G.HideWeaponUtilityCells) == "function" and not G._nativeAppearanceHideFix029682 then
    local baseHideWeaponUtilityCells = HideWeaponUtilityCellsImpl
    HideWeaponUtilityCellsImpl = function(self, ...)
        local result = baseHideWeaponUtilityCells(self, ...)
        local slot = rawget(_G, "ZO_CharacterEquipmentSlotsCostume")
        if slot and type(slot.SetHidden) == "function" then pcall(slot.SetHidden, slot, true) end
        local cell = self.weaponUtilityCells and self.weaponUtilityCells.Appearance
        local label = cell and cell.easNativeAppearanceLabel029682
        if label and type(label.SetHidden) == "function" then pcall(label.SetHidden, label, true) end
        return result
    end
    G._nativeAppearanceHideFix029682 = true
end

-- Apply immediately if the Character/Inventory equipment scene is already open.
restoreNativeAppearanceSlot()
if G.IsPlayerSceneShowing and G:IsPlayerSceneShowing() and G.RequestRefresh then
    G:RequestRefresh(0)
end

EPC.characterAppearanceSlotFix029682 = true

-- END ABSORBED: CharacterAppearanceSlotFix.lua


-- Character Gear collectible slot corrections

-- BEGIN ABSORBED: CharacterGearSkinSlotFix.lua
-- ESO Adventurer Suite
-- v0.29.648 - Character Gear Skin / Costume collectible slot.
-- Display-only bridge into ESO's native Collections UI. The Suite never calls
-- UseCollectible or protected collectible actions, preserving Outfit/Collections
-- secure preview paths.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER then return end
local G = EPC.CharacterGearScreen
if not G then return end

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_CharacterGearSkinSlot029627"
local wm = WINDOW_MANAGER
local PLAYER = rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_PLAYER")
local SKIN_TYPE = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_SKIN")
local COSTUME_TYPE = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_COSTUME")
local DEFAULT_APPEARANCE_ICON = "EsoUI/Art/Collections/collections_tabIcon_appearance_up.dds"
local DEFAULT_COSTUME_ICON = "EsoUI/Art/Dye/dyes_tabicon_costumedye_down.dds"

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function high(control, level)
    if not control then return end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then
        pcall(control.SetDrawLayer, control, DL_OVERLAY)
    end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 650) end
end

local function activeCollectibleId(categoryType)
    if categoryType == nil or PLAYER == nil or type(GetActiveCollectibleByType) ~= "function" then return 0 end
    return tonumber(first(GetActiveCollectibleByType, 0, categoryType, PLAYER)) or 0
end

local function activeAppearance()
    local costumeId = activeCollectibleId(COSTUME_TYPE)
    if costumeId > 0 then return costumeId, "COSTUME", "Costume" end
    local skinId = activeCollectibleId(SKIN_TYPE)
    if skinId > 0 then return skinId, "SKIN", "Skin" end
    return 0, "NONE", "Skin"
end

local function collectibleIcon(id, kind)
    if id and id > 0 and type(GetCollectibleIcon) == "function" then
        local icon = first(GetCollectibleIcon, "", id)
        if icon and icon ~= "" then return icon end
    end
    if kind == "COSTUME" then return DEFAULT_COSTUME_ICON end
    return DEFAULT_APPEARANCE_ICON
end

local function collectibleName(id, fallback)
    if id and id > 0 and type(GetCollectibleName) == "function" then
        local name = first(GetCollectibleName, "", id)
        if name and name ~= "" then return name end
    end
    return fallback or "Appearance"
end

local function openCollections()
    if not SCENE_MANAGER then return end
    local scene = SCENE_MANAGER:GetScene("collectionsBook")
    if scene then pcall(SCENE_MANAGER.Show, SCENE_MANAGER, "collectionsBook") end
end

local function ensureCell()
    if G.skinUtilityCell029544 then return G.skinUtilityCell029544 end

    local cell = wm:CreateTopLevelWindow(NAME .. "Cell")
    cell:SetDimensions(68, 68)
    cell:SetMouseEnabled(true)
    cell:SetClampedToScreen(true)
    high(cell, 650)

    local bg = wm:CreateControl(nil, cell, CT_BACKDROP)
    bg:SetAnchorFill(cell)
    bg:SetCenterColor(0.025, 0.03, 0.04, 0.92)
    bg:SetEdgeColor(0.60, 0.48, 0.25, 0.92)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-TooltipBorder.dds", 16, 4, 4)
    bg:SetMouseEnabled(false)
    high(bg, 651)

    local icon = wm:CreateControl(nil, cell, CT_TEXTURE)
    icon:SetAnchor(CENTER, cell, CENTER, 0, -4)
    icon:SetDimensions(42, 42)
    icon:SetTextureCoords(0.04, 0.96, 0.04, 0.96)
    icon:SetMouseEnabled(false)
    high(icon, 652)

    local label = wm:CreateControl(nil, cell, CT_LABEL)
    label:SetAnchor(TOP, cell, BOTTOM, 0, 2)
    label:SetDimensions(140, 20)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(1, 0.82, 0.26, 1)
    label:SetText("Skin")
    label:SetMouseEnabled(false)
    high(label, 653)

    cell.bg = bg
    cell.icon = icon
    cell.label = label

    cell:SetHandler("OnMouseEnter", function(ctrl)
        local id, kind, labelText = activeAppearance()
        if not InformationTooltip or type(InitializeTooltip) ~= "function" then return end
        InitializeTooltip(InformationTooltip, ctrl, LEFT, -8, 0, RIGHT)
        local text
        if id > 0 then
            text = collectibleName(id, labelText) .. "\nClick to open ESO Collections"
        else
            text = "Skin / Costume\nNo skin or costume equipped\nClick to open ESO Collections"
        end
        if type(SetTooltipText) == "function" then SetTooltipText(InformationTooltip, text) end
    end)

    cell:SetHandler("OnMouseExit", function()
        if InformationTooltip and type(ClearTooltip) == "function" then pcall(ClearTooltip, InformationTooltip) end
    end)

    cell:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or upInside == false then return end
        openCollections()
    end)

    G.skinUtilityCell029544 = cell
    return cell
end

local function refresh()
    if SKIN_TYPE == nil and COSTUME_TYPE == nil then
        if G.skinUtilityCell029544 then G.skinUtilityCell029544:SetHidden(true) end
        return
    end

    local appearance = G.weaponUtilityCells and G.weaponUtilityCells.Appearance
    if not appearance or (type(appearance.IsHidden) == "function" and appearance:IsHidden()) then
        if G.skinUtilityCell029544 then G.skinUtilityCell029544:SetHidden(true) end
        return
    end

    local cell = ensureCell()
    local size = tonumber(first(appearance.GetWidth, 68, appearance)) or 68
    if size < 48 then size = 48 elseif size > 128 then size = 128 end
    cell:SetDimensions(size, size)
    cell.icon:SetDimensions(size * 0.62, size * 0.62)
    cell:ClearAnchors()
    cell:SetAnchor(LEFT, appearance, RIGHT, 12, 0)

    local id, kind, labelText = activeAppearance()
    cell.activeSkinId029544 = kind == "SKIN" and id or 0
    cell.activeCostumeId029627 = kind == "COSTUME" and id or 0
    cell.activeAppearanceId029627 = id
    cell.activeAppearanceKind029627 = kind
    cell.icon:SetTexture(collectibleIcon(id, kind))
    cell.label:SetText(labelText)

    if id > 0 then
        cell.bg:SetEdgeColor(0.92, 0.72, 0.26, 1)
        cell.icon:SetColor(1, 1, 1, 1)
    else
        cell.bg:SetEdgeColor(0.42, 0.42, 0.46, 0.84)
        cell.icon:SetColor(0.65, 0.65, 0.68, 0.82)
    end

    cell:SetHidden(false)
    high(cell, 650); high(cell.bg, 651); high(cell.icon, 652); high(cell.label, 653)
end

local function delayedRefresh()
    refresh()
    if type(zo_callLater) == "function" then
        zo_callLater(refresh, 80)
        zo_callLater(refresh, 250)
    end
end

if EVENT_MANAGER then
    -- Remove the old 200 ms polling loop. Appearance state changes are event-driven.
    EVENT_MANAGER:UnregisterForUpdate(NAME)

    local collectibleEvent = rawget(_G, "EVENT_COLLECTIBLE_UPDATED")
    if collectibleEvent then
        EPC.Runtime:RegisterEvent("CharacterGearSkin", "Collectible", collectibleEvent, delayedRefresh)
    end

    local activeCollectibleEvent = rawget(_G, "EVENT_ACTIVE_COLLECTIBLE_UPDATED")
    if activeCollectibleEvent then
        EPC.Runtime:RegisterEvent("CharacterGearSkin", "ActiveCollectible", activeCollectibleEvent, delayedRefresh)
    end

    local activatedEvent = rawget(_G, "EVENT_PLAYER_ACTIVATED")
    if activatedEvent then
        EPC.Runtime:RegisterEvent("CharacterGearSkin", "PlayerActivated", activatedEvent, delayedRefresh)
    end
end

delayedRefresh()

-- END ABSORBED: CharacterGearSkinSlotFix.lua

-- BEGIN ABSORBED: CharacterGearPolymorphSlotFix.lua
-- ESO Adventurer Suite
-- v0.29.648 - Character Gear Polymorph collectible slot.
-- Display-only bridge into ESO's native Collections UI. The Suite never calls
-- UseCollectible or protected collectible actions, preserving Outfit/Collections
-- secure preview paths.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER then return end
local G = EPC.CharacterGearScreen
if not G then return end

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_CharacterGearPolymorphSlot029546"
local wm = WINDOW_MANAGER
local PLAYER = rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_PLAYER")
local POLYMORPH_TYPE = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_POLYMORPH")

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function high(control, level)
    if not control then return end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then
        pcall(control.SetDrawLayer, control, DL_OVERLAY)
    end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 660) end
end

local function activePolymorphId()
    if POLYMORPH_TYPE == nil or PLAYER == nil or type(GetActiveCollectibleByType) ~= "function" then return 0 end
    return tonumber(first(GetActiveCollectibleByType, 0, POLYMORPH_TYPE, PLAYER)) or 0
end

local function collectibleIcon(id)
    if id and id > 0 and type(GetCollectibleIcon) == "function" then
        local icon = first(GetCollectibleIcon, "", id)
        if icon and icon ~= "" then return icon end
    end
    return "EsoUI/Art/Collections/collections_tabIcon_appearance_up.dds"
end

local function collectibleName(id)
    if id and id > 0 and type(GetCollectibleName) == "function" then
        local name = first(GetCollectibleName, "", id)
        if name and name ~= "" then return name end
    end
    return "Polymorph"
end

local function openCollections()
    if not SCENE_MANAGER then return end
    local scene = SCENE_MANAGER:GetScene("collectionsBook")
    if scene then pcall(SCENE_MANAGER.Show, SCENE_MANAGER, "collectionsBook") end
end

local function ensureCell()
    if G.polymorphUtilityCell029546 then return G.polymorphUtilityCell029546 end

    local cell = wm:CreateTopLevelWindow(NAME .. "Cell")
    cell:SetDimensions(68, 68)
    cell:SetMouseEnabled(true)
    cell:SetClampedToScreen(true)
    high(cell, 660)

    local bg = wm:CreateControl(nil, cell, CT_BACKDROP)
    bg:SetAnchorFill(cell)
    bg:SetCenterColor(0.025, 0.03, 0.04, 0.92)
    bg:SetEdgeColor(0.60, 0.48, 0.25, 0.92)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-TooltipBorder.dds", 16, 4, 4)
    bg:SetMouseEnabled(false)
    high(bg, 661)

    local icon = wm:CreateControl(nil, cell, CT_TEXTURE)
    icon:SetAnchor(CENTER, cell, CENTER, 0, -4)
    icon:SetDimensions(42, 42)
    icon:SetTextureCoords(0.04, 0.96, 0.04, 0.96)
    icon:SetMouseEnabled(false)
    high(icon, 662)

    local label = wm:CreateControl(nil, cell, CT_LABEL)
    label:SetAnchor(TOP, cell, BOTTOM, 0, 2)
    label:SetDimensions(140, 20)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(1, 0.82, 0.26, 1)
    label:SetText("Polymorph")
    label:SetMouseEnabled(false)
    high(label, 663)

    cell.bg = bg
    cell.icon = icon
    cell.label = label

    cell:SetHandler("OnMouseEnter", function(ctrl)
        local id = activePolymorphId()
        if not InformationTooltip or type(InitializeTooltip) ~= "function" then return end
        InitializeTooltip(InformationTooltip, ctrl, LEFT, -8, 0, RIGHT)
        local text = id > 0 and (collectibleName(id) .. "\nClick to open ESO Collections") or "Polymorph\nNo polymorph equipped\nClick to open ESO Collections"
        if type(SetTooltipText) == "function" then SetTooltipText(InformationTooltip, text) end
    end)

    cell:SetHandler("OnMouseExit", function()
        if InformationTooltip and type(ClearTooltip) == "function" then pcall(ClearTooltip, InformationTooltip) end
    end)

    cell:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or upInside == false then return end
        openCollections()
    end)

    G.polymorphUtilityCell029546 = cell
    return cell
end

local function refresh()
    if POLYMORPH_TYPE == nil then
        if G.polymorphUtilityCell029546 then G.polymorphUtilityCell029546:SetHidden(true) end
        return
    end

    local skin = G.skinUtilityCell029544
    local appearance = G.weaponUtilityCells and G.weaponUtilityCells.Appearance
    local anchor = skin or appearance
    if not anchor or (type(anchor.IsHidden) == "function" and anchor:IsHidden()) then
        if G.polymorphUtilityCell029546 then G.polymorphUtilityCell029546:SetHidden(true) end
        return
    end

    local cell = ensureCell()
    local size = tonumber(first(anchor.GetWidth, 68, anchor)) or 68
    if size < 48 then size = 48 elseif size > 128 then size = 128 end
    cell:SetDimensions(size, size)
    cell.icon:SetDimensions(size * 0.62, size * 0.62)
    cell:ClearAnchors()
    cell:SetAnchor(LEFT, anchor, RIGHT, 12, 0)

    local id = activePolymorphId()
    cell.activePolymorphId029546 = id
    cell.icon:SetTexture(collectibleIcon(id))
    if id > 0 then
        cell.bg:SetEdgeColor(0.92, 0.72, 0.26, 1)
        cell.icon:SetColor(1, 1, 1, 1)
    else
        cell.bg:SetEdgeColor(0.42, 0.42, 0.46, 0.84)
        cell.icon:SetColor(0.65, 0.65, 0.68, 0.82)
    end
    cell:SetHidden(false)
    high(cell, 660); high(cell.bg, 661); high(cell.icon, 662); high(cell.label, 663)
end

local function delayedRefresh()
    refresh()
    if type(zo_callLater) == "function" then
        zo_callLater(refresh, 80)
        zo_callLater(refresh, 250)
    end
end

if EVENT_MANAGER then
    EVENT_MANAGER:UnregisterForUpdate(NAME)

    local collectibleEvent = rawget(_G, "EVENT_COLLECTIBLE_UPDATED")
    if collectibleEvent then
        EPC.Runtime:RegisterEvent("CharacterGearPolymorph", "Collectible", collectibleEvent, delayedRefresh)
    end

    local activeCollectibleEvent = rawget(_G, "EVENT_ACTIVE_COLLECTIBLE_UPDATED")
    if activeCollectibleEvent then
        EPC.Runtime:RegisterEvent("CharacterGearPolymorph", "ActiveCollectible", activeCollectibleEvent, delayedRefresh)
    end

    local activatedEvent = rawget(_G, "EVENT_PLAYER_ACTIVATED")
    if activatedEvent then
        EPC.Runtime:RegisterEvent("CharacterGearPolymorph", "PlayerActivated", activatedEvent, delayedRefresh)
    end
end

delayedRefresh()

-- END ABSORBED: CharacterGearPolymorphSlotFix.lua

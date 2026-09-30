-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.AllianceRank = EPC.AllianceRank or {}
local A = EPC.AllianceRank
local wm = WINDOW_MANAGER

local FRAME_TEX = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_frame.dds"
local BG_TEX = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FILL_TEX = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_GLOSS_TEX = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill_gloss.dds"
local ALLIANCE_MASK_LEFT = EPC:AssetPath("Art/alliance_fill_mask_left.dds")
local ALLIANCE_MASK_CENTER = EPC:AssetPath("Art/alliance_fill_mask_center.dds")
local ALLIANCE_MASK_RIGHT = EPC:AssetPath("Art/alliance_fill_mask_right.dds")
local ALLIANCE_FILL_LEFT = EPC:AssetPath("Art/alliance_fill_left.dds")
local ALLIANCE_FILL_RIGHT = EPC:AssetPath("Art/alliance_fill_right.dds")

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e
end

local function safeNumber(fn, fallback, ...)
    local value = safe(fn, fallback, ...)
    local number = tonumber(value)
    if number ~= nil then return number end
    return tonumber(fallback) or 0
end

local function allianceColor()
    local alliance = safeNumber(GetUnitAlliance, 0, "player")
    if ALLIANCE_ALDMERI_DOMINION and alliance == ALLIANCE_ALDMERI_DOMINION then return 0.92,0.73,0.18 end
    if ALLIANCE_DAGGERFALL_COVENANT and alliance == ALLIANCE_DAGGERFALL_COVENANT then return 0.20,0.46,0.86 end
    if ALLIANCE_EBONHEART_PACT and alliance == ALLIANCE_EBONHEART_PACT then return 0.80,0.17,0.16 end
    return 0.91,0.70,0.28
end

local function allianceFillKey(alliance)
    if ALLIANCE_ALDMERI_DOMINION and alliance == ALLIANCE_ALDMERI_DOMINION then return "aldmeri" end
    if ALLIANCE_DAGGERFALL_COVENANT and alliance == ALLIANCE_DAGGERFALL_COVENANT then return "daggerfall" end
    if ALLIANCE_EBONHEART_PACT and alliance == ALLIANCE_EBONHEART_PACT then return "ebonheart" end
    return "neutral"
end

local function allianceFillTexture(alliance, piece)
    return EPC:AssetPath(string.format("Art/alliance_fill_%s_%s.dds", allianceFillKey(alliance), piece))
end

local function allianceFallbackName(alliance)
    if ALLIANCE_ALDMERI_DOMINION and alliance == ALLIANCE_ALDMERI_DOMINION then return "Aldmeri Dominion" end
    if ALLIANCE_DAGGERFALL_COVENANT and alliance == ALLIANCE_DAGGERFALL_COVENANT then return "Daggerfall Covenant" end
    if ALLIANCE_EBONHEART_PACT and alliance == ALLIANCE_EBONHEART_PACT then return "Ebonheart Pact" end
    return "Alliance"
end

local function allianceFallbackTexture(alliance)
    -- Last-resort base-game textures. Prefer ESO's runtime helpers below.
    if ALLIANCE_ALDMERI_DOMINION and alliance == ALLIANCE_ALDMERI_DOMINION then
        return "EsoUI/Art/Stats/allianceBadge_aldmeri.dds"
    end
    if ALLIANCE_DAGGERFALL_COVENANT and alliance == ALLIANCE_DAGGERFALL_COVENANT then
        return "EsoUI/Art/Stats/allianceBadge_daggerfall.dds"
    end
    if ALLIANCE_EBONHEART_PACT and alliance == ALLIANCE_EBONHEART_PACT then
        return "EsoUI/Art/Stats/allianceBadge_ebonheart.dds"
    end
    return ""
end

local function getAllianceDisplayName(alliance)
    local name = safe(GetAllianceName, "", alliance)
    name = tostring(name or "")
    if name == "" then name = allianceFallbackName(alliance) end
    return name
end

local function getAllianceCrestTexture(alliance)
    -- It returns a texture path appropriate for the active client/platform.
    if type(ZO_GetLargeAllianceSymbolIcon) == "function" then
        local texture = safe(ZO_GetLargeAllianceSymbolIcon, "", alliance)
        if texture and texture ~= "" then return texture end
    end
    if type(ZO_GetPlatformAllianceSymbolIcon) == "function" then
        local texture = safe(ZO_GetPlatformAllianceSymbolIcon, "", alliance)
        if texture and texture ~= "" then return texture end
    end
    if type(GetAllianceSymbolIcon) == "function" then
        local texture = safe(GetAllianceSymbolIcon, "", alliance)
        if texture and texture ~= "" then return texture end
    end
    return allianceFallbackTexture(alliance)
end

local function setTierLayerLevel(control, tier, layer, level)
    if not control then return end
    if control.SetDrawTier then control:SetDrawTier(tier) end
    if control.SetDrawLayer then control:SetDrawLayer(layer) end
    if control.SetDrawLevel then control:SetDrawLevel(level) end
end

local function createNativeBar(parent, name, width)
    local bar = wm:CreateControl(name, parent, CT_CONTROL)
    local height = 23
    bar:SetDimensions(width, height)

    -- Match the exact symmetric ESO resource-bar construction used by the
    -- Suite Player/Target frames: native arrow caps, native center texture,
    -- two StatusBars meeting at center, gloss, then ornate frame on top.
    local capWidth = 13
    local fillHeight = 17

    local bgLeft = wm:CreateControlFromVirtual(name .. "_BgLeft", bar, "ZO_PlayerAttributeBgLeftArrow_Keyboard_Template")
    bgLeft:SetDimensions(capWidth, height)
    bgLeft:ClearAnchors()
    bgLeft:SetAnchor(LEFT, bar, LEFT, 0, 0)

    local bgRight = wm:CreateControlFromVirtual(name .. "_BgRight", bar, "ZO_PlayerAttributeBgRightArrow_Keyboard_Template")
    bgRight:SetDimensions(capWidth, height)
    bgRight:ClearAnchors()
    bgRight:SetAnchor(RIGHT, bar, RIGHT, 0, 0)

    local bgCenter = wm:CreateControlFromVirtual(name .. "_BgCenter", bar, "ZO_PlayerAttributeBgCenter_Keyboard_Template")
    bgCenter:ClearAnchors()
    bgCenter:SetAnchor(TOPLEFT, bgLeft, TOPRIGHT, 0, 0)
    bgCenter:SetAnchor(BOTTOMRIGHT, bgRight, BOTTOMLEFT, 0, 0)

    -- Alliance-only progress fill: three geometric pieces, never a StatusBar.
    -- The left and right pieces have transparent bevels, so even at low AP the
    -- visible fill is a shaped capsule/arrow instead of a rectangular block.
    local fillHeight = 17
    local fillInset = capWidth - 2
    local bevelWidth = 12

    local fillGroup = wm:CreateControl(name .. "_FillGroup", bar, CT_CONTROL)
    fillGroup:SetHeight(fillHeight)
    fillGroup:SetAnchor(LEFT, bar, LEFT, fillInset, 0)
    fillGroup:SetWidth(0)
    fillGroup:SetClampedToScreen(false)

    local fillLeft = wm:CreateControl(name .. "_FillLeft", fillGroup, CT_TEXTURE)
    fillLeft:SetTexture(ALLIANCE_MASK_LEFT)
    fillLeft:SetDimensions(bevelWidth, fillHeight)
    fillLeft:SetAnchor(LEFT, fillGroup, LEFT, 0, 0)

    local fillCenter = wm:CreateControl(name .. "_FillCenter", fillGroup, CT_TEXTURE)
    fillCenter:SetTexture(ALLIANCE_MASK_CENTER)
    fillCenter:SetDimensions(0, fillHeight - 2)
    fillCenter:SetAnchor(LEFT, fillGroup, LEFT, bevelWidth, 0)

    local fillRight = wm:CreateControl(name .. "_FillRight", fillGroup, CT_TEXTURE)
    fillRight:SetTexture(ALLIANCE_MASK_RIGHT)
    fillRight:SetDimensions(bevelWidth, fillHeight)
    fillRight:SetAnchor(RIGHT, fillGroup, RIGHT, 0, 0)

    for _, control in ipairs({fillLeft, fillCenter, fillRight}) do
        control:SetDrawLayer(DL_CONTROLS)
        control:SetDrawLevel(24)
        control:SetHidden(true)
    end

    local frameLeft = wm:CreateControlFromVirtual(name .. "_FrameLeft", bar, "ZO_PlayerAttributeFrameLeftArrow_Keyboard_Template")
    frameLeft:SetDimensions(capWidth, height)
    frameLeft:ClearAnchors()
    frameLeft:SetAnchor(LEFT, bar, LEFT, 0, 0)

    local frameRight = wm:CreateControlFromVirtual(name .. "_FrameRight", bar, "ZO_PlayerAttributeFrameRightArrow_Keyboard_Template")
    frameRight:SetDimensions(capWidth, height)
    frameRight:ClearAnchors()
    frameRight:SetAnchor(RIGHT, bar, RIGHT, 0, 0)

    local frameCenter = wm:CreateControlFromVirtual(name .. "_FrameCenter", bar, "ZO_PlayerAttributeFrameCenter_Keyboard_Template")
    frameCenter:ClearAnchors()
    frameCenter:SetAnchor(TOPLEFT, frameLeft, TOPRIGHT, 0, 0)
    frameCenter:SetAnchor(BOTTOMRIGHT, frameRight, BOTTOMLEFT, 0, 0)

    for _, control in ipairs({bgLeft, bgRight, bgCenter}) do
        if control.SetDrawTier then control:SetDrawTier(DT_LOW) end
        control:SetDrawLayer(DL_CONTROLS)
        control:SetDrawLevel(1)
    end
    for _, control in ipairs({frameLeft, frameRight, frameCenter}) do
        if control.SetDrawTier then control:SetDrawTier(DT_HIGH) end
        control:SetDrawLayer(DL_OVERLAY)
        control:SetDrawLevel(100)
    end

    local text = wm:CreateControl(name .. "Text", bar, CT_LABEL)
    text:SetAnchorFill(bar)
    text:SetFont("ZoFontGameSmall")
    text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    text:SetColor(0.96,0.92,0.82,1)
    setTierLayerLevel(text, DT_HIGH, DL_OVERLAY, 200)

    bar.epcFillGroup = fillGroup
    bar.epcFillLeft = fillLeft
    bar.epcFillCenter = fillCenter
    bar.epcFillRight = fillRight
    bar.epcFillInset = fillInset
    bar.epcBevelWidth = bevelWidth
    bar.epcWidth = width
    bar.epcText = text
    return bar
end


-- v0.29.61 - Reliable Alliance Rank gain-only visibility.
-- Alliance Rank progression is driven by Alliance Points/rank points rather than
-- normal character XP. In GAIN mode the overlay stays hidden until ESO reports
-- an increase to the player's Alliance Rank points, then remains visible briefly.
local ALLIANCE_GAIN_DISPLAY_MS_2960 = 10000

local function allianceNowMs2960()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok and value ~= nil then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok and value ~= nil then return tonumber(value) or 0 end
    end
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok and value ~= nil then return (tonumber(value) or 0) * 1000 end
    end
    return 0
end

function A:GetVisibilityMode2960()
    local mode = EPC.saved and tostring(EPC.saved.allianceRankVisibility or "ALWAYS") or "ALWAYS"
    if mode == "GAIN" then return "GAIN" end
    if mode == "COMBAT" then return "COMBAT" end
    return "ALWAYS"
end

function A:IsGainWindowActive2960()
    if self:GetVisibilityMode2960() ~= "GAIN" then return true end
    local untilMs = tonumber(self.gainVisibleUntilMs2960) or 0
    return untilMs > 0 and allianceNowMs2960() <= untilMs
end

function A:ShowForAllianceGain2960()
    self.gainVisibleUntilMs2960 = allianceNowMs2960() + ALLIANCE_GAIN_DISPLAY_MS_2960
    self:Refresh()
end

function A:HandleAllianceProgress2960(forceGain)
    local points = safeNumber(GetUnitAvARankPoints, 0, "player")
    local previous = tonumber(self.lastAllianceRankPoints2960)
    local gained = forceGain == true or (previous ~= nil and points > previous)
    self.lastAllianceRankPoints2960 = points
    if gained then
        self:ShowForAllianceGain2960()
    else
        self:Refresh()
    end
end

-- EVENT_ALLIANCE_POINT_UPDATE already tells us exactly how much AP changed.
-- Use its positive difference directly instead of waiting for
-- GetUnitAvARankPoints() to catch up; on some clients the getter is still stale
-- when the event fires, which made GAIN mode miss the popup entirely.
function A:HandleAlliancePointEvent2961(alliancePoints, difference)
    local newTotal = tonumber(alliancePoints)
    local delta = tonumber(difference) or 0
    if newTotal ~= nil then
        self.lastAllianceRankPoints2960 = newTotal
    end
    if delta > 0 then
        self.lastAllianceGainAmount2961 = delta
        self:ShowForAllianceGain2960()
    else
        self:Refresh()
    end
end

-- Some reward paths cache currency before the normal AP event propagates.
-- We only use this as a visibility trigger; the normal refresh still reads the
-- authoritative Alliance Rank values from ESO.
function A:HandlePendingCurrencyReward2961(currencyType, amount)
    if CURT_ALLIANCE_POINTS and currencyType == CURT_ALLIANCE_POINTS then
        local delta = tonumber(amount) or 0
        if delta > 0 then
            self.lastAllianceGainAmount2961 = delta
            self:ShowForAllianceGain2960()
        end
    end
end

function A:ShouldShow2960()
    if not EPC.saved then return false end
    local show = EPC.saved.showAllianceRank ~= false
    if self.layoutMode then return show end
    if show then
        local mode = self:GetVisibilityMode2960()
        if mode == "GAIN" then
            show = self:IsGainWindowActive2960()
        elseif mode == "COMBAT" and EPC.OverlayModeAllows then
            show = EPC:OverlayModeAllows("allianceRankVisibility")
        end
    end
    if show and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then show = false end
    return show
end

function A:Anchor()
    if not self.frame then return end
    self.frame:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.allianceRankLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.allianceRankTop) or -1
    if left >= 0 and top >= 0 then
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.frame:SetAnchor(TOP, GuiRoot, TOP, 0, 64)
    end
end

function A:Create()
    local frame = wm:CreateTopLevelWindow("EAS_AllianceRankOverlay")
    -- Compact horizontal HUD treatment: no large rectangular panel.
    frame:SetDimensions(318, 58)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    -- Small crest only. The old 74x74 rectangular backing plate is intentionally
    -- removed so the overlay reads as a lightweight HUD element rather than a box.
    local crest = wm:CreateControl("EAS_AllianceCrest", frame, CT_TEXTURE)
    crest:SetDimensions(44,44)
    crest:SetAnchor(LEFT, frame, LEFT, 0, 0)
    crest:SetDrawTier(DT_HIGH)
    crest:SetDrawLayer(DL_OVERLAY)
    crest:SetDrawLevel(260)
    crest:SetColor(1,1,1,1)
    crest:SetAlpha(1)
    crest:SetHidden(false)

    local rankIcon = wm:CreateControl("EAS_AllianceRankIcon", frame, CT_TEXTURE)
    rankIcon:SetDimensions(22,22)
    rankIcon:SetAnchor(BOTTOMRIGHT, crest, BOTTOMRIGHT, 3, 3)
    rankIcon:SetDrawTier(DT_HIGH)
    rankIcon:SetDrawLayer(DL_OVERLAY)
    rankIcon:SetDrawLevel(280)

    local title = wm:CreateControl("EAS_AllianceRankTitle", frame, CT_LABEL)
    title:SetAnchor(TOPLEFT, frame, TOPLEFT, 52, 0)
    title:SetDimensions(260, 20)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.98,0.96,0.90,1)

    local rankLevel = wm:CreateControl("EAS_AllianceRankLevel", frame, CT_LABEL)
    rankLevel:SetAnchor(TOPLEFT, frame, TOPLEFT, 52, 18)
    rankLevel:SetDimensions(260, 16)
    rankLevel:SetFont("ZoFontGameSmall")
    rankLevel:SetColor(0.78,0.80,0.84,1)

    local bar = createNativeBar(frame, "EAS_AllianceRankProgress", 260)
    bar:SetAnchor(TOPLEFT, frame, TOPLEFT, 52, 34)

    local hint = wm:CreateControl("EAS_AllianceRankMoveHint", frame, CT_LABEL)
    hint:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 16)
    hint:SetDimensions(150,16)
    hint:SetFont("ZoFontGameSmall")
    hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hint:SetColor(0.91,0.70,0.28,1)
    hint:SetText("DRAG TO MOVE")
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.allianceRankLeft = control:GetLeft()
            EPC.saved.allianceRankTop = control:GetTop()
        end
    end)

    self.frame = frame
    self.crestBack = nil
    self.crest = crest
    self.icon = rankIcon
    self.allianceName = nil
    self.title = title
    self.rankLevel = rankLevel
    self.bar = bar
    self.hint = hint
    self:Anchor()
end

function A:Refresh()
    if not self.frame or not EPC.saved then return end
    local show = self:ShouldShow2960()
    self.frame:SetHidden(not show)
    if not show then return end

    local alliance = safeNumber(GetUnitAlliance, 0, "player")
    local points = safeNumber(GetUnitAvARankPoints, 0, "player")
    local rank, subRank = safe(GetUnitAvARank, 0, "player")
    rank, subRank = tonumber(rank) or 0, tonumber(subRank) or 0
    local gender = safe(GetUnitGender, GENDER_MALE or 0, "player")
    local rankName = tostring(safe(GetAvARankName, "Alliance Rank", gender, rank) or "Alliance Rank")
    if rankName == "" then rankName = "Alliance Rank" end

    local allianceName = getAllianceDisplayName(alliance)
    local crestTexture = getAllianceCrestTexture(alliance)
    if self.crest then
        self.crest:SetTexture(crestTexture or "")
        self.crest:SetColor(1,1,1,1)
        self.crest:SetAlpha(1)
        self.crest:SetHidden(not crestTexture or crestTexture == "")
    end

    local rankTexture = safe(GetLargeAvARankIcon, "", rank)
    if not rankTexture or rankTexture == "" then rankTexture = safe(GetAvARankIcon, "", rank) end
    if self.icon then
        if rankTexture and rankTexture ~= "" then
            self.icon:SetTexture(rankTexture)
            self.icon:SetHidden(false)
        else
            self.icon:SetHidden(true)
        end
    end

    local subStart, nextSub, rankStart, nextRank = safe(GetAvARankProgress, 0, points)
    subStart, nextSub = tonumber(subStart) or 0, tonumber(nextSub) or 0
    local current = math.max(0, points - subStart)
    local maximum = math.max(0, nextSub - subStart)
    if maximum <= 0 then current, maximum = 1, 1 end
    local value = math.min(current, maximum)
    local fraction = maximum > 0 and math.max(0, math.min(1, value / maximum)) or 1
    local totalWidth = tonumber(self.bar.epcWidth) or self.bar:GetWidth() or 260
    local fillInset = tonumber(self.bar.epcFillInset) or 11
    local bevelWidth = tonumber(self.bar.epcBevelWidth) or 12
    local usableWidth = math.max(1, totalWidth - (fillInset * 2))
    local progressWidth = math.max(0, math.min(usableWidth, fraction * usableWidth))
    local r,g,b = allianceColor()
    local alliance = safeNumber(GetUnitAlliance, 0, "player")

    -- Shaped left -> right progress. At tiny percentages the two bevels shrink
    -- toward one another; once there is room, a center strip grows between them.
    if self.bar.epcFillGroup then
        self.bar.epcFillGroup:SetWidth(math.max(1, progressWidth))
        self.bar.epcFillGroup:SetHidden(progressWidth < 1)
    end
    local sideWidth = math.min(bevelWidth, math.max(1, progressWidth * 0.5))
    local centerWidth = math.max(0, progressWidth - (sideWidth * 2))
    -- Use dedicated DXT5 alpha-mask textures for the Alliance bar. ESO requires
    -- a render-safe compressed DDS here; these masks preserve a real beveled
    -- silhouette while SetColor supplies the live alliance color.
    if self.bar.epcFillLeft then
        self.bar.epcFillLeft:SetTexture(ALLIANCE_MASK_LEFT)
        self.bar.epcFillLeft:SetDimensions(sideWidth, 17)
        self.bar.epcFillLeft:SetColor(r,g,b,1)
        self.bar.epcFillLeft:SetHidden(progressWidth < 1)
    end
    if self.bar.epcFillRight then
        self.bar.epcFillRight:SetTexture(ALLIANCE_MASK_RIGHT)
        self.bar.epcFillRight:SetDimensions(sideWidth, 17)
        self.bar.epcFillRight:SetColor(r,g,b,1)
        self.bar.epcFillRight:SetHidden(progressWidth < 1)
    end
    if self.bar.epcFillCenter then
        self.bar.epcFillCenter:ClearAnchors()
        self.bar.epcFillCenter:SetAnchor(LEFT, self.bar.epcFillGroup, LEFT, sideWidth, 0)
        self.bar.epcFillCenter:SetTexture(ALLIANCE_MASK_CENTER)
        self.bar.epcFillCenter:SetDimensions(centerWidth, 15)
        self.bar.epcFillCenter:SetColor(r,g,b,1)
        self.bar.epcFillCenter:SetHidden(centerWidth < 1)
    end

    self.title:SetText(rankName)
    self.title:SetColor(r,g,b,1)
    if self.rankLevel then
        local levelText = allianceName .. "  •  Rank " .. tostring(rank)
        if subRank > 0 then levelText = levelText .. "  •  Level " .. tostring(subRank) end
        self.rankLevel:SetText(levelText)
    end

    if maximum > 1 then
        self.bar.epcText:SetText(string.format("%s / %s AP  •  %d%%", ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(current) or tostring(current), ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(maximum) or tostring(maximum), math.floor((current/maximum)*100+0.5)))
    else
        self.bar.epcText:SetText("MAX RANK")
    end
    self.frame:SetScale(tonumber(EPC.saved.allianceRankScale) or 1.0)
end

function A:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    if self.hint then self.hint:SetHidden(not self.layoutMode) end
    self:Refresh()
end

function A:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.allianceRankLeft, EPC.saved.allianceRankTop = -1, -1
    self:Anchor()
end

function A:Initialize()
    self.layoutMode = false
    self.gainVisibleUntilMs2960 = 0
    self.lastAllianceRankPoints2960 = safeNumber(GetUnitAvARankPoints, 0, "player")
    self:Create()
    local prefix = EPC.name .. "_AllianceRank"
    if EVENT_RANK_POINT_UPDATE then
        EPC.Runtime:RegisterEvent("AllianceRank","Rank",EVENT_RANK_POINT_UPDATE, function(_, unitTag)
            if not unitTag or unitTag == "player" then self:HandleAllianceProgress2960(false) end
        end)
    end
    if EVENT_ALLIANCE_POINT_UPDATE then
        EPC.Runtime:RegisterEvent("AllianceRank","AP",EVENT_ALLIANCE_POINT_UPDATE, function(_, alliancePoints, playSound, difference, reason, locationId)
            self:HandleAlliancePointEvent2961(alliancePoints, difference)
            -- Refresh once more after ESO has propagated the new rank progress.
            if type(zo_callLater) == "function" then
                zo_callLater(function() self:Refresh() end, 75)
            end
        end)
    end
    if EVENT_PENDING_CURRENCY_REWARD_CACHED then
        EPC.Runtime:RegisterEvent("AllianceRank","PendingAP",EVENT_PENDING_CURRENCY_REWARD_CACHED, function(_, currencyType, amount, ...)
            self:HandlePendingCurrencyReward2961(currencyType, amount)
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("AllianceRank","Activated",EVENT_PLAYER_ACTIVATED, function()
            self.lastAllianceRankPoints2960 = safeNumber(GetUnitAvARankPoints, 0, "player")
            self.gainVisibleUntilMs2960 = 0
            self:Refresh()
        end)
    end
    if EVENT_PLAYER_COMBAT_STATE then EPC.Runtime:RegisterEvent("AllianceRank","Combat",EVENT_PLAYER_COMBAT_STATE, function() self:Refresh() end) end
    EPC.Runtime:RegisterUpdate("AllianceRank","Visibility",1000, function()
        if not self.frame or not EPC.saved then return end
        local show = self:ShouldShow2960()
        if self.frame:IsHidden() == show then self:Refresh() end
    end)
    self:Refresh()
end

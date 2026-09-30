-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.MiniMap = EPC.MiniMap or {}
local M = EPC.MiniMap

-- v0.27.00 minimap rebuild: delegate map-state ownership and cross-map
-- coordinate conversion to the established ESO libraries instead of forcing
-- the World Map ourselves.
local LMD = LibMapData
local GPS = LibGPS3
local LMP = LibMapPins

local EPC_SQUARE_FRAME_TEXTURE = EPC:AssetPath("Art/minimap_eso_square_frame.dds")
local EPC_MINIMAP_STYLE_BASE = "Art/minimap_styles/"
local EPC_MINIMAP_STYLE_FULL_BASE = "Art/minimap_styles_custom/"

-- v0.29.306: Fantasy Round and Fantasy Square DDS files now use the selected ornate compass-frame artwork.
-- Each 1024x1024 asset contains transparent center/outside areas and internal safety padding,
-- so all N/E/S/W plaques stay fully inside the texture bounds, including the south point.
local MINIMAP_STYLE_TEXTURES = {
    FANTASY_SQUARE = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    FANTASY_ROUND = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame.dds"),
    -- compatibility aliases
    MODERN_SQUARE = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    MINIMAP_SQUARE_DEFAULT = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    MINIMAP_SQUARE_GOLD = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    MINIMAP_SQUARE_BLACK = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    MINIMAP_SQUARE_RED = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame.dds"),
    MINIMAP_ROUND_DEFAULT = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame.dds"),
    MINIMAP_ROUND_GOLD = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame.dds"),
    MINIMAP_ROUND_BLACK = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame.dds"),
    MINIMAP_ROUND_RED = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame.dds"),
}

local MINIMAP_ALLIANCE_STYLE_TEXTURES = {
    AD = {
        FANTASY_SQUARE = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame_ad.dds"),
        FANTASY_ROUND = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame_ad.dds"),
    },
    EP = {
        FANTASY_SQUARE = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_square_frame_ep.dds"),
        FANTASY_ROUND = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_frame_ep.dds"),
    },
    -- Daggerfall Covenant intentionally uses the original blue fantasy frame.
}

local MINIMAP_STYLE_MASK_TEXTURES = {
    FANTASY_ROUND = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_mask.dds"),
    MINIMAP_ROUND_DEFAULT = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_mask.dds"),
    MINIMAP_ROUND_GOLD = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_mask.dds"),
    MINIMAP_ROUND_BLACK = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_mask.dds"),
    MINIMAP_ROUND_RED = EPC:AssetPath(EPC_MINIMAP_STYLE_FULL_BASE .. "fantasy_round_mask.dds"),
}

local PLAYER_MARKER_TEXTURES = {
    SUITE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    -- v0.29.447: the three alternate player-marker choices now intentionally
    -- use the same Suite arrow/pip silhouette, with alliance-colored tints.
    MINIMAP = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    MINIMAP_ARROW = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    MINIMAP_GOLD_ARROW = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
}

local PLAYER_GLOW_TEXTURES = {
    SUITE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    MINIMAP = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    MINIMAP_ARROW = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
    MINIMAP_GOLD_ARROW = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds",
}

local ZONE_THEME_STYLE_SETS = {
    SQUARE = { "FANTASY_SQUARE" },
    ROUND = { "FANTASY_ROUND" },
    MIXED = { "FANTASY_SQUARE", "FANTASY_ROUND" },
}

local wm = WINDOW_MANAGER

-- v0.29.308 performance governor. The minimap still follows the player smoothly,
-- but expensive native World Map/provider rebuilds must never run at frame-like
-- cadence during ordinary gameplay. These values keep live navigation responsive
-- while moving heavyweight pin work onto event/transition paths plus a slow safety pass.
local MINIMAP_PULSE_MS = 240
-- v0.29.313: the player pointer has its own very cheap update. Keeping this
-- independent from POI/map-layer work makes the arrow feel smooth without
-- forcing the rest of the minimap to run at 30 Hz.
local MINIMAP_PLAYER_MARKER_MS = 24
local MINIMAP_POSITION_SAMPLE_MS_029341 = 33
local MINIMAP_CAMERA_PAN_MS_029318 = 33
local POI_EVENT_DEBOUNCE_S = 1.00
local POI_REFRESH_MIN_GAP_S = 2.50
-- v0.29.314: dense settlements can expose hundreds of POI/native controls.
-- Keep all source data, but bound the number of simultaneously rendered static
-- controls so clipping/off-screen UI traversal cannot consume a large slice of
-- the frame budget while the player is running.
local POI_RENDER_HARD_CAP_029314 = 60
local NATIVE_MIRROR_RENDER_CAP_029314 = 48
local POI_REFRESH_STATIONARY_GRACE_S_029314 = 0.55
local MAP_ID_WATCH_INTERVAL_S = 0.60
local HIDDEN_SYNC_PULSE_MIN_GAP_S = 1.00
local HIDDEN_PIN_PRIME_MOVING_MIN_GAP_S = 5.0
local HIDDEN_PIN_PRIME_SAFETY_S = 15.0
-- v0.29.315 roaming governor. Dense towns can contain far more static controls
-- than are useful inside a small minimap viewport. While the player is moving,
-- keep only the nearest/first visual budget active. All source data remains
-- intact and the full stationary presentation is restored after movement stops.
local ROAMING_POI_CAP_029315 = POI_RENDER_HARD_CAP_029314
local ROAMING_NATIVE_CAP_029315 = NATIVE_MIRROR_RENDER_CAP_029314
local ROAMING_MERCHANT_CAP_029315 = 48
local ROAMING_SERVICE_CAP_029315 = 32
-- v0.29.319: keep 0.29.318 camera cadence/smoothness, but drastically
-- reduce the number of descendants attached to the moving static-pin canvas.
-- Off-screen/excess controls are parked under a hidden non-moving layer; the
-- source data remains loaded and controls are reattached as they approach.
local ROAMING_VISIBLE_POI_CAP_029319 = 34
local ROAMING_VISIBLE_NATIVE_CAP_029319 = 26
local ROAMING_VISIBLE_SHRINE_CAP_029319 = 18
local ROAMING_VISIBLE_MERCHANT_CAP_029319 = 18
local ROAMING_STATIC_CULL_MS_029319 = 650
local STATIONARY_STATIC_CULL_MS_029319 = 1200
local ROAMING_MOTION_GRACE_MS_029315 = 220
local MOTION_SMOOTH_TIME_S_029315 = 0.040

local COLORS = {
    white = {0.96, 0.97, 0.99, 1},
    muted = {0.68, 0.72, 0.78, 1},
    gold = {0.91, 0.70, 0.28, 1},
    cyan = {0.30, 0.78, 0.94, 1},
    blue = {0.30, 0.55, 0.96, 1},
    purple = {0.69, 0.46, 0.94, 1},
    green = {0.34, 0.82, 0.48, 1},
    red = {0.90, 0.28, 0.28, 1},
}

local PLAYER_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"
local GROUP_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds"

local function headingFromMapDelta(dx, dy)
    dx, dy = tonumber(dx), tonumber(dy)
    if not dx or not dy then return nil end
    if math.abs(dx) < 0.000001 and math.abs(dy) < 0.000001 then return nil end

    -- ESO map Y increases downward. Convert movement into the same clockwise
    -- radians used by SetTextureRotation/GetMapPlayerPosition: 0 = north.
    local x = -dy
    local y = dx
    local angle
    if x > 0 then
        angle = math.atan(y / x)
    elseif x < 0 and y >= 0 then
        angle = math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        angle = math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        angle = math.pi * 0.5
    elseif x == 0 and y < 0 then
        angle = -math.pi * 0.5
    else
        angle = 0
    end
    if angle < 0 then angle = angle + (math.pi * 2) end
    return angle
end
local WAYPOINT_TEXTURE = "EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination_white.dds"
local ESO_NATIVE_SKYSHARD_TEXTURE_029445 = "EsoUI/Art/MapPins/skyshard_seen.dds"
local QUEST_SKYSHARD_TEXTURE = ESO_NATIVE_SKYSHARD_TEXTURE_029445
local SUITE_SKYSHARD_TEXTURE_029443 = ESO_NATIVE_SKYSHARD_TEXTURE_029445
local QUEST_WORLD_PIN_TYPE_029442 = "EPC_TRACKED_QUEST_GOLD_SKYSHARD_029442"
local SKYSHARD_WORLD_PIN_TYPE_029443 = "EPC_SKYSHARD_GOLD_029443"
local COMPANION_TEXTURE = "EsoUI/Art/MapPins/activeCompanion_pin.dds"
local POI_FALLBACK_TEXTURE = WAYPOINT_TEXTURE

-- Promote sell-capable town merchants to an always-on minimap layer.
local function isStableMasterPOI(name, icon)
    local text = string.lower(tostring(name or "") .. " " .. tostring(icon or ""))
    local needles = {
        "stablemaster", "stable master", "servicepin_stable", "servicetooltipicon_stablemaster", "stable"
    }
    for i = 1, #needles do
        if string.find(text, needles[i], 1, true) then return true end
    end
    return false
end

local function isSellMerchantPOI(name, icon)
    local text = string.lower(tostring(name or "") .. " " .. tostring(icon or ""))
    local needles = {
        "merchant", "vendor", "generalstore", "general_store", "general goods",
        "shop", "store", "armsman", "armorer", "clothier", "woodworker",
        "alchemist", "enchanter", "mystic", "chef", "brewer", "outfitter",
        "blacksmith", "weaponsmith"
    }
    for i = 1, #needles do
        if string.find(text, needles[i], 1, true) then return true end
    end
    return false
end


local STORE_TYPE_LABELS = {
    blacksmith = "Blacksmith", clothier = "Clothier", woodworker = "Woodworker",
    alchemist = "Alchemist", enchanter = "Enchanter", grocer = "Grocer",
    brewer = "Brewer", chef = "Chef", mystic = "Mystic", stable = "Stable",
    armsman = "Armsman", armorer = "Armorer", merchant = "Merchant",
}

local function classifyStoreText(text)
    text = string.lower(tostring(text or ""))
    local rules = {
        {"blacksmith", "blacksmith"}, {"weaponsmith", "blacksmith"}, {"smith", "blacksmith"},
        {"clothier", "clothier"}, {"tailor", "clothier"},
        {"woodworker", "woodworker"}, {"woodworking", "woodworker"},
        {"alchemist", "alchemist"}, {"alchemy", "alchemist"}, {"potion", "alchemist"}, {"poison", "alchemist"},
        {"enchanter", "enchanter"}, {"enchant", "enchanter"}, {"glyph", "enchanter"},
        {"grocer", "grocer"}, {"provision", "grocer"}, {"ingredient", "grocer"},
        {"brewer", "brewer"}, {"drink", "brewer"},
        {"chef", "chef"}, {"food", "chef"},
        {"mystic", "mystic"}, {"jewelry", "mystic"},
        {"stable", "stable"}, {"horse", "stable"}, {"mount", "stable"},
        {"armsman", "armsman"}, {"weapon", "armsman"},
        {"armorer", "armorer"}, {"armor", "armorer"},
    }
    for i = 1, #rules do
        if string.find(text, rules[i][1], 1, true) then return rules[i][2] end
    end
    return nil
end

local VALID_MODES = {
    SMART = true,
    QUEST = true,
    EXPLORE = true,
    GROUP = true,
    MINIMAL = true,
    CUSTOM = true,
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f, g, h, i
end

local function getGroupRoleDotColor(unitTag)
    if type(GetGroupMemberSelectedRole) == "function" then
        local role = safe(GetGroupMemberSelectedRole, LFG_ROLE_INVALID, unitTag)
        if LFG_ROLE_TANK ~= nil and role == LFG_ROLE_TANK then return COLORS.blue end
        if LFG_ROLE_HEAL ~= nil and role == LFG_ROLE_HEAL then return COLORS.green end
        if LFG_ROLE_DPS ~= nil and role == LFG_ROLE_DPS then return COLORS.red end
    end
    return COLORS.cyan
end

-- Collapse multi-return ESO APIs before numeric conversion. This avoids
-- accidentally feeding a second API return into tonumber(value, base).
local function safeNumber(fn, fallback, ...)
    local value = safe(fn, fallback, ...)
    local number = tonumber(value)
    if number ~= nil then return number end
    return tonumber(fallback) or 0
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

-- 0.29.281: minimap pins stay readable by default while the player arrow
-- footprint is reduced. The minimap also actively keeps the hidden player map
-- synced, similar to dedicated minimap addons, so opening the full map is not
-- required just to populate nearby pins.
function M:GetIconScale()
    return clamp(EPC.saved and EPC.saved.miniMapIconScale or 1.00, 0.60, 1.60)
end

function M:GetScaledPinSize(size)
    local base = tonumber(size) or 18
    return math.floor(clamp((base * self:GetIconScale()) + 0.5, 5, 48))
end
function M:GetVisualStyle()
    return self:NormalizeLegacyMiniMapStyle(EPC.saved and EPC.saved.miniMapVisualStyle or "FANTASY_ROUND")
end

function M:GetFrameColorChoice()
    -- v0.29.301: allow the player to override alliance coloring manually.
    -- Preserve the old v0.29.300 checkbox behavior for existing profiles that
    -- have not used the new dropdown yet.
    local saved = EPC.saved
    if not saved then return "AUTO" end

    local choice = tostring(saved.miniMapFrameColorChoice or "")
    if choice == "AUTO" or choice == "BLUE" or choice == "AD" or choice == "EP" then
        return choice
    end

    if saved.miniMapAllianceFrame == false then
        return "BLUE"
    end
    return "AUTO"
end

function M:GetAllianceFrameKey()
    local choice = self:GetFrameColorChoice()

    -- Manual override choices. BLUE intentionally resolves to DC/base art.
    if choice == "AD" then return "AD" end
    if choice == "EP" then return "EP" end
    if choice == "BLUE" then return "DC" end

    -- AUTO follows the current character alliance.
    if type(GetUnitAlliance) ~= "function" then return nil end

    local alliance = tonumber(safe(GetUnitAlliance, 0, "player")) or 0
    local isAD = (ALLIANCE_ALDMERI_DOMINION ~= nil and alliance == ALLIANCE_ALDMERI_DOMINION) or alliance == 1
    local isEP = (ALLIANCE_EBONHEART_PACT ~= nil and alliance == ALLIANCE_EBONHEART_PACT) or alliance == 2
    local isDC = (ALLIANCE_DAGGERFALL_COVENANT ~= nil and alliance == ALLIANCE_DAGGERFALL_COVENANT) or alliance == 3

    if isAD then return "AD" end
    if isEP then return "EP" end
    if isDC then return "DC" end
    return nil
end

function M:GetVisualStyleTexture(style)
    local textures = MINIMAP_STYLE_TEXTURES or {}
    local styleKey = tostring(style or self:GetVisualStyle())
    local baseTexture = textures[styleKey]

    -- v0.29.301: fantasy frame color can follow the current alliance or use a manual override.
    -- AUTO follows alliance; manual Gold/Yellow, Blue, or Red choices override it.
    -- This swaps only the decorative frame DDS;
    -- the live map, crop mask, pins, and minimap zoom are untouched.
    local allianceKey = self:GetAllianceFrameKey()
    local allianceTextures = allianceKey and MINIMAP_ALLIANCE_STYLE_TEXTURES[allianceKey] or nil
    return (allianceTextures and allianceTextures[styleKey]) or baseTexture
end

function M:GetVisualThemeMode()
    return tostring(EPC.saved and EPC.saved.miniMapThemeMode or "MANUAL")
end

function M:GetZoneThemeFamily()
    return tostring(EPC.saved and EPC.saved.miniMapZoneThemeFamily or "MIXED")
end

function M:GetZoneThemeSeed()
    local seed = tonumber(self.mapId) or tonumber(self.zoneIndex) or 0
    local name = tostring(self.mapName or "")
    for i = 1, #name do
        seed = (seed * 33 + string.byte(name, i)) % 2147483647
    end
    if type(IsInImperialCity) == "function" and safe(IsInImperialCity, false) == true then
        seed = seed + 103
    elseif type(IsInCyrodiil) == "function" and safe(IsInCyrodiil, false) == true then
        seed = seed + 211
    end
    return math.abs(seed)
end

function M:GetZoneThemeStyle()
    local family = string.upper(self:GetZoneThemeFamily())
    local set = ZONE_THEME_STYLE_SETS[family] or ZONE_THEME_STYLE_SETS.MIXED
    local count = #set
    if count <= 0 then return self:GetVisualStyle() end
    local index = (self:GetZoneThemeSeed() % count) + 1
    return set[index] or self:GetVisualStyle()
end

function M:GetEffectiveVisualStyle()
    if string.upper(self:GetVisualThemeMode()) == "AUTO_ZONE" then
        return self:GetZoneThemeStyle()
    end
    return self:GetVisualStyle()
end

function M:NormalizeLegacyMiniMapStyle(style)
    style = tostring(style or "")
    if style == "" then return "FANTASY_ROUND" end
    if string.find(style, "ROUND", 1, true) then return "FANTASY_ROUND" end
    if string.find(style, "SQUARE", 1, true) or style == "MODERN_SQUARE" then return "FANTASY_SQUARE" end
    return "FANTASY_ROUND"
end

function M:GetPlayerMarkerStyle()
    return tostring(EPC.saved and EPC.saved.miniMapPlayerMarkerStyle or "MINIMAP_GOLD_ARROW")
end

function M:GetPlayerMarkerTexture(style)
    style = tostring(style or self:GetPlayerMarkerStyle())
    local textures = PLAYER_MARKER_TEXTURES or {}
    return textures[style] or textures.SUITE or PLAYER_TEXTURE
end

function M:GetPlayerGlowTexture(style)
    style = tostring(style or self:GetPlayerMarkerStyle())
    local textures = PLAYER_GLOW_TEXTURES or {}
    return textures[style] or textures.SUITE or PLAYER_TEXTURE
end

function M:GetPlayerMarkerTint(style)
    style = tostring(style or self:GetPlayerMarkerStyle())
    if style == "MINIMAP" then
        return {0.95, 0.78, 0.16, 1.00} -- Aldmeri gold/yellow
    elseif style == "MINIMAP_ARROW" then
        return {0.22, 0.50, 0.90, 1.00} -- Daggerfall blue
    elseif style == "MINIMAP_GOLD_ARROW" then
        return {0.88, 0.24, 0.20, 1.00} -- Ebonheart red
    end
    return {1, 1, 1, 1}
end

function M:GetPlayerGlowAlpha(style)
    style = tostring(style or self:GetPlayerMarkerStyle())
    if style == "SUITE" then return 0.18 end
    return 0.26
end


function M:GetPlayerPinSize()
    return 18
end

function M:GetPlayerGlowSize()
    return 24
end

local function nowSeconds()
    if type(GetFrameTimeSeconds) == "function" then return tonumber(GetFrameTimeSeconds()) or 0 end
    if type(GetGameTimeMilliseconds) == "function" then return (tonumber(GetGameTimeMilliseconds()) or 0) / 1000 end
    return 0
end

function M:TrySyncHiddenPlayerMap(reason)
    if self:IsWorldMapShowing() then return false end
    if type(SetMapToPlayerLocation) ~= "function" then return false end
    local now = nowSeconds()
    -- SetMapToPlayerLocation can cascade through LibMapData/LibMapPins callbacks.
    -- Never hammer it from the normal minimap pulse; transitions still get the
    -- short retry window needed for city/interior map hand-offs.
    local minGap = HIDDEN_SYNC_PULSE_MIN_GAP_S
    if reason == "transition" then minGap = 0.08 end
    if self.lastHiddenPlayerMapSyncAt and (now - self.lastHiddenPlayerMapSyncAt) < minGap then return false end
    self.lastHiddenPlayerMapSyncAt = now

    -- Do this even when DoesCurrentMapMatchMapForPlayerLocation() says true.
    -- ESO can consider the surrounding zone map a valid player-location map
    -- while LibMapData has already resolved a more specific city/sub-map. The
    -- native World Map calls SetMapToPlayerLocation again when M is opened;
    -- repeating that call in gameplay is what lets the hidden map advance to
    -- the final local map without requiring the player to open the World Map.
    local ok, result = pcall(SetMapToPlayerLocation)
    if not ok then return false end
    self.lastHiddenPlayerMapSyncResult = tonumber(result) or result

    -- ESO normally fires OnWorldMapChanged immediately after
    -- SetMapToPlayerLocation changes the map while the World Map is open.  The
    -- minimap performs the same player-map sync while the scene is hidden, so
    -- fire the same callback here.  LibMapData, LibMapPins and many pin addons
    -- use this signal to switch/rebuild their current-area data.
    local currentMapId = safeNumber(GetCurrentMapId, 0)
    local mapChanged = SET_MAP_RESULT_MAP_CHANGED ~= nil and result == SET_MAP_RESULT_MAP_CHANGED
    local firstSignalForMap = (reason == "transition") and currentMapId > 0
        and tonumber(self.lastHiddenWorldMapCallbackMapId) ~= currentMapId
    if (mapChanged or firstSignalForMap)
        and CALLBACK_MANAGER and type(CALLBACK_MANAGER.FireCallbacks) == "function" then
        self.lastHiddenWorldMapCallbackMapId = currentMapId
        pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "OnWorldMapChanged")
    end

    return result ~= SET_MAP_RESULT_FAILED and result ~= 0
end

-- v0.29.296 - Keep ESO's hidden CURRENT MAP in the exact same coordinate
-- space the minimap is rendering. This is the missing piece that made city,
-- town, interior and other local-map icons appear only after pressing M.
--
-- LibMapData can correctly report the player's local map before ESO's global
-- current-map state has switched away from the surrounding zone map. APIs such
-- as GetPOIMapInfo(), GetFastTravelNodeInfo() and the native pin manager all
-- use that global current-map state. The minimap therefore looked correct but
-- queried pins for the wrong map until the native World Map opened and changed
-- the global map context.
--
-- SetMapToMapId is used directly (not WORLD_MAP_MANAGER:SetMapById) so this
-- background alignment is NOT marked as a user-chosen World Map. Opening M
-- still behaves normally and recenters on the player.
function M:EnsureHiddenMapContext(mapId, reason)
    mapId = tonumber(mapId) or 0
    if mapId <= 0 or self:IsWorldMapShowing() then return false end
    if self.hiddenMapContextSyncInProgress == true then
        return safeNumber(GetCurrentMapId, 0) == mapId
    end

    local currentMapId = safeNumber(GetCurrentMapId, 0)
    if currentMapId == mapId then return true end
    if type(SetMapToMapId) ~= "function" then return false end

    self.hiddenMapContextSyncInProgress = true
    local ok, result = pcall(SetMapToMapId, mapId)
    local afterMapId = safeNumber(GetCurrentMapId, 0)
    local changed = ok and afterMapId == mapId and afterMapId ~= currentMapId

    -- Match the native World Map's map-change path while the scene remains
    -- closed. Keeping the guard set during callbacks prevents the minimap's own
    -- LibMapData callback from recursively starting another map switch, while
    -- still allowing ESO/custom pin providers to rebuild for this exact map.
    if changed and CALLBACK_MANAGER and type(CALLBACK_MANAGER.FireCallbacks) == "function" then
        self.lastHiddenWorldMapCallbackMapId = afterMapId
        pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "OnWorldMapChanged")
    end
    self.hiddenMapContextSyncInProgress = false

    self.lastHiddenExactMapId = afterMapId
    self.lastHiddenExactMapReason = reason
    self.lastHiddenExactMapResult = tonumber(result) or result
    return afterMapId == mapId
end

-- v0.29.295 - Keep ESO/LibMapPins pin state current while the World Map is CLOSED.
-- SetMapToPlayerLocation updates the current player map, but it does not always
-- cause ESO or custom pin providers to rebuild their pin manager. Opening the
-- full World Map did that implicitly, which is why many icons only appeared
-- after pressing M. Prime the hidden map at a controlled cadence instead.
-- v0.29.297 - ESO's native World Map does not execute its OnUpdate loop while
-- the scene is hidden. ZO_WorldMap_UpdateMap() queues several refresh groups
-- (notably map-location/city labels and world-event data), but those queued
-- groups are only consumed by the native World Map OnUpdate. That is why
-- pressing M instantly made missing minimap icons appear even after we had
-- already selected the correct hidden map and called the public refreshers.
--
-- Pump the EXISTING native OnUpdate handler without showing either World Map
-- scene. This executes ESO's private refresh queue exactly as the visible map
-- would. We then restore the minimap's exact local map if ESO's periodic player
-- recenter changed it during the pump, and run one second pump to consume the
-- refreshes queued for the restored map.
function M:PumpHiddenNativeWorldMap(reason, force)
    if self:IsWorldMapShowing() or self.hiddenNativeMapPumpInProgress == true then return false end

    local control = ZO_WorldMap
    if not control or type(control.GetHandler) ~= "function" then return false end
    local okHandler, handler = pcall(control.GetHandler, control, "OnUpdate")
    if not okHandler or type(handler) ~= "function" then return false end

    local now = nowSeconds()
    local minGap = force == true and 0.35 or 1.50
    if self.lastHiddenNativeMapPumpAt and (now - self.lastHiddenNativeMapPumpAt) < minGap then
        return false
    end
    self.lastHiddenNativeMapPumpAt = now

    local targetMapId = tonumber(self.mapId) or 0
    if targetMapId <= 0 and LMD then targetMapId = tonumber(LMD.mapId) or 0 end

    self.hiddenNativeMapPumpInProgress = true
    local ok = pcall(handler, control, now)

    -- The native update periodically calls SetMapToPlayerLocation(). If that
    -- resolves to a parent map while LibMapData/minimap is already on a city or
    -- interior sub-map, put the hidden context back and flush that map's queue.
    if targetMapId > 0 and safeNumber(GetCurrentMapId, 0) ~= targetMapId then
        self:EnsureHiddenMapContext(targetMapId, "pump-restore:" .. tostring(reason or ""))
        if safeNumber(GetCurrentMapId, 0) == targetMapId then
            if type(ZO_WorldMap_UpdateMap) == "function" then
                pcall(ZO_WorldMap_UpdateMap)
            end
            -- g_refreshUpdateTime was advanced by the first call, so this second
            -- call normally flushes the restored map without another recenter.
            pcall(handler, control, now + 0.001)
        end
    end

    self.hiddenNativeMapPumpInProgress = false
    return ok
end

-- v0.29.438: Quest-only hidden refresh. Quest journal/tracking events are
-- infrequent but can happen while the player is moving. Refresh only ESO's
-- objective pin group instead of waking every POI/wayshrine/custom provider.
-- This keeps quest markers current without reintroducing the old minimap hitch.
function M:PrimeHiddenQuestPins029438(reason)
    if self:IsWorldMapShowing() or self.hiddenPinPrimeInProgress == true then return false end

    local targetMapId = tonumber(self.mapId) or 0
    if targetMapId <= 0 and LMD then targetMapId = tonumber(LMD.mapId) or 0 end
    if targetMapId <= 0 then return false end

    self:TrySyncHiddenPlayerMap("quest")
    self:EnsureHiddenMapContext(targetMapId, reason or "quest")

    local currentMapId = safeNumber(GetCurrentMapId, 0)
    if currentMapId <= 0 or currentMapId ~= targetMapId then return false end

    self.hiddenPinPrimeInProgress = true
    local refreshed = false

    if type(ZO_WorldMap_RefreshObjectives) == "function" then
        local ok = pcall(ZO_WorldMap_RefreshObjectives)
        refreshed = ok or refreshed
    end

    -- ESO queues some objective pin changes for the World Map's update pass.
    -- Pump that hidden handler once, then snapshot the shared pin manager.
    local pumped = self:PumpHiddenNativeWorldMap("quest", true)
    refreshed = pumped or refreshed

    local manager = nil
    if type(ZO_WorldMap_GetPinManager) == "function" then
        local ok, active = pcall(ZO_WorldMap_GetPinManager)
        if ok then manager = active end
    end
    if not manager and LMP then manager = LMP.pinManager end
    if manager and type(manager.UpdateMovingPins) == "function" then
        pcall(manager.UpdateMovingPins, manager)
    end

    local captured = self:CaptureAllNativeMapPins(true)
    self.hiddenPinPrimeInProgress = false
    return refreshed or captured
end

function M:QueueQuestPinRefresh029438()
    self.lastQuestPinEventAt029438 = nowSeconds()
    self.questNativeRefreshRequested029438 = true
    -- Let the cheap Suite-owned tracked quest marker refresh on the next pulse
    -- even if its normal 0.6/0.85 s dynamic cadence has not elapsed yet.
    self.lastDynamicPinLayoutAt029312 = nil
    if EPC.ActiveQuest and type(EPC.ActiveQuest.ResolveQuestSource2516) == "function"
        and type(EPC.ActiveQuest.GetQuestTrackingSource2513) == "function"
        and type(EPC.ActiveQuest.EnsureQuestBreadcrumbs2519) == "function" then
        local source = EPC.ActiveQuest:GetQuestTrackingSource2513()
        local questIndex = EPC.ActiveQuest:ResolveQuestSource2516(source)
        if questIndex then pcall(EPC.ActiveQuest.EnsureQuestBreadcrumbs2519, EPC.ActiveQuest, questIndex, true) end
    end
    self:RefreshQuestPin()
    self:RefreshQuestWorldMapPin029442()
end

function M:PrimeHiddenWorldMapPins(reason, force)
    if self:IsWorldMapShowing() or self.hiddenPinPrimeInProgress == true then return false end

    local primeNow029311 = nowSeconds()
    if force == true and reason == "event" and self.lastForcedEventPrimeAt029311
        and primeNow029311 - self.lastForcedEventPrimeAt029311 < 2.50 then
        return false
    end

    local targetMapId = tonumber(self.mapId) or 0
    if targetMapId <= 0 and LMD then targetMapId = tonumber(LMD.mapId) or 0 end

    local now = nowSeconds()
    local x, y = safe(GetMapPlayerPosition, nil, "player")
    x, y = tonumber(x), tonumber(y)
    local moved2 = 1
    if x and y and self.lastHiddenPinPrimeX and self.lastHiddenPinPrimeY
        and tonumber(self.lastHiddenPinPrimeMapId) == targetMapId then
        local dx, dy = x - self.lastHiddenPinPrimeX, y - self.lastHiddenPinPrimeY
        moved2 = (dx * dx) + (dy * dy)
    end

    -- Heavy native refreshers below rebuild ESO POIs, wayshrines, custom pin
    -- providers and the native World Map refresh queue. Before 0.29.308 this
    -- path could be entered every ~1 second while moving. Keep force=true for
    -- actual map/pin events, but make ordinary movement a slow safety fallback.
    if force ~= true and targetMapId > 0 and tonumber(self.lastHiddenPinPrimeMapId) == targetMapId then
        local elapsed = now - (tonumber(self.lastHiddenPinPrimeAt) or 0)
        if elapsed < HIDDEN_PIN_PRIME_MOVING_MIN_GAP_S then return false end
        if elapsed < HIDDEN_PIN_PRIME_SAFETY_S and moved2 < 0.001600 then return false end
    end

    -- Only after the cheap throttle passes do we touch ESO's global hidden map.
    self:TrySyncHiddenPlayerMap(reason == "transition" and "transition" or "pulse")
    if targetMapId <= 0 then
        targetMapId = tonumber(self.mapId) or 0
        if targetMapId <= 0 and LMD then targetMapId = tonumber(LMD.mapId) or 0 end
    end
    if targetMapId > 0 then self:EnsureHiddenMapContext(targetMapId, reason) end

    local matchesPlayer = type(DoesCurrentMapMatchMapForPlayerLocation) ~= "function"
        or safe(DoesCurrentMapMatchMapForPlayerLocation, false) == true
    if not matchesPlayer and targetMapId <= 0 then return false end

    local currentMapId = safeNumber(GetCurrentMapId, 0)
    if currentMapId <= 0 then return false end
    if targetMapId > 0 and currentMapId ~= targetMapId then return false end

    if force == true and reason == "event" then self.lastForcedEventPrimeAt029311 = primeNow029311 end
    self.lastHiddenPinPrimeAt = now
    self.lastHiddenPinPrimeMapId = currentMapId
    if x and y then self.lastHiddenPinPrimeX, self.lastHiddenPinPrimeY = x, y end
    self.hiddenPinPrimeInProgress = true

    local refreshed = false

    -- Rebuild the same native pin groups ESO refreshes for its World Map, but do
    -- it while the scene remains hidden.  These functions operate on the shared
    -- map pin manager and do not require the player to actually open the map.
    local nativeRefreshers = {
        "ZO_WorldMap_RefreshAllPOIs",
        "ZO_WorldMap_RefreshObjectives",
        "ZO_WorldMap_RefreshWayshrines",
        "ZO_WorldMap_RefreshKeeps",
        "ZO_WorldMap_RefreshForwardCamps",
        "ZO_WorldMap_RefreshKillLocations",
    }
    for i = 1, #nativeRefreshers do
        local fn = _G[nativeRefreshers[i]]
        if type(fn) == "function" then
            local ok = pcall(fn)
            refreshed = ok or refreshed
        end
    end

    -- This remains a compatibility safety pass because ESO's own UpdateMap()
    -- also refreshes map-location/world-event managers that are not exposed as
    -- individual public functions on every API revision.
    if type(ZO_WorldMap_UpdateMap) == "function" then
        local ok = pcall(ZO_WorldMap_UpdateMap)
        refreshed = ok or refreshed
    end

    -- ZO_WorldMap_UpdateMap() queues private refresh groups; it does not execute
    -- them. The native World Map normally consumes those queues from its hidden
    -- local OnUpdate function. Pump that handler here so city/location pins are
    -- actually built while M remains closed.
    local pumped = self:PumpHiddenNativeWorldMap(reason, force)
    refreshed = pumped or refreshed

    -- IMPORTANT: refresh the actual ESO pin manager directly.  ESO's
    -- ZO_WorldMap_UpdateMap() calls g_mapPinManager:RefreshCustomPins() with NO
    -- pin type to rebuild every registered custom provider.  The previous Suite
    -- path called LibMapPins:RefreshPins(nil), which does not reproduce that
    -- world-map-open behavior for all providers and is why many icons still only
    -- appeared after pressing M.
    local pinManager = nil
    if type(ZO_WorldMap_GetPinManager) == "function" then
        local ok, manager = pcall(ZO_WorldMap_GetPinManager)
        if ok then pinManager = manager end
    end
    if not pinManager and LMP then pinManager = LMP.pinManager end
    if pinManager and type(pinManager.RefreshCustomPins) == "function" then
        local ok = pcall(pinManager.RefreshCustomPins, pinManager)
        refreshed = ok or refreshed
    end
    if pinManager and type(pinManager.UpdateMovingPins) == "function" then
        pcall(pinManager.UpdateMovingPins, pinManager)
    end

    -- v0.29.311: do not force a second native World Map OnUpdate pump in the
    -- same frame. The first pump plus RefreshCustomPins builds the active set;
    -- delayed mirror snapshots catch providers that finish on a later UI tick.

    -- Snapshot the freshly rebuilt manager into the Suite mirror immediately.
    local captured = self:CaptureAllNativeMapPins(true)
    self.hiddenPinPrimeInProgress = false
    return refreshed or captured
end

local function clean(text, fallback)
    text = tostring(text or "")
    text = string.gsub(text, "[%c]+", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return fallback or "" end
    return text
end

-- Defined after safe/safeNumber/clean so these are captured as locals rather
-- than looked up as globals when a store opens.
function M:GetCurrentStoreIdentity()
    local storeName = "Merchant"
    if type(GetStoreName) == "function" then
        local rawName = safe(GetStoreName, "Merchant")
        storeName = clean(rawName, "Merchant")
    end

    local storeType = classifyStoreText(storeName)
    local representativeIcon = nil
    local sampleText = storeName

    if type(GetNumStoreItems) == "function" and type(GetStoreEntryInfo) == "function" then
        local count = math.min(24, safeNumber(GetNumStoreItems, 0))
        for i = 1, count do
            local icon, itemName = safe(GetStoreEntryInfo, nil, i)
            icon = tostring(icon or "")
            itemName = tostring(itemName or "")
            if not representativeIcon and icon ~= "" then representativeIcon = icon end
            sampleText = sampleText .. " " .. itemName .. " " .. icon
            if not storeType then storeType = classifyStoreText(itemName .. " " .. icon) end
        end
    end

    storeType = storeType or classifyStoreText(sampleText) or "merchant"
    return storeName, storeType, representativeIcon or POI_FALLBACK_TEXTURE
end


-- Legacy walk-up/interaction pin learning is retired in 0.27.02.
-- Native ESO/LibMapPins town icons are now the authoritative source.
-- Keep the old functions for saved-variable compatibility, but do not learn or
-- render those historical pins after the user clears them.
M.LEGACY_LEARNED_PINS_ENABLED = false

-- Learned town services. ESO does not expose every service NPC/station through
-- the regular POI list, so remember the player's exact map position when a
-- service UI is actually used. Whenever possible, borrow the nearest ESO POI
-- texture so the learned pin matches the icon the base game uses for that spot.
local CRAFTING_SERVICE_TYPES = {}
local function addCraftingServiceType(constantValue, key, label)
    if constantValue ~= nil then CRAFTING_SERVICE_TYPES[constantValue] = { key=key, label=label } end
end
addCraftingServiceType(CRAFTING_TYPE_BLACKSMITHING, "blacksmithing", "Blacksmithing Station")
addCraftingServiceType(CRAFTING_TYPE_CLOTHIER, "clothing", "Clothing Station")
addCraftingServiceType(CRAFTING_TYPE_WOODWORKING, "woodworking", "Woodworking Station")
addCraftingServiceType(CRAFTING_TYPE_ALCHEMY, "alchemy", "Alchemy Station")
addCraftingServiceType(CRAFTING_TYPE_ENCHANTING, "enchanting", "Enchanting Table")
addCraftingServiceType(CRAFTING_TYPE_PROVISIONING, "provisioning", "Provisioning Station")
addCraftingServiceType(CRAFTING_TYPE_JEWELRYCRAFTING, "jewelry", "Jewelry Crafting Station")
addCraftingServiceType(CRAFTING_TYPE_SCRIBING, "scribing", "Scribing Altar")

-- Service-specific ESO UI art used only when the base map does not expose a
-- nearby service pin. The first choice is always the actual nearby ESO POI
-- texture captured at interaction time.
local SERVICE_FALLBACK_ICONS = {
    stable = "EsoUI/Art/Icons/ServiceMapPins/servicepin_stable.dds",
    enchanting = "EsoUI/Art/Crafting/crafting_runestone02_slot.dds",
    jewelry = "EsoUI/Art/Crafting/jewelry_tabIcon_icon_up.dds",
    blacksmithing = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds",
    clothing = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds",
    woodworking = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds",
    alchemy = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds",
    provisioning = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds",
    scribing = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
    service = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
}

local function getServiceFallbackIcon(kind)
    return SERVICE_FALLBACK_ICONS[tostring(kind or "service")] or SERVICE_FALLBACK_ICONS.service
end

function M:FindNearestPOIIdentity(x, y, kind, label)
    local zoneIndex = tonumber(self.zoneIndex)
    if not zoneIndex or type(GetNumPOIs) ~= "function" or type(GetPOIMapInfo) ~= "function" then
        return nil, nil
    end
    local wanted = string.lower(tostring(kind or "") .. " " .. tostring(label or ""))
    local bestName, bestIcon, bestScore
    local count = safeNumber(GetNumPOIs, 0, zoneIndex)
    for poiIndex = 1, count do
        local px, py, _, icon, shown, locked = safe(GetPOIMapInfo, nil, zoneIndex, poiIndex)
        px, py = tonumber(px), tonumber(py)
        if shown == true and locked ~= true and px and py then
            local name = ""
            if type(GetPOIInfo) == "function" then
                name = clean(select(1, safe(GetPOIInfo, "", zoneIndex, poiIndex)), "")
            end
            local dx, dy = px - x, py - y
            local d2 = dx * dx + dy * dy
            -- Search a wider neighborhood than before. Town service icons are
            -- often offset from the exact NPC/station interaction position.
            if d2 <= 0.000625 then
                local hay = string.lower(name .. " " .. tostring(icon or ""))
                local score = d2
                -- Strongly prefer a nearby pin whose name/texture resembles
                -- the service we just interacted with.
                for token in string.gmatch(wanted, "%a+") do
                    if #token >= 4 and string.find(hay, token, 1, true) then
                        score = score - 0.001
                    end
                end
                if icon and icon ~= "" and (bestScore == nil or score < bestScore) then
                    bestScore, bestName, bestIcon = score, name, icon
                end
            end
        end
    end
    return bestName, bestIcon
end

function M:RememberServiceHere(kind, label, iconOverride)
    if self.LEGACY_LEARNED_PINS_ENABLED ~= true then return false end
    if not EPC.saved then return false end
    kind = tostring(kind or "service")
    if kind == "stable" then return false end

    -- Save services in the exact minimap map context currently being rendered.
    -- Using a cached pre-interaction map caused stable records to land in the
    -- wrong bucket on some characters.
    local mapId = tonumber(self.mapId)
    local x, y

    if not mapId and type(GetCurrentMapId) == "function" then mapId = safeNumber(GetCurrentMapId, 0) end
    if not mapId or mapId <= 0 then return false end

    if not x or not y then
        local px, py, _, shown = safe(GetMapPlayerPosition, nil, "player")
        px, py = tonumber(px), tonumber(py)
        if shown == true and px and py and px > 0 and px < 1 and py > 0 and py < 1 then
            x, y = px, py
        end
    end

    -- Interaction scenes can hide map-position data. Fall back to the most
    -- recent minimap position if the direct API position is unavailable.
    if not x or not y or x <= 0 or x >= 1 or y <= 0 or y >= 1 then
        x, y = tonumber(self.playerX), tonumber(self.playerY)
    end
    if not x or not y or x <= 0 or x >= 1 or y <= 0 or y >= 1 then return false end

    local poiName, poiIcon = self:FindNearestPOIIdentity(x, y, kind, label)
    local name = clean(label or poiName, "Service")
    local icon = iconOverride
    if not icon or icon == "" then icon = poiIcon end
    if not icon or icon == "" then icon = getServiceFallbackIcon(kind) end

    EPC.saved.miniMapKnownServices = EPC.saved.miniMapKnownServices or {}
    local mapKey = tostring(mapId)
    local list = EPC.saved.miniMapKnownServices[mapKey]
    if type(list) ~= "table" then list = {}; EPC.saved.miniMapKnownServices[mapKey] = list end

    for i = 1, #list do
        local old = list[i]
        local dx = x - (tonumber(old.x) or -10)
        local dy = y - (tonumber(old.y) or -10)
        -- Every learned service is a one-time location. Interaction callbacks
        -- can report slightly different coordinates on later visits, so use a
        -- forgiving radius and never append/update a second copy.
        local sameLocationRadius2 = 0.000225
        if tostring(old.kind or "service") == kind and (dx * dx + dy * dy) < sameLocationRadius2 then
            return true
        end
    end

    list[#list + 1] = { x=x, y=y, kind=kind, name=name, icon=icon, learned=true, lastSeen=safeNumber(GetTimeStamp, 0) }
    while #list > 80 do table.remove(list, 1) end
    self.staticPinsDirty = true
    return true
end

function M:RememberCurrentCraftingStation()
    if type(GetCraftingInteractionType) ~= "function" then return false end
    local craftingType = safeNumber(GetCraftingInteractionType, 0)
    local info = CRAFTING_SERVICE_TYPES[craftingType]
    if not info then return false end
    return self:RememberServiceHere(info.key, info.label)
end

function M:RememberStableHere()
    -- Stable learning was removed. Native ESO stable POIs, when exposed by the
    -- map API, are rendered as ordinary POIs instead of being persisted by us.
    return false
end

-- Stable masters are not exposed consistently through one dedicated event on
-- every UI/input path. Detect them while the conversation/chatter window is
-- still open, before the stable scene can hide map-position data.
function M:ChatterLooksLikeStable()
    if type(GetNumChatterOptions) ~= "function" or type(GetChatterOption) ~= "function" then return false end
    local count = safeNumber(GetNumChatterOptions, 0)
    for i = 1, count do
        local text, optionType = safe(GetChatterOption, nil, i)
        local lower = string.lower(tostring(text or ""))
        -- English text fallback plus optional API constants when present.
        if string.find(lower, "stable", 1, true)
            or string.find(lower, "riding", 1, true)
            or string.find(lower, "train mount", 1, true)
            or string.find(lower, "train my mount", 1, true)
            or (CHATTER_START_STABLE ~= nil and optionType == CHATTER_START_STABLE)
            or (CHATTER_BEGIN_STABLE ~= nil and optionType == CHATTER_BEGIN_STABLE)
            or (CHATTER_STABLE ~= nil and optionType == CHATTER_STABLE) then
            return true
        end
    end
    return false
end

function M:ActiveSceneLooksLikeStable()
    if not SCENE_MANAGER then return false end
    local scene = nil
    if type(SCENE_MANAGER.GetCurrentScene) == "function" then
        scene = safe(function() return SCENE_MANAGER:GetCurrentScene() end, nil)
    end
    if scene and type(scene.GetName) == "function" then
        local name = string.lower(tostring(safe(function() return scene:GetName() end, "") or ""))
        if string.find(name, "stable", 1, true) or string.find(name, "riding", 1, true) then return true end
    end
    return false
end

local function mapPointNear(ax, ay, bx, by, radius2)
    ax, ay, bx, by = tonumber(ax), tonumber(ay), tonumber(bx), tonumber(by)
    if not ax or not ay or not bx or not by then return false end
    local dx, dy = ax - bx, ay - by
    return (dx * dx + dy * dy) <= (radius2 or 0.000225)
end

local function normalizedPinIdentity(item)
    if type(item) ~= "table" then return "" end
    local name = string.lower(clean(item.name or "", ""))
    local icon = string.lower(tostring(item.icon or ""))
    local kind = string.lower(tostring(item.kind or item.storeType or ""))
    local pinType = tostring(item.pinType or "")
    return name .. "|" .. icon .. "|" .. kind .. "|" .. pinType
end

-- Merchant dedupe must identify the actual store, not just the map position.
-- This preserves two genuinely different merchants that happen to stand beside
-- each other while preventing repeated visits to the same merchant from adding
-- another saved pin.
local function normalizedMerchantIdentity(item)
    if type(item) ~= "table" then return "" end
    local name = string.lower(clean(item.name or "", ""))
    local storeType = string.lower(tostring(item.storeType or "merchant"))
    local icon = string.lower(tostring(item.icon or ""))
    if name ~= "" and name ~= "merchant" and name ~= "store" then
        return name .. "|" .. storeType
    end
    return name .. "|" .. storeType .. "|" .. icon
end

function M:CleanupLearnedMapData()
    if not EPC.saved then return end

    -- Remove the abandoned custom stable-learning records entirely.
    if type(EPC.saved.miniMapKnownServices) == "table" then
        for mapKey, list in pairs(EPC.saved.miniMapKnownServices) do
            if type(list) == "table" then
                local compact = {}
                for i = 1, #list do
                    local item = list[i]
                    if type(item) == "table" and tostring(item.kind or "service") ~= "stable" then
                        local duplicate = false
                        for j = 1, #compact do
                            local old = compact[j]
                            if tostring(old.kind or "service") == tostring(item.kind or "service")
                                and mapPointNear(old.x, old.y, item.x, item.y, 0.000225) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then compact[#compact + 1] = item end
                    end
                end
                EPC.saved.miniMapKnownServices[mapKey] = compact
            end
        end
    end

    -- Collapse legacy duplicate merchant records created by repeated visits.
    if type(EPC.saved.miniMapKnownMerchants) == "table" then
        for mapKey, list in pairs(EPC.saved.miniMapKnownMerchants) do
            if type(list) == "table" then
                local compact = {}
                for i = 1, #list do
                    local item = list[i]
                    if type(item) == "table" then
                        local duplicate = false
                        for j = 1, #compact do
                            local old = compact[j]
                            local sameIdentity = normalizedMerchantIdentity(old) == normalizedMerchantIdentity(item)
                            if sameIdentity and mapPointNear(old.x, old.y, item.x, item.y, 0.000225) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then compact[#compact + 1] = item end
                    end
                end
                EPC.saved.miniMapKnownMerchants[mapKey] = compact
            end
        end
    end

    -- Collapse duplicate learned POIs while preserving genuinely different POIs
    -- that happen to be close together in dense towns.
    if type(EPC.saved.miniMapKnownPOIs) == "table" then
        for mapKey, list in pairs(EPC.saved.miniMapKnownPOIs) do
            if type(list) == "table" then
                local compact = {}
                for i = 1, #list do
                    local item = list[i]
                    if type(item) == "table" then
                        local duplicate = false
                        local ident = normalizedPinIdentity(item)
                        for j = 1, #compact do
                            local old = compact[j]
                            if ident ~= "|||" and ident == normalizedPinIdentity(old)
                                and mapPointNear(old.x, old.y, item.x, item.y, 0.000225) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then compact[#compact + 1] = item end
                    end
                end
                EPC.saved.miniMapKnownPOIs[mapKey] = compact
            end
        end
    end
end

function M:ClearLegacyMapIcons()
    if not EPC.saved then return false end

    -- These are the pre-0.27 walk-up/interaction caches. Do NOT clear
    -- miniMapNativeTownPins: those are the new ESO/LibMapPins snapshots.
    EPC.saved.miniMapKnownServices = {}
    EPC.saved.miniMapKnownMerchants = {}
    EPC.saved.miniMapKnownPOIs = {}

    -- Drop any already-built legacy rows from the current render and force a
    -- clean native-pin rebuild immediately.
    self.merchantData = {}
    self.serviceData = {}
    self.poiData = {}
    self.staticPinsDirty = true
    if type(self.RefreshStaticPins) == "function" then self:RefreshStaticPins() end
    if type(self.UpdatePanAndPins) == "function" then self:UpdatePanAndPins(true) end

    if EPC.Print then
        EPC:Print("Legacy walk-up map icons cleared. Native ESO town icons, checkpoints, and minimap settings were kept.")
    end
    return true
end

function M:RememberVisiblePOIs()
    if self.LEGACY_LEARNED_PINS_ENABLED ~= true then return end
    if not EPC.saved then return end
    local mapId, zoneIndex = tonumber(self.mapId), tonumber(self.zoneIndex)
    if not mapId or not zoneIndex or type(GetNumPOIs) ~= "function" or type(GetPOIMapInfo) ~= "function" then return end
    EPC.saved.miniMapKnownPOIs = EPC.saved.miniMapKnownPOIs or {}
    local mapKey = tostring(mapId)
    local list = EPC.saved.miniMapKnownPOIs[mapKey]
    if type(list) ~= "table" then list = {}; EPC.saved.miniMapKnownPOIs[mapKey] = list end

    local count = safeNumber(GetNumPOIs, 0, zoneIndex)
    for poiIndex = 1, count do
        local x, y, pinType, icon, shown, locked, discovered, nearby = safe(GetPOIMapInfo, nil, zoneIndex, poiIndex)
        x, y = tonumber(x), tonumber(y)
        if shown == true and locked ~= true and x and y and (discovered == true or nearby == true) then
            local name = type(GetPOIInfo) == "function" and clean(select(1, safe(GetPOIInfo, "", zoneIndex, poiIndex)), "Point of Interest") or "Point of Interest"
            local found = false
            for i = 1, #list do
                local old = list[i]
                local dx, dy = x - (tonumber(old.x) or -10), y - (tonumber(old.y) or -10)
                if (dx * dx + dy * dy) < 0.000225 then
                    found = true
                    break
                end
            end
            if not found then list[#list + 1] = { x=x, y=y, name=name, icon=icon, pinType=pinType, learned=true } end
        end
    end
    while #list > 220 do table.remove(list, 1) end
end

function M:AddRememberedServices()
    if self.LEGACY_LEARNED_PINS_ENABLED ~= true then return end
    if not EPC.saved then return end
    local mapId = tonumber(self.mapId)
    if not mapId then return end

    self.serviceData = self.serviceData or {}
    local services = type(EPC.saved.miniMapKnownServices) == "table" and EPC.saved.miniMapKnownServices[tostring(mapId)] or nil
    if type(services) == "table" then
        for i = 1, #services do
            local saved = services[i]
            local x, y = tonumber(saved.x), tonumber(saved.y)
            local kind = tostring(saved.kind or "service")
            if kind ~= "stable" and x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                local duplicate = false
                for j = 1, #self.serviceData do
                    local old = self.serviceData[j]
                    if tostring(old.kind or "service") == kind and mapPointNear(old.x, old.y, x, y, 0.000225) then
                        duplicate = true
                        break
                    end
                end
                -- If ESO already exposes a live POI at this spot, prefer the
                -- native pin rather than drawing a second learned icon on top.
                if not duplicate then
                    for j = 1, #(self.poiData or {}) do
                        local old = self.poiData[j]
                        if mapPointNear(old.x, old.y, x, y, 0.000225) then
                            duplicate = true
                            break
                        end
                    end
                end
                if not duplicate then
                    local rememberedIcon = saved.icon
                    if not rememberedIcon or rememberedIcon == "" or rememberedIcon == POI_FALLBACK_TEXTURE then
                        rememberedIcon = getServiceFallbackIcon(kind)
                        saved.icon = rememberedIcon
                    end
                    self.serviceData[#self.serviceData + 1] = {
                        x=x, y=y, name=clean(saved.name, "Service"), icon=rememberedIcon,
                        kind=kind, discovered=true, nearby=true, learned=true, isService=true,
                    }
                end
            end
        end
    end

    local pois = type(EPC.saved.miniMapKnownPOIs) == "table" and EPC.saved.miniMapKnownPOIs[tostring(mapId)] or nil
    if type(pois) == "table" then
        self.poiData = self.poiData or {}
        for i = 1, #pois do
            local saved = pois[i]
            local x, y = tonumber(saved.x), tonumber(saved.y)
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local duplicate = false
                -- Prefer live ESO POIs over remembered copies.
                for j = 1, #self.poiData do
                    local old = self.poiData[j]
                    if mapPointNear(old.x, old.y, x, y, 0.000225) then
                        duplicate = true
                        break
                    end
                end
                -- Also prevent an old remembered POI from duplicating a learned
                -- merchant/service at the same location.
                if not duplicate then
                    for j = 1, #(self.merchantData or {}) do
                        local old = self.merchantData[j]
                        if mapPointNear(old.x, old.y, x, y, 0.000225) then
                            duplicate = true
                            break
                        end
                    end
                end
                if not duplicate then
                    for j = 1, #(self.serviceData or {}) do
                        local old = self.serviceData[j]
                        if mapPointNear(old.x, old.y, x, y, 0.000225) then
                            duplicate = true
                            break
                        end
                    end
                end
                if not duplicate then
                    self.poiData[#self.poiData + 1] = {
                        x=x, y=y, name=clean(saved.name, "Point of Interest"), icon=saved.icon,
                        pinType=saved.pinType, discovered=true, nearby=true, learned=true, distance2=0,
                    }
                end
            end
        end
    end
end

local function directionText(dx, dy)
    dx = tonumber(dx) or 0
    dy = tonumber(dy) or 0
    local ax, ay = math.abs(dx), math.abs(dy)
    if ax < 0.00001 and ay < 0.00001 then return "HERE" end
    if ax < ay * 0.42 then return dy < 0 and "N" or "S" end
    if ay < ax * 0.42 then return dx > 0 and "E" or "W" end
    if dx > 0 then return dy < 0 and "NE" or "SE" end
    return dy < 0 and "NW" or "SW"
end

local function makeBackdrop(parent, name)
    local control = wm:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(0.035, 0.045, 0.060, 0.22)
    control:SetEdgeColor(0.20, 0.23, 0.30, 0.34)
    control:SetEdgeTexture(nil, 1, 1, 1)
    return control
end

local function makeLabel(parent, name, font, color, align)
    local label = wm:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "$(BOLD_FONT)|14|soft-shadow-thin")
    label:SetColor(unpack(color or COLORS.white))
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    if label.SetMaxLineCount then label:SetMaxLineCount(1) end
    return label
end

local function easSceneIsShowingOrShown(scene)
    if not scene then return false end
    if type(scene.IsShowing) == "function" then
        local ok, showing = pcall(scene.IsShowing, scene)
        if ok and showing == true then return true end
    end
    -- ESO commonly builds native map pins while the scene is still entering
    -- SCENE_SHOWING. IsShowing() can remain false during that exact window,
    -- so accept SHOWING/SHOWN explicitly without accepting hidden background
    -- map changes used by quest/travel resolution.
    if type(scene.GetState) == "function" then
        local ok, state = pcall(scene.GetState, scene)
        if ok then
            if SCENE_SHOWING ~= nil and state == SCENE_SHOWING then return true end
            if SCENE_SHOWN ~= nil and state == SCENE_SHOWN then return true end
        end
    end
    return false
end

local function isWorldMapShowing()
    if easSceneIsShowingOrShown(WORLD_MAP_SCENE) then return true end
    return false
end

local MENU_SCENES = {
    "inventory", "character", "skills", "championPerks", "journal",
    "collectionsBook", "groupMenu", "contacts", "guildHome", "mailInbox",
    "bank", "store", "tradingHouse", "crafting", "gameMenuInGame", "settings",
}

local function isMenuShowing()
    -- v0.29.373: free-pointer/cursor mode is not a menu. Rely on the Suite's
    -- scene-aware suppression helper first so pressing '.' cannot hide the map.
    if EPC and type(EPC.IsGameplayHudSuppressed) == "function" then
        local ok, suppressed = pcall(EPC.IsGameplayHudSuppressed, EPC)
        if ok then return suppressed == true end
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" then
        for i = 1, #MENU_SCENES do
            local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, MENU_SCENES[i])
            if ok and showing == true then return true end
        end
    end
    return false
end

function M:GetMode()
    local mode = string.upper(tostring(EPC.saved and EPC.saved.miniMapMode or "SMART"))
    if not VALID_MODES[mode] then mode = "SMART" end
    return mode
end

function M:SetMode(mode)
    if not EPC.saved then return false end
    mode = string.upper(tostring(mode or ""))
    if not VALID_MODES[mode] then return false end
    EPC.saved.miniMapMode = mode
    self.staticPinsDirty = true
    self:RefreshStaticPins()
    self:UpdatePanAndPins(true)
    self:UpdateContextText(true)
    return true
end

function M:LayerEnabled(layer)
    if not EPC.saved then return false end
    local mode = self:GetMode()
    local profiles = {
        -- Navigation landmarks stay visible in every profile. Mode now changes
        -- supplemental layers, not the core town/POI/wayshrine information.
        SMART = { quest=true, waypoint=true, shrines=true, group=true, companion=true, rally=true, pois=true, trail=true },
        QUEST = { quest=true, waypoint=true, shrines=true, group=false, companion=false, rally=false, pois=true, trail=false },
        EXPLORE = { quest=true, waypoint=true, shrines=true, group=false, companion=false, rally=false, pois=true, trail=true },
        GROUP = { quest=true, waypoint=true, shrines=true, group=true, companion=true, rally=true, pois=true, trail=false },
        MINIMAL = { quest=true, waypoint=true, shrines=true, group=false, companion=false, rally=false, pois=true, trail=false },
        CUSTOM = { quest=true, waypoint=true, shrines=true, group=true, companion=true, rally=true, pois=true, trail=true },
    }
    local p = profiles[mode] or profiles.SMART
    if p[layer] ~= true then return false end

    local toggles = {
        quest = "miniMapShowQuest",
        waypoint = "miniMapShowWaypoint",
        shrines = "miniMapShowWayshrines",
        group = "miniMapShowGroup",
        companion = "miniMapShowCompanion",
        rally = "miniMapShowRally",
        pois = "miniMapShowPOIs",
        trail = "miniMapShowTrail",
    }
    local key = toggles[layer]
    if key and EPC.saved[key] == false then return false end

    -- Keep navigation landmarks visible even in combat. SMART may still hide the
    -- breadcrumb trail, but it never removes POIs or wayshrines from the map.
    if mode == "SMART" and safe(IsUnitInCombat, false, "player") == true then
        if layer == "trail" then return false end
    end
    return true
end

-- v0.29.307: The stock SetClampedToScreen movement clamp keeps top-level
-- windows inside ESO's UI-safe rectangle, which prevents the minimap from being
-- placed flush against some monitor edges/corners. HUD Layout Mode now uses its
-- own light recovery clamp instead: the map may be placed directly on any edge
-- (or slightly off-screen), while a small grab strip always remains recoverable.
function M:GetPositionRecoveryBounds()
    if not self.frame or not GuiRoot then return nil end
    local frameW = tonumber(self.frame:GetWidth()) or tonumber(self.frameSize) or 0
    local frameH = tonumber(self.frame:GetHeight()) or tonumber(self.frameSize) or 0
    local rootW = tonumber(GuiRoot:GetWidth()) or 0
    local rootH = tonumber(GuiRoot:GetHeight()) or 0
    if frameW <= 0 or frameH <= 0 or rootW <= 0 or rootH <= 0 then return nil end

    -- Keep only a small draggable part visible. This deliberately does NOT keep
    -- the whole minimap inside the screen, so corners and side edges are usable.
    local grab = math.floor(math.min(56, math.max(28, math.min(frameW, frameH) * 0.16)) + 0.5)
    return -(frameW - grab), rootW - grab, -(frameH - grab), rootH - grab
end

function M:KeepPositionRecoverable(left, top)
    left, top = tonumber(left), tonumber(top)
    if not left or not top then return left, top end
    local minLeft, maxLeft, minTop, maxTop = self:GetPositionRecoveryBounds()
    if minLeft then
        left = clamp(left, minLeft, maxLeft)
        top = clamp(top, minTop, maxTop)
    end
    return left, top
end

function M:SavePosition()
    if not EPC.saved or not self.frame then return end
    local left = tonumber(self.frame:GetLeft())
    local top = tonumber(self.frame:GetTop())
    if left and top then
        left, top = self:KeepPositionRecoverable(left, top)
        -- StartMoving may leave the control fractionally outside our recovery
        -- range. Re-anchor only when correction is actually needed.
        local currentLeft = tonumber(self.frame:GetLeft()) or left
        local currentTop = tonumber(self.frame:GetTop()) or top
        if math.abs(currentLeft - left) > 0.25 or math.abs(currentTop - top) > 0.25 then
            self.frame:ClearAnchors()
            self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
        end
        EPC.saved.miniMapLeft = left
        EPC.saved.miniMapTop = top
        -- A separate validity flag is required because edge placement can now
        -- legitimately save negative coordinates. The old -1 sentinel alone
        -- cannot distinguish those positions from "use default".
        EPC.saved.miniMapPositionSaved = true
    end
end

function M:AnchorFrame()
    if not self.frame or not EPC.saved then return end
    self.frame:ClearAnchors()
    local left = tonumber(EPC.saved.miniMapLeft) or -1
    local top = tonumber(EPC.saved.miniMapTop) or -1
    -- Migrate existing installations automatically: any old non-negative saved
    -- position remains valid even before miniMapPositionSaved exists.
    local hasSavedPosition = EPC.saved.miniMapPositionSaved == true or (left >= 0 and top >= 0)
    if hasSavedPosition then
        left, top = self:KeepPositionRecoverable(left, top)
        EPC.saved.miniMapLeft = left
        EPC.saved.miniMapTop = top
        EPC.saved.miniMapPositionSaved = true
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -34, 185)
    end
end

function M:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.miniMapLeft = -1
    EPC.saved.miniMapTop = -1
    EPC.saved.miniMapPositionSaved = false
    self:AnchorFrame()
end

function M:CreatePin(name, size, texture, color, mapLocked)
    local parent = (mapLocked == true and self.staticPinLayer) or self.viewport
    local pin = wm:CreateControl(name, parent, CT_TEXTURE)
    pin.easMapLocked029312 = mapLocked == true
    pin:SetDimensions(size, size)
    pin:SetTexture(texture or WAYPOINT_TEXTURE)
    pin:SetDrawLayer(DL_OVERLAY)
    pin:SetDrawLevel(60)
    if color then pin:SetColor(unpack(color)) end
    pin:SetHidden(true)
    return pin
end

-- Special game modes benefit from a denser, fully labeled navigation view.
-- Keep normal overland PvE icon-focused, but show names automatically in
-- Cyrodiil / Imperial City / Battlegrounds and instanced dungeons.
function M:IsPvPIconOnlyMode()
    if safe(IsPlayerInAvAWorld, false) == true then return true end
    if safe(IsActiveWorldBattleground, false) == true then return true end
    if safe(IsInCampaign, false) == true then return true end
    return false
end

function M:IsLabeledMapMode()
    -- The Suite minimap mirrors ESO's map icon presentation. ESO's full map
    -- does not print a text label under every dungeon/service pin, so keep
    -- object labels disabled here too. This also removes the old generic
    -- "Map Location" spam seen on dungeon minimaps.
    return false
end

function M:EnsureMapObjectLabels(kind, count)
    self.mapObjectLabels = self.mapObjectLabels or {}
    local pool = self.mapObjectLabels[kind]
    if not pool then pool = {}; self.mapObjectLabels[kind] = pool end
    for i = #pool + 1, count do
        local label = makeLabel(self.viewport, "EPC_MiniMap_Label_" .. tostring(kind) .. "_" .. tostring(i), "$(BOLD_FONT)|11|soft-shadow-thick", COLORS.white, TEXT_ALIGN_CENTER)
        label:SetDimensions(150, 18)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(96)
        label:SetHidden(true)
        pool[i] = label
    end
    return pool
end

function M:HideMapObjectLabels()
    if not self.mapObjectLabels then return end
    for _, pool in pairs(self.mapObjectLabels) do
        for i = 1, #pool do pool[i]:SetHidden(true) end
    end
end

function M:PlaceMapObjectLabel(label, text, x, y, yOffset, color)
    if not label or not text or text == "" then return false end
    local px, py, inside = self:MapToScreen(x, y)
    if not inside or px == nil or py == nil then label:SetHidden(true) return false end
    label:ClearAnchors()
    label:SetAnchor(TOP, self.viewport, TOPLEFT, px, py + (tonumber(yOffset) or 10))
    label:SetText(tostring(text))
    if color then label:SetColor(unpack(color)) else label:SetColor(unpack(COLORS.white)) end
    label:SetHidden(false)
    return true
end

function M:GetPvPPinTexture(pinType)
    if pinType == nil then return nil end
    if type(GetMapPinTexture) == "function" then
        local tex = safe(GetMapPinTexture, nil, pinType)
        if type(tex) == "string" and tex ~= "" then return tex end
    end
    if ZO_MapPin and type(ZO_MapPin.PIN_DATA) == "table" then
        local def = ZO_MapPin.PIN_DATA[pinType]
        if type(def) == "table" then
            local tex = def.texture
            if type(tex) == "string" and tex ~= "" then return tex end
            if type(tex) == "function" then
                local ok, value = pcall(tex, pinType)
                if ok and type(value) == "string" and value ~= "" then return value end
            end
        end
    end
    return nil
end

-- Normal PvE maps should use the same native-icon approach as the Cyrodiil
-- layer.  Prefer the exact texture ESO supplies for the POI.  Some POIs only
-- expose a MapDisplayPinType, so fall back to ESO's native pin definition
-- instead of drawing the Suite's generic custom-destination diamond.
function M:GetNativePvEMapPinTexture(icon, pinType)
    if type(icon) == "string" and icon ~= "" and icon ~= POI_FALLBACK_TEXTURE and icon ~= WAYPOINT_TEXTURE then
        return icon
    end
    local native = self:GetPvPPinTexture(pinType)
    if type(native) == "string" and native ~= "" and native ~= POI_FALLBACK_TEXTURE and native ~= WAYPOINT_TEXTURE then
        return native
    end
    return nil
end

-- v0.26.19 - Native town/service pin mirror. ESO creates the complete city/town
-- icon set on its World Map pin manager (banks, crafting, stables, merchants,
-- guild traders, shrines, etc.). Capture those native pins when ESO builds a
-- map and reuse their exact texture/coordinates on the Suite minimap.
local function easNativeTownPinIsDynamic(texture)
    local t = string.lower(tostring(texture or ""))
    if t == "" then return true end
    local dynamic = {
        -- Quest pins are intentionally NOT filtered in v0.29.295. They are
        -- rebuilt in gameplay now, so the minimap can mirror the same quest
        -- markers that would normally appear only after opening the World Map.
        "player", "group", "companion", "waypoint", "rally",
        "ping", "ava_", "battleground", "killlocation", "elder_scroll",
    }
    for i=1,#dynamic do if string.find(t, dynamic[i], 1, true) then return true end end
    return false
end

-- v0.29.439: Native quest/objective markers must not compete with ordinary
-- service/POI mirror pins for the minimap's capped render budget. ESO quest pin
-- artwork consistently carries quest/objective/journal naming, and providers
-- commonly expose questIndex/questId fields on the tag. Keep the test broad but
-- limited to clear quest semantics so unrelated pins are never promoted.
local function easLooksLikeNativeQuestPin(texture, pinTag, pinType)
    -- v0.29.440: Prefer ESO's actual map-pin type constants when available.
    -- Texture-name matching alone misses several quest pin styles whose DDS
    -- path does not contain the word quest/objective. Unknown constants are
    -- simply nil on older clients, so this stays backward compatible.
    local pt = tonumber(pinType)
    if pt ~= nil then
        local questTypeNames = {
            "MAP_PIN_TYPE_QUEST_CONDITION",
            "MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION",
            "MAP_PIN_TYPE_QUEST_ENDING",
            "MAP_PIN_TYPE_QUEST_OFFER",
            "MAP_PIN_TYPE_QUEST_REPEATABLE_OFFER",
            "MAP_PIN_TYPE_TRACKED_QUEST_CONDITION",
            "MAP_PIN_TYPE_TRACKED_QUEST_ENDING",
            "MAP_PIN_TYPE_TRACKED_QUEST_OFFER",
            "MAP_PIN_TYPE_QUEST_INTERACT",
        }
        for i = 1, #questTypeNames do
            local value = _G and _G[questTypeNames[i]] or nil
            if value ~= nil and tonumber(value) == pt then return true end
        end
    end

    local t = string.lower(tostring(texture or ""))
    if t ~= "" then
        local words = { "quest", "objective", "journal" }
        for i=1,#words do
            if string.find(t, words[i], 1, true) then return true end
        end
    end
    if type(pinTag) == "table" then
        if tonumber(pinTag.questIndex or pinTag.questId or pinTag.journalQuestIndex or pinTag.journalIndex) then
            return true
        end
        local tagKind = string.lower(tostring(pinTag.pinType or pinTag.type or pinTag.kind or ""))
        if string.find(tagKind, "quest", 1, true) or string.find(tagKind, "objective", 1, true) then
            return true
        end
    end
    return false
end

local function easUniversalPointForMap(mapId, x, y)
    mapId = tonumber(mapId) or 0
    x, y = tonumber(x), tonumber(y)
    if mapId <= 0 or x == nil or y == nil then return nil, nil end

    -- LibGPS measurements are map-id aware and do not require changing the
    -- player's visible World Map. This is the primary projection path.
    if GPS and type(GPS.GetMapMeasurementByMapId) == "function" then
        local ok, measurement = pcall(GPS.GetMapMeasurementByMapId, GPS, mapId)
        if ok and measurement and type(measurement.ToGlobal) == "function" then
            local ok2, gx, gy = pcall(measurement.ToGlobal, measurement, x, y)
            gx, gy = tonumber(gx), tonumber(gy)
            if ok2 and gx ~= nil and gy ~= nil then return gx, gy end
        end
    end

    -- Safe fallback for maps not yet measured by LibGPS. This API is passive;
    -- unlike SetMapToPlayerLocation/ProcessMapClick it never changes map state.
    if type(GetUniversallyNormalizedMapInfo) == "function" then
        local ok, ox, oy, w, h = pcall(GetUniversallyNormalizedMapInfo, mapId)
        ox, oy, w, h = tonumber(ox), tonumber(oy), tonumber(w), tonumber(h)
        if ok and ox and oy and w and h and w > 0 and h > 0 then
            return ox + (x * w), oy + (y * h)
        end
    end
    return nil, nil
end

local function easLocalPointForMap(mapId, gx, gy)
    mapId = tonumber(mapId) or 0
    gx, gy = tonumber(gx), tonumber(gy)
    if mapId <= 0 or gx == nil or gy == nil then return nil, nil end

    if GPS and type(GPS.GetMapMeasurementByMapId) == "function" then
        local ok, measurement = pcall(GPS.GetMapMeasurementByMapId, GPS, mapId)
        if ok and measurement and type(measurement.ToLocal) == "function" then
            local ok2, x, y = pcall(measurement.ToLocal, measurement, gx, gy)
            x, y = tonumber(x), tonumber(y)
            if ok2 and x and y then
                local epsilon = 0.001
                if x >= -epsilon and x <= 1 + epsilon and y >= -epsilon and y <= 1 + epsilon then
                    return clamp(x, 0, 1), clamp(y, 0, 1)
                end
            end
        end
    end

    if type(GetUniversallyNormalizedMapInfo) == "function" then
        local ok, ox, oy, w, h = pcall(GetUniversallyNormalizedMapInfo, mapId)
        ox, oy, w, h = tonumber(ox), tonumber(oy), tonumber(w), tonumber(h)
        if ok and ox and oy and w and h and w > 0 and h > 0 then
            local x, y = (gx - ox) / w, (gy - oy) / h
            local epsilon = 0.001
            if x >= -epsilon and x <= 1 + epsilon and y >= -epsilon and y <= 1 + epsilon then
                return clamp(x, 0, 1), clamp(y, 0, 1)
            end
        end
    end
    return nil, nil
end

function M:CaptureNativeTownPin(pinType, pinTag, x, y, textureOverride, sizeOverride)
    if not EPC.saved then return end
    if EPC.TreasureLocator and type(EPC.TreasureLocator.IsTreasurePinTag) == "function"
        and EPC.TreasureLocator:IsTreasurePinTag(pinTag) then return end
    -- Normally capture pins while ESO's World Map is visible. 0.29.33 also
    -- allows a tightly-scoped gameplay capture immediately after the player's
    -- current map/sub-map changes. The scoped flag is set only by
    -- CaptureAllNativeMapPins(true), after it verifies that ESO's current map
    -- really matches the player's location. This keeps quest/wayshrine scans
    -- from polluting the minimap cache while still letting the minimap follow
    -- cities, homes, delves, interiors, and zone maps automatically.
    local hiddenCaptureActive = self.allowGameplayNativeCapture == true
        or self.hiddenPinPrimeInProgress == true
        or self.hiddenNativeMapPumpInProgress == true
    if not self:IsWorldMapShowing() and not hiddenCaptureActive then return end
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end

    local mapId = 0
    if type(GetCurrentMapId) == "function" then mapId = tonumber(safe(GetCurrentMapId, 0)) or 0 end
    if mapId <= 0 then return end

    local texture = type(textureOverride) == "string" and textureOverride or nil
    if type(texture) ~= "string" or texture == "" then
        texture = self:GetNativePvEMapPinTexture(nil, pinType)
    end
    if (type(texture) ~= "string" or texture == "") and ZO_MapPin and type(ZO_MapPin.PIN_DATA) == "table" then
        local def = ZO_MapPin.PIN_DATA[pinType]
        local tex = type(def) == "table" and def.texture or nil
        if type(tex) == "function" then
            local attempts = {
                function() return tex(pinTag) end,
                function() return tex(pinType, pinTag) end,
                function() return tex(pinType) end,
            }
            for i=1,#attempts do
                local ok, value = pcall(attempts[i])
                if ok and type(value) == "string" and value ~= "" then texture=value; break end
            end
        elseif type(tex) == "string" then texture=tex end
    end
    if type(texture) ~= "string" or texture == "" or easNativeTownPinIsDynamic(texture) then return end

    local size = tonumber(sizeOverride)
    if size then size = clamp(size, 12, 64) end

    local ux, uy = easUniversalPointForMap(mapId, x, y)
    local zoneIndex, zoneId, zoneName = 0, 0, ""
    if type(GetCurrentMapZoneIndex) == "function" then
        local ok, value = pcall(GetCurrentMapZoneIndex)
        if ok then zoneIndex = tonumber(value) or 0 end
    end
    if zoneIndex > 0 and type(GetZoneId) == "function" then
        local ok, value = pcall(GetZoneId, zoneIndex)
        if ok then zoneId = tonumber(value) or 0 end
    end
    if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then
        local ok, value = pcall(GetZoneNameByIndex, zoneIndex)
        if ok and type(value) == "string" then zoneName = clean(value, "") end
    end

    EPC.saved.miniMapNativeTownPins = EPC.saved.miniMapNativeTownPins or {}
    local key = tostring(mapId)
    local scratch = self.nativeCaptureScratch
    local list
    if scratch and tonumber(scratch.mapId) == mapId and type(scratch.list) == "table" then
        list = scratch.list
    else
        list = EPC.saved.miniMapNativeTownPins[key]
        if type(list) ~= "table" then list = {}; EPC.saved.miniMapNativeTownPins[key] = list end
    end

    local name = ""
    if type(pinTag) == "table" then
        local zi = tonumber(pinTag.zoneIndex or pinTag.zone or 0) or 0
        local pi = tonumber(pinTag.poiIndex or pinTag.poi or 0) or 0
        if zi > 0 and pi > 0 and type(GetPOIInfo) == "function" then
            local n = select(1, safe(GetPOIInfo, "", zi, pi))
            if type(n) == "string" and n ~= "" then name = clean(n, "") end
        elseif type(pinTag.name) == "string" and pinTag.name ~= "" then
            name = clean(pinTag.name, "")
        end
    end

    local rx, ry = math.floor(x * 100000 + 0.5), math.floor(y * 100000 + 0.5)
    -- Texture is part of the identity because ESO can legitimately stack two
    -- different native icons at the same normalized location.
    local isQuestPin = easLooksLikeNativeQuestPin(texture, pinTag, pinType)
    local id = tostring(pinType or "") .. ":" .. tostring(rx) .. ":" .. tostring(ry) .. ":" .. tostring(texture)
    for i=1,#list do
        if list[i] and list[i].id == id then
            list[i].texture, list[i].name, list[i].x, list[i].y = texture, name, x, y
            list[i].size = size or list[i].size
            list[i].isQuest = isQuestPin == true
            list[i].sourceMapId, list[i].ux, list[i].uy = mapId, ux, uy
            list[i].zoneIndex, list[i].zoneId, list[i].zoneName = zoneIndex, zoneId, zoneName
            if not scratch then
                self.staticPinsDirty = true
                self.nativeTownPinsChanged = true
            end
            return
        end
    end
    list[#list+1] = {
        id=id, pinType=pinType, texture=texture, name=name, x=x, y=y, size=size,
        isQuest=isQuestPin == true, sourceMapId=mapId, ux=ux, uy=uy,
        zoneIndex=zoneIndex, zoneId=zoneId, zoneName=zoneName,
    }
    while #list > 320 do table.remove(list, 1) end
    if not scratch then
        self.staticPinsDirty = true
        self.nativeTownPinsChanged = true
    end
end

function M:HookNativeTownPins()
    if self.nativeTownPinHooked then return end
    local owner = self

    -- Capture the fully initialized native pin whenever possible.  The old
    -- CreatePin pre-hook ran before ESO finished SetData(), which meant some
    -- city/service pins were cached with incomplete texture/tag information.
    -- Post-hooking ZO_MapPin:SetData gives us the final normalized position and
    -- the exact texture ESO chose for that pin.
    if ZO_MapPin and type(ZO_MapPin.SetData) == "function" and type(ZO_PostHook) == "function" then
        ZO_PostHook(ZO_MapPin, "SetData", function(pin, pinType, pinTag)
            local hiddenCaptureActive = owner.hiddenPinPrimeInProgress == true
                or owner.hiddenNativeMapPumpInProgress == true
                or owner.allowGameplayNativeCapture == true
            if (not owner:IsWorldMapShowing() and not hiddenCaptureActive) or not pin then return end
            local x, y
            if type(pin.GetNormalizedPosition) == "function" then
                local ok, px, py = pcall(pin.GetNormalizedPosition, pin)
                if ok then x, y = tonumber(px), tonumber(py) end
            end
            if not x or not y then return end

            local texture, pinSize
            if type(pin.GetControl) == "function" then
                local ok, control = pcall(pin.GetControl, pin)
                if ok and control then
                    if type(control.GetDimensions) == "function" then
                        local okDim, width, height = pcall(control.GetDimensions, control)
                        if okDim then pinSize = math.max(tonumber(width) or 0, tonumber(height) or 0) end
                    end
                    if type(control.GetTextureFileName) == "function" then
                        local okTex, tex = pcall(control.GetTextureFileName, control)
                        if okTex and type(tex) == "string" and tex ~= "" then texture = tex end
                    end
                    if (not texture or texture == "") and type(control.GetNamedChild) == "function" then
                        local childNames = {"Icon", "Texture", "Pin", "MapPin"}
                        for i=1,#childNames do
                            local okChild, child = pcall(control.GetNamedChild, control, childNames[i])
                            if okChild and child and type(child.GetTextureFileName) == "function" then
                                local okTex, tex = pcall(child.GetTextureFileName, child)
                                if okTex and type(tex) == "string" and tex ~= "" then texture = tex; break end
                            end
                        end
                    end
                end
            end
            owner:CaptureNativeTownPin(pinType, pinTag, x, y, texture, pinSize)
        end)
    end

    -- Keep the manager hook as a compatibility fallback for clients where the
    -- pin class cannot be post-hooked. Duplicate entries are deduped by id.
    if type(ZO_WorldMap_GetPinManager) == "function" and type(ZO_PreHook) == "function" then
        local manager = ZO_WorldMap_GetPinManager()
        if manager and type(manager.CreatePin) == "function" then
            ZO_PreHook(manager, "CreatePin", function(_, pinType, pinTag, x, y)
                owner:CaptureNativeTownPin(pinType, pinTag, x, y)
                return false
            end)
        end
    end
    self.nativeTownPinHooked = true
end

function M:CaptureAllNativeMapPins(allowGameplayCapture)
    -- Snapshot ESO's CURRENT live pin manager as one atomic set. 0.29.33 may
    -- do this while the World Map is hidden, but only when the current mapId is
    -- verified as the player's real current map/sub-map. This gives the
    -- minimap a fresh pin set when crossing a city/home/interior boundary
    -- without anchoring it to a parent map.
    if not LMP then return false end

    local worldMapShowing = self:IsWorldMapShowing()
    local gameplayCapture = (not worldMapShowing) and allowGameplayCapture == true
    if not worldMapShowing and not gameplayCapture then return false end

    -- Always prefer ESO's active shared pin manager.  LibMapPins normally wraps
    -- this same manager, but some library/provider versions do not publish their
    -- manager reference until the full World Map has been shown once.
    local manager = nil
    if type(ZO_WorldMap_GetPinManager) == "function" then
        local okManager, activeManager = pcall(ZO_WorldMap_GetPinManager)
        if okManager then manager = activeManager end
    end
    if not manager then manager = LMP.pinManager end
    if not manager or type(manager.GetActiveObjects) ~= "function" then return false end

    local mapId = tonumber(safe(GetCurrentMapId, 0)) or 0
    if mapId <= 0 then return false end

    if gameplayCapture then
        -- Do not snapshot a map that some unrelated addon/quest scan has made
        -- current. Exact map-id equality with the Suite's verified render map is
        -- the authoritative guard here. DoesCurrentMapMatchMapForPlayerLocation()
        -- can legitimately report false for city/interior sub-maps selected by
        -- LibMapData, and that old second gate was discarding the very hidden
        -- snapshots we need until the user opened the native World Map.
        if mapId ~= (tonumber(self.mapId) or 0) then return false end
    end

    local ok, pins = pcall(manager.GetActiveObjects, manager)
    if not ok or type(pins) ~= "table" then return false end

    EPC.saved.miniMapNativeTownPins = EPC.saved.miniMapNativeTownPins or {}
    self.nativeCaptureScratch = { mapId = mapId, list = {} }
    self.allowGameplayNativeCapture = gameplayCapture

    for _, pin in pairs(pins) do
        if pin then
            local pinType, pinTag
            if type(pin.GetPinTypeAndTag) == "function" then
                local okType, a, b = pcall(pin.GetPinTypeAndTag, pin)
                if okType then pinType, pinTag = a, b end
            elseif type(pin.GetPinType) == "function" then
                local okType, a = pcall(pin.GetPinType, pin)
                if okType then pinType = a end
            end

            local x, y
            if type(pin.GetNormalizedPosition) == "function" then
                local okPos, px, py = pcall(pin.GetNormalizedPosition, pin)
                if okPos then x, y = tonumber(px), tonumber(py) end
            end

            local texture, pinSize
            if type(pin.GetControl) == "function" then
                local okControl, control = pcall(pin.GetControl, pin)
                if okControl and control then
                    if type(control.GetDimensions) == "function" then
                        local okDim, width, height = pcall(control.GetDimensions, control)
                        if okDim then pinSize = math.max(tonumber(width) or 0, tonumber(height) or 0) end
                    end
                    local candidates = { control }
                    if type(GetControl) == "function" then
                        local okBg, bg = pcall(GetControl, control, "Background")
                        if okBg and bg then candidates[#candidates + 1] = bg end
                    end
                    if type(control.GetNamedChild) == "function" then
                        for _, childName in ipairs({"Background", "Icon", "Texture", "Pin", "MapPin"}) do
                            local okChild, child = pcall(control.GetNamedChild, control, childName)
                            if okChild and child then candidates[#candidates + 1] = child end
                        end
                    end
                    for i = 1, #candidates do
                        local c = candidates[i]
                        if c and type(c.GetTextureFileName) == "function" then
                            local okTex, tex = pcall(c.GetTextureFileName, c)
                            if okTex and type(tex) == "string" and tex ~= "" then
                                texture = tex
                                break
                            end
                        end
                    end
                end
            end

            if x and y then
                self:CaptureNativeTownPin(pinType, pinTag, x, y, texture, pinSize)
            end
        end
    end

    local snapshot = self.nativeCaptureScratch and self.nativeCaptureScratch.list or {}
    self.nativeCaptureScratch = nil
    self.allowGameplayNativeCapture = false

    -- A hidden pin manager can briefly be empty while ESO is rebuilding a new
    -- local map. Never replace a good snapshot with that transient empty set;
    -- the scheduled retries below will capture again a few frames later.
    if gameplayCapture and #snapshot == 0 then return false end

    EPC.saved.miniMapNativeTownPins[tostring(mapId)] = snapshot
    self.lastNativeSnapshotMapId = mapId
    self.nativeTownPinsChanged = true
    self.staticPinsDirty = true
    return true
end

local function easUniversalMapRect(mapId)
    mapId = tonumber(mapId) or 0
    if mapId <= 0 or type(GetUniversallyNormalizedMapInfo) ~= "function" then return nil end
    local ok, ox, oy, w, h = pcall(GetUniversallyNormalizedMapInfo, mapId)
    ox, oy, w, h = tonumber(ox), tonumber(oy), tonumber(w), tonumber(h)
    if not ok or not ox or not oy or not w or not h or w <= 0 or h <= 0 then return nil end
    return { x=ox, y=oy, w=w, h=h, area=w*h }
end

local function easNativeTownPinAllowedOnMap(sourceMapId, currentMapId)
    sourceMapId = tonumber(sourceMapId) or 0
    currentMapId = tonumber(currentMapId) or 0
    if sourceMapId <= 0 or currentMapId <= 0 then return false end
    if sourceMapId == currentMapId then return true end

    local source = easUniversalMapRect(sourceMapId)
    local current = easUniversalMapRect(currentMapId)
    if not source or not current then
        -- Without map bounds, never project town-detail icons across map IDs.
        -- This avoids leaking city services onto the surrounding zone map.
        return false
    end

    -- Town/service detail may be captured from a parent map while ESO is
    -- building a town/sub-map. Allow projection only when the minimap is at
    -- least as detailed (same size or smaller) than the source map. Never
    -- project a smaller town map outward onto a larger overland/zone map.
    local tolerance = 1.02
    if current.area > (source.area * tolerance) then return false end

    -- The current map must also overlap the source map in universal space.
    local sx2, sy2 = source.x + source.w, source.y + source.h
    local cx2, cy2 = current.x + current.w, current.y + current.h
    local overlaps = not (cx2 < source.x or current.x > sx2 or cy2 < source.y or current.y > sy2)
    return overlaps
end

function M:AddCapturedNativeTownPins()
    -- Exact native mirror: use ONLY the snapshot from the exact same mapId and
    -- reuse ESO's normalized coordinates directly. Cross-map projection was the
    -- source of shifted icons in interiors/town submaps and is intentionally not
    -- used for this mirror layer.
    self.nativeMirrorData = {}
    self.useExactNativeStaticMirror = false
    if not EPC.saved or type(EPC.saved.miniMapNativeTownPins) ~= "table" then return false end
    local currentMapId = tonumber(self.mapId) or 0
    if currentMapId <= 0 then return false end

    local list = EPC.saved.miniMapNativeTownPins[tostring(currentMapId)]
    if type(list) ~= "table" then return false end

    local seen = {}
    for i=1,#list do
        local row = list[i]
        if type(row) == "table" and type(row.texture) == "string" and row.texture ~= "" then
            local x, y = tonumber(row.x), tonumber(row.y)
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and not easNativeTownPinIsDynamic(row.texture) then
                local key = tostring(row.id or (tostring(row.pinType or "") .. ":" .. tostring(math.floor(x*100000+0.5)) .. ":" .. tostring(math.floor(y*100000+0.5)) .. ":" .. tostring(row.texture)))
                if not seen[key] then
                    seen[key] = true
                    self.nativeMirrorData[#self.nativeMirrorData + 1] = {
                        x=x, y=y, texture=row.texture, pinType=row.pinType,
                        isQuest=(row.isQuest == true) or easLooksLikeNativeQuestPin(row.texture, nil, row.pinType),
                        -- Full World Map controls can be 36-48+ UI units.  Reusing
                        -- those dimensions made the newly live-refreshed city
                        -- icons dominate the minimap.  Preserve relative sizing
                        -- but cap the minimap base footprint before user scaling.
                        name=clean(row.name, ""), size=clamp(tonumber(row.size) or 22, 12, 28),
                    }
                end
            end
        end
    end

    self.useExactNativeStaticMirror = #self.nativeMirrorData > 0
    return self.useExactNativeStaticMirror
end

-- Native World Map pins are supplemental only. Live ESO POI/wayshrine APIs are
-- always refreshed in gameplay, and the minimap now actively syncs the hidden
-- current player map so opening the full map is never required to
-- keep the minimap current. Remove native snapshot entries that are already
-- represented by a live pin to avoid double icons when a cached snapshot exists.
function M:FilterNativeMirrorDuplicates()
    if type(self.nativeMirrorData) ~= "table" or #self.nativeMirrorData == 0 then
        self.useExactNativeStaticMirror = false
        return
    end

    local live = {}
    local function addRows(rows)
        for i = 1, #(rows or {}) do
            local d = rows[i]
            if d and tonumber(d.x) and tonumber(d.y) then
                live[#live + 1] = {
                    x = tonumber(d.x), y = tonumber(d.y),
                    texture = string.lower(tostring(d.icon or d.texture or "")),
                }
            end
        end
    end
    addRows(self.shrineData)
    addRows(self.poiData)
    addRows(self.merchantData)
    addRows(self.serviceData)

    local filtered = {}
    for i = 1, #self.nativeMirrorData do
        local d = self.nativeMirrorData[i]
        local duplicate = false
        local dx0, dy0 = tonumber(d.x), tonumber(d.y)
        local texture = string.lower(tostring(d.texture or ""))
        if dx0 and dy0 then
            for j = 1, #live do
                local row = live[j]
                local dx, dy = dx0 - row.x, dy0 - row.y
                local dist2 = (dx * dx) + (dy * dy)
                -- Exact/near-exact coordinate matches are duplicates. Slightly
                -- wider matching is allowed only when ESO chose the same art.
                if dist2 <= 0.00000009
                    or (texture ~= "" and texture == row.texture and dist2 <= 0.00000025) then
                    duplicate = true
                    break
                end
            end
        end
        if not duplicate then filtered[#filtered + 1] = d end
    end

    self.nativeMirrorData = filtered
    self.useExactNativeStaticMirror = #filtered > 0
end

function M:EnsureNativeMirrorPins(count)
    self.nativeMirrorPins = self.nativeMirrorPins or {}
    for i = #self.nativeMirrorPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_NativeMirror_" .. tostring(i), 24, POI_FALLBACK_TEXTURE, COLORS.white, true)
        pin:SetDrawLevel(84)
        self.nativeMirrorPins[i] = pin
    end
end

local function easLooksLikeStationServiceTexture(texture)
    local t = string.lower(tostring(texture or ""))
    return string.find(t, "craft", 1, true) ~= nil
        or string.find(t, "service", 1, true) ~= nil
        or string.find(t, "blacksmith", 1, true) ~= nil
        or string.find(t, "cloth", 1, true) ~= nil
        or string.find(t, "woodwork", 1, true) ~= nil
        or string.find(t, "jewelry", 1, true) ~= nil
        or string.find(t, "alchemy", 1, true) ~= nil
        or string.find(t, "enchant", 1, true) ~= nil
        or string.find(t, "provision", 1, true) ~= nil
        or string.find(t, "transmute", 1, true) ~= nil
        or string.find(t, "outfit", 1, true) ~= nil
end

function M:RenderNativeMirrorPins()
    local rawData = self.nativeMirrorData or {}
    if self.useExactNativeStaticMirror ~= true or #rawData == 0 then
        self.lastNativeMirrorUsed029318 = 0
        for i=1,#(self.nativeMirrorPins or {}) do self.nativeMirrorPins[i]:SetHidden(true) end
        return
    end

    -- v0.29.439: Build a cheap render-order view with quest/objective pins first.
    -- This guarantees quests remain visible in cities where the native mirror can
    -- contain far more service/crafting/POI pins than the 48-control FPS budget.
    local data = {}
    local showQuest = self:LayerEnabled("quest")
    for i=1,#rawData do
        local d = rawData[i]
        if d and d.isQuest == true and showQuest then data[#data + 1] = d end
    end
    for i=1,#rawData do
        local d = rawData[i]
        if d and d.isQuest ~= true then data[#data + 1] = d end
    end

    local renderCount = math.min(#data, self.roamingVisualBudget029315 == true and ROAMING_NATIVE_CAP_029315 or NATIVE_MIRROR_RENDER_CAP_029314)
    self:EnsureNativeMirrorPins(renderCount)
    local used = 0
    local stationClusters = {}
    local fullW = math.max(1, tonumber(self.fullMapWidth) or tonumber(self.size) or 300)
    local stationNear = 7 / fullW
    local stationNear2 = stationNear * stationNear
    local stationOffset = 9 / fullW
    for i=1,renderCount do
        local d = data[i]
        if d and d.x and d.y and type(d.texture) == "string" and d.texture ~= "" then
            used = used + 1
            local pin = self.nativeMirrorPins[used]
            local size = clamp(tonumber(d.size) or 22, 12, 28)
            pin:SetDimensions(size, size)
            pin:SetTexture(d.texture)
            if type(pin.SetTextureCoords) == "function" then pin:SetTextureCoords(0, 1, 0, 1) end
            if type(pin.SetBlendMode) == "function" then pin:SetBlendMode(TEX_BLEND_MODE_ALPHA) end
            pin:SetColor(1, 1, 1, 1)

            local drawX, drawY = d.x, d.y
            -- ESO/provider snapshots can legitimately contain several service/crafting
            -- pins at virtually the same coordinate. On a small minimap they become
            -- an unreadable stack. Keep every station icon, but fan only the visual
            -- controls a few pixels around the shared point; the stored map data stays exact.
            if easLooksLikeStationServiceTexture(d.texture) then
                local cluster = nil
                for c = 1, #stationClusters do
                    local row = stationClusters[c]
                    local dx, dy = d.x - row.x, d.y - row.y
                    if (dx * dx + dy * dy) <= stationNear2 then cluster = row; break end
                end
                if cluster then
                    cluster.count = cluster.count + 1
                    local slot = cluster.count - 1
                    local angles = {0, math.pi * 0.5, math.pi, math.pi * 1.5, math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75}
                    local angle = angles[((slot - 1) % #angles) + 1]
                    local ring = 1 + math.floor((slot - 1) / #angles)
                    drawX = clamp(d.x + math.cos(angle) * stationOffset * ring, 0, 1)
                    drawY = clamp(d.y + math.sin(angle) * stationOffset * ring, 0, 1)
                else
                    stationClusters[#stationClusters + 1] = { x=d.x, y=d.y, count=1 }
                end
            end
            self:PlacePin(pin, drawX, drawY, size, false)
        end
    end
    self.lastNativeMirrorUsed029318 = used
    for i=used+1,#self.nativeMirrorPins do self.nativeMirrorPins[i]:SetHidden(true) end
end

function M:ClearStaticPinsForMapTransition()
    -- Immediately remove the previous area's static data before the new map is
    -- built. This prevents a city/home/delve transition from showing stale
    -- icons for even a fraction of a second on the new local map.
    self.nativeMirrorData = {}
    self.useExactNativeStaticMirror = false
    self.shrineData = {}
    self.skyshardData = {}
    self.poiData = {}
    self.merchantData = {}
    self.serviceData = {}
    self.pvpKeepData = {}
    self.pvpTravelLinks = {}
    self.nearestUndiscoveredPOI = nil

    local pools = {
        self.nativeMirrorPins, self.shrinePins, self.skyshardPins, self.poiPins,
        self.merchantPins, self.servicePins, self.pvpKeepPins,
        self.pvpScrollPins,
    }
    for _, pool in ipairs(pools) do
        if type(pool) == "table" then
            for i = 1, #pool do
                if pool[i] and type(pool[i].SetHidden) == "function" then pool[i]:SetHidden(true) end
            end
        end
    end
    self:HideMapObjectLabels()
end

function M:ScheduleLiveNativeMirrorRefresh(mapId)
    mapId = tonumber(mapId) or 0
    if mapId <= 0 or type(zo_callLater) ~= "function" then return end
    self.nativeRefreshToken = (tonumber(self.nativeRefreshToken) or 0) + 1
    local token = self.nativeRefreshToken

    -- v0.29.316: opening the full World Map must never be required to populate
    -- minimap icons. Normal transition/event code still owns the first hidden
    -- provider prime. These delayed passes mainly snapshot providers that finish
    -- registering a little later. Only if the current map never received a prime
    -- (or the live manager is still empty after settling) do we perform ONE
    -- guarded recovery prime. This keeps the 0.29.315 FPS gains without making M
    -- a prerequisite for POI/service/custom-provider icons.
    local recoveryPrimeUsed = false
    local delays = { 450, 1100, 2600 }
    for i = 1, #delays do
        local pass = i
        zo_callLater(function()
            if token ~= self.nativeRefreshToken then return end
            if self:IsWorldMapShowing() then return end
            if (tonumber(self.mapId) or 0) ~= mapId then return end

            local captured = self:CaptureAllNativeMapPins(true)
            if captured then
                self.staticPinsDirty = true
            end

            local savedList = EPC.saved and EPC.saved.miniMapNativeTownPins
                and EPC.saved.miniMapNativeTownPins[tostring(mapId)]
            local hasSnapshot = type(savedList) == "table" and #savedList > 0
            local primedThisMap = tonumber(self.lastHiddenPinPrimeMapId) == mapId

            -- First delayed pass only recovers a transition whose normal prime
            -- never happened. The final pass may recover an empty provider set,
            -- but at most once for this schedule token.
            local needsRecoveryPrime = (pass == 1 and not primedThisMap)
                or (pass == #delays and not hasSnapshot)
            if needsRecoveryPrime and not recoveryPrimeUsed then
                recoveryPrimeUsed = true
                if self:PrimeHiddenWorldMapPins("autopopulate", true) then
                    self.staticPinsDirty = true
                    if self:CaptureAllNativeMapPins(true) then
                        self.staticPinsDirty = true
                    end
                end
            end
        end, delays[i])
    end
end

function M:GetPvPAllianceColor(alliance)
    alliance = tonumber(alliance) or 0
    if type(GetAllianceColor) == "function" and alliance > 0 then
        local r, g, b = safe(GetAllianceColor, nil, alliance)
        if tonumber(r) and tonumber(g) and tonumber(b) then return {r, g, b, 1} end
    end
    if alliance == ALLIANCE_ALDMERI_DOMINION then return {0.95, 0.78, 0.16, 1} end
    if alliance == ALLIANCE_DAGGERFALL_COVENANT then return {0.22, 0.50, 0.90, 1} end
    if alliance == ALLIANCE_EBONHEART_PACT then return {0.88, 0.24, 0.20, 1} end
    return COLORS.white
end

function M:EnsurePvPPins(count)
    self.pvpPins = self.pvpPins or {}
    for i = #self.pvpPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_PvPObjective_" .. tostring(i), 26, POI_FALLBACK_TEXTURE, COLORS.white, true)
        pin:SetDrawLevel(88)
        self.pvpPins[i] = pin
    end
end

function M:HidePvPPins()
    for i = 1, #(self.pvpPins or {}) do self.pvpPins[i]:SetHidden(true) end
end

function M:EnsurePvPTransitLines(count)
    self.pvpTransitLines = self.pvpTransitLines or {}
    for i = #self.pvpTransitLines + 1, count do
        local line = wm:CreateControl("EPC_MiniMap_PvPTransit_" .. tostring(i), self.viewport, CT_LINE)
        line:SetThickness(3)
        line:SetColor(1, 1, 1, 0.88)
        line:SetDrawLayer(DL_OVERLAY)
        line:SetDrawLevel(82)
        line:SetHidden(true)
        self.pvpTransitLines[i] = line
    end
    return self.pvpTransitLines
end

function M:HidePvPTransitLines()
    for i = 1, #(self.pvpTransitLines or {}) do self.pvpTransitLines[i]:SetHidden(true) end
end

function M:PlacePvPTransitLine(line, data)
    if not line or not data then return false end
    local x1, y1, in1 = self:MapToScreen(data.startX, data.startY)
    local x2, y2, in2 = self:MapToScreen(data.endX, data.endY)
    if x1 == nil or y1 == nil or x2 == nil or y2 == nil or (not in1 and not in2) then
        line:SetHidden(true)
        return false
    end

    -- A LineControl stretches between two anchors. Pick opposing corners based
    -- on slope so both positive- and negative-slope Cyrodiil links render.
    line:ClearAnchors()
    if (x2 - x1) * (y2 - y1) >= 0 then
        local leftX, leftY, rightX, rightY
        if x1 <= x2 then leftX, leftY, rightX, rightY = x1, y1, x2, y2
        else leftX, leftY, rightX, rightY = x2, y2, x1, y1 end
        if leftY <= rightY then
            line:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, leftX, leftY)
            line:SetAnchor(BOTTOMRIGHT, self.viewport, TOPLEFT, rightX, rightY)
        else
            line:SetAnchor(BOTTOMLEFT, self.viewport, TOPLEFT, leftX, leftY)
            line:SetAnchor(TOPRIGHT, self.viewport, TOPLEFT, rightX, rightY)
        end
    else
        local leftX, leftY, rightX, rightY
        if x1 <= x2 then leftX, leftY, rightX, rightY = x1, y1, x2, y2
        else leftX, leftY, rightX, rightY = x2, y2, x1, y1 end
        line:SetAnchor(BOTTOMLEFT, self.viewport, TOPLEFT, leftX, leftY)
        line:SetAnchor(TOPRIGHT, self.viewport, TOPLEFT, rightX, rightY)
    end

    local color = data.color or COLORS.white
    local alpha = data.active == false and 0.34 or 0.88
    line:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, alpha)
    line:SetThickness(data.active == false and 2 or 3)
    line:SetHidden(false)
    return true
end

function M:RenderPvPTransitLines()
    local data = self.pvpTravelLinks or {}
    if safe(IsPlayerInAvAWorld, false) ~= true or #data == 0 then
        self:HidePvPTransitLines()
        return
    end
    local pool = self:EnsurePvPTransitLines(#data)
    local used = 0
    for i = 1, #data do
        local d = data[i]
        if d and d.startX and d.startY and d.endX and d.endY then
            used = used + 1
            self:PlacePvPTransitLine(pool[used], d)
        end
    end
    for i = used + 1, #pool do pool[i]:SetHidden(true) end
end

local RenderPvPPinsImplArch

function M:RenderPvPPins(...)

    return RenderPvPPinsImplArch(self, ...)

end

RenderPvPPinsImplArch = function(self)
    local data = self.pvpKeepData or {}
    if safe(IsPlayerInAvAWorld, false) ~= true or #data == 0 then self:HidePvPPins(); return end
    self:EnsurePvPPins(#data)
    local used = 0
    for i = 1, #data do
        local d = data[i]
        if d and d.x and d.y then
            used = used + 1
            local pin = self.pvpPins[used]
            local texture = d.texture
            if type(texture) == "string" and texture ~= "" then
                pin:SetTexture(texture)
                -- Native ESO PvP pin textures already encode ownership/state.
                pin:SetColor(1, 1, 1, 1)
            else
                pin:SetTexture(POI_FALLBACK_TEXTURE)
                pin:SetColor(unpack(d.color or COLORS.white))
            end
            local size = tonumber(d.size) or 26
            pin:SetDimensions(size, size)
            self:PlacePin(pin, d.x, d.y, size, false)
        end
    end
    for i = used + 1, #self.pvpPins do self.pvpPins[i]:SetHidden(true) end
end

function M:EnsureGroupPins(count)
    self.groupPins = self.groupPins or {}
    for i = #self.groupPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_Group_" .. tostring(i), 16, GROUP_TEXTURE, COLORS.cyan)
        if type(pin.SetTextureCoords) == "function" then pin:SetTextureCoords(0, 1, 0, 1) end
        if type(pin.SetBlendMode) == "function" then pin:SetBlendMode(TEX_BLEND_MODE_ALPHA) end
        pin:SetDrawLevel(75)
        self.groupPins[i] = pin
    end
end

function M:EnsureShrinePins(count)
    self.shrinePins = self.shrinePins or {}
    for i = #self.shrinePins + 1, count do
        self.shrinePins[i] = self:CreatePin("EPC_MiniMap_Shrine_" .. tostring(i), 17, WAYPOINT_TEXTURE, COLORS.gold, true)
    end
end

function M:EnsureSkyshardPins(count)
    self.skyshardPins = self.skyshardPins or {}
    for i = #self.skyshardPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_Skyshard_" .. tostring(i), 20, SUITE_SKYSHARD_TEXTURE_029443, COLORS.gold, true)
        pin:SetDrawLayer(DL_OVERLAY)
        pin:SetDrawLevel(89)
        self.skyshardPins[i] = pin
    end
end

function M:EnsurePOIPins(count)
    self.poiPins = self.poiPins or {}
    for i = #self.poiPins + 1, count do
        self.poiPins[i] = self:CreatePin("EPC_MiniMap_POI_" .. tostring(i), 17, POI_FALLBACK_TEXTURE, COLORS.white, true)
    end
end

function M:EnsureMerchantPins(count)
    self.merchantPins = self.merchantPins or {}
    for i = #self.merchantPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_Merchant_" .. tostring(i), 22, POI_FALLBACK_TEXTURE, COLORS.gold, true)
        pin:SetDrawLayer(DL_OVERLAY)
        pin:SetDrawLevel(55)
        self.merchantPins[i] = pin
    end
end

function M:EnsureServicePins(count)
    self.servicePins = self.servicePins or {}
    self.serviceBackings = self.serviceBackings or {}
    for i = #self.servicePins + 1, count do
        -- A guaranteed-visible backing means a learned service can never vanish
        -- just because ESO rejects a service-specific texture path.
        local backing = self:CreatePin("EPC_MiniMap_ServiceBacking_" .. tostring(i), 30, POI_FALLBACK_TEXTURE, COLORS.gold, true)
        backing:SetDrawLayer(DL_OVERLAY)
        backing:SetDrawLevel(78)
        -- Backings are intentionally never rendered in the current minimap style.
        -- Keep them completely out of the moving static hierarchy.
        if self.staticPinDormantLayer029319 and type(backing.SetParent) == "function" then
            backing:SetParent(self.staticPinDormantLayer029319)
            backing.easMapParked029319 = true
        end
        self.serviceBackings[i] = backing

        local pin = self:CreatePin("EPC_MiniMap_Service_" .. tostring(i), 24, POI_FALLBACK_TEXTURE, COLORS.white, true)
        pin:SetDrawLayer(DL_OVERLAY)
        -- Above the player arrow (70) so the Stable icon is visible immediately
        -- while the player is still standing on top of the learned location.
        pin:SetDrawLevel(82)
        self.servicePins[i] = pin
    end
end

function M:EnsureTrailPins(count)
    self.trailPins = self.trailPins or {}
    for i = #self.trailPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_Trail_" .. tostring(i), 6, PLAYER_TEXTURE, COLORS.muted, true)
        pin:SetDrawLevel(8)
        self.trailPins[i] = pin
    end
end

function M:EnsureAntiquityPins(count)
    self.antiquityPins = self.antiquityPins or {}
    for i = #self.antiquityPins + 1, count do
        local texture = EPC.AntiquityAssistant and EPC.AntiquityAssistant:GetShovelTexture() or POI_FALLBACK_TEXTURE
        local pin = self:CreatePin("EPC_MiniMap_Antiquity_" .. tostring(i), 30, texture, COLORS.gold)
        pin:SetDrawLevel(93)
        self.antiquityPins[i] = pin
    end
end

function M:RenderAntiquityPins()
    local enabled = EPC.saved and EPC.saved.antiquityAssistantEnabled ~= false and EPC.saved.antiquityShowMiniMap ~= false
    local assistant = EPC.AntiquityAssistant
    if not enabled or not assistant or type(assistant.GetCurrentMapDigSites) ~= "function" then
        for _, pin in ipairs(self.antiquityPins or {}) do pin:SetHidden(true) end
        return
    end
    local sites = assistant:GetCurrentMapDigSites(false) or {}
    self:EnsureAntiquityPins(#sites)
    local pulse = 1.0 + (0.08 * ((math.sin(nowSeconds() * 4.5) + 1) * 0.5))
    for index, pin in ipairs(self.antiquityPins or {}) do
        local site = sites[index]
        if site then
            pin:SetTexture(assistant:GetShovelTexture())
            pin:SetDimensions(30, 30)
            pin:SetColor(1.00, 0.78, 0.24, 1.00)
            if type(pin.SetScale) == "function" then pin:SetScale(pulse) end
            self:PlacePin(pin, site.x, site.y, 30, true)
        else
            pin:SetHidden(true)
        end
    end
end

function M:EnsureTreasureLocatorPins(count)
    self.treasureLocatorPins = self.treasureLocatorPins or {}
    for i = #self.treasureLocatorPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_TreasureLocator_" .. tostring(i), 28, POI_FALLBACK_TEXTURE, COLORS.gold)
        pin:SetDrawLevel(92)
        -- The parent minimap only accepts mouse input while Suite interaction/HUD
        -- layout mode is active, so enabling these children does not steal normal
        -- camera input. Tooltip work runs only on actual mouse enter/exit.
        pin:SetMouseEnabled(true)
        pin:SetHandler("OnMouseEnter", function(control)
            local locator = EPC and EPC.TreasureLocator
            if locator and type(locator.ShowMiniMapTooltip029309) == "function" and control.easTreasureEntry029309 then
                locator:ShowMiniMapTooltip029309(control, control.easTreasureEntry029309)
            end
        end)
        pin:SetHandler("OnMouseExit", function()
            local locator = EPC and EPC.TreasureLocator
            if locator and type(locator.HideMiniMapTooltip029309) == "function" then locator:HideMiniMapTooltip029309() end
        end)
        self.treasureLocatorPins[i] = pin
    end
end

function M:RenderTreasureLocatorPins()
    local locator = EPC.TreasureLocator
    local enabled = EPC.saved and EPC.saved.treasureLocatorEnabled ~= false and EPC.saved.treasureLocatorShowMap ~= false
    if not enabled or not locator or type(locator.GetMiniMapPins) ~= "function" then
        for _, pin in ipairs(self.treasureLocatorPins or {}) do
            pin.easTreasureEntry029309 = nil
            pin:SetHidden(true)
        end
        return
    end
    local entries = locator:GetMiniMapPins(self.mapId) or {}
    self:EnsureTreasureLocatorPins(#entries)
    local size = math.max(18, math.min(40, tonumber(EPC.saved.treasureLocatorPinSize) or 32))
    for index, pin in ipairs(self.treasureLocatorPins or {}) do
        local entry = entries[index]
        if entry then
            pin.easTreasureEntry029309 = entry
            pin:SetTexture(entry.texture or POI_FALLBACK_TEXTURE)
            pin:SetDimensions(size, size)
            pin:SetColor(1, 1, 1, 1)
            local edgeGuide = locator.GetScope and locator:GetScope() ~= "ALL"
            self:PlacePin(pin, entry.x, entry.y, size, edgeGuide)
        else
            pin.easTreasureEntry029309 = nil
            pin:SetHidden(true)
        end
    end
end

function M:GetAdaptiveMapZoomMultiplier()
    local mapId = tonumber(self.mapId) or 0
    if mapId <= 0 or type(GetMapInfoById) ~= "function" then return 1.0 end

    -- Cache per gameplay map. City/local maps in ESO are commonly SUBZONE maps;
    -- dungeon and battleground maps are also physically tighter than overland
    -- zone maps. Use the map metadata rather than English place-name matching so
    -- this works in every client language.
    if self.zoomContextMapId == mapId and self.zoomContextMultiplier then
        return self.zoomContextMultiplier
    end

    local _, mapType, mapContentType = safe(GetMapInfoById, nil, mapId)
    local multiplier = 1.0
    local kind = "OVERLAND"

    if MAPTYPE_SUBZONE ~= nil and mapType == MAPTYPE_SUBZONE then
        multiplier = 1.28
        kind = "LOCAL"
    end

    if MAP_CONTENT_DUNGEON ~= nil and mapContentType == MAP_CONTENT_DUNGEON then
        multiplier = math.max(multiplier, 1.18)
        kind = "DUNGEON"
    elseif MAP_CONTENT_BATTLEGROUND ~= nil and mapContentType == MAP_CONTENT_BATTLEGROUND then
        multiplier = math.max(multiplier, 1.10)
        kind = "BATTLEGROUND"
    end

    self.zoomContextMapId = mapId
    self.zoomContextMultiplier = multiplier
    self.zoomContextKind = kind
    return multiplier
end

function M:GetEffectiveZoom()
    local zoom = clamp(EPC.saved and EPC.saved.miniMapZoom or 1.38, 0.70, 2.00)
    if not EPC.saved or EPC.saved.miniMapAdaptiveZoom == false or self.layoutMode then return zoom end

    -- Cities, settlements, interiors and other local/sub-zone maps get a closer
    -- automatic view. Riding still pulls the view back a little, while combat
    -- gets a modest detail boost without making the city view excessively large.
    zoom = zoom * self:GetAdaptiveMapZoomMultiplier()
    if safe(IsUnitInCombat, false, "player") == true then
        zoom = zoom * 1.08
    elseif safe(IsMounted, false) == true then
        zoom = zoom * 0.95
    end
    return clamp(zoom, 0.70, 2.00)
end

function M:IsInteractive()
    -- The suite interaction hotkey (often bound to Enter by users) enters ESO UI
    -- mode so the mouse is available. Keep the minimap usable in that mode without
    -- requiring the minimap to be unlocked/movable.
    return self.layoutMode == true or EPC.interactionMode == true
end

function M:AdjustZoom(delta)
    if not self:IsInteractive() or not EPC.saved then return end
    local zoom = clamp((tonumber(EPC.saved.miniMapZoom) or 1.38) + ((tonumber(delta) or 0) * 0.05), 0.70, 2.00)
    EPC.saved.miniMapZoom = zoom
    self:RebuildMap(true)
end

function M:BeginDrag(button)
    if not self.layoutMode or not self.frame then return end
    if MOUSE_BUTTON_INDEX_LEFT ~= nil and button ~= nil and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if self.dragging then return end
    self.dragging = true
    if type(self.frame.StartMoving) == "function" then self.frame:StartMoving() end
end

function M:EndDrag()
    if not self.frame then return end
    if type(self.frame.StopMovingOrResizing) == "function" then self.frame:StopMovingOrResizing() end
    self.dragging = false
    self:SavePosition()
end

function M:Create()
    self.frame = wm:CreateTopLevelWindow("EPC_MiniMap")
    -- Do not use ESO's built-in UI-safe-area clamp here. It blocks true edge and
    -- corner placement in HUD Layout Mode. SavePosition/AnchorFrame provide a
    -- small recovery-only bound so the minimap can never become irretrievable.
    self.frame:SetClampedToScreen(false)
    self.frame:SetDrawTier(DT_HIGH)
    self.frame:SetDrawLayer(DL_CONTROLS)
    self.frame:SetMovable(true)
    self.frame:SetMouseEnabled(false)

    self.background = makeBackdrop(self.frame, "EPC_MiniMap_Background")
    self.background:SetAnchorFill(self.frame)

    -- Reliable ESO-style square minimap. Use a guaranteed visible gold frame backdrop
    -- plus the addon artwork as an optional decorative overlay.
    self.viewport = wm:CreateControl("EPC_MiniMap_Viewport", self.frame, CT_CONTROL)
    self.viewport:SetDrawLayer(DL_BACKGROUND)
    self.viewport:SetDrawLevel(5)
    if type(self.viewport.SetAutoRectClipChildren) == "function" then self.viewport:SetAutoRectClipChildren(true) end

    self.tileContainer = wm:CreateControl("EPC_MiniMap_Tiles", self.viewport, CT_CONTROL)
    self.tileContainer:SetDrawLayer(DL_BACKGROUND)
    self.tileContainer:SetDrawLevel(1)
    self.tiles = {}

    -- v0.29.312 movement-performance layer. Static map pins live on a map-sized
    -- canvas that pans with the map tiles. This lets ESO move hundreds of icons
    -- with ONE parent-anchor update instead of the Suite clearing/re-anchoring
    -- every POI/wayshrine/native pin whenever the player runs.
    self.staticPinLayer = wm:CreateControl("EPC_MiniMap_StaticPins", self.viewport, CT_CONTROL)
    self.staticPinLayer:SetDrawLayer(DL_OVERLAY)
    self.staticPinLayer:SetDrawLevel(20)
    self.staticPinLayer:SetMouseEnabled(false)

    -- v0.29.319: off-screen static pins do not need to remain descendants of
    -- the control that pans every 33 ms. Park them here so ESO's layout walk for
    -- the moving layer scales with visible icons instead of every cached icon.
    self.staticPinDormantLayer029319 = wm:CreateControl("EPC_MiniMap_StaticPinsDormant029319", self.viewport, CT_CONTROL)
    self.staticPinDormantLayer029319:SetDimensions(1, 1)
    self.staticPinDormantLayer029319:SetMouseEnabled(false)
    self.staticPinDormantLayer029319:SetHidden(true)

    -- Modern map-surface treatment: a soft glass tint above the raw ESO tiles
    -- plus a subtle inner chrome ring so the minimap feels more like a modern
    -- navigation product without losing the ESO world-map art.
    self.mapGlass = makeBackdrop(self.viewport, "EPC_MiniMap_MapGlass")
    self.mapGlass:SetAnchorFill(self.viewport)
    self.mapGlass:SetDrawLayer(DL_OVERLAY)
    self.mapGlass:SetDrawLevel(6)
    self.mapGlass:SetMouseEnabled(false)

    self.mapChrome = makeBackdrop(self.viewport, "EPC_MiniMap_MapChrome")
    self.mapChrome:SetAnchorFill(self.viewport)
    self.mapChrome:SetDrawLayer(DL_OVERLAY)
    self.mapChrome:SetDrawLevel(7)
    self.mapChrome:SetMouseEnabled(false)

    self.mapNorthFade = makeBackdrop(self.viewport, "EPC_MiniMap_MapNorthFade")
    self.mapNorthFade:SetDrawLayer(DL_OVERLAY)
    self.mapNorthFade:SetDrawLevel(8)
    self.mapNorthFade:SetMouseEnabled(false)

    self.frameBorder = makeBackdrop(self.frame, "EPC_MiniMap_FrameBorder")
    self.frameBorder:SetAnchorFill(self.frame)
    self.frameBorder:SetDrawLayer(DL_OVERLAY)
    self.frameBorder:SetDrawLevel(50)
    self.frameBorder:SetMouseEnabled(false)

    -- Build the visible skin from native controls so it always renders, even if a
    -- custom DDS fails to load on a particular client install.
    local function skinPiece(name)
        local c = makeBackdrop(self.frame, name)
        c:SetDrawLayer(DL_OVERLAY)
        c:SetDrawLevel(58)
        c:SetMouseEnabled(false)
        return c
    end
    self.skinTop = skinPiece("EPC_MiniMap_SkinTop")
    self.skinBottom = skinPiece("EPC_MiniMap_SkinBottom")
    self.skinLeft = skinPiece("EPC_MiniMap_SkinLeft")
    self.skinRight = skinPiece("EPC_MiniMap_SkinRight")
    self.skinTL = skinPiece("EPC_MiniMap_SkinTL")
    self.skinTR = skinPiece("EPC_MiniMap_SkinTR")
    self.skinBL = skinPiece("EPC_MiniMap_SkinBL")
    self.skinBR = skinPiece("EPC_MiniMap_SkinBR")
    self.skinTopGem = skinPiece("EPC_MiniMap_SkinTopGem")

    self.esoFrame = wm:CreateControl("EPC_MiniMap_ESOFrame", self.frame, CT_TEXTURE)
    self.esoFrame:SetAnchorFill(self.frame)
    self.esoFrame:SetTexture(EPC_SQUARE_FRAME_TEXTURE)
    self.esoFrame:SetDrawLayer(DL_OVERLAY)
    self.esoFrame:SetDrawLevel(60)
    self.esoFrame:SetMouseEnabled(false)
    self.esoFrame:SetHidden(true)

    self.esoMask = wm:CreateControl("EPC_MiniMap_ESOMask", self.frame, CT_TEXTURE)
    self.esoMask:SetAnchorFill(self.frame)
    self.esoMask:SetDrawLayer(DL_OVERLAY)
    self.esoMask:SetDrawLevel(59)
    self.esoMask:SetMouseEnabled(false)
    self.esoMask:SetHidden(true)

    self.modeLabel = makeLabel(self.frame, "EPC_MiniMap_Mode", "$(BOLD_FONT)|11|soft-shadow-thick", COLORS.gold, TEXT_ALIGN_LEFT)
    self.modeLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 15, 10)
    self.modeLabel:SetDimensions(72, 20)
    self.modeLabel:SetDrawLayer(DL_OVERLAY)
    self.modeLabel:SetDrawLevel(55)
    self.modeLabel:SetHidden(true)

    self.zoneLabel = makeLabel(self.frame, "EPC_MiniMap_Zone", "$(BOLD_FONT)|14|soft-shadow-thick", COLORS.white, TEXT_ALIGN_CENTER)
    self.zoneLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 76, 10)
    self.zoneLabel:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -56, 10)
    self.zoneLabel:SetHeight(20)
    self.zoneLabel:SetDrawLayer(DL_OVERLAY)
    self.zoneLabel:SetDrawLevel(55)
    self.zoneLabel:SetHidden(true)

    self.coordsLabel = makeLabel(self.frame, "EPC_MiniMap_Coords", "$(BOLD_FONT)|11|soft-shadow-thin", COLORS.muted, TEXT_ALIGN_RIGHT)
    self.coordsLabel:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -14, 10)
    self.coordsLabel:SetDimensions(58, 20)
    self.coordsLabel:SetDrawLayer(DL_OVERLAY)
    self.coordsLabel:SetDrawLevel(55)
    self.coordsLabel:SetHidden(true)

    local function cardinal(name, text, point, relativePoint, x, y)
        local label = makeLabel(self.frame, name, "$(BOLD_FONT)|12|soft-shadow-thick", text == "N" and COLORS.gold or COLORS.muted, TEXT_ALIGN_CENTER)
        label:SetText(text)
        label:SetDimensions(18, 18)
        label:SetAnchor(point, self.frame, relativePoint, x, y)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(55)
        return label
    end
    self.northLabel = cardinal("EPC_MiniMap_North", "N", TOP, TOP, 0, 34)
    self.eastLabel = cardinal("EPC_MiniMap_East", "E", RIGHT, RIGHT, -12, 0)
    self.southLabel = cardinal("EPC_MiniMap_South", "S", BOTTOM, BOTTOM, 0, -34)
    self.westLabel = cardinal("EPC_MiniMap_West", "W", LEFT, LEFT, 12, 0)
    self.northLabel:SetHidden(true)
    self.eastLabel:SetHidden(true)
    self.southLabel:SetHidden(true)
    self.westLabel:SetHidden(true)

    self.contextLabel = makeLabel(self.frame, "EPC_MiniMap_Context", "$(BOLD_FONT)|11|soft-shadow-thin", COLORS.white, TEXT_ALIGN_CENTER)
    self.contextLabel:SetAnchor(BOTTOMLEFT, self.frame, BOTTOMLEFT, 18, -10)
    self.contextLabel:SetAnchor(BOTTOMRIGHT, self.frame, BOTTOMRIGHT, -18, -10)
    self.contextLabel:SetHeight(18)
    self.contextLabel:SetDrawLayer(DL_OVERLAY)
    self.contextLabel:SetDrawLevel(55)
    self.contextLabel:SetHidden(true)

    self.moveHint = makeLabel(self.frame, "EPC_MiniMap_MoveHint", "$(BOLD_FONT)|12|soft-shadow-thick", COLORS.gold, TEXT_ALIGN_CENTER)
    self.moveHint:SetText("DRAG MINI MAP  |  WHEEL = ZOOM  |  INTERACT = LOCK")
    self.moveHint:SetAnchor(BOTTOMLEFT, self.frame, BOTTOMLEFT, 12, -10)
    self.moveHint:SetAnchor(BOTTOMRIGHT, self.frame, BOTTOMRIGHT, -12, -10)
    self.moveHint:SetHeight(22)
    self.moveHint:SetDrawLayer(DL_OVERLAY)
    self.moveHint:SetDrawLevel(70)
    self.moveHint:SetHidden(true)

    self.statusLabel = makeLabel(self.frame, "EPC_MiniMap_Status", "$(BOLD_FONT)|14|soft-shadow-thick", COLORS.muted, TEXT_ALIGN_CENTER)
    self.statusLabel:SetAnchor(CENTER, self.frame, CENTER, 0, 0)
    self.statusLabel:SetDimensions(220, 44)
    self.statusLabel:SetDrawLayer(DL_OVERLAY)
    self.statusLabel:SetDrawLevel(60)
    self.statusLabel:SetHidden(true)

    self.playerGlow = self:CreatePin("EPC_MiniMap_PlayerGlow", self:GetPlayerGlowSize(), PLAYER_TEXTURE, COLORS.cyan)
    self.playerGlow:SetHidden(false)
    self.playerGlow:SetAnchor(CENTER, self.viewport, CENTER, 0, 0)
    self.playerGlow:SetDrawLevel(66)
    self.playerGlow:SetAlpha(0.18)

    self.playerPin = self:CreatePin("EPC_MiniMap_Player", self:GetPlayerPinSize(), PLAYER_TEXTURE, COLORS.white)
    self.playerPin:SetHidden(false)
    self.playerPin:SetAnchor(CENTER, self.viewport, CENTER, 0, 0)
    self.playerPin:SetDrawLevel(70)

    self.waypointPin = self:CreatePin("EPC_MiniMap_Waypoint", 24, WAYPOINT_TEXTURE, {0.24, 0.56, 0.97, 1})
    -- v0.29.441: Use the same gold skyshard-style icon language as the Suite's
    -- uncollected skyshard markers so tracked quests stand out immediately.
    self.questPin = self:CreatePin("EPC_MiniMap_Quest", 34, QUEST_SKYSHARD_TEXTURE, {1.00, 0.82, 0.20, 1})
    self.questPin:SetDrawLevel(94)
    self.questBadge029440 = nil
    self.rallyPin = self:CreatePin("EPC_MiniMap_Rally", 22, WAYPOINT_TEXTURE, {0.21, 0.78, 0.52, 1})
    self.companionPin = self:CreatePin("EPC_MiniMap_Companion", 18, COMPANION_TEXTURE, COLORS.white)

    self.frame:SetHandler("OnMouseDown", function(_, button) self:BeginDrag(button) end)
    self.frame:SetHandler("OnMouseUp", function() if self.layoutMode then self:EndDrag() end end)
    self.frame:SetHandler("OnMouseWheel", function(_, delta) self:AdjustZoom(delta) end)
    self.frame:SetHandler("OnMoveStop", function() self:SavePosition() end)

    self.dragSurface = wm:CreateControl("EPC_MiniMap_DragSurface", self.frame, CT_CONTROL)
    self.dragSurface:SetAnchorFill(self.frame)
    self.dragSurface:SetDrawLayer(DL_OVERLAY)
    self.dragSurface:SetDrawLevel(1000)
    self.dragSurface:SetMouseEnabled(false)
    self.dragSurface:SetHidden(true)
    if type(self.dragSurface.RegisterForDrag) == "function" and MOUSE_BUTTON_INDEX_LEFT ~= nil then
        pcall(self.dragSurface.RegisterForDrag, self.dragSurface, MOUSE_BUTTON_INDEX_LEFT)
    end
    self.dragSurface:SetHandler("OnMouseDown", function(_, button) self:BeginDrag(button) end)
    self.dragSurface:SetHandler("OnDragStart", function(_, button) self:BeginDrag(button) end)
    self.dragSurface:SetHandler("OnMouseUp", function() if self.layoutMode then self:EndDrag() end end)
    self.dragSurface:SetHandler("OnDragStop", function() if self.layoutMode then self:EndDrag() end end)
    self.dragSurface:SetHandler("OnMouseWheel", function(_, delta) self:AdjustZoom(delta) end)

    self:ApplySizeAndStyle()
    self:AnchorFrame()
end

function M:ApplySizeAndStyle()
    if not self.frame or not EPC.saved then return end

    local visualStyle = self:GetEffectiveVisualStyle()
    local frameTexture = self:GetVisualStyleTexture(visualStyle)
    local useReferenceFrame = type(frameTexture) == "string" and frameTexture ~= ""
    local roundStyle = string.find(visualStyle, "ROUND", 1, true) ~= nil
    local insetRatio = 0.055
    -- v0.29.291: the fantasy DDS files are now true transparent frame overlays,
    -- not full mockup screenshots. Let the live map extend underneath the inner
    -- rim so there is no exposed gap between the live tiles and the artwork.
    if useReferenceFrame then insetRatio = 0.105 end

    -- v0.29.303: keep the fantasy artwork outside the live map instead of
    -- thickening it inward.  This preserves the complete N/E/S/W plaques and
    -- keeps map pins from being buried under the decorative ring.  The frame
    -- gets its own small scale control and a transparent safety gutter so the
    -- compass tips are never clipped by the top-level window.
    local configuredSize = math.floor(clamp(EPC.saved.miniMapSize or 270, 180, 420))
    local inset = math.floor(math.max(12, configuredSize * insetRatio))
    local baseContentSize = configuredSize - (inset * 2)
    local fantasyScale = 1.0
    local frameArtSize = configuredSize
    local frameSafePad = 0
    local frameSize = configuredSize
    local contentSize = baseContentSize
    if useReferenceFrame then
        fantasyScale = clamp(tonumber(EPC.saved.miniMapFantasyFrameScale) or 1.08, 1.00, 1.12)
        frameArtSize = math.floor(configuredSize * fantasyScale + 0.5)
        frameSafePad = math.max(5, math.floor(frameArtSize * 0.025 + 0.5))
        frameSize = frameArtSize + (frameSafePad * 2)
        -- Grow the live viewport just enough to continue underneath the same
        -- inner rim as the artwork grows.  Icon dimensions themselves do not
        -- change, so the user's current pin-size tuning stays intact.
        contentSize = baseContentSize + math.floor((frameArtSize - configuredSize) * 0.72 + 0.5)
    end
    local sizeChanged = self.frameSize ~= frameSize or self.size ~= contentSize
    local styleChanged = self.appliedVisualStyle ~= visualStyle or self.circularStyle ~= roundStyle
    EPC.saved.miniMapSize = configuredSize
    self.frameSize = frameSize
    self.frameArtSize = frameArtSize
    self.frameSafePad = frameSafePad
    self.inset = inset
    self.size = contentSize
    self.circularStyle = roundStyle
    self.appliedVisualStyle = visualStyle

    self.frame:SetDimensions(frameSize, frameSize)
    self.viewport:ClearAnchors()
    self.viewport:SetDimensions(contentSize, contentSize)
    self.viewport:SetAnchor(CENTER, self.frame, CENTER, 0, 0)

    if self.esoFrame then
        self.esoFrame:ClearAnchors()
        if useReferenceFrame then
            self.esoFrame:SetDimensions(frameArtSize, frameArtSize)
            self.esoFrame:SetAnchor(CENTER, self.frame, CENTER, 0, 0)
        else
            self.esoFrame:SetAnchorFill(self.frame)
        end
    end

    -- v0.29.292: use a real alpha mask for the round viewport. The previous
    -- SetCircularClip call could blank the entire live minimap on some clients.
    -- The corrected mask is opaque in the circular center and transparent in the
    -- corners, so map tiles + pins stay visible inside the ornate ring and never
    -- leak outside it. Square mode explicitly disables the mask.
    local maskTexture = roundStyle and MINIMAP_STYLE_MASK_TEXTURES[visualStyle] or nil
    if roundStyle and maskTexture and type(self.viewport.SetMaskTexture) == "function" and type(self.viewport.SetMaskMode) == "function" and CONTROL_MASK_MODE_BASIC ~= nil then
        self.viewport:SetMaskTexture(maskTexture)
        self.viewport:SetMaskMode(CONTROL_MASK_MODE_BASIC)
    elseif type(self.viewport.SetMaskMode) == "function" and CONTROL_MASK_MODE_NONE ~= nil then
        self.viewport:SetMaskMode(CONTROL_MASK_MODE_NONE)
    end

    local alpha = clamp(EPC.saved.miniMapAlpha or 0.92, 0.35, 1.0)
    self.frame:SetAlpha(alpha)

    local playerMarkerStyle = self:GetPlayerMarkerStyle()
    local tint = self:GetPlayerMarkerTint(playerMarkerStyle)
    if self.playerPin then
        self.playerPin:SetTexture(self:GetPlayerMarkerTexture(playerMarkerStyle))
        self.playerPin:SetColor(unpack(tint))
    end
    if self.playerGlow then
        self.playerGlow:SetTexture(self:GetPlayerGlowTexture(playerMarkerStyle))
        self.playerGlow:SetColor(unpack(tint))
        self.playerGlow:SetAlpha(self:GetPlayerGlowAlpha(playerMarkerStyle))
    end

    local softAlpha = clamp(EPC.saved.unitFrameBackgroundAlpha or 0.20, 0.08, 0.45)
    if useReferenceFrame then
        self.background:SetCenterColor(0, 0, 0, 0)
        self.background:SetEdgeColor(0, 0, 0, 0)
    elseif self.layoutMode then
        self.background:SetCenterColor(0.10, 0.08, 0.05, 0.34)
        self.background:SetEdgeColor(0.82, 0.66, 0.26, 0.72)
    else
        self.background:SetCenterColor(0.06, 0.05, 0.03, math.max(0.14, softAlpha * 0.78))
        self.background:SetEdgeColor(0, 0, 0, 0)
    end

    if self.mapGlass then
        self.mapGlass:SetEdgeTexture(nil, 1, 1, 0)
        self.mapGlass:SetEdgeColor(0, 0, 0, 0)
        if useReferenceFrame then
            self.mapGlass:SetHidden(true)
        else
            self.mapGlass:SetHidden(false)
            self.mapGlass:SetCenterColor(0.88, 0.95, 1.00, self.layoutMode and 0.08 or 0.11)
        end
    end
    if self.mapChrome then
        if useReferenceFrame then
            self.mapChrome:SetHidden(true)
        else
            self.mapChrome:SetHidden(false)
            self.mapChrome:SetCenterColor(0, 0, 0, 0)
            self.mapChrome:SetEdgeTexture(nil, 1, 1, 1)
            self.mapChrome:SetEdgeColor(0.92, 0.97, 1.00, self.layoutMode and 0.34 or 0.26)
        end
    end
    if self.mapNorthFade then
        self.mapNorthFade:ClearAnchors()
        self.mapNorthFade:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, 0, 0)
        self.mapNorthFade:SetAnchor(TOPRIGHT, self.viewport, TOPRIGHT, 0, 0)
        self.mapNorthFade:SetHeight(math.max(16, math.floor(contentSize * 0.13)))
        self.mapNorthFade:SetEdgeTexture(nil, 1, 1, 0)
        self.mapNorthFade:SetEdgeColor(0, 0, 0, 0)
        if useReferenceFrame then
            self.mapNorthFade:SetHidden(true)
        else
            self.mapNorthFade:SetHidden(false)
            self.mapNorthFade:SetCenterColor(1.00, 1.00, 1.00, self.layoutMode and 0.04 or 0.06)
        end
    end

    local pieces = { self.skinTop, self.skinBottom, self.skinLeft, self.skinRight, self.skinTL, self.skinTR, self.skinBL, self.skinBR, self.skinTopGem }
    if useReferenceFrame then
        if self.frameBorder then self.frameBorder:SetHidden(true) end
        for i = 1, #pieces do if pieces[i] then pieces[i]:SetHidden(true) end end
        if self.esoMask then self.esoMask:SetHidden(true) end
        if self.esoFrame then
            self.esoFrame:SetTexture(frameTexture)
            self.esoFrame:SetColor(1, 1, 1, 1)
            self.esoFrame:SetAlpha(1)
            self.esoFrame:SetHidden(false)
        end
    else
        if self.frameBorder then
            self.frameBorder:SetHidden(false)
            self.frameBorder:SetCenterColor(0, 0, 0, 0)
            self.frameBorder:SetEdgeTexture(nil, 1, 1, 3)
            self.frameBorder:SetEdgeColor(0.52, 0.37, 0.14, self.layoutMode and 0.98 or 0.92)
        end

        local rail = math.max(5, math.floor(frameSize * 0.022))
        local corner = math.max(15, math.floor(frameSize * 0.060))
        local goldR, goldG, goldB = 0.82, 0.65, 0.28
        local darkR, darkG, darkB = 0.12, 0.08, 0.035
        local rails = { self.skinTop, self.skinBottom, self.skinLeft, self.skinRight }
        for i = 1, #rails do
            local c = rails[i]
            if c then
                c:SetHidden(false)
                c:SetCenterColor(goldR, goldG, goldB, 0.90)
                c:SetEdgeColor(0.30, 0.20, 0.07, 0.98)
                c:SetEdgeTexture(nil, 1, 1, 1)
            end
        end
        if self.skinTop then
            self.skinTop:ClearAnchors()
            self.skinTop:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, -rail, -rail)
            self.skinTop:SetAnchor(TOPRIGHT, self.viewport, TOPRIGHT, rail, -rail)
            self.skinTop:SetHeight(rail)
        end
        if self.skinBottom then
            self.skinBottom:ClearAnchors()
            self.skinBottom:SetAnchor(BOTTOMLEFT, self.viewport, BOTTOMLEFT, -rail, rail)
            self.skinBottom:SetAnchor(BOTTOMRIGHT, self.viewport, BOTTOMRIGHT, rail, rail)
            self.skinBottom:SetHeight(rail)
        end
        if self.skinLeft then
            self.skinLeft:ClearAnchors()
            self.skinLeft:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, -rail, 0)
            self.skinLeft:SetAnchor(BOTTOMLEFT, self.viewport, BOTTOMLEFT, -rail, 0)
            self.skinLeft:SetWidth(rail)
        end
        if self.skinRight then
            self.skinRight:ClearAnchors()
            self.skinRight:SetAnchor(TOPRIGHT, self.viewport, TOPRIGHT, rail, 0)
            self.skinRight:SetAnchor(BOTTOMRIGHT, self.viewport, BOTTOMRIGHT, rail, 0)
            self.skinRight:SetWidth(rail)
        end

        local corners = {
            {self.skinTL, TOPLEFT, self.viewport, TOPLEFT, -corner * 0.45, -corner * 0.45},
            {self.skinTR, TOPRIGHT, self.viewport, TOPRIGHT, corner * 0.45, -corner * 0.45},
            {self.skinBL, BOTTOMLEFT, self.viewport, BOTTOMLEFT, -corner * 0.45, corner * 0.45},
            {self.skinBR, BOTTOMRIGHT, self.viewport, BOTTOMRIGHT, corner * 0.45, corner * 0.45},
        }
        for i = 1, #corners do
            local c, point, rel, relPoint, x, y = unpack(corners[i])
            if c then
                c:SetHidden(false)
                c:ClearAnchors()
                c:SetDimensions(corner, corner)
                c:SetAnchor(point, rel, relPoint, x, y)
                c:SetCenterColor(darkR, darkG, darkB, 0.98)
                c:SetEdgeTexture(nil, 1, 1, 2)
                c:SetEdgeColor(goldR, goldG, goldB, 0.96)
            end
        end
        if self.skinTopGem then
            self.skinTopGem:SetHidden(false)
            self.skinTopGem:ClearAnchors()
            self.skinTopGem:SetDimensions(corner, math.max(9, math.floor(corner * 0.55)))
            self.skinTopGem:SetAnchor(TOP, self.viewport, TOP, 0, -math.floor(corner * 0.45))
            self.skinTopGem:SetCenterColor(0.36, 0.23, 0.07, 0.98)
            self.skinTopGem:SetEdgeTexture(nil, 1, 1, 2)
            self.skinTopGem:SetEdgeColor(0.92, 0.74, 0.32, 1.0)
        end
        if self.esoFrame then self.esoFrame:SetHidden(true) end
        if self.esoMask then self.esoMask:SetHidden(true) end
    end

    if (sizeChanged or styleChanged) and self.mapId then self:RebuildMap(true) end
end

function M:SetLayoutMode(active)
    active = active == true
    if not active and self.dragging then self:EndDrag() end
    self.layoutMode = active

    -- Full Suite HUD Layout Mode deliberately switches ESO into camera UI mode.
    -- That normally looks like a menu to the compass visibility code, which made
    -- the stock top compass disappear exactly when the user was arranging HUD
    -- elements.  Layout mode always previews the compass; leaving layout mode
    -- immediately returns it to the normal world-map/menu visibility rules.
    self:SyncESOCompassVisibility()

    if not self.frame then return end
    -- Keep native clamping disabled in both layout and gameplay; otherwise a
    -- saved edge position can snap inward as soon as HUD Layout Mode closes.
    self.frame:SetClampedToScreen(false)
    self.frame:SetMouseEnabled(self:IsInteractive())
    self.frame:SetMovable(self.layoutMode)
    if self.dragSurface then
        self.dragSurface:SetHidden(not self.layoutMode)
        self.dragSurface:SetMouseEnabled(self.layoutMode)
    end
    self.moveHint:SetHidden(not self.layoutMode)
    self.contextLabel:SetHidden(true)
    self:ApplySizeAndStyle()
    self:Refresh(true)
end

function M:IsWorldMapShowing()
    return isWorldMapShowing()
end

function M:IsMenuShowing()
    -- Suite interaction mode deliberately activates ESO's UI cursor. That is not a
    -- menu and must not hide the minimap; users need the map to remain on screen
    -- while they interact with the suite.
    if self.layoutMode or EPC.interactionMode == true then return false end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true then return true end
    if not EPC.saved or EPC.saved.miniMapHideInMenus == false then return false end
    return isMenuShowing()
end

-- Keep ESO's normal top compass during gameplay, but hide it whenever the player
-- enters a menu/UI scene. The custom minimap has separate interaction handling and
-- can remain available while the Suite interaction cursor is active.
function M:SetESOCompassHidden(hidden)
    hidden = hidden == true
    if self.esoCompassHidden == hidden then return end
    self.esoCompassHidden = hidden

    if COMPASS_FRAME_FRAGMENT and type(COMPASS_FRAME_FRAGMENT.SetHiddenForReason) == "function" then
        pcall(COMPASS_FRAME_FRAGMENT.SetHiddenForReason, COMPASS_FRAME_FRAGMENT, "ESOAdventurerSuiteMenu", hidden)
        return
    end

    -- Compatibility fallback for UI revisions where the fragment is unavailable.
    local controls = { ZO_CompassFrame, ZO_Compass, ZO_CompassContainer }
    for i = 1, #controls do
        local control = controls[i]
        if control and type(control.SetHidden) == "function" then
            pcall(control.SetHidden, control, hidden)
        end
    end
end

function M:SyncESOCompassVisibility()
    -- HUD Layout Mode is a deliberate preview state. It activates camera UI mode,
    -- but the ESO compass must remain visible so the player can see the complete
    -- HUD while arranging Suite overlays. The minimap's own layoutMode is set by
    -- the common HUD Layout Mode, while EPC.unitFramesMoveMode covers the brief
    -- transition before/after all modules have finished updating.
    if self.layoutMode == true or EPC.unitFramesMoveMode == true then
        self:SetESOCompassHidden(false)

        -- Compatibility safeguard: some ESO UI revisions hide the compass control
        -- itself while camera UI mode is active even after our fragment reason is
        -- cleared. Re-expose the stock controls during layout preview only.
        local controls = { ZO_CompassFrame, ZO_Compass, ZO_CompassContainer }
        for i = 1, #controls do
            local control = controls[i]
            if control then
                if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, false) end
                if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
            end
        end
        return
    end

    -- Use the raw menu/UI detector here rather than M:IsMenuShowing(), because
    -- M:IsMenuShowing() intentionally ignores Suite interaction mode so the custom
    -- minimap can stay on screen and receive mouse input.
    local hideCompass = isWorldMapShowing() or isMenuShowing()
    self:SetESOCompassHidden(hideCompass == true)
end

function M:SyncToPlayerMap(force)
    -- Never move ESO's visible map from the minimap. LibMapData owns the
    -- current player-map state and refreshes it on zone/map transitions.
    if self:IsWorldMapShowing() and not self.layoutMode then
        self.mapWasOpen = true
        return false
    end
    if self.mapWasOpen then
        self.mapWasOpen = false
        force = true
    end

    local mapId = 0
    local zoneIndex = nil
    local mapName = nil

    -- Keep asking ESO for its player-location map while the World Map is hidden.
    -- On login and city/interior handoffs the first call can still resolve to a
    -- parent zone; later calls refine it just like opening M does.
    self:TrySyncHiddenPlayerMap(force and "transition" or "pulse")

    -- LibMapData is specifically the player-location map authority used by the
    -- Suite dependencies. Prefer its mapId for gameplay so a city/sub-map does
    -- not get replaced by a broader parent map merely because ESO reports that
    -- both maps "match" the player's location.
    if LMD then
        mapId = tonumber(LMD.mapId) or 0
        zoneIndex = tonumber(LMD.zoneIndex)
        mapName = clean(LMD.mapName or LMD.subzoneName or "", "")
    end

    if mapId <= 0 then
        local currentMatchesPlayer = type(DoesCurrentMapMatchMapForPlayerLocation) ~= "function"
            or safe(DoesCurrentMapMatchMapForPlayerLocation, false) == true
        if currentMatchesPlayer then
            mapId = safeNumber(GetCurrentMapId, 0)
            if mapId > 0 then
                if type(GetCurrentMapZoneIndex) == "function" then
                    zoneIndex = tonumber(safe(GetCurrentMapZoneIndex, nil))
                end
                if not zoneIndex then
                    local _, _, _, zi = safe(GetMapInfoById, nil, mapId)
                    zoneIndex = tonumber(zi)
                end
                mapName = clean(safe(GetMapNameById, "", mapId), "")
            end
        end
    end
    if mapId <= 0 then
        self.playerShown = false
        return false
    end

    -- IMPORTANT: GetMapPlayerPosition, GetPOIMapInfo, wayshrines and the native
    -- pin manager are all relative to ESO's global current map. Align that
    -- hidden context to the exact minimap map BEFORE reading coordinates.
    self:EnsureHiddenMapContext(mapId, force and "transition" or "sync")

    local x, y, heading, shown = safe(GetMapPlayerPosition, nil, "player")
    x, y = tonumber(x), tonumber(y)
    if x == nil or y == nil or shown == false then
        self.playerShown = false
        return false
    end

    self.playerShown = true
    self.playerX = clamp(x, 0, 1)
    self.playerY = clamp(y, 0, 1)
    self.playerHeading = tonumber(heading) or safeNumber(GetPlayerCameraHeading, 0)
    self.lastGameplayMapId = mapId
    self.lastGameplayX = self.playerX
    self.lastGameplayY = self.playerY
    if self.viewPlayerX == nil or force == true then self.viewPlayerX = self.playerX end
    if self.viewPlayerY == nil or force == true then self.viewPlayerY = self.playerY end

    if self.mapId ~= mapId or force then
        local changed = self.mapId ~= mapId
        self.mapId = mapId
        if not mapName or mapName == "" then
            mapName = clean(safe(GetMapNameById, "", mapId), "Current Area")
        end
        self.mapName = mapName
        if self.zoneLabel then self.zoneLabel:SetText(mapName) end
        self.zoneIndex = zoneIndex
        if not self.zoneIndex then
            local _, _, _, zi = safe(GetMapInfoById, nil, mapId)
            self.zoneIndex = tonumber(zi)
        end
        if changed then
            self.trailData = {}
            self:ClearStaticPinsForMapTransition()
            if string.upper(self:GetVisualThemeMode()) == "AUTO_ZONE" then
                self:ApplySizeAndStyle()
            end
        end
        self:RebuildMap(true)
        -- v0.29.311 frame-time hotfix: SyncToPlayerMap owns coordinate/map state
        -- only. Do not perform a full hidden ESO World Map/provider rebuild inside
        -- this generic sync function; transition/event code schedules exactly one
        -- controlled prime. This prevents callers using force=true from accidentally
        -- stacking multiple complete pin rebuilds in the same frame.
        if changed then self.hiddenPinRefreshRequested = true end
        self:RefreshStaticPins()
        if changed then self:ScheduleLiveNativeMirrorRefresh(mapId) end
        self:UpdateContextText(true)
    end
    return true
end

function M:EnsureTiles(count)
    for i = #self.tiles + 1, count do
        local tile = wm:CreateControl("EPC_MiniMap_Tile_" .. tostring(i), self.tileContainer, CT_TEXTURE)
        tile:SetDrawLayer(DL_BACKGROUND)
        tile:SetDrawLevel(1)
        tile:SetHidden(true)
        self.tiles[i] = tile
    end
end

function M:RebuildMap(force)
    if not self.frame or not EPC.saved then return end
    local mapId = tonumber(self.mapId) or 0
    if mapId <= 0 then return end

    local horizontal, vertical = safe(GetMapNumTilesForMapId, nil, mapId)
    horizontal = tonumber(horizontal) or 0
    vertical = tonumber(vertical) or 0
    if horizontal <= 0 or vertical <= 0 then
        self.statusLabel:SetHidden(true)
        return
    end

    local zoom = self:GetEffectiveZoom()
    self.effectiveZoom = zoom
    -- Show more territory at each zoom level so the native map texture stays
    -- closer to its intended sampling scale and looks less pixelated.
    local visibleSpan = clamp(0.31 / zoom, 0.145, 0.44)
    local fullW = self.size / visibleSpan
    local fullH = fullW * (vertical / horizontal)
    self.fullMapWidth = fullW
    self.fullMapHeight = fullH
    self.motionCameraX029318 = nil
    self.motionCameraY029318 = nil
    self.lastCameraPanAt029318 = nil
    self.lastStaticCullAt029318 = nil
    self.horizontalTiles = horizontal
    self.verticalTiles = vertical

    self.tileContainer:SetDimensions(fullW, fullH)
    if self.staticPinLayer then self.staticPinLayer:SetDimensions(fullW, fullH) end
    self:EnsureTiles(horizontal * vertical)
    local tileW = fullW / horizontal
    local tileH = fullH / vertical
    local mapAlpha = math.max(0.94, clamp(EPC.saved.miniMapMapAlpha or 0.94, 0.55, 1.0))

    local index = 1
    for row = 1, vertical do
        for col = 1, horizontal do
            local tile = self.tiles[index]
            tile:ClearAnchors()
            tile:SetAnchor(TOPLEFT, self.tileContainer, TOPLEFT, (col - 1) * tileW, (row - 1) * tileH)
            tile:SetDimensions(tileW + 0.75, tileH + 0.75)
            local filename = safe(GetMapTileTextureForMapId, "", mapId, index)
            if filename and filename ~= "" then
                tile:SetTexture(filename)
                tile:SetColor(0.97, 0.99, 0.95, 1.0)
                tile:SetAlpha(mapAlpha)
                tile:SetHidden(false)
            else
                tile:SetHidden(true)
            end
            index = index + 1
        end
    end
    for i = index, #self.tiles do self.tiles[i]:SetHidden(true) end
    self.statusLabel:SetHidden(true)
    self:UpdatePanAndPins(true)
end

function M:MapToScreen(x, y)
    if not self.playerShown or not self.fullMapWidth or not self.fullMapHeight then return nil, nil, false end
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return nil, nil, false end
    local centerX = self.viewPlayerX or self.playerX
    local centerY = self.viewPlayerY or self.playerY
    local px = (self.size * 0.5) + ((x - centerX) * self.fullMapWidth)
    local py = (self.size * 0.5) + ((y - centerY) * self.fullMapHeight)
    local inside = px >= 0 and py >= 0 and px <= self.size and py <= self.size
    return px, py, inside
end

function M:PlacePin(pin, x, y, size, allowEdge)
    if not pin then return false, false end
    local drawSize = self:GetScaledPinSize(size)
    if type(pin.SetDimensions) == "function" then pin:SetDimensions(drawSize, drawSize) end

    -- Static pins are anchored once in full-map coordinates. The parent map
    -- canvas moves with tileContainer, so running no longer causes hundreds of
    -- ClearAnchors/SetAnchor calls. The viewport clips off-screen children.
    if pin.easMapLocked029312 == true and self.staticPinLayer and self.fullMapWidth and self.fullMapHeight then
        x, y = tonumber(x), tonumber(y)
        if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
            pin:SetHidden(true)
            return false, false
        end
        pin.easMapX029318 = x
        pin.easMapY029318 = y
        pin.easMapCullHidden029318 = false
        local ax = x * self.fullMapWidth
        local ay = y * self.fullMapHeight
        local key = string.format("%.5f:%.5f:%d:%d", x, y, math.floor(self.fullMapWidth + 0.5), math.floor(self.fullMapHeight + 0.5))

        -- A pin may have been parked on the dormant layer by the movement
        -- governor. Any real render/refresh makes it active again immediately.
        local parentChanged029319 = false
        if self.staticPinDormantLayer029319 and type(pin.GetParent) == "function" and type(pin.SetParent) == "function" then
            local okParent029319, currentParent029319 = pcall(pin.GetParent, pin)
            if okParent029319 and currentParent029319 ~= self.staticPinLayer then
                pin:SetParent(self.staticPinLayer)
                parentChanged029319 = true
            end
        end
        if parentChanged029319 or pin.easMapAnchorKey029312 ~= key then
            pin.easMapAnchorKey029312 = key
            pin:ClearAnchors()
            pin:SetAnchor(CENTER, self.staticPinLayer, TOPLEFT, ax, ay)
        end
        pin:SetHidden(false)
        pin:SetAlpha(1.0)
        return true, false
    end

    local px, py, inside = self:MapToScreen(x, y)
    if px == nil then pin:SetHidden(true) return false, false end
    local margin = math.max(8, drawSize * 0.6)
    local edge = false
    local guideEnabled = EPC.saved and EPC.saved.miniMapEdgeGuidance ~= false
    if not inside then
        if allowEdge == true and guideEnabled then
            edge = true
        else
            pin:SetHidden(true)
            return false, false
        end
    end

    -- v0.29.303: even a pin whose CENTER is inside the viewport can have half
    -- of its texture cut by the round mask / fantasy rim.  Keep the complete
    -- icon inside a safe visual boundary so wayshrines, services, quests, etc.
    -- remain recognizable at the edge of the minimap.
    local frameGuard = (self.appliedVisualStyle and string.find(self.appliedVisualStyle, "FANTASY_", 1, true)) and 6 or 2
    if self.circularStyle == true then
        local center = self.size * 0.5
        local dx = px - center
        local dy = py - center
        local distance = math.sqrt((dx * dx) + (dy * dy))
        local radius = math.max(12, center - margin - frameGuard)
        if distance > radius and distance > 0.0001 then
            local scale = radius / distance
            px = center + (dx * scale)
            py = center + (dy * scale)
            edge = true
        end
    else
        local minX = margin + frameGuard
        local maxX = self.size - margin - frameGuard
        local minY = margin + frameGuard + 4
        local maxY = self.size - margin - frameGuard - 4
        local oldX, oldY = px, py
        px = clamp(px, minX, maxX)
        py = clamp(py, minY, maxY)
        if px ~= oldX or py ~= oldY then edge = true end
    end
    pin:ClearAnchors()
    pin:SetAnchor(CENTER, self.viewport, TOPLEFT, px, py)
    pin:SetHidden(false)
    pin:SetAlpha(edge and 0.96 or 1.0)
    return true, edge
end

function M:GetDirectionTo(x, y)
    if not self.playerShown then return "" end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return "" end
    return directionText(x - (self.playerX or 0.5), y - (self.playerY or 0.5))
end

function M:UpdatePOIDistances()
    local data = self.poiData or {}
    self.nearestUndiscoveredPOI = nil
    for i = 1, #data do
        local poi = data[i]
        local dx = (tonumber(poi.x) or 0) - (self.playerX or 0.5)
        local dy = (tonumber(poi.y) or 0) - (self.playerY or 0.5)
        poi.distance2 = (dx * dx) + (dy * dy)
        if poi.discovered ~= true and (not self.nearestUndiscoveredPOI or poi.distance2 < self.nearestUndiscoveredPOI.distance2) then
            self.nearestUndiscoveredPOI = poi
        end
    end
    table.sort(data, function(a, b)
        if a.discovered ~= b.discovered then return a.discovered == false end
        if a.nearby ~= b.nearby then return a.nearby == true end
        if a.isCompletion ~= b.isCompletion then return a.isCompletion == true end
        return (a.distance2 or 999) < (b.distance2 or 999)
    end)
end

function M:RememberMerchantHere()
    if self.LEGACY_LEARNED_PINS_ENABLED ~= true then return false end
    if not EPC.saved then return false end
    local mapId = tonumber(self.mapId)
    if not mapId and type(GetCurrentMapId) == "function" then
        mapId = safeNumber(GetCurrentMapId, 0)
    end
    if not mapId or mapId <= 0 then return false end

    local x, y, _, shown = safe(GetMapPlayerPosition, nil, "player")
    x, y = tonumber(x), tonumber(y)
    if shown ~= true or not x or not y or x <= 0 or x >= 1 or y <= 0 or y >= 1 then return false end

    EPC.saved.miniMapKnownMerchants = EPC.saved.miniMapKnownMerchants or {}
    local mapKey = tostring(mapId)
    local list = EPC.saved.miniMapKnownMerchants[mapKey]
    if type(list) ~= "table" then
        list = {}
        EPC.saved.miniMapKnownMerchants[mapKey] = list
    end

    local storeName, storeType, storeIcon = self:GetCurrentStoreIdentity()

    -- Opening a store can fire more than once. Only collapse a visit when both
    -- the store identity and location match. Different merchants at the same
    -- market stall/area are intentionally allowed to keep separate pins.
    local candidate = { name=storeName, storeType=storeType, icon=storeIcon }
    local candidateIdentity = normalizedMerchantIdentity(candidate)
    for i = 1, #list do
        local old = list[i]
        if normalizedMerchantIdentity(old) == candidateIdentity
            and mapPointNear(old.x, old.y, x, y, 0.000225) then
            -- Same merchant revisited: refresh metadata but never add a second pin.
            old.name = storeName
            old.storeType = storeType
            old.icon = storeIcon
            old.lastSeen = safeNumber(GetTimeStamp, 0)
            self.staticPinsDirty = true
            return true
        end
    end

    list[#list + 1] = {
        x=x, y=y, name=storeName, storeType=storeType, icon=storeIcon,
        learned=true, lastSeen=safeNumber(GetTimeStamp, 0)
    }
    while #list > 24 do table.remove(list, 1) end
    self.staticPinsDirty = true
    return true
end

function M:AddRememberedMerchants()
    if self.LEGACY_LEARNED_PINS_ENABLED ~= true then return end
    if not EPC.saved or type(EPC.saved.miniMapKnownMerchants) ~= "table" then return end
    local mapId = tonumber(self.mapId)
    if not mapId then return end
    local list = EPC.saved.miniMapKnownMerchants[tostring(mapId)]
    if type(list) ~= "table" then return end

    self.merchantData = self.merchantData or {}
    for i = 1, #list do
        local saved = list[i]
        local x, y = tonumber(saved.x), tonumber(saved.y)
        if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
            local duplicate = false
            local savedIdentity = normalizedMerchantIdentity(saved)
            for j = 1, #self.merchantData do
                local existing = self.merchantData[j]
                -- Do not suppress a different merchant just because it occupies
                -- the same small market area. Only the same learned identity is
                -- considered a duplicate here.
                if existing.learned == true
                    and normalizedMerchantIdentity(existing) == savedIdentity
                    and mapPointNear(existing.x, existing.y, x, y, 0.000225) then
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                self.merchantData[#self.merchantData + 1] = {
                    x=x, y=y,
                    name=clean(saved.name, STORE_TYPE_LABELS[saved.storeType] or "Merchant"),
                    storeType=saved.storeType or "merchant",
                    icon=(saved.icon and saved.icon ~= "") and saved.icon or POI_FALLBACK_TEXTURE,
                    discovered=true, nearby=true, isMerchant=true, learned=true,
                }
            end
        end
    end
end

-- v0.29.313: POI proximity/discovery events are common while running through
-- towns and dense objective areas. Refresh only the live POI/service layers here
-- instead of rescanning every wayshrine, PvP keep, native mirror provider, etc.
function M:RefreshLivePOILayer029313()
    if not EPC.saved then return end
    local zoneIndex = tonumber(self.zoneIndex)
    if not zoneIndex or type(GetNumPOIs) ~= "function" or type(GetPOIMapInfo) ~= "function" then
        self.poiRefreshDirty029313 = false
        return
    end

    self.skyshardData = self:BuildCurrentSkyshardData029443()
    self:EnsureSkyshardPins(#(self.skyshardData or {}))
    if self.skyshardData and self.skyshardPins and self:SkyshardsEnabled029443() then
        for i = 1, #self.skyshardPins do
            local data = self.skyshardData[i]
            local pin = self.skyshardPins[i]
            if data then
                pin:SetTexture(SUITE_SKYSHARD_TEXTURE_029443)
                pin:SetColor(1.00, 0.82, 0.20, 1.00)
                self:PlacePin(pin, data.x, data.y, 20, false)
            else
                pin:SetHidden(true)
            end
        end
    elseif self.skyshardPins then
        for i = 1, #self.skyshardPins do self.skyshardPins[i]:SetHidden(true) end
    end
    self:RefreshSkyshardWorldMapPin029443()

    self.poiData = {}
    self.merchantData = {}
    self.serviceData = {}
    self.nearestUndiscoveredPOI = nil

    local poiCount = safeNumber(GetNumPOIs, 0, zoneIndex)
    local noneType = ZONE_COMPLETION_TYPE_NONE or 0
    for poiIndex = 1, poiCount do
        local x, y, pinType, icon, shown, locked, discovered, nearby = safe(GetPOIMapInfo, nil, zoneIndex, poiIndex)
        x, y = tonumber(x), tonumber(y)
        if shown == true and locked ~= true and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local completionType = type(GetPOIZoneCompletionType) == "function"
                and safe(GetPOIZoneCompletionType, noneType, zoneIndex, poiIndex) or noneType
            local isCompletion = completionType ~= noneType
            local name = type(GetPOIInfo) == "function"
                and clean(select(1, safe(GetPOIInfo, "", zoneIndex, poiIndex)), "Point of Interest") or "Point of Interest"
            local dx = x - (self.playerX or 0.5)
            local dy = y - (self.playerY or 0.5)
            local dist2 = (dx * dx) + (dy * dy)
            local nativeIcon = self:GetNativePvEMapPinTexture(icon, pinType)
            local data = {
                x=x, y=y, icon=nativeIcon or icon, name=name, discovered=discovered == true,
                nearby=nearby == true, isCompletion=isCompletion, distance2=dist2, pinType=pinType,
                nativeIcon=nativeIcon ~= nil,
            }
            if isStableMasterPOI(name, icon) then
                data.kind = "stable"
                data.isService = true
                data.name = clean(name, "Stablemaster")
                if not data.icon or data.icon == "" then data.icon = getServiceFallbackIcon("stable") end
                self.serviceData[#self.serviceData + 1] = data
            elseif isSellMerchantPOI(name, icon) then
                data.isMerchant = true
                self.merchantData[#self.merchantData + 1] = data
            elseif self:LayerEnabled("pois") then
                self.poiData[#self.poiData + 1] = data
                if discovered ~= true and (not self.nearestUndiscoveredPOI or dist2 < self.nearestUndiscoveredPOI.distance2) then
                    self.nearestUndiscoveredPOI = data
                end
            end
        end
    end

    self:UpdatePOIDistances()
    -- Legacy caches are disabled in normal Suite builds; these calls remain safe
    -- for users who deliberately retained that compatibility mode.
    self:AddRememberedMerchants()
    self:AddRememberedServices()

    local maxPins = math.max(24, math.min(POI_RENDER_HARD_CAP_029314, tonumber(EPC.saved.miniMapPOIMax) or 160))
    self:EnsurePOIPins(maxPins)
    self:EnsureMerchantPins(math.min(48, math.max(16, #(self.merchantData or {}))))
    self:EnsureServicePins(math.min(32, math.max(8, #(self.serviceData or {}))))

    -- v0.29.314: do not touch the supplemental native snapshot on ordinary POI
    -- proximity/discovery updates. Filtering that snapshot against every live POI
    -- and then re-rendering the entire native pool was a dense-town hitch. Native
    -- snapshot reconciliation now belongs to true static/map-transition refreshes.
    self:RenderPOIPins()
    self:RenderMerchantPins()
    self:RenderServicePins()
    self.poiRefreshDirty029313 = false
end

function M:RefreshStaticPins()
    if not EPC.saved then return end

    self.shrineData = {}
    if self:LayerEnabled("shrines") and type(GetNumFastTravelNodes) == "function" and type(GetFastTravelNodeInfo) == "function" then
        local count = safeNumber(GetNumFastTravelNodes, 0)
        for nodeIndex = 1, count do
            local known, name, x, y, icon, _, _, shown, locked = safe(GetFastTravelNodeInfo, nil, nodeIndex)
            if known == true and shown == true and locked ~= true and tonumber(x) and tonumber(y) then
                self.shrineData[#self.shrineData + 1] = {
                    x=tonumber(x), y=tonumber(y), icon=icon, name=clean(name, "Wayshrine"),
                    nativeIcon=(type(icon) == "string" and icon ~= ""),
                }
                if #self.shrineData >= 96 then break end
            end
        end
    end
    self:EnsureShrinePins(#self.shrineData)
    for i = 1, #self.shrinePins do
        local data = self.shrineData[i]
        local pin = self.shrinePins[i]
        if data then
            if data.icon and data.icon ~= "" then
                pin:SetTexture(data.icon)
                -- ESO's wayshrine / fast-travel artwork already carries its own
                -- visual treatment, so do not recolor it with the old gold tint.
                pin:SetColor(1, 1, 1, 1)
            else
                pin:SetTexture(WAYPOINT_TEXTURE)
                pin:SetColor(1, 1, 1, 1)
            end
        else
            pin:SetHidden(true)
        end
    end

    self.skyshardData = self:BuildCurrentSkyshardData029443()
    self:EnsureSkyshardPins(#(self.skyshardData or {}))
    if self.skyshardData and self.skyshardPins and self:SkyshardsEnabled029443() then
        for i = 1, #self.skyshardPins do
            local data = self.skyshardData[i]
            local pin = self.skyshardPins[i]
            if data then
                pin:SetTexture(SUITE_SKYSHARD_TEXTURE_029443)
                pin:SetColor(1.00, 0.82, 0.20, 1.00)
                self:PlacePin(pin, data.x, data.y, 20, false)
            else
                pin:SetHidden(true)
            end
        end
    elseif self.skyshardPins then
        for i = 1, #self.skyshardPins do self.skyshardPins[i]:SetHidden(true) end
    end
    self:RefreshSkyshardWorldMapPin029443()

    self.poiData = {}
    self.merchantData = {}
    self.serviceData = {}
    self.nearestUndiscoveredPOI = nil
    local zoneIndex = tonumber(self.zoneIndex)
    -- Merchants are scanned even if the normal POI layer is disabled.
    if zoneIndex and type(GetNumPOIs) == "function" and type(GetPOIMapInfo) == "function" then
        local poiCount = safeNumber(GetNumPOIs, 0, zoneIndex)
        local noneType = ZONE_COMPLETION_TYPE_NONE or 0
        local mode = self:GetMode()
        for poiIndex = 1, poiCount do
            local x, y, pinType, icon, shown, locked, discovered, nearby = safe(GetPOIMapInfo, nil, zoneIndex, poiIndex)
            x = tonumber(x)
            y = tonumber(y)
            if shown == true and locked ~= true and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local completionType = type(GetPOIZoneCompletionType) == "function" and safe(GetPOIZoneCompletionType, noneType, zoneIndex, poiIndex) or noneType
                local isCompletion = completionType ~= noneType
                -- Base map tiles do not contain ESO map pins, so render every POI the
                -- API says should be shown. Layer toggles/modes still decide whether
                -- the POI layer itself is enabled.
                local include = true
                if include then
                    local name = type(GetPOIInfo) == "function" and clean(select(1, safe(GetPOIInfo, "", zoneIndex, poiIndex)), "Point of Interest") or "Point of Interest"
                    local dx = (x - (self.playerX or 0.5))
                    local dy = (y - (self.playerY or 0.5))
                    local dist2 = (dx * dx) + (dy * dy)
                    local nativeIcon = self:GetNativePvEMapPinTexture(icon, pinType)
                    local data = {
                        x=x, y=y, icon=nativeIcon or icon, name=name, discovered=discovered == true,
                        nearby=nearby == true, isCompletion=isCompletion, distance2=dist2, pinType=pinType,
                        nativeIcon=nativeIcon ~= nil,
                    }
                    if isStableMasterPOI(name, icon) then
                        -- Stablemasters are promoted to the always-on service layer so
                        -- every stable ESO exposes on the current zone/town map remains
                        -- visible even when the general POI layer is disabled.
                        data.kind = "stable"
                        data.isService = true
                        data.name = clean(name, "Stablemaster")
                        if not data.icon or data.icon == "" then data.icon = getServiceFallbackIcon("stable") end
                        self.serviceData[#self.serviceData + 1] = data
                    elseif isSellMerchantPOI(name, icon) then
                        data.isMerchant = true
                        self.merchantData[#self.merchantData + 1] = data
                    elseif self:LayerEnabled("pois") then
                        self.poiData[#self.poiData + 1] = data
                        if discovered ~= true and (not self.nearestUndiscoveredPOI or dist2 < self.nearestUndiscoveredPOI.distance2) then
                            self.nearestUndiscoveredPOI = data
                        end
                    end
                end
            end
        end
        self:UpdatePOIDistances()
    end
    -- 0.29.280: live gameplay APIs are always authoritative. A native World Map
    -- snapshot is optional supplemental data only; it must never replace the
    -- live layers or require the player to open the full map before icons sync.
    self:RememberVisiblePOIs()
    self:AddRememberedMerchants()
    self:AddRememberedServices()
    self:AddCapturedNativeTownPins()
    self:FilterNativeMirrorDuplicates()

    local maxPins = math.max(24, math.min(POI_RENDER_HARD_CAP_029314, tonumber(EPC.saved.miniMapPOIMax) or 160))
    self:EnsurePOIPins(maxPins)
    self:EnsureMerchantPins(math.min(48, math.max(16, #(self.merchantData or {}))))
    self:EnsureServicePins(math.min(32, math.max(8, #(self.serviceData or {}))))
    self:RefreshPvPKeepData()

    -- Place map-locked layers only when their data changes. They subsequently
    -- travel with staticPinLayer while the player moves.
    if self.shrineData and self.shrinePins then
        if self:LayerEnabled("shrines") then
            for i = 1, #self.shrinePins do
                local data = self.shrineData[i]
                if data then self:PlacePin(self.shrinePins[i], data.x, data.y, 17, false) else self.shrinePins[i]:SetHidden(true) end
            end
        else
            for i = 1, #self.shrinePins do self.shrinePins[i]:SetHidden(true) end
        end
    end
    self:RenderNativeMirrorPins()
    self:RenderPOIPins()
    self:RenderPvPPins()
    self:RenderTrail()
    self:RenderModeLabels()
    self:UpdateContextText(false)
    self.staticPinsDirty = false
    self.poiRefreshDirty029313 = false
end

local RefreshPvPKeepDataImplArch

function M:RefreshPvPKeepData(...)

    return RefreshPvPKeepDataImplArch(self, ...)

end

RefreshPvPKeepDataImplArch = function(self)
    self.pvpKeepData = {}
    self.pvpTravelLinks = {}
    if safe(IsPlayerInAvAWorld, false) ~= true then return end
    if type(GetNumKeeps) ~= "function" or type(GetKeepKeysByIndex) ~= "function" or type(GetKeepPinInfo) ~= "function" then return end
    local count = safeNumber(GetNumKeeps, 0)
    for i = 1, count do
        local keepId = select(1, safe(GetKeepKeysByIndex, nil, i))
        if keepId then
            local name = type(GetKeepName) == "function" and clean(safe(GetKeepName, "", keepId), "PvP Objective") or "PvP Objective"
            local x, y, pinType, contextUsed
            for context = 1, 3 do
                local pType, kx, ky = safe(GetKeepPinInfo, nil, keepId, context)
                kx, ky = tonumber(kx), tonumber(ky)
                if kx and ky and kx > 0 and ky > 0 and kx <= 1 and ky <= 1 then
                    pinType, x, y, contextUsed = pType, kx, ky, context
                    break
                end
            end
            if x and y then
                local alliance = 0
                if type(GetKeepAlliance) == "function" then alliance = tonumber(safe(GetKeepAlliance, 0, keepId, contextUsed or 1)) or 0 end
                local keepType = type(GetKeepType) == "function" and safe(GetKeepType, nil, keepId) or nil
                local resourceType = type(GetKeepResourceType) == "function" and safe(GetKeepResourceType, nil, keepId) or nil
                local size = 26
                -- Resources are visually smaller than keeps/outposts on ESO's PvP map.
                if resourceType and resourceType ~= 0 then size = 20 end
                self.pvpKeepData[#self.pvpKeepData + 1] = {
                    x=x, y=y, name=name, keepId=keepId, pinType=pinType,
                    texture=self:GetPvPPinTexture(pinType), alliance=alliance,
                    color=self:GetPvPAllianceColor(alliance), keepType=keepType,
                    resourceType=resourceType, size=size, context=contextUsed,
                }
            end
        end
    end

    -- Cyrodiil transitus network. ESO exposes each connection with owner,
    -- restriction, state, and normalized map endpoints. Use those values
    -- directly so the minimap mirrors who owns each connected supply line.
    if type(GetNumKeepTravelNetworkLinks) == "function" and type(GetKeepTravelNetworkLinkInfo) == "function" then
        local context = BGQUERY_LOCAL or 1
        local linkCount = safeNumber(GetNumKeepTravelNetworkLinks, 0, context)
        for i = 1, linkCount do
            local linkType, linkOwner, restrictedToAlliance, startX, startY, endX, endY = safe(GetKeepTravelNetworkLinkInfo, nil, i, context)
            startX, startY, endX, endY = tonumber(startX), tonumber(startY), tonumber(endX), tonumber(endY)
            if startX and startY and endX and endY and startX >= 0 and startX <= 1 and startY >= 0 and startY <= 1 and endX >= 0 and endX <= 1 and endY >= 0 and endY <= 1 then
                local owner = tonumber(linkOwner) or 0
                if owner <= 0 then owner = tonumber(restrictedToAlliance) or 0 end
                local active = true
                if FAST_TRAVEL_LINK_ACTIVE ~= nil and tonumber(linkType) ~= nil then
                    active = tonumber(linkType) == tonumber(FAST_TRAVEL_LINK_ACTIVE)
                end
                self.pvpTravelLinks[#self.pvpTravelLinks + 1] = {
                    startX=startX, startY=startY, endX=endX, endY=endY,
                    linkType=linkType, alliance=owner, active=active,
                    color=self:GetPvPAllianceColor(owner),
                }
            end
        end
    end
end

function M:RenderModeLabels()
    -- Exact native mirror is icon-for-icon with ESO's full map and therefore
    -- never adds Suite-only text such as "Map Location".
    if self.useExactNativeStaticMirror == true then self:HideMapObjectLabels(); return end
    -- PvP intentionally uses icons only, matching ESO's Cyrodiil map.
    if self:IsPvPIconOnlyMode() then self:HideMapObjectLabels(); return end
    if not self:IsLabeledMapMode() then self:HideMapObjectLabels(); return end

    local function render(kind, data, nameFn, offset, colorFn)
        data = data or {}
        local pool = self:EnsureMapObjectLabels(kind, #data)
        local used = 0
        for i = 1, #data do
            local d = data[i]
            if d and d.x and d.y then
                used = used + 1
                local text = nameFn and nameFn(d, i) or d.name
                local color = colorFn and colorFn(d, i) or COLORS.white
                self:PlaceMapObjectLabel(pool[used], text, d.x, d.y, offset, color)
            end
        end
        for i = used + 1, #pool do pool[i]:SetHidden(true) end
    end

    render("shrines", self.shrineData, function(d) return d.name end, 10, function() return COLORS.gold end)
    render("pois", self.poiData, function(d) return d.name end, 10, function(d) return d.discovered and COLORS.white or COLORS.gold end)
    render("merchants", self.merchantData, function(d) return d.name or "Merchant" end, 13, function() return COLORS.gold end)
    render("services", self.serviceData, function(d) return d.name or STORE_TYPE_LABELS[d.kind] or "Service" end, 15, function() return COLORS.gold end)
    render("keeps", self.pvpKeepData, function(d) return d.name end, 15, function(d) return d.color or COLORS.white end)

    local groupData = {}
    for i, st in pairs(self.groupPinState or {}) do
        if st and st.x and st.y and st.name then groupData[#groupData + 1] = {x=st.x,y=st.y,name=st.name,leader=st.leader} end
    end
    render("group", groupData, function(d) return d.leader and (d.name .. " [LEADER]") or d.name end, 10, function() return COLORS.cyan end)

    local specials = {}
    if self.questPosition and self.questPosition.x and self.questPosition.y then specials[#specials+1] = {x=self.questPosition.x,y=self.questPosition.y,name=self.questPosition.name or "Quest",color=COLORS.gold} end
    if self.waypointPosition and self.waypointPosition.x and self.waypointPosition.y then specials[#specials+1] = {x=self.waypointPosition.x,y=self.waypointPosition.y,name="Waypoint",color=COLORS.blue} end
    if self.rallyPosition and self.rallyPosition.x and self.rallyPosition.y then specials[#specials+1] = {x=self.rallyPosition.x,y=self.rallyPosition.y,name="Rally Point",color=COLORS.green} end
    render("special", specials, function(d) return d.name end, 14, function(d) return d.color end)

    local playerPool = self:EnsureMapObjectLabels("player", 1)
    self:PlaceMapObjectLabel(playerPool[1], "YOU", self.playerX, self.playerY, 16, COLORS.white)

    local companionData = {}
    if safe(DoesUnitExist, false, "companion") == true then
        local x, y, _, shown = safe(GetMapPlayerPosition, nil, "companion")
        if shown == true and tonumber(x) and tonumber(y) then companionData[1] = {x=tonumber(x),y=tonumber(y),name=clean(safe(GetUnitName,"","companion"),"Companion")} end
    end
    render("companion", companionData, function(d) return d.name end, 10, function() return COLORS.white end)
end


function M:SkyshardsEnabled029443()
    return EPC.saved and EPC.saved.resourcePinsShowSkyshards ~= false
end

function M:GetCurrentSkyshardZoneId029443()
    local zoneIndex = 0
    if type(GetCurrentMapZoneIndex) == "function" then
        local ok, value = pcall(GetCurrentMapZoneIndex)
        if ok then zoneIndex = tonumber(value) or 0 end
    end
    if zoneIndex <= 0 then zoneIndex = tonumber(self.zoneIndex) or 0 end
    if zoneIndex > 0 and type(GetZoneId) == "function" then
        local ok, value = pcall(GetZoneId, zoneIndex)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

function M:BuildCurrentSkyshardData029443()
    local results = {}
    if not self:SkyshardsEnabled029443() then return results end
    if type(GetNumSkyshardsInZone) ~= "function" or type(GetZoneSkyshardId) ~= "function"
        or type(GetSkyshardDiscoveryStatus) ~= "function" or type(GetNormalizedPositionForSkyshardId) ~= "function" then
        return results
    end
    local zoneId = self:GetCurrentSkyshardZoneId029443()
    if zoneId <= 0 then return results end

    local acquired = rawget(_G, "SKYSHARD_DISCOVERY_STATUS_ACQUIRED")
    local count = tonumber(safe(GetNumSkyshardsInZone, 0, zoneId)) or 0
    for i = 1, count do
        local shardId = tonumber(safe(GetZoneSkyshardId, 0, zoneId, i)) or 0
        if shardId > 0 then
            local status = safe(GetSkyshardDiscoveryStatus, acquired, shardId)
            if acquired == nil or status ~= acquired then
                local x, y, isInMap = safe(GetNormalizedPositionForSkyshardId, nil, shardId)
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (isInMap == nil or isInMap == true) then
                    local hint = type(GetSkyshardHint) == "function" and clean(safe(GetSkyshardHint, "Skyshard", shardId), "Skyshard") or "Skyshard"
                    results[#results + 1] = {
                        x = x, y = y, skyshardId = shardId, name = hint ~= "" and hint or "Skyshard",
                    }
                end
            end
        end
    end
    return results
end

function M:RegisterSkyshardWorldMapPin029443()
    if self.skyshardWorldMapPinRegistered029443 then return true end
    if type(ZO_WorldMap_AddCustomPin) ~= "function" then return false end

    local layout = {
        level = 94,
        texture = SUITE_SKYSHARD_TEXTURE_029443,
        size = 28,
        tint = ZO_ColorDef and ZO_ColorDef:New(1.00, 0.82, 0.20, 1.00) or nil,
    }

    local function addPins(pinManager)
        local mm = EPC and EPC.MiniMap
        if not mm or not mm:SkyshardsEnabled029443() then return end
        local data = mm:BuildCurrentSkyshardData029443()
        for i = 1, #data do
            local row = data[i]
            pinManager:CreatePin(_G[SKYSHARD_WORLD_PIN_TYPE_029443], row, row.x, row.y)
        end
    end

    local ok = pcall(ZO_WorldMap_AddCustomPin, SKYSHARD_WORLD_PIN_TYPE_029443, addPins, nil, layout, nil)
    if ok and _G[SKYSHARD_WORLD_PIN_TYPE_029443] then
        self.skyshardWorldMapPinRegistered029443 = true
        if type(ZO_WorldMap_SetCustomPinEnabled) == "function" then
            pcall(ZO_WorldMap_SetCustomPinEnabled, _G[SKYSHARD_WORLD_PIN_TYPE_029443], true)
        end
        return true
    end
    return false
end

function M:RefreshSkyshardWorldMapPin029443()
    self:RegisterSkyshardWorldMapPin029443()
    if self.skyshardWorldMapPinRegistered029443
        and type(ZO_WorldMap_RefreshCustomPinsOfType) == "function"
        and _G[SKYSHARD_WORLD_PIN_TYPE_029443] then
        pcall(ZO_WorldMap_RefreshCustomPinsOfType, _G[SKYSHARD_WORLD_PIN_TYPE_029443])
    end
end

-- v0.29.442: One authoritative tracked-quest map point feeds BOTH the World Map
-- and Suite minimap. Registering a real ESO custom pin fixes the previous case
-- where the gold marker only existed as a minimap overlay and could drift from
-- ESO's normalized map coordinate space.
function M:ResolveTrackedQuestMapPoint029442()
    if not self:LayerEnabled("quest") then return nil end
    if not EPC.ActiveQuest
        or type(EPC.ActiveQuest.GetQuestTrackingSource2513) ~= "function"
        or type(EPC.ActiveQuest.ResolveQuestSource2516) ~= "function"
        or type(EPC.ActiveQuest.GetQuestDirectionPosition2512) ~= "function" then
        return nil
    end

    local source = EPC.ActiveQuest:GetQuestTrackingSource2513()
    local questIndex = EPC.ActiveQuest:ResolveQuestSource2516(source)
    if not questIndex then return nil end

    if type(EPC.ActiveQuest.EnsureQuestBreadcrumbs2519) == "function" then
        pcall(EPC.ActiveQuest.EnsureQuestBreadcrumbs2519, EPC.ActiveQuest, questIndex, false)
    end

    local position = EPC.ActiveQuest:GetQuestDirectionPosition2512(questIndex)
    if not position or position.available ~= true then return nil end
    local x, y = tonumber(position.x), tonumber(position.y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return nil end

    local name = "Quest"
    if type(GetJournalQuestName) == "function" then
        name = clean(safe(GetJournalQuestName, "Quest", questIndex), "Quest")
    end
    return {
        x = x,
        y = y,
        name = name,
        objective = position.targetText,
        questIndex = questIndex,
    }
end

function M:RegisterQuestWorldMapPin029442()
    if self.questWorldMapPinRegistered029442 then return true end
    if type(ZO_WorldMap_AddCustomPin) ~= "function" then return false end

    local layout = {
        level = 95,
        texture = QUEST_SKYSHARD_TEXTURE,
        size = 34,
        tint = ZO_ColorDef and ZO_ColorDef:New(1.00, 0.82, 0.20, 1.00) or nil,
    }

    local function addPins(pinManager)
        local mm = EPC and EPC.MiniMap
        if not mm or not mm:LayerEnabled("quest") then return end
        local point = mm:ResolveTrackedQuestMapPoint029442()
        if point then
            mm.questPosition = point
            pinManager:CreatePin(_G[QUEST_WORLD_PIN_TYPE_029442], point, point.x, point.y)
        end
    end

    local ok = pcall(ZO_WorldMap_AddCustomPin, QUEST_WORLD_PIN_TYPE_029442, addPins, nil, layout, nil)
    if ok and _G[QUEST_WORLD_PIN_TYPE_029442] then
        self.questWorldMapPinRegistered029442 = true
        if type(ZO_WorldMap_SetCustomPinEnabled) == "function" then
            pcall(ZO_WorldMap_SetCustomPinEnabled, _G[QUEST_WORLD_PIN_TYPE_029442], true)
        end
        return true
    end
    return false
end

function M:RefreshQuestWorldMapPin029442()
    self:RegisterQuestWorldMapPin029442()
    self:RegisterSkyshardWorldMapPin029443()
    if self.questWorldMapPinRegistered029442
        and type(ZO_WorldMap_RefreshCustomPinsOfType) == "function"
        and _G[QUEST_WORLD_PIN_TYPE_029442] then
        pcall(ZO_WorldMap_RefreshCustomPinsOfType, _G[QUEST_WORLD_PIN_TYPE_029442])
    end
end

function M:SetQuestMarkerVisible029440(x, y, visible)
    if visible == true and tonumber(x) and tonumber(y) then
        local shown = self:PlacePin(self.questPin, tonumber(x), tonumber(y), 34, true)
        if self.questBadge029440 then self.questBadge029440:SetHidden(true) end
        return shown == true
    end
    if self.questPin then self.questPin:SetHidden(true) end
    if self.questBadge029440 then self.questBadge029440:SetHidden(true) end
    return false
end

function M:GetNativeQuestFallback029440()
    -- When ESO's breadcrumb object has not populated yet, use the nearest
    -- quest/objective pin already captured from the native World Map. This is
    -- read-only and does not trigger a broad map rebuild.
    local px, py = tonumber(self.playerX), tonumber(self.playerY)
    local best, bestD2 = nil, nil
    for i = 1, #(self.nativeMirrorData or {}) do
        local row = self.nativeMirrorData[i]
        if row and (row.isQuest == true or easLooksLikeNativeQuestPin(row.texture, nil, row.pinType))
            and tonumber(row.x) and tonumber(row.y) then
            local dx = px and (tonumber(row.x) - px) or 0
            local dy = py and (tonumber(row.y) - py) or 0
            local d2 = dx * dx + dy * dy
            if best == nil or bestD2 == nil or d2 < bestD2 then
                best, bestD2 = row, d2
            end
        end
    end
    return best
end

function M:RefreshQuestPin()
    self.questPosition = nil
    if not self.questPin or not self:LayerEnabled("quest") then
        self:SetQuestMarkerVisible029440(nil, nil, false)
        return
    end

    -- v0.29.442: first use the exact point also supplied to the real World Map
    -- custom pin. Both maps now render the same normalized ESO map coordinates.
    local sharedPoint029442 = self:ResolveTrackedQuestMapPoint029442()
    if sharedPoint029442 then
        self.questPosition = sharedPoint029442
        self:SetQuestMarkerVisible029440(sharedPoint029442.x, sharedPoint029442.y, true)
        return
    end

    -- Use the exact same live ESO breadcrumb/objective resolver as the quest
    -- direction tracker. This keeps the minimap marker and the tracked objective
    -- synchronized on multi-objective quests instead of choosing a different
    -- incomplete condition.
    if EPC.ActiveQuest and type(EPC.ActiveQuest.GetQuestTrackingSource2513) == "function"
        and type(EPC.ActiveQuest.ResolveQuestSource2516) == "function"
        and type(EPC.ActiveQuest.GetQuestDirectionPosition2512) == "function" then
        local source = EPC.ActiveQuest:GetQuestTrackingSource2513()
        local questIndex = EPC.ActiveQuest:ResolveQuestSource2516(source)
        if questIndex then
            local position = EPC.ActiveQuest:GetQuestDirectionPosition2512(questIndex)
            if position and position.available == true and tonumber(position.x) and tonumber(position.y) then
                local questName = "Quest"
                if type(GetJournalQuestName) == "function" then
                    questName = clean(safe(GetJournalQuestName, "Quest", questIndex), "Quest")
                end
                local qx, qy = tonumber(position.x), tonumber(position.y)
                local currentMapId = tonumber(self.mapId) or 0
                if currentMapId <= 0 and type(GetCurrentMapId) == "function" then
                    currentMapId = tonumber(safe(GetCurrentMapId, 0)) or 0
                end
                -- RequestJournalQuestConditionAssistance returns coordinates for
                -- the objective map. If the player is on another map/zone, those
                -- normalized coordinates cannot be drawn directly on this
                -- minimap. Use the universal coordinates cached by Travel to
                -- project the objective back into the player's current map.
                if tonumber(position.mapId) and tonumber(position.mapId) > 0
                    and currentMapId > 0 and tonumber(position.mapId) ~= currentMapId then
                    local gx, gy = tonumber(position.globalX), tonumber(position.globalY)
                    if gx ~= nil and gy ~= nil then
                        local projectedX, projectedY = easLocalPointForMap(currentMapId, gx, gy)
                        if projectedX ~= nil and projectedY ~= nil then
                            qx, qy = projectedX, projectedY
                        else
                            self:SetQuestMarkerVisible029440(nil, nil, false)
                            return
                        end
                    else
                        self:SetQuestMarkerVisible029440(nil, nil, false)
                        return
                    end
                end
                self.questPosition = {
                    x = qx,
                    y = qy,
                    name = questName,
                    objective = position.targetText,
                }
                self:SetQuestMarkerVisible029440(self.questPosition.x, self.questPosition.y, true)
                return
            end
        end
    end

    -- Fallback to the Travel resolver for clients/maps where live breadcrumbs
    -- have not populated yet. If Travel itself is unavailable, still use the
    -- already-captured native quest snapshot instead of hiding the marker.
    if not EPC.Travel or type(EPC.Travel.GetFocusedQuest) ~= "function" then
        local nativeQuest = self:GetNativeQuestFallback029440()
        if nativeQuest then
            self.questPosition = { x=nativeQuest.x, y=nativeQuest.y, name=nativeQuest.name ~= "" and nativeQuest.name or "Quest" }
            self:SetQuestMarkerVisible029440(nativeQuest.x, nativeQuest.y, true)
        else
            self:SetQuestMarkerVisible029440(nil, nil, false)
        end
        return
    end
    local quest = EPC.Travel:GetFocusedQuest(EPC.lastSnapshot or {})
    local position = quest and quest.position or nil
    if position and position.available == true then
        local x, y = tonumber(position.x), tonumber(position.y)
        local currentMapId = tonumber(self.mapId) or 0
        if currentMapId <= 0 and type(GetCurrentMapId) == "function" then currentMapId = tonumber(safe(GetCurrentMapId, 0)) or 0 end

        local gx, gy = tonumber(position.globalX), tonumber(position.globalY)
        if gx ~= nil and gy ~= nil and currentMapId > 0 then
            local projectedX, projectedY = easLocalPointForMap(currentMapId, gx, gy)
            if projectedX ~= nil and projectedY ~= nil then
                x, y = projectedX, projectedY
            elseif tonumber(position.mapId) ~= currentMapId then
                self:SetQuestMarkerVisible029440(nil, nil, false)
                return
            end
        elseif tonumber(position.mapId) and tonumber(position.mapId) > 0 and tonumber(position.mapId) ~= currentMapId then
            self:SetQuestMarkerVisible029440(nil, nil, false)
            return
        end

        if x ~= nil and y ~= nil then
            self.questPosition = { x=x, y=y, name=clean(quest.name or quest.title or "Quest", "Quest"), objective=quest.objectiveName }
            self:SetQuestMarkerVisible029440(x, y, true)
        else
            self:SetQuestMarkerVisible029440(nil, nil, false)
        end
    else
        local nativeQuest = self:GetNativeQuestFallback029440()
        if nativeQuest then
            self.questPosition = { x=nativeQuest.x, y=nativeQuest.y, name=nativeQuest.name ~= "" and nativeQuest.name or "Quest" }
            self:SetQuestMarkerVisible029440(nativeQuest.x, nativeQuest.y, true)
        else
            self:SetQuestMarkerVisible029440(nil, nil, false)
        end
    end
end

function M:RefreshWaypointPin()
    self.waypointPosition = nil
    if not self.waypointPin or not self:LayerEnabled("waypoint") or type(GetMapPlayerWaypoint) ~= "function" then
        if self.waypointPin then self.waypointPin:SetHidden(true) end
        return
    end
    local x, y = safe(GetMapPlayerWaypoint, nil)
    x = tonumber(x)
    y = tonumber(y)
    if x and y and (x > 0 or y > 0) then
        self.waypointPosition = { x=x, y=y }
        self:PlacePin(self.waypointPin, x, y, 24, true)
    else self.waypointPin:SetHidden(true) end
end

function M:RefreshRallyPin()
    self.rallyPosition = nil
    if not self.rallyPin or not self:LayerEnabled("rally") or type(GetMapRallyPoint) ~= "function" then
        if self.rallyPin then self.rallyPin:SetHidden(true) end
        return
    end
    local x, y = safe(GetMapRallyPoint, nil)
    x = tonumber(x)
    y = tonumber(y)
    if x and y and (x > 0 or y > 0) then
        self.rallyPosition = { x=x, y=y }
        self:PlacePin(self.rallyPin, x, y, 22, true)
    else self.rallyPin:SetHidden(true) end
end

function M:RefreshCompanionPin()
    if not self.companionPin or not self:LayerEnabled("companion") then
        if self.companionPin then self.companionPin:SetHidden(true) end
        return
    end
    if safe(DoesUnitExist, false, "companion") ~= true then self.companionPin:SetHidden(true) return end
    local x, y, heading, shown = safe(GetMapPlayerPosition, nil, "companion")
    if shown == true then
        if type(self.companionPin.SetTextureRotation) == "function" and tonumber(heading) then
            self.companionPin:SetTextureRotation(tonumber(heading), 0.5, 0.5)
        end
        self:PlacePin(self.companionPin, x, y, 18, false)
    else self.companionPin:SetHidden(true) end
end

function M:RefreshGroupPins()
    self.groupLeaderPosition = nil
    self.groupPinState = self.groupPinState or {}
    if not self:LayerEnabled("group") then
        if self.groupPins then for i = 1, #self.groupPins do self.groupPins[i]:SetHidden(true) end end
        return
    end
    local groupSize = safeNumber(GetGroupSize, 0)
    self:EnsureGroupPins(groupSize)
    for i = 1, #self.groupPins do
        local pin = self.groupPins[i]
        if i <= groupSize then
            local unitTag
            if type(ZO_Group_GetUnitTagForGroupIndex) == "function" then unitTag = safe(ZO_Group_GetUnitTagForGroupIndex, nil, i) end
            unitTag = unitTag or ("group" .. tostring(i))
            local exists = safe(DoesUnitExist, false, unitTag) == true
            local isSelf = safe(AreUnitsEqual, false, unitTag, "player") == true
            if exists and not isSelf then
                local x, y, heading, shown = safe(GetMapPlayerPosition, nil, unitTag)
                x, y = tonumber(x), tonumber(y)
                if shown == true and x and y then
                    local leader = safe(IsUnitGroupLeader, false, unitTag) == true
                    if leader then self.groupLeaderPosition = { x=x, y=y } end
                    local dotColor = getGroupRoleDotColor(unitTag)
                    local inSupportRange = safe(IsUnitInGroupSupportRange, true, unitTag) ~= false
                    pin:SetDimensions(leader and 20 or 16, leader and 20 or 16)
                    pin:SetColor(unpack(dotColor))
                    if type(pin.SetTextureRotation) == "function" then pin:SetTextureRotation(0, 0.5, 0.5) end

                    local state = self.groupPinState[i] or {}
                    local drawHeading = tonumber(heading)
                    if state.x and state.y then
                        local dx, dy = x - state.x, y - state.y
                        local movementHeading = headingFromMapDelta(dx, dy)
                        local moved2 = (dx * dx) + (dy * dy)
                        if movementHeading and moved2 > 0.0000000025 then
                            drawHeading = movementHeading
                        elseif state.heading ~= nil and drawHeading == nil then
                            drawHeading = state.heading
                        end
                    end
                    if drawHeading ~= nil then state.heading = drawHeading end
                    state.x, state.y = x, y
                    state.name = clean(safe(GetUnitName, "", unitTag), unitTag)
                    state.leader = leader
                    state.outOfRange = not inSupportRange
                    self.groupPinState[i] = state

                    -- Normal group marker only. Out-of-range members are not
                    -- given a glow or an artificial minimap-edge locator.
                    self:PlacePin(pin, x, y, leader and 20 or 16, false)
                else
                    pin:SetHidden(true)
                    self.groupPinState[i] = nil
                end
            else
                pin:SetHidden(true)
                self.groupPinState[i] = nil
            end
        else
            pin:SetHidden(true)
            self.groupPinState[i] = nil
        end
    end
end

function M:RenderServicePins()
    if not self.servicePins then return end
    local used = 0
    for i = 1, #(self.serviceData or {}) do
        local serviceCap = self.roamingVisualBudget029315 == true and ROAMING_SERVICE_CAP_029315 or #self.servicePins
        if used >= math.min(#self.servicePins, serviceCap) then break end
        local data = self.serviceData[i]
        -- Service pins are map-locked in 0.29.314. Render them once in full-map
        -- coordinates and let the viewport clip them; never re-anchor per movement.
        if data and tonumber(data.x) and tonumber(data.y) then
            used = used + 1
            local pin = self.servicePins[used]
            local backing = self.serviceBackings and self.serviceBackings[used] or nil
            local isStable = data.kind == "stable"
            local size = isStable and 28 or 24
            local backingSize = isStable and 36 or 30

            if backing then
                -- Never draw the generic white/custom-destination backing.
                -- Only the real service icon should be visible on the minimap.
                backing:SetHidden(true)
            end

            pin:SetDimensions(size, size)
            -- Stable uses a known ESO mount texture; other learned services keep
            -- their captured/specific texture with a reliable fallback.
            local texture = ((data.icon and data.icon ~= "") and data.icon or getServiceFallbackIcon(data.kind))
            if not texture or texture == "" or texture == POI_FALLBACK_TEXTURE or texture == WAYPOINT_TEXTURE then
                pin:SetHidden(true)
            else
                pin:SetTexture(texture)
            -- Reset texture state because pooled minimap pins may previously have
            -- displayed atlas-like ESO textures.  Packaged service icons use the
            -- full 0..1 texture surface.
            if type(pin.SetTextureCoords) == "function" then pin:SetTextureCoords(0, 1, 0, 1) end
            if type(pin.SetBlendMode) == "function" then pin:SetBlendMode(TEX_BLEND_MODE_ALPHA) end
                pin:SetColor(1, 1, 1, 1)
                pin:SetDrawLevel(isStable and 90 or 82)
                self:PlacePin(pin, data.x, data.y, size, true)
            end
        end
    end
    self.lastServiceRenderUsed029319 = used
    for i = used + 1, #self.servicePins do self.servicePins[i]:SetHidden(true) end
    if self.serviceBackings then
        for i = used + 1, #self.serviceBackings do self.serviceBackings[i]:SetHidden(true) end
    end
end

function M:RenderMerchantPins()
    if not self.merchantPins then return end
    local used = 0
    for i = 1, #(self.merchantData or {}) do
        local merchantCap = self.roamingVisualBudget029315 == true and ROAMING_MERCHANT_CAP_029315 or #self.merchantPins
        if used >= math.min(#self.merchantPins, merchantCap) then break end
        local data = self.merchantData[i]
        -- Merchant pins ride the same static map canvas as POIs/wayshrines.
        if data and tonumber(data.x) and tonumber(data.y) then
            used = used + 1
            local pin = self.merchantPins[used]
            local size = data.learned and 26 or 22
            pin:SetDimensions(size, size)
            if data.icon and data.icon ~= "" then pin:SetTexture(data.icon) else pin:SetTexture(POI_FALLBACK_TEXTURE) end
            -- Learned stores use the actual representative ESO store-item icon
            -- discovered when the player opened that store. Keep it full-color
            -- so a blacksmith, alchemist, clothier, etc. are visually distinct.
            if data.learned then
                pin:SetColor(1, 1, 1, 1)
            else
                pin:SetColor(1.00, 0.82, 0.28, 1.00)
            end
            self:PlacePin(pin, data.x, data.y, size, true)
        end
    end
    self.lastMerchantRenderUsed029319 = used
    for i = used + 1, #self.merchantPins do self.merchantPins[i]:SetHidden(true) end
end

function M:RenderPOIPins()
    if not self.poiPins then return end
    if not self:LayerEnabled("pois") then
        self.lastPOIRenderUsed029318 = 0
        for i = 1, #self.poiPins do self.poiPins[i]:SetHidden(true) end
        return
    end

    local maxPins = math.max(24, math.min(POI_RENDER_HARD_CAP_029314, tonumber(EPC.saved.miniMapPOIMax) or 160))
    if self.roamingVisualBudget029315 == true then maxPins = math.min(maxPins, ROAMING_POI_CAP_029315) end
    local used = 0
    local nativePvE = not self:IsPvPIconOnlyMode()

    for i = 1, #(self.poiData or {}) do
        if used >= maxPins then break end
        local data = self.poiData[i]
        local texture = self:GetNativePvEMapPinTexture(data.icon, data.pinType)

            -- Never replace a missing ESO icon with the generic white/custom
            -- destination diamond.  This keeps the overland map looking like
            -- ESO's own map rather than a field of addon fallback markers.
            if texture then
                used = used + 1
                local pin = self.poiPins[used]
                local size = data.nearby and 21 or (data.isCompletion and 19 or 18)
                pin:SetDimensions(size, size)
                pin:SetTexture(texture)

                if nativePvE then
                    -- Match the PvP implementation: let ESO's native texture
                    -- encode POI type/state and leave the artwork untinted.
                    -- Unlike the old minimap pass, discovered overland POIs are
                    -- no longer hidden just because they are not nearby.
                    pin:SetColor(1, 1, 1, 1)
                    self:PlacePin(pin, data.x, data.y, size, false)
                else
                    -- Preserve the established PvP behavior so Cyrodiil remains
                    -- focused on keeps, scrolls, and transit-network ownership.
                    if data.discovered == true and data.nearby ~= true and data.learned ~= true and not self:IsLabeledMapMode() then
                        pin:SetHidden(true)
                        used = used - 1
                    else
                        if data.discovered ~= true then
                            pin:SetColor(0.98, 0.72, 0.18, 0.98)
                        elseif data.nearby then
                            pin:SetColor(0.24, 0.56, 0.97, 0.94)
                        else
                            pin:SetColor(1, 1, 1, 1)
                        end
                        self:PlacePin(pin, data.x, data.y, size, false)
                    end
                end
            end
    end

    self.lastPOIRenderUsed029318 = used
    for i = used + 1, #self.poiPins do self.poiPins[i]:SetHidden(true) end
end

function M:CaptureTrailPoint(force)
    if not self:LayerEnabled("trail") or not self.playerShown then return false end
    self.trailData = self.trailData or {}
    local x = tonumber(self.playerX)
    local y = tonumber(self.playerY)
    if not x or not y then return false end
    local last = self.trailData[#self.trailData]
    if not force and last then
        local dx = x - last.x
        local dy = y - last.y
        if (dx * dx) + (dy * dy) < 0.000010 then return false end
    end
    self.trailData[#self.trailData + 1] = { x=x, y=y }
    local maxPoints = 10
    while #self.trailData > maxPoints do table.remove(self.trailData, 1) end
    return true
end

function M:RenderTrail()
    self:EnsureTrailPins(10)
    if not self:LayerEnabled("trail") then
        for i = 1, #self.trailPins do self.trailPins[i]:SetHidden(true) end
        return
    end
    local data = self.trailData or {}
    local total = #data
    local used = 0
    for i = 1, total do
        local point = data[i]
        used = used + 1
        local pin = self.trailPins[used]
        local frac = total > 1 and (i / total) or 1
        local size = 4 + math.floor(frac * 3)
        pin:SetDimensions(size, size)
        pin:SetColor(0.70, 0.82, 0.94, 0.18 + (0.42 * frac))
        self:PlacePin(pin, point.x, point.y, size, false)
    end
    for i = used + 1, #self.trailPins do self.trailPins[i]:SetHidden(true) end
end

function M:UpdateContextText(force)
    -- Normal overland mode stays icon-focused. Object labels for special game
    -- modes are rendered separately by RenderModeLabels().
    if self.modeLabel then self.modeLabel:SetHidden(true) end
    if self.zoneLabel then self.zoneLabel:SetHidden(true) end
    if self.coordsLabel then self.coordsLabel:SetHidden(true) end
    if self.contextLabel then self.contextLabel:SetHidden(true) end
    if self.northLabel then self.northLabel:SetHidden(true) end
    if self.eastLabel then self.eastLabel:SetHidden(true) end
    if self.southLabel then self.southLabel:SetHidden(true) end
    if self.westLabel then self.westLabel:SetHidden(true) end
end

function M:PulsePriorityPins()
    local t = nowSeconds()
    local scale = 1.0 + (0.06 * ((math.sin(t * 5.0) + 1) * 0.5))
    if self.questPin and not self.questPin:IsHidden() and self.questPin.SetScale then self.questPin:SetScale(scale) end
    if self.waypointPin and not self.waypointPin:IsHidden() and self.waypointPin.SetScale then self.waypointPin:SetScale(scale) end
end

-- v0.29.313: update only the player marker. This is intentionally tiny: one
-- position read, at most two anchors, and texture rotation. It must never touch
-- POI pools, hidden map providers, quest scans, or static map layers.
function M:ApplyRoamingVisualBudget029315(moving)
    moving = moving == true
    if self.roamingVisualBudget029315 == moving then return end
    self.roamingVisualBudget029315 = moving

    -- v0.29.316: never delete/static-hide the data merely because the player is
    -- moving. v0.29.319 only changes which already-populated controls are attached
    -- to the moving canvas, and restores the wider nearby set as soon as movement
    -- settles.
    self.restoreRoamingPins029315 = false
    self.lastStaticCullAt029318 = nil
    if self.CullStaticMapPins029318 and self.staticPinLayer then
        self:CullStaticMapPins029318(true)
    end
end

-- v0.29.374: the player marker should never be visually cut by the ornate frame
-- or round viewport mask. When the world-map camera clamps near a zone edge, keep
-- the arrow and glow slightly inside the safe visible boundary instead of letting
-- the texture clip away and appear to shrink/disappear.
function M:ClampPlayerMarkerToVisibleArea029374(px, py)
    px, py = tonumber(px), tonumber(py)
    if px == nil or py == nil or not self.size then return px, py, false end

    local markerSize = math.max(tonumber(self:GetPlayerPinSize()) or 16, tonumber(self:GetPlayerGlowSize()) or 20)
    local margin = math.max(10, markerSize * 0.60)
    local style = tostring(self.appliedVisualStyle or "")
    local frameGuard = string.find(style, "FANTASY_", 1, true) and 8 or 4
    local adjusted = false

    if self.circularStyle == true then
        local center = self.size * 0.5
        local dx = px - center
        local dy = py - center
        local distance = math.sqrt((dx * dx) + (dy * dy))
        local radius = math.max(12, center - margin - frameGuard)
        if distance > radius and distance > 0.0001 then
            local scale = radius / distance
            px = center + (dx * scale)
            py = center + (dy * scale)
            adjusted = true
        end
    else
        local minX = margin + frameGuard
        local maxX = self.size - margin - frameGuard
        local minY = margin + frameGuard + 2
        local maxY = self.size - margin - frameGuard - 2
        local oldX, oldY = px, py
        px = clamp(px, minX, maxX)
        py = clamp(py, minY, maxY)
        adjusted = (px ~= oldX) or (py ~= oldY)
    end

    return px, py, adjusted
end

-- v0.29.315: one lightweight motion path owns BOTH the map camera and player
-- marker. 0.29.313 updated the arrow at 33 ms while the map camera moved at
-- 100 ms, so the two coordinate spaces repeatedly drifted apart and snapped
-- back together. That was the visible arrow skip. This path samples the player,
-- smooths position/heading with frame-time based interpolation, pans only the
-- two parent map controls, and never touches POI/provider/quest data.
function M:SetStaticPinParked029319(pin, parked)
    if not pin or pin.easMapLocked029312 ~= true then return end
    local dormant = self.staticPinDormantLayer029319
    if parked == true then
        if pin.easMapParked029319 == true then return end
        pin.easMapParked029319 = true
        pin.easMapCullHidden029318 = true
        pin:SetHidden(true)
        if dormant and type(pin.SetParent) == "function" then
            pin:ClearAnchors()
            pin:SetParent(dormant)
            pin.easMapAnchorKey029312 = nil
        end
        return
    end

    if pin.easMapParked029319 ~= true then
        if pin.easMapCullHidden029318 == true then
            pin:SetHidden(false)
            pin.easMapCullHidden029318 = false
        end
        return
    end

    pin.easMapParked029319 = false
    if self.staticPinLayer and type(pin.SetParent) == "function" then
        pin:SetParent(self.staticPinLayer)
    end
    local x, y = tonumber(pin.easMapX029318), tonumber(pin.easMapY029318)
    if x and y and self.fullMapWidth and self.fullMapHeight then
        local ax, ay = x * self.fullMapWidth, y * self.fullMapHeight
        pin:ClearAnchors()
        pin:SetAnchor(CENTER, self.staticPinLayer, TOPLEFT, ax, ay)
        pin.easMapAnchorKey029312 = string.format("%.5f:%.5f:%d:%d", x, y, math.floor(self.fullMapWidth + 0.5), math.floor(self.fullMapHeight + 0.5))
    end
    if pin.easMapCullHidden029318 == true then
        pin:SetHidden(false)
        pin.easMapCullHidden029318 = false
    end
end

function M:CullStaticMapPins029318(force)
    if not self.playerShown or not self.fullMapWidth or not self.fullMapHeight then return end
    local nowMs = type(GetFrameTimeMilliseconds) == "function" and (tonumber(GetFrameTimeMilliseconds()) or 0) or (nowSeconds() * 1000)
    local moving = nowMs < (tonumber(self.motionMovingUntil029315) or 0)
    local cullGap = moving and ROAMING_STATIC_CULL_MS_029319 or STATIONARY_STATIC_CULL_MS_029319
    if force ~= true and self.lastStaticCullAt029318 and (nowMs - self.lastStaticCullAt029318) < cullGap then return end
    self.lastStaticCullAt029318 = nowMs

    local cx = tonumber(self.viewPlayerX) or tonumber(self.playerX) or 0.5
    local cy = tonumber(self.viewPlayerY) or tonumber(self.playerY) or 0.5
    -- v0.29.341: do not rescan every static pin pool just because the cull timer
    -- elapsed. Require meaningful camera travel as well. This removes recurring
    -- 300 ms traversal spikes while running through dense POI areas.
    if force ~= true and self.lastStaticCullCenterX029341 and self.lastStaticCullCenterY029341 then
        local dxPx = math.abs(cx - self.lastStaticCullCenterX029341) * self.fullMapWidth
        local dyPx = math.abs(cy - self.lastStaticCullCenterY029341) * self.fullMapHeight
        if dxPx < 20 and dyPx < 20 then return end
    end
    self.lastStaticCullCenterX029341, self.lastStaticCullCenterY029341 = cx, cy
    -- Smaller roaming prefetch keeps the moving hierarchy lean. At rest use a
    -- wider margin so nearby icons are already attached before the next move.
    local marginScale = moving and 0.58 or 0.72
    local halfX = math.min(0.5, (self.size * marginScale) / self.fullMapWidth)
    local halfY = math.min(0.5, (self.size * marginScale) / self.fullMapHeight)

    local poiLimit = tonumber(self.lastPOIRenderUsed029318) or 0
    local nativeLimit = tonumber(self.lastNativeMirrorUsed029318) or 0
    local shrineLimit = #(self.shrineData or {})
    local skyshardLimit = #(self.skyshardData or {})
    local merchantLimit = tonumber(self.lastMerchantRenderUsed029319) or 0
    local trailLimit = #(self.trailData or {})
    local groups = {
        { pool = self.poiPins, limit = poiLimit, cap = moving and ROAMING_VISIBLE_POI_CAP_029319 or poiLimit },
        { pool = self.nativeMirrorPins, limit = nativeLimit, cap = moving and ROAMING_VISIBLE_NATIVE_CAP_029319 or nativeLimit },
        { pool = self.shrinePins, limit = shrineLimit, cap = moving and ROAMING_VISIBLE_SHRINE_CAP_029319 or shrineLimit },
        { pool = self.skyshardPins, limit = skyshardLimit, cap = moving and math.min(24, skyshardLimit) or skyshardLimit },
        { pool = self.merchantPins, limit = merchantLimit, cap = moving and ROAMING_VISIBLE_MERCHANT_CAP_029319 or merchantLimit },
        -- Crafting/service stations stay attached to the static map layer. They are
        -- few in number, and parking/re-parenting them while moving made learned
        -- station icons appear to blink/jump or lag behind the map.
        { pool = self.trailPins, limit = trailLimit, cap = trailLimit },
    }

    for _, group in ipairs(groups) do
        local pool = group.pool
        local limit = math.max(0, tonumber(group.limit) or 0)
        local visibleCap = math.max(0, tonumber(group.cap) or limit)
        local visibleUsed = 0
        if type(pool) == "table" then
            local activeLimit = math.min(#pool, limit)
            for i = 1, activeLimit do
                local pin = pool[i]
                if pin and pin.easMapLocked029312 == true then
                    local x, y = tonumber(pin.easMapX029318), tonumber(pin.easMapY029318)
                    if x and y then
                        local inBudget = math.abs(x - cx) <= halfX and math.abs(y - cy) <= halfY
                        local shouldAttach = inBudget and visibleUsed < visibleCap
                        if shouldAttach then
                            visibleUsed = visibleUsed + 1
                            self:SetStaticPinParked029319(pin, false)
                        else
                            self:SetStaticPinParked029319(pin, true)
                        end
                    else
                        self:SetStaticPinParked029319(pin, true)
                    end
                end
            end
            -- Pool controls above the currently rendered count are otherwise
            -- hidden but still descendants of the moving layer. Park them too;
            -- PlacePin() automatically reattaches one when a later refresh uses it.
            for i = activeLimit + 1, #pool do
                self:SetStaticPinParked029319(pool[i], true)
            end
        end
    end
end

function M:UpdatePlayerMarkerFast(force, useCachedPosition)
    if not self.playerShown or not self.viewport or not self.fullMapWidth or not self.fullMapHeight then return end

    local nowMs = type(GetFrameTimeMilliseconds) == "function" and (tonumber(GetFrameTimeMilliseconds()) or 0) or (nowSeconds() * 1000)
    local lastMs = tonumber(self.lastFastMotionAt029315) or nowMs
    local dt = math.max(0.001, math.min(0.050, (nowMs - lastMs) / 1000))
    self.lastFastMotionAt029315 = nowMs

    -- v0.29.341: ESO's normalized map position does not need to be queried on
    -- every 16 ms marker tick. Sample it at the same fixed cadence as the map
    -- camera, then interpolate the cached sample between updates. This halves
    -- the movement-time map-position API traffic and removes the old velocity
    -- prediction overshoot/correction cycle that could make the marker tremble.
    local positionDue = force == true
        or self.lastMapPositionSampleAt029341 == nil
        or (nowMs - self.lastMapPositionSampleAt029341) >= MINIMAP_POSITION_SAMPLE_MS_029341

    if useCachedPosition ~= true and positionDue then
        local x, y, heading, shown = safe(GetMapPlayerPosition, nil, "player")
        if shown == true and tonumber(x) and tonumber(y) then
            self.lastMapPositionSampleAt029341 = nowMs
            local nx, ny = clamp(x, 0, 1), clamp(y, 0, 1)
            local lx, ly = tonumber(self.lastMotionMapX029314), tonumber(self.lastMotionMapY029314)
            if lx and ly then
                local mdx, mdy = nx - lx, ny - ly
                if (mdx * mdx) + (mdy * mdy) >= 0.0000000004 then
                    self.lastPlayerMotionAt029314 = nowSeconds()
                    self.motionMovingUntil029315 = nowMs + ROAMING_MOTION_GRACE_MS_029315
                end
            end
            self.lastMotionMapX029314, self.lastMotionMapY029314 = nx, ny
            self.playerShown = true
            self.playerX, self.playerY = nx, ny
            if tonumber(self.mapId) and self.mapId > 0 then
                self.lastGameplayMapId = self.mapId
                self.lastGameplayX = nx
                self.lastGameplayY = ny
            end
            local sampledHeading = tonumber(heading)
            if sampledHeading ~= nil then
                local previousHeading = tonumber(self.playerHeading)
                if previousHeading == nil then
                    self.playerHeading = sampledHeading
                else
                    local headingDelta = sampledHeading - previousHeading
                    while headingDelta > math.pi do headingDelta = headingDelta - (math.pi * 2) end
                    while headingDelta < -math.pi do headingDelta = headingDelta + (math.pi * 2) end
                    -- Ignore sub-degree camera/player-heading noise. Accumulated
                    -- real turning still crosses the threshold immediately, while
                    -- standing/running straight no longer makes the arrow twitch.
                    if math.abs(headingDelta) >= 0.0025 then self.playerHeading = sampledHeading end
                end
            elseif self.playerHeading == nil then
                self.playerHeading = 0
            end
        elseif self.playerX == nil or self.playerY == nil then
            return
        end
    elseif self.playerX == nil or self.playerY == nil then
        return
    end

    local targetX = tonumber(self.playerX)
    local targetY = tonumber(self.playerY)
    if not targetX or not targetY then return end
    local targetHeading = tonumber(self.playerHeading) or 0

    if force == true or self.motionDisplayX029315 == nil or self.motionDisplayY029315 == nil then
        self.motionDisplayX029315, self.motionDisplayY029315 = targetX, targetY
        self.motionDisplayHeading029315 = targetHeading
    else
        local follow = 1 - math.exp(-dt / MOTION_SMOOTH_TIME_S_029315)
        self.motionDisplayX029315 = self.motionDisplayX029315 + ((targetX - self.motionDisplayX029315) * follow)
        self.motionDisplayY029315 = self.motionDisplayY029315 + ((targetY - self.motionDisplayY029315) * follow)
        local h = tonumber(self.motionDisplayHeading029315) or targetHeading
        local delta = targetHeading - h
        while delta > math.pi do delta = delta - (math.pi * 2) end
        while delta < -math.pi do delta = delta + (math.pi * 2) end
        h = h + (delta * follow)
        if h < 0 then h = h + (math.pi * 2) elseif h >= math.pi * 2 then h = h - (math.pi * 2) end
        self.motionDisplayHeading029315 = h
    end

    local displayX = self.motionDisplayX029315
    local displayY = self.motionDisplayY029315
    local displayHeading = tonumber(self.motionDisplayHeading029315) or targetHeading

    -- The map tree still pans at a fixed 30 Hz. The marker itself no longer
    -- carries the camera's inter-frame residual in the ordinary interior of a
    -- map: that old compensation made it drift a fraction of a pixel and snap
    -- back every camera pan. Keep the marker exactly centered while the camera
    -- can follow; only let it move on an axis when the map boundary clamps that
    -- axis and the player genuinely has to travel away from center.
    local halfVisibleX = math.min(0.5, (self.size * 0.5) / self.fullMapWidth)
    local halfVisibleY = math.min(0.5, (self.size * 0.5) / self.fullMapHeight)
    local desiredViewX = clamp(displayX, halfVisibleX, 1.0 - halfVisibleX)
    local desiredViewY = clamp(displayY, halfVisibleY, 1.0 - halfVisibleY)

    local cameraX = tonumber(self.motionCameraX029318)
    local cameraY = tonumber(self.motionCameraY029318)
    local panDue = force == true or cameraX == nil or cameraY == nil
        or self.lastCameraPanAt029318 == nil
        or (nowMs - self.lastCameraPanAt029318) >= MINIMAP_CAMERA_PAN_MS_029318
    if panDue then
        cameraX, cameraY = desiredViewX, desiredViewY
        self.motionCameraX029318, self.motionCameraY029318 = cameraX, cameraY
        self.lastCameraPanAt029318 = nowMs
        local offsetX = (self.size * 0.5) - (cameraX * self.fullMapWidth)
        local offsetY = (self.size * 0.5) - (cameraY * self.fullMapHeight)
        local cameraMoved029319 = force == true or self.lastPanOffsetX029312 == nil
            or math.abs(offsetX - self.lastPanOffsetX029312) >= 0.20
            or math.abs(offsetY - self.lastPanOffsetY029312) >= 0.20
        if cameraMoved029319 then
            self.lastPanOffsetX029312, self.lastPanOffsetY029312 = offsetX, offsetY
            self.tileContainer:ClearAnchors()
            self.tileContainer:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, offsetX, offsetY)
            if self.staticPinLayer then
                self.staticPinLayer:ClearAnchors()
                self.staticPinLayer:SetAnchor(TOPLEFT, self.viewport, TOPLEFT, offsetX, offsetY)
            end
        end
        self.viewPlayerX, self.viewPlayerY = cameraX, cameraY
        if cameraMoved029319 or force == true then
            self:CullStaticMapPins029318(force == true)
        end
    else
        cameraX = cameraX or desiredViewX
        cameraY = cameraY or desiredViewY
        self.viewPlayerX, self.viewPlayerY = cameraX, cameraY
    end

    local center = self.size * 0.5
    -- Use the actively displayed camera center rather than the next desired one.
    -- During the short interval between camera pans this keeps the player marker
    -- in the correct place relative to the currently visible map, which prevents
    -- it from getting pushed into the frame edge and looking clipped.
    local activeViewX = tonumber(self.viewPlayerX) or cameraX or desiredViewX
    local activeViewY = tonumber(self.viewPlayerY) or cameraY or desiredViewY
    local xIsBoundaryClamped = math.abs(activeViewX - displayX) > 0.0000001
    local yIsBoundaryClamped = math.abs(activeViewY - displayY) > 0.0000001
    local playerScreenX = xIsBoundaryClamped and (center + ((displayX - activeViewX) * self.fullMapWidth)) or center
    local playerScreenY = yIsBoundaryClamped and (center + ((displayY - activeViewY) * self.fullMapHeight)) or center
    playerScreenX, playerScreenY = self:ClampPlayerMarkerToVisibleArea029374(playerScreenX, playerScreenY)

    local lastHeading = tonumber(self.lastFastPlayerHeading029313)
    local headingChanged = force == true or lastHeading == nil
    if not headingChanged then
        local d = math.abs(displayHeading - lastHeading)
        if d > math.pi then d = (math.pi * 2) - d end
        headingChanged = d >= 0.0012
    end
    local moved = force == true or self.lastFastPlayerX029313 == nil
        or math.abs(playerScreenX - self.lastFastPlayerX029313) >= 0.10
        or math.abs(playerScreenY - self.lastFastPlayerY029313) >= 0.10

    if self.playerGlow then
        local glowSize = self:GetPlayerGlowSize()
        if force == true or self.lastFastGlowSize029313 ~= glowSize then
            self.lastFastGlowSize029313 = glowSize
            if type(self.playerGlow.SetDimensions) == "function" then self.playerGlow:SetDimensions(glowSize, glowSize) end
        end
        if type(self.playerGlow.SetScale) == "function" then self.playerGlow:SetScale(1) end
        if type(self.playerGlow.SetTextureCoords) == "function" then self.playerGlow:SetTextureCoords(0, 1, 0, 1) end
        if headingChanged and type(self.playerGlow.SetTextureRotation) == "function" then
            self.playerGlow:SetTextureRotation(displayHeading, 0.5, 0.5)
        end
        if moved then
            self.playerGlow:ClearAnchors()
            self.playerGlow:SetAnchor(CENTER, self.viewport, TOPLEFT, playerScreenX, playerScreenY)
        end
        self.playerGlow:SetHidden(false)
    end

    if self.playerPin then
        local playerSize = self:GetPlayerPinSize()
        if force == true or self.lastFastPlayerSize029313 ~= playerSize then
            self.lastFastPlayerSize029313 = playerSize
            if type(self.playerPin.SetDimensions) == "function" then self.playerPin:SetDimensions(playerSize, playerSize) end
        end
        if type(self.playerPin.SetScale) == "function" then self.playerPin:SetScale(1) end
        if type(self.playerPin.SetTextureCoords) == "function" then self.playerPin:SetTextureCoords(0, 1, 0, 1) end
        if headingChanged and type(self.playerPin.SetTextureRotation) == "function" then
            self.playerPin:SetTextureRotation(displayHeading, 0.5, 0.5)
        end
        if moved then
            self.playerPin:ClearAnchors()
            self.playerPin:SetAnchor(CENTER, self.viewport, TOPLEFT, playerScreenX, playerScreenY)
        end
        self.playerPin:SetHidden(false)
    end

    if moved then self.lastFastPlayerX029313, self.lastFastPlayerY029313 = playerScreenX, playerScreenY end
    if headingChanged then self.lastFastPlayerHeading029313 = displayHeading end

    local moving = nowMs < (tonumber(self.motionMovingUntil029315) or 0)
    self:ApplyRoamingVisualBudget029315(moving)
end

function M:UpdatePanAndPins(forceStatic)
    if not self.playerShown or not self.fullMapWidth or not self.fullMapHeight then return end

    -- The 16 ms motion path owns position, camera pan, and arrow rotation. A
    -- forced rebuild snaps that shared motion state immediately; ordinary slow
    -- pulses must not move the camera a second time.
    if forceStatic == true then
        self:UpdatePlayerMarkerFast(true, false)
    end

    local pinNow029312 = nowSeconds()
    local frameNowMs029318 = type(GetFrameTimeMilliseconds) == "function" and (tonumber(GetFrameTimeMilliseconds()) or 0) or (pinNow029312 * 1000)
    local moving029318 = frameNowMs029318 < (tonumber(self.motionMovingUntil029315) or 0)
    local edgeGap029318 = moving029318 and 1.25 or 0.75
    local dynamicGap029318 = moving029318 and 0.85 or 0.60
    local pvpGap029318 = moving029318 and 1.50 or 1.00
    if forceStatic == true or not self.lastEdgePinLayoutAt029312 or (pinNow029312 - self.lastEdgePinLayoutAt029312) >= edgeGap029318 then
        self.lastEdgePinLayoutAt029312 = pinNow029312
        self:RenderTreasureLocatorPins()
        self:RenderAntiquityPins()
    end
    if forceStatic == true or not self.lastDynamicPinLayoutAt029312 or (pinNow029312 - self.lastDynamicPinLayoutAt029312) >= dynamicGap029318 then
        self.lastDynamicPinLayoutAt029312 = pinNow029312
        self:RefreshWaypointPin()
        self:RefreshQuestPin()
        self:RefreshRallyPin()
        self:RefreshGroupPins()
        self:RefreshCompanionPin()
    end
    if forceStatic == true or not self.lastPvPLineLayoutAt029312 or (pinNow029312 - self.lastPvPLineLayoutAt029312) >= pvpGap029318 then
        self.lastPvPLineLayoutAt029312 = pinNow029312
        self:RenderPvPTransitLines()
    end
    if moving029318 then
        if self.priorityPulsePaused029318 ~= true then
            self.priorityPulsePaused029318 = true
            if self.questPin and self.questPin.SetScale then self.questPin:SetScale(1) end
            if self.waypointPin and self.waypointPin.SetScale then self.waypointPin:SetScale(1) end
        end
    else
        self.priorityPulsePaused029318 = false
        self:PulsePriorityPins()
    end
end

function M:Refresh(force)
    if not self.frame or not EPC.saved then return end
    self:SyncESOCompassVisibility()
    local show = EPC.saved.showMiniMap ~= false or self.layoutMode == true
    if self.layoutMode ~= true and EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("miniMapVisibility") end
    local mapOpen = self:IsWorldMapShowing()
    local menuOpen = self:IsMenuShowing()
    if mapOpen then show = false
    elseif menuOpen and not self.layoutMode then show = false end
    self.frame:SetHidden(not show)
    if not show then return end

    self.frame:SetMouseEnabled(self:IsInteractive())
    self.frame:SetMovable(self.layoutMode == true)
    self:ApplySizeAndStyle()
    if self:SyncToPlayerMap(force == true) then
        self:UpdatePanAndPins(force == true)
    else
        self.statusLabel:SetHidden(true)
    end
end

function M:RegisterEvents()
    local prefix = EPC.name .. "_MiniMap"

    -- LibMapData is now the single owner of player-map transitions. The Suite
    -- listens and redraws instead of forcing map changes itself.
    local function syncMapTransitionNow()
        self.needsSync = true
        self.staticPinsDirty = true
        -- The hidden native pump can legitimately trigger OnWorldMapChanged as
        -- part of ESO's own update function. Do not recursively start another
        -- transition/pump from that internally generated callback.
        if self.hiddenNativeMapPumpInProgress == true then return end

        -- LibMapData and ESO can report the same handoff through several
        -- callbacks on adjacent frames. Coalesce that burst so one zone change
        -- does not rebuild the tile grid several times. The scheduled retries
        -- below still catch a mapId that becomes valid a few frames later.
        local signalAt = nowSeconds()
        if self.lastMapTransitionSignal and signalAt - self.lastMapTransitionSignal < 0.20 then return end
        self.lastMapTransitionSignal = signalAt

        self.mapTransitionToken = (tonumber(self.mapTransitionToken) or 0) + 1
        local token = self.mapTransitionToken

        -- Never carry static pins/trails from the previous area across a travel
        -- handoff. ESO and LibMapData can publish the new map on adjacent frames,
        -- so retry briefly until the verified player map is ready.
        self.trailData = {}
        self:ClearStaticPinsForMapTransition()

        local function attempt()
            if token ~= self.mapTransitionToken then return end
            if not self.frame or self:IsWorldMapShowing() then return end
            if self.hiddenMapContextSyncInProgress == true then
                self.needsSync = true
                self.staticPinsDirty = true
                return
            end
            self:TrySyncHiddenPlayerMap("transition")
            local synced = self:SyncToPlayerMap(true)
            self.needsSync = not synced
            if synced then
                -- v0.29.311: prime the expensive hidden native map exactly once
                -- for this resolved transition. All scheduled attempts share this
                -- token; once the map is valid, invalidate the remaining retries.
                local resolvedMapId = tonumber(self.mapId) or 0
                local primeNow = nowSeconds()
                if resolvedMapId > 0 and (tonumber(self.lastTransitionPrimedMapId029311) ~= resolvedMapId
                    or primeNow - (tonumber(self.lastTransitionPrimeAt029311) or 0) >= 2.0) then
                    self.lastTransitionPrimedMapId029311 = resolvedMapId
                    self.lastTransitionPrimeAt029311 = primeNow
                    self.hiddenPinRefreshRequested = true
                end
                -- Keep the handoff light: update the visible map/player first,
                -- then spread static/provider work over later frames.
                self:UpdatePanAndPins(false)
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if tonumber(self.mapId) ~= resolvedMapId then return end
                        self:RefreshStaticPins()
                    end, 120)
                    zo_callLater(function()
                        if tonumber(self.mapId) ~= resolvedMapId then return end
                        if self.hiddenPinRefreshRequested and self:PrimeHiddenWorldMapPins("transition", true) then
                            self.hiddenPinRefreshRequested = false
                        end
                    end, 320)
                    zo_callLater(function()
                        if tonumber(self.mapId) ~= resolvedMapId then return end
                        self:ScheduleLiveNativeMirrorRefresh(resolvedMapId)
                    end, 520)
                else
                    self:RefreshStaticPins()
                end
                if self.mapTransitionToken == token then self.mapTransitionToken = token + 1 end
            end
        end

        -- Never do the expensive transition work in the same frame as ESO's
        -- zone/POI boundary callback. Town, boss-area and linked-world-position
        -- borders can fire several map signals while the player is moving.
        -- Give LibMapData/ESO one frame to settle, then verify that the actual
        -- player map changed before rebuilding tiles/providers.
        local function guardedAttempt()
            if token ~= self.mapTransitionToken then return end
            local currentMapId = type(GetCurrentMapId) == "function" and (tonumber(GetCurrentMapId()) or 0) or 0
            local renderedMapId = tonumber(self.mapId) or 0
            if currentMapId > 0 and renderedMapId > 0 and currentMapId == renderedMapId then
                -- Same map: this was only a POI/subzone signal. The cheap POI
                -- layer can refresh later; do not clear tiles or wake hidden map.
                self.needsSync = false
                self.poiRefreshDirty029313 = true
                self.lastPOIEventAt029313 = nowSeconds()
                if self.mapTransitionToken == token then self.mapTransitionToken = token + 1 end
                return
            end
            attempt()
        end

        if type(zo_callLater) == "function" then
            for _, delay in ipairs({90, 220, 500, 1000, 2000}) do
                zo_callLater(guardedAttempt, delay)
            end
        else
            guardedAttempt()
        end
    end

    if LMD and type(LMD.RegisterCallback) == "function" and LMD.callbackType then
        local function onMapDataChanged()
            if self.hiddenNativeMapPumpInProgress == true then
                self.needsSync = true
                self.staticPinsDirty = true
                return
            end
            if self.hiddenMapContextSyncInProgress == true then
                self.needsSync = true
                self.staticPinsDirty = true
                return
            end
            syncMapTransitionNow()
        end
        if LMD.callbackType.OnWorldMapChanged then
            LMD:RegisterCallback(LMD.callbackType.OnWorldMapChanged, onMapDataChanged)
        end
        if LMD.callbackType.EVENT_ZONE_CHANGED then
            LMD:RegisterCallback(LMD.callbackType.EVENT_ZONE_CHANGED, onMapDataChanged)
        end
        -- Entering/leaving towns and other linked sub-maps often does not fire a
        -- normal zone change. LibMapData exposes this callback specifically for
        -- those player-position map transitions, so the minimap must follow it.
        if LMD.callbackType.EVENT_LINKED_WORLD_POSITION_CHANGED then
            LMD:RegisterCallback(LMD.callbackType.EVENT_LINKED_WORLD_POSITION_CHANGED, onMapDataChanged)
        end
        if LMD.callbackType.EVENT_PLAYER_ACTIVATED then
            LMD:RegisterCallback(LMD.callbackType.EVENT_PLAYER_ACTIVATED, onMapDataChanged)
        end
    end
    local seen = {}
    local function register(eventId, staticPinsDirty)
        if not eventId or seen[eventId] or not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForEvent) ~= "function" then return end
        seen[eventId] = true
        EVENT_MANAGER:RegisterForEvent(prefix .. "_" .. tostring(eventId), eventId, function(...)
            -- Only genuine player-map transitions are allowed to request a map
            -- resync. POI/group/quest/network events do NOT mean the current map
            -- is wrong, and treating them as transitions was the main POI-area
            -- frame-drop source in 0.29.312.
            if eventId == EVENT_PLAYER_ACTIVATED
                or eventId == EVENT_ZONE_CHANGED
                or eventId == EVENT_LINKED_WORLD_POSITION_CHANGED then
                syncMapTransitionNow()
                return
            end

            -- Approaching, discovering, or changing POIs can emit bursts of these
            -- events while the player is running. Coalesce them and refresh only
            -- the live POI layer after the burst settles.
            if eventId == EVENT_POI_UPDATED
                or (EVENT_POIS_INITIALIZED ~= nil and eventId == EVENT_POIS_INITIALIZED) then
                self.poiRefreshDirty029313 = true
                self.lastPOIEventAt029313 = nowSeconds()
                return
            end

            -- Group markers remain cheap/live. Quest and tracking changes need
            -- an immediate objective refresh because ESO can leave the hidden
            -- World Map's quest pin group stale until M is opened. Queue a
            -- quest-only refresh; do not rebuild POIs/wayshrines/custom pins.
            if eventId == EVENT_GROUP_UPDATE
                or eventId == EVENT_GROUP_MEMBER_JOINED
                or eventId == EVENT_GROUP_MEMBER_LEFT then
                return
            end
            if EVENT_SKYSHARDS_UPDATED ~= nil and eventId == EVENT_SKYSHARDS_UPDATED then
                self.staticPinsDirty = true
                self:RefreshSkyshardWorldMapPin029443()
                return
            end

            if eventId == EVENT_TRACKING_UPDATE
                or eventId == EVENT_QUEST_ADDED
                or eventId == EVENT_QUEST_REMOVED
                or eventId == EVENT_QUEST_ADVANCED
                or eventId == EVENT_QUEST_CONDITION_COUNTER_CHANGED then
                self:QueueQuestPinRefresh029438()
                return
            end

            if staticPinsDirty == true then
                self.staticPinsDirty = true
                -- Fast-travel/world-object networks may genuinely alter native
                -- provider pins. Coalesce one provider prime, but never mark the
                -- player map itself as out of sync.
                self.hiddenPinRefreshRequested = true
            end
        end)
    end

    register(EVENT_PLAYER_ACTIVATED, true)
    register(EVENT_ZONE_CHANGED, true)
    register(EVENT_LINKED_WORLD_POSITION_CHANGED, true)
    register(EVENT_POIS_INITIALIZED, true)
    register(EVENT_WORLD_EVENTS_INITIALIZED, true)
    register(EVENT_FAST_TRAVEL_NETWORK_UPDATED, true)
    register(EVENT_FAST_TRAVEL_KEEP_NETWORK_UPDATED, true)
    register(EVENT_FAST_TRAVEL_KEEP_NETWORK_LINK_CHANGED, true)
    register(EVENT_GROUP_UPDATE, false)
    register(EVENT_GROUP_MEMBER_JOINED, false)
    register(EVENT_GROUP_MEMBER_LEFT, false)
    register(EVENT_TRACKING_UPDATE, false)
    register(EVENT_POI_UPDATED, true)
    register(EVENT_SKYSHARDS_UPDATED, true)

    -- ESO does not consistently publish merchant NPCs as map POIs. Learn a
    -- merchant's normalized map position whenever the player actually opens a
    -- store, then keep that pin permanently for this character/account save.
    if EVENT_OPEN_STORE and EVENT_MANAGER and type(EVENT_MANAGER.RegisterForEvent) == "function" then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_MerchantStoreOpen", EVENT_OPEN_STORE, function()
            self:RememberMerchantHere()
        end)
    end


    -- Learn crafting stations when their interaction opens. Event constants can
    -- vary between client/API revisions, so this hook remains optional.
    if EVENT_CRAFTING_STATION_INTERACT and EVENT_MANAGER and type(EVENT_MANAGER.RegisterForEvent) == "function" then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_CraftingStationOpen", EVENT_CRAFTING_STATION_INTERACT, function()
            self:RememberCurrentCraftingStation()
        end)
    end
    -- Custom stable learning intentionally removed. Native stable map POIs
    -- continue to render through the ordinary ESO POI layer when available.
    register(EVENT_QUEST_ADDED, true)
    register(EVENT_QUEST_REMOVED, true)
    register(EVENT_QUEST_ADVANCED, true)
    register(EVENT_QUEST_CONDITION_COUNTER_CHANGED, true)

    if not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then return end

    EVENT_MANAGER:RegisterForUpdate(prefix .. "_PlayerMarker", MINIMAP_PLAYER_MARKER_MS, function()
        -- The main minimap pulse owns visibility/menu state. The fast marker path
        -- only needs to know whether its parent is currently visible; avoid doing
        -- additional scene/map queries 30 times per second.
        if not self.frame or not EPC.saved or self.frame:IsHidden() then return end
        self:UpdatePlayerMarkerFast(false, false)
    end)

    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Pulse", MINIMAP_PULSE_MS, function()
        if not self.frame or not EPC.saved then return end
        self:SyncESOCompassVisibility()
        local show = EPC.saved.showMiniMap ~= false or self.layoutMode == true
        if self.layoutMode ~= true and EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("miniMapVisibility") end
        if not show then self.frame:SetHidden(true) return end

        local mapOpen = self:IsWorldMapShowing()
        local menuOpen = self:IsMenuShowing()
        if mapOpen or (menuOpen and not self.layoutMode) then
            self.frame:SetHidden(true)
            if mapOpen then
                local captureNow = nowSeconds()
                local openingEdge = self.mapWasOpen ~= true
                self.mapWasOpen = true
                -- Capture on the open edge, then only at a slow safety cadence.
                -- The old 33ms pulse walked the complete native pin set every
                -- frame while World Map was open, which was a major avoidable cost.
                if openingEdge or not self.lastNativeMapCaptureAt029122
                    or captureNow - self.lastNativeMapCaptureAt029122 >= 2.0 then
                    self.lastNativeMapCaptureAt029122 = captureNow
                    self:CaptureAllNativeMapPins()
                end
            end
            self.menuWasOpen = menuOpen == true
            return
        end

        self.frame:SetHidden(false)
        self.frame:SetMouseEnabled(self:IsInteractive())
        self.frame:SetMovable(self.layoutMode == true)
        local worldMapJustClosed = self.mapWasOpen == true
        if worldMapJustClosed then
            -- The close edge belongs to this pulse only. Clear it before syncing so
            -- later pulses cannot repeatedly treat the World Map as freshly closed.
            self.mapWasOpen = false
        end
        if worldMapJustClosed or self.menuWasOpen then
            self.needsSync = true
            self.staticPinsDirty = true
            if self.nativeTownPinsChanged then
                self.nativeTownPinsChanged = false
            end
        end
        self.menuWasOpen = false

        -- Safety net for same-zone town/sub-map transitions. Some locations can
        -- change LibMapData.mapId without ESO producing a zone event on the exact
        -- frame our callbacks run. Poll the library-owned map id at a fast fallback rate and
        -- request a full sync whenever it differs from the minimap map. This never
        -- changes ESO's visible World Map.
        local mapWatchNow = nowSeconds()
        if not self.lastMapIdWatch or mapWatchNow - self.lastMapIdWatch >= MAP_ID_WATCH_INTERVAL_S then
            self.lastMapIdWatch = mapWatchNow
            local watchedMapId = 0
            if type(DoesCurrentMapMatchMapForPlayerLocation) == "function"
                and safe(DoesCurrentMapMatchMapForPlayerLocation, false) == true then
                watchedMapId = safeNumber(GetCurrentMapId, 0)
            end
            if watchedMapId <= 0 and LMD then watchedMapId = tonumber(LMD.mapId) or 0 end
            if watchedMapId > 0 and watchedMapId ~= (tonumber(self.mapId) or 0) then
                self.needsSync = true
                self.staticPinsDirty = true
                -- Keep ESO's hidden current map aligned with the player's real area
                -- so the minimap can switch immediately on city/interior travel.
                self:TrySyncHiddenPlayerMap("transition")
                -- Switch on this pulse rather than waiting for another one.
                local synced = self:SyncToPlayerMap(true)
                self.needsSync = not synced
                if synced then
                    self:RefreshStaticPins()
                    self:UpdatePanAndPins(true)
                    self:ScheduleLiveNativeMirrorRefresh(self.mapId)
                end
            elseif type(DoesCurrentMapMatchMapForPlayerLocation) == "function"
                and safe(DoesCurrentMapMatchMapForPlayerLocation, false) ~= true then
                -- v0.29.341: this used to run on every 240 ms pulse. Checking at
                -- the map-id watchdog cadence is sufficient and avoids repeated
                -- hidden-map sync probes during ordinary movement.
                self:TrySyncHiddenPlayerMap("pulse")
            end
        end

        if self.needsSync or not self.mapId then
            self:TrySyncHiddenPlayerMap("transition")
            local synced = self:SyncToPlayerMap(true)
            self.needsSync = not synced
            self.staticPinsDirty = true
            -- Native map pins may have been learned while the player viewed the
            -- World Map. One clean redraw is enough; LibMapData restores the
            -- player-map state without the Suite touching zoom/map selection.
            if synced and worldMapJustClosed then
                self.lastStaticRefresh = nowSeconds()
                self:RefreshStaticPins()
                self:UpdatePanAndPins(true)
            end
        else
            -- v0.29.341: the fast marker path already owns the authoritative
            -- GetMapPlayerPosition sample at 30 Hz. Re-reading it here duplicated
            -- map-position work during movement and could feed the camera two
            -- slightly different samples. The slow pulse consumes that cache only.
            if self.playerX == nil or self.playerY == nil then self.needsSync = true end
        end

        local effective = self:GetEffectiveZoom()
        if self.effectiveZoom and math.abs(effective - self.effectiveZoom) > 0.01 then self:RebuildMap(true) end

        local now = nowSeconds()

        -- v0.29.438: quest/tracking events use a dedicated, debounced objective
        -- refresh. It is allowed while moving because it touches only quest
        -- objectives, not every map/custom-pin provider.
        if self.questNativeRefreshRequested029438 == true then
            local questEventAt = tonumber(self.lastQuestPinEventAt029438) or 0
            local lastQuestPrime = tonumber(self.lastQuestNativePrimeAt029438) or 0
            if now - questEventAt >= 0.12 and now - lastQuestPrime >= 0.35 then
                self.questNativeRefreshRequested029438 = false
                self.lastQuestNativePrimeAt029438 = now
                if self:PrimeHiddenQuestPins029438("quest-event") then
                    self.staticPinsDirty = true
                    -- Quest snapshots are event-driven and infrequent. Render the
                    -- newly captured objective pins immediately when the static
                    -- throttle allows it instead of waiting another general pulse.
                    if not self.lastStaticRefresh or now - self.lastStaticRefresh >= 0.35 then
                        self.lastStaticRefresh = now
                        self:RefreshStaticPins()
                    end
                end
                self.lastDynamicPinLayoutAt029312 = nil
                self:RefreshQuestPin()
            end
        end

        -- POI/network events can change map pins while the player stands still.
        -- Rebuild the full hidden pin manager only for those heavier provider
        -- changes; quest events are handled above by the objective-only path.
        if self.hiddenPinRefreshRequested == true then
            -- v0.29.341: heavyweight hidden-provider primes never compete with
            -- active movement. Network/world-event changes can wait until the
            -- player has been still briefly; the request remains queued.
            local lastMotionForPrime = tonumber(self.lastPlayerMotionAt029314) or 0
            local providerPrimeSettled = lastMotionForPrime <= 0 or (now - lastMotionForPrime) >= 0.65
            if providerPrimeSettled then
                self.hiddenPinRefreshRequested = false
                if self:PrimeHiddenWorldMapPins("event", true) then
                    self.staticPinsDirty = true
                end
            end
        end

        -- POI proximity/discovery has a dedicated debounce. Dense towns can fire
        -- many EVENT_POI_UPDATED callbacks in a short run; perform one POI-only
        -- pass after the burst instead of rebuilding every static minimap layer.
        if self.poiRefreshDirty029313 == true then
            local lastEvent = tonumber(self.lastPOIEventAt029313) or 0
            local lastRefresh = tonumber(self.lastPOIRefreshAt029313) or 0
            local lastMotion = tonumber(self.lastPlayerMotionAt029314) or 0
            local movementSettled = lastMotion <= 0 or (now - lastMotion) >= POI_REFRESH_STATIONARY_GRACE_S_029314
            if movementSettled and now - lastEvent >= POI_EVENT_DEBOUNCE_S and now - lastRefresh >= POI_REFRESH_MIN_GAP_S then
                self.lastPOIRefreshAt029313 = now
                self:RefreshLivePOILayer029313()
            end
        end

        if self.restoreRoamingPins029315 == true and self.roamingVisualBudget029315 ~= true then
            self.restoreRoamingPins029315 = false
            -- Cached-data-only restore. No World Map/provider/POI API scan.
            self:RenderNativeMirrorPins()
            self:RenderPOIPins()
            self:RenderMerchantPins()
            self:RenderServicePins()
        end

        if self.staticPinsDirty and (not self.lastStaticRefresh or now - self.lastStaticRefresh >= 0.35) then
            self.lastStaticRefresh = now
            self:RefreshStaticPins()
        end
        -- v0.29.312: POI order is built when static map data changes. Do not
        -- re-sort the entire POI table just because the player is moving.
        if not self.lastTrailCapture or now - self.lastTrailCapture >= 1.20 then
            self.lastTrailCapture = now
            if self:CaptureTrailPoint(false) then self:RenderTrail() end
        end
        -- Poll crafting interactions as a fallback for clients where a dedicated
        -- crafting event is absent. Learned locations are save-once and deduped.
        local t = nowSeconds()
        if EVENT_CRAFTING_STATION_INTERACT == nil and t - (self.lastServiceLearnCheck or 0) >= 3.0 then
            self.lastServiceLearnCheck = t
            self:RememberCurrentCraftingStation()
        end

        -- v0.29.312: no periodic native-pin snapshot while running. Even without
        -- a provider rebuild, walking the entire ESO/LibMapPins manager can hitch
        -- a frame in dense maps. Native snapshots are now event/map-transition
        -- driven only; Suite-owned group/quest/waypoint pins update independently.

        self:UpdatePanAndPins(false)
    end)
end

local InitializeImplArch

function M:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.layoutMode = false
    self.mapBackend = (LMD and GPS and LMP) and "LibMapData + LibGPS + LibMapPins" or "fallback"
    self.esoCompassHidden = nil
    self.mapId = nil
    self.lastGameplayMapId = nil
    self.lastGameplayX = nil
    self.lastGameplayY = nil
    self.stableInteractionActive = false
    -- v0.29.297 rebuilds native/custom pin snapshots while the World Map is
    -- hidden. Invalidate the older cache once so every map starts from pin data
    -- produced by the new gameplay refresh path.
    if EPC.saved and tonumber(EPC.saved.miniMapNativeMirrorSchema) ~= 2970 then
        EPC.saved.miniMapNativeTownPins = {}
        EPC.saved.miniMapNativeMirrorSchema = 2970
    end
    if EPC.saved then
        -- v0.29.293: the first live-map crop build preserved the older, very
        -- wide 1.05/0.88 tuning. Migrate only that old/default range once so
        -- existing users immediately get a useful navigation scale and readable
        -- POI/service icons, while leaving deliberately larger custom values alone.
        local tuningSchema = tonumber(EPC.saved.miniMapTuningSchema) or 0
        if tuningSchema < 293 then
            local oldZoom = tonumber(EPC.saved.miniMapZoom)
            local oldIcons = tonumber(EPC.saved.miniMapIconScale)
            if oldZoom == nil or oldZoom <= 1.10 then EPC.saved.miniMapZoom = 1.38 end
            if oldIcons == nil or oldIcons <= 0.90 then EPC.saved.miniMapIconScale = 1.15 end
            EPC.saved.miniMapTuningSchema = 293
        end

        -- v0.29.295: the 115% marker boost was useful before independent pin
        -- refresh was working, but ESO's real city/service pin artwork is larger
        -- than our fallback POI set.  Migrate only that v293 default band back to
        -- 100%; deliberate user sizes outside the band are left unchanged.
        local iconTuningSchema = tonumber(EPC.saved.miniMapIconTuningSchema) or 0
        if iconTuningSchema < 295 then
            local currentIcons = tonumber(EPC.saved.miniMapIconScale)
            if currentIcons == nil or (currentIcons >= 1.10 and currentIcons <= 1.20) then
                EPC.saved.miniMapIconScale = 1.00
            end
            EPC.saved.miniMapIconTuningSchema = 295
        end

        local visualSchema = tonumber(EPC.saved.miniMapVisualSchema) or 0
        if visualSchema < 29283 then
            local currentScale = tonumber(EPC.saved.miniMapIconScale)
            if currentScale == nil or math.abs(currentScale - 0.70) < 0.001 then
                EPC.saved.miniMapIconScale = 0.88
            end
            if not EPC.saved.miniMapVisualStyle or EPC.saved.miniMapVisualStyle == "" then
                EPC.saved.miniMapVisualStyle = "FANTASY_ROUND"
            elseif string.find(tostring(EPC.saved.miniMapVisualStyle), "ROUND", 1, true) then
                EPC.saved.miniMapVisualStyle = "FANTASY_ROUND"
            else
                EPC.saved.miniMapVisualStyle = "FANTASY_SQUARE"
            end
            if not EPC.saved.miniMapPlayerMarkerStyle or EPC.saved.miniMapPlayerMarkerStyle == "" then
                EPC.saved.miniMapPlayerMarkerStyle = "MINIMAP_GOLD_ARROW"
            end
            if not EPC.saved.miniMapThemeMode or EPC.saved.miniMapThemeMode == "" then
                EPC.saved.miniMapThemeMode = "MANUAL"
            end
            if not EPC.saved.miniMapZoneThemeFamily or EPC.saved.miniMapZoneThemeFamily == "" then
                EPC.saved.miniMapZoneThemeFamily = "MIXED"
            end
            EPC.saved.miniMapVisualSchema = 29283
        end
    end
    self:CleanupLearnedMapData()
    self.mapWasOpen = false
    self.needsSync = true
    self.staticPinsDirty = true
    self.hiddenPinRefreshRequested = true
    self.hiddenPinPrimeInProgress = false
    self.trailData = {}
    self:Create()
    self:RegisterQuestWorldMapPin029442()
    self:RegisterEvents()
    self:HookNativeTownPins()
    if type(zo_callLater) == "function" then zo_callLater(function() self:HookNativeTownPins() end, 1200) end
    self:Refresh(true)
    if tonumber(self.mapId) and tonumber(self.mapId) > 0 then
        self:ScheduleLiveNativeMirrorRefresh(self.mapId)
    elseif type(zo_callLater) == "function" then
        zo_callLater(function()
            if tonumber(self.mapId) and tonumber(self.mapId) > 0 then
                self:ScheduleLiveNativeMirrorRefresh(self.mapId)
            end
        end, 500)
    end
end


-- ============================================================================
-- v0.24.84 - Live Cyrodiil Elder Scroll objective layer
-- Elder Scrolls are objective records, not keep pins. Query them separately so
-- carried/returned scrolls remain visible on the icon-only PvP minimap.
-- ============================================================================
function M:EnsurePvPScrollPins(count)
    self.pvpScrollPins = self.pvpScrollPins or {}
    for i = #self.pvpScrollPins + 1, count do
        local pin = self:CreatePin("EPC_MiniMap_ElderScroll_" .. tostring(i), 30, POI_FALLBACK_TEXTURE, COLORS.white, true)
        pin:SetDrawLevel(94)
        self.pvpScrollPins[i] = pin
    end
end

function M:HidePvPScrollPins()
    for i = 1, #(self.pvpScrollPins or {}) do self.pvpScrollPins[i]:SetHidden(true) end
end

function M:IsElderScrollObjective(keepId, objectiveId, objectiveName)
    keepId = tonumber(keepId) or 0
    objectiveId = tonumber(objectiveId) or 0
    if keepId > 0 and type(GetKeepArtifactObjectiveId) == "function" then
        local artifactId = tonumber(safe(GetKeepArtifactObjectiveId, 0, keepId)) or 0
        if artifactId > 0 and artifactId == objectiveId then return true end
    end
    local name = string.lower(tostring(objectiveName or ""))
    return name:find("elder scroll", 1, true) ~= nil
end

local RefreshPvPScrollDataImplArch

function M:RefreshPvPScrollData(...)

    return RefreshPvPScrollDataImplArch(self, ...)

end

RefreshPvPScrollDataImplArch = function(self)
    self.pvpScrollData = {}
    if safe(IsPlayerInAvAWorld, false) ~= true then return end
    if type(GetNumObjectives) ~= "function" or type(GetObjectiveIdsForIndex) ~= "function" or type(GetObjectivePinInfo) ~= "function" then return end

    local num = safeNumber(GetNumObjectives, 0)
    for index = 1, num do
        local keepId, objectiveId, context = safe(GetObjectiveIdsForIndex, nil, index)
        keepId, objectiveId = tonumber(keepId) or 0, tonumber(objectiveId) or 0
        context = context or BGQUERY_LOCAL or 1
        if objectiveId > 0 then
            local objectiveName, objectiveType, objectiveState = "", nil, nil
            if type(GetObjectiveInfo) == "function" then
                objectiveName, objectiveType, objectiveState = safe(GetObjectiveInfo, "", keepId, objectiveId, context)
            end
            if self:IsElderScrollObjective(keepId, objectiveId, objectiveName) then
                local pinType, x, y, continuous = safe(GetObjectivePinInfo, nil, keepId, objectiveId, context)
                x, y = tonumber(x), tonumber(y)

                -- At-base or transition states may temporarily omit a current
                -- coordinate. Fall back to return/spawn locations so the scroll
                -- never disappears from the minimap merely because it was reset.
                if not x or not y or x <= 0 or y <= 0 or x > 1 or y > 1 then
                    if type(GetObjectiveReturnPinInfo) == "function" then
                        local returnPinType, rx, ry = safe(GetObjectiveReturnPinInfo, nil, keepId, objectiveId, context)
                        rx, ry = tonumber(rx), tonumber(ry)
                        if rx and ry and rx > 0 and ry > 0 and rx <= 1 and ry <= 1 then
                            pinType, x, y = returnPinType or pinType, rx, ry
                        end
                    end
                end
                if not x or not y or x <= 0 or y <= 0 or x > 1 or y > 1 then
                    if type(GetObjectiveSpawnPinInfo) == "function" then
                        local spawnPinType, sx, sy = safe(GetObjectiveSpawnPinInfo, nil, keepId, objectiveId, context)
                        sx, sy = tonumber(sx), tonumber(sy)
                        if sx and sy and sx > 0 and sy > 0 and sx <= 1 and sy <= 1 then
                            pinType, x, y = spawnPinType or pinType, sx, sy
                        end
                    end
                end

                if x and y and x > 0 and y > 0 and x <= 1 and y <= 1 then
                    local color = COLORS.white
                    if type(GetObjectiveAuraPinInfo) == "function" then
                        local _, r, g, b = safe(GetObjectiveAuraPinInfo, nil, keepId, objectiveId, context)
                        if tonumber(r) and tonumber(g) and tonumber(b) then color = {r, g, b, 1} end
                    end
                    self.pvpScrollData[#self.pvpScrollData + 1] = {
                        x=x, y=y, keepId=keepId, objectiveId=objectiveId, context=context,
                        name=objectiveName, pinType=pinType, objectiveType=objectiveType,
                        objectiveState=objectiveState, continuous=continuous == true,
                        texture=self:GetPvPPinTexture(pinType), color=color,
                    }
                end
            end
        end
    end
end

local RenderPvPScrollPinsImplArch

function M:RenderPvPScrollPins(...)

    return RenderPvPScrollPinsImplArch(self, ...)

end

RenderPvPScrollPinsImplArch = function(self)
    if not self:IsPvPIconOnlyMode() then self:HidePvPScrollPins(); return end

    local now = type(GetFrameTimeMilliseconds) == "function" and tonumber(GetFrameTimeMilliseconds()) or 0
    if now == 0 or not self.lastPvPScrollRefreshMs or (now - self.lastPvPScrollRefreshMs) >= 250 then
        self.lastPvPScrollRefreshMs = now
        self:RefreshPvPScrollData()
    end

    local data = self.pvpScrollData or {}
    self:EnsurePvPScrollPins(#data)
    for i = 1, #self.pvpScrollPins do
        local pin = self.pvpScrollPins[i]
        local scroll = data[i]
        if scroll then
            if scroll.texture and scroll.texture ~= "" then pin:SetTexture(scroll.texture) else pin:SetTexture(POI_FALLBACK_TEXTURE) end
            local c = scroll.color or COLORS.white
            pin:SetColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            self:PlacePin(pin, scroll.x, scroll.y, 30, false)
        else
            pin:SetHidden(true)
        end
    end
end

local easLegacyRenderPvPPins_2484 = RenderPvPPinsImplArch
RenderPvPPinsImplArch = function(self)
    if easLegacyRenderPvPPins_2484 then easLegacyRenderPvPPins_2484(self) end
    self:RenderPvPScrollPins()
end

local easLegacyRefreshPvPKeepData_2484 = RefreshPvPKeepDataImplArch
RefreshPvPKeepDataImplArch = function(self)
    easLegacyRefreshPvPKeepData_2484(self)
    self:RefreshPvPScrollData()
end


-- ============================================================================
-- v0.24.86 - Native Elder Scroll artwork resolver
-- Use the exact objective pin type returned by ESO and try the game's native
-- map-pin texture definitions with objective context. Native textures are
-- rendered untinted so their built-in alliance/artifact colors remain intact.
-- ============================================================================
function M:GetNativeObjectivePinTexture(pinType, keepId, objectiveId, context, objectiveName)
    if pinType == nil then return nil end

    if type(GetMapPinTexture) == "function" then
        local tex = safe(GetMapPinTexture, nil, pinType)
        if type(tex) == "string" and tex ~= "" then return tex end
    end

    if ZO_MapPin and type(ZO_MapPin.PIN_DATA) == "table" then
        local def = ZO_MapPin.PIN_DATA[pinType]
        if type(def) == "table" then
            local tex = def.texture
            if type(tex) == "string" and tex ~= "" then return tex end
            if type(tex) == "function" then
                local tag = {
                    pinType = pinType,
                    keepId = keepId,
                    objectiveId = objectiveId,
                    bgContext = context,
                    context = context,
                    objectiveName = objectiveName,
                }
                local attempts = {
                    function() return tex(tag) end,
                    function() return tex(pinType, tag) end,
                    function() return tex(keepId, objectiveId, context) end,
                    function() return tex(pinType, keepId, objectiveId, context) end,
                    function() return tex(pinType) end,
                }
                for i = 1, #attempts do
                    local ok, value = pcall(attempts[i])
                    if ok and type(value) == "string" and value ~= "" then return value end
                end
            end
        end
    end

    return self:GetPvPPinTexture(pinType)
end

local easLegacyRefreshPvPScrollData_2486 = RefreshPvPScrollDataImplArch
RefreshPvPScrollDataImplArch = function(self)
    easLegacyRefreshPvPScrollData_2486(self)
    for i = 1, #(self.pvpScrollData or {}) do
        local scroll = self.pvpScrollData[i]
        scroll.texture = self:GetNativeObjectivePinTexture(
            scroll.pinType, scroll.keepId, scroll.objectiveId, scroll.context, scroll.name
        )
        scroll.hasNativeTexture = type(scroll.texture) == "string" and scroll.texture ~= ""
    end
end

local easLegacyRenderPvPScrollPins_2486 = RenderPvPScrollPinsImplArch
RenderPvPScrollPinsImplArch = function(self)
    if not self:IsPvPIconOnlyMode() then self:HidePvPScrollPins(); return end

    local now = type(GetFrameTimeMilliseconds) == "function" and tonumber(GetFrameTimeMilliseconds()) or 0
    if now == 0 or not self.lastPvPScrollRefreshMs or (now - self.lastPvPScrollRefreshMs) >= 250 then
        self.lastPvPScrollRefreshMs = now
        self:RefreshPvPScrollData()
    end

    local data = self.pvpScrollData or {}
    self:EnsurePvPScrollPins(#data)
    for i = 1, #self.pvpScrollPins do
        local pin = self.pvpScrollPins[i]
        local scroll = data[i]
        if scroll then
            if scroll.hasNativeTexture then
                pin:SetTexture(scroll.texture)
                -- Do not tint ESO's native Elder Scroll artwork. The texture
                -- itself carries the correct multi-color scroll appearance.
                pin:SetColor(1, 1, 1, 1)
            else
                pin:SetTexture(POI_FALLBACK_TEXTURE)
                local c = scroll.color or COLORS.white
                pin:SetColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            end
            self:PlacePin(pin, scroll.x, scroll.y, 30, false)
        else
            pin:SetHidden(true)
        end
    end
end

-- ============================================================================
-- v0.29.376 - low-cost minimap render self-heal.
-- A POI/town boundary must not force a heavyweight rebuild, but a genuinely
-- wrong player map must not remain rendered indefinitely either. Two consecutive
-- native mismatch samples mark the existing deferred sync path dirty; the normal
-- minimap pulse performs the actual rebuild using its movement/performance gates.
-- ============================================================================
local EAS_MiniMapInitializeBase029376 = InitializeImplArch
InitializeImplArch = function(self)
    local result=EAS_MiniMapInitializeBase029376(self)
    if EVENT_MANAGER then
        local name=(EPC.name or "ESOAdventurerSuite").."_MiniMapMismatch029376"
        EVENT_MANAGER:UnregisterForUpdate(name)
        EVENT_MANAGER:RegisterForUpdate(name,500,function()
            local mm=EPC and EPC.MiniMap
            if not mm or not mm.root or mm.root:IsHidden() then return end
            if WORLD_MAP_SCENE and type(WORLD_MAP_SCENE.IsShowing)=="function" then local ok,showing=pcall(WORLD_MAP_SCENE.IsShowing,WORLD_MAP_SCENE); if ok and showing then mm.mapMismatchSamples029376=0; return end end
            if type(DoesCurrentMapMatchMapForPlayerLocation)~="function" then return end
            local ok,match=pcall(DoesCurrentMapMatchMapForPlayerLocation)
            if not ok then return end
            if match==true then mm.mapMismatchSamples029376=0
            else
                mm.mapMismatchSamples029376=(tonumber(mm.mapMismatchSamples029376) or 0)+1
                if mm.mapMismatchSamples029376>=2 then mm.needsSync=true; mm.staticPinsDirty=true; mm.mapMismatchSamples029376=0 end
            end
        end)
    end
    return result
end


-- ============================================================================
-- v0.29.381 - settled player-map render recovery.
-- A confirmed mismatch gets one debounced hidden-map sync after ESO has settled.
-- This is not tied to every POI event, so it preserves the POI freeze fix.
-- ============================================================================
local EAS_MiniMapInitializeBase029381 = InitializeImplArch
InitializeImplArch = function(self)
    local result = EAS_MiniMapInitializeBase029381(self)
    if EVENT_MANAGER then
        local name = (EPC.name or "ESOAdventurerSuite") .. "_MiniMapRenderRecover029381"
        EVENT_MANAGER:UnregisterForUpdate(name)
        EVENT_MANAGER:RegisterForUpdate(name, 650, function()
            local mm = EPC and EPC.MiniMap
            if not mm or not mm.root or mm.root:IsHidden() or mm:IsWorldMapShowing() then return end
            if type(DoesCurrentMapMatchMapForPlayerLocation) ~= "function" then return end
            local ok, match = pcall(DoesCurrentMapMatchMapForPlayerLocation)
            if not ok or match == true then
                mm.renderMismatchCount029381 = 0
                return
            end
            mm.renderMismatchCount029381 = (tonumber(mm.renderMismatchCount029381) or 0) + 1
            if mm.renderMismatchCount029381 < 2 or mm.renderRecoveryPending029381 then return end
            mm.renderMismatchCount029381 = 0
            mm.renderRecoveryPending029381 = true
            local function recover()
                mm.renderRecoveryPending029381 = false
                if not mm.root or mm.root:IsHidden() or mm:IsWorldMapShowing() then return end
                local synced = mm:TrySyncHiddenPlayerMap("transition")
                mm.needsSync = not synced
                mm.staticPinsDirty = true
                if synced and mm.RebuildMap then pcall(mm.RebuildMap, mm, true) end
            end
            if type(zo_callLater) == "function" then zo_callLater(recover, 140) else recover() end
        end)
    end
    return result
end

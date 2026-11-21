KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.WorldIcons = KyzderpsDerps.WorldIcons or {}
local WorldIcons = KyzderpsDerps.WorldIcons
WorldIcons.name = KyzderpsDerps.name .. "WorldIcons"

---------------------------------------------------------------------
-- Map Waypoint
---------------------------------------------------------------------
local cachedLocalX, cachedLocalZ
local cachedWorldX, cachedWorldZ

local function ConvertToWorldPosition(localX, localZ)
    -- Check cached first
    if (localX == cachedLocalX and localZ == cachedLocalZ) then
        return cachedWorldX, cachedWorldZ
    end

    -- Somewhat yoinked from M0R
    local zone, pX, pY, pZ = GetUnitRawWorldPosition("player")

    -- Calculate based on some other arbitrary point
    local playerNormalizedX, playerNormalizedY = GetRawNormalizedWorldPosition(zone, pX, pY, pZ)
    local otherNormalizedX, otherNormalizedY = GetRawNormalizedWorldPosition(zone, pX + 100, pY, pZ + 100)

    -- Linear regression through these 2 points
    local mX =  100 / (otherNormalizedX - playerNormalizedX)
    local bX = pX - playerNormalizedX * mX

    local mY = 100 / (otherNormalizedY - playerNormalizedY)
    local bY = pZ - playerNormalizedY * mY

    -- Plug in waypoint coords
    local worldX = mX * localX + bX
    local worldZ = mY * localZ + bY

    cachedLocalX = localX
    cachedLocalZ = localZ
    cachedWorldX = worldX
    cachedWorldZ = worldZ

    return worldX, worldZ
end

local function WaypointUpdateFunc(icon)
    local localX, localZ = GetMapPlayerWaypoint()
    if (localX == 0 and localZ == 0) then
        icon:SetColor(1, 1, 1, 0) -- Set alpha to 0 to hide, not exactly efficient I guess
        return
    end

    local worldX, worldZ = ConvertToWorldPosition(localX, localZ)

    local _, _, worldY = GetUnitRawWorldPosition("player")

    icon:SetPosition(worldX, worldY, worldZ)
    icon:SetColor(1, 1, 1, 1)
end

local crutchWaypointKey
local function CreateCrutchWaypoint()
    crutchWaypointKey = CrutchAlerts.Drawing.CreateWorldTexture(
        "esoui/art/mappins/ui_worldmap_pin_customdestination.dds",
        0, 0, 0,
        5, 5,
        {1, 1, 1},
        false, -- useDepthBuffer
        true, -- faceCamera
        nil,
        WaypointUpdateFunc)
end

local worldIcon
local function UpdateWaypoint()
    if (worldIcon) then
        OSI.DiscardPositionIcon(worldIcon)
        worldIcon = nil
    end

    local localX, localZ = GetMapPlayerWaypoint()
    if (localX == 0 and localZ == 0) then
        return
    end

    local worldX, worldZ = ConvertToWorldPosition(localX, localZ)
    local _, _, worldY = GetUnitRawWorldPosition("player")

    worldIcon = OSI.CreatePositionIcon(worldX, worldY, worldZ, "esoui/art/mappins/ui_worldmap_pin_customdestination.dds", 200)
end

---------------------------------------------------------------------
-- Called by keybind
---------------------------------------------------------------------
function KyzderpsDerps.PrintCurrentPosition()
    local zoneId, worldX, worldY, worldZ = GetUnitRawWorldPosition( "player" )
    KyzderpsDerps:msg(zo_strformat("zoneId=<<1>> heading=<<5>> {x = <<2>>, y = <<3>>, z = <<4>>}", zoneId, worldX, worldY, worldZ, GetPlayerCameraHeading()))

    if (CrutchAlerts and CrutchAlerts.Drawing) then
        local key = CrutchAlerts.Drawing.CreatePlacedIcon("CrutchAlerts/assets/poop.dds", worldX, worldY, worldZ, 40)
        zo_callLater(function() CrutchAlerts.Drawing.RemovePlacedIcon(key) end, 10000)
    elseif (OSI and OSI.CreatePositionIcon) then
        -- KyzderpsDerps:msg("Creating an icon at that position for 10 seconds...")
        local tempIcon = OSI.CreatePositionIcon(worldX, worldY, worldZ, "odysupporticons/icons/emoji-poop.dds", 100)
        zo_callLater(function() OSI.DiscardPositionIcon(tempIcon) end, 10000)
    else
        KyzderpsDerps:msg("You don't have OdySupportIcons enabled or don't have the latest version, so no icon will be drawn at that position")
    end
end

---------------------------------------------------------------------
-- Use OSI and HarvestMap to show icons for chests in dungeons
-- Permission granted by Shinni :D
---------------------------------------------------------------------
local inCombat = false
local chestPoops = {}

-- Whether icons of a particular type should be shown right now
local function ShouldShowHarvest(settingName)
    -- Check if in the correct zone first
    local zoneId = tostring(GetZoneId(GetUnitZoneIndex("player")))
    if ((settingName == "dungeonChest" or settingName == "dungeonSack")
        and not KyzderpsDerps.DUNGEON_ZONEIDS[zoneId]) then
        return false
    end
    if ((settingName == "trialChest" or settingName == "trialSack")
        and not KyzderpsDerps.TRIAL_ZONEIDS[zoneId]) then
        return false
    end

    -- Check the setting itself, and combat state if needed
    local setting = KyzderpsDerps.savedOptions.worldIcons[settingName]
    if (setting == 1) then
        return false
    elseif (setting == 2) then
        return not inCombat
    elseif (setting == 3) then
        return true
    end
end

-- Remove all icons
local function RemoveChestPoops()
    for _, icon in pairs(chestPoops) do
        OSI.DiscardPositionIcon(icon)
    end
    chestPoops = {}
end

local retries = 0
local prevShowChest = false
local prevShowSack = false
local function AddChestPoops(isCombatOnlyChange)
    -- d("harvest " .. tostring(Harvest == nil))
    -- d("harvest.Data " .. tostring(Harvest.Data == nil))
    -- d("Harvest.Data:GetCurrentZoneCache() " .. tostring(Harvest.Data:GetCurrentZoneCache() == nil))
    -- d("Harvest.Data:GetCurrentZoneCache().mapCaches " .. tostring(Harvest.Data:GetCurrentZoneCache().mapCaches == nil))
    -- d("Harvest.mapTools " .. tostring(Harvest.mapTools == nil))
    -- d("Harvest.mapTools:GetPlayerMapMetaData() " .. tostring(Harvest.mapTools:GetPlayerMapMetaData() == nil))
    -- d("Harvest.mapTools:GetPlayerMapMetaData().map " .. tostring(Harvest.mapTools:GetPlayerMapMetaData().map == nil))

    if (not Harvest
        or not Harvest.Data
        or not Harvest.Data:GetCurrentZoneCache()
        or not Harvest.Data:GetCurrentZoneCache().mapCaches
        or not Harvest.mapTools
        or not Harvest.mapTools:GetPlayerMapMetaData()
        or not Harvest.mapTools:GetPlayerMapMetaData().map) then
        KyzderpsDerps:dbg("|cFF0000Something is nil REEEE (probably just harvest data not initialized?)|r")
        KyzderpsDerps:dbg("Trying chest poops again in 3 seconds")
        retries = retries + 1
        zo_callLater(function() AddChestPoops(isCombatOnlyChange) end, 3000)
        return
    end
    local cache = Harvest.Data:GetCurrentZoneCache().mapCaches[Harvest.mapTools:GetPlayerMapMetaData().map]
    KyzderpsDerps:dbg(Harvest.mapTools:GetPlayerMapMetaData().map)

    -- Retry because data might not be loaded yet. Maybe there's some event that's fired when loading is done, but I'm too lazy to look
    if (retries > 5) then return end
    if (not cache or not cache.pinTypeId) then
        KyzderpsDerps:dbg("Trying chest poops again in 3 seconds")
        retries = retries + 1
        zo_callLater(function() AddChestPoops(isCombatOnlyChange) end, 3000)
        return
    end
    retries = 0

    -- Get the current state of settings. ShouldShowHarvest handles the zone, so we need
    -- only take either of them
    local showChest = ShouldShowHarvest("dungeonChest") or ShouldShowHarvest("trialChest")
    local showSack = ShouldShowHarvest("dungeonSack") or ShouldShowHarvest("trialSack")
    KyzderpsDerps:dbg(string.format("combat %s chest %s sack %s",
        isCombatOnlyChange and "true" or "false",
        showChest and "true" or "false",
        showSack and "true" or "false"))

    -- Do not redraw all the icons if this redraw was triggered by a combat state change, but nothing has changed
    if (isCombatOnlyChange and prevShowChest == showChest and prevShowSack == showSack) then return end
    RemoveChestPoops()
    prevShowChest = showChest
    prevShowSack = showSack
    if (not showChest and not showSack) then return end

    KyzderpsDerps:dbg("drawing icons")
    for i, pinTypeId in pairs(cache.pinTypeId) do
        if (pinTypeId == 6 and showChest) then
            local icon = OSI.CreatePositionIcon(cache.worldX[i]*100, cache.worldZ[i]*100-50, cache.worldY[i]*100, "HarvestMap/Textures/Map/chest.dds", 100, {1.000, 0.937, 0.380})
            table.insert(chestPoops, icon)
        elseif (pinTypeId == 9 and showSack) then
            local icon = OSI.CreatePositionIcon(cache.worldX[i]*100, cache.worldZ[i]*100-50, cache.worldY[i]*100, "HarvestMap/Textures/Map/heavysack.dds", 100, {0.424, 0.690, 0.360})
            table.insert(chestPoops, icon)
        end
    end
end

local prevMap = ""
local function OnChestNeedsRefreshing(isCombatOnlyChange)
    local map = Harvest.mapTools:GetPlayerMapMetaData().map
    if (map == prevMap) then return end

    RemoveChestPoops()
    AddChestPoops(isCombatOnlyChange)
    prevMap = map
end

local function OnCombatStateChanged(_, combat)
    if (inCombat ~= combat) then
        inCombat = combat
        AddChestPoops(true)
    end
end

---------------------------------------------------------------------
-- On boss change, check if it's Xalvakka
---------------------------------------------------------------------
local function GetUnitNameIfExists(unitTag)
    if (DoesUnitExist(unitTag)) then
        return GetUnitName(unitTag)
    end
end

local xalvakkaIcons = {}
local xalvakkaLabels = {} -- [label] = used,

local function FindUnusedLabel()
    local i = 1
    for label, used in pairs(xalvakkaLabels) do
        i = i + 1
        if (not used) then
            label:SetFont("$(BOLD_FONT)|$(KB_54)|outline")
            label:SetDrawLayer(DL_BACKGROUND)
            label:SetDrawTier(DT_LOW)
            label:SetColor(1, 1, 1, 0.8)
            return label
        end
    end

    local label = WINDOW_MANAGER:CreateControl("XalvakkaLabel" .. i, OSI.win, CT_LABEL)
    label:SetFont("$(BOLD_FONT)|$(KB_54)|outline")
    label:SetDrawLayer(DL_BACKGROUND)
    label:SetDrawTier(DT_LOW)
    label:SetColor(1, 1, 1, 0.8)
    return label
end

local function DoXalvakkaIcons()
    KyzderpsDerps:dbg("Adding Xalvakka labels")
    local coords = {{161658, 34800, 161179}, {159807, 34800, 158763}, {158659, 34800, 160797}, {161943, 38800, 159268}, {159803, 38800, 161564}, {158790, 38800, 158695}}
    local labels = {"A entrance", "B window", "C exit", "A window", "B entrance", "C exit"}

    for i, coord in ipairs(coords) do
        local icon = OSI.CreatePositionIcon(coord[1], coord[2], coord[3], "blank.dds", 10, {1, 1, 1})
        local xalvakkaTextLabel = FindUnusedLabel()
        xalvakkaTextLabel:SetParent(icon.ctrl)
        xalvakkaTextLabel:ClearAnchors()
        xalvakkaTextLabel:SetAnchor(CENTER, icon.ctrl, CENTER)
        xalvakkaTextLabel:SetHidden(false)
        xalvakkaTextLabel:SetText(labels[i])
        KyzderpsDerps:dbg("Created " .. labels[i])

        xalvakkaIcons[icon] = xalvakkaTextLabel
        xalvakkaLabels[xalvakkaTextLabel] = true
    end
end
KyzderpsDerps.DoXalvakkaIcons = DoXalvakkaIcons

local function RemoveXalvakkaIcons()
    KyzderpsDerps:dbg("Removing Xalvakka labels")
    for icon, label in pairs(xalvakkaIcons) do
        OSI.DiscardPositionIcon(icon)
        xalvakkaLabels[label] = false
        label:SetHidden(true)
    end
    xalvakkaIcons = {}
end
KyzderpsDerps.RemoveXalvakkaIcons = RemoveXalvakkaIcons

local prevBosses = ""
local function OnBossesChanged()
    local bossHash = ""
    for i = 1, BOSS_RANK_ITERATION_END do
        local name = GetUnitNameIfExists("boss" .. tostring(i))
        if (name and name ~= "") then
            bossHash = bossHash .. name
        end
    end
    if (bossHash == prevBosses) then return end
    prevBosses = bossHash

    local _, powerMax, _ = GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)
    if (powerMax == 214233024 -- HM
        or powerMax == 53558256 -- Vet
        or powerMax == 25084768 -- Normal
        ) then
        DoXalvakkaIcons()
    else
        RemoveXalvakkaIcons()
    end
end

---------------------------------------------------------------------
-- Called on initial player activated
---------------------------------------------------------------------
function WorldIcons.Initialize()
    KyzderpsDerps:dbg("    Initializing Waypoint module...")
    if (CrutchAlerts and CrutchAlerts.Drawing.CreateWorldTexture and KyzderpsDerps.savedOptions.worldIcons.destination) then
        CreateCrutchWaypoint()
        -- TODO: clean up
    elseif (OSI and OSI.CreatePositionIcon and KyzderpsDerps.savedOptions.worldIcons.destination) then
        EVENT_MANAGER:RegisterForUpdate(WorldIcons.name .. "Waypoint", 1000, UpdateWaypoint)
    end

    local settings = KyzderpsDerps.savedOptions.worldIcons
    if (OSI and Harvest
        and (settings.dungeonChest > 1
            or settings.dungeonSack > 1
            or settings.trialChest > 1
            or settings.trialSack > 1)) then
        KyzderpsDerps:dbg("    Pooping on chests...")

        EVENT_MANAGER:RegisterForEvent(WorldIcons.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
        EVENT_MANAGER:RegisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_PLAYER_ACTIVATED, function() OnChestNeedsRefreshing(false) end)
        EVENT_MANAGER:RegisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_ZONE_CHANGED, function() OnChestNeedsRefreshing(false) end)
        EVENT_MANAGER:RegisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_CURRENT_SUBZONE_LIST_CHANGED, function() OnChestNeedsRefreshing(false) end)

        prevMap = ""
        inCombat = IsUnitInCombat("player")
        OnChestNeedsRefreshing(false)
    end

    if (OSI and OSI.CreatePositionIcon and KyzderpsDerps.savedOptions.worldIcons.xalvakka) then
        EVENT_MANAGER:RegisterForEvent(WorldIcons.name .. "XalvakkaLabels", EVENT_BOSSES_CHANGED, OnBossesChanged)
    end
end

function WorldIcons.Uninitialize()
    EVENT_MANAGER:UnregisterForUpdate(WorldIcons.name .. "Waypoint")
    EVENT_MANAGER:UnregisterForEvent(WorldIcons.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE)
    EVENT_MANAGER:UnregisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_ZONE_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(WorldIcons.name .. "ChestPoops", EVENT_CURRENT_SUBZONE_LIST_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(WorldIcons.name .. "XalvakkaLabels", EVENT_BOSSES_CHANGED)

    if (crutchWaypointKey) then
        CrutchAlerts.Drawing.RemoveWorldTexture(crutchWaypointKey)
        crutchWaypointKey = nil
    end
end


---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------
function WorldIcons.GetSettings()
    return {
        {
            type = "description",
            title = nil,
            text = "This module uses CrutchAlerts or OdySupportIcons to draw icons in the world. These icons will be shown through objects and terrain.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show destination in world",
            tooltip = "When you use the base-game keybind to \"Set Destination\" on the world map, also show it as an icon in the world. This will display at the same height your character is at. Requires CrutchAlerts 2.0.0+ OR OdySupportIcons",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.destination end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.destination = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return CrutchAlerts == nil and OSI == nil end,
        },
        {
            type = "dropdown",
            name = "Show HarvestMap chests in dungeons",
            tooltip = "Uses your HarvestMap data to display chest spawn locations while inside a dungeon. Recommend downloading the data via HarvestMapData. Requires OdySupportIcons and HarvestMap",
            choices = {"Never", "Outside combat", "Always"},
            choicesValues = {1, 2, 3},
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.dungeonChest end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.dungeonChest = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return OSI == nil or Harvest == nil end,
        },
        {
            type = "dropdown",
            name = "Show HarvestMap heavy sacks in dungeons",
            tooltip = "Uses your HarvestMap data to display heavy sack spawn locations while inside a dungeon. Recommend downloading the data via HarvestMapData. Requires OdySupportIcons and HarvestMap",
            choices = {"Never", "Outside combat", "Always"},
            choicesValues = {1, 2, 3},
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.dungeonSack end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.dungeonSack = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return OSI == nil or Harvest == nil end,
        },
        {
            type = "dropdown",
            name = "Show HarvestMap chests in trials",
            tooltip = "Uses your HarvestMap data to display chest spawn locations while inside a trial. Recommend downloading the data via HarvestMapData. Requires OdySupportIcons and HarvestMap",
            choices = {"Never", "Outside combat", "Always"},
            choicesValues = {1, 2, 3},
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.trialChest end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.trialChest = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return OSI == nil or Harvest == nil end,
        },
        {
            type = "dropdown",
            name = "Show HarvestMap heavy sacks in trials",
            tooltip = "Uses your HarvestMap data to display heavy sack spawn locations while inside a trial. Recommend downloading the data via HarvestMapData. Requires OdySupportIcons and HarvestMap",
            choices = {"Never", "Outside combat", "Always"},
            choicesValues = {1, 2, 3},
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.trialSack end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.trialSack = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return OSI == nil or Harvest == nil end,
        },
        {
            type = "checkbox",
            name = "Show clone labels on Xalvakka",
            tooltip = "Shows janky labels during the Xalvakka fight in Rockgrove with Entrance/Window/Exit and A/B/C, matching Qcell's Rockgrove Helper, for the hipsters who don't use Qcell's",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.worldIcons.xalvakka end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.worldIcons.xalvakka = value
                WorldIcons.Uninitialize()
                WorldIcons.Initialize()
            end,
            width = "full",
            disabled = function() return OSI == nil end,
        },
    }
end

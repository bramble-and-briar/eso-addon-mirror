-- ESO Adventurer Suite - Treasure & Survey Locator
-- Suite-native integration using LibTreasure location data when installed.
-- LostTreasure itself is not required.

local EPC = ESOProgressionCoach
EPC.TreasureLocator = EPC.TreasureLocator or {}
local T = EPC.TreasureLocator

local PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_TreasureLocator"
local SCOPE_INVENTORY = "INVENTORY"
local SCOPE_OPENED = "OPENED"
local SCOPE_ALL = "ALL"

local TYPES = {
    TREASURE = {
        libType = "treasure",
        pinName = "EAS_TreasureLocator_Treasure",
        specializedType = _G and _G.SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or nil,
        fallbackTexture = EPC:AssetPath("Art/ResourcePins/chest.dds"),
        libIconIndex = 1,
        label = "Treasure Map",
    },
    SURVEY = {
        libType = "survey",
        pinName = "EAS_TreasureLocator_Survey",
        specializedType = _G and _G.SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT or nil,
        fallbackTexture = EPC:AssetPath("Art/ResourcePins/mining.dds"),
        libIconIndex = 5,
        label = "Crafting Survey",
    },
    CLUE = {
        libType = "clue",
        pinName = "EAS_TreasureLocator_Clue",
        specializedType = _G and _G.SPECIALIZED_ITEMTYPE_TROPHY_TRIBUTE_CLUE or nil,
        fallbackTexture = EPC:AssetPath("Art/ResourcePins/world_marker.dds"),
        libIconIndex = 5,
        label = "Tribute Clue",
    },
}

local TYPE_ORDER = { "TREASURE", "SURVEY", "CLUE" }

local function num(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback or 0 end
    return value
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

local function clean(value, fallback)
    local text = tostring(value or "")
    if text == "" then text = tostring(fallback or "") end

    -- ESO item/map names can carry language grammar payloads (for example
    -- Russian case/gender markers).  Always give ESO first chance to resolve
    -- those markers instead of trying to parse translated text ourselves.
    if text ~= "" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then
            text = formatted
        end
    end

    -- If a third-party/library string still contains an unresolved grammar
    -- suffix, remove only the ASCII control payload.  Do not byte-slice UTF-8
    -- text; that was the source of the apparent missing Cyrillic letters.
    text = text:gsub("%^+[%a][%a%d]*{[^}]*}", "")
    text = text:gsub("%^+[%a][%a%d]*", "")
    text = text:gsub("%^", "")
    text = text:gsub("{[%d]+}", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return tostring(fallback or "") end
    return text
end

function T:IsLibTreasureAvailable()
    return type(_G.LibTreasure_GetMapIdData) == "function"
end

local function EAS_LegacyIsCompassAvailable(self)
    return _G.COMPASS_PINS ~= nil
        and type(_G.COMPASS_PINS.AddCustomPin) == "function"
        and type(_G.COMPASS_PINS.RefreshPins) == "function"
end

function T:IsEnabled()
    return EPC.saved and EPC.saved.treasureLocatorEnabled ~= false and self:IsLibTreasureAvailable()
end

function T:GetScope()
    local scope = EPC.saved and EPC.saved.treasureLocatorScope or SCOPE_INVENTORY
    if scope ~= SCOPE_INVENTORY and scope ~= SCOPE_OPENED and scope ~= SCOPE_ALL then
        scope = SCOPE_INVENTORY
    end
    return scope
end

function T:IsTypeEnabled(typeKey)
    if not EPC.saved then return false end
    if typeKey == "TREASURE" then return EPC.saved.treasureLocatorTreasure ~= false end
    if typeKey == "SURVEY" then return EPC.saved.treasureLocatorSurvey ~= false end
    if typeKey == "CLUE" then return EPC.saved.treasureLocatorClue ~= false end
    return false
end

function T:GetPinTexture(typeKey)
    local def = TYPES[typeKey]
    if not def then return "" end
    if type(_G.LibTreasure_GetIcons) == "function" then
        local icons = safeCall(_G.LibTreasure_GetIcons, nil)
        if type(icons) == "table" then
            local texture = icons[def.libIconIndex]
            if type(texture) == "string" and texture ~= "" then return texture end
        end
    end
    return def.fallbackTexture
end

function T:GetItemLink(itemId)
    itemId = num(itemId, 0)
    if itemId <= 0 then return "" end
    return string.format("|H0:item:%d:4:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

function T:GetItemName(itemId, fallback)
    local link = self:GetItemLink(itemId)
    if link ~= "" and type(GetItemLinkName) == "function" then
        local name = safeCall(GetItemLinkName, "", link)
        name = clean(name, "")
        if name ~= "" then return name end
    end
    return fallback or "Treasure Location"
end


-- Hover information is built only when the player actually points at a pin.
-- Nothing here runs in the minimap/world-map update loops, so the locator gains
-- useful context without adding a new polling/FPS cost.
function T:GetTypeKeyFromPinData029309(pinData, fallbackTypeKey)
    if type(pinData) == "table" then
        if pinData.easTypeKey and TYPES[pinData.easTypeKey] then return pinData.easTypeKey end
        for _, typeKey in ipairs(TYPE_ORDER) do
            if pinData.pinType == TYPES[typeKey].libType then return typeKey end
        end
    end
    if fallbackTypeKey and TYPES[fallbackTypeKey] then return fallbackTypeKey end
    return "TREASURE"
end

function T:GetMapDisplayName029309(mapId)
    mapId = num(mapId, 0)
    if mapId > 0 and type(GetMapNameById) == "function" then
        local name = clean(safeCall(GetMapNameById, "", mapId), "")
        if name ~= "" then return name end
    end
    if type(GetMapName) == "function" then
        local name = clean(safeCall(GetMapName, ""), "")
        if name ~= "" then return name end
    end
    return "Current map"
end

function T:GetPinExplanation029309(typeKey)
    if typeKey == "SURVEY" then
        return "Survey resource site. Bring the matching survey report here to find the concentrated crafting nodes."
    elseif typeKey == "CLUE" then
        return "Location associated with this Tribute clue."
    end
    return "Treasure dig location for this map. Travel to the marker and look for the treasure mound."
end

function T:GetPinScopeText029309(itemId)
    local scope = self:GetScope()
    if scope == SCOPE_ALL then
        return "Shown because the locator is set to All Known Locations."
    elseif scope == SCOPE_OPENED then
        return "Shown because this item was opened and is still being tracked."
    end
    if num(itemId, 0) > 0 and self.inventoryItems and self.inventoryItems[num(itemId, 0)] then
        return "Shown because the matching item is in your backpack."
    end
    return "Shown from your current locator inventory filter."
end

function T:AddPinTooltipLines029309(tooltip, pinData, fallbackTypeKey, sourceMapId, x, y)
    if not tooltip or type(tooltip.AddLine) ~= "function" then return end
    pinData = type(pinData) == "table" and pinData or {}
    local typeKey = self:GetTypeKeyFromPinData029309(pinData, fallbackTypeKey)
    local def = TYPES[typeKey] or TYPES.TREASURE
    local itemId = num(pinData.itemId, 0)
    local itemName = self:GetItemName(itemId, def.label)
    sourceMapId = num(sourceMapId or pinData.easSourceMapId, 0)
    local mapName = self:GetMapDisplayName029309(sourceMapId)

    tooltip:AddLine(itemName, "ZoFontWinH4")
    tooltip:AddLine("|cFFD166Type:|r " .. tostring(def.label), "ZoFontGame")
    tooltip:AddLine("|cFFD166Zone / Map:|r " .. tostring(mapName), "ZoFontGame")
    if tonumber(x) and tonumber(y) then
        -- LibTreasure / map pin coordinates are normalized map coordinates
        -- (0..1), not percentages.  Show the actual coordinate values so the
        -- tooltip is unambiguous and can be compared directly with API data.
        tooltip:AddLine(string.format("|cFFD166Map coordinates:|r X: %.3f, Y: %.3f", tonumber(x), tonumber(y)), "ZoFontGameSmall")
    end
    tooltip:AddLine(self:GetPinExplanation029309(typeKey), "ZoFontGameSmall")
    tooltip:AddLine(self:GetPinScopeText029309(itemId), "ZoFontGameSmall")
end

function T:CreateWorldMapTooltip029309(pin, fallbackTypeKey)
    if not pin or not InformationTooltip then return end
    -- LibMapPins initializes and anchors InformationTooltip before invoking this
    -- creator.  Do NOT ClearTooltip here: clearing it destroys LibMapPins' hover
    -- state/anchor and makes the description flash briefly and disappear while
    -- the pointer is still over the pin.  Localized grammar cleanup is handled
    -- on the strings themselves instead.
    local pinData = nil
    if type(pin.GetPinTypeAndTag) == "function" then
        local _, tag = safeCall(pin.GetPinTypeAndTag, nil, pin)
        pinData = tag
    end
    if type(pinData) ~= "table" then return end
    local x, y = nil, nil
    if type(pin.GetNormalizedPosition) == "function" then
        x, y = safeCall(pin.GetNormalizedPosition, nil, pin)
    end
    self:AddPinTooltipLines029309(InformationTooltip, pinData, fallbackTypeKey, pinData.easSourceMapId, x, y)
end

function T:ShowMiniMapTooltip029309(control, entry)
    if not control or type(entry) ~= "table" or not InformationTooltip or type(InitializeTooltip) ~= "function" then return end
    if type(ClearTooltip) == "function" then pcall(ClearTooltip, InformationTooltip) end
    InitializeTooltip(InformationTooltip, control, RIGHT, 8, 0, LEFT)
    local pinData = {
        itemId = entry.itemId,
        pinType = TYPES[entry.typeKey] and TYPES[entry.typeKey].libType or nil,
        easTypeKey = entry.typeKey,
        easSourceMapId = entry.sourceMapId,
    }
    self:AddPinTooltipLines029309(InformationTooltip, pinData, entry.typeKey, entry.sourceMapId, entry.x, entry.y)
end

function T:HideMiniMapTooltip029309()
    if InformationTooltip and type(ClearTooltip) == "function" then
        pcall(ClearTooltip, InformationTooltip)
    end
end

function T:BuildInventoryCache()
    self.inventoryItems = self.inventoryItems or {}
    for key in pairs(self.inventoryItems) do self.inventoryItems[key] = nil end

    if BAG_BACKPACK == nil or type(GetBagSize) ~= "function" then return end
    local bagSize = num(safeCall(GetBagSize, 0, BAG_BACKPACK), 0)
    for slotIndex = 0, math.max(0, bagSize - 1) do
        local _, specializedType = safeCall(GetItemType, nil, BAG_BACKPACK, slotIndex)
        local tracked = false
        for _, typeKey in ipairs(TYPE_ORDER) do
            local def = TYPES[typeKey]
            if def.specializedType ~= nil and specializedType == def.specializedType then
                tracked = true
                break
            end
        end
        if tracked then
            local itemId = num(safeCall(GetItemId, 0, BAG_BACKPACK, slotIndex), 0)
            if itemId > 0 then self.inventoryItems[itemId] = true end
        end
    end

    -- "Opened item" behaves like LostTreasure's mark-on-use behavior: once the
    -- item leaves the backpack, its temporary mark disappears too.
    if self.openedItems then
        for itemId in pairs(self.openedItems) do
            if not self.inventoryItems[itemId] then self.openedItems[itemId] = nil end
        end
    end
end

function T:ScheduleInventoryRefresh()
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForUpdate(PREFIX .. "_InventoryDebounce")
    EVENT_MANAGER:RegisterForUpdate(PREFIX .. "_InventoryDebounce", 180, function()
        EVENT_MANAGER:UnregisterForUpdate(PREFIX .. "_InventoryDebounce")
        if not EPC or not EPC.TreasureLocator then return end
        EPC.TreasureLocator:BuildInventoryCache()
        EPC.TreasureLocator:RefreshPins()
    end)
end

function T:ShouldShowPin(typeKey, pinData)
    if not self:IsEnabled() or not self:IsTypeEnabled(typeKey) or type(pinData) ~= "table" then return false end
    if pinData.pinType ~= TYPES[typeKey].libType then return false end

    local scope = self:GetScope()
    if scope == SCOPE_ALL then return true end

    local itemId = num(pinData.itemId, 0)
    if itemId <= 0 then return false end
    if scope == SCOPE_OPENED then return self.openedItems and self.openedItems[itemId] == true end
    return self.inventoryItems and self.inventoryItems[itemId] == true
end

function T:GetCurrentMapPins(typeKey)
    local result = {}
    if not self:IsEnabled() then return result end
    local mapId = num(safeCall(GetCurrentMapId, 0), 0)
    if mapId <= 0 then return result end
    local mapData = safeCall(_G.LibTreasure_GetMapIdData, nil, mapId)
    if type(mapData) ~= "table" then return result end
    for _, pinData in ipairs(mapData) do
        if self:ShouldShowPin(typeKey, pinData) then result[#result + 1] = pinData end
    end
    return result
end

local function EAS_LegacyCreateMapPins(self, typeKey)
    if not EPC.saved or EPC.saved.treasureLocatorShowMap == false then return end
    local lib = _G.LibMapPins
    local def = TYPES[typeKey]
    if not lib or not def or type(lib.CreatePin) ~= "function" then return end
    for _, pinData in ipairs(self:GetCurrentMapPins(typeKey)) do
        local x, y = num(pinData.x, -1), num(pinData.y, -1)
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            lib:CreatePin(def.pinName, pinData, x, y)
        end
    end
end

local function EAS_LegacyCreateCompassPins(self, typeKey)
    if not EPC.saved or EPC.saved.treasureLocatorShowCompass == false or not self:IsCompassAvailable() then return end
    local def = TYPES[typeKey]
    local manager = _G.COMPASS_PINS and _G.COMPASS_PINS.pinManager or nil
    if not def or not manager or type(manager.CreatePin) ~= "function" then return end
    for _, pinData in ipairs(self:GetCurrentMapPins(typeKey)) do
        local x, y = num(pinData.x, -1), num(pinData.y, -1)
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local label = self:GetItemName(pinData.itemId, def.label)
            manager:CreatePin(def.pinName, pinData, x, y, label)
        end
    end
end

local function EAS_LegacyApplyPinLayouts(self)
    local lib = _G.LibMapPins
    local size = math.max(18, math.min(64, num(EPC.saved and EPC.saved.treasureLocatorPinSize, 32)))
    for _, typeKey in ipairs(TYPE_ORDER) do
        local def = TYPES[typeKey]
        local texture = self:GetPinTexture(typeKey)
        if lib and type(lib.SetLayoutKey) == "function" then
            pcall(lib.SetLayoutKey, lib, def.pinName, "size", size)
            pcall(lib.SetLayoutKey, lib, def.pinName, "texture", texture)
            pcall(lib.SetLayoutKey, lib, def.pinName, "level", 48)
        end
        if self:IsCompassAvailable() and _G.COMPASS_PINS.pinLayouts and _G.COMPASS_PINS.pinLayouts[def.pinName] then
            _G.COMPASS_PINS.pinLayouts[def.pinName].texture = texture
        end
    end
end

local function EAS_LegacyRegisterPinTypes(self)
    if self.pinTypesRegistered or not self:IsLibTreasureAvailable() then return end
    local lib = _G.LibMapPins
    if not lib or type(lib.AddPinType) ~= "function" then return end

    local size = math.max(18, math.min(64, num(EPC.saved and EPC.saved.treasureLocatorPinSize, 32)))
    for _, typeKey in ipairs(TYPE_ORDER) do
        local currentTypeKey = typeKey
        local def = TYPES[currentTypeKey]
        local layout = { level = 48, size = size, texture = self:GetPinTexture(currentTypeKey) }
        local mapCallback = function() self:CreateMapPins(currentTypeKey) end
        local ok = pcall(lib.AddPinType, lib, def.pinName, mapCallback, nil, layout, nil)
        if ok and type(lib.SetEnabled) == "function" then pcall(lib.SetEnabled, lib, def.pinName, true) end

        if self:IsCompassAvailable() then
            local compassLayout = { maxDistance = 0.05, texture = self:GetPinTexture(currentTypeKey) }
            pcall(_G.COMPASS_PINS.AddCustomPin, _G.COMPASS_PINS, def.pinName, function() self:CreateCompassPins(currentTypeKey) end, compassLayout)
        end
    end
    self.pinTypesRegistered = true
    self:ApplyPinLayouts()
end

local function EAS_LegacyRefreshPins(self)
    if not self.pinTypesRegistered then self:RegisterPinTypes() end
    if not self.pinTypesRegistered then return end

    self:ApplyPinLayouts()
    local lib = _G.LibMapPins
    local showMap = EPC.saved and EPC.saved.treasureLocatorShowMap ~= false and self:IsEnabled()
    for _, typeKey in ipairs(TYPE_ORDER) do
        local def = TYPES[typeKey]
        local enabledForType = showMap and self:IsTypeEnabled(typeKey)
        if lib and type(lib.SetEnabled) == "function" then pcall(lib.SetEnabled, lib, def.pinName, enabledForType) end
        if lib and type(lib.RefreshPins) == "function" then pcall(lib.RefreshPins, lib, def.pinName) end
        if self:IsCompassAvailable() then pcall(_G.COMPASS_PINS.RefreshPins, _G.COMPASS_PINS, def.pinName) end
    end

    self:BuildMiniMapCache()
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local mini = EPC and EPC.MiniMap
            if mini and type(mini.UpdatePanAndPins) == "function" then
                pcall(mini.UpdatePanAndPins, mini, true)
            end
        end, 80)
    end
end


local function EAS_LegacyBuildMiniMapCache(self)
    local result = {}
    local mapId = num(safeCall(GetCurrentMapId, 0), 0)
    if EPC.saved and EPC.saved.treasureLocatorShowMap ~= false and self:IsEnabled() then
        for _, typeKey in ipairs(TYPE_ORDER) do
            if self:IsTypeEnabled(typeKey) then
                local texture = self:GetPinTexture(typeKey)
                for _, pinData in ipairs(self:GetCurrentMapPins(typeKey)) do
                    local x, y = num(pinData.x, -1), num(pinData.y, -1)
                    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                        result[#result + 1] = {
                            x = x, y = y, typeKey = typeKey, texture = texture,
                            itemId = pinData.itemId, label = self:GetItemName(pinData.itemId, TYPES[typeKey].label),
                        }
                        if #result >= 120 then break end
                    end
                end
            end
            if #result >= 120 then break end
        end
    end
    self.miniMapPinsCache = result
    self.miniMapPinsCacheMapId = mapId
    return result
end

local function EAS_LegacyGetMiniMapPins(self)
    local mapId = num(safeCall(GetCurrentMapId, 0), 0)
    if type(self.miniMapPinsCache) ~= "table" or self.miniMapPinsCacheMapId ~= mapId then
        return self:BuildMiniMapCache()
    end
    return self.miniMapPinsCache
end

function T:IsTreasurePinTag(pinTag)
    if type(pinTag) ~= "table" then return false end
    local pinType = pinTag.pinType
    return pinType == "treasure" or pinType == "survey" or pinType == "clue"
end

function T:MarkOpenedItem(itemId)
    itemId = num(itemId, 0)
    if itemId <= 0 then return end
    self.openedItems = self.openedItems or {}
    self.openedItems[itemId] = true
    if self:GetScope() == SCOPE_OPENED then self:RefreshPins() end
end

function T:OnTreasureMapOpened(treasureMapIndex)
    if type(GetTreasureMapInfo) ~= "function" or type(_G.LibTreasure_GetTextureData) ~= "function" then return end
    local _, texturePath = safeCall(GetTreasureMapInfo, nil, treasureMapIndex)
    texturePath = clean(texturePath, "")
    if texturePath == "" then return end
    local textureName = texturePath:match(".+/(.+)%.dds")
    if not textureName then return end
    local data = safeCall(_G.LibTreasure_GetTextureData, nil, textureName)
    if type(data) == "table" then self:MarkOpenedItem(data.itemId) end
end

function T:OnBookOpened(bookId)
    if type(_G.LibTreasure_GetBookIdItemId) ~= "function" then return end
    local itemId = safeCall(_G.LibTreasure_GetBookIdItemId, 0, bookId)
    self:MarkOpenedItem(itemId)
end

function T:RefreshSettings()
    self:RegisterPinTypes()
    self:RefreshPins()
end


function T:GetCurrentMapStatusCounts()
    local counts = { TREASURE = 0, SURVEY = 0, CLUE = 0, visible = 0 }
    if not self:IsLibTreasureAvailable() then return counts end

    local mapId = num(safeCall(GetCurrentMapId, 0), 0)
    if mapId <= 0 then return counts end
    local mapData = safeCall(_G.LibTreasure_GetMapIdData, nil, mapId)
    if type(mapData) ~= "table" then return counts end

    for _, pinData in ipairs(mapData) do
        if type(pinData) == "table" then
            if pinData.pinType == TYPES.TREASURE.libType then
                counts.TREASURE = counts.TREASURE + 1
                if self:ShouldShowPin("TREASURE", pinData) then counts.visible = counts.visible + 1 end
            elseif pinData.pinType == TYPES.SURVEY.libType then
                counts.SURVEY = counts.SURVEY + 1
                if self:ShouldShowPin("SURVEY", pinData) then counts.visible = counts.visible + 1 end
            elseif pinData.pinType == TYPES.CLUE.libType then
                counts.CLUE = counts.CLUE + 1
                if self:ShouldShowPin("CLUE", pinData) then counts.visible = counts.visible + 1 end
            end
        end
    end
    return counts
end

local function EAS_BaseDetailedStatusText(self)
    if not self:IsLibTreasureAvailable() then
        return "|cFF5555LibTreasure: NOT LOADED|r  |  Locator inactive. Install LibTreasure to supply Treasure Map, Survey, and Tribute Clue coordinates."
    end

    local counts = self:GetCurrentMapStatusCounts()
    local compass = self:IsCompassAvailable() and "|c66FF66AVAILABLE|r" or "|cFFD166NOT INSTALLED|r"
    local enabled = self:IsEnabled() and "|c66FF66ACTIVE|r" or "|cFFD166DISABLED|r"
    return string.format(
        "Locator: %s  |  LibTreasure: |c66FF66LOADED|r  |  Current map database: %d Treasure / %d Surveys / %d Clues  |  Visible now: %d  |  Compass: %s",
        enabled, counts.TREASURE, counts.SURVEY, counts.CLUE, counts.visible, compass
    )
end

function T:PrintDetailedStatus()
    local text = self:GetDetailedStatusText()
    if EPC and EPC.Print then EPC:Print(text) elseif type(d) == "function" then d(text) end
end

function T:CreatePinPreviewWindow()
    if self.pinPreviewWindow then return self.pinPreviewWindow end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("EAS_TreasureLocatorPinPreview029147")
    root:SetDimensions(540, 245)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(true)
    root:SetMovable(true)
    root:SetHidden(true)
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawLevel then root:SetDrawLevel(1800) end

    local bg = wm:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.018, 0.025, 0.040, 0.98)
    bg:SetEdgeColor(0.70, 0.52, 0.14, 0.95)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 16, 2, 2)

    local title = wm:CreateControl(nil, root, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetColor(1.0, 0.82, 0.30, 1)
    title:SetText("TREASURE & SURVEY PIN PREVIEW")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 10)
    title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 10)
    title:SetHeight(32)

    local subtitle = wm:CreateControl(nil, root, CT_LABEL)
    subtitle:SetFont("ZoFontGame")
    subtitle:SetColor(0.82, 0.85, 0.90, 1)
    subtitle:SetText("These are the actual icons used by the Suite on the World Map and Mini Map.")
    subtitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subtitle:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 45)
    subtitle:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 45)
    subtitle:SetHeight(24)

    root.previewTextures = {}
    root.previewLabels = {}
    local previewOrder = {
        { key = "TREASURE", label = "TREASURE MAP" },
        { key = "SURVEY", label = "CRAFTING SURVEY" },
        { key = "CLUE", label = "TRIBUTE CLUE" },
    }
    local startX, cardW = 25, 163
    for i, info in ipairs(previewOrder) do
        local card = wm:CreateControl(nil, root, CT_BACKDROP)
        card:SetDimensions(cardW, 112)
        card:SetAnchor(TOPLEFT, root, TOPLEFT, startX + ((i - 1) * (cardW + 8)), 78)
        card:SetCenterColor(0.030, 0.040, 0.060, 0.94)
        card:SetEdgeColor(0.28, 0.32, 0.38, 0.95)

        local texture = wm:CreateControl(nil, card, CT_TEXTURE)
        texture:SetDimensions(54, 54)
        texture:SetAnchor(TOP, card, TOP, 0, 10)
        texture:SetTexture(self:GetPinTexture(info.key))
        root.previewTextures[info.key] = texture

        local label = wm:CreateControl(nil, card, CT_LABEL)
        label:SetFont("ZoFontGameBold")
        label:SetColor(0.95, 0.95, 0.94, 1)
        label:SetText(info.label)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOPLEFT, card, TOPLEFT, 5, 72)
        label:SetAnchor(TOPRIGHT, card, TOPRIGHT, -5, 72)
        label:SetHeight(28)
        root.previewLabels[info.key] = label
    end

    local close = wm:CreateControl(nil, root, CT_BUTTON)
    close:SetDimensions(120, 32)
    close:SetAnchor(BOTTOM, root, BOTTOM, 0, -12)
    close:SetFont("ZoFontGameBold")
    close:SetText("CLOSE")
    close:SetNormalFontColor(0.95, 0.95, 0.95, 1)
    close:SetMouseOverFontColor(1.0, 0.82, 0.30, 1)
    close:SetPressedFontColor(1.0, 0.82, 0.30, 1)
    close:SetHandler("OnClicked", function() root:SetHidden(true) end)

    root:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and root.StartMoving then root:StartMoving() end
    end)
    root:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and root.StopMoving then root:StopMoving() end
    end)

    self.pinPreviewWindow = root
    return root
end

function T:ShowPinPreview()
    local root = self:CreatePinPreviewWindow()
    if not root then
        if EPC and EPC.Print then EPC:Print("Treasure & Survey pin preview could not be created.") end
        return
    end
    for _, typeKey in ipairs(TYPE_ORDER) do
        local texture = root.previewTextures and root.previewTextures[typeKey]
        if texture then texture:SetTexture(self:GetPinTexture(typeKey)) end
    end
    root:SetHidden(false)
    if root.BringWindowToTop then root:BringWindowToTop() end
end

function T:GetDependencyStatusText()
    if not self:IsLibTreasureAvailable() then
        return "LibTreasure is not loaded. Install LibTreasure through Minion/ESOUI to enable treasure, survey, and Tribute-clue location data."
    end
    if EPC.saved and EPC.saved.treasureLocatorShowCompass ~= false and not self:IsCompassAvailable() then
        return "LibTreasure is loaded. World Map / Suite Mini Map pins are available. Install CustomCompassPins to enable compass markers."
    end
    return "LibTreasure location data is loaded. Treasure, survey, and Tribute-clue locator is ready."
end

local function EAS_BaseInitialize(self)
    self.inventoryItems = self.inventoryItems or {}
    self.openedItems = self.openedItems or {}
    self:BuildInventoryCache()
    self:RegisterPinTypes()

    if EVENT_MANAGER then
        if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
            EVENT_MANAGER:RegisterForEvent(PREFIX .. "_Inventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
                if bagId == BAG_BACKPACK then self:ScheduleInventoryRefresh() end
            end)
        end
        if EVENT_SHOW_TREASURE_MAP then
            EVENT_MANAGER:RegisterForEvent(PREFIX .. "_TreasureMap", EVENT_SHOW_TREASURE_MAP, function(_, treasureMapIndex)
                self:OnTreasureMapOpened(treasureMapIndex)
            end)
        end
        if EVENT_SHOW_BOOK then
            EVENT_MANAGER:RegisterForEvent(PREFIX .. "_Book", EVENT_SHOW_BOOK, function(_, _, _, _, _, bookId)
                self:OnBookOpened(bookId)
            end)
        end
        if EVENT_PLAYER_ACTIVATED then
            EVENT_MANAGER:RegisterForEvent(PREFIX .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
                self:BuildInventoryCache()
                self:RefreshPins()
            end)
        end
    end

    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function() self:RefreshPins() end)
    end

    if type(zo_callLater) == "function" then zo_callLater(function() self:RefreshPins() end, 700) end
end


-- ============================================================================
-- v0.29.148 - Renderer registration hardening + cross-map projection.
-- LibTreasure stores its coordinates on zone maps. ESO can leave the active
-- map on a city/interior/sub-map, which made the database report as loaded but
-- left World Map, Suite Mini Map, and compass renderers with no usable points.
-- Resolve parent-zone map sources and project them into the actual target map
-- through LibGPS (with the universal-map API as a fallback). Registration is
-- also tracked per renderer/type so a failed pin registration can be retried.
-- ============================================================================
local function EAS_AddUniqueMapId029148(list, seen, mapId)
    mapId = num(mapId, 0)
    if mapId > 0 and not seen[mapId] then
        seen[mapId] = true
        list[#list + 1] = mapId
    end
end

function T:GetZoneMapIdFromZoneIndex029148(zoneIndex)
    zoneIndex = num(zoneIndex, 0)
    if zoneIndex <= 0 or type(GetZoneId) ~= "function" or type(GetMapIdByZoneId) ~= "function" then return 0 end
    local zoneId = num(safeCall(GetZoneId, 0, zoneIndex), 0)
    if zoneId <= 0 then return 0 end
    if type(GetParentZoneId) == "function" then
        local parentId = num(safeCall(GetParentZoneId, zoneId, zoneId), zoneId)
        if parentId > 0 then zoneId = parentId end
    end
    return num(safeCall(GetMapIdByZoneId, 0, zoneId), 0)
end

function T:GetPlayerZoneMapId029148()
    if type(GetUnitZoneIndex) ~= "function" then return 0 end
    local zoneIndex = num(safeCall(GetUnitZoneIndex, 0, "player"), 0)
    return self:GetZoneMapIdFromZoneIndex029148(zoneIndex)
end

function T:GetCurrentMapZoneMapId029148()
    if type(GetCurrentMapZoneIndex) ~= "function" then return 0 end
    return self:GetZoneMapIdFromZoneIndex029148(num(safeCall(GetCurrentMapZoneIndex, 0), 0))
end

function T:GetTreasureSourceMapIds029148(targetMapId, includePlayerZone)
    local result, seen = {}, {}
    EAS_AddUniqueMapId029148(result, seen, targetMapId)
    EAS_AddUniqueMapId029148(result, seen, self:GetCurrentMapZoneMapId029148())
    if includePlayerZone == true then
        EAS_AddUniqueMapId029148(result, seen, self:GetPlayerZoneMapId029148())
    end
    return result
end

function T:ProjectTreasurePoint029148(sourceMapId, targetMapId, x, y)
    sourceMapId, targetMapId = num(sourceMapId, 0), num(targetMapId, 0)
    x, y = tonumber(x), tonumber(y)
    if sourceMapId <= 0 or targetMapId <= 0 or not x or not y then return nil, nil end
    if sourceMapId == targetMapId then return x, y end

    local gps = _G.LibGPS3
    if gps and type(gps.GetMapMeasurementByMapId) == "function" then
        local okS, sourceMeasurement = pcall(gps.GetMapMeasurementByMapId, gps, sourceMapId)
        local okT, targetMeasurement = pcall(gps.GetMapMeasurementByMapId, gps, targetMapId)
        if okS and okT and sourceMeasurement and targetMeasurement
            and type(sourceMeasurement.ToGlobal) == "function" and type(targetMeasurement.ToLocal) == "function" then
            local okG, gx, gy = pcall(sourceMeasurement.ToGlobal, sourceMeasurement, x, y)
            if okG and gx ~= nil and gy ~= nil then
                local okL, lx, ly = pcall(targetMeasurement.ToLocal, targetMeasurement, gx, gy)
                lx, ly = tonumber(lx), tonumber(ly)
                if okL and lx and ly and lx >= -0.001 and lx <= 1.001 and ly >= -0.001 and ly <= 1.001 then
                    return math.max(0, math.min(1, lx)), math.max(0, math.min(1, ly))
                end
            end
        end
    end

    if type(GetUniversallyNormalizedMapInfo) == "function" then
        local okS, sox, soy, sw, sh = pcall(GetUniversallyNormalizedMapInfo, sourceMapId)
        local okT, tox, toy, tw, th = pcall(GetUniversallyNormalizedMapInfo, targetMapId)
        sox, soy, sw, sh = tonumber(sox), tonumber(soy), tonumber(sw), tonumber(sh)
        tox, toy, tw, th = tonumber(tox), tonumber(toy), tonumber(tw), tonumber(th)
        if okS and okT and sox and soy and sw and sh and tox and toy and tw and th
            and sw > 0 and sh > 0 and tw > 0 and th > 0 then
            local gx, gy = sox + (x * sw), soy + (y * sh)
            local lx, ly = (gx - tox) / tw, (gy - toy) / th
            if lx >= -0.001 and lx <= 1.001 and ly >= -0.001 and ly <= 1.001 then
                return math.max(0, math.min(1, lx)), math.max(0, math.min(1, ly))
            end
        end
    end
    return nil, nil
end

function T:GetPinsForTargetMap029148(typeKey, targetMapId, includePlayerZone)
    local result = {}
    if not self:IsEnabled() or not self:IsTypeEnabled(typeKey) then return result end
    targetMapId = num(targetMapId, 0)
    if targetMapId <= 0 then return result end

    local seen = {}
    for _, sourceMapId in ipairs(self:GetTreasureSourceMapIds029148(targetMapId, includePlayerZone == true)) do
        local mapData = safeCall(_G.LibTreasure_GetMapIdData, nil, sourceMapId)
        if type(mapData) == "table" then
            for _, pinData in ipairs(mapData) do
                if self:ShouldShowPin(typeKey, pinData) then
                    local px, py = self:ProjectTreasurePoint029148(sourceMapId, targetMapId, pinData.x, pinData.y)
                    if px and py then
                        local key = string.format("%s:%s:%.5f:%.5f", tostring(typeKey), tostring(pinData.itemId or 0), px, py)
                        if not seen[key] then
                            seen[key] = true
                            result[#result + 1] = { data = pinData, x = px, y = py, sourceMapId = sourceMapId }
                        end
                    end
                end
            end
        end
    end
    return result
end

function T:IsCompassAvailable()
    local compass = _G.COMPASS_PINS
    return compass ~= nil and type(compass.AddCustomPin) == "function"
        and type(compass.RefreshPins) == "function" and compass.pinManager ~= nil
        and type(compass.pinManager.CreatePin) == "function"
end

function T:GetCompassRange029148()
    local percent = num(EPC.saved and EPC.saved.treasureLocatorCompassRange, 10)
    return math.max(2, math.min(25, percent)) / 100
end

function T:CreateMapPins(typeKey)
    self.lastWorldMapDrawn029148 = self.lastWorldMapDrawn029148 or {}
    self.lastWorldMapDrawn029148[typeKey] = 0
    if not EPC.saved or EPC.saved.treasureLocatorShowMap == false then return end
    local lib, def = _G.LibMapPins, TYPES[typeKey]
    if not lib or not def or type(lib.CreatePin) ~= "function" then return end
    local targetMapId = num(safeCall(GetCurrentMapId, 0), 0)
    for _, entry in ipairs(self:GetPinsForTargetMap029148(typeKey, targetMapId, false)) do
        -- Use a tiny metadata wrapper for the pin tag so hover tooltips know the
        -- original source map even when LibGPS projected a sub-map pin. Keep the
        -- normal LibTreasure fields so all existing filtering/deduplication works.
        local tag = {}
        if type(entry.data) == "table" then
            for key, value in pairs(entry.data) do tag[key] = value end
        end
        tag.easTypeKey = typeKey
        tag.easSourceMapId = entry.sourceMapId
        lib:CreatePin(def.pinName, tag, entry.x, entry.y)
        self.lastWorldMapDrawn029148[typeKey] = self.lastWorldMapDrawn029148[typeKey] + 1
    end
end

function T:CreateCompassPins(typeKey)
    self.lastCompassDrawn029148 = self.lastCompassDrawn029148 or {}
    self.lastCompassDrawn029148[typeKey] = 0
    if not EPC.saved or EPC.saved.treasureLocatorShowCompass == false or not self:IsCompassAvailable() then return end
    local def = TYPES[typeKey]
    local manager = _G.COMPASS_PINS.pinManager
    local targetMapId = num(safeCall(GetCurrentMapId, 0), 0)
    for _, entry in ipairs(self:GetPinsForTargetMap029148(typeKey, targetMapId, true)) do
        local label = self:GetItemName(entry.data.itemId, def.label)
        manager:CreatePin(def.pinName, entry.data, entry.x, entry.y, label)
        self.lastCompassDrawn029148[typeKey] = self.lastCompassDrawn029148[typeKey] + 1
    end
end

function T:RegisterMapPinTypes029148()
    local lib = _G.LibMapPins
    if not self:IsLibTreasureAvailable() or not lib or type(lib.AddPinType) ~= "function" then return false end
    self.mapPinTypeIds029148 = self.mapPinTypeIds029148 or {}
    self.mapPinRegistrationErrors029148 = self.mapPinRegistrationErrors029148 or {}
    local size = math.max(18, math.min(64, num(EPC.saved and EPC.saved.treasureLocatorPinSize, 32)))
    local allRegistered = true
    for _, typeKey in ipairs(TYPE_ORDER) do
        -- Freeze the loop value for callbacks retained by LibMapPins.
        local currentTypeKey = typeKey
        local def = TYPES[currentTypeKey]
        if not self.mapPinTypeIds029148[currentTypeKey] then
            local layout = { level = 48, size = size, texture = self:GetPinTexture(currentTypeKey) }
            local tooltipCreator = {
                creator = function(pin) self:CreateWorldMapTooltip029309(pin, currentTypeKey) end,
                tooltip = 1, -- LibMapPins INFORMATION tooltip mode
                hasTooltip = function() return true end,
            }
            local ok, pinTypeId = pcall(
                lib.AddPinType, lib, def.pinName,
                function() self:CreateMapPins(currentTypeKey) end,
                nil, layout, tooltipCreator
            )
            if ok then
                pinTypeId = pinTypeId or (_G and _G[def.pinName])
                self.mapPinTypeIds029148[currentTypeKey] = pinTypeId or true
                self.mapPinRegistrationErrors029148[currentTypeKey] = nil
            else
                self.mapPinRegistrationErrors029148[currentTypeKey] = tostring(pinTypeId)
            end
        end
        if not self.mapPinTypeIds029148[currentTypeKey] then allRegistered = false end
    end
    return allRegistered
end

function T:RegisterCompassPinTypes029148()
    if not self:IsCompassAvailable() then return false end
    self.compassPinRegistered029148 = self.compassPinRegistered029148 or {}
    self.compassRegistrationErrors029148 = self.compassRegistrationErrors029148 or {}
    local allRegistered = true
    for _, typeKey in ipairs(TYPE_ORDER) do
        local def = TYPES[typeKey]
        if not self.compassPinRegistered029148[typeKey] then
            local layout = { maxDistance = self:GetCompassRange029148(), texture = self:GetPinTexture(typeKey) }
            local ok, err = pcall(_G.COMPASS_PINS.AddCustomPin, _G.COMPASS_PINS, def.pinName, function() self:CreateCompassPins(typeKey) end, layout)
            if ok then
                self.compassPinRegistered029148[typeKey] = true
                self.compassRegistrationErrors029148[typeKey] = nil
            else
                self.compassRegistrationErrors029148[typeKey] = tostring(err)
            end
        end
        if not self.compassPinRegistered029148[typeKey] then allRegistered = false end
    end
    return allRegistered
end

function T:RegisterPinTypes()
    local mapOk = self:RegisterMapPinTypes029148()
    self:RegisterCompassPinTypes029148()
    self.pinTypesRegistered = mapOk == true
    self:ApplyPinLayouts()
end

function T:ApplyPinLayouts()
    local lib = _G.LibMapPins
    local size = math.max(18, math.min(64, num(EPC.saved and EPC.saved.treasureLocatorPinSize, 32)))
    for _, typeKey in ipairs(TYPE_ORDER) do
        local def, texture = TYPES[typeKey], self:GetPinTexture(typeKey)
        if lib and type(lib.SetLayoutKey) == "function" and self.mapPinTypeIds029148 and self.mapPinTypeIds029148[typeKey] then
            pcall(lib.SetLayoutKey, lib, def.pinName, "size", size)
            pcall(lib.SetLayoutKey, lib, def.pinName, "texture", texture)
            pcall(lib.SetLayoutKey, lib, def.pinName, "level", 48)
        end
        if self:IsCompassAvailable() and _G.COMPASS_PINS.pinLayouts and _G.COMPASS_PINS.pinLayouts[def.pinName] then
            _G.COMPASS_PINS.pinLayouts[def.pinName].texture = texture
            _G.COMPASS_PINS.pinLayouts[def.pinName].maxDistance = self:GetCompassRange029148()
        end
    end
end

function T:BuildMiniMapCache(targetMapId)
    local result = {}
    targetMapId = num(targetMapId, 0)
    if targetMapId <= 0 then targetMapId = num(safeCall(GetCurrentMapId, 0), 0) end
    if EPC.saved and EPC.saved.treasureLocatorShowMap ~= false and self:IsEnabled() then
        for _, typeKey in ipairs(TYPE_ORDER) do
            if self:IsTypeEnabled(typeKey) then
                local texture = self:GetPinTexture(typeKey)
                for _, entry in ipairs(self:GetPinsForTargetMap029148(typeKey, targetMapId, true)) do
                    result[#result + 1] = {
                        x = entry.x, y = entry.y, typeKey = typeKey, texture = texture,
                        itemId = entry.data.itemId, label = self:GetItemName(entry.data.itemId, TYPES[typeKey].label),
                        sourceMapId = entry.sourceMapId,
                    }
                    if #result >= 120 then break end
                end
            end
            if #result >= 120 then break end
        end
    end
    self.miniMapPinsCache = result
    self.miniMapPinsCacheMapId = targetMapId
    self.lastMiniMapCached029148 = #result
    return result
end

function T:GetMiniMapPins(targetMapId)
    targetMapId = num(targetMapId, 0)
    if targetMapId <= 0 then targetMapId = num(safeCall(GetCurrentMapId, 0), 0) end
    if type(self.miniMapPinsCache) ~= "table" or self.miniMapPinsCacheMapId ~= targetMapId then
        return self:BuildMiniMapCache(targetMapId)
    end
    return self.miniMapPinsCache
end

function T:RefreshPins()
    self:RegisterPinTypes()
    self:ApplyPinLayouts()
    local lib = _G.LibMapPins
    local showMap = EPC.saved and EPC.saved.treasureLocatorShowMap ~= false and self:IsEnabled()
    for _, typeKey in ipairs(TYPE_ORDER) do
        local def = TYPES[typeKey]
        local mapRegistered = self.mapPinTypeIds029148 and self.mapPinTypeIds029148[typeKey]
        if mapRegistered and lib and type(lib.SetEnabled) == "function" then
            pcall(lib.SetEnabled, lib, def.pinName, showMap and self:IsTypeEnabled(typeKey))
        end
        if mapRegistered and lib and type(lib.RefreshPins) == "function" then pcall(lib.RefreshPins, lib, def.pinName) end
        if self.compassPinRegistered029148 and self.compassPinRegistered029148[typeKey]
            and self:IsCompassAvailable() then
            pcall(_G.COMPASS_PINS.RefreshPins, _G.COMPASS_PINS, def.pinName)
        end
    end

    local miniTarget = EPC.MiniMap and num(EPC.MiniMap.mapId, 0) or num(safeCall(GetCurrentMapId, 0), 0)
    self:BuildMiniMapCache(miniTarget)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local mini = EPC and EPC.MiniMap
            if mini and type(mini.UpdatePanAndPins) == "function" then pcall(mini.UpdatePanAndPins, mini, true) end
        end, 80)
    end
end

function T:GetRendererStatus029148()
    local function yesNo(v) return v and "YES" or "NO" end
    local mapCount, compassCount = 0, 0
    for _, typeKey in ipairs(TYPE_ORDER) do
        if self.mapPinTypeIds029148 and self.mapPinTypeIds029148[typeKey] then mapCount = mapCount + 1 end
        if self.compassPinRegistered029148 and self.compassPinRegistered029148[typeKey] then compassCount = compassCount + 1 end
    end
    local worldDrawn, compassDrawn = 0, 0
    for _, v in pairs(self.lastWorldMapDrawn029148 or {}) do worldDrawn = worldDrawn + num(v, 0) end
    for _, v in pairs(self.lastCompassDrawn029148 or {}) do compassDrawn = compassDrawn + num(v, 0) end
    return string.format("World Map: %d/3 registered, %d last drawn | Mini Map: %d cached | Compass: %d/3 registered, %d last created",
        mapCount, worldDrawn, num(self.lastMiniMapCached029148, 0), compassCount, compassDrawn)
end

function T:GetDetailedStatusText()
    local base = EAS_BaseDetailedStatusText(self)
    if not self:IsLibTreasureAvailable() then return base end
    return base .. "\n" .. self:GetRendererStatus029148()
end

function T:Initialize()
    EAS_BaseInitialize(self)
    -- Optional libraries can finish initialization after this module. Retry the
    -- independent renderer registrations after the UI has settled.
    if type(zo_callLater) == "function" then
        zo_callLater(function() if EPC and EPC.TreasureLocator then EPC.TreasureLocator:RefreshPins() end end, 1200)
        zo_callLater(function() if EPC and EPC.TreasureLocator then EPC.TreasureLocator:RefreshPins() end end, 3000)
    end
end

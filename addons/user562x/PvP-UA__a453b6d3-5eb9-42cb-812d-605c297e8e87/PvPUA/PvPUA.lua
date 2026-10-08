local PvPUA = {}
PvPUA.name = "PvPUA"

--------------------------------------------------
-- Config
--------------------------------------------------
PvPUA.config = {}
PvPUA.config.isClampedToScreen = true
PvPUA.config.imageWidth = 30
PvPUA.config.nameWidth = 165
PvPUA.config.flagWidth = 40
PvPUA.config.flagHeight = 8
PvPUA.config.flagFlipWidth = 40
PvPUA.config.underAttackForWidth = 50
PvPUA.config.width = 430
PvPUA.config.siegeWidth = 30
PvPUA.config.entryHeight = 32

--------------------------------------------------
-- ICON SIZES
--------------------------------------------------
PvPUA.config.iconScale = {
    scrollCarrier = 1.65,
    scrollOnKeep  = 1.25,
    volendrung    = 1.0,
    rank          = 1.25,
    emperor       = 0.90,
    allianceScore = 1.0,
}

PvPUA.config.barHeight = 18

PvPUA.config.barFontSize = 0

PvPUA.config.barTextNudge = 2

--------------------------------------------------
-- K: / D: readout
--------------------------------------------------
PvPUA.config.kdGap       = "  "
PvPUA.config.kdRightPad  = 4
PvPUA.config.kdTextNudge = 2
PvPUA.config.kdFontSize  = 20


PvPUA.config.volendrungTintToHud = true
PvPUA.config.height = PvPUA.config.entryHeight * 10
PvPUA.config.backdropAlphaOdd = 0.25
PvPUA.config.backdropAlphaEven = 0.15
PvPUA.config.flagBackdropColor = { r = 0.1, g = 0.1, b = 0.1 }
PvPUA.config.iconOutline = false

--------------------------------------------------
-- Constants
--------------------------------------------------
PvPUA.constants = {}
PvPUA.constants.updateInterval = 1000
PvPUA.constants.siegeTimeout = 5000
PvPUA.constants.resourceType = { FARM = 1, MINE = 2, LUMBER = 3 }
PvPUA.constants.flipTimes = { KEEP = 20000, OUTPOST = 20000, RESOURCE = 20000 }

PvPUA.constants.textures = {}
PvPUA.constants.textures.KEEP = "/esoui/art/mappins/ava_largekeep_neutral.dds"
PvPUA.constants.textures.OUTPOST = "/esoui/art/mappins/ava_outpost_neutral.dds"
PvPUA.constants.textures.VILLAGE = "/esoui/art/mappins/ava_town_neutral.dds"
PvPUA.constants.textures.RESOURCE_MINE = "/esoui/art/compass/ava_mine_neutral.dds"
PvPUA.constants.textures.RESOURCE_FARM = "/esoui/art/compass/ava_farm_neutral.dds"
PvPUA.constants.textures.RESOURCE_LUMBER = "/esoui/art/compass/ava_lumbermill_neutral.dds"
PvPUA.constants.textures.BRIDGE_PASSABLE = "/esoui/art/mappins/ava_bridge_passable.dds"
PvPUA.constants.textures.BRIDGE_NOT_PASSABLE = "/esoui/art/mappins/ava_bridge_not_passable.dds"
PvPUA.constants.textures.MILEGATE_PASSABLE = "/esoui/art/mappins/ava_milegate_passable.dds"
PvPUA.constants.textures.MILEGATE_NOT_PASSABLE = "/esoui/art/mappins/ava_milegate_not_passable.dds"
PvPUA.constants.textures.DISTRICT = "/esoui/art/mappins/ava_imperialdistrict_neutral.dds"

PvPUA.constants.emperorKeeps = {
    { name = "Aleswell",  col = 0, row = 0 },
    { name = "Chalman",   col = 1, row = 0 },
    { name = "Ash",       col = 0, row = 1 },
    { name = "Blue Road", col = 1, row = 1 },
    { name = "Roebeck",   col = 0, row = 2 },
    { name = "Alessia",   col = 1, row = 2 },
}

PvPUA.constants.userIcons = {
    ["@user562"]         = { texture = "PvPUA/Textures/icon_panda.dds" },
    ["@sir gilson7"]     = { texture = "PvPUA/Textures/icon_werewolf.dds", heightOffset = 1.0 },
    ["@get em nala"]     = { texture = "PvPUA/Textures/icon_hedgehog.dds" },
    ["@suzyqboston3383"] = { texture = "PvPUA/Textures/icon_trinity.dds", heightOffset = 1.0 },
    ["@suzibrew"]        = { texture = "PvPUA/Textures/icon_elephant.dds" },
    ["@maddogmcree6157"] = { texture = "PvPUA/Textures/icon_devildog.dds" },
    ["@sgt bear78fh"]    = { texture = "PvPUA/Textures/icon_bear.dds", heightOffset = 1.0 },
    ["@rolo tsg"]        = { texture = "PvPUA/Textures/icon_wizard.dds" },
    ["@bella nekro"]     = { texture = "PvPUA/Textures/icon_bellamask.dds" },
}

PvPUA.constants.ICON_NONE    = 1
PvPUA.constants.ICON_DEFAULT = 2

PvPUA.constants.iconCategories = {
    { id = "other",     name = "Other" },
    { id = "alliances", name = "Alliances" },
    { id = "symbols",   name = "Symbols" },
    { id = "memes",     name = "Memes" },
}

PvPUA.constants.iconChoices = {
    { name = "None",       category = "other",     texture = "EsoUI/Art/Buttons/decline_up.dds", none = true },
    { name = "Default",    category = "other",     isDefault = true },
    { name = "Kiss",       category = "memes",     texture = "PvPUA/Textures/icon_kiss.dds" },
    { name = "Troll Blob", category = "memes",     texture = "PvPUA/Textures/icon_trollblob.dds" },
    { name = "Trollface",  category = "memes",     texture = "PvPUA/Textures/icon_trollface.dds" },
    { name = "Butterfly",  category = "other",     texture = "PvPUA/Textures/icon_butterfly.dds" },
    { name = "Hi",         category = "other",     texture = "PvPUA/Textures/icon_hi.dds" },
    { name = "Crown",      category = "symbols",   texture = "PvPUA/Textures/icon_crown.dds" },
    { name = "Arrow",      category = "symbols",   texture = "PvPUA/Textures/icon_arrow.dds" },
    { name = "DC Banner",  category = "alliances", texture = "PvPUA/Textures/icon_dc_banner.dds" },
    { name = "DC Shield",  category = "alliances", texture = "PvPUA/Textures/icon_dc_shield.dds" },
    { name = "AD Banner",  category = "alliances", texture = "PvPUA/Textures/icon_ad_banner.dds" },
    { name = "AD Shield",  category = "alliances", texture = "PvPUA/Textures/icon_ad_shield.dds" },
    { name = "EP Banner",  category = "alliances", texture = "PvPUA/Textures/icon_ep_banner.dds" },
    { name = "EP Shield",  category = "alliances", texture = "PvPUA/Textures/icon_ep_shield.dds" },
}

PvPUA.defaults = { posX = 100, posY = 450, timerColor = { r = 1, g = 1, b = 1, a = 1 }, enableAPChat = true, consolidateAPChat = false, consolidateRepairDelay = 5, consolidateCombatDelay = 10, alertsEnabled = false, alertLifespan = 10, font = "EsoUI/Common/Fonts/FTN57.otf", backdropStyle = "Alliance", backdropColor = { r = 0, g = 0, b = 0, a = 1 }, listSize = "Default", uiScale = 1.0, barMode = "AP", iconShowSelf = true, iconShowOthers = true, iconShowSmallGroupFrames = true, iconShowLargeGroupFrames = true, showMilegates = true, showBridges = true, showTowns = true, showResources = true, showScrollCarriers = true, showVolendrungRow = true, showListInMenus = false, showListWhileSieging = false, showListWhileDead = true, showListDeadRepair = false, listCap = 0 }

PvPUA.capChoices = {
    { name = "All", value = 0  },
    { name = "5",   value = 5  },
    { name = "10",  value = 10 },
    { name = "15",  value = 15 },
    { name = "30",  value = 30 },
}

PvPUA.charDefaults = { aiKeyword = "", aiEnabled = false, aiWhisper = true, aiSay = false, aiZone = false, aiGuild = false, aiGuildName = "", aiGuildToggles = {}, aiGuildMigrated = false, aiGuildMigrationRepair = false, aiKickOffline = false, aiKickMinutes = 5, aiPvP = true, aiPvE = true }

PvPUA.state = {}
PvPUA.state.visibleControls = {}
PvPUA.state.resources = {}
PvPUA.state.keeps = {}
PvPUA.state.outposts = {}
PvPUA.state.villages = {}
PvPUA.state.destructibles = {}
PvPUA.state.districts = {}

PvPUA.controls = {}
PvPUA.savedVariables = nil
PvPUA.cachedFont = nil
PvPUA.volendrung = nil
PvPUA.initializedItems = false
PvPUA.registeredCyroEvents = false
PvPUA.creditCycle = 0

PvPUA.session = { killingBlows = 0, deaths = 0 }

--------------------------------------------------
-- Alliance Hex
--------------------------------------------------
local DC_HEX = GetAllianceColor(ALLIANCE_DAGGERFALL_COVENANT):ToHex()
local AD_HEX = GetAllianceColor(ALLIANCE_ALDMERI_DOMINION):ToHex()
local EP_HEX = GetAllianceColor(ALLIANCE_EBONHEART_PACT):ToHex()

local CREDIT_STATES = {}
local ALLIANCE_STR  = "Alliance!"
local CYCLE_COLORS  = { DC_HEX, AD_HEX, EP_HEX }
local totalSteps    = #ALLIANCE_STR * #CYCLE_COLORS
for step = 0, totalSteps - 1 do
    local colorIndex  = math.floor(step / #ALLIANCE_STR) + 1
    local letterIndex = (step % #ALLIANCE_STR) + 1
    local animated    = ""
    for i = 1, #ALLIANCE_STR do
        local ch = ALLIANCE_STR:sub(i, i)
        if i <= letterIndex then
            animated = animated .. "|c" .. CYCLE_COLORS[colorIndex] .. ch .. "|r"
        else
            local prevColor = colorIndex > 1 and CYCLE_COLORS[colorIndex - 1] or CYCLE_COLORS[#CYCLE_COLORS]
            animated = animated .. "|c" .. prevColor .. ch .. "|r"
        end
    end
    CREDIT_STATES[step] = "|c" .. DC_HEX .. "DC|r, |c00FF00the BEST|r " .. animated .. " - |c00FF00user562|r"
end

--------------------------------------------------
-- Combat Tracking Locals
--------------------------------------------------
local pvpIsCombatRegistered = false

local VOLENDRUNG_DESPAWN_GRACE = 10000

local wm = WINDOW_MANAGER



--------------------------------------------------
-- Player Icon System
--------------------------------------------------
PvPUA.playerIcon = {}
local PI = PvPUA.playerIcon

PI.toplevel = nil
PI.markers  = {}
PI.remote   = {}
PI.running  = false
PI.updateInterval = 10

PI.SIZE_MIN    = 50
PI.SIZE_MAX    = 200
PI.SIZE_STEP   = 5
PI.HEIGHT_MIN  = -1.0
PI.HEIGHT_MAX  = 3.0
PI.HEIGHT_STEP = 0.1
PI.OPACITY_MIN  = 20
PI.OPACITY_MAX  = 100
PI.OPACITY_STEP = 5

local ICON_MARKER_DATA = {
    scaleX = 2,
    scaleY = 2,
    X = 0,
    Y = 3.75,
    Z = 0,
    depthBuffer = false,
}

local function PICreate3D(toplevel, data)
    local marker = wm:CreateControl(nil, toplevel, CT_TEXTURE)

    function marker:updateSize()
        self:Set3DLocalDimensions(self.size.X * self.scale, self.size.Y * self.scale)
    end

    function marker:updateMarkerData(data)
        self.offset = {
            X = data.X or 0,
            Y = data.Y or 0,
            Z = data.Z or 0
        }
        self.size = {
            X = data.scaleX or 1,
            Y = data.scaleY or 1
        }
        self.texture = data.texture or ""

        if data.depthBuffer == nil then self.depthBuffer = true else self.depthBuffer = data.depthBuffer end
        if data.facePlayer == nil then self.facePlayer = true else self.facePlayer = data.facePlayer end

        self:Set3DRenderSpaceUsesDepthBuffer(self.depthBuffer)
        self:SetTexture(self.texture)
        self:updateSize()
    end

    marker.scale = 1
    marker.userOffset = 0

    marker:Create3DRenderSpace()
    marker:SetDrawLevel(1)
    marker:Set3DRenderSpaceOrigin(0, 0, 0)
    marker:updateMarkerData(data)
    marker:SetHidden(true)

    function marker:setPos(X, Y, Z)
        if not self.enabled then return end
        self:turnToFace()
        self:Set3DRenderSpaceOrigin(X + self.offset.X, Y + self.offset.Y + self.userOffset, Z + self.offset.Z)
    end

    function marker:turnToFace()
        if not self.enabled then return end
        if self.facePlayer then
            local heading = GetPlayerCameraHeading()
            if heading > math.pi then
                heading = heading - 2 * math.pi
            end
            self:Set3DRenderSpaceOrientation(0, heading, 0)
        end
    end

    function marker:setColour(r, g, b, a)
        self:SetColor(r, g, b, a)
    end

    function marker:setUserOffset(offset)
        self.userOffset = offset
    end

    function marker:show()
        if self.enabled then
            self:SetTexture(self.texture)
            self:SetHidden(false)
        end
    end
    function marker:hide()
        self:SetTexture("")
        if self.enabled then
            self:SetHidden(true)
        end
    end

    function marker:enable()
        self.enabled = true
    end
    function marker:disable()
        self.enabled = false
        self:SetHidden(true)
        self:SetTexture("")
    end

    function marker:setScale(scale)
        self.scale = scale
        self:updateSize()
    end

    function marker:applyStyle(texture, alpha, sizePct, height)
        if self.styleTexture ~= texture then
            self.styleTexture = texture
            self.texture = texture
            if self.enabled then self:SetTexture(self.texture) end
        end
        if self.styleAlpha ~= alpha then
            self.styleAlpha = alpha
            self:setColour(1, 1, 1, alpha)
        end
        local scale = (sizePct or 100) / 100
        if self.scale ~= scale then
            self:setScale(scale)
        end
        self:setUserOffset(height or 0)
    end

    return marker
end

local function PIListEntry(nameLower)
    local info = PvPUA.constants.userIcons[nameLower]
    if type(info) == "string" then info = { texture = info } end
    return info
end

local function PIRoundOpacity(v)
    v = zo_clamp(tonumber(v) or 100, PI.OPACITY_MIN, PI.OPACITY_MAX)
    return math.floor(v / PI.OPACITY_STEP + 0.5) * PI.OPACITY_STEP
end

local function PIListStyle(nameLower)
    local info = PIListEntry(nameLower)
    if not info or not info.texture then return nil end
    return PvPUA.constants.ICON_DEFAULT, math.floor((info.scale or 1) * 100 + 0.5), info.heightOffset or 0, PIRoundOpacity((info.alpha or 1) * 100)
end

local function PIIconTexture(iconIndex, nameLower)
    local icon = iconIndex and PvPUA.constants.iconChoices[iconIndex]
    if not icon or icon.none then return nil end
    if icon.isDefault then
        local info = nameLower and PIListEntry(nameLower)
        if not info or not info.texture then return nil end
        return info.texture, 1.0
    end
    return icon.texture, icon.alpha or 1.0
end

local function PIMyNameLower()
    local name = GetDisplayName()
    if not name or name == "" then return nil end
    return string.lower(name)
end

local function PIRoundHeight(v)
    v = zo_clamp(tonumber(v) or 0, PI.HEIGHT_MIN, PI.HEIGHT_MAX)
    return math.floor(v * 10 + 0.5) / 10
end

local function PIRoundSize(v)
    v = zo_clamp(tonumber(v) or 100, PI.SIZE_MIN, PI.SIZE_MAX)
    return math.floor(v / PI.SIZE_STEP + 0.5) * PI.SIZE_STEP
end

local function PIIsChoiceAllowedForMe(index)
    local icon = index and PvPUA.constants.iconChoices[index]
    if not icon then return false end
    if icon.isDefault then
        local me = PIMyNameLower()
        local info = me and PIListEntry(me)
        return info ~= nil and info.texture ~= nil
    end
    return true
end

function PI.GetCategoryChoices()
    local list = {}
    for i, category in ipairs(PvPUA.constants.iconCategories) do
        list[i] = { name = category.name, value = category.id }
    end
    return list
end

function PI.GetIconCategory(index)
    local icon = index and PvPUA.constants.iconChoices[index]
    return icon and icon.category or PvPUA.constants.iconCategories[1].id
end

function PI.GetFirstIconInCategory(categoryId)
    for i, icon in ipairs(PvPUA.constants.iconChoices) do
        if icon.category == categoryId and PIIsChoiceAllowedForMe(i) then return i end
    end
    return nil
end

function PI.GetMyCategory()
    return PI.GetIconCategory(PI.GetMyIcon())
end

function PI.RefreshIconMenu()
    zo_callLater(function()
        local lcm = rawget(_G, "LibConsoleMenu")
        if lcm and lcm.list and lcm.list.RefreshVisible then
            pcall(lcm.list.RefreshVisible, lcm.list)
        end
    end, 1)
end

function PI.SetMyCategory(categoryId)
    if categoryId == PI.GetMyCategory() then return end
    local first = PI.GetFirstIconInCategory(categoryId)
    if not first then return end
    PI.SetMyIcon(first)
    PI.RefreshIconMenu()
end

function PI.BuildPickerChoices(categoryId)
    categoryId = categoryId or PI.GetMyCategory()
    PI.pickerToIndex = {}
    PI.indexToPicker = {}
    local textures = {}
    local me = PIMyNameLower()
    for i, icon in ipairs(PvPUA.constants.iconChoices) do
        if icon.category == categoryId and PIIsChoiceAllowedForMe(i) then
            local texture = icon.texture
            if icon.isDefault then texture = PIIconTexture(i, me) end
            textures[#textures + 1] = texture
            PI.pickerToIndex[#textures] = i
            PI.indexToPicker[i] = #textures
        end
    end
    return textures
end

function PI.GetMyPickerIndex()
    PI.BuildPickerChoices()
    return PI.indexToPicker[PI.GetMyIcon()] or 1
end

function PI.SetMyPickerIndex(pickerIndex)
    PI.BuildPickerChoices()
    local index = PI.pickerToIndex[tonumber(pickerIndex) or 1]
    if index then PI.SetMyIcon(index) end
end

function PI.GetMyDefaults()
    local me = PIMyNameLower()
    local iconIndex, sizePct, height, opacity
    if me then
        iconIndex, sizePct, height, opacity = PIListStyle(me)
    end
    return iconIndex or PvPUA.constants.ICON_NONE, PIRoundSize(sizePct or 100), PIRoundHeight(height or 0), PIRoundOpacity(opacity or 100)
end

function PI.GetMyIcon()
    local sv = PvPUA.savedVariables
    local index = sv and tonumber(sv.iconChoice)
    if index and PIIsChoiceAllowedForMe(index) then return index end
    local defaultIndex = PI.GetMyDefaults()
    return defaultIndex
end

function PI.GetMySize()
    local cv = PvPUA.charVariables
    if cv and cv.iconSize ~= nil then return PIRoundSize(cv.iconSize) end
    local _, defaultSize = PI.GetMyDefaults()
    return defaultSize
end

function PI.GetMyHeight()
    local cv = PvPUA.charVariables
    if cv and cv.iconHeight ~= nil then return PIRoundHeight(cv.iconHeight) end
    local _, _, defaultHeight = PI.GetMyDefaults()
    return defaultHeight
end

function PI.OnMyStyleChanged(delay)
    PI.ScheduleGroupRefresh()
    PI.ScheduleBroadcast(delay or 500)
end

function PI.SetMyIcon(index)
    index = tonumber(index)
    if not index or not PIIsChoiceAllowedForMe(index) then return end
    PvPUA.savedVariables.iconChoice = index
    PI.OnMyStyleChanged()
end

function PI.SetMySize(v)
    PvPUA.charVariables.iconSize = PIRoundSize(v)
    PI.OnMyStyleChanged(750)
end

function PI.SetMyHeight(v)
    PvPUA.charVariables.iconHeight = PIRoundHeight(v)
    PI.OnMyStyleChanged(750)
end

function PI.GetMyOpacity()
    local cv = PvPUA.charVariables
    if cv and cv.iconOpacity ~= nil then return PIRoundOpacity(cv.iconOpacity) end
    local _, _, _, defaultOpacity = PI.GetMyDefaults()
    return defaultOpacity
end

function PI.SetMyOpacity(v)
    PvPUA.charVariables.iconOpacity = PIRoundOpacity(v)
    PI.OnMyStyleChanged(750)
end

local function PIResolve(unit, nameLower)
    if unit == "player" then
        return PI.GetMyIcon(), PI.GetMySize(), PI.GetMyHeight(), PI.GetMyOpacity()
    end
    local r = PI.remote[nameLower]
    if r then
        return r.icon, r.size, r.height, r.opacity
    end
    return PIListStyle(nameLower)
end

function PI.Init()
    PI.toplevel = wm:CreateTopLevelWindow("PvPUA_PIWin")
    PI.toplevel:SetDrawLayer(0)
end

local function PIGetMarker(nameLower)
    local marker = PI.markers[nameLower]
    if not marker then
        marker = PICreate3D(PI.toplevel, ICON_MARKER_DATA)
        PI.markers[nameLower] = marker
    end
    return marker
end

local PI_SEEN = {}

local function PIShowUnit(unit, nameLower)
    local iconIndex, sizePct, height, opacity = PIResolve(unit, nameLower)
    local texture, alpha = PIIconTexture(iconIndex, nameLower)
    if not texture then return end

    local marker = PIGetMarker(nameLower)
    marker:applyStyle(texture, alpha * (opacity or 100) / 100, sizePct, height)
    if not marker.enabled then
        marker:enable()
        marker:show()
    end
    local _, Xw, Yw, Zw = GetUnitRawWorldPosition(unit)
    local X, Y, Z = WorldPositionToGuiRender3DPosition(Xw, Yw, Zw)
    marker:setPos(X, Y, Z)
    PI_SEEN[nameLower] = true
end

function PI.updateMarker()
    local sv = PvPUA.savedVariables
    if not sv or not PI.toplevel then return end

    for k in pairs(PI_SEEN) do PI_SEEN[k] = nil end

    if sv.iconShowSelf then
        local selfName = GetDisplayName()
        if selfName and selfName ~= "" then
            PIShowUnit("player", string.lower(selfName))
        end
    end

    if sv.iconShowOthers and IsUnitGrouped("player") then
        for i = 1, 12 do
            local unit = "group" .. i
            if DoesUnitExist(unit) and IsUnitOnline(unit) and not AreUnitsEqual(unit, "player") then
                local dn = GetUnitDisplayName(unit)
                if dn and dn ~= "" then
                    PIShowUnit(unit, string.lower(dn))
                end
            end
        end
    end

    for nameLower, marker in pairs(PI.markers) do
        if marker.enabled and not PI_SEEN[nameLower] then
            marker:disable()
        end
    end
end

function PI.StartPolling()
    if PI.running then return end
    EVENT_MANAGER:RegisterForUpdate("PvPUA_PlayerIconUpdate", PI.updateInterval, function()
        local ok = pcall(PI.updateMarker)
        if not ok then
            EVENT_MANAGER:UnregisterForUpdate("PvPUA_PlayerIconUpdate")
            PI.running = false
        end
    end)
    PI.running = true
end

function PI.StopPolling()
    if not PI.running then return end
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_PlayerIconUpdate")
    PI.running = false
    for _, marker in pairs(PI.markers) do
        marker:disable()
    end
end

--------------------------------------------------
-- Icon Sharing
--------------------------------------------------
local ICON_PROTOCOL_ID   = 271
local ICON_PROTOCOL_NAME = "PvPUAIconStyle"

local function PIEncodeSize(v)
    return zo_clamp(math.floor((PIRoundSize(v) - PI.SIZE_MIN) / PI.SIZE_STEP + 0.5), 0, 63)
end

local function PIDecodeSize(steps)
    return PIRoundSize(PI.SIZE_MIN + (tonumber(steps) or 10) * PI.SIZE_STEP)
end

local function PIEncodeHeight(v)
    return zo_clamp(math.floor((PIRoundHeight(v) - PI.HEIGHT_MIN) / PI.HEIGHT_STEP + 0.5), 0, 63)
end

local function PIDecodeHeight(steps)
    return PIRoundHeight(PI.HEIGHT_MIN + (tonumber(steps) or 10) * PI.HEIGHT_STEP)
end

local function PIEncodeOpacity(v)
    return zo_clamp(math.floor((PIRoundOpacity(v) - PI.OPACITY_MIN) / PI.OPACITY_STEP + 0.5), 0, 31)
end

local function PIDecodeOpacity(steps)
    return PIRoundOpacity(PI.OPACITY_MIN + (tonumber(steps) or 16) * PI.OPACITY_STEP)
end

function PI.Broadcast(request)
    if not PI.protocol or not IsUnitGrouped("player") then return end
    if not PvPUA.savedVariables or not PvPUA.charVariables then return end
    PI.protocol:Send({
        icon    = PI.GetMyIcon(),
        size    = PIEncodeSize(PI.GetMySize()),
        height  = PIEncodeHeight(PI.GetMyHeight()),
        opacity = PIEncodeOpacity(PI.GetMyOpacity()),
        request = request == true,
    })
end

function PI.ScheduleBroadcast(delay, request)
    if not PI.protocol then return end
    if request then PI.pendingRequest = true end
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_IconBroadcast")
    EVENT_MANAGER:RegisterForUpdate("PvPUA_IconBroadcast", delay or 1000, function()
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_IconBroadcast")
        local wantReply = PI.pendingRequest == true
        PI.pendingRequest = false
        pcall(PI.Broadcast, wantReply)
    end)
end

function PI.PruneRemote()
    if not IsUnitGrouped("player") then
        for k in pairs(PI.remote) do PI.remote[k] = nil end
        return
    end
    local present = {}
    for i = 1, 12 do
        local unit = "group" .. i
        if DoesUnitExist(unit) then
            local dn = GetUnitDisplayName(unit)
            if dn and dn ~= "" then present[string.lower(dn)] = true end
        end
    end
    for nameLower in pairs(PI.remote) do
        if not present[nameLower] then PI.remote[nameLower] = nil end
    end
end

local function PIOnIconData(unitTag, data)
    if type(unitTag) ~= "string" or type(data) ~= "table" then return end
    if not DoesUnitExist(unitTag) or AreUnitsEqual(unitTag, "player") then return end

    local dn = GetUnitDisplayName(unitTag)
    if not dn or dn == "" then return end

    if data.request then
        PI.ScheduleBroadcast(500)
    end

    local iconIndex = tonumber(data.icon)
    if not iconIndex or not PvPUA.constants.iconChoices[iconIndex] then return end

    PI.remote[string.lower(dn)] = {
        icon   = iconIndex,
        size   = PIDecodeSize(data.size),
        height = PIDecodeHeight(data.height),
        opacity = PIDecodeOpacity(data.opacity),
    }
    PI.ScheduleGroupRefresh()
end

local function PIOnGroupChanged()
    PI.PruneRemote()
    PI.ScheduleGroupRefresh()
    PI.ScheduleBroadcast(500)
end

function PI.InitNetwork()
    local LGB = rawget(_G, "LibGroupBroadcast")
    if type(LGB) ~= "table" or type(LGB.RegisterHandler) ~= "function" then return end

    local handler = LGB:RegisterHandler(PvPUA.name, "PvPUAIcon")
    if not handler then return end
    handler:SetDisplayName("PvP UA!")
    handler:SetDescription("Shares your PvPUA icon, size and height with group members.")

    local protocol = handler:DeclareProtocol(ICON_PROTOCOL_ID, ICON_PROTOCOL_NAME)
    protocol:AddField(LGB.CreateNumericField("icon",   { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("size",   { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("height", { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("opacity", { minValue = 0, maxValue = 31, trimValues = true }))
    protocol:AddField(LGB.CreateFlagField("request", { defaultValue = false }))
    protocol:OnData(PIOnIconData)
    protocol:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true })
    PI.protocol = protocol

    local ns = PvPUA.name .. "_IconNet"
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_PLAYER_ACTIVATED, function()
        PI.PruneRemote()
        PI.ScheduleBroadcast(1000, true)
    end)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_JOINED, PIOnGroupChanged)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_LEFT, PIOnGroupChanged)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_CONNECTED_STATUS, PIOnGroupChanged)
end

--------------------------------------------------
-- Group Frame Icons
--------------------------------------------------
local function PIGetGroupFrameIconInfo(unitTag, frameStyle)
    local sv = PvPUA.savedVariables
    if not sv or type(unitTag) ~= "string" then return nil end
    if frameStyle == "ZO_RaidUnitFrame" then
        if not sv.iconShowLargeGroupFrames then return nil end
    elseif not sv.iconShowSmallGroupFrames then
        return nil
    end
    if not string.match(unitTag, "^group%d+$") then return nil end

    local displayName = GetUnitDisplayName(unitTag)
    if not displayName or displayName == "" then return nil end

    local unit = unitTag
    if AreUnitsEqual(unitTag, "player") then
        if not sv.iconShowSelf then return nil end
        unit = "player"
    elseif not sv.iconShowOthers then
        return nil
    end

    local nameLower = string.lower(displayName)
    local iconIndex, _, _, opacity = PIResolve(unit, nameLower)
    local texture, alpha = PIIconTexture(iconIndex, nameLower)
    if not texture then return nil end
    return texture, alpha * (opacity or 100) / 100
end

local function PIUpdateGroupFrameIcon(frame)
    local electionIcon = frame.electionIcon
    if not electionIcon then return end

    local texture, alpha = PIGetGroupFrameIconInfo(frame.unitTag, frame.style)
    if not texture or not electionIcon:IsHidden() then
        if frame.piIcon then
            frame.piIcon:SetHidden(true)
        end
        return
    end

    if not frame.piIcon then
        frame.piIcon = wm:CreateControl(nil, frame.frame, CT_TEXTURE)
        frame.piIcon:SetDrawLayer(DL_OVERLAY)
    end

    local icon = frame.piIcon
    local width, height = electionIcon:GetDimensions()
    icon:ClearAnchors()
    icon:SetAnchor(CENTER, electionIcon, CENTER, 0, 0)
    icon:SetDimensions(width * 2, height * 2)
    icon:SetTexture(texture)
    icon:SetAlpha(alpha or 1.0)
    icon:SetHidden(false)
end

function PI.RefreshGroupFrameIcons()
    if UNIT_FRAMES and UNIT_FRAMES.UpdateNames then
        pcall(UNIT_FRAMES.UpdateNames, UNIT_FRAMES)
    end
end

function PI.ScheduleGroupRefresh()
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_GroupIconRefresh")
    EVENT_MANAGER:RegisterForUpdate("PvPUA_GroupIconRefresh", 100, function()
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_GroupIconRefresh")
        PI.RefreshGroupFrameIcons()
    end)
end

function PI.InitGroupFrameIcons()
    if PI.groupFrameHooked then return end
    if not (ZO_PostHook and ZO_UnitFrameObject and ZO_UnitFrameObject.UpdateName) then return end

    ZO_PostHook(ZO_UnitFrameObject, "UpdateName", function(frame)
        pcall(PIUpdateGroupFrameIcon, frame)
    end)
    ZO_PostHook(ZO_UnitFrameObject, "RefreshElectionIcon", function(frame)
        pcall(PIUpdateGroupFrameIcon, frame)
    end)
    PI.groupFrameHooked = true

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_GroupIconsUpdate", EVENT_GROUP_UPDATE, PI.ScheduleGroupRefresh)
    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_GroupIconsJoined", EVENT_GROUP_MEMBER_JOINED, PI.ScheduleGroupRefresh)
end

--------------------------------------------------
-- Timer Colors
--------------------------------------------------
local function GetTimerColor()
    local c = PvPUA.savedVariables and PvPUA.savedVariables.timerColor
    if type(c) == "table" then
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 1, 1, 1
end

function PvPUA:GetFont()
    if not self.cachedFont then
        local path = self.savedVariables and self.savedVariables.font or "EsoUI/Common/Fonts/FTN47.otf"
        local size = "25"
        self.cachedFont = path .. "|" .. size .. "|outline"
    end
    return self.cachedFont
end

function PvPUA:InvalidateFontCache()
    self.cachedFont = nil
end

--------------------------------------------------
-- Alliance Colors
--------------------------------------------------
local function GetColorForAlliance(alliance)
    return GetAllianceColor(alliance)
end

local function ToHex(r, g, b)
    return string.format("%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255))
end

local function ColorText(text, r, g, b)
    return "|c" .. ToHex(r, g, b) .. text .. "|r"
end

local rainbowPalette = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }
local function RainbowText(text)
    local out = {}
    local idx = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then
            out[#out + 1] = ch
        else
            local color = rainbowPalette[((idx - 1) % #rainbowPalette) + 1]
            out[#out + 1] = "|c" .. color .. ch .. "|r"
            idx = idx + 1
        end
    end
    return table.concat(out)
end

local function GetGuildAllianceColor(guildId)
    if not guildId or guildId <= 0 then return GetAllianceColor(ALLIANCE_NONE) end
    local alliance = GetGuildAlliance(guildId)
    return GetColorForAlliance(alliance)
end

--------------------------------------------------
-- Volendrung Helpers
--------------------------------------------------
local function GetVolendrungTexture(pinType)
    if pinType and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType] then
        local tex = ZO_MapPin.PIN_DATA[pinType].texture
        if tex and type(tex) == "string" then return tex end
    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI    then return "/esoui/art/mappins/ava_daedricartifact_volendrung_aldmeri.dds"    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_DAGGERFALL  then return "/esoui/art/mappins/ava_daedricartifact_volendrung_daggerfall.dds"  end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_EBONHEART   then return "/esoui/art/mappins/ava_daedricartifact_volendrung_ebonheart.dds"   end
    return "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds"
end

local function GetVolendrungAlliance(pinType)
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI    then return ALLIANCE_ALDMERI_DOMINION    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_DAGGERFALL  then return ALLIANCE_DAGGERFALL_COVENANT  end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_EBONHEART   then return ALLIANCE_EBONHEART_PACT       end
    return 0
end

--------------------------------------------------
-- Zone Detection
--------------------------------------------------
local function IsInICCampaign()
    if not (GetCurrentCampaignId and IsImperialCityCampaign) then return false end
    local ok, result = pcall(function()
        local id = GetCurrentCampaignId()
        return id ~= 0 and IsImperialCityCampaign(id) == true
    end)
    return ok and result == true
end

local function IsInCyrodiilOrIC()
    if IsInICCampaign() == true then
        return true
    elseif IsInCyrodiil() == true then
        return true
    elseif IsInCyrodiil() == false and IsPlayerInAvAWorld() == true and IsInAvAZone() == true and IsInImperialCity() == false and IsActiveWorldBattleground() == false then
        return true
    else
        return false
    end
end

--------------------------------------------------
-- Name Helpers
--------------------------------------------------
local function AdjustDistrictName(name)
    if name == nil then return "" end
    name = name:gsub(" District", "")
    return name
end

local function AdjustResourceName(name)
    name = name:gsub("Castle ", ""):gsub("[fF]ort ", ""):gsub("Keep ", ""):gsub("[Ll]umbermill", "Lumber")
    return name
end

local function AdjustKeepName(name)
    name = name:gsub(",..$", ""):gsub("Castle ", ""):gsub("[fF]ort ", ""):gsub("Keep ", ""):gsub("Keep", "")
    return name
end

local function AdjustOutpostName(name)
    name = name:gsub("Outpost", "")
    return name
end

--------------------------------------------------
-- Init Functions
--------------------------------------------------
function PvPUA:InitResources(gameTime)
    local resources = { 22, 23, 24, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
                        61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87 }
    self.state.resources = {}
    for i = 1, #resources do
        local id = resources[i]
        self.state.resources[id] = {}
        self.state.resources[id].id = id
        self.state.resources[id].keepType = GetKeepType(id)
        self.state.resources[id].name = AdjustResourceName(zo_strformat("<<1>>", GetKeepName(id)))
        self.state.resources[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.resources[id].isUnderAttack == true then
            self.state.resources[id].interestingSince = gameTime
        else
            self.state.resources[id].interestingSince = nil
        end
        self.state.resources[id].attackStatusLostAt = 0
        self.state.resources[id].underAttackFor = 0
        self.state.resources[id].siegeWeapons = {}
        self.state.resources[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.resources[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.resources[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.resources[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitKeeps(gameTime)
    self.state.keeps = {}
    for i = 3, 20 do
        self.state.keeps[i] = {}
        self.state.keeps[i].id = i
        self.state.keeps[i].keepType = GetKeepType(i)
        self.state.keeps[i].name = AdjustKeepName(zo_strformat("<<1>>", GetKeepName(i)))
        self.state.keeps[i].isUnderAttack = GetKeepUnderAttack(i, BGQUERY_LOCAL)
        if self.state.keeps[i].isUnderAttack == true then
            self.state.keeps[i].interestingSince = gameTime
        else
            self.state.keeps[i].interestingSince = nil
        end
        self.state.keeps[i].attackStatusLostAt = 0
        self.state.keeps[i].underAttackFor = 0
        self.state.keeps[i].siegeWeapons = {}
        self.state.keeps[i].siegeWeapons.AD = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.keeps[i].siegeWeapons.DC = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.keeps[i].siegeWeapons.EP = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.keeps[i].owningAlliance = GetKeepAlliance(i, BGQUERY_LOCAL)
        self.state.keeps[i].resources = {}
        local farmId = GetResourceKeepForKeep(i, RESOURCETYPE_FOOD)
        local lumberId = GetResourceKeepForKeep(i, RESOURCETYPE_WOOD)
        local mineId = GetResourceKeepForKeep(i, RESOURCETYPE_ORE)
        if self.state.resources[farmId] then
            self.state.resources[farmId].rType = PvPUA.constants.resourceType.FARM
        end
        if self.state.resources[lumberId] then
            self.state.resources[lumberId].rType = PvPUA.constants.resourceType.LUMBER
        end
        if self.state.resources[mineId] then
            self.state.resources[mineId].rType = PvPUA.constants.resourceType.MINE
        end
    end
    local allianceHomeKeepNames = {
        [ALLIANCE_ALDMERI_DOMINION]    = { "Alessia", "Black Boot", "Bloodmayne", "Brindle", "Faregyl", "Roebeck" },
        [ALLIANCE_DAGGERFALL_COVENANT] = { "Aleswell", "Ash", "Dragonclaw", "Glademist", "Rayles", "Warden" },
        [ALLIANCE_EBONHEART_PACT]      = { "Arrius", "Blue Road", "Chalman", "Drakelowe", "Farragut", "Kingscrest" },
    }
    self.homeKeepIds = {}
    self.emperorKeepIds = {}
    for i = 3, 20 do
        local rawName = zo_strformat("<<1>>", GetKeepName(i))
        for alliance, names in pairs(allianceHomeKeepNames) do
            for _, hkName in ipairs(names) do
                if rawName:find(hkName) then
                    self.homeKeepIds[i] = alliance
                    break
                end
            end
        end
        for slot = 1, #PvPUA.constants.emperorKeeps do
            if self.emperorKeepIds[slot] == nil
               and rawName:find(PvPUA.constants.emperorKeeps[slot].name) then
                self.emperorKeepIds[slot] = i
                break
            end
        end
    end
end

function PvPUA:InitOutposts(gameTime)
    local outposts = { 132, 133, 134, 163, 164, 165 }
    self.state.outposts = {}
    for i = 1, #outposts do
        local id = outposts[i]
        self.state.outposts[id] = {}
        self.state.outposts[id].id = id
        self.state.outposts[id].keepType = GetKeepType(id)
        self.state.outposts[id].name = AdjustOutpostName(zo_strformat("<<1>>", GetKeepName(id)))
        self.state.outposts[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.outposts[id].isUnderAttack == true then
            self.state.outposts[id].interestingSince = gameTime
        else
            self.state.outposts[id].interestingSince = nil
        end
        self.state.outposts[id].attackStatusLostAt = 0
        self.state.outposts[id].underAttackFor = 0
        self.state.outposts[id].siegeWeapons = {}
        self.state.outposts[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.outposts[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.outposts[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.outposts[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitVillages(gameTime)
    local villages = { 149, 151, 152 }
    self.state.villages = {}
    for i = 1, #villages do
        local id = villages[i]
        self.state.villages[id] = {}
        self.state.villages[id].id = id
        self.state.villages[id].keepType = GetKeepType(id)
        self.state.villages[id].name = zo_strformat("<<1>>", GetKeepName(id))
        self.state.villages[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.villages[id].isUnderAttack == true then
            self.state.villages[id].interestingSince = gameTime
        else
            self.state.villages[id].interestingSince = nil
        end
        self.state.villages[id].attackStatusLostAt = 0
        self.state.villages[id].underAttackFor = 0
        self.state.villages[id].siegeWeapons = {}
        self.state.villages[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.villages[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.villages[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.villages[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitDestructibles(gameTime)
    self.state.destructibles = {}
    for i = 154, 162 do
        self.state.destructibles[i] = {}
        self.state.destructibles[i].id = i
        self.state.destructibles[i].keepType = GetKeepType(i)
        self.state.destructibles[i].name = AdjustResourceName(zo_strformat("<<1>>", GetKeepName(i)))
        self.state.destructibles[i].isUnderAttack = GetKeepUnderAttack(i, BGQUERY_LOCAL)
        if self.state.destructibles[i].isUnderAttack == true then
            self.state.destructibles[i].interestingSince = gameTime
        else
            self.state.destructibles[i].interestingSince = nil
        end
        self.state.destructibles[i].attackStatusLostAt = 0
        self.state.destructibles[i].underAttackFor = 0
        self.state.destructibles[i].isPassable = IsKeepPassable(i, BGQUERY_LOCAL)
        self.state.destructibles[i].directionalAccess = GetKeepDirectionalAccess(i, BGQUERY_LOCAL)
    end
end

function PvPUA:InitDistricts(gameTime)
    self.state.districts = {}
    if not (GetNumKeeps and GetKeepKeysByIndex) then return end
    pcall(function()
        local n = GetNumKeeps() or 0
        for i = 1, n do
            local id = GetKeepKeysByIndex(i)
            if id and id ~= 0 and GetKeepType(id) == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
                local d = {}
                d.id = id
                d.keepType = KEEPTYPE_IMPERIAL_CITY_DISTRICT
                d.name = AdjustDistrictName(zo_strformat("<<1>>", GetKeepName(id)))
                d.isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
                if d.isUnderAttack == true then d.interestingSince = gameTime end
                d.attackStatusLostAt = 0
                d.underAttackFor = 0
                d.owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
                d.objectives = { { id = nil, state = 100, holdingAlliance = d.owningAlliance } }
                self.state.districts[id] = d
            end
        end
    end)
end

function PvPUA:InitState(hadVolendrung)
    local gameTime = GetGameTimeMilliseconds()

    if IsInICCampaign() then
        self.state.resources = {}
        self.state.keeps = {}
        self.state.outposts = {}
        self.state.villages = {}
        self.state.destructibles = {}
        self.homeKeepIds = {}
        self:InitDistricts(gameTime)
        self:AddObjectives()
        return
    end

    self.state.districts = {}
    self:InitResources(gameTime)
    self:InitKeeps(gameTime)
    self:InitOutposts(gameTime)
    self:InitVillages(gameTime)
    self:InitDestructibles(gameTime)
    self:AddObjectives()
    self:ScanForVolendrung()
    self:ScanForScrolls()
    if self.volendrung == nil and hadVolendrung then
        self.volendrung = hadVolendrung
        self.volendrung.despawnAt = GetGameTimeMilliseconds() + VOLENDRUNG_DESPAWN_GRACE
    end
end

--------------------------------------------------
-- ScanForVolendrung
--------------------------------------------------
function PvPUA:ScanForVolendrung()
    if not GetNumObjectives then return end
    local n = GetNumObjectives()
    if not n then return end
    for i = 1, n do
        local keepId, objectiveId = GetObjectiveIdsForIndex(i)
        if keepId and objectiveId then
            local _, objectiveType, objectiveState = GetObjectiveInfo(keepId, objectiveId, BGQUERY_LOCAL)
            if objectiveType == OBJECTIVE_DAEDRIC_WEAPON then
                local objectiveControlEvent = GetLastObjectiveControlEvent(keepId, objectiveId, BGQUERY_LOCAL)
                if objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED
                or objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_HELD
                or objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED
                or (objectiveState ~= nil and objectiveState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN) then
                    local pinType = GetObjectivePinInfo(keepId, objectiveId, BGQUERY_LOCAL)
                    self.volendrung = {
                        texture        = GetVolendrungTexture(pinType),
                        holderAlliance = GetVolendrungAlliance(pinType),
                        objectiveId    = objectiveId,
                        keepId         = keepId,
                        despawnAt      = nil,
                        spawnedAt      = GetGameTimeMilliseconds(),
                    }
                    return
                end
            end
        end
    end
end

local SCROLL_TEXTURE_FALLBACK = {
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_OFFENSIVE]     = "/esoui/art/mappins/ava_artifact_altadoon.dds",
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_DEFENSIVE]     = "/esoui/art/mappins/ava_artifact_mnem.dds",
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_OFFENSIVE]   = "/esoui/art/mappins/ava_artifact_ghartok.dds",
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_DEFENSIVE]   = "/esoui/art/mappins/ava_artifact_chim.dds",
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_OFFENSIVE]  = "/esoui/art/mappins/ava_artifact_nimohk.dds",
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_DEFENSIVE]  = "/esoui/art/mappins/ava_artifact_almaruma.dds",
}

local SCROLL_PINTYPE_ALLIANCE = {
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_OFFENSIVE]     = ALLIANCE_ALDMERI_DOMINION,
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_DEFENSIVE]     = ALLIANCE_ALDMERI_DOMINION,
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_OFFENSIVE]   = ALLIANCE_EBONHEART_PACT,
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_DEFENSIVE]   = ALLIANCE_EBONHEART_PACT,
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_OFFENSIVE]  = ALLIANCE_DAGGERFALL_COVENANT,
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_DEFENSIVE]  = ALLIANCE_DAGGERFALL_COVENANT,
}

local function GetScrollTexture(pinType)
    if pinType and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType] then
        local tex = ZO_MapPin.PIN_DATA[pinType].texture
        if tex and type(tex) == "string" then return tex end
    end
    return SCROLL_TEXTURE_FALLBACK[pinType]
end

--------------------------------------------------
-- Scroll Display
--------------------------------------------------
function PvPUA:RefreshScrolls()
    local ok = pcall(function()
        for _, keep in pairs(self.state.keeps) do keep.scroll = nil end
        for _, town in pairs(self.state.villages) do town.scroll = nil end

        if not GetNumObjectives then return end
        local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
        local n = GetNumObjectives() or 0
        for i = 1, n do
            local keepId, objectiveId, ctx = keysFn(i)
            if keepId and objectiveId then
                local ctxUse = ctx or BGQUERY_LOCAL
                local _, oType, oState = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                if (oType == OBJECTIVE_ARTIFACT_OFFENSIVE or oType == OBJECTIVE_ARTIFACT_DEFENSIVE)
                and oState == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                    local atKeep
                    if GetKeepThatHasCapturedThisArtifactScrollObjective then
                        atKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(keepId, objectiveId, ctxUse)
                    end
                    local target
                    if atKeep and atKeep ~= 0 then
                        target = self.state.keeps[atKeep] or self.state.villages[atKeep]
                    end
                    if target then
                        local pinType = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        local home
                        if GetArtifactScrollObjectiveOriginalOwningAlliance then
                            home = GetArtifactScrollObjectiveOriginalOwningAlliance(keepId, objectiveId, ctxUse)
                        end
                        if not home or home == 0 then home = SCROLL_PINTYPE_ALLIANCE[pinType] or 0 end
                        if pinType then
                            target.scroll = {
                                pinType         = pinType,
                                holdingAlliance = home,
                                objectiveId     = objectiveId,
                            }
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        for _, keep in pairs(self.state.keeps) do keep.scroll = nil end
        for _, town in pairs(self.state.villages) do town.scroll = nil end
    end
end

function PvPUA:ScanForScrolls()
    self:RefreshScrolls()
end

local SCROLL_CARRIER_GRACE = 30000

local SCROLL_KEEP_ICON_SCALE        = PvPUA.config.iconScale.scrollOnKeep
local SCROLL_CARRIER_ICON_SCALE     = PvPUA.config.iconScale.scrollCarrier
local VOLENDRUNG_CARRIER_ICON_SCALE = PvPUA.config.iconScale.volendrung

PvPUA.scrollCarriers = {}

PvPUA.artifactHolders = {}
PvPUA.artifactHolderAlliance = {}

local function ScrollKey(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub("^Elder Scroll of ", ""):gsub("^Scroll of ", "")
    return string.lower(name)
end

function PvPUA:OnArtifactControlState(_, artifactName, keepId, characterName, playerAlliance, objectiveControlEvent, objectiveControlState, campaignId, displayName)
    if campaignId == 0 then return end
    local key = artifactName and ScrollKey(artifactName) or nil
    if not key or key == "" then return end
    if objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_TAKEN then
        local nm = displayName or characterName or ""
        if type(nm) == "string" then
            local stripped = (nm:gsub("^@", ""))
            if stripped ~= "" then nm = stripped end
        end
        self.artifactHolders[key] = nm
        self.artifactHolderAlliance[key] = playerAlliance or 0
    elseif objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED then
        self.artifactHolders[key] = ""
        self.artifactHolderAlliance[key] = 0
    end
end

local function ShortenScrollName(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub("^Elder Scroll of ", ""):gsub("^Scroll of ", "")
    return name
end

local function ShortenPOIName(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub(",..$", "")
                :gsub("%^.d$", "")
                :gsub(" Wayshrine", "")
                :gsub("District", "")
                :gsub("Castle ", "")
                :gsub("[fF]ort ", "")
                :gsub("[Ll]umber ?[Mm]ill", "Lumber")
                :gsub("^Scroll Temple of ", "Temple of ")
                :gsub("Keep ", "")
                :gsub("Keep$", "")
                :gsub("Outpost", "")
    name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

PvPUA.locationCache = PvPUA.locationCache or {}

function PvPUA:BuildLocationCache()
    local mapId = GetCurrentMapId and GetCurrentMapId() or 0
    if self.locationCache[mapId] then return self.locationCache[mapId] end

    local list = {}

    for keepId = 1, 200 do
        local _, nx, ny = GetKeepPinInfo(keepId, BGQUERY_LOCAL)
        local keepName = GetKeepName and GetKeepName(keepId) or nil
        if nx and ny and not (nx == 0 and ny == 0)
           and keepName and keepName ~= "" then
            list[#list + 1] = { x = nx, y = ny, name = ShortenPOIName(keepName) }
        end
    end

    if #list == 0 then return {} end

    if GetNumPOIs and GetPOIMapInfo and GetPOIInfo then
        local zoneIndex = GetCurrentMapZoneIndex and GetCurrentMapZoneIndex() or nil
        if zoneIndex then
            local count = GetNumPOIs(zoneIndex) or 0
            for poiIndex = 1, count do
                local nx, ny = GetPOIMapInfo(zoneIndex, poiIndex)
                local poiName = GetPOIInfo(zoneIndex, poiIndex)
                if nx and ny and not (nx == 0 and ny == 0)
                   and poiName and poiName ~= "" then
                    list[#list + 1] = { x = nx, y = ny, name = ShortenPOIName(poiName) }
                end
            end
        end
    end

    self.locationCache[mapId] = list
    return list
end

function PvPUA:GetClosestLocationName(x, y)
    if not x or not y then return "" end
    if x == 0 and y == 0 then return "" end

    local list = self:BuildLocationCache()
    local bestName, bestDistSq = "", math.huge
    for i = 1, #list do
        local v = list[i]
        local dx = v.x - x
        local dy = v.y - y
        local dsq = dx * dx + dy * dy
        if dsq < bestDistSq then
            bestDistSq = dsq
            bestName = v.name
        end
    end
    return bestName
end

function PvPUA:RefreshScrollCarriers()
    local ok = pcall(function()
        local now = GetGameTimeMilliseconds()
        local seen = {}

        if GetNumObjectives then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local oName, oType, oState = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                    if (oType == OBJECTIVE_ARTIFACT_OFFENSIVE or oType == OBJECTIVE_ARTIFACT_DEFENSIVE)
                    and (oState == OBJECTIVE_CONTROL_STATE_FLAG_HELD
                      or oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED) then

                        local key = tostring(keepId) .. ":" .. tostring(objectiveId)
                        seen[key] = true

                        local c = self.scrollCarriers[key]
                        if not c then
                            c = { startedAt = now }
                            self.scrollCarriers[key] = c
                        end

                        local pinType, px, py = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        c.texture = GetScrollTexture(pinType)
                        c.scrollName = ShortenScrollName(oName)

                        c.scrollAlliance = SCROLL_PINTYPE_ALLIANCE[pinType] or 0

                        local nameKey = ScrollKey(oName)
                        local holderName, holderAlliance

                        if self.artifactHolders[nameKey] and self.artifactHolders[nameKey] ~= "" then
                            holderName = self.artifactHolders[nameKey]
                            holderAlliance = self.artifactHolderAlliance[nameKey]
                        end

                        local function pickHolder(raw, display)
                            if type(display) == "string" and display ~= "" then
                                local stripped = (display:gsub("^@", ""))
                                if stripped ~= "" then return stripped end
                            end
                            if type(raw) == "string" and raw ~= "" then return raw end
                            return nil
                        end

                        if (holderName == nil or holderName == "") and GetCarryableObjectiveHoldingCharacterInfo then
                            local raw, disp = GetCarryableObjectiveHoldingCharacterInfo(keepId, objectiveId, ctxUse)
                            holderName = pickHolder(raw, disp)
                        end
                        if (holderName == nil or holderName == "") and GetCarryableObjectiveLastHoldingCharacterInfo then
                            local raw, disp = GetCarryableObjectiveLastHoldingCharacterInfo(keepId, objectiveId, ctxUse)
                            holderName = pickHolder(raw, disp)
                        end
                        if (holderAlliance == nil or holderAlliance == 0) and GetCarryableObjectiveHoldingAllianceInfo then
                            local hA, lastA = GetCarryableObjectiveHoldingAllianceInfo(keepId, objectiveId, ctxUse)
                            holderAlliance = (hA and hA ~= 0) and hA or lastA
                        end

                        if oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED then
                            holderName = "Dropped"
                        elseif holderName == nil or holderName == "" then
                            holderName = "Held"
                        end
                        c.holder = holderName
                        c.holderAlliance = holderAlliance or 0
                        c.location = self:GetClosestLocationName(px, py)

                        if oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED then
                            c.droppedAt = c.droppedAt or now
                        else
                            c.droppedAt = nil
                        end
                    end
                end
            end
        end

        for key, c in pairs(self.scrollCarriers) do
            if not seen[key] then
                self.scrollCarriers[key] = nil
            elseif c.droppedAt and (now - c.droppedAt) > SCROLL_CARRIER_GRACE then
                self.scrollCarriers[key] = nil
            end
        end
    end)
    if not ok then self.scrollCarriers = {} end
end

function PvPUA:GetScrollCarrierItems()
    local out = {}
    local now = GetGameTimeMilliseconds()
    for key, c in pairs(self.scrollCarriers) do
        local scrollName = c.scrollName or ""
        local loc         = c.location or ""
        local who         = c.holder or ""
        local isDropped   = (c.droppedAt ~= nil)
        local sc = GetColorForAlliance(c.scrollAlliance or 0)
        local label = "|c" .. ToHex(sc.r, sc.g, sc.b) .. scrollName .. "|r"
        local hasPrefix = (scrollName ~= "")
        if loc ~= "" then
            label = label .. " @ " .. loc
            hasPrefix = true
        end
        if who ~= "" then
            local hc = GetColorForAlliance(c.holderAlliance or 0)
            local holderHex = isDropped and "FFFFFF" or ToHex(hc.r, hc.g, hc.b)
            local bracket = "|c" .. holderHex .. "[" .. who .. "]|r"
            label = hasPrefix and (label .. " " .. bracket) or bracket
        end
        out[#out + 1] = {
            isScrollCarrier = true,
            isScrollDropped = isDropped,
            id              = 0,
            name            = label,
            carrierTexture  = c.texture,
            scrollAlliance  = c.scrollAlliance or 0,
            owningAlliance  = c.holderAlliance or 0,
            isUnderAttack   = false,
            underAttackFor  = now - (c.startedAt or now),
            interestingSince = c.startedAt,
            siegeWeapons    = {},
        }
    end
    return out
end

local VOLENDRUNG_NEUTRAL_TEXTURE = "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds"

PvPUA.volendrungName    = nil

function PvPUA:RefreshVolendrungCarrier()
    local ok = pcall(function()
        local fKeep, fObj, fCtx, oName, oState, pinType, px, py

        if GetNumObjectives then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local nm, ty, st = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                    if ty == OBJECTIVE_DAEDRIC_WEAPON
                    and st ~= nil and st ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
                        fKeep, fObj, fCtx = keepId, objectiveId, ctxUse
                        oName, oState = nm, st
                        pinType, px, py = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        break
                    end
                end
            end
        end

        local activeId = GetActiveDaedricArtifactId and GetActiveDaedricArtifactId() or 0

        if fKeep or (activeId and activeId ~= 0) then
            local v = self.volendrung
            if not v then
                v = { spawnedAt = GetGameTimeMilliseconds() }
                self.volendrung = v
            end
            if fKeep then
                v.keepId, v.objectiveId, v.ctx = fKeep, fObj, fCtx
                v.texture = GetVolendrungTexture(pinType)
                v.holderAlliance = GetVolendrungAlliance(pinType) or 0
            end
            v.despawnAt = nil
            if activeId and activeId ~= 0 and GetDaedricArtifactDisplayName then
                local nm = GetDaedricArtifactDisplayName(activeId)
                if nm and nm ~= "" then self.volendrungName = zo_strformat("<<1>>", nm) end
            end
        end

        local v = self.volendrung
        if not v then return end

        local isDropped = (oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED)
        local isHeld    = (oState == OBJECTIVE_CONTROL_STATE_FLAG_HELD)

        local alliance
        if fKeep and GetCarryableObjectiveHoldingAllianceInfo then
            alliance = GetCarryableObjectiveHoldingAllianceInfo(fKeep, fObj, fCtx)
        end
        if not alliance or alliance == 0 then
            alliance = GetVolendrungAlliance(pinType) or 0
        end

        local holder
        local objKey = oName and oName ~= "" and ScrollKey(oName) or nil
        if objKey and self.artifactHolders[objKey]
           and self.artifactHolders[objKey] ~= "" and self.artifactHolders[objKey] ~= "?" then
            holder = self.artifactHolders[objKey]
        end

        if (holder == nil or holder == "") and fKeep then
            local function pick(raw, display)
                if type(display) == "string" and display ~= "" then
                    local stripped = (display:gsub("^@", ""))
                    if stripped ~= "" then return stripped end
                end
                if type(raw) == "string" and raw ~= "" then return raw end
                return nil
            end
            if GetCarryableObjectiveHoldingCharacterInfo then
                holder = pick(GetCarryableObjectiveHoldingCharacterInfo(fKeep, fObj, fCtx))
            end
            if (holder == nil or holder == "") and GetCarryableObjectiveLastHoldingCharacterInfo then
                holder = pick(GetCarryableObjectiveLastHoldingCharacterInfo(fKeep, fObj, fCtx))
            end
        end

        if holder and holder ~= "" then
            v.knownHolder         = holder
            v.knownHolderAlliance = alliance or 0
        elseif isHeld and v.knownHolder
           and v.knownHolderAlliance == (alliance or 0) and (alliance or 0) ~= 0 then
            holder = v.knownHolder .. "?"
        end
        if isDropped or (alliance or 0) == 0
           or (v.knownHolderAlliance and v.knownHolderAlliance ~= (alliance or 0)) then
            if not (holder and holder ~= "") then
                v.knownHolder, v.knownHolderAlliance = nil, nil
            end
        end

        if isDropped then
            v.holder      = "Dropped"
            v.rowAlliance = 0
        elseif isHeld then
            v.holder      = (holder and holder ~= "") and holder or "Held"
            v.rowAlliance = alliance or 0
        else
            v.holder      = nil
            v.rowAlliance = 0
        end

        if self.config.volendrungTintToHud then
            v.rowTexture = VOLENDRUNG_NEUTRAL_TEXTURE
        elseif v.rowAlliance == 0 then
            v.rowTexture = VOLENDRUNG_NEUTRAL_TEXTURE
        else
            v.rowTexture = GetVolendrungTexture(pinType) or VOLENDRUNG_NEUTRAL_TEXTURE
        end

        v.isDropped = isDropped
        v.location  = self:GetClosestLocationName(px, py)
        v.rowName   = (oName and oName ~= "" and zo_strformat("<<1>>", oName))
                      or self.volendrungName or "Volendrung"
    end)

    if not ok and self.volendrung then
        local v = self.volendrung
        v.holder, v.location, v.isDropped = nil, "", false
        v.rowAlliance = 0
        v.rowTexture  = VOLENDRUNG_NEUTRAL_TEXTURE
        v.rowName     = self.volendrungName or "Volendrung"
    end
end

function PvPUA:GetVolendrungCarrierItem()
    local v = self.volendrung
    if not v then return nil end

    local rowName   = v.rowName or self.volendrungName or "Volendrung"
    local loc       = v.location or ""
    local who       = v.holder or ""
    local isDropped = (v.isDropped == true)

    local carrierAlliance = (not isDropped) and (v.rowAlliance or 0) or 0
    local cc  = GetColorForAlliance(carrierAlliance)
    local hex = ToHex(cc.r, cc.g, cc.b)

    local label = "|c" .. hex .. rowName .. "|r"
    local hasPrefix = (rowName ~= "")
    if loc ~= "" then
        label = label .. " @ " .. loc
        hasPrefix = true
    end
    if who ~= "" then
        local bracket = "|c" .. hex .. "[" .. who .. "]|r"
        label = hasPrefix and (label .. " " .. bracket) or bracket
    end

    local now = GetGameTimeMilliseconds()
    return {
        isScrollCarrier  = true,
        isVolendrung     = true,
        isScrollDropped  = isDropped,
        id               = 0,
        name             = label,
        carrierTexture   = v.rowTexture or VOLENDRUNG_NEUTRAL_TEXTURE,
        carrierIconScale = VOLENDRUNG_CARRIER_ICON_SCALE,
        carrierTint      = (self.config.volendrungTintToHud == true),
        scrollAlliance   = v.rowAlliance or 0,
        owningAlliance   = v.rowAlliance or 0,
        isUnderAttack    = false,
        underAttackFor   = now - (v.spawnedAt or now),
        interestingSince = v.spawnedAt,
        siegeWeapons     = {},
    }
end

PvPUA.constants.textures.SCROLL_TALLY = {
    [ALLIANCE_ALDMERI_DOMINION]    = "/esoui/art/campaign/overview_scrollicon_aldmeri.dds",
    [ALLIANCE_EBONHEART_PACT]      = "/esoui/art/campaign/overview_scrollicon_ebonheart.dds",
    [ALLIANCE_DAGGERFALL_COVENANT] = "/esoui/art/campaign/overview_scrollicon_daggefall.dds",
}

PvPUA.scrollCounts = { [ALLIANCE_ALDMERI_DOMINION] = 0, [ALLIANCE_DAGGERFALL_COVENANT] = 0, [ALLIANCE_EBONHEART_PACT] = 0 }

function PvPUA:UpdateScrollCounts()
    local ok = pcall(function()
        local ad, dc, ep = 0, 0, 0
        if GetNumObjectives and GetKeepThatHasCapturedThisArtifactScrollObjective then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local holdingKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(keepId, objectiveId, ctxUse)
                    if holdingKeep and holdingKeep ~= 0 then
                        local state = GetObjectiveControlState and GetObjectiveControlState(keepId, objectiveId, ctxUse)
                        if state == nil
                        or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
                        or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                            local alliance = GetKeepAlliance(holdingKeep, ctxUse)
                            if alliance == ALLIANCE_ALDMERI_DOMINION then ad = ad + 1
                            elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then dc = dc + 1
                            elseif alliance == ALLIANCE_EBONHEART_PACT then ep = ep + 1 end
                        end
                    end
                end
            end
        end
        self.scrollCounts[ALLIANCE_ALDMERI_DOMINION]    = ad
        self.scrollCounts[ALLIANCE_DAGGERFALL_COVENANT] = dc
        self.scrollCounts[ALLIANCE_EBONHEART_PACT]      = ep
    end)
    if not ok then
        self.scrollCounts[ALLIANCE_ALDMERI_DOMINION]    = 0
        self.scrollCounts[ALLIANCE_DAGGERFALL_COVENANT] = 0
        self.scrollCounts[ALLIANCE_EBONHEART_PACT]      = 0
    end
end

function PvPUA:RefreshScrollTally()
    local map = {
        { icon = self.controls.scoreDCScroll, txt = self.controls.scoreDCScrollTxt, alliance = ALLIANCE_DAGGERFALL_COVENANT },
        { icon = self.controls.scoreADScroll, txt = self.controls.scoreADScrollTxt, alliance = ALLIANCE_ALDMERI_DOMINION },
        { icon = self.controls.scoreEPScroll, txt = self.controls.scoreEPScrollTxt, alliance = ALLIANCE_EBONHEART_PACT },
    }
    for i = 1, #map do
        local e = map[i]
        if e.icon and e.txt then
            local count = self.scrollCounts[e.alliance] or 0
            e.icon:SetHidden(false)
            e.txt:SetHidden(false)
            e.txt:SetText(tostring(count))
        end
    end
end

--------------------------------------------------
-- AddObjectives
--------------------------------------------------
function PvPUA:AddObjectives()
    local numObjectives = GetNumObjectives()
    for i = 1, numObjectives do
        local keepId, objectiveId, bgqueryType = GetObjectiveIdsForIndex(i)
        if bgqueryType == BGQUERY_ASSIGNED_AND_LOCAL or bgqueryType == BGQUERY_LOCAL then
            if self.state.keeps[keepId] ~= nil then
                self.state.keeps[keepId].objectives = self.state.keeps[keepId].objectives or {}
                if self.state.keeps[keepId].objectives[1] == nil then
                    self.state.keeps[keepId].objectives[1] = {}
                    self.state.keeps[keepId].objectives[1].id = objectiveId
                    self.state.keeps[keepId].objectives[1].state = 100
                    self.state.keeps[keepId].objectives[1].holdingAlliance = self.state.keeps[keepId].owningAlliance
                elseif self.state.keeps[keepId].objectives[2] == nil then
                    self.state.keeps[keepId].objectives[2] = {}
                    self.state.keeps[keepId].objectives[2].id = objectiveId
                    self.state.keeps[keepId].objectives[2].state = 100
                    self.state.keeps[keepId].objectives[2].holdingAlliance = self.state.keeps[keepId].owningAlliance
                end
            elseif self.state.resources[keepId] ~= nil then
                self.state.resources[keepId].objectives = self.state.resources[keepId].objectives or {}
                self.state.resources[keepId].objectives[1] = {}
                self.state.resources[keepId].objectives[1].id = objectiveId
                self.state.resources[keepId].objectives[1].state = 100
                self.state.resources[keepId].objectives[1].holdingAlliance = self.state.resources[keepId].owningAlliance
            elseif self.state.outposts[keepId] ~= nil then
                self.state.outposts[keepId].objectives = self.state.outposts[keepId].objectives or {}
                if self.state.outposts[keepId].objectives[1] == nil then
                    self.state.outposts[keepId].objectives[1] = {}
                    self.state.outposts[keepId].objectives[1].id = objectiveId
                    self.state.outposts[keepId].objectives[1].state = 100
                    self.state.outposts[keepId].objectives[1].holdingAlliance = self.state.outposts[keepId].owningAlliance
                else
                    self.state.outposts[keepId].objectives[2] = {}
                    self.state.outposts[keepId].objectives[2].id = objectiveId
                    self.state.outposts[keepId].objectives[2].state = 100
                    self.state.outposts[keepId].objectives[2].holdingAlliance = self.state.outposts[keepId].owningAlliance
                end
            elseif self.state.districts[keepId] ~= nil then
                self.state.districts[keepId].objectives = self.state.districts[keepId].objectives or {}
                self.state.districts[keepId].objectives[1] = {}
                self.state.districts[keepId].objectives[1].id = objectiveId
                self.state.districts[keepId].objectives[1].state = 100
                self.state.districts[keepId].objectives[1].holdingAlliance = self.state.districts[keepId].owningAlliance
            elseif self.state.villages[keepId] ~= nil then
                self.state.villages[keepId].objectives = self.state.villages[keepId].objectives or {}
                if self.state.villages[keepId].objectives[1] == nil then
                    self.state.villages[keepId].objectives[1] = {}
                    self.state.villages[keepId].objectives[1].id = objectiveId
                    self.state.villages[keepId].objectives[1].state = 100
                    self.state.villages[keepId].objectives[1].holdingAlliance = self.state.villages[keepId].owningAlliance
                elseif self.state.villages[keepId].objectives[2] == nil then
                    self.state.villages[keepId].objectives[2] = {}
                    self.state.villages[keepId].objectives[2].id = objectiveId
                    self.state.villages[keepId].objectives[2].state = 100
                    self.state.villages[keepId].objectives[2].holdingAlliance = self.state.villages[keepId].owningAlliance
                else
                    self.state.villages[keepId].objectives[3] = {}
                    self.state.villages[keepId].objectives[3].id = objectiveId
                    self.state.villages[keepId].objectives[3].state = 100
                    self.state.villages[keepId].objectives[3].holdingAlliance = self.state.villages[keepId].owningAlliance
                end
            end
        end
    end
end

--------------------------------------------------
-- ResetObjectives
--------------------------------------------------
function PvPUA:ResetObjective(keeps)
    for key, keep in pairs(keeps) do
        if keep.objectives ~= nil then
            for i = 1, #keep.objectives do
                keep.objectives[i].state = 100
                keep.objectives[i].holdingAlliance = keep.owningAlliance
            end
        end
    end
end

function PvPUA:ResetObjectives()
    self:ResetObjective(self.state.keeps)
    self:ResetObjective(self.state.outposts)
    self:ResetObjective(self.state.resources)
    self:ResetObjective(self.state.villages)
    self:ResetObjective(self.state.districts)
end

--------------------------------------------------
-- GetItemByKeepId
--------------------------------------------------
function PvPUA:GetItemByKeepId(keepId)
    if keepId ~= nil then
        if self.state.resources[keepId] ~= nil then return self.state.resources[keepId]
        elseif self.state.keeps[keepId] ~= nil then return self.state.keeps[keepId]
        elseif self.state.outposts[keepId] ~= nil then return self.state.outposts[keepId]
        elseif self.state.villages[keepId] ~= nil then return self.state.villages[keepId]
        elseif self.state.districts[keepId] ~= nil then return self.state.districts[keepId]
        end
    end
    return nil
end

--------------------------------------------------
-- Flag State / Flip Logic
--------------------------------------------------
local function GetFlagStatePercent(state, owningAlliance, holdingAlliance)
    local percent = 99
    if state == OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD then
        if holdingAlliance == owningAlliance then percent = 90 else percent = 51 end
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL then
        if holdingAlliance == 0 then percent = 0 else percent = 10 end
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_MAX_CONTROL then
        percent = 100
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD then
        if holdingAlliance == owningAlliance then percent = 40 else percent = 10 end
    end
    return percent
end

local function GetFlipConstant(keepType)
    if keepType == KEEPTYPE_KEEP then return PvPUA.constants.flipTimes.KEEP
    elseif keepType == KEEPTYPE_OUTPOST then return PvPUA.constants.flipTimes.OUTPOST
    elseif keepType == KEEPTYPE_RESOURCE then return PvPUA.constants.flipTimes.RESOURCE
    else return 0 end
end

local function FlagsAtFlipState(objectives, owningAlliance)
    local flips = false
    if objectives ~= nil then
        local flipedFlags = 0
        for i = 1, #objectives do
            if objectives[i].holdingAlliance ~= owningAlliance and objectives[i].state > 50 then
                flipedFlags = flipedFlags + 1
            else
                break
            end
        end
        if flipedFlags == #objectives then
            if #objectives == 1 then
                flips = true
            elseif #objectives == 2 and objectives[1].holdingAlliance == objectives[2].holdingAlliance then
                flips = true
            elseif #objectives == 3 and objectives[1].holdingAlliance == objectives[2].holdingAlliance and objectives[1].holdingAlliance == objectives[3].holdingAlliance then
                flips = true
            end
        end
    end
    return flips
end

local function AdjustKeepFlipping(keep)
    local flipTime = GetFlipConstant(keep.keepType)
    if flipTime > 0 then
        if FlagsAtFlipState(keep.objectives, keep.owningAlliance) == true then
            if keep.flipsAt == nil then
                keep.flipsAt = GetGameTimeMilliseconds() + flipTime
            end
        else
            keep.flipsAt = nil
        end
    end
end

--------------------------------------------------
-- UpdateItem
--------------------------------------------------
local notifCooldowns = {}

local function FireKeepUA(keepId, name, owningAlliance)
    if not PvPUA.savedVariables or not PvPUA.savedVariables.alertsEnabled then return end

    local now = GetGameTimeMilliseconds()
    if notifCooldowns[keepId] and now - notifCooldowns[keepId] < 30000 then return end
    notifCooldowns[keepId] = now

    local ac = GetColorForAlliance(owningAlliance)
    local nameHex = ToHex(ac.r, ac.g, ac.b)
    PvPUA:HKPush(keepId, string.format("|c%s%s|r |cFF8C00UA!|r", nameHex, name))
end

function PvPUA:UpdateItem(items, gameTime)
    local itemsOfInterest = {}
    for key, item in pairs(items) do
        local itemOfInterest = false
        local previousOwningAlliance = item.owningAlliance
        item.owningAlliance = GetKeepAlliance(key, BGQUERY_LOCAL)
        local previousAttackState = item.isUnderAttack
        item.isUnderAttack = GetKeepUnderAttack(key, BGQUERY_LOCAL)
        item.underAttackFor = 0

        if item.owningAlliance ~= previousOwningAlliance and self.state.destructibles[key] == nil then
            itemOfInterest = true
            if item.interestingSince == nil then item.interestingSince = gameTime end
            item.underAttackFor = gameTime - item.interestingSince
            if item.objectives ~= nil then
                for i = 1, #item.objectives do
                    item.objectives[i].state = 100
                    item.objectives[i].holdingAlliance = item.owningAlliance
                end
            end
            item.flipsAt = nil
        end
        if previousAttackState == false and item.isUnderAttack == true then
            if item.attackStatusLostAt ~= 0 and item.attackStatusLostAt + PvPUA.constants.siegeTimeout < gameTime then
                item.interestingSince = gameTime
            end
            local playerAlliance = GetUnitAlliance("player")
            if item.name ~= nil and self.state.keeps[key] ~= nil
               and PvPUA.homeKeepIds[key] == playerAlliance then
                FireKeepUA(key, item.name, item.owningAlliance)
            end
        elseif previousAttackState == true and item.isUnderAttack == false then
            item.attackStatusLostAt = gameTime
        end
        if item.isUnderAttack == true then
            itemOfInterest = true
            if item.interestingSince == nil then item.interestingSince = gameTime end
            item.underAttackFor = gameTime - item.interestingSince
        else
            if item.attackStatusLostAt ~= 0 and item.attackStatusLostAt + PvPUA.constants.siegeTimeout > gameTime then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
            end
        end
        if self.state.destructibles[key] == nil and item.siegeWeapons ~= nil then
            item.siegeWeapons.AD = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
            item.siegeWeapons.DC = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
            item.siegeWeapons.EP = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
            if item.siegeWeapons.AD > 0 or item.siegeWeapons.DC > 0 or item.siegeWeapons.EP > 0 then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
                item.lastSiegeWeaponSeen = gameTime
            elseif item.lastSiegeWeaponSeen ~= nil and item.lastSiegeWeaponSeen + PvPUA.constants.siegeTimeout > gameTime then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
            else
                item.lastSiegeWeaponSeen = nil
            end
        end
        if item.keepType == KEEPTYPE_BRIDGE or item.keepType == KEEPTYPE_MILEGATE then
            item.isPassable = IsKeepPassable(key, BGQUERY_LOCAL)
            item.directionalAccess = GetKeepDirectionalAccess(key, BGQUERY_LOCAL)
        end
        if itemOfInterest == true then
            local sv = PvPUA.savedVariables
            local hidden = false
            if sv then
                if item.keepType == KEEPTYPE_MILEGATE and sv.showMilegates == false then hidden = true
                elseif item.keepType == KEEPTYPE_BRIDGE and sv.showBridges == false then hidden = true
                elseif item.keepType == KEEPTYPE_TOWN and sv.showTowns == false then hidden = true
                elseif item.keepType == KEEPTYPE_RESOURCE and sv.showResources == false then hidden = true
                end
            end
            if hidden then
                item.interestingSince = nil
            else
                table.insert(itemsOfInterest, item)
            end
        else
            item.interestingSince = nil
        end
    end
    return itemsOfInterest
end

--------------------------------------------------
-- Sort
--------------------------------------------------
local function SortItemsOfInterest(itemA, itemB)
    if itemA == nil or itemB == nil then return true end
    if itemA.isScrollCarrier and not itemB.isScrollCarrier then return true end
    if itemB.isScrollCarrier and not itemA.isScrollCarrier then return false end
    if itemA.isScrollCarrier and itemB.isScrollCarrier then
        if itemA.isVolendrung and not itemB.isVolendrung then return true end
        if itemB.isVolendrung and not itemA.isVolendrung then return false end
        return (itemA.interestingSince or 0) < (itemB.interestingSince or 0)
    end
    local playerAlliance = GetUnitAlliance("player")
    local aFriendly = GetKeepAlliance(itemA.id, BGQUERY_LOCAL) == playerAlliance
    local bFriendly = GetKeepAlliance(itemB.id, BGQUERY_LOCAL) == playerAlliance
    if aFriendly and not bFriendly then return true end
    if not aFriendly and bFriendly then return false end
    if not aFriendly and not bFriendly then
        local aSiege = itemA.siegeWeapons and (
            (playerAlliance == ALLIANCE_ALDMERI_DOMINION    and (itemA.siegeWeapons.AD or 0) > 0) or
            (playerAlliance == ALLIANCE_DAGGERFALL_COVENANT and (itemA.siegeWeapons.DC or 0) > 0) or
            (playerAlliance == ALLIANCE_EBONHEART_PACT      and (itemA.siegeWeapons.EP or 0) > 0)
        )
        local bSiege = itemB.siegeWeapons and (
            (playerAlliance == ALLIANCE_ALDMERI_DOMINION    and (itemB.siegeWeapons.AD or 0) > 0) or
            (playerAlliance == ALLIANCE_DAGGERFALL_COVENANT and (itemB.siegeWeapons.DC or 0) > 0) or
            (playerAlliance == ALLIANCE_EBONHEART_PACT      and (itemB.siegeWeapons.EP or 0) > 0)
        )
        if aSiege and not bSiege then return true end
        if not aSiege and bSiege then return false end
    end
    if itemA.interestingSince == nil or itemB.interestingSince == nil then return true end
    return itemA.interestingSince < itemB.interestingSince
end

--------------------------------------------------
-- Texture Helper
--------------------------------------------------
local function GetTextureAndOffsetForItem(keepType, rType, isPassable)
    if keepType == KEEPTYPE_KEEP then
        return PvPUA.constants.textures.KEEP, 3
    elseif keepType == KEEPTYPE_OUTPOST then
        return PvPUA.constants.textures.OUTPOST, 3
    elseif keepType == KEEPTYPE_RESOURCE then
        if rType == PvPUA.constants.resourceType.FARM then return PvPUA.constants.textures.RESOURCE_FARM, -1
        elseif rType == PvPUA.constants.resourceType.MINE then return PvPUA.constants.textures.RESOURCE_MINE, -1
        elseif rType == PvPUA.constants.resourceType.LUMBER then return PvPUA.constants.textures.RESOURCE_LUMBER, -1
        end
    elseif keepType == KEEPTYPE_TOWN then
        return PvPUA.constants.textures.VILLAGE, 2
    elseif keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
        return PvPUA.constants.textures.DISTRICT, 2
    elseif keepType == KEEPTYPE_BRIDGE then
        if isPassable == true then return PvPUA.constants.textures.BRIDGE_PASSABLE, -2
        else return PvPUA.constants.textures.BRIDGE_NOT_PASSABLE, -2 end
    elseif keepType == KEEPTYPE_MILEGATE then
        if isPassable == true then return PvPUA.constants.textures.MILEGATE_PASSABLE, -2
        else return PvPUA.constants.textures.MILEGATE_NOT_PASSABLE, -2 end
    end
    return "", 0
end

--------------------------------------------------
-- Format Time
--------------------------------------------------
local function FormatUnderAttackTime(underAttackFor)
    if underAttackFor ~= nil or underAttackFor == 0 then
        local minutes = string.format("%d", underAttackFor / 60)
        local seconds = underAttackFor - minutes * 60
        if seconds > 0 and seconds < 10 then
            return string.format("%d:0%d", minutes, seconds)
        elseif seconds == 0 then
            return string.format("%d:00", minutes)
        else
            return string.format("%d:%d", minutes, seconds)
        end
    else
        return ""
    end
end

local function SetSiegeWeapons(control, weapons)
    if weapons ~= nil and weapons > 0 then
        control:SetText(weapons)
    else
        control:SetText("")
    end
end

--------------------------------------------------
-- Create Progress Bar
--------------------------------------------------
local function CreateProgressBar(parent)
    local control = wm:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.flagHeight)
    control:SetHidden(true)

    control.backdrop = wm:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    control.backdrop:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.flagHeight)
    control.backdrop:SetEdgeColor(0, 0, 0, 1)
    control.backdrop:SetCenterColor(PvPUA.config.flagBackdropColor.r, PvPUA.config.flagBackdropColor.g, PvPUA.config.flagBackdropColor.b, 1)

    control.progress = wm:CreateControl(nil, control, CT_STATUSBAR)
    control.progress:SetAnchor(TOPLEFT, control, TOPLEFT, 1, 1)
    control.progress:SetDimensions(PvPUA.config.flagWidth - 2, PvPUA.config.flagHeight - 2)
    control.progress:SetMinMax(0, 100)
    control.progress:SetValue(0)
    return control
end

--------------------------------------------------
-- Create Entry Control
--------------------------------------------------
local function CreateEntryControl(parent)
    local controlFont = PvPUA:GetFont()

    local control = wm:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(PvPUA.config.width, PvPUA.config.entryHeight)
    control:SetHidden(true)

    control.backdrop = wm:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    control.backdrop:SetDimensions(PvPUA.config.width, PvPUA.config.entryHeight)
    control.backdrop:SetDrawLayer(0)

    control.uaOutline = wm:CreateControl(nil, control, CT_TEXTURE)
    control.uaOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -5 - 2, -5 - 2)
    control.uaOutline:SetDimensions(PvPUA.config.imageWidth + 10 + 4, PvPUA.config.entryHeight + 10 + 4)
    control.uaOutline:SetTexture("/esoui/art/mappins/ava_attackburst_64.dds")
    control.uaOutline:SetColor(0, 0, 0, 1)
    control.uaOutline:SetHidden(true)
    control.uaOutline:SetDrawLayer(0)

    control.uaImage = wm:CreateControl(nil, control, CT_TEXTURE)
    control.uaImage:SetAnchor(TOPLEFT, control, TOPLEFT, -5, -5)
    control.uaImage:SetDimensions(PvPUA.config.imageWidth + 10, PvPUA.config.entryHeight + 10)
    control.uaImage:SetTexture("/esoui/art/mappins/ava_attackburst_64.dds")
    control.uaImage:SetHidden(true)
    control.uaImage:SetDrawLayer(1)

    control.imageOutline = wm:CreateControl(nil, control, CT_TEXTURE)
    control.imageOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -2 - 2, -2 - 2)
    control.imageOutline:SetDimensions(PvPUA.config.imageWidth + 4 + 4, PvPUA.config.entryHeight + 4 + 4)
    control.imageOutline:SetColor(0, 0, 0, 1)
    control.imageOutline:SetDrawLayer(1)
    control.imageOutline:SetHidden(not PvPUA.config.iconOutline)

    control.image = wm:CreateControl(nil, control, CT_TEXTURE)
    control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -2, -2)
    control.image:SetDimensions(PvPUA.config.imageWidth + 4, PvPUA.config.entryHeight + 4)
    control.image:SetDrawLayer(2)

    control.scrollImage = wm:CreateControl(nil, control, CT_TEXTURE)
    control.scrollImage:SetDrawLayer(3)
    control.scrollImage:SetHidden(true)

    control.name = wm:CreateControl(nil, control, CT_LABEL)
    control.name:SetAnchor(TOPLEFT, control, TOPLEFT, PvPUA.config.imageWidth + 4, 0)
    control.name:SetDimensions(PvPUA.config.nameWidth, PvPUA.config.entryHeight)
    control.name:SetFont(controlFont)
    control.name:SetWrapMode(ELLIPSIS)
    control.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    control.progress = wm:CreateControl(nil, control, CT_CONTROL)
    control.progress:SetAnchor(TOPLEFT, control, TOPLEFT, PvPUA.config.imageWidth + 4 + PvPUA.config.nameWidth, 0)
    control.progress:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.entryHeight)
    control.progress.bar1 = CreateProgressBar(control.progress)
    control.progress.bar2 = CreateProgressBar(control.progress)
    control.progress.bar3 = CreateProgressBar(control.progress)

    local siegeOffset = PvPUA.config.imageWidth + 4 + PvPUA.config.nameWidth + PvPUA.config.flagWidth
    control.dcSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.dcSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset, 0)
    control.dcSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.dcSiege:SetFont(controlFont)
    control.dcSiege:SetWrapMode(ELLIPSIS)
    control.dcSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.dcSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.adSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.adSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth, 0)
    control.adSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.adSiege:SetFont(controlFont)
    control.adSiege:SetWrapMode(ELLIPSIS)
    control.adSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.adSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.epSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.epSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth * 2, 0)
    control.epSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.epSiege:SetFont(controlFont)
    control.epSiege:SetWrapMode(ELLIPSIS)
    control.epSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.epSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.flipStatus = wm:CreateControl(nil, control, CT_LABEL)
    control.flipStatus:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth * 3 + 10, 0)
    control.flipStatus:SetDimensions(PvPUA.config.flagFlipWidth, PvPUA.config.entryHeight)
    control.flipStatus:SetFont(controlFont)
    control.flipStatus:SetWrapMode(ELLIPSIS)
    control.flipStatus:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.flipStatus:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    control.underAttackFor = wm:CreateControl(nil, control, CT_LABEL)
    control.underAttackFor:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    control.underAttackFor:SetDimensions(PvPUA.config.underAttackForWidth, PvPUA.config.entryHeight)
    control.underAttackFor:SetFont(controlFont)
    control.underAttackFor:SetWrapMode(ELLIPSIS)
    control.underAttackFor:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.underAttackFor:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    return control
end

function PvPUA:ApplyPosition()
    self.controls.TLW:ClearAnchors()
    self.controls.TLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        self.savedVariables.posX or PvPUA.defaults.posX,
        self.savedVariables.posY or PvPUA.defaults.posY)
end

function PvPUA:ApplyScale()
    if not self.controls.TLW then return end
    local scale = self.savedVariables and self.savedVariables.uiScale or 1.0
    self.controls.TLW:SetScale(scale)
end

--------------------------------------------------
-- Apply Size
--------------------------------------------------
function PvPUA:ApplyListSize()
    self.config.entryHeight         = 34
    self.config.nameWidth           = 180
    self.config.width               = 510
    self.config.siegeWidth          = 38
    self.config.underAttackForWidth = 65
    self.config.flagFlipWidth       = 60
    self:InvalidateFontCache()
end

--------------------------------------------------
-- Create UI
--------------------------------------------------
function PvPUA:CreateUI()
    self.controls.TLW = wm:CreateTopLevelWindow("PvPUA_TLW")
    self.controls.TLW:SetClampedToScreen(self.config.isClampedToScreen)
    self.controls.TLW:SetDimensions(self.config.width, self.config.height + self.config.entryHeight * 2 + 20)
    self.controls.TLW:SetDrawLayer(DL_BACKGROUND)
    self.controls.TLW:SetDrawTier(DT_LOW)
    self.controls.TLW:SetHidden(true)

    self:ApplyPosition()
    self:ApplyScale()

    self.controls.TLW.rootControl = wm:CreateControl(nil, self.controls.TLW, CT_CONTROL)
    local rootControl = self.controls.TLW.rootControl
    rootControl:SetDimensions(self.config.width, self.config.height)
    rootControl:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20 + self.config.entryHeight * 2)

    self.state.visibleControls = {}
    for i = 1, 15 do
        local entry = CreateEntryControl(rootControl)
        entry:SetAnchor(TOPLEFT, rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
        entry:SetHidden(true)
        table.insert(self.state.visibleControls, entry)
    end
    zo_callLater(function()
        for i = 16, 30 do
            local entry = CreateEntryControl(rootControl)
            entry:SetAnchor(TOPLEFT, rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
            entry:SetHidden(true)
            table.insert(self.state.visibleControls, entry)
        end
    end, 100)

    self.controls.creditLabel = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.creditLabel:SetFont("EsoUI/Common/Fonts/univers67.otf|15|outline")
    self.controls.creditLabel:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 0)
    self.controls.creditLabel:SetDimensions(self.config.width, 20)
    self.controls.creditLabel.baseY = 0
    self.controls.creditLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.creditLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.creditLabel:SetText(CREDIT_STATES[0])
    self.controls.creditLabel:SetDrawLayer(2)
    self.controls.creditLabel:SetHidden(true)

    self.controls.infoBg = wm:CreateControl(nil, self.controls.TLW, CT_BACKDROP)
    self.controls.infoBg:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20)
    self.controls.infoBg:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.infoBg.baseX, self.controls.infoBg.baseY = 0, 20
    self.controls.infoBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaOdd)
    self.controls.infoBg:SetEdgeColor(0, 0, 0, 0)
    self.controls.infoBg:SetDrawLayer(0)
    self.controls.infoBg:SetHidden(true)

    local infoH      = self.config.entryHeight
    local rankBase   = math.max(28, infoH - 2)
    local rankIconSz = math.floor(rankBase * self.config.iconScale.rank)
    local barPad     = 4
    local kbStart    = self.config.width - 130
    local gapEnd     = kbStart - barPad
    local rankX      = 0
    local barLeft    = rankX + rankBase + barPad
    local barW       = gapEnd - barLeft

    local barFontPx = self.config.barFontSize
    if not barFontPx or barFontPx <= 0 then
        barFontPx = math.max(10, math.floor(self.config.barHeight))
    end
    local barLabelFont = "EsoUI/Common/Fonts/FTN57.otf|" .. barFontPx .. "|outline"
    local barNudge = self.config.barTextNudge or 0

    local killFont = "EsoUI/Common/Fonts/FTN57.otf|" .. (self.config.kdFontSize or 20) .. "|outline"


    local rankGrow = math.floor((rankIconSz - rankBase) / 2)
    self.controls.infoRankIcon = wm:CreateControl(nil, self.controls.TLW, CT_TEXTURE)
    self.controls.infoRankIcon:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT,
        rankX - rankGrow,
        20 + math.floor((infoH - rankBase) / 2) - rankGrow)
    self.controls.infoRankIcon.baseX = rankX - rankGrow
    self.controls.infoRankIcon.baseY = 20 + math.floor((infoH - rankBase) / 2) - rankGrow
    self.controls.infoRankIcon:SetDimensions(rankIconSz, rankIconSz)
    self.controls.infoRankIcon:SetDrawLayer(2)
    self.controls.infoRankIcon:SetHidden(true)

    local barH = self.config.barHeight
    self.controls.infoBarBg = wm:CreateControl(nil, self.controls.TLW, CT_BACKDROP)
    self.controls.infoBarBg:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, barLeft, 20 + math.floor((infoH - barH) / 2))
    self.controls.infoBarBg:SetDimensions(barW, barH)
    self.controls.infoBarBg.baseX = barLeft
    self.controls.infoBarBg.baseY = 20 + math.floor((infoH - barH) / 2)
    self.controls.infoBarBg:SetCenterColor(0.1, 0.1, 0.1, 0.9)
    self.controls.infoBarBg:SetEdgeColor(0, 0, 0, 1)
    self.controls.infoBarBg:SetDrawLayer(1)
    self.controls.infoBarBg:SetHidden(true)

    self.controls.infoBar = wm:CreateControl(nil, self.controls.TLW, CT_STATUSBAR)
    self.controls.infoBar:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, barLeft + 1, 20 + math.floor((infoH - barH) / 2) + 1)
    self.controls.infoBar:SetDimensions(barW - 2, barH - 2)
    self.controls.infoBar.baseX = barLeft + 1
    self.controls.infoBar.baseY = 20 + math.floor((infoH - barH) / 2) + 1
    self.controls.infoBar:SetMinMax(0, 100)
    self.controls.infoBar:SetValue(0)
    self.controls.infoBar:SetDrawLayer(2)
    self.controls.infoBar:SetHidden(true)

    self.controls.infoRankNum = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoRankNum:SetFont(barLabelFont)
    self.controls.infoRankNum:SetAnchor(LEFT, self.controls.infoBarBg, LEFT, 3, barNudge)
    self.controls.infoRankNum:SetDimensions(math.floor(barW / 2), barH + 6)
    self.controls.infoRankNum:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoRankNum:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.infoRankNum:SetColor(1, 1, 1, 1)
    self.controls.infoRankNum:SetDrawLayer(3)
    self.controls.infoRankNum:SetHidden(true)

    self.controls.infoAPText = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoAPText:SetFont(barLabelFont)
    self.controls.infoAPText:SetAnchor(RIGHT, self.controls.infoBarBg, RIGHT, -3, barNudge)
    self.controls.infoAPText:SetDimensions(barW - 3, barH + 6)
    self.controls.infoAPText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoAPText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.infoAPText:SetColor(1, 1, 1, 1)
    self.controls.infoAPText:SetDrawLayer(3)
    self.controls.infoAPText:SetHidden(true)

    self.controls.infoKD = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoKD:SetFont(killFont)
    self.controls.infoKD:SetAnchor(TOPRIGHT, self.controls.TLW, TOPRIGHT,
        -(self.config.kdRightPad or 0), 20 + (self.config.kdTextNudge or 0))
    self.controls.infoKD.baseX = -(self.config.kdRightPad or 0)
    self.controls.infoKD.baseY = 20 + (self.config.kdTextNudge or 0)
    self.controls.infoKD:SetDimensions(220, infoH)
    self.controls.infoKD:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoKD:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.infoKD:SetDrawLayer(2)
    self.controls.infoKD:SetHidden(true)

    local scoreFont = "EsoUI/Common/Fonts/FTN57.otf|20|outline"
    self.controls.scoreRow = wm:CreateControl(nil, self.controls.TLW, CT_CONTROL)
    self.controls.scoreRow:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.scoreRow:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20 + self.config.entryHeight)
    self.controls.scoreRow:SetHidden(true)

    self.controls.scoreRowBg = wm:CreateControl(nil, self.controls.scoreRow, CT_BACKDROP)
    self.controls.scoreRowBg:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, 0, 0)
    self.controls.scoreRowBg:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.scoreRowBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaEven)
    self.controls.scoreRowBg:SetEdgeColor(0, 0, 0, 0)
    self.controls.scoreRowBg:SetDrawLayer(0)

    local iBase = math.max(16, self.config.entryHeight - 4)
    local iSize = math.floor(iBase * self.config.iconScale.allianceScore)
    local iGrow = math.floor((iSize - iBase) / 2)
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)

    local empBaseW = PvPUA.config.imageWidth + 4
    local empBaseH = self.config.entryHeight + 4
    local empW     = math.floor(empBaseW * self.config.iconScale.emperor)
    local empH     = math.floor(empBaseH * self.config.iconScale.emperor)
    self.controls.infoEmpIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.infoEmpIcon:SetTexture("esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds")
    self.controls.infoEmpIcon:SetDimensions(empW, empH)
    self.controls.infoEmpIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT,
        -2 - math.floor((empW - empBaseW) / 2),
        -2 - math.floor((empH - empBaseH) / 2))
    self.controls.infoEmpIcon:SetColor(0.35, 0.35, 0.35, 1)
    self.controls.infoEmpIcon:SetDrawLayer(1)
    self.controls.infoEmpIcon:SetHidden(true)

    self.controls.empSlices = {}
    local sliceW = empW / 2
    local empBands = { { 0, 0.4082 }, { 0.4082, 0.5918 }, { 0.5918, 1 } }
    for slot = 1, #PvPUA.constants.emperorKeeps do
        local def = PvPUA.constants.emperorKeeps[slot]
        local band = empBands[def.row + 1]
        local slice = wm:CreateControl(nil, self.controls.infoEmpIcon, CT_TEXTURE)
        slice:SetTexture("esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds")
        slice:SetDimensions(sliceW, empH * (band[2] - band[1]))
        slice:SetAnchor(TOPLEFT, self.controls.infoEmpIcon, TOPLEFT,
            def.col * sliceW, empH * band[1])
        slice:SetTextureCoords(def.col * 0.5, def.col * 0.5 + 0.5,
            band[1], band[2])
        slice:SetColor(0.35, 0.35, 0.35, 1)
        slice:SetDrawLayer(2)
        self.controls.empSlices[slot] = slice
    end

    local volW = PvPUA.config.imageWidth + 4 + 8
    local timerW = self.config.underAttackForWidth
    local remaining = self.config.width - volW - timerW - 4
    local groupW = math.floor(remaining / 3)
    local ptsW = groupW - iBase
    local col1 = volW
    local col2 = col1 + groupW
    local col3 = col1 + groupW * 2

    self.controls.scoreDCIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreDCIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_daggerfall.dds")
    self.controls.scoreDCIcon:SetDimensions(iSize, iSize)
    self.controls.scoreDCIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col1 - iGrow, -iGrow)
    self.controls.scoreDCIcon:SetDrawLayer(1)

    self.controls.scoreDCScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreDCScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_DAGGERFALL_COVENANT])
    self.controls.scoreDCScroll:SetDimensions(iBase, iBase)
    self.controls.scoreDCScroll:SetAnchor(CENTER, self.controls.scoreDCIcon, CENTER, 0, 0)
    self.controls.scoreDCScroll:SetDrawLayer(3)
    self.controls.scoreDCScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreDCScroll:SetHidden(false)

    self.controls.scoreDCScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreDCScrollTxt:SetFont(scoreFont)
    self.controls.scoreDCScrollTxt:SetAnchor(CENTER, self.controls.scoreDCIcon, CENTER, 0, 0)
    self.controls.scoreDCScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreDCScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreDCScrollTxt:SetDrawLayer(4)
    self.controls.scoreDCScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreDCScrollTxt:SetHidden(false)

    self.controls.scoreDCPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreDCPts:SetFont(scoreFont)
    self.controls.scoreDCPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col1 + iBase + 4, 0)
    self.controls.scoreDCPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreDCPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreDCPts:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)

    self.controls.scoreADIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreADIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_aldmeri.dds")
    self.controls.scoreADIcon:SetDimensions(iSize, iSize)
    self.controls.scoreADIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col2 - iGrow, -iGrow)
    self.controls.scoreADIcon:SetDrawLayer(1)

    self.controls.scoreADScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreADScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_ALDMERI_DOMINION])
    self.controls.scoreADScroll:SetDimensions(iBase, iBase)
    self.controls.scoreADScroll:SetAnchor(CENTER, self.controls.scoreADIcon, CENTER, 0, 0)
    self.controls.scoreADScroll:SetDrawLayer(3)
    self.controls.scoreADScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreADScroll:SetHidden(false)

    self.controls.scoreADScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreADScrollTxt:SetFont(scoreFont)
    self.controls.scoreADScrollTxt:SetAnchor(CENTER, self.controls.scoreADIcon, CENTER, 0, 0)
    self.controls.scoreADScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreADScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreADScrollTxt:SetDrawLayer(4)
    self.controls.scoreADScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreADScrollTxt:SetHidden(false)

    self.controls.scoreADPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreADPts:SetFont(scoreFont)
    self.controls.scoreADPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col2 + iBase + 4, 0)
    self.controls.scoreADPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreADPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreADPts:SetColor(adColor.r, adColor.g, adColor.b, 1)

    self.controls.scoreEPIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreEPIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_ebonheart.dds")
    self.controls.scoreEPIcon:SetDimensions(iSize, iSize)
    self.controls.scoreEPIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col3 - iGrow, -iGrow)
    self.controls.scoreEPIcon:SetDrawLayer(1)

    self.controls.scoreEPScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreEPScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_EBONHEART_PACT])
    self.controls.scoreEPScroll:SetDimensions(iBase, iBase)
    self.controls.scoreEPScroll:SetAnchor(CENTER, self.controls.scoreEPIcon, CENTER, 0, 0)
    self.controls.scoreEPScroll:SetDrawLayer(3)
    self.controls.scoreEPScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreEPScroll:SetHidden(false)

    self.controls.scoreEPScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreEPScrollTxt:SetFont(scoreFont)
    self.controls.scoreEPScrollTxt:SetAnchor(CENTER, self.controls.scoreEPIcon, CENTER, 0, 0)
    self.controls.scoreEPScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreEPScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreEPScrollTxt:SetDrawLayer(4)
    self.controls.scoreEPScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreEPScrollTxt:SetHidden(false)

    self.controls.scoreEPPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreEPPts:SetFont(scoreFont)
    self.controls.scoreEPPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col3 + iBase + 4, 0)
    self.controls.scoreEPPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreEPPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreEPPts:SetColor(epColor.r, epColor.g, epColor.b, 1)

    self.controls.scoreTimer = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreTimer:SetFont(scoreFont)
    self.controls.scoreTimer:SetAnchor(TOPRIGHT, self.controls.scoreRow, TOPRIGHT, -2, 0)
    self.controls.scoreTimer:SetDimensions(timerW, self.config.entryHeight)
    self.controls.scoreTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreTimer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.scoreTimer:SetColor(1, 1, 1, 1)

    self.controls.hudFragment = ZO_HUDFadeSceneFragment:New(self.controls.TLW)

    if SCENE_MANAGER and not self.listSceneHooked then
        self.listSceneHooked = true
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, _, newState)
            if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
                PvPUA:ApplyListVisibility()
            end
        end)
    end
end

--------------------------------------------------
-- Campaign Queue
--------------------------------------------------
PvPUA.queue = { active = false }

local QUEUE_SIDE_PAD   = 10
local QUEUE_EDGE_PAD   = 6
local QUEUE_MAX_ROWS   = 3
local QUEUE_FONT       = "ZoFontGamepad27"
local QUEUE_HEADER_H   = 33
local QUEUE_ROW_H      = 35
local QUEUE_SAFETY_TICK = 5000
local QUEUE_RETRY_MS   = 3000

function PvPUA:AnchorQueueWindow(height)
    local tlw = self.controls.queueTLW
    if not tlw then return end
    local baseHeight = QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H
    local grow = (height or baseHeight) - baseHeight
    tlw:ClearAnchors()
    if ZO_CompassFrame then
        tlw:SetAnchor(LEFT, ZO_CompassFrame, RIGHT, 40, grow / 2)
    else
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 100)
    end
end

function PvPUA:CreateQueueUI()
    if self.controls.queueTLW then return end

    local tlw = wm:CreateTopLevelWindow("PvPUA_QueueTLW")
    tlw:SetClampedToScreen(true)
    tlw:SetDimensions(160, QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawLevel(9000)
    tlw:SetHidden(true)
    self.controls.queueTLW = tlw

    self:AnchorQueueWindow(QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H)

    local bg = wm:CreateControl(nil, tlw, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, tlw, TOPLEFT, 0, 0)
    bg:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, 0, 0)
    bg:SetCenterColor(0, 0, 0, 0.6)
    bg:SetEdgeColor(0.6, 0.6, 0.6, 0.8)
    bg:SetEdgeTexture(nil, 1, 1, 1, 0)
    self.controls.queueBg = bg

    local header = wm:CreateControl(nil, tlw, CT_LABEL)
    header:SetFont(QUEUE_FONT)
    header:SetAnchor(TOP, tlw, TOP, 0, QUEUE_EDGE_PAD)
    header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    header:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    header:SetColor(0, 1, 0, 1)
    self.controls.queueHeader = header

    self.controls.queueRows = {}
    for i = 1, QUEUE_MAX_ROWS do
        local row = wm:CreateControl(nil, tlw, CT_LABEL)
        row:SetFont(QUEUE_FONT)
        row:SetAnchor(TOP, tlw, TOP, 0,
            QUEUE_EDGE_PAD + QUEUE_HEADER_H + QUEUE_ROW_H * (i - 1))
        row:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        row:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row:SetColor(1, 1, 1, 1)
        row:SetHidden(true)
        self.controls.queueRows[i] = row
    end
end

local function QueueCampaignName(campaignId)
    local name = ""
    if GetCampaignName then
        local ok, value = pcall(GetCampaignName, campaignId)
        if ok and value then name = zo_strformat("<<1>>", value) end
    end
    if name == "" then name = "Campaign " .. tostring(campaignId) end
    if #name > 14 then name = name:sub(1, 13) .. "." end
    return name
end

local function QueueEntryIsDisplayable(entry)
    if type(entry.position) ~= "number" or entry.position <= 0 then return false end
    if entry.state ~= nil and CAMPAIGN_QUEUE_REQUEST_STATE_WAITING ~= nil then
        if entry.state ~= CAMPAIGN_QUEUE_REQUEST_STATE_WAITING then return false end
    end
    return true
end

function PvPUA:GetQueueEntries()
    local out = {}
    if not (GetNumCampaignQueueEntries and GetCampaignQueueEntry) then return out end
    local ok = pcall(function()
        local n = GetNumCampaignQueueEntries() or 0
        for i = 1, n do
            local campaignId, queueAsGroup = GetCampaignQueueEntry(i)
            if campaignId and campaignId ~= 0 then
                local entry = { campaignId = campaignId, asGroup = queueAsGroup == true }
                if GetCampaignQueuePosition then
                    entry.position = GetCampaignQueuePosition(campaignId, entry.asGroup)
                end
                if GetCampaignQueueState then
                    entry.state = GetCampaignQueueState(campaignId, entry.asGroup)
                end
                if QueueEntryIsDisplayable(entry) then
                    out[#out + 1] = entry
                end
            end
        end
    end)
    if not ok then return {} end
    return out
end

function PvPUA:RefreshQueueWindow()
    if not self.controls.queueTLW then return end

    local entries = self:GetQueueEntries()
    if #entries == 0 then
        self.controls.queueTLW:SetHidden(true)
        self.queue.active = false
        return
    end

    local shown = #entries
    if shown > QUEUE_MAX_ROWS then shown = QUEUE_MAX_ROWS end

    self.controls.queueHeader:SetText(shown > 1 and "Queues" or "Queue")

    local ac = GetColorForAlliance(GetUnitAlliance("player"))

    for i = 1, QUEUE_MAX_ROWS do
        local row = self.controls.queueRows[i]
        local entry = entries[i]
        if entry and i <= shown then
            local positionText = "--"
            if type(entry.position) == "number" and entry.position > 0 then
                positionText = tostring(entry.position)
            end
            local groupTag = entry.asGroup and " |c9090A0(G)|r" or ""
            row:SetText(ColorText(QueueCampaignName(entry.campaignId), ac.r, ac.g, ac.b) ..
                " |c00FF00#|r" ..
                ColorText(positionText, ac.r, ac.g, ac.b) .. groupTag)
            row:SetHidden(false)
        else
            row:SetText("")
            row:SetHidden(true)
        end
    end

    local widest = self.controls.queueHeader:GetTextWidth() or 0
    for i = 1, shown do
        local w = self.controls.queueRows[i]:GetTextWidth() or 0
        if w > widest then widest = w end
    end

    local width = math.ceil(widest) + QUEUE_SIDE_PAD * 2
    local height = QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H * shown

    self.controls.queueTLW:SetDimensions(width, height)
    self:AnchorQueueWindow(height)

    self.controls.queueTLW:SetHidden(false)
    self.queue.active = true
end

function PvPUA:RefreshQueueSoon()
    self:RefreshQueueWindow()
    zo_callLater(function() PvPUA:RefreshQueueWindow() end, QUEUE_RETRY_MS)
end

function PvPUA:StartQueueSafetyPoll()
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_QueueSafety")
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_QueueSafety", QUEUE_SAFETY_TICK,
        function() PvPUA:RefreshQueueWindow() end)
end

function PvPUA:RegisterQueueEvents()
    local pairsToBind = {
        { EVENT_CAMPAIGN_QUEUE_JOINED,           "_QueueJoined" },
        { EVENT_CAMPAIGN_QUEUE_LEFT,             "_QueueLeft" },
        { EVENT_CAMPAIGN_QUEUE_POSITION_CHANGED, "_QueuePosition" },
        { EVENT_CAMPAIGN_QUEUE_STATE_CHANGED,    "_QueueState" },
    }
    for i = 1, #pairsToBind do
        local eventId, suffix = pairsToBind[i][1], pairsToBind[i][2]
        if eventId ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. suffix, eventId,
                function() PvPUA:RefreshQueueWindow() end)
        end
    end
end

--------------------------------------------------
-- UpdateHUDScenes
--------------------------------------------------
function PvPUA:ApplyHeaderLayout()
    local c = self.controls
    if not (c.TLW and c.creditLabel and c.infoBg) then return end

    local shift = (self.initializedZone == "IC") and self.config.entryHeight or 0
    if self.headerShift == shift then return end
    self.headerShift = shift

    local function place(control, point, relPoint)
        if not control or control.baseY == nil then return end
        control:ClearAnchors()
        control:SetAnchor(point, c.TLW, relPoint, control.baseX or 0, control.baseY + shift)
    end

    place(c.creditLabel, TOPLEFT, TOPLEFT)
    place(c.infoBg, TOPLEFT, TOPLEFT)
    place(c.infoRankIcon, TOPLEFT, TOPLEFT)
    place(c.infoBarBg, TOPLEFT, TOPLEFT)
    place(c.infoBar, TOPLEFT, TOPLEFT)
    place(c.infoKD, TOPRIGHT, TOPRIGHT)
end

function PvPUA:ShowListInMenus()
    return self.savedVariables ~= nil and self.savedVariables.showListInMenus == true
end

function PvPUA:ShowListWhileDead()
    return self.savedVariables ~= nil and self.savedVariables.showListWhileDead == true
end

function PvPUA:ShowListWhileSieging()
    return self.savedVariables ~= nil and self.savedVariables.showListWhileSieging == true
end

--------------------------------------------------
-- Scenes
--------------------------------------------------
local LIST_HUD_SCENES   = { "hud", "hudui" }
local LIST_SIEGE_SCENES = { "siegeBar", "siegeBarUI" }

local function IsSceneNamed(names, sceneName)
    for i = 1, #names do
        if names[i] == sceneName then return true end
    end
    return false
end

function PvPUA:CurrentSceneName()
    return (SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()) or ""
end

function PvPUA:IsHudScene()
    return IsSceneNamed(LIST_HUD_SCENES, self:CurrentSceneName())
end

function PvPUA:IsSiegeScene()
    return IsSceneNamed(LIST_SIEGE_SCENES, self:CurrentSceneName())
end

--------------------------------------------------
-- While Dead
--------------------------------------------------
function PvPUA:RefreshDeadHiddenReason()
    local fragment = self.controls.hudFragment
    if not (fragment and fragment.SetHiddenForReason) then return end
    local hide = self:EAIsPlayerDead() and not self:ShowListWhileDead()
    fragment:SetHiddenForReason("PvPUADead", hide)
end

function PvPUA:ApplyListVisibility()
    local tlw = self.controls.TLW
    if not tlw then return end

    self:RefreshDeadHiddenReason()

    if self:IsHudScene() or self:IsSiegeScene() then return end

    if IsInCyrodiilOrIC() and self:ShowListInMenus() then
        tlw:SetAlpha(1)
        tlw:SetHidden(false)
    else
        tlw:SetHidden(true)
    end
end

function PvPUA:ApplyFragmentToScenes(names, wanted)
    local fragment = self.controls.hudFragment
    for i = 1, #names do
        local scene = SCENE_MANAGER:GetScene(names[i])
        if scene then
            local has = scene:HasFragment(fragment)
            if wanted and not has then
                scene:AddFragment(fragment)
            elseif not wanted and has then
                scene:RemoveFragment(fragment)
            end
        end
    end
end

function PvPUA:UpdateHUDScenes()
    if not self.controls.hudFragment then return end
    local inPvP = IsInCyrodiilOrIC()
    self:ApplyFragmentToScenes(LIST_HUD_SCENES, inPvP)
    self:ApplyFragmentToScenes(LIST_SIEGE_SCENES, inPvP and self:ShowListWhileSieging())
    self:ApplyListVisibility()
end

--------------------------------------------------
-- RefreshBackdropColors
--------------------------------------------------
function PvPUA:RefreshBackdropColors()
    local useAlliance = self.savedVariables and self.savedVariables.backdropStyle == "Alliance"
    local bc = self.savedVariables and self.savedVariables.backdropColor
    local br = bc and bc.r or 0
    local bg_c = bc and bc.g or 0
    local bb = bc and bc.b or 0
    if self.controls.scoreRowBg then
        if useAlliance then
            self.controls.scoreRowBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaEven)
        else
            self.controls.scoreRowBg:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
        end
    end
    if self.controls.infoBg then
        if useAlliance then
            self.controls.infoBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaOdd)
        else
            self.controls.infoBg:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
        end
    end
    if self.state and self.state.visibleControls then
        for i, control in ipairs(self.state.visibleControls) do
            if control and control.backdrop then
                local ac = { r = 0, g = 0, b = 0 }
                if useAlliance and self.state.lastItems and self.state.lastItems[i] then
                    ac = GetColorForAlliance(self.state.lastItems[i].owningAlliance)
                end
                if useAlliance then
                    local rr, rg, rb = ac.r, ac.g, ac.b
                    local li = self.state.lastItems and self.state.lastItems[i]
                    if li and li.isScrollDropped then rr, rg, rb = 1, 1, 1 end
                    if i % 2 == 0 then
                        control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaEven)
                    else
                        control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaOdd)
                    end
                else
                    if i % 2 == 0 then
                        control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
                    else
                        control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- UpdateEntries
--------------------------------------------------
function PvPUA:UpdateEntries(itemsOfInterest)
    local listCap = (self.savedVariables and self.savedVariables.listCap) or 0
    if listCap > 0 then
        for i = #itemsOfInterest, listCap + 1, -1 do
            itemsOfInterest[i] = nil
        end
    end

    self.state.lastItems = itemsOfInterest
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    for i = 1, #itemsOfInterest do
        local item = itemsOfInterest[i]
        local control = self.state.visibleControls[i]
        if not control then break end
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, self.controls.TLW.rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
        control:SetHidden(false)
        local ac = GetColorForAlliance(item.owningAlliance)
        local useAlliance = self.savedVariables and self.savedVariables.backdropStyle == "Alliance"
        local bc = self.savedVariables and self.savedVariables.backdropColor
        local br = bc and bc.r or 0
        local bg_c = bc and bc.g or 0
        local bb = bc and bc.b or 0
        if useAlliance then
            local rr, rg, rb = ac.r, ac.g, ac.b
            if item.isScrollDropped then rr, rg, rb = 1, 1, 1 end
            if i % 2 == 0 then
                control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaEven)
            else
                control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaOdd)
            end
        else
            if i % 2 == 0 then
                control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
            else
                control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
            end
        end
        control.backdrop:SetEdgeColor(0, 0, 0, 0)
        if item.isUnderAttack == true then
            control.backdrop:SetHidden(false)
            control.uaImage:SetHidden(false)
            if control.uaOutline then control.uaOutline:SetHidden(item.isScrollCarrier == true) end
            control.image:SetHidden(false)
        else
            control.backdrop:SetHidden(false)
            control.uaImage:SetHidden(true)
            if control.uaOutline then control.uaOutline:SetHidden(true) end
            control.image:SetHidden(false)
        end
        local texture, offset = GetTextureAndOffsetForItem(item.keepType, item.rType, item.isPassable)
        if item.isScrollCarrier then
            texture = item.carrierTexture or texture
            offset = 2
            local baseW = self.config.imageWidth + offset * 2
            local baseH = self.config.entryHeight + offset * 2
            local iconScale = item.carrierIconScale or SCROLL_CARRIER_ICON_SCALE
            local cw = baseW * iconScale
            local ch = baseH * iconScale
            local dx = (cw - baseW) / 2
            local dy = (ch - baseH) / 2
            control.image:SetTexture(texture)
            control.image:ClearAnchors()
            control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -offset - dx, -offset - dy)
            control.image:SetDimensions(cw, ch)
            if item.carrierTint then
                control.image:SetColor(ac.r, ac.g, ac.b, 1)
            else
                control.image:SetColor(1, 1, 1, 1)
            end
            if control.imageOutline then control.imageOutline:SetHidden(true) end
        else
            control.image:SetTexture(texture)
            control.image:ClearAnchors()
            control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -offset, -offset)
            control.image:SetDimensions(self.config.imageWidth + offset * 2, self.config.entryHeight + offset * 2)
            control.image:SetColor(ac.r, ac.g, ac.b, 1)
            if control.imageOutline then
                local OL = 2
                control.imageOutline:SetTexture(texture)
                control.imageOutline:ClearAnchors()
                control.imageOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -offset - OL, -offset - OL)
                control.imageOutline:SetDimensions(self.config.imageWidth + offset * 2 + OL * 2,
                                                   self.config.entryHeight + offset * 2 + OL * 2)
                control.imageOutline:SetColor(0, 0, 0, 1)
                control.imageOutline:SetHidden(not self.config.iconOutline or texture == nil or texture == "")
            end
        end

        if control.scrollImage then
            local okScroll = pcall(function()
                if item.isScrollCarrier then
                    control.scrollImage:SetHidden(true)
                elseif item.scroll and item.scroll.pinType then
                    local sTex = GetScrollTexture(item.scroll.pinType)
                    if sTex then
                        local sw = (self.config.imageWidth + offset * 2) * SCROLL_KEEP_ICON_SCALE
                        local sh = (self.config.entryHeight + offset * 2) * SCROLL_KEEP_ICON_SCALE
                        control.scrollImage:ClearAnchors()
                        control.scrollImage:SetAnchor(CENTER, control.image, CENTER, 0, 0)
                        control.scrollImage:SetDimensions(sw, sh)
                        control.scrollImage:SetTexture(sTex)
                        control.scrollImage:SetColor(1, 1, 1, 1)
                        control.scrollImage:SetHidden(false)
                    else
                        control.scrollImage:SetHidden(true)
                    end
                else
                    control.scrollImage:SetHidden(true)
                end
            end)
            if not okScroll then control.scrollImage:SetHidden(true) end
        end

        if item.isScrollCarrier then
            local wideName = self.config.nameWidth + self.config.flagWidth
                           + self.config.siegeWidth * 3 + self.config.flagFlipWidth
            control.name:SetDimensions(wideName, self.config.entryHeight)
            control.name:SetColor(1, 1, 1, 1)
            control.name:SetText(item.name)
        else
            control.name:SetDimensions(self.config.nameWidth, self.config.entryHeight)
            control.name:SetColor(ac.r, ac.g, ac.b, 1)
            control.name:SetText(item.name)
        end

        local font = PvPUA:GetFont()
        control.name:SetFont(font)
        control.adSiege:SetFont(font)
        control.epSiege:SetFont(font)
        control.dcSiege:SetFont(font)
        control.flipStatus:SetFont(font)
        control.underAttackFor:SetFont(font)

        if item.siegeWeapons ~= nil then
            SetSiegeWeapons(control.dcSiege, item.siegeWeapons.DC)
            SetSiegeWeapons(control.adSiege, item.siegeWeapons.AD)
            SetSiegeWeapons(control.epSiege, item.siegeWeapons.EP)
            control.dcSiege:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)
            control.adSiege:SetColor(adColor.r, adColor.g, adColor.b, 1)
            control.epSiege:SetColor(epColor.r, epColor.g, epColor.b, 1)
        else
            control.adSiege:SetText("")
            control.epSiege:SetText("")
            control.dcSiege:SetText("")
        end

        local underAttackFor = item.underAttackFor
        control.underAttackFor:SetText(FormatUnderAttackTime(underAttackFor / 1000))
        local tr, tg, tb = GetTimerColor()
        control.underAttackFor:SetColor(tr, tg, tb, 1)

        local objectives = item.objectives
        control.progress.bar1:ClearAnchors()
        control.progress.bar2:ClearAnchors()
        control.progress.bar3:ClearAnchors()
        if item.isScrollCarrier then
            control.progress.bar1:SetHidden(true)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
            control.flipStatus:SetText("")
        elseif item.keepType == KEEPTYPE_KEEP or item.keepType == KEEPTYPE_OUTPOST then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 - self.config.flagHeight - 1)
            control.progress.bar2:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 + 1)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(false)
            control.progress.bar3:SetHidden(true)
            if objectives ~= nil and objectives[1] ~= nil and objectives[2] ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar2.progress:SetValue(objectives[2].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
                control.progress.bar2.progress:SetColor(GetColorForAlliance(objectives[2].holdingAlliance).r, GetColorForAlliance(objectives[2].holdingAlliance).g, GetColorForAlliance(objectives[2].holdingAlliance).b)
            else
                control.progress.bar1.progress:SetValue(100)
                control.progress.bar2.progress:SetValue(100)
            end
        elseif item.keepType == KEEPTYPE_TOWN then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 - self.config.flagHeight / 2)
            control.progress.bar2:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 * 3 - self.config.flagHeight / 2)
            control.progress.bar3:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 * 5 - self.config.flagHeight / 2)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(false)
            control.progress.bar3:SetHidden(false)
            if objectives ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar2.progress:SetValue(objectives[2].state)
                control.progress.bar3.progress:SetValue(objectives[3].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
                control.progress.bar2.progress:SetColor(GetColorForAlliance(objectives[2].holdingAlliance).r, GetColorForAlliance(objectives[2].holdingAlliance).g, GetColorForAlliance(objectives[2].holdingAlliance).b)
                control.progress.bar3.progress:SetColor(GetColorForAlliance(objectives[3].holdingAlliance).r, GetColorForAlliance(objectives[3].holdingAlliance).g, GetColorForAlliance(objectives[3].holdingAlliance).b)
            end
        elseif item.keepType == KEEPTYPE_RESOURCE or item.keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 - self.config.flagHeight / 2)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
            if objectives ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
            end
        else
            control.progress.bar1:SetHidden(true)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
        end

        if item.flipsAt ~= nil then
            local flipsIn = math.floor((item.flipsAt - GetGameTimeMilliseconds()) / 1000)
            if flipsIn >= 0 then
                control.flipStatus:SetText(flipsIn)
                if objectives ~= nil and objectives[1].holdingAlliance == GetUnitAlliance("player") then
                    control.flipStatus:SetColor(0, 1, 0, 1)
                else
                    control.flipStatus:SetColor(1, 0, 0, 1)
                end
            else
                control.flipStatus:SetText("")
            end
        else
            control.flipStatus:SetText("")
        end
    end
    for i = #itemsOfInterest + 1, #self.state.visibleControls do
        local c = self.state.visibleControls[i]
        c:SetHidden(true)
        if c.scrollImage then c.scrollImage:SetHidden(true) end
    end
end

function PvPUA:GetVeterancyInfo()
    local info = { ok = false, rank = 0, progress = 0, total = 0, icon = nil, raw1 = nil, why = nil }
    local okCall = pcall(function()
        if REWARD_TRACK_TYPE_AVA_VETERANCY == nil then info.why = "no REWARD_TRACK_TYPE_AVA_VETERANCY" return end
        if not (GetActiveReferenceTrackIdsForRewardTrackType and GetReferenceTrackIndex
                and GetInfoForRewardTrack) then info.why = "reward track API missing" return end

        local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY

        local ids = { GetActiveReferenceTrackIdsForRewardTrackType(trackType) }
        if #ids == 0 then info.why = "no active track ids" return end

        local trackId, trackIndex
        for i = 1, #ids do
            local candidate = ids[i]
            if type(candidate) == "number" then
                local idx = GetReferenceTrackIndex(trackType, candidate)
                if idx then
                    trackId, trackIndex = candidate, idx
                    break
                end
            end
        end
        if not trackIndex then info.why = "no resolvable track index" return end

        local first, currentRank, progressToNextRank = GetInfoForRewardTrack(trackType, trackIndex)
        info.raw1 = first

        if type(currentRank) ~= "number" then
            local rets = { GetInfoForRewardTrack(trackType, trackIndex) }
            for i = 1, #rets do
                if type(rets[i]) == "number" then
                    currentRank = rets[i]
                    progressToNextRank = (type(rets[i + 1]) == "number") and rets[i + 1] or 0
                    break
                end
            end
        end

        info.rank = currentRank or 0
        info.progress = progressToNextRank or 0

        local iconRank = info.rank
        if iconRank > 100 then iconRank = 100 end

        if info.rank >= 101 then
            info.total = 0
        elseif GetRewardTrackIdFromReferenceTrackId and GetTotalProgressAtRewardTrackTier then
            local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(trackType, trackId)
            if rewardTrackId then
                info.total = GetTotalProgressAtRewardTrackTier(rewardTrackId, info.rank) or 0
            end
        end

        if type(first) == "string" and first:lower():find("%.dds") then
            info.icon = first
        end

        if not info.icon then
            local iconFns = {
                { fn = "GetVeterancyRankIcon",          args = { "rank" } },
                { fn = "GetAvAVeterancyRankIcon",       args = { "rank" } },
                { fn = "GetRewardTrackTierIcon",        args = { "rewardTrackId", "rank" } },
                { fn = "GetRewardTrackRankIcon",        args = { "trackType", "rank" } },
                { fn = "GetLargeAvAVeterancyRankIcon",  args = { "rank" } },
            }
            local rewardTrackIdForIcon
            if GetRewardTrackIdFromReferenceTrackId then
                rewardTrackIdForIcon = GetRewardTrackIdFromReferenceTrackId(trackType, trackId)
            end
            local argValues = {
                rank          = iconRank,
                trackType     = trackType,
                rewardTrackId = rewardTrackIdForIcon,
                tier          = (type(first) == "number") and first or nil,
            }
            for i = 1, #iconFns do
                local entry = iconFns[i]
                local f = _G[entry.fn]
                if type(f) == "function" then
                    local callArgs, missing = {}, false
                    for a = 1, #entry.args do
                        local val = argValues[entry.args[a]]
                        if val == nil then
                            missing = true
                            break
                        end
                        callArgs[a] = val
                    end
                    if not missing then
                        local okIcon, res
                        if #callArgs == 1 then
                            okIcon, res = pcall(f, callArgs[1])
                        else
                            okIcon, res = pcall(f, callArgs[1], callArgs[2])
                        end
                        if okIcon and type(res) == "string" and res ~= ""
                           and res:lower():find("%.dds") then
                            info.icon = res
                            info.iconSource = entry.fn .. "(" .. table.concat(entry.args, ",") .. ")"
                            break
                        end
                    end
                end
            end
        end

        info.ok = true
    end)
    if not okCall then info.ok = false; info.why = info.why or "api call errored" end
    return info
end

--------------------------------------------------
-- RefreshRankLabel
--------------------------------------------------
function PvPUA:RefreshRankLabel()
    if not self.controls.infoRankNum then return end
    if self.savedVariables and self.savedVariables.barMode == "Veterancy" then
        local v = self:GetVeterancyInfo()
        if v.ok then
            self.controls.infoRankNum:SetText(tostring(v.rank))
        else
            self.controls.infoRankNum:SetText("--")
        end
        return
    end
    local rankNum  = ZO_CampaignAvARankRank and ZO_CampaignAvARankRank:GetText() or ""
    local rankName = ZO_CampaignAvARankName and ZO_CampaignAvARankName:GetText() or ""
    local grade    = rankName:match("GRADE %d+") or ""
    if rankNum ~= "" then
        self.controls.infoRankNum:SetText(rankNum .. (grade ~= "" and (" " .. grade) or ""))
    end
end

--------------------------------------------------
-- OnUiUpdate
--------------------------------------------------
function PvPUA:OnUiUpdate(itemsOfInterest)
    local rootControl = self.controls.TLW.rootControl

    rootControl:ClearAnchors()
    rootControl:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20 + self.config.entryHeight * 2)

    if itemsOfInterest ~= nil then
        self:UpdateEntries(itemsOfInterest)
    else
        for i = 1, #self.state.visibleControls do
            self.state.visibleControls[i]:SetHidden(true)
        end
    end

    self.controls.creditLabel:SetHidden(false)
    self.creditCycle = (self.creditCycle + 1) % totalSteps
    self.controls.creditLabel:SetText(CREDIT_STATES[self.creditCycle])
    self.controls.infoBg:SetHidden(false)
    self.controls.infoRankIcon:SetHidden(false)
    self.controls.infoEmpIcon:SetHidden(false)
    self.controls.infoBarBg:SetHidden(false)
    self.controls.infoBar:SetHidden(false)
    self.controls.infoRankNum:SetHidden(false)
    self.controls.infoAPText:SetHidden(false)
    self.controls.infoKD:SetHidden(false)

    local inIC = self.initializedZone == "IC"
    self:ApplyHeaderLayout()
    self.controls.scoreRow:SetHidden(inIC)

    local vetMode = self.savedVariables and self.savedVariables.barMode == "Veterancy"
    local vetIconShown = false
    PvPUA:RefreshRankLabel()

    if vetMode then
        local v = self:GetVeterancyInfo()
        if v.icon then
            self.controls.infoRankIcon:SetTexture(v.icon)
            self.controls.infoRankIcon:SetHidden(false)
            vetIconShown = true
        else
            local rankIconTex = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or ""
            if rankIconTex ~= "" then self.controls.infoRankIcon:SetTexture(rankIconTex) end
        end

        if v.ok and v.total and v.total > 0 then
            local pct = (v.progress / v.total) * 100
            if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
            self.controls.infoBar:SetValue(pct)
            self.controls.infoAPText:SetText(
                ZO_CommaDelimitNumber(v.progress) .. " / " .. ZO_CommaDelimitNumber(v.total))
        else
            self.controls.infoBar:SetValue(v.ok and 100 or 0)
            self.controls.infoAPText:SetText("")
        end
    else
        local currentXP = GetUnitAvARankPoints("player")
        local lastRankXP, nextRankXP = GetAvARankProgress(currentXP)
        local rankIconTex = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or ""
        if rankIconTex ~= "" then
            self.controls.infoRankIcon:SetTexture(rankIconTex)
        end
        local apEarned   = currentXP - lastRankXP
        local apRequired = nextRankXP and (nextRankXP - lastRankXP) or 0
        if nextRankXP and apRequired > 0 then
            local barPct = (apEarned / apRequired * 100)
            self.controls.infoBar:SetValue(barPct)
            self.controls.infoAPText:SetText(
                ZO_CommaDelimitNumber(apEarned) .. " / " .. ZO_CommaDelimitNumber(apRequired))
        else
            self.controls.infoBar:SetValue(100)
            self.controls.infoAPText:SetText("")
        end
    end
    local pAlliance = GetUnitAlliance("player")
    local ac = GetColorForAlliance(pAlliance)
    self.controls.infoBar:SetColor(ac.r, ac.g, ac.b, 1)
    if vetIconShown then
        self.controls.infoRankIcon:SetColor(1, 1, 1, 1)
    else
        self.controls.infoRankIcon:SetColor(ac.r, ac.g, ac.b, 1)
    end

    self:RefreshKDText()

    if inIC then return end

    local campaignId = GetCurrentCampaignId()

    if self.controls.empSlices then
        local empAlliance = GetCampaignEmperorInfo and GetCampaignEmperorInfo(campaignId) or 0
        local hasEmperor = empAlliance ~= nil and empAlliance ~= 0
        local ec = hasEmperor and GetColorForAlliance(empAlliance) or nil

        for slot = 1, #self.controls.empSlices do
            local slice = self.controls.empSlices[slot]
            if hasEmperor then
                slice:SetColor(ec.r, ec.g, ec.b, 1)
            else
                local keepId = self.emperorKeepIds and self.emperorKeepIds[slot]
                local owner = keepId and GetKeepAlliance(keepId, BGQUERY_LOCAL) or 0
                if owner ~= nil and owner ~= 0 then
                    local kc = GetColorForAlliance(owner)
                    slice:SetColor(kc.r, kc.g, kc.b, 1)
                else
                    slice:SetColor(0.35, 0.35, 0.35, 1)
                end
            end
        end
    end

    local secs = GetSecondsUntilCampaignScoreReevaluation(campaignId)
    local mins = math.floor(secs / 60)
    local s = secs - mins * 60
    self.controls.scoreTimer:SetText(string.format("%d:%02d", mins, s))
    local dcTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_DAGGERFALL_COVENANT) or 0
    local adTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_ALDMERI_DOMINION) or 0
    local epTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_EBONHEART_PACT) or 0
    local dcPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_DAGGERFALL_COVENANT) or 0
    local adPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_ALDMERI_DOMINION) or 0
    local epPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_EBONHEART_PACT) or 0
    self.controls.scoreDCPts:SetText("[" .. dcTotal .. "] +" .. dcPot .. "p")
    self.controls.scoreADPts:SetText("[" .. adTotal .. "] +" .. adPot .. "p")
    self.controls.scoreEPPts:SetText("[" .. epTotal .. "] +" .. epPot .. "p")
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)
    self.controls.scoreDCIcon:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)
    self.controls.scoreADIcon:SetColor(adColor.r, adColor.g, adColor.b, 1)
    self.controls.scoreEPIcon:SetColor(epColor.r, epColor.g, epColor.b, 1)


end

--------------------------------------------------
-- OnObjectiveControlState
--------------------------------------------------
function PvPUA:OnObjectiveControlState(eventCode, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, objectiveControlState, holdingAlliance, attackingAlliance, pinType)
    local keep = self:GetItemByKeepId(keepId)
    if keep ~= nil then
        local objectives = keep.objectives
        if objectives == nil then
            self:AddObjectives()
            objectives = keep.objectives
        end
        if objectives ~= nil then
            local objective = nil
            for i = 1, #objectives do
                if objectives[i].id == objectiveId then
                    objective = objectives[i]
                    break
                end
            end
            if objective == nil then
                for i = 1, #objectives do
                    if objectives[i].id == nil then
                        objectives[i].id = objectiveId
                        objective = objectives[i]
                        break
                    end
                end
            end
            if objective ~= nil then
                objective.holdingAlliance = holdingAlliance
                if objective.holdingAlliance == 0 then
                    objective.holdingAlliance = attackingAlliance
                end
                objective.state = GetFlagStatePercent(objectiveControlState, keep.owningAlliance, holdingAlliance)
                AdjustKeepFlipping(keep)
            end
        end
    end
end

--------------------------------------------------
-- K:/D: text
--------------------------------------------------
function PvPUA:RefreshKDText()
    local c = self.controls
    if not c or not c.infoKD then return end
    local gap = self.config.kdGap or " "
    c.infoKD:SetText("|c00FF00K:|r " .. self.session.killingBlows
                     .. gap .. "|cFF0000D:|r " .. self.session.deaths)
end

--------------------------------------------------
-- CyroUpdateLoop
--------------------------------------------------
function PvPUA:CyroUpdateLoop()
    if IsInCyrodiilOrIC() == true then
        local itemsOfInterest = {}
        local gameTime = GetGameTimeMilliseconds()
        local function addItems(newItems)
            if newItems ~= nil then
                for i = 1, #newItems do
                    table.insert(itemsOfInterest, newItems[i])
                end
            end
        end
        addItems(self:UpdateItem(self.state.resources, gameTime))
        addItems(self:UpdateItem(self.state.keeps, gameTime))
        addItems(self:UpdateItem(self.state.outposts, gameTime))
        addItems(self:UpdateItem(self.state.villages, gameTime))
        addItems(self:UpdateItem(self.state.destructibles, gameTime))
        addItems(self:UpdateItem(self.state.districts, gameTime))
        if self.initializedZone ~= "IC" then
            self:RefreshScrolls()
            self:UpdateScrollCounts()
            self:RefreshScrollTally()
            self:RefreshScrollCarriers()
            if not (self.savedVariables and self.savedVariables.showScrollCarriers == false) then
                addItems(self:GetScrollCarrierItems())
            end
            self:RefreshVolendrungCarrier()
            if not (self.savedVariables and self.savedVariables.showVolendrungRow == false) then
                local volItem = self:GetVolendrungCarrierItem()
                if volItem then addItems({ volItem }) end
            end
        end
        if #itemsOfInterest > 1 then
            table.sort(itemsOfInterest, SortItemsOfInterest)
        end
        self:OnUiUpdate(itemsOfInterest)
        self:ApplyListVisibility()
    end
end

--------------------------------------------------
-- Volendrung Events
--------------------------------------------------
function PvPUA:CacheVolendrungName(daedricArtifactId)
    if not daedricArtifactId or not GetDaedricArtifactDisplayName then return end
    local nm = GetDaedricArtifactDisplayName(daedricArtifactId)
    if nm and nm ~= "" then
        self.volendrungName    = zo_strformat("<<1>>", nm)
    end
end

function PvPUA:OnVolendrungSpawned(eventCode, daedricArtifactId)
    self:CacheVolendrungName(daedricArtifactId)
    self.volendrung = {
        texture        = "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds",
        holderAlliance = 0,
        objectiveId    = nil,
        keepId         = nil,
        despawnAt      = nil,
        spawnedAt      = GetGameTimeMilliseconds(),
    }
    self:CyroUpdateLoop()
end

function PvPUA:OnVolendrungStateChanged(eventCode, objectiveKeepId, objectiveObjectiveId, battlegroundContext,
    objectiveControlEvent, objectiveControlState, holderAlliance, lastHolderAlliance, pinType,
    daedricArtifactId, lastObjectiveControlState)

    self:CacheVolendrungName(daedricArtifactId)

    if lastObjectiveControlState == OBJECTIVE_CONTROL_STATE_UNKNOWN
    and objectiveControlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
        self.volendrung = {
            texture        = GetVolendrungTexture(pinType),
            holderAlliance = GetVolendrungAlliance(pinType),
            objectiveId    = objectiveObjectiveId,
            keepId         = objectiveKeepId,
            despawnAt      = nil,
            spawnedAt      = (self.volendrung and self.volendrung.spawnedAt) or GetGameTimeMilliseconds(),
        }
        self:CyroUpdateLoop()
        return
    end

    if self.volendrung and objectiveControlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
        self.volendrung.texture        = GetVolendrungTexture(pinType)
        self.volendrung.holderAlliance = GetVolendrungAlliance(pinType)
        self.volendrung.objectiveId    = objectiveObjectiveId
        self.volendrung.keepId         = objectiveKeepId
        self.volendrung.despawnAt      = nil
        self:CyroUpdateLoop()
    end
end

function PvPUA:OnArtifactScrollStateChanged(...)
    self:RefreshScrolls()
end

--------------------------------------------------
-- Volendrung Despawn Poll
--------------------------------------------------
function PvPUA:PollVolendrungDespawn()
    if not self.volendrung then return end

    if self.volendrung.despawnAt then
        if GetGameTimeMilliseconds() >= self.volendrung.despawnAt then
            self.volendrung = nil
            self:CyroUpdateLoop()
        end
        return
    end

    if self.volendrung.objectiveId and self.volendrung.keepId then
        local objectiveState = select(3, GetObjectiveInfo(
            self.volendrung.keepId,
            self.volendrung.objectiveId,
            BGQUERY_LOCAL
        ))
        if objectiveState == OBJECTIVE_CONTROL_STATE_UNKNOWN or objectiveState == nil then
            self.volendrung.despawnAt = GetGameTimeMilliseconds() + VOLENDRUNG_DESPAWN_GRACE
        end
    end
end

function PvPUA:RefreshStatLabels()
    local c = self.controls
    if not c.infoKD then return end
    self:RefreshKDText()
    c.infoKD:SetHidden(false)
end

--------------------------------------------------
-- UpdateKAD
--------------------------------------------------
local function UpdateKAD()
    if PvPUA.controls and PvPUA.controls.infoKD then
        PvPUA:RefreshKDText()
    end
end

--------------------------------------------------
-- OnPlayerActivated
--------------------------------------------------
function PvPUA:ZoneCheck()
    if IsInCyrodiilOrIC() == true then
        local zoneKind = IsInICCampaign() and "IC" or "CYRO"
        if self.initializedItems == false or self.initializedZone ~= zoneKind then
            local hadVolendrung = self.volendrung
            self:InitState(hadVolendrung)
            self:ResetObjectives()
            self.initializedItems = true
            self.initializedZone = zoneKind
        end
        if self.registeredCyroEvents == false then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_OBJECTIVE_CONTROL_STATE,
                function(...) PvPUA:OnObjectiveControlState(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED,
                function(...) PvPUA:OnVolendrungSpawned(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED,
                function(...) PvPUA:OnVolendrungStateChanged(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_ARTIFACT_SCROLL_STATE_CHANGED,
                function(...) PvPUA:OnArtifactScrollStateChanged(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_ArtifactCtrl", EVENT_ARTIFACT_CONTROL_STATE,
                function(...) PvPUA:OnArtifactControlState(...) end)
            if EVENT_REWARD_TRACK_PROGRESS_GAINED then
                EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_VetTrack", EVENT_REWARD_TRACK_PROGRESS_GAINED,
                    function(_, trackType)
                        if trackType == REWARD_TRACK_TYPE_AVA_VETERANCY then
                            PvPUA:RefreshRankLabel()
                        end
                    end)
            end
            EVENT_MANAGER:RegisterForUpdate(PvPUA.name, PvPUA.constants.updateInterval,
                function()
                    pcall(function()
                        PvPUA:CyroUpdateLoop()
                        PvPUA:PollVolendrungDespawn()
                    end)
                end)
            self.registeredCyroEvents = true
        end
    else
        if self.registeredCyroEvents == true then
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_OBJECTIVE_CONTROL_STATE)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_ARTIFACT_SCROLL_STATE_CHANGED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_ArtifactCtrl", EVENT_ARTIFACT_CONTROL_STATE)
            if EVENT_REWARD_TRACK_PROGRESS_GAINED then
                EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_VetTrack", EVENT_REWARD_TRACK_PROGRESS_GAINED)
            end
            EVENT_MANAGER:UnregisterForUpdate(PvPUA.name)
            self.registeredCyroEvents = false
        end
        self.initializedItems = false
        self.volendrung = nil
        self.volendrungName    = nil
        self.controls.TLW:SetHidden(true)
        self.controls.creditLabel:SetHidden(true)
        self.controls.scoreRow:SetHidden(true)
        self.controls.infoBg:SetHidden(true)
        self.controls.infoRankIcon:SetHidden(true)
        self.controls.infoEmpIcon:SetHidden(true)
        self.controls.infoBarBg:SetHidden(true)
        self.controls.infoBar:SetHidden(true)
        self.controls.infoRankNum:SetHidden(true)
        self.controls.infoAPText:SetHidden(true)
        self.controls.infoKD:SetHidden(true)
    end
    PvPUA:UpdateHUDScenes()
end

function PvPUA:OnPlayerActivated()
    PI.StartPolling()
    PI.ScheduleGroupRefresh()
    self:RefreshQueueSoon()

    self:ZoneCheck()

    zo_callLater(function() PvPUA:UpdateHUDScenes() end, 500)
    zo_callLater(function() PvPUA:RefreshRankLabel() end, 2000)
    if PvPUA_RefreshRespawnButtons then PvPUA_RefreshRespawnButtons() end
end

--------------------------------------------------
-- Auto Invite
--------------------------------------------------
PvPUA.aiListening = false

local function AIEcho(msg)
    CHAT_ROUTER:AddSystemMessage("|cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r |c" .. AD_HEX .. "" .. msg)
end

local function AIEchoRed(msg)
    CHAT_ROUTER:AddSystemMessage("|cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r |c" .. EP_HEX .. "" .. msg)
end

local function AIGuildChannelToIndex(messageType)
    if messageType == CHAT_CHANNEL_GUILD_1 then return 1 end
    if messageType == CHAT_CHANNEL_GUILD_2 then return 2 end
    if messageType == CHAT_CHANNEL_GUILD_3 then return 3 end
    if messageType == CHAT_CHANNEL_GUILD_4 then return 4 end
    if messageType == CHAT_CHANNEL_GUILD_5 then return 5 end
    return nil
end

local function AIIsZoneChannel(messageType)
    if messageType == CHAT_CHANNEL_ZONE then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_1 then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_2 then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_3 then return true end
    return false
end

local function AIResolveInvitee(messageType, from)
    local raw = from or ""

    local function strip(n) return (n or ""):gsub("%^.+", "") end

    if ZO_ShouldPreferUserId and ZO_ShouldPreferUserId() then
        return strip(raw)
    end

    if messageType == CHAT_CHANNEL_WHISPER then
        return strip(raw)
    end

    local gIdx = AIGuildChannelToIndex(messageType)
    if gIdx then
        local guildId = GetGuildId(gIdx)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == raw then
                    local hasChar, charName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return strip(charName) end
                    return ""
                end
            end
        end
        return strip(raw)
    end

    for i = 1, GetNumFriends() do
        local hasChar, cName = GetFriendCharacterInfo(i)
        local acct = GetFriendInfo(i)
        if acct == raw and hasChar then
            return strip(cName)
        end
    end
    for g = 1, 5 do
        local guildId = GetGuildId(g)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == raw then
                    local hasChar, charName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return strip(charName) end
                end
            end
        end
    end
    return strip(raw)
end

local function AIKeywordList()
    local raw = PvPUA.charVariables.aiKeyword
    if not raw or raw == "" then return nil end
    local list = {}
    for word in string.gmatch(raw, "[^,]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", "")
        if word ~= "" then
            list[#list + 1] = string.lower(word)
        end
    end
    if #list == 0 then return nil end
    return list
end

local aiSelfName, aiSelfAccount
local function AIIsSelf(from, fromDisplayName)
    if not aiSelfName then
        aiSelfName = (GetUnitName("player") or ""):gsub("%^.+", "")
        aiSelfAccount = GetUnitDisplayName("player") or ""
    end
    local n = (from or ""):gsub("%^.+", "")
    if n ~= "" and n == aiSelfName then return true end
    if fromDisplayName and fromDisplayName ~= "" and fromDisplayName == aiSelfAccount then return true end
    return false
end

local function AIIsPvPZoneName(zoneName)
    if not zoneName or zoneName == "" then return nil end
    if zoneName:find("Cyrodiil") then return true end
    if zoneName:find("Imperial") then return true end
    return false
end

local function AIResolveSenderZoneStatus(messageType, from)
    local gIdx = AIGuildChannelToIndex(messageType)
    if gIdx then
        local guildId = GetGuildId(gIdx)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == from then
                    local hasChar, _, zoneName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return AIIsPvPZoneName(zoneName) end
                    return nil
                end
            end
        end
        return nil
    end

    if messageType == CHAT_CHANNEL_WHISPER then
        for g = 1, 5 do
            local guildId = GetGuildId(g)
            if guildId and guildId > 0 then
                for i = 1, GetNumGuildMembers(guildId) do
                    local acct = GetGuildMemberInfo(guildId, i)
                    if acct == from then
                        local hasChar, _, zoneName = GetGuildMemberCharacterInfo(guildId, i)
                        if hasChar then return AIIsPvPZoneName(zoneName) end
                        return nil
                    end
                end
            end
        end
        for i = 1, GetNumFriends() do
            local acct = GetFriendInfo(i)
            if acct == from then
                local hasChar, _, zoneName = GetFriendCharacterInfo(i)
                if hasChar then return AIIsPvPZoneName(zoneName) end
                return nil
            end
        end
        return nil
    end

    return nil
end

local function AIOnWhisper(_, messageType, from, message, isCustomerService, fromDisplayName)
    local keywords = AIKeywordList()
    if not keywords then return end

    if AIIsSelf(from, fromDisplayName) then return end

    local allowed = false
    if messageType == CHAT_CHANNEL_WHISPER then
        allowed = PvPUA.charVariables.aiWhisper
    elseif messageType == CHAT_CHANNEL_SAY then
        allowed = PvPUA.charVariables.aiSay
    elseif AIIsZoneChannel(messageType) then
        allowed = PvPUA.charVariables.aiZone
    else
        local gIdx = AIGuildChannelToIndex(messageType)
        if gIdx then
            local toggles = PvPUA.charVariables.aiGuildToggles
            if toggles and toggles[gIdx] then
                allowed = true
            end
        end
    end
    if not allowed then return end

    local aiPvP = PvPUA.charVariables.aiPvP
    local aiPvE = PvPUA.charVariables.aiPvE
    if not (aiPvP and aiPvE) then
        local isPvPZone
        if messageType == CHAT_CHANNEL_SAY or AIIsZoneChannel(messageType) then
            isPvPZone = IsInCyrodiilOrIC()
        else
            isPvPZone = AIResolveSenderZoneStatus(messageType, from)
        end
        if isPvPZone == true and not aiPvP then return end
        if isPvPZone == false and not aiPvE then return end
    end

    local lowerMsg = string.lower(message)
    local matched = false
    for _, kw in ipairs(keywords) do
        if lowerMsg == kw then
            matched = true
            break
        end
    end
    if not matched then return end

    if GetGroupSize() >= 12 then
        AIEcho("Group is full. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
        return
    end

    local name = AIResolveInvitee(messageType, from)
    if not name or name == "" then return end
    name = name:gsub("%^.+", "")
    if name == "" then return end

    local shown = fromDisplayName
    if not shown or shown == "" then shown = name end

    AIEcho("Inviting |c00FF00" .. shown .. "|r")
    GroupInviteByName(name)
end


local function RSFindNearestKeep()
    local selfX, selfY = GetMapPlayerPosition("player")
    local bestId, bestDist
    for i = 1, GetNumKeeps() do
        local keepId = GetKeepKeysByIndex(i)
        if CanRespawnAtKeep(keepId) then
            local _, kx, ky = GetKeepPinInfo(keepId, BGQUERY_LOCAL)
            if kx ~= 0 and ky ~= 0 then
                local dist = zo_distance3D(selfX, selfY, 0, kx, ky, 0)
                if not bestDist or dist < bestDist then
                    bestId, bestDist = keepId, dist
                end
            end
        end
    end
    return bestId
end

local function RSFindNearestCamp()
    if GetNumForwardCamps(BGQUERY_LOCAL) == 0 then return nil end
    local selfX, selfY = GetMapPlayerPosition("player")
    local bestIndex, bestDist
    for i = 1, GetNumForwardCamps(BGQUERY_LOCAL) do
        local _, cx, cy, radius = GetForwardCampPinInfo(BGQUERY_LOCAL, i)
        if cx ~= 0 and cy ~= 0 and radius and radius > 0 then
            local dist = zo_distance3D(selfX, selfY, 0, cx, cy, 0)
            if dist < radius and (not bestDist or dist < bestDist) then
                bestIndex, bestDist = i, dist
            end
        end
    end
    return bestIndex
end

local function RSCampCooldownText()
    local ok, result = pcall(function()
        if not GetNextForwardCampRespawnTime then return "" end
        local nextRespawnMS = GetNextForwardCampRespawnTime()
        if not nextRespawnMS or nextRespawnMS == 0 then return "" end
        local remainingMS = nextRespawnMS - GetGameTimeMilliseconds()
        if remainingMS <= 0 then return "" end
        local totalSeconds = math.ceil(remainingMS / 1000)
        local minutes = math.floor(totalSeconds / 60)
        local seconds = totalSeconds % 60
        return string.format(" |cB4B2A9%d:%02d|r", minutes, seconds)
    end)
    if ok then return result end
    return ""
end

local function RSRespawnAtNearestKeep()
    local keepId = RSFindNearestKeep()
    if keepId then RespawnAtKeep(keepId) end
end

local function RSRespawnAtNearestCamp()
    local campIndex = RSFindNearestCamp()
    if campIndex then RespawnAtForwardCamp(campIndex) end
end

local function RSStyleButton(button)
    if button.rsStyled then return end
    button.rsStyled = true
    local template = ZO_GetPlatformTemplate("ZO_DeathKeybindButton")
    if template then
        ApplyTemplateToControl(button, template)
    end
    button:SetNormalTextColor(IsInGamepadPreferredMode() and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT)
end

local function RSSetupDeathButtons()
    if not IsInCyrodiil() then return end

    local btnCamp = PvPUA_Death_ButtonsButton1
    local btnKeep = PvPUA_Death_ButtonsButton2
    if not btnCamp or not btnKeep then return end

    RSStyleButton(btnCamp)
    RSStyleButton(btnKeep)

    local aColor = GetAllianceColor(GetUnitAlliance("player")):ToHex()

    local suffix = " |cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r"

    local campIndex = RSFindNearestCamp()
    if campIndex then
        local cooldownText = RSCampCooldownText()
        btnCamp:SetKeybind("PVPUA_RESPAWN_AT_CAMP")
        btnCamp:SetText("Respawn at |c" .. aColor .. "Forward Camp|r" .. cooldownText .. suffix)
        btnCamp:SetCallback(RSRespawnAtNearestCamp)
        btnCamp:SetEnabled(true)
        btnCamp:SetKeybindEnabled(true)
        btnCamp:SetHidden(false)
    else
        btnCamp:SetKeybind(nil)
        btnCamp:SetText("")
        btnCamp:SetCallback(nil)
        btnCamp:SetHidden(true)
    end

    local keepId = RSFindNearestKeep()
    if keepId then
        local keepName = GetKeepName(keepId) or "Keep"
        btnKeep:SetKeybind("PVPUA_RESPAWN_AT_KEEP")
        btnKeep:SetText("Respawn at |c" .. aColor .. keepName .. "|r" .. suffix)
        btnKeep:SetCallback(RSRespawnAtNearestKeep)
        btnKeep:SetEnabled(true)
        btnKeep:SetKeybindEnabled(true)
        btnKeep:SetHidden(false)
    else
        btnKeep:SetKeybind(nil)
        btnKeep:SetText("")
        btnKeep:SetCallback(nil)
        btnKeep:SetHidden(true)
    end
end

local rsButtonsShown = false

local function RSShouldShow()
    if not IsInCyrodiil() then return false end
    if not IsUnitDead("player") then return false end
    local name = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    return name == "hud" or name == "hudui"
end

local function RSApplyVisibility()
    local control = PvPUA_Death_Buttons
    if not control then return end

    if RSShouldShow() then
        control:SetHidden(false)
        RSSetupDeathButtons()
        if not rsButtonsShown then
            rsButtonsShown = true
            control:SetHandler("OnUpdate", function() RSSetupDeathButtons() end)
        end
    else
        control:SetHidden(true)
        if rsButtonsShown then
            rsButtonsShown = false
            control:SetHandler("OnUpdate", nil)
        end
    end
end

local rsSceneHooked = false
local function RSHookScenes()
    if rsSceneHooked or not SCENE_MANAGER then return end
    rsSceneHooked = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        RSApplyVisibility()
    end)
end

local function RSOnDeathStateChanged()
    RSHookScenes()
    RSApplyVisibility()
end

function PvPUA_RefreshRespawnButtons()
    RSOnDeathStateChanged()
end

local function AICanInvite()
    if GetGroupSize() > 1 and not IsUnitGroupLeader("player") then
        return false
    end
    return true
end

local function AIOnLeaderUpdate()
    if not PvPUA.charVariables.aiEnabled then return end

    if not AICanInvite() then
        if PvPUA.aiListening then
            AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
            PvPUA:AIStop(true)
        end
        return
    end

    if PvPUA.aiListening then return end
    if GetGroupSize() >= 12 then return end

    local kw = PvPUA.charVariables.aiKeyword or ""
    if GetGroupSize() > 1 then
        AIEcho("You are now group leader. Listening again for keyword(s): |c00FF00" .. kw .. "|r")
    else
        AIEcho("Now solo. Listening again for keyword(s): |c00FF00" .. kw .. "|r")
    end
    PvPUA:AIStart(true)
end

local function AIOnGroupMemberLeft()
    if not PvPUA.charVariables.aiEnabled then return end
    if PvPUA.aiListening then return end
    if not AICanInvite() then return end
    if GetGroupSize() <= 1 then
        AIOnLeaderUpdate()
        return
    end
    AIEcho("Spot opened. Listening again for keyword(s): |c00FF00" .. (PvPUA.charVariables.aiKeyword or "") .. "|r")
    PvPUA:AIStart(true)
end

local function AICheckGroupFull()
    if not PvPUA.aiListening then return end
    if GetGroupSize() >= 12 then
        AIEcho("Group is full. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
        return
    end
    if not AICanInvite() then
        AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
    end
end

PvPUA.aiKickTable = {}

local function AIKickScanOffline()
    local now = GetTimeStamp()
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and tag ~= "" and not IsUnitOnline(tag) then
            local n = GetUnitName(tag)
            if n then n = n:gsub("%^.+", "") end
            if n and n ~= "" and PvPUA.aiKickTable[n] == nil then
                PvPUA.aiKickTable[n] = now
            end
        end
    end
end

local function AIKickByName(name)
    PvPUA.aiKickTable[name] = nil
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        local tagName = nil
        if tag and tag ~= "" then
            tagName = GetUnitName(tag)
            if tagName then tagName = tagName:gsub("%^.+", "") end
        end
        if tag and tag ~= "" and tagName == name then
            local mins = PvPUA.charVariables.aiKickMinutes or 5
            local shown = GetUnitDisplayName(tag)
            if not shown or shown == "" then shown = name end
            AIEcho("|c" .. EP_HEX .. "Kicked|r |c00FF00" .. shown .. "|r - offline " .. mins .. " min.")
            GroupKick(tag)
            return
        end
    end
end

local function AIOnConnectedStatus(_, unitTag, isOnline)
    if not unitTag or unitTag == "" then return end
    local n = GetUnitName(unitTag)
    if not n or n == "" then return end
    n = n:gsub("%^.+", "")
    if n == "" then return end
    if isOnline then
        PvPUA.aiKickTable[n] = nil
    elseif PvPUA.aiKickTable[n] == nil then
        PvPUA.aiKickTable[n] = GetTimeStamp()
        if PvPUA.charVariables.aiKickOffline
           and GetGroupSize() > 1
           and IsUnitGroupLeader("player") then
            local mins = PvPUA.charVariables.aiKickMinutes or 5
            local shown = GetUnitDisplayName(unitTag)
            if not shown or shown == "" then shown = n end
            AIEcho("|c00FF00" .. shown .. "|r went offline. |c" .. EP_HEX .. "Kicking|r in " .. mins .. " min.")
        end
    end
end

local function AIOnKickGroupLeft(_, characterName, _, isLocalPlayer)
    if isLocalPlayer then
        PvPUA.aiKickTable = {}
        return
    end
    if type(characterName) == "string" and characterName ~= "" then
        PvPUA.aiKickTable[(characterName:gsub("%^.+", ""))] = nil
    end
end

local function AIKickCheck()
    if not PvPUA.charVariables.aiKickOffline then return end
    if GetGroupSize() <= 1 then return end
    if not IsUnitGroupLeader("player") then return end

    local limit = (PvPUA.charVariables.aiKickMinutes or 5) * 60
    local now = GetTimeStamp()
    for n, t in pairs(PvPUA.aiKickTable) do
        if GetDiffBetweenTimeStamps(now, t) > limit then
            AIKickByName(n)
        end
    end
end

function PvPUA:AIKickStart()
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AIKickStatus",
        EVENT_GROUP_MEMBER_CONNECTED_STATUS,
        AIOnConnectedStatus
    )
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AIKickLeft",
        EVENT_GROUP_MEMBER_LEFT,
        AIOnKickGroupLeft
    )
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_AIKickTick", 1000, AIKickCheck)
    AIKickScanOffline()
end

function PvPUA:AIKickStop()
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIKickStatus", EVENT_GROUP_MEMBER_CONNECTED_STATUS)
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIKickLeft", EVENT_GROUP_MEMBER_LEFT)
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_AIKickTick")
    PvPUA.aiKickTable = {}
end

function PvPUA:AIStart(internal)
    if not AICanInvite() then
        if not internal then
            PvPUA.charVariables.aiEnabled = true
            AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
        end
        return
    end

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AI",
        EVENT_CHAT_MESSAGE_CHANNEL,
        AIOnWhisper
    )
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_AIFullCheck", 1000, AICheckGroupFull)
    PvPUA.aiListening = true
    if not internal then
        PvPUA.charVariables.aiEnabled = true
        AIEcho("Listening for keyword(s): |c00FF00" .. (PvPUA.charVariables.aiKeyword or "") .. "|r")
    end
end

function PvPUA:AIStop(internal)
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AI", EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_AIFullCheck")
    PvPUA.aiListening = false
    if not internal then
        PvPUA.charVariables.aiEnabled = false
        EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIGroup", EVENT_GROUP_MEMBER_LEFT)
        EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AILeader", EVENT_LEADER_UPDATE)
        AIEchoRed("|c" .. AD_HEX .. "Auto invite |c" .. EP_HEX .. "disabled|r.")
    end
end

--------------------------------------------------
-- Screen Bounds
--------------------------------------------------
local function ScreenBounds()
    local w, h
    if GuiRoot and GuiRoot.GetDimensions then w, h = GuiRoot:GetDimensions() end
    if type(w) ~= "number" or w < 640 then w = 1920 end
    if type(h) ~= "number" or h < 480 then h = 1080 end
    return math.ceil(w / 5) * 5, math.ceil(h / 5) * 5
end

--------------------------------------------------
-- Effect Alerts
--------------------------------------------------
PvPUA.effectAlerts = {}

local EA_DAMAGE_TIMEOUT_MS = 3000
local EA_PANEL_WIDTH = 1200
local HK_KEY = "homekeeps"
local HK_TICK_MS = 250

local EA_DEFS = {
    { key = "homekeeps", label = "|cFF8800Home Keeps|r",
      defaultText = "Home Keeps",
      defaultColor = { r = 1, g = 1, b = 1, a = 1 },
      defaultPosY = -335,
      mode = "queue",
      icon = "EsoUI/Art/Campaign/Gamepad/gp_overview_keepIcon.dds" },
    { key = "negate",    label = "|c9B59D0Negate|r",
      defaultText = "ENEMY NEGATE!",
      defaultColor = { r = 0.61, g = 0.35, b = 0.82, a = 1 },
      defaultPosY = -220,
      mode = "effect",
      icon = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds",
      names = { "Negate Magic", "Suppression Field", "Absorption Field" } },
    { key = "corrosive", label = "|c" .. EP_HEX .. "Corrosive|r",
      defaultText = "ENEMY CORROSIVE!",
      defaultColor = { r = 1, g = 0.2, b = 0.2, a = 1 },
      defaultPosY = -160,
      mode = "damage",
      icon = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds",
      abilityIds = { 17879 } },
}

local EA_NAME_LOOKUP = {}
local EA_ID_LOOKUP = {}
local EA_DEF_BY_KEY = {}
for i = 1, #EA_DEFS do
    EA_DEF_BY_KEY[EA_DEFS[i].key] = EA_DEFS[i]
    if EA_DEFS[i].names then
        for _, n in ipairs(EA_DEFS[i].names) do
            EA_NAME_LOOKUP[n] = EA_DEFS[i].key
        end
    end
    if EA_DEFS[i].abilityIds then
        for _, id in ipairs(EA_DEFS[i].abilityIds) do
            EA_ID_LOOKUP[id] = EA_DEFS[i].key
        end
    end
end

local EA_FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Light",   value = "EsoUI/Common/Fonts/univers55.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
    { name = "Arial Narrow",    value = "EsoUI/Common/Fonts/arialn.ttf" },
    { name = "Consolas",        value = "EsoUI/Common/Fonts/consola.ttf" },
}

function PvPUA:EAVars(key)
    local sv = self.savedVariables
    if not sv then return nil end
    sv.effectAlerts = sv.effectAlerts or {}
    if not sv.effectAlerts[key] then
        local def
        for i = 1, #EA_DEFS do
            if EA_DEFS[i].key == key then def = EA_DEFS[i] break end
        end
        local dc = def and def.defaultColor or { r = 1, g = 0.2, b = 0.2, a = 1 }
        sv.effectAlerts[key] = {
            enabled     = false,
            messageText = def and def.defaultText or "ALERT",
            posX        = 0,
            posY        = def and def.defaultPosY or -160,
            fontSize    = 45,
            font        = "EsoUI/Common/Fonts/univers67.otf",
            textColor   = { r = dc.r, g = dc.g, b = dc.b, a = 1 },
            pulsate     = false,
            pulseSpeed  = 3,
        }
    end
    return sv.effectAlerts[key]
end

function PvPUA:EAFont(key)
    local v = self:EAVars(key)
    if not v then return "EsoUI/Common/Fonts/univers67.otf|45|outline" end
    return (v.font or "EsoUI/Common/Fonts/univers67.otf") .. "|" .. tostring(v.fontSize or 45) .. "|outline"
end

function PvPUA:EAApplyPosition(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end
    local def = EA_DEF_BY_KEY[key]
    a.panel:ClearAnchors()
    a.panel:SetAnchor(CENTER, GuiRoot, CENTER,
        v.posX or 0,
        v.posY or (def and def.defaultPosY) or -160)
end

function PvPUA:EAApplyMetrics(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end
    local def = EA_DEF_BY_KEY[key]
    if not def or def.mode ~= "queue" then return end
    local size = v.fontSize or 45
    a.panel:SetDimensions(EA_PANEL_WIDTH, math.ceil(size * 3))
    a.label:SetWidth(EA_PANEL_WIDTH)
end

function PvPUA:EACreatePanel(key)
    if self.effectAlerts[key] then return end
    local panel = wm:CreateTopLevelWindow("PvPUA_Alert_" .. key)
    panel:SetClampedToScreen(true)
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_HIGH)
    panel:SetDimensions(EA_PANEL_WIDTH, 120)
    panel:SetHidden(true)

    local label = wm:CreateControl(nil, panel, CT_LABEL)
    label:SetAnchor(CENTER, panel, CENTER, 0, 0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.effectAlerts[key] = { panel = panel, label = label, active = false, preview = false }
    self:EAApplyMetrics(key)
    self:EARefresh(key)
    self:EAApplyPosition(key)
end

function PvPUA:EAIsPlayerDead()
    if type(IsUnitDeadOrReincarnating) == "function" and IsUnitDeadOrReincarnating("player") then
        return true
    end
    if type(IsUnitDead) == "function" and IsUnitDead("player") then
        return true
    end
    return false
end

function PvPUA:EAClearAll()
    for i = 1, #EA_DEFS do
        local key = EA_DEFS[i].key
        if EA_DEFS[i].mode ~= "queue" then
            local a = self.effectAlerts[key]
            if a then a.active = false end
            self:EAStopExpiry(key)
            self:EARefresh(key)
        end
    end
end

--------------------------------------------------
-- Home Keep Queue
--------------------------------------------------
PvPUA.hkQueue = {}

function PvPUA:HKText()
    local q = self.hkQueue
    local parts = {}
    for i = 1, #q do parts[#parts + 1] = q[i].text end
    return table.concat(parts, ", ")
end

function PvPUA:HKStopTick()
    if not self.hkTicking then return end
    self.hkTicking = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_HKQueue")
end

function PvPUA:HKStartTick()
    if self.hkTicking then return end
    self.hkTicking = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_HKQueue", HK_TICK_MS, function()
        local q = PvPUA.hkQueue
        local now = GetGameTimeMilliseconds()
        local changed = false
        for i = #q, 1, -1 do
            if now >= q[i].expires then
                table.remove(q, i)
                changed = true
            end
        end
        if changed then PvPUA:EARefresh(HK_KEY) end
        if #q == 0 then PvPUA:HKStopTick() end
    end)
end

function PvPUA:HKPush(keepId, text)
    if not self.savedVariables then return end
    local q = self.hkQueue
    local expires = GetGameTimeMilliseconds() + ((self.savedVariables.alertLifespan or 10) * 1000)
    for i = 1, #q do
        if q[i].id == keepId then
            q[i].text = text
            q[i].expires = expires
            self:EARefresh(HK_KEY)
            return
        end
    end
    q[#q + 1] = { id = keepId, text = text, expires = expires }
    self:EARefresh(HK_KEY)
    self:HKStartTick()
end

function PvPUA:HKClear()
    local q = self.hkQueue
    for i = #q, 1, -1 do q[i] = nil end
    self:HKStopTick()
    self:EARefresh(HK_KEY)
end

function PvPUA:EARefresh(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end

    local def = EA_DEF_BY_KEY[key]
    if def and def.mode == "queue" then
        local text
        if a.preview then
            text = def.defaultText
        elseif self.savedVariables.alertsEnabled and #self.hkQueue > 0 then
            text = self:HKText()
        end

        if not text or text == "" then
            a.panel:SetHidden(true)
            self:EAStopPulse(key)
            a.label:SetAlpha(1)
            return
        end

        self:EAApplyMetrics(key)
        a.label:SetFont(self:EAFont(key))
        a.label:SetText(text)
        a.label:SetColor(1, 1, 1, 1)
        a.panel:SetHidden(false)

        if v.pulsate then
            self:EAStartPulse(key)
        else
            self:EAStopPulse(key)
            a.label:SetAlpha(1)
        end
        return
    end

    local show = a.preview or (v.enabled and a.active and not self:EAIsPlayerDead())
    if not show then
        a.panel:SetHidden(true)
        self:EAStopPulse(key)
        return
    end

    a.label:SetFont(self:EAFont(key))
    a.label:SetText(v.messageText or "")

    local c = v.textColor
    local r, g, b = 1, 1, 1
    if type(c) == "table" then r, g, b = c.r or 1, c.g or 1, c.b or 1 end
    a.label:SetColor(r, g, b, 1)
    a.panel:SetHidden(false)

    if v.pulsate then self:EAStartPulse(key) else self:EAStopPulse(key) end
end

function PvPUA:EAStartPulse(key)
    local a = self.effectAlerts[key]
    if not a or a.pulsing then return end
    a.pulsing = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_EAPulse_" .. key, 50, function()
        local v = PvPUA:EAVars(key)
        local ac = PvPUA.effectAlerts[key]
        if not v or not ac or ac.panel:IsHidden() then return end
        local t = GetGameTimeSeconds() * (v.pulseSpeed or 3)
        local alpha = 0.45 + (0.55 * math.abs(math.sin(t * math.pi)))
        local def = EA_DEF_BY_KEY[key]
        if def and def.mode == "queue" then
            ac.label:SetAlpha(alpha)
            return
        end
        local c = v.textColor
        local r, g, b = 1, 1, 1
        if type(c) == "table" then r, g, b = c.r or 1, c.g or 1, c.b or 1 end
        ac.label:SetColor(r, g, b, alpha)
    end)
end

function PvPUA:EAStopPulse(key)
    local a = self.effectAlerts[key]
    if not a or not a.pulsing then return end
    a.pulsing = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_EAPulse_" .. key)
    a.label:SetAlpha(1)
end

local function EAOnEffectChanged(_, changeType, _, effectName, unitTag)
    if unitTag ~= "player" then return end
    local key = EA_NAME_LOOKUP[effectName]
    if not key then return end
    local a = PvPUA.effectAlerts[key]
    if not a then return end
    if changeType == EFFECT_RESULT_FADED then
        a.active = false
    else
        a.active = true
    end
    PvPUA:EARefresh(key)
end

function PvPUA:EAStartExpiry(key)
    local a = self.effectAlerts[key]
    if not a or a.expiring then return end
    a.expiring = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_EAExpire_" .. key, 250, function()
        local ac = PvPUA.effectAlerts[key]
        if not ac then return end
        if not ac.active or GetGameTimeMilliseconds() - (ac.lastHit or 0) > EA_DAMAGE_TIMEOUT_MS then
            ac.active = false
            PvPUA:EAStopExpiry(key)
            PvPUA:EARefresh(key)
        end
    end)
end

function PvPUA:EAStopExpiry(key)
    local a = self.effectAlerts[key]
    if not a or not a.expiring then return end
    a.expiring = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_EAExpire_" .. key)
end

local function EAOnCombatEvent(_, _, isError, _, _, _, _, _, _, targetType, hitValue,
                               _, _, _, _, _, abilityId)
    if isError then return end
    if targetType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if not hitValue or hitValue <= 0 then return end
    local key = EA_ID_LOOKUP[abilityId]
    if not key then return end
    local a = PvPUA.effectAlerts[key]
    if not a then return end
    a.lastHit = GetGameTimeMilliseconds()
    if not a.active then
        a.active = true
        PvPUA:EARefresh(key)
        PvPUA:EAStartExpiry(key)
    end
end

function PvPUA:EAApplyCombatListener()
    local wanted = false
    for i = 1, #EA_DEFS do
        if EA_DEFS[i].mode == "damage" and self:EAVars(EA_DEFS[i].key).enabled then
            wanted = true
            break
        end
    end

    if wanted == self.eaCombatRegistered then return end
    self.eaCombatRegistered = wanted

    for id in pairs(EA_ID_LOOKUP) do
        local name = PvPUA.name .. "_DamageAlert_" .. tostring(id)
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        if wanted then
            EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, EAOnCombatEvent)
            if EVENT_MANAGER.AddFilterForEvent then
                pcall(function()
                    EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                        REGISTER_FILTER_ABILITY_ID, id,
                        REGISTER_FILTER_IS_ERROR, false)
                end)
            end
        end
    end

    if not wanted then
        for i = 1, #EA_DEFS do
            if EA_DEFS[i].mode == "damage" then
                local a = self.effectAlerts[EA_DEFS[i].key]
                if a then a.active = false end
                self:EAStopExpiry(EA_DEFS[i].key)
                self:EARefresh(EA_DEFS[i].key)
            end
        end
    end
end

function PvPUA:EAInit()
    for i = 1, #EA_DEFS do
        self:EACreatePanel(EA_DEFS[i].key)
    end
    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_EffectAlert", EVENT_EFFECT_CHANGED, EAOnEffectChanged)
    if EVENT_MANAGER.AddFilterForEvent then
        pcall(function()
            EVENT_MANAGER:AddFilterForEvent(PvPUA.name .. "_EffectAlert", EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG, "player")
        end)
    end
    self.eaCombatRegistered = false
    self:EAApplyCombatListener()
end

function PvPUA:HKBuildSettings(def)
    local key = def.key
    local screenW, screenH = ScreenBounds()
    local halfW, halfH = math.ceil(screenW / 10) * 5, math.ceil(screenH / 10) * 5
    return { type = "submenu", name = def.label, icon = def.icon, options = {
        { type = "toggle", name = "Preview",
          getFunc = function() return self.effectAlerts[key] and self.effectAlerts[key].preview or false end,
          setFunc = function(v)
              if self.effectAlerts[key] then self.effectAlerts[key].preview = v end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Horizontal Position", min = -halfW, max = halfW, step = 5,
          getFunc = function() return self:EAVars(key).posX end,
          setFunc = function(v) self:EAVars(key).posX = v; self:EAApplyPosition(key) end },
        { type = "slider", name = "Vertical Position", min = -halfH, max = halfH, step = 5,
          getFunc = function() return self:EAVars(key).posY end,
          setFunc = function(v) self:EAVars(key).posY = v; self:EAApplyPosition(key) end },


        { type = "toggle", name = "Enabled", preset = "YES_NO",
          tooltip = "Shows an alert when a home keep comes under attack.",
          default = PvPUA.defaults.alertsEnabled,
          getFunc = function() return self.savedVariables.alertsEnabled end,
          setFunc = function(v)
              self.savedVariables.alertsEnabled = v
              if not v then self:HKClear() end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Duration", min = 5, max = 30, step = 1,
          tooltip = "How long each keep stays on screen (seconds).",
          default = PvPUA.defaults.alertLifespan,
          getFunc = function() return self.savedVariables.alertLifespan end,
          setFunc = function(v) self.savedVariables.alertLifespan = v end },


        { type = "slider", name = "Size", min = 25, max = 90, step = 1,
          getFunc = function() return self:EAVars(key).fontSize end,
          setFunc = function(v) self:EAVars(key).fontSize = v; self:EARefresh(key) end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          getFunc = function() return self:EAVars(key).font end,
          setFunc = function(v) self:EAVars(key).font = v; self:EARefresh(key) end },
        { type = "toggle", name = "Pulsate", preset = "YES_NO",
          getFunc = function() return self:EAVars(key).pulsate end,
          setFunc = function(v) self:EAVars(key).pulsate = v; self:EARefresh(key) end },
        { type = "slider", name = "Pulse Speed", min = 1, max = 10, step = 1,
          disabled = function() return not self:EAVars(key).pulsate end,
          getFunc = function() return self:EAVars(key).pulseSpeed end,
          setFunc = function(v) self:EAVars(key).pulseSpeed = v; self:EARefresh(key) end },
    } }
end

function PvPUA:EABuildSettings(def)
    local key = def.key
    local screenW, screenH = ScreenBounds()
    local halfW, halfH = math.ceil(screenW / 10) * 5, math.ceil(screenH / 10) * 5
    return { type = "submenu", name = def.label, icon = def.icon, options = {
        { type = "toggle", name = "Preview",
          getFunc = function() return self.effectAlerts[key] and self.effectAlerts[key].preview or false end,
          setFunc = function(v)
              if self.effectAlerts[key] then self.effectAlerts[key].preview = v end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Horizontal Position", min = -halfW, max = halfW, step = 5,
          getFunc = function() return self:EAVars(key).posX end,
          setFunc = function(v) self:EAVars(key).posX = v; self:EAApplyPosition(key) end },
        { type = "slider", name = "Vertical Position", min = -halfH, max = halfH, step = 5,
          getFunc = function() return self:EAVars(key).posY end,
          setFunc = function(v) self:EAVars(key).posY = v; self:EAApplyPosition(key) end },


        { type = "toggle", name = "Enabled", preset = "YES_NO",
          getFunc = function() return self:EAVars(key).enabled end,
          setFunc = function(v)
              self:EAVars(key).enabled = v
              self:EAApplyCombatListener()
              self:EARefresh(key)
          end },


        { type = "editbox", name = "Text",
          getFunc = function() return self:EAVars(key).messageText end,
          setFunc = function(v)
              if v == nil or v == "" then v = def.defaultText end
              self:EAVars(key).messageText = v
              self:EARefresh(key)
          end },
        { type = "slider", name = "Size", min = 25, max = 90, step = 1,
          getFunc = function() return self:EAVars(key).fontSize end,
          setFunc = function(v) self:EAVars(key).fontSize = v; self:EARefresh(key) end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          getFunc = function() return self:EAVars(key).font end,
          setFunc = function(v) self:EAVars(key).font = v; self:EARefresh(key) end },
        { type = "colorpicker", name = RainbowText("Color"),
          default = def.defaultColor,
          getFunc = function()
              local c = self:EAVars(key).textColor or def.defaultColor
              return c.r, c.g, c.b, 1
          end,
          setFunc = function(r, g, b)
              self:EAVars(key).textColor = { r = r, g = g, b = b, a = 1 }
              self:EARefresh(key)
          end },
        { type = "toggle", name = "Pulsate", preset = "YES_NO",
          getFunc = function() return self:EAVars(key).pulsate end,
          setFunc = function(v) self:EAVars(key).pulsate = v; self:EARefresh(key) end },
        { type = "slider", name = "Pulse Speed", min = 1, max = 10, step = 1,
          disabled = function() return not self:EAVars(key).pulsate end,
          getFunc = function() return self:EAVars(key).pulseSpeed end,
          setFunc = function(v) self:EAVars(key).pulseSpeed = v; self:EARefresh(key) end },
    } }
end

local P = {}
PvPUA.Potion = P

P.previewMode = false

local POTION_DEFAULTS = {
    potionEnabled     = false,
    potionText        = "USE POTION NOW!",
    potionPosX        = 0,
    potionPosY        = -220,
    potionFontSize    = 45,
    potionFont        = "EsoUI/Common/Fonts/univers67.otf",
    potionColor       = { r = 1, g = 0.2, b = 0.2, a = 1 },
    potionPulsate     = false,
    potionPulseSpeed  = 3,
    potionAlwaysOn    = false,
    potionHealthGate  = false,
    potionHealthPct   = 60,
    potionMagickaGate = false,
    potionMagickaPct  = 60,
    potionStaminaGate = false,
    potionStaminaPct  = 60,
}

for key, value in pairs(POTION_DEFAULTS) do
    if PvPUA.defaults[key] == nil then
        PvPUA.defaults[key] = value
    end
end

local potionInCombat       = false
local potionVisible      = false
local potionIsReady    = true
local potionCooldownEnds = 0

local POTION_GATES = {
    { label = "health",  enable = "potionHealthGate",  threshold = "potionHealthPct",
      consts = { "COMBAT_MECHANIC_FLAGS_HEALTH",  "POWERTYPE_HEALTH"  } },
    { label = "magicka", enable = "potionMagickaGate", threshold = "potionMagickaPct",
      consts = { "COMBAT_MECHANIC_FLAGS_MAGICKA", "POWERTYPE_MAGICKA" } },
    { label = "stamina", enable = "potionStaminaGate", threshold = "potionStaminaPct",
      consts = { "COMBAT_MECHANIC_FLAGS_STAMINA", "POWERTYPE_STAMINA" } },
}

local potionPowerPct = {}

local POTION_FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
}

function P:SV()
    return PvPUA.savedVariables
end

function P:GetFont()
    local sv = self:SV()
    return string.format("%s|%d|%s", sv.potionFont, sv.potionFontSize, "outline")
end

function P:InvalidateFont()
    if self.label then
        self.label:SetFont(self:GetFont())
    end
    self:RefreshDisplay()
end

function P:ApplyPosition()
    if not self.panel then return end
    local sv = self:SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(CENTER, GuiRoot, CENTER, sv.potionPosX, sv.potionPosY)
end

function P:CreatePanel()
    if self.panel then return end

    self.panel = WINDOW_MANAGER:CreateTopLevelWindow("PvPUA_PotionPanel")
    self.panel:SetClampedToScreen(true)
    self.panel:SetDrawLayer(DL_OVERLAY)
    self.panel:SetDrawTier(DT_HIGH)
    self.panel:SetDimensions(1200, 120)
    self.panel:SetHidden(true)
    self:ApplyPosition()

    local label = WINDOW_MANAGER:CreateControl("PvPUA_PotionLabel", self.panel, CT_LABEL)
    label:SetAnchor(CENTER, self.panel, CENTER, 0, 0)
    label:SetFont(self:GetFont())
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.label = label
end

function P:OnPotionUsed(_, sound)
    if sound ~= ITEM_SOUND_CATEGORY_POTION then return end

    potionIsReady = false
    self:RefreshDisplay()

    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_PotionDrink", 10, function()
        local slotIndex = GetCurrentQuickslot()
        local remain, duration, global = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)

        if not global then
            EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_PotionDrink")

            remain = remain or 0
            potionCooldownEnds = GetGameTimeMilliseconds() + remain
        end
    end)
end

function P:IsPotionReady()
    if potionIsReady then return true end

    if potionCooldownEnds > 0 and GetGameTimeMilliseconds() >= potionCooldownEnds then
        potionIsReady    = true
        potionCooldownEnds = 0
        return true
    end

    return false
end

function P:ResolvePowerTypes()
    for _, gate in ipairs(POTION_GATES) do
        gate.power = nil

        for _, name in ipairs(gate.consts) do
            local value = _G[name]
            if type(value) == "number" then
                gate.power = value
                break
            end
        end

        if gate.power then
            potionPowerPct[gate.power] = 100
        end
    end
end

function P:RefreshPowerPercents()
    for _, gate in ipairs(POTION_GATES) do
        if gate.power then
            local current, maxVal, effectiveMax = GetUnitPower("player", gate.power)
            local capacity = effectiveMax or maxVal

            if current and capacity and capacity > 0 then
                potionPowerPct[gate.power] = (current / capacity) * 100
            end
        end
    end
end

function P.OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax)
    if unitTag ~= "player" then return end
    if powerType == nil or potionPowerPct[powerType] == nil then return end
    if not powerMax or powerMax <= 0 then return end

    potionPowerPct[powerType] = (powerValue / powerMax) * 100

    P:RefreshDisplay()
end

function P:ResourceGatesPassed()
    local sv = self:SV()

    if sv.potionAlwaysOn then return true end

    for _, gate in ipairs(POTION_GATES) do
        if sv[gate.enable] then
            local pct = potionPowerPct[gate.power] or 100
            if pct <= sv[gate.threshold] then
                return true
            end
        end
    end

    return false
end

function P:IsPlayerDead()
    if type(IsUnitDead) == "function" and IsUnitDead("player") then
        return true
    end

    if type(IsUnitReincarnating) == "function" and IsUnitReincarnating("player") then
        return true
    end

    return false
end

function P:OnPlayerDead()
    potionInCombat  = false
    potionVisible = false
    if self.panel then self.panel:SetHidden(true) end
    self:RefreshDisplay()
end

function P:OnPlayerAlive()
    potionInCombat = IsUnitInCombat("player")
    self:RefreshPowerPercents()
    self:RefreshDisplay()
end

function P:ShouldShow()
    if self.previewMode then return true end
    if not self:SV().potionEnabled then return false end
    if self:IsPlayerDead() then return false end
    if not potionInCombat then return false end
    if not self:IsPotionReady() then return false end
    if not self:ResourceGatesPassed() then return false end

    return true
end

function P:RefreshDisplay()
    if not self.panel then return end

    local sv = self:SV()
    local show = self:ShouldShow()

    if not show then
        if potionVisible then
            potionVisible = false
        end
        self.panel:SetHidden(true)
        return
    end

    if not potionVisible then
        potionVisible = true
    end

    self.label:SetText(sv.potionText)

    local c = sv.potionColor
    local r, g, b = 1, 1, 1
    if type(c) == "table" then
        r, g, b = c.r or 1, c.g or 1, c.b or 1
    end

    local alpha = 1
    if sv.potionPulsate then
        local t = GetGameTimeSeconds() * sv.potionPulseSpeed
        alpha = 0.45 + (0.55 * math.abs(math.sin(t * math.pi)))
    end

    self.label:SetColor(r, g, b, alpha)
    self.panel:SetHidden(false)
end

function P:OnCombatState(eventCode, combatState)
    potionInCombat = combatState

    if not potionInCombat then
        potionVisible = false
        if self.panel then self.panel:SetHidden(true) end
    else
        self:IsPotionReady()
    end

    self:RefreshDisplay()
end

function P:InitializeSceneHiding()
    local function OnSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWING then
            if P.panel then P.panel:SetHidden(true) end
        elseif newState == SCENE_HIDDEN then
            P:RefreshDisplay()
        end
    end

    local scenes = { "worldMap", "gameMenuInGame", "inventory", "gamepad_inventory_root" }
    for _, sceneName in ipairs(scenes) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", OnSceneStateChange)
        end
    end
end

function P:GetOptions()
    return {
        {
            type    = "toggle",
            name    = "Preview",
            getFunc = function() return P.previewMode end,
            setFunc = function(val)
                P.previewMode = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "slider",
            name    = "Horizontal Position",
            min     = -1200, max = 1200, step = 5,
            default = POTION_DEFAULTS.potionPosX,
            getFunc = function() return P:SV().potionPosX end,
            setFunc = function(val)
                P:SV().potionPosX = val
                P:ApplyPosition()
            end,
        },
        {
            type    = "slider",
            name    = "Vertical Position",
            min     = -800, max = 800, step = 5,
            default = POTION_DEFAULTS.potionPosY,
            getFunc = function() return P:SV().potionPosY end,
            setFunc = function(val)
                P:SV().potionPosY = val
                P:ApplyPosition()
            end,
        },
        {
            type    = "toggle",
            name    = "Enabled",
            preset = "YES_NO",
            default = POTION_DEFAULTS.potionEnabled,
            getFunc = function() return P:SV().potionEnabled end,
            setFunc = function(val)
                P:SV().potionEnabled = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "toggle",
            name    = "Always On",
            preset = "YES_NO",
            tooltip = "Show the alert whenever you are in combat with a potion ready, ignoring the resource options below.",
            default = POTION_DEFAULTS.potionAlwaysOn,
            getFunc = function() return P:SV().potionAlwaysOn end,
            setFunc = function(val)
                P:SV().potionAlwaysOn = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c" .. EP_HEX .. "Health|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your health has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionHealthGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionHealthGate end,
            setFunc  = function(val)
                P:SV().potionHealthGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionHealthPct,
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionHealthGate
            end,
            getFunc  = function() return P:SV().potionHealthPct end,
            setFunc  = function(val)
                P:SV().potionHealthPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c" .. DC_HEX .. "Magicka|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your magicka has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionMagickaGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionMagickaGate end,
            setFunc  = function(val)
                P:SV().potionMagickaGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionMagickaPct,
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionMagickaGate
            end,
            getFunc  = function() return P:SV().potionMagickaPct end,
            setFunc  = function(val)
                P:SV().potionMagickaPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c00CC44Stamina|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your stamina has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionStaminaGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionStaminaGate end,
            setFunc  = function(val)
                P:SV().potionStaminaGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionStaminaPct,
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionStaminaGate
            end,
            getFunc  = function() return P:SV().potionStaminaPct end,
            setFunc  = function(val)
                P:SV().potionStaminaPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "editbox",
            name    = "Text",
            getFunc = function() return P:SV().potionText end,
            setFunc = function(val)
                if val == nil or val == "" then val = "USE POTION NOW!" end
                P:SV().potionText = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "slider",
            name    = "Size",
            min     = 25, max = 90, step = 1,
            default = POTION_DEFAULTS.potionFontSize,
            getFunc = function() return P:SV().potionFontSize end,
            setFunc = function(val)
                P:SV().potionFontSize = val
                P:InvalidateFont()
            end,
        },
        {
            type    = "dropdown",
            name    = "Font",
            choices = POTION_FONT_CHOICES,
            default = POTION_DEFAULTS.potionFont,
            getFunc = function() return P:SV().potionFont end,
            setFunc = function(val)
                P:SV().potionFont = val
                P:InvalidateFont()
            end,
        },
        {
            type    = "colorpicker",
            name    = RainbowText("Color"),
            default = POTION_DEFAULTS.potionColor,
            getFunc = function()
                local c = P:SV().potionColor
                if type(c) == "table" then
                    return c.r or 1, c.g or 1, c.b or 1, 1
                end
                return 1, 1, 1, 1
            end,
            setFunc = function(r, g, b, a)
                P:SV().potionColor = { r = r, g = g, b = b, a = a }
                P:RefreshDisplay()
            end,
        },
        {
            type    = "toggle",
            name    = "Pulsate",
            preset = "YES_NO",
            default = POTION_DEFAULTS.potionPulsate,
            getFunc = function() return P:SV().potionPulsate end,
            setFunc = function(val)
                P:SV().potionPulsate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Pulse Speed",
            min      = 1, max = 10, step = 1,
            default  = POTION_DEFAULTS.potionPulseSpeed,
            disabled = function() return not P:SV().potionPulsate end,
            getFunc  = function() return P:SV().potionPulseSpeed end,
            setFunc  = function(val) P:SV().potionPulseSpeed = val end,
        },
    }
end

function P:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:ResolvePowerTypes()
    self:RefreshPowerPercents()
    self:CreatePanel()
    self:InitializeSceneHiding()

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionUsed",
        EVENT_INVENTORY_ITEM_USED,
        function(...) P:OnPotionUsed(...) end
    )

    if EVENT_POWER_UPDATE ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionPower",
            EVENT_POWER_UPDATE,
            P.OnPowerUpdate
        )

        EVENT_MANAGER:AddFilterForEvent(
            PvPUA.name .. "_PotionPower",
            EVENT_POWER_UPDATE,
            REGISTER_FILTER_UNIT_TAG, "player"
        )
    end

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionCombat",
        EVENT_PLAYER_COMBAT_STATE,
        function(...) P:OnCombatState(...) end
    )

    if EVENT_PLAYER_DEAD ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionDead",
            EVENT_PLAYER_DEAD,
            function() P:OnPlayerDead() end
        )
    end

    if EVENT_PLAYER_ALIVE ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionAlive",
            EVENT_PLAYER_ALIVE,
            function() P:OnPlayerAlive() end
        )
    end

    EVENT_MANAGER:RegisterForUpdate(
        PvPUA.name .. "_PotionTick",
        100,
        function() P:RefreshDisplay() end
    )

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            potionInCombat = IsUnitInCombat("player")
            P:RefreshDisplay()
        end
    )
end

--------------------------------------------------
-- PvP Ranks
--------------------------------------------------
local R = {}
PvPUA.Ranks = R

local RANKS_MAX = 50
local RANKS_ICON_SIZE = 35
local RANKS_SKILL_ICON_SIZE = 32
local RANKS_MAX_SKILL_RANK = 10

function R:Data()
    if self.data then return self.data end
    local gender = GetUnitGender("player")
    local data = {}
    local points = 0
    for rank = 0, RANKS_MAX do
        local _, _, startsAt, nextRankAt = GetAvARankProgress(points)
        local endsAt = startsAt ~= nextRankAt and nextRankAt - 1 or nil
        points = nextRankAt + 1
        data[rank] = {
            name = zo_strformat(SI_STAT_RANK_NAME_FORMAT, GetAvARankName(gender, rank)),
            icon = zo_iconFormatInheritColor(GetAvARankIcon(rank), RANKS_ICON_SIZE, RANKS_ICON_SIZE),
            startsAt = startsAt,
            endsAt = endsAt,
        }
    end
    self.data = data
    return data
end

function R:Label(rank)
    local entry = self:Data()[rank]
    if not entry then return "" end

    local current = GetUnitAvARank("player")
    local alliance = GetUnitAlliance("player")
    if current ~= self.lastRank or alliance ~= self.lastAlliance then
        self.lastRank = current
        self.lastAlliance = alliance
        local data = self:Data()
        for i = 0, RANKS_MAX do
            data[i].label = nil
        end
    end

    if not entry.label then
        local text = rank .. ")  " .. entry.icon .. " " .. entry.name
        if rank == current then
            text = "|c" .. GetAllianceColor(alliance):ToHex() .. text .. "|r"
        end
        entry.label = text
    end

    return entry.label
end

function R:LineRankSpread(lineIndex)
    local lineData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillLineDataByIndices
                 and SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(SKILL_TYPE_AVA, lineIndex)
    if not (lineData and lineData.GetNumSkills) then return 0 end
    local seen, distinct = {}, 0
    for i = 1, lineData:GetNumSkills() do
        local skillData = lineData:GetSkillDataByIndex(i)
        local lineRank = skillData and skillData.GetLineRankNeededToPurchase
                     and skillData:GetLineRankNeededToPurchase() or 0
        if lineRank > 0 and not seen[lineRank] then
            seen[lineRank] = true
            distinct = distinct + 1
        end
    end
    return distinct
end

function R:SkillLines()
    if self.lines then return self.lines end
    local lines = {}
    local count = GetNumSkillLines and GetNumSkillLines(SKILL_TYPE_AVA) or 0
    for lineIndex = 1, count do
        if GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lineIndex, 2)
           and self:LineRankSpread(lineIndex) >= 2 then
            lines[#lines + 1] = lineIndex
        end
    end
    self.lines = lines
    return lines
end

function R:Unlocks()
    if self.unlocks then return self.unlocks end

    local lines = self:SkillLines()
    if #lines == 0 then return nil end

    local byLineRank = {}
    for lineRank = 1, RANKS_MAX_SKILL_RANK do
        local startsAt
        if lineRank == RANKS_MAX_SKILL_RANK then
            local _, nextExtent = GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lines[1], lineRank - 1)
            startsAt = nextExtent
        else
            startsAt = GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lines[1], lineRank)
        end
        if not startsAt then return nil end
        byLineRank[lineRank] = { startsAt = startsAt, skills = {} }
    end

    for _, lineIndex in ipairs(lines) do
        local lineData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillLineDataByIndices
                     and SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(SKILL_TYPE_AVA, lineIndex)
        if lineData and lineData.GetNumSkills then
            for i = 1, lineData:GetNumSkills() do
                local skillData = lineData:GetSkillDataByIndex(i)
                if skillData then
                    local lineRank = skillData.GetLineRankNeededToPurchase
                                 and skillData:GetLineRankNeededToPurchase() or 0
                    if byLineRank[lineRank] then
                        local prog = skillData.GetCurrentProgressionData and skillData:GetCurrentProgressionData()
                        local name = prog and prog.GetFormattedName and prog:GetFormattedName() or ""
                        local icon = prog and prog.GetIcon and prog:GetIcon() or ""
                        if name ~= "" then
                            table.insert(byLineRank[lineRank].skills, { name = name, icon = icon })
                        end
                    end
                end
            end
        elseif GetNumSkillAbilities and GetSkillAbilityLineRankNeededToUnlock then
            for i = 1, GetNumSkillAbilities(SKILL_TYPE_AVA, lineIndex) do
                local lineRank = GetSkillAbilityLineRankNeededToUnlock(SKILL_TYPE_AVA, lineIndex, i) or 0
                if byLineRank[lineRank] and GetSkillAbilityInfo then
                    local name, icon = GetSkillAbilityInfo(SKILL_TYPE_AVA, lineIndex, i)
                    table.insert(byLineRank[lineRank].skills, { name = name or "", icon = icon or "" })
                end
            end
        end
    end

    self.unlocks = byLineRank
    return self.unlocks
end

function R:UnlocksFor(startsAt, endsAt)
    local byLineRank = self:Unlocks()
    if not byLineRank then return nil end
    for lineRank = 1, RANKS_MAX_SKILL_RANK do
        local entry = byLineRank[lineRank]
        if entry and entry.startsAt >= startsAt and (not endsAt or entry.startsAt <= endsAt) then
            return entry.skills
        end
    end
    return nil
end

function R:APIcon()
    if not self.apIcon then
        if ZO_Currency_GetPlatformFormattedCurrencyIcon and CURT_ALLIANCE_POINTS then
            self.apIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(CURT_ALLIANCE_POINTS, nil, true)
        end
        if not self.apIcon or self.apIcon == "" then
            self.apIcon = "AP"
        end
    end
    return self.apIcon
end

function R:Tooltip(rank)
    local entry = self:Data()[rank]
    if not entry then return "" end
    if not entry.tip then
        local ap = self:APIcon()
        local text = "Starts at " .. ZO_CommaDelimitNumber(entry.startsAt) .. " " .. ap
        if entry.endsAt then
            text = text .. "\nEnds at " .. ZO_CommaDelimitNumber(entry.endsAt) .. " " .. ap
        end

        local ready = self:Unlocks() ~= nil
        local skills = self:UnlocksFor(entry.startsAt, entry.endsAt)
        if skills and #skills > 0 then
            text = text .. "\n"
            for i = 1, #skills do
                local skill = skills[i]
                local mark = skill.icon ~= "" and zo_iconFormat(skill.icon, RANKS_SKILL_ICON_SIZE, RANKS_SKILL_ICON_SIZE) .. " " or ""
                text = text .. "\n" .. mark .. skill.name
            end
        end

        if not ready then return text end
        entry.tip = text
    end
    return entry.tip
end

function R.Jump()
    local list = LibConsoleMenu and LibConsoleMenu.list
    if not list then return end
    local index = GetUnitAvARank("player") + 1
    if list.SetSelectedIndexWithoutAnimation then
        list:SetSelectedIndexWithoutAnimation(index)
    elseif list.SetSelectedIndex then
        list:SetSelectedIndex(index)
    end
end


function R:GetOptions()
    local out = {}
    for rank = 0, RANKS_MAX do
        out[#out + 1] = {
            type = "button",
            name = function() return R:Label(rank) end,
            tooltip = function() return R:Tooltip(rank) end,
            func = R.Jump,
        }
    end
    return out
end

function R:PatchKeybind(menu)
    if not (menu and menu.controls) then return end
    for i = 1, #menu.controls do
        local control = menu.controls[i]
        if control and control.clickHandler == R.Jump then
            control.buttonText = "My Rank"
        end
    end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
PVPUA_ADDON_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_multiplayer.dds"

PvPUA.AIGuildChoices = {}

function PvPUA:AIRefreshGuildChoices()
    local choices = PvPUA.AIGuildChoices
    for i = #choices, 1, -1 do choices[i] = nil end
    for i = 1, 5 do
        local guildId = GetGuildId(i)
        if guildId and guildId > 0 then
            local gName = GetGuildName(guildId)
            if gName and gName ~= "" then
                choices[#choices + 1] = gName
            end
        end
    end

    if not PvPUA.charVariables.aiGuildMigrated then
        PvPUA.charVariables.aiGuildToggles = PvPUA.charVariables.aiGuildToggles or {}
        local guildDataReady = false
        for i = 1, 5 do
            local id = GetGuildId(i)
            if id and id > 0 then guildDataReady = true break end
        end
        if guildDataReady then
            if PvPUA.charVariables.aiGuild and PvPUA.charVariables.aiGuildName ~= "" then
                for i = 1, 5 do
                    local guildId = GetGuildId(i)
                    if guildId and guildId > 0
                       and GetGuildName(guildId) == PvPUA.charVariables.aiGuildName then
                        PvPUA.charVariables.aiGuildToggles[i] = true
                        break
                    end
                end
            end
            PvPUA.charVariables.aiGuildMigrated = true
        end
    end

    local sel2 = PvPUA.charVariables.aiGuildName
    if sel2 and sel2 ~= "" then
        local found2 = false
        for _, n in ipairs(PvPUA.AIGuildChoices) do if n == sel2 then found2 = true break end end
        if not found2 then PvPUA.charVariables.aiGuildName = "" end
    end
end

local function CopyDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            target[k] = {}
            CopyDefaults(target[k], v)
        else
            target[k] = v
        end
    end
end

function PvPUA:ResetAllSettings()
    if self.savedVariables then
        for k in pairs(self.savedVariables) do
            if k ~= "version" and k ~= "lastSeenVersion" then self.savedVariables[k] = nil end
        end
        CopyDefaults(self.savedVariables, PvPUA.defaults)
    end
    if self.charVariables then
        for k in pairs(self.charVariables) do
            if k ~= "version" then self.charVariables[k] = nil end
        end
        CopyDefaults(self.charVariables, PvPUA.charDefaults)
    end
    self:InvalidateFontCache()
    self:ApplyPosition()
    self:ApplyScale()
    self:RefreshBackdropColors()
    self:UpdateHUDScenes()
    self:HKClear()
    for i = 1, #EA_DEFS do
        self:EAApplyMetrics(EA_DEFS[i].key)
        self:EAApplyPosition(EA_DEFS[i].key)
        self:EARefresh(EA_DEFS[i].key)
    end
    self:EAApplyCombatListener()
    pcall(PI.OnMyStyleChanged)
end

function PvPUA:AIChannelChoices()
    local choices = {
        { name = ColorText("Whisper", 0.1725, 1, 0.9725),   value = "whisper" },
        { name = ColorText("Say Chat", 1, 1, 1),            value = "say" },
        { name = ColorText("Zone Chat", 0.7725, 0.7608, 0.6196), value = "zone" },
    }
    for i = 1, 5 do
        local id = GetGuildId(i)
        local label
        if id and id > 0 then
            local c = GetGuildAllianceColor(id)
            label = ColorText("Guild: " .. GetGuildName(id), c.r, c.g, c.b)
        else
            label = "Guild " .. i
        end
        choices[#choices + 1] = { name = label, value = "guild" .. i }
    end
    return choices
end

PVPUA_MENU_TITLE_COLORED = "|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r |cFF8800UA!|r"
PVPUA_TOOLTIP_AUTHOR_COLORED = "user|c" .. DC_HEX .. "5|r|c" .. AD_HEX .. "6|r|c" .. EP_HEX .. "2|r"

local function PvPUA_PaintMenuEntry(entry)
    if not entry then return false end
    local data = entry.data
    local addon = data and data.addon
    if not addon or addon.menuId ~= "PvPUA" then return false end
    if entry.text == PVPUA_MENU_TITLE_COLORED then return false end

    entry.text = PVPUA_MENU_TITLE_COLORED
    if entry.SetText then entry:SetText(PVPUA_MENU_TITLE_COLORED) end
    addon.displayTitle = PVPUA_MENU_TITLE_COLORED
    return true
end

local function PvPUA_ApplyMenuEntryColor()
    if not ZO_MENU_ENTRIES then return false end

    local changed = false
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        local subMenu = entry.subMenu or (entry.data and entry.data.subMenu)
        if subMenu then
            for _, child in ipairs(subMenu) do
                changed = PvPUA_PaintMenuEntry(child) or changed
            end
        end
    end

    if changed and MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end
    return changed
end

local function PvPUA_HookTooltipColor()
    if type(LibConsoleMenu.GetAddonManifestMeta) ~= "function" or LibConsoleMenu.pvpuaTooltipColorHook then
        return
    end

    LibConsoleMenu.pvpuaTooltipColorHook = LibConsoleMenu.GetAddonManifestMeta
    LibConsoleMenu.GetAddonManifestMeta = function(addon, ...)
        local meta = LibConsoleMenu.pvpuaTooltipColorHook(addon, ...)
        if meta and type(addon) == "table" and addon.menuId == "PvPUA" then
            if meta.title ~= "" then
                meta.title = PVPUA_MENU_TITLE_COLORED
            end
            if meta.author ~= "" then
                meta.author = PVPUA_TOOLTIP_AUTHOR_COLORED
            end
        end
        return meta
    end
end

local function PvPUA_HookMenuEntryColor()
    PvPUA_HookTooltipColor()

    if type(LibConsoleMenu.InjectIntoAddonsMenu) == "function" and not LibConsoleMenu.pvpuaTitleColorHook then
        LibConsoleMenu.pvpuaTitleColorHook = LibConsoleMenu.InjectIntoAddonsMenu
        LibConsoleMenu.InjectIntoAddonsMenu = function(libSelf, ...)
            local result = LibConsoleMenu.pvpuaTitleColorHook(libSelf, ...)
            pcall(PvPUA_ApplyMenuEntryColor)
            return result
        end
    end

    if MAIN_MENU_GAMEPAD_SCENE and not PvPUA.menuTitleColorSceneHooked then
        PvPUA.menuTitleColorSceneHooked = true
        MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                pcall(PvPUA_ApplyMenuEntryColor)
            end
        end)
    end
end

function PvPUA:HasConsoleMenu()
    return type(LibConsoleMenu) == "table"
       and type(LibConsoleMenu.CreateAddonMenu) == "function"
end

function PvPUA:CreateSettings()
    if not self:HasConsoleMenu() then
        PvPUA.settingsUnavailable = true
        return
    end
    self:AIRefreshGuildChoices()

    local screenW, screenH = ScreenBounds()
    local myIconDefault, mySizeDefault, myHeightDefault, myOpacityDefault = PI.GetMyDefaults()
    local myCategoryDefault = PI.GetIconCategory(myIconDefault)
    PI.BuildPickerChoices(myCategoryDefault)
    local myPickerDefault = PI.indexToPicker[myIconDefault] or 1

    local addonCategory = MOD_BROWSER_CATEGORY_TYPE_PVP
    if type(LibConsoleMenu.ResolveAddonMenuIcon) == "function" then
        if not LibConsoleMenu.pvpuaIconHook then
            LibConsoleMenu.pvpuaIconHook = LibConsoleMenu.ResolveAddonMenuIcon
            LibConsoleMenu.ResolveAddonMenuIcon = function(category)
                if category == PVPUA_ADDON_ICON then return PVPUA_ADDON_ICON end
                return LibConsoleMenu.pvpuaIconHook(category)
            end
        end
        local ok, resolved = pcall(LibConsoleMenu.ResolveAddonMenuIcon, PVPUA_ADDON_ICON)
        if ok and resolved == PVPUA_ADDON_ICON then
            addonCategory = PVPUA_ADDON_ICON
        end
    end

    local menu = LibConsoleMenu:CreateAddonMenu("PvPUA", {
        title          = "PvP UA!",
        author         = "user562",
        version        = "5.1",
        category       = addonCategory,
        enableDefaults = true,
        enableReset    = true,
        childrenAlign  = "center",
        resetFunc      = function() PvPUA:ResetAllSettings() end,
    })
    if not menu then return end

    PvPUA_HookMenuEntryColor()

    menu:AddOptions({
        { type = "submenu",
          name = "|c" .. DC_HEX .. "Appearance|r",
          icon = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_uiGraphics.dds",
          options = {
        { type = "checklist",
          name = "Show List",
          noSelectionText = "None",
          choices = {
              { name = "In Menus",      value = "showListInMenus" },
              { name = "While Sieging", value = "showListWhileSieging" },
              { name = "While Dead",    value = "showListWhileDead" },
          },
          default = { "showListWhileDead" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.showListInMenus then sel[#sel + 1] = "showListInMenus" end
              if sv.showListWhileSieging then sel[#sel + 1] = "showListWhileSieging" end
              if sv.showListWhileDead then sel[#sel + 1] = "showListWhileDead" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local sv = PvPUA.savedVariables
              sv.showListInMenus = on.showListInMenus == true
              sv.showListWhileSieging = on.showListWhileSieging == true
              sv.showListWhileDead = on.showListWhileDead == true
              PvPUA:UpdateHUDScenes()
          end },
        { type = "slider", name = "Size", min = 80, max = 150, step = 5,
          default = 100,
          getFunc = function() return math.floor((self.savedVariables.uiScale or 1.0) * 100 + 0.5) end,
          setFunc = function(v) self.savedVariables.uiScale = v / 100; self:ApplyScale() end },
        { type = "slider", name = "Horizontal Position", min = 0, max = screenW, step = 5,
          default = PvPUA.defaults.posX,
          getFunc = function() return self.savedVariables.posX end,
          setFunc = function(v) self.savedVariables.posX = v; self:ApplyPosition() end },
        { type = "slider", name = "Vertical Position", min = 0, max = screenH, step = 5,
          default = PvPUA.defaults.posY,
          getFunc = function() return self.savedVariables.posY end,
          setFunc = function(v) self.savedVariables.posY = v; self:ApplyPosition() end },
        { type = "checklist",
          name = "Show in List",
          noSelectionText = "None",
          choices = {
              { name = "Milegates", value = "showMilegates" },
              { name = "Bridges", value = "showBridges" },
              { name = "Towns", value = "showTowns" },
              { name = "Resources", value = "showResources" },
              { name = "Scroll Carriers", value = "showScrollCarriers" },
              { name = "Volendrung", value = "showVolendrungRow" },
          },
          default = { "showMilegates", "showBridges", "showTowns", "showResources", "showScrollCarriers", "showVolendrungRow" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.showMilegates then sel[#sel + 1] = "showMilegates" end
              if sv.showBridges then sel[#sel + 1] = "showBridges" end
              if sv.showTowns then sel[#sel + 1] = "showTowns" end
              if sv.showResources then sel[#sel + 1] = "showResources" end
              if sv.showScrollCarriers then sel[#sel + 1] = "showScrollCarriers" end
              if sv.showVolendrungRow then sel[#sel + 1] = "showVolendrungRow" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local sv = PvPUA.savedVariables
              sv.showMilegates = on.showMilegates == true
              sv.showBridges = on.showBridges == true
              sv.showTowns = on.showTowns == true
              sv.showResources = on.showResources == true
              sv.showScrollCarriers = on.showScrollCarriers == true
              sv.showVolendrungRow = on.showVolendrungRow == true
          end },
        { type = "dropdown", name = "Cap List At",
          choices = PvPUA.capChoices,
          default = 0,
          getFunc = function() return self.savedVariables.listCap end,
          setFunc = function(val) self.savedVariables.listCap = val end },
        { type = "dropdown", name = "Rank Display",
          choices = { "AP Progress Bar", "Veterancy Progress Bar" },
          getFunc = function()
              return (self.savedVariables.barMode == "Veterancy")
                  and "Veterancy Progress Bar" or "AP Progress Bar"
          end,
          setFunc = function(val)
              self.savedVariables.barMode = (val == "Veterancy Progress Bar") and "Veterancy" or "AP"
              self:RefreshRankLabel()
          end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          default = PvPUA.defaults.font,
          getFunc = function() return self.savedVariables.font end,
          setFunc = function(val) self.savedVariables.font = val; self:InvalidateFontCache() end,
        },
        { type = "colorpicker", name = RainbowText("Timer Color"),
          tooltip = "Changes the UA! timer color.",
          default = { r = 1, g = 1, b = 1, a = 1 },
          getFunc = function()
              local c = self.savedVariables.timerColor
              if type(c) == "table" then
                  return c.r or 1, c.g or 1, c.b or 1, 1
              end
              return 1, 1, 1, 1
          end,
          setFunc = function(r, g, b, a)
              self.savedVariables.timerColor = { r = r, g = g, b = b, a = a }
          end,
        },
        { type = "dropdown", name = RainbowText("Background Color"),
          choices = { "Alliance", "Custom" },
          default = PvPUA.defaults.backdropStyle,
          getFunc = function() return self.savedVariables.backdropStyle end,
          setFunc = function(val)
              self.savedVariables.backdropStyle = val
              self:RefreshBackdropColors()
          end },
        { type = "colorpicker", name = "",
          tooltip = "Can only be changed when set to Custom.",
          disabled = function() return self.savedVariables.backdropStyle ~= "Custom" end,
          default = { r = 0, g = 0, b = 0, a = 1 },
          getFunc = function()
              local c = self.savedVariables.backdropColor
              if type(c) == "table" then
                  return c.r or 0, c.g or 0, c.b or 0, 1
              end
              return 0, 0, 0, 1
          end,
          setFunc = function(r, g, b, a)
              self.savedVariables.backdropColor = { r = r, g = g, b = b, a = a }
              self:RefreshBackdropColors()
          end,
        },
          } },
        { type = "submenu",
          name = "|c" .. AD_HEX .. "Alerts|r",
          childrenAlign = "center",
          icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_communications.dds",
          options = {
        self:HKBuildSettings(EA_DEFS[1]),
        self:EABuildSettings(EA_DEFS[2]),
        self:EABuildSettings(EA_DEFS[3]),
        { type = "submenu", name = "Potions", icon = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_buffsAndDebuffs.dds",
          options = PvPUA.Potion and PvPUA.Potion:GetOptions() or {} },
          } },
        { type = "submenu",
          name = "|c00FF00AP in Chat|r",
          icon = "EsoUI/Art/HUD/Gamepad/gp_HUDNotification_notification.dds",
          options = {
        { type = "toggle", name = "Enabled", preset = "YES_NO",
          default = PvPUA.defaults.enableAPChat,
          getFunc = function() return self.savedVariables.enableAPChat end,
          setFunc = function(v) self.savedVariables.enableAPChat = v end },
        { type = "toggle", name = "Consolidate", preset = "YES_NO",
          tooltip = "Consolidates Repair and Combat AP instead of printing each one individually.\nPrints after the last gain of that type based on the duration set below.",
          default = PvPUA.defaults.consolidateAPChat,
          getFunc = function() return self.savedVariables.consolidateAPChat end,
          setFunc = function(v) self.savedVariables.consolidateAPChat = v end },
        { type = "slider", name = "Repair Duration", min = 5, max = 60, step = 1,
          tooltip = "How long to wait before printing consolidated Repair AP (seconds).",
          default = PvPUA.defaults.consolidateRepairDelay,
          getFunc = function() return self.savedVariables.consolidateRepairDelay end,
          setFunc = function(v) self.savedVariables.consolidateRepairDelay = v end },
        { type = "slider", name = "Combat Duration", min = 5, max = 60, step = 1,
          tooltip = "How long to wait before printing consolidated Combat AP (seconds).",
          default = PvPUA.defaults.consolidateCombatDelay,
          getFunc = function() return self.savedVariables.consolidateCombatDelay end,
          setFunc = function(v) self.savedVariables.consolidateCombatDelay = v end },
          } },
        { type = "submenu",
          name = "|c" .. EP_HEX .. "Auto Invite|r",
          icon = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_down.dds",
          options = {
        { type = "toggle",
          name = "Enabled",
          preset = "YES_NO",
          tooltip = "Pauses automatically when the group is full and un-pauses when a spot opens.",
          getFunc = function() return PvPUA.charVariables.aiEnabled end,
          setFunc = function(val)
              if val then
                  EVENT_MANAGER:RegisterForEvent(
                      PvPUA.name .. "_AIGroup",
                      EVENT_GROUP_MEMBER_LEFT,
                      AIOnGroupMemberLeft
                  )
                  EVENT_MANAGER:RegisterForEvent(
                      PvPUA.name .. "_AILeader",
                      EVENT_LEADER_UPDATE,
                      AIOnLeaderUpdate
                  )
                  PvPUA:AIStart()
              else
                  PvPUA:AIStop()
              end
          end },
        { type = "editbox",
          name = "Keyword(s)",
          tooltip = "Words that trigger an invite. Separate multiple with commas (e.g., \"lfg, inv, x\"). Any ONE of them works on its own; a person is invited if their message is EXACTLY one of these words.",
          getFunc = function() return PvPUA.charVariables.aiKeyword end,
          setFunc = function(val)
              if val == PvPUA.charVariables.aiKeyword then return end
              PvPUA.charVariables.aiKeyword = val
              if PvPUA.charVariables.aiEnabled then
                  AIEcho("Keyword(s) updated to: |c00FF00" .. val .. "|r")
              end
          end },
        { type = "checklist",
          name = "Zones",
          tooltip = "Where the sender must be for their message to trigger an invite.",
          noSelectionText = "None",
          choices = {
              { name = "PvP", value = "pvp" },
              { name = "PvE", value = "pve" },
          },
          default = { "pvp", "pve" },
          getFunc = function()
              local cv = PvPUA.charVariables
              local sel = {}
              if cv.aiPvP then sel[#sel + 1] = "pvp" end
              if cv.aiPvE then sel[#sel + 1] = "pve" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              PvPUA.charVariables.aiPvP = on.pvp == true
              PvPUA.charVariables.aiPvE = on.pve == true
          end },
        { type = "checklist",
          name = "Channels",
          tooltip = "Channels the auto invite listens to for your keyword.",
          noSelectionText = "None",
          choices = PvPUA:AIChannelChoices(),
          default = { "whisper" },
          getFunc = function()
              local cv = PvPUA.charVariables
              local sel = {}
              if cv.aiWhisper then sel[#sel + 1] = "whisper" end
              if cv.aiSay then sel[#sel + 1] = "say" end
              if cv.aiZone then sel[#sel + 1] = "zone" end
              cv.aiGuildToggles = cv.aiGuildToggles or {}
              for i = 1, 5 do
                  if cv.aiGuildToggles[i] then sel[#sel + 1] = "guild" .. i end
              end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local cv = PvPUA.charVariables
              cv.aiWhisper = on.whisper == true
              cv.aiSay = on.say == true
              cv.aiZone = on.zone == true
              cv.aiGuildToggles = cv.aiGuildToggles or {}
              for i = 1, 5 do
                  cv.aiGuildToggles[i] = on["guild" .. i] == true
              end
          end },
        { type = "button",
          name = "|cFF8800ReloadUI|r",
          tooltip = "Guild names in the Channels list are read once when the addon loads. If you have joined or left a guild this session, reloadui to refresh them.",
          func = function() ReloadUI("ingame") end },
        { type = "toggle",
          name = "Auto Kick",
          tooltip = "Automatically removes group members who have been offline longer than the time below.",
          default = PvPUA.charDefaults.aiKickOffline,
          getFunc = function() return PvPUA.charVariables.aiKickOffline end,
          setFunc = function(val)
              PvPUA.charVariables.aiKickOffline = val
              if val then PvPUA:AIKickStart() else PvPUA:AIKickStop() end
          end },
        { type = "slider", name = "Offline Minutes", min = 1, max = 30, step = 1,
          default = PvPUA.charDefaults.aiKickMinutes,
          getFunc = function() return PvPUA.charVariables.aiKickMinutes end,
          setFunc = function(v) PvPUA.charVariables.aiKickMinutes = v end,
          disabled = function() return not PvPUA.charVariables.aiKickOffline end },
          } },
        { type = "submenu",
          name = "|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r |cFFFFFFRanks|r",
          childrenAlign = "leftFlush",
          icon = PVPUA_ADDON_ICON,
          options = PvPUA.Ranks and PvPUA.Ranks:GetOptions() or {} },
        { type = "submenu",
          name = "|c" .. DC_HEX .. "Icon|r",
          icon = "EsoUI/Art/Options/Gamepad/gp_options_nameplates.dds",
          options = {
        { type = "selector",
          name = "Category",
          choices = PI.GetCategoryChoices(),
          default = myCategoryDefault,
          getFunc = function() return PI.GetMyCategory() end,
          setFunc = function(categoryId) PI.SetMyCategory(categoryId) end },
        { type = "iconpicker",
          name = "Icon",
          choices = function() return PI.BuildPickerChoices() end,
          default = myPickerDefault,
          getFunc = function() return PI.GetMyPickerIndex() end,
          setFunc = function(index) PI.SetMyPickerIndex(index) end },
        { type = "slider", name = "Size", min = PI.SIZE_MIN, max = PI.SIZE_MAX, step = PI.SIZE_STEP,
          default = mySizeDefault,
          getFunc = function() return PI.GetMySize() end,
          setFunc = function(v) PI.SetMySize(v) end },
        { type = "slider", name = "Height", min = PI.HEIGHT_MIN, max = PI.HEIGHT_MAX, step = PI.HEIGHT_STEP,
          default = myHeightDefault,
          getFunc = function() return PI.GetMyHeight() end,
          setFunc = function(v) PI.SetMyHeight(v) end },
        { type = "slider", name = "Opacity", min = PI.OPACITY_MIN, max = PI.OPACITY_MAX, step = PI.OPACITY_STEP,
          default = myOpacityDefault,
          getFunc = function() return PI.GetMyOpacity() end,
          setFunc = function(v) PI.SetMyOpacity(v) end },
        { type = "checklist",
          name = "Show",
          noSelectionText = "None",
          choices = {
              { name = "Self",   value = "self" },
              { name = "Others", value = "others" },
              { name = "Small Group Frames", value = "smallGroupFrames" },
              { name = "Large Group Frames", value = "largeGroupFrames" },
          },
          default = { "self", "others", "smallGroupFrames", "largeGroupFrames" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.iconShowSelf then sel[#sel + 1] = "self" end
              if sv.iconShowOthers then sel[#sel + 1] = "others" end
              if sv.iconShowSmallGroupFrames then sel[#sel + 1] = "smallGroupFrames" end
              if sv.iconShowLargeGroupFrames then sel[#sel + 1] = "largeGroupFrames" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              PvPUA.savedVariables.iconShowSelf = on.self == true
              PvPUA.savedVariables.iconShowOthers = on.others == true
              PvPUA.savedVariables.iconShowSmallGroupFrames = on.smallGroupFrames == true
              PvPUA.savedVariables.iconShowLargeGroupFrames = on.largeGroupFrames == true
              PI.RefreshGroupFrameIcons()
          end },
          } },
    })

    if PvPUA.Ranks then PvPUA.Ranks:PatchKeybind(menu) end
end
--------------------------------------------------
-- Kill Feed
--------------------------------------------------
local KILL_FEED_EXPIRATION_MS = 10000
local killFeedSeen = {}

local function KFNormalize(name)
    name = zo_strformat("<<1>>", name or "")
    name = name:gsub("^@", "")
    return name:lower()
end

local function KFPlayerIdentity()
    local charName = KFNormalize(GetUnitName("player") or "")
    local displayName = ""
    local ok, dn = pcall(GetDisplayName)
    if ok and dn then displayName = KFNormalize(dn) end
    return charName, displayName
end

local function KFIsPlayer(displayName, characterName)
    local playerChar, playerDisplay = KFPlayerIdentity()
    local c = KFNormalize(characterName)
    local d = KFNormalize(displayName)
    if c ~= "" and playerChar ~= "" and c == playerChar then return true end
    if d ~= "" and playerDisplay ~= "" and d == playerDisplay then return true end
    if d ~= "" and playerChar ~= "" and d == playerChar then return true end
    if c ~= "" and playerDisplay ~= "" and c == playerDisplay then return true end
    return false
end

local function KFPreferredName(displayName, characterName)
    local d = KFNormalize(displayName)
    if d ~= "" then return d end
    return KFNormalize(characterName)
end

local function KFShouldSuppress(killerName, victimName, isKillLocation)
    local now = GetGameTimeMilliseconds()
    for key, stamp in pairs(killFeedSeen) do
        if now - stamp > KILL_FEED_EXPIRATION_MS then
            killFeedSeen[key] = nil
        end
    end
    local suffix = killerName .. "___" .. victimName
    local ownKey = (isKillLocation and "B" or "L") .. suffix
    local otherKey = (isKillLocation and "L" or "B") .. suffix
    if killFeedSeen[otherKey] ~= nil then
        killFeedSeen[otherKey] = nil
        return true
    end
    killFeedSeen[ownKey] = now
    return false
end

local function PvPUA_OnKillFeedDeath(eventCode, killLocation,
        killerDisplayName, killerCharacterName, killerAlliance, killerRank,
        victimDisplayName, victimCharacterName, victimAlliance, victimRank,
        isKillLocation)
    if not KFIsPlayer(killerDisplayName, killerCharacterName) then return end
    if KFIsPlayer(victimDisplayName, victimCharacterName) then return end
    local killerName = KFPreferredName(killerDisplayName, killerCharacterName)
    local victimName = KFPreferredName(victimDisplayName, victimCharacterName)
    if victimName == "" then return end
    if KFShouldSuppress(killerName, victimName, isKillLocation == true) then return end
    PvPUA.session.killingBlows = PvPUA.session.killingBlows + 1
    UpdateKAD()
end

--------------------------------------------------
-- Whats New
--------------------------------------------------
local WHATS_NEW_DIALOG = "PVPUA_WHATS_NEW"
local whatsNewRegistered = false

local function WhatsNewPublicIconCount()
    local count = 0
    for _, icon in ipairs(PvPUA.constants.iconChoices) do
        if not icon.none and not icon.isDefault then count = count + 1 end
    end
    return count
end

PvPUA.whatsNew = {
    version = "1.8",
    title = "PvP UA!",
    message = table.concat({
        "Updated to version 5.",
        "",
        "- Icons are now available to everyone. There are just " .. WhatsNewPublicIconCount() .. " for now.",
        "- You can change your icon's size and height.",
        "- LibGroupBroadcast is only needed for you and your group to see each other's icons.",
        "- Show now includes Small Group Frames and Large Group Frames.",
        "- If you can't see your group members' icons, first make sure you have LibGroupBroadcast. If you do, try quitting and restarting your game.",
        "- If your own icon isn't showing, try quitting and restarting your game as well.",
        "",
        "Any bugs, message me:",
        "Xbox: user562",
        "Discord: user562. (period included)",
    }, "\n"),
}

local function WhatsNewTitle()
    return PvPUA.whatsNew.title or ""
end

local function WhatsNewMessage()
    return PvPUA.whatsNew.message or ""
end

local function WhatsNewMarkSeen()
    if PvPUA.savedVariables then
        PvPUA.savedVariables.lastSeenVersion = PvPUA.whatsNew.version
    end
end

local function WhatsNewRegisterDialog()
    if whatsNewRegistered or not ZO_Dialogs_RegisterCustomDialog then return end
    ZO_Dialogs_RegisterCustomDialog(WHATS_NEW_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC },
        title = { text = WhatsNewTitle },
        mainText = { text = WhatsNewMessage },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = SI_OK, callback = WhatsNewMarkSeen },
        },
    })
    whatsNewRegistered = true
end

function PvPUA:ShowWhatsNew()
    WhatsNewRegisterDialog()
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(WHATS_NEW_DIALOG)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(WHATS_NEW_DIALOG)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(WHATS_NEW_DIALOG)
    end
end

function PvPUA:WhatsNewCheck(freshInstall)
    local wn = PvPUA.whatsNew
    if type(wn.version) ~= "string" or wn.version == "" then return end
    if not self.savedVariables then return end
    if freshInstall then
        WhatsNewMarkSeen()
        return
    end
    if self.savedVariables.lastSeenVersion == wn.version then return end
    self:ShowWhatsNew()
end

--------------------------------------------------
-- Load
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName ~= PvPUA.name then return end

    local freshInstall = (PvPUA_SavedVars == nil)

    PvPUA.savedVariables = ZO_SavedVars:NewAccountWide(
        "PvPUA_SavedVars", 27, nil,
        PvPUA.defaults
    )

    PvPUA.charVariables = ZO_SavedVars:NewCharacterIdSettings(
        "PvPUA_CharVars", 1, nil,
        PvPUA.charDefaults
    )

    if type(PvPUA.charVariables.aiGuildToggles) ~= "table" then
        PvPUA.charVariables.aiGuildToggles = {}
    end

    if type(PvPUA.savedVariables.lastSeenVersion) ~= "string" then
        PvPUA.savedVariables.lastSeenVersion = ""
    end

    if PvPUA.charVariables.aiPvP == nil then
        PvPUA.charVariables.aiPvP = true
    end
    if PvPUA.charVariables.aiPvE == nil then
        PvPUA.charVariables.aiPvE = true
    end

    if not PvPUA.charVariables.aiGuildMigrationRepair then
        PvPUA.charVariables.aiGuildMigrated = false
        PvPUA.charVariables.aiGuildMigrationRepair = true
    end

    if not PvPUA.savedVariables.showListDeadRepair then
        PvPUA.savedVariables.showListWhileDead = true
        PvPUA.savedVariables.showListDeadRepair = true
    end

    PvPUA.savedVariables.listSize = "Default"

    if PvPUA.savedVariables.iconShowGroupFrames ~= nil then
        PvPUA.savedVariables.iconShowSmallGroupFrames = PvPUA.savedVariables.iconShowGroupFrames
        PvPUA.savedVariables.iconShowLargeGroupFrames = PvPUA.savedVariables.iconShowGroupFrames
        PvPUA.savedVariables.iconShowGroupFrames = nil
    end

    if PvPUA.Potion then
        pcall(function() PvPUA.Potion:Initialize() end)
    end

    local style = PvPUA.savedVariables.backdropStyle
    if style == "Alliance Colored" then
        PvPUA.savedVariables.backdropStyle = "Alliance"
    elseif style == "Black" then
        PvPUA.savedVariables.backdropStyle = "Custom"
        PvPUA.savedVariables.backdropColor = { r = 0, g = 0, b = 0, a = 1 }
    end

    PvPUA:ApplyListSize()
    PvPUA:CreateUI()
    PvPUA:CreateQueueUI()
    PvPUA:RegisterQueueEvents()
    PvPUA:StartQueueSafetyPoll()
    PvPUA:RefreshQueueSoon()
    PvPUA:RefreshBackdropColors()
    PvPUA:EAInit()
    local settingsOk, settingsErr = pcall(function() PvPUA:CreateSettings() end)
    if not settingsOk then
        PvPUA.settingsUnavailable = true
        PvPUA.settingsError = tostring(settingsErr)
    end

    pcall(PI.Init)
    pcall(PI.InitNetwork)
    pcall(PI.InitGroupFrameIcons)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_PLAYER_ACTIVATED,
        function() PvPUA:OnPlayerActivated() end)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_WhatsNew", EVENT_PLAYER_ACTIVATED,
        function()
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_WhatsNew", EVENT_PLAYER_ACTIVATED)
            PvPUA:WhatsNewCheck(freshInstall)
        end)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_ZoneChanged", EVENT_ZONE_CHANGED,
        function() PvPUA:ZoneCheck() end)

    local siegeEvents = {
        { EVENT_BEGIN_SIEGE_CONTROL, "_SiegeBegin" },
        { EVENT_END_SIEGE_CONTROL,   "_SiegeEnd" },
    }
    for i = 1, #siegeEvents do
        local eventId, suffix = siegeEvents[i][1], siegeEvents[i][2]
        if eventId ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. suffix, eventId,
                function() PvPUA:ApplyListVisibility() end)
        end
    end

    if not pvpIsCombatRegistered then

        if EVENT_PVP_KILL_FEED_DEATH ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_KillFeed", EVENT_PVP_KILL_FEED_DEATH,
                PvPUA_OnKillFeedDeath)
        end

        EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_Death", EVENT_PLAYER_DEAD,
            function()
                RSOnDeathStateChanged()
                PvPUA:EAClearAll()
                PvPUA:ApplyListVisibility()
                if not (IsPlayerInAvAWorld() or IsActiveWorldBattleground()) then return end
                PvPUA.session.deaths = PvPUA.session.deaths + 1
                UpdateKAD()
            end)

        EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_Alive", EVENT_PLAYER_ALIVE,
            function()
                RSOnDeathStateChanged()
                PvPUA:EAClearAll()
                PvPUA:ApplyListVisibility()
            end)

        pvpIsCombatRegistered = true
    end

    if PvPUA.charVariables.aiEnabled then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_AIGroup",
            EVENT_GROUP_MEMBER_LEFT,
            AIOnGroupMemberLeft
        )
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_AILeader",
            EVENT_LEADER_UPDATE,
            AIOnLeaderUpdate
        )
        PvPUA:AIStart(true)
    end

    if PvPUA.charVariables.aiKickOffline then
        PvPUA:AIKickStart()
    end

    EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

--------------------------------------------------
-- AP In Chat
--------------------------------------------------
local function FormatAP(amount)
    if amount >= 1000000 then return string.format("%.1fM", amount / 1000000)
    elseif amount >= 1000 then return string.format("%.1fK", amount / 1000)
    else return tostring(amount) end
end

local AP_REASONS = {
    [CURRENCY_CHANGE_REASON_KILL]                  = "Combat",
    [CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD] = "Capture",
    [CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD] = "D-Tick",
    [CURRENCY_CHANGE_REASON_KEEP_REPAIR]           = "Repair",
    [CURRENCY_CHANGE_REASON_PVP_RESURRECT]         = "Rez",
    [CURRENCY_CHANGE_REASON_MEDAL]                 = "Medal",
    [CURRENCY_CHANGE_REASON_BATTLEGROUND]          = "BG",
    [CURRENCY_CHANGE_REASON_QUESTREWARD]           = "Quest",
}

local apBuckets = {}

local function FlushAPBucket(reason)
    local bucket = apBuckets[reason]
    if not bucket or bucket.total <= 0 then return end
    local source = AP_REASONS[reason]
    local alliance = GetUnitAlliance("player")
    local aColor = GetAllianceColor(alliance):ToHex()
    local msg = "|c00FF00+" .. FormatAP(bucket.total) .. " AP|r"
    if source then msg = msg .. " |c" .. aColor .. "(" .. source .. ")|r" end
    d(msg)
    bucket.total = 0
end

local function OnAPGain(eventCode, alliancePoints, playSound, difference, reason)
    PvPUA:RefreshRankLabel()
    if reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
    or reason == CURRENCY_CHANGE_REASON_VENDOR
    or reason == CURRENCY_CHANGE_REASON_TRADE
    or difference <= 0 then return end
    if not PvPUA.savedVariables or not PvPUA.savedVariables.enableAPChat then return end

    local source = AP_REASONS[reason]
    local alliance = GetUnitAlliance("player")
    local aColor = GetAllianceColor(alliance):ToHex()

    if PvPUA.savedVariables.consolidateAPChat
    and (reason == CURRENCY_CHANGE_REASON_KILL or reason == CURRENCY_CHANGE_REASON_KEEP_REPAIR) then
        if not apBuckets[reason] then
            apBuckets[reason] = { total = 0 }
        end
        apBuckets[reason].total = apBuckets[reason].total + difference
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_APFlush_" .. tostring(reason))
        local delay = (reason == CURRENCY_CHANGE_REASON_KEEP_REPAIR)
            and (PvPUA.savedVariables.consolidateRepairDelay or 5) * 1000
            or  (PvPUA.savedVariables.consolidateCombatDelay or 10) * 1000
        EVENT_MANAGER:RegisterForUpdate("PvPUA_APFlush_" .. tostring(reason), delay, function()
            EVENT_MANAGER:UnregisterForUpdate("PvPUA_APFlush_" .. tostring(reason))
            FlushAPBucket(reason)
        end)
    else
        local msg = "|c00FF00+" .. FormatAP(difference) .. " AP|r"
        if source then msg = msg .. " |c" .. aColor .. "(" .. source .. ")|r" end
        d(msg)
    end
end

EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_AP", EVENT_ALLIANCE_POINT_UPDATE, OnAPGain)

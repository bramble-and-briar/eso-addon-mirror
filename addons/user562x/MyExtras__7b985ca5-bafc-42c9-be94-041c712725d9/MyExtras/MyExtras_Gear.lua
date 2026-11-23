local ME = MyExtras
local Gear = {}
ME.Gear = Gear

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON  = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_characterProgression.dds"
local ICON_SIZE     = 40
local DETAILS_ICON  = 96
local EMPTY_COLOR   = "8C8C8C"
local WEIGHT_NAMES  = {
    [ARMORTYPE_LIGHT]  = "Light",
    [ARMORTYPE_MEDIUM] = "Medium",
    [ARMORTYPE_HEAVY]  = "Heavy",
}
local TITLE_TEXT    = "Equipped Sets"
local REFRESH_MS    = 100
local MOVE_SPEED    = 500
local SCALE_SPEED   = 10
local SIZE_MIN      = 16
local SIZE_MAX      = 48
local BOX_PAD_X     = 0.4
local BOX_PAD_Y     = 0.2
local BOX_CORNER    = 0.35
local CARE_NAME     = ME.name .. "_GearCare"
local CARE_SOON_MS  = 500
local CARE_WAIT_MS  = 3000
local CARE_CHECK_MS = 1000

Gear.charDefaults = {
    gearUseCharacter = false,
}

Gear.defaults = {
    gearShow          = false,
    gearTitle         = true,
    gearFont          = "EsoUI/Common/Fonts/FTN57.otf",
    gearSize          = 24,
    gearStretch       = 100,
    gearCompleteStyle = "Alliance",
    gearCompleteColor = { r = 1, g = 1, b = 1, a = 1 },
    gearPartialStyle  = "Custom",
    gearPartialColor  = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
    gearPosX          = 60,
    gearPosY          = 520,
    gearBackground        = true,
    gearBackgroundOpacity = 100,
    gearAutoRepair        = false,
    gearRepairBelow       = 10,
    gearMerchantRepair    = false,
    gearAutoCharge        = false,
    gearChargeBelow       = 10,
    gearAutoBind          = false,
    gearLogRepair         = true,
    gearLogCharge         = true,
    gearLogBind           = true,
}

Gear.logChoices = {
    { name = "Repairs", value = "repair" },
    { name = "Charges", value = "charge" },
    { name = "Binds",   value = "bind"   },
}

local LOG_KEYS = { repair = "gearLogRepair", charge = "gearLogCharge", bind = "gearLogBind" }

local WEAPON_SLOTS = {
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

local ARMOR = {
    { slot = EQUIP_SLOT_HEAD,      label = "Head"      },
    { slot = EQUIP_SLOT_SHOULDERS, label = "Shoulders" },
    { slot = EQUIP_SLOT_CHEST,     label = "Chest"     },
    { slot = EQUIP_SLOT_HAND,      label = "Hands"     },
    { slot = EQUIP_SLOT_WAIST,     label = "Waist"     },
    { slot = EQUIP_SLOT_LEGS,      label = "Legs"      },
    { slot = EQUIP_SLOT_FEET,      label = "Feet"      },
}

local JEWELRY = {
    { slot = EQUIP_SLOT_NECK,  label = "Neck" },
    { slot = EQUIP_SLOT_RING1, label = "Ring" },
    { slot = EQUIP_SLOT_RING2, label = "Ring" },
}

local FRONT = {
    { slot = EQUIP_SLOT_MAIN_HAND, label = "Main Hand", weapon = true },
    { slot = EQUIP_SLOT_OFF_HAND,  label = "Off Hand",  weapon = true },
    { slot = EQUIP_SLOT_POISON,    label = "Poison",    poison = true },
}

local BACK = {
    { slot = EQUIP_SLOT_BACKUP_MAIN,   label = "Main Hand", weapon = true },
    { slot = EQUIP_SLOT_BACKUP_OFF,    label = "Off Hand",  weapon = true },
    { slot = EQUIP_SLOT_BACKUP_POISON, label = "Poison",    poison = true },
}

Gear.dirty   = true
Gear.preview = false
Gear.moving  = false

local rows       = {}
local lines      = {}
local hudShowing = { hud = false, hudui = false }
local pending    = false
local careWatch  = false
local careQueued = false
local careWait   = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local charFilled = false

local function CharSettings()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.gearCharSettings) ~= "table" then cv.gearCharSettings = {} end
    local settings = cv.gearCharSettings
    if not settings.seeded then
        local account = ME.savedVariables
        for key, value in pairs(Gear.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            settings[key] = current
        end
        settings.seeded = true
        charFilled = true
    elseif not charFilled then
        for key, value in pairs(Gear.defaults) do
            if settings[key] == nil then settings[key] = value end
        end
        charFilled = true
    end
    return settings
end

function Gear:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.gearUseCharacter == true
end

local CARE_KEYS = {
    gearAutoRepair     = true,
    gearRepairBelow    = true,
    gearMerchantRepair = true,
    gearAutoCharge     = true,
    gearChargeBelow    = true,
    gearAutoBind       = true,
    gearLogRepair      = true,
    gearLogCharge      = true,
    gearLogBind        = true,
}

local careScope = ME:NewScope("gearCareCharSettings")
do
    local careDefaults = {}
    for key in pairs(CARE_KEYS) do careDefaults[key] = Gear.defaults[key] end
    careScope:AddDefaults(careDefaults, "gearCare")
end

local function BaseSV()
    if Gear:UsesCharacterSettings() then
        return CharSettings() or ME.savedVariables
    end
    return ME.savedVariables
end

local settingsProxy = setmetatable({}, {
    __index = function(_, key)
        if CARE_KEYS[key] then return careScope:Settings()[key] end
        return BaseSV()[key]
    end,
    __newindex = function(_, key, value)
        if CARE_KEYS[key] then
            careScope:Settings()[key] = value
        else
            BaseSV()[key] = value
        end
    end,
})

local function SV()
    return settingsProxy
end

local function MigrateCare()
    local cv = ME.charVariables
    if not cv or cv.gearCareCharSettingsScopes ~= nil then return end
    if cv.gearUseCharacter == true and type(cv.gearCharSettings) == "table" then
        careScope:SetUsesCharacter("gearCare", true)
        local settings = careScope:CharTable()
        for key in pairs(CARE_KEYS) do
            if cv.gearCharSettings[key] ~= nil then settings[key] = cv.gearCharSettings[key] end
        end
    else
        careScope:Flags()
    end
end

local function SavedTip()
    if Gear:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

local function WornLink(slot)
    local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)
    if type(link) ~= "string" or link == "" then return nil end
    return link
end

local function CleanName(text)
    if type(text) ~= "string" or text == "" then return "" end
    return zo_strformat("<<1>>", text)
end

local function QualityName(link)
    local name = zo_strformat("<<t:1>>", GetItemLinkName(link))
    local color = GetItemQualityColor and GetItemQualityColor(GetItemLinkDisplayQuality(link))
    if color then name = color:Colorize(name) end
    return name
end

local function IsTwoHanded(slot)
    local link = WornLink(slot)
    return link ~= nil and GetItemLinkEquipType(link) == EQUIP_TYPE_TWO_HAND
end

local function StyleColor(style, custom)
    if style == "Custom" and type(custom) == "table" then
        return custom.r or 1, custom.g or 1, custom.b or 1
    end
    local color = GetAllianceColor(GetUnitAlliance("player"))
    if color then return color:UnpackRGB() end
    return 1, 1, 1
end

local function RowFont()
    local sv = SV()
    return string.format("%s|%d|soft-shadow-thick", sv.gearFont, sv.gearSize)
end

local function SampleFont()
    return string.format("%s|40|outline", SV().gearFont)
end

local function SampleLine(complete)
    for i = 1, #lines do
        local line = lines[i]
        if line.complete == complete then
            local text = "(" .. line.count .. "/" .. line.max .. ") " .. line.name
            if line.tag then text = text .. ", " .. line.tag end
            return text
        end
    end
    if complete then return "(5/5) Example Set" end
    return "(3/5) Example Set"
end

local function RefreshPanelPages()
    Gear.dirty = true
    local panel = ME.settingsPanel
    if panel and panel.RefreshPages then panel:RefreshPages() end
end

--------------------------------------------------
-- Sets
--------------------------------------------------
local function AddPiece(sets, order, link, pieces)
    local hasSet, setName, _, _, maxEquipped, setId = GetItemLinkSetInfo(link, false)
    if not hasSet then return end

    local baseId = setId
    local perfected = false
    local unperfectedId = GetItemSetUnperfectedSetId(setId)
    if unperfectedId and unperfectedId ~= 0 then
        baseId = unperfectedId
        perfected = true
    end

    local set = sets[baseId]
    if not set then
        local name = setName
        if perfected then name = GetItemSetName(baseId) end
        set = { id = baseId, name = CleanName(name), count = 0, max = maxEquipped or 0 }
        sets[baseId] = set
        order[#order + 1] = set
    end
    set.count = set.count + pieces
end

local function AddSlots(sets, order, list)
    for i = 1, #list do
        local entry = list[i]
        if not entry.poison then
            local link = WornLink(entry.slot)
            if link then
                local pieces = 1
                if entry.weapon and GetItemLinkEquipType(link) == EQUIP_TYPE_TWO_HAND then pieces = 2 end
                AddPiece(sets, order, link, pieces)
            end
        end
    end
end

local function BarSets(weapons)
    local sets, order = {}, {}
    AddSlots(sets, order, ARMOR)
    AddSlots(sets, order, JEWELRY)
    AddSlots(sets, order, weapons)
    return sets, order
end

local function CompareLines(a, b)
    local aDone, bDone = a.complete, b.complete
    if aDone ~= bDone then return aDone end
    if a.count ~= b.count then return a.count > b.count end
    if a.max ~= b.max then return a.max > b.max end
    return a.name < b.name
end

function Gear:BuildLines()
    ZO_ClearNumericallyIndexedTable(lines)
    local frontSets, frontOrder = BarSets(FRONT)
    local backSets, backOrder = BarSets(BACK)

    local seen = {}
    local function Add(set)
        if seen[set.id] then return end
        seen[set.id] = true
        local front = frontSets[set.id]
        local back = backSets[set.id]
        local frontCount = front and front.count or 0
        local backCount = back and back.count or 0
        local count = math.max(frontCount, backCount)
        local tag
        if frontCount > backCount then
            tag = "Front Bar"
        elseif backCount > frontCount then
            tag = "Back Bar"
        end
        local shown = set.max > 0 and math.min(count, set.max) or count
        lines[#lines + 1] = {
            name     = set.name,
            count    = shown,
            max      = set.max,
            tag      = tag,
            complete = set.max > 0 and count >= set.max,
        }
    end
    for i = 1, #frontOrder do Add(frontOrder[i]) end
    for i = 1, #backOrder do Add(backOrder[i]) end
    table.sort(lines, CompareLines)
end

--------------------------------------------------
-- Overlay
--------------------------------------------------
function Gear:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_GearPanel")
    panel:SetDrawLayer(DL_BACKGROUND)
    panel:SetDrawTier(DT_LOW)
    panel:SetMouseEnabled(false)
    panel:SetHidden(true)
    self.panel = panel

    local box = ME:CreateRoundBox("MyExtras_GearBox", panel)
    box:SetHidden(true)
    self.box = box

    local title = WINDOW_MANAGER:CreateControl("MyExtras_GearTitle", panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    title:SetDrawLevel(2)
    title:SetText(TITLE_TEXT)
    self.title = title
end

local function GetRow(index)
    local row = rows[index]
    if not row then
        row = WINDOW_MANAGER:CreateControl("MyExtras_GearRow" .. index, Gear.panel, CT_LABEL)
        row:SetDrawLevel(2)
        rows[index] = row
    end
    return row
end

function Gear:ApplyBox(width, height)
    if not self.box then return end
    local sv = SV()
    local show = sv.gearBackground == true and width > 0 and height > 0
    self.box:SetHidden(not show)
    if not show then return end
    local size = sv.gearSize or self.defaults.gearSize
    local padX = math.max(4, zo_floor(size * BOX_PAD_X))
    local padY = math.max(2, zo_floor(size * BOX_PAD_Y))
    local opacity = tonumber(sv.gearBackgroundOpacity) or self.defaults.gearBackgroundOpacity
    self.box:SetFillColor(0, 0, 0, opacity / 100)
    self.box:SetCorner(math.max(6, size * BOX_CORNER))
    self.box.control:ClearAnchors()
    self.box.control:SetAnchor(TOPLEFT, self.panel, TOPLEFT, -padX, -padY)
    self.box.control:SetDimensions(zo_ceil(width) + padX * 2, zo_ceil(height) + padY * 2)
end

function Gear:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.gearPosX, sv.gearPosY)
    ME:ApplyStretch(self.panel, SV().gearStretch)
end

function Gear:Render()
    if not self.panel then return end
    local sv = SV()
    local font = RowFont()
    local spacing = zo_floor(sv.gearSize * 1.3)
    local doneR, doneG, doneB = StyleColor(sv.gearCompleteStyle, sv.gearCompleteColor)
    local partR, partG, partB = StyleColor(sv.gearPartialStyle, sv.gearPartialColor)

    local y = 0
    local width, height = 0, 0
    local showTitle = sv.gearTitle == true
    self.title:SetHidden(not showTitle)
    if showTitle then
        self.title:SetFont(font)
        self.title:SetColor(1, 1, 1, 1)
        width = self.title:GetTextWidth() or 0
        height = self.title:GetTextHeight() or 0
        y = spacing
    end

    local list = lines
    if (self.preview or self.moving) and #list == 0 then
        list = {
            { name = "Example Set", count = 5, max = 5, complete = true, tag = "Front Bar" },
            { name = "Example Set", count = 3, max = 5, complete = false },
        }
    end

    for i = 1, #list do
        local line = list[i]
        local row = GetRow(i)
        local text = "(" .. line.count .. "/" .. line.max .. ") " .. line.name
        if line.tag then text = text .. ", " .. line.tag end
        row:SetFont(font)
        row:SetText(text)
        if line.complete then
            row:SetColor(doneR, doneG, doneB, 1)
        else
            row:SetColor(partR, partG, partB, 1)
        end
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.panel, TOPLEFT, 0, y)
        row:SetHidden(false)
        width = math.max(width, row:GetTextWidth() or 0)
        height = y + (row:GetTextHeight() or 0)
        y = y + spacing
    end
    for i = #list + 1, #rows do
        rows[i]:SetHidden(true)
    end

    self.panel:SetDimensions(400, math.max(y, spacing))
    self:ApplyBox(width, height)
end

function Gear:Refresh()
    self:BuildLines()
    self:Render()
    self:UpdateVisibility()
end

local function RunRefresh()
    pending = false
    EVENT_MANAGER:UnregisterForUpdate(ME.name .. "_GearRefresh")
    Gear:Refresh()
    if not Gear.dirty then RefreshPanelPages() end
end

function Gear:QueueRefresh()
    if pending then
        EVENT_MANAGER:UnregisterForUpdate(ME.name .. "_GearRefresh")
    end
    pending = true
    EVENT_MANAGER:RegisterForUpdate(ME.name .. "_GearRefresh", REFRESH_MS, RunRefresh)
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function Gear:UpdateVisibility()
    if not self.panel then return end
    local onHud = hudShowing.hud or hudShowing.hudui
    local hasLines = #lines > 0 or SV().gearTitle == true
    local show = self.preview or self.moving or (SV().gearShow and (onHud or ME.placing) and hasLines)
    self.panel:SetHidden(not show)
end

function Gear:OnPlacing()
    self:UpdateVisibility()
end

function Gear:SetPreview(value)
    self.preview = value == true
    self:Render()
    self:UpdateVisibility()
end

function Gear:RegisterScenes()
    local names = { "hud", "hudui" }
    for i = 1, #names do
        local sceneName = names[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            hudShowing[sceneName] = scene:IsShowing()
            scene:RegisterCallback("StateChange", function(oldState, newState)
                hudShowing[sceneName] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
                Gear:UpdateVisibility()
            end)
        end
    end
end

--------------------------------------------------
-- Move
--------------------------------------------------
function Gear:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moving = true
    local started = LibUser562:StartMove({
        controls    = { self.panel },
        moveSpeed   = MOVE_SPEED,
        scaleSpeed  = SCALE_SPEED,
        sizeMin     = SIZE_MIN,
        sizeMax     = SIZE_MAX,
        defaults    = {
            x    = self.defaults.gearPosX,
            y    = self.defaults.gearPosY,
            size = self.defaults.gearSize,
        },
        getPosition = function() return SV().gearPosX, SV().gearPosY end,
        setPosition = function(x, y)
            local sv = SV()
            sv.gearPosX, sv.gearPosY = x, y
            Gear:ApplyPosition()
        end,
        getSize    = function() return SV().gearSize end,
        setSize    = function(size)
            SV().gearSize = size
            Gear:Render()
        end,
        getStretch = function() return SV().gearStretch or 100 end,
        setStretch = function(percent)
            SV().gearStretch = percent
            ME:ApplyStretch(Gear.panel, percent)
        end,
        onShow = function()
            ME:SetPlacing(true)
            Gear:Render()
            Gear:UpdateVisibility()
        end,
        onHide = function()
            Gear.moving = false
            ME:SetPlacing(false)
            if Gear.movePreview then
                Gear.movePreview = false
                Gear:SetPreview(true)
            else
                Gear:Render()
                Gear:UpdateVisibility()
            end
        end,
    })
    if not started then self.moving = false end
end

--------------------------------------------------
-- Maintenance
--------------------------------------------------
local function CareWaiting(key)
    local untilMs = careWait[key]
    return untilMs ~= nil and GetFrameTimeMilliseconds() < untilMs
end

local function CareHold(key)
    careWait[key] = GetFrameTimeMilliseconds() + CARE_WAIT_MS
end

local function CareLog(kind, text)
    if SV()[LOG_KEYS[kind]] then ME:Chat(ME:ChatPrefix("Gear") .. text) end
end

local function LinkText(link)
    return ME:Icon(GetItemLinkIcon(link)) .. link
end

local function CareConfirm(check, kind, text)
    zo_callLater(function()
        if check() then CareLog(kind, text) end
    end, CARE_CHECK_MS)
end

local function IsGroupKit(slot)
    if not (IsItemRepairKit and IsItemNonGroupRepairKit) then return false end
    return IsItemRepairKit(BAG_BACKPACK, slot) and not IsItemNonGroupRepairKit(BAG_BACKPACK, slot)
end

local function FindRepairKits()
    local best, bestTier, crown
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if not IsGroupKit(slot) then
            if IsItemNonCrownRepairKit(BAG_BACKPACK, slot) then
                local tier = GetRepairKitTier(BAG_BACKPACK, slot) or 0
                if not best or tier > bestTier then best, bestTier = slot, tier end
            elseif not crown and GetItemType(BAG_BACKPACK, slot) == ITEMTYPE_CROWN_REPAIR then
                crown = slot
            end
        end
    end
    return best, crown
end

local function FindSoulGem()
    local crown
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsItemSoulGem(SOUL_GEM_TYPE_FILLED, BAG_BACKPACK, slot) then
            if not IsItemFromCrownStore(BAG_BACKPACK, slot) then return slot end
            crown = crown or slot
        end
    end
    return crown
end

local function NeedsRepair(slot, below)
    return HasItemInSlot(BAG_WORN, slot) and DoesItemHaveDurability(BAG_WORN, slot)
        and GetItemCondition(BAG_WORN, slot) <= below
end

function Gear:RepairGear()
    local sv = SV()
    if not sv.gearAutoRepair or IsUnitInCombat("player") then return false end
    if CareWaiting("crown") then return true end
    local below = sv.gearRepairBelow or self.defaults.gearRepairBelow
    for slot = 0, GetBagSize(BAG_WORN) - 1 do
        if NeedsRepair(slot, below) then
            if CareWaiting("repair" .. slot) then return true end
            local kit, crown = FindRepairKits()
            local before = GetItemCondition(BAG_WORN, slot)
            if kit then
                local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_BRACKETS)
                CareHold("repair" .. slot)
                if ME:CallGame("RepairItemWithRepairKit", BAG_WORN, slot, BAG_BACKPACK, kit) then
                    CareConfirm(function() return GetItemCondition(BAG_WORN, slot) > before end,
                        "repair", "Repaired " .. LinkText(link) .. ".")
                end
                return true
            elseif crown then
                CareHold("crown")
                local kitIcon = ME:Icon((GetItemInfo(BAG_BACKPACK, crown)))
                if ME:CallGame("UseItem", BAG_BACKPACK, crown) then
                    CareConfirm(function() return GetItemCondition(BAG_WORN, slot) > before end,
                        "repair", "Used a " .. kitIcon .. "Crown Repair Kit.")
                end
                return true
            end
            return false
        end
    end
    return false
end

function Gear:ChargeWeapons()
    local sv = SV()
    if not sv.gearAutoCharge then return false end
    local below = sv.gearChargeBelow or self.defaults.gearChargeBelow
    for i = 1, #WEAPON_SLOTS do
        local slot = WEAPON_SLOTS[i]
        if HasItemInSlot(BAG_WORN, slot) then
            local charge, maxCharge = GetChargeInfoForItem(BAG_WORN, slot)
            if (maxCharge or 0) > 0 and (charge or 0) / maxCharge * 100 <= below then
                if CareWaiting("charge" .. slot) then return true end
                local gem = FindSoulGem()
                if not gem then return false end
                local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_BRACKETS)
                CareHold("charge" .. slot)
                if ME:CallGame("ChargeItemWithSoulGem", BAG_WORN, slot, BAG_BACKPACK, gem) then
                    CareConfirm(function() return (GetChargeInfoForItem(BAG_WORN, slot) or 0) > (charge or 0) end,
                        "charge", "Charged " .. LinkText(link) .. ".")
                end
                return true
            end
        end
    end
    return false
end

function Gear:CareCheck()
    EVENT_MANAGER:UnregisterForUpdate(CARE_NAME)
    careQueued = false
    if not careWatch or IsUnitDead("player") then return end
    local again = self:ChargeWeapons()
    if self:RepairGear() then again = true end
    if again then self:CareSoon(CARE_WAIT_MS + 100) end
end

function Gear:CareSoon(delay)
    if careQueued or not careWatch then return end
    careQueued = true
    EVENT_MANAGER:RegisterForUpdate(CARE_NAME, delay or CARE_SOON_MS, function() Gear:CareCheck() end)
end

local function OnCareChanged()
    Gear:CareSoon()
end

local function OnCombatState(_, inCombat)
    if not inCombat then Gear:CareSoon() end
end

local function IsCareItem(bagId, slotId)
    if GetItemType(bagId, slotId) == ITEMTYPE_CROWN_REPAIR then return true end
    if IsItemNonCrownRepairKit(bagId, slotId) then return true end
    return IsItemSoulGem(SOUL_GEM_TYPE_FILLED, bagId, slotId)
end

local function BindNewItem(bagId, slotId)
    if not SV().gearAutoBind then return end
    local itemType = GetItemType(bagId, slotId)
    if itemType ~= ITEMTYPE_ARMOR and itemType ~= ITEMTYPE_WEAPON then return end
    if IsItemBound(bagId, slotId) then return end
    local link = GetItemLink(bagId, slotId, LINK_STYLE_BRACKETS)
    if not IsItemLinkSetCollectionPiece(link) then return end
    if IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(link)) then return end
    if ME:CallGame("BindItem", bagId, slotId) then
        CareConfirm(function() return IsItemBound(bagId, slotId) end,
            "bind", "Bound " .. LinkText(link) .. ".")
    end
end

local function OnBagItem(_, bagId, slotId, isNewItem)
    local sv = SV()
    if (sv.gearAutoRepair or sv.gearAutoCharge) and IsCareItem(bagId, slotId) then
        Gear:CareSoon()
    end
    if isNewItem then BindNewItem(bagId, slotId) end
end

local function OnOpenStore()
    if not SV().gearMerchantRepair or not CanStoreRepair() then return end
    local cost = GetRepairAllCost()
    if not cost or cost <= 0 then return end
    if cost > GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) then return end
    if ME:CallGame("RepairAll") then
        CareLog("repair", "Repaired all for " .. ZO_CommaDelimitNumber(cost) .. " "
            .. ZO_Currency_GetPlatformFormattedCurrencyIcon(CURT_MONEY) .. ".")
    end
end

function Gear:RefreshCare()
    local sv = SV()
    local on = sv.gearAutoRepair == true or sv.gearAutoCharge == true
        or sv.gearMerchantRepair == true or sv.gearAutoBind == true
    if on and not careWatch then
        local charge, durability, new = CARE_NAME .. "Charge", CARE_NAME .. "Durability", CARE_NAME .. "New"
        EVENT_MANAGER:RegisterForEvent(charge, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnCareChanged)
        EVENT_MANAGER:AddFilterForEvent(charge, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_WORN,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_ITEM_CHARGE)
        EVENT_MANAGER:RegisterForEvent(durability, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnCareChanged)
        EVENT_MANAGER:AddFilterForEvent(durability, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_WORN,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DURABILITY_CHANGE)
        EVENT_MANAGER:RegisterForEvent(new, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBagItem)
        EVENT_MANAGER:AddFilterForEvent(new, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:RegisterForEvent(CARE_NAME .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        EVENT_MANAGER:RegisterForEvent(CARE_NAME .. "Alive", EVENT_PLAYER_ALIVE, OnCareChanged)
        EVENT_MANAGER:RegisterForEvent(CARE_NAME .. "Store", EVENT_OPEN_STORE, OnOpenStore)
    elseif not on and careWatch then
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "Charge", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "Durability", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "New", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "Combat", EVENT_PLAYER_COMBAT_STATE)
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "Alive", EVENT_PLAYER_ALIVE)
        EVENT_MANAGER:UnregisterForEvent(CARE_NAME .. "Store", EVENT_OPEN_STORE)
        EVENT_MANAGER:UnregisterForUpdate(CARE_NAME)
        careQueued = false
    end
    careWatch = on
    if on then self:CareSoon() end
end

--------------------------------------------------
-- Items
--------------------------------------------------
local function ItemDetails(entry, link)
    local details = { "Slot: " .. entry.label }

    if entry.poison then
        local _, stack = GetItemInfo(BAG_WORN, entry.slot)
        details[#details + 1] = "Count: " .. tostring(stack or 0)
        return table.concat(details, "\n")
    end

    local weight = WEIGHT_NAMES[GetItemLinkArmorType(link)]
    if weight then details[#details + 1] = "Weight: " .. weight end

    local hasSet, setName = GetItemLinkSetInfo(link, false)
    details[#details + 1] = "Set: " .. (hasSet and CleanName(setName) or "None")

    local traitType = GetItemLinkTraitInfo(link)
    if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
        details[#details + 1] = "Trait: " .. GetString("SI_ITEMTRAITTYPE", traitType)
    else
        details[#details + 1] = "Trait: None"
    end

    local _, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(link)
    if type(enchantHeader) == "string" and enchantHeader ~= "" then
        details[#details + 1] = "Enchantment: " .. CleanName(enchantHeader)
        if type(enchantDescription) == "string" and enchantDescription ~= "" then
            details[#details + 1] = enchantDescription
        end
    else
        details[#details + 1] = "Enchantment: None"
    end

    return table.concat(details, "\n")
end

local function ItemOption(entry)
    local link = WornLink(entry.slot)
    if not link then
        return {
            type    = "button",
            name    = "|c" .. EMPTY_COLOR .. entry.label .. ": Empty|r",
            tooltip = "Nothing is equipped in this slot.",
        }
    end

    local icon = GetItemLinkIcon(link)
    return {
        type       = "button",
        name       = zo_iconFormat(icon, ICON_SIZE, ICON_SIZE) .. " " .. QualityName(link),
        tooltip    = ItemDetails(entry, link),
        sampleIcon = function() return icon, DETAILS_ICON end,
    }
end

local function AddSection(options, title, list)
    options[#options + 1] = { type = "header", name = title }
    local twoHanded = false
    for i = 1, #list do
        local entry = list[i]
        if entry.weapon and i == 1 then twoHanded = IsTwoHanded(entry.slot) end
        local skip = twoHanded and entry.weapon and i == 2 and not WornLink(entry.slot)
        if not skip then
            options[#options + 1] = ItemOption(entry)
        end
    end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function Gear:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

function Gear:SettingOptions()
    if self.settingOptions then return self.settingOptions end
    local defaults = self.defaults

    local function IsOff() return not SV().gearShow end

    local equippedSets = {
        {
            type    = "toggle",
            name    = "Enabled",
            preset  = "YES_NO",
            default = defaults.gearShow,
            tooltip = "Shows your equipped sets on screen, with how many pieces of each you're wearing.",
            getFunc = function() return SV().gearShow end,
            setFunc = function(val)
                SV().gearShow = val
                if not val and Gear.preview then Gear:SetPreview(false) end
                Gear:UpdateVisibility()
            end,
        },
        {
            type    = "toggle",
            name    = "Character Settings",
            tooltip = MyExtras.CHARACTER_SETTINGS_TIP,
            getFunc = function() return Gear:UsesCharacterSettings() end,
            setFunc = function(val) Gear:SetUseCharacterSettings(val) end,
        },
        {
            type     = "toggle",
            name     = "Preview",
            tooltip  = "Shows your sets here so you can see your changes. "
                    .. "Stays on until you turn it off or leave the settings.",
            disabled = IsOff,
            getFunc  = function() return Gear.preview end,
            setFunc  = function(val) Gear:SetPreview(val) end,
        },
        {
            type       = "button",
            name       = "Move / Scale",
            buttonText = "Move / Scale",
            tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right stretches it wider or narrower.",
            disabled   = IsOff,
            func       = function() Gear:StartMove() end,
        },
        {
            type     = "submenu",
            name     = "Appearance",
            tooltip  = "Title, font, colors and background for your sets.",
            disabled = IsOff,
            options  = {
                {
                    type    = "toggle",
                    name    = "Title",
                    preset  = "YES_NO",
                    default = defaults.gearTitle,
                    tooltip = "Shows \"" .. TITLE_TEXT .. "\" above your sets.",
                    getFunc = function() return SV().gearTitle end,
                    setFunc = function(val)
                        SV().gearTitle = val
                        Gear:Render()
                        Gear:UpdateVisibility()
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "Font",
                    tooltip = "Some fonts look bigger or smaller than others. Default is Gamepad Medium.",
                    choices = ME.FONT_CHOICES,
                    default = defaults.gearFont,
                    sample  = function() return TITLE_TEXT, SampleFont(), 1, 1, 1 end,
                    getFunc = function() return SV().gearFont end,
                    setFunc = function(val)
                        SV().gearFont = val
                        Gear:Render()
                    end,
                },
                {
                    type         = "stylecolor",
                    name         = ME.RainbowText("Complete Color"),
                    choices      = { "Alliance", "Custom" },
                    customValue  = "Custom",
                    default      = defaults.gearCompleteStyle,
                    colorDefault = { r = 1, g = 1, b = 1 },
                    details      = function()
                        if SV().gearCompleteStyle == "Custom" then
                            return "Complete sets use your color."
                        end
                        return "Complete sets use your alliance color."
                    end,
                    sample   = function()
                        local sv = SV()
                        local r, g, b = StyleColor(sv.gearCompleteStyle, sv.gearCompleteColor)
                        return SampleLine(true), SampleFont(), r, g, b
                    end,
                    getFunc  = function() return SV().gearCompleteStyle end,
                    setFunc  = function(val)
                        SV().gearCompleteStyle = val
                        Gear:Render()
                    end,
                    getColor = function()
                        local c = SV().gearCompleteColor
                        if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                        return 1, 1, 1
                    end,
                    setColor = function(r, g, b)
                        SV().gearCompleteColor = { r = r, g = g, b = b, a = 1 }
                        Gear:Render()
                    end,
                },
                {
                    type         = "stylecolor",
                    name         = ME.RainbowText("Incomplete Color"),
                    choices      = { "Alliance", "Custom" },
                    customValue  = "Custom",
                    default      = defaults.gearPartialStyle,
                    colorDefault = { r = 0.7, g = 0.7, b = 0.7 },
                    details      = function()
                        if SV().gearPartialStyle == "Custom" then
                            return "Incomplete sets use your color."
                        end
                        return "Incomplete sets use your alliance color."
                    end,
                    sample   = function()
                        local sv = SV()
                        local r, g, b = StyleColor(sv.gearPartialStyle, sv.gearPartialColor)
                        return SampleLine(false), SampleFont(), r, g, b
                    end,
                    getFunc  = function() return SV().gearPartialStyle end,
                    setFunc  = function(val)
                        SV().gearPartialStyle = val
                        Gear:Render()
                    end,
                    getColor = function()
                        local c = SV().gearPartialColor
                        if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                        return 0.7, 0.7, 0.7
                    end,
                    setColor = function(r, g, b)
                        SV().gearPartialColor = { r = r, g = g, b = b, a = 1 }
                        Gear:Render()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Background",
                    preset  = "YES_NO",
                    default = defaults.gearBackground,
                    tooltip = "Puts a black box behind your sets so they're easier to read.",
                    getFunc = function() return SV().gearBackground end,
                    setFunc = function(val)
                        SV().gearBackground = val
                        Gear:Render()
                    end,
                },
                {
                    type     = "slider",
                    name     = "Background Opacity",
                    min      = 0, max = 100, step = 5,
                    default  = defaults.gearBackgroundOpacity,
                    tooltip  = "Default is " .. defaults.gearBackgroundOpacity .. ".",
                    disabled = function() return not SV().gearBackground end,
                    getFunc  = function() return SV().gearBackgroundOpacity end,
                    setFunc  = function(val)
                        SV().gearBackgroundOpacity = val
                        Gear:Render()
                    end,
                },
            },
        },
    }

    self.settingOptions = {
        {
            type    = "submenu",
            name    = "Equipped Sets",
            tooltip = function()
                return "Shows your equipped sets on screen.\n\n" .. SavedTip()
            end,
            options = equippedSets,
        },
        {
            type     = "submenu",
            name     = "Maintenance",
            tooltip  = function()
                return "Keeps your gear repaired, charged and bound for you.\n\n" .. ME:SavedTip(careScope, "gearCare")
            end,
            options  = {
                ME:CharacterOption(careScope, "gearCare", function() Gear:RefreshCare() end),
                {
                    type    = "toggle",
                    name    = "Auto Repair",
                    preset  = "YES_NO",
                    default = defaults.gearAutoRepair,
                    tooltip = "Repairs your gear with a repair kit when a piece drops to Repair Below. "
                           .. "It uses regular kits first, and only uses a Crown Repair Kit when you don't have any regular ones. "
                           .. "It waits until you're out of combat.",
                    getFunc = function() return SV().gearAutoRepair end,
                    setFunc = function(val)
                        SV().gearAutoRepair = val
                        Gear:RefreshCare()
                    end,
                },
                {
                    type     = "slider",
                    name     = "Repair Below",
                    min      = 1, max = 99, step = 1,
                    default  = defaults.gearRepairBelow,
                    tooltip  = "Default is " .. defaults.gearRepairBelow .. ".",
                    details  = function()
                        return "Repairs a piece when its durability drops to " .. SV().gearRepairBelow .. "% or lower."
                    end,
                    disabled = function() return not SV().gearAutoRepair end,
                    getFunc  = function() return SV().gearRepairBelow end,
                    setFunc  = function(val)
                        SV().gearRepairBelow = val
                        Gear:CareSoon()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Repair At Merchants",
                    preset  = "YES_NO",
                    default = defaults.gearMerchantRepair,
                    tooltip = "Repairs all your gear at a merchant, as long as you have enough gold.",
                    getFunc = function() return SV().gearMerchantRepair end,
                    setFunc = function(val)
                        SV().gearMerchantRepair = val
                        Gear:RefreshCare()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Auto Charge",
                    preset  = "YES_NO",
                    default = defaults.gearAutoCharge,
                    tooltip = "Recharges your weapons with a filled soul gem when their charge drops to Charge Below. "
                           .. "It uses regular soul gems before Crown soul gems.",
                    getFunc = function() return SV().gearAutoCharge end,
                    setFunc = function(val)
                        SV().gearAutoCharge = val
                        Gear:RefreshCare()
                    end,
                },
                {
                    type     = "slider",
                    name     = "Charge Below",
                    min      = 1, max = 99, step = 1,
                    default  = defaults.gearChargeBelow,
                    tooltip  = "Default is " .. defaults.gearChargeBelow .. ".",
                    details  = function()
                        return "Recharges a weapon when its charge drops to " .. SV().gearChargeBelow .. "% or lower."
                    end,
                    disabled = function() return not SV().gearAutoCharge end,
                    getFunc  = function() return SV().gearChargeBelow end,
                    setFunc  = function(val)
                        SV().gearChargeBelow = val
                        Gear:CareSoon()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Auto Bind",
                    preset  = "YES_NO",
                    default = defaults.gearAutoBind,
                    tooltip = "Binds new set pieces you haven't collected yet. Type /bindall to bind the ones already in your bags.",
                    getFunc = function() return SV().gearAutoBind end,
                    setFunc = function(val)
                        SV().gearAutoBind = val
                        Gear:RefreshCare()
                    end,
                },
                {
                    type     = "checklist",
                    name     = "Show In Chat",
                    choices  = Gear.logChoices,
                    default  = { "repair", "charge", "bind" },
                    tooltip  = "Tells you in chat when something is repaired, charged or bound.",
                    disabled = function()
                        local sv = SV()
                        return not (sv.gearAutoRepair or sv.gearMerchantRepair or sv.gearAutoCharge or sv.gearAutoBind)
                    end,
                    getFunc  = function()
                        local sv = SV()
                        local values = {}
                        for i = 1, #Gear.logChoices do
                            local value = Gear.logChoices[i].value
                            if sv[LOG_KEYS[value]] then values[#values + 1] = value end
                        end
                        return values
                    end,
                    setFunc  = function(values)
                        local sv = SV()
                        local set = {}
                        if type(values) == "table" then
                            for i = 1, #values do set[values[i]] = true end
                        end
                        for value, key in pairs(LOG_KEYS) do
                            sv[key] = set[value] == true
                        end
                    end,
                },
            },
        },
    }
    return self.settingOptions
end

function Gear:EquippedOptions()
    local options = {}
    AddSection(options, "Armor", ARMOR)
    AddSection(options, "Jewelry", JEWELRY)
    AddSection(options, "Front Bar", FRONT)
    AddSection(options, "Back Bar", BACK)
    return options
end

function Gear:BuildPageOptions()
    local options = {}
    local settings = self:SettingOptions()
    for i = 1, #settings do options[#options + 1] = settings[i] end
    options[#options + 1] = {
        type    = "submenu",
        name    = "Equipped Items",
        tooltip = "Everything you have equipped right now. Highlight an item to see its details.",
        options = function() return Gear:EquippedOptions() end,
    }
    self.pageOptions = options
    self.dirty = false
    return options
end

function Gear:PageOptions()
    if self.dirty or not self.pageOptions then
        return self:BuildPageOptions()
    end
    return self.pageOptions
end

function Gear:GetOptions()
    if not self.submenu then
        self.submenu = {
            type    = "submenu",
            name    = "Gear",
            icon    = SUBMENU_ICON,
            tooltip = "Shows your equipped sets on screen, keeps your gear repaired, charged and bound, "
                   .. "and lists everything you have equipped.",
            options = function() return Gear:PageOptions() end,
        }
    end
    return { self.submenu }
end

function Gear:OnSettingsState(newState)
    if newState == SCENE_HIDDEN then
        self.dirty = true
        self.pageOptions = nil
        if self.preview then self:SetPreview(false) end
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
local function OnWornChanged()
    Gear:QueueRefresh()
end

function Gear:Init()
    MigrateCare()
    self:CreatePanel()
    self:RegisterScenes()
    self:ApplyPosition()
    local name = ME.name .. "_Gear"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornChanged)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function() Gear:QueueRefresh() end)
    self:RefreshCare()
end

function Gear:OnPlayerActivated()
    self.dirty = true
    self:Refresh()
    self:CareSoon()
end

function Gear:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.gearUseCharacter == true) == value then return end
    cv.gearUseCharacter = value
    self:ApplyPosition()
    self:Render()
    self:UpdateVisibility()
    self:RefreshCare()
    RefreshPanelPages()
end

function Gear:ResetSkipKeys()
    local keys = careScope:ResetSkipKeys()
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do
            if not CARE_KEYS[key] then keys[#keys + 1] = key end
        end
    end
    return keys
end

function Gear:OnReset()
    self.preview = false
    careScope:ResetCharacter()
    if self:UsesCharacterSettings() then
        local settings = CharSettings()
        if settings then
            for key, value in pairs(self.defaults) do
                if type(value) == "table" then
                    local copy = {}
                    for k, v in pairs(value) do copy[k] = v end
                    settings[key] = copy
                else
                    settings[key] = value
                end
            end
            settings.seeded = true
        end
    end
    self:ApplyPosition()
    self:Render()
    self:UpdateVisibility()
    self:RefreshCare()
end

ME:RegisterFeature(Gear)

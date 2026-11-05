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
local TITLE_TEXT    = "Equipped Sets"
local REFRESH_MS    = 100
local MOVE_SPEED    = 500
local SCALE_SPEED   = 10
local SIZE_MIN      = 16
local SIZE_MAX      = 48
local MOVE_SCENE    = "MyExtras_GearMove"

Gear.defaults = {
    gearShow          = false,
    gearTitle         = true,
    gearFont          = "EsoUI/Common/Fonts/FTN57.otf",
    gearSize          = 24,
    gearCompleteStyle = "Alliance",
    gearCompleteColor = { r = 1, g = 1, b = 1, a = 1 },
    gearPartialStyle  = "Custom",
    gearPartialColor  = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
    gearPosX          = 60,
    gearPosY          = 520,
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

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return ME.savedVariables
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

    local title = WINDOW_MANAGER:CreateControl("MyExtras_GearTitle", panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    title:SetText(TITLE_TEXT)
    self.title = title
end

local function GetRow(index)
    local row = rows[index]
    if not row then
        row = WINDOW_MANAGER:CreateControl("MyExtras_GearRow" .. index, Gear.panel, CT_LABEL)
        rows[index] = row
    end
    return row
end

function Gear:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.gearPosX, sv.gearPosY)
end

function Gear:Render()
    if not self.panel then return end
    local sv = SV()
    local font = RowFont()
    local spacing = zo_floor(sv.gearSize * 1.3)
    local doneR, doneG, doneB = StyleColor(sv.gearCompleteStyle, sv.gearCompleteColor)
    local partR, partG, partB = StyleColor(sv.gearPartialStyle, sv.gearPartialColor)

    local y = 0
    local showTitle = sv.gearTitle == true
    self.title:SetHidden(not showTitle)
    if showTitle then
        self.title:SetFont(font)
        self.title:SetColor(1, 1, 1, 1)
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
        y = y + spacing
    end
    for i = #list + 1, #rows do
        rows[i]:SetHidden(true)
    end

    self.panel:SetDimensions(400, math.max(y, spacing))
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
Gear.mover = {}

function Gear.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        Gear:SetPosition(Gear.moveX + x * MOVE_SPEED * deltaS, Gear.moveY - y * MOVE_SPEED * deltaS)
    end
    local _, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if scaleY ~= 0 then
        Gear:SetScale(Gear.moveSize + scaleY * SCALE_SPEED * deltaS)
    end
end

Gear.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() Gear:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() Gear:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() Gear:EndMove(false) end,
    },
}

function Gear:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    self.moveX = zo_clamp(x, 0, screenW)
    self.moveY = zo_clamp(y, 0, screenH)
    local sv = SV()
    sv.gearPosX = zo_floor(self.moveX + 0.5)
    sv.gearPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPosition()
end

function Gear:SetScale(size)
    self.moveSize = zo_clamp(size, SIZE_MIN, SIZE_MAX)
    local rounded = zo_floor(self.moveSize + 0.5)
    local sv = SV()
    if sv.gearSize ~= rounded then
        sv.gearSize = rounded
        self:Render()
    end
end

function Gear:MoveToDefault()
    self:SetScale(self.defaults.gearSize)
    self:SetPosition(self.defaults.gearPosX, self.defaults.gearPosY)
end

function Gear:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            Gear:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            Gear:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function Gear:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function Gear:OnMoveShowing()
    local sv = SV()
    self.moving = true
    ME:RaiseWhilePlacing({ self.panel }, true)
    self.moveStartX, self.moveStartY = sv.gearPosX, sv.gearPosY
    self.moveStartSize = sv.gearSize
    self.moveX, self.moveY = sv.gearPosX, sv.gearPosY
    self.moveSize = sv.gearSize
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self.panel)
    ME:SetPlacing(true)
    self:Render()
    self:UpdateVisibility()
end

function Gear:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartSize)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    ME:RaiseWhilePlacing({ self.panel }, false)
    ME:SetPlacing(false)
    if self.movePreview then
        self.movePreview = false
        self:SetPreview(true)
    else
        self:Render()
        self:UpdateVisibility()
    end
end

function Gear:EndMove(save)
    if not self.moving then return end
    self.moveSaved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
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

    self.settingOptions = {
        {
            type    = "toggle",
            name    = "Show",
            preset  = "YES_NO",
            default = defaults.gearShow,
            tooltip = "Shows your equipped sets on screen.",
            getFunc = function() return SV().gearShow end,
            setFunc = function(val)
                SV().gearShow = val
                Gear:UpdateVisibility()
            end,
        },
        {
            type    = "toggle",
            name    = "Preview",
            tooltip = "Shows your sets here so you can see your changes. "
                   .. "Stays on until you turn it off or leave the settings.",
            getFunc = function() return Gear.preview end,
            setFunc = function(val) Gear:SetPreview(val) end,
        },
        {
            type       = "button",
            name       = "Move / Scale",
            buttonText = "Move / Scale",
            tooltip    = "Move it with the left stick and scale it with the right stick.",
            func       = function() Gear:StartMove() end,
        },
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
    }
    return self.settingOptions
end

function Gear:BuildPageOptions()
    local options = {}
    local settings = self:SettingOptions()
    for i = 1, #settings do options[#options + 1] = settings[i] end
    AddSection(options, "Armor", ARMOR)
    AddSection(options, "Jewelry", JEWELRY)
    AddSection(options, "Front Bar", FRONT)
    AddSection(options, "Back Bar", BACK)
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
            tooltip = "Shows your equipped sets on screen and lists everything this character has equipped, "
                   .. "including both weapon bars.\n\n" .. ME.SAVED_ACCOUNT_TIP,
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
    self:CreatePanel()
    self:RegisterScenes()
    self:ApplyPosition()
    local name = ME.name .. "_Gear"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornChanged)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function() Gear:QueueRefresh() end)
end

function Gear:OnPlayerActivated()
    self.dirty = true
    self:Refresh()
end

function Gear:OnReset()
    self.preview = false
    self:ApplyPosition()
    self:Render()
    self:UpdateVisibility()
end

ME:RegisterFeature(Gear)

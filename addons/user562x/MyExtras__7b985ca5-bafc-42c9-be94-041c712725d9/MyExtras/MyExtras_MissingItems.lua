local ME = MyExtras
local QoL = ME.QualityOfLife
local MI = {}
ME.MissingItems = MI

--------------------------------------------------
-- Config
--------------------------------------------------
local GEAR_ICON  = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_locked_set_piece.dds"
local LEARN_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_can_learn.dds"
local RED_HEX    = "FF3333"
local RED        = { 1, 0.2, 0.2, 1 }
local ITEM_LINK  = "(|H%d:item:.-|h.-|h)"

local LIST_ICONS = {
    [GEAR_ICON]  = "miGear",
    [LEARN_ICON] = "miLearn",
    ["EsoUI/Art/Inventory/inventory_locked_set_piece_icon.dds"] = "miGear",
    ["EsoUI/Art/Inventory/inventory_can_learn_icon.dds"]        = "miLearn",
}

local DEFAULTS = {
    miEnabled = false,
    miGear    = true,
    miLearn   = true,
}
QoL:AddDefaults(DEFAULTS)

MI.typeChoices = {
    { name = "Set Items",       value = "miGear"  },
    { name = "Learnable Items", value = "miLearn" },
}

local TYPE_ICONS = {
    miGear  = GEAR_ICON,
    miLearn = LEARN_ICON,
}

local chatHooked = false
local listsHooked = false
local lootLogHooked = false
local entriesHooked = false
local wrappedFormatters = {}
local redTint

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function IsOn()
    return SV().miEnabled == true
end

local function Icon(path)
    return "|c" .. RED_HEX .. zo_iconFormatInheritColor(path, "100%", "100%") .. "|r"
end

local function RedTint()
    if not redTint and ZO_ColorDef then
        redTint = ZO_ColorDef:New(RED[1], RED[2], RED[3], RED[4])
    end
    return redTint
end

local function MissingIcon(itemLink)
    local sv = SV()
    if sv.miGear and IsItemLinkLockedSetPiece and IsItemLinkLockedSetPiece(itemLink) then
        return GEAR_ICON
    end
    if sv.miLearn and CanItemLinkBeUsedToLearn and CanItemLinkBeUsedToLearn(itemLink) then
        return LEARN_ICON
    end
    return nil
end

local function Annotate(text)
    if type(text) ~= "string" or not string.find(text, "|H", 1, true) then return text end
    return (string.gsub(text, ITEM_LINK, function(itemLink)
        local ok, icon = pcall(MissingIcon, itemLink)
        if ok and icon then return itemLink .. " " .. Icon(icon) end
        return itemLink
    end))
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

--------------------------------------------------
-- Chat
--------------------------------------------------
local function WrapFormatter(formatter)
    if type(formatter) ~= "function" or wrappedFormatters[formatter] then return formatter end
    local wrapped = function(...)
        local results = Pack(formatter(...))
        if results[1] ~= nil and IsOn() then
            local ok, text = pcall(Annotate, results[1])
            if ok then results[1] = text end
        end
        return unpack(results, 1, results.n)
    end
    wrappedFormatters[wrapped] = true
    return wrapped
end

local function HookChat()
    if chatHooked then return end
    local router = CHAT_ROUTER
    if not (router and router.GetRegisteredMessageFormatters and router.RegisterMessageFormatter) then return end
    local formatters = router:GetRegisteredMessageFormatters()
    if type(formatters) ~= "table" then return end
    chatHooked = true
    for eventKey, formatter in pairs(formatters) do
        formatters[eventKey] = WrapFormatter(formatter)
    end
    local register = router.RegisterMessageFormatter
    router.RegisterMessageFormatter = function(self, eventKey, formatter, ...)
        return register(self, eventKey, WrapFormatter(formatter), ...)
    end
end

--------------------------------------------------
-- Lists
--------------------------------------------------
local function TintFor(iconTexture)
    local key = LIST_ICONS[iconTexture]
    if not key or not IsOn() or not SV()[key] then return nil end
    return RedTint()
end

local function WrapMultiIcon(control)
    if not control or control.myExtrasTinted or type(control.AddIcon) ~= "function" then return end
    local addIcon = control.AddIcon
    control.AddIcon = function(self, iconTexture, iconTint, ...)
        local ok, tint = pcall(TintFor, iconTexture)
        if ok and tint then iconTint = tint end
        return addIcon(self, iconTexture, iconTint, ...)
    end
    control.myExtrasTinted = true
end

local function HookLists()
    if listsHooked or type(ZO_MultiIcon_Initialize) ~= "function" then return end
    listsHooked = true
    SecurePostHook(_G, "ZO_MultiIcon_Initialize", WrapMultiIcon)
end

--------------------------------------------------
-- Entries
--------------------------------------------------
local function MarkEntry(itemData)
    if type(itemData) ~= "table" or itemData.bagId ~= nil or not IsOn() then return end
    local itemLink = itemData.itemLink
    if type(itemLink) ~= "string" or itemLink == "" then return end
    local sv = SV()
    if sv.miGear and not itemData.isLockedSetPiece and IsItemLinkLockedSetPiece and IsItemLinkLockedSetPiece(itemLink) then
        itemData.isLockedSetPiece = true
    end
    if sv.miLearn and not itemData.canBeUsedToLearn and CanItemLinkBeUsedToLearn and CanItemLinkBeUsedToLearn(itemLink) then
        itemData.canBeUsedToLearn = true
    end
end

local function HookEntries()
    if entriesHooked or not (ZO_GamepadEntryData and ZO_GamepadEntryData.InitializeInventoryVisualData) then return end
    entriesHooked = true
    ZO_PreHook(ZO_GamepadEntryData, "InitializeInventoryVisualData", function(_, itemData)
        pcall(MarkEntry, itemData)
        return false
    end)
end

--------------------------------------------------
-- Loot Log
--------------------------------------------------
local function LootLogKey(history, statusIcon)
    if type(history.GetLockedSetPieceIcon) == "function" and statusIcon == history:GetLockedSetPieceIcon() then
        return "miGear"
    end
    if type(history.GetCanLearnIcon) == "function" and statusIcon == history:GetCanLearnIcon() then
        return "miLearn"
    end
    return nil
end

local function RecolorLootEntry(history, lootData)
    if type(lootData) ~= "table" or not lootData.statusIcon or not IsOn() then return end
    local key = LootLogKey(history, lootData.statusIcon)
    if key and SV()[key] then lootData.statusIconColor = RedTint() end
end

local function HookLootLog()
    if lootLogHooked or not (ZO_LootHistory_Shared and ZO_LootHistory_Shared.CreateLootEntry) then return end
    lootLogHooked = true
    ZO_PreHook(ZO_LootHistory_Shared, "CreateLootEntry", function(history, lootData)
        pcall(RecolorLootEntry, history, lootData)
        return false
    end)
end

--------------------------------------------------
-- Menu
--------------------------------------------------
local function ChecklistValues(choices)
    local sv = SV()
    local values = {}
    for i = 1, #choices do
        local key = choices[i].value
        if sv[key] then values[#values + 1] = key end
    end
    return values
end

local function SaveChecklist(choices, values)
    local sv = SV()
    local set = {}
    if type(values) == "table" then
        for i = 1, #values do set[values[i]] = true end
    end
    for i = 1, #choices do
        local key = choices[i].value
        sv[key] = set[key] == true
    end
end

local function DefaultValues(choices)
    local values = {}
    for i = 1, #choices do
        local key = choices[i].value
        if DEFAULTS[key] then values[#values + 1] = key end
    end
    return values
end

function MI:SubmenuOption()
    local function IsOff() return not SV().miEnabled end
    return {
        type    = "submenu",
        name    = "Missing Items",
        tooltip = "Marks items you don't have yet with a red icon, in chat and in your lists.",
        options = {
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = DEFAULTS.miEnabled,
                tooltip = "Turns the game's missing-item icons red, and adds a red icon after item links in chat.",
                getFunc = function() return SV().miEnabled end,
                setFunc = function(val) SV().miEnabled = val end,
            },
            {
                type     = "checklist",
                name     = "Item Types",
                choices  = self.typeChoices,
                default  = DefaultValues(self.typeChoices),
                disabled = IsOff,
                tooltip  = "Which items count as missing.\n\n"
                        .. "Set Items: set pieces you haven't collected yet.\n"
                        .. "Learnable Items: recipes, motifs, style pages, runeboxes and anything else "
                        .. "you haven't learned yet.",
                details  = function()
                    local sv = SV()
                    local shown = {}
                    for i = 1, #MI.typeChoices do
                        local key = MI.typeChoices[i].value
                        if sv[key] then shown[#shown + 1] = Icon(TYPE_ICONS[key]) end
                    end
                    if #shown == 0 then return nil end
                    return table.concat(shown, "  ")
                end,
                getFunc  = function() return ChecklistValues(MI.typeChoices) end,
                setFunc  = function(values) SaveChecklist(MI.typeChoices, values) end,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function MI:Init()
    HookLists()
    HookEntries()
    HookLootLog()
    HookChat()
end

function MI:OnPlayerActivated()
    HookLists()
    HookEntries()
    HookLootLog()
    HookChat()
end

ME:RegisterFeature(MI)

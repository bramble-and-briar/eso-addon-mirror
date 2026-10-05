-- Skillbound_Marks.lua : a small amber dot on gear that one of your builds uses, in
-- the bag, the bank and the crafting stations' lists (so you don't sell or
-- deconstruct it by mistake). Hover the dot: which builds use it.
-- Also Skillbound.UsesItemLink(link) for other addons (Set Hunter asks it before it
-- calls a piece "safe to deconstruct").

local B = Skillbound
local L = B.L
local Items = B.Items
local Marks = {}
B.Marks = Marks

local marks = {}   -- row control name -> mark

-- true when a build uses this item or a copy of it (same item and trait)
function B.UsesItemLink(link)
    if not B.sv or not link or link == "" then return false end
    local used = Items.UsedByBuilds()
    local key = GetItemLinkItemId(link) .. ":" .. tostring(GetItemLinkTraitInfo(link))
    return used.byKey[key] == true
end

-- true when a build uses exactly this item
function B.UsesItem(bag, slot)
    local uid = Items.Uid(bag, slot)
    return uid ~= nil and Items.UsedByBuilds().byUid[uid] ~= nil
end

local function Mark(row)
    local name = row:GetName()
    local mark = marks[name]
    if not mark then
        mark = WINDOW_MANAGER:CreateControl(name .. "Skillbound", row, CT_TEXTURE)
        mark:SetTexture(B.TEX .. "disc.dds")
        mark:SetDimensions(9, 9)
        mark:SetDrawLayer(DL_OVERLAY)
        mark:SetAnchor(CENTER, row, LEFT, 28, -12)
        mark:SetMouseEnabled(true)
        mark:SetHandler("OnMouseEnter", function(self)
            if self.names then
                InitializeTooltip(InformationTooltip, self, RIGHT, -6, 0, LEFT)
                SetTooltipText(InformationTooltip, L("MARK_TT", table.concat(self.names, ", ")))
            end
        end)
        mark:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        marks[name] = mark
    end
    return mark
end

local function OnRowSetup(row)
    local data = row.dataEntry and row.dataEntry.data
    if not data or not data.bagId or not data.slotIndex then return end
    local names
    if B.sv.marks then
        local uid = Items.Uid(data.bagId, data.slotIndex)
        names = uid and Items.UsedByBuilds().byUid[uid]
    end
    local mark = marks[row:GetName()]
    if not names then
        if mark then mark:SetHidden(true) end
        return
    end
    mark = Mark(row)
    mark.names = names
    mark:SetColor(B.RGBA(B.COLOR.theme))
    mark:SetHidden(false)
end

local LISTS = {
    "ZO_PlayerInventoryBackpack", "ZO_PlayerBankBackpack", "ZO_HouseBankBackpack",
    "ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack",
    "ZO_SmithingTopLevelImprovementPanelInventoryBackpack",
    "ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack",
}

function Marks.Init()
    for _, name in ipairs(LISTS) do
        local list = _G[name]
        if list and list.dataTypes and list.dataTypes[1] and list.dataTypes[1].setupCallback then
            SecurePostHook(list.dataTypes[1], "setupCallback", function(row) OnRowSetup(row) end)
        end
    end
    B.callbacks:RegisterCallback("BuildsChanged", function()
        if PLAYER_INVENTORY and PLAYER_INVENTORY.RefreshAllInventorySlots then
            pcall(PLAYER_INVENTORY.RefreshAllInventorySlots, PLAYER_INVENTORY, INVENTORY_BACKPACK)
        end
    end)
end

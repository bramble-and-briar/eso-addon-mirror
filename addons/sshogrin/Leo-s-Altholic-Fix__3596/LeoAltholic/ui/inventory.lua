local LeoAltholic = LeoAltholic
LeoAltholic.InventoryList = ZO_SortFilterList:Subclass()
function LeoAltholic.InventoryList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
        ["bag"] = { tiebreaker = "name" },
        ["gold"] = { tiebreaker = "name" },
        ["soulgems"] = { tiebreaker = "name" },
        ["ap"] = { tiebreaker = "name" },
        ["telvar"] = { tiebreaker = "name" },
        ["writvouchers"] = { tiebreaker = "name" },
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicInventoryListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

local function formatNumber(amount)
    if amount == nil then return nil; end
    if type(amount) == "string" then amount = tonumber( amount ) end
    if type(amount) ~= "number" then return amount; end
    if amount < 1000 then return amount; end
    return FormatIntegerWithDigitGrouping( amount, GetString( SI_DIGIT_GROUP_SEPARATOR ) )
end

function LeoAltholic.InventoryList:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    local color = '|c'..LeoAltholic.color.hex.green
    if data.inventory.free <= 25 then color = '|c'..LeoAltholic.color.hex.orange end
    if data.inventory.free <= 10 then color = '|c'..LeoAltholic.color.hex.red end
    control.bag = GetControl(control, "Bag")
    control.bag:SetText(color .. data.inventory.used .. "|r / " .. data.inventory.size)

    control.soulgems = GetControl(control, "SoulGems")
    control.soulgems:SetText("|c" ..LeoAltholic.color.hex.green.. data.inventory.soulGemFilled .. '|r / ' .. data.inventory.soulGemEmpty)

    control.gold = GetControl(control, "Gold")
    control.gold:SetText(formatNumber(data.inventory.gold))

    control.ap = GetControl(control, "AP")
    control.ap:SetText(formatNumber(data.inventory.ap))

    control.telvar = GetControl(control, "TelVar")
    control.telvar:SetText(formatNumber(data.inventory.telvar))

    control.writVouchers = GetControl(control, "Writ")
    control.writVouchers:SetText(formatNumber(data.inventory.writVoucher))

    control.listButton = GetControl(control, "ListButton")
    control.listButton:SetHandler('OnClicked', function() LeoAltholic.ShowInventoryUI(data.name, BAG_BACKPACK) end)

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholic.InventoryList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child then
            if data.name == LeoAltholic.CharName then
                child:SetColor(r, g, b)
            else
                child:SetColor(color:UnpackRGBA())
            end
        end
    end
end

function LeoAltholic.InventoryList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child:GetType() == CT_LABEL and string.find(child:GetName(), 'Name$') then
            if data.name == LeoAltholic.CharName then
                child:SetColor(r, g, b)
            else
                child:SetColor(color:UnpackRGBA())
            end
        end
        if not child.nonRecolorable and child.number ~= nil then
            if child.number == child.max then
                child:SetColor(0, 1, 0, 1)
            elseif child.number > child.max * 0.8 then
                child:SetColor(1, 1, 0, 1)
            elseif child.number > child.max * 0.1 then
                child:SetColor(color:UnpackRGBA())
            else
                child:SetColor(1, 0, 0, 1)
            end
        end
    end
end

function LeoAltholic.InventoryList:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            inventory = v.inventory
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholic.InventoryList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholic.InventoryList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end

function LeoAltholic.UI.InitInventory()
    local panel = WINDOW_MANAGER:GetControlByName("LeoAltholicWindowInventoryPanel")
    local list = GetControl(panel, "ListScroll")

    local charTotalRow = WINDOW_MANAGER:CreateControlFromVirtual("LeoAltholicWindowInventoryPanelCharTotalRow", panel, "LeoAltholicInventoryListTemplate")
    charTotalRow:SetAnchor(TOPLEFT, list, BOTTOMLEFT, 20, 0)
    local control = GetControl(charTotalRow, "Name")
    control:SetText(ZO_CachedStrFormat(GetString(LEOALT_TOTAL_INVENTORY)))
    local gold = 0
    local soulGemFilled = 0
    local soulGemEmpty = 0
    local ap = 0
    local telvar = 0
    local writVoucher = 0
    for _, char in ipairs(LeoAltholic.ExportCharacters()) do
        gold = gold + char.inventory.gold
        ap = ap + char.inventory.ap
        telvar = telvar + char.inventory.telvar
        writVoucher = writVoucher + char.inventory.writVoucher
        soulGemFilled = soulGemFilled + char.inventory.soulGemFilled
        soulGemEmpty = soulGemEmpty + char.inventory.soulGemEmpty
    end
    GetControl(charTotalRow, "Gold"):SetText(formatNumber(gold))
    GetControl(charTotalRow, "AP"):SetText(formatNumber(ap))
    GetControl(charTotalRow, "TelVar"):SetText(formatNumber(telvar))
    GetControl(charTotalRow, "Writ"):SetText(formatNumber(writVoucher))
    control = GetControl(charTotalRow, "SoulGems")
    control:SetText("|c" ..LeoAltholic.color.hex.green.. soulGemFilled .. '|r / ' .. soulGemEmpty)
    GetControl(charTotalRow, "ListButton"):SetHidden(true)

    local bankRow = WINDOW_MANAGER:CreateControlFromVirtual("LeoAltholicWindowInventoryPanelBankRow", panel, "LeoAltholicInventoryListTemplate")
    bankRow:SetAnchor(TOPLEFT, list, BOTTOMLEFT, 20, 30)
    control = GetControl(bankRow, "Name")
    control:SetText(ZO_CachedStrFormat(GetString(SI_CURRENCYLOCATION1)))
    control = GetControl(bankRow, "ListButton")
    control:SetHandler('OnClicked', function() LeoAltholic.ShowInventoryUI(nil, BAG_BANK) end)

    local totalRow = WINDOW_MANAGER:CreateControlFromVirtual("LeoAltholicWindowInventoryPanelTotalRow", panel, "LeoAltholicInventoryListTemplate")
    totalRow:SetAnchor(TOPLEFT, list, BOTTOMLEFT, 20, 60)
    control = GetControl(totalRow, "Name")
    control:SetText(ZO_CachedStrFormat(GetString(LEOALT_TOTAL)))
    GetControl(totalRow, "ListButton"):SetHidden(true)

    GetControl(totalRow, "Gold"):SetText(formatNumber(gold + LeoAltholic.globalData.AccountData.inventory.money))
    GetControl(totalRow, "AP"):SetText(formatNumber(ap + LeoAltholic.globalData.AccountData.inventory.ap))
    GetControl(totalRow, "TelVar"):SetText(formatNumber(telvar + LeoAltholic.globalData.AccountData.inventory.telvar))
    GetControl(totalRow, "Writ"):SetText(formatNumber(writVoucher + LeoAltholic.globalData.AccountData.inventory.writVoucher))
    control = GetControl(totalRow, "SoulGems")
    control:SetText("|c" ..LeoAltholic.color.hex.green.. (soulGemFilled+LeoAltholic.globalData.AccountData.inventory.soulGemFilled)
            .. '|r / ' .. (soulGemEmpty+LeoAltholic.globalData.AccountData.inventory.soulGemEmpty))

    LeoAltholic.UI.UpdateInventory()
end

function LeoAltholic.UI.UpdateInventory()

    local data = LeoAltholic.globalData.AccountData
    local bankRow = WINDOW_MANAGER:GetControlByName("LeoAltholicWindowInventoryPanelBankRow")

    local free = data.inventory[BAG_BANK].free + data.inventory[BAG_SUBSCRIBER_BANK].free
    local used = data.inventory[BAG_BANK].used + data.inventory[BAG_SUBSCRIBER_BANK].used
    local size = data.inventory[BAG_BANK].size + data.inventory[BAG_SUBSCRIBER_BANK].size
    local color = '|c'..LeoAltholic.color.hex.green
    if free <= 25 then color = '|c'..LeoAltholic.color.hex.orange end
    if free <= 10 then color = '|c'..LeoAltholic.color.hex.red end
    control = GetControl(bankRow, "Bag")
    control:SetText(color .. used .. "|r / " .. size)

    control = GetControl(bankRow, "Gold")
    control:SetText(formatNumber(data.inventory.money))

    control = GetControl(bankRow, "SoulGems")
    if data.inventory.soulGemFilled ~= nil then
        control:SetText("|c" ..LeoAltholic.color.hex.green.. data.inventory.soulGemFilled .. '|r / ' .. data.inventory.soulGemEmpty)
    end

    control = GetControl(bankRow, "AP")
    control:SetText(formatNumber(data.inventory.ap))

    control = GetControl(bankRow, "TelVar")
    control:SetText(formatNumber(data.inventory.telvar))

    control = GetControl(bankRow, "Writ")
    control:SetText(formatNumber(data.inventory.writVoucher))
end

---@diagnostic disable: undefined-field, inject-field -- Native gamepad controls and entry data expose additional runtime methods and fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocContentsHeader
---@field titleText string|nil
---@field subtitleText string|nil

---@class InventoryPocContentsTrigger
---@field name fun(): string|nil
---@field keybind string
---@field callback fun()
---@field ethereal boolean

---@class InventoryPocContentsPanel
---@field control Control
---@field header Control
---@field headerData InventoryPocContentsHeader
---@field list ZO_ParametricScrollList
---@field triggers InventoryPocContentsTrigger[]
---@field active boolean
---@field entry InventoryPocLogEntry|nil
local ContentsPanel = {}
ContentsPanel.__index = ContentsPanel
BattleScrolls.inventoryPocContents = ContentsPanel

---@param control Control
---@return InventoryPocContentsPanel
function ContentsPanel.new(control)
    local content = control:GetNamedChild('Content')
    local self = setmetatable({ control = control, active = false, triggers = {}, headerData = {} }, ContentsPanel)
    self.header = content:GetNamedChild('HeaderContainer'):GetNamedChild('Header')
    ZO_GamepadGenericHeader_Initialize(self.header, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE)
    self.list = ZO_GamepadVerticalItemParametricScrollList:New(content:GetNamedChild('List'))
    self.list:SetAlignToScreenCenter(true)
    self.list:AddDataTemplate('ZO_GamepadItemSubEntryTemplate', function(row, data, selected, reselecting, enabled, active)
        row:GetNamedChild('Label').templateFullWidth = math.max(1, content:GetWidth() - ZO_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT)
        ZO_SharedGamepadEntry_OnSetup(row, data, selected, reselecting, enabled, active)
    end,
        ZO_GamepadMenuEntryTemplateParametricListFunction)
    self.list:SetOnSelectedDataChangedCallback(function() self:showTooltip() end)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.triggers, self.list)
    SCREEN_NARRATION_MANAGER:RegisterParametricList(self.list, {
        canNarrate = function() return self.active and not self.control:IsControlHidden() end,
        headerNarrationFunction = function() return ZO_GamepadGenericHeader_GetNarrationText(self.header, self.headerData) end,
        narrationType = NARRATION_TYPE_UI_SCREEN,
    })
    return self
end

function ContentsPanel:showTooltip()
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_QUAD3_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
    if self.control:IsControlHidden() then return end
    local data = self.list:GetTargetData()
    local item = data and data.reward
    if not item then return end
    if item.currencyType then
        GAMEPAD_TOOLTIPS:LayoutCurrency(GAMEPAD_QUAD3_TOOLTIP, item.currencyType, item.quantity)
    elseif item.questItemId and item.questItemId > 0 then
        GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_QUAD3_TOOLTIP, item.questItemId)
    elseif item.antiquityId and item.antiquityId > 0 then
        GAMEPAD_TOOLTIPS:LayoutAntiquityLead(GAMEPAD_QUAD3_TOOLTIP, item.antiquityId)
    elseif item.tributePatronId and item.tributeCardIndex then
        local patron = TRIBUTE_DATA_MANAGER:GetTributePatronData(item.tributePatronId)
        if patron then
            local _, cardId = patron:GetDockCardInfoByIndex(item.tributeCardIndex)
            if cardId then
                ---@diagnostic disable-next-line: redundant-parameter -- The native constructor forwards both IDs to Initialize(patronDefId, cardDefId).
                local card = ZO_TributeCardData:New(item.tributePatronId, cardId)
                GAMEPAD_TOOLTIPS:LayoutTributeCard(GAMEPAD_QUAD3_TOOLTIP, card)
            end
        end
    elseif item.link and item.link ~= '' then
        if item.lootType == LOOT_TYPE_COLLECTIBLE then
            GAMEPAD_TOOLTIPS:LayoutCollectibleFromLink(GAMEPAD_QUAD3_TOOLTIP, item.link)
        else
            GAMEPAD_TOOLTIPS:LayoutItemWithStackCountSimple(GAMEPAD_QUAD3_TOOLTIP, item.link, item.quantity)
            ZO_LayoutItemLinkEquippedComparison(GAMEPAD_RIGHT_TOOLTIP, item.link)
        end
    else
        GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_QUAD3_TOOLTIP, item.name,
            BattleScrolls.inventoryPoc.formatLoot(item))
    end
end

---@param entry InventoryPocLogEntry
function ContentsPanel:show(entry)
    local selected = self.entry == entry and self.list:GetTargetData()
    local selectedIndex = 1
    self.entry = entry
    self.control:SetHidden(false)
    self.headerData = { titleText = GetString(BATTLESCROLLS_IPOC_CONTENTS),
        subtitleText = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(entry.itemLink)) }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    self.list:Clear()
    for index, item in ipairs(entry.contents or {}) do
        local name = item.currencyType and GetCurrencyName(item.currencyType, IsCountSingularForm(item.quantity), false) or item.name
        local data = ZO_GamepadEntryData:New(name, item.icon)
        data:InitializeLootVisualData(nil, item.quantity, item.quality, nil, item.questItemId ~= nil, item.stolen, item.lootType)
        data.reward, data.stolen = item, item.stolen
        self.list:AddEntry('ZO_GamepadItemSubEntryTemplate', data)
        if selected and selected.reward == item then selectedIndex = index end
    end
    self.list:Commit()
    self.list:SetSelectedIndexWithoutAnimation(selectedIndex)
    self:showTooltip()
end

---@param active boolean
function ContentsPanel:setActive(active)
    if self.active == active then return end
    self.active = active
    if active then
        self.list:Activate()
        KEYBIND_STRIP:AddKeybindButtonGroup(self.triggers)
    else
        self.list:Deactivate()
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.triggers)
    end
end

function ContentsPanel:hide()
    self:setActive(false)
    self.control:SetHidden(true)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_QUAD3_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
end

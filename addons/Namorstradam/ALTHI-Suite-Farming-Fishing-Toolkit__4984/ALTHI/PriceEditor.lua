local A = ALTHarvestItems
local function L(key) return A:T(key) end
function A:OpenPriceEditor(id)
    if not id then return end
    if not self.priceEditor then
        local window = WINDOW_MANAGER:CreateTopLevelWindow("ALTHIPriceEditor")
        window:SetDimensions(590, 220); window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        window:SetMouseEnabled(true); window:SetMovable(true); window:SetClampedToScreen(true)
        self:Backdrop(window)
        window.title = self:Label(window, "ZoFontWinH2")
        window.title:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 16); window.title:SetWidth(510)
        local help = self:Label(window)
        help:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 55)
        help:SetDimensions(550, 36); help:SetMaxLineCount(2); help:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        help:SetText(L("CUSTOM_GROSS_UNIT_PRICE_IN_GOLD_EMPTY_AUTOMATIC_SOURCE"))
        local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
        bg:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 92); bg:SetDimensions(550, 34)
        bg:SetCenterColor(0.12, 0.18, 0.14, 1)
        window.edit = WINDOW_MANAGER:CreateControl("ALTHIPriceEdit", window, CT_EDITBOX)
        window.edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 8, 2); window.edit:SetDimensions(534, 30)
        window.edit:SetFont("ZoFontGame"); window.edit:SetMaxInputChars(16); window.edit:SetMouseEnabled(true)
        self:EnableEdit(window.edit)
        window.edit:SetHandler("OnEscape",function() self:CloseDialog(window) end)
        self:CloseIcon(window)
        window:SetHandler("OnHide",function() window.edit:LoseFocus() end)
        local save = self:Button(window, L("SAVE"), 130, function()
            if self:SetManualPrice(window.itemId, window.edit:GetText()) then
                window.edit:LoseFocus(); self:CloseDialog(window); self:RefreshSettings()
            else self:Say(L("ENTER_A_VALID_NUMBER_OF_ZERO_OR_MORE_OR_LEAVE_BLANK")) end
        end)
        save:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 18, -18)
        local cancel = self:Button(window, L("CANCEL"), 130, function()
            window.edit:LoseFocus(); self:CloseDialog(window)
        end)
        cancel:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -18)
        self.priceEditor = window
    end
    local editor = self.priceEditor
    editor.itemId = id
    editor.title:SetText(self.db.catalog[id].name .. " · ID " .. id)
    editor.edit:SetText(self.db.manualPrices[id] ~= nil and tostring(self.db.manualPrices[id]) or "")
    ClearTooltip(ItemTooltip)
    self:ShowDialog(editor); editor.edit:TakeFocus()
    local _, source = self:Price(id)
    self:Say(L("CURRENT_PRICE_SOURCE") .. source)
end

GridBagsGoldUI = {}
local U = GridBagsGoldUI
local G = GridBagsGold
local UI = GridBagsRoutingUI

local function Amount(value)
    if value == nil then return "not observed" end
    return string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function U:IsEditing()
    return self.window ~= nil and not self.window:IsHidden()
end

function U:Message(text)
    self.status:SetText(text)
    d("GridBags gold: " .. text)
end

function U:Load(id)
    self.character = id
    local p = G:Profile(id)
    self.enabled, self.mode, self.frequency = p.enabled, p.mode, p.frequency
    self.refill = p.refill ~= false
    self.characterButton:SetText("Character: " .. GridBagsRouting:Name(id))
    for key, edit in pairs(self.edits) do
        local value = key == "bankReserve" and (G.data.bankReserve or 0) or p[key]
        edit:SetText(value ~= nil and tostring(value) or "")
    end
    self.status:SetText("Save applies at the next bank opening. Once preapproves one eligible move within these limits; Standing continues until revoked.")
    self.preview:SetText("")
    local hold = G.data.holds[id]
    if hold and hold.operation then
        local op = hold.operation
        local change = op.direction == "deposit" and -op.amount or op.amount
        self.preview:SetText(string.format("Held %s of %s gold\nExpected carried: %s > %s\nExpected bank: %s > %s\nInspect the real balances before clearing this hold.",
            op.direction, Amount(op.amount), Amount(op.beforeChar), Amount(op.beforeChar + change), Amount(op.beforeBank), Amount(op.beforeBank - change)))
    end
    self:Update()
end

function U:Spec()
    local p = { enabled = self.enabled, mode = self.mode, frequency = self.frequency, refill = self.refill }
    for key, edit in pairs(self.edits) do
        if key ~= "bankReserve" then p[key] = edit:GetText() end
    end
    return p
end

function U:Preview()
    local p, err = G:ValidateProfile(self:Spec())
    local reserve = tonumber(self.edits.bankReserve:GetText())
    if not p then self:Message(err); return end
    if not reserve or reserve < 0 or reserve ~= math.floor(reserve) then self:Message("Bank reserve must be a whole nonnegative amount."); return end
    local carried, bank, context
    if self.character == G.character then carried = GridBagsSnapshots:ReadGold(false) end
    if G:IsBanking() then bank = GridBagsSnapshots:ReadGold(true) end
    local record = GridBagsSnapshots.records[self.character]
    if carried == nil then carried = record and record.gold end
    if bank == nil then
        local saved = G.owner.saved.bankSnapshots[GetWorldName()]
        bank = saved and saved.gold
    end
    context = self.character == G.character and G:IsBanking() and "Live balances" or "Includes saved balances; preview only"
    local op, reason = G:Compute(self.character, p, carried, bank, reserve)
    if not op then self.preview:SetText(context .. "\nCarried: " .. Amount(carried) .. " | Bank: " .. Amount(bank) .. "\n" .. reason); return end
    local change = op.direction == "deposit" and -op.amount or op.amount
    self.preview:SetText(string.format("%s\n%s %s gold — %s\nCarried: %s > %s\nBank: %s > %s", context,
        op.direction, Amount(op.amount), op.reason, Amount(carried), Amount(carried + change), Amount(bank), Amount(bank - change)))
end

function U:Update()
    if not self.window or not G.data then return end
    self.enabledButton:SetText(self.enabled and "Gold rule: enabled" or "Gold rule: disabled")
    self.modeButton:SetText("Approval: " .. (self.mode or "ask"))
    self.frequencyButton:SetText(self.frequency == "daily" and "Fixed deposit: daily" or "Fixed deposit: per bank visit")
    self.refillButton:SetText(self.refill ~= false and "Refill min: ON" or "Refill min: off")
    local hold = G.data.holds[self.character]
    self.releaseButton:SetHidden(not hold)
    local visit = G.data.visit
    self.review:SetText(hold and hold.reason or (visit and visit.character == self.character and visit.reason) or "")
    local op = G.current
    self.confirm:SetHidden(not op or not G:IsBanking() or not G.owner:IsSupportedScene() or self:IsEditing() or GridBagsRoutingUI.editingSession == true or GridBagsActivity:IsPaused())
    if op then
        local change = op.direction == "deposit" and -op.amount or op.amount
        self.confirmText:SetText(string.format("%s %s gold\n%s\nCarried: %s > %s\nBank: %s > %s\nOne gold operation for this bank opening.",
            op.direction, Amount(op.amount), op.reason, Amount(op.beforeChar), Amount(op.beforeChar + change),
            Amount(op.beforeBank), Amount(op.beforeBank - change)))
    end
end

function U:Close()
    if not self.window then return end
    for _, edit in pairs(self.edits) do edit:LoseFocus() end
    self.window:SetHidden(true); self:Update()
end

function U:Show()
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    if GridBagsProtectionUI then GridBagsProtectionUI:Close() end
    if GridBagsDeliveryUI then GridBagsDeliveryUI:Close() end
    if G.pending then d("GridBags: wait for the current gold transfer to settle."); return end
    G.owner:ReleaseSearchFocus(); UI:Close()
    self:Load(G.character)
    self.window:SetHidden(false); self:Update()
end

function U:Initialize(owner)
    self.window = UI.MakeFrame("GridBagsGoldRules", 780, 800)
    UI.MakeLabel(self.window, "GOLD RULES", 20, 12, 600, "ZoFontWinH2")
    UI.MakeButton(self.window, "Close", 660, 12, 100, function() self:Close() end)
    self.characterButton = UI.MakeButton(self.window, "Character", 20, 55, 500, function(c)
        UI:Characters(c, function(id) self:Load(id) end, false)
    end)
    self.refillButton = UI.MakeButton(self.window, "Refill min: ON", 540, 55, 200, function()
        self.refill = self.refill == false; self:Update()
    end)
    self.edits = {
        min = UI.MakeEdit(self.window, "Carried minimum", 20, 105, 0),
        max = UI.MakeEdit(self.window, "Carried maximum", 400, 105, ""),
        fixed = UI.MakeEdit(self.window, "Fixed deposit", 20, 150, 0),
        threshold = UI.MakeEdit(self.window, "Deposit only above", 400, 150, 0),
        cap = UI.MakeEdit(self.window, "Per-move cap (0: none)", 20, 195, 0),
        bankReserve = UI.MakeEdit(self.window, "Shared bank reserve", 400, 195, 0),
        unitsLeft = UI.MakeEdit(self.window, "Gold allowance left", 20, 240, ""),
        movesLeft = UI.MakeEdit(self.window, "Move allowance left", 400, 240, ""),
        resetHour = UI.MakeEdit(self.window, "Daily reset hour (UTC)", 20, 330, 0),
    }
    for _, edit in pairs(self.edits) do edit:SetMaxInputChars(12) end
    self.frequencyButton = UI.MakeButton(self.window, "Frequency", 20, 285, 340, function(c)
        ClearMenu()
        AddMenuItem("Per bank visit", function() self.frequency = "visit"; ClearMenu(); self:Update() end)
        AddMenuItem("Once daily at an eligible bank visit", function() self.frequency = "daily"; ClearMenu(); self:Update() end)
        ShowMenu(c)
    end)
    self.modeButton = UI.MakeButton(self.window, "Approval", 400, 285, 340, function(c)
        ClearMenu()
        local labels = { ask = "Ask before each eligible move", once = "Preapprove one eligible move, then Ask",
            limited = "Use allowance, then Ask", standing = "Standing approval until disabled" }
        for _, name in ipairs({ "ask", "once", "limited", "standing" }) do
            local mode = name
            AddMenuItem(labels[mode], function() self.mode = mode; ClearMenu(); self:Update() end)
        end
        ShowMenu(c)
    end)
    self.enabledButton = UI.MakeButton(self.window, "Enabled", 400, 330, 340, function()
        self.enabled = not self.enabled; self:Update()
    end)
    local help = UI.MakeLabel(self.window, "Minimum refills a shortfall; maximum deposits excess (blank disables it). Daily applies to the fixed deposit; min/max apply each visit. Fixed deposits require the full amount above the minimum and threshold. Reasons combine into one move. Blank allowance = unlimited; 0 = exhausted.", 20, 375, 740, "ZoFontGameSmall")
    help:SetDimensions(740, 72)
    self.saveButton = UI.MakeButton(self.window, "Save gold rule", 20, 460, 210, function()
        local p, err = G:SaveProfile(self.character, self:Spec(), self.edits.bankReserve:GetText())
        self:Message(p and "Saved. Close and reopen the banker to evaluate this rule. Gold moves only while banking on this character." or err)
    end)
    self.previewButton = UI.MakeButton(self.window, "Preview these values", 250, 460, 240, function() self:Preview() end)
    self.preview = UI.MakeLabel(self.window, "", 20, 510, 740); self.preview:SetDimensions(740, 130)
    self.status = UI.MakeLabel(self.window, "", 20, 640, 740); self.status:SetDimensions(740, 60)
    self.review = UI.MakeLabel(self.window, "", 20, 705, 740); self.review:SetDimensions(740, 42)
    self.releaseButton = UI.MakeButton(self.window, "Balances checked: clear hold and require Ask", 20, 755, 500, function()
        local ok, err = G:ReleaseHold(self.character)
        if ok then self:Load(self.character) else self:Message(err) end
    end)
    UI.MakeButton(self.window, "History / tools", 540, 755, 200, function() GridBagsToolsUI:Show("history") end)
    self.confirm = UI.MakeFrame("GridBagsGoldConfirmation", 720, 360)
    UI.MakeLabel(self.confirm, "CONFIRM GOLD TRANSFER", 20, 12, 680, "ZoFontWinH2")
    self.confirmText = UI.MakeLabel(self.confirm, "", 20, 60, 680); self.confirmText:SetDimensions(680, 205)
    UI.MakeButton(self.confirm, "Confirm gold", 20, 305, 190, function() G:Confirm() end)
    UI.MakeButton(self.confirm, "Skip this visit", 225, 305, 190, function() G:Skip() end)
    UI.MakeButton(self.confirm, "Gold rules...", 430, 305, 250, function() self:Show() end)
end

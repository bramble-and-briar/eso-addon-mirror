local C = CrownCrateCodex
local PAGE_SIZE, COLUMN_WIDTH, ROW_HEIGHT = 6, 206, 96
local GOLD, MUTED = "|cE7C877", "|cAEB8C5"
local MISSING = "EsoUI/Art/Icons/icon_missing.dds"

local function Label(parent, name, x, y, width, height, font)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetFont(font or "ZoFontGame")
    control:SetMaxLineCount(10)
    return control
end
local function Button(parent, name, text, x, y, width, callback)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    button:SetDimensions(width, 30)
    button:SetFont("ZoFontGameBold")
    button:SetNormalFontColor(0.91, 0.8, 0.52, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    button:SetText(C.L(text))
    if C.FitLocalizedLabel then C:FitLocalizedLabel(button) end
    button:SetHandler("OnClicked", callback)
    C.fontButtons=C.fontButtons or {}
    C.fontButtons[#C.fontButtons+1]=button
    if C.RegisterGamepadTarget then
        C:RegisterGamepadTarget(button,callback,function()
            if button.codexDescription then return button.codexDescription end
            local label=button.GetLabelControl and button:GetLabelControl() or button
            return label.GetText and label:GetText() or text
        end)
    end
    return button
end
local function Backdrop(parent, alpha)
    local bg = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    bg:SetAnchorFill(parent)
    bg:SetCenterColor(0.025, 0.035, 0.05, alpha or 0.96)
    bg:SetEdgeColor(0.5, 0.41, 0.25, 0.75)
    bg:SetEdgeTexture("", 1, 1, 1)
    return bg
end
C.UI = { Label = Label, Button = Button, Backdrop = Backdrop }

local function Icon(parent, x, y, size)
    local icon = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    icon:SetDimensions(size, size)
    return icon
end
local function Tooltip(control, callback)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(target)
        local text = callback()
        if text then C:ShowTooltip(target,text) end
    end)
    control:SetHandler("OnMouseExit", function() C:HideTooltip() end)
end
local function Percent(n, total)
    return total > 0 and string.format("%.2f%%", n * 100 / total) or "--"
end
C.Percent = Percent
local function Date(timestamp)
    -- Use the game's date formatting; the explicitly labelled clock is UTC.
    local seconds = timestamp % 86400
    return GetDateStringFromTimestamp(timestamp) .. string.format("  %02d:%02d UTC", math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
end
local function Crates()
    local result = {}
    for _, crate in pairs(C.db.crates) do result[#result + 1] = crate end
    table.sort(result, function(a, b) if a.name == b.name then return a.id < b.id end; return a.name < b.name end)
    return result
end

function C:RewardDescription(reward)
    return string.format("%s x%d\n%s / %s / %s%s\n%s\n%s",
        reward.name, reward.stack, reward.typeText or "", C.RewardRarityName(reward), C.RewardTierName(reward),
        reward.bonus and C.L(" / BONUS CARD") or "", reward.catalogSource and (C.L("Verified catalog: ") .. reward.catalogSource .. "\n"..C.L("ESO's original internal tier ID was not recorded by Tracker.")) or reward.tierSource and C.L("Tier matched to a live reward from this same crate and quantity.") or "", C.L("Click to see this reward's observed rate in the statistics panel.")) .. (reward.productType==MARKET_PRODUCT_TYPE_COLLECTIBLE and ("\n"..self:ActionHint(C.L("Right-click to open in Collections."))) or "") .. self:ItemGemHint(reward)
end

function C:CycleCrate(direction)
    local crates, position = Crates(), 0
    for i, crate in ipairs(crates) do if crate.id == self.crateFilter then position = i; break end end
    position = (position + direction) % (#crates + 1)
    self.crateFilter, self.page, self.selectedReward = crates[position] and crates[position].id, 1, nil
    self:RefreshUI()
end

function C:CreateUI()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("CrownCrateCodexWindow")
    self.window = window
    self.view, self.page, self.query, self.rewardPage = "History", 1, "", 1
    window:SetDimensions(1820,930)
    window:SetAnchor(RIGHT, GuiRoot, RIGHT, -20, 0)
    window:SetScale(math.min(1,GuiRoot:GetWidth()/1860,GuiRoot:GetHeight()/970))
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    C:SetWindowHidden(window,true)
    window:SetHandler("OnHide",function() self:HideTooltip(); self:HideChoiceMenu() end)
    self.windowBackdrop=Backdrop(window,self.db.settings.backgroundOpacity/100)
    window:SetHandler("OnMouseDown",function() self:RaiseWindow() end)
    Label(window, nil, 22, 16, 1120, 38, "ZoFontWinH1"):SetText(GOLD .. "CROWN CRATE CODEX|r"..(self.world and ("  |c69D6FF"..(self.world=="NA Megaserver" and "PC_NA" or self.world=="EU Megaserver" and "PC_EU" or self.world).."|r") or ""))
    self.accountNameLabel=Label(window,nil,430,18,480,36,"ZoFontWinH2")
    self.accountNameLabel:SetMaxLineCount(1)
    self.accountNameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.importResultLabel=Label(window,nil,930,20,480,30,"ZoFontGame")
    self.importResultLabel:SetMaxLineCount(1)
    Button(window, nil, C.L("Close"), 1725, 20, 75, function() C:SetWindowHidden(window,true) end)
    Button(window,nil,C.L("Keybindings"),1440,20,130,function() self:OpenKeybindings() end)
    self.settingsButton=Button(window,nil,C.L("Settings"),1580,20,120,function() self:OpenSettings() end)
    self.settingsButton.codexDescription=C.L("Language, appearance, controller options, and statistics preferences.")
    Tooltip(self.settingsButton,function() return self.settingsButton.codexDescription end)
    for index, view in ipairs({ "History", "Reward rates", "Codex", "Status" }) do
        local name = view
        Button(window, nil, name, 22 + (index - 1) * 150, 65, 140, function()
            self.view, self.page = name, 1
            self:RefreshUI()
        end)
    end
    Button(window, nil, C.L("Export CSV"), 945, 65, 150, function() self:ShowExport() end)
    self.allCratesButton = Button(window, nil, C.L("SHOW ALL CRATES"), 22, 112, 190, function() self.crateFilter = nil; self.page = 1; self.selectedReward = nil; self:RefreshUI() end)
    Backdrop(self.allCratesButton, 0.9)
    self.crateButton=Button(window,nil,C.L("Select Crate Type"),222,112,338,function() self:ShowCrateMenu() end)
    self.crateButton:SetNormalFontColor(0.41,0.84,1,1)
    Backdrop(self.crateButton,0.8)
    Label(window, nil, 566, 115, 50, 26):SetText(C.L("Find:"))
    self.textSizeButton = Button(window, nil, "", 620, 65, 130, function()
        local nextSize = {Compact="Large",Large="Extra Large",["Extra Large"]="Compact"}
        self:SetDisplaySize(nextSize[self.db.settings.displaySize] or "Large")
    end)
    local searchBG = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
    searchBG:SetAnchor(TOPLEFT, window, TOPLEFT, 620, 110)
    searchBG:SetDimensions(480, 34)
    Backdrop(searchBG)
    local search=WINDOW_MANAGER:CreateControlFromVirtual("CrownCrateCodexSearch",searchBG,"ZO_DefaultEditForBackdrop")
    self.searchBox=search
    search:ClearAnchors()
    search:SetAnchor(TOPLEFT, searchBG, TOPLEFT, 8, 4)
    search:SetDimensions(464, 26)
    search:SetFont("ZoFontGame")
    search:SetMouseEnabled(true)
    search:SetEditEnabled(true)
    search:SetHandler("OnMouseDown",function(control) control:TakeFocus() end)
    searchBG:SetMouseEnabled(true)
    searchBG:SetHandler("OnMouseDown",function() search:TakeFocus() end)
    search:SetMaxInputChars(120)
    search:SetHandler("OnTextChanged", function(control)
        self.query, self.page = control:GetText(), 1
        self:RefreshUI()
    end)
    search:SetHandler("OnEscape", function(control) control:LoseFocus() end)
    search:SetHandler("OnFocusGained",function(control)
        if self.SyncGamepad and IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
            self.gamepadEditing=true; self:SyncGamepad()
            if ZO_GamepadEditBox_FocusGained then ZO_GamepadEditBox_FocusGained(control) end
        end
    end)
    search:SetHandler("OnFocusLost",function(control)
        if self.gamepadEditing and ZO_GamepadEditBox_FocusLost then ZO_GamepadEditBox_FocusLost(control) end
        self.gamepadEditing=false; if self.SyncGamepad then self:SyncGamepad() end
    end)
    search:SetHandler("OnEnter",function(control) control:LoseFocus() end)
    self.clearSearchButton=Button(window,nil,C.L("Clear"),1105,112,100,function() search:SetText(""); search:LoseFocus() end)
    self.summary = Label(window, nil, 22, 153, 650, 24, "ZoFontGameSmall")
    self.categoryButton = Button(window,nil,C.L("All reward types"),700,150,500,function() self:ShowCategoryMenu() end)
    Button(window, nil, C.L("Opening / date"), 22, 180, 156, function() self.oldestFirst = not self.oldestFirst; self:RefreshUI() end)
    self.columnLabels = {}
    for i = 1, 5 do self.columnLabels[i] = Label(window, nil, 190 + (i - 1) * COLUMN_WIDTH, 183, 180, 25, "ZoFontGameBold") end
    self.rows = {}
    for index = 1, PAGE_SIZE do
        local row = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
        row:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 214 + (index - 1) * ROW_HEIGHT)
        row:SetDimensions(1200, ROW_HEIGHT - 4)
        Backdrop(row, index % 2 == 0 and 0.45 or 0.18)
        row.icon = Icon(row, 5, 5, 34)
        row.crateName = Label(row, nil, 44, 4, 113, 40, "ZoFontGameSmall")
        row.date = Label(row, nil, 5, 46, 152, 35, "ZoFontGameSmall")
        row.text = Label(row, nil, 12, 4, 1170, 33, "ZoFontGameBold")
        row.detail = Label(row, nil, 12, 39, 1170, 37, "ZoFontGame")
        row.cells = {}
        for column = 1, 5 do
            local cell = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
            cell:SetAnchor(TOPLEFT, row, TOPLEFT, 170 + (column - 1) * COLUMN_WIDTH, 3)
            cell:SetDimensions(COLUMN_WIDTH - 4, 76)
            cell.icon = Icon(cell, 2, 4, 32)
            cell.name = Label(cell, nil, 40, 1, 138, 48, "ZoFontGameSmall")
            cell.name:SetMaxLineCount(3)
            cell.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            cell.quantity = Label(cell, nil, 2, 42, 178, 30, "ZoFontGameSmall")
            Tooltip(cell, function() return cell.reward and self:RewardDescription(cell.reward) end)
            cell:SetHandler("OnMouseWheel",function(_,delta) self:ScrollRows(delta) end)
            cell:SetHandler("OnMouseUp", function(_, button, inside)
                if inside and button == MOUSE_BUTTON_INDEX_RIGHT and cell.reward then
                    self:OpenCollectible(cell.reward)
                elseif inside and button == MOUSE_BUTTON_INDEX_LEFT and cell.reward then
                    self.crateFilter, self.page = cell.crateId, 1
                    self.selectedReward = C.RewardKey(cell.reward)
                    self:RefreshUI()
                end
            end)
            row.cells[column] = cell
            if self.RegisterGamepadTarget then
                self:RegisterGamepadTarget(cell,function()
                    local handler=cell:GetHandler("OnMouseUp"); if handler then handler(cell,MOUSE_BUTTON_INDEX_LEFT,true) end
                end,nil,function() return cell.reward end)
            end
        end
        Tooltip(row, function() return row.tooltip end)
        row:SetHandler("OnMouseWheel",function(_,delta) self:ScrollRows(delta) end)
        row:SetHandler("OnMouseUp", function(_, button, inside)
            if inside and button == MOUSE_BUTTON_INDEX_RIGHT and row.reward then
                self:OpenCollectible(row.reward)
            elseif inside and button == MOUSE_BUTTON_INDEX_LEFT then
                if row.opening then
                    self.crateFilter, self.page, self.selectedReward = row.opening.crateId, 1, nil
                    self:RefreshUI()
                elseif row.wishKey then
                    self.db.wishes[row.wishKey] = not self.db.wishes[row.wishKey] or nil
                    self:RefreshUI()
                end
            end
        end)
        self.rows[index] = row
        if self.RegisterGamepadTarget then
            local function Activate() local handler=row:GetHandler("OnMouseUp"); if handler then handler(row,MOUSE_BUTTON_INDEX_LEFT,true) end end
            local function Details() return row.tooltip or ((row.text:GetText() or "").."\n"..(row.detail:GetText() or "")) end
            self:RegisterGamepadTarget(row.crateName,Activate,Details)
            self:RegisterGamepadTarget(row.text,Activate,Details,function() return row.reward end)
        end
    end
    Button(window, nil, C.L("< Previous"), 22, 820, 125, function() self:MoveRows(-1) end)
    self.pageLabel = Label(window, nil, 172, 824, 220, 24)
    Button(window, nil, C.L("Next >"), 380, 820, 100, function() self:MoveRows(1) end)
    self.previousCardsButton=Button(window,nil,C.L("< Cards"),710,820,110,function() self.rewardPage=math.max(1,self.rewardPage-1); self:RefreshUI(true) end)
    self.nextCardsButton=Button(window,nil,C.L("Cards >"),920,820,110,function() self.rewardPage=math.min(self.rewardPages,self.rewardPage+1); self:RefreshUI(true) end)
    self.browseModeButton=Button(window,nil,"",500,820,190,function() self:SetBrowseMode(self.db.settings.browseMode=="Pages" and "Scrolling" or "Pages") end)
    self.helpLabel=Label(window,nil,22,870,1200,28,"ZoFontGame")
    self.helpLabel:SetText(C.L("Left-click: rate. ")..self:ActionHint(C.L("Right-click collectible: Collections."))..C.L(" Filters do not change rate denominators."))
    self.scrollBar=WINDOW_MANAGER:CreateControl(nil,window,CT_SLIDER)
    self.scrollBar:SetAnchor(TOPLEFT,window,TOPLEFT,1220,214)
    self.scrollBar:SetDimensions(16,580)
    self.scrollBar:SetOrientation(ORIENTATION_VERTICAL)
    self.scrollBar:SetMouseEnabled(true)
    self.scrollBar:SetValueStep(1)
    local thumb="EsoUI/Art/Miscellaneous/scrollbox_elevator.dds"
    self.scrollBar:SetThumbTexture(thumb,thumb,thumb,16,36,0,0,1,1)
    self.scrollBar:SetHandler("OnValueChanged",function(_,value)
        if not self.updatingScrollBar and self.db.settings.browseMode=="Scrolling" then self.scrollOffset=math.floor(value+0.5); self:RefreshUI(true) end
    end)
    self.scrollBar:SetHandler("OnMouseWheel",function(_,delta) self:ScrollRows(delta) end)
    self:CreateStatsPanel()
    if self.WatchGamepadWindow then self:WatchGamepadWindow(window) end
end

function C:BuildRows()
    if self.view == "Status" then return self:StatusRows() end
    if self.view == "History" then
        local rows = self:HistoryRows(self.query, self.crateFilter)
        if self.oldestFirst then
            local reversed = {}
            for index = #rows, 1, -1 do reversed[#reversed + 1] = rows[index] end
            return reversed
        end
        return rows
    end
    local rows, query = {}, C.Lower(self.query or "")
    for _, crate in ipairs(Crates()) do
        if not self.crateFilter or crate.id == self.crateFilter then
            local stats = self:Statistics(crate.id, self.sessionOnly and self.view == "Reward rates", self.view == "Codex")
            for key, entry in pairs(stats.rewards) do
                local r = entry.reward
                local wishKey = crate.id .. ":" .. key
                local text = r.name .. " " .. crate.name .. " " .. (r.typeText or "") .. " " .. C.RewardRarityName(r) .. " " .. C.RewardTierName(r)
                if self:RewardCategoryMatches(r) and (query == "" or string.find(C.Lower(text), query, 1, true)) then
                    local owned = ""
                    if r.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE and IsCollectibleUnlocked then owned = IsCollectibleUnlocked(r.referenceId) and C.L(" / Collected") or C.L(" / Not collected") end
                    rows[#rows + 1] = {
                        heading = (self.db.wishes[wishKey] and C.L("[WISH] ") or "") .. r.name .. owned,
                        detail = self.view == "Codex" and string.format(C.L("%s / %s / %d observed cards / %d units (including imports)"), crate.name, C.RarityName(r.rarity), entry.cards, entry.units)
                            or string.format(C.L("%s / %s / %s of openings (%d / %d) / %d cards / %d units"), crate.name, C.RarityName(r.rarity), Percent(entry.openings, stats.openings), entry.openings, stats.openings, entry.cards, entry.units),
                        tooltip = text .. "\n\n"..C.L("Left-click: wishlist. Right-click a collectible: Collections."), wishKey = wishKey, reward=r,
                    }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.heading .. a.detail < b.heading .. b.detail end)
    return rows
end

function C:RefreshUI(navigationOnly)
    if not self.window then return end
    self:HideTooltip()
    self:ApplyReadability()
    local rows=navigationOnly and self.cachedRows or self:BuildRows()
    rows=rows or self:BuildRows()
    self.cachedRows=rows
    local context=table.concat({self.view,self.query or "",tostring(self.crateFilter),tostring(self.categoryFilter),self.db.settings.displaySize,self.db.settings.browseMode},":")
    if context~=self.browseContext then self.scrollOffset=0; self.browseContext=context end
    local maxCards = 5
    if self.view == "History" then for _, row in ipairs(rows) do maxCards = math.max(maxCards, #row.rewards) end end
    self.rewardPages = math.ceil(maxCards / 5)
    self.rewardPage = math.min(self.rewardPage, self.rewardPages)
    self.previousCardsButton:SetHidden(self.view~="History" or self.rewardPages<=1)
    self.nextCardsButton:SetHidden(self.view~="History" or self.rewardPages<=1)
    local cardOffset = (self.rewardPage - 1) * 5
    for i, label in ipairs(self.columnLabels) do label:SetText(self.view == "History" and string.format(C.L("Reward %d"),i + cardOffset) or "") end
    local crate = self.crateFilter and self.db.crates[self.crateFilter]
    self.crateButton:SetText(crate and crate.name or C.L("Select Crate Type"))
    self.summary:SetText(string.format(C.L("%s / %d records / Slots %d-%d"), C.L(self.view), #rows, cardOffset+1,cardOffset+5))
    self.importResultLabel:SetText(self.importSummary or "")
    self.categoryButton:SetText(self.categoryFilterName or C.L("All reward types"))
    self.allCratesButton:SetText(self.crateFilter and C.L("SHOW ALL CRATES") or C.L("ALL CRATES SHOWN"))
    self.totalPages = math.max(1, math.ceil(#rows / self.pageSize))
    self.page = math.min(self.page, self.totalPages)
    self.maxScrollOffset=math.max(0,#rows-self.pageSize)
    self.scrollOffset=math.max(0,math.min(self.maxScrollOffset,self.scrollOffset or 0))
    local scrolling=self.db.settings.browseMode=="Scrolling"
    self.browseModeButton:SetText(scrolling and C.L("View: Scrolling") or C.L("View: Pages"))
    self.pageLabel:SetText(scrolling and string.format(C.L("Rows %d-%d / %d"),#rows>0 and self.scrollOffset+1 or 0,math.min(#rows,self.scrollOffset+self.pageSize),#rows) or string.format(C.L("Page %d / %d"),self.page,self.totalPages))
    self.updatingScrollBar=true
    self.scrollBar:SetMinMax(0,self.maxScrollOffset)
    self.scrollBar:SetValue(self.scrollOffset)
    self.scrollBar:SetHidden(not scrolling or self.maxScrollOffset==0)
    self.updatingScrollBar=false
    local offset=scrolling and self.scrollOffset or (self.page-1)*self.pageSize
    for i, control in ipairs(self.rows) do
        local row=i<=self.pageSize and rows[offset+i] or nil
        control:SetHidden(not row)
        control.opening, control.wishKey, control.tooltip, control.reward = nil, nil, nil, nil
        local history = self.view == "History"
        control.icon:SetHidden(not history)
        control.crateName:SetHidden(not history)
        control.date:SetHidden(not history)
        control.text:SetHidden(history)
        control.detail:SetHidden(history)
        for column, cell in ipairs(control.cells) do
            local reward = row and history and row.rewards[column + cardOffset]
            cell.reward = reward
            cell.crateId = row and history and row.crateId or nil
            cell:SetHidden(not reward)
            if reward then
                cell.icon:SetTexture(reward.icon or reward.image or MISSING)
                cell.name:SetText(reward.name)
                cell.quantity:SetText(string.format("%sx%d / %s%s|r", MUTED, reward.stack, C.RewardRarityName(reward), reward.bonus and C.L(" / BONUS") or ""))
            end
        end
        if row and history then
            control.opening = row
            local crateData = self.db.crates[row.crateId]
            control.icon:SetTexture(crateData.icon or MISSING)
            control.crateName:SetText(crateData.name)
            control.idLabel:SetText("#" .. row.id .. (row.source == "tracker" and C.L(" Imported") or C.L(" Live")))
            control.date:SetText(GetDateStringFromTimestamp(row.timestamp))
            local details = {}
            for _,reward in ipairs(row.rewards) do
                details[#details+1]=string.format("%s x%d / %s%s",reward.name,reward.stack,C.RewardRarityName(reward),reward.bonus and C.L(" / BONUS") or "")
            end
            control.tooltip=crateData.name.."\n"..Date(row.timestamp).."\n"..(row.source=="tracker" and C.L("Imported opening / hover each reward for tier provenance.") or C.L("Recorded by Codex")).."\n"..table.concat(details,"\n")
        elseif row then
            control.text:SetText(GOLD .. row.heading .. "|r")
            control.detail:SetText(row.detail)
            control.wishKey, control.tooltip, control.reward = row.wishKey, row.tooltip, row.reward
        end
    end
    if #rows == 0 then
        local first = self.rows[1]
        first:SetHidden(false)
        first.icon:SetHidden(true); first.crateName:SetHidden(true); first.date:SetHidden(true)
        first.idLabel:SetHidden(true)
        first.text:SetHidden(false); first.detail:SetHidden(false)
        first.text:SetText(C.L("No matching records"))
        first.detail:SetText(C.L("Clear the search, select All, or import your Tracker history."))
    end
    if not navigationOnly then self:RefreshStats() end
    if self.FitLocalizedLabel then
        for _,button in ipairs(self.fontButtons or {}) do self:FitLocalizedLabel(button) end
        for _,label in ipairs(self.columnLabels) do self:FitLocalizedLabel(label) end
    end
    if self.SyncGamepad then self:SyncGamepad() end
end

function C:ApplyReadability()
    local size = self.db.settings.displaySize
    local extra, large = size == "Extra Large", size ~= "Compact"
    self.pageSize = extra and 3 or large and 4 or PAGE_SIZE
    local height = extra and 194 or large and 146 or ROW_HEIGHT
    local font = extra and "$(MEDIUM_FONT)|22|soft-shadow-thin" or large and "ZoFontGame" or "ZoFontGameSmall"
    local iconSize = extra and 64 or large and 48 or 32
    local textX = extra and 72 or large and 54 or 40
    self.window:SetScale(math.min(self.db.settings.windowScale/100,GuiRoot:GetWidth()/1860,GuiRoot:GetHeight()/970))
    self.textSizeButton:SetText(extra and C.L("Text: XL") or large and C.L("Text: LARGE") or C.L("Text: Compact"))
    self.helpLabel:SetFont(font)
    self.helpLabel:SetDimensions(1200,52)
    self.helpLabel:SetMaxLineCount(2)
    self.helpLabel:SetText(C.L("Left-click: rate. ")..self:ActionHint(C.L("Right-click collectible: Collections."))..C.L(" Filters do not change rate denominators."))
    self.helpLabel:SetHidden(not self.db.settings.showHelp)
    local account=GetDisplayName and GetDisplayName() or self.profileAccount or ""
    self.accountNameLabel:SetText(self.db.settings.showAccountName and account~="" and ("|c69D6FF"..account.."|r") or "")
    self.accountNameLabel:SetHidden(not self.db.settings.showAccountName or account=="")
    self.summary:SetFont(font)
    self.importResultLabel:SetFont(font)
    self.summary:SetMaxLineCount(1)
    self.referenceLabel:SetFont(font)
    self.referenceLabel:SetDimensions(524,28)
    self.referenceLabel:SetHidden(not self.db.settings.showHelp and not self.db.settings.showOfficialReference)
    self.officialNoteLabel:SetFont(font)
    self.officialNoteLabel:SetHidden(not self.db.settings.showOfficialReference)
    self.windowBackdrop:SetCenterColor(0.025,0.035,0.05,self.db.settings.backgroundOpacity/100)
    for _,button in ipairs(self.fontButtons or {}) do button:SetFont(extra and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "ZoFontGameBold") end
    for _,label in ipairs(self.columnLabels) do label:SetFont(extra and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "ZoFontGameBold"); label:SetDimensions(180,28) end
    for index,row in ipairs(self.rows) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT,self.window,TOPLEFT,20,214+(math.min(index,self.pageSize)-1)*height)
        row:SetDimensions(1200,height-4)
        row.icon:SetDimensions(extra and 56 or large and 44 or 34,extra and 56 or large and 44 or 34)
        row.crateName:ClearAnchors(); row.crateName:SetAnchor(TOPLEFT,row,TOPLEFT,extra and 5 or large and 54 or 44,extra and 66 or 4)
        row.crateName:SetDimensions(extra and 152 or large and 103 or 113,extra and 66 or large and 90 or 48)
        row.crateName:SetFont(font)
        if not row.idLabel then row.idLabel=Label(row,nil,5,0,152,24,"ZoFontGame") end
        row.idLabel:ClearAnchors(); row.idLabel:SetAnchor(TOPLEFT,row,TOPLEFT,5,height-(extra and 60 or 50))
        row.idLabel:SetFont(font); row.idLabel:SetDimensions(152,extra and 28 or 24)
        row.idLabel:SetHidden(self.view~="History")
        row.date:ClearAnchors(); row.date:SetAnchor(TOPLEFT,row,TOPLEFT,5,height-(extra and 30 or 26))
        row.date:SetFont(font)
        row.date:SetDimensions(152,extra and 26 or 22)
        for _,cell in ipairs(row.cells) do
            cell:SetDimensions(COLUMN_WIDTH-4,height-10)
            cell.icon:SetDimensions(iconSize,iconSize)
            cell.name:ClearAnchors(); cell.name:SetAnchor(TOPLEFT,cell,TOPLEFT,textX,1)
            cell.name:SetDimensions(COLUMN_WIDTH-textX-8,extra and 126 or large and 92 or 52)
            cell.name:SetFont(font); cell.name:SetMaxLineCount(extra and 5 or large and 4 or 3)
            cell.quantity:ClearAnchors(); cell.quantity:SetAnchor(TOPLEFT,cell,TOPLEFT,2,extra and 136 or large and 98 or 56)
            cell.quantity:SetFont(font); cell.quantity:SetDimensions(COLUMN_WIDTH-8,extra and 48 or large and 38 or 30)
        end
    end
end
function C:Toggle()
    if not self.db then return end
    if not self.window then self:CreateUI() end
    if self.window:IsHidden() then self:Discover(); self:ImportAvailable(); self:RefreshUI(); self:SetWindowHidden(self.window,false); self:RaiseWindow()
    else self:SetWindowHidden(self.window,true) end
end

function C:AttachCrateScene()
    if self.sceneAttached or not CROWN_CRATE_KEYBOARD_SCENE then return end
    self.sceneAttached = true
    self.crateKeybind = {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT, order = -10,
        name = C.L("Codex history"), keybind = "CROWN_CRATE_CODEX_TOGGLE",
        callback = function() self:Toggle() end,
    }
    local function SceneChanged(_, state)
        if state == SCENE_SHOWN and not self.footerAdded then
            KEYBIND_STRIP:AddKeybindButton(self.crateKeybind)
            self.footerAdded = true
        elseif state ~= SCENE_SHOWN and self.footerAdded then
            KEYBIND_STRIP:RemoveKeybindButton(self.crateKeybind)
            self.footerAdded = false
        end
        if state == SCENE_HIDDEN then
            if self.window then self:SetWindowHidden(self.window,true) end
            if self.exportWindow then self:SetWindowHidden(self.exportWindow,true) end
        end
    end
    CROWN_CRATE_KEYBOARD_SCENE:RegisterCallback("StateChange", SceneChanged)
    if CROWN_CRATE_GAMEPAD_SCENE then CROWN_CRATE_GAMEPAD_SCENE:RegisterCallback("StateChange", SceneChanged) end
end

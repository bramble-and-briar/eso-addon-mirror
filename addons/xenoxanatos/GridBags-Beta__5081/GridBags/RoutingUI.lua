GridBagsRoutingUI = {}
local U = GridBagsRoutingUI
local WM = WINDOW_MANAGER
local R = GridBagsRouting

local function Label(parent, text, x, y, width, font)
    local c = WM:CreateControl(nil, parent, CT_LABEL)
    c:SetFont(font or "ZoFontGame"); c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 48); c:SetText(text); return c
end
local function Button(parent, text, x, y, width, fn)
    local c = WM:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    c:SetDimensions(width, 28); c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetText(text); c:SetHandler("OnClicked", fn); GridBagsHelp:Auto(c,text); return c
end
local function Frame(name, width, height)
    local c = WM:CreateTopLevelWindow(name)
    c:SetDimensions(width, height); c:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    c:SetDrawTier(DT_HIGH); c:SetMouseEnabled(true); c:SetHidden(true)
    local bg = WM:CreateControl(nil, c, CT_BACKDROP); bg:SetAnchorFill(c)
    bg:SetCenterColor(0.035, 0.04, 0.05, 0.99); bg:SetEdgeColor(0.5, 0.45, 0.3, 1)
    bg:SetEdgeTexture("", 1, 1, 1, 0)
    c:SetScale(math.min(1, (GuiRoot:GetWidth() - 60) / width, (GuiRoot:GetHeight() - 90) / height))
    return c
end
local function Edit(parent, label, x, y, value)
    Label(parent, label, x, y, 180)
    local bg = WM:CreateControl(nil, parent, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, parent, TOPLEFT, x + 184, y); bg:SetDimensions(100, 28)
    bg:SetCenterColor(0.12, 0.12, 0.14, 1); bg:SetEdgeColor(0.4, 0.4, 0.4, 1); bg:SetEdgeTexture("", 1, 1, 1, 0)
    local c = WM:CreateControlFromVirtual(nil, bg, "ZO_DefaultEditForBackdrop")
    c:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 2); c:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -6, -2)
    c:SetFont("ZoFontGame"); c:SetMouseEnabled(true); c:SetEditEnabled(true); c:SetMaxInputChars(9)
    c:SetText(tostring(value or 0)); c:LoseFocus()
    c:SetHandler("OnEscape", function(edit) edit:LoseFocus() end)
    c:SetHandler("OnEnter", function(edit) edit:LoseFocus() end)
    GridBagsHelp:Auto(c,label)
    return c
end

-- Share the native, focus-managed controls with the currency policy screen.
U.MakeFrame, U.MakeLabel, U.MakeButton, U.MakeEdit = Frame, Label, Button, Edit

function U:Characters(button, fn, includeBank, includeAny)
    ClearMenu()
    if includeAny then AddMenuItem("Any source (characters + account bank)",function()ClearMenu();fn(R.ANY)end)end
    if includeBank then AddMenuItem("Account bank", function() ClearMenu(); fn(R.BANK) end) end
    local entries, seen = {}, {}
    for id in pairs(GridBagsSnapshots.records) do entries[#entries + 1] = id; seen[id] = true end
    if not seen[R.character] then entries[#entries + 1] = R.character end
    table.sort(entries, function(a, b) return R:Name(a) < R:Name(b) end)
    for _, id in ipairs(entries) do
        local key = id
        AddMenuItem(R:Name(id), function() ClearMenu(); fn(key) end)
    end
    ShowMenu(button)
end

function U:Message(text)
    if self.message then self.message:SetText(text) end
    if self.editorMessage then self.editorMessage:SetText(text) end
    d("GridBags: " .. text)
end

function U:Mark(panel, item)
    if R.pending then self:Message("Wait for the current bank operation to settle."); return end
    if item.equipSlot ~= nil then self:Message("Equipped snapshots are read-only comparison context."); return end
    local selected = panel.key == "Backpack" and GridBagsSnapshots:GetSelected(GridBags)
    local source = panel.key == "Bank" and R.BANK or R.character
    local evidence
    if selected then
        source = GridBags.selectedCharacter == "@account-bank" and R.BANK or GridBags.selectedCharacter
        evidence = { link = item.link, name = item.displayName or item.name, qty = item.stack,
            uid = item.uid, maxStack = item.maxStack, bound = item.bound, observedAt = selected.updatedAt,
            blocked=item.locked or item.playerLocked or item.stolen }
    else
        local live = R:Read(item.bag, item.slot)
        if not live or live.uid ~= item.identity then self:Message("Item changed; refresh and mark it again."); return end
        evidence = live
    end
    if not evidence.uid or not evidence.maxStack then self:Message("Refresh this snapshot by visiting the character/bank before planning moves."); return end
    if self.replacingRule then
        local replacement = self.replacingRule; self.replacingRule = nil
        local rule = R:Rule(replacement.id)
        if not rule then self:Message("The rule no longer exists."); return end
        local spec = replacement.spec
        spec.source, spec.link, spec.name, spec.maxStack = source, evidence.link, evidence.name, evidence.maxStack
        spec.smart = nil
        self:EditRule(rule, spec)
        return
    end
    GridBags:ReleaseSearchFocus(); self:Close()
    self.editingRuleId = nil
    self.ruleKind = nil
    self.editing = { source = source, dest = source == R.BANK and R.character or R.BANK,
        link = evidence.link, name = evidence.name, qty = evidence.qty, available = evidence.qty,
        uid = evidence.uid, maxStack = evidence.maxStack or 1, bound = evidence.bound,blocked=evidence.blocked,
        observedAt = evidence.observedAt or GetTimeStamp(), mode = "ask" }
    self.editorTitle:SetText(evidence.name .. "\nFrom " .. R:Name(source) .. " | last observed " .. GetDateStringFromTimestamp(self.editing.observedAt))
    self.quantity:SetText(tostring(evidence.qty)); self.allowUnits:SetText("200"); self.allowMoves:SetText("3")
    self.bankStacks:SetText("3")
    self.editorMessage:SetText("")
    local guard = R:Protection(source, evidence.link)
    self.keep:SetText(tostring(guard.keep or 0)); self.never = guard.blocked == true
    self:UpdateEditor(); self.window:SetHidden(true); self.editor:SetHidden(false)
end

function U:UpdateEditor()
    if not self.editing then return end
    self.destination:SetText("To: " .. R:Name(self.editing.dest))
    self.approval:SetText("Approval: " .. self.editing.mode)
    self.neverButton:SetText(self.never and "Never export: ON" or "Never export: off")
    if self.deconstructButton then
        for kind,button in pairs({deconstruct=self.deconstructButton,research=self.researchButton})do
            local entries,reason=GridBagsGearRouting:Choices(self.editing,kind)
            button:SetEnabled(#entries>0)
            GridBagsHelp:Bind(button,(kind=="research"and "Send this item to a designated researcher who needs its trait. "or "Send this item to a designated crafter for later manual deconstruction. ")..(reason or "").." No item is consumed automatically.")
        end
    end
    self.keep:SetEditEnabled(self.editing.source ~= R.ANY)
    self.neverButton:SetEnabled(self.editing.source ~= R.ANY)
    if self.protectionButton then self.protectionButton:SetText(self.editing.source == R.ANY and "Open source protections"or "Save source protection")end
    local fixedLearningQuantity = self.editingRuleId ~= nil and self.ruleKind == "learning"
    self.quantity:SetEditEnabled(not fixedLearningQuantity)
    if fixedLearningQuantity then self.quantity:SetText("1"); self.quantity:LoseFocus() end
    if self.sourceButton then
        self.sourceButton:SetHidden(not self.editingRuleId)
        self.sourceButton:SetText("From: " .. R:Name(self.editing.source))
        self.kindButton:SetHidden(not self.editingRuleId)
        self.kindButton:SetText("Kind: " .. (self.ruleKind or "repeat"))
        self.replaceButton:SetHidden(not self.editingRuleId)
        self.enabledButton:SetHidden(not self.editingRuleId)
        self.enabledButton:SetText(self.editing.enabled == false and "Rule: paused" or "Rule: enabled")
        self.saveRuleButton:SetHidden(not self.editingRuleId)
        for _, button in ipairs(self.createButtons) do button:SetHidden(self.editingRuleId ~= nil) end
    end
end

function U:GearRecipients(button,kind)
    if not self.editing then return end
    local entries,reason=GridBagsGearRouting:Choices(self.editing,kind)
    if #entries==0 then self:Message(reason);self:UpdateEditor();return end
    ClearMenu()
    local ties=0
    for _,entry in ipairs(entries)do if entry.top then ties=ties+1 end end
    for _,entry in ipairs(entries)do
        local candidate=entry
        local label=(entry.top and (ties>1 and "Joint top: "or "Top verified: ")or "Researcher / crafter: ")..R:Name(entry.id)..
            string.format(" | rank %d, passives %d, priority %d",entry.rank,entry.points,entry.priority)
        AddMenuItem(label,function()
            self.editing.dest=candidate.id
            self.editing.smart=kind=="research"and {kind="research",craft=candidate.craft,profileResearch=true}or {kind="deconstruct",craft=candidate.craft}
            if kind=="research"then self.quantity:SetText("1")end
            ClearMenu();self:UpdateEditor();self:Message((kind=="research"and "Research"or "Deconstruction").." recipient selected: "..R:Name(candidate.id)..". Save a delivery; item use remains manual.")
        end)
    end
    ShowMenu(button)
end

function U:EditorSpec()
    local spec = {}; for key, value in pairs(self.editing) do spec[key] = value end
    spec.qty = tonumber(self.quantity:GetText())
    spec.units = self.allowUnits:GetText() ~= "" and self.allowUnits:GetText() or nil
    spec.moves = self.allowMoves:GetText() ~= "" and self.allowMoves:GetText() or nil
    spec.overflowStacks = tonumber(self.bankStacks:GetText())
    spec.editorKind = self.ruleKind
    return spec
end

function U:EditRule(rule, override)
    if rule.material then GridBagsCraftingUI:Edit(rule); return end
    if R.pending then self:Message("Wait for the current transfer to settle."); return end
    GridBags:ReleaseSearchFocus(); self:Close()
    self.editingRuleId = rule.id
    self.editingSession = true
    self.confirmWindow:SetHidden(true)
    if GridBagsGoldUI and GridBagsGoldUI.window then GridBagsGoldUI:Update() end
    self.editing = override or { source = rule.source, dest = rule.dest, link = rule.link, name = rule.name,
        qty = rule.maxPerStack, maxStack = rule.maxStack, mode = rule.mode, units = rule.unitsLeft,
        moves = rule.movesLeft, overflowStacks = rule.overflowStacks, strategy = rule.strategy,
        smart = rule.smart, enabled = rule.enabled }
    local spec = self.editing
    self.ruleKind = spec.editorKind or (spec.strategy and "learning" or (spec.overflowStacks ~= nil and "overflow" or "repeat"))
    self.editorTitle:SetText(spec.name)
    self.quantity:SetText(tostring(spec.qty)); self.allowUnits:SetText(spec.units ~= nil and tostring(spec.units) or "")
    self.allowMoves:SetText(spec.moves ~= nil and tostring(spec.moves) or "")
    self.bankStacks:SetText(tostring(spec.overflowStacks or 3))
    local guard = R:Protection(spec.source, spec.link)
    self.keep:SetText(tostring(guard.keep or 0)); self.never = guard.blocked == true
    self.editorMessage:SetText("Transfers pause while editing. Change source, recipient, item, kind, quantity, approval or remaining allowances. Existing deposits retain their original destination and require review.")
    self:UpdateEditor(); self.window:SetHidden(true); self.editor:SetHidden(false)
end

function U:Save(kind)
    if not self.editing then return end
    local spec = self:EditorSpec()
    if self.editingRuleId then kind = self.ruleKind end
    if kind ~= "learning" then spec.strategy = nil end
    spec.overflow = kind == "overflow"; spec.overflowStacks = tonumber(self.bankStacks:GetText())
    local protected, protectionError = true,nil
    if spec.source ~= R.ANY then protected, protectionError = R:SetProtection(spec.source, spec.link, self.never, self.keep:GetText(), true) end
    if not protected then self:Message(protectionError); return end
    local result, err
    if kind == "learning" then
        local lib = LibCharacterKnowledge
        if GridBagsSmartRouting:ResearchKey(spec.link) then spec.strategy = "research"
        elseif lib and lib.GetItemCategory and lib.GetItemCategory(spec.link) ~= lib.ITEM_CATEGORY_NONE then spec.strategy = "recipe"
        else self:Message("Character Knowledge has no supported recipe/research classification for this item."); return end
        spec.dest = "@learners"; spec.qty = 1; spec.smart = nil
        if self.editingRuleId then result, err = R:UpdateRule(self.editingRuleId, spec)
        else result, err = R:AddRule(spec) end
    elseif kind == "once" then
        if spec.source == R.BANK then
            local record = GridBagsSnapshots:GetSelected(GridBags)
            local total
            if record and GridBags.selectedCharacter == "@account-bank" then
                total = 0; for _, item in ipairs(record.items) do if item.link == spec.link then total = total + item.stack end end
            elseif R:IsBanking() then total = R:Total(R:Scan(R.BANK), spec.link) end
            if not total or (spec.qty or 0) > total - R:Reserved(spec.link) then
                self:Message("Not enough unreserved bank stock in the observed inventory."); return
            end
        end
        result, err = R:Add(spec)
    elseif self.editingRuleId then result, err = R:UpdateRule(self.editingRuleId, spec)
    else result, err = R:AddRule(spec) end
    if not result then self:Message(err); return end
    if spec.source ~= R.ANY then R:SetProtection(spec.source, spec.link, self.never, self.keep:GetText()) end
    self:Close(); self.editing = nil; self.editingRuleId = nil; self.window:SetHidden(false)
    self:Message("Saved. New work is evaluated at the next personal-bank opening.")
    self:Update(R)
end

function U:Profiles(button)
    self:Characters(button, function(id)
      EVENT_MANAGER:RegisterForUpdate("GridBagsProfileMenu", 1, function()
        EVENT_MANAGER:UnregisterForUpdate("GridBagsProfileMenu")
        if self.window:IsHidden() then return end
        local profile = R.data.profiles[id] or { priority = 100 }
        R.data.profiles[id] = profile
        ClearMenu()
        for _, role in ipairs({ "crafter", "researcher", "learner", "overflow" }) do
            local name = role
            AddMenuItem(name .. (profile[name] and ": ON" or ": off"), function()
                profile[name] = not profile[name]; ClearMenu(); self:Message("Profile role updated; transfer approvals are unchanged.")
            end)
        end
        for _, priority in ipairs({1,2,3,5,10,20,50,100}) do
            local value = priority
            AddMenuItem("Priority " .. value .. (profile.priority == value and " (selected)" or ""), function()
                profile.priority = value; ClearMenu(); self:Message("Profile priority saved. Lower numbers are served first.")
            end)
        end
        ShowMenu(button)
      end)
    end, false)
end

function U:Suggestions(button)
    local spec = self.editing
    if not spec then return end
    local M = GridBagsSmartRouting
    ClearMenu()
    if M:CraftRequirement(spec.link) then AddMenuItem("Suggest highest qualified designated crafter", function()
        local id, err, requirement, reason = M:Crafter(spec.link, spec.source)
        if id then spec.dest = id; spec.smart = requirement; self:UpdateEditor(); self:Message(reason)
        else self:Message(err) end
        ClearMenu()
    end) end
    local lib = LibCharacterKnowledge
    local recipe = lib and lib.GetItemCategory and lib.GetItemCategory(spec.link)
    local kinds = {}
    local materialEntries, materialSupported = GridBagsCrafting:RecipientSuggestions(spec.link, spec.source)
    for _, entry in ipairs(materialEntries) do
        local target, craft, scope = entry.id, entry.craft, entry.scope
        local label = (entry.lead and "Lead " or "Qualified ") .. GridBagsCrafting.names[craft] .. ": " .. R:Name(target) ..
            (entry.cross and " (cross-profession known recipe; manual approval)"or (scope == "known" and " (known recipe ingredients)" or " (usable material)"))
        AddMenuItem(label, function()
            spec.dest=target; spec.smart={kind="materials",craft=craft,scope=scope}
            ClearMenu(); self:UpdateEditor()
        end)
    end
    if materialSupported and #materialEntries == 0 then
        AddMenuItem("No qualified material recipient; check profession roles, usable tiers and fresh recipe scans",function() end)
    end
    if recipe and recipe ~= lib.ITEM_CATEGORY_NONE then kinds[#kinds + 1] = "recipe" end
    if M:ResearchKey(spec.link) then kinds[#kinds + 1] = "research" end
    for _, kind in ipairs(kinds) do
        local strategy = kind
        local entries, noData = M:Learners(spec.link, spec.source, strategy == "research")
        for _, entry in ipairs(entries) do
            local id = entry.id
            local evidence=strategy=="research"and entry.rank and string.format("rank %d, passives %d, priority %d",entry.rank,entry.points,entry.priority)or ("priority "..entry.priority)
            AddMenuItem("Missing " .. strategy .. ": " .. R:Name(id) .. " (" .. evidence .. ")", function()
                spec.dest = id; spec.smart = { kind = strategy }; self.quantity:SetText("1")
                ClearMenu(); self:UpdateEditor()
            end)
        end
        if noData then AddMenuItem(strategy .. ": some profiles have missing/stale data; held for review", function() end) end
        if #entries == 0 and not noData then
            AddMenuItem("No eligible " .. strategy .. " learner. Set profiles; known items and existing copies/plans are excluded.", function()
                self:Message("Use Planner > Profiles to designate learners/researchers. Only confirmed missing knowledge without an existing copy or delivery is suggested.")
            end)
        end
    end
    if #kinds == 0 and not materialSupported and not M:CraftRequirement(spec.link) then
        AddMenuItem("No supported smart recipient for this item; choose a destination manually", function() end)
    end
    for id, profile in pairs(R.data.profiles) do
        if profile.overflow and id ~= spec.source then
            local target = id
            AddMenuItem("Backstock profile: " .. R:Name(target), function()
                spec.dest = target; spec.smart = nil; ClearMenu(); self:UpdateEditor()
            end)
        end
    end
    ShowMenu(button)
end

function U:EntryMenu(button, entry, isRule)
    ClearMenu()
    AddMenuItem(isRule and "Explain this rule..." or "Delivery details...",function()
        ClearMenu()
        if isRule then GridBagsDeliveryUI:Explain(entry)
        else GridBagsDeliveryUI:Details("DELIVERY DETAILS",GridBagsRoutingInsights:DeliveryDetails(entry))end
    end)
    if R.pending then ShowMenu(button);return end
    if isRule then
        AddMenuItem("Edit complete rule...", function() ClearMenu(); self:EditRule(entry) end)
        AddMenuItem("Delete rule (retain existing bank deliveries for review)", function()
            local ok, err = R:DeleteRule(entry.id)
            ClearMenu(); self:Message(ok and "Rule deleted. Unstarted batches cancelled; existing bank deliveries preserved for review." or err)
            self:Update(R)
        end)
        AddMenuItem(entry.enabled and "Pause / revoke automatic approval" or "Enable rule", function()
            local before=R:RuleSnapshot(entry)
            entry.enabled = not entry.enabled; ClearMenu(); self:Update(R)
            R:RecordRuleChange("EDITED",before,entry)
        end)
        AddMenuItem("Ask on every move", function()
            local before=R:RuleSnapshot(entry)
            entry.mode = "ask"
            R.confirmAll = false
            for _, p in ipairs(R.data.plans) do if p.rule == entry.id and (p.state == "source" or p.state == "bank") then p.mode = "ask"; p.approved = nil end end
            ClearMenu(); self:Update(R)
            R:RecordRuleChange("EDITED",before,entry)
        end)
        AddMenuItem("Standing approval until revoked", function()
            local before=R:RuleSnapshot(entry)
            entry.mode = "standing"
            for _, p in ipairs(R.data.plans) do if p.rule == entry.id and (p.state == "source" or p.state == "bank") then p.mode = "standing" end end
            ClearMenu(); self:Update(R)
            R:RecordRuleChange("EDITED",before,entry)
        end)
    else
        if entry.state == "source" or entry.state == "bank" then
            AddMenuItem("Approve this complete route in advance", function() R:Approve(entry.id); ClearMenu(); self:Update(R) end)
            AddMenuItem("Revoke advance approval; ask for next step", function() entry.approved = nil;entry.recipeConsent=nil; entry.mode = "ask"; ClearMenu(); self:Update(R) end)
        end
        AddMenuItem("Cancel plan / release its reservation (does not undo moves)", function()
            local ok, err = R:Cancel(entry.id); if not ok then self:Message(err) end
            if ok and entry.rule then self:Message("Batch cancelled. Pause its repeat rule too if you want to stop future matching batches.") end
            ClearMenu(); self:Update(R)
        end)
    end
    ShowMenu(button)
end

function U:Update(routing)
    if not self.window then return end
    local entries = {}
    local planNumber = 0
    for _, p in ipairs(routing.data.plans) do
        if p.state ~= "done" and p.state ~= "cancelled" then
            planNumber = planNumber + 1; entries[#entries + 1] = { value = p, number = planNumber }
        end
    end
    for number, rule in ipairs(routing.data.rules) do entries[#entries + 1] = { value = rule, rule = true, number = number } end
    self.page = math.max(0, math.min(self.page or 0, math.max(0, math.ceil(#entries / 6) - 1)))
    for i, row in ipairs(self.rows) do
        local entry = entries[self.page * 6 + i]
        row.button:SetHidden(not entry); row.label:SetHidden(not entry)
        if entry then
            local p = entry.value
            row.button:SetText(entry.rule and ("Rule " .. entry.number) or ("Plan " .. entry.number))
            row.button:SetHandler("OnClicked", function(c) self:EntryMenu(c, p, entry.rule) end)
            GridBagsHelp:Bind(row.button,entry.rule and
                ("Click for Explain this rule, edit, pause or delete. Priority group: "..GridBagsRoutingInsights.stages[R:RulePriority(p)]..". "..(p.reason or "Open the explanation for processing order, overlap examples and a read-only preview.")) or
                ("Click for delivery details or cancellation. "..GridBagsRoutingInsights:Reason(p)))
            local state = entry.rule and (p.enabled and "repeat: " .. p.mode or "paused") or p.state
            local amount = entry.rule and p.maxPerStack or p.remaining
            local ruleDetails = entry.rule and (p.mode == "limited" and
                ("allowance " .. tostring(p.unitsLeft or "unlimited") .. " units / " .. tostring(p.movesLeft or "unlimited") .. " routes") or ("Approval: " .. p.mode))
            local details = p.reason or ruleDetails or (p.approved and "Route preapproved" or "Ask at bank")
            row.label:SetText(string.format("%s x%d | %s > %s | %s\n%s", p.name, amount, routing:Name(p.source), routing:Name(p.dest), state, details))
        end
    end
    self.summary:SetText((GridBagsActivity:IsPaused() and "PAUSED | " or "") .. string.format("%d pending plans/rules | page %d | Equipped gear is never a source", #entries, self.page + 1))
    local op = routing.current
    self.confirmWindow:SetHidden(not op or not routing:IsBanking() or self.editingSession == true or GridBagsActivity:IsPaused())
    if op then
        local lines = { op.name .. " x" .. op.qty, "From " .. routing:Name(op.source) .. " | " .. (op.phase == "source" and "Deposit into account bank" or "Withdraw into current character's inventory") }
        if routing:NeedsRecipeConsent(op)then lines[#lines+1]="Recipe ingredient or furniture-material exception: explicit confirmation required for this named delivery."end
        local recipients, order = {}, {}
        for _, a in ipairs(op.allocations) do
            local p = routing:Plan(a.plan)
            if p then
                if not recipients[p.dest] then recipients[p.dest] = { qty = 0, plans = 0 }; order[#order + 1] = p.dest end
                recipients[p.dest].qty = recipients[p.dest].qty + a.qty
                recipients[p.dest].plans = recipients[p.dest].plans + 1
            end
        end
        for _, id in ipairs(order) do
            local recipient = recipients[id]
            lines[#lines + 1] = string.format("%d for %s (%d named plan(s))", recipient.qty, routing:Name(id), recipient.plans)
        end
        lines[#lines + 1] = "Confirm approves this stack's named route. All applies only to this frozen bank-visit queue."
        self.confirmText:SetText(table.concat(lines, "\n"))
        local textHeight = #lines * 26 + 48
        self.confirmText:SetDimensions(660, textHeight)
        self.confirmWindow:SetDimensions(700, textHeight + 122)
        self.confirmWindow:SetScale(math.min(1, (GuiRoot:GetWidth() - 60) / 700, (GuiRoot:GetHeight() - 90) / (textHeight + 122)))
    end
    if routing.notice then self.message:SetText(routing.notice) end
end

function U:Close(keepRuleSession)
    local wasEditing = self.editingSession
    self.editingSession = keepRuleSession == true and wasEditing or false
    for _, edit in ipairs({ self.quantity, self.keep, self.allowUnits, self.allowMoves, self.bankStacks }) do if edit then edit:LoseFocus() end end
    if self.window then self.window:SetHidden(true); self.editor:SetHidden(true) end
    if wasEditing and not self.editingSession then R:Notify() end
    if wasEditing and not self.editingSession and GridBagsGoldUI and GridBagsGoldUI.window then GridBagsGoldUI:Update() end
end

function U:Initialize(owner)
    self.window = Frame("GridBagsPlanner", 800, 670)
    Label(self.window, "GRIDBAGS ROUTING PLANNER", 20, 12, 630, "ZoFontWinH2")
    Button(self.window, "Close", 690, 12, 90, function() self:Close() end)
    self.summary = Label(self.window, "", 20, 55, 760)
    self.rows = {}
    for i = 1, 6 do
        self.rows[i] = { button = Button(self.window, "", 20, 100 + (i - 1) * 65, 100, function() end),
            label = Label(self.window, "", 130, 100 + (i - 1) * 65, 645) }
    end
    Button(self.window, "Previous", 20, 500, 100, function() self.page = math.max(0, (self.page or 0) - 1); self:Update(R) end)
    Button(self.window, "Next", 130, 500, 100, function() self.page = (self.page or 0) + 1; self:Update(R) end)
    Button(self.window, "Mark items: toggle", 250, 500, 180, function()
        owner.planMode = not owner.planMode; self:Close(); owner:Refresh()
    end)
    self.profileButton = Button(self.window, "Profiles...", 450, 500, 150, function(c) self:Profiles(c) end)
    Button(self.window, "History / tools", 620, 500, 160, function() GridBagsToolsUI:Show("history") end)
    Button(self.window, "Crafting / material rules", 20, 620, 240, function() GridBagsCraftingUI:Show() end)
    Button(self.window, "Deliveries", 280, 620, 230, function() GridBagsDeliveryUI:Show() end)
    Button(self.window, "Protected items", 530, 620, 250, function() GridBagsProtectionUI:Show() end)
    self.message = Label(self.window, "Use Mark items, then the P button on a bag/bank item to create a route. Snapshot plans wait for the source character's bank visit.", 20, 548, 760)

    self.editor = Frame("GridBagsRouteEditor", 700, 700)
    Label(self.editor, "PLAN ITEM DELIVERY", 20, 12, 500, "ZoFontWinH2")
    Button(self.editor, "Close", 590, 12, 90, function() self:Close() end)
    self.editorTitle = Label(self.editor, "", 20, 55, 660)
    self.sourceButton = Button(self.editor, "Source", 20, 84, 420, function(c)
        self:Characters(c, function(id)
            self.editing.source = id
            local guard = R:Protection(id, self.editing.link)
            self.keep:SetText(tostring(guard.keep or 0)); self.never = guard.blocked == true
            self:UpdateEditor()
        end, true, true)
    end)
    self.destination = Button(self.editor, "Destination", 20, 116, 420, function(c)
        self:Characters(c, function(id) self.editing.dest = id; self.editing.smart = nil; self:UpdateEditor() end, true)
    end)
    Button(self.editor, "Suggest recipient...", 450, 116, 220, function(c) self:Suggestions(c) end)
    self.deconstructButton = Button(self.editor, "Send for deconstruction...", 20, 160, 320, function(c) self:GearRecipients(c,"deconstruct") end)
    self.researchButton = Button(self.editor, "Send for research...", 350, 160, 320, function(c) self:GearRecipients(c,"research") end)
    self.quantity = Edit(self.editor, "Units per plan/stack", 20, 205, 1)
    self.approval = Button(self.editor, "Approval", 330, 205, 340, function(c)
        ClearMenu()
        for _, mode in ipairs({ "ask", "advance", "limited", "standing" }) do
            local value = mode
            AddMenuItem(value, function() self.editing.mode = value; ClearMenu(); self:UpdateEditor() end)
        end
        ShowMenu(c)
    end)
    self.allowUnits = Edit(self.editor, "Automatic unit allowance", 20, 250, 200)
    self.allowMoves = Edit(self.editor, "Automatic route allowance", 330, 250, 3)
    self.bankStacks = Edit(self.editor, "Overflow: retain stacks", 20, 295, 3)
    self.kindButton = Button(self.editor, "Kind", 330, 295, 160, function(c)
        ClearMenu()
        for _, kind in ipairs({ "repeat", "overflow", "learning" }) do
            local value = kind
            AddMenuItem(value, function() self.ruleKind = value; ClearMenu(); self:UpdateEditor() end)
        end
        ShowMenu(c)
    end)
    self.replaceButton = Button(self.editor, "Change item...", 500, 295, 170, function()
        self.replacingRule = { id = self.editingRuleId, spec = self:EditorSpec() }
        self:Close(true); owner.planMode = true; owner:Refresh()
        self:Message("Click P on the replacement item. Your other rule edits will be retained.")
    end)
    Label(self.editor, "Ask: each stack. Advance: one route. Limited: counters, then Ask (one blank counter = unlimited). Standing: until revoked.", 20, 340, 660)
    self.keep = Edit(self.editor, "Keep units on source", 20, 405, 0)
    self.neverButton = Button(self.editor, "Never export: off", 330, 405, 200, function() self.never = not self.never; self:UpdateEditor() end)
    self.protectionButton = Button(self.editor, "Save source protection", 20, 450, 240, function()
        if self.editing.source == R.ANY then GridBagsProtectionUI:Show();return end
        local ok, err = R:SetProtection(self.editing.source, self.editing.link, self.never, self.keep:GetText())
        self:Message(ok and "Source protection saved. It applies to all plans for this exact item variant." or err)
    end)
    self.enabledButton = Button(self.editor, "Rule: enabled", 300, 450, 200, function()
        self.editing.enabled = self.editing.enabled == false; self:UpdateEditor()
    end)
    self.createButtons = {
        Button(self.editor, "One-time plan", 20, 507, 155, function() self:Save("once") end),
        Button(self.editor, "Repeat rule", 185, 507, 155, function() self:Save("repeat") end),
        Button(self.editor, "Bank overflow", 350, 507, 155, function() self:Save("overflow") end),
        Button(self.editor, "Learning rule", 515, 507, 155, function() self:Save("learning") end),
    }
    self.saveRuleButton = Button(self.editor, "Save rule changes", 20, 507, 240, function() self:Save(self.ruleKind) end)
    for _, c in ipairs({self.sourceButton,self.kindButton,self.replaceButton,self.enabledButton,self.saveRuleButton}) do c:SetHidden(true) end
    Label(self.editor, "New plans never change the current frozen bank queue. Source protections override all approvals. Gear deliveries go to inventory; nothing auto-equips.", 20, 555, 660)
    self.editorMessage = Label(self.editor, "", 20, 615, 660)
    self.editorMessage:SetDimensions(660, 60)

    self.confirmWindow = Frame("GridBagsRouteConfirmation", 700, 340)
    Label(self.confirmWindow, "CONFIRM BANK TRANSFER", 20, 12, 660, "ZoFontWinH2")
    self.confirmText = Label(self.confirmWindow, "", 20, 60, 660)
    self.confirmText:SetDimensions(660, 205)
    local buttons = {
        Button(self.confirmWindow, "Confirm stack", 20, 285, 155, function() R:Confirm(false) end),
        Button(self.confirmWindow, "Skip stack", 185, 285, 155, function() R:Skip(false) end),
        Button(self.confirmWindow, "Confirm all", 350, 285, 155, function() R:Confirm(true) end),
        Button(self.confirmWindow, "Skip all", 515, 285, 155, function() R:Skip(true) end),
    }
    for i, button in ipairs(buttons) do
        button:ClearAnchors(); button:SetAnchor(BOTTOMLEFT, self.confirmWindow, BOTTOMLEFT, 20 + (i - 1) * 165, -12)
    end
end

function U:Show()
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    if GridBagsProtectionUI then GridBagsProtectionUI:Close() end
    if GridBagsDeliveryUI then GridBagsDeliveryUI:Close() end
    if GridBagsCraftingUI and GridBagsCraftingUI.window then GridBagsCraftingUI:Close() end
    self.replacingRule = nil
    GridBags:ReleaseSearchFocus(); self:Close(); self.window:SetHidden(false); self:Update(R)
end

GridBagsTransferTools = {}
local T = GridBagsTransferTools

function T:Clone(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = self:Clone(item) end; return result
end

function T:Preview()
    local R, A = GridBagsRouting, GridBagsActivity
    if R.pending or GridBagsGold.pending then return nil, "Wait for the current transfer receipt before previewing." end
    local original, depth, originalClaims = R.data, A.previewDepth or 0, R.materialClaims
    local originalPlans={};for _,p in ipairs(original.plans)do originalPlans[p.id]=p end
    R.data = self:Clone(original); A.previewDepth = depth + 1
    local ok, result = pcall(function()
        local live = R:IsBanking()
        local snapshot = GridBags.saved.bankSnapshots[GetWorldName()]
        local backpack, bank = R:Scan(R.character), {}
        if live then bank = R:Scan(R.BANK)
        elseif snapshot then
            for index, item in ipairs(snapshot.items) do
                bank[#bank + 1] = { bag = BAG_BANK, slot = index - 1, uid = item.uid or ("snapshot-" .. index),
                    link = item.link, qty = item.stack, maxStack = item.maxStack or 1, name = item.displayName or item.name,
                    blocked = item.locked or item.playerLocked or item.stolen, bound = item.bound,
                    blockedReason = "Saved item is locked or stolen", blockedCode = "SAVED_ITEM_PROTECTED" }
            end
        end
        R.data.visit = { queue = {}, touched = {}, index = 1, id = -1 }
        R:GenerateRules(backpack, bank); R:BuildQueue(backpack, bank)
        local rows, represented, representedRules = {}, {}, {}
        for _, op in ipairs(R.data.visit.queue) do
            local authorized = R:Allowed(op)
            local reason, code, state = "Bank capacity and identity will be checked live", "TENTATIVE", "tentative"
            if live then
                local destination
                destination, reason, code = R:Validate(op)
                state = destination and "eligible now" or "blocked"
                if destination then reason, code = "Live checks passed; execution rechecks capacity and identity", "ELIGIBLE_NOW" end
            end
            for _, part in ipairs(op.allocations) do
                represented[part.plan] = true
                local p = R:Plan(part.plan)
                if p.rule then representedRules[p.rule]=true end
                rows[#rows + 1] = { item = p.name, quantity = part.qty, source = p.source, destination = p.dest,
                    state = state, reason = reason, code = code, approval = authorized and "authorized if earlier eligible moves run" or "confirmation required",
                    observedAt = p.observedAt, rule=p.rule, plan=p.id }
            end
            if state~="blocked"then
                for _,part in ipairs(op.allocations)do
                    local p=R:Plan(part.plan);local rule=p.rule and R:Rule(p.rule)
                    if rule and not p.funded then
                        if rule.unitsLeft~=nil then rule.unitsLeft=math.max(0,rule.unitsLeft-part.qty)end
                        if rule.movesLeft~=nil then rule.movesLeft=math.max(0,rule.movesLeft-1)end
                        p.funded=true
                    end
                end
            end
        end
        for _, p in ipairs(R.data.plans) do
            if not represented[p.id] and p.state ~= "done" and p.state ~= "cancelled" then
                if p.rule then representedRules[p.rule]=true end
                local reason = p.reason or (p.state == "source" and "Waiting for source character's bank visit" or "Waiting for destination character's bank visit")
                local code = p.reasonCode or "WAITING_CHARACTER"
                local state = p.state == "review" and "review" or "waiting"
                if not live and not snapshot and p.state ~= "source" then reason, code, state = "No bank snapshot: visit a personal banker first", "BANK_NOT_OBSERVED", "unknown" end
                if not live and snapshot and p.state=="review"and originalPlans[p.id]and originalPlans[p.id].state=="bank"then
                    reason,code,state="Saved bank contents do not confirm this reservation; verify at a live banker","SAVED_BANK_UNCERTAIN","tentative"
                end
                rows[#rows + 1] = { item = p.name, quantity = p.remaining, source = p.source, destination = p.dest,
                    state = state, reason = reason, code = code, observedAt = p.observedAt, rule=p.rule, plan=p.id }
            end
        end
        for _,rule in ipairs(R.data.rules)do
            if not representedRules[rule.id]then
                local reason = not rule.enabled and "Rule is paused/disabled" or rule.reason or
                    ((rule.source~=R.character and rule.source~=R.BANK and rule.source~=R.ANY)and"Waiting for source character's bank visit"or"No eligible matching stack in the observed inventories")
                rows[#rows+1]={item=rule.name,quantity=rule.maxPerStack,source=rule.source,destination=rule.dest,
                    state="waiting",reason=reason,code=not rule.enabled and"RULE_PAUSED"or"RULE_WAITING",rule=rule.id,isRule=true}
            end
        end
        return { rows = rows, live = live, bankObservedAt = snapshot and snapshot.updatedAt, paused = A:IsPaused(),
            note = live and "Current character, live observations. Capacity can change between moves." or
                ("Current character and last bank snapshot" .. (snapshot and (" (" .. math.max(0,math.floor((GetTimeStamp()-snapshot.updatedAt)/60)) .. " min old)") or " (not observed)") .. ". Capacity unverified away from banker.") }
    end)
    R.data, A.previewDepth, R.materialClaims = original, depth, originalClaims
    if not ok then return nil, "Preview could not finish; no live plans were changed. " .. tostring(result) end
    return result
end

function T:Report()
    local A, R, Gold = GridBagsActivity, GridBagsRouting, GridBagsGold
    local counts = { source = 0, bank = 0, review = 0 }
    for _, p in ipairs(R.data.plans) do if counts[p.state] then counts[p.state] = counts[p.state] + 1 end end
    local lines = { "GridBags troubleshooting report", "Version: " .. tostring(GridBags.version),
        "ESO API: " .. tostring(GetAPIVersion and GetAPIVersion() or "unknown"),
        "Paused: " .. tostring(A:IsPaused()), "Personal bank open: " .. tostring(R:IsBanking()),
        string.format("Pending plans: source=%d bank=%d review=%d; rules=%d", counts.source, counts.bank, counts.review, #R.data.rules),
        "Item request pending: " .. tostring(R.pending ~= nil), "Gold request pending: " .. tostring(Gold.pending ~= nil),
        "Display: columns=" .. tostring(GridBags.saved.columns) .. " size=" .. tostring(GridBags.saved.size) .. " sort=" .. tostring(GridBags.saved.sort),
        "Filters: external=" .. tostring(GridBags.saved.externalFilters) .. " embedded=" .. tostring(GridBags.saved.embeddedFilters) }
    local holds,holdCount={},0
    for _,p in ipairs(R.data.plans)do if p.state=="review"then local code=A:SafeCode(p.reasonCode or"RESULT_UNCERTAIN");holds[code]=(holds[code]or 0)+1 end end
    for _,hold in pairs(Gold.data.holds)do local code=A:SafeCode(hold.code or"GOLD_RESULT_UNCERTAIN");holds[code]=(holds[code]or 0)+1;holdCount=holdCount+1 end
    lines[#lines+1]="Gold review holds: "..holdCount
    for code,count in pairs(holds)do lines[#lines+1]="Review code: "..code.." count="..count end
    lines[#lines+1]="Relevant addons:"
    local wanted = { GridBags=true, AdvancedFilters=true, ["LibFilters-3.0"]=true, LibFilters3=true, ["LibAddonMenu-2.0"]=true,
        LibCharacterKnowledge=true,LibResearch=true,LibCustomMenu=true,ResearchAssistant=true, CharacterKnowledge=true,
        CraftStore=true,CraftStoreFixedAndImproved=true, BankManagerRevived=true, GridList=true, GridPadInventory=true }
    local manager = GetAddOnManager and GetAddOnManager()
    if manager then
        for index = 1, manager:GetNumAddOns() do
            local ok, name, _, _, _, enabled = pcall(manager.GetAddOnInfo, manager, index)
            if ok and wanted[name] then
                local versionOK, version = pcall(manager.GetAddOnVersion, manager, index)
                lines[#lines + 1] = name .. ": " .. tostring(versionOK and version or "unknown") .. " enabled=" .. tostring(enabled)
            end
        end
    else lines[#lines + 1] = "Addon manager unavailable" end
    lines[#lines + 1] = "Recent outcomes (private details omitted):"
    for index = math.max(1, #A.data.history - 19), #A.data.history do
        local e = A.data.history[index]
        local kinds={item=true,gold=true,rule=true,control=true,error=true}
        local outcomes={success=true,requested=true,waiting=true,skipped=true,review=true,failed=true,control=true}
        lines[#lines + 1] = tostring(e.at) .. " " .. (kinds[e.kind] and e.kind or "unknown") .. " " .. (outcomes[e.outcome] and e.outcome or "unknown") .. " " .. A:SafeCode(e.code)
    end
    lines[#lines + 1] = "Recent GridBags error frames (raw messages omitted):"
    local files={Compatibility=true,Activity=true,SnapshotFilters=true,Snapshots=true,Equipment=true,Routing=true,RoutingUI=true,
        SmartRouting=true,Crafting=true,GearRouting=true,CraftingUI=true,Help=true,RoutingInsights=true,DeliveryUI=true,ProtectionUI=true,RecipeGather=true,RecipeGatherUI=true,Layout=true,GoldRouting=true,GoldUI=true,TransferTools=true,ConfigCodec=true,ToolsUI=true,AdvancedFilters=true,GridBags=true}
    for _, entry in ipairs(A.data.errors) do
        local frames = {}
        local raw=type(entry.text)=="string"and entry.text or ""
        for _,part in ipairs(entry.continuation or {})do if type(part)=="string"then raw=raw..part end end
        for file, line in raw:gmatch("GridBags/([%w_%-]+%.lua):(%d+)") do
            local stem=file:sub(1,-5)
            if files[stem] and tonumber(line)<=1000000 then frames[#frames + 1] = "GridBags/" .. file .. ":" .. line end
        end
        local category = "Lua error"
        for _, text in ipairs({ "private function", "nil value", "stack overflow", "bad argument", "arithmetic" }) do
            if raw:find(text, 1, true) then category = text; break end
        end
        lines[#lines + 1] = tostring(entry.at) .. " " .. category .. " " .. table.concat(frames, ", ")
    end
    lines[#lines + 1] = "No character names/IDs, item names/links, balances or snapshot contents are included."
    return table.concat(lines, "\n")
end

function T:CaptureConfig()
    local R, Gold = GridBagsRouting, GridBagsGold
    local result = { schema = 1, world = GetWorldName(), characters = {}, rules = {}, roles = self:Clone(R.data.profiles),
        protections = self:Clone(R.data.protections), gold = self:Clone(Gold.data.profiles), bankReserve = Gold.data.bankReserve or 0,
        view = {} }
    local function Character(id)
        if id and id ~= R.BANK and id ~= R.ANY and id ~= "@learners" and id ~= "@best-crafter" then result.characters[id] = R:Name(id) end
    end
    for _, rule in ipairs(R.data.rules) do
        local spec = { source = rule.source, dest = rule.dest, link = rule.link, name = rule.name,
            qty = rule.maxPerStack, maxStack = rule.maxStack, mode = rule.mode, units = rule.unitsLeft, moves = rule.movesLeft,
            overflow = rule.overflowStacks ~= nil, overflowStacks = rule.overflowStacks, strategy = rule.strategy,
            smart = self:Clone(rule.smart), enabled = rule.enabled, material=rule.material, craft=rule.craft, scope=rule.scope,
            sourceUnassigned=rule.sourceUnassigned }
        result.rules[#result.rules + 1] = spec; Character(spec.source); Character(spec.dest)
    end
    for _, collection in ipairs({result.roles,result.protections,result.gold}) do for id in pairs(collection) do Character(id) end end
    for _, key in ipairs({ "columns", "size", "sort", "showGold", "externalFilters", "embeddedFilters", "layouts" }) do result.view[key] = self:Clone(GridBags.saved[key]) end
    return result
end

function T:Backup(label)
    local backups = GridBagsActivity.data.backups
    backups[#backups + 1] = { at = GetTimeStamp(), label = label or "Manual configuration backup", config = self:CaptureConfig() }
    if #backups > 5 then table.remove(backups, 1) end
    GridBagsActivity:Append({kind="control",outcome="control",code="CONFIG_BACKUP",reason="Configuration backed up locally; no inventory or transfer journal copied"})
    return backups[#backups]
end

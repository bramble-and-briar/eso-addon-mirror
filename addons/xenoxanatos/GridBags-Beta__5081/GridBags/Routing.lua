-- Persistent, account/world-scoped routing. Only the currently logged-in
-- character and an open personal bank can participate in a physical operation.
GridBagsRouting = { BANK = "@bank", ANY = "@any" }
local R = GridBagsRouting
local BANK = R.BANK
local TIMER = "GridBagsRoutingTick"

local function Copy(t)
    local result = {}; for k, v in pairs(t) do result[k] = v end; return result
end
local function Integer(value, default)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return default end
    return math.max(0, math.floor(value))
end
local function Active(p) return p.state == "source" or p.state == "bank" end

function R:Id()
    self.data.nextId = (self.data.nextId or 0) + 1
    return self.data.nextId
end

function R:Name(id)
    if id == self.ANY then return "Any source" end
    if id == BANK then return "Account bank" end
    if id == "@learners" then return "eligible learning profiles" end
    if id == "@best-crafter" then return "best profession crafter (each new batch)" end
    if id == self.character then return zo_strformat(SI_UNIT_NAME, GetUnitName("player")) end
    local record = GridBagsSnapshots.records[id]
    return record and record.name or tostring(id)
end

function R:IsBanking()
    return IsBankOpen() and GetBankingBag() == BAG_BANK and not IsInGamepadPreferredMode()
end

function R:Read(bag, slot)
    if GetItemId(bag, slot) == 0 then return nil end
    local _, count, _, _, locked = GetItemInfo(bag, slot)
    local _, maximum = GetSlotStackSize(bag, slot)
    local stolen, playerLocked = IsItemStolen(bag, slot), IsItemPlayerLocked(bag, slot)
    local characterBound = GetItemLinkBindType and GetItemLinkBindType(GetItemLink(bag, slot)) == BIND_TYPE_ON_PICKUP_BACKPACK
    return { bag = bag, slot = slot, link = GetItemLink(bag, slot), qty = count,
        uid = Id64ToString(GetItemUniqueId(bag, slot)), maxStack = maximum or 1,
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bag, slot)),
        blocked = locked or playerLocked or stolen or characterBound,
        blockedReason = (locked or playerLocked) and "Item is locked" or (stolen and "Stolen item cannot be banked" or (characterBound and "Item is character-bound" or nil)),
        blockedCode = (locked or playerLocked) and "ITEM_LOCKED" or (stolen and "ITEM_STOLEN" or (characterBound and "CHARACTER_BOUND" or nil)),
        bound = IsItemBound(bag, slot) }
end

function R:Scan(id)
    local result = {}
    local bags = id == BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { BAG_BACKPACK }
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagSize(bag) - 1 do
            local item = self:Read(bag, slot)
            if item then result[#result + 1] = item end
        end
    end
    return result
end

function R:Total(items, link)
    local total = 0
    for _, item in ipairs(items) do if item.link == link then total = total + item.qty end end
    return total
end

function R:Protection(source, link)
    local rules = self.data.protections[source]
    return rules and rules[link] or {}
end

function R:SetProtection(source, link, blocked, keep, validateOnly)
    if source == self.ANY then return nil, "Protections apply to a named character or the bank; open Protected items." end
    local value = tonumber(keep)
    if value == nil or Integer(value, -1) ~= value then return nil, "Keep limit must be a nonnegative whole number." end
    if validateOnly then return true end
    self.data.protections[source] = self.data.protections[source] or {}
    self.data.protections[source][link] = { blocked = blocked == true, keep = value }
    return true
end

function R:KeepFloor(source,link)
    local manual=self:Protection(source,link).keep or 0
    local recipe=GridBagsRecipeGather and GridBagsRecipeGather:Keep(source,link)or 0
    return math.max(manual,recipe)
end

function R:RemoveProtection(source, link)
    if self.pending then return nil, "Wait for the current item transfer to settle before removing protection." end
    local list = self.data.protections[source]
    if list then list[link] = nil; if not next(list) then self.data.protections[source] = nil end end
    self:Notify(); return true
end

function R:Reserved(link, except)
    local n = 0
    for _, p in ipairs(self.data.plans) do
        -- Review holds continue reserving stock; an uncertain result is not free stock.
        if p.id ~= except and p.link == link and (p.state == "bank" or (p.state == "review" and p.reserve)) then
            n = n + p.remaining
        end
    end
    return n
end

-- Reservations follow individual quantities, not a profession-wide batch lock.
function R:Allocated(source, item)
    local stack,total=0,0
    for _,p in ipairs(self.data.plans)do
        local relevant=source==BANK and (p.state=="bank"or(p.state=="review"and p.reserve))or
            (source~=BANK and p.source==source and (p.state=="source"or p.state=="review"))
        if relevant and p.link==item.link then
            total=total+p.remaining
            if p.uid==item.uid or p.bankUid==item.uid then stack=stack+p.remaining end
        end
    end
    return stack,total
end

function R:RuleAvailable(rule,items,item)
    local stack,total=self:Allocated(rule.source,item)
    local own=0
    for _,p in ipairs(self.data.plans)do
        local sameSource=rule.source==BANK and (p.state=="bank"or(p.state=="review"and p.reserve))or
            (p.source==rule.source and (p.state=="source"or p.state=="review"))
        if p.rule==rule.id and sameSource and p.link==item.link and (p.uid==item.uid or p.bankUid==item.uid)then own=own+p.remaining end
    end
    local guard=self:Protection(rule.source,item.link)
    if guard.blocked then return 0 end
    return math.max(0,math.min(item.qty-stack,self:Total(items,item.link)-total-self:KeepFloor(rule.source,item.link),rule.maxPerStack-own))
end

function R:Add(spec)
    if spec.source == self.ANY or spec.dest == self.ANY then return nil, "Any source belongs to repeat rules; concrete deliveries require named sources and destinations." end
    if not spec.link or not spec.source or not spec.dest or spec.source == spec.dest then return nil, "Choose different source and destination." end
    if spec.dest == "@learners" or spec.dest == "@best-crafter" then return nil, "A concrete plan needs a named character; use a rule to choose recipients." end
    if spec.equipped then return nil, "Equipped gear is comparison context, not a move source." end
    local qty = Integer(spec.qty, 0)
    if qty < 1 or qty ~= tonumber(spec.qty) then return nil, "Enter a positive whole quantity." end
    if spec.source ~= BANK and not spec.uid then return nil, "Refresh this character snapshot to capture item identity first." end
    if spec.mode ~= "ask" and spec.mode ~= "advance" and spec.mode ~= "limited" and spec.mode ~= "standing" then
        return nil, "Unknown approval mode."
    end
    if spec.mode == "limited" and not spec.rule then return nil, "Limited allowances belong to repeat rules; use Ask or Advance for a one-time plan." end
    local guard = self:Protection(spec.source, spec.link)
    if guard.blocked then return nil, "Source is protected: never export this item." end
    local allocated = 0
    for _, p in ipairs(self.data.plans) do
        if (Active(p) or p.state == "review") and p.source == spec.source and p.uid == spec.uid and p.link == spec.link
            and p.state ~= "bank" then allocated = allocated + p.remaining end
    end
    if spec.available and qty + allocated > spec.available then return nil, "Quantity exceeds this observed stack's unplanned units." end
    local p = { id = self:Id(), link = spec.link, name = spec.name or spec.link,
        source = spec.source, dest = spec.dest, uid = spec.uid, qty = qty, remaining = qty,
        state = spec.source == BANK and "bank" or "source", mode = spec.mode,
        approved = spec.mode == "advance" or nil, rule = spec.rule,
        observedAt = spec.observedAt or GetTimeStamp(), bound = spec.bound, maxStack = spec.maxStack or 1,
        bankUid = spec.source == BANK and spec.uid or nil, smart = spec.smart,
        sourceCount = spec.available, sourceMovedAtPlan = self.data.sourceMoved and self.data.sourceMoved[spec.uid] or 0 }
    self.data.plans[#self.data.plans + 1] = p
    if spec.mode=="advance"and self:RequiresMaterialConsent(p)then p.recipeConsent=true end
    return p
end

function R:BuildRule(spec)
    if spec.dest == self.ANY then return nil, "Any is a source option; choose a destination." end
    if spec.material ~= nil and type(spec.material) ~= "boolean" then return nil, "Invalid material rule flag." end
    if spec.material then
        if spec.craft ~= Integer(spec.craft, -1) or spec.craft < 0 or spec.craft > 9 then return nil, "Choose a material category." end
        if spec.craft >= 8 and (spec.scope ~= "all" or spec.dest == "@best-crafter" or spec.sourceUnassigned) then return nil, "Style/trait categories use storage scope and a named recipient or bank, without profession filters." end
        if spec.sourceUnassigned ~= nil and type(spec.sourceUnassigned) ~= "boolean" then return nil, "Invalid source profession filter." end
        if spec.sourceUnassigned and spec.source == BANK then return nil, "Source profession filters require a character source." end
        if spec.craft == 0 and (spec.scope ~= "all" or spec.dest == "@best-crafter") then return nil, "All-profession clearing uses storage scope and a named character or bank destination." end
        if spec.scope ~= "all" and spec.scope ~= "usable" and spec.scope ~= "known" then return nil, "Choose a material scope." end
        if spec.strategy or spec.overflow or spec.smart or spec.dest == "@learners" then return nil, "Material rules cannot also be learning/overflow rules." end
        if spec.scope ~= "all" and spec.dest == BANK then return nil, "Usability requires a character destination; use storage scope for bank deposits." end
    elseif spec.dest == "@best-crafter" then return nil, "Dynamic crafters require a profession material rule." end
    if spec.source == spec.dest then return nil, "Source and destination must differ." end
    if spec.mode == "advance" then return nil, "Advance approval applies to a one-time route. Choose Ask, allowance, or standing for repeat rules." end
    if not spec.link or not spec.source or not spec.dest then return nil, "Choose an item, source and destination." end
    if spec.strategy and spec.strategy ~= "recipe" and spec.strategy ~= "research" then return nil, "Choose a supported learning rule." end
    if not spec.strategy and spec.dest == "@learners" then return nil, "Choose a named destination for a repeat/overflow rule." end
    if spec.strategy and (spec.dest ~= "@learners" or tonumber(spec.qty) ~= 1 or spec.overflow) then return nil, "Learning rules allocate one copy to eligible learner profiles." end
    if spec.mode ~= "ask" and spec.mode ~= "limited" and spec.mode ~= "standing" then return nil, "Choose Ask, limited allowance or standing approval." end
    if not tonumber(spec.qty) or Integer(spec.qty, 0) ~= tonumber(spec.qty) or tonumber(spec.qty) < 1 then return nil, "Units must be a positive whole number." end
    if spec.mode == "limited" and ((spec.units == nil and spec.moves == nil) or
        (spec.units ~= nil and (not tonumber(spec.units) or Integer(spec.units, -1) ~= tonumber(spec.units))) or
        (spec.moves ~= nil and (not tonumber(spec.moves) or Integer(spec.moves, -1) ~= tonumber(spec.moves)))) then
        return nil, "Use nonnegative whole allowance counters; leave one blank for unlimited, but not both."
    end
    if spec.overflow and (not tonumber(spec.overflowStacks) or Integer(spec.overflowStacks, -1) ~= tonumber(spec.overflowStacks)) then
        return nil, "Bank stack retention must be a nonnegative whole number."
    end
    local rule = { link = spec.link, name = spec.name or spec.link,
        source = spec.source, dest = spec.dest, mode = spec.mode or "ask", enabled = spec.enabled ~= false,
        unitsLeft = spec.units ~= nil and Integer(spec.units, 0) or nil, movesLeft = spec.moves ~= nil and Integer(spec.moves, 0) or nil,
        maxPerStack = Integer(spec.qty, 1), overflowStacks = spec.overflow and Integer(spec.overflowStacks, 3) or nil,
        maxStack = spec.maxStack or 1, createdAt = GetTimeStamp(), smart = spec.smart, strategy = spec.strategy,
        material = spec.material == true or nil, craft = spec.material and spec.craft or nil, scope = spec.material and spec.scope or nil,
        sourceUnassigned = spec.material and spec.sourceUnassigned == true or nil }
    if rule.maxPerStack < 1 then return nil, "Quantity must be positive." end
    if rule.overflowStacks and rule.source ~= BANK then return nil, "Overflow rules start at the account bank." end
    return rule
end

local function RuleRecord(rule)
    if not rule then return nil end
    local record={}
    for _,key in ipairs({"id","name","link","source","dest","material","craft","scope","mode","enabled","sourceUnassigned","maxPerStack","unitsLeft","movesLeft"})do record[key]=rule[key]end
    return record
end

function R:RuleSnapshot(rule) return RuleRecord(rule) end

function R:RecordRuleChange(action,before,after)
    self.data.ruleAudit=self.data.ruleAudit or {}
    local entry={at=GetTimeStamp(),clock=GetTimeString and GetTimeString()or nil,action=action,before=RuleRecord(before),after=RuleRecord(after)}
    self.data.ruleAudit[#self.data.ruleAudit+1]=entry
    if #self.data.ruleAudit>100 then table.remove(self.data.ruleAudit,1)end
    local rule=after or before
    GridBagsActivity:Append({kind="control",outcome="control",code="RULE_"..action,rule=rule.id,item=rule.name,
        source=rule.source,destination=rule.dest,reason="Rule "..action:lower().."; see Backups / import > Rule change history for before/after details"})
end

function R:RuleHistory()
    local lines={"Rule changes recorded by this version (latest 100). Earlier missing rules cannot be reconstructed from this history.",
        "ESO persists SavedVariables on normal logout/reload; a crash can lose changes from the current session."}
    local function Describe(record)
        if not record then return "none"end
        return (record.name or record.link).." | "..self:Name(record.source).." > "..self:Name(record.dest).." | "..record.mode.." | category "..tostring(record.craft or "exact/learning").." | "..(record.enabled and "enabled"or "disabled")
    end
    for index=#(self.data.ruleAudit or {}),1,-1 do
        local e=self.data.ruleAudit[index]
        lines[#lines+1]="\n"..GetDateStringFromTimestamp(e.at).." "..(e.clock or "").." | "..e.action
        lines[#lines+1]="Before: "..Describe(e.before);lines[#lines+1]="After: "..Describe(e.after)
        if e.note then lines[#lines+1]=e.note end
    end
    return table.concat(lines,"\n")
end

function R:AddRule(spec)
    local rule, err = self:BuildRule(spec)
    if not rule then return nil, err end
    rule.id = self:Id()
    self.data.rules[#self.data.rules + 1] = rule
    self:RecordRuleChange("CREATED",nil,rule)
    return rule
end

function R:RetireRuleBatch(id)
    local affected = {}
    for _, p in ipairs(self.data.plans) do
        if p.rule == id and (Active(p) or p.state == "review") then
            affected[p.id] = true
            if p.state == "source" then p.state = "cancelled"
            else
                -- Existing deposits and uncertain outcomes must retain their custody ledger.
                p.rule = nil; p.mode = "ask"; p.approved = nil;p.recipeConsent=nil
                p.reason = "Original rule changed/deleted; existing delivery retained for review"
            end
            GridBagsActivity:Plan(p, "waiting", p.reason or "Unstarted batch cancelled after rule change", "RULE_CHANGED")
        end
    end
    for _, op in ipairs(self.data.visit and self.data.visit.queue or {}) do
        for _, a in ipairs(op.allocations) do
            if affected[a.plan] and op.status == "queued" then
                op.status = "skipped"; op.reason = "Rule changed; review at next bank opening"
                GridBagsActivity:Item(op, "skipped", op.reason, "RULE_CHANGED")
                if self.current == op then self.current = nil end
            end
        end
    end
end

function R:UpdateRule(id, spec)
    if self.pending then return nil, "Wait for the current transfer to settle." end
    local existing = self:Rule(id)
    if not existing then return nil, "This rule no longer exists." end
    local updated, err = self:BuildRule(spec)
    if not updated then return nil, err end
    local before=RuleRecord(existing)
    self:RetireRuleBatch(id)
    updated.id = id; updated.createdAt = existing.createdAt; updated.enabled = spec.enabled ~= false
    updated.editedAt = GetTimeStamp()
    for key in pairs(existing) do existing[key] = nil end
    for key, value in pairs(updated) do existing[key] = value end
    self:RecordRuleChange("EDITED",before,existing)
    self:Notify()
    return existing
end

function R:DeleteRule(id)
    if self.pending then return nil, "Wait for the current transfer to settle." end
    for index, rule in ipairs(self.data.rules) do
        if rule.id == id then
            self:RetireRuleBatch(id)
            table.remove(self.data.rules, index)
            self:RecordRuleChange("DELETED",rule,nil)
            self:Notify()
            return true
        end
    end
    return nil, "This rule no longer exists."
end

function R:Approve(id)
    for _, p in ipairs(self.data.plans) do
        if p.id == id and Active(p) then p.approved = true; if self:RequiresMaterialConsent(p)then p.recipeConsent=true end;p.reason = nil; return true end
    end
end

function R:Cancel(id)
    if self.pending then return false, "Wait for the current operation to settle." end
    for _, p in ipairs(self.data.plans) do
        if p.id == id then
            -- Cancelling a reservation releases stock; it never reverses a deposit.
            p.state = "cancelled"; p.reserve = nil; p.approved = nil
            GridBagsActivity:Plan(p, "skipped", "Plan cancelled by player; no automatic reversal requested", "USER_CANCEL")
            return true
        end
    end
end

function R:Rule(id)
    for _, rule in ipairs(self.data.rules) do if rule.id == id then return rule end end
end

function R:Plan(id)
    for _, p in ipairs(self.data.plans) do if p.id == id then return p end end
end

function R:RulePriority(rule)
    if rule.strategy then return 0 end
    if rule.overflowStacks then return 6 end
    if rule.material then return rule.scope == "known" and 2 or (rule.scope == "usable" and 3 or (rule.craft == 0 and 5 or 4)) end
    return 1
end

function R:OrderedRules()
    local rules = {}
    for _, rule in ipairs(self.data.rules) do rules[#rules + 1] = rule end
    table.sort(rules, function(a, b)
        local ap, bp = self:RulePriority(a), self:RulePriority(b)
        if ap==bp and (a.source==self.ANY)~=(b.source==self.ANY) then return a.source~=self.ANY end
        return ap == bp and a.id < b.id or ap < bp
    end)
    return rules
end

function R:GenerateRules(backpack, bank)
    self.data.learningHolds = {}
    self.materialClaims = {}
    for _, definition in ipairs(self:OrderedRules()) do
      local sources = definition.source == self.ANY and {self.character,BANK} or {definition.source}
      local reasons = {}
      for _, source in ipairs(sources) do
        local rule = definition
        if definition.source == self.ANY then rule = Copy(definition); rule.source = source; rule.anySource = true; rule.reason=nil;rule.reasonCode=nil end
        if rule.source ~= rule.dest then
        if rule.enabled and (rule.source == self.character or rule.source == BANK) then
          local initialPlans = #self.data.plans
          rule.reason = nil
          rule.reasonCode = nil
          if rule.material then
            GridBagsCrafting:Generate(rule, rule.source == BANK and bank or backpack)
          elseif rule.strategy then
            GridBagsSmartRouting:GenerateLearning(rule, rule.source == BANK and bank or backpack)
          else
            do
                local items = rule.source == BANK and bank or backpack
                local guard = self:Protection(rule.source, rule.link)
                local free = self:Total(items, rule.link) - self:KeepFloor(rule.source,rule.link)
                if rule.source == BANK then
                    free = free - self:Reserved(rule.link)
                    if rule.overflowStacks then free = math.min(free, self:Total(items, rule.link) - self:Reserved(rule.link) - rule.overflowStacks * rule.maxStack) end
                end
                local hold = rule.overflowStacks and ((self.data.tierHolds and self.data.tierHolds[rule.link]) or
                    (self.data.learningHolds and self.data.learningHolds[rule.link]))
                rule.reason = guard.blocked and "Source protected" or (hold and "Held: material tier or learner evidence needs review" or nil)
                if not guard.blocked and not hold then
                    for _, item in ipairs(items) do
                        if item.link == rule.link and not item.blocked and free > 0 and
                            (not rule.overflowStacks or not self.materialClaims[rule.source .. ":" .. tostring(item.uid)]) then
                            local qty = math.min(free, self:RuleAvailable(rule,items,item))
                            local p = qty>0 and self:Add({ source = rule.source, dest = rule.dest, link = rule.link,
                                name = rule.name, uid = item.uid, qty = qty, mode = rule.mode,
                                rule = rule.id, bound = item.bound, maxStack = item.maxStack, smart = rule.smart, available = item.qty })
                            if p then free = free - qty end
                        end
                    end
                end
            end
          end
          if #self.data.plans == initialPlans or rule.reason then
            if not rule.reason then
                local items = rule.source == BANK and bank or backpack
                local total = self:Total(items,rule.link)
                if total == 0 then rule.reason = "No matching item is present at this source"
                elseif rule.overflowStacks then rule.reason = "No unreserved stock above the bank overflow threshold"
                else rule.reason = "No eligible unallocated stack remains after locks, keep limits and existing plans" end
            end
            GridBagsActivity:Rule(rule,rule.reason,rule.reasonCode or (rule.strategy and "LEARNING_RULE_WAITING" or "RULE_NO_ELIGIBLE_BATCH"))
          end
        elseif not rule.enabled and (rule.source == self.character or rule.source == BANK) then
          GridBagsActivity:Rule(rule,"Rule is paused/disabled","RULE_PAUSED")
        end
        end
        if definition.source == self.ANY then
            if rule.reason then reasons[#reasons+1] = self:Name(source)..": "..rule.reason end
            definition.activityVisit = rule.activityVisit
        end
      end
      if definition.source == self.ANY then definition.reason = #reasons > 0 and table.concat(reasons,"; ") or nil end
    end
end

function R:ExplainWaiting(p, items, phase, remaining, available)
    local source=phase=="bank"and BANK or self.character
    if available<remaining and GridBagsRecipeGather and GridBagsRecipeGather:Keep(source,p.link)>0 then return "Ingredients held for a confirmed recipe request; release its hold in Gather ingredients > Requests when finished","RECIPE_GATHER_RESERVED"end
    local match, original
    for _, item in ipairs(items) do
        if item.uid == p.uid then original = item end
        local identity = phase == "bank" and ((p.maxStack or 1) > 1 or item.uid == (p.bankUid or p.uid)) or item.uid == p.uid
        if item.link == p.link and identity then match = item end
    end
    if not match then
        if original then return "Source identity changed since planning; refresh the snapshot", "SOURCE_CHANGED" end
        return "Planned item is missing from the observed source", "ITEM_MISSING"
    end
    if match.blocked then return match.blockedReason, match.blockedCode end
    if match.qty < remaining then return "Observed quantity is smaller than the planned move, or split across stacks", "QUANTITY_CHANGED_OR_FRAGMENTED" end
    if available < remaining then return "Source keep limit or earlier allocations leave too few units", "KEEP_OR_ALLOCATION_LIMIT" end
    return "Source units are already allocated to other work this visit", "SOURCE_ALLOCATED"
end

-- A unique live item can prove arrival outside our transfer queue. A matching
-- item link or saved snapshot cannot establish ownership of a particular copy.
function R:ReconcileArrivals()
    if self.pending or (self.data.visit and self.data.visit.inFlight) then return 0 end
    local owned,arrivals={},{}
    for _,bag in ipairs({BAG_BACKPACK,BAG_WORN})do
        for slot=0,GetBagSize(bag)-1 do
            local item=self:Read(bag,slot)
            if item and item.maxStack==1 and item.qty==1 then owned[item.uid]=item end
        end
    end
    local completed=0
    for _,p in ipairs(self.data.plans)do
        local eligible=Active(p)or (p.state=="review"and p.reasonCode=="RESERVATION_MISSING"and p.reserve)
        local identity=p.bankUid or p.uid
        if eligible and p.dest==self.character and p.maxStack==1 and p.qty==1 and p.remaining==1
            and type(identity)=="string"and identity:match("^%d+$")and identity~="0"then
            local item=owned[identity]
            if item then
                completed=completed+1
                p.state="done";p.remaining=0;p.reserve=nil;p.reason=nil;p.reasonCode=nil
                p.reconciledArrival={at=GetTimeStamp(),uid=identity,bag=item.bag,slot=item.slot}
                p.completionReason="Exact unique item observed in the intended character's live inventory; arrival reconciled outside the GridBags transfer queue."
                -- Old source and bank plans may describe the same physical item.
                -- Fulfil all matching goals, but log one arrival per unique ID.
                local arrival=arrivals[identity]
                if not arrival then
                    arrival={kind="item",outcome="success",quantity=1,plan=p.id,item=p.name,
                        source=p.source,destination=p.dest,observedAt=p.observedAt,relatedPlans={},
                        reason=p.completionReason,code="RECIPIENT_ALREADY_HAS_ITEM"}
                    arrivals[identity]=arrival
                end
                arrival.relatedPlans[#arrival.relatedPlans+1]=p.id
            end
        end
    end
    for _,arrival in pairs(arrivals)do
        arrival.reason=arrival.reason.." Matched delivery records: "..#arrival.relatedPlans.."."
        GridBagsActivity:Append(arrival)
    end
    return completed
end

function R:BuildQueue(backpack, bank)
    local visit = self.data.visit
    visit.queue = {}
    local totals, reserved, left, sourceLeft, grouped = {}, {}, {}, {}, {}
    for _, item in ipairs(bank) do totals[item.link] = (totals[item.link] or 0) + item.qty end
    for _, p in ipairs(self.data.plans) do
        if p.state == "bank" or (p.state == "review" and p.reserve) then reserved[p.link] = (reserved[p.link] or 0) + p.remaining end
    end
    for _, p in ipairs(self.data.plans) do
        if p.state == "bank" then
            local missing = (reserved[p.link] or 0) > (totals[p.link] or 0)
            if (p.maxStack or 1) == 1 then
                local found = false
                for _, item in ipairs(bank) do
                    if item.link == p.link and item.uid == (p.bankUid or p.uid) then found = true; break end
                end
                missing = missing or not found
            end
            if missing then
                p.state = "review"; p.reserve = true; p.reason = "Reserved bank stock or unique gear is missing; inspect and replan"
                p.reasonCode = "RESERVATION_MISSING"
                GridBagsActivity:Plan(p, "review", p.reason, "RESERVATION_MISSING")
            end
        end
    end
    for _, p in ipairs(self.data.plans) do
        local rule = p.rule and self:Rule(p.rule)
        local phase = p.state
        local eligible = (phase == "source" and p.source == self.character) or (phase == "bank" and p.dest == self.character)
        if eligible and (not rule or rule.enabled) then
            local source = phase == "source" and self.character or BANK
            local guard = self:Protection(source, p.link)
            local items = phase == "source" and backpack or bank
            sourceLeft[source] = sourceLeft[source] or {}
            local available = sourceLeft[source][p.link]
            if available == nil then
                available = math.max(0, self:Total(items, p.link) - self:KeepFloor(source,p.link))
                sourceLeft[source][p.link] = available
            end
            local targetEligible, targetReason, targetCode = GridBagsSmartRouting:Eligible(p,items)
            if guard.blocked then p.reason = "Source protected: never export"; p.reasonCode = "SOURCE_PROTECTED"
            elseif not targetEligible then p.reason, p.reasonCode = targetReason, targetCode
            elseif phase == "bank" and (reserved[p.link] or 0) > (totals[p.link] or 0) then
                p.state = "review"; p.reserve = true; p.reason = "Reserved bank stock is missing; reconcile before continuing"
                p.reasonCode = "RESERVATION_MISSING"
            else
                local remaining = p.remaining
                for _, item in ipairs(items) do
                    local identityMatches = item.uid == p.uid
                    if phase == "bank" then identityMatches = (p.maxStack or 1) > 1 or item.uid == (p.bankUid or p.uid) end
                    local key = tostring(item.bag) .. ":" .. item.slot
                    left[key] = left[key] or item.qty
                    if remaining > 0 and item.link == p.link and identityMatches and not item.blocked then
                        local qty = math.min(left[key], remaining, sourceLeft[source][p.link])
                        -- One-time source plans require the approved quantity as observed.
                        if qty < remaining then qty = 0 end
                        if qty > 0 then
                            local op = grouped[key]
                            if not op then
                                op = { bag = item.bag, slot = item.slot, uid = item.uid, link = item.link,
                                    source = source, phase = phase, qty = 0, allocations = {}, status = "queued", name = p.name }
                                grouped[key] = op; visit.queue[#visit.queue + 1] = op
                            end
                            op.qty = op.qty + qty
                            op.allocations[#op.allocations + 1] = { plan = p.id, qty = qty }
                            left[key] = left[key] - qty
                            sourceLeft[source][p.link] = sourceLeft[source][p.link] - qty
                            remaining = remaining - qty
                            p.reason = nil
                            p.reasonCode = nil
                        end
                    end
                end
                if remaining > 0 then p.reason, p.reasonCode = self:ExplainWaiting(p, items, phase, remaining, sourceLeft[source][p.link]) end
            end
            if p.reason then GridBagsActivity:Plan(p, p.state == "review" and "review" or "waiting", p.reason, p.reasonCode or "NEEDS_REVIEW") end
        elseif Active(p) then
            p.reason = rule and not rule.enabled and "Generating rule is paused" or
                (p.state == "source" and "Waiting for source character's bank visit" or "Waiting for destination character's bank visit")
            p.reasonCode = rule and not rule.enabled and "RULE_PAUSED" or "WAITING_CHARACTER"
            GridBagsActivity:Plan(p, "waiting", p.reason, p.reasonCode)
        end
    end
end

function R:Open()
    if not self:IsBanking() then return end
    if self.pending then return end
    if BMR then
        self.notice = "BankManager is still loaded. Reload/restart with it disabled before routing."
        if not self.conflictLoggedAt or GetTimeStamp()-self.conflictLoggedAt>1 then
            GridBagsActivity:Append({kind="control",outcome="skipped",reason=self.notice,code="AUTO_MOVER_CONFLICT"})
            self.conflictLoggedAt=GetTimeStamp()
        end
        self:Notify(); return
    end
    self.notice = nil
    local visit = self.data.visit
    if visit and visit.open and visit.character == self.character then
        -- A UI reload cannot turn the same opening into a fresh execution queue.
        if visit.inFlight then
            self:Hold(visit.inFlight, "UI reloaded during transfer; check both inventories before releasing reservations", "RELOAD_UNCERTAIN")
            visit.inFlight = nil
        end
        visit.index = 1 -- Revisit queued approvals, retaining the same frozen queue/journal.
    else
        self.data.nextVisit = (self.data.nextVisit or 0) + 1
        visit = { id = self.data.nextVisit, open = true, character = self.character, at = GetTimeStamp(), touched = {}, queue = {}, index = 1 }
        self.data.visit = visit
        local backpack, bank = self:Scan(self.character), self:Scan(BANK)
        self:ReconcileArrivals()
        self:GenerateRules(backpack, bank)
        self:BuildQueue(backpack, bank)
    end
    self.confirmAll = false
    EVENT_MANAGER:RegisterForUpdate(TIMER, 250, function() self:Tick() end)
    self:Tick()
end

function R:Close()
    if self.pending then self:Hold(self.pending, "Bank closed during transfer; reconcile manually", "BANK_CLOSED_UNCERTAIN") end
    self.pending = nil
    if self.data.visit then self.data.visit.open = false; self.data.visit.inFlight = nil end
    self.current = nil; self.confirmAll = false
    EVENT_MANAGER:UnregisterForUpdate(TIMER)
    self:Notify()
end

function R:Hold(op, reason, code)
    op.status = "review"; op.reason = reason
    for _, a in ipairs(op.allocations) do
        local p = self:Plan(a.plan)
        if p then p.reserve = true; p.state = "review"; p.reason = reason; p.reasonCode = code or "RESULT_UNCERTAIN" end
    end
    GridBagsActivity:Item(op, "review", reason, code or "RESULT_UNCERTAIN")
end

function R:IsCrossRecipe(plan)
    local smart=plan.smart
    return smart and smart.kind=="materials"and smart.scope=="known"and type(smart.craft)=="number"and smart.craft>=1 and smart.craft<=7 and not GridBagsCrafting:Related(plan.link,smart.craft)
end

function R:RequiresMaterialConsent(plan)
    return self:IsCrossRecipe(plan)or not GridBagsCrafting:AutomaticFurnitureRoute(plan.link,plan.source,plan.dest)
end

function R:NeedsRecipeConsent(op)
    for _,part in ipairs(op.allocations)do
        local p=self:Plan(part.plan)
        if p and self:RequiresMaterialConsent(p)and not p.recipeConsent then return true end
    end
    return false
end

function R:Allowed(op)
    if self:NeedsRecipeConsent(op)then return false end
    local units, moves = {}, {}
    for _, a in ipairs(op.allocations) do
        local p = self:Plan(a.plan)
        if not p or p.state ~= op.phase then return false end
        local rule = p.rule and self:Rule(p.rule)
        if rule and not rule.enabled then return false end
        if not p.approved then
            if p.mode == "standing" then
                -- Scoped to this named plan/rule; never inferred from Confirm All.
            elseif p.mode == "limited" and rule then
                units[rule.id] = (units[rule.id] or 0) + a.qty
                moves[rule.id] = (moves[rule.id] or 0) + 1
                if (rule.unitsLeft and rule.unitsLeft < units[rule.id]) or (rule.movesLeft and rule.movesLeft < moves[rule.id]) then return false end
            else return false end
        end
    end
    return true
end

function R:Destination(op)
    local bags = { BAG_BACKPACK }
    if op.phase == "source" then
        bags = { BAG_BANK }
        if IsESOPlusSubscriber and IsESOPlusSubscriber() then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    end
    local empty, free, touched = nil, 0, false
    local source = self:Read(op.bag, op.slot)
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagUseableSize(bag) - 1 do
            local item = self:Read(bag, slot)
            if not item then
                if not self:Touched(bag, slot) then empty = empty or { bag = bag, slot = slot, qty = 0 } else touched = true end
            elseif item.link == op.link and not item.blocked and item.bound == source.bound then
                local room = item.maxStack - item.qty
                if not self:Touched(item.bag, item.slot, item.uid) then
                    free = free + math.max(0, room)
                    if room >= op.qty then return item end
                elseif room >= op.qty then touched = true end
            end
        end
    end
    if empty then return empty end
    local place = op.phase == "source" and "Bank" or "Inventory"
    if touched then return nil, "Destination space was already used this bank opening", "DESTINATION_ALREADY_USED" end
    if free >= op.qty then return nil, place .. " space is fragmented: no single stack can hold the approved quantity", place:upper() .. "_FRAGMENTED" end
    return nil, place .. " is full: No room for the approved quantity in a usable slot or compatible stack", place:upper() .. "_FULL"
end

function R:Touched(bag, slot, uid)
    local journal = self.data.visit.touched
    return journal["slot:" .. bag .. ":" .. slot] or (uid and journal["uid:" .. uid])
end

function R:Touch(bag, slot, uid)
    self.data.visit.touched["slot:" .. bag .. ":" .. slot] = true
    if uid then self.data.visit.touched["uid:" .. uid] = true end
end

function R:Validate(op)
    if not self:IsBanking() then return nil, "Personal bank is not open in keyboard mode", "BANK_UNAVAILABLE" end
    if BMR then return nil, "BankManager is still loaded; planned transfers are blocked", "AUTO_MOVER_CONFLICT" end
    local item = self:Read(op.bag, op.slot)
    if not item then return nil, "Planned item is missing from its source slot; refresh the snapshot", "ITEM_MISSING" end
    if item.uid ~= op.uid or item.link ~= op.link then return nil, "Source identity changed since planning; refresh the snapshot", "SOURCE_CHANGED" end
    if item.qty < op.qty then return nil, "Source quantity is smaller than the planned move", "QUANTITY_CHANGED" end
    if item.blocked then return nil, item.blockedReason, item.blockedCode end
    if self:Touched(op.bag, op.slot, op.uid) then return nil, "Stack already used this bank opening", "SOURCE_ALREADY_USED" end
    local protection = self:Protection(op.source, op.link)
    if protection.blocked then return nil, "Source protected: never export", "SOURCE_PROTECTED" end
    if self:Total(self:Scan(op.source), op.link) - op.qty < self:KeepFloor(op.source,op.link) then
        if GridBagsRecipeGather and GridBagsRecipeGather:Keep(op.source,op.link)>0 then return nil,"Ingredients held for a confirmed recipe request; release its hold after crafting","RECIPE_GATHER_RESERVED"end
        return nil,"Source keep limit would be violated","KEEP_LIMIT"
    end
    if op.phase == "bank" and self:Total(self:Scan(BANK), op.link) < self:Reserved(op.link) then
        for _, p in ipairs(self.data.plans) do
            if p.link == op.link and p.state == "bank" then
                p.state = "review"; p.reserve = true; p.reason = "Bank reservation shortage; inspect and replan explicitly"
            end
        end
        return nil, "Bank reservation shortage; review required", "RESERVATION_MISSING"
    end
    for _, a in ipairs(op.allocations) do
        local p = self:Plan(a.plan)
        if not p or p.state ~= op.phase or p.remaining < a.qty then return nil, "Plan changed since queue was frozen", "PLAN_CHANGED" end
        if op.phase == "source" and p.sourceCount then
            local moved = (self.data.sourceMoved and self.data.sourceMoved[p.uid] or 0) - (p.sourceMovedAtPlan or 0)
            if item.qty < p.sourceCount - moved then return nil, "Source stack shrank since its planning observation; refresh/replan", "STALE_SNAPSHOT" end
        end
        local targetEligible, targetReason, targetCode = GridBagsSmartRouting:Eligible(p,item)
        if not targetEligible then return nil, targetReason, targetCode end
        local rule = p.rule and self:Rule(p.rule)
        if rule and not rule.enabled then return nil, "Rule paused/revoked", "RULE_PAUSED" end
    end
    local dest, reason, code = self:Destination(op)
    if not dest then return nil, reason, code end
    if self:Touched(dest.bag, dest.slot, dest.uid) then return nil, "Destination stack already used this opening", "DESTINATION_ALREADY_USED" end
    return dest
end

function R:Start(op,manual)
    if GridBagsActivity:IsPaused() then return end
    if self:NeedsRecipeConsent(op)and not manual then self.current=op;self:Notify();return end
    local dest, reason, code = self:Validate(op)
    if not dest then
        op.status = "skipped"; op.reason = reason
        for _, a in ipairs(op.allocations) do local p = self:Plan(a.plan); if p then p.reason = reason end end
        GridBagsActivity:Item(op, "skipped", reason, code)
        self.current = nil; self:Notify(); return
    end
    local item = self:Read(op.bag, op.slot)
    if manual then
        for _,part in ipairs(op.allocations)do local p=self:Plan(part.plan);if p and self:RequiresMaterialConsent(p)then p.recipeConsent=true end end
    end
    op.before = item.qty; op.destBag = dest.bag; op.destSlot = dest.slot; op.destBefore = dest.qty
    op.sentAt = GetFrameTimeSeconds(); op.status = "sent"
    self:Touch(op.bag, op.slot, op.uid); self:Touch(dest.bag, dest.slot, dest.uid)
    self.data.visit.inFlight = op; self.pending = op; self.current = nil
    GridBagsActivity:Item(op, "requested", "Transfer requested; awaiting inventory changes", "REQUESTED")
    -- The journal precedes the request; success is established by Observe, never by this return value.
    local ok, accepted, detail = pcall(CallSecureProtected, "RequestMoveItem", op.bag, op.slot, dest.bag, dest.slot, op.qty)
    if not ok or accepted == false then
        self:Hold(op, (ok and "Game rejected the transfer request" or "Client transfer call raised an error") ..
            ((ok and detail or accepted) and (": " .. tostring(ok and detail or accepted):sub(1, 1000)) or "") .. "; inspect before retrying",
            ok and "REQUEST_REJECTED" or "REQUEST_CALL_ERROR")
        self.pending = nil; self.data.visit.inFlight = nil
    end
    self:Notify()
end

function R:Observe()
    local op = self.pending
    if not op then return end
    local source, dest = self:Read(op.bag, op.slot), self:Read(op.destBag, op.destSlot)
    local sourceCount = source and source.qty or 0
    op.observedSourceCount, op.observedDestinationCount = sourceCount, dest and dest.qty or 0
    local sourceOK = not source or (source.link == op.link and source.uid == op.uid)
    if sourceOK and dest and dest.link == op.link and sourceCount == op.before - op.qty and dest.qty == op.destBefore + op.qty then
        self:Touch(dest.bag, dest.slot, dest.uid)
        if op.phase == "source" then
            self.data.sourceMoved = self.data.sourceMoved or {}
            self.data.sourceMoved[op.uid] = (self.data.sourceMoved[op.uid] or 0) + op.qty
        end
        for _, a in ipairs(op.allocations) do
            local p = self:Plan(a.plan)
            if p then
                if op.phase == "source" then
                    p.state = p.dest == BANK and "done" or "bank"
                    if p.maxStack == 1 then p.bankUid = dest.uid end
                else
                    p.remaining = p.remaining - a.qty
                    if p.remaining == 0 then p.state = "done" end
                end
                local rule = p.rule and self:Rule(p.rule)
                if rule and not p.funded then
                    if rule.unitsLeft then rule.unitsLeft = math.max(0, rule.unitsLeft - a.qty) end
                    if rule.movesLeft then rule.movesLeft = math.max(0, rule.movesLeft - 1) end
                end
                p.funded = true; p.approved = true; p.reason = nil; p.reserve = nil
            end
        end
        op.status = "done"; self.pending = nil; self.data.visit.inFlight = nil
        GridBagsActivity:Item(op, "success", "Source and destination quantities verified", "VERIFIED_MOVE")
        self.owner:QueueRefresh(); self:Notify()
    elseif GetFrameTimeSeconds() - op.sentAt > 4 then
        self:Hold(op, "Transfer timed out without matching source/destination changes; outcome uncertain, inspect both inventories", "TIMEOUT_UNCERTAIN")
        self.pending = nil; self.data.visit.inFlight = nil; self:Notify()
    end
end

function R:Tick()
    if not self:IsBanking() then return end
    if self.pending then self:Observe(); return end
    if GridBagsActivity:IsPaused() then return end
    if GridBagsGold and GridBagsGold.data and GridBagsGold:IsBusy() then return end
    if GridBagsRoutingUI and GridBagsRoutingUI.editingSession then return end
    local visit = self.data.visit
    if not visit or not visit.open then return end
    if self.current then return end
    while visit.index <= #visit.queue do
        local op = visit.queue[visit.index]
        visit.index = visit.index + 1
        if op.status == "queued" then
            local dest, reason, code = self:Validate(op)
            if not dest then
                op.status = "skipped"; op.reason = reason
                for _, a in ipairs(op.allocations) do local p = self:Plan(a.plan); if p then p.reason = reason end end
                GridBagsActivity:Item(op, "skipped", reason, code)
            elseif self.confirmAll or self:Allowed(op) then
                self:Start(op,self.confirmAll==true); return
            else self.current = op; self:Notify(); return end
        end
    end
    self:Notify()
end

function R:Confirm(all)
    if GridBagsActivity:IsPaused() then return end
    if GridBagsGold and GridBagsGold.data and GridBagsGold:IsBusy() then return end
    if GridBagsRoutingUI and GridBagsRoutingUI.editingSession then return end
    if not self.current then return end
    self.confirmAll = all == true
    self:Start(self.current,true)
end

function R:Skip(all)
    local visit = self.data.visit
    if self.current then
        self.current.status = "skipped"; self.current.reason = "Skipped by player"
        GridBagsActivity:Item(self.current, "skipped", self.current.reason, "USER_SKIP")
        self.current = nil
    end
    if all and visit then
        for _, op in ipairs(visit.queue) do if op.status == "queued" then
            op.status = "skipped"; op.reason = "Skipped by player"
            GridBagsActivity:Item(op, "skipped", op.reason, "USER_SKIP_ALL")
        end end
    end
    self:Notify()
end

function R:Notify()
    if GridBagsRoutingUI then GridBagsRoutingUI:Update(self) end
    if GridBagsDeliveryUI and GridBagsDeliveryUI.window then pcall(GridBagsDeliveryUI.Update,GridBagsDeliveryUI) end
end

function R:Initialize(owner)
    self.owner = owner; self.character = GetCurrentCharacterId()
    owner.saved.routing = owner.saved.routing or {}
    local world = GetWorldName()
    owner.saved.routing[world] = owner.saved.routing[world] or { plans = {}, rules = {}, protections = {}, profiles = {} }
    self.data = owner.saved.routing[world]
    for _, key in ipairs({ "plans", "rules", "protections", "profiles" }) do self.data[key] = self.data[key] or {} end
    EVENT_MANAGER:RegisterForEvent("GridBagsRouting", EVENT_OPEN_BANK, function()
        EVENT_MANAGER:RegisterForUpdate("GridBagsRoutingOpen", 400, function()
            EVENT_MANAGER:UnregisterForUpdate("GridBagsRoutingOpen"); self:Open()
        end)
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsRouting", EVENT_CLOSE_BANK, function()
        EVENT_MANAGER:UnregisterForUpdate("GridBagsRoutingOpen"); self:Close()
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsRouting", EVENT_PLAYER_ACTIVATED, function()
        if self:IsBanking() then self:Open()
        else
            if self.data.visit then self.data.visit.open = false end
            if self:ReconcileArrivals()>0 then self:Notify()end
        end
    end)
end

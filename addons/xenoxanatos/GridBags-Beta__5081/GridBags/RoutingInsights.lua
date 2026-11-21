GridBagsRoutingInsights = {}
local I = GridBagsRoutingInsights
local R,F,T = GridBagsRouting,GridBagsCrafting,GridBagsTransferTools
I.stages = {[0]="Learning copies",[1]="Specific items",[2]="Known-recipe ingredients",[3]="Usable materials",[4]="Profession storage",[5]="Gatherer clearing",[6]="Bank overflow"}
I.states = {source="Awaiting deposit",bank="Stored for pickup",review="Needs review",done="Completed",cancelled="Cancelled"}

function I:RuleLabel(rule)
    for index,value in ipairs(R.data.rules) do if value.id==rule.id then return "Rule "..index end end
    return "Former rule"
end

function I:Reason(plan)
    if plan.state=="done" then return plan.completionReason or (plan.dest==R.BANK and "Bank deposit verified; this storage route is complete." or "Delivery to destination inventory verified.") end
    if plan.state=="cancelled" then return "Cancelled; its repeat rule may still propose future batches unless paused or deleted." end
    for _,part in ipairs(R.pending and R.pending.allocations or {})do
        if part.plan==plan.id then return "Transfer requested; waiting for source and destination counts to verify the result. Do not assume completion yet."end
    end
    if plan.reason then return plan.reason end
    if plan.state=="review" then return "Outcome or reserved stock needs inspection; automatic retry is held." end
    if GridBagsActivity:IsPaused() then return "All planned transfers are paused." end
    local rule=plan.rule and R:Rule(plan.rule)
    if rule and not rule.enabled then return "The parent rule is paused." end
    local visit=R.data.visit
    if visit and visit.open then
        for _,op in ipairs(visit.queue or {})do
            for _,part in ipairs(op.allocations)do
                if part.plan==plan.id then
                    if op.status=="skipped"then return "Skipped this bank opening: "..(op.reason or "see transfer log")end
                    if R.current==op then return "Awaiting your confirmation for this bank operation; the named route is not yet complete."end
                end
            end
        end
    end
    if plan.state=="bank" then return "Reserved in the account bank for "..R:Name(plan.dest).."; collect on that character's personal-bank visit." end
    return "Waiting for "..R:Name(plan.source).." to visit a personal bank; approval, stock and space are checked then."
end

function I:Deliveries(filter)
    filter=filter or {};local rows={};local counts={source=0,bank=0,review=0,done=0,cancelled=0}
    local query=zo_strlower(filter.query or "")
    for _,p in ipairs(R.data.plans)do
        if counts[p.state]~=nil then counts[p.state]=counts[p.state]+1 end
        if (not filter.state or filter.state==p.state) and (not filter.character or p.source==filter.character or p.dest==filter.character) and
            (query=="" or zo_strlower(p.name or ""):find(query,1,true) or zo_strlower(p.link or ""):find(query,1,true)) then
            rows[#rows+1]=p
        end
    end
    table.sort(rows,function(a,b)return a.id>b.id end)
    return rows,counts
end

function I:DeliveryDetails(p)
    local rule=p.rule and R:Rule(p.rule)
    local lines={p.name or p.link,"Stage: "..(self.states[p.state]or tostring(p.state)),
        "Route: "..R:Name(p.source).." > "..R:Name(p.dest),"Planned units: "..p.qty,
        "Units awaiting delivery: "..((p.state=="done"or p.state=="cancelled")and 0 or p.remaining),
        "Reason: "..self:Reason(p),"Parent: "..(rule and self:RuleLabel(rule).." / "..rule.name or "One-time or detached delivery"),
        "Approval: "..(p.approved and "This named route is approved"or p.mode),
        "Approval and eligibility are separate. Every physical step checks identity, quantity, protections and space."}
    if p.reasonCode and p.state~="done"then lines[#lines+1]="Reason code: "..p.reasonCode end
    if p.observedAt then lines[#lines+1]="Planning observation age: "..math.max(0,math.floor((GetTimeStamp()-p.observedAt)/60)).." minutes"end
    if p.smart then lines[#lines+1]="Qualification: "..p.smart.kind..(p.smart.craft and " / "..F.names[p.smart.craft]or "")..(p.smart.scope and " / "..p.smart.scope or "") end
    if p.smart and p.smart.kind=="gatherRecipe"then
        local request=(R.data.gatherRequests or {})[p.smart.request]
        lines[#lines+1]="Selected recipe: "..(request and request.recipe.name or "Missing request").."; only the explicitly confirmed quantity is authorized."
        lines[#lines+1]="Release its ingredient hold in Gather ingredients > Requests after crafting."
    end
    if R:IsCrossRecipe(p)then lines[#lines+1]="Cross-profession known-recipe ingredient: "..(p.recipeConsent and "this named quantity was explicitly approved"or "manual approval required; Standing and Limited do not authorize it")end
    if p.state=="review"then lines[#lines+1]="Inspect actual inventories and the transfer log before cancelling or replanning. A review hold is not proof that nothing moved."end
    return table.concat(lines,"\n")
end

function I:SourceItems(rule)
    if rule.source==R.ANY then
        local items={}
        for _,source in ipairs({R.character,R.BANK})do
            if source~=rule.dest then
                local observed=self:SourceItems({source=source})
                for _,item in ipairs(observed)do
                    local copy={};for key,value in pairs(item)do copy[key]=value end
                    copy.insightSource=source;items[#items+1]=copy
                end
            end
        end
        return items,"Any source: current character and observed bank stock; offline characters wait for their own bank visits"
    end
    if rule.source==R.character then return R:Scan(R.character),"Live source inventory" end
    if rule.source==R.BANK and R:IsBanking()then return R:Scan(R.BANK),"Live personal bank"end
    local rec=rule.source==R.BANK and GridBags.saved.bankSnapshots[GetWorldName()] or GridBagsSnapshots.records[rule.source]
    return rec and rec.items or {},rec and "Saved source snapshot; live availability and capacity are unverified"or "Source has no saved observation"
end

function I:Matches(rule,item)
    if item.insightSource then
        if rule.source~=R.ANY and rule.source~=item.insightSource then return false end
        if rule.source==R.ANY then
            local copy={};for key,value in pairs(rule)do copy[key]=value end
            copy.source=item.insightSource;rule=copy
        end
    end
    return rule.material and F:MatchesSource(rule,item.link) or (not rule.material and rule.link==item.link)
end

function I:ExplainRule(rule)
    local ordered=R:OrderedRules();local position
    for index,value in ipairs(ordered)do if value.id==rule.id then position=index end end
    if not position then return "This rule no longer exists. Existing deposited deliveries retain their original destination; inspect them in Deliveries."end
    local lines={self:RuleLabel(rule).." / "..rule.name,
        "Processing position: "..tostring(position).." of "..#ordered.." (includes paused rules).",
        "Priority group: "..self.stages[R:RulePriority(rule)],"State: "..(rule.enabled and "Enabled"or "Paused"),
        "Route: "..R:Name(rule.source).." > "..R:Name(rule.dest),
        "Approval: "..rule.mode.."; maximum units per source stack: "..rule.maxPerStack,
        "Order: learning > specific items > known recipes > usable materials > profession storage > gatherer clearing > overflow. Within a group, named sources precede Any, then creation order applies.",
        "An earlier matching rule does not automatically win: eligibility, locks, keep limits, existing reservations and quantity caps decide what remains."}
    if rule.material then
        lines[#lines+1]="Material scope: "..F.names[rule.craft].." / "..rule.scope
        if rule.scope=="known"then lines[#lines+1]="Cross-profession ingredients only match a verified learned/craftable recipe. Each new cross-profession delivery needs explicit approval; this does not detect an actively selected recipe or request ingredients automatically."end
        if rule.sourceUnassigned then lines[#lines+1]="Source filter: retain materials for professions assigned to that concrete source as Crafter. Style/trait materials use separate categories."end
        if rule.scope~="all"then lines[#lines+1]="Missing/stale or unsupported crafting evidence holds stock against storage fallback. Definite ineligibility may fall back to an explicit storage route."end
    end
    if rule.mode=="limited"then lines[#lines+1]="Remaining allowance: "..tostring(rule.unitsLeft or "unlimited").." units / "..tostring(rule.movesLeft or "unlimited").." routes; then Ask."end
    if rule.overflowStacks then lines[#lines+1]="Overflow retains "..rule.overflowStacks.." full stacks before this rule can allocate unreserved bank stock."end
    local items,note=self:SourceItems(rule);lines[#lines+1]="\nOverlap examples: "..note
    local samples,links={},{}
    for _,item in ipairs(items)do
        if #samples>=40 then break end
        if not links[item.link]then samples[#samples+1]=item;links[item.link]=true end
    end
    local overlaps=0
    for index,other in ipairs(ordered)do
        if other.id~=rule.id and other.enabled and (other.source==rule.source or other.source==R.ANY or rule.source==R.ANY) then
            for _,item in ipairs(samples)do
                if self:Matches(rule,item)and self:Matches(other,item)then
                    lines[#lines+1]=self:RuleLabel(other).." ("..(index<position and "earlier"or "later").."): "..other.name.." also matches "..(item.displayName or item.name or item.link)
                    overlaps=overlaps+1;break
                end
            end
        end
        if overlaps>=8 then break end
    end
    if overlaps==0 then lines[#lines+1]="No enabled overlap found in the sampled source items. This does not exclude overlaps in future stock."end
    lines[#lines+1]="Overlap examples sample up to 40 item variants and 8 rules. They describe matching, not authorization or a promise to move."
    lines[#lines+1]="\nRead-only next-visit result (current character):"
    local preview,err=T:Preview();local n=0
    if preview then
        for _,row in ipairs(preview.rows)do
            if row.rule==rule.id then
                lines[#lines+1]=(row.item or rule.name).." x"..tostring(row.quantity).." > "..R:Name(row.destination)..": "..row.state.." / "..row.reason
                n=n+1;if n>=12 then break end
            end
        end
        if n==0 then lines[#lines+1]="No new proposal shown; existing batches, protections or the source character's availability may prevent new work."end
        lines[#lines+1]=preview.note
    else lines[#lines+1]=err end
    if rule.reason then lines[#lines+1]="Last recorded rule reason: "..rule.reason.." (from an earlier generation; see refreshed preview above)."end
    return table.concat(lines,"\n")
end

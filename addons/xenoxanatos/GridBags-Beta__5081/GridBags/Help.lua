-- Help is attached only to GridBags controls, never native inventory slot handlers.
GridBagsHelp = {}
local H = GridBagsHelp
H.text = {
    ["Gather ingredients..."]="Choose a learned recipe and review its ingredient needs, available stock and named source deliveries. Confirm selected transfers first. No crafting is triggered.",
    ["Recipe holds..."]="Open recipe requests to release their ingredient holds after crafting. Releasing a hold does not cancel previously approved deliveries; cancel those in the planner if unwanted.",
    ["Requests / release"]="Release a confirmed recipe's ingredient hold when finished crafting. Pending approved deliveries remain unless separately cancelled in the planner.",
    ["Protected items"]="Review Never export blocks and Keep reserves by source. Remove an accidental entry without locating the original inventory item. These settings override standing and blanket rules.",
    ["Remove protection"]="Remove both Never export and Keep for this exact item variant and source only. Approved queued work may proceed after its next live check. Other source protections, ESO item locks and uncertain transfer holds remain separate.",
    ["P"]="Plan a move for this item or stack. Snapshot items wait for the source character to visit a banker. Equipped snapshot gear is comparison context and cannot be exported while equipped.",
    ["Character..."]="Choose live current-character inventory, another character's last saved backpack/equipment, or the saved account bank. Offline views are read-only and can be used for planning.",
    ["Compare..."]="Choose a character's saved equipped gear for comparison while inspecting compatible items. This does not equip gear or move it.",
    ["GridBags view"]="Return from ESO's standard inventory to the grid. Your inventory contents and configured routes are retained.",
    ["Carried minimum"]="Refill carried gold toward this minimum at an eligible bank visit if refill is enabled. Deposits preserve the minimum; shared bank reserves are respected.",
    ["Carried maximum"]="Deposit carried gold above this ceiling. Leave blank to disable the maximum-balance deposit trigger.",
    ["Fixed deposit"]="Optional fixed gold deposit at an eligible visit or daily opportunity. It must pass the threshold, carried minimum and approval checks.",
    ["Deposit only above"]="Require carried gold to exceed this threshold before the fixed deposit is eligible.",
    ["Shared bank reserve"]="Protect this much account-bank gold against planned withdrawals for every character. This does not constrain manual native currency transfers.",
    ["Daily reset hour (UTC)"]="UTC hour used to group once-daily deposits. The deposit occurs at a qualifying bank visit, not automatically while offline.",
    ["Gold allowance left"]="Remaining automatically authorized gold units under Limited approval. After the budget is exhausted, confirmation is required.",
    ["Move allowance left"]="Remaining automatically authorized currency moves under Limited approval. This is separate from item-route allowances.",
    ["Preview these values"]="Explain what this gold configuration would propose using observed balances. Preview does not save the policy or move currency.",
    ["Deposit currency"]="Open ESO's native gold deposit dialog. Automatic gold is skipped for this bank opening to avoid competing with your manual transfer.",
    ["Withdraw currency"]="Open ESO's native gold withdrawal dialog. Automatic gold is skipped for this bank opening to avoid competing with your manual transfer.",
    ["Locked"]="Lock the grid window's position. Unlock to move it by its header; inventory and bank layouts remember separate positions.",
    ["Crafting / material rules"]="Inspect each character's profession skills and recipe scan, assign crafting roles, or create blanket material routes and gatherer clearing rules.",
    ["Profiles..."]="Assign general crafting, learning, research and overflow roles. Per-profession roles in Crafting can override these general defaults.",
    ["Frequency"]="Choose whether the fixed gold deposit is eligible each bank visit or once per UTC reset day. No transfer occurs while offline.",
    ["Per-move cap (0: none)"]="Maximum currency transferred in one automatic operation. Zero removes this cap; carried minima and bank reserves still apply.",
    ["Gold rules..."]="Open gold policy settings. Item and currency transfers are serialized so they do not compete for the same banking operation.",
    ["Skip this visit"]="Skip this gold proposal for the current bank opening. The saved policy can propose again at a later eligible visit.",
    ["Planner"]="Create and edit item routes. Mark an item with P, choose a destination and approval policy, then visit a personal bank.",
    ["Mark items: off"]="Show a P planning button on items. Planning a snapshot item does not move it; the source character must visit a banker.",
    ["Log"]="View transfer results and failure reasons. Open Deliveries here to track pending, banked and completed item routes.",
    ["Deliveries"]="Track saved item deliveries across characters. Filter by item, source/destination character or delivery stage. Viewing does not move or approve items.",
    ["Preview"]="Simulate the current character's next bank visit without moving items, reserving stock or spending approval allowances. Capacity is tentative away from a banker.",
    ["Pause transfers"]="Pause planned item and gold transfers. Already requested operations are still observed so their results can be recorded.",
    ["Backups / import"]="Back up or share rule settings. Imports start paused with rules disabled and Ask approval; existing deposited deliveries keep their custody records.",
    ["Report"]="Create a troubleshooting report that omits character names, item links, balances and snapshot contents. Activity details and configuration exports contain private data.",
    ["Suggest recipient..."]="Offer designated crafters who can use this material, characters with suitable learned recipes, or eligible recipe/trait learners. Selecting a suggestion does not approve a move.",
    ["Approval"]="Ask confirms a batch at the bank. Advance preapproves one named route. Limited spends a configured allowance then asks. Standing continues until paused or revoked.",
    ["Units per plan/stack"]="Maximum units taken from each matching stack in a new batch. Actual quantities also obey source keep limits, reservations and available stock.",
    ["Automatic unit allowance"]="Units authorized automatically by a Limited rule. Zero means exhausted; a blank counter is unlimited when the other counter is specified.",
    ["Automatic route allowance"]="Number of named routes authorized automatically by a Limited rule. Funding a route covers its bank deposit and pickup rather than spending twice.",
    ["Overflow: retain stacks"]="Send only unreserved stock above this number of full bank stacks. This threshold applies to the overflow rule; it is not a protected minimum against every withdrawal.",
    ["Keep units on source"]="Keep at least this many units of the exact item variant on this source. This overrides every planned route and approval.",
    ["Never export: off"]="Protect this exact item variant from all planned exports from the selected source, including standing and blanket rules.",
    ["One-time plan"]="Create one named delivery. Ask or Advance applies to this delivery; it does not authorize future matching items.",
    ["Repeat rule"]="Create transactions for newly unallocated stock on later bank visits, even while earlier deliveries await pickup. Existing quantities remain reserved; fresh Ask transactions still need confirmation.",
    ["Learning rule"]="Allocate one copy to eligible learner profiles with confirmed missing knowledge. Known, researching, duplicate and missing-data cases are held or excluded.",
    ["Bank overflow"]="Create a repeat route from bank stock above the retained stack threshold, after earlier crafting and learning allocations.",
    ["Confirm all"]="Approve the remaining queued operations for this bank opening. This does not turn an Ask rule into permanent standing approval.",
    ["Skip all"]="Skip remaining queued operations for this bank opening. Pending routes can be reconsidered on a later visit; pause or delete their rules to stop future batches.",
    ["New material rule"]="Route a profession's materials by storage, usable tier or learned-recipe eligibility. Named character deliveries pass through the account bank.",
    ["Clear gatherer's materials..."]="Start an Ask rule for a farming character's materials. The optional source filter keeps materials for professions assigned to that source as Crafter.",
    ["Roles..."]="Assign this character as crafter, researcher or learner for this profession. Lower priority numbers break earned-rank and passive-investment ties.",
    ["Max units / stack"]="Cap each matching source stack in a material batch. Earlier specific routes and existing reservations receive stock first.",
    ["Allowance units"]="Limited approval's remaining automatic unit budget. Leave blank for unlimited units only when a move counter is set.",
    ["Allowance moves"]="Limited approval's remaining automatic route budget. Leave blank for unlimited moves only when a unit counter is set.",
    ["Gold rules"]="Configure carried gold minimum/maximum and optional fixed deposits. Shared bank reserves, approval and per-visit limits still apply.",
    ["Sort..."]="Change display order only. Sorting does not physically rearrange bag slots or create routing rules.",
    ["Filters..."]="Choose inventory filters. Filtering hides nonmatching items from the view; it does not alter your items or route rules.",
    ["Standard view"]="Show ESO's normal inventory. Use its GridBags view button to return to the grid.",
}
function H:Bind(control, body)
    if not control then return end
    control.gridBagsHelp = body
    if control.gridBagsHelpBound then return end
    control.gridBagsHelpBound = true
    local enter, leave = control:GetHandler("OnMouseEnter"), control:GetHandler("OnMouseExit")
    control:SetHandler("OnMouseEnter",function(c,...)
        if enter then enter(c,...) end
        if not InformationTooltip then return end
        local text = type(c.gridBagsHelp)=="function" and c.gridBagsHelp(c) or c.gridBagsHelp
        if not text then return end
        InitializeTooltip(InformationTooltip,c,TOPLEFT,0,0,BOTTOMLEFT)
        H.owner=c
        if SetTooltipText then SetTooltipText(InformationTooltip,text) else InformationTooltip:AddLine(text) end
    end)
    control:SetHandler("OnMouseExit",function(c,...)
        if leave then leave(c,...) end
        if InformationTooltip and H.owner==c then ClearTooltip(InformationTooltip);H.owner=nil end
    end)
end
function H:Auto(control, label)
    local body = self.text[label]
    if body then self:Bind(control,body) end
end

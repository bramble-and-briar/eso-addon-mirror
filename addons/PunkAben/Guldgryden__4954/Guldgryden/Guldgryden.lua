local NAME, VERSION = 'Guldgryden', '0.5.2'
local PROTECTED = {
    [115026]='Aetherial Dust', [120894]='Animus Stone', [27059]='Bervez Juice',
    [171326]='Cyrodiil Citrus', [120078]='Diminished Aetherial Dust',
    [26802]='Frost Mirriam', [171433]='Mourning Dew', [64222]='Perfect Roe',
    [224836]='Portent of Curiosity', [225210]='Red Lichen', [171328]='Rubyblosson Extract',
}
local MAX_BATCH = 999
Guldgryden = Guldgryden or {}
local G = Guldgryden
G.ledger, G.expanded, G.store, G.running, G.runId = {}, false, false, false, 0
local C, EM, WM = G.Core, EVENT_MANAGER, WINDOW_MANAGER
local CRAFT_TIMEOUT_HANDLER = NAME .. 'CraftTimeout'
local SALE_POLL_HANDLER = NAME .. 'SalePoll'
local SALE_CHECK_HANDLER = NAME .. 'SaleCheck'
local function Say(s) d('|cD8BC77Guldgryden:|r ' .. s) end
local function Pretty(n) return tostring(math.floor(n or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '') end
local function ItemKey(link)
    return tostring(GetItemLinkItemId(link)) .. ':' .. tostring(GetItemLinkRequiredLevel(link)) .. ':' .. tostring(GetItemLinkRequiredChampionPoints(link)) .. ':' .. tostring(GetItemLinkFunctionalQuality(link))
end
local function BackpackCount(key)
    local count = 0
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        if link ~= '' and ItemKey(link) == key then count = count + GetSlotStackSize(BAG_BACKPACK, slot) end
    end
    return count
end
local function AtStation() return GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING end
function G:Reconcile()
    for key, entry in pairs(self.ledger) do
        if not (self.inflight and self.inflight.row.recipe.itemKey == key) and not (self.sale and self.sale.key == key) then
            local current = BackpackCount(key)
            -- Losses are charged to our production first; additions never authorize sales.
            entry.pending = math.max(0, math.min(current, entry.pending - math.max(0, (entry.observed or current) - current)))
            entry.observed, entry.baseline = current, current - entry.pending
            if entry.pending == 0 then self.ledger[key] = nil end
        end
    end
end
function G:Status(s, good)
    self.status:SetText((good and '|c9DD18A' or '|cE1B46A') .. s .. '|r')
end
function G:Stop(reason)
    self.autoLeaveCraft = false
    self.running = false
    self.runId = self.runId + 1
    self.start:SetText('Start crafting')
    if reason then self:Status(reason, false) end
end
function G:CancelCraftTimeout()
    EM:UnregisterForUpdate(CRAFT_TIMEOUT_HANDLER)
end
function G:ArmCraftTimeout(operation)
    self:CancelCraftTimeout()
    EM:RegisterForUpdate(CRAFT_TIMEOUT_HANDLER, 120000, function()
        self:CancelCraftTimeout()
        if self.inflight == operation then
            self.inflight = nil
            self:Stop('No response from the game · crafting stopped.')
        end
    end)
end
function G:CancelSalePoll()
    EM:UnregisterForUpdate(SALE_POLL_HANDLER)
end
function G:ScheduleSaleCheck()
    if self.saleCheckScheduled then return end
    self.saleCheckScheduled = true
    EM:RegisterForUpdate(SALE_CHECK_HANDLER, 50, function()
        EM:UnregisterForUpdate(SALE_CHECK_HANDLER)
        self.saleCheckScheduled = false
        self:CheckSale()
    end)
end
function G:HasProduction()
    for key, entry in pairs(self.ledger) do
        if C.Sellable(entry.pending, BackpackCount(key), entry.baseline) > 0 then return true end
    end
    return false
end
function G:PlanHasRoom()
    local first = self.plan and self.plan.rows[1]
    if not first then return false end
    for _, row in ipairs(self.plan.rows) do
        if row.recipe.value < first.recipe.value then break end
        if row.count > 0 and self:RoomCrafts(row.recipe) > 0 then return true end
    end
    return false
end
function G:Scan()
    if self.running or self.inflight then return end
    if not AtStation() then self:Status('Visit a cooking fire to see your crafting plan.', false); return end
    local recipes, owned = {}, {}
    local missingImprovement, missingQuality = false, false
    local improvement = GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_LEVEL)
    local rarity = GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL)
    for list = 1, GetNumRecipeLists() do
        local _, count = GetRecipeListInfo(list)
        for recipe = 1, count do
            local known, _, n, levelReq, qualityReq, _, station = GetRecipeInfo(list, recipe)
            if known and station == CRAFTING_TYPE_PROVISIONING and n == 2 then
                local link = GetRecipeResultItemLink(list, recipe, LINK_STYLE_DEFAULT)
                local kind = GetItemLinkItemType(link)
                local name, _, _, price, quality = GetRecipeResultItemInfo(list, recipe)
                if (kind == ITEMTYPE_FOOD or kind == ITEMTYPE_DRINK) and quality == ITEM_DISPLAY_QUALITY_MAGIC and price >= 1 then
                    local r = {list = list, recipe = recipe, key = list .. ':' .. recipe, link = link,
                        itemKey = ItemKey(link), name = zo_strformat('<<1>>', name), value = price,
                        output = GetRecipeResultQuantity(list, recipe, 1), ingredients = {}}
                    local valid = r.output and r.output > 0
                    for i = 1, n do
                        local ingLink = GetRecipeIngredientItemLink(list, recipe, i, LINK_STYLE_DEFAULT)
                        local ingName, _, qty, _, ingQuality = GetRecipeIngredientItemInfo(list, recipe, i)
                        local id = GetItemLinkItemId(ingLink)
                        if qty ~= 1 or ingQuality ~= ITEM_DISPLAY_QUALITY_NORMAL or id == 0 or PROTECTED[id] then valid = false end
                        r.ingredients[#r.ingredients + 1] = {id = id, qty = qty, index = i, name = zo_strformat('<<1>>', ingName)}
                        owned[id] = GetCurrentRecipeIngredientCount(list, recipe, i)
                    end
                    if valid then
                        local enough = true
                        for _, ing in ipairs(r.ingredients) do
                            if owned[ing.id] - self.saved.reserve < ing.qty then enough = false end
                        end
                        local needsLevel, needsQuality = levelReq > improvement, qualityReq > rarity
                        if enough then
                            missingImprovement = missingImprovement or needsLevel
                            missingQuality = missingQuality or needsQuality
                        end
                        if not needsLevel and not needsQuality then recipes[#recipes + 1] = r end
                    end
                end
            end
        end
    end
    self.recipes, self.owned = recipes, owned
    self.plan = C.Plan(recipes, owned, self.saved.reserve)
    -- Plan from skills and ingredients, independent of the game's bag-limited craft maximum.
    self.spaceBlocked = GetNumBagFreeSlots(BAG_BACKPACK) == 0 and not self:PlanHasRoom()
    self:Render()
    self:Status(#self.plan.rows > 0 and 'Ready · crafts until your bag is full or reserves are reached' or 'No eligible recipes with ingredients above your reserve.', #self.plan.rows > 0)
    if self.spaceBlocked then
        self:Status('Your bag is full – make room or visit a merchant.', false)
    elseif missingImprovement or missingQuality then
        local skills = {}
        if missingImprovement then skills[#skills + 1] = 'Recipe Improvement' end
        if missingQuality then skills[#skills + 1] = 'Recipe Quality' end
        local prefix = #self.plan.rows > 0 and 'More recipes require skill points in:\n' or 'Missing Provisioning skill points:\n'
        self:Status(prefix .. table.concat(skills, ' / '), false)
    elseif #self.plan.rows > 0 then
        local outputSkills = {}
        if GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD) < 3 then outputSkills[#outputSkills + 1] = 'Chef' end
        if GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_DRINK) < 3 then outputSkills[#outputSkills + 1] = 'Brewer' end
        if #outputSkills > 0 then self:Status('Ready · for maximum yield, invest 3/3 in:\n' .. table.concat(outputSkills, ' / '), false) end
    end
end
function G:Render()
    local plan = self.plan or {rows = {}, gold = 0, crafts = 0, portions = 0}
    self.summary:SetText('Keep each ingredient: |cD8BC77' .. Pretty(self.saved.reserve) .. '|r\n\nExpected income: |cD8BC77' .. Pretty(plan.gold) .. ' gold|r\nCrafts remaining: ' .. Pretty(plan.crafts) .. ' · ' .. Pretty(plan.portions) .. ' portions\nFree bag slots: ' .. GetNumBagFreeSlots(BAG_BACKPACK) .. '\nContinues automatically while there is room')
    self.detailButton:SetText(self.expanded and '− Hide recipes and ingredients' or '+ Show recipes and ingredients')
    local lines, remaining = {}, {}
    for id, count in pairs(self.owned or {}) do remaining[id] = count end
    for _, row in ipairs(plan.rows) do
        for _, ing in ipairs(row.recipe.ingredients) do remaining[ing.id] = (remaining[ing.id] or 0) - row.count * ing.qty end
    end
    for _, row in ipairs(plan.rows) do
        local r = row.recipe
        if row.count > 0 then
            local a, b = r.ingredients[1], r.ingredients[2]
            lines[#lines + 1] = '|cD8BC77' .. r.name .. '|r\n' .. Pretty(row.count * r.output) .. ' portions · ' .. Pretty(row.count * r.output * r.value) .. ' gold\n' .. a.name .. ' + ' .. b.name .. '\nLeft after the full plan: ' .. Pretty(remaining[a.id]) .. ' / ' .. Pretty(remaining[b.id])
        end
    end
    self.details:SetText(table.concat(lines, '\n\n'))
    self.details:GetParent():SetHeight(math.max(200, self.details:GetTextHeight() + 12))
    self.detailScroll:SetHidden(not self.expanded)
    self.window:SetHeight(self.expanded and 610 or 395)
end
function G:RoomCrafts(r)
    local space, observedMax = 0, nil
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        if link ~= '' and ItemKey(link) == r.itemKey and not IsItemPlayerLocked(BAG_BACKPACK, slot) and not IsItemStolen(BAG_BACKPACK, slot) then
            local count, max = GetSlotStackSize(BAG_BACKPACK, slot)
            space = space + math.max(0, max - count)
            observedMax = max
        end
    end
    -- Until a matching stack exists, reserve one free slot per craft conservatively.
    local capacity = space + GetNumBagFreeSlots(BAG_BACKPACK) * (observedMax or r.output)
    return math.floor(capacity / r.output)
end
function G:Next()
    if not self.running or self.inflight then return end
    if not AtStation() then self:Stop('Stopped: you left the cooking fire.'); return end
    if IsAwaitingCraftingProcessResponse() then self:Stop('Another crafting operation is in progress.'); return end
    local selected, batch, blockedBySpace, activePrice
    for _, row in ipairs(self.plan.rows) do
        local r = row.recipe
        if activePrice and r.value < activePrice then break end
        local allowed = math.min(row.count, MAX_BATCH)
        for _, ing in ipairs(r.ingredients) do
            if PROTECTED[ing.id] then allowed = 0 end
            local surplus = GetCurrentRecipeIngredientCount(r.list, r.recipe, ing.index) - self.saved.reserve
            allowed = math.min(allowed, math.max(0, math.floor(surplus / ing.qty)))
        end
        if allowed > 0 then
            activePrice = r.value
            local room = self:RoomCrafts(r)
            if room > 0 then
                -- Capture only the first return. The second is a reason code, NOT a craft limit.
                local gameMax = GetMaxIterationsPossibleForRecipe(r.list, r.recipe)
                allowed = math.min(allowed, room, gameMax)
                if allowed > 0 then selected, batch = row, allowed; break end
            else blockedBySpace = true end
        end
    end
    if not selected then
        local leave = self.autoLeaveCraft and (self.done or 0) > 0 and self:HasProduction()
        self:Stop(blockedBySpace and 'Your bag is full – make room or visit a merchant.' or 'Crafting complete.')
        if leave and AtStation() and not IsAwaitingCraftingProcessResponse() then EndInteraction(INTERACTION_CRAFT) end
        return
    end
    local r = selected.recipe
    local before = BackpackCount(r.itemKey)
    self:Reconcile()
    if not self.ledger[r.itemKey] then self.ledger[r.itemKey] = {baseline = before, pending = 0, observed = before} end
    local operation = {row = selected, before = before, runId = self.runId, iterations = batch, expected = GetRecipeResultQuantity(r.list, r.recipe, batch)}
    self.inflight = operation
    self:Status('Crafting ' .. Pretty(operation.expected) .. ' portions · ' .. r.name, true)
    local ok, err = pcall(CraftProvisionerItem, r.list, r.recipe, batch)
    if not ok then self.inflight = nil; self:Stop('Could not start crafting: ' .. tostring(err)); return end
    self:ArmCraftTimeout(operation)
end
function G:Start()
    if self.running then self:Stop(self.inflight and 'Stopping after the current batch.' or 'Crafting stopped.'); return end
    if self.inflight then self:Status('Wait for the current batch to finish.', false); return end
    if not AtStation() then self:Status('You must be at a cooking fire.', false); return end
    self:Scan()
    if self.spaceBlocked or not self.plan or #self.plan.rows == 0 then return end
    self.done = 0; self.running = true; self.runId = self.runId + 1
    self.autoLeaveCraft = true
    self.start:SetText('Stop crafting')
    self:Next()
end
function G:CraftCompleted(skill)
    if skill ~= CRAFTING_TYPE_PROVISIONING or not self.inflight then return end
    local operation = self.inflight
    self:CancelCraftTimeout()
    zo_callLater(function()
        if self.inflight ~= operation then return end
        self.inflight = nil
        local r = operation.row.recipe
        local gained = BackpackCount(r.itemKey) - operation.before
        -- Only trust a matching observed result; never authorize an unobserved sale.
        if gained ~= operation.expected then self:Stop('Unexpected yield (' .. gained .. '/' .. operation.expected .. ') · stopped.'); return end
        local entry = self.ledger[r.itemKey]
        if entry then entry.pending = entry.pending + gained; entry.observed = BackpackCount(r.itemKey) end
        for _, ing in ipairs(r.ingredients) do
            if self.owned then self.owned[ing.id] = GetCurrentRecipeIngredientCount(r.list, r.recipe, ing.index) end
        end
        operation.row.count = operation.row.count - operation.iterations
        self.done = self.done + operation.iterations
        self.plan.crafts = math.max(0, self.plan.crafts - operation.iterations)
        self.plan.portions = math.max(0, self.plan.portions - gained)
        self.plan.gold = math.max(0, self.plan.gold - gained * r.value)
        self:Render()
        if self.running and self.runId == operation.runId then self:Next() end
    end, 250)
end
function G:SaleSummary()
    if (self.soldPortions or 0) > 0 then Say('Sold ' .. Pretty(self.soldPortions) .. ' portions for ' .. Pretty(self.soldGold) .. ' gold.') end
    self.soldPortions, self.soldGold = 0, 0
end
function G:CheckSale()
    local op = self.sale
    if not op then return end
    local current = BackpackCount(op.key)
    local removed = op.before - current
    local paid = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) - op.money
    if removed == op.amount and paid == op.amount * op.value then
        self:CancelSalePoll()
        op.entry.pending = math.max(0, op.entry.pending - removed)
        op.entry.observed = current
        self.sale, self.selling = nil, false
        self.soldPortions = (self.soldPortions or 0) + removed
        self.soldGold = (self.soldGold or 0) + paid
        zo_callLater(function() self:SellNext() end, 10)
    elseif op.polls >= 100 or removed < 0 or removed > op.amount then
        self:CancelSalePoll()
        self.ledger[op.key] = nil
        self.sale, self.selling, self.saleFailed = nil, false, true
        self:SaleSummary()
        Say('Sale could not be confirmed. Close the merchant before trying again.')
    end
end
function G:SellNext()
    if self.selling then return end
    if not self.store or not self.saved.autoSell or self.saleFailed then self:SaleSummary(); return end
    self:Reconcile()
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        if link ~= '' and not IsItemPlayerLocked(BAG_BACKPACK, slot) and not IsItemStolen(BAG_BACKPACK, slot) then
            local key = ItemKey(link)
            local entry = self.ledger[key]
            if entry then
                local count = BackpackCount(key)
                local amount = math.min(GetSlotStackSize(BAG_BACKPACK, slot), C.Sellable(entry.pending, count, entry.baseline))
                if amount > 0 then
                    local value = GetItemSellValueWithBonuses(BAG_BACKPACK, slot)
                    if value <= 0 then return end
                    self.selling = true
                    local op = {key=key, entry=entry, before=count, amount=amount, value=value,
                        money=GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER), polls=0}
                    self.sale = op
                    local ok = pcall(SellInventoryItem, BAG_BACKPACK, slot, amount)
                    if not ok then
                        self.sale, self.selling, self.saleFailed = nil, false, true
                        self.ledger[key] = nil; self:SaleSummary(); Say('Could not start selling.'); return
                    end
                    self:CancelSalePoll()
                    EM:RegisterForUpdate(SALE_POLL_HANDLER, 50, function()
                        if self.sale ~= op then self:CancelSalePoll(); return end
                        op.polls = op.polls + 1
                        self:CheckSale()
                    end)
                    return
                end
            end
        end
    end
    local leave = (self.soldPortions or 0) > 0 and not self:HasProduction()
    self:SaleSummary()
    if leave and self.store then EndInteraction(INTERACTION_VENDOR) end
end
local function Label(parent, name, x, y, width, text)
    local c = WM:CreateControl(name, parent, CT_LABEL)
    c:SetFont('ZoFontGame'); c:SetWidth(width); c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetText(text or '')
    return c
end
local function Button(parent, name, x, y, width, text, handler)
    local c = WM:CreateControlFromVirtual(name, parent, 'ZO_DefaultButton')
    c:SetDimensions(width, 32); c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetText(text); c:SetHandler('OnClicked', handler)
    return c
end
function G:CreateUI()
    local w = WM:CreateTopLevelWindow('GuldgrydenWindow'); self.window = w
    w:SetDimensions(550, 395); w:SetAnchor(CENTER, GuiRoot, CENTER, 200, 0)
    if self.saved.position then w:ClearAnchors(); w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.position.x, self.saved.position.y) end
    w:SetHandler('OnMoveStop', function() self.saved.position = {x=w:GetLeft(), y=w:GetTop()} end)
    w:SetMovable(true); w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetHidden(true)
    local bg = WM:CreateControl(nil, w, CT_BACKDROP); bg:SetAnchorFill(w); bg:SetCenterColor(0.09,0.08,0.06,0.98); bg:SetEdgeColor(0.6,0.5,0.3,1)
    Label(w, nil, 20, 14, 390, '|cD8BC77Guldgryden|r'):SetFont('ZoFontWinH2')
    Button(w, nil, 488, 12, 40, 'X', function() self:Stop(); w:SetHidden(true) end)
    self.summary = Label(w, nil, 22, 58, 500, 'Visit a cooking fire to see your crafting plan.')
    self.detailButton = Button(w, nil, 20, 215, 500, '+ Show recipes and ingredients', function() self.expanded = not self.expanded; self.saved.expanded = self.expanded; self:Render() end)
    local scroll = WM:CreateControlFromVirtual('GuldgrydenDetails', w, 'ZO_ScrollContainer'); self.detailScroll = scroll
    scroll:SetAnchor(TOPLEFT, w, TOPLEFT, 24, 254); scroll:SetDimensions(500, 200); scroll:SetHidden(true)
    local child = scroll:GetNamedChild('ScrollChild')
    self.details = Label(child, nil, 0, 0, 465, '')
    self.status = Label(w, nil, 0, 0, 500, '')
    self.status:ClearAnchors(); self.status:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 22, -98)
    self.start = Button(w, nil, 0, 0, 510, 'Start crafting', function() self:Start() end)
    self.start:ClearAnchors(); self.start:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 15, -49)
    local note = Label(w, nil, 0, 0, 510, 'Green food/drink · white ingredients · 5 → 4 → 3 → 2 → 1 gold')
    note:ClearAnchors(); note:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 20, -18); note:SetFont('ZoFontGameSmall')
end
function G:Settings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    LAM:RegisterAddonPanel('GuldgrydenSettings', {type = 'panel', name = NAME, displayName = NAME, author = 'Punk & Nova', version = VERSION, registerForRefresh = true})
    local options = {
        {type = 'editbox', name = 'Minimum to keep of each ingredient', tooltip = 'Only ingredients above this reserve may be used.', isMultiline = false,
            getFunc = function() return tostring(self.saved.reserve) end,
            setFunc = function(s) local n = tonumber(s); if n and n >= 0 then self:Stop('Ingredient reserve changed.'); self.saved.reserve = math.floor(n); if not self.inflight then self.plan = nil end; self:Render() end end,
            default = '1000'},
        {type = 'checkbox', name = 'Sell Guldgryden products at merchants', getFunc = function() return self.saved.autoSell end,
            setFunc = function(v) self.saved.autoSell = v end, default = true},
        {type = 'description', text = 'Uses only white ingredients. Stop lets the current batch finish. Unsold products are tracked per character. Moving or consuming products reduces the amount available for automatic sale. The planner compares three allocations within each price tier; a global optimum is not guaranteed.'},
        {type = 'description', text = 'The 11 protected special ingredients are never used. White ingredients follow your reserve.'},
        {type = 'description', text = 'Provisioning: Recipe Improvement 6/6 unlocks the highest recipe levels. Recipe Quality must meet the recipe requirements; green recipes do not require 4/4. Chef 3/3 maximizes food yield and Brewer 3/3 maximizes drink yield. The plan always uses your actual yield.'},
    }
    LAM:RegisterOptionControls('GuldgrydenSettings', options)
end
local function Loaded(_, addon)
    if addon ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    G.saved = ZO_SavedVars:NewAccountWide('GuldgrydenSaved', 1, nil, {reserve = 1000, autoSell = true, characters = {}})
    G.saved.protected = nil -- Remove obsolete per-ingredient switches.
    -- Character IDs are already unique across megaservers. Migrate the former
    -- world-prefixed keys without discarding any existing production ledger.
    for oldKey, ledger in pairs(G.saved.characters) do
        local characterId = oldKey:match('^.-:(%d+)$')
        if characterId then
            if not G.saved.characters[characterId] then G.saved.characters[characterId] = ledger end
            G.saved.characters[oldKey] = nil
        end
    end
    local character = tostring(GetCurrentCharacterId())
    G.saved.characters[character] = G.saved.characters[character] or {}
    G.ledger = G.saved.characters[character]
    G.expanded = G.saved.expanded == true
    G:CreateUI(); G:Settings()
    SLASH_COMMANDS['/gg'] = function(args)
        local n = args:match('^keep%s+(%d+)$') or args:match('^behold%s+(%d+)$')
        if n then G:Stop(); G.saved.reserve = tonumber(n); if not G.inflight then G.plan = nil end; G:Render(); Say('Keeping at least ' .. n .. ' of each ingredient.'); return end
        G.window:SetHidden(not G.window:IsHidden())
        if not G.window:IsHidden() then G:Scan() end
    end
    EM:RegisterForEvent(NAME, EVENT_CRAFTING_STATION_INTERACT, function(_, skill)
        if skill == CRAFTING_TYPE_PROVISIONING then G.window:SetHidden(false); G:Scan() end
    end)
    EM:RegisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT, function()
        G:CancelCraftTimeout()
        G.inflight = nil
        G:Stop('You left the cooking fire.')
        G.window:SetHidden(true)
    end)
    EM:RegisterForEvent(NAME, EVENT_CRAFT_COMPLETED, function(_, skill) G:CraftCompleted(skill) end)
    EM:RegisterForEvent(NAME, EVENT_CRAFT_FAILED, function() if G.inflight then G:CancelCraftTimeout(); G.inflight = nil; G:Stop('The game rejected the craft · stopped.'); end end)
    EM:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() G:Reconcile() end)
    EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        G:Reconcile(); G:ScheduleSaleCheck()
    end)
    EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EM:RegisterForEvent(NAME, EVENT_MONEY_UPDATE, function() G:ScheduleSaleCheck() end)
    EM:RegisterForEvent(NAME, EVENT_OPEN_STORE, function() G.store = true; G.saleFailed = false; zo_callLater(function() G:SellNext() end, 100) end)
    EM:RegisterForEvent(NAME, EVENT_CLOSE_STORE, function()
        G.store = false
        G:CancelSalePoll()
        if G.sale then
            G.ledger[G.sale.key] = nil -- Sale was not confirmed; fail closed against overselling.
            G.sale, G.selling, G.saleFailed = nil, false, true
        end
        G:SaleSummary()
    end)
    Say(VERSION .. ' ready. Visit a cooking fire or type /gg.')
end
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Loaded)

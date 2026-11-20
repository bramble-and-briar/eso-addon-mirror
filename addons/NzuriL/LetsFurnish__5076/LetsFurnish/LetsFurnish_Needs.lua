local LF = LetsFurnish
local ask, L = LF.ask, LF.L
local count, list, sentences = LF.count, LF.list, LF.sentences
local made
local function recipes()
    if made and next(made) then return made end
    made = {}
    for listIndex = 1, ask(GetNumRecipeLists) or 0 do
        local _, numRecipes = ask(GetRecipeListInfo, listIndex)
        for index = 1, numRecipes or 0 do
            local resultId = select(8, ask(GetRecipeInfo, listIndex, index))
            if type(resultId) == "number" and resultId ~= 0 and not made[resultId] then made[resultId] = { listIndex, index } end
        end
    end
    return made
end
local function materialKey(link, name)
    local id = link and ask(GetItemLinkItemId, link)
    if type(id) == "number" and id ~= 0 then return "item:" .. tostring(id) end
    return "name:" .. tostring(LF.clean(name))
end
function LF.recipeOf(itemId)
    local at = recipes()[itemId]
    if not at then return nil end
    local listIndex, index = at[1], at[2]
    local known, name, numIngredients, _, _, _, station = ask(GetRecipeInfo, listIndex, index)
    local yield = ask(GetRecipeResultQuantity, listIndex, index, 1)
    local recipe = { list = listIndex, index = index, known = known == true, name = LF.clean(LF.nonempty(name)),
                     listName = LF.clean(ask(GetRecipeListInfo, listIndex)) or "",
                     station = station and LF.nonempty(ask(GetCraftingSkillName, station) or "") or nil,
                     yield = (type(yield) == "number" and yield > 0) and yield or 1,
                     link = LF.nonempty(ask(GetRecipeResultItemLink, listIndex, index, LINK_STYLE_BRACKETS)), ingredients = {} }
    for i = 1, numIngredients or 0 do
        local name, icon, quantity = ask(GetRecipeIngredientItemInfo, listIndex, index, i)
        local link = LF.nonempty(ask(GetRecipeIngredientItemLink, listIndex, index, i, LINK_STYLE_BRACKETS))
        if LF.nonempty(LF.clean(name) or "") == nil or (quantity or 0) <= 0 or not (link and (ask(GetItemLinkItemId, link) or 0) > 0) then
            recipe.hidden = true
        else
            recipe.ingredients[#recipe.ingredients + 1] = { key = materialKey(link, name), name = LF.clean(name), icon = LF.nonempty(icon), link = link,
                                                            need = quantity, have = ask(GetCurrentRecipeIngredientCount, listIndex, index, i) or 0 }
        end
    end
    if #recipe.ingredients == 0 and not recipe.known then recipe.hidden = true end
    local pattern = not recipe.known and LF.patternFor(itemId)
    if pattern then
        recipe.pattern = { id = pattern, link = LF.itemLink({ item_id = pattern }) }
        local fromPattern = {}
        for i = 1, ask(GetItemLinkRecipeNumIngredients, recipe.pattern.link) or 0 do
            local name, owned, required = ask(GetItemLinkRecipeIngredientInfo, recipe.pattern.link, i)
            local link = LF.nonempty(ask(GetItemLinkRecipeIngredientItemLink, recipe.pattern.link, i, LINK_STYLE_BRACKETS) or "")
            if LF.nonempty(LF.clean(name) or "") and (required or 0) > 0 then
                fromPattern[#fromPattern + 1] = { key = materialKey(link, name), name = LF.clean(name), link = link,
                                                  icon = link and LF.nonempty(ask(GetItemLinkIcon, link) or "") or nil, need = required, have = owned or 0 }
            end
        end
        if #fromPattern > 0 then recipe.ingredients, recipe.hidden = fromPattern, false end
    end
    recipe.tickable = recipe.known or (recipe.pattern ~= nil and not recipe.hidden)
    return recipe
end
local function crafts(need)
    return math.ceil(need.missing / need.recipe.yield)
end
local function categoryOf(need)
    local dataId
    if need.kind == "collectible" then dataId = ask(GetCollectibleFurnitureDataId, need.id) else dataId = ask(GetItemLinkFurnitureDataId, need.link) end
    if not dataId or dataId == 0 then return nil end
    local category, subcategory = ask(GetFurnitureDataInfo, dataId)
    local a = category and category ~= 0 and LF.nonempty(LF.clean(ask(GetFurnitureCategoryInfo, category)) or "")
    local b = subcategory and subcategory ~= 0 and LF.nonempty(LF.clean(ask(GetFurnitureCategoryInfo, subcategory)) or "")
    if a and b then return zo_strformat(L.needs.category, a, b) end
    return a or b or nil
end
local function carriedText(places)
    local parts = {}
    for _, place in ipairs(places or {}) do parts[#parts + 1] = zo_strformat(L.needs.place, place.label, place.count) end
    return #parts > 0 and list(unpack(parts)) or nil
end
local function linkOf(row)
    if row.kind == "collectible" then return LF.nonempty(ask(GetCollectibleLink, row.item_id, LINK_STYLE_BRACKETS)) end
    return LF.itemLink(row)
end
function LF.needs(layout)
    local held = LF.held()
    local out, by = {}, {}
    for _, row in ipairs(type(layout) == "table" and type(layout.items) == "table" and layout.items or {}) do
        if type(row) == "table" and (row.kind == "item" or row.kind == "collectible") and type(row.item_id) == "number" then
            local what = LF.rowWhat(row)
            if not by[what] then
                by[what] = { what = what, kind = row.kind, id = row.item_id, link = linkOf(row), name = LF.rowName(row), icon = LF.iconOf(row), need = 0 }
                out[#out + 1] = by[what]
            end
            by[what].need = by[what].need + 1
        end
    end
    for _, need in ipairs(out) do
        if need.kind == "collectible" then
            need.places = ask(IsCollectibleUnlocked, need.id) and { { source = "collection", label = L.house.collection, count = 1 } } or {}
        else
            need.places = held[need.what] or {}
        end
        need.have = 0
        for _, place in ipairs(need.places) do need.have = need.have + place.count end
        need.missing = math.max(0, need.need - need.have)
        need.category = categoryOf(need)
        need.price = need.kind == "item" and LF.priceOf(need.link) or nil
        if need.missing > 0 then
            need.recipe = need.kind == "item" and LF.recipeOf(need.id) or nil
            if need.recipe and need.recipe.pattern then need.carried = carriedText(held["item:" .. tostring(need.recipe.pattern.id)]) end
            if need.recipe and not need.recipe.known and not need.recipe.pattern then
                if not LF.patternsRead() and not LF.patternsStopped then LF.readPatterns() end
                local state = LF.patternState(need.id)
                if state == "none" then need.untaught, need.recipe = need.recipe, nil else need[state] = true end
            end
        end
    end
    return out
end
function LF.craftable(needs)
    local out = {}
    for _, need in ipairs(needs) do
        if need.recipe and need.missing > 0 then out[#out + 1] = { need = need, recipe = need.recipe, crafts = crafts(need) } end
    end
    return out
end
function LF.crafting(needs, ticked)
    local recipesNeeded, materials, by = {}, {}, {}
    for _, entry in ipairs(LF.craftable(needs)) do
        local need = entry.need
        if ticked[need.what] and need.recipe.tickable then
            local times = entry.crafts
            recipesNeeded[#recipesNeeded + 1] = entry
            for _, ingredient in ipairs(need.recipe.ingredients) do
                local material = by[ingredient.key]
                if not material then
                    material = { key = ingredient.key, name = ingredient.name, icon = ingredient.icon, link = ingredient.link, need = 0, have = ingredient.have }
                    by[ingredient.key] = material
                    materials[#materials + 1] = material
                end
                material.link, material.icon = material.link or ingredient.link, material.icon or ingredient.icon
                material.need = material.need + ingredient.need * times
            end
        end
    end
    for _, material in ipairs(materials) do
        material.missing = math.max(0, material.need - material.have)
        material.price = LF.priceOf(material.link)
    end
    return { recipes = recipesNeeded, materials = materials }
end
local function placeText(place)
    if place.moved and place.at then
        return zo_strformat(L.needs.place_moved_seen, place.label, place.count, LF.seenText(place.at))
    elseif place.moved then
        return zo_strformat(L.needs.place_moved, place.label, place.count)
    elseif place.at then
        return zo_strformat(L.needs.place_seen, place.label, place.count, LF.seenText(place.at))
    end
    return zo_strformat(L.needs.place, place.label, place.count)
end
function LF.placeLines(need)
    local lines = {}
    for _, place in ipairs(need.places) do lines[#lines + 1] = placeText(place) end
    return lines
end
function LF.placesText(need)
    local several, said, parts, short = {}, {}, {}, false
    for _, place in ipairs(need.places) do
        if place.source == "placed_elsewhere" or place.source == "storage" then
            local group = several[place.source] or { n = 0, count = 0 }
            several[place.source], group.n, group.count = group, group.n + 1, group.count + place.count
        end
    end
    for _, place in ipairs(need.places) do
        local group = several[place.source]
        if group and group.n > 1 then
            short = true
            if not said[place.source] then
                said[place.source] = true
                parts[#parts + 1] = place.source == "storage" and count(L.needs.place_chests, group.n, group.count, LF.sourceLabels.storage)
                                    or count(L.needs.place_houses, group.n, group.count)
            end
        else
            parts[#parts + 1] = placeText(place)
        end
    end
    local counts = zo_strformat(L.needs.counts, need.need, need.have)
    if #parts == 0 then return counts, false end
    return zo_strformat(L.needs.counts_where, counts, list(unpack(parts))), short
end
function LF.aboutText(need, categoryOnly)
    local made
    if need.recipe then
        made = need.recipe.station or need.recipe.listName
        if need.checking then
            made = zo_strformat(L.needs.checking, made)
        elseif need.unchecked then
            made = zo_strformat(L.needs.pattern_unchecked, made)
        elseif not need.recipe.known then
            made = zo_strformat(L.needs.pattern_unknown, made)
        end
    elseif need.missing > 0 or categoryOnly then
        if need.kind == "collectible" then
            made = LF.gameWords(SI_ITEM_FORMAT_STR_COLLECTIBLE, L.needs.collectible)
        elseif need.untaught then
            made = categoryOnly and L.needs.no_pattern_short or L.needs.no_pattern
        elseif not categoryOnly then
            made = L.needs.not_craftable
        end
    end
    if categoryOnly then
        return (made and need.category) and zo_strformat(L.needs.made_at, made, need.category) or made or need.category
    end
    local text = (made and need.category) and zo_strformat(L.needs.made_at, made, need.category) or made or need.category
    if need.carried then text = list(text, zo_strformat(L.needs.you_carry, need.carried)) end
    return text
end
function LF.sourcesText()
    local parts = {}
    for _, state in ipairs(LF.sourceStates()) do
        if state.state == "now" then
            parts[#parts + 1] = zo_strformat(L.needs.source_now, state.label)
        elseif state.state == "seen" then
            parts[#parts + 1] = zo_strformat(L.needs.source_seen, state.label, LF.seenText(state.at))
        elseif state.state == "changed" then
            parts[#parts + 1] = zo_strformat(L.needs.source_changed, state.label, LF.seenText(state.at))
        elseif state.state == "never" then
            parts[#parts + 1] = zo_strformat(L.needs.source_never, state.label)
        end
    end
    return #parts > 0 and zo_strformat(L.needs.counted, list(unpack(parts))) or L.needs.no_counted
end
function LF.needText(need, red, categoryOnly)
    local first = LF.placesText(need)
    if need.missing > 0 then first = list(first, red(count(L.needs.missing, need.missing))) end
    local about = LF.aboutText(need, categoryOnly)
    return about and (first .. "\n" .. about) or first
end
function LF.craftText(entry, red)
    local need, recipe = entry.need, entry.recipe
    local first, second = list(count(L.needs.missing, need.missing), count(L.needs.crafted, entry.crafts)), nil
    if recipe.pattern and need.carried then second = zo_strformat(L.needs.you_carry, need.carried)
    elseif recipe.known or recipe.pattern then second = LF.aboutText(need)
    else second = red(zo_strformat(L.needs.pattern, recipe.name or recipe.listName)) end
    return first .. "\n" .. second
end
function LF.materialText(material, red, short)
    local missing = material.missing > 0 and red(count(L.needs.missing, material.missing)) or nil
    if short then
        local text = zo_strformat(L.needs.need_have, material.need, material.have)
        return missing and (text .. "\n" .. missing) or text
    end
    local text = zo_strformat(L.needs.material, material.need, material.have)
    return missing and list(text, missing) or text
end
function LF.ttcPresent()
    return type(TamrielTradeCentrePrice) == "table" and type(TamrielTradeCentrePrice.GetPriceInfo) == "function"
end
function LF.pricesOn()
    return LF.ttcPresent() and LF.saved.ttc ~= false
end
local BAND = 0.25
LF.PRICE_BAND, LF.PRICE_STEP = BAND, 0.02
LF.PRICE_DEFAULTS = { range = "band", at = 0.5 }
function LF.priceSettings()
    local range = LF.saved.priceRange == "listing" and "listing" or "band"
    local at = tonumber(LF.saved.priceAt) or LF.PRICE_DEFAULTS.at
    return range, math.max(0, math.min(1, at))
end
function LF.setPriceRange(range)
    LF.saved.priceRange = range == "listing" and "listing" or nil
end
function LF.setPriceAt(at)
    at = math.floor(math.max(0, math.min(1, tonumber(at) or 0)) / LF.PRICE_STEP + 0.5) * LF.PRICE_STEP
    LF.saved.priceAt = at
    return at
end
function LF.resetPrices()
    LF.saved.ttc, LF.saved.priceRange, LF.saved.priceAt = nil, nil, nil
end
function LF.priceOf(link)
    if not (LF.nonempty(link or "") and LF.pricesOn()) then return nil end
    local ok, info = pcall(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, link)
    if not ok or type(info) ~= "table" then return nil end
    local min, max = tonumber(info.Min), tonumber(info.Max)
    local base = tonumber(info.SuggestedPrice) or tonumber(info.Avg)
    if not (min or max or base) then return nil end
    base = base or ((min or max) + (max or min)) / 2
    local range, at = LF.priceSettings()
    local price = { base = base, rec = base * (1 + BAND * at) }
    if range == "listing" then
        price.min, price.max = min or base, max or base
    else
        price.min, price.max = base, base * (1 + BAND)
    end
    return price
end
function LF.gold(amount)
    amount = math.floor(amount + 0.5)
    return ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(amount) or tostring(amount)
end
function LF.rangeText(price, times)
    return zo_strformat(L.needs.price_range, LF.gold(price.min * (times or 1)), LF.gold(price.max * (times or 1)))
end
function LF.toBuy(material, all)
    return (all and material.need or material.missing) or 0
end
function LF.materialsTotal(materials, all)
    local min, max, rec, priced, counted = 0, 0, 0, 0, 0
    for _, m in ipairs(materials) do
        local n = LF.toBuy(m, all)
        if n > 0 then
            counted = counted + 1
            if m.price then
                priced = priced + 1
                min, max, rec = min + m.price.min * n, max + m.price.max * n, rec + m.price.rec * n
            end
        end
    end
    if counted == 0 then return nil end
    return { rec = rec, min = min, max = max, priced = priced, counted = counted }
end
function LF.ttcAge()
    if not LF.ttcPresent() or type(TamrielTradeCentrePrice.GetPriceTableUpdatedDateString) ~= "function" then return nil end
    local ok, said = pcall(TamrielTradeCentrePrice.GetPriceTableUpdatedDateString, TamrielTradeCentrePrice)
    return ok and LF.nonempty(said or "") or nil
end
local PATTERN_UPDATE = "LetsFurnishPatterns"
local SLICE = 800
local GAP = 30000
local MARGIN = 30000
LF.PATTERN_GAP, LF.PATTERN_MARGIN = GAP, MARGIN
local function patternVersion()
    return tostring(ask(GetAPIVersion) or "?")
end
function LF.patternsRead()
    local kept = LF.saved and LF.saved.patterns
    return type(kept) == "table" and kept.version == patternVersion() and type(kept.byResult) == "table" and kept or nil
end
function LF.patternFor(itemId)
    local kept = LF.patternsRead()
    return kept and kept.byResult[itemId] or nil
end
function LF.patternState(resultId)
    if LF.patternJob then return "checking" end
    local kept = LF.patternsRead()
    local readTo = kept and (kept.readTo or ((kept.highest or 0) + LF.PATTERN_GAP))
    if readTo and resultId + LF.PATTERN_MARGIN <= readTo then return "none" end
    return "unchecked"
end
function LF.patternsShare()
    local job = LF.patternJob
    if not job then return nil end
    return math.min(0.99, job.next / math.max(job.last + LF.PATTERN_GAP, job.bound, 1))
end
local function highestNamed()
    local highest = 0
    for resultId in pairs(recipes()) do highest = math.max(highest, resultId) end
    for what in pairs(LF.held()) do
        local id = tonumber(string.match(what, "^item:(%d+)$"))
        if id then highest = math.max(highest, id) end
    end
    return highest
end
local function finishPatterns(job)
    EVENT_MANAGER:UnregisterForUpdate(PATTERN_UPDATE)
    LF.patternJob = nil
    LF.saved.patterns = { version = patternVersion(), highest = job.last, readTo = job.next - 1, bound = job.bound, byResult = job.byResult,
                          read = GetTimeStamp() }
    LF.say(count(L.needs.patterns_read, job.found))
    if LF.onProgress then LF.onProgress() end
    if LF.window and LF.window.paint then LF.window.paint() end
end
local function readSlice()
    local job = LF.patternJob
    if not job then return end
    for _ = 1, SLICE do
        local id = job.next
        job.next = id + 1
        local link = LF.itemLink({ item_id = id })
        local kind = ask(GetItemLinkItemType, link)
        if kind and kind ~= 0 then
            job.last = id
            if kind == ITEMTYPE_RECIPE then
                local made = ask(GetItemLinkItemId, ask(GetItemLinkRecipeResultItemLink, link) or "")
                if made and made ~= 0 then
                    job.found = job.found + 1
                    job.byResult[made] = job.byResult[made] or id
                end
            end
        elseif id - job.last > LF.PATTERN_GAP and id > job.bound then
            return finishPatterns(job)
        end
    end
    if LF.onProgress then LF.onProgress() end
end
function LF.readPatterns(force)
    if force then LF.patternsStopped = nil end
    if LF.patternJob or (LF.patternsRead() and not force) or not ITEMTYPE_RECIPE then return end
    LF.patternJob = { next = 1, last = 0, found = 0, byResult = {}, bound = highestNamed() + LF.PATTERN_MARGIN }
    EVENT_MANAGER:RegisterForUpdate(PATTERN_UPDATE, 0, readSlice)
    if LF.onProgress then LF.onProgress() end
end
function LF.stopPatterns()
    if not LF.patternJob then return false end
    EVENT_MANAGER:UnregisterForUpdate(PATTERN_UPDATE)
    LF.patternJob = nil
    LF.patternsStopped = true
    LF.say(L.needs.patterns_stopped)
    if LF.onProgress then LF.onProgress() end
    return true
end

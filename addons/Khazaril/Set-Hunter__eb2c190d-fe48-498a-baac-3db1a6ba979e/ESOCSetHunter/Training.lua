-- Set Hunter training kits: crafted Training gear for levelling a new character.
-- Choose a recipe, then go to its set stations. Each station shows a review; nothing is spent until you press Make all.

local SH = ESOC_SetHunter
local T = {}
SH.Training = T

local I, sv, W
local DIALOG = "ESOC_SETHUNTER_KIT"
local CRAFT_TIMEOUT = 30000
local STEP_DELAY = 900
local NO_TRAIT = 1 -- LibLazyCrafting's trait index is the game's trait type plus one

-- Each set is found through one of its items, so names follow the game's language.
local SETS = {
    order = { item = 184771, name = "Order's Wrath", where = "High Isle" },
    adept = { item = 135717, name = "Adept Rider", where = "Summerset" },
    heartland = { item = 172829, name = "Heartland Conqueror", where = "Blackwood" },
    telvanni = { item = 194942, name = "Telvanni Efficiency", where = "Telvanni Peninsula" },
    torug = { item = 50708, name = "Torug's Pact", where = "Grahtwood, Stormhaven or Deshaan" },
    ashen = { item = 49563, name = "Ashen Grip", where = "Auridon, Glenumbra or Stonefalls" },
    seducer = { item = 48031, name = "Armor of the Seducer", where = "Grahtwood, Stormhaven or Deshaan" },
}

local RECIPES = {
    { name = "All-rounder", body = "order", gear = "adept", note = "Critical hits for any class, plus 30% run speed." },
    { name = "Maximum XP", body = "adept", gear = "heartland", note = "Run speed, and Heartland doubles the weapon's Training." },
    { name = "Solo with a companion", body = "telvanni", gear = "adept", note = "Companion abilities recharge faster, plus run speed." },
    { name = "No DLC, melee", body = "torug", gear = "ashen", note = "Extra armor and health, plus fire breath on melee hits." },
    { name = "No DLC, magicka", body = "seducer", gear = "torug", note = "Magicka abilities cost 10% less." },
}

local LEVELS = { 1, 16, 26, 36, 46 }

local ARMOR = {
    Light = { station = CRAFTING_TYPE_CLOTHIER, Chest = 1, Feet = 3, Hands = 4, Head = 5, Legs = 6, Shoulders = 7, Waist = 8 },
    Medium = { station = CRAFTING_TYPE_CLOTHIER, Chest = 9, Feet = 10, Hands = 11, Head = 12, Legs = 13, Shoulders = 14, Waist = 15 },
    Heavy = { station = CRAFTING_TYPE_BLACKSMITHING, Chest = 8, Feet = 9, Hands = 10, Head = 11, Legs = 12, Shoulders = 13, Waist = 14 },
}
local ARMOR_NAMES = { "Light", "Medium", "Heavy", "Mixed" }
-- Mixed levels all three armor skill lines: 3 Light, 2 Medium, 2 Heavy
local MIXED = { Head = "Heavy", Shoulders = "Medium", Chest = "Light", Hands = "Medium", Waist = "Heavy", Legs = "Light", Feet = "Light" }
local BODY_SLOTS = { "Head", "Shoulders", "Chest", "Hands", "Waist", "Legs", "Feet" }

local WEAPONS = {
    { name = "Greatsword", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 6 },
    { name = "Battle Axe", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 4 },
    { name = "Maul", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 5 },
    { name = "Bow", station = CRAFTING_TYPE_WOODWORKING, pattern = 1 },
    { name = "Inferno Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 3 },
    { name = "Ice Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 4 },
    { name = "Lightning Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 5 },
    { name = "Restoration Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 6 },
}

local QUALITY_NAME = { [1] = "White", [2] = "Green", [3] = "Blue", [4] = "Purple", [5] = "Gold" }
local ARMOR_QUALITIES = { 2, 3, 4, 5 }
local WEAPON_QUALITIES = { 2, 3, 4 } -- a training weapon never goes above purple
local JEWELRY_QUALITIES = { 1, 2, 3 } -- jewelry upgrades are expensive, so it stops at blue
local ARMOR_XP = { [2] = 8, [3] = 9, [4] = 10, [5] = 11 }
local WEAPON_XP = { [2] = 6, [3] = 7, [4] = 8 }

local STATION_NAME = {
    [CRAFTING_TYPE_BLACKSMITHING] = "Blacksmithing",
    [CRAFTING_TYPE_CLOTHIER] = "Clothing",
    [CRAFTING_TYPE_WOODWORKING] = "Woodworking",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "Jewelry",
}

local function alert(text) pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. text) end

local function itemLink(itemId)
    return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

local function recipeNamed(name)
    for _, recipe in ipairs(RECIPES) do
        if recipe.name == name then return recipe end
    end
    return RECIPES[1]
end

local function weaponNamed(name)
    for _, weapon in ipairs(WEAPONS) do
        if weapon.name == name then return weapon end
    end
    return WEAPONS[1]
end

local function setIdFor(key)
    local ok, hasSet, _, _, _, _, setId = pcall(GetItemLinkSetInfo, string.format("|H1:item:%d:30:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h", SETS[key].item))
    if ok and hasSet then return setId end
    return nil
end

function T.XpBonus(choice)
    local recipe = recipeNamed(choice.recipe)
    local weapon = WEAPON_XP[choice.weaponQuality] or 8
    if recipe.gear == "heartland" then weapon = weapon * 2 end
    return (ARMOR_XP[choice.armorQuality] or 8) * 7 + weapon
end

-- The 11 pieces of a kit: 7 body pieces in one set, a two-handed weapon and 3 jewelry in the other.
function T.Pieces(kit)
    local recipe, weapon = recipeNamed(kit.recipe), weaponNamed(kit.weapon)
    local pieces = {}
    for _, slot in ipairs(BODY_SLOTS) do
        local weight = kit.weight == "Mixed" and MIXED[slot] or kit.weight
        local armor = ARMOR[weight] or ARMOR.Light
        pieces[#pieces + 1] = {
            key = slot, label = kit.weight == "Mixed" and (slot .. " (" .. weight .. ")") or slot,
            setKey = recipe.body, station = armor.station, pattern = armor[slot],
            trait = ITEM_TRAIT_TYPE_ARMOR_TRAINING + 1, quality = kit.armorQuality,
        }
    end
    pieces[#pieces + 1] = {
        key = "Weapon", label = weapon.name, setKey = recipe.gear, station = weapon.station, pattern = weapon.pattern,
        trait = ITEM_TRAIT_TYPE_WEAPON_TRAINING + 1, quality = kit.weaponQuality,
    }
    for _, jewel in ipairs({ { "Neck", 2 }, { "Ring 1", 1 }, { "Ring 2", 1 } }) do
        pieces[#pieces + 1] = {
            key = jewel[1], label = jewel[1], setKey = recipe.gear, station = CRAFTING_TYPE_JEWELRYCRAFTING,
            pattern = jewel[2], trait = NO_TRAIT, quality = kit.jewelryQuality or 1, -- jewelry can't have Training
        }
    end
    return pieces
end

local function canMakeHere(skill, setId)
    if GetCraftingInteractionType() ~= skill then return false end
    if ZO_Smithing_IsConsolidatedStationCraftingMode and ZO_Smithing_IsConsolidatedStationCraftingMode() then
        return IsConsolidatedSmithingItemSetIdUnlocked(setId)
    end
    local ok, current = pcall(W.llc.GetCurrentSetInteractionIndex)
    return ok and current == setId
end

-- The known style you have the most stones for, after what this plan has already used.
local function chooseStyle(pattern, usedStones)
    local best, bestCount
    for index = 1, GetNumValidItemStyles() do
        local style = GetValidItemStyleId(index)
        if style and style > 0 and IsSmithingStyleKnown(style, pattern) then
            local count = (GetCurrentSmithingStyleItemCount(style) or 0) - (usedStones[style] or 0)
            if count > 0 and (not bestCount or count > bestCount) then best, bestCount = style, count end
        end
    end
    return best
end

local function buildRequest(piece, level, setId, style)
    local materialIndex = level < 3 and 1 or math.floor(level / 2)
    local request = {
        type = "smithing", pattern = piece.pattern, style = style, trait = piece.trait, materialIndex = materialIndex,
        materialQuantity = W.llc.GetMatRequirements(piece.pattern, materialIndex, piece.station),
        station = piece.station, setIndex = setId, quality = piece.quality, useUniversalStyleItem = false, smithingQuantity = 1,
    }
    -- The library flips ring and necklace for newer sets when it queues them, so the check must match
    local info = LibLazyCrafting.GetSetIndexes()[setId]
    if piece.station == CRAFTING_TYPE_JEWELRYCRAFTING and info and info.isSwapped then
        request.pattern = piece.pattern == 1 and 2 or 1
        request.isJewelrySwapped = true
    end
    return request
end

local function knowledgeProblem(request, setId)
    local interaction = LibLazyCrafting.craftInteractionTables[request.station]
    local ok, reasons = pcall(interaction.getNonCraftableReasons, request)
    if not ok or not reasons then return "couldn't be checked" end
    local missing = reasons.missingKnowledge
    if not missing then return nil end
    local knowledge = missing.knowledge or {}
    if knowledge.traitNumber then
        local info = LibLazyCrafting.GetSetIndexes()[setId]
        return "needs " .. tostring(info and info[3] or "more") .. " traits researched"
    end
    if knowledge.trait then return "Training isn't researched" end
    if missing.craftSkill then return "needs a higher crafting skill for this level" end
    if knowledge.style then return "style isn't known" end
    return nil
end

function T.PlanHere(skill)
    local kit = sv.kit
    if not kit or not W.llc then return nil end
    local plan = { jobs = {}, blocked = {}, materials = {}, order = {} }
    local left, usedStones = {}, {}
    local space = GetNumBagFreeSlots(BAG_BACKPACK) or 0
    for _, piece in ipairs(T.Pieces(kit)) do
        local setId = setIdFor(piece.setKey)
        if not kit.made[piece.key] and piece.station == skill and setId and canMakeHere(skill, setId) then
            local style
            if skill ~= CRAFTING_TYPE_JEWELRYCRAFTING then style = chooseStyle(piece.pattern, usedStones) end
            if skill ~= CRAFTING_TYPE_JEWELRYCRAFTING and not style then
                plan.blocked[#plan.blocked + 1] = piece.label .. ": no style stones for a known style"
            else
                local request = buildRequest(piece, kit.level, setId, style)
                local problem = knowledgeProblem(request, setId)
                if not problem and space < 1 then problem = "no free bag slot" end
                local costs
                if not problem then
                    costs = W.llc.CompileRequirements(request)
                    for itemId, need in pairs(costs) do
                        if left[itemId] == nil then
                            left[itemId] = GetItemLinkInventoryCount(itemLink(itemId), INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG) or 0
                        end
                        if left[itemId] < need then
                            local name = GetItemLinkName(itemLink(itemId))
                            problem = "not enough " .. zo_strformat("<<t:1>>", name ~= "" and name or "materials")
                        end
                    end
                end
                if problem then
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": " .. problem
                else
                    for itemId, need in pairs(costs) do
                        left[itemId] = left[itemId] - need
                        if not plan.materials[itemId] then
                            plan.materials[itemId] = 0
                            plan.order[#plan.order + 1] = itemId
                        end
                        plan.materials[itemId] = plan.materials[itemId] + need
                    end
                    if style then usedStones[style] = (usedStones[style] or 0) + 1 end
                    space = space - 1
                    plan.jobs[#plan.jobs + 1] = { piece = piece, setId = setId, style = style }
                end
            end
        end
    end
    plan.setName = plan.jobs[1] and SETS[plan.jobs[1].piece.setKey].name
    return plan
end

function T.ReviewText(plan)
    local kit = sv.kit
    local lines = { kit.recipe .. ", level " .. kit.level .. ":" }
    for _, job in ipairs(plan.jobs) do
        local piece = job.piece
        local trait = piece.trait == NO_TRAIT and "no trait" or "Training"
        lines[#lines + 1] = piece.label .. ": " .. SETS[piece.setKey].name .. ", " .. trait .. ", " .. QUALITY_NAME[piece.quality]
    end
    if #plan.order > 0 then
        lines[#lines + 1] = "\nMaterials:"
        table.sort(plan.order)
        for _, itemId in ipairs(plan.order) do
            local link = itemLink(itemId)
            local have = GetItemLinkInventoryCount(link, INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG) or 0
            lines[#lines + 1] = zo_strformat("<<t:1>>", GetItemLinkName(link) or "Material") .. ": have " .. have .. ", use " .. plan.materials[itemId]
        end
    end
    if #plan.blocked > 0 then
        lines[#lines + 1] = "\nCan't make yet:"
        for _, reason in ipairs(plan.blocked) do lines[#lines + 1] = reason end
    end
    return table.concat(lines, "\n")
end

-- Called when a station opens. Returns true if the kit has something to show here.
function T.OfferHere(skill)
    if not sv.kit or T.run or not I.opts.offerAtStations then return false end
    local ok, plan = pcall(T.PlanHere, skill)
    if not ok or not plan then return false end
    if #plan.jobs == 0 and #plan.blocked == 0 then return false end
    if #plan.jobs == 0 then
        alert(plan.blocked[1])
        return true
    end
    T.reviewPlan = plan
    ZO_Dialogs_ShowGamepadDialog(DIALOG, { plan = plan })
    return true
end

---------------------------------------------------------------------------
-- Making the pieces, one at a time. Any problem stops the queue.
---------------------------------------------------------------------------
local function finish(message)
    local run = T.run
    if run and run.reference and W.llc and W.llc.cancelItemByReference then
        pcall(W.llc.cancelItemByReference, W.llc, run.reference)
    end
    T.run = nil
    if message then alert(message) end
    pcall(SH.MarkAllDirty)
    pcall(SH.Refresh)
end

local function armTimeout()
    local run = T.run
    run.token = (run.token or 0) + 1
    local token = run.token
    zo_callLater(function()
        if T.run == run and run.token == token then finish("stopped, the game didn't respond") end
    end, CRAFT_TIMEOUT)
end

function T.Next()
    local run = T.run
    if not run then return end
    run.index = run.index + 1
    local job = run.plan.jobs[run.index]
    if not job then
        local count = #run.plan.jobs
        finish("made " .. count .. (count == 1 and " training piece" or " training pieces"))
        return
    end
    local piece = job.piece
    if GetCraftingInteractionType() ~= piece.station then return finish("stopped because you left the station") end
    if (GetNumBagFreeSlots(BAG_BACKPACK) or 0) < 1 then return finish("stopped, your bags are full") end
    run.reference = "SetHunterKit" .. piece.key
    run.job = job
    armTimeout()
    local ok = pcall(W.llc.CraftSmithingItemByLevel, W.llc, piece.pattern, false, sv.kit.level, job.style, piece.trait,
        false, piece.station, job.setId, piece.quality, true, run.reference)
    if not ok then finish("stopped, couldn't start " .. piece.label) end
end

function T.ConfirmReview()
    local plan = T.reviewPlan
    T.reviewPlan = nil
    if not plan or T.run or #plan.jobs == 0 then return end
    if W.IsBusy() then return alert("wait for the current job to finish") end
    T.run = { plan = plan, index = 0 }
    T.Next()
end

-- Returns true when the event belonged to a kit, so the workshop ignores it.
function T.OnLazyCraft(event, _, result)
    local run = T.run
    if not run or not run.reference then return false end
    if event == LLC_CRAFT_SUCCESS then
        if not result or result.reference ~= run.reference then return false end
        sv.kit.made[run.job.piece.key] = true
        run.reference = nil
        run.token = (run.token or 0) + 1
        local token = run.token
        zo_callLater(function()
            if T.run == run and run.token == token then T.Next() end
        end, STEP_DELAY)
        return true
    elseif event == LLC_CRAFT_PARTIAL_IMPROVEMENT or event == LLC_INITIAL_CRAFT_SUCCESS then
        armTimeout()
        return true
    elseif event == LLC_INSUFFICIENT_MATERIALS or event == LLC_INSUFFICIENT_SKILL then
        finish("stopped, couldn't make " .. run.job.piece.label)
        return true
    end
    return false
end

function T.OnStationClosed()
    if T.run then finish("stopped because you left the station") end
    T.reviewPlan = nil
end

---------------------------------------------------------------------------
-- Choosing a kit
---------------------------------------------------------------------------
function T.Choice()
    sv.kitChoice = sv.kitChoice or {
        recipe = RECIPES[1].name, level = 1, weight = "Light", armorQuality = 2,
        weapon = WEAPONS[1].name, weaponQuality = 4,
    }
    sv.kitChoice.jewelryQuality = sv.kitChoice.jewelryQuality or 1
    return sv.kitChoice
end

function T.StartKit()
    if sv.kit then
        alert("finish or cancel the current kit first")
        return false
    end
    if not W.llc then
        alert("LibLazyCrafting is needed for training kits")
        return false
    end
    local kit = SH.DeepCopy(T.Choice())
    kit.made = {}
    sv.kit = kit
    SH.Refresh()
    local recipe = recipeNamed(kit.recipe)
    alert("kit ready. Go to " .. SETS[recipe.body].name .. " in " .. SETS[recipe.body].where)
    return true
end

function T.CancelKit()
    if T.run then
        alert("wait for the current job to finish")
        return false
    end
    sv.kit = nil
    SH.Refresh()
    return true
end

-- What's left, grouped by set and station, so you know where to go next.
function T.Remaining()
    local kit = sv.kit
    if not kit then return {}, 0, 0 end
    local groups, order, made, total = {}, {}, 0, 0
    for _, piece in ipairs(T.Pieces(kit)) do
        total = total + 1
        if kit.made[piece.key] then
            made = made + 1
        else
            local key = piece.setKey .. ":" .. piece.station
            if not groups[key] then
                groups[key] = { set = SETS[piece.setKey], station = STATION_NAME[piece.station], count = 0 }
                order[#order + 1] = groups[key]
            end
            groups[key].count = groups[key].count + 1
        end
    end
    return order, made, total
end

function T.PanelLines()
    if not sv or not sv.kit then return {} end
    local groups, made, total = T.Remaining()
    local lines = { I.Colour("66DD66", "Training kit: " .. sv.kit.recipe .. ", level " .. sv.kit.level .. "  " .. made .. "/" .. total) }
    for _, group in ipairs(groups) do
        lines[#lines + 1] = I.Colour("AAAAAA", group.set.name .. " (" .. group.set.where .. "): " .. group.station .. " " .. group.count)
    end
    if #groups == 0 then lines[#lines + 1] = I.Colour("66DD66", "All made") end
    return lines
end

function T.ChoiceText()
    local choice = T.Choice()
    local recipe = recipeNamed(choice.recipe)
    local body, gear = SETS[recipe.body], SETS[recipe.gear]
    local function traits(key)
        local setId = setIdFor(key)
        local info = setId and LibLazyCrafting and LibLazyCrafting.GetSetIndexes and LibLazyCrafting.GetSetIndexes()[setId]
        return info and (" (" .. info[3] .. " traits)") or ""
    end
    return recipe.name .. ": " .. recipe.note
        .. "\n\nBody: " .. body.name .. traits(recipe.body) .. ", " .. body.where
        .. "\nWeapon and jewelry: " .. gear.name .. traits(recipe.gear) .. ", " .. gear.where
        .. (choice.weight == "Mixed" and "\n\nMixed armor: 3 Light, 2 Medium, 2 Heavy. Needs Clothing and Blacksmithing stations." or "")
        .. "\n\nAbout +" .. T.XpBonus(choice) .. "% XP at best. Lower-level gear may give less."
end

function T.StatusText()
    if not sv.kit then return "No kit started" end
    local _, made, total = T.Remaining()
    return "Current kit: " .. sv.kit.recipe .. ", level " .. sv.kit.level .. ", " .. made .. "/" .. total .. " made"
end

local function createPage()
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return end
    local page = LHAS:AddAddon("Set Hunter Training Kits", { allowDefaults = false, allowRefresh = true })
    local function redraw() pcall(function() page:UpdateControls() end) end
    local function locked() return sv.kit ~= nil end
    local function showChoice()
        pcall(function() GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, T.ChoiceText(), "") end)
    end
    -- Console dropdowns fire at every scroll step, so these only store the choice and update the info panel
    local function dropdown(label, key, items, show)
        return {
            type = LHAS.ST_DROPDOWN, label = label, items = items, disable = locked, tooltip = function() return T.ChoiceText() end,
            getFunction = function() return show(T.Choice()[key]) end,
            setFunction = function(_, _, item)
                T.Choice()[key] = I.DropdownValue(item, T.Choice()[key])
                showChoice()
            end,
        }
    end
    local function list(values, nameOf)
        local items = {}
        for _, value in ipairs(values) do items[#items + 1] = { name = nameOf(value), data = value } end
        return items
    end
    local function same(value) return value end
    local function levelName(value) return "Level " .. value end
    local function qualityName(value) return QUALITY_NAME[value] end
    local recipeNames, weaponNames = {}, {}
    for _, recipe in ipairs(RECIPES) do recipeNames[#recipeNames + 1] = recipe.name end
    for _, weapon in ipairs(WEAPONS) do weaponNames[#weaponNames + 1] = weapon.name end

    page:AddSettings({
        { type = LHAS.ST_SECTION, label = "Training kit" },
        { type = LHAS.ST_LABEL, label = function() return T.StatusText() end },
        dropdown("Recipe", "recipe", list(recipeNames, same), same),
        dropdown("Character level", "level", list(LEVELS, levelName), levelName),
        dropdown("Armor weight", "weight", list(ARMOR_NAMES, same), same),
        dropdown("Armor quality", "armorQuality", list(ARMOR_QUALITIES, qualityName), qualityName),
        dropdown("Two-handed weapon", "weapon", list(weaponNames, same), same),
        dropdown("Weapon quality", "weaponQuality", list(WEAPON_QUALITIES, qualityName), qualityName),
        dropdown("Jewelry quality", "jewelryQuality", list(JEWELRY_QUALITIES, qualityName), qualityName),
        {
            type = LHAS.ST_BUTTON, label = "Start this kit", buttonText = "Start kit",
            tooltip = "Then go to the recipe's set stations. Each one shows a review, and nothing is spent until you press Make all.",
            disable = locked,
            clickHandler = function() if T.StartKit() then redraw() end end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Cancel this kit", buttonText = "Cancel kit",
            tooltip = "Stops tracking this kit. Pieces already made stay in your bag.",
            disable = function() return not locked() end,
            clickHandler = function() if T.CancelKit() then redraw() end end,
        },
    })
end

function T.Init()
    I, sv, W = SH.internal, SH.internal.sv, SH.Workshop
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Training kit" },
        mainText = { text = function(dialog) return T.ReviewText(dialog.data.plan) end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Make all", callback = function() T.ConfirmReview() end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL, callback = function() T.reviewPlan = nil end },
        },
    })
    createPage()
end

-- Set Hunter crafted sets: crafted gear isn't in the Sticker Book, so it's added from the Builds page.
-- Pieces sit on the same list as everything else. Each station shows a review; nothing is spent until Make all.

local SH = ESOC_SetHunter
local C = {}
SH.Crafted = C

local I, sv, W, T
local DIALOG = "ESOC_SETHUNTER_CRAFTED"
local CRAFT_TIMEOUT = 30000
local STEP_DELAY = 900
local CP_LEVEL = 160
local CP_MATERIAL_INDEX = 41 -- LibLazyCrafting's material index for CP160
local LEGENDARY = ITEM_FUNCTIONAL_QUALITY_LEGENDARY or 5
local QUALITY_NAME = { [1] = "White", [2] = "Green", [3] = "Blue", [4] = "Purple", [5] = "Gold" }

local WEAPONS = {
    { name = "Sword", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 3, weapon = WEAPONTYPE_SWORD, equip = EQUIP_TYPE_ONE_HAND },
    { name = "Axe", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 1, weapon = WEAPONTYPE_AXE, equip = EQUIP_TYPE_ONE_HAND },
    { name = "Mace", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 2, weapon = WEAPONTYPE_HAMMER, equip = EQUIP_TYPE_ONE_HAND },
    { name = "Dagger", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 7, weapon = WEAPONTYPE_DAGGER, equip = EQUIP_TYPE_ONE_HAND },
    { name = "Greatsword", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 6, weapon = WEAPONTYPE_TWO_HANDED_SWORD, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Battle Axe", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 4, weapon = WEAPONTYPE_TWO_HANDED_AXE, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Maul", station = CRAFTING_TYPE_BLACKSMITHING, pattern = 5, weapon = WEAPONTYPE_TWO_HANDED_HAMMER, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Bow", station = CRAFTING_TYPE_WOODWORKING, pattern = 1, weapon = WEAPONTYPE_BOW, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Inferno Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 3, weapon = WEAPONTYPE_FIRE_STAFF, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Ice Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 4, weapon = WEAPONTYPE_FROST_STAFF, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Lightning Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 5, weapon = WEAPONTYPE_LIGHTNING_STAFF, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Restoration Staff", station = CRAFTING_TYPE_WOODWORKING, pattern = 6, weapon = WEAPONTYPE_HEALING_STAFF, equip = EQUIP_TYPE_TWO_HAND },
    { name = "Shield", station = CRAFTING_TYPE_WOODWORKING, pattern = 2, weapon = WEAPONTYPE_SHIELD, equip = EQUIP_TYPE_OFF_HAND, shield = true },
}

local OFF = "Off"
local WEIGHTS = { OFF, "Light", "Medium", "Heavy" }
local BODY = { "Head", "Shoulders", "Chest", "Hands", "Waist", "Legs", "Feet" }
local RING_COUNTS = { OFF, "1", "2" }

local function alert(text) pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. text) end

local function named(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then return entry end
    end
    return list[1]
end

---------------------------------------------------------------------------
-- Which sets can be crafted
---------------------------------------------------------------------------
local function setInfo(setId)
    if not setId or setId == 0 or not LibLazyCrafting or not LibLazyCrafting.GetSetIndexes then return nil end
    return LibLazyCrafting.GetSetIndexes()[setId]
end

function C.SetName(setId)
    local info = setInfo(setId)
    return zo_strformat("<<t:1>>", info and info[1] or GetItemSetName(setId))
end

function C.TraitsNeeded(setId)
    local info = setInfo(setId)
    return info and info[3] or nil
end

-- Shown under the set's name on the side panel.
function C.SetNote(setId)
    local traits = C.TraitsNeeded(setId)
    return traits and ("Crafted, needs " .. traits .. " traits") or "Crafted"
end

local function lowered(text) return (zo_strlower or string.lower)(text) end

-- Sets matching the search, with names that start with it first.
function C.SetItems()
    local items, hasLibrary = {}, LibLazyCrafting and LibLazyCrafting.GetSetIndexes
    local query = lowered(sv.craftedChoice and sv.craftedChoice.search or "")
    if hasLibrary then
        for setId, info in pairs(LibLazyCrafting.GetSetIndexes()) do
            if setId ~= 0 and type(info) == "table" and info[1] then
                local name = C.SetName(setId)
                local at = query == "" and 1 or lowered(name):find(query, 1, true)
                if at then
                    items[#items + 1] = { name = name .. " (" .. tostring(info[3]) .. " traits)", data = setId, first = at == 1 }
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.first ~= b.first then return a.first end
        return a.name < b.name
    end)
    if #items == 0 then items[1] = { name = hasLibrary and "No sets match" or "Needs LibLazyCrafting", data = 0 } end
    return items
end

-- Keeps the chosen set if it still matches, otherwise moves to the best match.
function C.SetSearch(text)
    local choice = C.Choice()
    choice.search = tostring(text or ""):match("^%s*(.-)%s*$")
    local items = C.SetItems()
    for _, item in ipairs(items) do
        if item.data == choice.setId then return end
    end
    choice.setId = items[1].data
end

---------------------------------------------------------------------------
-- Adding pieces
---------------------------------------------------------------------------
function C.Choice()
    local choice = sv.craftedChoice or {}
    sv.craftedChoice = choice
    choice.setId = choice.setId or 0
    choice.search = choice.search or ""
    choice.slots = choice.slots or {}
    choice.necklace = choice.necklace or false
    choice.rings = choice.rings or OFF
    choice.weapon1 = choice.weapon1 or OFF
    choice.weapon2 = choice.weapon2 or OFF
    choice.fill = choice.fill or "Medium"
    choice.pieces, choice.weight, choice.weapon = nil, nil, nil -- from the old picker
    return choice
end

local function clearPicks(choice)
    choice.slots, choice.necklace, choice.rings, choice.weapon1, choice.weapon2 = {}, false, OFF, OFF, OFF
    choice.search = ""
end

local function pieceKey(equip, armor, weapon)
    return "crafted:" .. tostring(equip) .. ":" .. tostring(armor) .. ":" .. tostring(weapon)
end

local NO_ARMOR, NO_WEAPON = ARMORTYPE_NONE or 0, WEAPONTYPE_NONE or 0

-- The pieces a choice stands for.
function C.Specs(choice)
    local specs = {}
    for _, slot in ipairs(BODY) do
        local weight = choice.slots[slot]
        local armor = weight and T.ARMOR[weight]
        if armor then
            specs[#specs + 1] = {
                station = armor.station, pattern = armor[slot], equip = T.EQUIP[slot],
                armor = T.ARMOR_TYPE[weight], weapon = NO_WEAPON,
                category = ITEM_TRAIT_TYPE_CATEGORY_ARMOR, label = weight .. " " .. slot,
            }
        end
    end
    if choice.necklace then
        specs[#specs + 1] = {
            station = CRAFTING_TYPE_JEWELRYCRAFTING, pattern = 2, equip = EQUIP_TYPE_NECK, armor = NO_ARMOR, weapon = NO_WEAPON,
            category = ITEM_TRAIT_TYPE_CATEGORY_JEWELRY, label = "Necklace",
        }
    end
    local rings = tonumber(choice.rings)
    if rings then
        specs[#specs + 1] = {
            station = CRAFTING_TYPE_JEWELRYCRAFTING, pattern = 1, equip = EQUIP_TYPE_RING, armor = NO_ARMOR, weapon = NO_WEAPON,
            category = ITEM_TRAIT_TYPE_CATEGORY_JEWELRY, count = rings > 1 and rings or nil,
            label = rings > 1 and "2 Rings" or "Ring",
        }
    end
    local function addWeapon(name, matching)
        local weapon = named(WEAPONS, name)
        local two = matching and weapon.equip == EQUIP_TYPE_ONE_HAND and not weapon.shield
        specs[#specs + 1] = {
            station = weapon.station, pattern = weapon.pattern, equip = weapon.equip, armor = NO_ARMOR, weapon = weapon.weapon,
            category = weapon.shield and ITEM_TRAIT_TYPE_CATEGORY_ARMOR or ITEM_TRAIT_TYPE_CATEGORY_WEAPON,
            count = two and 2 or nil, label = (two and "2 " or "") .. weapon.name,
        }
    end
    if choice.weapon1 ~= OFF then addWeapon(choice.weapon1, choice.weapon1 == choice.weapon2) end
    if choice.weapon2 ~= OFF and choice.weapon2 ~= choice.weapon1 then addWeapon(choice.weapon2) end
    return specs
end

function C.PickedText()
    local names = {}
    for _, spec in ipairs(C.Specs(C.Choice())) do names[#names + 1] = spec.label end
    if #names == 0 then return "Turn on at least one piece." end
    return "Adds at CP160: " .. table.concat(names, ", ") .. ". Set trait, quality and enchant under Piece. Nothing is spent until you press Make all."
end

-- Pieces already on the list keep their trait, quality and enchant.
function C.AddChoice()
    if W.IsBusy() then
        alert("wait for the current job to finish")
        return 0
    end
    local choice = C.Choice()
    if not setInfo(choice.setId) then
        alert("choose a crafted set first")
        return 0
    end
    local sets = I.ActiveSets()
    local goal = sets[choice.setId] or { wants = {}, crafted = true }
    local specs = C.Specs(choice)
    if #specs == 0 then
        alert("turn on at least one piece")
        return 0
    end
    local setName, added = C.SetName(choice.setId), 0
    for _, spec in ipairs(specs) do
        local id = pieceKey(spec.equip, spec.armor, spec.weapon)
        local existing = goal.wants[id]
        if existing then
            if (spec.count or 1) > (existing.count or 1) then
                existing.count = spec.count
                added = added + 1
            end
        else
            -- A new weight replaces this set's piece in that slot and keeps its trait, quality and enchant
            local replaced
            if spec.armor ~= NO_ARMOR then
                for otherId, other in pairs(goal.wants) do
                    if other.crafted and other.equip == spec.equip and other.armor ~= spec.armor then
                        replaced = other
                        goal.wants[otherId] = nil
                        break
                    end
                end
            end
            goal.wants[id] = {
                crafted = true, station = spec.station, pattern = spec.pattern, equip = spec.equip, armor = spec.armor,
                weapon = spec.weapon, category = spec.category, count = spec.count, name = setName,
                trait = replaced and replaced.trait, quality = replaced and replaced.quality,
                enchant = replaced and replaced.enchant,
            }
            added = added + 1
        end
    end
    if added == 0 then
        alert("those pieces are already on your list")
        return 0
    end
    sets[choice.setId] = goal
    clearPicks(choice)
    SH.MarkAllDirty()
    SH.Refresh()
    alert("added " .. added .. (added == 1 and " piece of " or " pieces of ") .. setName)
    return added
end

---------------------------------------------------------------------------
-- What can be made at this station
---------------------------------------------------------------------------
local function neededPieces(skill)
    local pieces = {}
    for setId, goal in pairs(I.ActiveSets()) do
        if goal.crafted then
            for id, want in pairs(goal.wants) do
                if want.station == skill then
                    pieces[#pieces + 1] = { setId = setId, id = id, want = want, label = I.ShortName(want) }
                end
            end
        end
    end
    table.sort(pieces, function(a, b)
        if a.setId ~= b.setId then return a.setId < b.setId end
        local orderA, orderB = I.PieceOrder(a.want), I.PieceOrder(b.want)
        if orderA ~= orderB then return orderA < orderB end
        return a.id < b.id
    end)
    return pieces
end

function C.PlanHere(skill)
    if not W.llc then return nil end
    local plan = { jobs = {}, blocked = {}, materials = {}, order = {} }
    local left, usedStones = {}, {}
    local space = GetNumBagFreeSlots(BAG_BACKPACK) or 0
    for _, entry in ipairs(neededPieces(skill)) do
        if T.CanMakeHere(skill, entry.setId) then
            local _, have, count = I.PieceStatus(entry.setId, entry.id, entry.want)
            for _ = 1, count - have do
                local trait = I.TargetTrait(entry.want)
                local problem, style, costs
                local piece = {
                    pattern = entry.want.pattern, station = skill, trait = (trait or 0) + 1,
                    quality = entry.want.quality or LEGENDARY, label = entry.label,
                }
                if not trait or trait == 0 then problem = "choose a trait" end
                if not problem and skill ~= CRAFTING_TYPE_JEWELRYCRAFTING then
                    style = T.ChooseStyle(piece.pattern, usedStones)
                    if not style then problem = "no style stones for a known style" end
                end
                local request
                if not problem then
                    request = T.BuildRequest(piece, CP_LEVEL, entry.setId, style, CP_MATERIAL_INDEX)
                    problem = T.KnowledgeProblem(request, entry.setId, piece)
                end
                if not problem and space < 1 then problem = "no free bag slot" end
                if not problem then
                    costs = W.llc.CompileRequirements(request)
                    for itemId, need in pairs(costs) do
                        if left[itemId] == nil then
                            left[itemId] = GetItemLinkInventoryCount(T.ItemLink(itemId), INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG) or 0
                        end
                        if left[itemId] < need then
                            local name = GetItemLinkName(T.ItemLink(itemId))
                            problem = "not enough " .. zo_strformat("<<t:1>>", name ~= "" and name or "materials")
                        end
                    end
                end
                if problem then
                    plan.blocked[#plan.blocked + 1] = entry.label .. ": " .. problem
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
                    plan.jobs[#plan.jobs + 1] = { piece = piece, setId = entry.setId, style = style }
                end
            end
        end
    end
    return plan
end

function C.ReviewText(plan)
    local lines = {}
    for _, job in ipairs(plan.jobs) do
        local piece = job.piece
        lines[#lines + 1] = piece.label .. ": " .. C.SetName(job.setId) .. ", " .. I.TraitName(piece.trait - 1)
            .. ", " .. (QUALITY_NAME[piece.quality] or "Gold") .. ", CP160"
    end
    if #plan.order > 0 then
        lines[#lines + 1] = "\nMaterials:"
        table.sort(plan.order)
        for _, itemId in ipairs(plan.order) do
            local link = T.ItemLink(itemId)
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

-- Returns true if there's something to make here, so the workshop doesn't open a second review.
-- Anything blocked is returned so it can be listed with the upgrades instead.
function C.OfferHere(skill)
    if C.run or not I.opts.offerAtStations then return false end
    local ok, plan = pcall(C.PlanHere, skill)
    if not ok or not plan then return false end
    if #plan.jobs == 0 then return false, plan.blocked end
    C.reviewPlan = plan
    ZO_Dialogs_ShowGamepadDialog(DIALOG, { plan = plan })
    return true
end

---------------------------------------------------------------------------
-- Making the pieces, one at a time. Any problem stops the queue.
---------------------------------------------------------------------------
function C.IsBusy() return C.run ~= nil end

local function finish(message)
    local run = C.run
    if run and run.reference and W.llc and W.llc.cancelItemByReference then
        pcall(W.llc.cancelItemByReference, W.llc, run.reference)
    end
    C.run = nil
    if message then alert(message) end
    pcall(SH.MarkAllDirty)
    pcall(SH.Refresh)
end

local function armTimeout()
    local run = C.run
    run.token = (run.token or 0) + 1
    local token = run.token
    zo_callLater(function()
        if C.run == run and run.token == token then finish("stopped, the game didn't respond") end
    end, CRAFT_TIMEOUT)
end

function C.Next()
    local run = C.run
    if not run then return end
    run.index = run.index + 1
    local job = run.plan.jobs[run.index]
    if not job then
        local count = #run.plan.jobs
        finish("made " .. count .. (count == 1 and " crafted piece" or " crafted pieces"))
        return
    end
    local piece = job.piece
    if GetCraftingInteractionType() ~= piece.station then return finish("stopped because you left the station") end
    if (GetNumBagFreeSlots(BAG_BACKPACK) or 0) < 1 then return finish("stopped, your bags are full") end
    run.reference = "SetHunterCrafted" .. run.index
    run.job = job
    armTimeout()
    local ok = pcall(W.llc.CraftSmithingItemByLevel, W.llc, piece.pattern, true, CP_LEVEL, job.style, piece.trait,
        false, piece.station, job.setId, piece.quality, true, run.reference)
    if not ok then finish("stopped, couldn't start " .. piece.label) end
end

function C.ConfirmReview()
    local plan = C.reviewPlan
    C.reviewPlan = nil
    if not plan or #plan.jobs == 0 then return end
    if W.IsBusy() then return alert("wait for the current job to finish") end
    C.run = { plan = plan, index = 0 }
    C.Next()
end

-- Locked only once it's finished, because the library still has to improve it after crafting.
local function lockFinished(result)
    if not I.opts.autoLock then return end
    local slot = result.slot or result.ItemSlotID
    if not slot or GetItemId(BAG_BACKPACK, slot) == 0 then return end
    if CanItemBePlayerLocked(BAG_BACKPACK, slot) and not IsItemPlayerLocked(BAG_BACKPACK, slot) then
        I.LockItem(BAG_BACKPACK, slot)
    end
end

-- Returns true when the event belonged to this queue.
function C.OnLazyCraft(event, _, result)
    local run = C.run
    if not run or not run.reference then return false end
    if event == LLC_CRAFT_SUCCESS then
        if not result or result.reference ~= run.reference then return false end
        pcall(lockFinished, result)
        run.reference = nil
        run.token = (run.token or 0) + 1
        local token = run.token
        zo_callLater(function()
            if C.run == run and run.token == token then C.Next() end
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

function C.OnStationClosed()
    if C.run then finish("stopped because you left the station") end
    C.reviewPlan = nil
end

---------------------------------------------------------------------------
-- Builds page
---------------------------------------------------------------------------
-- Console dropdowns fire at every scroll step, so these only store the choice. Nothing is added until Add.
function C.SettingsRows(LHAS, redraw)
    local function listOf(values)
        local items = {}
        for _, value in ipairs(values) do items[#items + 1] = { name = value.name or value, data = value.name or value } end
        return items
    end
    local function dropdown(label, key, values, tooltip)
        return {
            type = LHAS.ST_DROPDOWN, label = label, items = listOf(values), tooltip = tooltip,
            getFunction = function() return C.Choice()[key] end,
            setFunction = function(_, _, item)
                C.Choice()[key] = I.DropdownValue(item, C.Choice()[key])
                redraw()
            end,
        }
    end
    local weaponChoices = { OFF }
    for _, weapon in ipairs(WEAPONS) do weaponChoices[#weaponChoices + 1] = weapon.name end

    local rows = {
        { type = LHAS.ST_SECTION, label = "Add a crafted set" },
        {
            type = LHAS.ST_EDIT, label = "Search sets",
            tooltip = "Type the first few letters of a set's name. Crafted set then shows only the matches. Clear this to see every set.",
            getFunction = function() return C.Choice().search end,
            setFunction = function(value) C.SetSearch(value); redraw() end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Crafted set", items = C.SetItems,
            tooltip = "Crafted sets aren't in the Sticker Book, so add them here. The number is how many traits you must research.",
            getFunction = function()
                local choice = C.Choice()
                if not setInfo(choice.setId) then return choice.search ~= "" and "No sets match" or "Choose a set" end
                return C.SetName(choice.setId) .. " (" .. tostring(C.TraitsNeeded(choice.setId)) .. " traits)"
            end,
            setFunction = function(_, _, item)
                C.Choice().setId = I.DropdownValue(item, C.Choice().setId)
                redraw()
            end,
        },
        dropdown("All armor to", "fill", WEIGHTS, "Pick a weight, then press Apply to set all seven armor pieces at once. You can still change any single piece below."),
        {
            type = LHAS.ST_BUTTON, label = "Apply to all armor", buttonText = "Apply",
            clickHandler = function()
                local choice = C.Choice()
                for _, slot in ipairs(BODY) do choice.slots[slot] = choice.fill end
                redraw()
            end,
        },
    }
    for _, slot in ipairs(BODY) do
        rows[#rows + 1] = {
            type = LHAS.ST_DROPDOWN, label = slot, items = listOf(WEIGHTS),
            getFunction = function() return C.Choice().slots[slot] or OFF end,
            setFunction = function(_, _, item)
                C.Choice().slots[slot] = I.DropdownValue(item, OFF)
                redraw()
            end,
        }
    end
    rows[#rows + 1] = {
        type = LHAS.ST_CHECKBOX, label = "Necklace", default = false,
        getFunction = function() return C.Choice().necklace end,
        setFunction = function(value) C.Choice().necklace = value; redraw() end,
    }
    rows[#rows + 1] = dropdown("Rings", "rings", RING_COUNTS)
    rows[#rows + 1] = dropdown("Weapon 1", "weapon1", weaponChoices)
    rows[#rows + 1] = dropdown("Weapon 2", "weapon2", weaponChoices, "Choose the same one-handed weapon in both to make a matching pair.")
    rows[#rows + 1] = {
        type = LHAS.ST_BUTTON, label = "Add to my list", buttonText = "Add",
        tooltip = function() return C.PickedText() end,
        disable = function()
            local choice = C.Choice()
            return not setInfo(choice.setId) or #C.Specs(choice) == 0
        end,
        clickHandler = function() if C.AddChoice() > 0 then redraw() end end,
    }
    return rows
end

function C.Init()
    I, sv, W, T = SH.internal, SH.internal.sv, SH.Workshop, SH.Training
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Crafted sets" },
        mainText = { text = function(dialog) return C.ReviewText(dialog.data.plan) end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Make all", callback = function() C.ConfirmReview() end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL, callback = function() C.reviewPlan = nil end },
        },
    })
end

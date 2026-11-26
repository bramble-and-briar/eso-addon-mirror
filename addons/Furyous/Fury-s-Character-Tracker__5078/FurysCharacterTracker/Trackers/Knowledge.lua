-- shared
-- What a character has learned: provisioning recipes, furnishing plans, motif styles, and scribing
-- (grimoires and scripts). Each is a count out of a total the game reports.
local CT = FurysCharacterTracker
local U = CT.Util

local function Known(what, value, total)
    return string.format("%s: %s%s", what, U.Comma(value), total and (" of " .. U.Comma(total)) or "")
end

-- Game only -------------------------------------------------------------------------------------

-- Provisioning recipes and furnishing plans live in the same recipe lists;
-- the crafting station each one needs tells them apart.
local function ReadRecipes(c)
    local recipes, recipesTotal, plans, plansTotal = 0, 0, 0, 0
    for listIndex = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(listIndex)
        for recipeIndex = 1, numRecipes do
            local known, _, _, _, _, _, station = GetRecipeInfo(listIndex, recipeIndex)
            if station == CRAFTING_TYPE_PROVISIONING then
                recipesTotal = recipesTotal + 1
                if known then recipes = recipes + 1 end
            else
                plansTotal = plansTotal + 1
                if known then plans = plans + 1 end
            end
        end
    end
    c.recipes, c.recipesTotal, c.furnishings, c.furnishingsTotal = recipes, recipesTotal, plans, plansTotal
end

-- Motif styles known in full. The game's own count: it is known to get one or two styles wrong
-- (Mercenary, for one), so it can differ slightly from crafting addons that track chapters by hand.
local function ReadMotifs(c)
    local known, total = 0, 0
    for index = 1, GetNumValidItemStyles() do
        local styleId = GetValidItemStyleId(index)
        if styleId and styleId > 0 then
            total = total + 1
            if IsSmithingStyleKnown(styleId) then known = known + 1 end
        end
    end
    c.motifs, c.motifsTotal = known, total
end

-- Scribing is learned like recipes: a set number of grimoires and scripts per character.
-- Counted the way Character Knowledge counts it (79 when everything is known): grimoires
-- plus scripts. Many scripts fit several grimoires, so each script is counted once.
local function ReadScribing(c)
    local seen = {}
    local grimoires, grimoiresTotal, scripts, scriptsTotal = 0, 0, 0, 0
    for index = 1, GetNumCraftedAbilities() do
        local craftedAbilityId = GetCraftedAbilityIdAtIndex(index)
        grimoiresTotal = grimoiresTotal + 1
        if IsCraftedAbilityUnlocked(craftedAbilityId) then grimoires = grimoires + 1 end
        for slot = 1, 3 do   -- primary (focus), secondary (signature), tertiary (affix)
            for scriptIndex = 1, GetNumScriptsInSlotForCraftedAbility(craftedAbilityId, slot) do
                local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slot, scriptIndex)
                if scriptId and scriptId ~= 0 and not seen[scriptId] then
                    seen[scriptId] = true
                    scriptsTotal = scriptsTotal + 1
                    if IsCraftedAbilityScriptUnlocked(scriptId) then scripts = scripts + 1 end
                end
            end
        end
    end
    c.grimoires, c.grimoiresTotal, c.scriptsOnly, c.scriptsOnlyTotal = grimoires, grimoiresTotal, scripts, scriptsTotal
    c.scripts, c.scriptsTotal = grimoires + scripts, grimoiresTotal + scriptsTotal
end

-- Three parts, so learning a recipe does not count the motifs again.
CT.Track({
    id = "recipes",
    read = ReadRecipes,
    events = { EVENT_RECIPE_LEARNED, EVENT_MULTIPLE_RECIPES_LEARNED },
    columns = {
        { key = "recipes", title = "Recipes", width = 84, max = function(e) return e.c.recipesTotal end,
          head = "Recipes: provisioning recipes (food and drink) this character knows.",
          value = function(e) return e.c.recipes or 0 end,
          tip = function(e) return Known("Provisioning recipes known", e.c.recipes or 0, e.c.recipesTotal) end },
        { key = "plans", title = "Furnishing", width = 92, max = function(e) return e.c.furnishingsTotal end,
          head = "Furnishing: furnishing plans this character knows (blueprints, patterns, designs and the rest).",
          value = function(e) return e.c.furnishings or 0 end,
          tip = function(e) return Known("Furnishing plans known", e.c.furnishings or 0, e.c.furnishingsTotal) end },
    },
    summary = function(e)
        local P = CT.Trackers.Progress
        return { P("Recipes", e.c.recipes, e.c.recipesTotal), P("Furnishing plans", e.c.furnishings, e.c.furnishingsTotal) }
    end,
    export = {
        { "Recipes", function(e) return e.c.recipes end }, { "Recipes total", function(e) return e.c.recipesTotal end },
        { "Furnishing plans", function(e) return e.c.furnishings end }, { "Furnishing plans total", function(e) return e.c.furnishingsTotal end },
    },
})

CT.Track({
    id = "motifs",
    read = ReadMotifs,
    events = { EVENT_STYLE_LEARNED },
    columns = {
        { key = "motifs", title = "Motifs", width = 72, max = function(e) return e.c.motifsTotal end,
          head = "Motifs: crafting styles this character knows in full.",
          value = function(e) return e.c.motifs or 0 end,
          tip = function(e)
              return Known("Motif styles known in full", e.c.motifs or 0, e.c.motifsTotal) ..
                     "\nThe game's own count; it can be off by one or two from crafting addons."
          end },
    },
    summary = function(e) return { CT.Trackers.Progress("Motif styles", e.c.motifs, e.c.motifsTotal) } end,
    export = { { "Motif styles", function(e) return e.c.motifs end }, { "Motif styles total", function(e) return e.c.motifsTotal end } },
})

CT.Track({
    id = "scribing",
    read = ReadScribing,
    events = { EVENT_CRAFTED_ABILITY_LOCK_STATE_CHANGED, EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED },
    columns = {
        { key = "scribing", title = "Scribing", width = 80, max = function(e) return e.c.scriptsTotal or CT.SCRIPTS_TOTAL end,
          head = "Scribing: grimoires and scripts this character has learned.",
          value = function(e) return e.c.scripts or 0 end,
          tip = function(e)
              local c = e.c
              local text = string.format("Scribing learned: %d of %d (grimoires + scripts)", c.scripts or 0, c.scriptsTotal or CT.SCRIPTS_TOTAL)
              if c.grimoires then
                  text = text .. string.format("\nGrimoires %d / %d\nScripts %d / %d", c.grimoires, c.grimoiresTotal, c.scriptsOnly, c.scriptsOnlyTotal)
              end
              return text
          end },
    },
    summary = function(e)
        local P, c = CT.Trackers.Progress, e.c
        return { P("Scribing", c.scripts, c.scriptsTotal or CT.SCRIPTS_TOTAL), P("Grimoires", c.grimoires, c.grimoiresTotal),
                 P("Scripts", c.scriptsOnly, c.scriptsOnlyTotal) }
    end,
    export = { { "Scribing (grimoires + scripts)", function(e) return e.c.scripts end } },
})

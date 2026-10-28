-- FurnitureFinder.lua
--
-- Hooks the gamepad item tooltip and appends source/material/ownership/
-- recipe-knowledge info when the item being shown is a furnishing.
--
-- VERIFICATION NOTE: The API functions and events referenced here
-- (IsItemLinkPlaceableFurniture, GetItemLinkItemId,
-- GetItemLinkDisplayQuality, EVENT_ADD_ON_LOADED) are documented ESO Lua
-- API. Furnishing detection uses IsItemLinkPlaceableFurniture rather than
-- comparing itemType to ITEMTYPE_FURNISHING directly -- confirmed in-game
-- (2026-08-24) that placeable furnishings can report different itemType
-- values (e.g. trophy-style wall decor reported itemType 29, not
-- 61/FURNISHING), so a strict itemType match silently skipped valid
-- furnishings.
-- APIVersion 101051 confirmed live 2026-10-20 (Update 51).

-- Public release 2026-08-25: removed the always-on display-name and
-- APIVersion diagnostic prints that used to be here (were spamming chat
-- on every login for every user, not just during testing).

-- 2026-10-01: MIGRATED off the one-off Wookiefriseur data dump
-- (FurnitureFinder_ExportData.lua / FurnitureFinder_ExportAPI.lua,
-- removed from the manifest and deleted) onto LibFurnitureCatalogue (LFC),
-- Wookiefriseur's new structured, web-edited, self-maintaining database
-- library. We now read live via LibFurnitureCatalogue.API instead of a
-- static snapshot we had to regenerate by hand -- no more manual
-- dump/convert cycle going forward. API surface confirmed by reading the
-- library's real source (Api.lua, Query.lua) rather than assumed:
--   GetSourceDetails(itemOrLink) -> structured source records (vendor id,
--     zone/place ids, achievement id, cost as {currency, amount}, etc.)
--     -- these are *ids*, not pre-formatted text, so we resolve them
--     ourselves below (GetString/GetZoneNameById/GetAchievementName/etc,
--     exactly as each field's own doc comment in Api.lua says to).
--   GetIngredients(itemOrLink) -> real ingredient item links + quantities,
--     resolved live from the game's own recipe API -- an upgrade over the
--     old static Materials() list, since real links mean we can read
--     quality color directly (GetItemLinkDisplayQuality) with no need for
--     the old synthetic-link/material-id-table workaround.
--   OnReady / IsReady -- the DB now builds itself at runtime (it did not
--     before, when it was just a static file), so lookups made before it's
--     ready can come back empty. OnReady() is kicked off at load to start
--     that build early.

FurnitureFinder = FurnitureFinder or {}
local FF = FurnitureFinder
FF.name = "FurnitureFinder"

-- LibFurnitureCatalogue.API -- confirmed public entry point, see Api.lua's
-- own header comment: `local LFC = LibFurnitureCatalogue.API`. Declared as
-- a hard DependsOn in the manifest (not OptionalDependsOn), since source/
-- material data is this addon's core purpose, not an extra -- same
-- reasoning that keeps LibCharacterKnowledge optional (recipe-knowledge
-- display is a bonus on top).
local LFC = LibFurnitureCatalogue and LibFurnitureCatalogue.API

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function IsFurnishingLink(itemLink)
    if not itemLink or itemLink == "" then return false end
    local ok, isPlaceable = pcall(IsItemLinkPlaceableFurniture, itemLink)
    if not ok then return false end
    return isPlaceable == true
end

-- Formats a cost as "<amount> <currency name>". cost.currency is a real
-- ESO currency constant (CURT_*), confirmed by LFCSourceCost's own doc
-- comment in Api.lua ("currency integer ESO currency constant"), not an
-- LFC-internal id needing translation. GetCurrencyName is guarded with
-- pcall like everything else here -- if the signature assumption is off,
-- we just fall back to the bare number instead of erroring.
local function FormatCurrency(amount, currencyType)
    if not amount then return nil end
    if currencyType then
        local ok, name = pcall(GetCurrencyName, currencyType, amount ~= 1, false)
        if ok and name and name ~= "" then
            return zo_strformat("<<1>> <<2>>", amount, name)
        end
    end
    return tostring(amount)
end

-- Resolves one LFCPlacement (a zone id and/or a place-within-zone string
-- id) to display text. Per Api.lua's own doc comment on LFCPlacement.
local function ResolvePlacement(placement)
    local parts = {}
    if placement.location then
        local ok, name = pcall(GetZoneNameById, placement.location)
        if ok and name and name ~= "" then
            table.insert(parts, zo_strformat("<<C:1>>", name))
        end
    end
    if placement.place then
        local ok, text = pcall(GetString, placement.place)
        if ok and text and text ~= "" then
            table.insert(parts, zo_strformat("<<C:1>>", text))
        end
    end
    if placement.note and type(placement.note) == "string" then
        table.insert(parts, placement.note)
    end
    return table.concat(parts, ", ")
end

-- English-only fallback label for a source type (e.g. "Luxury Furnisher"),
-- used only when we can't resolve anything more specific (no vendor name,
-- no category string) to describe where a source comes from.
local sourceTypeInfoCache = nil
local function GetSourceLabel(sourceType)
    if not LFC then return "Source" end
    if not sourceTypeInfoCache then
        local ok, info = pcall(LFC.GetSourceTypeInfo)
        sourceTypeInfoCache = (ok and info) or {}
    end
    local info = sourceTypeInfoCache[sourceType]
    return (info and info.label) or "Other"
end

-- Turns one LFCSourceRecord into a header ("what") plus a list of
-- sub-lines (location, price, achievement, etc.), covering the common
-- fields documented on LFCSourceOrigin in Api.lua. Not every possible
-- field is handled (packs/bundle/crate/containerKind/npcClass are left
-- out as rare edge cases) -- the common ones (vendor, location, price,
-- achievement, quest, event, houses, rarity) cover the large majority of
-- real entries.
local function DescribeSourceRecord(record)
    local source = record.source
    local sublines = {}

    local what = nil
    if source.vendor then
        local ok, raw = pcall(GetString, source.vendor)
        if ok and raw and raw ~= "" then
            what = zo_strformat("<<C:1>>", raw)
        end
    end
    if not what and source.category then
        local ok, text = pcall(GetString, source.category)
        if ok and text and text ~= "" then
            what = zo_strformat("<<C:1>>", text)
        end
    end
    if not what then
        what = GetSourceLabel(source.type)
    end

    for _, placement in ipairs(source.locations or {}) do
        local text = ResolvePlacement(placement)
        if text ~= "" then
            table.insert(sublines, zo_strformat("  Location: <<1>>", text))
        end
    end

    if source.event then
        local ok, text = pcall(GetString, source.event)
        if ok and text and text ~= "" then
            table.insert(sublines, zo_strformat("  Event: <<1>>", zo_strformat("<<C:1>>", text)))
        end
    end

    if record.cost and record.cost.amount then
        local priceText = FormatCurrency(record.cost.amount, record.cost.currency)
        if priceText then
            table.insert(sublines, zo_strformat("  Price: <<1>>", priceText))
        end
    end

    if source.achievement and source.achievement ~= 0 then
        local ok, name = pcall(GetAchievementName, source.achievement)
        if ok and name and name ~= "" then
            table.insert(sublines, zo_strformat("  Requires: <<1>>", name))
        end
    elseif source.achievement == 0 then
        table.insert(sublines, "  Requires: an achievement")
    end

    if source.quest then
        local ok, name = pcall(GetQuestName, source.quest)
        if ok and name and name ~= "" then
            table.insert(sublines, zo_strformat("  Quest: <<1>>", name))
        end
    end

    if source.houses then
        local names = {}
        for _, houseId in ipairs(source.houses) do
            local ok, name = pcall(GetCollectibleName, houseId)
            if ok and name and name ~= "" then
                table.insert(names, name)
            end
        end
        if #names > 0 then
            table.insert(sublines, zo_strformat("  Comes with: <<1>>", table.concat(names, ", ")))
        elseif #source.houses == 0 then
            table.insert(sublines, "  Comes with: a house (unspecified)")
        end
    end

    if source.rarity then
        local ok, text = pcall(GetString, source.rarity)
        if ok and text and text ~= "" then
            table.insert(sublines, zo_strformat("  Rarity: <<1>>", text))
        end
    end

    return what, sublines
end

-- GetQualityLine() removed 2026-08-28 -- was only used to display the
-- Quality line, which was removed as redundant (visible on the item
-- itself already). No other caller, so removed rather than left dead.

local function BuildFurnitureLines(itemLink)
    local lines = {}

    -- Item ID and Quality lines removed 2026-08-28 -- both are already
    -- visible from the item itself, redundant in the tooltip. itemId is
    -- still resolved here since the database lookup, ownership check, and
    -- recipe-knowledge lookup all need it internally.
    local ok, itemId = pcall(GetItemLinkItemId, itemLink)

    if LFC and ok and itemId then
        local okRec, records = pcall(LFC.GetSourceDetails, itemId)
        if okRec and records and #records > 0 then
            for i, record in ipairs(records) do
                local what, sublines = DescribeSourceRecord(record)
                -- Multiple sources per item are real (e.g. both a drop AND
                -- a festival drop) -- show each on its own line, numbered
                -- only when there's more than one so the common case (one
                -- source) stays clean.
                local prefix = (#records > 1) and zo_strformat("Source <<1>>: <<2>>", i, what) or zo_strformat("Source: <<1>>", what)
                table.insert(lines, prefix)
                for _, subline in ipairs(sublines) do
                    table.insert(lines, subline)
                end
            end

            -- Real ingredient item links + quantities, resolved live from
            -- the game's recipe API. Works directly on the furnishing's
            -- own item id -- LFC resolves the blueprint link internally,
            -- confirmed via GetIngredients' own doc comment in Api.lua.
            local okIng, ingredients = pcall(LFC.GetIngredients, itemId)
            if okIng and ingredients and next(ingredients) then
                local parts = {}
                for ingredientLink, qty in pairs(ingredients) do
                    local okName, matName = pcall(GetItemLinkName, ingredientLink)
                    matName = (okName and matName and matName ~= "") and matName or "Unknown Material"

                    local hex = nil
                    local okQ, quality = pcall(GetItemLinkDisplayQuality, ingredientLink)
                    if okQ and quality then
                        local okC, colorDef = pcall(GetItemQualityColor, quality)
                        if okC and colorDef then
                            hex = colorDef:ToHex()
                        end
                    end

                    if hex then
                        table.insert(parts, zo_strformat("<<1>>x |c<<2>><<3>>|r", qty, hex, matName))
                    else
                        table.insert(parts, zo_strformat("<<1>>x <<2>>", qty, matName))
                    end
                end
                table.insert(lines, zo_strformat("Materials: <<1>>", table.concat(parts, ", ")))
            end
        else
            -- Only show a "missing" fallback for items that are actually
            -- placeable furnishings -- i.e. the kind of item this database
            -- is keyed by. A recipe/diagram item will ALWAYS miss here,
            -- since the database is keyed by the crafted furnishing's item
            -- ID, not the recipe's own ID -- showing "not in database" on
            -- a recipe is misleading, not a real gap.
            local okFurn, isFurnishing = pcall(IsItemLinkPlaceableFurniture, itemLink)
            if okFurn and isFurnishing then
                if LFC.IsReady and not LFC.IsReady() then
                    -- The catalogue builds itself in the background on
                    -- first use now (it didn't when this was a static
                    -- file) -- a miss right after login may just mean the
                    -- build isn't finished yet, not a real gap.
                    table.insert(lines, "|c888888Source: catalogue still loading, try again in a moment|r")
                else
                    table.insert(lines, "|c888888Source: not in local database yet|r")
                end
            end
        end
    end

    -- Ownership info (FurnitureFinder_Ownership.lua). Guarded with pcall
    -- since the ownership module is a separate file/SavedVariables and
    -- shouldn't be able to break the core tooltip if it errors.
    if ok and FFOwnership and FFOwnership.FormatOwnershipLine then
        local ok3, ownLine = pcall(FFOwnership.FormatOwnershipLine, itemLink, itemId)
        if ok3 and ownLine then
            table.insert(lines, zo_strformat("<<1>>", ownLine))
        end
    end

    -- Recipe/furnishing-plan known status, via LibCharacterKnowledge if
    -- present (bundled alongside this addon, OptionalDependsOn in the
    -- manifest -- confirmed console-compatible, has its own console/
    -- settings). Confirmed real API: LibCharacterKnowledge.GetItemKnowledgeForCharacter
    -- returns KNOWLEDGE_INVALID for ordinary furnishings (not a plan
    -- item), so this correctly stays silent except on actual "Recipe:"/
    -- "Diagram:" plan items.
    if ok and LibCharacterKnowledge then
        -- Same validity check as before: try the item itself first, fall
        -- back to LibCharacterKnowledge's reverse lookup (crafted
        -- furnishing -> its recipe/diagram) if the item isn't itself a
        -- recipe. This just determines whether we have a valid target to
        -- check at all -- the actual per-character breakdown comes from
        -- GetItemKnowledgeList below.
        local targetItem = itemLink
        local ok4, knowledge = pcall(LibCharacterKnowledge.GetItemKnowledgeForCharacter, targetItem)

        if ok4 and knowledge == LibCharacterKnowledge.KNOWLEDGE_INVALID then
            local ok5, recipeItemId = pcall(LibCharacterKnowledge.GetSourceItemIdFromResultItem, itemId)
            if ok5 and recipeItemId and recipeItemId ~= 0 then
                targetItem = recipeItemId
                ok4, knowledge = pcall(LibCharacterKnowledge.GetItemKnowledgeForCharacter, targetItem)
            end
        end

        -- Only worth building the character list if we ended up with a
        -- genuinely valid recipe/plan target (known OR unknown for the
        -- current character -- i.e. IsKnowledgeUsable). NODATA/INVALID at
        -- this point means there's nothing meaningful to show.
        if ok4 and LibCharacterKnowledge.IsKnowledgeUsable(knowledge) then
            local ok6, charList = pcall(LibCharacterKnowledge.GetItemKnowledgeList, targetItem)
            if ok6 and charList then
                local namesWhoKnow = {}
                local namesWhoDontKnow = {}
                for _, entry in ipairs(charList) do
                    if entry.knowledge == LibCharacterKnowledge.KNOWLEDGE_KNOWN then
                        table.insert(namesWhoKnow, entry.name)
                    elseif entry.knowledge == LibCharacterKnowledge.KNOWLEDGE_UNKNOWN then
                        table.insert(namesWhoDontKnow, entry.name)
                    end
                end
                if #namesWhoKnow > 0 then
                    table.insert(lines, zo_strformat("|c00c000Known by: <<1>>|r", table.concat(namesWhoKnow, ", ")))
                end
                if #namesWhoDontKnow > 0 then
                    table.insert(lines, zo_strformat("|cc00000Not known by: <<1>>|r", table.concat(namesWhoDontKnow, ", ")))
                end
                -- If both lists are empty, no tracked characters have data
                -- for this item yet -- stay silent, nothing meaningful to show.
            end
        end
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

local function HookItemTooltip()
    -- CONFIRMED pattern (2026-08-25): GAMEPAD_TOOLTIPS:GetTooltip()
    -- instances, hooked via ZO_PostHook on AddItemTitle, using
    -- AcquireSection/AddSection. (An earlier version hooked the shared
    -- ZO_Tooltip.LayoutItem class method with raw AddLine calls -- that
    -- was the likely cause of state corruption that crashed
    -- ZO_GamepadInventory:Select downstream, and has been replaced.)

    if not GAMEPAD_TOOLTIPS or not GAMEPAD_TOOLTIPS.GetTooltip then
        d("[FurnitureFinder] GAMEPAD_TOOLTIPS not found -- hook NOT installed")
        return
    end

    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP }
    local hookedCount = 0

    for _, tooltipType in pairs(tooltipTypes) do
        local ok, tooltip = pcall(function() return GAMEPAD_TOOLTIPS:GetTooltip(tooltipType) end)
        if ok and tooltip and tooltip.AddItemTitle then
            ZO_PostHook(tooltip, "AddItemTitle", function(self, itemLink, name)
                -- CONFIRMED against real ESOUI source and in-game testing
                -- (2026-08-25): AddItemTitle(itemLink, name) -- arg1 is the
                -- real itemLink. itemId/isFurnishing resolve correctly.
                local ok, err = pcall(function()
                    local itemId = GetItemLinkItemId(itemLink)

                    -- Gate widened 2026-08-25: a "Recipe:"/"Diagram:" item is
                    -- NOT itself placeable furniture (it's the separate,
                    -- consumable item that teaches you one) -- the original
                    -- IsItemLinkPlaceableFurniture-only gate silently skipped
                    -- every recipe item, including the LibCharacterKnowledge
                    -- lookup, before BuildFurnitureLines ever ran. Now also
                    -- let actual recipe items through so the known/unknown
                    -- line can show.
                    local okType, itemType = pcall(GetItemLinkItemType, itemLink)
                    local isRecipeItem = okType and itemType == ITEMTYPE_RECIPE
                    local isFurnishing = IsItemLinkPlaceableFurniture(itemLink)

                    if not isFurnishing and not isRecipeItem then
                        return
                    end

                    local lines = BuildFurnitureLines(itemLink)
                    if not lines or #lines == 0 then
                        return
                    end

                    -- CONFIRMED pattern from real ESOUI source
                    -- (esoui/esoui/publicallingames/tooltip/itemtooltips.lua):
                    -- real game code always adds body content via
                    -- AcquireSection -> section:AddLine -> AddSection,
                    -- never a raw AddLine call directly on the tooltip
                    -- object itself.
                    local section = self:AcquireSection(self:GetStyle("bodySection"))
                    for _, line in ipairs(lines) do
                        section:AddLine(line, self:GetStyle("bodyDescription"))
                    end
                    self:AddSection(section)
                end)

                if not ok then
                    d("[FurnitureFinder] tooltip section error (safely caught): " .. tostring(err))
                end
            end)
            hookedCount = hookedCount + 1
        end
    end

    -- v0.3.0: success message removed (it printed on every login for every
    -- user). Only report the failure case, which is worth knowing about.
    if hookedCount == 0 then
        d("[FurnitureFinder] could not hook any gamepad tooltip -- tooltip info will not show")
    end
end

local function HookHousingEditorTooltip()
    -- TODO / needs in-game verification: if the Housing Editor's furniture
    -- browser and placed-item selection tooltip turn out NOT to route
    -- through the same GAMEPAD_TOOLTIPS instances, hook the specific
    -- control here using the same pattern as HookItemTooltip above.
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= FF.name then return end
    EVENT_MANAGER:UnregisterForEvent(FF.name, EVENT_ADD_ON_LOADED)

    -- Kick off LibFurnitureCatalogue's DB build now rather than waiting
    -- for the first tooltip -- OnReady starts loading if needed (per its
    -- own doc comment in Api.lua) and this just primes it early so it's
    -- more likely ready by the time the player actually opens a tooltip.
    -- The empty callback is intentional: BuildFurnitureLines already
    -- handles "still loading" gracefully via LFC.IsReady().
    if LFC and LFC.OnReady then
        LFC.OnReady(function() end)
    end

    HookItemTooltip()
    HookHousingEditorTooltip()
end

EVENT_MANAGER:RegisterForEvent(FF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

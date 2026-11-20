local MCH = MonsterCofferHelper

local Tooltips = {}
MCH.Tooltips = Tooltips

local RGB = {
    good  = { 0.40, 0.87, 0.40 },
    warn  = { 0.91, 0.76, 0.35 },
    bad   = { 0.87, 0.40, 0.40 },
    dim   = { 0.62, 0.62, 0.62 },
    plain = { 0.90, 0.90, 0.90 },
}

local function AddLine(tooltip, text, rgb)
    tooltip:AddLine(text, "ZoFontGame", rgb[1], rgb[2], rgb[3])
end

local function AppendMystery(tooltip, result)
    AddLine(tooltip, zo_strformat(SI_MCH_TT_CHANCE, MCH.Format.Percent(result.chanceNew)), RGB.plain)
    AddLine(tooltip, zo_strformat(SI_MCH_TT_COST, MCH.Format.Num(result.mysteryPerNew)), RGB.plain)

    if result.verdict == MCH.VERDICT_MYSTERY then
        AddLine(tooltip, GetString(SI_MCH_TT_BEST), RGB.good)
    elseif result.verdict == MCH.VERDICT_CURATED then
        AddLine(tooltip, GetString(SI_MCH_TT_WORSE), RGB.warn)
    end
end

local function AppendCurated(tooltip, result, setIds)
    local missing, total = MCH.Advisor.CofferCounts(result.pool, setIds)

    if missing == 0 then
        -- Every set in it is complete: a duplicate no matter what the odds say.
        AddLine(tooltip, GetString(SI_MCH_TT_SET_DONE), RGB.bad)
        return
    end

    if missing then
        AddLine(tooltip, zo_strformat(SI_MCH_TT_SET_MISSING, missing, total), RGB.plain)
    end
    AddLine(tooltip, zo_strformat(SI_MCH_TT_COST, MCH.Format.Num(result.curatedPerNew)), RGB.plain)

    if result.verdict == MCH.VERDICT_CURATED then
        AddLine(tooltip, GetString(SI_MCH_TT_BEST), RGB.good)
    elseif result.verdict == MCH.VERDICT_MYSTERY then
        AddLine(tooltip, GetString(SI_MCH_TT_WORSE), RGB.warn)
    end
end

local function OnStoreItemTooltip(tooltip, storeIndex)
    if not MCH.db.tooltips then return end

    local scan = MCH.Store.current
    if not scan then return end

    local isMystery = (scan.mysteryIndex == storeIndex)
    local setIds = scan.curatedIndexToSetIds[storeIndex]
    if not isMystery and not setIds then return end

    local result = MCH.Advisor.ForVendor(scan.vendorId)
    if not result or result.verdict == MCH.VERDICT_DONE then return end

    ZO_Tooltip_AddDivider(tooltip)
    if isMystery then
        AppendMystery(tooltip, result)
    else
        AppendCurated(tooltip, result, setIds)
    end
end

function Tooltips.Initialize()
    -- Post-hook rather than a wholesale replacement: the original still runs
    -- untouched and we only add lines after it, which keeps the store's own
    -- tooltip behaviour intact.
    ZO_PostHook(ItemTooltip, "SetStoreItem", OnStoreItemTooltip)
end

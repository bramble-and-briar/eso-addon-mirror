-- SetHunter_FCOIS.lua : marks from FCO ItemSaver (FCOIS, by Baertram) on your set
-- items, right from Set Hunter's lists. Optional: everything here is skipped when
-- FCOIS isn't installed.
--
-- How: when Set Hunter reads a bag it also asks FCOIS which id it saves marks under
-- for that item (an item instance id, or a unique id if the player turned that on in
-- FCOIS). Marks are then set / read by that id, so pieces on OTHER characters can be
-- marked too; FCOIS shows them the next time you log in there.
-- API from FCOIS_API.lua (github.com/Baertram/FCOItemSaver): MarkItemByItemInstanceId,
-- IsMarkedByItemInstanceId, GetIconText, IsIconEnabled, GetFCOISMarkerIconSavedVariablesItemId.

local S = SetHunter
local F = {}
S.FCO = F

-- the marks offered (FCOIS's own icon numbers; gear set and dynamic icons left out)
local ICON_NAMES = {
    "FCOIS_CON_ICON_LOCK", "FCOIS_CON_ICON_SELL", "FCOIS_CON_ICON_DECONSTRUCTION",
    "FCOIS_CON_ICON_SELL_AT_GUILDSTORE", "FCOIS_CON_ICON_RESEARCH",
    "FCOIS_CON_ICON_IMPROVEMENT", "FCOIS_CON_ICON_INTRICATE",
}

function F.Ready()
    return FCOIS ~= nil and FCOIS.MarkItemByItemInstanceId ~= nil and FCOIS.IsMarkedByItemInstanceId ~= nil
end

-- The id FCOIS keeps this bag slot's marks under (nil without FCOIS).
function F.IdFor(bagId, slotIndex)
    if not F.Ready() then return nil end
    if FCOIS.GetFCOISMarkerIconSavedVariablesItemId then
        local ok, id = pcall(FCOIS.GetFCOISMarkerIconSavedVariablesItemId, bagId, slotIndex, nil, nil, nil, false)
        if ok and id ~= nil and id ~= "" and id ~= 0 then return id end
    end
    local id = GetItemInstanceId(bagId, slotIndex)
    return (id and id ~= 0) and id or nil
end

-- A mark's name the way FCOIS's own menus show it: the player's name for it if they
-- gave one, else FCOIS's text in its language ("options_icon5_color" = "Selling"),
-- with the icon (in its color) in front.
local function IconName(id)
    local name = FCOIS.GetIconText and FCOIS.GetIconText(id, true)
    if name and name ~= "" then return name end
    local loc = FCOIS.localizationVars
    local texts = loc and loc.fcois_loc
    local suffix = loc and loc.iconEndStrArray and loc.iconEndStrArray[id] or FCOIS_CON_ICON_SUFFIX_COLOR or "color"
    name = texts and texts["options_icon" .. id .. "_" .. suffix]
    if not name or name == "" then name = S.L("FCO_ICON_" .. id) end
    if FCOIS.BuildIconText then
        local ok, withIcon = pcall(FCOIS.BuildIconText, name, id)
        if ok and withIcon then name = withIcon end
    end
    return name
end

-- { { iconId, name }, ... }: the marks this player has switched on in FCOIS
function F.Icons()
    local list = {}
    for _, global in ipairs(ICON_NAMES) do
        local id = _G[global]
        if id and (not FCOIS.IsIconEnabled or FCOIS.IsIconEnabled(id, true) ~= false) then
            list[#list + 1] = { iconId = id, name = IconName(id) }
        end
    end
    return list
end

function F.IsMarked(entry, iconId)
    if not F.Ready() or not entry.fco then return false end
    local ok, marked = pcall(FCOIS.IsMarkedByItemInstanceId, entry.fco, iconId)
    return ok and marked == true
end

function F.Set(entry, iconId, on)
    if not F.Ready() or not entry.fco then return false end
    local ok, result = pcall(FCOIS.MarkItemByItemInstanceId, entry.fco, iconId, on, entry.link, nil, nil, true)
    return ok and result ~= false
end

-- names of the marks an item has ("Lock, Deconstruction"), with FCOIS's icons
function F.MarkNames(entry)
    if not F.Ready() or not entry.fco then return nil end
    local names = {}
    for _, icon in ipairs(F.Icons()) do
        if F.IsMarked(entry, icon.iconId) then names[#names + 1] = icon.name end
    end
    return #names > 0 and table.concat(names, ", ") or nil
end

-- locked in FCOIS: never "safe to deconstruct"
function F.IsLocked(entry)
    return FCOIS_CON_ICON_LOCK ~= nil and F.IsMarked(entry, FCOIS_CON_ICON_LOCK)
end

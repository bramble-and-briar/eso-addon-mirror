-- FurnitureFinderLiteTooltipActions.lua: the source lines in gamepad item tooltips.
--
-- Every gamepad item tooltip writes its title through ZO_Tooltip:AddItemTitle(itemLink, name).
-- A section with the source lines is added right after it, the way Furniture Finder does and
-- the way the game adds its own body content (AcquireSection, AddLine, AddSection).
--
-- The tooltip objects are controls, and ZO_Tooltip's methods are copied into each one when the
-- game first initializes it. So the hook goes on the class (SecurePostHook: the game's call
-- stays secure) for every tooltip initialized from now on, and on the object itself for the
-- ones initialized before this add-on loaded (the way Preview Anywhere hooks tooltips).
local FFL = FurnitureFinderLite
local Lines = FFL.Lines

local Tooltip = {}

local TOOLTIP_TYPES = { "GAMEPAD_LEFT_TOOLTIP", "GAMEPAD_RIGHT_TOOLTIP", "GAMEPAD_QUAD3_TOOLTIP", "GAMEPAD_QUAD1_TOOLTIP", "GAMEPAD_QUAD_2_3_TOOLTIP", "GAMEPAD_MOVABLE_TOOLTIP", "GAMEPAD_LEFT_DIALOG_TOOLTIP" }
local LOG_LIMIT = 12

local state = "not set up yet"
local logged = 0

---@param tooltip table the tooltip object whose title was just written
---@param itemLink string
local function OnItemTitle(tooltip, itemLink)
    if FFL.state.savedVars.enabled ~= true then
        return
    end
    local lines = Lines.ForLink(itemLink)
    if not lines or #lines == 0 then
        return
    end
    FFL.Count("tooltips")
    local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    local style = tooltip:GetStyle("bodyDescription")
    for _, line in ipairs(lines) do
        section:AddLine(line, style)
    end
    tooltip:AddSection(section)
    if logged < LOG_LIMIT then
        logged = logged + 1
        FFL.Log("tooltip %s: %s", tostring(GetItemLinkItemId(itemLink)), table.concat(lines, " | "))
    end
end

---Hook the tooltips, once.
---@return boolean hooked
function Tooltip.Initialize()
    if rawget(_G, "FurnitureFinder") then
        -- The original writes the same lines from the full database.
        state = "Furniture Finder is installed: it writes the source lines, this add-on stands by"
        return false
    end
    local class = rawget(_G, "ZO_Tooltip")
    if type(class) ~= "table" or type(class.AddItemTitle) ~= "function" then
        state = "the gamepad tooltip class is not there: no source lines"
        return false
    end
    local guarded = FFL.Guard("TooltipItemTitle", OnItemTitle)
    if rawget(_G, "SecurePostHook") then
        SecurePostHook(class, "AddItemTitle", guarded)
    else
        ZO_PostHook(class, "AddItemTitle", guarded)
    end
    local alreadyInitialized = {}
    local tooltips = rawget(_G, "GAMEPAD_TOOLTIPS")
    for _, tooltipTypeName in ipairs(TOOLTIP_TYPES) do
        local tooltipType = rawget(_G, tooltipTypeName)
        if tooltipType and tooltips then
            local ok, container = pcall(function() return tooltips:GetTooltipContainer(tooltipType) end)
            local tip = ok and container and container.tip
            if tip and tip.initialized and tip.tooltip and type(tip.tooltip.AddItemTitle) == "function" then
                ZO_PostHook(tip.tooltip, "AddItemTitle", guarded)
                alreadyInitialized[#alreadyInitialized + 1] = tooltipTypeName
            end
        end
    end
    state = "source lines in gamepad item tooltips" .. (#alreadyInitialized > 0 and (" (hooked directly: " .. table.concat(alreadyInitialized, ", ") .. ")") or "")
    return true
end

---@return string
function Tooltip.StateText()
    return state
end

FFL.Tooltip = Tooltip

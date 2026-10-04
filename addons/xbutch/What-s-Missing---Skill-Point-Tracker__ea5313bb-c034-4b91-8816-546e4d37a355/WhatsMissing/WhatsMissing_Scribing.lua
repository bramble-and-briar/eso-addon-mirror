if SPT == nil then SPT = {} end
local Scribing = { firstCharacter = 1, stateKey = "Scribing" }
SPT.Scribing = Scribing
local slots = { SCRIBING_SLOT_PRIMARY, SCRIBING_SLOT_SECONDARY, SCRIBING_SLOT_TERTIARY }
local indicators = {
    known = "Yes",
    missing = "-",
    unknown = "?",
}

function Scribing:IsReady()
    return SCRIBING_DATA_MANAGER and SCRIBING_DATA_MANAGER.GetAllCraftedAbilityScriptIds
        and IsCraftedAbilityScriptUnlocked and GetCraftedAbilityScriptScribingSlot
end

function Scribing:Capture()
    if not self:IsReady() then return end
    local ids = SCRIBING_DATA_MANAGER:GetAllCraftedAbilityScriptIds()
    if #ids == 0 then return end -- Catalog not ready; retain any previous snapshot.
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do
        if IsCraftedAbilityScriptUnlocked(id) then parts[#parts + 1] = tostring(id) .. "," end
    end
    SPT.CharCache:WriteProgressionSnapshot("scribingScripts", "1;" .. table.concat(parts))
end

function Scribing:Init()
    if EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(SPT.AddonName .. "Scribing", EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED,
            function() SPT:QueueProgressionSnapshot(self) end)
    end
end

function Scribing:ReleaseDisplay()
    self.catalog = nil
end

function Scribing:GetPickupLocation(id)
    local icon = GetCraftedAbilityScriptIcon(id)
    if type(icon) ~= "string" then return end
    local basename = icon:lower():match("([^/\\]+)%.dds$")
    return SPT.ScribingLocations[basename]
end

function Scribing:CanSetPickupWaypoint(script)
    local pickup = script and script.pickup
    return pickup ~= nil and type(pickup.mapId) == "number" and pickup.mapId > 0
        and pickup.mapId <= 2147483647
        and pickup.mapId == math.floor(pickup.mapId)
        and type(pickup.x) == "number" and pickup.x > 0 and pickup.x < 1
        and type(pickup.y) == "number" and pickup.y > 0 and pickup.y < 1
        and GetCurrentMapId ~= nil and SetMapToMapId ~= nil and PingMap ~= nil
end

function Scribing:SetPickupWaypoint(script)
    if not self:CanSetPickupWaypoint(script) then return false end
    local pickup = script.pickup
    local previousMap = GetCurrentMapId()
    local result = SetMapToMapId(pickup.mapId)
    local success = result ~= SET_MAP_RESULT_FAILED and GetCurrentMapId() == pickup.mapId
    if success then
        PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, pickup.x, pickup.y)
    end
    -- Keep the user's map context; the native waypoint retains its destination.
    if previousMap and previousMap > 0 and GetCurrentMapId() ~= previousMap then
        SetMapToMapId(previousMap)
    end
    local message = success and string.format(GetString(SPT_MSG_SCRIPT_WAYPOINT_SET), script.name)
        or GetString(SPT_MSG_SCRIPT_WAYPOINT_FAILED)
    if success and CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE)
        params:SetText(message)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    end
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(message)
    elseif type(d) == "function" then
        d(message)
    end
    return success
end

function Scribing:GetCatalog()
    if self.catalog then return self.catalog end
    if not self:IsReady() then return end
    local ids = SCRIBING_DATA_MANAGER:GetAllCraftedAbilityScriptIds()
    if #ids == 0 then return end
    local catalog = {}
    for _, id in ipairs(ids) do
        local slot = GetCraftedAbilityScriptScribingSlot(id)
        if not IsCraftedAbilityScriptDisabled(id) and (slot == slots[1] or slot == slots[2] or slot == slots[3]) then
            catalog[#catalog + 1] = { id = id, slot = slot,
                name = zo_strformat("<<C:1>>", GetCraftedAbilityScriptDisplayName(id)),
                pickup = self:GetPickupLocation(id) }
        end
    end
    table.sort(catalog, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    self.catalog = catalog
    return catalog
end

local function GetUnlocked(charId, catalog)
    if charId == SPT.CharCache:GetCharId() then
        local unlocked = {}
        for _, script in ipairs(catalog) do
            if IsCraftedAbilityScriptUnlocked(script.id) then unlocked[script.id] = true end
        end
        return unlocked
    end
    return SPT:DecodeProgressionSnapshot(SPT.CharCache.roster[charId].scribingScripts, false)
end

local function SlotName(slot)
    return GetString("SI_SCRIBINGSLOT_SHORT", slot)
end

local function ScriptInfo(script)
    local parts = { script.name .. "\n" .. SlotName(script.slot) }
    local description = GetCraftedAbilityScriptGeneralDescription(script.id)
    if description and description ~= "" then parts[#parts + 1] = description end
    local hint = GetCraftedAbilityScriptAcquireHint(script.id)
    if not hint or hint == "" then hint = GetString(SPT_GUI_SCRIPT_ACQUISITION_UNAVAILABLE) end
    parts[#parts + 1] = GetString(SPT_GUI_SCRIPT_ACQUISITION) .. "\n" .. hint
    if script.pickup then
        parts[#parts + 1] = GetString(SPT_GUI_SCRIPT_PICKUP) .. "\n"
            .. GetString(_G[script.pickup.directions]) .. "\n" .. GetString(SPT_GUI_SCRIPT_PICKUP_REQUIREMENT)
    end
    return table.concat(parts, "\n\n")
end

function Scribing:BuildSummary(charId)
    local entry = SPT.CharCache.roster[charId]
    local isLive = charId == SPT.CharCache:GetCharId()
    local unlocked = not isLive and entry and SPT:DecodeProgressionSnapshot(entry.scribingScripts, false) or nil
    local counts, ready = {}, self:IsReady()
    for _, slot in ipairs(slots) do counts[slot] = { known = 0, total = 0 } end
    if ready then
        local ids = SCRIBING_DATA_MANAGER:GetAllCraftedAbilityScriptIds()
        ready = #ids > 0
        for _, id in ipairs(ids) do
            local count = counts[GetCraftedAbilityScriptScribingSlot(id)]
            if count and not IsCraftedAbilityScriptDisabled(id) then
                count.total = count.total + 1
                if (isLive and IsCraftedAbilityScriptUnlocked(id)) or (unlocked and unlocked[id]) then
                    count.known = count.known + 1
                end
            end
        end
    end
    local rows = {}
    local hasData = ready and (isLive or unlocked ~= nil) or false
    local status = SPT:GetProgressionStatus(charId, "scribingScripts", hasData)
    for _, slot in ipairs(slots) do
        local count = counts[slot]
        local progress = hasData and string.format("%d/%d", count.known, count.total) or "?"
        rows[#rows + 1] = { rowKey = "scribing:" .. slot, source = SlotName(slot), progress = progress,
            tooltipText = (entry and entry.name or "") .. "  |  " .. status .. "\n"
                .. GetString(SPT_GUI_TAB_SCRIBING) .. " - " .. SlotName(slot) .. ": " .. progress }
    end
    return rows
end

function Scribing:BuildView()
    local catalog = self:GetCatalog()
    local legend = string.format(GetString(SPT_GUI_SCRIBING_HELP), indicators.known, indicators.missing, indicators.unknown)
    local view = SPT:CreateProgressionTableView(self, GetString(SPT_GUI_SCRIPT), legend)
    view.infoTitle = GetString(SPT_GUI_TAB_SCRIBING)
    if not catalog then
        view.rows[1] = { source = GetString(SPT_GUI_DATA_UNAVAILABLE), cells = {} }
        return view
    end

    for _, slot in ipairs(slots) do
        local expanded = SPT:IsProgressionGroupExpanded(self, slot)
        view.rows[#view.rows + 1] = { source = (expanded and "[-] " or "[+] ") .. SlotName(slot),
            groupId = slot, rowKey = "slot:" .. slot, cells = {},
            tooltipText = SlotName(slot) .. "\n\n" .. GetString("SI_SCRIBINGSLOT_DESCRIPTION", slot)
                .. "\n\n" .. GetString(SPT_GUI_SCRIPT_GROUP_HELP) }
        if expanded then
            for _, script in ipairs(catalog) do
                if script.slot == slot then
                    view.rows[#view.rows + 1] = { source = "  " .. script.name,
                        rowKey = "script:" .. script.id, script = script, cells = {},
                        tooltipText = ScriptInfo(script) }
                end
            end
        end
    end

    for column, id in ipairs(view.characters) do
        local unlocked = GetUnlocked(id, catalog)
        for _, row in ipairs(view.rows) do
            local text = indicators.unknown
            if unlocked then
                if row.groupId then
                    local known, total = 0, 0
                    for _, script in ipairs(catalog) do
                        if script.slot == row.groupId then
                            total = total + 1
                            if unlocked[script.id] then known = known + 1 end
                        end
                    end
                    text = string.format("%d/%d", known, total)
                else
                    text = unlocked[row.script.id] and indicators.known or indicators.missing
                end
            end
            row.cells[column] = text
        end
    end
    return view
end

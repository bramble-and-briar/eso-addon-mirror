if SPT == nil then SPT = {} end
local Scribing = { firstCharacter = 1 }
SPT.Scribing = Scribing
local slots = { SCRIBING_SLOT_PRIMARY, SCRIBING_SLOT_SECONDARY, SCRIBING_SLOT_TERTIARY }

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
                name = zo_strformat("<<C:1>>", GetCraftedAbilityScriptDisplayName(id)) }
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

function Scribing:BuildView()
    local catalog = self:GetCatalog()
    local view = SPT:CreateProgressionTableView(self, GetString(SPT_GUI_SCRIPT), GetString(SPT_GUI_SCRIBING_HELP))
    view.infoTitle = GetString(SPT_GUI_TAB_SCRIBING)
    if not catalog then
        view.rows[1] = { source = GetString(SPT_GUI_DATA_UNAVAILABLE), cells = {} }
        return view
    end

    for _, slot in ipairs(slots) do
        local expanded = SPT:IsProgressionGroupExpanded(self, slot)
        view.rows[#view.rows + 1] = { source = (expanded and "[-] " or "[+] ") .. SlotName(slot),
            groupId = slot, rowKey = "slot:" .. slot, cells = {} }
        if expanded then
            for _, script in ipairs(catalog) do
                if script.slot == slot then
                    view.rows[#view.rows + 1] = { source = "  " .. script.name,
                        rowKey = "script:" .. script.id, script = script, cells = {},
                        info = { script.name, SlotName(slot), GetCraftedAbilityScriptAcquireHint(script.id) } }
                end
            end
        end
    end

    for column, id in ipairs(view.characters) do
        local entry = SPT.CharCache.roster[id]
        local unlocked = GetUnlocked(id, catalog)
        local status = SPT:GetProgressionStatus(id, "scribingScripts", unlocked ~= nil)
        for _, row in ipairs(view.rows) do
            local text = "?"
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
                    text = unlocked[row.script.id] and "|cFFFFFF" .. GetString(SPT_GUI_KNOWN) .. "|r" or "|cE8B864--|r"
                end
            end
            SPT:AddProgressionTableCell(row, column, entry.name, text, status)
        end
    end
    return SPT:FinishProgressionTableView(view)
end

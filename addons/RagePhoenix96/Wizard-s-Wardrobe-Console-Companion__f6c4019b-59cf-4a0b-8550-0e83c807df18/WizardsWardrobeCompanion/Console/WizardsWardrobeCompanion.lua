local companion = WizardsWardrobeCompanion
companion.name = "WizardsWardrobeCompanion"
companion.version = "1.0.0"
companion.status = "waiting"
companion.sharedZones = {}
companion.warnings = {}

local consoleUI = false
if type(ZO_IsConsoleOrGameCoreUI) == "function" then
    consoleUI = ZO_IsConsoleOrGameCoreUI()
elseif type(IsConsoleUI) == "function" then
    consoleUI = IsConsoleUI()
end
if not consoleUI then
    companion.status = "inactive: console UI required"
    return
end

local unpackValues = unpack or table.unpack
local function pack(...)
    return { n = select("#", ...), ... }
end

local function warn(message)
    table.insert(companion.warnings, message)
    if type(d) == "function" then
        d("Wizard's Wardrobe Console Companion: " .. message)
    end
end

local function isShared(zone)
    return zone and companion.sharedZones[zone.tag] == zone
end

local function installDungeons(WW)
    local trash = GetString(WW_TRASH)
    -- Decline conflicting tags before adding either category.
    for _, definition in ipairs(companion.dungeons) do
        local zone = WW.zones[definition.tag]
        local pages, setups = WW.pages[definition.tag], WW.setups[definition.tag]
        if (pages == nil and type(setups) == "table" and next(setups))
            or (pages ~= nil and (type(pages) ~= "table" or type(pages[0]) ~= "table"
                or type(pages[0].selected) ~= "number"
                or type(pages[pages[0].selected]) ~= "table")) then
            warn("Dungeon categories not added: existing " .. definition.tag .. " builds have incomplete page metadata. No saved builds changed.")
            return false
        end
        if zone and not (zone.tag == definition.tag and zone.sharedDungeonSetups
            and zone.category == WW.ACTIVITIES[definition.category]
            and type(zone.bosses) == "table" and #zone.bosses == 2
            and type(zone.bosses[1]) == "table" and type(zone.bosses[2]) == "table"
            and zone.bosses[1].name == trash
            and zone.bosses[2].name == companion.bossKey
            and type(zone.Init) == "function"
            and type(zone.Reset) == "function"
            and type(zone.OnBossChange) == "function") then
            warn("Dungeon categories not added: another addon owns " .. definition.tag .. ".")
            return false
        end
    end

    companion.skippedZoneIds = {}
    for _, definition in ipairs(companion.dungeons) do
        local zone = WW.zones[definition.tag]
        if not zone then
            zone = {
                tag = definition.tag,
                name = definition.name,
                category = WW.ACTIVITIES[definition.category],
                priority = definition.priority,
                icon = definition.icon,
                id = {},
                sharedDungeonSetups = true,
                bosses = {
                    { name = trash },
                    { name = companion.bossKey, displayName = "Bosses" },
                },
            }
            local eventName = companion.name .. definition.tag
            function zone.Init()
                if not WW.pages[zone.tag] then
                    local pageId = WW.selection.pageId
                    local result = pack(pcall(WW.gui.CreatePage, zone))
                    WW.selection.pageId = pageId
                    if not result[1] then error(result[2], 0) end
                end
                WW.conditions.LoadConditions()
                EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_COMBAT_STATE,
                    function(_, inCombat)
                        if not inCombat and WW.currentZone == zone then
                            WW.OnBossChange()
                        end
                    end)
            end
            function zone.Reset()
                EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_COMBAT_STATE)
                if WW.currentZone == zone then
                    WW.conditions.bossList = {}
                    WW.conditions.trashList = {}
                end
            end
            function zone.OnBossChange(bossName)
                if WW.currentZone ~= zone then return end
                WW.conditions.OnBossChange(#bossName > 0 and companion.bossKey or "")
            end
            WW.zones[zone.tag] = zone
        end

        companion.sharedZones[zone.tag] = zone
        zone.lookupBosses = zone.lookupBosses or {}
        for index, boss in ipairs(zone.bosses) do
            zone.lookupBosses[boss.name] = index
        end
        for _, id in ipairs(definition.ids) do
            local current = WW.lookupZones[id]
            if current == nil or current == zone then
                if type(zone.id) == "table" then zone.id[id] = true end
                WW.lookupZones[id] = zone
            else
                table.insert(companion.skippedZoneIds, id)
            end
        end
    end
    if #companion.skippedZoneIds > 0 then
        warn("Kept " .. #companion.skippedZoneIds .. " existing dungeon routes from other addons.")
    end
    return true
end

local function wrapTracking(WW)
    if type(WW.equipped) ~= "table" then WW.equipped = {} end
    local originalLoad = WW.LoadSetup
    WW.LoadSetup = function(zone, pageId, index, ...)
        if type(WW.equipped) ~= "table" then WW.equipped = {} end
        local result = pack(originalLoad(zone, pageId, index, ...))
        if result[1] == true then
            WW.equipped.zone = zone.tag
            WW.equipped.page = pageId
            WW.equipped.setup = index
        end
        return unpackValues(result, 1, result.n)
    end
end

local function wrapSubstitutes(WW)
    local original = WW.conditions.LoadSubstitute
    WW.conditions.LoadSubstitute = function(...)
        if isShared(WW.currentZone) then return end
        return original(...)
    end
end

local function wrapConsoleMenu(WW)
    local originalInit = WW.consoleControl.Init
    WW.consoleControl.Init = function(...)
        local previous = WW.equipped or {}
        local saved = { zone = previous.zone, page = previous.page, setup = previous.setup }
        local library = LibHarvensAddonSettings
        local originalAddAddon = library.AddAddon
        local ownAddAddon = rawget(library, "AddAddon")
        local restorations = {}
        local condition, baseDisable
        local patchedCondition, patchedAfter = false, false

        local function selectedShared()
            return WW.selection and isShared(WW.selection.zone)
        end

        local function patchSetting(setting)
            if setting.label == "Category" and type(setting.disable) == "function" then
                baseDisable = setting.disable
            elseif setting.label == "Auto Equip Condition"
                and setting.type == library.ST_DROPDOWN and baseDisable
                and type(setting.disable) == "function"
                and type(setting.getFunction) == "function"
                and type(setting.setFunction) == "function" then
                condition = setting
                local originalDisable = setting.disable
                local originalSet = setting.setFunction
                setting.disable = function(...)
                    if not selectedShared() then return originalDisable(...) end
                    return baseDisable(...) or not WW.settings.autoEquipSetups
                end
                setting.setFunction = function(control, name, item, ...)
                    if selectedShared() and item and type(item.data) == "table"
                        and item.data.boss == WW.CONDITIONS.NONE then
                        local normalized = {}
                        for key, value in pairs(item) do normalized[key] = value end
                        normalized.data = WW.CONDITIONS.NONE
                        return originalSet(control, name, normalized, ...)
                    end
                    return originalSet(control, name, item, ...)
                end
                patchedCondition = true
            elseif setting.label == "Auto Equip Trash After"
                and setting.type == library.ST_DROPDOWN and baseDisable and condition
                and type(setting.disable) == "function" then
                local originalDisable = setting.disable
                setting.disable = function(...)
                    if not selectedShared() then return originalDisable(...) end
                    return baseDisable(...) or not WW.settings.autoEquipSetups
                        or condition.getFunction() ~= GetString(WW_TRASH)
                end
                patchedAfter = true
            end
        end

        -- Intercept only this menu's construction, then restore the library methods.
        library.AddAddon = function(self, name, ...)
            local result = pack(originalAddAddon(self, name, ...))
            local menu = result[1]
            if name == "Wizards Wardrobe Control" and menu
                and type(menu.AddSetting) == "function" then
                local originalAddSetting = menu.AddSetting
                table.insert(restorations, { menu = menu, method = rawget(menu, "AddSetting") })
                menu.AddSetting = function(target, setting, ...)
                    patchSetting(setting)
                    return originalAddSetting(target, setting, ...)
                end
            end
            return unpackValues(result, 1, result.n)
        end

        local result = pack(pcall(originalInit, ...))
        library.AddAddon = ownAddAddon
        for index = #restorations, 1, -1 do
            local restore = restorations[index]
            restore.menu.AddSetting = restore.method
        end

        -- Stock Init creates a new table captured by its UI callbacks. Retain it.
        local equipped = WW.equipped
        if type(equipped) == "table" and equipped.zone == nil
            and equipped.page == nil and equipped.setup == nil then
            equipped.zone, equipped.page, equipped.setup = saved.zone, saved.page, saved.setup
        end
        if not result[1] then error(result[2], 0) end
        companion.menuPatched = patchedCondition and patchedAfter
        if not companion.menuPatched and next(companion.sharedZones) then
            warn("Some condition controls were not recognized; unrecognized controls keep their original guards.")
        end
        return unpackValues(result, 2, result.n)
    end
end

local function ready(WW)
    return type(WW) == "table" and WW.version == "0.4.2"
        and type(WW.lookupZones) == "table"
        and type(WW.zones) == "table" and type(WW.pages) == "table"
        and type(WW.setups) == "table" and type(WW.settings) == "table"
        and type(WW.selection) == "table" and type(WW.ACTIVITIES) == "table"
        and WW.ACTIVITIES.DUNGEONS and WW.ACTIVITIES.DLC_DUNGEONS
        and type(WW.CONDITIONS) == "table" and WW.CONDITIONS.NONE ~= nil
        and WW.CONDITIONS.EVERYWHERE ~= nil
        and type(WW.LoadSetup) == "function" and type(WW.OnBossChange) == "function"
        and type(WW.gui) == "table" and type(WW.gui.CreatePage) == "function"
        and type(WW.conditions) == "table"
        and type(WW.conditions.LoadSubstitute) == "function"
        and type(WW.conditions.LoadConditions) == "function"
        and type(WW.conditions.OnBossChange) == "function"
        and type(WW.consoleControl) == "table"
        and type(WW.consoleControl.Init) == "function"
        and type(LibHarvensAddonSettings) == "table"
        and type(LibHarvensAddonSettings.AddAddon) == "function"
end

local function stopWaiting()
    EVENT_MANAGER:UnregisterForEvent(companion.name, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:UnregisterForEvent(companion.name, EVENT_PLAYER_ACTIVATED)
end

function companion.Apply()
    if companion.applied then return true end
    local WW = WizardsWardrobe
    if type(WW) == "table" and WW.version and WW.version ~= "0.4.2" then
        companion.status = "inactive: unsupported Wardrobe version"
        warn("Tested with console Wizard's Wardrobe 0.4.2 only; no changes applied to " .. tostring(WW.version) .. ".")
        stopWaiting()
        return false
    end
    if not ready(WW) then return false end
    companion.dungeonsEnabled = installDungeons(WW)
    wrapTracking(WW)
    wrapSubstitutes(WW)
    wrapConsoleMenu(WW)
    companion.applied = true
    companion.status = companion.dungeonsEnabled and "active" or "active: tracking only"
    stopWaiting()
    return true
end

EVENT_MANAGER:RegisterForEvent(companion.name, EVENT_ADD_ON_LOADED,
    function(_, addonName)
        if addonName == companion.name or addonName == "WizardsWardrobe" then
            companion.Apply()
        end
    end)
EVENT_MANAGER:RegisterForEvent(companion.name, EVENT_PLAYER_ACTIVATED,
    function()
        if not companion.Apply() then
            companion.status = "inactive: dependency not ready"
            warn("Required console Wizard's Wardrobe APIs are unavailable. Check addon dependencies, then reload the UI.")
        end
        stopWaiting()
    end)

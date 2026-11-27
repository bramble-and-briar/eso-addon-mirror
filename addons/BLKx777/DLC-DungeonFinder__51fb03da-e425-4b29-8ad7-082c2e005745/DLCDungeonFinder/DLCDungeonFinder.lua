-- DLC Dungeon Finder | BLKx777 | 0.1.0
-- Console / gamepad Dungeon Finder extension.
local ADDON = "DLCDungeonFinder"
local TITLE = "DLC Dungeon Finder"
local MENU_TEXT = "Random Veteran DLC Dungeon"
local TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local ICON = "EsoUI/Art/LFG/Gamepad/gp_LFG_menuIcon_Random.dds"
local CATEGORY_MODE = 1
local installed = false
local sceneRegistered = false
local warned = false
local prepared = false
local entry

-- Original group dungeons plus Imperial City dungeons (base game since U49).
-- Zone IDs are stable across client languages and normal/veteran activity IDs.
local BASE_ZONES = {
    [148] = true, -- Arx Corinium
    [380] = true, [935] = true, -- Banished Cells I / II
    [38] = true, -- Blackheart Haven
    [64] = true, -- Blessed Crucible
    [176] = true, [681] = true, -- City of Ash I / II
    [130] = true, [932] = true, -- Crypt of Hearts I / II
    [63] = true, [930] = true, -- Darkshade Caverns I / II
    [449] = true, -- Direfrost Keep
    [126] = true, [931] = true, -- Elden Hollow I / II
    [283] = true, [934] = true, -- Fungal Grotto I / II
    [31] = true, -- Selene's Web
    [144] = true, [936] = true, -- Spindleclutch I / II
    [131] = true, -- Tempest Island
    [11] = true, -- Vaults of Madness
    [22] = true, -- Volenfell
    [146] = true, [933] = true, -- Wayrest Sewers I / II
    [678] = true, [688] = true, -- Imperial City Prison / White-Gold Tower
}

local function Notify(message)
    local text = TITLE .. ": " .. message
    if type(ZO_Alert) == "function" and UI_ALERT_CATEGORY_ALERT then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, text)
    elseif type(d) == "function" then
        d(text)
    end
end

local function IsSearching(root)
    return IsCurrentlySearchingForGroup() or
        (root.GetIsCurrentlyInQueue and root:GetIsCurrentlyInQueue())
end

local function IsEligible(location)
    if location:GetActivityType() ~= LFG_ACTIVITY_MASTER_DUNGEON then return false end
    if location:GetEntryType() ~= ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE.SPECIFIC then return false end
    local zone = location:GetZoneId()
    if type(zone) ~= "number" or zone <= 0 or BASE_ZONES[zone] then return false end
    if not location:IsActive() or location:IsLocked() or location:IsDisabled() then return false end
    return true
end

local function ValidateSelections(root, allowed, expected)
    local count = 0
    for _, locations in pairs(root:GetLocationsData()) do
        for _, location in ipairs(locations) do
            if location:IsSelected() then
                if not allowed[location] then return false end
                count = count + 1
            end
        end
    end
    return count == expected and count > 0
end

local function Prepare(root, quiet)
    if IsSearching(root) then
        if not quiet then Notify("Already in a queue. Leave it before changing dungeons.") end
        return false
    end
    if root:IsLockedByNotLeader() then
        if not quiet then Notify("Only the group leader can prepare the queue.") end
        return false
    end
    if type(ZO_GroupFinder_IsGroupFinderInUse) == "function" and ZO_GroupFinder_IsGroupFinderInUse() then
        if not quiet then Notify("Close Group Finder before queueing.") end
        return false
    end

    local changed = false
    local ok, count = pcall(function()
        root:UpdateLocationData()
        local locations = root:GetLocationsData(LFG_ACTIVITY_MASTER_DUNGEON)
        if type(locations) ~= "table" then error("Veteran activity data unavailable") end
        local candidates, allowed = {}, {}
        for _, location in ipairs(locations) do
            if IsEligible(location) and not allowed[location] then
                candidates[#candidates + 1] = location
                allowed[location] = true
            end
        end
        -- Clear any previously selected random set, normal or base-game dungeon.
        changed = true
        root:ClearSelections()
        if #candidates == 0 then return 0 end
        for _, location in ipairs(candidates) do
            root:SetLocationSelected(location, true)
        end
        if not ValidateSelections(root, allowed, #candidates) then
            error("Dungeon selection did not match the DLC filter")
        end
        return #candidates
    end)

    prepared = ok and count > 0
    if not ok then
        if changed and not IsSearching(root) then pcall(root.ClearSelections, root) end
        Notify("Could not prepare a safe DLC-only selection. No queue was started.")
        if type(d) == "function" then d(TITLE .. " [0.1.0]: " .. tostring(count)) end
        return false
    end
    if count == 0 then
        Notify("No eligible veteran DLC dungeons. Check your level, access and group status.")
        return false
    end
    if not quiet then
        Notify(string.format("%d veteran DLC dungeons selected. Use Join Queue. No random bonus.", count))
    end
    return true
end

local function FindKeybind(descriptor, key)
    for _, item in ipairs(descriptor or {}) do
        if item.keybind == key and type(item.callback) == "function" then return item end
    end
end

local function IsCustomTarget(finder)
    if finder.navigationMode ~= CATEGORY_MODE or finder:GetCurrentList() ~= finder.categoryList then return false end
    local target = finder.categoryList:GetTargetData()
    return target and target.data and target.data.dlcDungeonFinder == true
end

local function EnsureEntry(finder)
    local list = finder.categoryList
    for index = 1, list:GetNumEntries() do
        local existing = list:GetEntryData(index)
        if existing and existing.data and existing.data.dlcDungeonFinder then return end
    end
    entry = ZO_GamepadEntryData:New(MENU_TEXT, ICON)
    entry.data = { dlcDungeonFinder = true }
    entry:SetIconTintOnSelection(true)
    list:AddEntry(TEMPLATE, entry)
    list:Commit()
end

local function Install()
    local finder = DUNGEON_FINDER_GAMEPAD
    local root = ZO_ACTIVITY_FINDER_ROOT_MANAGER
    if not finder or not root or not finder.categoryList or not finder.keybindStripDescriptor then return false end
    local list = finder.categoryList
    if not ZO_GamepadEntryData or not ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE or not LFG_ACTIVITY_MASTER_DUNGEON then return false end
    if type(list.GetNumEntries) ~= "function" or type(list.GetEntryData) ~= "function" or
       type(list.AddEntry) ~= "function" or type(list.Commit) ~= "function" then return false end
    if not installed then
        local primary = FindKeybind(finder.keybindStripDescriptor, "UI_SHORTCUT_PRIMARY")
        local secondary = FindKeybind(finder.keybindStripDescriptor, "UI_SHORTCUT_SECONDARY")
        if not primary or not secondary then return false end
        local originalPrimary, originalSecondary = primary.callback, secondary.callback
        primary.callback = function(...)
            if IsCustomTarget(finder) then
                Prepare(root, false)
                return
            end
            -- Native menu selection retains its original behavior.
            if finder.navigationMode == CATEGORY_MODE then
                local target = list:GetTargetData()
                if target and target.data and not target.data.isRoleSelector then prepared = false end
            end
            return originalPrimary(...)
        end
        secondary.callback = function(...)
            -- Recheck eligibility immediately before native matchmaking.
            -- Never intercept the native Leave Queue action.
            if not IsSearching(root) and (IsCustomTarget(finder) or
                (prepared and finder.navigationMode == CATEGORY_MODE)) then
                if not Prepare(root, true) then return end
            end
            prepared = false
            return originalSecondary(...)
        end
        installed = true
    end
    EnsureEntry(finder)
    return true
end

local function TryInstall(reportFailure)
    local ok, result = pcall(Install)
    if (not ok or not result) and reportFailure and not warned then
        warned = true
        Notify("Dungeon Finder menu unavailable. Please report the client/API version.")
        if not ok and type(d) == "function" then d(TITLE .. ": " .. tostring(result)) end
    end
    return ok and result
end

local function RegisterScene()
    if sceneRegistered then return end
    local scene = GAMEPAD_DUNGEON_FINDER_SCENE or
        (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepadDungeonFinder"))
    if not scene then return end
    sceneRegistered = true
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
            TryInstall(newState == SCENE_SHOWN)
        elseif newState == SCENE_HIDING then
            local root = ZO_ACTIVITY_FINDER_ROOT_MANAGER
            if prepared and root and not IsSearching(root) then root:ClearSelections() end
            prepared = false
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    RegisterScene()
    TryInstall(false)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
        RegisterScene()
        TryInstall(false)
        if sceneRegistered then EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED) end
    end)
end)

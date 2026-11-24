-- Settings panel: profiles, the zone types they load in, and a read-only view of their slots.

local QSP = QuickslotProfiles
local LAM = LibAddonMenu2

local panel = nil
local selectedId = nil

local function GetSelected()
    if not QSP.GetProfile(selectedId) then
        selectedId = QSP.GetActiveId() or QSP.GetOrder()[1]
    end
    return selectedId
end

local function ProfileChoices()
    local names, ids = {}, {}
    for _, id in ipairs(QSP.GetOrder()) do
        names[#names + 1] = QSP.ProfileName(id)
        ids[#ids + 1] = id
    end
    return names, ids
end

function QSP.RefreshSettings()
    if not panel then return end
    local dropdown = QuickslotProfilesProfileDropdown
    if dropdown and dropdown.UpdateChoices then
        dropdown:UpdateChoices(ProfileChoices())
    end
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
end

function QSP.OpenSettings()
    if panel then LAM:OpenToPanel(panel) end
end

local function SlotsText()
    local id = GetSelected()
    local profile = QSP.GetProfile(id)
    if not profile then return "" end
    local lines = {}
    for slot = 1, QSP.NUM_SLOTS do
        lines[slot] = slot .. ".  " .. QSP.DescribeEntry(profile.slots[slot], true)
    end
    return table.concat(lines, "\n")
end

local function ZoneOverviewText()
    local lines = {}
    local fallback = QSP.GetZoneTypeOwner("other")
    for _, zoneType in ipairs(QSP.ZONE_TYPES) do
        local owner = QSP.GetZoneTypeOwner(zoneType.key)
        local text
        if owner then
            text = QSP.Hi(QSP.ProfileName(owner))
        elseif fallback then
            text = QSP.ProfileName(fallback) .. " |c888888(everything else)|r"
        else
            text = "|c888888wheel stays as it is|r"
        end
        lines[#lines + 1] = zoneType.name .. ":  " .. text
    end
    local active = QSP.GetActiveId()
    lines[#lines + 1] = ""
    if QSP.IsArmoryUnlocked() then
        lines[#lines + 1] = "Armory build in use: " .. QSP.Hi(QSP.LayerName(QSP.GetCurrentLayer()))
    end
    lines[#lines + 1] = "On the wheel now: " .. QSP.Hi(active and QSP.ProfileName(active) or "none")
    return table.concat(lines, "\n")
end

function QSP.InitializeSettings()
    panel = LAM:RegisterAddonPanel(QSP.NAME .. "Options", {
        type = "panel",
        name = QSP.TITLE,
        displayName = QSP.TITLE,
        author = "Schrodi",
        version = QSP.VERSION,
        registerForRefresh = true,
    })

    local names, ids = ProfileChoices()
    local options =
    {
        {
            type = "description",
            text = "Each profile is a set of quickslots. A loading screen puts the profile of the zone type you're in on the wheel.\n"
                .. "Profiles are edited in the inventory's Quickslots tab (or " .. QSP.Hi("Edit slots") .. " below): under the wheel "
                .. "you pick a profile and the zone types it loads in, and keep changes with " .. QSP.Hi("Save") .. ". "
                .. "Opening the tab also loads the profile again, e.g. after restocking.\n"
                .. "Zone types can be set per Armory build: restore or save a build at the Armory once, then pick the build "
                .. "above the wheel in the Quickslots tab.",
        },
        {
            type = "dropdown",
            name = "Profile",
            choices = names,
            choicesValues = ids,
            scrollable = true,
            getFunc = GetSelected,
            setFunc = function(id) selectedId = id end,
            reference = "QuickslotProfilesProfileDropdown",
        },
        {
            type = "editbox",
            name = "Name",
            getFunc = function() return QSP.ProfileName(GetSelected()) end,
            setFunc = function(name)
                local id = GetSelected()
                if not id or name == QSP.ProfileName(id) then return end
                local ok, reason = QSP.RenameProfile(id, name)
                if not ok then QSP.Msg(reason) end
                QSP.RefreshSettings()
            end,
            disabled = function() return GetSelected() == nil end,
            isMultiline = false,
        },
        {
            type = "description",
            title = "Slots",
            text = SlotsText,
            enableLinks = true,
        },
        {
            type = "button",
            name = "Edit slots",
            tooltip = "Opens the inventory's Quickslots tab with this profile on the wheel. Drag items and collectibles onto the wheel as usual "
                .. "and press Save. Leaving the tab puts this zone's profile back.",
            width = "half",
            func = function() QSP.Editor.Open(GetSelected()) end,
            disabled = function() return GetSelected() == nil end,
        },
        {
            type = "button",
            name = "New profile",
            tooltip = "A new profile with what is on the wheel now. It doesn't load anywhere until you pick zone types for it in Edit slots.",
            width = "half",
            func = function()
                selectedId = QSP.CreateProfile(nil, QSP.CaptureWheel())
                QSP.RefreshSettings()
            end,
        },
        {
            type = "button",
            name = "Delete profile",
            width = "half",
            isDangerous = true,
            warning = "Deletes the selected profile. The wheel stays as it is.",
            func = function()
                local id = GetSelected()
                if not id then return end
                local name = QSP.ProfileName(id)
                QSP.DeleteProfile(id)
                selectedId = nil
                QSP.Msg("Deleted " .. QSP.Hi(name) .. ".")
                QSP.RefreshSettings()
            end,
            disabled = function() return GetSelected() == nil end,
        },
        {
            type = "header",
            name = "Zone types",
        },
        {
            type = "description",
            text = function()
                return QSP.IsArmoryUnlocked() and "For the Armory build in use. Other builds: pick the build above the wheel in the Quickslots tab." or ""
            end,
        },
        {
            type = "description",
            text = ZoneOverviewText,
        },
        {
            type = "header",
            name = "Options",
        },
        {
            type = "checkbox",
            name = "Save changes when leaving the quickslot menu",
            tooltip = "Closing the inventory, leaving the Quickslots tab or picking another profile saves the profile you edited. "
                .. "Off: unsaved changes are discarded, keep them with the Save button.\n\nFor all characters.",
            getFunc = QSP.IsSaveOnLeaveOn,
            setFunc = QSP.SetSaveOnLeave,
        },
        {
            type = "checkbox",
            name = "Clear slots that are empty in the profile",
            tooltip = "When a profile loads, its empty slots empty the wheel's slot too. Off: those slots keep whatever was there.\n\n"
                .. "In the quickslot menu a profile is always shown exactly, empty slots included.\n\nFor all characters.",
            getFunc = QSP.IsClearEmptyOn,
            setFunc = QSP.SetClearEmpty,
        },
        {
            type = "checkbox",
            name = "Chat message when a profile loads",
            tooltip = "Missing items are always reported.\n\nFor all characters.",
            getFunc = QSP.IsChatOnLoadOn,
            setFunc = QSP.SetChatOnLoad,
        },
    }

    LAM:RegisterOptionControls(QSP.NAME .. "Options", options)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(openedPanel)
        if openedPanel == panel then QSP.RefreshSettings() end
    end)
end

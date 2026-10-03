CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- Display name for the keybind action declared in Bindings.xml (action
-- name COMPANIONGEARHUNTER_TOGGLE). Must run before the Keybindings menu
-- is ever opened, so top-level code here is fine - same pattern
-- CompanionRoster uses for its own /fcr toggle keybind.
ZO_CreateStringId("SI_BINDING_NAME_COMPANIONGEARHUNTER_TOGGLE", "Toggle Feliks' Companion Gear Hunter")

local IGNORE_CALLBACKS = true

local companionDropdown = nil
local selectedCompanionId = nil
local currentCompanionRole = nil

-- Same engine constants CompanionRoster stores its Role tag as
-- (LFG_ROLE_TANK/_HEAL/_DPS), so a role read from there is directly usable
-- here with no translation.
local ROLE_NAMES = {
    [LFG_ROLE_TANK] = "Tank",
    [LFG_ROLE_HEAL] = "Healer",
    [LFG_ROLE_DPS] = "DPS",
}

-- rows[i] = { control = <row control>, slotDef = <SLOTS entry>,
-- wantType/wantTrait/wantQuality = <ZO_ComboBox object> }
local rows = {}

local WEIGHT_NAMES = {
    [ARMORTYPE_LIGHT] = "Light",
    [ARMORTYPE_MEDIUM] = "Medium",
    [ARMORTYPE_HEAVY] = "Heavy",
}

-- Highlight color for a slot that's actively wanted (not all "Any") and not
-- yet satisfied by what's equipped - the same signal as a yellow-highlighted
-- row in a manual tracking spreadsheet.
local ROW_HIGHLIGHT_COLOR = { 1, 0.9, 0.3, 0.18 }
local ROW_STRIPE_COLOR = { 1, 1, 1, 0.06 }
local ROW_CLEAR_COLOR = { 0, 0, 0, 0 }
local BLANK_TEXT_COLOR = { 0.6, 0.6, 0.6, 1 }

local function SelectComboValue(combo, value)
    for _, entry in ipairs(combo.m_sortedItems) do
        if entry.matchValue == value then
            combo:SelectItem(entry, IGNORE_CALLBACKS)
            return
        end
    end
end

-- Wanted-column selection handlers - one shared handler per column type,
-- reading the slot/value off the entry itself (same pattern CompanionRoster
-- uses for its character dropdown), rather than a one-off closure per option.

-- ZO_CheckButton invokes this as buttonControl:toggleFunction(checked), i.e.
-- toggleFunction(buttonControl, checked) - the callback needs both
-- parameters even though only `checked` is used, otherwise `checked` here
-- silently receives the button control instead of the boolean (confirmed
-- via real ZO_CheckButton_SetToggleFunction call sites, e.g.
-- groupfinder_additionalfilters_keyboard.lua's `function(button, checked)`).
-- Without the first parameter, every click was writing a truthy control
-- object as `enabled`, which then compared false against `== true` and
-- immediately unchecked itself on refresh - this is that fix.
local function CreateWantEnabledToggle(slotKey)
    return function(buttonControl, checked)
        CompanionGearHunter.Data.SetWishlistEnabled(selectedCompanionId, slotKey, checked)
        CompanionGearHunter.RefreshGrid()
    end
end

local function OnWantTypeSelected(comboBoxControl, entryText, entry)
    CompanionGearHunter.Data.SetWishlistSubType(selectedCompanionId, entry.slotKey, entry.matchValue)
    CompanionGearHunter.RefreshGrid()
end

local function OnWantTraitSelected(comboBoxControl, entryText, entry)
    CompanionGearHunter.Data.SetWishlistTrait(selectedCompanionId, entry.slotKey, entry.matchValue)
    CompanionGearHunter.RefreshGrid()
end

local function OnWantQualitySelected(comboBoxControl, entryText, entry)
    CompanionGearHunter.Data.SetWishlistQualityFloor(selectedCompanionId, entry.slotKey, entry.matchValue)
    CompanionGearHunter.RefreshGrid()
end

local function PopulateTypeCombo(combo, slotDef)
    combo:ClearItems()
    local anyEntry = combo:CreateItemEntry("Any", OnWantTypeSelected)
    anyEntry.slotKey, anyEntry.matchValue = slotDef.key, nil
    combo:AddItem(anyEntry)

    local options
    if slotDef.category == "armor" then
        options = CompanionGearHunter.Data.WEIGHT_OPTIONS
    elseif slotDef.category == "weapon" then
        options = CompanionGearHunter.Data.WEAPON_TYPE_OPTIONS
    end

    if options then
        for _, option in ipairs(options) do
            local entry = combo:CreateItemEntry(option.name, OnWantTypeSelected)
            entry.slotKey, entry.matchValue = slotDef.key, option.value
            combo:AddItem(entry)
        end
    end
end

local function PopulateTraitCombo(combo, slotDef)
    combo:ClearItems()
    local anyEntry = combo:CreateItemEntry("Any", OnWantTraitSelected)
    anyEntry.slotKey, anyEntry.matchValue = slotDef.key, nil
    combo:AddItem(anyEntry)

    for _, option in ipairs(CompanionGearHunter.Data.GetTraitOptions(slotDef.category)) do
        local entry = combo:CreateItemEntry(option.name, OnWantTraitSelected)
        entry.slotKey, entry.matchValue = slotDef.key, option.traitType
        combo:AddItem(entry)
    end
end

local function PopulateQualityCombo(combo, slotDef)
    combo:ClearItems()
    local anyEntry = combo:CreateItemEntry("Any", OnWantQualitySelected)
    anyEntry.slotKey, anyEntry.matchValue = slotDef.key, nil
    combo:AddItem(anyEntry)

    for _, option in ipairs(CompanionGearHunter.Data.QUALITY_OPTIONS) do
        local entry = combo:CreateItemEntry(option.name, OnWantQualitySelected)
        entry.slotKey, entry.matchValue = slotDef.key, option.value
        combo:AddItem(entry)
    end
end

-- On the CompanionGearHunter table (not a separate bare global) because the
-- XML OnMouseEnter handler on the Role texture's wrapper Control calls this
-- by name.
function CompanionGearHunter.OnCompanionRoleMouseEnter(control)
    if currentCompanionRole then
        ZO_Tooltips_ShowTextTooltip(control, TOP, ROLE_NAMES[currentCompanionRole] or "Unknown role")
    end
end

-- CompanionRoster only exists as a global when that addon is actually
-- installed and loaded - guarding on it (and its Data table) is what makes
-- this integration optional rather than a hard dependency.
local function RefreshCompanionRole()
    currentCompanionRole = (CompanionRoster and CompanionRoster.Data and selectedCompanionId)
        and CompanionRoster.Data.GetCompanionRole(selectedCompanionId)
        or nil

    local roleControl = CompanionGearHunterWindowCompanionRole
    if currentCompanionRole then
        roleControl:GetNamedChild("Icon"):SetTexture(ZO_GetRoleIcon(currentCompanionRole))
        roleControl:SetHidden(false)
    else
        roleControl:SetHidden(true)
    end
end

-- companionId -> its dropdown entry, so labels can be updated in place.
local companionEntries = {}

-- Appends a companion icon (in the "wanted" color) to the name of any companion with something still being
-- hunted. Suffix rather than prefix so names stay left-aligned whether or not
-- the icon is shown. Entry names are read when the list is drawn, so updating
-- them in place is enough; the closed dropdown's own text is set separately.
local function RefreshCompanionDropdownLabels()
    if companionDropdown == nil then
        return
    end
    local starTag = string.format(" |c%s%s|r", CompanionGearHunter.Data.GetMarkerColorHex("wanted"), zo_iconFormatInheritColor(CompanionGearHunter.Data.MARKER_ICON, 30, 30))
    for companionId, entry in pairs(companionEntries) do
        entry.name = entry.baseName .. (CompanionGearHunter.Data.HasActiveHunt(companionId) and starTag or "")
        if companionId == selectedCompanionId then
            companionDropdown:SetSelectedItemText(entry.name)
        end
    end
end

function CompanionGearHunter.RefreshGrid()
    if selectedCompanionId == nil then
        local companions = CompanionGearHunter.Data.GetAllCompanions()
        selectedCompanionId = companions[1] and companions[1].id
    end

    RefreshCompanionRole()

    -- Shared with CompanionGearHunter_Data.lua's matching/upgrade logic
    -- (GetCandidateSlotKeysForCompanion) so the grid and the tooltip
    -- signals always agree on which companions currently have no
    -- Off-Hand slot to speak of.
    local hideOffHand = selectedCompanionId and CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(selectedCompanionId)

    for i, rowInfo in ipairs(rows) do
        local row = rowInfo.control
        local slotDef = rowInfo.slotDef

        if slotDef.key == "OffHand" and hideOffHand then
            row:SetHidden(true)
        else
            row:SetHidden(false)

            local slotLabel = slotDef.label
            if slotDef.key == "MainHand" and hideOffHand then
                slotLabel = "Two-Handed"
            end
            row:GetNamedChild("Slot"):SetText(slotLabel)

            local itemLink = selectedCompanionId and CompanionGearHunter.Data.GetCachedEquippedLink(selectedCompanionId, slotDef.key)
            local info = CompanionGearHunter.Data.DecodeItemLink(itemLink)

            local eqType = row:GetNamedChild("EqType")
            local eqTrait = row:GetNamedChild("EqTrait")
            local eqQuality = row:GetNamedChild("EqQuality")

            if slotDef.category == "jewelry" then
                eqType:SetText("")
            elseif slotDef.category == "armor" then
                eqType:SetText((info and info.armorType and WEIGHT_NAMES[info.armorType]) or "-")
            else
                eqType:SetText((info and info.weaponType and CompanionGearHunter.Data.WEAPON_TYPE_NAMES[info.weaponType]) or "-")
            end

            eqTrait:SetText((info and info.trait and GetString("SI_ITEMTRAITTYPE", info.trait)) or "-")

            if info and info.quality then
                eqQuality:SetText(GetString("SI_ITEMQUALITY", info.quality))
                eqQuality:SetColor(GetItemQualityColor(info.quality):UnpackRGBA())
            else
                eqQuality:SetText("-")
                eqQuality:SetColor(unpack(BLANK_TEXT_COLOR))
            end

            -- No auto-uncheck call here anymore - see ToggleWindow below for
            -- why it moved to window-close instead of running on every
            -- live edit.
            local wishlistEntry = selectedCompanionId and CompanionGearHunter.Data.GetWishlistEntry(selectedCompanionId, slotDef.key) or {}
            local isActive = wishlistEntry.enabled == true

            ZO_CheckButton_SetCheckState(row:GetNamedChild("WantEnabled"), isActive)

            for _, combo in ipairs({ rowInfo.wantType, rowInfo.wantTrait, rowInfo.wantQuality }) do
                combo:SetEnabled(isActive)
            end

            if isActive then
                SelectComboValue(rowInfo.wantType, wishlistEntry.subType)
                SelectComboValue(rowInfo.wantTrait, wishlistEntry.trait)
                SelectComboValue(rowInfo.wantQuality, wishlistEntry.qualityFloor)
            else
                -- Blank rather than left showing "Any" - an untouched row
                -- shouldn't visually read as if it's already wanting
                -- something - a wall of "Any" on every untouched row is confusing.
                rowInfo.wantType:SetSelectedItemText("")
                rowInfo.wantTrait:SetSelectedItemText("")
                rowInfo.wantQuality:SetSelectedItemText("")
            end

            -- Shared with FindWishlistMatches/AutoClearIfSatisfiedWishlist
            -- in CompanionGearHunter_Data.lua - all-Any never counts as
            -- satisfied here ("we REALLY alert on any/any/any conditions
            -- for that row" - "I want anything here" has no criteria that
            -- could ever be considered met on its own).
            local isSatisfied = CompanionGearHunter.Data.DoesInfoSatisfyWishlist(info, wishlistEntry)

            local stripe = row:GetNamedChild("Stripe")
            if isActive and not isSatisfied then
                stripe:SetCenterColor(unpack(ROW_HIGHLIGHT_COLOR))
            elseif i % 2 == 0 then
                stripe:SetCenterColor(unpack(ROW_STRIPE_COLOR))
            else
                stripe:SetCenterColor(unpack(ROW_CLEAR_COLOR))
            end
        end
    end

    RefreshCompanionDropdownLabels()
end

local function OnCompanionSelected(comboBoxControl, entryText, entry)
    selectedCompanionId = entry.companionId
    CompanionGearHunter.RefreshGrid()
end

local function PopulateCompanionDropdown()
    companionDropdown:ClearItems()
    companionEntries = {}

    -- Default to whichever companion is actually summoned right now (if
    -- any) on first open, same reasoning as CompanionRoster defaulting to
    -- the logged-in character - a manual pick made later this session is
    -- preserved instead of being reset every time the window reopens.
    local preferredId = selectedCompanionId or CompanionGearHunter.Data.GetActiveCompanionId()

    local firstEntry = nil
    local entryToSelect = nil

    for _, companion in ipairs(CompanionGearHunter.Data.GetAllCompanions()) do
        local entry = companionDropdown:CreateItemEntry(companion.name, OnCompanionSelected)
        entry.companionId = companion.id
        entry.baseName = companion.name
        companionEntries[companion.id] = entry
        companionDropdown:AddItem(entry)

        if firstEntry == nil then
            firstEntry = entry
        end
        if companion.id == preferredId then
            entryToSelect = entry
        end
    end

    if entryToSelect then
        selectedCompanionId = preferredId
        companionDropdown:SelectItem(entryToSelect, IGNORE_CALLBACKS)
    elseif firstEntry then
        selectedCompanionId = firstEntry.companionId
        companionDropdown:SelectItem(firstEntry, IGNORE_CALLBACKS)
    else
        selectedCompanionId = nil
    end
end

-- On the CompanionGearHunter table (not a separate bare global) because the
-- XML OnMoveStop handler calls this by name.
function CompanionGearHunter.OnWindowMoveStop(control)
    local _, point, _, relativePoint, offsetX, offsetY = control:GetAnchor(0)
    CompanionGearHunter.Data.SaveWindowPosition(point, relativePoint, offsetX, offsetY)
end

-- On the CompanionGearHunter table because both the slash command and (if a
-- keybind is ever added) Bindings.xml would call this by name.
function CompanionGearHunter.ToggleWindow()
    if CompanionGearHunterWindow:IsHidden() then
        PopulateCompanionDropdown()
        CompanionGearHunter.RefreshGrid()
        CompanionGearHunterWindow:SetHidden(false)
    else
        CompanionGearHunterWindow:SetHidden(true)

        -- Auto-uncheck "Find" for any row the equipped gear already
        -- satisfies, now that editing is done - deliberately run once on
        -- close rather than live on every dropdown change (see project/
        -- CLAUDE.md's "Non-obvious decisions" for why a live/debounced
        -- check kept firing mid-edit, before all 3 dropdowns were set).
        for _, companion in ipairs(CompanionGearHunter.Data.GetAllCompanions()) do
            for _, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
                CompanionGearHunter.Data.AutoClearIfSatisfiedWishlist(companion.id, slotDef.key)
            end
        end
    end
end

-- Every addon's EVENT_ADD_ON_LOADED fires before EVENT_PLAYER_ACTIVATED, so by
-- the time this runs (once, right after the first login/reloadui) every other
-- addon that's going to register a slash command already has. SLASH_COMMANDS
-- is the same real table LibSlashCommander reads from - if our own alias no
-- longer points at our own Command object there, something else claimed it
-- after us. Same approach as CompanionRoster's.
local function CheckSlashCommandHijack()
    EVENT_MANAGER:UnregisterForEvent("CompanionGearHunter_UI", EVENT_PLAYER_ACTIVATED)

    local currentCommand = CompanionGearHunter.Data.GetSlashCommand()
    local owner = SLASH_COMMANDS[zo_strlower(currentCommand)]
    if owner == CompanionGearHunter.slashCommand then
        return
    end

    local who = "another addon"
    if LibSlashCommander.IsCommand(owner) then
        local description = owner:GetDescription()
        if description then
            who = description
        end
    end

    d(string.format("|cFF0000!!!! WARNING !!!!|r Feliks' Companion Gear Hunter: %s has been taken over by %s and won't open this window anymore. Check Settings > Add-Ons > Feliks' Companion Gear Hunter to pick a different command.", currentCommand, who))
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionGearHunter.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionGearHunter_UI", EVENT_ADD_ON_LOADED)

    companionDropdown = ZO_ComboBox_ObjectFromContainer(CompanionGearHunterWindowCompanionDropdown)
    companionDropdown:SetSortsItems(false)

    for i, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
        local rowControl = _G["CompanionGearHunterWindowRow" .. i]

        ZO_CheckButton_SetToggleFunction(rowControl:GetNamedChild("WantEnabled"), CreateWantEnabledToggle(slotDef.key))

        local wantType = ZO_ComboBox_ObjectFromContainer(rowControl:GetNamedChild("WantType"))
        local wantTrait = ZO_ComboBox_ObjectFromContainer(rowControl:GetNamedChild("WantTrait"))
        local wantQuality = ZO_ComboBox_ObjectFromContainer(rowControl:GetNamedChild("WantQuality"))

        wantType:SetSortsItems(false)
        wantTrait:SetSortsItems(false)
        wantQuality:SetSortsItems(false)

        PopulateTypeCombo(wantType, slotDef)
        PopulateTraitCombo(wantTrait, slotDef)
        PopulateQualityCombo(wantQuality, slotDef)

        rows[i] = { control = rowControl, slotDef = slotDef, wantType = wantType, wantTrait = wantTrait, wantQuality = wantQuality }
    end

    local savedPosition = CompanionGearHunter.Data.GetWindowPosition()
    if savedPosition then
        CompanionGearHunterWindow:ClearAnchors()
        CompanionGearHunterWindow:SetAnchor(savedPosition.point, nil, savedPosition.relativePoint, savedPosition.offsetX, savedPosition.offsetY)
    end

    CompanionGearHunterWindowFooter:SetText("Feliks' Companion Gear Hunter - Version: " .. CompanionGearHunter.version)
    CompanionGearHunterWindowFooter:SetColor(unpack(BLANK_TEXT_COLOR))

    -- Same library CompanionRoster uses for its own /fcr command, so
    -- the slash command gets a real chat-autocomplete description instead of
    -- just being a bare, undocumented SLASH_COMMANDS entry.
    CompanionGearHunter.slashCommand = LibSlashCommander:Register(CompanionGearHunter.Data.GetSlashCommand(), CompanionGearHunter.ToggleWindow, "Feliks' Companion Gear Hunter")
    EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_UI", EVENT_PLAYER_ACTIVATED, CheckSlashCommandHijack)
end

EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_UI", EVENT_ADD_ON_LOADED, OnAddOnLoaded)

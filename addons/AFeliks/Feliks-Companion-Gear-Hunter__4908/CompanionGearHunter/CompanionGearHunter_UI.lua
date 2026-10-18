CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- (The display name for the keybind action declared in Bindings.xml, action
-- name COMPANIONGEARHUNTER_TOGGLE, is the string
-- SI_BINDING_NAME_COMPANIONGEARHUNTER_TOGGLE in lang/default.lua.)

local IGNORE_CALLBACKS = true

-- The addon's own ESOUI download page - opened when the footer is clicked.
local ESOUI_PAGE_URL = "https://www.esoui.com/downloads/info4908.html"
local FOOTER_HOVER_COLOR = { 0.6, 0.8, 1, 1 }

local companionDropdown = nil
local selectedCompanionId = nil
local currentCompanionRole = nil
local currentCompanionRoleSecondary = nil

-- companionId -> its dropdown entry, so labels can be updated in place.
local companionEntries = {}

-- Same engine constants CompanionRoster stores its Role tag as
-- (LFG_ROLE_TANK/_HEAL/_DPS), so a role read from there is directly usable
-- here with no translation.
-- Role names come from the game's own SI_LFGROLE strings (looked up by the
-- role value, as the game's tooltips do), so they are already translated.
local function GetRoleName(role)
    return GetString("SI_LFGROLE", role)
end

-- rows[i] = { control = <row control>, slotDef = <SLOTS entry>,
-- wantType/wantTrait/wantQuality = <ZO_ComboBox object> }
local rows = {}

-- Highlight color for a slot that's actively wanted (not all "Any") and not
-- yet satisfied by what's equipped - the same signal as a yellow-highlighted
-- row in a manual tracking spreadsheet.
local ROW_HIGHLIGHT_COLOR = { 1, 0.9, 0.3, 0.18 }
local ROW_STRIPE_COLOR = { 1, 1, 1, 0.06 }
local ROW_CLEAR_COLOR = { 0, 0, 0, 0 }

-- The Off-Hand row is dimmed by this much while it is closed (see RefreshGrid),
-- and offHandClosed (set there) tells the row label's tooltip whether to speak.
local CLOSED_ROW_ALPHA = 0.45
local offHandClosed = false

-- Invisible control laid over the Off-Hand Find checkbox. A disabled button may
-- not deliver mouse events, so this catches the hover instead; it is mouse-
-- enabled only while Off-Hand is closed (set in RefreshGrid), so it never
-- blocks the checkbox when it is usable.
local offHandCheckboxCover = nil
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
    local anyEntry = combo:CreateItemEntry(GetString(COMPANIONGEARHUNTER_ANY), OnWantTypeSelected)
    anyEntry.slotKey, anyEntry.matchValue = slotDef.key, nil
    combo:AddItem(anyEntry)

    local options
    if slotDef.category == CompanionGearHunter.Data.CATEGORY_ARMOR then
        options = CompanionGearHunter.Data.WEIGHT_OPTIONS
    elseif slotDef.category == CompanionGearHunter.Data.CATEGORY_WEAPON then
        options = CompanionGearHunter.Data.GetWeaponTypeOptions(slotDef.key)
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
    local anyEntry = combo:CreateItemEntry(GetString(COMPANIONGEARHUNTER_ANY), OnWantTraitSelected)
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
    local anyEntry = combo:CreateItemEntry(GetString(COMPANIONGEARHUNTER_ANY), OnWantQualitySelected)
    anyEntry.slotKey, anyEntry.matchValue = slotDef.key, nil
    combo:AddItem(anyEntry)

    for _, option in ipairs(CompanionGearHunter.Data.QUALITY_OPTIONS) do
        local entry = combo:CreateItemEntry(option.name, OnWantQualitySelected)
        entry.slotKey, entry.matchValue = slotDef.key, option.value
        combo:AddItem(entry)
    end
end

-- "All slots" row ---------------------------------------------------------
-- Three dropdowns that act as buttons: picking a value applies it to every
-- slot of the selected companion (see Data.ApplyToAllSlots), then the
-- dropdown goes back to blank so it never reads as stored state.

local allSlotsCombos = {}

local function BlankAllSlotsCombos()
    for _, combo in ipairs(allSlotsCombos) do
        combo:SetSelectedItemText("")
    end
end

local function OnAllSlotsSelected(comboBoxControl, entryText, entry)
    if selectedCompanionId == nil then
        return
    end
    CompanionGearHunter.Data.ApplyToAllSlots(selectedCompanionId, entry.field, entry.matchValue)
    CompanionGearHunter.RefreshGrid()
    -- Blanked again next frame in case the combo writes the picked text
    -- after calling back, which would undo the blanking RefreshGrid just did.
    zo_callLater(BlankAllSlotsCombos, 1)
end

-- options: list of { name =, value = }; "Any" is always added first.
local function PopulateAllSlotsCombo(combo, field, options)
    combo:SetSortsItems(false)
    combo:ClearItems()

    local anyEntry = combo:CreateItemEntry(GetString(COMPANIONGEARHUNTER_ANY), OnAllSlotsSelected)
    anyEntry.field, anyEntry.matchValue = field, nil
    combo:AddItem(anyEntry)

    for _, option in ipairs(options) do
        local entry = combo:CreateItemEntry(option.name, OnAllSlotsSelected)
        entry.field, entry.matchValue = field, option.value
        combo:AddItem(entry)
    end

    combo:SetSelectedItemText("")
    table.insert(allSlotsCombos, combo)
end

local function SetUpAllSlotsRow()
    local allRow = CompanionGearHunterWindowAllRow

    local traitOptions = {}
    for _, option in ipairs(CompanionGearHunter.Data.GetTraitSuffixOptions()) do
        table.insert(traitOptions, { name = option.name, value = option.suffix })
    end

    PopulateAllSlotsCombo(ZO_ComboBox_ObjectFromContainer(allRow:GetNamedChild("Type")), "subType", CompanionGearHunter.Data.WEIGHT_OPTIONS)
    PopulateAllSlotsCombo(ZO_ComboBox_ObjectFromContainer(allRow:GetNamedChild("Trait")), "trait", traitOptions)
    PopulateAllSlotsCombo(ZO_ComboBox_ObjectFromContainer(allRow:GetNamedChild("Quality")), "qualityFloor", CompanionGearHunter.Data.QUALITY_OPTIONS)
end

-- Clear button: wipes the selected companion's whole page, after a
-- confirmation - there is no undo.
local CLEAR_DIALOG = "COMPANIONGEARHUNTER_CLEAR_PAGE"

local function RegisterClearDialog()
    ZO_Dialogs_RegisterCustomDialog(CLEAR_DIALOG, {
        title = { text = COMPANIONGEARHUNTER_CLEAR_DIALOG_TITLE },
        mainText = { text = COMPANIONGEARHUNTER_CLEAR_DIALOG_TEXT },
        buttons = {
            {
                text = COMPANIONGEARHUNTER_CLEAR,
                callback = function(dialog)
                    CompanionGearHunter.Data.ClearCompanionWishlist(dialog.data.companionId)
                    CompanionGearHunter.RefreshGrid()
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

-- On the CompanionGearHunter table because the XML Clear button calls this
-- by name.
function CompanionGearHunter.OnClearClicked()
    if selectedCompanionId == nil then
        return
    end
    local entry = companionEntries[selectedCompanionId]
    ZO_Dialogs_ShowDialog(CLEAR_DIALOG, { companionId = selectedCompanionId }, { mainTextParams = { entry and entry.baseName or "" } })
end

-- On the CompanionGearHunter table (not a separate bare global) because the
-- XML OnMouseEnter handler on the Role texture's wrapper Control calls this
-- by name.
function CompanionGearHunter.OnCompanionRoleMouseEnter(control)
    if currentCompanionRole then
        local text = GetRoleName(currentCompanionRole)
        if currentCompanionRoleSecondary then
            text = text .. " + " .. GetRoleName(currentCompanionRoleSecondary)
        end
        ZO_Tooltips_ShowTextTooltip(control, TOP, text)
    end
end

-- CompanionRoster only exists as a global when that addon is actually
-- installed and loaded - guarding on it (and its Data table) is what makes
-- this integration optional rather than a hard dependency. An older
-- CompanionRoster has no second role (GetCompanionRoles), so it falls back
-- to the single-role getter and shows one icon.
local function RefreshCompanionRole()
    currentCompanionRole, currentCompanionRoleSecondary = nil, nil
    if CompanionRoster and CompanionRoster.Data and selectedCompanionId then
        if CompanionRoster.Data.GetCompanionRoles then
            currentCompanionRole, currentCompanionRoleSecondary = CompanionRoster.Data.GetCompanionRoles(selectedCompanionId)
        else
            currentCompanionRole = CompanionRoster.Data.GetCompanionRole(selectedCompanionId)
        end
    end

    local roleControl = CompanionGearHunterWindowCompanionRole
    local icon2 = roleControl:GetNamedChild("Icon2")
    if currentCompanionRole then
        roleControl:GetNamedChild("Icon"):SetTexture(ZO_GetRoleIcon(currentCompanionRole))
        if currentCompanionRoleSecondary then
            icon2:SetTexture(ZO_GetRoleIcon(currentCompanionRoleSecondary))
            icon2:SetHidden(false)
            roleControl:SetWidth(50)
        else
            icon2:SetHidden(true)
            roleControl:SetWidth(24)
        end
        roleControl:SetHidden(false)
    else
        roleControl:SetHidden(true)
    end
end

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
    BlankAllSlotsCombos()

    -- Same facts the matching/upgrade logic in CompanionGearHunter_Data.lua
    -- uses. The Off-Hand row is always shown, but it is only usable while the
    -- companion's effective Main Hand is one-handed (Data.IsOffHandAvailable:
    -- a one-handed type wanted on the Main Hand row, else what is equipped).
    -- While closed it is greyed out and unticked and its stored picks are
    -- ignored; its equipped columns read "-" while a two-hander is worn
    -- (GetCachedEquippedLink returns nothing for it).
    local twoHanded = selectedCompanionId and CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(selectedCompanionId)
    offHandClosed = selectedCompanionId ~= nil and not CompanionGearHunter.Data.IsOffHandAvailable(selectedCompanionId)
    if offHandCheckboxCover then
        offHandCheckboxCover:SetMouseEnabled(offHandClosed)
    end

    for i, rowInfo in ipairs(rows) do
        local row = rowInfo.control
        local slotDef = rowInfo.slotDef

        do
            row:SetHidden(false)

            local slotLabel = slotDef.label
            if slotDef.key == "MainHand" and twoHanded then
                slotLabel = GetString("SI_EQUIPTYPE", EQUIP_TYPE_TWO_HAND)
            end
            row:GetNamedChild("Slot"):SetText(slotLabel)

            local itemLink = selectedCompanionId and CompanionGearHunter.Data.GetCachedEquippedLink(selectedCompanionId, slotDef.key)
            local info = CompanionGearHunter.Data.DecodeItemLink(itemLink)

            local eqType = row:GetNamedChild("EqType")
            local eqTrait = row:GetNamedChild("EqTrait")
            local eqQuality = row:GetNamedChild("EqQuality")

            if slotDef.category == CompanionGearHunter.Data.CATEGORY_JEWELRY then
                eqType:SetText("")
            elseif slotDef.category == CompanionGearHunter.Data.CATEGORY_ARMOR then
                eqType:SetText((info and info.armorType and GetString("SI_ARMORTYPE", info.armorType)) or "-")
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
            local rowClosed = slotDef.key == "OffHand" and offHandClosed
            local isActive = wishlistEntry.enabled == true and not rowClosed

            local wantEnabledButton = row:GetNamedChild("WantEnabled")
            ZO_CheckButton_SetCheckState(wantEnabledButton, isActive)
            if rowClosed then
                ZO_CheckButton_Disable(wantEnabledButton)
            else
                ZO_CheckButton_Enable(wantEnabledButton)
            end
            row:SetAlpha(rowClosed and CLOSED_ROW_ALPHA or 1)

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

-- On the CompanionGearHunter table because the XML footer handlers call these
-- by name.
function CompanionGearHunter.OnFooterClicked()
    RequestOpenUnsafeURL(ESOUI_PAGE_URL)
end

function CompanionGearHunter.OnFooterMouseEnter(control)
    control:SetColor(unpack(FOOTER_HOVER_COLOR))
end

function CompanionGearHunter.OnFooterMouseExit(control)
    control:SetColor(unpack(BLANK_TEXT_COLOR))
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
-- the time this runs (once, from the first EVENT_PLAYER_ACTIVATED handled in
-- CompanionGearHunter.lua, right after the first login/reloadui) every other
-- addon that's going to register a slash command already has. SLASH_COMMANDS
-- is the same real table LibSlashCommander reads from - if our own alias no
-- longer points at our own Command object there, something else claimed it
-- after us. Same approach as CompanionRoster's.
function CompanionGearHunter.CheckSlashCommandHijack()
    local currentCommand = CompanionGearHunter.Data.GetSlashCommand()
    local owner = SLASH_COMMANDS[zo_strlower(currentCommand)]
    if owner == CompanionGearHunter.slashCommand then
        return
    end

    local who = GetString(COMPANIONGEARHUNTER_ANOTHER_ADDON)
    if LibSlashCommander.IsCommand(owner) then
        local description = owner:GetDescription()
        if description then
            who = description
        end
    end

    d(zo_strformat(COMPANIONGEARHUNTER_COMMAND_HIJACKED, currentCommand, who))
end

-- The window's headers and buttons take their text from the string table (set
-- here, once, rather than hardcoded in the XML, so they can be translated).
-- The window title is the addon's name and stays in the XML.
local function SetWindowTexts()
    local window = CompanionGearHunterWindow
    window:GetNamedChild("ColumnSlot"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_SLOT))
    window:GetNamedChild("ColumnEqType"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_TYPE))
    window:GetNamedChild("ColumnEqTrait"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_TRAIT))
    window:GetNamedChild("ColumnEqQuality"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_QUALITY))
    window:GetNamedChild("ColumnFind"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_FIND))
    window:GetNamedChild("ColumnWantType"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_TYPE))
    window:GetNamedChild("ColumnWantTrait"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_TRAIT))
    window:GetNamedChild("ColumnWantQuality"):SetText(GetString(COMPANIONGEARHUNTER_COLUMN_QUALITY_FLOOR))
    window:GetNamedChild("SettingsButton"):SetText(GetString(SI_GAME_MENU_SETTINGS))

    local allRow = window:GetNamedChild("AllRow")
    allRow:GetNamedChild("Label"):SetText(GetString(COMPANIONGEARHUNTER_ALL_SLOTS))
    allRow:GetNamedChild("Clear"):SetText(GetString(COMPANIONGEARHUNTER_CLEAR))
end

-- Builds the window: dropdowns, rows, All-slots row, dialog, position, footer.
-- Called once from the single EVENT_ADD_ON_LOADED handler in
-- CompanionGearHunter.lua, after the saved data is ready.
function CompanionGearHunter.BuildUI()
    SetWindowTexts()

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

        -- The Off-Hand row's name and its Find checkbox explain why it is
        -- greyed out, while it is.
        if slotDef.key == "OffHand" then
            local function ShowClosedTip(control)
                if offHandClosed then
                    ZO_Tooltips_ShowTextTooltip(control, TOP, GetString(COMPANIONGEARHUNTER_OFF_HAND_CLOSED_TIP))
                end
            end
            local function HideClosedTip()
                ZO_Tooltips_HideTextTooltip()
            end

            local slotLabel = rowControl:GetNamedChild("Slot")
            slotLabel:SetMouseEnabled(true)
            slotLabel:SetHandler("OnMouseEnter", ShowClosedTip)
            slotLabel:SetHandler("OnMouseExit", HideClosedTip)

            offHandCheckboxCover = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_CONTROL)
            offHandCheckboxCover:SetAnchorFill(rowControl:GetNamedChild("WantEnabled"))
            offHandCheckboxCover:SetMouseEnabled(false)
            offHandCheckboxCover:SetHandler("OnMouseEnter", ShowClosedTip)
            offHandCheckboxCover:SetHandler("OnMouseExit", HideClosedTip)
        end
    end

    SetUpAllSlotsRow()
    RegisterClearDialog()

    local savedPosition = CompanionGearHunter.Data.GetWindowPosition()
    if savedPosition then
        CompanionGearHunterWindow:ClearAnchors()
        CompanionGearHunterWindow:SetAnchor(savedPosition.point, nil, savedPosition.relativePoint, savedPosition.offsetX, savedPosition.offsetY)
    end

    CompanionGearHunterWindowFooter:SetText(zo_strformat(COMPANIONGEARHUNTER_FOOTER, CompanionGearHunter.version))
    CompanionGearHunterWindowFooter:SetColor(unpack(BLANK_TEXT_COLOR))
end

-- Same library CompanionRoster uses for its own /fcr command, so the slash
-- command gets a real chat-autocomplete description instead of just being a
-- bare, undocumented SLASH_COMMANDS entry.
function CompanionGearHunter.SetSlashCommands()
    CompanionGearHunter.slashCommand = LibSlashCommander:Register(CompanionGearHunter.Data.GetSlashCommand(), CompanionGearHunter.ToggleWindow, "Feliks' Companion Gear Hunter")
end

CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- Display name for the keybind action declared in Bindings.xml (action name
-- COMPANIONROSTER_TOGGLE). Must run before the Keybindings menu is ever
-- opened, so top-level code here is fine.
ZO_CreateStringId("SI_BINDING_NAME_COMPANIONROSTER_TOGGLE", "Toggle Feliks' Companion Roster")

-- Number of pre-created row controls (CompanionRosterWindowRow1..N in the
-- XML) - a display ceiling, not a data limit. CompanionRoster.Data.GetAllCompanions()
-- discovers however many companions actually exist live; if that count ever
-- exceeds this, the extras simply won't have a row to show in. Bump this,
-- add one more RowN to the XML, and grow the window's height by one row
-- (26px) if that happens.
local MAX_COMPANION_ROWS = 8

local characterDropdown = nil
local selectedCharacterKey = nil

-- Matches the gaps/widths hardcoded in CompanionRoster_Window.xml's row
-- template - kept here too because the spanned-state math below needs them.
local GAP_COMPANION_ROLE = 4
local ROLE_WIDTH = 20
local GAP_ROLE_LEVEL = 4
local LEVEL_WIDTH = 55
local GAP_LEVEL_RAPPORT = 2

-- How wide the Rapport label needs to be to span the (blank) Role and Level
-- columns too when it's showing a status message instead of real data (see
-- SetRowBlank), since both are blank in that case anyway.
local RAPPORT_NORMAL_WIDTH = 90
local RAPPORT_SPANNED_WIDTH = ROLE_WIDTH + GAP_ROLE_LEVEL + LEVEL_WIDTH + GAP_LEVEL_RAPPORT + RAPPORT_NORMAL_WIDTH

-- The addon's own ESOUI download page - opened when the footer is clicked.
local ESOUI_PAGE_URL = "https://www.esoui.com/downloads/info4862.html"
local FOOTER_COLOR = { 0.6, 0.6, 0.6, 1 }
local FOOTER_HOVER_COLOR = { 0.6, 0.8, 1, 1 }

-- LFG_ROLE_TANK/LFG_ROLE_HEAL/LFG_ROLE_DPS are the same engine constants
-- the game's own Group Finder uses - reusing them (rather than inventing
-- our own enum) means ZO_GetRoleIcon below already knows how to draw them.
local ROLE_NAMES = {
    [LFG_ROLE_TANK] = "Tank",
    [LFG_ROLE_HEAL] = "Healer",
    [LFG_ROLE_DPS] = "DPS",
}

-- Shown faded in the Role slot when no role is set yet - a real texture
-- rather than an empty one, since an untextured Texture control renders as
-- a plain white box instead of nothing.
local ROLE_HINT_ICON = "EsoUI/Art/Miscellaneous/icon_RMB.dds"
local ROLE_HINT_ALPHA = 0.35

local function SetRowBlank(row)
    row.hasInfo = false
    row.rapportLevelText = nil
    row.passivePerkName = nil
    row.passivePerkDescription = nil
    row.skillLines = nil

    row:GetNamedChild("Level"):SetText("")

    local rapport = row:GetNamedChild("Rapport")
    if not row.isOwned then
        rapport:SetText("Not Owned")
    elseif row.canSummon == false then
        rapport:SetText("Quest Not Done")
    else
        rapport:SetText("No Info")
    end
    rapport:SetColor(0.7, 0.7, 0.7, 1)

    -- These status messages are too wide for the Rapport column alone to
    -- fit on one line - span it across the (blank) Level column too
    -- instead of wrapping and overflowing into the row below.
    rapport:SetWidth(RAPPORT_SPANNED_WIDTH)
    rapport:ClearAnchors()
    rapport:SetAnchor(LEFT, row:GetNamedChild("Companion"), RIGHT, GAP_COMPANION_ROLE)
end

local function SetRowData(row, info)
    row.hasInfo = true
    row.rapportLevelText = info.rapportLevelText
    row.passivePerkName = info.passivePerkName
    row.passivePerkDescription = info.passivePerkDescription
    row.skillLines = info.skillLines

    row:GetNamedChild("Level"):SetText(info.level and ("Lv." .. info.level) or "Lv.?")

    local rapport = row:GetNamedChild("Rapport")
    rapport:SetText(info.rapportValue .. "/" .. info.rapportMax)
    if info.rapportValue >= info.rapportMax then
        rapport:SetColor(0.4, 1, 0.4, 1)
    else
        rapport:SetColor(1, 0.8, 0.4, 1)
    end

    -- Back to its normal position/width, in case a previous refresh had it
    -- spanned across the Level column (see SetRowBlank).
    rapport:SetWidth(RAPPORT_NORMAL_WIDTH)
    rapport:ClearAnchors()
    rapport:SetAnchor(LEFT, row:GetNamedChild("Level"), RIGHT, GAP_LEVEL_RAPPORT)
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Rapport label calls this by name.
function CompanionRoster.OnRapportMouseEnter(control)
    local row = control:GetParent()
    if row.hasInfo == false then
        if not row.isOwned then
            ZO_Tooltips_ShowTextTooltip(control, TOP, "You don't own this companion yet.")
        elseif row.canSummon == false then
            ZO_Tooltips_ShowTextTooltip(control, TOP, "You haven't completed this companion's recruitment quest on this character yet.")
        else
            ZO_Tooltips_ShowTextTooltip(control, TOP, "Rapport data will be recorded when this companion is summoned.")
        end
    elseif row.rapportLevelText then
        ZO_Tooltips_ShowTextTooltip(control, TOP, row.rapportLevelText)
    end
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Companion label calls this by name.
function CompanionRoster.OnCompanionMouseEnter(control)
    local row = control:GetParent()
    if row.passivePerkName == nil then
        return
    end

    local nameLine = row.passivePerkName
    if row.keepsakeUnlocked then
        nameLine = nameLine .. " |c66FF66- Unlocked|r"
    end

    ZO_Tooltips_ShowTextTooltip(control, TOP, nameLine .. "\n" .. row.passivePerkDescription)
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Level label calls this by name. Shows skill
-- line names + current rank grouped by type (Class/Weapon/Armor/Guild).
function CompanionRoster.OnLevelMouseEnter(control)
    local row = control:GetParent()
    if row.skillLines == nil then
        -- Blank Level cell (not owned / quest not done) - nothing useful to say.
        if row.hasInfo == false and (not row.isOwned or row.canSummon == false) then
            return
        end
        ZO_Tooltips_ShowTextTooltip(control, TOP, "Skill data will be recorded when this companion is summoned.")
        return
    end

    local lines = {}
    for _, group in ipairs(row.skillLines) do
        table.insert(lines, group.typeName .. ":")
        for _, skillLine in ipairs(group.lines) do
            table.insert(lines, skillLine.name .. ": " .. skillLine.rank)
        end
        table.insert(lines, "")
    end
    table.remove(lines) -- drop the trailing blank line between groups

    ZO_Tooltips_ShowTextTooltip(control, TOP, table.concat(lines, "\n"))
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Role texture calls this by name.
function CompanionRoster.OnRoleMouseEnter(control)
    local row = control:GetParent()
    local roleName = row.role and ROLE_NAMES[row.role]
    ZO_Tooltips_ShowTextTooltip(control, TOP, roleName or "Right-click to tag this companion's role (Tank/Healer/DPS).")
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseUp handler on the Role texture calls this by name. Purely a manual
-- label - there's no API to detect a companion's build from gear or slotted
-- skills, so this is the player's own tag, not derived data.
function CompanionRoster.OnRoleMouseUp(control)
    local row = control:GetParent()
    local companionId = row.companionId

    local function SetRoleAndRefresh(role)
        CompanionRoster.Data.SetCompanionRole(companionId, role)
        CompanionRoster.RefreshGrid()
    end

    ClearMenu()
    AddMenuItem(zo_iconFormat(ZO_GetRoleIcon(LFG_ROLE_TANK), 16, 16) .. " Tank", function() SetRoleAndRefresh(LFG_ROLE_TANK) end)
    AddMenuItem(zo_iconFormat(ZO_GetRoleIcon(LFG_ROLE_HEAL), 16, 16) .. " Healer", function() SetRoleAndRefresh(LFG_ROLE_HEAL) end)
    AddMenuItem(zo_iconFormat(ZO_GetRoleIcon(LFG_ROLE_DPS), 16, 16) .. " DPS", function() SetRoleAndRefresh(LFG_ROLE_DPS) end)
    AddMenuItem("Clear Role", function() SetRoleAndRefresh(nil) end)
    ShowMenu(control)
end

function CompanionRoster.RefreshGrid()
    local companions = CompanionRoster.Data.GetAllCompanions()
    local companionsForCharacter = selectedCharacterKey and CompanionRoster.Data.GetCompanionsForCharacter(selectedCharacterKey) or {}

    for i = 1, MAX_COMPANION_ROWS do
        local row = _G["CompanionRosterWindowRow" .. i]
        local companion = companions[i]

        if companion == nil then
            row:SetHidden(true)
        else
            row:SetHidden(false)
            row.companionId = companion.id
            row.keepsakeUnlocked = CompanionRoster.Data.IsKeepsakeUnlocked(companion.name)
            row.isOwned = CompanionRoster.Data.IsCompanionOwned(companion.id)
            row.canSummon = selectedCharacterKey and CompanionRoster.Data.CanSummonCompanion(selectedCharacterKey, companion.id)

            row.role = CompanionRoster.Data.GetCompanionRole(companion.id)
            local roleTexture = row:GetNamedChild("Role"):GetNamedChild("Icon")
            if row.role then
                roleTexture:SetTexture(ZO_GetRoleIcon(row.role))
                roleTexture:SetAlpha(1)
            else
                roleTexture:SetTexture(ROLE_HINT_ICON)
                roleTexture:SetAlpha(ROLE_HINT_ALPHA)
            end

            local companionLabel = row:GetNamedChild("Companion")
            companionLabel:SetText(companion.name)
            if row.keepsakeUnlocked then
                companionLabel:SetColor(0.4, 1, 0.4, 1)
            else
                companionLabel:SetColor(1, 1, 1, 1)
            end

            if i % 2 == 0 then
                row:GetNamedChild("Stripe"):SetCenterColor(1, 1, 1, 0.13)
            else
                row:GetNamedChild("Stripe"):SetCenterColor(0, 0, 0, 0)
            end

            local info = companionsForCharacter[companion.id]
            if info then
                SetRowData(row, info)
            else
                SetRowBlank(row)
            end

            if row.passivePerkName == nil then
                row.passivePerkName, row.passivePerkDescription = CompanionRoster.Data.GetPassivePerkInfo(companion.id)
            end

            if row.skillLines == nil then
                row.skillLines = CompanionRoster.Data.GetSkillLinesForCompanion(companion.id)
            end
        end
    end
end

local function OnCharacterSelected(comboBoxControl, entryText, entry)
    selectedCharacterKey = entry.characterKey
    CompanionRoster.RefreshGrid()
end

local function PopulateDropdown()
    characterDropdown:ClearItems()

    -- On first open since a reload, default to whichever character is
    -- actually logged in right now, not just whoever sorts first
    -- alphabetically. A manual pick made later this session (selectedCharacterKey
    -- already set) is preserved rather than reset every time the window reopens.
    local preferredKey = selectedCharacterKey or CompanionRoster.Data.GetCurrentCharacterName()

    local firstEntry = nil
    local entryToSelect = nil

    for _, characterKey in ipairs(CompanionRoster.Data.GetCharacterNames()) do
        local entry = characterDropdown:CreateItemEntry(characterKey, OnCharacterSelected)
        entry.characterKey = characterKey
        characterDropdown:AddItem(entry)

        if firstEntry == nil then
            firstEntry = entry
        end
        if characterKey == preferredKey then
            entryToSelect = entry
        end
    end

    local IGNORE_CALLBACKS = true
    if entryToSelect then
        selectedCharacterKey = preferredKey
        characterDropdown:SelectItem(entryToSelect, IGNORE_CALLBACKS)
    elseif firstEntry then
        selectedCharacterKey = firstEntry.characterKey
        characterDropdown:SelectItem(firstEntry, IGNORE_CALLBACKS)
    else
        selectedCharacterKey = nil
    end
end

-- On the CompanionRoster table (not a separate bare global) because the
-- XML OnMouseUp/OnMouseEnter/OnMouseExit handlers on the Footer label call
-- these by name.
function CompanionRoster.OnFooterClicked()
    RequestOpenUnsafeURL(ESOUI_PAGE_URL)
end

function CompanionRoster.OnFooterMouseEnter(control)
    control:SetColor(unpack(FOOTER_HOVER_COLOR))
end

function CompanionRoster.OnFooterMouseExit(control)
    control:SetColor(unpack(FOOTER_COLOR))
end

-- On the CompanionRoster table (not a separate bare global) because the
-- XML OnMoveStop handler calls this by name.
function CompanionRoster.OnWindowMoveStop(control)
    local _, point, _, relativePoint, offsetX, offsetY = control:GetAnchor(0)
    CompanionRoster.Data.SaveWindowPosition(point, relativePoint, offsetX, offsetY)
end

-- On the CompanionRoster table (not a separate bare global) because both
-- the <Down> handler in Bindings.xml and the /fcr slash command call this
-- by name.
function CompanionRoster.ToggleWindow()
    if CompanionRosterWindow:IsHidden() then
        PopulateDropdown()
        CompanionRoster.RefreshGrid()
        CompanionRosterWindow:SetHidden(false)
    else
        CompanionRosterWindow:SetHidden(true)
    end
end

-- Every addon's EVENT_ADD_ON_LOADED fires during the loading screen, before
-- EVENT_PLAYER_ACTIVATED - so by the time this runs (once, right after the
-- first login/reloadui this session), every other addon that's going to
-- register a slash command already has. SLASH_COMMANDS is the same real
-- table LibSlashCommander itself reads from (see the collision check in
-- CompanionRoster_Settings.lua) - if our own alias no longer points at our
-- own Command object there, something else claimed it after us.
local function CheckSlashCommandHijack()
    EVENT_MANAGER:UnregisterForEvent("CompanionRoster_UI", EVENT_PLAYER_ACTIVATED)

    local currentCommand = CompanionRoster.Data.GetSlashCommand()
    local owner = SLASH_COMMANDS[zo_strlower(currentCommand)]
    if owner == CompanionRoster.slashCommand then
        return
    end

    local who = "another addon"
    if LibSlashCommander.IsCommand(owner) then
        local description = owner:GetDescription()
        if description then
            who = description
        end
    end

    d(string.format("|cFF0000!!!! WARNING !!!!|r Feliks' Companion Roster: %s has been taken over by %s and won't open this window anymore. Check Settings > Add-Ons > Feliks' Companion Roster to pick a different command.", currentCommand, who))
end

-- Real event, confirmed against the client source (EVENT_PLAYER_COMBAT_STATE
-- fires with an inCombat boolean - dozens of built-in ESO UI elements, e.g.
-- the combat overlay and buff/debuff trackers, already hide/show off this
-- exact event). Only closes the window, never opens it, and only when
-- opted in via the settings panel (off by default).
local function OnPlayerCombatState(eventCode, inCombat)
    if inCombat and CompanionRoster.Data.GetCloseOnCombat() and not CompanionRosterWindow:IsHidden() then
        CompanionRosterWindow:SetHidden(true)
    end
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionRoster.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionRoster_UI", EVENT_ADD_ON_LOADED)

    characterDropdown = ZO_ComboBox_ObjectFromContainer(CompanionRosterWindowCharacterDropdown)
    characterDropdown:SetSortsItems(false)

    local savedPosition = CompanionRoster.Data.GetWindowPosition()
    if savedPosition then
        CompanionRosterWindow:ClearAnchors()
        CompanionRosterWindow:SetAnchor(savedPosition.point, nil, savedPosition.relativePoint, savedPosition.offsetX, savedPosition.offsetY)
    end

    CompanionRosterWindowFooter:SetText("Feliks' Companion Roster - Version: " .. CompanionRoster.version)
    CompanionRosterWindowFooter:SetColor(unpack(FOOTER_COLOR))

    CompanionRoster.slashCommand = LibSlashCommander:Register(CompanionRoster.Data.GetSlashCommand(), CompanionRoster.ToggleWindow, "Feliks' Companion Roster")
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_UI", EVENT_PLAYER_ACTIVATED, CheckSlashCommandHijack)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_UI", EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
end

EVENT_MANAGER:RegisterForEvent("CompanionRoster_UI", EVENT_ADD_ON_LOADED, OnAddOnLoaded)

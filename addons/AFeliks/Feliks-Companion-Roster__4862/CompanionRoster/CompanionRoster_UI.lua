CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups
CompanionRoster.UI = {}

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
-- The Role column is 34 wide so it can hold two small icons for a hybrid
-- (16 + 2 + 16); the Companion name label was narrowed by the same 14 so
-- Level and Rapport stay exactly where they were.
local GAP_COMPANION_ROLE = 4
local ROLE_WIDTH = 34
local GAP_ROLE_LEVEL = 4
local LEVEL_WIDTH = 55
local GAP_LEVEL_RAPPORT = 2

-- How wide the Rapport label needs to be to span the (blank) Role and Level
-- columns too when it's showing a status message instead of real data (see
-- SetRowBlank), since both are blank in that case anyway.
local RAPPORT_NORMAL_WIDTH = 90
local RAPPORT_SPANNED_WIDTH = ROLE_WIDTH + GAP_ROLE_LEVEL + LEVEL_WIDTH + GAP_LEVEL_RAPPORT + RAPPORT_NORMAL_WIDTH

-- Widths set in CompanionRoster_Window.xml. The window is widened from these
-- when a name or a status message is longer than they allow (see
-- FitWindowToText), never narrowed below them.
local BASE_NAME_WIDTH = 136
local BASE_HEADER_WIDTH = 150
local BASE_ROW_WIDTH = 350
local BASE_WINDOW_WIDTH = 360
local MAX_EXTRA_WIDTH = 120 -- per kind of text, so one huge string can't make the window absurd
local MEASURE_PADDING = 6

-- Width of the blank-state status text; grows with FitWindowToText.
local rapportSpannedWidth = RAPPORT_SPANNED_WIDTH

-- The addon's own ESOUI download page - opened when the footer is clicked.
local ESOUI_PAGE_URL = "https://www.esoui.com/downloads/info4862.html"
local FOOTER_COLOR = { 0.6, 0.6, 0.6, 1 }
local FOOTER_HOVER_COLOR = { 0.6, 0.8, 1, 1 }

-- Every chat message from this addon starts with its name. Takes a string ID
-- (lang/default.lua) and its <<1>>, <<2>> values. Public so the HUD file prints
-- the same way.
local function Say(stringId, ...)
    d(CompanionRoster.title .. ": " .. zo_strformat(stringId, ...))
end
CompanionRoster.Say = Say

local function Trim(text)
    return (text:match("^%s*(.-)%s*$"))
end

-- A typed name matched more than one companion: list them instead of guessing.
local function SayAmbiguousMatch(term, matches)
    local names = {}
    for _, match in ipairs(matches) do
        table.insert(names, match.name)
    end
    Say(COMPANIONROSTER_SAY_AMBIGUOUS, term, table.concat(names, ", "))
end

-- Role icon sizes: one role is drawn at the full 20px, a hybrid as two 16px
-- icons side by side in the same column. Role names/choices live in
-- CompanionRoster.Data (GetRoleLabel, ROLE_CHOICES) so the menu, the settings
-- panel and this window can't drift apart.
local ROLE_ICON_SIZE_SINGLE = 20
local ROLE_ICON_SIZE_HYBRID = 16

-- Shown faded in the Role slot when no role is set yet - a real texture
-- rather than an empty one, since an untextured Texture control renders as
-- a plain white box instead of nothing.
local ROLE_HINT_ICON = "EsoUI/Art/Miscellaneous/icon_RMB.dds"
local ROLE_HINT_ALPHA = 0.35

local function SetRowBlank(row)
    row.hasInfo = false
    row.rapportLevelText = nil

    row:GetNamedChild("Level"):SetText("")

    local rapport = row:GetNamedChild("Rapport")
    if not row.isOwned then
        rapport:SetText(GetString(COMPANIONROSTER_STATUS_NOT_OWNED))
    elseif row.canSummon == false then
        rapport:SetText(GetString(COMPANIONROSTER_STATUS_QUEST_NOT_DONE))
    else
        rapport:SetText(GetString(COMPANIONROSTER_STATUS_NO_INFO))
    end
    rapport:SetColor(0.7, 0.7, 0.7, 1)

    -- These status messages are too wide for the Rapport column alone to
    -- fit on one line - span it across the (blank) Level column too
    -- instead of wrapping and overflowing into the row below.
    rapport:SetWidth(rapportSpannedWidth)
    rapport:ClearAnchors()
    rapport:SetAnchor(LEFT, row:GetNamedChild("Companion"), RIGHT, GAP_COMPANION_ROLE)
end

local function SetRowData(row, info)
    row.hasInfo = true
    row.rapportLevelText = info.rapportLevelText

    row:GetNamedChild("Level"):SetText(info.level and zo_strformat(COMPANIONROSTER_LEVEL_CELL, info.level) or GetString(COMPANIONROSTER_LEVEL_UNKNOWN))

    local rapport = row:GetNamedChild("Rapport")
    rapport:SetText(info.rapportValue .. "/" .. info.rapportMax)
    local r, g, b = CompanionRoster.Data.GetColor(info.rapportValue >= info.rapportMax and "done" or "inProgress")
    rapport:SetColor(r, g, b, 1)

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
    local text
    if row.hasInfo == false then
        if not row.isOwned then
            text = GetString(COMPANIONROSTER_TIP_NOT_OWNED)
        elseif row.canSummon == false then
            text = GetString(COMPANIONROSTER_TIP_QUEST_NOT_DONE)
        else
            text = GetString(COMPANIONROSTER_TIP_NO_RAPPORT_DATA)
        end
    else
        text = row.rapportLevelText
    end

    local hint = "|c999999" .. GetString(COMPANIONROSTER_TIP_CLICK_RAPPORT) .. "|r"
    ZO_Tooltips_ShowTextTooltip(control, TOP, text and (text .. "\n" .. hint) or hint)
end

-- Same popup as the chat command's "c <name>". Rapport tips are static data,
-- so this works on every row, including ones with no recorded rapport yet.
-- On the CompanionRoster table because the XML OnMouseUp handler calls it.
function CompanionRoster.OnRapportMouseUp(control)
    local companionId = control:GetParent().companionId
    local companionName = companionId and CompanionRoster.Data.GetCompanionNameById(companionId)
    if companionName then
        CompanionRoster.RunCompanionLookup(companionName)
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
        nameLine = nameLine .. " |c66FF66" .. GetString(COMPANIONROSTER_TIP_UNLOCKED) .. "|r"
    end

    ZO_Tooltips_ShowTextTooltip(control, TOP, nameLine .. "\n" .. row.passivePerkDescription .. "\n|c999999" .. GetString(COMPANIONROSTER_TIP_CLICK_SUMMON) .. "|r")
end

-- The one set of summon rules, shared by clicking a name in the roster and
-- typing a name after the chat command. A summon only ever happens from one
-- of those direct actions. Does nothing for a companion who's already out,
-- since UseCollectible would toggle (dismiss) them. `canSummon` false means
-- known-unavailable; nil (never recorded) is left to the game to decide.
local function TrySummonCompanion(companionId, companionName, canSummon)
    if canSummon == false then
        Say(COMPANIONROSTER_SAY_CANT_SUMMON_YET, companionName)
        return
    end

    local collectibleId = GetCompanionCollectibleId(companionId)
    if IsCollectibleActive(collectibleId) then
        return
    end
    if IsCollectibleBlocked(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) then
        local reason = GetCollectibleBlockReason(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        Say(COMPANIONROSTER_SAY_CANT_SUMMON_REASON, companionName, zo_strformat(GetString("SI_COLLECTIBLEUSAGEBLOCKREASON", reason)))
        return
    end

    UseCollectible(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseUp handler on the Companion label calls this by name.
function CompanionRoster.OnCompanionMouseUp(control)
    local row = control:GetParent()
    local companionName = control:GetText()

    if selectedCharacterKey ~= CompanionRoster.Data.GetCurrentCharacterName() then
        Say(COMPANIONROSTER_SAY_SWITCH_CHARACTER, companionName)
        return
    end

    TrySummonCompanion(row.companionId, companionName, row.canSummon)
end

-- "<command> <name>" - summons the companion whose name matches (partial,
-- case-insensitive, so "zer" finds Zerith-var), under the same rules as
-- clicking their name. An exact name match wins outright; two or more
-- partial matches list the candidates instead of guessing.
function CompanionRoster.SummonCompanionByName(term)
    local lowerTerm = zo_strlower(term)

    local matches = {}
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        local lowerName = zo_strlower(companion.name)
        if lowerName == lowerTerm then
            matches = { companion }
            break
        end
        if lowerName:find(lowerTerm, 1, true) then
            table.insert(matches, companion)
        end
    end

    if #matches == 0 then
        Say(COMPANIONROSTER_SAY_NO_COMPANION, term)
        return
    end
    if #matches > 1 then
        SayAmbiguousMatch(term, matches)
        return
    end

    local companion = matches[1]
    local canSummon = CompanionRoster.Data.CanSummonCompanion(CompanionRoster.Data.GetCurrentCharacterName(), companion.id)
    TrySummonCompanion(companion.id, companion.name, canSummon)
end

-- The game's tooltip wraps at roughly 40 characters of normal text and breaks
-- inside names ("One Hand and / Shield"), so each group is packed into lines no
-- longer than this many visible characters, breaking only after a comma. Lower
-- it if a line still wraps; raise it if lines break too early.
local LEVEL_TIP_LINE_CHARS = 40
local NBSP = "\194\160"
local LEVEL_TIP_INDENT = NBSP .. NBSP -- continuation lines of a group

-- Length of a string as drawn (color codes take no room, a no-break space is one).
local function VisibleLength(text)
    return #(text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(NBSP, " "))
end

-- One group as tooltip lines: a yellow "Label:" followed by the items on the
-- same line, wrapping after a comma (never inside a name) onto indented lines:
-- "Guild: Fighters 2, Mages 7" / "Weapon: Destruction 20," + "  Restoration 4".
local function BuildGroupLines(label, items)
    local lines = {}
    -- The label color is the configurable "tooltipLabel" color (yellow by default).
    local current = string.format("|c%s%s|r", CompanionRoster.Data.GetColorHex("tooltipLabel"), zo_strformat(COMPANIONROSTER_LEVEL_TIP_LABEL, label))
    local firstOnLine = true
    for _, item in ipairs(items) do
        if firstOnLine then
            current = current .. " " .. item
            firstOnLine = false
        elseif VisibleLength(current .. ", " .. item) > LEVEL_TIP_LINE_CHARS then
            table.insert(lines, current .. ",")
            current = LEVEL_TIP_INDENT .. item
        else
            current = current .. ", " .. item
        end
    end
    table.insert(lines, current)
    return lines
end

-- The items shown for one skill type group, e.g. { "One Hand and Shield 20",
-- "Dual Wield 19", "Bow 3" }. A maxed rank is drawn in the Done color instead
-- of a "(Maxed)" tag, and a group whose lines are all maxed at the same rank
-- collapses to one item, "all maxed (N)". Words the group label already says
-- (Guild, Armor, Staff) are dropped from the names. Class/Weapon/Armor skills
-- still at rank 1 are left out and returned as the second result (full names,
-- for the tooltip's "Untrained" line); Guild lines are always listed, since
-- rank 1 there means no quests done yet, which is useful to see. The first
-- result is empty when nothing in the group is worth listing.
local function FormatSkillGroup(group)
    local isGuild = CompanionRoster.Data.IsGuildSkillGroup(group)
    local doneHex = CompanionRoster.Data.GetColorHex("done")

    local listed, untrained = {}, {}
    for _, skillLine in ipairs(group.lines) do
        if not isGuild and skillLine.rank <= 1 and not skillLine.isMaxed then
            table.insert(untrained, skillLine.name)
        else
            table.insert(listed, skillLine)
        end
    end
    if #listed == 0 then
        return {}, untrained
    end

    local allMaxedAtOneRank = true
    for _, skillLine in ipairs(listed) do
        if not skillLine.isMaxed or skillLine.rank ~= listed[1].rank then
            allMaxedAtOneRank = false
            break
        end
    end
    if allMaxedAtOneRank then
        return { string.format("|c%s%s|r", doneHex, zo_strformat(COMPANIONROSTER_LEVEL_TIP_ALL_MAXED, listed[1].rank)) }, untrained
    end

    local items = {}
    for _, skillLine in ipairs(listed) do
        local name = skillLine.name:gsub(" Guild$", ""):gsub(" Armor$", ""):gsub(" Staff$", "")
        local rankText = tostring(skillLine.rank)
        if skillLine.isMaxed then
            rankText = string.format("|c%s%s|r", doneHex, rankText)
        end
        table.insert(items, name .. " " .. rankText)
    end
    return items, untrained
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Level label calls this by name. Each skill type
-- (Guild first, then Class/Weapon/Armor) is one "Label: items" line in a plain
-- text tooltip (wrapping after commas, see BuildGroupLines), with the never-used
-- rank 1 skills together on a last "Untrained:" line. Hal rejected a version
-- with bold headings on their own lines (one AddLine per line spaces them far
-- apart and a tooltip can't mix bold inside a line) - a single text block keeps
-- the lines tight.
function CompanionRoster.OnLevelMouseEnter(control)
    local row = control:GetParent()
    if row.skillLines == nil then
        -- Blank Level cell (not owned / quest not done) - nothing useful to say.
        if row.hasInfo == false and (not row.isOwned or row.canSummon == false) then
            return
        end
        ZO_Tooltips_ShowTextTooltip(control, TOP, GetString(COMPANIONROSTER_TIP_NO_SKILL_DATA))
        return
    end

    local lines, untrained = {}, {}
    for pass = 1, 2 do -- pass 1 = the Guild group, pass 2 = the others
        for _, group in ipairs(row.skillLines) do
            if CompanionRoster.Data.IsGuildSkillGroup(group) == (pass == 1) then
                local items, rankOne = FormatSkillGroup(group)
                if #items > 0 then
                    -- The game's current name for the type; typeName was recorded
                    -- in whatever language the client had at the time.
                    local typeName = group.skillType and GetString("SI_SKILLTYPE", group.skillType) or group.typeName
                    for _, text in ipairs(BuildGroupLines(typeName, items)) do
                        table.insert(lines, text)
                    end
                end
                for _, name in ipairs(rankOne) do
                    table.insert(untrained, name)
                end
            end
        end
    end
    if #untrained > 0 then
        for _, text in ipairs(BuildGroupLines(GetString(COMPANIONROSTER_LEVEL_TIP_UNTRAINED), untrained)) do
            table.insert(lines, text)
        end
    end
    if #lines == 0 then
        return
    end

    ZO_Tooltips_ShowTextTooltip(control, TOP, table.concat(lines, "\n"))
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on the Role control calls this by name.
function CompanionRoster.OnRoleMouseEnter(control)
    local row = control:GetParent()
    local roleName = row.role and CompanionRoster.Data.GetRoleLabel(row.role, row.roleSecondary)
    ZO_Tooltips_ShowTextTooltip(control, TOP, roleName or GetString(COMPANIONROSTER_TIP_ROLE_HINT))
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseUp handler on the Role control calls this by name. Purely a manual
-- label - there's no API to detect a companion's build from gear or slotted
-- skills, so this is the player's own tag, not derived data.
function CompanionRoster.OnRoleMouseUp(control)
    local row = control:GetParent()
    local companionId = row.companionId

    local function SetRolesAndRefresh(primary, secondary)
        CompanionRoster.Data.SetCompanionRoles(companionId, primary, secondary)
        CompanionRoster.RefreshGrid()
    end

    ClearMenu()
    for _, choice in ipairs(CompanionRoster.Data.ROLE_CHOICES) do
        local label = zo_iconFormat(ZO_GetRoleIcon(choice.primary), 16, 16)
        if choice.secondary ~= nil then
            label = label .. zo_iconFormat(ZO_GetRoleIcon(choice.secondary), 16, 16)
        end
        label = label .. " " .. CompanionRoster.Data.GetRoleLabel(choice.primary, choice.secondary)
        AddMenuItem(label, function() SetRolesAndRefresh(choice.primary, choice.secondary) end)
    end
    AddMenuItem(GetString(COMPANIONROSTER_ROLE_CLEAR), function() SetRolesAndRefresh(nil, nil) end)
    ShowMenu(control)
end

-- Width of a string as the roster's text font draws it, measured on an
-- invisible label with no width limit.
local measureLabel = nil

local function MeasureTextWidth(text)
    if measureLabel == nil then
        measureLabel = WINDOW_MANAGER:CreateControl(nil, CompanionRosterWindow, CT_LABEL)
        measureLabel:SetFont("ZoFontWinH5")
        measureLabel:SetAlpha(0)
    end
    measureLabel:SetText(text)
    return measureLabel:GetTextWidth()
end

-- Extra width needed for a text of this width in a space of `available`.
local function ExtraWidthFor(textWidth, available)
    return zo_max(0, zo_min(MAX_EXTRA_WIDTH, zo_ceil(textWidth + MEASURE_PADDING - available)))
end

-- Widens the window when this client's longest companion name, or longest
-- status message ("Quest Not Done", ...), doesn't fit the columns - translated
-- text is often much longer than English. English stays as the XML has it.
-- The Role, Level and Rapport columns are anchored to the Companion label, so
-- they move with it.
local function FitWindowToText(companions)
    local longestName = 0
    for _, companion in ipairs(companions) do
        longestName = zo_max(longestName, MeasureTextWidth(companion.name))
    end

    local longestStatus = 0
    for _, stringId in ipairs({ COMPANIONROSTER_STATUS_NOT_OWNED, COMPANIONROSTER_STATUS_QUEST_NOT_DONE, COMPANIONROSTER_STATUS_NO_INFO }) do
        longestStatus = zo_max(longestStatus, MeasureTextWidth(GetString(stringId)))
    end

    local nameExtra = ExtraWidthFor(longestName, BASE_NAME_WIDTH)
    local statusExtra = ExtraWidthFor(longestStatus, RAPPORT_SPANNED_WIDTH)
    rapportSpannedWidth = RAPPORT_SPANNED_WIDTH + statusExtra

    local totalExtra = nameExtra + statusExtra
    for i = 1, MAX_COMPANION_ROWS do
        local row = _G["CompanionRosterWindowRow" .. i]
        row:SetWidth(BASE_ROW_WIDTH + totalExtra)
        row:GetNamedChild("Companion"):SetWidth(BASE_NAME_WIDTH + nameExtra)
    end
    CompanionRosterWindowColumnCompanion:SetWidth(BASE_HEADER_WIDTH + nameExtra)
    CompanionRosterWindow:SetWidth(BASE_WINDOW_WIDTH + totalExtra)
end

-- Redraws the roster grid. Does nothing while the window is hidden, so
-- callers outside it (the settings panel, new data being recorded) cost
-- nothing then - ToggleWindow shows the window first and then calls this.
function CompanionRoster.RefreshGrid()
    if CompanionRosterWindow:IsHidden() then
        return
    end

    local companions = CompanionRoster.Data.GetAllCompanions()
    FitWindowToText(companions)
    local companionsForCharacter = selectedCharacterKey and CompanionRoster.Data.GetCompanionsForCharacter(selectedCharacterKey) or {}

    for i = 1, MAX_COMPANION_ROWS do
        local row = _G["CompanionRosterWindowRow" .. i]
        local companion = companions[i]

        if companion == nil then
            row:SetHidden(true)
        else
            row:SetHidden(false)
            row.companionId = companion.id
            row.keepsakeUnlocked = CompanionRoster.Data.IsKeepsakeUnlocked(companion.id)
            row.isOwned = CompanionRoster.Data.IsCompanionOwned(companion.id)
            row.canSummon = selectedCharacterKey and CompanionRoster.Data.CanSummonCompanion(selectedCharacterKey, companion.id)

            row.role, row.roleSecondary = CompanionRoster.Data.GetCompanionRoles(companion.id)
            local roleControl = row:GetNamedChild("Role")
            local roleTexture = roleControl:GetNamedChild("Icon")
            local roleTexture2 = roleControl:GetNamedChild("Icon2")
            roleTexture:ClearAnchors()
            if row.role and row.roleSecondary then
                -- Hybrid: two smaller icons filling the 34px column.
                roleTexture:SetDimensions(ROLE_ICON_SIZE_HYBRID, ROLE_ICON_SIZE_HYBRID)
                roleTexture:SetAnchor(LEFT, roleControl, LEFT, 0, 0)
                roleTexture:SetTexture(ZO_GetRoleIcon(row.role))
                roleTexture:SetAlpha(1)
                roleTexture2:SetTexture(ZO_GetRoleIcon(row.roleSecondary))
                roleTexture2:SetHidden(false)
            else
                -- One role (or the faded hint): the original single 20px icon,
                -- centered in the wider column.
                roleTexture:SetDimensions(ROLE_ICON_SIZE_SINGLE, ROLE_ICON_SIZE_SINGLE)
                roleTexture:SetAnchor(CENTER, roleControl, CENTER, 0, 0)
                roleTexture2:SetHidden(true)
                if row.role then
                    roleTexture:SetTexture(ZO_GetRoleIcon(row.role))
                    roleTexture:SetAlpha(1)
                else
                    roleTexture:SetTexture(ROLE_HINT_ICON)
                    roleTexture:SetAlpha(ROLE_HINT_ALPHA)
                end
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

            -- Perk and skill lines are account-wide, so they come from the
            -- shared record whichever character the row is showing.
            row.passivePerkName, row.passivePerkDescription = CompanionRoster.Data.GetPassivePerkInfo(companion.id)
            row.skillLines = CompanionRoster.Data.GetSkillLinesForCompanion(companion.id)

            -- Guild skill line can only progress via quests, not grinding -
            -- color the Level cell to call out that it's been fully maxed.
            local levelLabel = row:GetNamedChild("Level")
            if CompanionRoster.Data.IsGuildSkillLineMaxed(row.skillLines) then
                local r, g, b = CompanionRoster.Data.GetColor("done")
                levelLabel:SetColor(r, g, b, 1)
            else
                levelLabel:SetColor(1, 1, 1, 1)
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

-- On the CompanionRoster table (not a separate bare global) because the
-- XML OnMoveStop handler on the results popup calls this by name.
function CompanionRoster.OnResultsMoveStop(control)
    local _, point, _, relativePoint, offsetX, offsetY = control:GetAnchor(0)
    CompanionRoster.Data.SaveResultsPosition(point, relativePoint, offsetX, offsetY)
end

-- Resizing also moves the window when it's dragged from the top or left edge,
-- so both the size and the position are saved. The text then re-wraps to the
-- new width (see SetResultWidths below).
function CompanionRoster.OnResultsResizeStop(control)
    CompanionRoster.Data.SaveResultsSize(control:GetWidth(), control:GetHeight())
    CompanionRoster.OnResultsMoveStop(control)
    CompanionRoster.SetResultWidths()
end

-- The results popup for /fcr s and /fcr c. Its body is a ZO_ScrollContainer
-- (the game's own scrolling pane, filled the way the game's EULA dialog fills
-- it: controls parented to <container>ScrollChild, which resizes to fit them).
-- Rows and text lines are created from the templates in the XML on first use,
-- then reused and re-stacked on every later call, so nothing piles up.
local RESULT_BLOCK_GAP = 10
local RESULT_LINE_GAP = 4

local resultRows = {}
local resultTexts = {}
local resultRowsUsed = 0
local resultTextsUsed = 0
local resultBlocks = {} -- everything currently shown, top to bottom

-- The text is fixed-width (the scroll child sizes itself to fit it, so it
-- can't be anchored to the child's edges), so its width follows the window:
-- the window less the container's side margins and scrollbar. At the default
-- 560 wide window this works out to the 500 the XML templates start with.
local RESULT_WIDTH_MARGIN = 60
local RESULT_DETAIL_INDENT = 20

local function GetResultTextWidth()
    return CompanionRosterResults:GetWidth() - RESULT_WIDTH_MARGIN
end

-- Re-wraps everything already built to the window's current width.
function CompanionRoster.SetResultWidths()
    local width = GetResultTextWidth()
    for _, label in ipairs(resultTexts) do
        label:SetWidth(width)
    end
    for _, row in ipairs(resultRows) do
        row:GetNamedChild("Detail"):SetWidth(width - RESULT_DETAIL_INDENT)
    end
end

local function PlaceResultBlock(block, gap)
    block:ClearAnchors()
    local previous = resultBlocks[#resultBlocks]
    if previous then
        block:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, gap)
    else
        block:SetAnchor(TOPLEFT, CompanionRosterResultsContainerScrollChild, TOPLEFT, 4, 4)
    end
    block:SetHidden(false)
    table.insert(resultBlocks, block)
end

-- Clears whatever the popup was showing, titles it, and opens it.
function CompanionRoster.ShowResults(title)
    for _, block in ipairs(resultBlocks) do
        block:SetHidden(true)
    end
    resultBlocks = {}
    resultRowsUsed = 0
    resultTextsUsed = 0

    CompanionRosterResultsHeaderTitle:SetText(title)
    ZO_Scroll_ScrollAbsolute(CompanionRosterResultsContainer, 0)
    CompanionRosterResults:SetHidden(false)
end

-- One /fcr s result: the companion's name (hover for their Guild skill lines),
-- info text beside it (rapport, Guild rank) and the wrapped rapport action below.
function CompanionRoster.AddResultRow(companionId, companionName, infoText, detailText)
    resultRowsUsed = resultRowsUsed + 1
    local row = resultRows[resultRowsUsed]
    if row == nil then
        row = CreateControlFromVirtual("CompanionRosterResultRow" .. resultRowsUsed, CompanionRosterResultsContainerScrollChild, "CompanionRoster_ResultRow")
        resultRows[resultRowsUsed] = row
    end

    row.companionId = companionId
    row:GetNamedChild("Name"):SetText(companionName)
    row:GetNamedChild("Info"):SetText(infoText)
    row:GetNamedChild("Detail"):SetWidth(GetResultTextWidth() - RESULT_DETAIL_INDENT)
    row:GetNamedChild("Detail"):SetText(detailText)
    PlaceResultBlock(row, RESULT_BLOCK_GAP)
end

-- A plain wrapped line: a heading (bold, more space above it) or a body line.
function CompanionRoster.AddResultText(text, isHeading)
    resultTextsUsed = resultTextsUsed + 1
    local label = resultTexts[resultTextsUsed]
    if label == nil then
        label = CreateControlFromVirtual("CompanionRosterResultText" .. resultTextsUsed, CompanionRosterResultsContainerScrollChild, "CompanionRoster_ResultText")
        resultTexts[resultTextsUsed] = label
    end

    label:SetFont(isHeading and "ZoFontGameBold" or "ZoFontGame")
    label:SetWidth(GetResultTextWidth())
    label:SetText(text)
    PlaceResultBlock(label, isHeading and RESULT_BLOCK_GAP or RESULT_LINE_GAP)
end

-- On the CompanionRoster table (not a separate bare global) because the XML
-- OnMouseEnter handler on a result row's name calls this by name. The
-- tooltip is the game's standard text tooltip, owned by the name label.
function CompanionRoster.OnResultNameMouseEnter(control)
    local companionId = control:GetParent().companionId
    local summary = companionId and CompanionRoster.Data.GetGuildSkillLineSummary(companionId)
    ZO_Tooltips_ShowTextTooltip(control, TOP, summary or GetString(COMPANIONROSTER_TIP_NO_GUILD_DATA))
end

-- "<command> search <term>" (or "s") and "<command> companion <name>" (or
-- "c") show rapport tips in the results popup (see CompanionRoster.ShowResults)
-- instead of toggling the window. "<command> <name>" summons that companion.
-- No argument at all (which is how a keybind or plain typed command calls
-- this) opens/closes the roster window. One-line messages (usage, no match)
-- still go to chat.
function CompanionRoster.RunRapportSearch(term)
    term = Trim(term)
    if term == "" then
        Say(COMPANIONROSTER_SAY_USAGE_SEARCH, CompanionRoster.Data.GetSlashCommand())
        return
    end

    local results = CompanionRoster.Data.SearchRapportTips(term)
    if #results == 0 then
        Say(COMPANIONROSTER_SAY_NO_TIPS, term)
        return
    end

    CompanionRoster.ShowResults(zo_strformat(COMPANIONROSTER_RESULTS_SEARCH_TITLE, term))
    for _, result in ipairs(results) do
        -- Info beside the name: current rapport (e.g. 3075/5500), left off when
        -- this character has never had that companion's rapport recorded, then,
        -- when the term is a Guild skill line, this companion's rank in it.
        -- Numbers are colored done/in progress (the configurable colors).
        local infoParts = {}
        if result.rapportValue and result.rapportMax then
            table.insert(infoParts, string.format("(|c%s%d/%d|r)", CompanionRoster.Data.GetColorHex(result.isMaxed and "done" or "inProgress"), result.rapportValue, result.rapportMax))
        end
        local guildParts = {}
        for _, line in ipairs(result.skillLineRanks) do
            local rankText = tostring(line.rank)
            if line.isMaxed then
                rankText = rankText .. " " .. GetString(COMPANIONROSTER_MAXED)
            end
            table.insert(guildParts, zo_strformat(COMPANIONROSTER_NAME_VALUE, line.name, string.format("|c%s%s|r", CompanionRoster.Data.GetColorHex(line.isMaxed and "done" or "inProgress"), rankText)))
        end
        if #guildParts > 0 then
            table.insert(infoParts, table.concat(guildParts, ", "))
        end

        local amountText = "+" .. (result.amountLabel or tostring(result.amount))
        CompanionRoster.AddResultRow(result.companionId, result.companionName, table.concat(infoParts, " "), zo_strformat(COMPANIONROSTER_SEARCH_DETAIL, amountText, result.description, result.cooldown))
    end
end

local function FormatTipLine(action)
    local amountText
    if action.amount >= 0 then
        amountText = "+" .. (action.amountLabel or tostring(action.amount))
    else
        amountText = action.amountLabel and ("-" .. action.amountLabel) or tostring(action.amount)
    end
    return zo_strformat(COMPANIONROSTER_TIP_LINE, amountText, action.description, action.cooldown)
end

function CompanionRoster.RunCompanionLookup(term)
    term = Trim(term)
    -- Everything is always shown now, so a trailing "all" (what this command
    -- used to need) is just dropped rather than treated as part of the name.
    term = term:match("^(.-)%s+[Aa][Ll][Ll]$") or term

    if term == "" then
        Say(COMPANIONROSTER_SAY_USAGE_COMPANION, CompanionRoster.Data.GetSlashCommand())
        return
    end

    local matches = CompanionRoster.Data.FindRapportTipsByName(term)
    if #matches == 0 then
        Say(COMPANIONROSTER_SAY_NO_COMPANION, term)
        return
    end
    if #matches > 1 then
        SayAmbiguousMatch(term, matches)
        return
    end

    local companion = matches[1]
    CompanionRoster.ShowResults(zo_strformat(COMPANIONROSTER_RESULTS_COMPANION_TITLE, companion.name))

    -- Fixed green/red headings: these mean "raises/lowers", not the
    -- configurable done/in-progress colors.
    CompanionRoster.AddResultText("|c66FF66" .. GetString(COMPANIONROSTER_RESULTS_LIKES) .. "|r", true)
    for _, action in ipairs(companion.likes) do
        CompanionRoster.AddResultText(FormatTipLine(action))
    end
    if #companion.likes == 0 then
        CompanionRoster.AddResultText(GetString(COMPANIONROSTER_RESULTS_NONE))
    end

    CompanionRoster.AddResultText("|cFF6666" .. GetString(COMPANIONROSTER_RESULTS_DISLIKES) .. "|r", true)
    for _, action in ipairs(companion.dislikes) do
        CompanionRoster.AddResultText(FormatTipLine(action))
    end
    if #companion.dislikes == 0 then
        CompanionRoster.AddResultText(GetString(COMPANIONROSTER_RESULTS_NONE))
    end
end

function CompanionRoster.OnSlashCommand(input)
    local verb, rest = (input or ""):match("^%s*(%S+)%s*(.-)%s*$")
    verb = verb and zo_strlower(verb)
    if verb == "search" or verb == "s" then
        CompanionRoster.RunRapportSearch(rest)
    elseif verb == "companion" or verb == "c" then
        CompanionRoster.RunCompanionLookup(rest)
    elseif verb == nil then
        CompanionRoster.ToggleWindow()
    else
        -- Anything else is a companion name to summon. Uses the whole input,
        -- not just the first word, so a two-word name like "bastian hallix" works.
        CompanionRoster.SummonCompanionByName(Trim(input))
    end
end

-- On the CompanionRoster table (not a separate bare global) because both
-- the <Down> handler in Bindings.xml and the /fcr slash command call this
-- by name.
function CompanionRoster.ToggleWindow()
    if CompanionRosterWindow:IsHidden() then
        PopulateDropdown()
        CompanionRosterWindow:SetHidden(false)
        CompanionRoster.RefreshGrid() -- must come after the window is shown
    else
        CompanionRosterWindow:SetHidden(true)
    end
end

-- Called by CompanionRoster_Data.lua whenever it records fresh companion data
-- (a summon, an XP or rapport change), so an open window shows it right away
-- instead of the stale row. RefreshGrid is a no-op while the window is hidden.
function CompanionRoster.OnDataRecorded()
    CompanionRoster.RefreshGrid()
end

-- Every addon's EVENT_ADD_ON_LOADED fires during the loading screen, before
-- EVENT_PLAYER_ACTIVATED - so by the time this runs (once, right after the
-- first login/reloadui this session), every other addon that's going to
-- register a slash command already has. SLASH_COMMANDS is the same real
-- table LibSlashCommander itself reads from (see the collision check in
-- CompanionRoster_Settings.lua) - if our own alias no longer points at our
-- own Command object there, something else claimed it after us.
local slashCommandChecked = false

local function CheckSlashCommandHijack()
    if slashCommandChecked then
        return
    end
    slashCommandChecked = true

    local currentCommand = CompanionRoster.Data.GetSlashCommand()
    local owner = SLASH_COMMANDS[zo_strlower(currentCommand)]
    if owner == CompanionRoster.slashCommand then
        return
    end

    local who = GetString(COMPANIONROSTER_ANOTHER_ADDON)
    if LibSlashCommander.IsCommand(owner) then
        local description = owner:GetDescription()
        if description then
            who = description
        end
    end

    d(zo_strformat(COMPANIONROSTER_COMMAND_TAKEN_WARNING, CompanionRoster.title, currentCommand, who))
end

-- Called from the addon's single EVENT_PLAYER_ACTIVATED handler
-- (CompanionRoster.lua). Only the first activation checks the command: by
-- then every addon that is going to register a slash command already has.
function CompanionRoster.UI.OnPlayerActivated()
    CheckSlashCommandHijack()
end

-- Real event, confirmed against the client source (EVENT_PLAYER_COMBAT_STATE
-- fires with an inCombat boolean - dozens of built-in ESO UI elements, e.g.
-- the combat overlay and buff/debuff trackers, already hide/show off this
-- exact event). Only closes the window, never opens it, and only when
-- opted in via the settings panel (off by default). Registered only while
-- the window is open and that option is on (see UpdateCombatEvent): the
-- event has no filterable parameter.
local COMBAT_EVENT_NAMESPACE = "CompanionRoster_UI"
local combatEventRegistered = false

local function OnPlayerCombatState(eventCode, inCombat)
    if inCombat and CompanionRoster.Data.GetCloseOnCombat() and not CompanionRosterWindow:IsHidden() then
        CompanionRosterWindow:SetHidden(true)
    end
end

function CompanionRoster.UpdateCombatEvent()
    local wanted = not CompanionRosterWindow:IsHidden() and CompanionRoster.Data.GetCloseOnCombat() == true
    if wanted == combatEventRegistered then
        return
    end
    combatEventRegistered = wanted
    if wanted then
        EVENT_MANAGER:RegisterForEvent(COMBAT_EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
    else
        EVENT_MANAGER:UnregisterForEvent(COMBAT_EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE)
    end
end

-- The roster window's OnEffectivelyShown / OnEffectivelyHidden handlers in the
-- XML call these by name, so the combat event follows the window however it
-- is opened or closed.
function CompanionRoster.OnWindowShown()
    CompanionRoster.UpdateCombatEvent()
end

function CompanionRoster.OnWindowHidden()
    CompanionRoster.UpdateCombatEvent()
end

-- Called once from the addon's single EVENT_ADD_ON_LOADED handler
-- (CompanionRoster.lua), after the saved data is ready.
function CompanionRoster.UI.Initialize()
    -- Window text. Set here, not in the XML, so it comes from lang/.
    CompanionRosterWindowHeaderTitle:SetText(CompanionRoster.title)
    CompanionRosterWindowColumnCompanion:SetText(GetString(COMPANIONROSTER_COLUMN_COMPANION))
    CompanionRosterWindowColumnLevel:SetText(GetString(COMPANIONROSTER_COLUMN_LEVEL))
    CompanionRosterWindowColumnRapport:SetText(GetString(COMPANIONROSTER_COLUMN_RAPPORT))

    characterDropdown = ZO_ComboBox_ObjectFromContainer(CompanionRosterWindowCharacterDropdown)
    characterDropdown:SetSortsItems(false)

    local savedPosition = CompanionRoster.Data.GetWindowPosition()
    if savedPosition then
        CompanionRosterWindow:ClearAnchors()
        CompanionRosterWindow:SetAnchor(savedPosition.point, nil, savedPosition.relativePoint, savedPosition.offsetX, savedPosition.offsetY)
    end

    local savedResultsSize = CompanionRoster.Data.GetResultsSize()
    if savedResultsSize then
        CompanionRosterResults:SetDimensions(savedResultsSize.width, savedResultsSize.height)
    end

    local savedResultsPosition = CompanionRoster.Data.GetResultsPosition()
    if savedResultsPosition then
        CompanionRosterResults:ClearAnchors()
        CompanionRosterResults:SetAnchor(savedResultsPosition.point, nil, savedResultsPosition.relativePoint, savedResultsPosition.offsetX, savedResultsPosition.offsetY)
    end

    -- The roster window and the results popup carry the same footer.
    local footerText = zo_strformat(COMPANIONROSTER_FOOTER, CompanionRoster.title, CompanionRoster.version)
    for _, footer in ipairs({ CompanionRosterWindowFooter, CompanionRosterResultsFooter }) do
        footer:SetText(footerText)
        footer:SetColor(unpack(FOOTER_COLOR))
    end

    CompanionRoster.slashCommand = LibSlashCommander:Register(CompanionRoster.Data.GetSlashCommand(), CompanionRoster.OnSlashCommand, CompanionRoster.title)
end

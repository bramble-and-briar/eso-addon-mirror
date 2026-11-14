local KELAPADUI_ENTRIES = {
    SETS           = 1,
    TRAIT_RESEARCH = 2,
    SETTINGS       = 3,
}

local KELAPADUI_TEXT_COLOR = "|cC64CFF"
--local KELAPADUI_ICON_COLOR = ZO_ColorDef:New("C64CFF")

local KELAPADUI_MENU_ENTRY_DATA =
{
    customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow",
    name = KELAPADUI_TEXT_COLOR .. GetString(KELA_MAINMENU_TITLE) .. "|r",
    icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_champion.dds",
    --iconColor = KELAPADUI_ICON_COLOR,
    subMenu =
    {
        [KELAPADUI_ENTRIES.SETS] =
        {
            scene = "kelaSets",
            name = GetString(KELA_MAINMENU_SETS),
            icon = "esoui/art/treeicons/gamepad/gp_collectionicon_weapona+armor.dds",
            isVisibleCallback = function()
                return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_SETS_ENABLED)
            end,
        },
        [KELAPADUI_ENTRIES.TRAIT_RESEARCH] =
        {
            scene = "kelaTraitResearch",
            name = GetString(KELA_MAINMENU_TRAIT_RESEARCH),
            icon = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_create.dds",
            isVisibleCallback = function()
                return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED)
            end,
        },
        [KELAPADUI_ENTRIES.SETTINGS] =
        {
            prePadding = 150,
            scene = "kela_options_root",
            name = GetString(SI_GAME_MENU_SETTINGS),
            icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds",
        },
    }
}

-- Shared with kpui_main_menu_shortcuts.lua for the Quick Access submenu entries.
function KelaCreateMainMenuEntry(data)
    local name = data.name
    if type(name) == "function" then
        name = "" --will be updated whenever the list is generated
    end

    local entry = ZO_GamepadEntryData:New(name, data.icon, nil, nil, data.isNewCallback)
    entry:SetIconTintOnSelection(true)
    if data.iconColor then
        entry:SetIconTint(data.iconColor, data.iconColor)
    end
    entry:SetIconDisabledTintOnSelection(true)

    local header = data.header
    if header then
        entry:SetHeader(header)
    end

    entry.canLevel = data.canLevel

    entry.data = data
    return entry
end

-- Create the Kela Menu
local kelaEntry = KelaCreateMainMenuEntry(KELAPADUI_MENU_ENTRY_DATA)

-- Add the Sub Menu
if KELAPADUI_MENU_ENTRY_DATA.subMenu then
    kelaEntry.subMenu = {}
    for submenuEntryId, subMenuData in ipairs(KELAPADUI_MENU_ENTRY_DATA.subMenu) do
        local newSubMenuEntry = KelaCreateMainMenuEntry(subMenuData)
        newSubMenuEntry.id = submenuEntryId
        table.insert(kelaEntry.subMenu, newSubMenuEntry)
    end
end

-- Place the Kela Menu Entry directly below Options, matching where users look
-- for the add-on's settings. Existing entries keep their ids: the game maps
-- entry id to list index in MAIN_MENU_GAMEPAD.mainMenuEntryToListIndex, so
-- inserting without renumbering keeps SelectMenuEntry() calls valid.
kelaEntry.id = #ZO_MENU_ENTRIES + 1
local kelaInsertIndex = #ZO_MENU_ENTRIES + 1
local kelaOptionsId = ZO_MENU_MAIN_ENTRIES and ZO_MENU_MAIN_ENTRIES.OPTIONS
if kelaOptionsId then
    for index, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.id == kelaOptionsId then
            kelaInsertIndex = index + 1
            break
        end
    end
end
table.insert(ZO_MENU_ENTRIES, kelaInsertIndex, kelaEntry)

-- The submenu opens with a section header carrying the root entry's name so the
-- list does not start with an unlabeled row. Sets and Trait Research can each be
-- turned off, Settings is always listed, so the header follows the first visible
-- entry.
local KELAPADUI_MENU_HEADER = GetString(KELA_MAINMENU_TITLE)

local function ApplySubMenuHeader()
	local headerAssigned = false
	for _, entry in ipairs(kelaEntry.subMenu) do
		local data = entry.data
		local isVisible = not data.isVisibleCallback or data.isVisibleCallback()
		if isVisible and not headerAssigned then
			entry:SetHeader(KELAPADUI_MENU_HEADER)
			headerAssigned = true
		else
			entry:SetHeader(nil)
		end
	end
end

function KelaSetupMainMenuHeader()
	ApplySubMenuHeader()

	if not MAIN_MENU_GAMEPAD_SCENE or MAIN_MENU_GAMEPAD_SCENE.kelaMenuHeaderRegistered then
		return
	end

	MAIN_MENU_GAMEPAD_SCENE.kelaMenuHeaderRegistered = true
	-- Re-evaluate when the menu opens so a setting changed without a reload
	-- still moves the header to the first visible entry.
	MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWING then
			ApplySubMenuHeader()
		end
	end)
end



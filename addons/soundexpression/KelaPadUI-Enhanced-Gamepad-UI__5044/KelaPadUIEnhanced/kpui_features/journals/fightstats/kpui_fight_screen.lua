-- KelaPadUI Fight Stats: the screen (kpui_core/kpui_gamepad_sheet.lua). The
-- fights are listed on the left and the selected one is shown on the right;
-- L1/R1 switch pages: Summary, Stats, Group (when LibGroupCombatStats is
-- installed, since only it shares other members' own numbers) and Loadout.

local SCENE_NAME = "KelaFightStats"

local UI = KPUI_FIGHT_STATS.UI
local Join, GetContentName, KIND_MATCH = UI.Join, UI.GetContentName, UI.KIND_MATCH

local source = {}

-- The list is coloured by what each entry is, so boss fights stand out from
-- trash pulls: boss fights amber, battleground matches blue, other fights
-- grey. Boss fights and matches are also the ones "Fights kept" keeps longest.
local BOSS_COLOR = ZO_ColorDef:New("FFB84D")
local MATCH_COLOR = ZO_ColorDef:New("6FB7FF")
local FIGHT_COLOR = kpuiConst.Colors.COLOR_LIGHT_GREY

local function GetRecordColor(record)
	if record.kind == KIND_MATCH then
		return MATCH_COLOR
	elseif record.bossFight then
		return BOSS_COLOR
	end
	return FIGHT_COLOR
end

local function HasGroupStats()
	return type(LibGroupCombatStats) == "table"
end

function source:GetPages()
	local pages = KPUI_FIGHT_STATS.Pages
	local list = { pages.Summary, pages.Stats }
	if HasGroupStats() then
		list[#list + 1] = pages.Group
	end
	list[#list + 1] = pages.Loadout
	return list
end

function source:GetEntries()
	return KPUI_FIGHT_STATS.GetRecords()
end

function source:GetEntryInfo(record)
	local name = record.target
	if record.kind == KIND_MATCH then
		name = name .. " (" .. zo_strformat(GetString(KELA_FIGHT_STATS_FIGHTS_IN_MATCH), record.fights or 1) .. ")"
	end
	return name, Join({ os.date("%m-%d %H:%M", record.timestamp), GetContentName(record), record.zone }), record.classIcon, GetRecordColor(record)
end

function source:GetEmptyText()
	return GetString(KELA_FIGHT_STATS_EMPTY)
end

function source:GetDeleteLabel()
	return GetString(KELA_FIGHT_STATS_DELETE)
end

function source:GetDeleteOptions(record)
	return
	{
		{
			label = GetString(KELA_FIGHT_STATS_DELETE_THIS),
			text = zo_strformat(GetString(KELA_FIGHT_STATS_DELETE_THIS_TEXT), record.target),
			action = function()
				KPUI_FIGHT_STATS.DeleteRecord(record)
			end,
		},
		{
			label = GetString(KELA_FIGHT_STATS_DELETE_ALL),
			text = zo_strformat(GetString(KELA_FIGHT_STATS_DELETE_ALL_TEXT), #KPUI_FIGHT_STATS.GetRecords()),
			action = KPUI_FIGHT_STATS.DeleteAllRecords,
		},
	}
end

local screen = nil

function KPUI_FIGHT_STATS.OnRecordsChanged()
	if screen then
		screen:Refresh()
	end
end

function KelaShowFightStats()
	if not KelaIsFightStatsAvailable() then
		return
	end
	if not screen then
		screen = KelaGamepadSheetScreen:New(SCENE_NAME, source)
	end
	SCENE_MANAGER:Push(SCENE_NAME)
end

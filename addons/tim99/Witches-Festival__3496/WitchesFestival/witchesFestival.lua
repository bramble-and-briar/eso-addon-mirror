tim99_WitchesFestival = tim99_WitchesFestival or {}
local tny = tim99_WitchesFestival

tny.name          = "WitchesFestival"
tny.author        = "|c595959tim99|r"
tny.firstCall     = true
tny.srv           = string.sub(GetWorldName(),1,2)
tny.svAcc         = {}
tny.svDefAcc      = {
	anchor          = {TOPLEFT, TOPLEFT, 100, 100},
	tmrDelve        = 0,
	tmrAnker        = 0,
	tmrWorld        = 0,
	tmrPublic       = 0,
	tmrGroup        = 0,
	tmrArena        = 0,
	tmrTrial        = 0,
	tmrCrow         = 0,
	tmrJack         = 0,
	tmrArchiv       = 0,
}
tny.colors={
	c_red=ZO_ColorDef:New(  1,.15,  0, 1), --#ff2600  //(255, 38,  0)  //(255/255, 38/255,  0/255,1)
	c_grn=ZO_ColorDef:New(  0,  1,  0, 1), --#00ff00  //(  0,255,  0)  //(  0/255,255/255,  0/255,1)
}
tny.ITEMID_PLUNDER_DELVE  = 190015		--|H1:item:190015:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_ANKER  = 190014		--|H1:item:190014:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_WORLD  = 190019		--|H1:item:190019:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_PUBLIC = 190017		--|H1:item:190017:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_GROUP  = 190016		--|H1:item:190016:124:1:0:0:0:2023:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_ARENA  = 190013		--|H1:item:190013:124:1:0:0:0:2023:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_TRIAL  = 190018		--|H1:item:190018:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_CROW   = 190038		--|H1:item:190038:124:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
tny.ITEMID_PLUNDER_JACK   = 211125      --|H1:item:211125:124:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h
tny.ITEMID_PLUNDER_ARCHIV = 211126      --|H1:item:211126:124:1:0:0:0:2024:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
--
tny.ITEMID_PLUNDER_NORMAL = 190037		--|H1:item:190037:123:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--from xml-layout
function Tim99_WitchesEventSaveAnchor()
	local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = TimWitchesUI:GetAnchor()
	if isValidAnchor then tny.svAcc.anchor={point, relativePoint, offsetX, offsetY} end
end
----------------------------------------------------------------------------------------------------
-- maybe change reset calculation to:
--     local dayreset = GetTimeUntilNextDailyLoginRewardClaimS()
----------------------------------------------------------------------------------------------------
local function GetDelve(i_ctrl)
	local _c,ico=" "," "
	if tny.svAcc.tmrDelve and tny.svAcc.tmrDelve>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrDelve>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrDelve>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_delve_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_delve_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetAnker(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrAnker and tny.svAcc.tmrAnker>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrAnker>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrAnker>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_portal_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_portal_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetWorld(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrWorld and tny.svAcc.tmrWorld>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then	
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrWorld>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrWorld>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_groupboss_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_groupboss_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetPublic(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrPublic and tny.svAcc.tmrPublic>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrPublic>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrPublic>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_dungeon_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_dungeon_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetDungeon(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrGroup and tny.svAcc.tmrGroup>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrGroup>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrGroup>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_groupinstance_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_groupinstance_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetArena(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrArena and tny.svAcc.tmrArena>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrArena>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrArena>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/treeicons/gamepad/gp_reconstruction_tabicon_arenasolo.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/treeicons/gamepad/gp_reconstruction_tabicon_arenasolo.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetTrial(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrTrial and tny.svAcc.tmrTrial>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrTrial>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrTrial>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_raiddungeon_complete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_raiddungeon_complete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetCrow(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrCrow and tny.svAcc.tmrCrow>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrCrow>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrCrow>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/hat_crowheartskullsallet.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/hat_crowheartskullsallet.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetJack(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrJack and tny.svAcc.tmrJack>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrJack>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrJack>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/collectible_memento_pumpkincarving.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/collectible_memento_pumpkincarving.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
local function GetArchiv(i_ctrl)
	local _c,ico="",""
	if tny.svAcc.tmrArchiv and tny.svAcc.tmrArchiv>0 then --wir haben zeit in den SavedVars
		if tny.srv=="EU" then
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
			if tny.svAcc.tmrArchiv>=todayReset then _c="grn" end --on CD
		else --NA, PT(S)
			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
			if tny.svAcc.tmrArchiv>=todayReset then _c="grn" end --on CD
		end
	end
	if _c=="grn" then
		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_endlessdungeon_incomplete.dds"))
	else
		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/icons/poi/poi_endlessdungeon_incomplete.dds"))
	end
	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
end
----------------------------------------------------------------------------------------------------
--local function GetQuest(i_ctrl)
--	local _c,ico="",""
--	if tny.svChr.tmrQuest and tny.svChr.tmrQuest>0 then --wir haben zeit in den SavedVars
--		if tny.srv=="EU" then
--			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641006000)/ZO_ONE_DAY_IN_SECONDS)
--			local todayReset=1641006000+(diff*ZO_ONE_DAY_IN_SECONDS) --04:00 (UTC+1)
--			if tny.svChr.tmrQuest>=todayReset then _c="grn" end --on CD
--		else --NA, PT(S)
--			local diff=zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(),1641031200)/ZO_ONE_DAY_IN_SECONDS)
--			local todayReset=1641031200+(diff*ZO_ONE_DAY_IN_SECONDS) --11:00 (UTC+1)
--			if tny.svChr.tmrQuest>=todayReset then _c="grn" end --on CD
--		end
--	end
--	if _c=="grn" then
--		ico=tny.colors.c_grn:Colorize(zo_iconFormatInheritColor("/esoui/art/journal/journal_tabicon_quest_down.dds"))
--	else
--		ico=tny.colors.c_red:Colorize(zo_iconFormatInheritColor("/esoui/art/journal/journal_tabicon_quest_down.dds"))
--	end
--	if i_ctrl~=false then i_ctrl:SetText(ico) else return ico end
--end
----------------------------------------------------------------------------------------------------
function tny.initUI()
	GetDelve(TimWitchesUIInfo01)
	GetAnker(TimWitchesUIInfo02)
	GetWorld(TimWitchesUIInfo03)
	GetPublic(TimWitchesUIInfo04)
	GetDungeon(TimWitchesUIInfo05)
	GetArena(TimWitchesUIInfo06)
	GetTrial(TimWitchesUIInfo07)
	GetCrow(TimWitchesUIInfo08)
	GetJack(TimWitchesUIInfo09)
	GetArchiv(TimWitchesUIInfo10)
end
----------------------------------------------------------------------------------------------------
function tny.onSceneChangeAll(oldState, newState)
	local mScene = SCENE_MANAGER:GetCurrentScene():GetName()
	if mScene=="hud" or mScene=="hudui" then 
		TimWitchesUI:SetHidden(false) 
	else 
		TimWitchesUI:SetHidden(true)
	end
end
----------------------------------------------------------------------------------------------------
function tny.onLootReceived(eventCode,receivedBy,itemName,quantity,soundCategory,lootType,self,isPickpocketLoot,questItemIcon,itemId,isStolen)
	if self~=true then return end --not mine
	itemId=itemId or GetItemLinkItemId(itemName)
	local updateWasDone = false
	if itemId==tny.ITEMID_PLUNDER_DELVE then
		tny.svAcc.tmrDelve=GetTimeStamp()
		GetDelve(TimWitchesUIInfo01)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_ANKER then
		tny.svAcc.tmrAnker=GetTimeStamp()
		GetAnker(TimWitchesUIInfo02)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_WORLD then
		tny.svAcc.tmrWorld=GetTimeStamp()
		GetWorld(TimWitchesUIInfo03)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_PUBLIC then
		tny.svAcc.tmrPublic=GetTimeStamp()
		GetPublic(TimWitchesUIInfo04)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_GROUP then
		tny.svAcc.tmrGroup=GetTimeStamp()
		GetDungeon(TimWitchesUIInfo05)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_ARENA then
		tny.svAcc.tmrArena=GetTimeStamp()
		GetArena(TimWitchesUIInfo06)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_TRIAL then
		tny.svAcc.tmrTrial=GetTimeStamp()
		GetTrial(TimWitchesUIInfo07)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_CROW then
		tny.svAcc.tmrCrow=GetTimeStamp()
		GetCrow(TimWitchesUIInfo08)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_JACK then
		tny.svAcc.tmrJack=GetTimeStamp()
		GetJack(TimWitchesUIInfo09)
		updateWasDone = true
	elseif itemId==tny.ITEMID_PLUNDER_ARCHIV then
		tny.svAcc.tmrArchiv=GetTimeStamp()
		GetArchiv(TimWitchesUIInfo10)
		updateWasDone = true
	end
	if updateWasDone then
        EVENT_MANAGER:UnregisterForUpdate("TimWitchesUI_Update")
        EVENT_MANAGER:RegisterForUpdate("TimWitchesUI_Update", 60000, tny.initUI)
    end
end
----------------------------------------------------------------------------------------------------
--function tny.onQuestComplete(eventCode,questName,level,previousExperience,currentExperience,championPoints,questType,instanceDisplayType)
--	if questType==QUEST_TYPE_HOLIDAY_EVENT then
--		if questName==GetString(TIM99_WITCH_QUESTNAME) then 
--			tny.svChr.tmrQuest=GetTimeStamp() 
--			GetQuest(TimWitchesUIInfo09)
--		end
--	end
--end
----------------------------------------------------------------------------------------------------
-- Right-click to manually toggle skulls for the current daily reset.
local function ToggleSkull(key)
    local now = GetTimeStamp()
    local resetBase = (tny.srv == "EU") and 1641006000 or 1641031200
    local todayReset = resetBase + zo_floor(GetDiffBetweenTimeStamps(now, resetBase) / ZO_ONE_DAY_IN_SECONDS) * ZO_ONE_DAY_IN_SECONDS
    local sv = tny.svAcc
    if (sv[key] or 0) >= todayReset then
        sv[key] = 0
    else
        sv[key] = now
    end
    tny.initUI()
end
----------------------------------------------------------------------------------------------------
function tny.onPlayerActivated()
	--just once at beginning
	if tny.firstCall==true then
		tny.firstCall=false
		SCENE_MANAGER:RegisterCallback("SceneStateChanged", tny.onSceneChangeAll)
		EVENT_MANAGER:RegisterForEvent(tny.name, EVENT_LOOT_RECEIVED, tny.onLootReceived)
			EVENT_MANAGER:AddFilterForEvent(tny.name, EVENT_LOOT_RECEIVED, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
			EVENT_MANAGER:AddFilterForEvent(tny.name, EVENT_LOOT_RECEIVED, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
			EVENT_MANAGER:AddFilterForEvent(tny.name, EVENT_LOOT_RECEIVED, REGISTER_FILTER_IS_NEW_ITEM, true)
        local skullControls = {
            [TimWitchesUIInfo01] = "tmrDelve",
            [TimWitchesUIInfo02] = "tmrAnker",
            [TimWitchesUIInfo03] = "tmrWorld",
            [TimWitchesUIInfo04] = "tmrPublic",
            [TimWitchesUIInfo05] = "tmrGroup",
            [TimWitchesUIInfo06] = "tmrArena",
            [TimWitchesUIInfo07] = "tmrTrial",
            [TimWitchesUIInfo08] = "tmrCrow",
            [TimWitchesUIInfo09] = "tmrJack",
            [TimWitchesUIInfo10] = "tmrArchiv",
        }
        for control, key in pairs(skullControls) do
            local skullKey = key
            control:SetHandler("OnMouseUp", function(_, button, upInside)
                if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then ToggleSkull(skullKey) end
            end)
        end
		tny.initUI()
		EVENT_MANAGER:RegisterForUpdate("TimWitchesUI_Update", 60000, tny.initUI)
	end
	--each loading screen
end
----------------------------------------------------------------------------------------------------
function tny.addonLoaded(event, addonName)
	if addonName~=tny.name then return end
	EVENT_MANAGER:UnregisterForEvent(tny.name, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(tny.name, EVENT_PLAYER_ACTIVATED, tny.onPlayerActivated)

	tny.svAcc=ZO_SavedVars:NewAccountWide("WitchesSettings", 1, nil, tny.svDefAcc, GetWorldName())

	TimWitchesUI:ClearAnchors();
	TimWitchesUI:SetAnchor(tny.svAcc.anchor[1],TimWitchesUI.parent,tny.svAcc.anchor[2],tny.svAcc.anchor[3],tny.svAcc.anchor[4])
	--tny.initMenu()
end
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(tny.name, EVENT_ADD_ON_LOADED, tny.addonLoaded)

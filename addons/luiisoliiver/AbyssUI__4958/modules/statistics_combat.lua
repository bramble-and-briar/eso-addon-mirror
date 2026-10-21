--DAMAGE MANAGEMENT COMPONENT
local Element={
	[0]="None",
	[1]="Generic",
	[2]="Physical",
	[3]="Fire",
	[4]="Shock",
	[5]="Oblivion",
	[6]="Cold",
	[7]="Earth",
	[8]="Magic",
	[9]="Drown",
	[10]="Diesease",
	[11]="Poison"
	}
local AdditionalAbilityName={
	[16688]=" (Bow)",[17173]=" (Bow)",
	[16499]=" (Dual)",[17169]=" (Dual Right))",
	[16037]=" (Two hand)",[17162]=" (Two Hand)",[17163]=" (Two Hand)",
	[15435]=" (One hand)",[15829]=" (One Hand)",
	}
local Multy_element={}
--[[
local function Targets_Init()	--TARGETS REPORT
	local Targets	=NAGA_BUI.UI.Control(	"NAGA_Statistics_Targets",					NAGA_StatisticsLayer,	{390,200},				NAGA_BUI.Vars.NAGA_Statistics_Targets,			true)
	Targets.backdrop	=NAGA_BUI.UI.Backdrop(	"NAGA_Statistics_Targets_BG",					Targets,	"inherit",				{CENTER,CENTER,0,0},			{0,0,0,0.25}, {0,0,0,0}, nil, false)
--	Targets:SetAlpha(1)
	Targets:SetMouseEnabled(true)
	Targets:SetMovable(true)
	Targets:SetHandler("OnMouseUp", function(self) NAGA_BUI.Menu:SaveAnchor(self) end)

	--Headers
	Targets.namesH	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_NamesHeader",			Targets,	{190,25},				{TOPLEFT,TOPLEFT,10,5},			NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,1}, "Target"	, false)
	Targets.timeH	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_TimeHeader",			Targets,	{45,25},				{LEFT,RIGHT,0,0,Targets.namesH},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,1}, "Time"	, false)
	Targets.damageH	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_DamageHeader",			Targets,	{90,25},				{LEFT,RIGHT,0,0,Targets.timeH},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,1}, "Damage"	, false)
	Targets.dpsH	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_DPSHeader",			Targets,	{75,25},				{LEFT,RIGHT,0,0,Targets.damageH},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,1}, "DPS"	, false)

	--Divider
	Targets.divider	=NAGA_BUI.UI.Texture(	"NAGA_Statistics_Targets_Divider",				Targets,	{360,8},				{TOPLEFT,TOPLEFT,20,32},		'EsoUI/Art/Miscellaneous/horizontalDivider.dds', false)
	Targets.divider:SetTextureCoords(0.181640625, 0.818359375, 0, 1) Targets:SetDrawLayer(DL_OVERLAY)

	--List
	Targets.names	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_Names",				Targets,	{190,600},				{TOPLEFT,TOPLEFT,10,40},		NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,0}, "names"	, false)
	Targets.time	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_Time",				Targets,	{45,600},				{LEFT,RIGHT,0,0,Targets.names},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,0}, "time"	, false)
	Targets.damage	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_Damage",				Targets,	{90,600},				{LEFT,RIGHT,0,0,Targets.time},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,0}, "damage"	, false)
	Targets.dps		=NAGA_BUI.UI.Label(	"NAGA_Statistics_Targets_DPS",				Targets,	{75,600},				{LEFT,RIGHT,0,0,Targets.damage},	NAGA_BUI.UI.Font("standard",16,true), {1,1,1,1}, {0,0}, "dps"	, false)
end

local TargetsWindowUpdated
local function TargetsDeveloperWindowUpdate()
	if not NAGA_BUI.Vars.DeveloperMode then return end
	if GetGameTimeMilliseconds()-TargetsWindowUpdated<500 then return end
	TargetsWindowUpdated=GetGameTimeMilliseconds()
	local parent=NAGA_Statistics_Targets
	local data=NAGA_BUI.Stats.GroupLog
	--Setup labels
	local fighttime=(NAGA_BUI.Stats.Current[NAGA_BUI.ReportN].endTime-NAGA_BUI.Stats.Current[NAGA_BUI.ReportN].startTime)/1000
	local names		=""
	local time		=""
	local damage	=""
	local dps		=""
	local targets	=0
	local color="|cFEFEFE"
	--Print to the targets window
	for i in pairs(data) do
		if NAGA_BUI.GroupMembers[i] then color="|cEEEE33" data[i].name=NAGA_BUI.GroupMembers[i]
		elseif NAGA_BUI.Player.id==i then color="|cEE3333" data[i].name=NAGA_BUI.Player.name
		else
			targets=targets+1
			names		=names..color..string.sub(zo_strformat("<<!aC:1>>",data[i].name),0,26).."|r\n"
			time		=time..ZO_FormatTime(fighttime ,SI_TIME_FORMAT_TIMESTAMP).."\n"
			damage	=damage..NAGA_BUI.DisplayNumber(data[i].dmg).."\n"
			dps		=dps..NAGA_BUI.DisplayNumber(data[i].dmg/fighttime).."\n"
		end
	end
	--Apply labels
	parent.names:SetText(names)
	parent.time:SetText(time)
	parent.damage:SetText(damage)
	parent.dps:SetText(dps)
	--Update height
	local height=50
	if targets<28 then height=50+(targets * 21) else height=50+(28*21) end
	parent:SetHeight(height) parent.backdrop:SetHeight(height) parent:SetHidden(targets==0)
	if not NAGA_BUI.TargetsWinowLoop then NAGA_BUI.TargetsWinowLoop=true NAGA_BUI.CallLater("TargetsWinow",8000,function() NAGA_BUI.TargetsWinowLoop=false parent:SetHidden(true) end) end
end
--]]
function NAGA_BUI.Damage.Attackers_UI()	--UI init
	local ch,ch1=NAGA_BUI.Vars.FrameHealthColor,NAGA_BUI.Vars.FrameHealthColor1
	local w,h=NAGA_BUI.Vars.AttackersWidth,NAGA_BUI.Vars.AttackersHeight
	local fs=math.min(NAGA_BUI.Vars.RaidFontSize,h*.8)
	local theme_color=NAGA_BUI.Vars.Theme==6 and {1,204/255,248/255,1} or NAGA_BUI.Vars.Theme==7 and NAGA_BUI.Vars.AdvancedThemeColor or NAGA_BUI.Vars.CustomEdgeColor
	local function CrateHitAnimation(control)
		local animation, timeline=CreateSimpleAnimation(ANIMATION_COLOR,control,0)
		animation:SetColorValues(1,.8,.8,1,unpack(ch))
		animation:SetDuration(750)
		timeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT,1)
		return timeline
	end

	local ui	=NAGA_BUI.UI.Control(	"NAGA_Statistics_Attackers",				NAGA_StatisticsLayer,	{w,h*3+8},		NAGA_BUI.Vars.NAGA_Statistics_Attackers or {TOPLEFT,TOP,710/2,5,ZO_CompassFrame},	not (NAGA_BUI.Vars.Attackers and NAGA_BUI.inMenu))
	ui.backdrop	=NAGA_BUI.UI.Backdrop(	"NAGA_Statistics_Attackers_BG",			ui,		"inherit",		{CENTER,CENTER,0,0},	{0,0,0,0.4}, {0,0,0,1}, nil, true)
	ui.label	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Attackers_Label",			ui.backdrop,	"inherit",	{CENTER,CENTER,0,0},	NAGA_BUI.UI.Font("standard",20,true), nil, {1,1}, NAGA_BUI.Loc("Attackers"))
	ui:SetDrawTier(DT_HIGH)
	ui:SetMovable(true)
	ui:SetHandler("OnMouseUp", function(self) NAGA_BUI.Menu:SaveAnchor(self) end)

	local anchor	={TOPLEFT,TOPLEFT,0,0,ui}
	for i=1, 10 do
		ui[i]		=NAGA_BUI.UI.Backdrop("NAGA_Statistics_Attackers"..i.."_Health",		ui,		{w,h},		anchor,			{0,0,0,1}, theme_color, nil, not (i==1 and NAGA_BUI.inMenu)) ui[i]:SetDrawTier(0)
		ui[i].bar	=NAGA_BUI.UI.Statusbar("NAGA_Statistics_Attackers"..i.."_Bar",		ui[i],	{w-4,h-4},		{LEFT,LEFT,2,0},		ch, NAGA_BUI.Textures[NAGA_BUI.Vars.FramesTexture])
--		ui[i].bar:SetGradientColors(ch[1],ch[2],ch[3],ch[4],ch1[1],ch1[2],ch1[3],ch1[4])
		ui[i].name	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Attackers"..i.."_Name",		ui[i],	{w,h},		{LEFT,LEFT,8,0},		NAGA_BUI.UI.Font(NAGA_BUI.Vars.FrameFont1,fs,true), nil, {0,1}, 'Name')
		ui[i].pct	=NAGA_BUI.UI.Label(	"NAGA_Statistics_Attackers"..i.."_Pct",		ui[i],	{w,h},		{RIGHT,RIGHT,-8,0},	NAGA_BUI.UI.Font(NAGA_BUI.Vars.FrameFont2,fs,true), nil, {2,1}, 'Damage')
		ui[i].hit	=CrateHitAnimation(ui[i].bar)
		anchor={TOP,BOTTOM,0,4,ui[i]}
	end
end

local function AttackersUpdate(now,unitId)
	if not NAGA_BUI.Vars.Attackers then return end
	now=now or GetGameTimeMilliseconds()
	local w=NAGA_BUI.Vars.AttackersWidth-4
	local t={}
	for id,data in pairs(NAGA_BUI.Attacker) do
		if data.ms+10000<now then
			NAGA_BUI.Attacker[id]=nil
		else
			table.insert(t,{id=id,name=data.name,ms=data.ms,value=data.value})
		end
	end
	if #t==0 then
		EVENT_MANAGER:UnregisterForUpdate("NAGA_Statistics_Attackers")
		NAGA_Statistics_Attackers:SetHidden(true)
		return
	elseif #t>3 then
		if NAGA_BUI.Vars.DeveloperMode then
			if NAGA_BUI.OnScreen.Message[78] then
				NAGA_BUI.OnScreen.Message[78].units=#t
			else
				NAGA_BUI.OnScreen.Notification(78,"Focused",nil,nil,nil,nil,#t)
			end
		end
	else
		NAGA_BUI.OnScreen.Message[78]=nil
	end
	table.sort(t,function(a,b) return a.value>b.value end)
	local maxValue=t[1].value

	NAGA_Statistics_Attackers:SetHidden(false)
	for i=1,10 do
		if t[i] then
			NAGA_Statistics_Attackers[i].name:SetText(t[i].name or "Unknown")
			NAGA_Statistics_Attackers[i].pct:SetText(t[i].value)
			NAGA_Statistics_Attackers[i].bar:SetWidth(w*t[i].value/maxValue)
			NAGA_Statistics_Attackers[i]:SetAlpha(t[i].ms+5000>now and 1 or .5)
			NAGA_Statistics_Attackers[i]:SetHidden(false)
			if t[i].id==unitId then
				NAGA_Statistics_Attackers[i].hit:PlayFromStart()
			end
		else
			NAGA_Statistics_Attackers[i]:SetHidden(true)
		end
	end
	EVENT_MANAGER:RegisterForUpdate("NAGA_Statistics_Attackers", 1000, AttackersUpdate)
end

function NAGA_BUI.Damage.New(result,abilityName,sourceName,sourceType,targetName,hitValue,powerType,damageType,sourceUnitId,targetUnitId,abilityId,isDamage)
	local now=GetGameTimeMilliseconds()
--	d(targetName.." ("..targetUnitId..") hit for "..hitValue.." by "..zo_strformat("<<!aC:1>>",sourceName).." ("..sourceUnitId..")")
	if abilityId==76325 then NAGA_BUI.BladeOfWoe=now return end --Blade of Woe
	--Compute some flags
	local Outgoing=(sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET) and targetName~=NAGA_BUI.Player.name
	local isCrit=(result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_DOT_TICK_CRITICAL or result==ACTION_RESULT_HOT_TICK_CRITICAL)
	local isHeal=(result==ACTION_RESULT_HEAL or result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK or result==ACTION_RESULT_HOT_TICK_CRITICAL)
	local isPower=(result==ACTION_RESULT_POWER_ENERGIZE or result==ACTION_RESULT_POWER_DRAIN)

	--Register Group Damage
	if not isPower then
		if not isHeal then
			if targetName==NAGA_BUI.Player.name then	--Incoming damage
				if sourceName=="" then sourceName=NAGA_BUI.Enemy[sourceUnitId] else sourceName=string.gsub(sourceName,"%^%w+","") end
				if NAGA_BUI.Vars.Log then
--					if NAGA_BUI.GroupMembers[targetUnitId] then targetName=NAGA_BUI.GroupMembers[targetUnitId] end
					local color=isHeal and 3 or isCrit and 4 or 5
					table.insert(NAGA_BUI.Log,{now,zo_strformat("<<!aC:1>>",sourceName),targetName,abilityId,result,hitValue,color})
				end
				if not NAGA_BUI.Attacker[sourceUnitId] then
					NAGA_BUI.Attacker[sourceUnitId]={name=sourceName,ms=now,value=hitValue}
				else
					NAGA_BUI.Attacker[sourceUnitId].value=NAGA_BUI.Attacker[sourceUnitId].value+hitValue
					NAGA_BUI.Attacker[sourceUnitId].ms=now
				end
				AttackersUpdate(now,(result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_DAMAGE) and sourceUnitId or nil)
			elseif NAGA_BUI.GroupMembers[targetUnitId]==nil then
				NAGA_BUI.Stats.GroupLog.Damage.Total=NAGA_BUI.Stats.GroupLog.Damage.Total+hitValue
--[[				--Targets developer dindow
				if (NAGA_BUI.Stats.GroupLog.Damage[targetUnitId]==nil) then
					NAGA_BUI.Stats.GroupLog.Damage[targetUnitId]={["name"]=targetName,["dmg"]=hitValue}
					--d(targetName.." ("..targetUnitId..") hit for "..hitValue.." by '"..zo_strformat("<<!aC:1>>",sourceName).."'")
				else
					NAGA_BUI.Stats.GroupLog.Damage[targetUnitId].name=(targetName~="") and targetName or NAGA_BUI.Stats.GroupLog.Damage[targetUnitId].name
					NAGA_BUI.Stats.GroupLog.Damage[targetUnitId].dmg=NAGA_BUI.Stats.GroupLog.Damage[targetUnitId].dmg+hitValue
					--d(targetName.." ("..targetUnitId..") hit for "..hitValue.." by '"..zo_strformat("<<!aC:1>>",sourceName).."' total "..NAGA_BUI.Stats.GroupLog.Damage[targetUnitId].dmg)
				end
				NAGA_BUI.Damage:TargetsDeveloperWindowUpdate()
--]]
			end
		elseif (targetName==NAGA_BUI.Player.name or NAGA_BUI.GroupMembers[targetUnitId]) then
			NAGA_BUI.Stats.GroupLog.Healing.Total=NAGA_BUI.Stats.GroupLog.Healing.Total+hitValue
--			d(targetName.." ("..targetUnitId..") heal for "..hitValue.." by '"..zo_strformat("<<!aC:1>>",sourceName).."' total "..NAGA_BUI.Stats.GroupLog.Healing.Total)
		end
	end

	--Debugging
--	d(result .. " || " .. sourceType .. " || " .. sourceName .. " || " .. targetName .. " || " .. abilityName .. " || " .. hitValue)
--[[
	--Misses and Dodges
	if (result==ACTION_RESULT_DODGED or result==ACTION_RESULT_MISS) then
	--Crowd Controls
	elseif (result==ACTION_RESULT_INTERRUPT or result==ACTION_RESULT_STUNNED or result==ACTION_RESULT_OFFBALANCE or result==ACTION_RESULT_DISORIENTED or result==ACTION_RESULT_STAGGERED or result==ACTION_RESULT_FEARED or result==ACTION_RESULT_SILENCED or result==ACTION_RESULT_ROOTED) then
	--Target Death
	elseif (result==ACTION_RESULT_DIED or result==ACTION_RESULT_DIED_XP) then
	--DEBUG NEW EVENTS
	elseif (result==ACTION_RESULT_EFFECT_FADED and NAGA_BUI.Vars.DeveloperMode) then
		local _name=" ["..abilityId.."]"..abilityName local direction=damageIn and "Incoming" or "Outgoing"
		d(direction .. " effect faded: " .. targetName .. " Value: " .. hitValue.._name)
	elseif (result==ACTION_RESULT_EFFECT_GAINED and NAGA_BUI.Vars.DeveloperMode) then
		local _name=" ["..abilityId.."]"..abilityName local direction=damageIn and "Incoming" or "Outgoing"
		d(direction .. " effect gained: " .. targetName .. " Value: " .. hitValue.._name)
	elseif (result==ACTION_RESULT_EFFECT_GAINED_DURATION and NAGA_BUI.Vars.DeveloperMode) then
		local _name=" ["..abilityId.."]"..abilityName local direction=damageIn and "Incoming" or "Outgoing"
		d(direction .. " effect duration: " .. targetName .. " Value: " .. hitValue.._name)
		if abilityId==21230 then NAGA_BUI.Actions.EnchantmentBerserk=true end
	elseif (hitValue>4 and NAGA_BUI.Vars.DeveloperMode) then
		--Prompt other unrecognized
		local direction=Outgoing and "Outgoing" or "Incoming"
		d(direction .. " result " .. result .. " not recognized! Target: " .. targetName .. " Value: " .. hitValue)
	end
--]]
	--Statistics
	if	(isDamage and Outgoing) or	--Damage dealt
		(isDamage and targetName==NAGA_BUI.Player.name) or	--Damage received
		(isPower and targetName==NAGA_BUI.Player.name) or	--Power gain
		(isHeal and (sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET)) then	--Healing dealt
		--InCombatReticle
		if isDamage then	--NAGA_BUI.Vars.InCombatReticle and
			NAGA_BUI.Damage.last=now
--			if (now-NAGA_BUI.Damage.last-10000)>0 then
--				d("["..abilityId.."] "..abilityName.."||"..tostring(sourceName).."||"..tostring(targetName).."||"..tostring(sourceType))
--				NAGA_BUI.Damage.last=now NAGA_BUI.InCombatReticle(true) else NAGA_BUI.Damage.last=now end
		end
		--Flag timestamps
--		if Outgoing then NAGA_BUI.Damage.lastOut=now else NAGA_BUI.Damage.lastIn=now end
		--Split elements
		if NAGA_BUI.Vars.StatsSplitElements then if damageType~=2 and Multy_element[abilityName] then abilityName=abilityName.." ("..Element[damageType]..")" end
		else if Multy_element[abilityName] then damageType=DAMAGE_TYPE_MAGIC end end
		if AdditionalAbilityName[abilityId] then abilityName=abilityName..AdditionalAbilityName[abilityId] end
		--Statistics
		NAGA_BUI.Stats.RegisterDamage({
			out		=Outgoing,
			target	=targetName,
			source	=sourceName,
			ability	=abilityName,
			value		=hitValue,
			powerType	=powerType,
			ms		=now,
			crit		=isCrit,
			heal		=isHeal,
			power		=isPower,
			damageType	=damageType,
			id		=abilityId,
		})
	end
end

function NAGA_BUI.Damage.Initialize()
	--Set up initial timestamps
--	NAGA_BUI.Damage.lastIn	=0
--	NAGA_BUI.Damage.lastOut=0
	NAGA_BUI.Damage.last=0
	local attacks={
		--Multy element attacks
		7880,				--Light Attack
		7095,				--Heavy Attack
		48991,46340,48971,	--Force Shock
		80526,			--Ilambris
		}
	for i=1, #attacks do Multy_element[GetAbilityName(attacks[i])]=true end
	NAGA_BUI.Damage.Attackers_UI()
end

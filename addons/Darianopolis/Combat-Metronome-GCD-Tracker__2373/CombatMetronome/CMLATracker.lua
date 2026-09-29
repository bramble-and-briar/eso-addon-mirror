local CM = CombatMetronome
CM.LATracker = CM.LATracker or {}
local LATracker = CM.LATracker
CombatMetronome.SV = CombatMetronome.SV or {}

local NumLA = 0
local TimeOfLastLA = 0
local TimeBetweenLA = 0
local LightAttacksPerSecond = 0

function LATracker:HandleLightAttacks(time)
	if CombatMetronome.SV.LATracker.hideInPVP and CM.inPVPZone then
		return
	else
		LATracker:NumberOfLightAttacks(time)
		LATracker:TimeBetweenLightAttacks(time)
		LATracker:CalculateLightAttacksPerSecond(time)
		LATracker:DisplayText()
	end
end

function LATracker:NumberOfLightAttacks(time)
	if not self.combatStart then self.combatStart = time end
	
	NumLA = NumLA + 1
end

function LATracker:TimeBetweenLightAttacks(time)
	if TimeOfLastLA ~= 0 then
		TimeBetweenLA = time - TimeOfLastLA
	else
		TimeBetweenLA = 0
	end
	TimeOfLastLA = time
end

function LATracker:CalculateLightAttacksPerSecond(time)
	if NumLA ~= 0 and self.combatStart then
		if self.combatStart ~= time then
			LightAttacksPerSecond = (NumLA * 1000) / (time - self.combatStart)
		end
	end
end

function LATracker:DisplayText()
	if CombatMetronome.SV.LATracker.choice == "Nothing" then
		LATracker.label:SetHidden(true)
	elseif self.combatStart or CombatMetronome.SV.LATracker.isUnlocked or CombatMetronome.SV.LATracker.timeTilHiding == 0 then
		LATracker.label:SetHidden(false)
		if CombatMetronome.SV.LATracker.choice == "Time between light attacks" then
			LATracker.label:SetText(TimeBetweenLA.." ms")
		elseif CombatMetronome.SV.LATracker.choice == "la/s" then
			if NumLA ~= 0 and LightAttacksPerSecond == 0 then
				LATracker.label:SetText("∞ la/s")
			else
				LATracker.label:SetText(string.format("%.2f", LightAttacksPerSecond).." la/s")
			end
		end
	elseif CombatMetronome.SV.LATracker.timeTilHiding > 0 then
		zo_callLater(function()
			if CombatMetronome.SV.LATracker.timeTilHiding > 0 and CM.inCombat == false then
				LATracker.label:SetHidden(true)
			end
		end,
		CombatMetronome.SV.LATracker.timeTilHiding*1000)
	end
end	

function LATracker:StartLATracker()
	if not self.combatStart then
		self.combatStart = GetGameTimeMilliseconds()
	end
	self:DisplayText()
end

function LATracker:ResetLATracker()
	LATracker:CalculateLightAttacksPerSecond(GetGameTimeMilliseconds())
	LATracker:DisplayText()
	if CombatMetronome.SV.LATracker.showLALogAfterFight then
		CombatMetronome.debug:Print("End of combat")
		CombatMetronome.debug:Print("You've been in combat for "..((GetGameTimeMilliseconds()-self.combatStart)/1000).."s")
		CombatMetronome.debug:Print("Total amount of light attacks: "..NumLA)
		CombatMetronome.debug:Print("This equals to "..string.format("%.2f", LightAttacksPerSecond).." la/s")
	end
	if NumLA ~= 0 then NumLA = 0 end
	if TimeOfLastLA ~= 0 then TimeOfLastLA = 0 end
	if TimeBetweenLA ~= 0 then TimeBetweenLA = 0 end
	if LightAttacksPerSecond ~= 0 then LightAttacksPerSecond = 0 end
	self.combatStart = nil
	if CombatMetronome.SV.LATracker.timeTilHiding > 0 then
		zo_callLater(function()
			if CombatMetronome.SV.LATracker.timeTilHiding > 0 and CM.inCombat == false then
				LATracker.label:SetHidden(true)
			end
		end,
		CombatMetronome.SV.LATracker.timeTilHiding*1000)
	end
end

function LATracker:ManageLATracker(inCombat)
	if not inCombat and LATracker.combatStart then LATracker:ResetLATracker() end
	if inCombat and not LATracker.combatStart then LATracker:StartLATracker() end
end
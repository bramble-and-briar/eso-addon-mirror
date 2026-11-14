-- KelaPadUI companion information and rapport notifications.
-- Extracted from KelaPadUI.lua during the refactor; behavior is unchanged.

local COMPANION_RAPPORT_EVENT_NAMESPACE = "KelaPadUI_CompanionRapport"

local function Set_Companion_Notifications()
	local maxRapport = GetMaximumRapport()
	local stopNotifyRapportLevel = 4000 -- Stop notifying once both rapport values reach the Companion tier.
	
	EVENT_MANAGER:RegisterForEvent(COMPANION_RAPPORT_EVENT_NAMESPACE, EVENT_COMPANION_RAPPORT_UPDATE, function(_, companionId, previousRapport, currentRapport)
		if currentRapport < stopNotifyRapportLevel or previousRapport < stopNotifyRapportLevel then
			CHAT_ROUTER:AddSystemMessage(zo_strformat(
				"<<1>> <<2>>: <<3>> <<4>>",
				os.date("[%H:%M:%S]", GetTimeStamp()),
				GetString(SI_COMPANION_OVERVIEW_RAPPORT),
				GetCompanionName(companionId),
				string.format("%+d (%d/%d)", currentRapport - previousRapport, currentRapport, maxRapport)
			))
		end
	end)
end

-- Adds companion rapport numbers to the companion information UI
-- Companion Rapport Levels
-- -5000 to -4000: Disdainful - Companion feels nothing but contempt for you.
-- -3999 to -2500: Irritated - Companion strongly dislikes you.
-- -2499 to 749:   Wary - Companion tolerates you.
--   750 to 999:   Cordial - Companion counts you as a friendly acquaintance.
--  1000 to 1999:  Friendly - Companion respects you as an ally. (5% companion experience bonus) [1st quest]
--  2000 to 2999:  Close - Companion greatly admires you (10% companion experience bonus) [2nd quest, last for Bastion & Mirri]
--  3000 to 3999:  Allied - Companion holds you in high esteem. (15% companion experience bonus) [3rd quest, final]
--  4000 to 5500:  Companion - Companion regards you as their greatest ally and dearest friend. (20% companion experience bonus)
local function Add_Enhanced_Companion_Information()
	local maxRapport = GetMaximumRapport()

	-- Modify companion information UI: Gamepad UI
	SecurePostHook(ZO_Tooltip, "LayoutCompanionOverview", function( self, companionData )
		-- What companion is active
		local activeCompanionID = GetActiveCompanionDefId()
		local activeCompanionName = zo_strformat(SI_COMPANION_NAME_FORMATTER, GetCompanionName(activeCompanionID))
		
		-- Get companion rapport information
		local rapportLevel = GetActiveCompanionRapportLevel()
		local currentRapport = GetActiveCompanionRapport()
		local percentageRapport = zo_floor(currentRapport / maxRapport * 100)
		local rapportDescription2 = string.format("%d: %d / %d (%d%%)", rapportLevel, currentRapport, maxRapport, percentageRapport)

		-- Add New Section containing the companion rapport numbers
		local rapportStatusSection = self:AcquireSection(self:GetStyle("companionOverviewStatValueSection"))
		local rapportStatusPair = rapportStatusSection:AcquireStatValuePair(self:GetStyle("statValuePair"))
		rapportStatusPair:SetStat("Rapport Level", self:GetStyle("statValuePairStat")) --GetString(SI_COMPANION_RAPPORT_STATUS)
		rapportStatusPair:SetValue(rapportDescription2, self:GetStyle("statValuePairValue"))
		rapportStatusSection:AddStatValuePair(rapportStatusPair)
		self:AddSection(rapportStatusSection)
		
		-- Add Additional Rapport Information
		local rapportBodySection2 = self:AcquireSection(self:GetStyle("companionOverviewBodySection"))
		rapportBodySection2:AddLine("Notable Rapport Stages", self:GetStyle("statValuePairStat"))
		rapportBodySection2:AddLine("1000: Friendly (1st Personal Quest)", self:GetStyle("statValuePairValue"))
		rapportBodySection2:AddLine("2000: Close (2nd Personal Quest, Final quest for Mirri and Bastion)", self:GetStyle("statValuePairValue"))
		rapportBodySection2:AddLine("3000: Allied (3rd Personal Quest)", self:GetStyle("statValuePairValue"))
		rapportBodySection2:AddLine("4000: Companion", self:GetStyle("statValuePairValue"))

		-- Add Companion Specific Sources of Rapport
		rapportBodySection2:AddLine(zo_strformat("Sources of Rapport for "..activeCompanionName.." ["..activeCompanionID.."]"), self:GetStyle("statValuePairStat"))
		if KELA_COMPANION_DATA[activeCompanionID] then
			for idx, val in ipairs(KELA_COMPANION_DATA[activeCompanionID]) do
				if string.sub(val, 1, 1) == "-" then
					rapportBodySection2:AddLine(zo_strformat("|cFF6666"..val.."|r"), self:GetStyle("statValuePairValue"))
				else
					rapportBodySection2:AddLine(zo_strformat(val), self:GetStyle("statValuePairValue"))
				end
			end
		else
			CHAT_ROUTER:AddSystemMessage("KPUI WARNING: Could not get companion info for " .. activeCompanionName .. " with ID " .. activeCompanionID)
		end
		self:AddSection(rapportBodySection2)

	end)

	Set_Companion_Notifications()

end


-- UNDAUNTED PLEDGES


function KelaSetupCompanionInfo()
    Add_Enhanced_Companion_Information()
end

-- -----------------------------------------------------------
-- AddOn "Port to Jo" by  Tazmyr
-- -----------------------------------------------------------

-- Initialize Addon
PortToJo 		= {}
PortToJo.Name 		= "PortToJo"
PortToJo.Version 	= "3.10"
PortToJo.Author 	= "Tazmyr"
PTJ 			= PortToJo

-- REMINDER !!!!!!!!!!! reset prior to release ===============
	PTJ.DebugFlag	    = false			-- debug flag

-- Set Variables/Constants:
-- (this ties to the keybinding in the PortToJo.xml file, and is the *Displayed* Text for it
	PTJ.KeybindingTextLeader			= "Port to Jo (Group Leader)"
	PTJ.KeybindingTextPartner			= "Port to Jo (Partner)"

	PTJ.Me						= GetUnitName("player")	-- get own player name

-- wait to start until addon is fully loaded
local function ptj_OnAddOnLoaded(event, addonName)
	if addonName ~= PTJ.Name then return end
	--if loaded, unregister the loaded check
	EVENT_MANAGER:UnregisterForEvent(PTJ.Name, EVENT_ADD_ON_LOADED)

	-- Initialize variables ----------------------------------
	local PTJ			= PTJ

	-- Register Slash command
	PTJ.ptjSlashCommand = ptjSlashCommand
	PTJ.ptpSlashCommand = ptpSlashCommand
	SLASH_COMMANDS["/ptj"] = ptjSlashCommand
	SLASH_COMMANDS["/ptp"] = ptpSlashCommand

	-- Register Keybindings ...
	ZO_CreateStringId("SI_BINDING_NAME_PORT_TO_JO", PTJ.KeybindingTextLeader)
	ZO_CreateStringId("SI_BINDING_NAME_PORT_TO_JO-Partner", PTJ.KeybindingTextPartner)

end

-- Startup ... register for load event 
EVENT_MANAGER:RegisterForEvent(PTJ.Name, EVENT_ADD_ON_LOADED, ptj_OnAddOnLoaded)


-- ========= Process inbound /ptj slash command ==================
-- Process slash command ... Jump to Group Leader
function ptjSlashCommand(ptjSlashOptions)
	if PTJ.DebugFlag then
		d("PTJ-Debug: /ptj triggered..") 
	end
	ptjPortToLeader()	
end

-- Process slash command ... Jump to Group Partner
function ptpSlashCommand(ptpSlashOptions)
	if PTJ.DebugFlag then
		d("PTJ-Debug: /ptp triggered..") 
	end
	ptjPortToPartner()	
end

-- ========= Process ptJ Keypress  =================
function PTJ.ptjKeypress()
	if PTJ.DebugFlag then
		d("PTJ-Debug: Leader Keypress...") 
	end
	ptjPortToLeader()	
end

-- ========= Process ptP Keypress  =================
function PTJ.ptpKeypress()
	if PTJ.DebugFlag then
		d("PTP-Debug: Partner Keypress...") 
	end
	ptjPortToPartner()	
end

-- ========== PORT to Leader! =================
function ptjPortToLeader()
	-- Port to Group leader
	if PTJ.DebugFlag then
		d("PTJ: Attempting Port to group leader...")
	end
	JumpToGroupLeader()
end

-- ========== PORT to partner! =================
function ptjPortToPartner()
	-- Port to Group leader
	if PTJ.DebugFlag then
		d("PTJ: Attempting Port to partner...")
		d("Group1: " .. GetUnitName("group1"))
		d("Group2: " .. GetUnitName("group2"))
		d("Me:" .. PTJ.Me)
	end
	-- If group size is 2, port to partner, else display message
	if GetGroupSize() == 2 then
		if GetUnitName("group1") == PTJ.Me then -- if I am group member 1, port to other group member
			JumpToGroupMember(GetUnitName("group2")) 
		else
			JumpToGroupMember(GetUnitName("group1"))
		end
	else
		-- display message in Alerts field (top-right)
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, "Port-to-Jo: Must be a 2-person group")
	end
end

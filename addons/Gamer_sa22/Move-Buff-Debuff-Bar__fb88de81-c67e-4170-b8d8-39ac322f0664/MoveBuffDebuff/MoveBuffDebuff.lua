MoveBuffDebuff = {}

MoveBuffDebuff.name = "MoveBuffDebuff"
MoveBuffDebuff.version = 1
MoveBuffDebuff.defaultCharacter = 
{	
	["offsetY"] = 325,
	["offsetX"] = 0,
	["alignment"] = {
		["name"] = "Center",
		["data"] = CENTER,
	},
	["useCharacterSettings"] = false,
	["IconDirHorz"] = {["name"]="Right", ["data"]=1},
	["IconDirVert"] = {["name"]="Down", ["data"]=1},
	["IconRow"] = 0,
	["IconSpaceX"] = 8,
	["IconSpaceY"] = 8,
}
MoveBuffDebuff.default = {
	["accountWideProfile"] = MoveBuffDebuff.defaultCharacter,
}

function MoveBuffDebuff.GetSettings()
	if MoveBuffDebuff.charSavedVars.useCharacterSettings then
		return MoveBuffDebuff.charSavedVars
	else
		return MoveBuffDebuff.savedvars.accountWideProfile
	end
end

function MoveBuffDebuff.ApplyAnchor()
	ZO_BuffDebuffTopLevelSelfContainer:ClearAnchors()	
	ZO_BuffDebuffTopLevelSelfContainer:SetAnchor(MoveBuffDebuff.GetSettings().alignment.data, GuiRoot, 0, MoveBuffDebuff.GetSettings().offsetX, MoveBuffDebuff.GetSettings().offsetY)	
end	

local BuffDebuffBarInMenu = false
local thebuffDebuffContainer=nil
local ICON_SIZE = ZO_BUFF_DEBUFF_FRAME_DIMENSIONS_GAMEPAD 


local function ApplyGrid()
	local ICONS_PER_ROW = MoveBuffDebuff.GetSettings().IconRow
	if ICONS_PER_ROW == 0 or nil then return end

	local total = 0
	local pools={thebuffDebuffContainer.buffPool, thebuffDebuffContainer.debuffPool}
	
	for _,pool in ipairs(pools) do
		local activeControls = pool:GetActiveObjects()
		local orderedBuffs = {}
		
		for _, buffControl in pairs(activeControls) do
			table.insert(orderedBuffs, buffControl)
		end
		table.sort(orderedBuffs, function(a, b)
			return a:GetLeft() < b:GetLeft()
		end)
		local index=0
		-- 4. Apply your custom 5-across grid math
		for i, buffControl in ipairs(orderedBuffs) do
			index = total+( i - 1 )
			
			local row = math.floor(index / ICONS_PER_ROW)
			local col = index % ICONS_PER_ROW

			local offsetX = col * (ICON_SIZE + MoveBuffDebuff.GetSettings().IconSpaceX)
			local offsetY = row * (ICON_SIZE + MoveBuffDebuff.GetSettings().IconSpaceY)

			-- Wipe the vanilla anchor and set the grid anchor
			buffControl:ClearAnchors()
			buffControl:SetAnchor(TOPLEFT, thebuffDebuffContainer.control, TOPLEFT, MoveBuffDebuff.GetSettings().IconDirHorz.data * offsetX, MoveBuffDebuff.GetSettings().IconDirVert.data * offsetY)
		end
		total=index+1
	end
end

function MoveBuffDebuff.BuildSettings()
	local LHAS = LibHarvensAddonSettings
		
    local options = {
        allowDefaults = true,
		allowRefresh = false,
		defaultsFunction = function()      
		d("MoveBuffDebuff Reset")
        end,
    }
    
    local settings = LHAS:AddAddon("Move Buff Debuff", options)
    if not settings then
        return
    end
	--On/Off for Character Settings
    local checkbox = {
        type = LHAS.ST_CHECKBOX,
        label = "Use character settings", 
		--default = false, 
        setFunction = function(value)
           MoveBuffDebuff.charSavedVars.useCharacterSettings = value
        end,
        getFunction = function()
            return MoveBuffDebuff.charSavedVars.useCharacterSettings
        end,
    }
    settings:AddSetting(checkbox)
	local scene
	local function addBuffDebuffBar()
		if BuffDebuffBarInMenu then
			return
		end
		scene = SCENE_MANAGER:GetCurrentScene()					
		scene:AddFragment(BUFF_DEBUFF_FRAGMENT)
		BUFF_DEBUFF_FRAGMENT:Refresh()
		ZO_BuffDebuffTopLevelSelfContainer:SetHidden(false)	
		BuffDebuffBarInMenu = true	
	end
	
	local function addonSelected(_, addonSettings)
		local addBuffDebuffBar = addonSettings == settings
		if not addBuffDebuffBar and BuffDebuffBarInMenu then	
			scene:RemoveFragment(BUFF_DEBUFF_FRAGMENT)
			BUFF_DEBUFF_FRAGMENT:Refresh()
			BuffDebuffBarInMenu = false
		end
	end
		
	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", addonSelected)

	local button = {
        type = LHAS.ST_BUTTON,
        label = "Show Buff Debuff Bar NOW",		
        buttonText = "Show",
        clickHandler = function(control, button)
			if not BuffDebuffBarInMenu then
				addBuffDebuffBar()
			else
				addonSelected()
			end
        end,
    }
	settings:AddSetting(button)
	 local Alainment={
			type = LHAS.ST_DROPDOWN,
			label = "Align Bar",
			items = {{
				name = "Center",
				data = CENTER
			},{
				name = "Right",
				data = RIGHT
			},{
                name = "Left",
                data = LEFT
			},{
                name = "Bottom",
                data = BOTTOM
            },},
			default = "Center",
			getFunction = function()
				return MoveBuffDebuff.GetSettings().alignment.name
			end,
			setFunction = function(combobox, name, item)
				MoveBuffDebuff.GetSettings().alignment = item
				MoveBuffDebuff.ApplyAnchor()
			end
		}
	settings:AddSetting(Alainment)
	
	--Slider to Adjust BuffDebuff Bar's Y Position
    local slider = {
        type = LHAS.ST_SLIDER,
        label = "Up <- -> Down",
		tooltip = "Default: 325",
        setFunction = function(value)
            MoveBuffDebuff.GetSettings().offsetY = value
			MoveBuffDebuff.ApplyAnchor()
        end,
        getFunction = function()
            return MoveBuffDebuff.GetSettings().offsetY
        end,
        default = 325,
        min = -1000,
        max = 1000,
        step = 5
    }
    settings:AddSetting(slider)
	--X value
	 local slider = {
        type = LHAS.ST_SLIDER,
        label = "Left <- -> Right",
		tooltip = "Default is 0",
        setFunction = function(value)
            MoveBuffDebuff.GetSettings().offsetX = value
			MoveBuffDebuff.ApplyAnchor()
        end,
        getFunction = function()
            return MoveBuffDebuff.GetSettings().offsetX
        end,
        default = 0,
        min = -1550,
        max = 1550,
        step = 5
    }
    settings:AddSetting(slider)
	
	local section = {
        type = LHAS.ST_SECTION,
        label = "EXPERIMENTAL",
    }
    settings:AddSetting(section)
	local Alainment={
		type = LHAS.ST_DROPDOWN,
		label = "Horizontal Direction",
		items = {
			{["name"]="Left", ["data"]=-1}, 
			{["name"]="Right", ["data"]=1},
		},
		default = "Right",
		getFunction = function()
			return MoveBuffDebuff.GetSettings().IconDirHorz.name
		end,
		setFunction = function(combobox, name, item)
			MoveBuffDebuff.GetSettings().IconDirHorz = item
			ApplyGrid()
		end
	}
	settings:AddSetting(Alainment)
	 local Alainment={
			type = LHAS.ST_DROPDOWN,
			label = "Vertical Direction",
			items = {
				{["name"]="Up", ["data"]=-1}, 
				{["name"]="Down", ["data"]=1},
			},
			default = "Down",
			getFunction = function()
				return MoveBuffDebuff.GetSettings().IconDirVert.name
			end,
			setFunction = function(combobox, name, item)
				MoveBuffDebuff.GetSettings().IconDirVert = item
				ApplyGrid()
			end
		}
	settings:AddSetting(Alainment)
    local slider = {
        type = LHAS.ST_SLIDER,
        label = "Buff's Per Row",
		tooltip = "Default: 0",
        setFunction = function(value)
            MoveBuffDebuff.GetSettings().IconRow = value
			ApplyGrid()		
        end,
        getFunction = function()
            return MoveBuffDebuff.GetSettings().IconRow
        end,
        default = 0,
        min = 0,
        max = 20,
        step = 1,
    }
    settings:AddSetting(slider)
	
	local slider = {
        type = LHAS.ST_SLIDER,
        label = "Spacing X",
		tooltip = "Default is 8",
        setFunction = function(value)
            MoveBuffDebuff.GetSettings().IconSpaceX = value
			ApplyGrid()
        end,
        getFunction = function()
            return MoveBuffDebuff.GetSettings().IconSpaceX
        end,
        default = 8,
        min = 0,
        max = 50,
        step = 1,
    }
    settings:AddSetting(slider)
	
	local slider = {
        type = LHAS.ST_SLIDER,
        label = "Spacing Y",
		tooltip = "Default is 8",
        setFunction = function(value)
            MoveBuffDebuff.GetSettings().IconSpaceY = value
			ApplyGrid()
        end,
        getFunction = function()
            return MoveBuffDebuff.GetSettings().IconSpaceY
        end,
        default = 8,
        min = 0,
        max = 50,
        step = 1,
    }
    settings:AddSetting(slider)
end



function MoveBuffDebuff.Initialize()
	--Load up, those Saved Vars
	local serverName = GetWorldName()
	MoveBuffDebuff.savedvars = ZO_SavedVars:NewAccountWide("MoveBuffDebuffSavedVariables", MoveBuffDebuff.version, serverName, MoveBuffDebuff.default)
	MoveBuffDebuff.charSavedVars = ZO_SavedVars:NewCharacterIdSettings("MoveBuffDebuffSavedVariables",MoveBuffDebuff.version, serverName, MoveBuffDebuff.savedvars.accountWideProfile) 	
	zo_callLater(function() MoveBuffDebuff.ApplyAnchor() end, 200) --move to saved position	
	SecurePostHook(BUFF_DEBUFF.containerObjectsByUnitTag["player"], "Update",function(self) thebuffDebuffContainer = self ApplyGrid() end)
	MoveBuffDebuff.BuildSettings()
end
function MoveBuffDebuff.OnAddOnLoaded(event, addonName)
	if addonName == MoveBuffDebuff.name then
		MoveBuffDebuff.Initialize()		
		EVENT_MANAGER:UnregisterForEvent(MoveBuffDebuff.name, EVENT_ADD_ON_LOADED)
	end
end
 
EVENT_MANAGER:RegisterForEvent(MoveBuffDebuff.name, EVENT_ADD_ON_LOADED, MoveBuffDebuff.OnAddOnLoaded)

--HUGE thanks to Dolgubon for helping me working out on how to do this
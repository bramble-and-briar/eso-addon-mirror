local Public = { }
LibCombatAlerts = Public


--------------------------------------------------------------------------------
-- Internal Components
--------------------------------------------------------------------------------

local Internal = {
	name = "LibCombatAlerts",
}
LibCombatAlertsInternal = Internal

do
	local cachedPath = nil

	local function GetRootPath( )
		local prefix = "user:/addons/"

		local am = GetAddOnManager()
		for i = 1, am:GetNumAddOns() do
			if (am:GetAddOnInfo(i) == Internal.name) then
				local path = am:GetAddOnRootDirectoryPath(i)
				if (zo_strlower(zo_strsub(path, 1, zo_strlen(prefix))) == prefix) then
					return zo_strsub(path, zo_strlen(prefix), -1)
				end
			end
		end

		-- Fallback
		return string.format("/%s/", Internal.name)
	end

	function Internal.GetRootPath( )
		if (not cachedPath) then
			cachedPath = GetRootPath()
		end
		return cachedPath
	end
end

do
	local scratch
	function Internal.GetScratchTable( )
		scratch = Public.PrepareScratchTable(scratch)
		return scratch
	end
end


--------------------------------------------------------------------------------
-- Base Object for Controls
--------------------------------------------------------------------------------

do
	local BaseControlObject = ZO_Object:Subclass()
	local nextUniqueId = 1

	function BaseControlObject:New( prefix )
		local obj = ZO_Object.New(self)
		obj.ID = string.format("%s_%d", prefix, nextUniqueId)
		nextUniqueId = nextUniqueId + 1
		return obj
	end

	function BaseControlObject:GetId( )
		return self.ID
	end

	Internal.BaseControlObject = BaseControlObject
end

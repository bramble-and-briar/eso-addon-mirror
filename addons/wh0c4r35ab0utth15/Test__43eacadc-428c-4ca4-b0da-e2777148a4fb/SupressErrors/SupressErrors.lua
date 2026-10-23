EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)

local function OnLuaError(_, errorString, errorCode)
end

EVENT_MANAGER:RegisterForEvent("SuppressErrors", EVENT_LUA_ERROR, OnLuaError)

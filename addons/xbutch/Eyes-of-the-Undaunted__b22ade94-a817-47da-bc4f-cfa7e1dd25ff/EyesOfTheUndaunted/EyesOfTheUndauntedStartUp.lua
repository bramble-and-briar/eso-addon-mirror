local C = EOTU_Config or { ADDON_NAME = "EyesOfTheUndaunted", NAME_SHORT = "EOTU", VERSION = "1.51.01" }
local previous = _G[C.NAME_SHORT] or EOTU
local EyesOfTheUndaunted = ZO_InitializingObject:Subclass()

EyesOfTheUndaunted.addOnName = C.ADDON_NAME
EyesOfTheUndaunted.addOnDisplayName = C.DISPLAY_NAME or "Eyes of the Undaunted"
EyesOfTheUndaunted.APIVersion = GetAPIVersion()
EyesOfTheUndaunted.internal = type(previous) == "table" and previous.internal or {}

local function GetAddOnInfos()
    local addOnManager = GetAddOnManager()
    for i = 1, addOnManager:GetNumAddOns() do
        local name, _, author = addOnManager:GetAddOnInfo(i)
        if name == EyesOfTheUndaunted.addOnName then
            return author, addOnManager:GetAddOnVersion(i)
        end
    end
end
EyesOfTheUndaunted.author, EyesOfTheUndaunted.addOnVersion = GetAddOnInfos()
EyesOfTheUndaunted.version = C.VERSION or "1.51.01"

if type(previous) == "table" then
    setmetatable(EyesOfTheUndaunted, { __index = previous })
end
_G[C.NAME_SHORT] = EyesOfTheUndaunted
if _G[C.NAME_SHORT].dbg then
    _G[C.NAME_SHORT].dbg("Startup completed. Version " .. tostring(_G[C.NAME_SHORT].version))
end

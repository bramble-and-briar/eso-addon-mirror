local AH = _G.EASArchiveHelper
local EPC = ESOProgressionCoach
if not AH or AH._suiteInitRegistered then return end
AH._suiteInitRegistered = true

local function deepFill(dst, src)
    for k,v in pairs(src or {}) do
        if type(v)=="table" then
            if type(dst[k])~="table" then dst[k]={} end
            deepFill(dst[k],v)
        elseif dst[k]==nil then dst[k]=v end
    end
end

local function init()
    if AH._suiteInitialized then return end
    if not EPC or not EPC.saved then return end
    EPC.saved.infiniteArchiveHelper = EPC.saved.infiniteArchiveHelper or {}
    deepFill(EPC.saved.infiniteArchiveHelper, AH.Defaults)
    AH.Vars = EPC.saved.infiniteArchiveHelper
    AH.Vars.AutoCheck = AH.Vars.AutoCheck ~= false
    AH.SELECTOR_SHORT = string.format("ZO_EndDunBuffSelector_%s", IsInGamepadPreferredMode() and "Gamepad" or "Keyboard")
    AH.SELECTOR = string.format("ZO_EndlessDungeonBuffSelector_%s", IsInGamepadPreferredMode() and "Gamepad" or "Keyboard")
    AH.SELECTOR_OBJECT = string.format("ENDLESS_DUNGEON_BUFF_SELECTOR_%s", IsInGamepadPreferredMode() and "GAMEPAD" or "KEYBOARD")
    AH.IsRu = GetCVar and GetCVar("language.2") == "ru"
    if LibChatMessage then AH.Chat = LibChatMessage("ESOAdventurerSuite", "EAS") end
    if AH.CheckDataShareLib then pcall(AH.CheckDataShareLib) end
    if AH.FindMissingAbilityIds then pcall(AH.FindMissingAbilityIds) end
    local hooksOK = true
    if AH.SetupHooks then hooksOK = pcall(AH.SetupHooks) end
    if not hooksOK then
        zo_callLater(function() AH._suiteInitialized = false; init() end, 1000)
        return
    end
    if AH.SetupEvents then pcall(AH.SetupEvents) end
    AH._suiteInitialized = true
end

local name="ESOAdventurerSuite_IAExtendedInit"
EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
    if not AH._suiteInitialized then zo_callLater(init, 500) end
end)
zo_callLater(init, 1500)

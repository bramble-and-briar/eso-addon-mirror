CraftPawns = CraftPawns or {}
local CAM = CraftPawns

CAM.name = "CraftPawns"
CAM.displayName = "CraftPawns"
CAM.version = "2.3.1"
CAM.schemaVersion = 2
CAM.snapshotVersion = 1
CAM.expectedPresetCost = 83
CAM.completedResearchPresetCost = 67
CAM.authorAccount = "@HellWhyNot"
CAM.defaults = {
    schemaVersion = 2,
    machineMigrationVersion = 0,
    migratedAccounts = {},
    servers = {},
    settings = {
        staleDays = 30, uiScale = 1, defaultRounds = 3,
        quickRounds = { 1, 2, 3, 5, 10 }, debug = false,
        integrateLazySetCrafter = true,
    },
}

CAM.CRAFTS = {
    { key="alchemy", name="Alchemy", type=CRAFTING_TYPE_ALCHEMY },
    { key="blacksmithing", name="Blacksmithing", type=CRAFTING_TYPE_BLACKSMITHING, research=true },
    { key="clothing", name="Clothing", type=CRAFTING_TYPE_CLOTHIER, research=true },
    { key="enchanting", name="Enchanting", type=CRAFTING_TYPE_ENCHANTING },
    { key="jewelry", name="Jewelry", type=CRAFTING_TYPE_JEWELRYCRAFTING, research=true },
    { key="provisioning", name="Provisioning", type=CRAFTING_TYPE_PROVISIONING },
    { key="woodworking", name="Woodworking", type=CRAFTING_TYPE_WOODWORKING, research=true },
}

CAM.RESEARCH_CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING,
}

function CAM:Debug(message)
    if self.sv and self.sv.settings.debug then d("[CAM] " .. tostring(message)) end
end

function CAM:Notify(message,isError)
    message=tostring(message or "")
    if type(ZO_Alert)=="function" then
        ZO_Alert(isError and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT,nil,message)
    else
        d("[CraftPawns] "..message)
    end
end

function CAM:SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, nil end
    return pcall(fn, ...)
end

function CAM:GetTraitName(traitType)
    if traitType==nil then return "Unknown Trait" end
    local stringId=_G["SI_ITEMTRAITTYPE"..tostring(traitType)]
    if stringId and type(GetString)=="function" then
        local ok,value=pcall(GetString,stringId)
        if ok and value and value~="" then return value end
    end
    return "Trait "..tostring(traitType)
end

function CAM:FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local d = math.floor(seconds / 86400); seconds = seconds % 86400
    local h = math.floor(seconds / 3600); seconds = seconds % 3600
    local m = math.floor(seconds / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

function CAM:OnLoaded(_, addonName)
    if addonName ~= self.name then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    self.SavedData:Initialize()
    self.Knowledge:Initialize()
    self.Settings:Initialize()
    self.UI:Initialize()
    self.AutoResearch:Initialize()
    self.MailTransfer:Initialize()
    self.ResearchScrolls:Initialize()
    self.Scanner:Initialize()
end

EVENT_MANAGER:RegisterForEvent(CAM.name, EVENT_ADD_ON_LOADED,
    function(...) CAM:OnLoaded(...) end)

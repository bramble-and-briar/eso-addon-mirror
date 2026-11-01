KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.ChatSpam = KyzderpsDerps.ChatSpam or {}
local Spam = KyzderpsDerps.ChatSpam

---------------------------------------------------------------------
-- Keeping track
---------------------------------------------------------------------
local chestsLooted = 0

local function UpdateDisplay()
    if (not KyzderpsDerps.savedOptions.infoPanel.chestsLooted) then
        -- Never display
        KDDInfoPanel:SetHidden(true)
        return
    end

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if (KyzderpsDerps.savedOptions.infoPanel.chestsLootedDungeonsOnly and not KyzderpsDerps.DUNGEON_ZONEIDS[tostring(zoneId)]) then
        -- Only display in dungeons
        KDDInfoPanel:SetHidden(true)
        return
    end

    KDDInfoPanel:SetHidden(false)
    KDDInfoPanel:SetWidth(150)

    KDDInfoPanelChestsLabel:SetWidth(150)
    KDDInfoPanelChestsLabel:SetText(string.format("%d chest%s looted", chestsLooted, chestsLooted == 1 and "" or "s"))
    KDDInfoPanelChestsLabel:SetWidth(KDDInfoPanelChestsLabel:GetTextWidth())

    KDDInfoPanel:SetWidth(KDDInfoPanelChestsLabel:GetTextWidth() + 8)
end
Spam.UpdateChestDisplay = UpdateDisplay

local function ResetCounter(prevZoneName)
    if (chestsLooted > 0 and KyzderpsDerps.savedOptions.chatSpam.printChestSummary) then
        KyzderpsDerps:msg(string.format("You looted %d chests while in %s. Resetting counter.", chestsLooted, prevZoneName))
    end
    chestsLooted = 0
    UpdateDisplay()
end
Spam.ResetCounter = ResetCounter

local function OnChestLooted()
    if (KyzderpsDerps.savedOptions.chatSpam.printChest) then
        KyzderpsDerps:msg("Looted chest.")
    end
    chestsLooted = chestsLooted + 1
    UpdateDisplay()
end

---------------------------------------------------------------------
-- On interact key
---------------------------------------------------------------------
local lastChestTime = 0
local function OnStartInteract()
    local interactText, mainText, _, isOwned = GetGameCameraInteractableActionInfo()
    if (interactText and interactText ~= "") then
        KyzderpsDerps:dbg(string.format("%s - %s - %s", tostring(interactText or "[]"), tostring(mainText or "[]"), tostring(isOwned or "[]")))
        -- Spam.AddMessage(zo_strformat("<<1>> <<2>> <<3>>", interactText, mainText, isOwned))
    end

    -- Looting a chest
    if (((mainText == "Chest" or mainText == "Hidden Chest") and interactText == "Use") and not isOwned) then
        local currentTimeStamp = GetTimeStamp()
        if (currentTimeStamp - lastChestTime > 3) then
            OnChestLooted()
            lastChestTime = currentTimeStamp
        end
    end
end


---------------------------------------------------------------------
-- Zoning to a different zone
---------------------------------------------------------------------
local prevZoneId
local function OnPlayerActivated()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))

    if (prevZoneId ~= zoneId) then
        ResetCounter(GetZoneNameById(prevZoneId))
    end

    prevZoneId = zoneId
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function Spam.InitializeInteract()
    ZO_PreHook(INTERACTIVE_WHEEL_MANAGER, "StartInteraction", OnStartInteract)

    -- Must do this separately, or else every attempt to pick lock will be an interact
    EVENT_MANAGER:RegisterForEvent(Spam.name .. "LockSuccess", EVENT_LOCKPICK_SUCCESS, OnStartInteract)

    -- Reset counter upon LFG joined, because sometimes we can queue from the same dungeon into a new instance
    EVENT_MANAGER:RegisterForEvent(Spam.name .. "LFGJoined", EVENT_GROUPING_TOOLS_LFG_JOINED, function(_, locationName)
        KyzderpsDerps:dbg("lfg joined " .. locationName)
        ResetCounter(GetZoneNameById(prevZoneId))
    end)

    EVENT_MANAGER:RegisterForEvent(Spam.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- UI
    KDDInfoPanel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        KyzderpsDerps.savedValues.chestsLooted.x, KyzderpsDerps.savedValues.chestsLooted.y)
    HUD_SCENE:AddFragment(ZO_SimpleSceneFragment:New(KDDHUDContainer))
    HUD_UI_SCENE:AddFragment(ZO_SimpleSceneFragment:New(KDDHUDContainer))
    UpdateDisplay()
end

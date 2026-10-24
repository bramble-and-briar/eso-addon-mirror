--[[
    AetherPath - Travel / Wayshrine helper
    Original implementation - public ESO APIs only
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.Travel = AP.Travel or {}

local Travel = AP.Travel

function Travel:Initialize()
    self.nodeCache = {}
end

local function SafeRecallCost(nodeIndex)
    if type(GetRecallCost) == "function" then
        local ok, cost = pcall(GetRecallCost, nodeIndex)
        if ok and type(cost) == "number" then return cost end
    end
    return 0
end

function Travel:RefreshNodes()
    self.nodeCache = {}
    local numNodes = GetNumFastTravelNodes() or 0
    for i = 1, numNodes do
        local known, name = GetFastTravelNodeInfo(i)
        if known and name and name ~= "" then
            local cost = SafeRecallCost(i)
            local isFavorite = AP.sv.favoriteNodes[i] == true
            local customName = AP.sv.customNames[i]
            table.insert(self.nodeCache, {
                index    = i,
                name     = customName or name,
                original = name,
                cost     = cost,
                favorite = isFavorite,
            })
        end
    end

    table.sort(self.nodeCache, function(a, b)
        if a.favorite ~= b.favorite then return a.favorite end
        return tostring(a.name) < tostring(b.name)
    end)
end

function Travel:GetNodes()
    if not self.nodeCache or #self.nodeCache == 0 then
        self:RefreshNodes()
    end
    return self.nodeCache
end

function Travel:ToggleFavorite(nodeIndex)
    if not nodeIndex then return end
    AP.sv.favoriteNodes[nodeIndex] = not AP.sv.favoriteNodes[nodeIndex]
    self:RefreshNodes()
    if AP.UI and AP.UI.RefreshTravelList then AP.UI:RefreshTravelList() end
end

function Travel:SetCustomName(nodeIndex, name)
    if not nodeIndex then return end
    if name and name ~= "" then
        AP.sv.customNames[nodeIndex] = name
    else
        AP.sv.customNames[nodeIndex] = nil
    end
    self:RefreshNodes()
end

function Travel:TravelTo(nodeIndex)
    if not nodeIndex then return end

    local known, name = GetFastTravelNodeInfo(nodeIndex)
    if not known then
        d("|cFF5555AetherPath|r " .. (AP.L("NODE_UNKNOWN") or "Unknown wayshrine"))
        return
    end

    local cost = SafeRecallCost(nodeIndex)
    local free = AP.atWayshrine or cost <= 0

    if AP.sv.confirmTravel and not free then
        local displayName = name or "?"
        -- Simple confirm via chat + direct travel; full ZO dialog optional
        if ZO_Dialogs_ShowPlatformDialog then
            ZO_Dialogs_ShowPlatformDialog("AETHERPATH_CONFIRM_TRAVEL", {
                callback = function()
                    FastTravelToNode(nodeIndex)
                end,
            }, {
                mainTextParams = { displayName, AP.FormatCost(cost) },
            })
        else
            FastTravelToNode(nodeIndex)
        end
    else
        FastTravelToNode(nodeIndex)
    end
end

function Travel:RegisterDialogs()
    if not ZO_Dialogs_RegisterCustomDialog then return end
    ZO_Dialogs_RegisterCustomDialog("AETHERPATH_CONFIRM_TRAVEL", {
        title = { text = function() return AP.L("CONFIRM_TRAVEL_TITLE") or "Confirm Travel" end },
        mainText = { text = function() return AP.L("CONFIRM_TRAVEL_BODY") or "Travel to <<1>> for <<2>>?" end },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    if dialog.data and dialog.data.callback then
                        dialog.data.callback()
                    end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

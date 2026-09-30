-- ESO Adventurer Suite
-- v0.29.720 - clean Suite Exclusive destinations; no amenity/public tooltip metadata.
-- These destinations are intentionally not exposed through SavedVariables or settings.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Travel then return end
local T = EPC.Travel

local MODE = "SUITE_EXCLUSIVES"

local DESTINATIONS = {
    {
        key = "master_suite_guild",
        name = "Master Suite Area",
        owner = "@MattiverseHQ",
        houseName = "Rogue's Refuge",
        houseId = 128,
    },
    {
        key = "master_crafting_area",
        name = "Master Crafting Area",
        owner = "@karthrag_inak",
        houseName = "Pariah's Pinnacle",
        houseId = 54,
    },
}

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("%^+[A-Za-z][A-Za-z0-9]*%b{}", "")
    text = text:gsub("%^+[A-Za-z][A-Za-z0-9]*", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function normalize(value)
    return string.lower(clean(value))
end

local function printMessage(text)
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(text)
    elseif type(d) == "function" then
        d("[ESO Adventurer Suite] " .. tostring(text))
    end
end

function T:GetSuiteExclusiveTeleporterEntries029672()
    local rows = {}
    for _, destination in ipairs(DESTINATIONS) do
        rows[#rows + 1] = {
            kind = "SUITE_EXCLUSIVE",
            key = "suite-exclusive:" .. destination.key,
            name = destination.name,
            -- Show the Suite destination name in the row. The real account owner
            -- remains hard-coded only in suiteExclusive and is used for travel.
            displayName = destination.name,
            characterName = "",
            zoneName = destination.houseName,
            sourceText = "SUITE EXCLUSIVE",
            sourceDetail = destination.name .. "  |  " .. destination.houseName,
            statusText = destination.accessOk029720 and "ACCESS OK" or "VISIT",
            canTravel = true,
            suiteExclusive = destination,
        }
    end
    return rows
end

function T:TravelSuiteExclusive029672(entry)
    local destination = entry and entry.suiteExclusive
    if type(destination) ~= "table" then return false end

    if type(self.CanLeaveNow) == "function" then
        local canLeave, reason = self:CanLeaveNow()
        if canLeave == false then
            printMessage(tostring(reason or "Travel is unavailable") .. ".")
            return false
        end
    end

    local houseId = tonumber(destination.houseId) or 0
    if houseId <= 0 then
        printMessage("Suite Exclusive house ID is missing for " .. tostring(destination.houseName) .. ".")
        return false
    end

    local owner = tostring(destination.owner or "")
    if owner == "" or type(JumpToSpecificHouse) ~= "function" then
        printMessage("ESO's specific-house travel API is unavailable.")
        return false
    end

    if type(self.RecordMapTeleporterTravel) == "function" then
        pcall(self.RecordMapTeleporterTravel, self, entry)
    end

    printMessage("Traveling to " .. tostring(destination.name) .. " — " .. tostring(destination.houseName) .. ".")

    self.pendingSuiteExclusiveArrival029720 = {
        key = destination.key,
        houseId = houseId,
        name = destination.name,
        startedAt = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or 0,
    }

    if type(zo_callLater) == "function" then
        local pendingKey = destination.key
        zo_callLater(function()
            local pending = T.pendingSuiteExclusiveArrival029720
            if not pending or pending.key ~= pendingKey then return end
            local currentHouseId = 0
            if type(GetCurrentZoneHouseId) == "function" then
                local okHouse, value = pcall(GetCurrentZoneHouseId)
                if okHouse then currentHouseId = tonumber(value) or 0 end
            end
            if currentHouseId ~= houseId then
                printMessage("Master Crafting Area travel was not confirmed. ESO may have rejected remote visitor access.")
                T.pendingSuiteExclusiveArrival029720 = nil
            end
        end, 30000)
    end

    local ok
    if type(IsProtectedFunction) == "function" and type(CallSecureProtected) == "function" then
        local protectedOk, isProtected = pcall(IsProtectedFunction, "JumpToSpecificHouse")
        if protectedOk and isProtected == true then
            ok = pcall(CallSecureProtected, "JumpToSpecificHouse", owner, houseId)
        end
    end
    if ok == nil then
        ok = pcall(JumpToSpecificHouse, owner, houseId)
    end

    if not ok then
        self.pendingSuiteExclusiveArrival029720 = nil
        printMessage("ESO rejected the Suite Exclusive travel request. The owner may need to allow visitor access to that home.")
        return false
    end

    if EPC.WayshrineAutoMessage and type(EPC.WayshrineAutoMessage.ArmSuiteTeleporterTravel) == "function" then
        pcall(EPC.WayshrineAutoMessage.ArmSuiteTeleporterTravel, EPC.WayshrineAutoMessage, entry)
    end
    return true
end

local baseBuildEntries = T.BuildMapTeleporterEntries
function T:BuildMapTeleporterEntries(...)
    if self.mapTeleporterMode ~= MODE then
        return baseBuildEntries(self, ...)
    end

    local entries = self:GetSuiteExclusiveTeleporterEntries029672()
    local playerNeedle = normalize(self.mapTeleporterPlayerSearch or "")
    local zoneNeedle = normalize(self.mapTeleporterZoneSearch or "")
    local filtered = {}
    for _, entry in ipairs(entries) do
        local destination = entry.suiteExclusive or {}
        local playerHay = normalize((entry.name or "") .. " " .. (destination.owner or "") .. " " .. (entry.sourceDetail or ""))
        local zoneHay = normalize((entry.zoneName or "") .. " " .. (entry.sourceText or ""))
        if (playerNeedle == "" or string.find(playerHay, playerNeedle, 1, true))
            and (zoneNeedle == "" or string.find(zoneHay, zoneNeedle, 1, true)) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

local baseTravelEntry = T.TravelMapTeleporterEntry
function T:TravelMapTeleporterEntry(entry, ...)
    if entry and entry.kind == "SUITE_EXCLUSIVE" then
        return self:TravelSuiteExclusive029672(entry)
    end
    return baseTravelEntry(self, entry, ...)
end

local baseViewLabel = T.GetMapTeleporterViewLabel02967
function T:GetMapTeleporterViewLabel02967(mode, ...)
    if mode == MODE then return "Suite Exclusives" end
    if type(baseViewLabel) == "function" then return baseViewLabel(self, mode, ...) end
    return tostring(mode or "Destinations")
end

local baseSetMode = T.SetMapTeleporterMode
function T:SetMapTeleporterMode(mode, ...)
    if mode == MODE then
        self.mapTeleporterMode = MODE
        self.mapTeleporterPage = 1
        if type(self.HideMapTeleporterFlyout02969) == "function" then
            self:HideMapTeleporterFlyout02969()
        end
        if type(self.RefreshMapTeleporter) == "function" then
            self:RefreshMapTeleporter()
        end
        if type(self.ApplyMapTeleporterDestinationLabel029142) == "function" then
            self:ApplyMapTeleporterDestinationLabel029142()
        end
        return true
    end
    if type(baseSetMode) == "function" then
        return baseSetMode(self, mode, ...)
    end
    return false
end

local baseViewMenu = T.ShowMapTeleporterViewMenu02967
function T:ShowMapTeleporterViewMenu02967(owner, ...)
    if type(baseViewMenu) ~= "function" then return false end

    local result = baseViewMenu(self, owner, ...)
    local root = self.mapTeleporter
    local flyout = root and root.flyout02969
    local existing = flyout and flyout.items02969
    if type(existing) ~= "table" or type(self.ShowMapTeleporterFlyout02969) ~= "function" then
        return result
    end

    local items = {
        {
            label = "Suite Exclusives",
            selected = self.mapTeleporterMode == MODE,
            _easSuiteExclusive029672 = true,
            action = function() self:SetMapTeleporterMode(MODE) end,
        },
    }

    for _, item in ipairs(existing) do
        if not (item and item._easSuiteExclusive029672) then
            items[#items + 1] = item
        end
    end

    return self:ShowMapTeleporterFlyout02969("DESTINATIONS", items, owner, false)
end

-- Suite Exclusives uses a cleaner fixed-destination row layout. The normal
-- Teleporter reserves a favorite button on the left and only 96px on the right;
-- that makes these two branded rows unnecessarily cramped. Hide the favorite
-- control here, move destination text left, and keep a dedicated right column.
-- Restore the stock geometry immediately when leaving this mode so other views
-- are unaffected.
local baseRefreshMapTeleporter = T.RefreshMapTeleporter
function T:RefreshMapTeleporter(...)
    local result = baseRefreshMapTeleporter(self, ...)
    local root = self.mapTeleporter
    if not root then return result end

    local exclusiveMode = self.mapTeleporterMode == MODE
    for _, row in ipairs(root.rows or {}) do
        if row then
            local isExclusiveRow = exclusiveMode and row.entry and row.entry.kind == "SUITE_EXCLUSIVE"
            if row.star then row.star:SetHidden(isExclusiveRow) end

            if row.source then
                row.source:ClearAnchors()
                row.source:SetAnchor(TOPRIGHT, row, TOPRIGHT, -7, 2)
                row.source:SetDimensions(isExclusiveRow and 124 or 96, 17)
            end
            if row.status then
                row.status:ClearAnchors()
                row.status:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -7, -2)
                row.status:SetDimensions(isExclusiveRow and 124 or 96, 16)
            end
            if row.name then
                row.name:ClearAnchors()
                row.name:SetAnchor(TOPLEFT, row, TOPLEFT, isExclusiveRow and 10 or 36, 2)
                row.name:SetAnchor(TOPRIGHT, row, TOPRIGHT, isExclusiveRow and -136 or -108, 2)
                row.name:SetHeight(18)
            end
            if row.zone then
                row.zone:ClearAnchors()
                row.zone:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, isExclusiveRow and 10 or 36, -2)
                row.zone:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, isExclusiveRow and -136 or -108, -2)
                row.zone:SetHeight(16)
            end
        end
    end
    return result
end

if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
    EPC.Runtime:RegisterEvent("TeleporterSuiteExclusives", "Arrival", EVENT_PLAYER_ACTIVATED, function()
        local pending = T.pendingSuiteExclusiveArrival029720
        if not pending then return end

        local currentHouseId = 0
        if type(GetCurrentZoneHouseId) == "function" then
            local okHouse, value = pcall(GetCurrentZoneHouseId)
            if okHouse then currentHouseId = tonumber(value) or 0 end
        end

        if currentHouseId == (tonumber(pending.houseId) or -1) then
            for _, destination in ipairs(DESTINATIONS) do
                if destination.key == pending.key then
                    destination.accessOk029720 = true
                    break
                end
            end
            printMessage("Access confirmed: " .. tostring(pending.name or "Suite Exclusive") .. ".")
            T.pendingSuiteExclusiveArrival029720 = nil
            if type(T.RefreshMapTeleporter) == "function" then pcall(T.RefreshMapTeleporter, T) end
        end
    end)
end

EPC.teleporterSuiteExclusives029676 = true
EPC.teleporterSuiteExclusiveClean029720 = true

BF.BuildApplier = {}

local LINK_STYLE = LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT or 0

local function AddBag(bags, bagId)
    if bagId ~= nil then table.insert(bags, bagId) end
end

local function BuildBagScanOrder()
    local bags = {}
    AddBag(bags, BAG_BACKPACK)
    AddBag(bags, BAG_BANK)
    AddBag(bags, BAG_SUBSCRIBER_BANK)
    AddBag(bags, BAG_WORN)
    return bags
end

local function IsValidBag(bagId)
    if bagId == nil or not GetBagSize then return false end
    local ok, bagSize = pcall(GetBagSize, bagId)
    return ok and bagSize ~= nil
end

local function GetSafeBagSize(bagId)
    if bagId == nil or not GetBagSize then return 0 end
    local ok, bagSize = pcall(GetBagSize, bagId)
    if ok and bagSize then return bagSize end
    return 0
end

local function GetLinkValue(fn, link, fallback)
    if not fn or not link or link == "" then return fallback end
    local ok, value = pcall(fn, link)
    if ok then return value end
    return fallback
end

local function GetSetId(link)
    if not GetItemLinkSetInfo or not link or link == "" then return 0 end
    local ok, _, _, _, _, _, setId = pcall(GetItemLinkSetInfo, link, false)
    if ok then return setId or 0 end
    return 0
end

local function ScoreCandidate(required, candidate)
    local score = 0
    if required.itemId and required.itemId ~= 0 and required.itemId == candidate.itemId then score = score + 100 end
    if required.setId and required.setId ~= 0 and required.setId == candidate.setId then score = score + 50 end
    if required.traitType and required.traitType ~= 0 and required.traitType == candidate.traitType then score = score + 25 end
    if required.enchantId and required.enchantId ~= 0 and required.enchantId == candidate.enchantId then score = score + 10 end
    if required.equipType and required.equipType ~= 0 and required.equipType == candidate.equipType then score = score + 5 end
    if required.armorType and required.armorType ~= 0 and required.armorType == candidate.armorType then score = score + 2 end
    if required.weaponType and required.weaponType ~= 0 and required.weaponType == candidate.weaponType then score = score + 2 end
    return score
end

local function BuildCandidate(bagId, slotIndex)
    local link = GetItemLink and GetItemLink(bagId, slotIndex, LINK_STYLE) or ""
    local _, _, _, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality = GetItemInfo(bagId, slotIndex)
    return {
        bagId = bagId,
        slotIndex = slotIndex,
        link = link,
        itemName = GetLinkValue(GetItemLinkName, link, "Unknown Item"),
        itemId = GetItemId and GetItemId(bagId, slotIndex) or GetLinkValue(GetItemLinkItemId, link, 0),
        setId = GetSetId(link),
        traitType = GetItemTrait and GetItemTrait(bagId, slotIndex) or GetLinkValue(GetItemLinkTraitType, link, 0),
        enchantId = GetLinkValue(GetItemLinkFinalEnchantId, link, 0),
        armorType = GetLinkValue(GetItemLinkArmorType, link, 0),
        weaponType = GetLinkValue(GetItemLinkWeaponType, link, 0),
        equipType = equipType or 0,
        itemStyleId = itemStyleId or 0,
        functionalQuality = functionalQuality or 0,
        displayQuality = displayQuality or 0,
        meetsUsageRequirement = meetsUsageRequirement,
        locked = locked,
        used = false,
    }
end

function BF.BuildApplier.BuildInventoryIndex()
    local index = { candidates = {}, byItemId = {}, scannedBags = 0, scannedItems = 0 }
    for _, bagId in ipairs(BuildBagScanOrder()) do
        if IsValidBag(bagId) then
            index.scannedBags = index.scannedBags + 1
            local bagSize = GetSafeBagSize(bagId)
            for slotIndex = 0, bagSize - 1 do
                if HasItemInSlot and HasItemInSlot(bagId, slotIndex) then
                    local isEquipable = IsEquipable and IsEquipable(bagId, slotIndex) or false
                    if isEquipable then
                        index.scannedItems = index.scannedItems + 1
                        local candidate = BuildCandidate(bagId, slotIndex)
                        table.insert(index.candidates, candidate)
                        if candidate.itemId and candidate.itemId ~= 0 then
                            if not index.byItemId[candidate.itemId] then index.byItemId[candidate.itemId] = {} end
                            table.insert(index.byItemId[candidate.itemId], candidate)
                        end
                    end
                end
            end
        end
    end
    return index
end

local function FindBestCandidate(required, index)
    local pool = required.itemId and index.byItemId[required.itemId] or nil
    if not pool or #pool == 0 then pool = index.candidates end
    local best = nil
    local bestScore = 0
    for _, candidate in ipairs(pool) do
        if not candidate.used then
            local score = ScoreCandidate(required, candidate)
            if score > bestScore then
                best = candidate
                bestScore = score
            end
        end
    end
    if best and bestScore >= 100 then return best, bestScore end
    if best and bestScore >= 75 then return best, bestScore end
    return nil, bestScore
end

function BF.BuildApplier.CompareBuild(build)
    if not build or not build.gear then
        BF.Chat("No build selected.")
        return nil
    end
    local index = BF.BuildApplier.BuildInventoryIndex()
    local matched = {}
    local missing = {}
    for _, required in ipairs(build.gear) do
        local candidate, score = FindBestCandidate(required, index)
        if candidate then
            candidate.used = true
            table.insert(matched, { required = required, candidate = candidate, score = score })
        else
            table.insert(missing, required)
        end
    end
    BF.runtime.matchedGear = matched
    BF.runtime.missingGear = missing
    BF.runtime.failedGear = {}
    BF.ui.lastCompareSummary = {
        buildName = build.name,
        matched = #matched,
        missing = #missing,
        failed = 0,
        total = #(build.gear or {}),
        scannedBags = index.scannedBags,
        scannedItems = index.scannedItems,
    }
    BF.Chat(string.format("Build compare: %d matched, %d missing.", #matched, #missing))
    if BF.RefreshUI then BF.RefreshUI() end
    return BF.ui.lastCompareSummary
end

local function EquipMatch(match)
    if not match or not match.required or not match.candidate then return false, "missing match" end
    if not RequestEquipItem then return false, "RequestEquipItem unavailable" end
    local result = RequestEquipItem(match.candidate.bagId, match.candidate.slotIndex, BAG_WORN, match.required.equipSlot)
    return result ~= false, result
end

function BF.BuildApplier.ApplyOwnedGear(build)
    if not build or not build.gear then
        BF.Chat("No build selected.")
        return nil
    end
    BF.BuildApplier.CompareBuild(build)
    local matches = BF.runtime.matchedGear or {}
    local failed = {}
    local applied = 0
    local delay = BF.savedVars and BF.savedVars.settings and BF.savedVars.settings.applyDelayMs or 350

    local function ApplyAt(index)
        local match = matches[index]
        if not match then
            BF.runtime.failedGear = failed
            BF.ui.lastCompareSummary.failed = #failed
            BF.Chat(string.format("Apply owned gear complete: %d applied, %d missing, %d failed.", applied, #(BF.runtime.missingGear or {}), #failed))
            if BF.RefreshUI then BF.RefreshUI() end
            return
        end
        local ok, result = EquipMatch(match)
        if ok then
            applied = applied + 1
        else
            table.insert(failed, { required = match.required, candidate = match.candidate, reason = tostring(result) })
        end
        if zo_callLater then
            zo_callLater(function() ApplyAt(index + 1) end, delay)
        else
            ApplyAt(index + 1)
        end
    end

    ApplyAt(1)
    return true
end

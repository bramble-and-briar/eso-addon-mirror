-- PreviewAnywhereProbeUtils.lua: pure helpers shared by the probe report and the preview actions.
local PA = PreviewAnywhere
local Fmt = PA.Fmt

local ProbeUtils = {}

---GetLinkType returns the LinkType enum (LINK_TYPE_ITEM == 1 on console), NOT the "item" string
---that ZO_LinkHandler_ParseLink / ZO_ExtractLinksFromText use (ITEM_LINK_TYPE). Comparing the two
---silently rejected every chat link through 0.2.8; match the link text itself instead.
---@param link string|nil
---@return boolean
function ProbeUtils.IsItemLink(link)
    if type(link) ~= "string" or link == "" then
        return false
    end
    if string.find(link, "^|H%d+:item:") then
        return true
    end
    local linkTypeItem = rawget(_G, "LINK_TYPE_ITEM")
    if linkTypeItem ~= nil then
        local ok, linkType = pcall(GetLinkType, link)
        return ok and linkType == linkTypeItem
    end
    return false
end

local function EngineCanPreview(link)
    local ok, can = pcall(CanItemLinkBePreviewed, link)
    return ok and can == true
end

---The link the engine should render for an item link: the link itself when previewable, else for
---recipes / furnishing plans the crafted result (what the plan makes), else nil.
---@param link string|nil
---@return string|nil previewLink
---@return boolean viaRecipe
function ProbeUtils.ResolvePreviewLink(link)
    if not ProbeUtils.IsItemLink(link) then
        return nil, false
    end
    if EngineCanPreview(link) then
        return link, false
    end
    local okType, itemType = pcall(GetItemLinkItemType, link)
    if okType and itemType == ITEMTYPE_RECIPE then
        local okResult, result = pcall(GetItemLinkRecipeResultItemLink, link, LINK_STYLE_DEFAULT)
        if okResult and ProbeUtils.IsItemLink(result) and EngineCanPreview(result) then
            return result, true
        end
    end
    return nil, false
end

---Whether the preview system can render this link, directly or through its recipe result.
---@param link string|nil
---@return boolean
function ProbeUtils.CanPreviewLink(link)
    return ProbeUtils.ResolvePreviewLink(link) ~= nil
end

---Replace the style field (15th data field) of an item link; used to probe whether the engine
---renders gear in a motif's style.
---@param link string
---@param styleId integer
---@return string|nil
function ProbeUtils.WithItemLinkStyle(link, styleId)
    local color, itemId, rest = string.match(link or "", "|H(%d):item:(%d+):([^|]*)|h")
    if not itemId then
        return nil
    end
    local fields = {}
    for field in string.gmatch(rest, "[^:]+") do
        fields[#fields + 1] = field
    end
    if #fields < 15 then
        return nil
    end
    fields[15] = tostring(styleId)
    return Fmt("|H%s:item:%s:%s|h|h", color, itemId, table.concat(fields, ":"))
end

---Strip slot-specific data from an item link so it looks like a link of unknown provenance
---(keeps item id, subtype and level; zeroes the rest; same field count as the original).
---@param link string
---@return string|nil
function ProbeUtils.NormalizeItemLink(link)
    local style, itemId, rest = string.match(link or "", "|H(%d):item:(%d+):([^|]*)|h")
    if not itemId then
        return nil
    end
    local fields = {}
    for field in string.gmatch(rest, "[^:]+") do
        fields[#fields + 1] = field
    end
    for i = 3, #fields do
        fields[i] = "0"
    end
    return Fmt("|H%s:item:%s:%s|h|h", style, itemId, table.concat(fields, ":"))
end

---One-line description of a bag slot's preview facts.
---@param bagId integer
---@param slotIndex integer
---@return string
function ProbeUtils.DescribeSlot(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)
    local name = GetItemName(bagId, slotIndex)
    local itemType, specializedType = GetItemType(bagId, slotIndex)
    local furnitureDataId = GetItemFurnitureDataId and GetItemFurnitureDataId(bagId, slotIndex) or "?"
    local okCan, canSlot = pcall(CanInventoryItemBePreviewed, bagId, slotIndex)
    local okLink, canLink = pcall(CanItemLinkBePreviewed, link)
    local okVar, numVariations = pcall(GetNumItemLinkPreviewVariations, link)
    local normalized = ProbeUtils.NormalizeItemLink(link)
    local okNorm, canNormalized = pcall(CanItemLinkBePreviewed, normalized or "")
    return Fmt("bag %d slot %d '%s' type=%s/%s furnId=%s | slot:%s link:%s normalized:%s variations:%s",
        bagId, slotIndex, tostring(name), tostring(itemType), tostring(specializedType), tostring(furnitureDataId),
        okCan and tostring(canSlot) or ("ERR " .. tostring(canSlot)),
        okLink and tostring(canLink) or ("ERR " .. tostring(canLink)),
        okNorm and tostring(canNormalized) or ("ERR " .. tostring(canNormalized)),
        okVar and tostring(numVariations) or ("ERR " .. tostring(numVariations)))
end

---Scan a bag: counts of items, furnishings, previewable slots; detail lines for the first few.
---@param bagId integer
---@param maxDetail integer
---@return string[] lines
---@return string[] previewableLinks item links of previewable slots (for the link test)
function ProbeUtils.ScanBag(bagId, maxDetail)
    local lines = {}
    local previewableLinks = {}
    local okSize, size = pcall(GetBagSize, bagId)
    if not okSize or not size or size == 0 then
        lines[#lines + 1] = Fmt("bag %d: size %s (not accessible here)", bagId, tostring(size))
        return lines, previewableLinks
    end
    local items, furnishings, previewable, previewableFurnishings, detail = 0, 0, 0, 0, 0
    local previewableTypes = {}
    for slotIndex = 0, size - 1 do
        if GetItemLink(bagId, slotIndex) ~= "" then
            items = items + 1
            local itemType = GetItemType(bagId, slotIndex)
            local isFurnishing = itemType == ITEMTYPE_FURNISHING
            if isFurnishing then
                furnishings = furnishings + 1
            end
            local okCan, can = pcall(CanInventoryItemBePreviewed, bagId, slotIndex)
            if okCan and can then
                previewable = previewable + 1
                previewableTypes[itemType] = (previewableTypes[itemType] or 0) + 1
                if isFurnishing then
                    previewableFurnishings = previewableFurnishings + 1
                end
                previewableLinks[#previewableLinks + 1] = GetItemLink(bagId, slotIndex)
            end
            if (isFurnishing or (okCan and can)) and detail < maxDetail then
                detail = detail + 1
                lines[#lines + 1] = "  " .. ProbeUtils.DescribeSlot(bagId, slotIndex)
            end
        end
    end
    local typeParts = {}
    for itemType, count in pairs(previewableTypes) do
        typeParts[#typeParts + 1] = Fmt("%s=%d", tostring(itemType), count)
    end
    table.sort(typeParts)
    table.insert(lines, 1, Fmt("bag %d: size %d items %d furnishings %d previewable %d (furnishings %d) byType{%s}",
        bagId, size, items, furnishings, previewable, previewableFurnishings, table.concat(typeParts, " ")))
    return lines, previewableLinks
end

---Item links from the gamepad chat menu's message log, most recent first, deduplicated.
---@return string[] links
---@return integer messagesScanned
function ProbeUtils.CollectChatItemLinks()
    local links, seen = {}, {}
    local chatMenu = rawget(_G, "CHAT_MENU_GAMEPAD")
    local entries = chatMenu and chatMenu.messageEntries
    if type(entries) ~= "table" then
        return links, 0
    end
    for i = #entries, 1, -1 do
        local data = entries[i] and entries[i].data
        if data and type(data.links) == "table" then
            for _, linkData in ipairs(data.links) do
                local link = linkData.link
                if ProbeUtils.IsItemLink(link) and not seen[link] then
                    seen[link] = true
                    links[#links + 1] = link
                end
            end
        end
    end
    return links, #entries
end

---@return string
function ProbeUtils.CurrentSceneName()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    return scene and scene:GetName() or "nil"
end

---Snapshot of the preview engine state, for logging.
---@return string
function ProbeUtils.PreviewStateLine()
    local preview = rawget(_G, "ITEM_PREVIEW_GAMEPAD")
    local function Try(fn, ...)
        if not fn then
            return "n/a"
        end
        local ok, v = pcall(fn, ...)
        return ok and tostring(v) or ("ERR " .. tostring(v))
    end
    return Fmt("scene=%s available=%s previewModeEnabled=%s currentlyPreviewing=%s fragmentShowing=%s waiting=%s interactionCamPreview=%s",
        ProbeUtils.CurrentSceneName(),
        Try(IsCharacterPreviewingAvailable),
        Try(GetPreviewModeEnabled),
        Try(IsCurrentlyPreviewing),
        preview and Try(function() return preview:GetFragment():IsShowing() end) or "n/a",
        preview and Try(function() return preview:IsWaitingForPreviewBegin() end) or "n/a",
        preview and preview.IsInteractionCameraPreviewEnabled and Try(function() return preview:IsInteractionCameraPreviewEnabled() end) or "n/a")
end

PA.ProbeUtils = ProbeUtils

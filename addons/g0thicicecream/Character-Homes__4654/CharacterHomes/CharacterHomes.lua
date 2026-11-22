local CH = {}
CharacterHomes = CH

local WAYSHRINE_ICON    = "/esoui/art/icons/mapkey/mapkey_wayshrine.dds"
local WAYSHRINE_ICON_MO = "/esoui/art/icons/mapkey/mapkey_wayshrine.dds"
local HOME_ICON         = "/esoui/art/collections/collections_tabicon_housing_up.dds"
local HOME_ICON_MO      = "/esoui/art/collections/collections_tabicon_housing_over.dds"
local EDIT_ICON      = "/esoui/art/buttons/edit_up.dds"
local EDIT_ICON_MO   = "/esoui/art/buttons/edit_over.dds"
local SAVE_ICON      = "/esoui/art/buttons/accept_up.dds"
local SAVE_ICON_MO   = "/esoui/art/buttons/accept_over.dds"
local ROW_H          = 44

-- Single account-wide SavedVars, keyed per megaserver.  Structure:
-- CharacterHomesSavedVars[GetWorldName()]["@account"]["$AccountWide"] = {
--   account    = { [alias] = { houseId, owner, displayName, zone } },
--   characters = { [charName] = { primary = {...} or nil, named = { [alias] = {...} } } }
-- }
-- entry fields: houseId (number), owner (string|nil), displayName (string), zone (string|nil)

-- Forward declarations
local populateDialog
local refreshIfOpen
local getOwnedHouses

local CH_DEBUG = false

-- Helpers

local function msg(text, ...)
    if select("#", ...) > 0 then text = string.format(text, ...) end
    d("|cffd700[CharacterHomes]|r " .. text)
end

-- chat message plus a center-screen announcement
local function announce(text, ...)
    if select("#", ...) > 0 then text = string.format(text, ...) end
    msg(text)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    params:SetText(text)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

local function charName() return GetUnitName("player") end

local function charData()
    local n = charName()
    if not CH.sv.characters[n] then
        CH.sv.characters[n] = { primary = nil, named = {} }
    end
    local cd = CH.sv.characters[n]
    if not cd.named then cd.named = {} end
    return cd
end

local function getHouseName(houseId)
    local collectibleId = GetCollectibleIdForHouse(houseId)
    if collectibleId and collectibleId ~= 0 then
        local name = GetCollectibleName(collectibleId)
        if name and name ~= "" then return name end
    end
    return GetMapName() or ("House #" .. houseId)
end

local function makeEntryKey(houseId, owner)
    local houseName = getHouseName(houseId)
    if owner and owner ~= "" then
        return owner .. "_" .. houseName
    end
    return houseName
end

-- Must be defined before currentHouseInfo which calls it.
local function getHouseZone(houseId)
    local zoneId = GetHouseZoneId(houseId)
    if zoneId and zoneId > 0 then
        local parentId = GetParentZoneId(zoneId)
        return GetZoneNameById((parentId and parentId > 0) and parentId or zoneId)
    end
    return nil
end

local function getHouseMapIndex(houseId)
    local zoneId = GetHouseZoneId(houseId)
    for _ = 1, 3 do
        if not zoneId or zoneId == 0 then return nil, nil end
        local mapIndex = GetMapIndexByZoneId(zoneId)
        if mapIndex then return mapIndex, zoneId end
        zoneId = GetParentZoneId(zoneId)
    end
end

-- Houses have no direct coordinates; match the house's map marker by name (same approach as BeamMeUp).
local function findHousePOI(zoneId, houseName)
    local zoneIndex = GetZoneIndex(zoneId)
    local target = string.lower(zo_strformat("<<1>>", houseName))
    for i = 1, GetNumPOIs(zoneIndex) do
        local x, y, _, icon = GetPOIMapInfo(zoneIndex, i)
        local name = string.lower(zo_strformat("<<1>>", GetPOIInfo(zoneIndex, i) or ""))
        local iconLower = string.lower(icon or "")
        if name ~= "" and name:find(target, 1, true)
           and not iconLower:find("wayshrine", 1, true) and not iconLower:find("portal", 1, true) then
            return x, y
        end
    end
end

function CH.ShowHouseOnMap(houseId)
    local mapIndex, zoneId = getHouseMapIndex(houseId)
    if not mapIndex then
        msg("Couldn't find a map for %s.", getHouseName(houseId))
        return
    end
    CH.HideDialog()
    SCENE_MANAGER:Show("worldMap")
    -- switch to Tamriel first to reset any subzone or zoom left over from earlier map use
    WORLD_MAP_MANAGER:SetMapByIndex(1)
    WORLD_MAP_MANAGER:SetMapByIndex(mapIndex)
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    local x, y = findHousePOI(zoneId, getHouseName(houseId))
    if x and y then
        zo_callLater(function() ZO_WorldMap_PanToNormalizedPosition(x, y) end, 200)
    end
end

local function currentHouseInfo()
    local houseId = GetCurrentZoneHouseId()
    if not houseId or houseId == 0 then return nil, nil, nil, nil end
    local owner = GetCurrentHouseOwner() or ""
    if owner == "" or owner == GetDisplayName() then owner = nil end
    return houseId, owner, getHouseName(houseId), getHouseZone(houseId)
end

local function jumpToInterior(entry)
    if entry.owner and entry.owner ~= "" then
        JumpToSpecificHouse(entry.owner, entry.houseId)
    else
        RequestJumpToHouse(entry.houseId)
    end
end

local function jumpToExterior(entry)
    if entry.owner and entry.owner ~= "" then
        msg("Teleporting outside isn't available for friends' houses — going inside instead.")
        JumpToSpecificHouse(entry.owner, entry.houseId)
    else
        RequestJumpToHouse(entry.houseId, true)
    end
end

-- Slash Commands

function CH.SlashSetHome(args)
    local name = args and zo_strtrim(args) or ""
    if name == "" then
        msg("Usage: /setglobalhome |cffffff<name>|r  (account-wide alias)")
        msg("To set your character primary home use /setmyhome with no arguments.")
        return
    end
    local houseId, owner, houseName, zoneName = currentHouseInfo()
    if not houseId then msg("You must be inside a house.") return end
    CH.sv.account[makeEntryKey(houseId, owner)] = { houseId = houseId, owner = owner, displayName = name, zone = zoneName }
    msg("Account home '|cffffff%s|r' -> %s%s", name, houseName,
        owner and (" (|cffffff" .. owner .. "|r)") or "")
    refreshIfOpen()
end

function CH.SlashSetMyHome(args)
    local name      = args and zo_strtrim(args) or ""
    local houseId, owner, houseName, zoneName = currentHouseInfo()
    if not houseId then msg("You must be inside a house.") return end
    -- named homes use the alias as initial display label; primary falls back to official name
    local entry    = { houseId = houseId, owner = owner, displayName = (name ~= "" and name or "Primary Residence"), zone = zoneName }
    local ownerStr = owner and (" (|cffffff" .. owner .. "|r)") or ""
    local cd = charData()
    if name == "" then
        cd.primary = entry
        msg("Primary home for |cffffff%s|r -> %s%s", charName(), houseName, ownerStr)
        refreshIfOpen()
        if CH_DEBUG then
            d("[CH DEBUG] set primary for key='" .. charName() .. "' houseId=" .. tostring(houseId))
            d("[CH DEBUG] cd.primary after set = " .. tostring(cd.primary))
            d("[CH DEBUG] sv.characters key check = " .. tostring(CH.sv.characters[charName()] ~= nil))
        end
    else
        cd.named[makeEntryKey(houseId, owner)] = entry
        msg("Character home '|cffffff%s|r' -> %s%s", name, houseName, ownerStr)
        refreshIfOpen()
    end
end

function CH.SlashResetHome()
    charData().primary = nil
    msg("Primary home cleared for |cffffff%s|r.", charName())
    refreshIfOpen()
end

function CH.SlashDelHome(args)
    local name = args and zo_strtrim(args) or ""
    if name == "" then msg("Usage: /delhome |cffffff<name>|r") return end
    local lname = string.lower(name)
    local matches = {}
    for k, v in pairs(CH.sv.account) do
        if string.lower(k):find(lname, 1, true) or string.lower(v.displayName or ""):find(lname, 1, true) then
            table.insert(matches, { key = k, entry = v })
        end
    end
    if #matches == 0 then
        msg("No account home matching '|cffffff%s|r'.", name)
    elseif #matches > 1 then
        msg("'|cffffff%s|r' matches %d homes — be more specific:", name, #matches)
        for _, m in ipairs(matches) do
            msg("  |cffffff%s|r  (%s)", m.entry.displayName or m.key, m.key)
        end
    else
        local m = matches[1]
        CH.sv.account[m.key] = nil
        msg("Account home '|cffffff%s|r' removed.", m.entry.displayName or m.key)
        refreshIfOpen()
    end
end

function CH.SlashDelMyHome(args)
    local name = args and zo_strtrim(args) or ""
    if name == "" then msg("Usage: /delmyhome |cffffff<name>|r  (or 'primary')") return end
    local cd = charData()
    if string.lower(name) == "primary" then
        if cd.primary then
            cd.primary = nil
            msg("Primary home cleared for |cffffff%s|r.", charName())
            refreshIfOpen()
        else
            msg("No primary home set for |cffffff%s|r.", charName())
        end
        return
    end
    local lname = string.lower(name)
    local matches = {}
    for k, v in pairs(cd.named) do
        if string.lower(k):find(lname, 1, true) or string.lower(v.displayName or ""):find(lname, 1, true) then
            table.insert(matches, { key = k, entry = v })
        end
    end
    if #matches == 0 then
        msg("No character home matching '|cffffff%s|r'.", name)
    elseif #matches > 1 then
        msg("'|cffffff%s|r' matches %d homes — be more specific:", name, #matches)
        for _, m in ipairs(matches) do
            msg("  |cffffff%s|r  (%s)", m.entry.displayName or m.key, m.key)
        end
    else
        local m = matches[1]
        cd.named[m.key] = nil
        msg("Character home '|cffffff%s|r' removed.", m.entry.displayName or m.key)
        refreshIfOpen()
    end
end

function CH.SlashHome(args)
    local query    = args and zo_strtrim(args) or ""
    local exterior = false

    -- "/gohome outside" or "/gohome outside <name>"
    local stripped = query:match("^outside%s+(.*)")
    if stripped then
        exterior = true
        query    = zo_strtrim(stripped)
    elseif string.lower(query) == "outside" then
        exterior = true
        query    = ""
    end

    local function go(entry)
        local official = getHouseName(entry.houseId)
        local dest     = exterior and "outside" or "inside"
        announce("Heading %s |cffffff%s|r (%s)...", dest, entry.displayName or official, official)
        if exterior then jumpToExterior(entry) else jumpToInterior(entry) end
    end

    if query == "" then
        local cd = charData()
        if cd.primary then
            go(cd.primary)
        else
            msg("No primary home set. Use /setmyhome inside a house.")
        end
        return
    end

    local lq      = string.lower(query)
    local matches = {}

    local function collectLabelMatches()
        local found = {}
        local function check(entry)
            local dn = string.lower(entry.displayName or "")
            if dn ~= "" and dn:find(lq, 1, true) then
                table.insert(found, { label = entry.displayName, entry = entry })
            end
        end
        local cd = charData()
        if cd.primary then check(cd.primary) end
        for _, entry in pairs(cd.named)      do check(entry) end
        for _, entry in pairs(CH.sv.account) do check(entry) end
        return found
    end

    local function collectOwnedMatches()
        local found = {}
        for _, h in ipairs(getOwnedHouses()) do
            if string.lower(h.name):find(lq, 1, true) then
                table.insert(found, { label = h.name, entry = { houseId = h.houseId } })
            end
        end
        return found
    end

    matches = collectLabelMatches()
    if #matches == 0 then matches = collectOwnedMatches() end

    if #matches == 0 then
        msg("No home matching '|cffffff%s|r'. Use /homes to see your list.", query)
    elseif #matches == 1 then
        go(matches[1].entry)
    else
        table.sort(matches, function(a, b) return (a.label or "") < (b.label or "") end)
        msg("'|cffffff%s|r' matches %d homes — be more specific:", query, #matches)
        for _, m in ipairs(matches) do
            msg("  |cffffff%s|r", m.label or "")
        end
    end
end

function CH.SlashHomes()
    CH.ShowDialog()
end

-- UI

local rowPool, headerPool, notePool  -- list controls are created once and reused (see populateDialog)
local populating         = false
local accountOwnerFilter = 0  -- 0=all, 1=mine (no owner), 2=friends (has owner)

local function addTooltip(ctrl, text)
    ctrl:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        InformationTooltip:AddLine(text, "ZoFontGame", 1, 1, 1)
    end)
    ctrl:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end

-- re-show the tooltip of whichever of these controls the mouse is over (after its text changed)
local function refreshHoverTooltip(...)
    local over = WINDOW_MANAGER:GetMouseOverControl()
    for _, ctrl in ipairs({ ... }) do
        if over == ctrl and not ctrl:IsHidden() then
            ctrl:GetHandler("OnMouseEnter")(ctrl)
            return
        end
    end
end

local ownedHouseCache = nil

getOwnedHouses = function()
    if not ownedHouseCache then
        ownedHouseCache = {}
        for houseId = 1, 1000 do
            local collectibleId = GetCollectibleIdForHouse(houseId)
            if collectibleId and collectibleId ~= 0 then
                if GetCollectibleUnlockStateById(collectibleId) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    local name = GetCollectibleName(collectibleId) or ("House #" .. houseId)
                    table.insert(ownedHouseCache, { houseId = houseId, name = name, zone = getHouseZone(houseId) })
                end
            end
        end
        table.sort(ownedHouseCache, function(a, b) return a.name < b.name end)
    end
    return ownedHouseCache
end

local allHouseCache = nil

local function getAllHouses()
    if not allHouseCache then
        allHouseCache = {}
        for houseId = 1, 1000 do
            local collectibleId = GetCollectibleIdForHouse(houseId)
            if collectibleId and collectibleId ~= 0 then
                local name = GetCollectibleName(collectibleId)
                if name and name ~= "" then
                    table.insert(allHouseCache, { houseId = houseId, name = name })
                end
            end
        end
        table.sort(allHouseCache, function(a, b) return a.name < b.name end)
    end
    return allHouseCache
end

local function getSearchFilter()
    local eb = CharacterHomesDialogSearchFilterBgEdit
    if not eb then return "" end
    return string.lower(zo_strtrim(eb:GetText() or ""))
end

local function accountOwnerMatchesFilter(entry)
    if accountOwnerFilter == 0 then return true end
    local isOwned = (entry.owner == nil or entry.owner == "")
    if accountOwnerFilter == 1 then return isOwned end
    return not isOwned  -- filter 2: friends
end

local function entryMatchesFilters(_, entry)
    local search = getSearchFilter()
    if search == "" then return true end
    local houseName = getHouseName(entry.houseId) or ""
    if string.lower(houseName):find(search, 1, true)               then return true end
    if string.lower(entry.displayName or ""):find(search, 1, true) then return true end
    if string.lower(entry.zone or ""):find(search, 1, true)        then return true end
    if string.lower(entry.owner or ""):find(search, 1, true)       then return true end
    return false
end

function CH.OnFilterChanged()
    if not CH.sv then return end
    if not rowPool then return end
    if CharacterHomesDialog:IsHidden() then return end
    zo_callLater(populateDialog, 0)
end

local function getRowWidth()
    local panel = CharacterHomesDialogScrollPanel
    return (panel and panel:GetWidth() > 0 and panel:GetWidth() or 700) - 18
end

local function getContent()
    return CharacterHomesDialogScrollPanelScrollChildContent
end

-- Controls are never destroyed (Destroy is unreliable in ESO); released ones are hidden and reused.
local function newPool(template, initOnce)
    local count = 0
    local function factory()
        count = count + 1
        local ctrl = CreateControlFromVirtual(template, getContent(), template, count)
        if initOnce then initOnce(ctrl) end
        return ctrl
    end
    local function reset(ctrl)
        ctrl:SetHidden(true)
        ctrl:ClearAnchors()
    end
    return ZO_ObjectPool:New(factory, reset)
end

local function acquire(pool, offsetX, yOff, fullWidth)
    local ctrl = pool:AcquireObject()
    local c    = getContent()
    ctrl:SetAnchor(TOPLEFT, c, TOPLEFT, offsetX, yOff)
    if fullWidth then ctrl:SetAnchor(TOPRIGHT, c, TOPRIGHT, 0, yOff) end
    ctrl:SetHidden(false)
    return ctrl
end

-- Wiring that doesn't depend on the entry; runs once when the pool creates a row.
local function initRow(row)
    local bg = row:GetNamedChild("Bg")
    row:SetHandler("OnMouseEnter", function() bg:SetCenterColor(1, 1, 1, 0.06) end)
    row:SetHandler("OnMouseExit",  function() bg:SetCenterColor(0, 0, 0, 0) end)
    row:GetNamedChild("NameBg"):SetCenterColor(0, 0, 0, 0.7)
    -- edit/delete button tooltips are set by addRow's edit mode switch
    -- keep our own (already sorted) order so SelectItemByIndex picks the right house
    ZO_ComboBox_ObjectFromContainer(row:GetNamedChild("HouseCombo")):SetSortsItems(false)
end

local function addHeader(text, yOff)
    acquire(headerPool, 2, yOff):SetText(text)
    return yOff + 30
end

local function addRow(typeLabel, aliasName, entry, yOff, onDelete)
    local isOwned = (entry.owner == nil or entry.owner == "")
    local row     = acquire(rowPool, 0, yOff, true)
    -- a row released while hovered never gets OnMouseExit, so clear its highlight
    row:GetNamedChild("Bg"):SetCenterColor(0, 0, 0, 0)

    local isPrimary = (typeLabel == "Primary")
    local teleIcon   = isPrimary and HOME_ICON    or WAYSHRINE_ICON
    local teleIconMO = isPrimary and HOME_ICON_MO or WAYSHRINE_ICON_MO
    local ico = row:GetNamedChild("Teleport")
    ico:SetNormalTexture(teleIcon)
    ico:SetPressedTexture(teleIcon)
    ico:SetMouseOverTexture(teleIconMO)
    local function doTeleport(exterior)
        CH.HideDialog()
        local official = getHouseName(entry.houseId)
        announce("Heading %s |cffffff%s|r (%s)...", exterior and "outside" or "inside", entry.displayName or official, official)
        if exterior then jumpToExterior(entry) else jumpToInterior(entry) end
    end

    ico:SetHandler("OnMouseUp", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            doTeleport(false)
        elseif button == MOUSE_BUTTON_INDEX_RIGHT and isOwned then  -- friend houses can't be entered from outside
            ClearMenu()
            AddMenuItem("Teleport Inside",  function() doTeleport(false) end)
            AddMenuItem("Teleport Outside", function() doTeleport(true)  end)
            ShowMenu(self)
        end
    end)
    local officialName = getHouseName(entry.houseId) or ("House #" .. tostring(entry.houseId or 0))
    local teleLabel = isOwned and ("Teleport to " .. (entry.displayName or officialName) .. "\n|c666666Right-click for outside|r")
                               or ("Teleport to " .. (entry.displayName or officialName) .. "\n|c888888via " .. entry.owner .. "|r")
    addTooltip(ico, teleLabel)

    -- col2: owner @name for friend homes; blank for own homes
    row:GetNamedChild("Owner"):SetText(entry.owner or "")

    -- col3: user's arbitrary display label (editable)
    local aliasLbl = row:GetNamedChild("Alias")
    aliasLbl:SetText(entry.displayName or "")

    -- col4: official ESO house name derived from houseId (not editable as text; changed via combo)
    local houseLbl = row:GetNamedChild("House")
    houseLbl:SetText(officialName)
    houseLbl:SetColor(0.75, 0.75, 0.75, 1)  -- may still be white from hover on a previous use
    houseLbl:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then CH.ShowHouseOnMap(entry.houseId) end
    end)
    houseLbl:SetHandler("OnMouseEnter", function(self)
        self:SetColor(1, 1, 1, 1)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        InformationTooltip:AddLine(entry.zone or getHouseZone(entry.houseId) or officialName, "ZoFontGameBold", 1, 1, 1)
        InformationTooltip:AddLine("Click to show on map", "ZoFontGame", 0.6, 0.6, 0.6)
    end)
    houseLbl:SetHandler("OnMouseExit", function(self)
        self:SetColor(0.75, 0.75, 0.75, 1)
        ClearTooltip(InformationTooltip)
    end)

    -- inline edit controls (hidden until edit mode)
    local dnBg            = row:GetNamedChild("NameBg")      -- label editbox, replaces Alias
    local dnEdit          = row:GetNamedChild("NameBgBox")
    local houseComboCtrl  = row:GetNamedChild("HouseCombo")  -- owned-house dropdown, replaces House
    local houseCombo      = ZO_ComboBox_ObjectFromContainer(houseComboCtrl)
    local selectedHouseId = entry.houseId
    local editBtn         = row:GetNamedChild("EditButton")
    local del             = row:GetNamedChild("DeleteButton")

    local exitEditMode  -- forward declare

    local function enterEditMode()
        ico:SetHidden(true)
        aliasLbl:SetHidden(true)
        houseLbl:SetHidden(true)
        dnBg:SetHidden(false)
        dnEdit:SetText(entry.displayName or "")
        dnEdit:TakeFocus()

        if isOwned then
            local houses = getOwnedHouses()
            houseCombo:ClearItems()
            local selectIdx = 1
            for i, h in ipairs(houses) do
                local houseId = h.houseId
                houseCombo:AddItem(houseCombo:CreateItemEntry(h.name, function()
                    selectedHouseId = houseId
                end))
                if h.houseId == entry.houseId then selectIdx = i end
            end
            houseCombo:SelectItemByIndex(selectIdx)
            houseComboCtrl:SetHidden(false)
        end

        editBtn:SetNormalTexture(SAVE_ICON)
        editBtn:SetMouseOverTexture(SAVE_ICON_MO)
        addTooltip(editBtn, "Save")
        del:SetHandler("OnClicked", function() exitEditMode(false) end)
        addTooltip(del, "Cancel")
        refreshHoverTooltip(editBtn, del)
    end

    exitEditMode = function(doSave, isReset)
        dnEdit:LoseFocus()
        ico:SetHidden(false)
        aliasLbl:SetHidden(false)
        houseLbl:SetHidden(false)
        dnBg:SetHidden(true)
        houseComboCtrl:SetHidden(true)
        editBtn:SetNormalTexture(EDIT_ICON)
        editBtn:SetMouseOverTexture(EDIT_ICON_MO)
        addTooltip(editBtn, "Edit label or change house")
        del:SetHandler("OnClicked", onDelete)
        addTooltip(del, "Remove from list")
        if not isReset then refreshHoverTooltip(editBtn, del) end
        if doSave then
            local newName = zo_strtrim(dnEdit:GetText() or "")
            if newName ~= "" then entry.displayName = newName end
            if isOwned then
                if selectedHouseId ~= entry.houseId then
                    entry.houseId = selectedHouseId
                    entry.owner   = nil
                    -- try to update zone from the owned-houses cache
                    for _, h in ipairs(getOwnedHouses()) do
                        if h.houseId == selectedHouseId then
                            if h.zone then entry.zone = h.zone end
                            break
                        end
                    end
                end
            end
            zo_callLater(populateDialog, 0)
        end
    end

    -- ESO's EditBox events are OnEnter/OnEscape (OnEnterPressed doesn't exist)
    dnEdit:SetHandler("OnEnter", function() exitEditMode(true) end)
    dnEdit:SetHandler("OnEscape", function() exitEditMode(false) end)

    editBtn:SetHandler("OnClicked", function()
        if dnBg:IsHidden() then enterEditMode()
        else exitEditMode(true) end
    end)

    -- start in view mode; a reused row may have been left in edit mode
    exitEditMode(false, true)

    return yOff + ROW_H + 2
end

local function addNote(text, yOff)
    acquire(notePool, 6, yOff):SetText(text)
    return yOff + 24
end

populateDialog = function()
    if populating then return end
    populating = true
    if not rowPool then
        rowPool    = newPool("CharacterHomesRow", initRow)
        headerPool = newPool("CharacterHomesHeader")
        notePool   = newPool("CharacterHomesNote")
    end
    rowPool:ReleaseAllObjects()
    headerPool:ReleaseAllObjects()
    notePool:ReleaseAllObjects()
    ClearTooltip(InformationTooltip)  -- a released control can't fire OnMouseExit to clear its own
    getContent():SetWidth(getRowWidth())

    local yOff = 4
    local cd   = charData()

    if CH_DEBUG then
        d("[CH DEBUG] populateDialog: charName='" .. charName() .. "' cd.primary=" .. tostring(cd.primary) .. " named_count=" .. tostring(cd.named and #cd.named or "nil"))
        d("[CH DEBUG] sv.characters keys:")
        for k,v in pairs(CH.sv.characters) do d("  key='" .. tostring(k) .. "'") end
    end

    yOff = addHeader("MY HOMES  (" .. charName() .. ")", yOff)

    local shownChar = 0
    if cd.primary and entryMatchesFilters("Primary", cd.primary) then
        local e = cd.primary
        yOff = addRow("Primary", "", e, yOff, function()
            charData().primary = nil
            zo_callLater(populateDialog, 0)
        end)
        shownChar = shownChar + 1
    end

    for n, e in pairs(cd.named) do
        if entryMatchesFilters(n, e) then
            local name, entry = n, e
            yOff = addRow("Named", name, entry, yOff, function()
                charData().named[name] = nil
                zo_callLater(populateDialog, 0)
            end)
            shownChar = shownChar + 1
        end
    end

    if shownChar == 0 then
        if cd.primary == nil and next(cd.named) == nil then
            yOff = addNote("No character homes set.", yOff)
        else
            yOff = addNote("No character homes match the filter.", yOff)
        end
    end

    yOff = yOff + 6
    yOff = addHeader("ACCOUNT HOMES", yOff)

    local shownAcc = 0
    for n, e in pairs(CH.sv.account) do
        if entryMatchesFilters(n, e) and accountOwnerMatchesFilter(e) then
            local name, entry = n, e
            yOff = addRow("Account", name, entry, yOff, function()
                CH.sv.account[name] = nil
                zo_callLater(populateDialog, 0)
            end)
            shownAcc = shownAcc + 1
        end
    end
    if shownAcc == 0 then
        if next(CH.sv.account) == nil then
            yOff = addNote("No account homes -- use /setglobalhome <name> inside a house.", yOff)
        else
            yOff = addNote("No account homes match the filter.", yOff)
        end
    end

    getContent():SetHeight(yOff + 4)
    populating = false
end

refreshIfOpen = function()
    if CharacterHomesDialog and not CharacterHomesDialog:IsHidden() then
        zo_callLater(populateDialog, 0)
    end
end

function CH.ShowDialog()
    SCENE_MANAGER:ShowTopLevel(CharacterHomesDialog)
    populateDialog()
end

function CH.HideDialog()
    SCENE_MANAGER:HideTopLevel(CharacterHomesDialog)
end

-- Read at press time so changes made in Controls > Keybindings apply immediately.
local function matchesCloseDialogBinding(key, ctrl, alt, shift, command)
    local layer, category, action = GetActionIndicesFromName("DIALOG_CLOSE")
    if not layer then return false end
    local held = { [KEY_CTRL] = ctrl == true, [KEY_ALT] = alt == true, [KEY_SHIFT] = shift == true, [KEY_COMMAND] = command == true }
    for i = 1, GetMaxBindingsPerAction() do
        local keyCode, m1, m2, m3, m4 = GetActionBindingInfo(layer, category, action, i)
        if keyCode ~= 0 and keyCode == key then
            local modsMatch = true
            for mod, isHeld in pairs(held) do
                -- a bare modifier binding (e.g. just Alt) reports its own flag as held
                if mod ~= keyCode and ZO_Keybindings_DoesKeyMatchAnyModifiers(mod, m1, m2, m3, m4) ~= isHeld then
                    modsMatch = false
                    break
                end
            end
            if modsMatch then return true end
        end
    end
    return false
end

function CH.OnKeyDown(key, ctrl, alt, shift, command)
    -- keyboard-enabled windows swallow keys, so Escape must be handled here too
    if key == KEY_ESCAPE or matchesCloseDialogBinding(key, ctrl, alt, shift, command) then
        CH.HideDialog()
    end
end

-- Add Bar / Friend Housing Bar

local ADD_TYPES    = { "Primary (character)", "Named (character)", "Account wide" }
local addTypeIndex = 1
local fhTypeIndex = 1

local function buildFriendHousingBar()
    local dlg = CharacterHomesDialog
    local ref = CharacterHomesDialogFHRefBg

    local selectedFriend  = nil
    local selectedHouseId = nil

    -- Friend dropdown (x=78, w=200) — anchor to dialog TOPLEFT for reliability
    local friendComboCtrl = WINDOW_MANAGER:CreateControlFromVirtual("CHFHFriendCombo", dlg, "ZO_ComboBox")
    friendComboCtrl:SetAnchor(LEFT, ref, LEFT, 78, 0)
    friendComboCtrl:SetDimensions(200, 28)
    local friendCb = ZO_ComboBox_ObjectFromContainer(friendComboCtrl)
    friendCb:SetSortsItems(false)

    -- collect friends
    local friendNames = {}
    local seenLower   = {}
    local numFriends  = GetNumFriends()
    for i = 1, numFriends do
        local displayName = GetFriendInfo(i)
        if displayName and displayName ~= "" then
            table.insert(friendNames, displayName)
            seenLower[string.lower(displayName)] = true
        end
    end
    table.sort(friendNames, function(a, b) return string.lower(a) < string.lower(b) end)

    -- collect guild masters (rankIndex 1) and officers (rankIndex 2), grouped by guild
    -- deduplicated against friends list so no @account appears twice
    local guildGroups = {}
    local numGuilds   = GetNumGuilds()
    for gi = 1, numGuilds do
        local guildId   = GetGuildId(gi)
        local guildName = GetGuildName(guildId)
        local members   = {}
        local numMembers = GetNumGuildMembers(guildId)
        for mi = 1, numMembers do
            local displayName, _, rankIndex = GetGuildMemberInfo(guildId, mi)
            if displayName and displayName ~= "" and rankIndex <= 2 then
                local low = string.lower(displayName)
                if not seenLower[low] then
                    table.insert(members, displayName)
                    seenLower[low] = true
                end
            end
        end
        table.sort(members, function(a, b) return string.lower(a) < string.lower(b) end)
        if #members > 0 then
            table.insert(guildGroups, { name = guildName, members = members })
        end
    end

    -- populate combo with section headers (non-selectable) and member entries
    local itemIndex          = 0
    local firstSelectableIdx = nil

    local function addSectionHeader(label)
        itemIndex = itemIndex + 1
        local entry = friendCb:CreateItemEntry("|c888888-- " .. label .. " --|r", function()
            -- header: re-assert current selection so clicking it changes nothing
            if selectedFriend then
                friendCb:SetSelectedItemText(selectedFriend)
            end
        end)
        friendCb:AddItem(entry)
    end

    local function addFriendEntry(name)
        itemIndex = itemIndex + 1
        local n = name
        friendCb:AddItem(friendCb:CreateItemEntry(n, function() selectedFriend = n end))
        if not firstSelectableIdx then
            firstSelectableIdx = itemIndex
            selectedFriend     = n
        end
    end

    if #friendNames > 0 then
        addSectionHeader("── Friends ──")
        for _, name in ipairs(friendNames) do addFriendEntry(name) end
    end
    for _, group in ipairs(guildGroups) do
        addSectionHeader("── " .. group.name .. " ──")
        for _, name in ipairs(group.members) do addFriendEntry(name) end
    end

    if firstSelectableIdx then
        friendCb:SelectItemByIndex(firstSelectableIdx)
    end

    -- Type dropdown — anchor RIGHT of friend combo, w=200 to match add bar type combo
    local fhTypeComboCtrl = WINDOW_MANAGER:CreateControlFromVirtual("CHFHTypeCombo", dlg, "ZO_ComboBox")
    fhTypeComboCtrl:SetAnchor(LEFT, friendComboCtrl, RIGHT, 8, 0)
    fhTypeComboCtrl:SetDimensions(200, 28)
    local fhTypeCb = ZO_ComboBox_ObjectFromContainer(fhTypeComboCtrl)
    for i, label in ipairs(ADD_TYPES) do
        local idx = i
        fhTypeCb:AddItem(fhTypeCb:CreateItemEntry(label, function() fhTypeIndex = idx end))
    end
    fhTypeCb:SelectFirstItem()

    -- House dropdown: all ESO houses (x=554, w=270)
    local houseComboCtrl = WINDOW_MANAGER:CreateControlFromVirtual("CHFHHouseCombo", dlg, "ZO_ComboBox")
    houseComboCtrl:SetAnchor(LEFT, ref, LEFT, 554, 0)
    houseComboCtrl:SetDimensions(270, 28)
    local houseCb = ZO_ComboBox_ObjectFromContainer(houseComboCtrl)

    for _, h in ipairs(getAllHouses()) do
        local houseId = h.houseId
        houseCb:AddItem(houseCb:CreateItemEntry(h.name, function() selectedHouseId = houseId end))
    end
    local houses = getAllHouses()
    if #houses > 0 then
        selectedHouseId = houses[1].houseId
        houseCb:SelectFirstItem()
    end

    local fhNameEdit = CharacterHomesDialogFHNameBgEdit

    addTooltip(CharacterHomesDialogFHSaveButton, "Save friend's house to your homes list")
    addTooltip(CharacterHomesDialogFHTeleButton, "Teleport to friend's house\n|c888888Does not save to list|r")

    -- Save (checkmark): adds friend's house to the list
    CharacterHomesDialogFHSaveButton:SetHandler("OnClicked", function()
        if not selectedFriend or not selectedHouseId then
            msg("Select a friend and a house first.")
            return
        end
        local officialKey = getHouseName(selectedHouseId)
        local entryKey    = makeEntryKey(selectedHouseId, selectedFriend)
        local labelText   = zo_strtrim(fhNameEdit:GetText() or "")
        local displayName = labelText ~= "" and labelText
                            or (fhTypeIndex == 1 and "Primary Residence" or officialKey)
        local zone        = getHouseZone(selectedHouseId)
        local entry = { houseId = selectedHouseId, owner = selectedFriend, displayName = displayName, zone = zone }
        if fhTypeIndex == 1 then
            charData().primary = entry
            msg("Primary home set to |cffffff%s|r (|c7a9cbf%s|r).", displayName, selectedFriend)
        elseif fhTypeIndex == 2 then
            charData().named[entryKey] = entry
            msg("Character home '|cffffff%s|r' saved (|c7a9cbf%s|r).", displayName, selectedFriend)
        else
            CH.sv.account[entryKey] = entry
            msg("Account home '|cffffff%s|r' saved (|c7a9cbf%s|r).", displayName, selectedFriend)
        end
        fhNameEdit:SetText("")
        zo_callLater(populateDialog, 0)
    end)

    -- Teleport button: just ports to friend's house, no save
    CharacterHomesDialogFHTeleButton:SetHandler("OnClicked", function()
        if not selectedFriend or not selectedHouseId then
            msg("Select a friend and a house.")
            return
        end
        if not CanJumpToHouseFromCurrentLocation() then
            msg("Cannot teleport from your current location.")
            return
        end
        local houseName = getHouseName(selectedHouseId)
        announce("Attempting to port to |cffffff%s|r at |c7a9cbf%s|r...", houseName, selectedFriend)
        CH.HideDialog()
        JumpToSpecificHouse(selectedFriend, selectedHouseId)
    end)
end

local addLabelEdit -- set by buildAddBar

local function buildAddBar()
    local dlg = CharacterHomesDialog

    addLabelEdit = CharacterHomesDialogAddLabelBgEdit

    -- AddRefBg is an invisible 1×28 control at x=0 in the add bar row, used as an
    -- anchor reference so combo x-offsets mirror the friend housing bar's column positions exactly.
    local ref = CharacterHomesDialogAddRefBg

    -- Type combo at x=286, aligned with friend housing bar type combo
    local typeComboCtrl = WINDOW_MANAGER:CreateControlFromVirtual("CHAddTypeCombo", dlg, "ZO_ComboBox")
    typeComboCtrl:SetAnchor(LEFT, ref, LEFT, 286, 0)
    typeComboCtrl:SetDimensions(200, 28)
    local typeCb = ZO_ComboBox_ObjectFromContainer(typeComboCtrl)
    for i, label in ipairs(ADD_TYPES) do
        local idx = i
        typeCb:AddItem(typeCb:CreateItemEntry(label, function() addTypeIndex = idx end))
    end
    typeCb:SelectFirstItem()

    -- House combo at x=554, mirroring friend housing bar House combo
    local houseComboCtrl = WINDOW_MANAGER:CreateControlFromVirtual("CHAddHouseCombo", dlg, "ZO_ComboBox")
    houseComboCtrl:SetAnchor(LEFT, ref, LEFT, 554, 0)
    houseComboCtrl:SetDimensions(270, 28)
    local houseCb = ZO_ComboBox_ObjectFromContainer(houseComboCtrl)

    local selectedHouseInfo = nil

    local function populateHouseCombo(zoneFilter)
        houseCb:ClearItems()
        selectedHouseInfo = nil
        for _, h in ipairs(getOwnedHouses()) do
            if not zoneFilter or h.zone == zoneFilter then
                local info = h
                houseCb:AddItem(houseCb:CreateItemEntry(h.name, function()
                    selectedHouseInfo = info
                end))
                selectedHouseInfo = selectedHouseInfo or info
            end
        end
        if selectedHouseInfo then houseCb:SelectFirstItem() end
    end
    populateHouseCombo(nil)

    -- zone combo (structure defined in XML): "All zones" plus each zone you own a house in
    local zoneCb = ZO_ComboBox_ObjectFromContainer(CharacterHomesDialogAddZoneCombo)
    zoneCb:SetSortsItems(false)
    zoneCb:AddItem(zoneCb:CreateItemEntry("All zones", function() populateHouseCombo(nil) end))
    local zones, seen = {}, {}
    for _, h in ipairs(getOwnedHouses()) do
        if h.zone and not seen[h.zone] then
            seen[h.zone] = true
            table.insert(zones, h.zone)
        end
    end
    table.sort(zones)
    for _, z in ipairs(zones) do
        local zone = z
        zoneCb:AddItem(zoneCb:CreateItemEntry(zone, function() populateHouseCombo(zone) end))
    end
    zoneCb:SelectFirstItem()

    addTooltip(CharacterHomesDialogSetHomeButton, "Save selected house to your homes list")
    addTooltip(CharacterHomesDialogClearButton,   "Teleport to the selected house\n|c666666Right-click for outside|r")

    -- Save (checkmark) button
    local addBtn = CharacterHomesDialogSetHomeButton
    addBtn:SetHandler("OnClicked", function()
        if not selectedHouseInfo then
            msg("No owned homes found — you must own at least one home.")
            return
        end
        local labelText   = zo_strtrim(addLabelEdit:GetText() or "")
        local displayName = labelText ~= "" and labelText
                            or (addTypeIndex == 1 and "Primary Residence" or selectedHouseInfo.name)
        local entryKey    = makeEntryKey(selectedHouseInfo.houseId, nil)
        local entry = { houseId = selectedHouseInfo.houseId, displayName = displayName, zone = selectedHouseInfo.zone }
        if addTypeIndex == 1 then
            charData().primary = entry
            msg("Primary home set to |cffffff%s|r.", displayName)
        elseif addTypeIndex == 2 then
            charData().named[entryKey] = entry
            msg("Character home '|cffffff%s|r' saved.", displayName)
        else
            CH.sv.account[entryKey] = entry
            msg("Account home '|cffffff%s|r' saved.", displayName)
        end
        addLabelEdit:SetText("")
        zo_callLater(populateDialog, 0)
    end)

    -- Teleport button: ports to currently selected owned house
    local function teleport(exterior)
        if not selectedHouseInfo then
            msg("No owned homes found.")
            return
        end
        if not CanJumpToHouseFromCurrentLocation() then
            msg("Cannot teleport from your current location.")
            return
        end
        announce("Heading %s |cffffff%s|r...", exterior and "outside" or "inside", selectedHouseInfo.name)
        CH.HideDialog()
        RequestJumpToHouse(selectedHouseInfo.houseId, exterior)
    end

    local teleBtn = CharacterHomesDialogClearButton
    teleBtn:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            teleport(false)
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            ClearMenu()
            AddMenuItem("Teleport Inside",  function() teleport(false) end)
            AddMenuItem("Teleport Outside", function() teleport(true)  end)
            ShowMenu(self)
        end
    end)
end

-- Addon shortcut links (right of search box)

local function buildAddonLinks()
    local dlg = CharacterHomesDialog
    local anchorTo = CharacterHomesDialogOwnerFilterLabel  -- each link chains left of the previous control

    local function tryLink(labelText, cmdCandidates, cmdArgs)
        local cmdKey = nil
        for _, k in ipairs(cmdCandidates) do
            if SLASH_COMMANDS[k] then cmdKey = k break end
        end
        if not cmdKey then return end

        local lbl = WINDOW_MANAGER:CreateControl(nil, dlg, CT_LABEL)
        lbl:SetFont("ZoFontGameSmall")
        lbl:SetText("|c5588bb" .. labelText .. "|r")
        lbl:SetAnchor(RIGHT, anchorTo, LEFT, -16, 0)
        lbl:SetMouseEnabled(true)
        lbl:SetHandler("OnMouseEnter", function() lbl:SetText("|cffffff" .. labelText .. "|r") end)
        lbl:SetHandler("OnMouseExit",  function() lbl:SetText("|c5588bb" .. labelText .. "|r") end)
        lbl:SetHandler("OnMouseUp", function(_, btn)
            if btn == MOUSE_BUTTON_INDEX_LEFT then
                SLASH_COMMANDS[cmdKey](cmdArgs)
            end
        end)
        anchorTo = lbl
    end

    tryLink("Open Port to Friend's House",      { "/ptf" },                                    "open")

    addTooltip(CharacterHomesDialogCloseButton, "Close")
end

-- ── Init ──────────────────────────────────────────────────────────────────────

local function onAddonLoaded(_, name)
    if name ~= "CharacterHomes" then return end
    EVENT_MANAGER:UnregisterForEvent("CharacterHomes", EVENT_ADD_ON_LOADED)

    -- Migrate legacy "Default" profile to the server-specific profile so EU and
    -- NA megaserver characters don't share the same saved data bucket.
    -- Total oversight when I created this, forgot there was a separation between NA and EU
    local server = GetWorldName()
    if server and server ~= "" and server ~= "Default" then
        local raw = CharacterHomesSavedVars
        if raw and raw["Default"] and not raw[server] then
            raw[server] = raw["Default"]
            raw["Default"] = nil
        end
    end

    CH.sv = ZO_SavedVars:NewAccountWide("CharacterHomesSavedVars", 3, nil, {
        account     = {},
        characters  = {},
        ownerFilter = 0,
    }, server)

    -- lets the game close the window on Escape and manage the mouse cursor
    SCENE_MANAGER:RegisterTopLevel(CharacterHomesDialog, false)

    -- ensure top-level keys exist (guards against stale saves from older versions)
    if not CH.sv.account        then CH.sv.account     = {} end
    if not CH.sv.characters     then CH.sv.characters  = {} end
    if CH.sv.ownerFilter == nil then CH.sv.ownerFilter = 0 end

    -- chat output is lost before EVENT_PLAYER_ACTIVATED, so conflicts are reported from that handler
    local takenCmds = {}
    local function reg(cmd, fn)
        if SLASH_COMMANDS[cmd] then
            table.insert(takenCmds, cmd)
        else
            SLASH_COMMANDS[cmd] = fn
        end
    end
    -- /sethome conflicts with EHT (which also registers /sethome); use /setglobalhome
    reg("/setglobalhome", function(a) CH.SlashSetHome(a)   end)
    reg("/setmyhome",     function(a) CH.SlashSetMyHome(a) end)
    reg("/resethome",     function()  CH.SlashResetHome()  end)
    reg("/delhome",       function(a) CH.SlashDelHome(a)   end)
    reg("/delmyhome",     function(a) CH.SlashDelMyHome(a) end)
    reg("/gohome",        function(a) CH.SlashHome(a)      end)
    reg("/homes",         function()  CH.SlashHomes()      end)

    -- /home belongs to EHT when it's enabled; claim it only if nothing else has once all addons are loaded
    EVENT_MANAGER:RegisterForEvent("CharacterHomes_HomeCmd", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("CharacterHomes_HomeCmd", EVENT_PLAYER_ACTIVATED)
        if not SLASH_COMMANDS["/home"] then
            SLASH_COMMANDS["/home"] = function(a) CH.SlashHome(a) end
        end
        if #takenCmds > 0 then
            msg("Already used by another addon, not registered: %s", table.concat(takenCmds, " "))
        end
    end)

    -- One-time migration: re-key entries to the official house name and recompute zones
    -- (fixes zones saved before the GetParentZoneId change).
    if not CH.sv.migrated then
        local function migrateTable(tbl)
            local rekeyed = {}
            for k, v in pairs(tbl) do
                local houseName = getHouseName(v.houseId) or k
                local newKey    = makeEntryKey(v.houseId, v.owner)
                v.zone = getHouseZone(v.houseId)
                if not v.displayName or v.displayName == k then
                    v.displayName = houseName
                end
                rekeyed[newKey] = v
            end
            return rekeyed
        end
        CH.sv.account = migrateTable(CH.sv.account)
        for _, charEntries in pairs(CH.sv.characters) do
            if charEntries.primary then
                charEntries.primary.zone = getHouseZone(charEntries.primary.houseId)
            end
            if charEntries.named then
                charEntries.named = migrateTable(charEntries.named)
            end
        end
        CH.sv.migrated = true
    end

    -- owner filter combo (structure defined in XML)
    local ownerCb = ZO_ComboBox_ObjectFromContainer(CharacterHomesDialogOwnerFilterCombo)
    ownerCb:SetSortsItems(false)  -- the saved filter is an index, so keep this order
    for i, opt in ipairs({ "All account homes", "My homes", "Friends' homes" }) do
        local v = i - 1
        ownerCb:AddItem(ownerCb:CreateItemEntry(opt, function()
            accountOwnerFilter = v
            CH.sv.ownerFilter  = v
            zo_callLater(populateDialog, 0)
        end))
    end
    accountOwnerFilter = CH.sv.ownerFilter or 0
    ownerCb:SelectItemByIndex(accountOwnerFilter + 1)

    buildFriendHousingBar()
    buildAddBar()
    buildAddonLinks()
end

EVENT_MANAGER:RegisterForEvent("CharacterHomes", EVENT_ADD_ON_LOADED, onAddonLoaded)

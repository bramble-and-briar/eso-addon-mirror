-- Set Hunter auto-bind: binds a looted bind-on-equip or still-tradeable dungeon/trial piece the first time it's new to your Sticker Book.
-- Binding can't be undone, so it's off by default and any set or single piece can be left out.
-- Only loot counts. Trader purchases, mail and trades are never bound.

local SH = ESOC_SetHunter
local B = {}
SH.AutoBind = B

local DIALOG = "ESOC_SETHUNTER_CLEAR_BIND_EXCEPTIONS"
local LOOT_DELAY = 500
local CHECK_DELAY = 800

local pending = {}  -- looted links waiting to be checked, kept through combat
local claimed = {}  -- [pieceId] = true once a copy is being bound, so a second drop stays free

local function alert(text) pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. text) end

local function exceptions()
    local sv = SH.internal.sv
    sv.noBindSets = sv.noBindSets or {}
    sv.noBindPieces = sv.noBindPieces or {}
    return sv.noBindSets, sv.noBindPieces
end

-- The Sticker Book piece with this set and shape.
local function pieceFor(setId, equip, armor, weapon)
    local I = SH.internal
    for index = 1, GetNumItemSetCollectionPieces(setId) do
        local pieceId = GetItemSetCollectionPieceInfo(setId, index)
        local link = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
        local pieceEquip, pieceArmor, pieceWeapon = I.LinkShape(link)
        if pieceEquip == equip and pieceArmor == armor and pieceWeapon == weapon then return pieceId end
    end
    return nil
end

-- Returns the piece id if this item should be bound.
function B.PieceToBind(bag, slot)
    local I = SH.internal
    local link = GetItemLink(bag, slot)
    local setId = I.SetIdOf(link)
    if not setId then return nil end
    if IsItemBound(bag, slot) or IsItemStolen(bag, slot) then return nil end
    -- Bind-on-equip pieces, and dungeon or trial drops still tradeable with the group
    -- (those don't reach the Sticker Book until they're bound, the same as the game's own Bind option).
    if GetItemBindType(bag, slot) ~= BIND_TYPE_ON_EQUIP and not IsItemBoPAndTradeable(bag, slot) then return nil end
    local noSets, noPieces = exceptions()
    if noSets[setId] then return nil end
    local pieceId = pieceFor(setId, I.LinkShape(link))
    if not pieceId or noPieces[pieceId] or claimed[pieceId] then return nil end
    if IsItemSetCollectionPieceUnlocked(pieceId) then return nil end
    return pieceId
end

local function bindItem(bag, slot, pieceId)
    local link = GetItemLink(bag, slot)
    local name = zo_strformat("<<t:1>>", GetItemLinkName(link))
    local uniqueId = GetItemUniqueId(bag, slot)
    claimed[pieceId] = true
    local ok
    if IsProtectedFunction and IsProtectedFunction("BindItem") then
        ok = pcall(CallSecureProtected, "BindItem", bag, slot)
    else
        ok = pcall(BindItem, bag, slot)
    end
    zo_callLater(function()
        if ok and GetItemUniqueId(bag, slot) == uniqueId and IsItemBound(bag, slot) then
            alert("bound " .. name .. " to your Sticker Book")
        else
            claimed[pieceId] = nil
            alert("couldn't bind " .. name .. ", so bind it yourself")
        end
        pcall(SH.MarkAllDirty)
        pcall(SH.Refresh)
    end, CHECK_DELAY)
end

-- Binds what's waiting, unless you're in combat. The next time combat ends, it tries again.
function B.Flush()
    local I = SH.internal
    if not I.opts.autoBind then
        pending = {}
        return
    end
    if IsUnitInCombat("player") then return end
    local waiting = pending
    pending = {}
    for _, link in ipairs(waiting) do
        local setId = I.SetIdOf(link)
        local equip, armor, weapon = I.LinkShape(link)
        local trait = GetItemLinkTraitType(link)
        for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
            if GetItemId(BAG_BACKPACK, slot) ~= 0 then
                local item = GetItemLink(BAG_BACKPACK, slot)
                if I.SetIdOf(item) == setId and I.SameShape({ equip = equip, armor = armor, weapon = weapon }, I.LinkShape(item))
                    and GetItemLinkTraitType(item) == trait then
                    local pieceId = B.PieceToBind(BAG_BACKPACK, slot)
                    if pieceId then
                        bindItem(BAG_BACKPACK, slot, pieceId)
                        break
                    end
                end
            end
        end
    end
end

function B.OnLoot(_, _, link, _, _, _, lootedBySelf)
    local I = SH.internal
    if not lootedBySelf or not I.opts.autoBind or type(link) == "nil" or link == "" then return end
    if not I.SetIdOf(link) then return end
    pending[#pending + 1] = link
    zo_callLater(function() pcall(B.Flush) end, LOOT_DELAY)
end

---------------------------------------------------------------------------
-- Exceptions
---------------------------------------------------------------------------
function B.TogglePiece(data)
    local _, noPieces = exceptions()
    local pieceId = data:GetId()
    if noPieces[pieceId] then
        noPieces[pieceId] = nil
    else
        noPieces[pieceId] = zo_strformat("<<t:1>>", GetItemLinkName(data:GetItemLink()))
    end
end

function B.ToggleSet(data)
    local noSets = exceptions()
    local setId = data:GetSetId()
    if noSets[setId] then
        noSets[setId] = nil
    else
        noSets[setId] = zo_strformat("<<t:1>>", GetItemSetName(setId))
    end
end

function B.AddBookKeys(descriptor, selectedPiece)
    local function shown() return SH.internal.opts.autoBind and selectedPiece() ~= nil end
    descriptor[#descriptor + 1] = {
        keybind = "UI_SHORTCUT_LEFT_STICK",
        name = function()
            local data = selectedPiece()
            local _, noPieces = exceptions()
            if data and noPieces[data:GetId()] then return "Auto-bind this piece" end
            return "Don't auto-bind piece"
        end,
        visible = shown,
        callback = function()
            local data = selectedPiece()
            if not data then return end
            B.TogglePiece(data)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
        end,
    }
    descriptor[#descriptor + 1] = {
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        name = function()
            local data = selectedPiece()
            local noSets = exceptions()
            if data and noSets[data:GetSetId()] then return "Auto-bind this set" end
            return "Don't auto-bind set"
        end,
        visible = shown,
        callback = function()
            local data = selectedPiece()
            if not data then return end
            B.ToggleSet(data)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
        end,
    }
end

function B.HasExceptions()
    if not SH.internal then return false end
    local noSets, noPieces = exceptions()
    return next(noSets) ~= nil or next(noPieces) ~= nil
end

function B.StatusText()
    if not SH.internal then return "" end
    local noSets, noPieces = exceptions()
    local sets, pieces = 0, 0
    for _ in pairs(noSets) do sets = sets + 1 end
    for _ in pairs(noPieces) do pieces = pieces + 1 end
    if sets + pieces == 0 then return "Auto-bind exceptions: none" end
    return "Auto-bind exceptions: " .. sets .. (sets == 1 and " set, " or " sets, ") .. pieces .. (pieces == 1 and " piece" or " pieces")
end

function B.ExceptionsText()
    local noSets, noPieces = exceptions()
    local names = {}
    for _, name in pairs(noSets) do names[#names + 1] = name .. " (whole set)" end
    for _, name in pairs(noPieces) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then return "In the Sticker Book, press L3 to skip a piece or R3 to skip a whole set." end
    return "Never auto-bound:\n" .. table.concat(names, "\n")
end

function B.ClearExceptions()
    local sv = SH.internal.sv
    sv.noBindSets, sv.noBindPieces = {}, {}
end

function B.OfferClear(onDone)
    if not B.HasExceptions() then return end
    ZO_Dialogs_ShowGamepadDialog(DIALOG, { onDone = onDone })
end

function B.ResetForTest()
    pending, claimed = {}, {}
end

function B.Init()
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Clear auto-bind exceptions" },
        mainText = { text = function() return "Remove every exception? Those sets and pieces can then be auto-bound." end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Clear", callback = function(dialog)
                B.ClearExceptions()
                if dialog.data.onDone then dialog.data.onDone() end
            end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })
    EVENT_MANAGER:RegisterForEvent("ESOCSetHunterBind", EVENT_LOOT_RECEIVED, function(...) pcall(B.OnLoot, ...) end)
end

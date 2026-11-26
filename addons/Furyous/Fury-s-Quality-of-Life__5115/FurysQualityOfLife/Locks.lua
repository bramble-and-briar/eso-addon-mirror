-- Fury's Quality of Life - lock what I'm wearing
-- Puts the game's own lock on every piece of gear the character has equipped (both weapon
-- bars included), or takes it off again. A locked item can't be deconstructed, sold, traded or
-- destroyed until it is unlocked, and Select all never picks it up.

local QOL = FurysQualityOfLife

-- Locks (true) or unlocks (false) everything worn. Returns how many items changed.
local function SetWornLocked(locked)
    local changed = 0
    for slot = 0, GetBagSize(BAG_WORN) - 1 do
        if CanItemBePlayerLocked(BAG_WORN, slot) and IsItemPlayerLocked(BAG_WORN, slot) ~= locked then
            SetItemIsPlayerLocked(BAG_WORN, slot, locked)
            changed = changed + 1
        end
    end
    return changed
end

local function Count(n)
    if n == 1 then return "1 item" end
    return n .. " items"
end

function QOL.LockWorn()
    local n = SetWornLocked(true)
    if n == 0 then
        QOL.Msg("Everything you are wearing is already locked.")
    else
        QOL.Msg("Locked " .. Count(n) .. " you are wearing.")
    end
end

function QOL.UnlockWorn()
    local n = SetWornLocked(false)
    if n == 0 then
        QOL.Msg("Nothing you are wearing is locked.")
    else
        QOL.Msg("Unlocked " .. Count(n) .. " you are wearing.")
    end
end

------------------------------------------------------------------------------
-- The two buttons on the inventory screen, under the weapons of the "Equipped" panel on the
-- left (keyboard interface). Shown only while their switch is on.
------------------------------------------------------------------------------
local lockButton, unlockButton

local function MakeButton(name, text, onClick, tip)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(name, ZO_Character, "ZO_DefaultButton")
    button:SetDimensions(172, 28)
    button:SetText(text)
    button:SetHandler("OnClicked", onClick)
    QOL.Theme.Tip(button, tip)
    button:SetHidden(true)
    return button
end

function QOL.RefreshLockButtons()
    local hidden = not QOL.SV().lockButtons
    lockButton:SetHidden(hidden)
    unlockButton:SetHidden(hidden)
end

function QOL.InitLocks()
    lockButton = MakeButton("FurysQualityOfLife_LockWorn", "Lock worn gear", QOL.LockWorn,
        "Fury's Quality of Life: puts the game's lock on everything this character is wearing, both weapon bars included. Locked items can't be deconstructed, sold, traded or destroyed.")
    lockButton:SetAnchor(TOPLEFT, ZO_CharacterEquipmentSlotsBackupMain, BOTTOMLEFT, 0, 14)
    unlockButton = MakeButton("FurysQualityOfLife_UnlockWorn", "Unlock worn gear", QOL.UnlockWorn,
        "Fury's Quality of Life: takes the lock off everything this character is wearing.")
    unlockButton:SetAnchor(TOPLEFT, lockButton, BOTTOMLEFT, 0, 6)
    QOL.RefreshLockButtons()
end

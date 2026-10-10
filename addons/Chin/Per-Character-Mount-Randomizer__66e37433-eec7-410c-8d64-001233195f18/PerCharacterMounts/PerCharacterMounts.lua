--[[
    Per-Character Mounts
    Copyright (c) 2026 the author. All rights reserved.
    No copying, modifying, reusing or redistributing any part of this code
    without written permission. See LICENSE.md.

    ESO stores favourite mounts account-wide. With this addon each character
    has its own favourites, starting from a clean slate: star the mounts you
    want on that character and it switches to "Random Favorite Mount". Its
    list is put back every time you log in to it.

    It's on for every character by default. Turn it off for a character (the
    settings menu, or /pcm off) and that character uses your normal favourites
    again: the ones you had before installing, plus any you change while it's
    off.

    The settings menu (Settings > Add-Ons) shows this character's list. On
    console its Mounts screen lists every mount you own, grouped as in
    Collections: Triangle adds or removes a favourite.
]]

local ADDON_NAME = "PerCharacterMounts"
local ADDON_VERSION = "1.4.6"
-- Stored with each character. 2 (1.3.2): characters that 1.3.0 or 1.3.1 left
-- off are turned back on once. 3 (1.4.3): characters that already have a list
-- of their own are switched to Random Favorite Mount once.
local DATA_REVISION = 3

local MOUNT = COLLECTIBLE_CATEGORY_TYPE_MOUNT
local FAVOURITE = COLLECTIBLE_USER_FLAG_FAVORITE
local PLAYER = GAMEPLAY_ACTOR_CATEGORY_PLAYER

-- Favourites are changed one at a time, this far apart, so swapping a big set
-- doesn't flood the server.
local CHANGE_INTERVAL_MS = 200
-- After the last change, give the server this long before checking the result.
local VERIFY_DELAY_MS = 2000
local MAX_ATTEMPTS = 3
local LINKS_PER_LINE = 8
-- On the first run, the UI reloads this long after login to save the normal
-- favourites; if it hasn't reloaded this much later, carry on without it.
local RELOAD_DELAY_MS = 1500
local RELOAD_TIMEOUT_MS = 10000

local savedCharacters -- every character's saved data on this server, by character ID
local character -- this character's saved data: name, account, enabled, favourites, randomMountType, switchToRandomFavourite
local normals -- this server's normal favourites, by account
local normal -- this account's normal favourites: favourites, timestamp
-- ESO only writes saved data on logout or /reloadui, so until the normal
-- favourites have been written once, nothing is un-starred.
local normalIsSaved = false
-- Mounts saved on disk when this session started (normal favourites and every
-- character's list). Only these are ever un-starred: something saved only this
-- session would be lost if the game crashed before ESO wrote it.
local savedOnDisk = {}
-- "loading" until the player is in the world, "swapping" while the right
-- favourites are put on the account, then "ready".
local state = "loading"
local requested = {} -- while swapping: the favourite state this addon asked for, by collectible ID
-- Favourite mounts on the account as last seen. A flag event that doesn't
-- change this (the game repeating what's already there) isn't a player's change.
local known = {}
-- On or off, asked for while swapping: applied as soon as the swap ends.
local pendingEnabled
-- This character was off and 1.3.2 turned it back on (see DATA_REVISION).
local turnedBackOn = false
-- With no favourite mounts on the account, the game switches "Random Favorite
-- Mount" to "Random Mount" by itself; this is set when that may have happened.
local gameMaySwitchToAny = false
local queue = {}
local attempts = 0
local changesSent = 0
local applyReason -- "first", "login", "on", "off", "apply", "copy", "edit" or "clear"
local copiedCount = 0
-- Mounts taken off this character's list in the settings menu. They're
-- un-starred even if they're saved nowhere else: the player asked for it.
local dropped = {}
-- The list was edited in the settings menu during a swap (see Verify).
local pendingEdit = false
-- Settings menu
local settingsPanel -- the LibHarvensAddonSettings or LibAddonMenu-2.0 panel, if either is installed
local settingsUsesLam = false
local selectedMount -- the mount picked in the settings menu
local mountNames = {} -- display names, by collectible ID
-- Clear all was pressed once on console and waits for the second press.
local clearArmed = false

local function Print(message, ...)
    CHAT_ROUTER:AddSystemMessage("|c7FB2E5Per-Character Mounts:|r " .. string.format(message, ...))
end

local function MountCount(count)
    if count == 1 then
        return "1 favourite mount"
    end
    return string.format("%d favourite mounts", count)
end

local function IsFavourite(collectibleId)
    return ZO_FlagHelpers.MaskHasFlag(GetCollectibleUserFlags(collectibleId), FAVOURITE)
end

local function HasAnyFavouriteMounts()
    return DoesCollectibleCategoryContainAnyCollectiblesWithUserFlags(MOUNT, FAVOURITE)
end

local function CopySet(set)
    local copy = {}
    for key in pairs(set) do
        copy[key] = true
    end
    return copy
end

-- Reads the account's favourite mounts, and remembers them as the last seen.
local function GetAccountFavourites()
    local favourites = {}
    for index = 1, GetTotalCollectiblesByCategoryType(MOUNT) do
        local collectibleId = GetCollectibleIdFromType(MOUNT, index)
        if IsFavourite(collectibleId) then
            favourites[collectibleId] = true
        end
    end
    known = CopySet(favourites)
    return favourites
end

local function MountName(collectibleId)
    local name = mountNames[collectibleId]
    if not name then
        name = zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleName(collectibleId))
        mountNames[collectibleId] = name
    end
    return name
end

-- Redraws the settings menu, if it's open.
local function RefreshSettings()
    if not settingsPanel then
        return
    elseif settingsUsesLam then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    elseif settingsPanel.selected then
        settingsPanel:UpdateControls()
    end
end

local function PrintMountLinks(collectibleIds)
    local mounts = {}
    for collectibleId in pairs(collectibleIds) do
        table.insert(mounts, {
            name = GetCollectibleName(collectibleId),
            link = GetCollectibleLink(collectibleId, LINK_STYLE_BRACKETS),
        })
    end
    table.sort(mounts, function(a, b) return a.name < b.name end)
    for first = 1, #mounts, LINKS_PER_LINE do
        local links = {}
        for index = first, math.min(first + LINKS_PER_LINE - 1, #mounts) do
            table.insert(links, mounts[index].link)
        end
        CHAT_ROUTER:AddSystemMessage(table.concat(links, ", "))
    end
end

-- The list this character's favourites should match: its own when it's on,
-- your normal favourites when it's off.
local function GetTargetList()
    if character.enabled and normalIsSaved then
        return character.favourites
    end
    return normal.favourites
end

-- Favourites saved somewhere other than the target list: your normal ones and
-- characters' own lists (this one's too, when it's off). Deleted characters
-- don't count, as their lists can never be loaded again.
-- Whether a saved character still exists, so its list can be loaded again. A
-- character list missing this character can't be trusted to say which were
-- deleted; then every saved character of this account counts.
local function GetCharacterCounter()
    local existing = {}
    for index = 1, GetNumCharacters() do
        local _, _, _, _, _, _, characterId = GetCharacterInfo(index)
        existing[characterId] = true
    end
    local listIsReliable = existing[GetCurrentCharacterId()]
    local account = GetDisplayName()
    return function(characterId, entry)
        if listIsReliable then
            return existing[characterId]
        end
        return entry.account == nil or entry.account == account
    end
end

local function GetFavouritesSavedElsewhere()
    local counts = GetCharacterCounter()
    local target = GetTargetList()
    local saved = {}
    if normal.favourites ~= target then
        for collectibleId in pairs(normal.favourites) do
            saved[collectibleId] = true
        end
    end
    for characterId, other in pairs(savedCharacters) do
        if counts(characterId, other) and other.favourites and other.favourites ~= target then
            for collectibleId in pairs(other.favourites) do
                saved[collectibleId] = true
            end
        end
    end
    return saved
end

-- A favourite that isn't saved anywhere (set just before a crash, say) joins
-- your normal favourites, so it's never lost.
local function SaveUnsavedFavourites(accountFavourites)
    local target = GetTargetList()
    local savedElsewhere = GetFavouritesSavedElsewhere()
    local added = 0
    for collectibleId in pairs(accountFavourites) do
        if not target[collectibleId] and not savedElsewhere[collectibleId] and not dropped[collectibleId] then
            normal.favourites[collectibleId] = true
            added = added + 1
        end
    end
    if added > 0 and normal.favourites ~= target then
        Print("added %s that no character had saved to your normal favourites.", MountCount(added))
    end
end

-- The changes that make the account's favourites match the target list.
-- Additions come first: if the account is ever left with no favourite mounts,
-- the game switches "Random Favorite Mount" over to "Random Mount". Mounts you
-- don't own are left alone, as the game only lets you favourite mounts you own,
-- and so are mounts not yet saved on disk (they're un-starred next session),
-- unless they were taken off in the settings menu.
local function GetPendingChanges(accountFavourites)
    local target = GetTargetList()
    local changes = {}
    for collectibleId in pairs(target) do
        if not accountFavourites[collectibleId] and IsCollectibleUnlocked(collectibleId) then
            table.insert(changes, { collectibleId = collectibleId, favourite = true })
        end
    end
    for collectibleId in pairs(accountFavourites) do
        if not target[collectibleId] and IsCollectibleUnlocked(collectibleId)
            and (savedOnDisk[collectibleId] or dropped[collectibleId]) then
            table.insert(changes, { collectibleId = collectibleId, favourite = false })
        end
    end
    return changes
end

-- Reads the account once, saves unsaved favourites, and works out what's left to change.
local function PlanChanges()
    local accountFavourites = GetAccountFavourites()
    SaveUnsavedFavourites(accountFavourites)
    return GetPendingChanges(accountFavourites), accountFavourites
end

-- Puts this character on "Random Favorite Mount" once the account has
-- favourites: after mounts were added to its list (see WantRandomFavourite),
-- or when the game switched it to "Random Mount" because the account had none
-- (say the last character played had none, or its list was cleared). Any
-- other switch the player made is left alone.
local function RestoreRandomFavourite()
    if not HasAnyFavouriteMounts() then
        return -- with no favourites yet (a clean slate, say), once there are some
    end
    local current = GetRandomMountType(PLAYER)
    if character.switchToRandomFavourite and current ~= RANDOM_MOUNT_TYPE_FAVORITE then
        SetRandomMountType(RANDOM_MOUNT_TYPE_FAVORITE, PLAYER)
        Print("Random Favorite Mount is on for %s.", character.name)
    elseif gameMaySwitchToAny and character.randomMountType == RANDOM_MOUNT_TYPE_FAVORITE
        and current == RANDOM_MOUNT_TYPE_ANY then
        SetRandomMountType(RANDOM_MOUNT_TYPE_FAVORITE, PLAYER)
    end
    character.switchToRandomFavourite = nil
    gameMaySwitchToAny = false
end

-- Mounts added to this character's own list are meant for Random Favorite
-- Mount, so adding one switches the character to it (see
-- RestoreRandomFavourite). A switch the player makes afterwards sticks until
-- the next mount is added.
local function WantRandomFavourite()
    character.switchToRandomFavourite = true
end

local Apply

local function Finish(failedCount, accountFavourites)
    state = "ready"
    if pendingEnabled ~= nil then
        -- Turned on or off during the swap: switch now.
        character.enabled = pendingEnabled
        pendingEnabled = nil
        Apply(character.enabled and "on" or "off")
        return
    end

    local count = NonContiguousCount(accountFavourites)
    if failedCount > 0 then
        Print("couldn't update %s. Type /pcm apply to try again.", MountCount(failedCount))
    elseif (applyReason == "first" or applyReason == "on") and count == 0 then
        Print("on for %s, starting from a clean slate. Star the mounts you want and Random Favorite Mount switches on. /pcm off brings back your normal favourites.", character.name)
    elseif applyReason == "on" then
        Print("on for %s: %s.", character.name, MountCount(count))
    elseif applyReason == "off" then
        Print("off for %s. Your normal favourites are back (%s).", character.name, MountCount(count))
    elseif applyReason == "copy" then
        Print("added %s from your normal favourites. %s now has %s.", MountCount(copiedCount), character.name, MountCount(count))
    elseif applyReason == "clear" then
        Print("cleared %s's favourite mounts.", character.name)
    elseif applyReason == "edit" then
        -- Changed in the settings menu, which shows the result.
    elseif not character.enabled then
        -- Said at every login, so a character that's off is never a surprise.
        Print("off for %s, so it uses your normal favourites (%s). /pcm on gives it its own again.", character.name, MountCount(count))
    elseif changesSent > 0 then
        Print("switched to %s's %s.", character.name, MountCount(count))
    elseif applyReason == "apply" then
        Print("%s's favourite mounts are already in place.", character.name)
    end
    RestoreRandomFavourite()
    RefreshSettings()
end

local StartApplying

local function Verify()
    if pendingEdit then
        -- The list was edited during the swap: fresh attempts for the new list.
        pendingEdit = false
        attempts = 0
    end
    local remaining, accountFavourites = PlanChanges()
    -- Forget changes the list no longer wants (it was edited since), so the
    -- player changing that mount later isn't taken for this addon's change
    -- coming back. Ones it still wants are sent again if they didn't stick.
    local target = GetTargetList()
    for collectibleId, favourite in pairs(requested) do
        if (target[collectibleId] or false) ~= favourite then
            requested[collectibleId] = nil
        end
    end
    if #remaining == 0 or attempts >= MAX_ATTEMPTS then
        Finish(#remaining, accountFavourites)
    else
        StartApplying(remaining)
    end
end

-- Sends the next change that still needs making. Ones already in place, or that
-- the list no longer wants (it was edited mid-swap), don't use up a turn.
local function SendNextChange()
    local target = GetTargetList()
    while #queue > 0 do
        local change = table.remove(queue, 1)
        if IsFavourite(change.collectibleId) ~= change.favourite
            and (target[change.collectibleId] or false) == change.favourite then
            requested[change.collectibleId] = change.favourite
            SetOrClearCollectibleUserFlag(change.collectibleId, FAVOURITE, change.favourite)
            changesSent = changesSent + 1
            return
        end
    end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
    zo_callLater(Verify, VERIFY_DELAY_MS)
end

function StartApplying(changes)
    attempts = attempts + 1
    queue = changes
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, CHANGE_INTERVAL_MS, SendNextChange)
    SendNextChange()
end

function Apply(reason)
    state = "swapping"
    requested = {}
    attempts = 0
    changesSent = 0
    applyReason = reason
    local changes, accountFavourites = PlanChanges()
    if #changes > 0 then
        StartApplying(changes)
    else
        Finish(0, accountFavourites)
    end
end

local function IsBusy()
    if state ~= "ready" then
        Print("still updating %s's favourite mounts. Try again in a moment.", character.name)
        return true
    end
    return false
end

-- Whether this character is on, counting a switch waiting for the swap to end.
local function IsEnabled()
    if pendingEnabled ~= nil then
        return pendingEnabled
    end
    return character.enabled
end

local function SetEnabled(enabled)
    if not normalIsSaved then
        Print("still saving your normal favourites. Try again after the UI reload.")
        return
    end
    if enabled == IsEnabled() then
        Print("already %s for %s.", enabled and "on" or "off", character.name)
        return
    end
    if state ~= "ready" then
        -- Mid-swap: keep the switch for when it ends rather than dropping it.
        if enabled == character.enabled then
            pendingEnabled = nil
        else
            pendingEnabled = enabled
        end
        Print("switching %s for %s once the current swap is done.", enabled and "on" or "off", character.name)
        return
    end
    character.enabled = enabled
    character.favourites = character.favourites or {}
    Apply(enabled and "on" or "off")
end

-- Adds your normal favourites to this character's own list.
local function CopyNormalFavourites()
    if not character.enabled then
        Print("off for %s, so it already uses your normal favourites.", character.name)
        return
    end
    copiedCount = 0
    for collectibleId in pairs(normal.favourites) do
        if not character.favourites[collectibleId] then
            character.favourites[collectibleId] = true
            copiedCount = copiedCount + 1
        end
    end
    if copiedCount == 0 then
        Print("%s already has all of your normal favourites.", character.name)
    else
        WantRandomFavourite()
        Apply("copy")
    end
end

local function ShowStatus()
    local list = GetTargetList()
    local count = NonContiguousCount(list)
    if character.enabled then
        Print("on for %s, with %s%s", character.name, MountCount(count), count > 0 and ":" or ".")
    else
        Print("off for %s, using your normal favourites (%s)%s", character.name, MountCount(count), count > 0 and ":" or ".")
    end
    if count > 0 then
        PrintMountLinks(list)
    end
    Print("/pcm on, /pcm off, /pcm copy adds your normal favourites to this character, /pcm clear empties its list, /pcm apply re-applies.")
end

-- Editing this character's list from the settings menu -----------------------

local function CanEditList()
    return normalIsSaved and IsEnabled()
end

-- Puts the edited list on the account: now, or once the current swap has done
-- its checks (see Verify).
local function ApplyEdit(reason)
    if state == "ready" then
        Apply(reason)
    else
        pendingEdit = true
        if reason == "clear" then
            applyReason = reason
        end
    end
    RefreshSettings()
end

local function SetFavourite(collectibleId, isFavourite)
    if not collectibleId or not CanEditList() or (character.favourites[collectibleId] or false) == isFavourite then
        return
    end
    character.favourites[collectibleId] = isFavourite or nil
    dropped[collectibleId] = not isFavourite or nil
    if isFavourite then
        WantRandomFavourite()
    end
    ApplyEdit("edit")
end

local function ClearFavourites()
    clearArmed = false
    if not CanEditList() then
        return
    end
    for collectibleId in pairs(character.favourites) do
        character.favourites[collectibleId] = nil
        dropped[collectibleId] = true
    end
    ApplyEdit("clear")
end

local function OnSlashCommand(arguments)
    local command = zo_strlower(zo_strtrim(arguments))
    if command == "on" then
        SetEnabled(true)
    elseif command == "off" then
        SetEnabled(false)
    elseif command == "clear" then
        if CanEditList() then
            ClearFavourites()
        else
            Print("off for %s, so there's no list to clear. /pcm on turns it back on.", character.name)
        end
    elseif IsBusy() then
        return
    elseif command == "apply" then
        Apply("apply")
    elseif command == "copy" or command == "restore" then
        CopyNormalFavourites()
    else
        ShowStatus()
    end
end

-- Previewing a mount from the PC menu ----------------------------------------

local function CanPreview(collectibleId)
    return collectibleId ~= nil and CanCollectibleBePreviewed(collectibleId) and IsCharacterPreviewingAvailable()
end

-- Collections opens on the mount, which previews it there.
local function PreviewMount(collectibleId)
    if CanPreview(collectibleId) then
        COLLECTIONS_BOOK_SINGLETON:BrowseToCollectible(collectibleId)
    end
end

-- Settings menu --------------------------------------------------------------
-- Console, and PC without LibAddonMenu-2.0, use LibHarvensAddonSettings: a
-- Mounts entry that opens the mount list (below), Clear all, and the on/off
-- switch. PC uses LibAddonMenu-2.0: a mount picker with Add, Remove and
-- Preview next to this character's list, Clear all, and the switch.
--
-- On console this addon opens no game dialogs and previews nothing. A game
-- dialog opened by an addon taints the buttons all game dialogs share, and the
-- console's add-on browser then can't install or update add-ons until the UI
-- reloads. Previewing a collectible is closed to addons (PreviewCollectible is
-- private).

local PICK_A_MOUNT = "Choose a mount"
-- Clear all on console needs a second press within this long.
local CLEAR_CONFIRM_MS = 5000

-- The PC picker's entries, and the mount behind each one
local pickerMounts = {}
local pickerNames = {}
local lamChoices = {}

-- An owned mount that Collections shows (it hides a few in every case).
local function IsListedMount(collectibleId)
    return IsCollectibleUnlocked(collectibleId) and GetCollectibleHideMode(collectibleId) ~= COLLECTIBLE_HIDE_MODE_ALWAYS
end

-- Owned mounts, sorted by name.
local function GetOwnedMounts()
    local mounts = {}
    for index = 1, GetTotalCollectiblesByCategoryType(MOUNT) do
        local collectibleId = GetCollectibleIdFromType(MOUNT, index)
        if IsListedMount(collectibleId) then
            table.insert(mounts, collectibleId)
        end
    end
    table.sort(mounts, function(a, b) return MountName(a) < MountName(b) end)
    return mounts
end

-- Builds the PC picker: every owned mount by name, after a "choose" entry.
local function BuildPicker()
    local entries = { PICK_A_MOUNT }
    local seen = {}
    pickerMounts, pickerNames = {}, {}
    for _, collectibleId in ipairs(GetOwnedMounts()) do
        local name = MountName(collectibleId)
        seen[name] = (seen[name] or 0) + 1
        if seen[name] > 1 then
            name = string.format("%s (%d)", name, seen[name])
        end
        table.insert(entries, name)
        pickerMounts[name] = collectibleId
        pickerNames[collectibleId] = name
    end
    return entries
end

-- This character's mounts sorted by name, and how many.
local function GetListedMounts()
    local mounts = {}
    for collectibleId in pairs(character.favourites) do
        table.insert(mounts, collectibleId)
    end
    table.sort(mounts, function(a, b) return MountName(a) < MountName(b) end)
    return mounts, #mounts
end

local function GetListTitle()
    local _, count = GetListedMounts()
    return string.format("%s's favourite mounts: %d", character.name, count)
end

-- One line, for the gamepad's info panel.
local function GetListText()
    local mounts, count = GetListedMounts()
    local names = {}
    for index, collectibleId in ipairs(mounts) do
        names[index] = MountName(collectibleId)
    end
    local list = table.concat(names, ", ") .. "."
    if not character.enabled then
        if count == 0 then
            return string.format("Off for %s, so it uses your normal favourites.", character.name)
        end
        return string.format("Off for %s, so it uses your normal favourites. Its own list, kept for when it's back on: %s", character.name, list)
    elseif count == 0 then
        return string.format("%s has no favourite mounts yet.", character.name)
    end
    return string.format("%s's favourites: %s", character.name, list)
end

-- One mount per line with its icon, for the keyboard menu.
local function GetListLines()
    local mounts, count = GetListedMounts()
    if count == 0 then
        return "None yet."
    end
    local lines = {}
    for index, collectibleId in ipairs(mounts) do
        lines[index] = zo_iconTextFormat(GetCollectibleIcon(collectibleId), 32, 32, MountName(collectibleId))
    end
    return table.concat(lines, "\n")
end

local function GetActionTooltip(action)
    if not selectedMount then
        return "Pick a mount first."
    end
    return string.format(action, MountName(selectedMount), character.name)
end

local function CannotAdd()
    return not CanEditList() or not selectedMount or character.favourites[selectedMount] == true
end

local function CannotRemove()
    return not CanEditList() or not selectedMount or not character.favourites[selectedMount]
end

local function CannotClear()
    return not CanEditList() or next(character.favourites) == nil
end

-- Console Clear all: the first press asks for a second, which clears.
local clearPresses = 0

local function PressClearAll()
    if CannotClear() then
        clearArmed = false
        return
    end
    if clearArmed then
        ClearFavourites()
        return
    end
    clearArmed = true
    clearPresses = clearPresses + 1
    local press = clearPresses
    zo_callLater(function()
        if clearArmed and clearPresses == press then
            clearArmed = false
            RefreshSettings()
        end
    end, CLEAR_CONFIRM_MS)
    RefreshSettings()
end

-- Console mount list ----------------------------------------------------------
-- Every mount you own in the right-hand panel: this character's favourites at
-- the top, then all of them grouped as Collections groups them. Favourites
-- carry Collections' star, so adding or removing one leaves every mount
-- where it is and the cursor on its row. Triangle adds or removes a favourite
-- and Back returns to the menu. It's the game's own list screen;
-- PerCharacterMounts.xml puts it on the right.

local MOUNT_LIST_SCENE = "PerCharacterMountsGamepad"
-- Collections' own row, with room for its favourite star.
local MOUNT_ROW = "ZO_GamepadSubMenuEntryTemplateWithStatus"
local mountList -- created the first time it's opened

-- Owned mounts in the game's collection categories, in Collections' order.
-- Read from the game's collection functions directly: its collection data
-- object rebuilds shared game data when called, and addon code shouldn't
-- set that off.
local function GetMountGroups()
    local groups, byCategory, sortKeys = {}, {}, {}
    for index = 1, GetTotalCollectiblesByCategoryType(MOUNT) do
        local collectibleId = GetCollectibleIdFromType(MOUNT, index)
        if IsListedMount(collectibleId) then
            local topLevelIndex, subcategoryIndex = GetCategoryInfoFromCollectibleId(collectibleId)
            local categoryId = topLevelIndex and GetCollectibleCategoryId(topLevelIndex, subcategoryIndex) or 0
            local group = byCategory[categoryId]
            if not group then
                group = {
                    name = topLevelIndex and zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleCategoryNameByCategoryId(categoryId)) or "Mounts",
                    topLevelIndex = topLevelIndex or math.huge,
                    subcategoryIndex = subcategoryIndex or 0,
                    mounts = {},
                }
                byCategory[categoryId] = group
                table.insert(groups, group)
            end
            table.insert(group.mounts, collectibleId)
            sortKeys[collectibleId] = {
                GetCollectibleSortOrder(collectibleId),
                IsCollectibleValidForPlayer(collectibleId),
                GetCollectibleName(collectibleId),
            }
        end
    end
    table.sort(groups, function(a, b)
        if a.topLevelIndex ~= b.topLevelIndex then
            return a.topLevelIndex < b.topLevelIndex
        end
        return a.subcategoryIndex < b.subcategoryIndex
    end)
    -- Collections' order within a category, without its favourites first.
    local function Compare(a, b)
        local keyA, keyB = sortKeys[a], sortKeys[b]
        if keyA[1] ~= keyB[1] then
            return keyA[1] < keyB[1]
        elseif keyA[2] ~= keyB[2] then
            return keyA[2]
        end
        return keyA[3] < keyB[3]
    end
    for _, group in ipairs(groups) do
        table.sort(group.mounts, Compare)
    end
    return groups
end

local function CreateMountList()
    local MountList = ZO_Gamepad_ParametricList_Screen:Subclass()

    function MountList:Initialize(control)
        local scene = ZO_Scene:New(MOUNT_LIST_SCENE, SCENE_MANAGER)
        ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, true, scene)
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
        scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_LEFT)
        scene:AddFragment(GAMEPAD_NAV_QUADRANT_4_BACKGROUND_FRAGMENT)
        scene:AddFragment(ZO_SimpleSceneFragment:New(control))
        scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
        scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
        scene:AddFragment(STOP_MOVEMENT_FRAGMENT)
        self.headerData = { data1HeaderText = GetString(SI_COLLECTIONS_FAVORITES_CATEGORY_HEADER) }
    end

    function MountList:SetupList(list)
        list:AddDataTemplate(MOUNT_ROW, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader(MOUNT_ROW, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
    end

    function MountList:GetSelectedMount()
        local data = self:GetMainList():GetTargetData()
        return data and data.collectibleId
    end

    function MountList:InitializeKeybindStripDescriptors()
        self.keybindStripDescriptor = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            -- Triangle, the button Collections uses for its actions
            {
                name = function()
                    if character.favourites[self:GetSelectedMount()] then
                        return GetString(SI_COLLECTIBLE_ACTION_REMOVE_FAVORITE)
                    end
                    return GetString(SI_COLLECTIBLE_ACTION_ADD_FAVORITE)
                end,
                keybind = "UI_SHORTCUT_TERTIARY",
                visible = function() return self:GetSelectedMount() ~= nil end,
                enabled = function()
                    if CanEditList() then
                        return true
                    end
                    return false, string.format("Off for %s. Turn it on in the menu first.", character.name)
                end,
                callback = function()
                    local list = self:GetMainList()
                    local entry = list:GetTargetData()
                    SetFavourite(entry.collectibleId, not character.favourites[entry.collectibleId])
                    self.focus = { collectibleId = entry.collectibleId, inFavourites = entry.inFavourites, index = list:GetSelectedIndex() }
                    self:Update()
                end,
            },
        }
        ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
    end

    function MountList:PerformUpdate()
        self.dirty = false
        local list = self:GetMainList()
        list:Clear()
        local groups = GetMountGroups()
        local favourites = {}
        for _, group in ipairs(groups) do
            for _, collectibleId in ipairs(group.mounts) do
                if character.favourites[collectibleId] then
                    table.insert(favourites, collectibleId)
                end
            end
        end
        table.insert(groups, 1, { name = GetString(SI_COLLECTIONS_FAVORITES_CATEGORY_HEADER), mounts = favourites, isFavourites = true })
        local focus, focusRow, row = self.focus, nil, 0
        for _, group in ipairs(groups) do
            local inFavourites = group.isFavourites == true
            for index, collectibleId in ipairs(group.mounts) do
                local entry = ZO_GamepadEntryData:New(MountName(collectibleId), GetCollectibleIcon(collectibleId))
                entry:SetIconTintOnSelection(true)
                entry.collectibleId = collectibleId
                entry.inFavourites = inFavourites
                entry.isFavorite = character.favourites[collectibleId] == true -- Collections' star
                if index == 1 then
                    entry:SetHeader(group.name)
                    list:AddEntryWithHeader(MOUNT_ROW, entry)
                else
                    list:AddEntry(MOUNT_ROW, entry)
                end
                row = row + 1
                if focus and focus.collectibleId == collectibleId and focus.inFavourites == inFavourites then
                    focusRow = row
                end
            end
        end
        list:Commit()
        -- After Triangle the cursor stays on the same row, or on the one that
        -- took its place when a favourite left the top section.
        if focus then
            list:SetSelectedIndexWithoutAnimation(focusRow or math.min(focus.index, row))
            self.focus = nil
        end
        self.headerData.titleText = character.name
        self.headerData.data1Text = tostring(#favourites)
        ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
        self:RefreshKeybinds()
    end

    return MountList:New(PerCharacterMountsGamepad)
end

local function OpenMountList()
    if not IsInGamepadPreferredMode() then
        -- Keyboard: Collections, where mounts are starred and previewed.
        local collectibleId = GetListedMounts()[1] or GetOwnedMounts()[1]
        if collectibleId then
            COLLECTIONS_BOOK_SINGLETON:BrowseToCollectible(collectibleId)
        end
        return
    end
    mountList = mountList or CreateMountList()
    mountList.dirty = true
    SCENE_MANAGER:Push(MOUNT_LIST_SCENE)
end

-- Console and gamepad: each row's tooltip is shown in the panel on the right.
local function CreateHarvensSettings()
    local LHAS = LibHarvensAddonSettings
    settingsPanel = LHAS:AddAddon("Per-Character Mounts", { allowRefresh = true })
    settingsPanel:AddSettings({
        {
            type = LHAS.ST_BUTTON,
            label = "Mounts",
            buttonText = "Choose",
            tooltip = GetListText,
            clickHandler = OpenMountList,
        },
        {
            type = LHAS.ST_BUTTON,
            label = function() return clearArmed and "Press again to clear all" or "Clear all favourites" end,
            buttonText = function() return clearArmed and "Confirm" or "Clear all" end,
            tooltip = function()
                if clearArmed then
                    return string.format("Press again to remove every favourite mount from %s.", character.name)
                end
                return string.format("Removes every favourite mount from %s.", character.name)
            end,
            disable = CannotClear,
            clickHandler = PressClearAll,
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Own favourite mounts for this character",
            tooltip = "On: this character keeps its own favourite mounts. Off: it uses your normal favourites.",
            getFunction = IsEnabled,
            setFunction = function(value) SetEnabled(value) end,
            disable = function() return not normalIsSaved end,
            default = true,
        },
    })
end

-- PC keyboard: the list sits on the right of the picker.
local function CreateLamSettings()
    local LAM = LibAddonMenu2
    settingsUsesLam = true
    settingsPanel = LAM:RegisterAddonPanel(ADDON_NAME, {
        type = "panel",
        name = "Per-Character Mounts",
        version = ADDON_VERSION,
        registerForRefresh = true,
    })
    LAM:RegisterOptionControls(ADDON_NAME, {
        {
            type = "dropdown",
            name = "Mount",
            choices = lamChoices,
            getFunc = function() return pickerNames[selectedMount] or PICK_A_MOUNT end,
            setFunc = function(name) selectedMount = pickerMounts[name] end,
            scrollable = 15,
            width = "half",
            reference = "PerCharacterMountsPicker",
        },
        {
            type = "description",
            title = GetListTitle,
            text = GetListLines,
            disabled = function() return not IsEnabled() end,
            width = "half",
        },
        {
            type = "button",
            name = "Add",
            tooltip = function() return GetActionTooltip("Adds %s to %s's favourite mounts.") end,
            disabled = CannotAdd,
            func = function() SetFavourite(selectedMount, true) end,
            width = "half",
        },
        {
            type = "button",
            name = "Remove",
            tooltip = function() return GetActionTooltip("Takes %s off %s's favourite mounts.") end,
            disabled = CannotRemove,
            func = function() SetFavourite(selectedMount, false) end,
            width = "half",
        },
        {
            type = "button",
            name = "Preview",
            tooltip = "Opens the mount in Collections, where it's previewed.",
            disabled = function() return not CanPreview(selectedMount) end,
            func = function() PreviewMount(selectedMount) end,
            width = "half",
        },
        {
            type = "button",
            name = "Clear all",
            warning = function() return string.format("Removes every favourite mount from %s.", character.name) end,
            isDangerous = true,
            disabled = CannotClear,
            func = ClearFavourites,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Own favourite mounts for this character",
            tooltip = "On: this character keeps its own favourite mounts. Off: it uses your normal favourites.",
            getFunc = IsEnabled,
            setFunc = function(value) SetEnabled(value) end,
            default = true,
        },
    })
    -- Mounts you get mid-session show up the next time the menu opens.
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == settingsPanel and PerCharacterMountsPicker then
            PerCharacterMountsPicker:UpdateChoices(BuildPicker())
        end
    end)
end

-- Fills the keyboard picker before the menu is first opened.
local function FillLamPicker()
    if settingsUsesLam then
        for index, name in ipairs(BuildPicker()) do
            lamChoices[index] = name
        end
    end
end

local function CreateSettingsPanel()
    local isConsole = IsConsoleUI and IsConsoleUI()
    if LibHarvensAddonSettings and (isConsole or not LibAddonMenu2) then
        CreateHarvensSettings()
    elseif LibAddonMenu2 then
        CreateLamSettings()
    end
end

local function Start()
    local reason = "login"
    if character.isNew then
        reason = "first"
    elseif turnedBackOn then
        reason = "on"
    end
    character.isNew = nil
    Apply(reason)
end

-- Without a UI reload, carry on anyway: the normal favourites are kept in
-- memory and saved when you log out.
local function StartWithoutReload()
    if normalIsSaved then
        return
    end
    normalIsSaved = true
    for collectibleId in pairs(normal.favourites) do
        savedOnDisk[collectibleId] = true
    end
    Start()
end

local function ReloadToSaveNormal()
    if not pcall(ReloadUI, "ingame") then
        StartWithoutReload()
    end
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    FillLamPicker()
    local accountFavourites = GetAccountFavourites()
    if not normal then
        -- First run on this account: what's favourited now is your normal list.
        normal = { favourites = accountFavourites, timestamp = GetTimeStamp() }
        normals[GetDisplayName()] = normal
    end
    -- Logging in with no favourite mounts on the account makes the game switch
    -- "Random Favorite Mount" to "Random Mount" (see Finish).
    gameMaySwitchToAny = not HasAnyFavouriteMounts()
    if character.randomMountType == nil then
        character.randomMountType = GetRandomMountType(PLAYER)
    end
    if not normalIsSaved then
        -- ESO only writes saved data on logout or a UI reload. Reload once now so
        -- the normal favourites are safely stored before any clean slate.
        Print("saved your normal favourite mounts. Reloading the UI once to store them safely.")
        state = "ready"
        zo_callLater(ReloadToSaveNormal, RELOAD_DELAY_MS)
        zo_callLater(StartWithoutReload, RELOAD_DELAY_MS + RELOAD_TIMEOUT_MS)
        return
    end
    Start()
end

local function OnCollectibleUserFlagsUpdated(_, collectibleId, _, newFlags)
    if state == "loading" or GetCollectibleCategoryType(collectibleId) ~= MOUNT then
        return
    end
    local isFavourite = ZO_FlagHelpers.MaskHasFlag(newFlags, FAVOURITE)
    local changed = (known[collectibleId] or false) ~= isFavourite
    known[collectibleId] = isFavourite or nil
    if not changed then
        return
    end
    -- While swapping, only take changes the player made: to a mount this addon
    -- isn't touching, or favouriting one it's removing. Anything else is this
    -- addon's own change coming back (or the server undoing it).
    local asked = requested[collectibleId]
    if state == "ready" or asked == nil or (isFavourite and asked == false) then
        local target = GetTargetList()
        target[collectibleId] = isFavourite or nil
        if isFavourite then
            dropped[collectibleId] = nil
            if target == character.favourites then
                WantRandomFavourite()
            end
        end
        if state == "ready" then
            RestoreRandomFavourite()
        end
    end
end

local function OnRandomMountSettingChanged(_, playerRandomMountType)
    -- A switch to "Random Mount" while the account has no favourites (or one
    -- arriving mid-swap after such a login) is the game's doing, not the
    -- player's; RestoreRandomFavourite undoes it.
    if playerRandomMountType == RANDOM_MOUNT_TYPE_ANY
        and (not HasAnyFavouriteMounts() or (state ~= "ready" and gameMaySwitchToAny)) then
        gameMaySwitchToAny = true
        return
    end
    character.randomMountType = playerRandomMountType
    character.switchToRandomFavourite = nil -- the player's choice wins over one still waiting
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Saved per server, then per character ID so renamed characters keep theirs.
    PerCharacterMounts_SV = PerCharacterMounts_SV or {}
    local world = GetWorldName()
    PerCharacterMounts_SV[world] = PerCharacterMounts_SV[world] or {}
    savedCharacters = PerCharacterMounts_SV[world]
    local characterId = GetCurrentCharacterId()
    character = savedCharacters[characterId] or {}
    savedCharacters[characterId] = character
    character.name = GetUnitName("player")
    character.account = GetDisplayName()
    if character.enabled == nil then
        -- New character, or one saved by 1.2.0 or earlier: on, from a clean slate.
        character.enabled = true
        character.favourites = {}
        character.isNew = true
    elseif not character.enabled and (character.revision or 1) < 2 then
        -- 1.3.0 and 1.3.1 dropped a switch back on made during a swap, which
        -- could leave a character off by mistake. Turn it on, keeping its list.
        character.enabled = true
        turnedBackOn = true
    end
    if (character.revision or 1) < 3 and character.enabled and next(character.favourites or {}) ~= nil then
        -- Before 1.4.3, adding mounts didn't switch on Random Favorite Mount.
        WantRandomFavourite()
    end
    character.revision = DATA_REVISION

    -- Normal favourites, one list per account on each server. They start as
    -- the favourites you had when the addon first ran (its backup in 1.2.0).
    PerCharacterMounts_Backup = PerCharacterMounts_Backup or {}
    normals = PerCharacterMounts_Backup[world] or {}
    if normals.favourites then
        normals = { [GetDisplayName()] = normals } -- 1.1.0 kept a single one per server
    end
    PerCharacterMounts_Backup[world] = normals
    normal = normals[GetDisplayName()]
    normalIsSaved = normal ~= nil
    if normal then
        for collectibleId in pairs(normal.favourites) do
            savedOnDisk[collectibleId] = true
        end
    end
    local counts = GetCharacterCounter()
    for characterId, entry in pairs(savedCharacters) do
        if counts(characterId, entry) and entry.favourites and not entry.isNew then
            for collectibleId in pairs(entry.favourites) do
                savedOnDisk[collectibleId] = true
            end
        end
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COLLECTIBLE_USER_FLAGS_UPDATED, OnCollectibleUserFlagsUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_RANDOM_MOUNT_SETTING_CHANGED, OnRandomMountSettingChanged)
    SLASH_COMMANDS["/pcm"] = OnSlashCommand
    CreateSettingsPanel()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

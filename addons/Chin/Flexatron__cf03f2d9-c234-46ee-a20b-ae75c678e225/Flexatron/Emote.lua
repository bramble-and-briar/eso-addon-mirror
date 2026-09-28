-- The emote: which ones the player owns, and playing the chosen one when a title lands, or on its
-- own timer while titles aren't changing.
local FT = Flexatron
local Emote = {}
FT.Emote = Emote

local NEW_TITLE_WAIT_MS = 5 * 60000 -- a new title's emote waits this long for a menu to close
local TICK_MS = 1000                -- how often the emote's own timer checks

local lastPlayed
local timerFrom   -- when the emote's own timer started: the character's first time in the world
local newTitleDue -- a new title's emote is waiting for the player to leave a menu, until this time

-- Any menu is open (settings, inventory, map, a merchant, a conversation...): the game shows a
-- scene other than its base one, the plain game view.
local function InMenu()
    return not SCENE_MANAGER:IsShowingBaseScene()
end

local function Unlocked(index)
    local collectibleId = GetEmoteCollectibleId(index)
    return not collectibleId or IsCollectibleUnlocked(collectibleId)
end

-- Owned emotes from the gamepad emote menu, the way the game builds that menu:
-- { { index, id, name, category }, ... } sorted by name.
function Emote.Owned()
    local list = {}
    for index = 1, GetNumEmotes() do
        local slashName, category, emoteId, displayName, showInGamepadUI = GetEmoteInfo(index)
        if slashName and slashName ~= "" and showInGamepadUI and Unlocked(index) then
            list[#list + 1] = { index = index, id = emoteId, name = zo_strformat("<<1>>", displayName), category = category }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- The emotes offered in settings: the owned Cheers and Jeers, any owned flex, and the one picked.
function Emote.Choices()
    local list = {}
    for _, emote in ipairs(Emote.Owned()) do
        if emote.category == EMOTE_CATEGORY_CHEERS_AND_JEERS or emote.id == FT.sv.emoteId
                or string.find(string.lower(emote.name), "flex", 1, true) then
            list[#list + 1] = emote
        end
    end
    return list
end

-- Plays the chosen emote if there is one, the player still owns it, no menu is open, the player
-- isn't fighting, moving or mounted, and it's due. A new title always gets it (after the menu
-- closes, if one is open); other title changes and the emote's own timer follow the "how often"
-- setting (seconds since the last emote; 0 = every change, -1 = only new titles). Otherwise nothing.
function Emote.Play(newTitle)
    local id = FT.sv.emoteId
    if not id or id == 0 then
        return false
    end
    if InMenu() then
        if newTitle then
            newTitleDue = GetGameTimeMilliseconds() + NEW_TITLE_WAIT_MS
        end
        return false
    end
    local now, every = GetGameTimeMilliseconds(), FT.sv.emoteEvery
    if not newTitle and (every < 0 or (lastPlayed and now - lastPlayed < every * 1000)) then
        return false
    end
    if IsUnitInCombat("player") or IsPlayerMoving() or IsMounted() then
        return false
    end
    local index = GetEmoteIndex(id)
    if not index or not Unlocked(index) then
        return false
    end
    PlayEmoteByIndex(index)
    lastPlayed = now
    return true
end

-- The emote on its own while titles aren't changing (rotation off or paused, one title, a best
-- title held, a new title on show): every "how often" seconds, as soon as nothing stops it. While
-- the rotation changes titles, the emote comes with a title change instead.
local function OnTick()
    local id, every = FT.sv.emoteId, FT.sv.emoteEvery
    if not timerFrom or not id or id == 0 or type(every) ~= "number" or every <= 0 then
        return
    end
    if GetGameTimeMilliseconds() - (lastPlayed or timerFrom) < every * 1000 then
        return
    end
    if not FT.Rotation.IsChangingTitles() then
        Emote.Play(false)
    end
end

local function OnPlayerActivated()
    timerFrom = timerFrom or GetGameTimeMilliseconds()
end

-- Back in the game view: a new title's emote that waited for the menu plays now.
local function OnSceneStateChanged(_, _, newState)
    if newTitleDue and newState == SCENE_SHOWN and not InMenu() then
        local due = newTitleDue
        newTitleDue = nil
        if GetGameTimeMilliseconds() <= due then
            Emote.Play(true)
        end
    end
end

function Emote.Init()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    EVENT_MANAGER:RegisterForEvent(FT.name .. "Emote", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForUpdate(FT.name .. "Emote", TICK_MS, OnTick)
end

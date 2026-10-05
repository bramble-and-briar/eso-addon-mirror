-- The emote: which ones the player owns, and playing the chosen one when a title lands, or on its
-- own timer while titles aren't changing. Only while the character stands idle, and never over an
-- emote, pose or memento the player started.
local FT = Flexatron
local Emote = {}
FT.Emote = Emote

local NEW_TITLE_WAIT_MS = 5 * 60000 -- a new title's emote waits this long for the character to be idle
local TICK_MS = 1000                -- how often the idle check and the emote's own timer run
local IDLE_MS = 5000                -- standing idle this long before an emote
local ARRIVAL_MS = 10000            -- after a loading screen or a teleport, before an emote
local TRAVEL_MAX_MS = 60000         -- a jump that never lands or fails stops counting after this
local PLAYER_EMOTE_MS = 15000       -- after the player's own emote or memento, before Flexatron's
local OWN_REFUSAL_MS = 2000         -- the game refusing an emote this soon after Flexatron's is Flexatron's
local REFUSED_WAIT_MS = 30000       -- after the game refused Flexatron's emote, before trying again

-- The game's own, for Flexatron's emotes; the player's go through the hook in Emote.Init.
local playEmote = PlayEmoteByIndex

local lastPlayed   -- when Flexatron last asked the game for its emote
local lastRefused  -- the game refused that one
local timerFrom    -- when the emote's own timer started: the character's first time in the world
local newTitleDue  -- a new title's emote is waiting for the character to be idle, until this time
local idleSince    -- when the character last became idle; nil while it isn't
local arrivedAt    -- the last loading screen's end, or the last teleport
local travelUntil  -- a jump is on its way: until it lands, fails or this time passes
local waitUntil    -- the player's own emote or memento, or a refused emote: wait until this time
local waitWhy      -- which of those it is: "PLAYER" or "REFUSED"
local posing       -- the player started a looping emote (sitting, dancing...): wait until they move
local ownAttemptAt -- when Flexatron last asked the game for an emote; nil once the player emotes
local checked      -- the last check in the game view, for the settings: { why, detail }, where why
                   -- is nil when ready, else a key of L.EMOTE_WAIT

local function Unlocked(index)
    local collectibleId = GetEmoteCollectibleId(index)
    return not collectibleId or IsCollectibleUnlocked(collectibleId)
end

-- Emotes that keep going until the character moves (sitting, leaning...). The auto emote is never
-- one of them, so the character goes back to idle on its own when it ends.
local function Loops(category)
    return category == EMOTE_CATEGORY_PERPETUAL or category == EMOTE_CATEGORY_POSES_AND_FIDGETS
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

local function IsFlex(emote)
    return string.find(string.lower(emote.name), "flex", 1, true) ~= nil
end

-- The emotes offered in settings: the owned Cheers and Jeers, any owned flex, and the one picked,
-- except emotes that loop.
function Emote.Choices()
    local list = {}
    for _, emote in ipairs(Emote.Owned()) do
        if not Loops(emote.category) and (emote.category == EMOTE_CATEGORY_CHEERS_AND_JEERS
                or emote.id == FT.sv.emoteId or IsFlex(emote)) then
            list[#list + 1] = emote
        end
    end
    return list
end

-- The emote used until the player picks one: the first flex they own, else the first choice.
function Emote.DefaultId()
    local choices = Emote.Choices()
    for _, emote in ipairs(choices) do
        if IsFlex(emote) then
            return emote.id
        end
    end
    return choices[1] and choices[1].id
end

-- The emote that plays, and that settings show: the one picked, or the default until one is (and
-- if the one picked is no longer owned, or loops).
function Emote.ChosenId()
    local id = FT.sv.emoteId
    local index = id and id ~= 0 and GetEmoteIndex(id)
    if not index or not Unlocked(index) or Loops(select(2, GetEmoteInfo(index))) then
        return Emote.DefaultId()
    end
    return id
end

-- The game view: the HUD, or the interface-mode HUD ("hudui"), which the game keeps after a
-- loading screen that ends without the game camera (a console emote add-on takes both). Menus, the
-- map, conversations and screenshot mode are other scenes.
local function InGameView()
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

-- What keeps the character from standing idle in the game view, as a key of L.EMOTE_WAIT, or nil.
-- Every check here is one the game's own interface or a console add-on relies on. 0.8.4 also asked
-- IsPlayerTryingToMove, IsUnitInAir and IsUnitFalling, which none does, and on console its emote
-- never played.
local function Blocker(now)
    if (travelUntil ~= nil and now < travelUntil) or not IsPlayerActivated() then
        return "TRAVEL"
    elseif not InGameView() then
        return "SCENE"
    elseif IsUnitInCombat("player") then
        return "COMBAT"
    elseif IsUnitDeadOrReincarnating("player") or IsUnitBeingResurrected("player") then
        return "DEAD"
    elseif IsPlayerMoving() then
        return "MOVING"
    elseif IsMounted() then
        return "MOUNTED"
    elseif IsUnitSwimming("player") then
        return "SWIMMING"
    elseif GetUnitStealthState("player") ~= STEALTH_STATE_NONE then
        return "CROUCHED"
    elseif IsBlockActive() or IsPlayerStunned() or IsPlayerGroundTargeting() then
        return "ACTION"
    elseif IsPlayerControllingSiegeWeapon() or IsPlayerEscortingRam() then
        return "SIEGE"
    elseif IsPlayerInWerewolfForm() then
        return "WEREWOLF"
    elseif not ArePlayerWeaponsSheathed() then
        return "WEAPONS"
    elseif IsInteracting() or IsInteractionPending() or IsPlayerInteractingWithObject()
            or GetInteractionType() ~= INTERACTION_NONE or IsLooting() then
        return "USING"
    elseif GetHousingEditorMode() ~= HOUSING_EDITOR_MODE_DISABLED then
        return "HOUSING"
    elseif IsCutsceneActive() then
        return "CUTSCENE"
    end
    return nil
end

-- A looping emote lasts until the player moves, mounts or fights.
local function PoseEnded()
    return IsPlayerMoving() or IsMounted() or IsUnitInCombat("player")
end

-- Whether the character has stood idle long enough for an emote: IDLE_MS without a break, and
-- ARRIVAL_MS since the last loading screen or teleport, with no emote, pose or memento of the
-- player's still going. If not, also why (a key of L.EMOTE_WAIT) and, for "ERROR", the error.
-- Keeps track of when idling began.
local function Ready(now)
    if posing and PoseEnded() then
        posing = false
    end
    -- A check the game can't run (one a console's game lacks, say) holds the emote, and settings
    -- show the error, instead of the whole tick failing unseen.
    local fine, blocker = pcall(Blocker, now)
    if not fine then
        idleSince = nil
        return false, "ERROR", tostring(blocker)
    elseif blocker then
        idleSince = nil
        return false, blocker
    end
    idleSince = idleSince or now
    if posing then
        return false, "POSE"
    elseif waitUntil ~= nil and now < waitUntil then
        return false, waitWhy
    elseif now - idleSince < IDLE_MS then
        return false, "SETTLING"
    elseif arrivedAt ~= nil and now - arrivedAt < ARRIVAL_MS then
        return false, "ARRIVING"
    end
    return true
end

-- Plays the emote if Flexatron and the auto emote are on, the player owns it, the character has
-- stood idle long enough and it's due. A new title always gets it (once the character is idle, if
-- it isn't); other title changes and the emote's own timer follow the "how often" setting (seconds
-- since the last emote; 0 = every change, -1 = only new titles). Otherwise nothing.
function Emote.Play(newTitle)
    local sv = FT.sv
    if not sv.active or not sv.emoteOn then
        return false
    end
    local now, every = GetGameTimeMilliseconds(), sv.emoteEvery
    if not newTitle and (type(every) ~= "number" or every < 0 or (lastPlayed and now - lastPlayed < every * 1000)) then
        return false
    end
    if not Ready(now) then
        if newTitle then
            newTitleDue = now + NEW_TITLE_WAIT_MS
        end
        return false
    end
    newTitleDue = nil
    local id = Emote.ChosenId()
    local index = id and GetEmoteIndex(id)
    if not index or not Unlocked(index) then
        return false
    end
    ownAttemptAt, lastPlayed, lastRefused = now, now, false
    playEmote(index)
    return true
end

-- Every second: a new title's emote that waited plays once the character is idle; otherwise the
-- emote on its own while titles aren't changing (rotation off or paused, one title, a best title
-- held), every "how often" seconds. While the rotation changes titles, the emote comes with a title
-- change instead.
local function OnTick()
    local sv = FT.sv
    if not sv.active or not sv.emoteOn then
        idleSince = nil
        return
    end
    local now = GetGameTimeMilliseconds()
    local ready, why, err = Ready(now)
    -- Kept for the settings. A menu (any scene but the game view or one standing in for it, like
    -- screenshot mode) has nothing new to tell: the check before it stands.
    if why ~= "SCENE" or SCENE_MANAGER:IsShowingBaseScene() then
        checked = checked or {}
        checked.why = why
        checked.detail = why == "SCENE" and (SCENE_MANAGER:GetCurrentSceneName() or "?") or err
    end
    if not ready then
        return
    end
    if newTitleDue then
        if now <= newTitleDue then
            Emote.Play(true)
            return
        end
        newTitleDue = nil
    end
    local every = sv.emoteEvery
    if not timerFrom or type(every) ~= "number" or every <= 0 then
        return
    end
    if now - (lastPlayed or timerFrom) < every * 1000 then
        return
    end
    if not FT.Rotation.IsChangingTitles() then
        Emote.Play(false)
    end
end

local function OnPlayerActivated()
    local now = GetGameTimeMilliseconds()
    timerFrom = timerFrom or now
    arrivedAt, travelUntil, posing, idleSince = now, nil, false, nil
end

-- A jump to another place is about to happen, or a loading screen has started.
local function OnTravelling()
    travelUntil = GetGameTimeMilliseconds() + TRAVEL_MAX_MS
    idleSince = nil
end

local function OnJumpFailed()
    travelUntil = nil
end

local function OnTeleportedLocally()
    arrivedAt, posing, idleSince = GetGameTimeMilliseconds(), false, nil
end

-- A memento (or any collectible) the player used: let it play out.
local function OnCollectibleUsed(_, result)
    if result == COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED then
        waitUntil = math.max(waitUntil or 0, GetGameTimeMilliseconds() + PLAYER_EMOTE_MS)
        waitWhy = "PLAYER"
        idleSince = nil
    end
end

-- The player's own emote: the emote wheel, the emote menu and slash commands all call
-- PlayEmoteByIndex. A looping one holds Flexatron's until they move; any other, PLAYER_EMOTE_MS.
local function OnPlayerEmote(index)
    posing = type(index) == "number" and Loops(select(2, GetEmoteInfo(index)))
    waitUntil = math.max(waitUntil or 0, GetGameTimeMilliseconds() + PLAYER_EMOTE_MS)
    waitWhy = "PLAYER"
    ownAttemptAt = nil -- a refusal from now on is the player's
    idleSince = nil
end

local function OwnRefusal()
    return ownAttemptAt ~= nil and GetGameTimeMilliseconds() - ownAttemptAt <= OWN_REFUSAL_MS
end

-- The game refused an emote. If it was Flexatron's, the character was busy in a way the checks
-- above can't see: wait a while. If it was the player's, there's no pose to protect.
local function OnEmoteRefused()
    if OwnRefusal() then
        waitUntil = GetGameTimeMilliseconds() + REFUSED_WAIT_MS
        waitWhy = "REFUSED"
        lastRefused = true
        idleSince = nil
    else
        posing = false
    end
end

-- The game's message for a refused emote ("Cannot play emote at this time.") isn't shown for
-- Flexatron's: the player didn't ask for that one. Their own refused emotes still show it.
local function HideOwnRefusals()
    local handlers = type(ZO_AlertText_GetHandlers) == "function" and ZO_AlertText_GetHandlers()
    local show = type(handlers) == "table" and handlers[EVENT_PLAYER_EMOTE_FAILED_PLAY]
    if type(show) ~= "function" then
        return
    end
    handlers[EVENT_PLAYER_EMOTE_FAILED_PLAY] = function(...)
        if OwnRefusal() then
            return
        end
        return show(...)
    end
end

local function Ago(ms)
    local seconds = math.floor(ms / 1000)
    if seconds < 120 then
        return string.format(FT.L.EMOTE_SECONDS, seconds)
    end
    return string.format(FT.L.EMOTE_MINUTES, math.floor(seconds / 60))
end

-- For the auto emote's info panel in settings: the last check in the game view and Flexatron's
-- last emote, so a player can see what keeps it waiting. Nil while Flexatron or the emote is off.
function Emote.Status()
    local sv, L = FT.sv, FT.L
    if not sv.active or not sv.emoteOn then
        return nil
    end
    local lines = {}
    if checked and checked.why then
        local reason = L.EMOTE_WAIT[checked.why] or checked.why
        if checked.detail then
            reason = string.format(reason, checked.detail)
        end
        lines[1] = string.format(L.EMOTE_STATUS_WAITING, reason)
    elseif checked then
        lines[1] = L.EMOTE_STATUS_READY
    end
    if lastPlayed then
        local ago = Ago(GetGameTimeMilliseconds() - lastPlayed)
        lines[#lines + 1] = string.format(lastRefused and L.EMOTE_LAST_REFUSED or L.EMOTE_LAST, ago)
    else
        lines[#lines + 1] = L.EMOTE_LAST_NONE
    end
    return table.concat(lines, "\n")
end

function Emote.Init()
    local name = FT.name .. "Emote"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PREPARE_FOR_JUMP, OnTravelling)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEACTIVATED, OnTravelling)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_JUMP_FAILED, OnJumpFailed)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_TELEPORTED_LOCALLY, OnTeleportedLocally)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COLLECTIBLE_USE_RESULT, OnCollectibleUsed)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_EMOTE_FAILED_PLAY, OnEmoteRefused)
    EVENT_MANAGER:RegisterForUpdate(name, TICK_MS, OnTick)
    ZO_PreHook("PlayEmoteByIndex", function(index) OnPlayerEmote(index) end)
    HideOwnRefusals()
end

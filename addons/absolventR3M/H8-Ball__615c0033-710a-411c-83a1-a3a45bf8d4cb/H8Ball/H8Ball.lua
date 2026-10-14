local ADDON_NAME = "H8Ball"
local TEXT_COLOR = "E6E0FF" -- very pale lavender, close to white
local DIAG_COLOR = "9A9A9A" -- grey status lines

local CATEGORIES = {
    {
        -- yes
        responses = {
            "Unfortunately for everyone, yes.",
            "Regrettably, probably.",
            "Yes, but you're still not going to like it.",
            "Worst-case scenario: Yes.",
            "Against my better judgment... signs point to yes.",
            "Sure, right after pigs fly.",
            "It is decidedly so, to my great dismay.",
            "Without a doubt, sadly.",
            "Yes, fine, stop shaking me.",
            "The universe says yes, but it's not happy about it.",
        },
    },
    {
        -- maybe
        responses = {
            "I'm a floating plastic triangle in blue liquid and even I know that's stupid.",
            "Ask someone who actually cares.",
            "Why don't you go figure it out yourself?",
            "Reply hazy, because I'm ignoring you.",
            "Concentrate... on leaving me alone.",
            "Ask again later. Much later. Like, never.",
            "Better not tell you now. Or ever.",
            "Cannot predict now. Don't want to, either.",
            "Ask again after I've had a nap.",
            "Wow. You really came to a toy for this?",
        },
    },
    {
        -- no
        responses = {
            "In your dreams, loser.",
            "Not if you were the last person on Earth.",
            "Absolutely not. Next dumb question?",
            "The universe actively hates this idea.",
            "LOL. No.",
            "Don't count on it. Don't count on anything.",
            "My reply is no. My sources also say no. Everyone says no.",
            "Outlook not so good, and I'm thrilled about it.",
            "Very doubtful, and frankly embarrassing.",
            "No. Shake me again and it's still no.",
        },
    },
}

-- Each answer gets exactly one roll number. Numbers cycle yes, maybe, no
-- (1 = yes #1, 2 = maybe #1, 3 = no #1, 4 = yes #2, ...), skipping any
-- list that has run out.
local ROLLS = {}
local longest = 0
for _, category in ipairs(CATEGORIES) do
    longest = math.max(longest, #category.responses)
end
for turn = 1, longest do
    for _, category in ipairs(CATEGORIES) do
        local text = category.responses[turn]
        if text then
            table.insert(ROLLS, text)
        end
    end
end

-- Prefer the game's own random helper; fall back to standard Lua if it's ever missing.
local Random = zo_random or math.random

local function RollAnswer()
    return ROLLS[Random(1, #ROLLS)]
end

-- Prints a line to the player's own chat window (only they see it).
local function ShowPrivately(text)
    CHAT_ROUTER:AddSystemMessage(string.format("|c%s[H8 Ball] %s|r", TEXT_COLOR, text))
end

-- Grey status line so a failed paste explains itself instead of failing silently.
local function Diag(text)
    CHAT_ROUTER:AddSystemMessage(string.format("|c%s[H8 Ball] %s|r", DIAG_COLOR, text))
end

-- Add-ons can't send chat, and the small HUD chat bar can't be opened from
-- add-on code on console (it calls the private SetSetting). What works is the
-- full-screen Chat page (scene "gamepadChatMenu"): we put the answer into its
-- text box and the player presses its own Send button, which posts to the
-- channel they last used.
local CHAT_MENU_SCENE = "gamepadChatMenu"
local pendingText = nil

local function FillChatPageBox(text)
    local edit = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.textEdit
    if not edit then return false, "Chat page text box not found" end
    -- SetText alone: the page's own text-changed handler refreshes the Send
    -- button, and the game re-checks it on every press anyway.
    local ok, err = pcall(edit.SetText, edit, text)
    if not ok then return false, tostring(err) end
    return true
end

local function ReportFill(ok, err)
    if ok then
        Diag("Pasted. Press Send. If the game refuses, press A, confirm the keyboard, then Send.")
    else
        Diag("Could not paste: " .. tostring(err))
    end
end

-- Runs when the Chat page finishes opening after we asked for it.
local function OnChatPageStateChange(oldState, newState)
    if newState == SCENE_SHOWN and pendingText then
        local text = pendingText
        pendingText = nil
        ReportFill(FillChatPageBox(text))
    end
end

local function PasteIntoChat(text)
    local line = "[H8 Ball] " .. text
    if not (SCENE_MANAGER and SCENE_MANAGER.IsShowing and zo_callLater) then
        Diag("Could not paste: chat page API missing")
        return
    end

    if SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE) then
        -- Typed /h8ball on the Chat page: we are running inside its Send button,
        -- which empties the box right after us. Fill it one frame later.
        zo_callLater(function() ReportFill(FillChatPageBox(line)) end, 1)
        return
    end

    -- From the wheel or the HUD chat bar: fill the box now (nothing clears it
    -- while the page opens), open the Chat page the way ZOS opens top-level
    -- pages from gameplay (Show), and confirm once it is shown.
    pendingText = line
    FillChatPageBox(line)
    local ok, err = pcall(SCENE_MANAGER.Show, SCENE_MANAGER, CHAT_MENU_SCENE)
    if not ok then
        pendingText = nil
        Diag("Could not open the Chat page: " .. tostring(err))
        return
    end
    zo_callLater(function()
        if pendingText == line then
            pendingText = nil
            Diag("Chat page did not open within 3 seconds.")
        end
    end, 3000)
end

local function Shake()
    local text = RollAnswer()
    ShowPrivately(text)
    PasteIntoChat(text)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    SLASH_COMMANDS["/h8ball"] = Shake

    local chatPage = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(CHAT_MENU_SCENE)
    if chatPage then
        chatPage:RegisterCallback("StateChange", OnChatPageStateChange)
    end

    LibRadialMenu:RegisterAddon(ADDON_NAME, "H8 Ball")
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Shake the H8 Ball", "shake",
        "EsoUI/Art/MapPins/battlegrounds_murderball_neutral.dds", Shake,
        "You know you want to.")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

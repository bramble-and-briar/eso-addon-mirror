-- Questbound_Skip.lua : "Skip dialogs" (button in the tracker header, /qb skip, keybind).
-- Clicks through NPC conversations for you, but more carefully than the usual skippers:
--  * only quest talk: shops, banks, stables, guild traders and answers that cost gold
--    are never picked (white list of option types below);
--  * decisions (two or more new answers): sv.skip.choices picks the best one by score
--    (BestAnswer: quest steps, [Persuade] / [Intimidate], answers that move on, never
--    declining or paying), else they're left to you; sv.skip.red allows the answers the
--    game shows in red (IsRed reads the label color; isImportant is NOT red);
--  * answers you already gave (grey) are never picked again; nothing loops (MAX_PICKS);
--  * hold Shift when you start talking = read this one conversation normally;
--  * "only dialogs I've read before": new story is shown, repeats (dailies) are skipped;
--  * what the NPC says goes to chat, so the story isn't lost.
-- API as used by the game's own interactwindow_shared.lua: GetChatterOption(i) =
-- text, optionType, optionalArg, isImportant, chosenBefore; SelectChatterOption,
-- GetOfferedQuestInfo / AcceptOfferedQuest, GetJournalQuestEnding / CompleteQuest.

local W = Questbound
local L = W.L
local C = W.COLOR

local Skip = {}
W.Skip = Skip

local NAME = "Questbound_Skip"
local MAX_PICKS = 30     -- per conversation: a safety stop against option loops
local MAX_SEEN = 4000    -- remembered dialogs ("only ones I've read before"); forgotten all at once beyond

-- Option types by name: a constant missing in this game version is simply left out
-- (a nil key in a table constructor would break the whole file).
local function TypeSet(names)
    local set = {}
    for _, name in ipairs(names) do
        local value = _G[name]
        if value ~= nil then set[value] = name end
    end
    return set
end

-- quest steps: always the right answer when one is there
local QUEST_TYPES = TypeSet({
    "CHATTER_START_NEW_QUEST_BESTOWAL",
    "CHATTER_START_COMPLETE_QUEST",
    "CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS",
    "CHATTER_START_GIVE_ITEM",
})
-- answers never picked (gold, or greyed out), but their presence makes it a decision
local ALT_TYPES = TypeSet({
    "CHATTER_TALK_CHOICE_MONEY",
    "CHATTER_TALK_CHOICE_PAY_BOUNTY",
    "CHATTER_TALK_CHOICE_PERSUADE_DISABLED",
    "CHATTER_TALK_CHOICE_INTIMIDATE_DISABLED",
    "CHATTER_TALK_CHOICE_CLEMENCY_DISABLED",
    "CHATTER_TALK_CHOICE_CLEMENCY_COOLDOWN",
})
-- persuade / intimidate you can use (skill passives): usually the best way through
local SKILL_TYPES = TypeSet({
    "CHATTER_TALK_CHOICE_PERSUADE",
    "CHATTER_TALK_CHOICE_INTIMIDATE",
})

-- Words in an answer that tell how it ends (lowercase, en / de / fr; plain find).
-- Moving on scores up; turning down / leaving scores down; sparing beats killing
-- (spared people often come back later with help or rewards).
local WORDS_GO = { "i'll help", "i will help", "i'll do it", "i'll go", "let's go", "i'm ready", "i accept", "agreed",
    "very well", "of course", "yes", "ich helfe", "ich mache", "einverstanden", "ja", "bereit", "je vais", "d'accord",
    "oui", "je suis prêt", "j'accepte" }
local WORDS_NO = { "not interested", "no thanks", "no", "i can't", "i refuse", "decline", "think about it", "later",
    "maybe another time", "goodbye", "leave", "nein", "kein interesse", "später", "ablehnen", "non", "plus tard",
    "pas intéressé", "je refuse", "au revoir" }
local WORDS_MERCY = { "spare", "let you go", "let him go", "let her go", "forgive", "mercy", "free", "verschon",
    "vergeb", "gnade", "freilassen", "épargne", "pardonne", "grâce", "libère" }
local WORDS_HARSH = { "kill", "execute", "töte", "stirb", "hinricht", "meurs", "exécute" }

-- true when one of the words starts a word in text (text is prepared by Words());
-- short words (4 letters or less: "yes", "ja", "non") must be the whole word
local function HasAny(text, list)
    for _, w in ipairs(list) do
        local pattern = " " .. w .. (#w <= 4 and " " or "")
        if string.find(text, pattern, 1, true) then return true end
    end
    return false
end

-- lowercase, punctuation (not apostrophes) turned into spaces, a space at both ends
local function Words(text)
    text = zo_strlower(text or "")
    text = string.gsub(text, "[%.,!%?;:%(%)%[%]\"]", " ")
    return " " .. text .. " "
end

-- ---------------------------------------------------------------------------
-- Reward picks in a conversation ("I'll take the sword" / "the light armor"): ESO has no
-- reward choice at the hand-in itself (the game's interactwindow just calls CompleteQuest),
-- so the only picks are dialog answers. With sv.skip.bestReward the answer that fits what
-- you wear wins: your most-worn armor weight, your equipped weapon types.

local REWARD_WORDS = {
    light = { "light armor", "light", "robe", "cloth", "leichte", "stoff", "légère", "tissu" },
    medium = { "medium armor", "medium", "leather", "mittlere", "leder", "moyenne", "cuir" },
    heavy = { "heavy armor", "heavy", "plate", "schwere", "platte", "lourde", "plaque" },
    sword = { "sword", "greatsword", "schwert", "épée" },
    axe = { "axe", "battle axe", "axt", "hache" },
    mace = { "mace", "hammer", "maul", "streitkolben", "masse", "marteau" },
    dagger = { "dagger", "dolch", "dague" },
    bow = { "bow", "bogen", "arc" },
    fire = { "inferno", "flame", "fire", "feuer", "flammes", "feu" },
    frost = { "frost", "ice", "eis", "glace" },
    shock = { "lightning", "shock", "blitz", "foudre" },
    resto = { "restoration", "healing", "heilung", "wiederherstellung", "rétablissement", "soin" },
    staff = { "staff", "stab", "bâton" },
    shield = { "shield", "schild", "bouclier" },
}

local function WeaponKinds(weaponType, kinds)
    local map = {
        WEAPONTYPE_SWORD = "sword", WEAPONTYPE_TWO_HANDED_SWORD = "sword",
        WEAPONTYPE_AXE = "axe", WEAPONTYPE_TWO_HANDED_AXE = "axe",
        WEAPONTYPE_HAMMER = "mace", WEAPONTYPE_TWO_HANDED_HAMMER = "mace",
        WEAPONTYPE_DAGGER = "dagger", WEAPONTYPE_BOW = "bow", WEAPONTYPE_SHIELD = "shield",
        WEAPONTYPE_FIRE_STAFF = "fire", WEAPONTYPE_FROST_STAFF = "frost",
        WEAPONTYPE_LIGHTNING_STAFF = "shock", WEAPONTYPE_HEALING_STAFF = "resto",
    }
    for name, kind in pairs(map) do
        if _G[name] ~= nil and _G[name] == weaponType then
            kinds[kind] = true
            if kind == "fire" or kind == "frost" or kind == "shock" or kind == "resto" then kinds.staff = true end
        end
    end
end

-- What you wear now: { light / medium / heavy (the most-worn weight), weapon kinds = true }
local function WornKinds()
    local kinds, count = {}, {}
    for _, slot in ipairs({ "EQUIP_SLOT_HEAD", "EQUIP_SLOT_CHEST", "EQUIP_SLOT_SHOULDERS", "EQUIP_SLOT_WAIST",
            "EQUIP_SLOT_LEGS", "EQUIP_SLOT_FEET", "EQUIP_SLOT_HAND" }) do
        local index = _G[slot]
        if index then
            local armor = GetItemArmorType(BAG_WORN, index)
            if armor == ARMORTYPE_LIGHT then count.light = (count.light or 0) + 1
            elseif armor == ARMORTYPE_MEDIUM then count.medium = (count.medium or 0) + 1
            elseif armor == ARMORTYPE_HEAVY then count.heavy = (count.heavy or 0) + 1 end
        end
    end
    local most, n = nil, 0
    for kind, c in pairs(count) do
        if c > n then most, n = kind, c end
    end
    if most then kinds[most] = true end
    for _, slot in ipairs({ "EQUIP_SLOT_MAIN_HAND", "EQUIP_SLOT_OFF_HAND", "EQUIP_SLOT_BACKUP_MAIN", "EQUIP_SLOT_BACKUP_OFF" }) do
        local index = _G[slot]
        if index then WeaponKinds(GetItemWeaponType(BAG_WORN, index), kinds) end
    end
    return kinds
end

-- the reward kinds an answer names (nil when it names none)
local function RewardKinds(words)
    local found
    for kind, list in pairs(REWARD_WORDS) do
        if HasAny(words, list) then
            found = found or {}
            found[kind] = true
        end
    end
    return found
end

-- Only when two or more answers name a reward (a real reward pick, not "light the brazier"):
-- an answer that fits your gear +25, one that doesn't -10.
local function ScoreRewards(talk)
    if not W.sv.skip.bestReward then return end
    local named = 0
    for _, t in ipairs(talk) do
        t.rewards = RewardKinds(Words(t.text))
        if t.rewards then named = named + 1 end
    end
    if named < 2 then return end
    local worn = WornKinds()
    for _, t in ipairs(talk) do
        if t.score and t.rewards then
            local fits = false
            for kind in pairs(t.rewards) do
                if worn[kind] then fits = true end
            end
            t.score = t.score + (fits and 25 or -10)
        end
    end
end

-- Red answers = the ones the game really SHOWS in red. (The "isImportant" flag is NOT red:
-- the game sets it on ordinary quest answers too, "That doesn't make any sense." stopped
-- the skip in-game.) The game fills its answer labels before addons hear the event, so the
-- label of this answer (matched by index AND text, never a stale one) tells its color.
local function IsRed(index, text)
    local window = INTERACTION   -- keyboard dialog window (gamepad: no red check, treated as not red)
    local controls = window and window.optionControls
    if type(controls) ~= "table" then return false end
    for _, c in pairs(controls) do
        local label = c.optionText
        local same = label == nil or label == text or string.find(tostring(label), text or "", 1, true) ~= nil
        if c.optionIndex == index and same and not c:IsHidden() then
            local ok, r, g, b = pcall(c.GetColor, c)
            return ok and r ~= nil and r > 0.7 and g < 0.45 and b < 0.45
        end
    end
    return false
end

-- How good an answer looks; nil = never pick it.
local function Score(text, optionType, isImportant, isRed)
    local s = W.sv.skip
    if isRed and not s.red then return nil end
    local score = 0
    local raw = zo_strtrim(text or "")
    local words = Words(raw)
    if SKILL_TYPES[optionType] or string.sub(raw, 1, 1) == "[" then
        score = score + 40   -- [Persuade] / [Intimidate]: the skill check way, usually the best outcome
    end
    if isImportant then score = score + 20 end         -- the game marks it for the quest: it moves the story
    if string.sub(raw, -1) == "?" then score = score - 15 end   -- a question: side talk, doesn't move on
    if HasAny(words, WORDS_GO) then score = score + 10 end
    if HasAny(words, WORDS_NO) then score = score - 30 end
    if HasAny(words, WORDS_MERCY) then score = score + 5 end
    if HasAny(words, WORDS_HARSH) then score = score - 5 end
    return score
end
local BESTOW = _G.CHATTER_START_NEW_QUEST_BESTOWAL
local COMPLETE = _G.CHATTER_START_COMPLETE_QUEST
-- plain talk ("Continue", "What happened here?")
local TALK = _G.CHATTER_TALK_CHOICE
local START_TALK = _G.CHATTER_START_TALK
local GOODBYE = _G.CHATTER_GOODBYE

local convo = nil   -- the running conversation: { picks, paused, acted, noted, npc }

local function sv() return W.sv.skip end

-- ---------------------------------------------------------------------------
-- Helpers

local function NpcName()
    local name = GetUnitName("interact")
    if not name or name == "" then return nil end
    return zo_strformat(SI_UNIT_NAME, name)
end

-- ---------------------------------------------------------------------------
-- Which quests get skipped: sv.skip.types[section] == false = read those yourself (all on
-- by default). The kind comes from the journal (same checks as the tracker's tabs). A
-- conversation belongs to the quest whose open step names this NPC, else to the followed
-- quest when you stand at its "talk to" target; quests it can't place count as side quests.

Skip.SECTIONS = { "main", "zone", "side", "guild", "daily", "dungeon", "companion", "crafting", "pvp", "event" }

local function TypeIs(questType, ...)
    for i = 1, select("#", ...) do
        local value = _G[select(i, ...)]
        if value ~= nil and value == questType then return true end
    end
    return false
end

function Skip.Section(qi)
    local _, _, _, _, _, _, _, _, _, questType = GetJournalQuestInfo(qi)
    if TypeIs(questType, "QUEST_TYPE_COMPANION") then return "companion" end
    if TypeIs(questType, "QUEST_TYPE_HOLIDAY_EVENT") then return "event" end
    if TypeIs(questType, "QUEST_TYPE_CRAFTING") then return "crafting" end
    if TypeIs(questType, "QUEST_TYPE_AVA", "QUEST_TYPE_AVA_GROUP", "QUEST_TYPE_AVA_GRAND", "QUEST_TYPE_BATTLEGROUND")
        or W.Dungeon.IsPvPQuest(qi) then return "pvp" end
    if TypeIs(questType, "QUEST_TYPE_DUNGEON", "QUEST_TYPE_RAID", "QUEST_TYPE_UNDAUNTED_PLEDGE")
        or W.Dungeon.Info(qi) ~= nil then return "dungeon" end
    if GetJournalQuestRepeatType and GetJournalQuestRepeatType(qi) ~= QUEST_REPEAT_NOT_REPEATABLE then return "daily" end
    if TypeIs(questType, "QUEST_TYPE_MAIN_STORY", "QUEST_TYPE_PROLOGUE") then return "main" end
    if TypeIs(questType, "QUEST_TYPE_GUILD", "QUEST_TYPE_CLASS") then return "guild" end
    if type(GetJournalQuestZoneStoryZoneId) == "function" then   -- (unverified API, guarded)
        local ok, zoneId = pcall(GetJournalQuestZoneStoryZoneId, qi)
        if ok and type(zoneId) == "number" and zoneId ~= 0 then return "zone" end
    end
    return "side"
end

local function SectionOn(qi)
    local types = sv().types or {}
    return types[qi and Skip.Section(qi) or "side"] ~= false
end

-- does a person's name appear in a journal text?
local function NameIn(npc, text)
    if not npc or not text or text == "" then return false end
    local want = zo_strlower(zo_strformat("<<1>>", text))
    for w in zo_strlower(npc):gmatch("[^%s%-]+") do
        if #w >= 3 and want:find(w, 1, true) then return true end
    end
    return false
end

-- the journal quest this conversation is about, or nil
local function ConvoQuest(npc)
    local state = W.Nav.state
    local followed = state and state.questIndex
    local found
    for qi = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(qi) then
            local hit = false
            for step = 1, GetJournalQuestNumSteps(qi) do
                local stepText, _, _, overrideText = GetJournalQuestStepInfo(qi, step)
                if NameIn(npc, stepText) or NameIn(npc, overrideText) then hit = true end
                for cond = 1, GetJournalQuestNumConditions(qi, step) do
                    local text, _, _, isFail = GetJournalQuestConditionInfo(qi, step, cond)
                    if not isFail and NameIn(npc, text) then hit = true end
                end
            end
            if hit then
                if qi == followed then return qi end
                found = found or qi
            end
        end
    end
    if found then return found end
    if followed and state.target and state.target.talk and (state.dist or 999) <= 15 then return followed end
    return nil
end

-- ---------------------------------------------------------------------------
-- The story log (shown by Questbound_Story.lua): what was said in the conversations
-- Questbound skipped and the answers it gave, kept per quest. Also the time saved:
-- voiced NPC lines run ~150 words a minute, plus a moment per page to click on.

local WORDS_PER_SECOND = 2.5
local PAGE_SECONDS = 1

-- skipped = false for a page you read yourself (kept in the story, no time saved)
local function Record(who, text, skipped)
    if not convo or not text or text == "" then return end
    convo.lines = convo.lines or {}
    convo.lines[#convo.lines + 1] = { w = who, s = text }
    if who == "npc" and skipped ~= false then
        local _, words = string.gsub(text, "%S+", "")
        local s = sv()
        s.saved = (s.saved or 0) + words / WORDS_PER_SECOND + PAGE_SECONDS
    end
end

-- "2 h 14 min", "35 min", "less than a minute"
function Skip.SavedText()
    local secs = sv().saved or 0
    local mins = math.floor(secs / 60)
    if mins >= 60 then return L("TIME_H_M", math.floor(mins / 60), mins % 60) end
    if mins >= 1 then return L("TIME_M", mins) end
    return L("TIME_LESS")
end

-- the button's tooltip: on / off, and the time saved so far. The saved line stands out:
-- the speech-bubble icon, the line in the accent color, the time itself bright cream.
local BRIGHT = "FFF2CC"
function Skip.Tooltip()
    local on = Skip.IsOn()
    local text = L(on and "TT_SKIP_ON" or "TT_SKIP_OFF", W.State(on, on and "STATE_ON" or "STATE_OFF"))
    if (sv().saved or 0) >= 30 then
        local t = C.theme
        local accent = string.format("%02X%02X%02X", zo_round(t.r * 255), zo_round(t.g * 255), zo_round(t.b * 255))
        local icon = string.format("|t20:20:%s:inheritcolor|t ", W.UI(W.TextureLoaded("skip.dds") and "skip.dds" or "chevron.dds"))
        -- (the time switches to cream and back to the accent: no |r in between, that would end in white)
        local line = L("SKIP_SAVED", "|c" .. BRIGHT .. Skip.SavedText() .. "|c" .. accent)
        text = text .. "\n\n|c" .. accent .. icon .. line .. "|r"
    end
    return text
end

-- The quest a finished conversation goes under: the quest handed in there, else the quest
-- the game changed during it (accepted, step done...), else the one it was about, else
-- "Other conversations". Quest events can come a moment after the window closes.
local recent   -- { name, at }: the last quest the game changed

local function QuestEvent(name)
    if name and name ~= "" then recent = { name = zo_strformat("<<1>>", name), at = GetFrameTimeSeconds() } end
end

local function SaveStory(c)
    if not c.lines or #c.lines == 0 or not W.Story then return end
    local function Changed() return recent and recent.at >= c.started - 0.5 and recent.name end
    local function Save()
        local name = c.questName or Changed()
        if not name and c.qi and IsValidQuestIndex(c.qi) then name = zo_strformat("<<1>>", GetJournalQuestName(c.qi)) end
        W.Story.Add(name, c.npc, c.lines)
    end
    if c.questName or Changed() then Save() else zo_callLater(Save, 1500) end
end

-- What the NPC says: into the story log, and into chat (name in the accent color, words in
-- the game's text color) when sv.skip.toChat.
local function ToChat(text, skipped)
    if not text or text == "" then return end
    Record("npc", text, skipped)
    if not sv().toChat then return end
    local who = convo and convo.npc or NpcName()
    local line = W.Colorize(C.quest, text)
    if who then line = W.Colorize(C.theme, who .. ":") .. " " .. line end
    d(line)
end

-- "Only dialogs I've read before": true when this text was seen already (and remembers it).
local function SeenBefore(kind, text)
    local s = sv()
    if not s.onlySeen then return true end
    local key = kind .. "|" .. ((convo and convo.npc) or "") .. "|" .. zo_strsub(text or "", 1, 80)
    if s.seen[key] then return true end
    if s.seenN >= MAX_SEEN then
        s.seen, s.seenN = {}, 0
    end
    s.seen[key] = true
    s.seenN = s.seenN + 1
    return false
end

local function Active()
    return sv().on and convo ~= nil and not convo.paused
end

-- ---------------------------------------------------------------------------
-- Which answer to give: index, or nil + "choice" when it's a real decision.

local function PickOption(count)
    local s = sv()
    local quest, talk, important = nil, {}, {}
    local onlyOld = true   -- every answer left was given before (or is "Goodbye")
    -- a service NPC (store, bank, stable, trader...): its "Talk" line is only taken when the
    -- game marks it for a quest, so shopping isn't skipped past
    local service, alt = false, false
    for i = 1, count do
        local _, optionType = GetChatterOption(i)
        if ALT_TYPES[optionType] then alt = true end
        if optionType ~= TALK and optionType ~= START_TALK and optionType ~= GOODBYE and not QUEST_TYPES[optionType] then
            service = true
        end
    end
    for i = 1, count do
        local text, optionType, _, isImportant, chosenBefore = GetChatterOption(i)
        if not chosenBefore and optionType ~= GOODBYE then onlyOld = false end
        if not chosenBefore then
            if QUEST_TYPES[optionType] then
                local allowed = (optionType ~= BESTOW or s.accept) and (optionType ~= COMPLETE or s.turnIn)
                if allowed and not quest then quest = i end
            elseif optionType == TALK or SKILL_TYPES[optionType]
                or (optionType == START_TALK and (isImportant or not service)) then
                talk[#talk + 1] = { index = i, text = text, score = Score(text, optionType, isImportant, IsRed(i, text)) }
                if isImportant then important[#important + 1] = i end
            end
        end
    end
    if quest then return quest end
    local decision = #talk > 1 or (#talk == 1 and alt)
    if not decision then
        local only = talk[1]
        if only and only.score then return only.index end
        return nil, (only and "choice") or (onlyOld and "done") or nil   -- (a red answer with red off)
    end
    if not s.choices then
        -- the game marks the answer the quest needs; one marked = no real choice
        if #important == 1 then
            for _, t in ipairs(talk) do
                if t.index == important[1] and t.score then return t.index end   -- (not when it's red and red is off)
            end
        end
        return nil, "choice"
    end
    -- best answer: highest score, the game's order breaks ties (its first answer is usually the main one)
    ScoreRewards(talk)
    local best
    for _, t in ipairs(talk) do
        if t.score and (not best or t.score > best.score) then best = t end
    end
    if not best then return nil, "choice" end
    return best.index, nil, best.text
end

-- ---------------------------------------------------------------------------
-- Speed. The answer goes to the server first, in the same frame the page arrives (no
-- delays like zo_callLater); chat lines are written after it. While Questbound answers,
-- the dialog window is see-through (sv.skip.hideWindow), so pages don't flash by: it
-- comes back the moment you're needed (a choice, a new page with "only read before",
-- a shop) or HIDE_SAFETY s after the last answer, whatever happens.

local HIDE_SAFETY = 2.5
local hiding = false
local lastAnswer = 0

local function DialogWindows()
    return { _G.ZO_InteractWindow, _G.ZO_InteractWindow_Gamepad }
end

local function KeepHidden()
    -- the window's own fade-in would bring it back: hold it at 0 every frame
    if GetFrameTimeSeconds() - lastAnswer > HIDE_SAFETY then
        Skip.ShowWindow()
        return
    end
    for _, c in ipairs(DialogWindows()) do c:SetAlpha(0) end
end

function Skip.ShowWindow()
    if not hiding then return end
    hiding = false
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Hide")
    for _, c in ipairs(DialogWindows()) do c:SetAlpha(1) end
end

local function HideWindow()
    lastAnswer = GetFrameTimeSeconds()
    if hiding or not sv().hideWindow then return end
    hiding = true
    for _, c in ipairs(DialogWindows()) do c:SetAlpha(0) end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Hide", 0, KeepHidden)
end

-- answer now, tell later
local function Answer(index, bodyText, chosen)
    local answer = GetChatterOption(index)
    SelectChatterOption(index)
    HideWindow()
    convo.picks = convo.picks + 1
    convo.acted = true
    ToChat(bodyText)
    Record("you", answer)
    -- a decision was made for you: say which answer
    if chosen and sv().toChat then d(W.Colorize(C.dim, L("SKIP_PICKED", zo_strtrim(chosen)))) end
end

local function Step(bodyText, count)
    if not Active() then return end
    local s = sv()
    if convo.picks >= MAX_PICKS then Skip.ShowWindow() return end
    if not SeenBefore("talk", bodyText) then   -- new words: you read them yourself
        Skip.ShowWindow()
        return
    end

    local index, why, chosen = PickOption(count)
    if index then
        Answer(index, bodyText, chosen)
    elseif (why == "done" or count == 0) and convo.acted and s.close then
        -- nothing new left to say after we talked for you: close the window
        -- (kept first: closing ends the conversation and its story at once)
        ToChat(bodyText)
        EndInteraction(INTERACTION_CONVERSATION)
    else
        Skip.ShowWindow()   -- your turn (a choice, a shop...)
        if why == "choice" and not convo.noted then
            convo.noted = true
            ToChat(bodyText, false)
            W.Print(L("SKIP_CHOICE"))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events

local function OnChatterBegin(_, count)
    local npc = NpcName()
    local qi = sv().on and ConvoQuest(npc) or nil
    convo = {
        picks = 0,
        npc = npc,
        qi = qi,
        started = GetFrameTimeSeconds(),
        -- holding Shift while starting to talk, or a kind of quest you read yourself
        -- (settings "Which quests to skip"): this conversation stays yours
        paused = (sv().shiftPause and IsShiftKeyDown()) or not SectionOn(qi),
    }
    Step(GetChatterGreeting(), count)
end

local function OnConversationUpdated(_, bodyText, count)
    if not convo then return end
    Step(bodyText, count)
end

local ReadSoon   -- (below: "read the note" steps)

local function OnChatterEnd()
    if convo then SaveStory(convo) end
    convo = nil
    Skip.ShowWindow()
    ReadSoon()   -- the NPC may have just handed you something to read
end

local function OnQuestOffered()
    if not Active() or not sv().accept then return end
    local dialog, response = GetOfferedQuestInfo()
    if not SeenBefore("offer", dialog) then
        Skip.ShowWindow()
        return
    end
    AcceptOfferedQuest()
    convo.acted = true
    ToChat(dialog)
    Record("you", response)
    -- done at once: no waiting for the "goodbye" page (one server round trip less)
    if sv().close then
        EndInteraction(INTERACTION_CONVERSATION)
    else
        HideWindow()
    end
end

local function OnQuestCompleteDialog(_, journalIndex)
    if not Active() or not sv().turnIn then return end
    -- a kind of quest you read yourself (the conversation may have been about another one)
    if not SectionOn(journalIndex) then
        convo.paused = true
        Skip.ShowWindow()
        return
    end
    local _, endDialog, confirmText = GetJournalQuestEnding(journalIndex)
    if not SeenBefore("end", endDialog) then
        Skip.ShowWindow()
        return
    end
    convo.questName = zo_strformat("<<1>>", GetJournalQuestName(journalIndex))   -- (the story goes under it)
    -- (no closing here: the NPC often offers the next quest right after)
    CompleteQuest()
    HideWindow()
    convo.acted = true
    ToChat(endDialog)
    Record("you", confirmText)
end

-- ---------------------------------------------------------------------------
-- "Read the note" steps (sv.skip.readNotes): when an open objective says to read
-- something, the quest item / quest tool / backpack item it means is used for you, and
-- the book window it opens closes again at once (the step counts on opening).
-- Same calls as the game's inventoryslot.lua: CanUseQuestItem / UseQuestItem(quest, step,
-- condition), CanUseQuestTool / UseQuestTool(quest, tool), IsItemUsable / UseItem(bag, slot).

local READ_WORDS = { "read", "lies", "lest", "lesen", "lire", "lis", "lisez" }
local READ_DELAY = 400      -- ms after the quest changed (the journal is up to date by then)
local tried = {}            -- [key] = { n = tries, at = seconds }: no hammering the same item
local autoBookUntil = 0     -- a book opening before this time was opened by us

local function Call(name, ...)
    local ok, fn = pcall(function() return _G[name] end)
    if not ok or type(fn) ~= "function" then return false end
    if pcall(fn, ...) then return true end
    -- protected in this version: the secure way (works out of combat)
    return pcall(CallSecureProtected, name, ...)
end

local function Can(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return true end   -- no check function: try it anyway
    local ok, result = pcall(fn, ...)
    return ok and result ~= false
end

local function QuestItemName(questItemId)
    if questItemId and questItemId ~= 0 and GetQuestItemName then
        local ok, name = pcall(GetQuestItemName, questItemId)
        if ok and name and name ~= "" then return zo_strformat("<<1>>", name) end
    end
end

-- an item name fits the objective when one of its words (4+ letters) is in the text
local function NameFits(words, name)
    if not name then return false end
    for w in string.gmatch(zo_strlower(name), "[^%s%p]+") do
        if #w >= 4 and string.find(words, " " .. w, 1, true) then return true end
    end
    return false
end

local function TryOnce(key)
    local now = GetFrameTimeSeconds()
    local t = tried[key]
    if t and (t.n >= 2 or now - t.at < 10) then return false end
    tried[key] = { n = (t and t.n or 0) + 1, at = now }
    return true
end

local function Use(key, name, fnName, ...)
    if not TryOnce(key) then return false end
    autoBookUntil = GetFrameTimeSeconds() + 3
    if Call(fnName, ...) then
        if name and sv().toChat then d(W.Colorize(C.dim, L("SKIP_READ", name))) end
        return true
    end
    return false
end

-- one read-objective of quest qi (step, cond): find what to read and use it
local function ReadFor(qi, step, cond, words)
    -- 1. the item attached to this very objective
    local _, _, _, _, itemId = GetQuestItemInfo(qi, step, cond)
    if itemId and itemId ~= 0 and Can("CanUseQuestItem", qi, step, cond) then
        return Use("i" .. qi .. ":" .. step .. ":" .. cond, QuestItemName(itemId), "UseQuestItem", qi, step, cond)
    end
    -- 2. the quest's tools: the one named in the objective, else the only usable one
    local usable, named = {}, nil
    for tool = 1, GetQuestToolCount(qi) do
        local _, _, _, _, toolId = GetQuestToolInfo(qi, tool)
        if toolId and toolId ~= 0 and Can("CanUseQuestTool", qi, tool) then
            local name = QuestItemName(toolId)
            usable[#usable + 1] = { tool = tool, name = name }
            if NameFits(words, name) then named = usable[#usable] end
        end
    end
    local pick = named or (#usable == 1 and usable[1]) or nil
    if pick then
        return Use("t" .. qi .. ":" .. pick.tool, pick.name, "UseQuestTool", qi, pick.tool)
    end
    -- 3. a normal item in the backpack whose name is in the objective ("Read Ulvon's letter")
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local name = GetItemName(BAG_BACKPACK, slot)
        if name and name ~= "" then
            name = zo_strformat("<<1>>", name)
            if NameFits(words, name) and IsItemUsable(BAG_BACKPACK, slot) then
                return Use("b" .. GetItemId(BAG_BACKPACK, slot), name, "UseItem", BAG_BACKPACK, slot)
            end
        end
    end
    return false
end

local function ReadNotes()
    local s = sv()
    if not s.on or not s.readNotes then return end
    -- not mid-conversation, not in a fight (item use is blocked then; tried again after)
    if convo or IsUnitInCombat("player") or IsUnitDead("player") then return end
    for qi = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(qi) then
            for step = 1, GetJournalQuestNumSteps(qi) do
                for cond = 1, GetJournalQuestNumConditions(qi, step) do
                    local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, step, cond)
                    if text and text ~= "" and not isFail and not isComplete and isVisible ~= false then
                        local words = Words(text)
                        if HasAny(words, READ_WORDS) and ReadFor(qi, step, cond, words) then
                            return   -- one at a time; the quest update brings the next check
                        end
                    end
                end
            end
        end
    end
end

ReadSoon = function()   -- (declared above OnChatterEnd)
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Read")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Read", READ_DELAY, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Read")
        ReadNotes()
    end)
end

-- quest books and notes: opening one already counts (objective, lore), so it can close at
-- once; one we opened ourselves for a "read" step always closes
local function OnShowBook()
    local s = sv()
    if not s.on then return end
    local ours = GetFrameTimeSeconds() < autoBookUntil
    if not ours and not s.books then return end
    if s.shiftPause and IsShiftKeyDown() then return end
    autoBookUntil = 0
    EndInteraction(INTERACTION_BOOK)
end

-- ---------------------------------------------------------------------------
-- Public

function Skip.IsOn()
    return sv().on
end

function Skip.Toggle()
    local s = sv()
    s.on = not s.on
    W.Print(L(s.on and "SKIP_NOW_ON" or "SKIP_NOW_OFF"))
    -- another dialog skipper running too would answer twice
    if s.on and QuestSkipper and not s.otherNoted then
        s.otherNoted = true
        W.Print(L("SKIP_OTHER_ADDON", "Quest Skipper"))
    end
    W.callbacks:FireCallbacks("SettingsChanged")
end

function Skip.Init()
    local em = EVENT_MANAGER
    em:RegisterForEvent(NAME, EVENT_CHATTER_BEGIN, OnChatterBegin)
    em:RegisterForEvent(NAME, EVENT_CONVERSATION_UPDATED, OnConversationUpdated)
    em:RegisterForEvent(NAME, EVENT_CHATTER_END, OnChatterEnd)
    em:RegisterForEvent(NAME, EVENT_QUEST_OFFERED, OnQuestOffered)
    em:RegisterForEvent(NAME, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    em:RegisterForEvent(NAME, EVENT_SHOW_BOOK, OnShowBook)
    -- "read the note" steps: checked whenever a quest changes, and after a fight
    local R = NAME .. "Read"
    em:RegisterForEvent(R, EVENT_QUEST_ADDED, ReadSoon)
    em:RegisterForEvent(R, EVENT_QUEST_ADVANCED, ReadSoon)
    em:RegisterForEvent(R, EVENT_QUEST_CONDITION_COUNTER_CHANGED, ReadSoon)
    em:RegisterForEvent(R, EVENT_PLAYER_ACTIVATED, ReadSoon)
    em:RegisterForEvent(R, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then ReadSoon() end
    end)
    -- story log: which quest the game changed (the conversation's story goes under it)
    local G = NAME .. "Log"
    em:RegisterForEvent(G, EVENT_QUEST_ADDED, function(_, _, name) QuestEvent(name) end)
    em:RegisterForEvent(G, EVENT_QUEST_ADVANCED, function(_, _, name) QuestEvent(name) end)
    em:RegisterForEvent(G, EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(_, _, name) QuestEvent(name) end)
    em:RegisterForEvent(G, EVENT_QUEST_COMPLETE, function(_, name) QuestEvent(name) end)
end

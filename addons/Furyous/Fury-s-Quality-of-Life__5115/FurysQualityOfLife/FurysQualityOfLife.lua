-- Fury's Quality of Life
-- Small comforts for everyday play, each one a switch on the settings page. Every switch starts
-- turned off, so the addon does nothing until you pick what you want.
--
-- Features so far:
--   SelectAll.lua  a Select all button on the deconstruct screens
--   Fishing.lua    a bite alert, the right bait for each fishing hole, bag warning, rare fish
--   Alerts.lua     the shared sound-and-flash alert, and the queue alert
--   Locks.lua      lock or unlock everything the character is wearing

FurysQualityOfLife = {}
local QOL = FurysQualityOfLife

QOL.name    = "FurysQualityOfLife"
QOL.title   = "Fury's Quality of Life"
QOL.version = "0.6.0"

-- Everything a new install starts with. Every switch is off; the "take" switches are extra
-- kinds of items Select all may pick up, so off is the careful choice.
local defaults = {
    welcomed = false,          -- the one-time welcome line was shown

    -- Select all: the button shows on every deconstruct screen (crafting stations, enchanting
    -- tables, and the deconstruction assistant's screen)
    selectAll = false,
    keepFilled = false,        -- after each deconstruct, select the next batch

    -- Select all: what it may pick up besides plain gear
    takeSets = false,          -- gear that belongs to an item set
    takeUncollected = false,   -- set pieces not yet in the Set Collection
    takeResearch = false,      -- gear with a trait this character can still research
    takeCrafted = false,       -- gear made by a player
    takeArmory = false,        -- gear saved in an Armory build
    maxQuality = ITEM_FUNCTIONAL_QUALITY_ARCANE,   -- nothing better than this is picked up

    -- Fishing
    fishAlert = false,         -- sound and flash when a fish bites
    fishSound = "DUEL_START",  -- which sound the alert plays ("NONE" for flash only)
    fishBait = false,          -- choose the bait that fits the water, the one with the most left
    fishBagWarn = false,       -- say so when the bag is nearly full at a bite
    fishRare = false,          -- callout when a rare fish is caught

    -- Queue alert
    queueAlert = false,        -- sound and flash when a group finder queue is ready
    queueSound = "DUEL_START",

    -- Lock what I'm wearing
    lockButtons = false,       -- show the two buttons on the inventory screen
}

local sv

function QOL.SV()
    return sv
end

function QOL.Msg(text)
    QOL.Theme.Chat(text)
end
local Say = QOL.Msg

------------------------------------------------------------------------------
-- Start here: the one window of this addon. Its title carries the version and its gear opens
-- the settings.
------------------------------------------------------------------------------
local START_INTRO = "Small comforts for everyday play. Everything starts turned off: the addon does nothing until you turn a feature on in the settings (the gear at the top right of this page)."

local START_SECTIONS = {
    { title = "1. Turn on what you want",
      lines = {
          "Click the gear at the top right, or open Settings > Addons > Fury's Quality of Life.",
          "Each feature has its own switch, and each switch has a hover tip that says what it does.",
      } },
    { title = "2. Select all on the deconstruct screens",
      lines = {
          "Adds a Select all button next to the big item slot on every deconstruct screen: blacksmithing, clothing, woodworking and jewelry stations, enchanting tables (extracting glyphs) and the deconstruct-anything screen of Giladil the Ragpicker. One switch turns it on everywhere.",
          "One click puts every item in the list you are looking at into the slot. It only selects: nothing is deconstructed until you press the game's own Deconstruct key, and the game still asks you to confirm.",
          "The game takes up to 100 items at a time. If there are more, deconstruct and click Select all again.",
          "Select none, right under it, empties the slot again.",
          "Keep the slot filled (its own switch): after Select all, each deconstruct is followed by the next batch, so a full bag is only a few presses of the Deconstruct key. It stops when the list is empty, when you click Select none or when you leave the station.",
      } },
    { title = "3. What Select all leaves alone",
      lines = {
          "Always: items you locked in the game, and items FCO ItemSaver or Item Saver protect from deconstruction (if you use one of them).",
          "Unless you allow it in the settings: gear that belongs to a set, set pieces you have not collected yet, gear with a trait this character can still research, gear made by a player, gear saved in an Armory build, and anything better than the quality you choose (Superior, blue, to begin with).",
          "After each click a chat line says how many items were selected and why the others were left out. You can still add any of them by hand.",
      } },
    { title = "4. Fishing: bite alert",
      lines = {
          "Plays a sound and flashes \"Fish on the line!\" across the screen the moment a fish bites, so you can look away while you wait. Press your interact key to reel in as usual; the addon never reels in for you.",
          "The settings let you pick the sound, or no sound, and have a button to try it.",
      } },
    { title = "5. Fishing: the right bait",
      lines = {
          "When you look at a fishing hole, the bait that fits its water is chosen for you: Crawlers or Fish Roe for foul water, Insect Parts or Shad for rivers, Guts or Minnow for lakes, Worms or Chub for salt water. If you carry both baits for that water, the one you have the most of is used.",
          "With neither in the bag, Simple Bait is used if you have any. A chat line says what was chosen.",
          "The bait is chosen once each time you look at a hole. If you then pick another bait by hand, yours stays until you look away.",
          "The water is read from the English name of the fishing hole, so this part needs the game in English.",
      } },
    { title = "6. Fishing: bag warning and rare fish",
      lines = {
          "Bag warning: when a fish bites and your bag has 5 free slots or fewer, a chat line and a short sound say so. It is said once, and again only after the bag had room in between.",
          "Rare fish: when a rare fish (the kind the fishing achievements count) lands in your bag, its name flashes across the screen and a chat line links it.",
      } },
    { title = "7. Queue alert",
      lines = {
          "When the dungeon finder, a battleground queue or any other group finder queue asks if you are ready, the same sound and flash as the bite alert tell you, for longer. You still accept it yourself.",
          "It has its own sound choice and a button to try it.",
      } },
    { title = "8. Lock what I'm wearing",
      lines = {
          "One click puts the game's own lock on every piece of gear the character has on, both weapon bars included. A locked item can't be deconstructed, sold, traded or destroyed, and Select all never picks it up.",
          "Unlock what I'm wearing takes the locks off again. Both are buttons in the settings, /qol lock and /qol unlock, and keys you can bind.",
          "Turn on \"Buttons on the inventory screen\" in the settings and both buttons also sit under your weapons on the left of the inventory screen.",
          "It locks what is worn at that moment. After you change gear, click it again.",
      } },
    { title = "9. Commands and keys",
      lines = {
          "/qol opens this page. /qol settings opens the settings. /qol help lists the commands. /furyqol does the same if another addon uses /qol.",
          "Under Controls > Keybindings > Fury's Quality of Life you can give Select all, Lock and Unlock their own keys.",
          "The Select all buttons are part of the keyboard and mouse interface. In gamepad mode they are not added.",
      } },
}

local startReady = false

function QOL.ShowStart()
    local win = FurysQualityOfLife_StartHere
    local T = QOL.Theme
    T.StartPage(win, START_INTRO, START_SECTIONS)
    if not startReady then
        startReady = true
        T.SetTitle(win, QOL.title, QOL.version)
        local gear = T.Gear(win, win:GetNamedChild("Close"), QOL.OpenSettings, "Settings: turn features on and off (also /qol settings)")
    -- The other Fury addons, one click each, in the title bar (Theme.lua).
        T.TitleIcons(win, gear)
    end
end

function QOL.HideStart()
    SCENE_MANAGER:HideTopLevel(FurysQualityOfLife_StartHere)
end

function QOL.ToggleStart()
    if FurysQualityOfLife_StartHere:IsHidden() then
        QOL.ShowStart()
    else
        QOL.HideStart()
    end
end

------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------
local function Help()
    Say(QOL.title .. " v" .. QOL.version .. " commands:")
    Say("/qol  open or close the Start here page")
    Say("/qol settings  open the settings")
    Say("/qol select  Select all on the deconstruct screen you have open")
    Say("/qol lock  lock everything you are wearing")
    Say("/qol unlock  unlock everything you are wearing")
    Say("/qol help  this list")
end

local function Slash(args)
    local cmd = zo_strlower(args or "")
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "" or cmd == "guide" or cmd == "start" then
        QOL.ToggleStart()
    elseif cmd == "settings" then
        QOL.OpenSettings()
    elseif cmd == "select" then
        QOL.SelectAllKey()
    elseif cmd == "lock" then
        QOL.LockWorn()
    elseif cmd == "unlock" then
        QOL.UnlockWorn()
    elseif cmd == "fishdebug" then
        QOL.FishDebug()
    else
        Help()
    end
end

------------------------------------------------------------------------------
-- Start-up
------------------------------------------------------------------------------
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(QOL.name, EVENT_PLAYER_ACTIVATED)
    QOL.Theme.Welcome(sv, "welcomed", "Welcome! Everything starts turned off. Type /qol to see what it can do and to turn on what you want.")
end

local function OnAddOnLoaded(_, name)
    if name ~= QOL.name then return end
    EVENT_MANAGER:UnregisterForEvent(QOL.name, EVENT_ADD_ON_LOADED)

    sv = QOL.Theme.SavedVars("FurysQualityOfLife_SV")
    for key, value in pairs(defaults) do
        if sv[key] == nil then sv[key] = value end
    end

    ZO_CreateStringId("SI_BINDING_NAME_FURYSQUALITYOFLIFE_SELECT_ALL", "Select all (deconstruct screens)")
    ZO_CreateStringId("SI_BINDING_NAME_FURYSQUALITYOFLIFE_GUIDE", "Open/close the Start here page")
    ZO_CreateStringId("SI_BINDING_NAME_FURYSQUALITYOFLIFE_LOCK", "Lock what I'm wearing")
    ZO_CreateStringId("SI_BINDING_NAME_FURYSQUALITYOFLIFE_UNLOCK", "Unlock what I'm wearing")

    QOL.InitSelectAll()
    QOL.InitFishing()
    QOL.RefreshQueueAlert()
    QOL.InitLocks()
    QOL.InitSettings()

    SLASH_COMMANDS["/qol"] = Slash
    SLASH_COMMANDS["/furyqol"] = Slash
    EVENT_MANAGER:RegisterForEvent(QOL.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(QOL.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

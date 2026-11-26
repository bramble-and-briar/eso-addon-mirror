-- Fury's Quality of Life - settings page (Settings > Addons > Fury's Quality of Life)

local QOL = FurysQualityOfLife

local panel

-- One on/off switch bound to a saved field.
local function Switch(field, name, tooltip, refresh)
    local function Get() return QOL.SV()[field] end
    local function Set(value)
        QOL.SV()[field] = value
        if refresh then refresh() end
    end
    return { type = "checkbox", name = name, tooltip = tooltip, getFunc = Get, setFunc = Set, default = false }
end

local function GetSound() return QOL.SV().fishSound end
local function SetSound(value) QOL.SV().fishSound = value end

local function GetQueueSound() return QOL.SV().queueSound end
local function SetQueueSound(value) QOL.SV().queueSound = value end

local function GetQuality() return QOL.SV().maxQuality end
local function SetQuality(value) QOL.SV().maxQuality = value end

function QOL.InitSettings()
    local LAM = LibAddonMenu2

    panel = LAM:RegisterAddonPanel("FurysQualityOfLife_Settings", {
        type = "panel",
        name = QOL.title,
        displayName = "|cA08CFF" .. QOL.title .. "|r",
        author = "Furyous",
        version = QOL.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local names = QOL.QUALITY_NAMES
    local soundNames, soundKeys = {}, {}
    for index, choice in ipairs(QOL.ALERT_SOUNDS) do
        soundKeys[index], soundNames[index] = choice[1], choice[2]
    end
    local options = {
        { type = "description",
          text = "Small comforts for everyday play. Everything starts turned off: turn on what you want below. " ..
                 "The Start here page explains each feature in plain words." },
        { type = "button", name = "Start here",
          tooltip = "Opens the Start here page (/qol): what each feature does and how to use it.",
          func = QOL.ShowStart },

        { type = "header", name = "Select all on the deconstruct screens" },
        { type = "description",
          text = "Adds a Select all button next to the big item slot on every deconstruct screen. One click puts every item of the list you are " ..
                 "looking at into the slot, up to the 100 the game takes at a time. It only selects: nothing is " ..
                 "deconstructed until you press the Deconstruct key yourself. Items you locked, and items FCO ItemSaver " ..
                 "or Item Saver protect, are never selected." },
        Switch("selectAll", "Select all and Select none buttons",
            "Shows the Select all button, and Select none under it, on every deconstruct screen: the Deconstruct tab of blacksmithing, clothing, woodworking and jewelry stations, the Extraction tab of enchanting tables, and the deconstruct-anything screen of Giladil the Ragpicker. Starts turned off.", QOL.RefreshSelectAll),
        Switch("keepFilled", "Keep the slot filled",
            "After you click Select all, each deconstruct is followed by the next batch, so you only press the Deconstruct key until the list is empty. It stops when you click Select none or leave the station. The same items are left out as with Select all. Starts turned off."),

        { type = "header", name = "What Select all may pick up" },
        { type = "description",
          text = "Plain gear and glyphs are always picked up. Each switch below adds one more kind of item. " ..
                 "Leave a switch off to keep those items out; you can still add any of them by hand." },
        Switch("takeSets", "Set items",
            "Off: gear that belongs to an item set is left out. On: set gear is picked up like any other gear. Starts turned off."),
        Switch("takeUncollected", "Set pieces you have not collected yet",
            "Only matters when Set items is on. Off: a set piece that is not in your Set Collection yet is left out, so you can bind it first. On: it is picked up (deconstructing it also adds it to your collection). Starts turned off."),
        Switch("takeResearch", "Gear with a trait you can still research",
            "Off: gear whose trait this character has not researched yet is left out, so you can research it. On: it is picked up. Starts turned off."),
        Switch("takeCrafted", "Crafted gear",
            "Off: gear made by a player is left out. On: it is picked up. Glyphs are not affected. Starts turned off."),
        Switch("takeArmory", "Gear in an Armory build",
            "Off: gear saved in one of your Armory builds is left out. On: it is picked up (the game still warns you before it is deconstructed). Starts turned off."),
        { type = "dropdown", name = "Best quality to pick up",
          tooltip = "Items and glyphs better than this are left out. Starts at Superior (blue), so Epic and Legendary items are never selected until you raise it.",
          choices = { names[1] .. " (white)", names[2] .. " (green)", names[3] .. " (blue)", names[4] .. " (purple)", names[5] .. " (gold)" },
          choicesValues = { 1, 2, 3, 4, 5 },
          getFunc = GetQuality, setFunc = SetQuality,
          default = ITEM_FUNCTIONAL_QUALITY_ARCANE },

        { type = "header", name = "Fishing" },
        Switch("fishAlert", "Bite alert",
            "Plays a sound and flashes \"Fish on the line!\" across the screen the moment a fish bites. You still reel in yourself. Starts turned off.", QOL.RefreshFishing),
        { type = "dropdown", name = "Bite alert sound",
          tooltip = "The sound the bite alert plays. Pick No sound for the flash alone.",
          choices = soundNames, choicesValues = soundKeys,
          getFunc = GetSound, setFunc = SetSound,
          default = "DUEL_START" },
        { type = "button", name = "Try the alert",
          tooltip = "Plays the sound and shows the flash once, so you know what a bite looks and sounds like. Close the settings to see the flash on the game world.",
          func = QOL.FishAlert },
        Switch("fishBait", "Choose the right bait",
            "When you look at a fishing hole, the bait that fits its water is chosen: foul, river, lake or salt water. If you carry both baits for that water, the one you have the most of is used; with neither, Simple Bait. A bait you pick by hand afterwards stays until you look away. Needs the game in English. Starts turned off.", QOL.RefreshFishing),
        Switch("fishBagWarn", "Bag nearly full warning",
            "When a fish bites and your bag has 5 free slots or fewer, a chat line and a short sound say so. Said once, and again only after the bag had room in between. Starts turned off.", QOL.RefreshFishing),
        Switch("fishRare", "Rare fish callout",
            "When a rare fish (the kind the fishing achievements count) lands in your bag, its name flashes across the screen with the bite alert sound, and a chat line links it. Starts turned off.", QOL.RefreshFishing),

        { type = "header", name = "Queue alert" },
        Switch("queueAlert", "Alert when a queue is ready",
            "Plays a sound and flashes \"Your queue is ready!\" across the screen when the dungeon finder, a battleground queue or another group finder queue asks if you are ready. You still accept it yourself. Starts turned off.", QOL.RefreshQueueAlert),
        { type = "dropdown", name = "Queue alert sound",
          tooltip = "The sound the queue alert plays. Pick No sound for the flash alone.",
          choices = soundNames, choicesValues = soundKeys,
          getFunc = GetQueueSound, setFunc = SetQueueSound,
          default = "DUEL_START" },
        { type = "button", name = "Try the queue alert",
          tooltip = "Plays the sound and shows the flash once. Close the settings to see the flash on the game world.",
          func = QOL.QueueAlert },

        { type = "header", name = "Lock what I'm wearing" },
        { type = "description",
          text = "Puts the game's own lock on every piece of gear this character has on, both weapon bars included. A locked " ..
                 "item can't be deconstructed, sold, traded or destroyed, and Select all never picks it up. It locks what is " ..
                 "worn right now, so click it again after you change gear." },
        Switch("lockButtons", "Buttons on the inventory screen",
            "Shows Lock worn gear and Unlock worn gear under your weapons, on the left of the inventory screen. Starts turned off.", QOL.RefreshLockButtons),
        { type = "button", name = "Lock what I'm wearing", width = "half",
          tooltip = "Locks every item this character has equipped right now. Also /qol lock, and a key you can bind.",
          func = QOL.LockWorn },
        { type = "button", name = "Unlock what I'm wearing", width = "half",
          tooltip = "Takes the lock off every item this character has equipped right now. Also /qol unlock, and a key you can bind.",
          func = QOL.UnlockWorn },
    }
    QOL.Theme.MoreOptions(options)
    LAM:RegisterOptionControls("FurysQualityOfLife_Settings", options)
end

function QOL.OpenSettings()
    QOL.HideStart()
    LibAddonMenu2:OpenToPanel(panel)
end

-- Skill Point Finder: Settings > Add-Ons > Skill Point Finder.

local SP = ESOC_SkillPointFinder
local Settings = {}
SP.Settings = Settings

-- Console LibHarvensAddonSettings passes the whole { name, data } item; other versions pass the data.
local function dropdownValue(item)
    if type(item) == "table" then return item.data end
    return item
end

local chosenDungeon

local function dungeonItems()
    local items = {}
    local ok, state = pcall(SP.Scan.Get)
    if ok then
        for _, dungeon in ipairs(state.dungeons) do
            local mark = dungeon.questDone and " (done)" or ""
            items[#items + 1] = { name = dungeon.name .. mark, data = dungeon.zoneId }
        end
    end
    if #items == 0 then items[1] = { name = "No dungeons found", data = false } end
    return items
end

local function dungeonName(zoneId)
    local ok, state = pcall(SP.Scan.Get)
    local dungeon = ok and zoneId and state.dungeonByZone[zoneId]
    return dungeon and dungeon.name or "Choose a dungeon"
end

local function createSettings(LHAS)
    local page = LHAS:AddAddon(SP.TITLE, { allowRefresh = true })
    local options = SP.sv.options
    local function open(tab)
        return function() SP.Screen.Open(tab) end
    end
    page:AddSettings({
        { type = LHAS.ST_LABEL, label = function()
            local ok, text = pcall(function() return SP.Lists.Summary(SP.Scan.Get()) end)
            return ok and text or "Skill Point Finder"
        end },
        { type = LHAS.ST_BUTTON, label = "Overview", buttonText = "Open",
            tooltip = "What you've collected and what's still missing. LT and RT change tab, LB and RB change page.",
            clickHandler = open("Overview") },
        { type = LHAS.ST_BUTTON, label = "Easiest first", buttonText = "Open",
            tooltip = "Every missing skill point, from very easy to hard.", clickHandler = open("Easiest first") },
        { type = LHAS.ST_BUTTON, label = "Zones ranked by points left", buttonText = "Open", clickHandler = open("By zone") },
        { type = LHAS.ST_BUTTON, label = "Checklist: group events and dungeon quests", buttonText = "Open",
            tooltip = "Every public dungeon group event and group dungeon quest for this character. A queues the dungeons you're missing.",
            clickHandler = open("Checklist") },
        { type = LHAS.ST_BUTTON, label = "This zone", buttonText = "Open", clickHandler = open("This zone") },

        { type = LHAS.ST_SECTION, label = "Dungeon Finder" },
        { type = LHAS.ST_BUTTON, label = "Queue every dungeon whose quest I'm missing (normal)", buttonText = "Queue",
            tooltip = "Selects those dungeons in the Dungeon Finder and starts the queue. If the game won't let it start, they stay ticked and you press Queue.",
            clickHandler = function() SP.Queue.Start(false) end },
        { type = LHAS.ST_BUTTON, label = "Queue every dungeon whose quest I'm missing (veteran)", buttonText = "Queue",
            clickHandler = function() SP.Queue.Start(true) end },

        { type = LHAS.ST_SECTION, label = "Options" },
        { type = LHAS.ST_CHECKBOX, label = "Show a panel when I enter a zone or dungeon",
            getFunction = function() return options.showPanel end,
            setFunction = function(value) options.showPanel = value end },
        { type = LHAS.ST_SLIDER, label = "Panel stays for (seconds)", min = 5, max = 60, step = 5, format = "%d",
            getFunction = function() return options.panelSeconds end,
            setFunction = function(value) options.panelSeconds = value end },
        { type = LHAS.ST_CHECKBOX, label = "Hide Cyrodiil and Imperial City skyshards (PvP)",
            getFunction = function() return options.hidePvP end,
            setFunction = function(value) options.hidePvP = value end },
        { type = LHAS.ST_CHECKBOX, label = "Hide dungeons from DLC I don't have",
            getFunction = function() return options.hideLocked end,
            setFunction = function(value) options.hideLocked = value end },

        { type = LHAS.ST_SECTION, label = "Fix a dungeon quest by hand" },
        { type = LHAS.ST_LABEL, label = "If the add-on says a dungeon quest is missing but you've done it on this character, mark it here." },
        { type = LHAS.ST_DROPDOWN, label = "Dungeon", items = dungeonItems,
            getFunction = function() return dungeonName(chosenDungeon) end,
            setFunction = function(_, _, item) chosenDungeon = dropdownValue(item) or chosenDungeon end },
        { type = LHAS.ST_BUTTON, label = "Mark its quest done", buttonText = "Mark",
            clickHandler = function()
                if not chosenDungeon then return end
                SP.character.overrides[chosenDungeon] = true
                SP.MarkDirty()
                SP.Alert(dungeonName(chosenDungeon) .. " marked done.")
            end },
        { type = LHAS.ST_BUTTON, label = "Undo: let the add-on decide", buttonText = "Undo",
            clickHandler = function()
                if not chosenDungeon then return end
                SP.character.overrides[chosenDungeon] = nil
                SP.character.dungeonQuests[chosenDungeon] = nil
                SP.MarkDirty()
                SP.Alert(dungeonName(chosenDungeon) .. " is back to automatic.")
            end },
        { type = LHAS.ST_BUTTON, label = "Detection check (for testing)", buttonText = "Open", clickHandler = open("Check") },
    })
end

function Settings.Install()
    local LHAS = LibHarvensAddonSettings
    if LHAS and LHAS.AddAddon then createSettings(LHAS) end
end

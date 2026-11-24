-- Fury's Account Sync - settings page (Settings > Addons > Fury's Account Sync)

local AS = FurysAccountSync

local panel

local function ModeChoices()
    return { "Off", "Ask me when I log in", "Automatically when I log in" }, { "off", "ask", "auto" }
end

function AS.InitSettings()
    local LAM = LibAddonMenu2
    local sv = AS.SV()
    local names, values = ModeChoices()

    panel = LAM:RegisterAddonPanel("FurysAccountSync_Settings", {
        type = "panel",
        name = AS.title,
        displayName = "|cA08CFF" .. AS.title .. "|r",
        author = "Furyous",
        version = AS.version,
        slashCommand = "/fassettings",
        registerForRefresh = true,
    })

    local controls = {
        { type = "description",
          text = "Make your other accounts on this PC match your main one. Every account on the same PC shares this addon's " ..
                 "saved file, so the main takes a snapshot and the others copy it. Everything here starts turned off." },
        { type = "description",
          text = function()
              if AS.OtherSyncActive() then
                  return "|cFFC857Synced Account Settings is turned on for this account. It puts its own saved settings and keybinds back " ..
                         "after every login, so nothing is copied here while it is on.|r"
              end
              return ""
          end },

        { type = "header", name = "Main account" },
        { type = "description",
          text = function()
              if not sv.main then return "No main account chosen yet. Log in on the account the others should look like and press the button." end
              if AS.IsMain() then return "This account (" .. sv.main .. ") is the main." end
              return "The main account is " .. sv.main .. ". Snapshot: " ..
                     (sv.snapshot and AS.When(sv.snapshot.time) or "none yet") .. "."
          end },
        { type = "button", name = "Make this account the main",
          tooltip = "The account you're on becomes the one the others copy. You can change it later.",
          isDangerous = true,
          warning = "Your other accounts will copy this account from now on.",
          disabled = function() return AS.IsMain() end,
          func = function()
              sv.main = GetDisplayName()
              AS.Msg(sv.main .. " is now the main account. Press Take snapshot in /fas to save its setup.")
              AS.RefreshWindow()
          end },
        { type = "checkbox", name = "Take a snapshot automatically",
          tooltip = "On the main account, saves a fresh snapshot every time you log out, reload or change zones, so it's never out of date.",
          disabled = function() return not AS.IsMain() end,
          getFunc = function() return sv.autoSnapshot end,
          setFunc = function(v) sv.autoSnapshot = v end },

        { type = "header", name = "This account" },
        { type = "dropdown", name = "Copy the main's setup",
          tooltip = "On this account, when the main has a newer snapshot than the character you log in on: do nothing, show what would change and wait for Apply, or apply it straight away. The game keeps settings per character, so each character copies once.",
          choices = names, choicesValues = values,
          disabled = function() return AS.IsMain() or not sv.main end,
          getFunc = function() return AS.AccountRecord().mode end,
          setFunc = function(v)
              AS.AccountRecord().mode = v
              AS.RefreshWindow()
          end },

        { type = "header", name = "What to copy" },
        { type = "description",
          text = "Graphics and sound are already the same for every account on this PC, so they aren't listed." },
    }

    for _, p in ipairs(AS.PANELS) do
        controls[#controls + 1] = {
            type = "checkbox", name = "Settings: " .. p.name,
            tooltip = "Everything on the game's " .. p.name .. " settings page.",
            getFunc = function() return sv.what.panels[p.key] end,
            setFunc = function(v) sv.what.panels[p.key] = v; AS.RefreshWindow() end,
        }
    end
    controls[#controls + 1] = {
        type = "checkbox", name = "Keybinds",
        tooltip = "Every key you can rebind, including addon keybinds. An addon's keybind is copied once that addon is turned on for the account.",
        getFunc = function() return sv.what.keybinds end,
        setFunc = function(v) sv.what.keybinds = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Chat colors, text size and fade",
        tooltip = "The color of each chat channel, the chat text size and how far the chat window fades.",
        getFunc = function() return sv.what.chat end,
        setFunc = function(v) sv.what.chat = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Addon settings",
        tooltip = "The settings of the addons on this addon's list that are turned on for this account: options, colors, window positions. Their stats, logs and collected data stay as this account has them, and addons that only hold data are never touched. Ends with a UI reload. Starts turned off.",
        getFunc = function() return sv.what.addons end,
        setFunc = function(v) sv.what.addons = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Chat window, meters and quest tracker",
        tooltip = "Where the base game's chat window, frame rate and ping meters and quest tracker sit, taken from the character the snapshot was made on. Ends with a UI reload. Starts turned off.",
        getFunc = function() return sv.what.layout end,
        setFunc = function(v) sv.what.layout = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "button", name = "Undo addon copies",
        tooltip = "Puts back the addon settings and window layout this account had before it first copied the main's, then reloads the UI. They are kept for a month after that first copy.",
        isDangerous = true,
        warning = "This reloads the UI.",
        disabled = function() return AS.UndoInfo() == nil end,
        func = function() AS.Undo() end,
    }

    controls[#controls + 1] = { type = "header", name = "Character builds" }
    controls[#controls + 1] = {
        type = "checkbox", name = "Character builds",
        tooltip = "Adds a builds section to the /fas window: save a character's skill bars, champion stars and quickslots, then load them onto any character on any account. What doesn't fit is skipped.",
        getFunc = function() return sv.builds_on end,
        setFunc = function(v) sv.builds_on = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "description",
        text = "What Load build puts on the character. The same three choices sit next to the Load build button in the window.",
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Load skill bars",
        tooltip = "The five skills and the ultimate of the build's front bar and back bar.",
        disabled = function() return not sv.builds_on end,
        getFunc = function() return sv.buildParts.skills end,
        setFunc = function(v) sv.buildParts.skills = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Load champion stars",
        tooltip = "Slots the saved stars the character has unlocked. Points spent in each tree are not changed.",
        disabled = function() return not sv.builds_on end,
        getFunc = function() return sv.buildParts.cp end,
        setFunc = function(v) sv.buildParts.cp = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Load quickslots",
        tooltip = "Slots the saved potions, food and collectibles that this character carries or owns.",
        disabled = function() return not sv.builds_on end,
        getFunc = function() return sv.buildParts.quick end,
        setFunc = function(v) sv.buildParts.quick = v; AS.RefreshWindow() end,
    }

    controls[#controls + 1] = { type = "header", name = "Windows tool" }
    controls[#controls + 1] = {
        type = "description",
        text = "A separate Windows tool copies addon settings with the game closed. Use it for addons that aren't turned on " ..
               "for an account or aren't on this addon's list, and when you want a full backup first. It shows what will " ..
               "change, never copies addon data, and can undo.",
    }
    controls[#controls + 1] = {
        type = "button", name = "Get the Windows tool",
        tooltip = "Opens the download page on GitHub in your browser. The game asks before it opens.",
        func = function() RequestOpenUnsafeURL(AS.toolUrl) end,
    }
    controls[#controls + 1] = {
        type = "button", name = "Open the window",
        tooltip = "Opens the Fury's Account Sync window (/fas).",
        func = function() AS.OpenWindow() end,
    }

    LAM:RegisterOptionControls("FurysAccountSync_Settings", controls)
end

function AS.OpenSettings()
    LibAddonMenu2:OpenToPanel(panel)
end

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
        website = "https://www.esoui.com/downloads/info5106.html",
        slashCommand = "/fassettings",
        registerForRefresh = true,
    })

    local controls = {
        { type = "description",
          text = "Make your other accounts on this PC match your main one. Every account on the same PC shares this addon's " ..
                 "saved file, so the main takes a snapshot and the others copy it. Everything here starts turned off. " ..
                 "The /fas window walks you through the first setup." },
        { type = "button", name = "Open the window",
          tooltip = "Opens the Fury's Account Sync window (/fas), which shows the setup steps and what would change.",
          func = function() AS.OpenWindow() end },
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
          tooltip = "The account you're on becomes the one the others copy. You can change it later. A pop-up asks first. If another account is the main now, that account's snapshot is removed so you take a new one here.",
          disabled = function() return AS.IsMain() end,
          func = function() AS.MakeMain() end },
        { type = "checkbox", name = "Take a snapshot automatically",
          tooltip = "On the main account, saves a fresh snapshot every time you log out, reload or change zones, so it's never out of date. Greyed out on every other account. Starts turned off.",
          disabled = function() return not AS.IsMain() end,
          getFunc = function() return sv.autoSnapshot end,
          setFunc = function(v) sv.autoSnapshot = v end },
        { type = "description",
          text = function()
              if not AS.IsMain() then return "" end
              local name = AS.MainCharName()
              if not name then return "Main character: none yet. Press Take snapshot in /fas on the character the others should copy." end
              return "Main character: " .. name .. ". Automatic snapshots only come from this character. Pressing Take snapshot on another character makes that one the main character."
          end },
        { type = "checkbox", name = "Same keybinds on all this account's characters",
          tooltip = "The game keeps keybinds per character, so a key you set on one character is missing on your others. With this on, every other character on the main account takes the main character's keybinds when you log in on it, game and addon keys alike. Set your keys on the main character: a key changed on another character goes back at its next login. Greyed out on every other account (they copy with Apply). Starts turned off.",
          disabled = function() return not AS.IsMain() end,
          getFunc = function() return sv.mainKeys end,
          setFunc = function(v)
              sv.mainKeys = v
              if v and AS.IsMain() and not AS.IsMainChar() then AS.CopyKeysHere() end
          end },
        { type = "button", name = "Copy keybinds to this character",
          tooltip = "Gives the character you're on the main character's keybinds right now (also /fas keys). Only keybinds change. Greyed out on the main character and on other accounts.",
          disabled = function() return not AS.IsMain() or AS.IsMainChar() or not sv.snapshot end,
          func = function() AS.CopyKeysHere() end },

        { type = "header", name = "This account" },
        { type = "description",
          text = function()
              if not sv.main then return "Greyed out until a main account is chosen above." end
              if AS.IsMain() then return "Greyed out because this is the main account. It has nothing to copy. Log in on another account to set this there." end
              return "The same choice is the \"At login\" button in the /fas window."
          end },
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
        type = "description",
        text = "|cFF6B86Warning: copying addon settings can break an addon.|r |cFFC857Some addons keep things that belong to one account or one character in with their settings. Copy with care: check your addons after the reload, and use \"Undo addon copies\" below if one misbehaves. It puts back what the account had, for a month.|r",
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Addon settings",
        warning = "Copying addon settings can break an addon. Check your addons after the reload. \"Undo addon copies\" puts back what the account had.",
        tooltip = "The settings of the addons on this addon's list that are turned on for this account: options, colors, window positions. Their stats, logs and collected data stay as this account has them, and addons that only hold data are never touched. Ends with a UI reload. Starts turned off.",
        getFunc = function() return sv.what.addons end,
        setFunc = function(v) sv.what.addons = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "checkbox", name = "Chat window, meters, quest tracker and HUD",
        tooltip = "Where the base game's chat window, frame rate and ping meters and quest tracker sit, taken from the character the snapshot was made on, and where the HUD windows sit that you moved in the game's own HUD editor (those are kept once per account). Ends with a UI reload. Starts turned off.",
        getFunc = function() return sv.what.layout end,
        setFunc = function(v) sv.what.layout = v; AS.RefreshWindow() end,
    }
    -- One tickbox per listed addon, in a fold-out, so addon settings can be copied a few at a time.
    local pickBoxes = {
        { type = "description",
          text = "Only a small set of well-known addons is ticked to begin with. Tick more one at a time: copy, check that addon in game, then tick the next. The names are the addons' saved-data names. An addon that isn't running on this account is greyed out." },
        { type = "button", name = "Tick the starter set only",
          tooltip = "Back to how a new install starts: the small set of well-known addons ticked, everything else unticked.",
          func = function() ZO_ClearTable(sv.pick); AS.RefreshWindow() end },
        { type = "button", name = "Untick all",
          tooltip = "Unticks every addon here, so Apply copies no addon settings until you tick some.",
          func = function() for _, name in ipairs(AS.SortedCopiedNames()) do sv.pick[name] = false end; AS.RefreshWindow() end },
    }
    for _, name in ipairs(AS.SortedCopiedNames()) do
        pickBoxes[#pickBoxes + 1] = {
            type = "checkbox", name = name,
            tooltip = "Copy this addon's settings from the main when \"Addon settings\" is ticked. Greyed out while the addon isn't running on this account.",
            disabled = function() return type(_G[name]) ~= "table" end,
            getFunc = function() return AS.IsPicked(name) end,
            setFunc = function(v) AS.SetPicked(name, v); AS.RefreshWindow() end,
        }
    end
    controls[#controls + 1] = {
        type = "submenu", name = "Which addons",
        tooltip = "Pick the addons whose settings are copied, one at a time. Starts with a small well-known set.",
        controls = pickBoxes,
    }
    controls[#controls + 1] = {
        type = "description",
        text = function()
            local names = AS.UndoNames()
            if #names == 0 then return "Undo one addon: nothing has been copied on this account yet." end
            return "Undo one addon: this account can undo " .. table.concat(names, ", ") .. "."
        end,
    }
    controls[#controls + 1] = {
        type = "editbox", name = "Undo one addon",
        tooltip = "Type one of the names listed above and press Enter. After a pop-up that lets you cancel, that addon gets back the settings this account had before it copied, it is unticked, and the UI reloads. Every other addon stays copied.",
        getFunc = function() return "" end,
        setFunc = function(text) if zo_strtrim(text) ~= "" then AS.UndoOne(text) end end,
    }
    controls[#controls + 1] = { type = "header", name = "Addons that aren't on the list" }
    controls[#controls + 1] = {
        type = "description",
        text = function()
            local found = {}
            for _, name in ipairs(AS.UnlistedAddons()) do
                if not sv.extra[name] then found[#found + 1] = name end
            end
            local added = {}
            for name in pairs(sv.extra) do added[#added + 1] = name end
            table.sort(added)
            local text = "\"Addon settings\" copies the addons this addon knows. For any other addon it can't tell settings from data, so it leaves it alone. " ..
                "You can add one here by its saved-data name. Then everything it keeps for the whole account is copied, data included, " ..
                "so only add addons that hold settings. |cFF6B86This can break that addon on the account.|r \"Undo addon copies\" covers these too. Nothing is added to start with."
            if not sv.main then
                text = text .. "\n\nChoose a main account first."
            elseif #found > 0 then
                text = text .. "\n\nRunning here and not on the list: |cECEAF8" .. table.concat(found, ", ") .. "|r"
            else
                text = text .. "\n\nEvery running addon with settings for the main is on the list or added."
            end
            if #added > 0 then text = text .. "\n\nAdded by you: |c5EE6A0" .. table.concat(added, ", ") .. "|r" end
            return text
        end,
    }
    controls[#controls + 1] = {
        type = "editbox", name = "Also copy this addon",
        tooltip = "Type an addon's saved-data name exactly as listed above (capitals matter) and press Enter. Its account-wide saved data is then copied from the main with the other addon settings. Starts empty.",
        getFunc = function() return "" end,
        setFunc = function(text)
            if zo_strtrim(text) == "" then return end
            local ok, why = AS.AddExtra(text)
            if ok then AS.Msg(zo_strtrim(text) .. " is now copied with the other addon settings.") else AS.Msg(why) end
            AS.RefreshWindow()
        end,
    }
    controls[#controls + 1] = {
        type = "button", name = "Remove the ones I added",
        tooltip = "Empties your own list, so only the built-in list is copied again. Settings that were already copied stay as they are.",
        disabled = function() return next(sv.extra) == nil end,
        func = function() ZO_ClearTable(sv.extra); AS.Msg("Your added addons are removed from the copy list."); AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "button", name = "Undo addon copies",
        tooltip = "Puts back the addon settings and window layout this account had before it first copied the main's, then reloads the UI after a pop-up that lets you cancel. They are kept for a month after that first copy.",
        warning = "Asks first, then reloads the UI.",
        disabled = function() return AS.UndoInfo() == nil end,
        func = function() AS.Undo() end,
    }

    controls[#controls + 1] = { type = "header", name = "Character builds" }
    controls[#controls + 1] = {
        type = "checkbox", name = "Character builds",
        tooltip = "Adds a builds section to the /fas window: save a character's skill bars, champion stars, quickslots and gear, then load them onto any character on any account. What doesn't fit is skipped.",
        getFunc = function() return sv.builds_on end,
        setFunc = function(v) sv.builds_on = v; AS.RefreshWindow() end,
    }
    controls[#controls + 1] = {
        type = "description",
        text = "What Load build puts on the character. The same four choices sit next to the Load build button in the window.",
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
    controls[#controls + 1] = {
        type = "checkbox", name = "Load gear",
        tooltip = "Puts on the build's armor, jewelry and weapons that are in this character's bag. A piece of the same item, trait and quality counts. Starts turned off.",
        disabled = function() return not sv.builds_on end,
        getFunc = function() return sv.buildParts.gear end,
        setFunc = function(v) sv.buildParts.gear = v; AS.RefreshWindow() end,
    }

    controls[#controls + 1] = { type = "header", name = "If something goes wrong" }
    controls[#controls + 1] = {
        type = "button", name = "Make a report line",
        tooltip = "Opens the window with one line of text to copy: the addon version, what is ticked, which addons were copied and how the last copy went. Paste it into your comment on ESOUI with what went wrong. It holds no account or character names.",
        func = function() AS.ShowReportBox() end,
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

    AS.Theme.MoreOptions(controls)   -- 0.5.3: the other Fury addons, at the very end
    LAM:RegisterOptionControls("FurysAccountSync_Settings", controls)
end

function AS.OpenSettings()
    LibAddonMenu2:OpenToPanel(panel)
end

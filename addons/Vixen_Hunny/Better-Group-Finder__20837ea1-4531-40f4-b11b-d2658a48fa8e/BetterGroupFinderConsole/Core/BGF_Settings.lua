-- BGF_Settings.lua
-- LibAddonMenu-2.0 settings panel. On PC it shows under Settings > Add-ons;
-- on console LAM r40+ converts it to a LibHarvensAddonSettings page.
-- Only uses control types the console converter supports (header,
-- description, checkbox, slider, dropdown, editbox, button, divider) and
-- plain-string names, so the same table works on both.

local BGF = BetterGroupFinderConsole
local A = BGF.Activities
local L = BGF.Api.Listing

BGF.Settings = {}
local S = BGF.Settings

local IS_CONSOLE_ADDON = zo_plainstrfind(BGF.name, "Console") ~= nil

local function Changed()
    BGF:Fire("SettingsChanged")
end

-- Re-run the automatic parts of the draft after a generator setting changes.
local function Regenerate()
    if not BGF.Api:IsAvailable() then return end
    pcall(L.RefreshAuto, L)
    Changed()
end

local function Checkbox(key, name, tooltip, onChange, extra)
    local c = {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return BGF.sv[key] end,
        setFunc = function(v)
            BGF.sv[key] = v
            if onChange then onChange(v) else Changed() end
        end,
        default = BGF.defaults[key],
    }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end

local function BuildCategoryChoices()
    local names, values = {}, {}
    for _, cat in ipairs(A:GetCategories()) do
        names[#names + 1] = cat.name
        values[#values + 1] = cat.value
    end
    return names, values
end

local function BuildIntentChoices()
    local names, values, tips = {}, {}, {}
    for _, intent in ipairs(A.INTENTS) do
        local cat = A:CategoryByKey(intent.category)
        names[#names + 1] = string.format("%s: %s", cat and cat.name or intent.category, intent.name)
        values[#values + 1] = intent.id
        tips[#tips + 1] = intent.summary
    end
    return names, values, tips
end

local function BuildSortChoices()
    local names, values = {}, {}
    for i, m in ipairs(BGF.SORT_MODES) do
        names[#names + 1] = m.name
        values[#values + 1] = i
    end
    return names, values
end

function S:ResetToDefaults()
    local keep = { windowPos = BGF.sv.windowPos, pcTab = BGF.sv.pcTab }
    for k, v in pairs(BGF.defaults) do
        BGF.sv[k] = v
    end
    for k, v in pairs(keep) do BGF.sv[k] = v end
    if BGF.sv.lastCategory == nil and GROUP_FINDER_CATEGORY_DUNGEON then
        BGF.sv.lastCategory = GROUP_FINDER_CATEGORY_DUNGEON
    end
    Changed()
end

function S:Build()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelId = BGF.name .. "Settings"
    self.panelId = panelId
    local panelData = {
        type = "panel",
        name = BGF.displayName .. (IS_CONSOLE_ADDON and " (Console)" or ""),
        displayName = string.format("|c%s%s|r", BGF.color, BGF.displayName),
        author = "Vixen Hunny",
        version = BGF.version,
        slashCommand = "/bgfsettings",
        registerForRefresh = true,
        registerForDefaults = true,
        resetFunc = function() S:ResetToDefaults() end,
    }
    self.panel = LAM:RegisterAddonPanel(panelId, panelData)
    LAM:RegisterOptionControls(panelId, self:BuildOptions())
end

-- The option list (LAM format). Also rendered by the console screen's own
-- Settings page, which works where no add-on settings menu is reachable
-- (e.g. gamepad mode on PC).
function S:BuildOptions()
    local catNames, catValues = BuildCategoryChoices()
    local intentNames, intentValues, intentTips = BuildIntentChoices()
    local sortNames, sortValues = BuildSortChoices()

    local options = {
        {
            type = "description",
            title = "Better Group Finder",
            text = IS_CONSOLE_ADDON
                and "Open it from Main Menu > Better Group Finder, with R3 on the Activity Finder, or with /bgf."
                or "Open it with /bgf, the keybind under Controls, or the button on the game's Group Finder.",
        },

        {
            type = "button",
            name = "Open Better Group Finder",
            opensUI = true,
            tooltip = "Closes this menu and opens Better Group Finder.",
            func = function() S:OpenUIFromSettings() end,
            width = "half",
        },
        {
            type = "button",
            name = "Browse Groups",
            opensUI = true,
            tooltip = "Closes this menu and opens the group browser.",
            func = function() S:OpenUIFromSettings("browse") end,
            width = "half",
        },
        {
            type = "button",
            name = "Create Listing",
            opensUI = true,
            tooltip = "Closes this menu and opens Create / Edit Listing.",
            func = function() S:OpenUIFromSettings("create") end,
            width = "half",
        },
        {
            type = "button",
            name = "My Group & Applicants",
            opensUI = true,
            tooltip = "Closes this menu and opens your listing and applicants.",
            func = function() S:OpenUIFromSettings("mine") end,
            width = "half",
        },

        -- Browse --------------------------------------------------------
        { type = "header", name = "Browse & Search" },
        {
            type = "dropdown",
            name = "Default category",
            tooltip = "The category searched when you first open Browse.",
            choices = catNames,
            choicesValues = catValues,
            getFunc = function() return BGF.sv.lastCategory end,
            setFunc = function(v) BGF.sv.lastCategory = v Changed() end,
            default = GROUP_FINDER_CATEGORY_DUNGEON,
        },
        {
            type = "dropdown",
            name = "Sort results by",
            tooltip = "Best match puts groups that need your role, accept your CP and are nearly full first.",
            choices = sortNames,
            choicesValues = sortValues,
            getFunc = function() return BGF.sv.sortMode or 1 end,
            setFunc = function(v) BGF.sv.sortMode = v Changed() end,
            default = BGF.defaults.sortMode,
        },
        Checkbox("filterNeedsMyRole", "Only groups that need my role", "Hide groups with no open slot for your selected role (Any slots count)."),
        Checkbox("filterMeetsCP", "Only groups whose CP I meet", "Hide groups whose minimum CP is above yours."),
        Checkbox("filterHideFull", "Hide full groups", "Hide groups with no open slots."),
        Checkbox("filterAutoAcceptOnly", "Auto-accept groups only", "Only show groups you join instantly."),
        Checkbox("filterNoInviteCode", "Hide invite-code groups", "Hide groups that need an invite code."),
        {
            type = "editbox",
            name = "Default apply message",
            tooltip = "Sent to the leader with your applications (role, build, experience...). Leave empty to send none.",
            getFunc = function() return BGF.sv.applyMessage or "" end,
            setFunc = function(v) BGF.sv.applyMessage = v or "" Changed() end,
            isMultiline = false,
            maxChars = 200,
            default = "",
        },

        -- Create ---------------------------------------------------------
        { type = "header", name = "Create Listing" },
        {
            type = "dropdown",
            name = "Default \"What are you doing?\"",
            tooltip = "The preset used when the Create tab opens with an empty listing.",
            choices = intentNames,
            choicesValues = intentValues,
            choicesTooltips = intentTips,
            scrollable = 12,
            getFunc = function() return BGF.sv.lastIntent end,
            setFunc = function(v) BGF.sv.lastIntent = v Changed() end,
            default = BGF.defaults.lastIntent,
        },
        Checkbox("autoRoles", "Automatic roles", "Work out tanks, healers and DPS from the activity, group size and your current group.", function() Regenerate() end),
        Checkbox("autoTitle", "Automatic title", "Keep the title in sync with the activity and open roles. Typing your own title turns this off.", function() Regenerate() end),
        Checkbox("autoDescription", "Automatic description", "Write the description for you. Typing your own description turns this off.", function() Regenerate() end),
        {
            type = "editbox",
            name = "Extra notes",
            tooltip = "Added to the end of every automatic description: sets you want, parse, discord, etc.",
            getFunc = function() return BGF.sv.extraNotes or "" end,
            setFunc = function(v) BGF.sv.extraNotes = v or "" Regenerate() end,
            isMultiline = false,
            maxChars = 150,
            default = "",
        },

        -- Auto generation ------------------------------------------------
        { type = "header", name = "Auto Generation" },
        {
            type = "slider",
            name = "Trial tanks",
            tooltip = "Tanks in the automatic 12-player makeup. Trials with their own makeup (e.g. Aetherian Archive) keep it.",
            min = 1, max = 4, step = 1,
            getFunc = function() return BGF.sv.trialTanks end,
            setFunc = function(v) BGF.sv.trialTanks = v Regenerate() end,
            default = BGF.defaults.trialTanks,
        },
        {
            type = "slider",
            name = "Trial healers",
            tooltip = "Healers in the automatic 12-player makeup. The rest are DPS.",
            min = 1, max = 4, step = 1,
            getFunc = function() return BGF.sv.trialHealers end,
            setFunc = function(v) BGF.sv.trialHealers = v Regenerate() end,
            default = BGF.defaults.trialHealers,
        },
        Checkbox("titleIncludeRoles", "Title: show roles still needed", "Adds e.g. \"LF 1T 2D\" to automatic titles.", function() Regenerate() end),
        Checkbox("titleIncludeCP", "Title: show CP requirement", "Adds e.g. \"CP1500+\" to automatic titles.", function() Regenerate() end),
        Checkbox("descIncludeActivity", "Description: start with the activity", "Starts the description with e.g. \"Sunspire (Veteran)\".", function() Regenerate() end),
        Checkbox("descIncludeAd", "Description: \"Created using Better Group Finder\"",
            "Adds \"Created using Better Group Finder\" to the end of your listing description (automatic or hand-written).",
            function(on)
                if BGF.Api:IsAvailable() then
                    local desc = L:GetDescription()
                    pcall(L.SetDescription, L, on and BGF.Roles:WithAd(desc) or BGF.Roles:WithoutAd(desc))
                end
                Changed()
            end),
        {
            type = "button",
            name = "Regenerate my draft now",
            tooltip = "Re-runs the automatic roles, title and description on your current draft listing.",
            func = function() Regenerate() BGF:Print("Draft regenerated.", true) end,
            width = "half",
        },

        -- Live listing ------------------------------------------------------
        { type = "header", name = "Live Listing" },
        Checkbox("autoAdjustRoles", "Auto-adjust when group roles change",
            "When a group member changes role, joins or leaves, re-fit the roles to the makeup you were aiming for, refresh the automatic title and description, and update your posted listing.",
            function(on) if on and BGF.Api:IsAvailable() then pcall(L.Rebalance, L) end Changed() end),

        -- General ----------------------------------------------------------
        { type = "header", name = "Notifications & Interface" },
        Checkbox("alertOnApplicant", "Alert on new applicant", "Show an on-screen alert and sound when someone applies to your listing."),
        Checkbox("printResults", "Chat messages", "Print listing posted / applied / error messages in chat."),
    }

    if not IS_CONSOLE_ADDON then
        options[#options + 1] = Checkbox("showNativeButton", "Button on the game's Group Finder",
            "Show a \"Better Group Finder\" button on the game's own Group Finder window.",
            function(v)
                if BGF.SetNativeButtonShown then BGF.SetNativeButtonShown(v) end
            end, { isPCOnly = true })
        options[#options + 1] = {
            type = "button",
            name = "Reset window position",
            tooltip = "Moves the Better Group Finder window back to the centre of the screen.",
            func = function()
                BGF.sv.windowPos = nil
                local win = BetterGroupFinderWindow
                if win then
                    win:ClearAnchors()
                    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                end
            end,
            width = "half",
            isPCOnly = true,
        }
    end

    return options
end

-- The settings menu is its own scene (game menu on PC, add-on settings on
-- console). Close it back to the world first, then open our UI once the
-- scene change has finished, so the window isn't hidden behind it.
function S:OpenUIFromSettings(tab)
    if not BGF.OpenUI then return end
    if SCENE_MANAGER and SCENE_MANAGER.ShowBaseScene then
        SCENE_MANAGER:ShowBaseScene()
    end
    if zo_callLater then
        zo_callLater(function() BGF.OpenUI(tab) end, 250)
    else
        BGF.OpenUI(tab)
    end
end

function S:Open()
    local LAM = LibAddonMenu2
    if LAM and self.panel and LAM.OpenToPanel then
        LAM:OpenToPanel(self.panel)
        return true
    end
    return false
end

BGF:OnInitialize(function()
    local ok, err = pcall(S.Build, S)
    if not ok then BGF:Print("Settings panel error: " .. tostring(err), true) end
end)

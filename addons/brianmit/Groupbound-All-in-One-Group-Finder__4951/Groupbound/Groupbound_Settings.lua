-- Groupbound_Settings.lua : settings page (LibAddonMenu-2.0, optional). The board's chips (what
-- to show, where from) live in the window itself.

local G = Groupbound
local L = G.L
local Content = G.Content

local panelId = "GroupboundSettings"
local panel

function G.OpenSettings()
    local LAM = LibAddonMenu2
    if LAM and panel then
        if G.UI.IsShown() then G.UI.Hide() end
        LAM:OpenToPanel(panel)
    else
        G.Print(L("NO_LAM"))
    end
end

local function Changed()
    G.callbacks:FireCallbacks("SettingsChanged")
end

local function WatchList()
    local names = {}
    for key in pairs(G.sv.watches) do
        if Content.Get(key) then names[#names + 1] = Content.Name(key) end
    end
    table.sort(names)
    if #names == 0 then return L("SET_WATCHES_NONE") end
    return table.concat(names, ", ")
end

local function HiddenCount()
    local n = 0
    for _, note in pairs(G.sv.notes) do
        if note.hidden then n = n + 1 end
    end
    return n
end

-- "I read German" (for the board's "Only languages I read")
local function LangBox(lang)
    return { type = "checkbox", name = L("SET_LANG_READ", L("LANG_" .. zo_strupper(lang))),
        getFunc = function() return G.sv.langs[lang] == true end,
        setFunc = function(v)
            G.sv.langs[lang] = v or nil
            Changed()
        end }
end

-- which Group Finder categories are searched (the tooltips say what's in each)
local function CatBox(kind, key)
    return { type = "checkbox", name = L(key), tooltip = L(key .. "_TT"),
        getFunc = function() return G.sv.cats[kind] == true end,
        setFunc = function(v)
            G.sv.cats[kind] = v
            Changed()
        end, default = true }
end

function G.InitSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    panel = LAM:RegisterAddonPanel(panelId, {
        type = "panel",
        name = L("TITLE"),
        displayName = G.Colorize(G.COLOR.theme, L("TITLE")),
        author = "|c00C8FFbrianmit|r",
        version = G.VERSION,
        registerForRefresh = true,
    })
    local sv = G.sv
    -- simplified 2026-10-14 (user: "only what's useful, not a long list"): the everyday options up
    -- front, everything else folded into "More options" (the defaults are fine for most players).
    local more = {
        { type = "slider", name = L("SET_CHAT_MINUTES"), tooltip = L("SET_CHAT_MINUTES_TT"), min = 5, max = 60, step = 5,
          getFunc = function() return sv.chatMinutes end, setFunc = function(v) sv.chatMinutes = v Changed() end, default = 15 },
        { type = "checkbox", name = L("SET_ASK_MSG"), tooltip = L("SET_ASK_MSG_TT"),
          getFunc = function() return sv.askApplyMsg end, setFunc = function(v) sv.askApplyMsg = v end, default = true },
        { type = "checkbox", name = L("SET_ROLE_WATCH"), tooltip = L("SET_ROLE_WATCH_TT"),
          getFunc = function() return sv.roleWatch end, setFunc = function(v) sv.roleWatch = v end, default = true },
        { type = "checkbox", name = L("SET_BACKGROUND"), tooltip = L("SET_BACKGROUND_TT"),
          getFunc = function() return sv.background end, setFunc = function(v) sv.background = v end, default = true },
        { type = "checkbox", name = L("SET_ALL_LISTINGS"), tooltip = L("SET_ALL_LISTINGS_TT"),
          getFunc = function() return sv.allListings end, setFunc = function(v) sv.allListings = v end, default = true },
        { type = "checkbox", name = L("SET_COMBAT_HIDE"),
          getFunc = function() return sv.launcher.combatHide end, setFunc = function(v) sv.launcher.combatHide = v Changed() end, default = true },
        { type = "dropdown", name = L("SET_ANIM"),
          choices = { L("ANIM_FULL"), L("ANIM_SUBTLE"), L("ANIM_OFF") }, choicesValues = { "full", "subtle", "off" },
          getFunc = function() return sv.anim end, setFunc = function(v) sv.anim = v end, default = "full" },

        { type = "header", name = L("SET_HEAD_LANGS") },
        { type = "description", text = L("SET_LANGS_INTRO") },
        LangBox("en"), LangBox("de"), LangBox("fr"), LangBox("es"),

        { type = "header", name = L("SET_HEAD_CATS") },
        { type = "description", text = L("SET_CATS_INTRO") },
        CatBox("trial", "CHIP_TRIALS"), CatBox("dungeon", "CHIP_DUNGEONS"), CatBox("arena", "CHIP_ARENAS"),
        CatBox("other", "CHIP_OTHER"),

        { type = "divider" },
        { type = "button", name = L("SET_UNHIDE"), tooltip = function() return L("SET_UNHIDE_TT", HiddenCount()) end, func = function()
            for account, note in pairs(sv.notes) do
                note.hidden = nil
                G.TidyNote(account)
            end
            Changed()
        end },
        { type = "button", name = L("SET_CLEAR_WATCHES"), func = function()
            ZO_ClearTable(sv.watches)
            Changed()
        end },
    }
    LAM:RegisterOptionControls(panelId, {
        { type = "header", name = L("SET_HEAD_BOARD") },
        { type = "checkbox", name = L("SET_HIDE_SALES"), tooltip = L("SET_HIDE_SALES_TT"),
          getFunc = function() return sv.hideSales end, setFunc = function(v) sv.hideSales = v Changed() end, default = true },
        { type = "editbox", name = L("SET_BLOCK_WORDS"), tooltip = L("SET_BLOCK_WORDS_TT"), isMultiline = false,
          getFunc = function() return sv.blockWords or "" end, setFunc = function(v) sv.blockWords = v or "" Changed() end, default = "" },

        { type = "header", name = L("SET_HEAD_ALERTS") },
        { type = "description", text = function() return L("SET_WATCHES", WatchList()) end },
        { type = "checkbox", name = L("SET_ALERT_ALL"), tooltip = L("SET_ALERT_ALL_TT"),
          getFunc = function() return sv.alertAll end, setFunc = function(v) sv.alertAll = v end, default = false },
        { type = "checkbox", name = L("SET_TOAST"), tooltip = L("SET_TOAST_TT"),
          getFunc = function() return sv.toast end, setFunc = function(v) sv.toast = v end, default = true },
        { type = "checkbox", name = L("SET_SOUND"),
          getFunc = function() return sv.sound end, setFunc = function(v) sv.sound = v end, default = true },

        { type = "header", name = L("SET_HEAD_SCREEN") },
        { type = "checkbox", name = L("SET_LAUNCHER"),
          getFunc = function() return not sv.launcher.hidden end, setFunc = function(v) sv.launcher.hidden = not v Changed() end, default = true },
        { type = "checkbox", name = L("SET_HUD"), tooltip = L("SET_HUD_TT"),
          getFunc = function() return sv.hud.shown end, setFunc = function(v) sv.hud.shown = v Changed() end, default = false },
        { type = "checkbox", name = L("SET_QUIET"), tooltip = L("SET_QUIET_TT"),
          getFunc = function() return sv.quietInside end, setFunc = function(v) sv.quietInside = v Changed() end, default = true },
        { type = "button", name = L("SET_RESET"), tooltip = L("SET_RESET_TT"), func = function()
            sv.launcher.x, sv.launcher.y = nil, nil
            sv.window.x, sv.window.y = nil, nil
            sv.hud.x, sv.hud.y = nil, nil
            G.callbacks:FireCallbacks("PositionsReset")
        end },

        { type = "submenu", name = L("SET_HEAD_MORE"), controls = more },
    })
end

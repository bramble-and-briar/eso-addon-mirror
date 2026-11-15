-- Editor pages: Library, Recorder, Ability search, Profiles, Settings.

local DT = DebuffTracker
local UI = DT.UI
local W = UI.W
local U = DT.Util
local C = DT.Const
local P = DT.Profiles
local L = DT.L
local WM = WINDOW_MANAGER

-- The description wraps inside the page (long ones get a second line instead of running off the
-- window) and its height follows the text, so the page content below never overlaps it.
local function PageTitle(parent, text, sub, width)
    local t = W.Label(parent, text, "$(BOLD_FONT)|20|soft-shadow-thick", C.GOLD)
    t:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    local s = W.Label(parent, sub or "", "ZoFontGame", { 0.7, 0.7, 0.7, 1 })
    s:SetAnchor(TOPLEFT, t, BOTTOMLEFT, 0, 2)
    width = (width and width > 0) and width or parent:GetWidth()
    if width and width > 0 then
        s:SetVerticalAlignment(TEXT_ALIGN_TOP)
        s:SetDimensions(width, W.TextHeight(sub or "", width, "game", s))
    end
    return t, s
end

local function ScrollBelow(parent, anchor, offsetY, bottomOffset)
    local scroll = W.ScrollContainer(W.UniqueName("PageScroll"), parent)
    scroll:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, offsetY or 10)
    scroll:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, bottomOffset or 0)
    return scroll, scroll:GetNamedChild("ScrollChild")
end

------------------------------------------------------------------------------
-- Library
------------------------------------------------------------------------------

-- Cooldowns addon -> DebuffTracker (Systems/Migration.lua)
function UI.ImportCooldownsFlow()
    local added, summary = DT.Migration.ImportCooldowns()
    if not added then UI.Message(L("Import from Cooldowns"), summary) return end
    UI.selectedId = added[1] and added[1].id
    local body = L("Added one \"My procs\" tracker where your Cooldowns procs were (<<1>> synergies / passives / champion skills picked, <<2>> switched off), plus <<3>> own tracker(s) for procs you use that sat somewhere else. You can disable Cooldowns now.",
        summary.picked, summary.hidden, summary.own)
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous Cooldowns import.", summary.replaced) end
    UI.Message(L("Imported from Cooldowns"), body)
    UI.Refresh()
end

-- Untaunted addon -> DebuffTracker (Systems/Migration.lua)
function UI.ImportUntauntedFlow()
    local added, summary = DT.Migration.ImportUntaunted()
    if not added then UI.Message(L("Import from Untaunted"), summary) return end
    UI.selectedId = added[1] and added[1].id
    local body = L("Added a \"Taunts (Untaunted)\" tracker with your <<1>> abilities, window size, bar count, directions and position. Like Untaunted, a taunt that ended (or that someone else took) stays on its row until 5 seconds after it would have run out, and an enemy that dies is removed at once.", summary.abilities)
    if summary.marker then body = body .. "\n" .. L("Your red arrow over enemies is switched on here too; it starts once Untaunted is disabled (two add-ons setting it can crash the game).") end
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous Untaunted import.", summary.replaced) end
    UI.Message(L("Imported from Untaunted"), body .. "\n" .. L("You can disable Untaunted now."))
    UI.Refresh()
end

-- BuffTheGroup -> DebuffTracker (Systems/Migration.lua)
function UI.ImportBTGFlow()
    local added, summary = DT.Migration.ImportBTG()
    if not added then UI.Message(L("Import from BuffTheGroup"), summary) return end
    UI.selectedId = added[1] and added[1].id
    local body = L("Added <<1>> tracker(s), one per buff BuffTheGroup tracked, where its windows were: every group member listed with role and account name, coloured while they have the buff and grey when they don't, in group dungeons, arenas and trials.", summary.buffs)
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous BuffTheGroup import.", summary.replaced) end
    UI.Message(L("Imported from BuffTheGroup"), body .. "\n" .. L("You can disable BuffTheGroup now."))
    UI.Refresh()
end

-- StaggerTracker -> DebuffTracker (Systems/Migration.lua)
function UI.ImportStaggerFlow()
    local added, summary = DT.Migration.ImportStagger()
    if not added then UI.Message(L("Import from StaggerTracker"), summary) return end
    UI.selectedId = added[1] and added[1].id
    local body = L("Added a \"Heat Shock (Magma Fist)\" icon: your Heat Shock with its time and stacks, the frame red / orange / yellow / green for 0-3 stacks. In combat, on a Dragonknight with Magma Fist on a bar. (Since Update 49 Stone Giant is Magma Fist and applies Heat Shock instead of Stagger -- StaggerTracker itself still looks for Stagger.)")
    if summary.placed then body = body .. "\n" .. L("It sits where StaggerTracker's icon was.") end
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous StaggerTracker import.", summary.replaced) end
    UI.Message(L("Imported from StaggerTracker"), body .. "\n" .. L("You can disable StaggerTracker now."))
    UI.Refresh()
end

-- ExoY's ProcSet Timer -> DebuffTracker (Systems/Migration.lua)
function UI.ImportExoYFlow()
    local added, summary = DT.Migration.ImportExoY()
    if not added then UI.Message(L("Import from ExoY's ProcSet Timer"), summary) return end
    UI.selectedId = added[1] and added[1].id
    local body = L("Added a \"My procs (ExoY)\" tracker where most of your ExoY icons were, plus <<1>> own tracker(s) for worn sets you had placed elsewhere: buff times from the game, the frame and the time green while active and red on cooldown, your icon size, font, edge and filters.", summary.own)
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous ExoY import.", summary.replaced) end
    UI.Message(L("Imported from ExoY's ProcSet Timer"), body .. "\n" .. L("You can disable ExoY's ProcSet Timer now."))
    UI.Refresh()
end

-- Meterskull -> DebuffTracker (Systems/Migration.lua)
function UI.ImportMeterskullFlow()
    local added, summary = DT.Migration.ImportMeterskull()
    if not added then UI.Message(L("Import from Meterskull"), summary) return end
    UI.selectedId = added[1] and added[1].id or UI.selectedId
    local body = L("Added <<1>> number tiles (Meter display) where your Meterskull meters were: <<2>> shown, the meters you had off are added switched off. Sizes, background, border and text transparency, your colour thresholds (as Text color rules), the number animation and \"only in combat\" came along.", summary.trackers, summary.shown)
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous Meterskull import.", summary.replaced) end
    UI.Message(L("Imported from Meterskull"), body .. "\n" .. L("You can disable Meterskull now."))
    UI.Refresh()
end

-- Miat's Ticks Tracker -> DebuffTracker (Systems/Migration.lua)
function UI.ImportMiatFlow()
    local added, summary = DT.Migration.ImportMiat()
    if not added then UI.Message(L("Import from Miat's Ticks Tracker"), summary) return end
    UI.selectedId = added[1] and added[1].id or UI.selectedId
    local body = L("Added a \"Resource tick\" bar where yours was, with your colours, thresholds, dodge fatigue, sound and size.")
    if summary.attached then body = body .. "\n" .. L("Yours was attached to the game's resource bar; ours is its own bar -- drag it there (Move).") end
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous import.", summary.replaced) end
    UI.Message(L("Imported from Miat's Ticks Tracker"), body .. "\n" .. L("You can disable Miat's Ticks Tracker now."))
    UI.Refresh()
end

-- Combat Metronome / GCD Bar / Global Cooldown Monitor -> DebuffTracker (Systems/Migration.lua)
function UI.ImportGcdFlow()
    local added, summary = DT.Migration.ImportGcd()
    if not added then UI.Message(L("Import a global cooldown bar"), summary) return end
    UI.selectedId = added[1] and added[1].id or UI.selectedId
    local body = L("Added <<1>> \"Global cooldown\" tracker(s) from <<2>> where yours were, with your sizes, colours, ping, adjustments and sounds.", #added, summary.from)
    if summary.replaced > 0 then body = body .. "\n" .. L("Replaced <<1>> tracker(s) from your previous import.", summary.replaced) end
    UI.Message(L("Imported"), body .. "\n" .. L("You can disable the old addon now."))
    UI.Refresh()
end

-- The addons DebuffTracker can replace, as one table (Settings): what each becomes, whether it's enabled now,
-- how many trackers its import added, Import / Remove. (Yarden: the import / remove buttons had become "a MASSIVE
-- pile of buttons".)
local function ImportRows()
    local M = DT.Migration
    return {
        { "Cooldowns", L("My procs"), M.FindCooldowns, UI.ImportCooldownsFlow, M.RemoveCooldownsImport, "fromCooldowns", "/dt cooldowns" },
        { "Untaunted", L("Taunts on every enemy"), M.FindUntaunted, UI.ImportUntauntedFlow, M.RemoveUntauntedImport, "fromUntaunted", "/dt untaunted" },
        { "BuffTheGroup", L("Group buff boards"), M.FindBTG, UI.ImportBTGFlow, M.RemoveBTGImport, "fromBTG", "/dt btg" },
        { "StaggerTracker", L("Heat Shock icon (Magma Fist)"), M.FindStagger, UI.ImportStaggerFlow, M.RemoveStaggerImport, "fromStagger", "/dt stagger" },
        { "ExoY's ProcSet Timer", L("My procs (ExoY)"), M.FindExoY, UI.ImportExoYFlow, M.RemoveExoYImport, "fromExoY", "/dt exoy" },
        { "Meterskull", L("Stat number tiles"), M.FindMeterskull, UI.ImportMeterskullFlow, M.RemoveMeterskullImport, "fromMeterskull", "/dt meterskull" },
        { "Miat's Ticks Tracker", L("Resource tick bar"), M.FindMiat, UI.ImportMiatFlow, M.RemoveMiatImport, "fromMiat", "/dt miat" },
        { "Combat Metronome, GCD Bar, GCD Monitor", L("Global cooldown bar"), M.FindGcdAddons, UI.ImportGcdFlow, M.RemoveGcdImport, "fromGcd", "/dt gcd" },
    }
end

local function ImportTable(parent, width)
    local rows = ImportRows()
    local HEAD_H, ROW_H = 24, 40
    local box = WM:CreateControl(nil, parent, CT_CONTROL)
    local height = HEAD_H + #rows * ROW_H
    box:SetDimensions(width, height)
    local btnW = 78
    local colName = math.floor(width * 0.36)
    local colWhat = math.floor(width * 0.24)
    local colStatus = width - colName - colWhat - 2 * btnW - 24
    local function Head(text, x, w)
        local l = W.Label(box, text, "ZoFontGameSmall", C.GOLD)
        l:SetAnchor(TOPLEFT, box, TOPLEFT, x, 2)
        l:SetDimensions(w, HEAD_H - 4)
    end
    Head(L("Addon"), 10, colName)
    Head(L("Becomes"), 10 + colName, colWhat)
    Head(L("Status"), 10 + colName + colWhat, colStatus)
    local refreshers = {}
    for i, r in ipairs(rows) do
        local name, what, find, flow, remove, flag, cmd = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
        local y = HEAD_H + (i - 1) * ROW_H
        local bg = W.Backdrop(box, i % 2 == 1 and { 0.10, 0.11, 0.13, 0.9 } or { 0.07, 0.08, 0.09, 0.9 }, { 0.22, 0.24, 0.27, 1 }, 1)
        bg:SetAnchor(TOPLEFT, box, TOPLEFT, 0, y)
        bg:SetDimensions(width, ROW_H - 4)
        local n = W.Label(box, name, "ZoFontGameBold", { 0.95, 0.92, 0.85, 1 })
        n:SetAnchor(LEFT, bg, LEFT, 10, 0)
        n:SetDimensions(colName - 12, ROW_H - 4)
        n:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local w2 = W.Label(box, what, "ZoFontGameSmall", { 0.75, 0.78, 0.82, 1 })
        w2:SetAnchor(LEFT, bg, LEFT, 10 + colName, 0)
        w2:SetDimensions(colWhat - 8, ROW_H - 4)
        w2:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local st = W.Label(box, "", "ZoFontGameSmall")
        st:SetAnchor(LEFT, bg, LEFT, 10 + colName + colWhat, 0)
        st:SetDimensions(colStatus - 6, ROW_H - 4)
        local count = 0
        local rem = W.FlatButton(box, btnW, 26, L("Remove"), function()
            if count == 0 then return end
            UI.Confirm(L("Remove the <<1>> import", name), L("Delete every tracker the <<1>> import added to \"<<2>>\"?", name, P.ActiveName()), function()
                local k = remove()
                UI.selectedId = nil
                UI.Message(L("Removed"), L("Deleted <<1>> tracker(s).", k))
                UI.Refresh()
            end)
        end, L("Delete the trackers this import added (your own copies stay)."), { 1, 0.55, 0.5, 1 })
        rem:SetAnchor(RIGHT, bg, RIGHT, -8, 0)
        local imp = W.FlatButton(box, btnW, 26, L("Import"), function() flow() end,
            L("Brings <<1>>'s setup over (<<2>>). It must be enabled, just for the import; importing again replaces the previous import.", name, cmd), C.GOLD)
        imp:SetAnchor(RIGHT, rem, LEFT, -6, 0)
        refreshers[#refreshers + 1] = function()
            local ok, found = pcall(find)
            local installed = ok and found ~= nil
            count = 0
            for _, t in ipairs(P.ActiveTrackers()) do if t[flag] then count = count + 1 end end
            if count > 0 then
                st:SetText(L("<<1>> imported", count)); st:SetColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
            elseif installed then
                st:SetText(L("Ready to import")); st:SetColor(0.45, 0.85, 0.5, 1)
            else
                st:SetText(L("Not enabled")); st:SetColor(0.55, 0.57, 0.6, 1)
            end
            imp:SetAlpha(installed and 1 or 0.45)
            rem:SetAlpha(count > 0 and 1 or 0.35)
        end
    end
    local function Refresh() for _, f in ipairs(refreshers) do f() end end
    W.Register(Refresh, "addon imports")
    Refresh()
    box.rows = #rows
    return box, height
end
UI.ImportTable = ImportTable

function UI.BuildLibraryPage(page, control, width)
    local _, sub = PageTitle(control, L("Library"), L("Ready-made trackers. Add one, then tweak it on the Trackers page."), width)
    local _, content = ScrollBelow(control, sub, 12)
    local cardW = (width - 30) / 2
    local cardH = 118
    local top = 0
    if DT.Migration.FindCooldowns() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)
        local text = W.Label(banner, L("Cooldowns is installed: bring its procs, positions, colours and sounds over."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from Cooldowns"), UI.ImportCooldownsFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = 52
    end
    if DT.Migration.FindUntaunted() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, top)
        local text = W.Label(banner, L("Untaunted is installed: bring its abilities, window and settings over."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from Untaunted"), UI.ImportUntauntedFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = top + 52
    end
    if DT.Migration.FindBTG() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, top)
        local text = W.Label(banner, L("BuffTheGroup is installed: bring its buff windows over."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from BuffTheGroup"), UI.ImportBTGFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = top + 52
    end
    if DT.Migration.FindStagger() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, top)
        local text = W.Label(banner, L("StaggerTracker is installed: bring its Stagger icon over."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from StaggerTracker"), UI.ImportStaggerFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = top + 52
    end
    if DT.Migration.FindExoY() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, top)
        local text = W.Label(banner, L("ExoY's ProcSet Timer is installed: bring its proc icons over."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from ExoY"), UI.ImportExoYFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = top + 52
    end
    if DT.Migration.FindMeterskull() then
        local banner = W.Backdrop(content, C.GOLD_BG, C.GOLD_DIM, 1)
        banner:SetDimensions(width - 18, 40)
        banner:SetAnchor(TOPLEFT, content, TOPLEFT, 0, top)
        local text = W.Label(banner, L("Meterskull is installed: bring its meters over as number tiles."), "ZoFontGame", { 0.95, 0.92, 0.85, 1 })
        text:SetAnchor(LEFT, banner, LEFT, 12, 0)
        text:SetDimensions(width - 240, 24)
        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local btn = W.FlatButton(banner, 190, 28, L("Import from Meterskull"), UI.ImportMeterskullFlow, nil, C.GOLD)
        btn:SetAnchor(RIGHT, banner, RIGHT, -8, 0)
        top = top + 52
    end
    local cards = {}
    for i, preset in ipairs(DT.Presets.LIST) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local card = W.Backdrop(content, { 0.09, 0.1, 0.12, 0.95 }, { 0.25, 0.27, 0.3, 1 }, 1)
        card:SetDimensions(cardW, cardH)
        card:SetAnchor(TOPLEFT, content, TOPLEFT, col * (cardW + 12), top + row * (cardH + 12))
        local frame = W.Backdrop(card, C.GOLD_BG, C.GOLD_DIM, 1)
        frame:SetDimensions(44, 44)
        frame:SetAnchor(TOPLEFT, card, TOPLEFT, 10, 10)
        local icon = W.Texture(frame, preset.icon and GetAbilityIcon(preset.icon) or C.DEFAULT_ICON, 40, 40)
        icon:SetAnchor(CENTER, frame, CENTER, 0, 0)
        local name = W.Label(card, preset.name, "$(BOLD_FONT)|16|soft-shadow-thin", { 0.95, 0.92, 0.85, 1 })
        name:SetAnchor(TOPLEFT, frame, TOPRIGHT, 10, 0)
        name:SetDimensions(cardW - 170, 22)
        name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local cat = W.Label(card, preset.category, "ZoFontGameSmall", { 0.62, 0.88, 0.80, 1 })
        cat:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 0, 0)
        local desc = W.Label(card, preset.description, "ZoFontGameSmall", { 0.72, 0.72, 0.72, 1 })
        desc:SetAnchor(TOPLEFT, frame, BOTTOMLEFT, 0, 8)
        desc:SetDimensions(cardW - 20, 48)
        desc:SetVerticalAlignment(TEXT_ALIGN_TOP)
        desc:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local add = W.FlatButton(card, 90, 28, L("Add"), function()
            local added = DT.Presets.Add(preset.key)
            if added and added[1] then
                UI.selectedId = added[1].id
                U.Print(L("Added \"<<1>>\".", preset.name))
                UI.SelectPage(1)
            end
        end, L("Add to the current profile"), C.GOLD)
        add:SetAnchor(TOPRIGHT, card, TOPRIGHT, -10, 10)
        cards[i] = card
    end
    content:SetHeight(top + math.ceil(#DT.Presets.LIST / 2) * (cardH + 12) + 20)
end

------------------------------------------------------------------------------
-- Recorder
------------------------------------------------------------------------------

function UI.BuildRecorderPage(page, control, width)
    local _, sub = PageTitle(control, L("Effect recorder"),
        L("Records buffs and debuffs around you, every ability you use and everything that hits you -- with IDs, results and amounts. Fight something, then click Track."), width)
    local bar = WM:CreateControl(nil, control, CT_CONTROL)
    bar:SetDimensions(width, 32)
    bar:SetAnchor(TOPLEFT, sub, BOTTOMLEFT, 0, 10)
    local startBtn = W.FlatButton(bar, 130, 30, "", function()
        if DT.Recorder.active then DT.Recorder.Stop() else DT.Recorder.Start() end
        page.OnRefresh()
    end)
    startBtn:SetAnchor(LEFT, bar, LEFT, 0, 0)
    local clear = W.FlatButton(bar, 70, 30, L("Clear"), function() DT.Recorder.Clear(); page.OnRefresh() end)
    clear:SetAnchor(LEFT, startBtn, RIGHT, 6, 0)
    local snap = W.FlatButton(bar, 120, 30, L("What's on it?"), function()
        local n, who = DT.Recorder.Snapshot()
        U.Print(L("<<1>> effects on <<2>> added to the list.", n, who))
        page.OnRefresh()
    end, L("Add every effect currently on your target (or on you, with no target) to the list"))
    snap:SetAnchor(LEFT, clear, RIGHT, 6, 0)
    local filter = ""
    local kind = "all"
    local edit = W.Edit(bar, 170, nil, function() return filter end, nil, nil,
        { noRefresh = true, placeholder = L("Filter: name, ID, unit"), onChange = function(v) filter = v; page.OnRefresh() end })
    edit:SetAnchor(LEFT, snap, RIGHT, 10, 0)
    local kinds = W.Segmented(bar, width - 130 - 70 - 120 - 170 - 40, nil, { { "all", L("All") }, { "effect", L("Effects") }, { "cast", L("My skills") }, { "incoming", L("On me") }, { "mine", L("Mine") } },
        function() return kind end, function(v) kind = v; page.OnRefresh() end)
    kinds:SetAnchor(LEFT, edit, RIGHT, 12, 0)

    local _, content = ScrollBelow(control, bar, 10)
    local list = W.NewList(content, width - 20, 36, function(p)
        local r = {}
        r.control = W.Backdrop(p, { 0.09, 0.1, 0.11, 0.9 }, { 0.2, 0.22, 0.25, 1 }, 1)
        r.control:SetDimensions(width - 20, 32)
        r.icon = W.Texture(r.control, nil, 26, 26)
        r.icon:SetAnchor(LEFT, r.control, LEFT, 4, 0)
        r.name = W.Label(r.control, "", "ZoFontGame")
        r.name:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
        r.name:SetDimensions(260, 26)
        r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.info = W.Label(r.control, "", "ZoFontGameSmall", { 0.65, 0.65, 0.65, 1 })
        r.info:SetAnchor(LEFT, r.name, RIGHT, 8, 0)
        r.info:SetDimensions(width - 560, 26)
        r.info:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.track = W.FlatButton(r.control, 80, 26, L("Track"), function()
            if not r.entry then return end
            local t = P.AddTracker(DT.Recorder.TrackerFor(r.entry))
            UI.selectedId = t.id
            UI.SelectPage(1)
        end, L("Create a new tracker for this"), C.GOLD)
        r.track:SetAnchor(RIGHT, r.control, RIGHT, -4, 0)
        r.add = W.FlatButton(r.control, 110, 26, L("Add to selected"), function()
            if r.entry and UI.AddAbilityToCurrent and UI.AddAbilityToCurrent(r.entry.abilityId) then
                U.Print(L("Added <<1>> to the selected tracker.", r.entry.abilityId))
            end
        end, L("Add this ability ID to the tracker selected on the Trackers page"))
        r.add:SetAnchor(RIGHT, r.track, LEFT, -6, 0)
        return r
    end)
    list.control:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)

    local SCOPE_LABEL = { enemies = L("enemy"), target = L("target"), boss = L("boss"), player = L("you"), group = L("group"), companion = L("companion"), combat = L("used"), onme = L("on you") }
    function page.OnRefresh()
        startBtn.label:SetText(DT.Recorder.active and L("Stop recording") or L("Start recording"))
        startBtn.bg:SetCenterColor(DT.Recorder.active and 0.45 or 0.12, DT.Recorder.active and 0.12 or 0.13, DT.Recorder.active and 0.12 or 0.15, 1)
        local entries = DT.Recorder.Filtered(filter, kind)
        local shown = {}
        for i = 1, math.min(#entries, 120) do shown[i] = entries[i] end
        list:Set(shown, function(r, e)
            r.entry = e
            r.icon:SetTexture(e.icon)
            r.name:SetText(string.format("%s  |c888888%d|r", e.name, e.abilityId))
            local parts = { SCOPE_LABEL[e.scope] or e.scope }
            if e.unitName ~= "" then parts[#parts + 1] = e.unitName end
            if e.kind == "effect" then
                parts[#parts + 1] = e.source == "me" and L("by you") or L("by others")
                if e.duration > 0 then parts[#parts + 1] = string.format("%.1fs", e.duration) end
                if e.effectType == BUFF_EFFECT_TYPE_DEBUFF then parts[#parts + 1] = L("debuff") elseif e.effectType == BUFF_EFFECT_TYPE_BUFF then parts[#parts + 1] = L("buff") end
            end
            if e.result then
                parts[#parts + 1] = DT.Recorder.ResultName(e.result)
                if (e.hitValue or 0) > 0 then parts[#parts + 1] = tostring(e.hitValue) end
            end
            if e.count > 1 then parts[#parts + 1] = "x" .. e.count end
            r.info:SetText(table.concat(parts, "  |  "))
        end)
        content:SetHeight(list:Height() + 20)
    end
    DT.Recorder.listeners[#DT.Recorder.listeners + 1] = function()
        if not control:IsHidden() then page.OnRefresh() end
    end
end

------------------------------------------------------------------------------
-- Ability search
------------------------------------------------------------------------------

function UI.BuildSearchPage(page, control, width)
    local _, sub = PageTitle(control, L("Ability search"), L("Find any ability by name or ID. The first name search builds an index (a few seconds, no lag)."), width)
    local query = ""
    local results = {}
    local edit = W.Edit(control, 360, nil, function() return query end, nil, L("Name or ID"),
        { noRefresh = true, onChange = function(v) query = v; page.Search() end })
    edit:SetAnchor(TOPLEFT, sub, BOTTOMLEFT, 0, 10)
    local status = W.Label(control, "", "ZoFontGameSmall", { 0.62, 0.88, 0.80, 1 })
    status:SetAnchor(LEFT, edit, RIGHT, 12, 0)
    local _, content = ScrollBelow(control, edit, 10)
    local list = W.NewList(content, width - 20, 36, function(p)
        local r = {}
        r.control = W.Backdrop(p, { 0.09, 0.1, 0.11, 0.9 }, { 0.2, 0.22, 0.25, 1 }, 1)
        r.control:SetDimensions(width - 20, 32)
        r.icon = W.Texture(r.control, nil, 26, 26)
        r.icon:SetAnchor(LEFT, r.control, LEFT, 4, 0)
        r.name = W.Label(r.control, "", "ZoFontGame")
        r.name:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
        r.name:SetDimensions(width - 340, 26)
        r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.new = W.FlatButton(r.control, 100, 26, L("New tracker"), function()
            if not r.result then return end
            local t = P.AddTracker({ name = r.result.name, trigger = { type = "effect", abilityIds = { r.result.id }, scope = "enemies" } })
            UI.selectedId = t.id
            UI.SelectPage(1)
        end, nil, C.GOLD)
        r.new:SetAnchor(RIGHT, r.control, RIGHT, -4, 0)
        r.add = W.FlatButton(r.control, 110, 26, L("Add to selected"), function()
            if r.result and UI.AddAbilityToCurrent and UI.AddAbilityToCurrent(r.result.id) then
                U.Print(L("Added <<1>> to the selected tracker.", r.result.id))
            end
        end)
        r.add:SetAnchor(RIGHT, r.new, LEFT, -6, 0)
        return r
    end)
    list.control:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)

    local function Render()
        list:Set(results, function(r, res)
            r.result = res
            r.icon:SetTexture(res.icon)
            local dur = res.duration > 0 and string.format("  |c888888%.1fs|r", res.duration) or ""
            r.name:SetText(string.format("%s  |c888888%d|r%s", res.name, res.id, dur))
        end)
        content:SetHeight(list:Height() + 20)
    end

    function page.Search()
        local AS = DT.AbilitySearch
        if U.Trim(query) ~= "" and not tonumber(query) and AS.state == "idle" then AS.Build() end
        results = AS.Search(query, 80)
        if AS.state == "building" then
            status:SetText(L("Building index... <<1>>%", math.floor(AS.progress * 100)))
        else
            status:SetText(#results > 0 and L("<<1>> results", #results) or "")
        end
        Render()
    end
    DT.AbilitySearch.OnProgress(function(state)
        if control:IsHidden() then return end
        if state == "ready" or math.floor(DT.AbilitySearch.progress * 100) % 10 == 0 then page.Search() end
    end)
    function page.OnRefresh() end
end

------------------------------------------------------------------------------
-- Profiles
------------------------------------------------------------------------------

function UI.BuildProfilesPage(page, control, width)
    local _, sub = PageTitle(control, L("Profiles"), L("Separate sets of trackers. Switch by hand or let rules switch for you."), width)
    local panel = W.NewPanel(control, width - 20)
    panel.scroll:SetAnchor(TOPLEFT, sub, BOTTOMLEFT, 0, 10)
    panel.scroll:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    local w = width - 30

    local list = W.NewList(panel.content, w, 40, function(p)
        local r = {}
        r.control = W.Backdrop(p, { 0.09, 0.1, 0.11, 0.9 }, { 0.2, 0.22, 0.25, 1 }, 1)
        r.control:SetDimensions(w, 36)
        r.name = W.Label(r.control, "", "ZoFontGame")
        r.name:SetAnchor(LEFT, r.control, LEFT, 10, 0)
        r.name:SetDimensions(w - 520, 30)
        r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local function B(label, fn, color)
            local b = W.FlatButton(r.control, 90, 26, label, fn, nil, color)
            return b
        end
        r.delete = B(L("Delete"), function()
            UI.Confirm(L("Delete profile"), L("Delete profile \"<<1>>\" and all its trackers?", r.pname), function()
                if not P.Delete(r.pname) then UI.Message(L("Can't delete"), L("You need at least one profile.")) end
                UI.Refresh()
            end)
        end, { 1, 0.45, 0.45, 1 })
        r.export = B(L("Export"), function()
            UI.ShowExport(L("Export profile: <<1>>", r.pname), DT.Serializer.Export("P", { name = r.pname, profile = P.SV().profiles[r.pname] }))
        end)
        r.copy = B(L("Duplicate"), function() P.Create(r.pname .. " " .. L("copy"), r.pname); UI.Refresh() end)
        r.rename = B(L("Rename"), function()
            UI.Prompt(L("Rename profile"), L("New name:"), r.pname, function(v)
                if not P.Rename(r.pname, v) then UI.Message(L("Can't rename"), L("That name is empty or already used.")) end
                UI.Refresh()
            end)
        end)
        r.activate = B(L("Activate"), function() P.SetActive(r.pname); UI.Refresh() end, C.GOLD)
        r.delete:SetAnchor(RIGHT, r.control, RIGHT, -4, 0)
        r.export:SetAnchor(RIGHT, r.delete, LEFT, -6, 0)
        r.copy:SetAnchor(RIGHT, r.export, LEFT, -6, 0)
        r.rename:SetAnchor(RIGHT, r.copy, LEFT, -6, 0)
        r.activate:SetAnchor(RIGHT, r.rename, LEFT, -6, 0)
        return r
    end)
    panel:Add(W.Section(panel.content, w, L("Your profiles")))
    panel:Add(list.control, function() return list:Height() end)
    local btnRow = WM:CreateControl(nil, panel.content, CT_CONTROL)
    btnRow:SetDimensions(w, 30)
    local newBtn = W.FlatButton(btnRow, 160, 28, L("+ New empty profile"), function()
        UI.Prompt(L("New profile"), L("Name:"), L("New profile"), function(v)
            local name = P.Create(v)
            P.SetActive(name)
            UI.Refresh()
        end)
    end)
    newBtn:SetAnchor(LEFT, btnRow, LEFT, 0, 0)
    local impBtn = W.FlatButton(btnRow, 160, 28, L("Import profile"), UI.ImportFlow)
    impBtn:SetAnchor(LEFT, newBtn, RIGHT, 8, 0)
    panel:Add(btnRow, 30)
    panel:Add(W.Checkbox(panel.content, w, L("Each character remembers its own active profile"),
        function() return P.SV().perCharacter end, function(v) P.SetPerCharacter(v) end,
        L("Off: one active profile for the whole account.")))

    panel:Add(W.Section(panel.content, w, L("Automatic switching")))
    panel:Add(W.Checkbox(panel.content, w, L("Switch profiles automatically (first matching rule wins)"),
        function() return P.SV().autoSwitch.enabled end, function(v) P.SV().autoSwitch.enabled = v; if v then P.ApplyAutoSwitch() else P.SyncAutoSwitchEvents() end end))
    panel:Add(W.Note(panel.content, w, L("Checked when you log in, change zone or change role, and when your group changes if a \"My group is\" rule is used (after the fight, if you're in one). Boss fights and trash: use each tracker's Load tab > Fights instead -- nothing has to rebuild mid-fight."), 40), 40)

    local function Rules() return P.SV().autoSwitch.rules end
    local ruleList = W.NewList(panel.content, w, 40, function(p, i)
        local function R() return Rules()[i] end
        local r = {}
        r.control = W.Backdrop(p, { 0.09, 0.1, 0.11, 0.9 }, { 0.2, 0.22, 0.25, 1 }, 1)
        r.control:SetDimensions(w, 36)
        local kind = W.Dropdown(r.control, 170, nil, P.RULE_KINDS, function() return R() and R().kind or "role" end,
            function(v) if R() then R().kind = v; R().value = nil end; P.SyncAutoSwitchEvents() end)
        kind:SetAnchor(LEFT, r.control, LEFT, 6, 0)
        local value = W.Dropdown(r.control, 200, nil, function()
            local rule = R()
            local k = rule and rule.kind or "role"
            if k == "role" then return C.ROLES end
            if k == "zoneType" then return C.ZONE_TYPES end
            if k == "class" then return C.CLASSES end
            if k == "group" then return P.GROUP_RULES end
            if k == "zone" then
                -- the zone you're in, plus the one already picked (by its name when the game knows it)
                local o = {}
                local function Add(id)
                    id = tonumber(id)
                    if not id or id <= 0 then return end
                    for _, e in ipairs(o) do if e[1] == id then return end end
                    local name = type(GetZoneNameById) == "function" and U.CleanName(GetZoneNameById(id)) or ""
                    o[#o + 1] = { id, name ~= "" and string.format("%s (%d)", name, id) or string.format(L("Zone %d"), id) }
                end
                Add(DT.Load.zone.id)
                Add(rule and rule.value)
                return o
            end
            return { { U.CleanName(GetUnitName("player")), U.CleanName(GetUnitName("player")) } }
        end, function() return R() and R().value end, function(v) if R() then R().value = v end end)
        value:SetAnchor(LEFT, kind, RIGHT, 8, 0)
        local arrow = W.Label(r.control, "->", "ZoFontGameBold", C.GOLD)
        arrow:SetAnchor(LEFT, value, RIGHT, 8, 0)
        local prof = W.Dropdown(r.control, 220, nil, function()
            local o = {}
            for _, n in ipairs(P.Names()) do o[#o + 1] = { n, n } end
            return o
        end, function() return R() and R().profile end, function(v) if R() then R().profile = v end end)
        prof:SetAnchor(LEFT, arrow, RIGHT, 8, 0)
        local del = W.FlatButton(r.control, 26, 24, "x", function() table.remove(Rules(), i); P.SyncAutoSwitchEvents(); UI.Refresh() end, L("Delete rule"), { 1, 0.45, 0.45, 1 })
        del:SetAnchor(RIGHT, r.control, RIGHT, -6, 0)
        return r
    end)
    panel:Add(ruleList.control, function() return ruleList:Height() end)
    local addRule = W.FlatButton(panel.content, 140, 28, L("+ Add rule"), function()
        local rules = Rules()
        rules[#rules + 1] = { kind = "role", value = "tank", profile = P.ActiveName() }
        UI.Refresh()
    end)
    panel:Add(addRule, 28)

    function page.OnRefresh()
        local active = P.ActiveName()
        local names = P.Names()
        list:Set(names, function(r, name)
            r.pname = name
            local n = #(P.SV().profiles[name].order or {})
            r.name:SetText(string.format("%s%s  |c888888%s|r", name == active and "|cF3D27A(active)|r " or "", name, L("<<1>> trackers", n)))
            r.activate:SetHidden(name == active)
        end)
        ruleList:Set(Rules(), function() end)
        panel:Layout()
    end
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

function UI.BuildSettingsPage(page, control, width)
    local _, sub = PageTitle(control, L("Settings"), L("Global options for all profiles."), width)
    local panel = W.NewPanel(control, width - 20)
    panel.scroll:SetAnchor(TOPLEFT, sub, BOTTOMLEFT, 0, 10)
    panel.scroll:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    local w = width - 30
    local function ST() return P.Settings() end

    panel:Add(W.Section(panel.content, w, L("Moving windows")))
    panel:Add(W.Checkbox(panel.content, w, L("Move mode (drag tracker windows)"), function() return DT.unlocked end, function(v) DT.Unlock.Set(v) end))
    panel:Add(W.Checkbox(panel.content, w, L("Show the grid while moving"), function() return ST().showGrid end, function(v) ST().showGrid = v; DT.Unlock.RefreshGrid() end))
    panel:Add(W.Checkbox(panel.content, w, L("Snap to the grid"), function() return ST().snapToGrid end, function(v) ST().snapToGrid = v end))
    panel:Add(W.Slider(panel.content, w, L("Grid size"), 4, 64, 2, function() return ST().gridSize end, function(v) ST().gridSize = v; DT.Unlock.RefreshGrid() end))

    panel:Add(W.Section(panel.content, w, L("Preview")))
    panel:Add(W.Checkbox(panel.content, w, L("Sample data while the editor is open"), function() return ST().testInEditor end,
        function(v) ST().testInEditor = v; DT.editorPreview = v and UI.IsShowing() end))
    panel:Add(W.Checkbox(panel.content, w, L("Sample data everywhere (test mode)"), function() return DT.testMode end, function(v) DT.testMode = v end,
        L("Shows every enabled tracker with fake data, even outside the editor. Turn it off before playing.")))

    panel:Add(W.Section(panel.content, w, L("Screen alerts")))
    panel:Add(W.Slider(panel.content, w, L("Distance from the top of the screen"), 0, 900, 10, function() return ST().alertY end,
        function(v) ST().alertY = v; DT.Announcer.ApplyPosition() end))
    panel:Add(W.Slider(panel.content, w, L("Text size"), 16, 60, 1, function() return ST().alertFontSize end,
        function(v) ST().alertFontSize = v; DT.Announcer.ApplyPosition() end))
    panel:Add(W.Button(panel.content, 180, L("Show a test alert"), function() DT.Announcer.Show(L("This is a screen alert"), GetAbilityIcon(62787)) end), 28)

    panel:Add(W.Section(panel.content, w, L("Enemy marker")))
    panel:Add(W.Note(panel.content, w, L("A red arrow over every enemy that's in combat with you (it replaces the game's own enemy marker). Only one add-on may set this marker: if another one does (Untaunted, Fancy Action Bar+...), DebuffTracker leaves it alone, because two add-ons setting it can crash the game."), 50), 50)
    panel:Add(W.Checkbox(panel.content, w, L("Red arrow over enemies in combat with me"), function() return ST().enemyMarker end,
        function(v) ST().enemyMarker = v; DT.Marker.SettingsChanged() end), 26, function() return DT.Marker.Available() end)
    panel:Add(W.Slider(panel.content, w, L("Arrow size"), 16, 64, 2, function() return ST().enemyMarkerSize end,
        function(v) ST().enemyMarkerSize = v; DT.Marker.SettingsChanged() end, nil, nil, function() return not ST().enemyMarker end), 44,
        function() return DT.Marker.Available() end)
    panel:Add(W.Note(panel.content, w, function() return L("Status: <<1>>", DT.Marker.Status()) end, 20), 20)

    panel:Add(W.Section(panel.content, w, L("My target and Tab")))
    panel:Add(W.Note(panel.content, w, L("The game doesn't tell add-ons who you tab-targeted, only that you have a tab target. With this on, \"My target\" trackers keep the enemy you looked at when you set it (or the one under your crosshair when you press Tab again) while you look away. If you press Tab while looking at nothing, it can't know the new one and shows your crosshair target again."), 64), 64)
    panel:Add(W.Checkbox(panel.content, w, L("\"My target\" keeps my tab target when I look away"), function() return ST().followTabTarget ~= false end,
        function(v) ST().followTabTarget = v; DT.Engine.Rebuild() end), 26)

    panel:Add(W.Section(panel.content, w, L("Penetration and critical damage vs. enemies")))
    panel:Add(W.Note(panel.content, w, L("Used by Stat trackers and by the rules \"My penetration vs. the enemy\". The values the debuffs on an enemy add come from Combat Metrics' table; the ones that depend on the gear of whoever applies them can be set here."), 48), 48)
    panel:Add(W.Edit(panel.content, w, L("Enemy armour (penetration cap; 0 = by zone)"), function() return tostring(ST().penTargetResist or 0) end,
        function(v) ST().penTargetResist = tonumber(v) or 0 end, L("0 = automatic: 18200 in dungeons, trials, arenas and houses (the trial dummy), 9100 overland. Dragons: 13650.")), 48)
    panel:Add(W.Edit(panel.content, w, L("Crusher on the enemy"), function() return tostring(ST().penCrusher or 2108) end,
        function(v) ST().penCrusher = tonumber(v) or 2108 end, L("2108 infused (the usual), 1622 plain, 2740 with Torug's Pact.")), 48)
    panel:Add(W.Edit(panel.content, w, L("Roar of Alkosh on the enemy"), function() return tostring(ST().penAlkosh or 6000) end,
        function(v) ST().penAlkosh = tonumber(v) or 6000 end, L("Up to 6000: it scales with the weapon damage of whoever applies it.")), 48)
    panel:Add(W.Edit(panel.content, w, L("Tremorscale on the enemy"), function() return tostring(ST().penTremorscale or 2640) end,
        function(v) ST().penTremorscale = tonumber(v) or 2640 end, L("It scales with the armour of whoever wears it.")), 48)
    panel:Add(W.Edit(panel.content, w, L("Anthelmir's Construct on the enemy"), function() return tostring(ST().penAnthelmir or 2000) end,
        function(v) ST().penAnthelmir = tonumber(v) or 2000 end, L("2000 by default; it scales with the weapon damage of whoever wears it.")), 48)

    panel:Add(W.Section(panel.content, w, L("Above heads")))
    panel:Add(W.Note(panel.content, w, L("For trackers shown above allies' heads (group members, you, your companion). Trackers can't be placed over enemies: the game gives addons no enemy positions."), 34), 34)
    panel:Add(W.Slider(panel.content, w, L("Height above the feet"), 1, 4, 0.1, function() return ST().headHeight end,
        function(v) ST().headHeight = v end, function(v) return string.format("%.1f m", v) end,
        L("Where the icons sit. Raise it if they cover names or health bars.")))
    panel:Add(W.Slider(panel.content, w, L("Hide beyond"), 10, 100, 5, function() return ST().headMaxDistance end,
        function(v) ST().headMaxDistance = v end, function(v) return string.format("%d m", v) end))
    panel:Add(W.Checkbox(panel.content, w, L("Fade out near that distance"), function() return ST().headFade end, function(v) ST().headFade = v end))
    panel:Add(W.Checkbox(panel.content, w, L("Smaller when far away"), function() return ST().headShrink end, function(v) ST().headShrink = v end))
    if DT.World.available == false then
        panel:Add(W.Note(panel.content, w, L("|cFF9060This game client has no 3D position API, so above-heads trackers can't be shown.|r"), 20), 20)
    end

    panel:Add(W.Section(panel.content, w, L("Coming from another addon")))
    panel:Add(W.Note(panel.content, w, L("Bring your setup over from the addons DebuffTracker replaces. Enable the old addon (just for the import), Import, then you can disable it."), 22), 22)
    local tbl, tblH = ImportTable(panel.content, w)
    panel:Add(tbl, tblH)

    panel:Add(W.Section(panel.content, w, L("Maintenance")))
    panel:Add(W.Checkbox(panel.content, w, L("Show ability IDs in skill tooltips (Skills window)"), function() return ST().skillTooltipIds end,
        function(v) ST().skillTooltipIds = v end))
    panel:Add(W.Checkbox(panel.content, w, L("Debug messages in chat"), function() return DT.debug end, function(v) DT.debug = v end))
    panel:Add(W.Button(panel.content, 260, L("Import my 4.x settings again"), function()
        local old = DT.oldSV
        if not old then UI.Message(L("Nothing to import"), L("No 4.x settings were found.")) return end
        local sv = P.SV()
        sv.migratedFromV4 = false
        local n, profiles = DT.Migration.Run(old, sv)
        P.Initialize(sv)
        DT.Engine.Rebuild()
        UI.Message(L("Imported"), L("Created <<1>> trackers in <<2>> profiles.", n, profiles))
        UI.Refresh()
    end), 28)
    panel:Add(W.Button(panel.content, 260, L("Delete every tracker in this profile"), function()
        UI.Confirm(L("Clear profile"), L("Delete all trackers in \"<<1>>\"?", P.ActiveName()), function()
            local profile = P.Active()
            profile.trackers, profile.order = {}, {}
            UI.selectedId = nil
            DT.Engine.Rebuild()
            UI.Refresh()
        end)
    end), 28)

    panel:Add(W.Section(panel.content, w, L("About")))
    panel:Add(W.Note(panel.content, w, L("DebuffTracker <<1>> by <<2>>. Commands: /dt (editor), /dt move, /dt test, /dt profile <name>, /dt debug. Keybinds are in Controls > Keybindings.",
        DT.version, DT.author), 40), 40)

    function page.OnRefresh() panel:Layout() end
end

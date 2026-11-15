-- The editor: a scene with a navigation sidebar and pages (Trackers, Library, Recorder, Ability
-- search, Profiles, Settings). Built lazily on first open, once. While it's open, every tracker
-- shows live sample data on screen (above the editor), so edits are visible instantly.

local DT = DebuffTracker
local UI = DT.UI
local W = UI.W
local U = DT.Util
local C = DT.Const
local L = DT.L
local WM = WINDOW_MANAGER

local SCENE = "DebuffTracker5Editor"
-- scenes that don't close a pinned editor (see Build): the HUD, and short in-world windows
local KEEP_PINNED = { hud = true, hudui = true, loot = true, interact = true }
UI.WIDTH = 1180
UI.NAV_W = 170
UI.HEADER_H = 48
UI.pages = {}
UI.selectedId = nil

------------------------------------------------------------------------------
-- Change propagation
------------------------------------------------------------------------------

function UI.Current()
    if not UI.selectedId then return nil end
    return DT.Profiles.Get(UI.selectedId)
end

-- Called by every widget after it writes a value. light = mid-drag (skip the full UI refresh).
function UI.Changed(light)
    local t = UI.Current()
    if t then DT.Profiles.TrackerChanged(t) else DT.Engine.Rebuild() end
    if not light then UI.Refresh() end
end

function UI.Refresh()
    if not UI.window then return end
    W.RefreshAll()
    for i, page in ipairs(UI.pages) do
        if page.OnRefresh and not page.control:IsHidden() then U.SafeCall("editor page " .. i, page.OnRefresh) end
    end
    if UI.RefreshHeader then U.SafeCall("editor header", UI.RefreshHeader) end
end

function UI.OnProfileChanged()
    if not UI.window then return end
    if UI.selectedId and not DT.Profiles.Get(UI.selectedId) then UI.selectedId = nil end
    UI.Refresh()
end

function UI.OnTrackerMoved(t)
    if UI.window and not UI.window:IsHidden() then UI.Refresh() end
end

function UI.IsShowing()
    return UI.window ~= nil and SCENE_MANAGER:IsShowing(SCENE)
end

------------------------------------------------------------------------------
-- Overlay dialogs (inside the editor window: no extra scenes, no focus fights)
------------------------------------------------------------------------------

local overlay

local function BuildOverlay(win)
    -- A separate top-level on the HIGH draw tier, laid over the editor: draw levels are compared
    -- across a whole window, so children of a dialog inside the editor would fight with page
    -- controls. A top-level of its own is simply above everything in the editor.
    overlay = WM:CreateTopLevelWindow("DebuffTracker5_EditorOverlay")
    overlay:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    overlay:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 0, 0)
    overlay:SetDrawTier(DT_HIGH)
    overlay:SetMouseEnabled(true)        -- blocks clicks to the editor behind
    overlay:SetHidden(true)
    local dim = W.Backdrop(overlay, { 0, 0, 0, 0.6 }, { 0, 0, 0, 0 }, 1)
    dim:SetAnchorFill()
    local box = W.Backdrop(overlay, { 0.07, 0.08, 0.1, 0.99 }, C.GOLD_DIM, 1)
    box:SetAnchor(CENTER, overlay, CENTER, 0, 0)
    overlay.box = box
    local title = W.Label(box, "", "$(BOLD_FONT)|18|soft-shadow-thick", C.GOLD)
    title:SetAnchor(TOPLEFT, box, TOPLEFT, 16, 12)
    overlay.title = title
    local body = W.Label(box, "", "ZoFontGame", { 0.85, 0.85, 0.85, 1 })
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    overlay.body = body

    local editRow = W.Edit(box, 600, nil, function() return overlay.text or "" end, nil, nil,
        { multiline = true, boxHeight = 240, maxChars = 200000, noRefresh = true })
    editRow:SetAnchor(TOPLEFT, body, BOTTOMLEFT, 0, 8)
    overlay.editRow = editRow
    local lineRow = W.Edit(box, 400, nil, function() return overlay.text or "" end, nil, nil, { noRefresh = true, maxChars = 200 })
    lineRow:SetAnchor(TOPLEFT, body, BOTTOMLEFT, 0, 8)
    overlay.lineRow = lineRow

    overlay.buttons = {}
    for i = 1, 3 do
        local b = W.Button(box, 140, "", function() if overlay.actions[i] then overlay.actions[i]() end end)
        overlay.buttons[i] = b
    end
    overlay.choices = W.NewList(box, 560, 34, function(parent)
        local r = {}
        r.control = W.FlatButton(parent, 556, 30, "", function() if r.onClick then r.onClick() end end)
        r.control.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        r.control.label:ClearAnchors()
        r.control.label:SetAnchor(LEFT, r.control, LEFT, 40, 0)
        r.icon = W.Texture(r.control, nil, 24, 24)
        r.icon:SetAnchor(LEFT, r.control, LEFT, 8, 0)
        return r
    end)
    overlay.choices.control:SetAnchor(TOPLEFT, body, BOTTOMLEFT, 0, 10)
end

local function ShowOverlay(spec)
    -- spec: title, body, mode ("text" | "line" | "choices" | "plain"), text, buttons = {{label, fn}}, choices = {{label, icon, fn}}
    overlay.text = spec.text or ""
    overlay.title:SetText(spec.title or "")
    overlay.body:SetText(spec.body or "")
    overlay.body:SetWidth(600)
    -- the body grows to fit its text (long descriptions and import notes are never cut)
    spec.bodyHeight = math.max(spec.bodyHeight or 40, W.TextHeight(spec.body or "", 600, "game", overlay.body) + 4)
    overlay.body:SetDimensions(600, spec.bodyHeight)
    overlay.editRow:SetHidden(spec.mode ~= "text")
    overlay.lineRow:SetHidden(spec.mode ~= "line")
    overlay.choices.control:SetHidden(spec.mode ~= "choices")
    local contentH = 40 + (spec.bodyHeight or 40)
    if spec.mode == "text" then
        overlay.editRow.edit:SetText(overlay.text)
        contentH = contentH + 250
    elseif spec.mode == "line" then
        overlay.lineRow.edit:SetText(overlay.text)
        contentH = contentH + 40
    elseif spec.mode == "choices" then
        overlay.choices:Set(spec.choices, function(r, c)
            r.control.label:SetText(c[1])
            r.icon:SetTexture(c[2] or C.DEFAULT_ICON)
            r.icon:SetHidden(c[2] == nil)
            r.onClick = function() UI.CloseOverlay(); c[3]() end
        end)
        contentH = contentH + overlay.choices:Height() + 10
    end
    overlay.actions = {}
    local prev
    for i, b in ipairs(overlay.buttons) do
        local spec2 = spec.buttons and spec.buttons[i]
        b:SetHidden(spec2 == nil)
        if spec2 then
            b:SetText(spec2[1])
            overlay.actions[i] = spec2[2]
            b:ClearAnchors()
            if prev then b:SetAnchor(RIGHT, prev, LEFT, -10, 0)
            else b:SetAnchor(BOTTOMRIGHT, overlay.box, BOTTOMRIGHT, -16, -12) end
            prev = b
        end
    end
    overlay.box:SetDimensions(640, contentH + 60)
    overlay:SetHidden(false)
    if spec.mode == "text" then overlay.editRow.edit:TakeFocus(); overlay.editRow.edit:SelectAll() end
    if spec.mode == "line" then overlay.lineRow.edit:TakeFocus(); overlay.lineRow.edit:SelectAll() end
end

function UI.CloseOverlay()
    if overlay then
        overlay.editRow.edit:LoseFocus()
        overlay.lineRow.edit:LoseFocus()
        overlay:SetHidden(true)
    end
end

function UI.OverlayShown() return overlay ~= nil and not overlay:IsHidden() end

-- the overlay's visible edit box (tests type into it like a player)
function UI.OverlayEdit()
    if not overlay.editRow:IsHidden() then return overlay.editRow.edit end
    return overlay.lineRow.edit
end

function UI.OverlayText()
    if not overlay.editRow:IsHidden() then return overlay.editRow.edit:GetText() end
    return overlay.lineRow.edit:GetText()
end

function UI.Confirm(title, body, onYes)
    ShowOverlay({ title = title, body = body, mode = "plain", buttons = {
        { L("Yes"), function() UI.CloseOverlay(); onYes() end },
        { L("Cancel"), UI.CloseOverlay },
    } })
end

function UI.Prompt(title, body, initial, onOk)
    ShowOverlay({ title = title, body = body, mode = "line", text = initial, buttons = {
        { L("OK"), function() local v = UI.OverlayText(); UI.CloseOverlay(); onOk(v) end },
        { L("Cancel"), UI.CloseOverlay },
    } })
end

-- jsonText: the same thing as readable JSON (to show an AI assistant / edit by hand); a button
-- switches between the two
function UI.ShowExport(title, text, jsonText)
    local function Show(asJson)
        local buttons = {
            { L("Close"), UI.CloseOverlay },
            { L("Select all"), function() overlay.editRow.edit:TakeFocus(); overlay.editRow.edit:SelectAll() end },
        }
        if jsonText then
            buttons[3] = asJson and { L("Export string"), function() Show(false) end }
                or { L("As JSON (for AI)"), function() Show(true) end }
        end
        ShowOverlay({ title = title, mode = "text", text = asJson and jsonText or text, bodyHeight = 40,
            body = asJson and L("JSON: readable, and what an AI assistant needs to understand or change this tracker. It can be imported again as it is.")
                or L("Press Ctrl+C to copy (the text is already selected), then share it anywhere."),
            buttons = buttons })
    end
    Show(false)
end

function UI.ShowImport(title, body, onImport)
    ShowOverlay({ title = title, mode = "text", text = "", body = body, bodyHeight = 40,
        buttons = {
            { L("Import"), function() onImport(UI.OverlayText()) end },
            { L("Cancel"), UI.CloseOverlay },
        } })
end

function UI.ShowChoices(title, body, choices)
    ShowOverlay({ title = title, body = body, mode = "choices", choices = choices, bodyHeight = 24,
        buttons = { { L("Cancel"), UI.CloseOverlay } } })
end

function UI.Message(title, body)
    local lines = 1
    for _ in tostring(body or ""):gmatch("\n") do lines = lines + 1 end
    ShowOverlay({ title = title, body = body, mode = "plain", bodyHeight = math.min(360, math.max(60, lines * 22 + 20)),
        buttons = { { L("OK"), UI.CloseOverlay } } })
end

------------------------------------------------------------------------------
-- Window shell
------------------------------------------------------------------------------

local function NavButton(parent, text, onClick)
    local b = WM:CreateControl(nil, parent, CT_BUTTON)
    b:SetDimensions(UI.NAV_W, 38)
    b:SetMouseEnabled(true)
    local bg = W.Backdrop(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 1)
    bg:SetAnchorFill()
    local accent = W.Backdrop(b, C.GOLD, { 0, 0, 0, 0 }, 1)
    accent:SetDimensions(3, 38)
    accent:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 0)
    local label = W.Label(b, text, "ZoFontGameBold")
    label:SetAnchor(LEFT, b, LEFT, 16, 0)
    local selected = false
    local function Set(sel)
        selected = sel
        accent:SetHidden(not sel)
        bg:SetCenterColor(0.16, 0.16, 0.19, sel and 1 or 0)
    end
    b:SetHandler("OnMouseEnter", function() if not selected then bg:SetCenterColor(0.13, 0.13, 0.14, 1) end end)
    b:SetHandler("OnMouseExit", function() if not selected then bg:SetCenterColor(0, 0, 0, 0) end end)
    b:SetHandler("OnClicked", function() PlaySound(SOUNDS.DEFAULT_CLICK); onClick() end)
    return b, Set
end

-- Re-show the current page once the window is really on screen. The very first open after a
-- /reloadui builds and fills every page while the window is still hidden; in game the tracker list
-- then stayed empty until the user switched pages and back. This does that switch for them:
-- hide/show the page (its controls get their "effectively shown" pass with the window visible),
-- refresh it, and let every scroll container re-measure its content.
function UI.Reshow()
    if not UI.window then return end
    local index = DT.Profiles.Settings().lastTab or 1
    local page = UI.pages[index]
    if page then
        page.control:SetHidden(true)
        page.control:SetHidden(false)
    end
    UI.SelectPage(index)
    W.UpdateScrolls()
end

function UI.SelectPage(index)
    for i, page in ipairs(UI.pages) do
        page.control:SetHidden(i ~= index)
        page.SetSelected(i == index)
    end
    DT.Profiles.Settings().lastTab = index
    local page = UI.pages[index]
    if page and page.OnShow then U.SafeCall("editor page " .. index .. " (show)", page.OnShow) end
    UI.Refresh()
end

local function Build()
    local win = WM:CreateTopLevelWindow("DebuffTracker5_Editor")
    UI.window = win
    local s = DT.Profiles.Settings()
    local maxH = math.max(560, GuiRoot:GetHeight() - 40)
    win:SetDimensions(UI.WIDTH, U.Clamp(s.editorHeight or 720, 520, maxH))
    win:SetDimensionConstraints(UI.WIDTH, 520, UI.WIDTH, maxH)
    win:SetResizeHandleSize(8)
    win:SetHandler("OnResizeStop", function() DT.Profiles.Settings().editorHeight = math.floor(win:GetHeight() + 0.5) end)
    win:SetAnchor(LEFT, GuiRoot, LEFT, 40, 0)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_LOW)   -- tracker displays draw above the editor: true WYSIWYG
    win:SetHidden(true)

    local bg = W.Backdrop(win, C.PANEL_BG, C.PANEL_EDGE, 1)
    bg:SetAnchorFill()

    -- Title bar
    local bar = W.Backdrop(win, { 0.09, 0.10, 0.12, 1 }, { 0, 0, 0, 0 }, 1)
    bar:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    bar:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    bar:SetHeight(UI.HEADER_H - 4)
    local rule = W.Backdrop(win, C.GOLD_DIM, { 0, 0, 0, 0 }, 1)
    rule:SetAnchor(TOPLEFT, bar, BOTTOMLEFT, 0, 0)
    rule:SetAnchor(TOPRIGHT, bar, BOTTOMRIGHT, 0, 0)
    rule:SetHeight(1)
    local iconFrame = W.Backdrop(bar, C.GOLD_BG, C.GOLD_DIM, 1)
    iconFrame:SetDimensions(28, 28)
    iconFrame:SetAnchor(LEFT, bar, LEFT, 12, 0)
    local icon = W.Texture(iconFrame, GetAbilityIcon(62988), 24, 24)
    icon:SetAnchor(CENTER, iconFrame, CENTER, 0, 0)
    local title = W.Label(bar, "DebuffTracker", "$(BOLD_FONT)|22|soft-shadow-thick", C.GOLD)
    title:SetAnchor(LEFT, iconFrame, RIGHT, 10, 0)
    local sub = W.Label(bar, "5", "$(BOLD_FONT)|22|soft-shadow-thick", { 0.62, 0.88, 0.80, 1 })
    sub:SetAnchor(LEFT, title, RIGHT, 6, 0)
    UI.profileLabel = W.Label(bar, "", "$(MEDIUM_FONT)|15|soft-shadow-thin", { 0.7, 0.7, 0.7, 1 })
    UI.profileLabel:SetAnchor(LEFT, sub, RIGHT, 18, 1)

    local close = WM:CreateControl(nil, win, CT_BUTTON)
    close:SetDimensions(32, 32)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    close:SetNormalTexture("/esoui/art/buttons/closebutton_up.dds")
    close:SetPressedTexture("/esoui/art/buttons/closebutton_down.dds")
    close:SetMouseOverTexture("/esoui/art/buttons/closebutton_mouseover.dds")
    close:SetClickSound(SOUNDS.DIALOG_DECLINE)
    close:SetHandler("OnClicked", function() UI.SetPinned(false); UI.Hide() end)

    UI.moveButton = W.FlatButton(bar, 110, 26, "", function() DT.Unlock.Toggle() end,
        L("Drag tracker windows into place (with grid snapping)."))
    UI.moveButton:SetAnchor(RIGHT, close, LEFT, -10, 0)
    UI.previewButton = W.FlatButton(bar, 150, 26, "", function()
        local st = DT.Profiles.Settings()
        st.testInEditor = not st.testInEditor
        DT.editorPreview = st.testInEditor and UI.IsShowing()
        DT.Engine.RequestUpdate()
        UI.Refresh()
    end, L("While the editor is open, show sample data in every tracker so you can see your changes."))
    UI.previewButton:SetAnchor(RIGHT, UI.moveButton, LEFT, -8, 0)
    UI.pinButton = W.FlatButton(bar, 90, 26, "", function()
        -- remembered: a pinned editor opens pinned next time too (Tony kept forgetting to pin it)
        DT.Profiles.Settings().editorPinned = not UI.pinned
        UI.SetPinned(not UI.pinned)
    end,
        L("Pinned: the editor stays on screen while you play, so you can watch your trackers react and adjust them live. Press your \"cursor\" key (default: .) to click into it while playing. The X -- or the cursor key while you're in the editor -- closes it."))
    UI.pinButton:SetAnchor(RIGHT, UI.previewButton, LEFT, -8, 0)

    function UI.RefreshHeader()
        UI.profileLabel:SetText(L("Profile: <<1>>", DT.Profiles.ActiveName()))
        UI.moveButton.label:SetText(DT.unlocked and L("Lock windows") or L("Move windows"))
        UI.moveButton.bg:SetCenterColor(DT.unlocked and 0.3 or 0.12, DT.unlocked and 0.25 or 0.13, DT.unlocked and 0.16 or 0.15, 1)
        local on = DT.Profiles.Settings().testInEditor
        UI.previewButton.label:SetText(on and L("Sample data: ON") or L("Sample data: OFF"))
        UI.pinButton.label:SetText(UI.pinned and L("Pinned") or L("Pin"))
        UI.pinButton.bg:SetCenterColor(UI.pinned and 0.3 or 0.12, UI.pinned and 0.25 or 0.13, UI.pinned and 0.16 or 0.15, 1)
    end

    -- Navigation
    local nav = W.Backdrop(win, { 0.05, 0.05, 0.06, 0.7 }, { 0.3, 0.3, 0.3, 0.6 }, 1)
    nav:SetWidth(UI.NAV_W)
    nav:SetAnchor(TOPLEFT, win, TOPLEFT, 10, UI.HEADER_H + 8)
    nav:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 10, -12)
    UI.nav = nav
    UI.stats = W.Label(nav, "", "ZoFontGameSmall", { 0.5, 0.5, 0.5, 1 })
    UI.stats:SetAnchor(BOTTOMLEFT, nav, BOTTOMLEFT, 12, -8)
    UI.stats:SetDimensions(UI.NAV_W - 20, 70)
    UI.stats:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)

    UI.content = WM:CreateControl(nil, win, CT_CONTROL)
    UI.content:SetAnchor(TOPLEFT, nav, TOPRIGHT, 12, 0)
    UI.content:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -12, -12)
    UI.contentWidth = UI.WIDTH - UI.NAV_W - 10 - 12 - 12

    local pageDefs = {
        { L("Trackers"), UI.BuildTrackersPage },
        { L("Library"), UI.BuildLibraryPage },
        { L("Recorder"), UI.BuildRecorderPage },
        { L("Ability search"), UI.BuildSearchPage },
        { L("Profiles"), UI.BuildProfilesPage },
        { L("Settings"), UI.BuildSettingsPage },
    }
    local prev
    for i, def in ipairs(pageDefs) do
        local b, setSel = NavButton(nav, def[1], function() UI.SelectPage(i) end)
        b:SetAnchor(TOPLEFT, prev or nav, prev and BOTTOMLEFT or TOPLEFT, 0, prev and 2 or 6)
        prev = b
        local control = WM:CreateControl(nil, UI.content, CT_CONTROL)
        control:SetAnchorFill()
        control:SetHidden(true)
        local page = { control = control, SetSelected = setSel }
        UI.pages[i] = page
        def[2](page, control, UI.contentWidth)
    end

    BuildOverlay(win)

    local scene = ZO_Scene:New(SCENE, SCENE_MANAGER)
    UI.fragment = ZO_FadeSceneFragment:New(win)
    scene:AddFragment(UI.fragment)
    DT.Displays.AddScene(scene)
    -- (No SetInUIMode calls: the scene manager enters/leaves cursor mode by itself.)
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            DT.editorPreview = DT.Profiles.Settings().testInEditor
            UI.SelectPage(DT.Profiles.Settings().lastTab or 1)
            EVENT_MANAGER:RegisterForUpdate("DebuffTracker5_EditorStats", 1000, UI.UpdateStats)
            UI.UpdateStats()
            DT.Engine.RequestUpdate()
        elseif newState == SCENE_SHOWN then
            UI.Reshow()
            -- and once more on the next frame, after the window's first layout pass
            EVENT_MANAGER:RegisterForUpdate("DebuffTracker5_EditorReshow", 0, function()
                EVENT_MANAGER:UnregisterForUpdate("DebuffTracker5_EditorReshow")
                if UI.IsShowing() then UI.Reshow() end
            end)
        elseif newState == SCENE_HIDING then
            -- back to the game: real data (a pinned editor stays on screen, see UI.SetPinned)
            DT.editorPreview = false
            if not UI.pinned then
                UI.CloseOverlay()
                EVENT_MANAGER:UnregisterForUpdate("DebuffTracker5_EditorStats")
            end
            DT.Engine.RequestUpdate()
        end
    end)
    UI.scene = scene
    -- A loading screen closes the editor, pinned or not (Yarden: queued into a battleground with the editor
    -- open and arrived with it still on screen over the game -- a pinned editor is part of the HUD, and the
    -- HUD comes back after the loading screen). Combat Metrics' report is its own scene only, so any loading
    -- screen closes it; this does the same for ours. The Pin preference stays: /dt opens it pinned again.
    if EVENT_PLAYER_DEACTIVATED then
        EVENT_MANAGER:RegisterForEvent("DebuffTracker5_EditorLoading", EVENT_PLAYER_DEACTIVATED, function()
            if UI.pinned then UI.SetPinned(false) end
            if UI.IsShowing() then UI.Hide() end
        end)
    end    -- Opening any other menu (the map, the group menu, inventory, the Esc menu...) closes it the same way
    -- (Yarden: with the editor open, opening the map or the group menu and closing it again left the pinned
    -- editor on screen over the game). Only the HUD itself (where Pin keeps it), our own scene and the short
    -- in-world windows (looting, talking to an NPC) leave it pinned; it's hidden during those and comes back.
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(other, _, newState)
            if newState ~= SCENE_SHOWING or not UI.window or other == UI.scene then return end
            local name = other and other.GetName and other:GetName() or (other and other.name)
            if KEEP_PINNED[name] or other == HUD_SCENE or other == HUD_UI_SCENE then return end
            if UI.pinned then UI.SetPinned(false) end
            if UI.IsShowing() then UI.Hide() end
        end)
    end
    -- The cursor key (the game's "toggle UI mode" binding; esoui ingamescenemanager.lua OnToggleUIModeBinding, "Alt Key
    -- Functions") pressed with the editor in front closes it, like Combat Metrics' report (Yarden: "it keeps the window
    -- opened but switches back to the main scene of the game instead of closing this scene"). The binding leaves UI mode
    -- by showing the HUD; a pinned editor is part of the HUD, so it stayed. Unpinned for this session first (the Pin
    -- preference stays, like the X). Walking away still keeps a pinned editor on screen -- that's what Pin is for.
    if SCENE_MANAGER and type(SCENE_MANAGER.OnToggleUIModeBinding) == "function" and type(ZO_PreHook) == "function" then
        ZO_PreHook(SCENE_MANAGER, "OnToggleUIModeBinding", function()
            if UI.window and UI.IsShowing() and UI.pinned then UI.SetPinned(false) end
        end)
    end
end

function UI.UpdateStats()
    if UI.RefreshLoadStatus then U.SafeCall("editor: load status", UI.RefreshLoadStatus) end
    local st = DT.Engine.stats
    UI.stats:SetText(L("<<1>> trackers loaded\n<<2>> entries shown\n<<3>> ms per update\n<<4>> game event hooks",
        st.loaded, st.states, string.format("%.2f", st.avgMs), DT.Effects.RegisteredCount() + DT.Combat.RegisteredCount()))
end

-- Pinned: the editor window is also part of the game's HUD scenes, so it stays on screen after the
-- editor "closes" (moving, Esc, fighting). The HUD-with-cursor scene (the cursor key) lets you click
-- into it. Only for this session; the X button unpins and closes.
function UI.SetPinned(on)
    if not UI.window or (UI.pinned or false) == (on or false) then return end
    UI.pinned = on or false
    for _, scene in ipairs({ HUD_SCENE, HUD_UI_SCENE }) do
        if scene then
            if UI.pinned then scene:AddFragment(UI.fragment) elseif scene.RemoveFragment then scene:RemoveFragment(UI.fragment) end
        end
    end
    if UI.pinned then
        EVENT_MANAGER:RegisterForUpdate("DebuffTracker5_EditorStats", 1000, UI.UpdateStats)
    elseif not UI.IsShowing() then
        UI.CloseOverlay()
        EVENT_MANAGER:UnregisterForUpdate("DebuffTracker5_EditorStats")
    end
    if UI.RefreshHeader then UI.RefreshHeader() end
end

function UI.Show()
    if not UI.window then Build() end
    SCENE_MANAGER:Show(SCENE)
    if DT.Profiles.Settings().editorPinned ~= false then UI.SetPinned(true) end
end

function UI.Hide()
    if UI.window then SCENE_MANAGER:Hide(SCENE) end
end

-- /dt: opens the editor; when it's open (or pinned on screen) /dt closes it completely, like the X
function UI.Toggle()
    if UI.IsShowing() or (UI.pinned and UI.window and not UI.window:IsHidden()) then
        UI.SetPinned(false)
        UI.Hide()
    else
        UI.Show()
    end
end

-- Open the editor on a specific tracker.
function UI.Edit(trackerId)
    UI.selectedId = trackerId
    if not UI.IsShowing() then UI.Show() end
    UI.SelectPage(1)
    if UI.Refresh then UI.Refresh() end
end

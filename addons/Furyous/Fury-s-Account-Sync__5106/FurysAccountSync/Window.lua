-- Fury's Account Sync - the window (/fas)

local AS = FurysAccountSync

local win, body, bodyText, combo
local partBoxes = {}

-- What Load build puts on the character: one tickbox each, next to the Load build button.
local PARTS = {
    { key = "skills", text = "Skill bars",    x = 130, tip = "Load the five skills and the ultimate of the build's front bar and back bar" },
    { key = "cp",    text = "Champion stars", x = 260, tip = "Slot the build's champion stars that this character has unlocked. Points spent in the trees are not changed" },
    { key = "quick", text = "Quickslots",     x = 420, tip = "Put the build's potions, food and collectibles on the quickslot wheel, as far as this character carries or owns them" },
    { key = "gear",  text = "Gear",           x = 550, tip = "Put on the build's armor, jewelry and weapons, as far as they are in this character's bag. A piece of the same item, trait and quality counts. Starts turned off" },
}
local chosenBuild
local deleteArmed = false
local replaceArmed       -- name of the build Save build asked about replacing
local reportShown = false   -- the report line's box sits under the buttons until the window closes
local note        -- one-off line shown above the preview (e.g. "the main's setup changed")

ZO_CreateStringId("SI_BINDING_NAME_FURYSACCOUNTSYNC_TOGGLE", "Open/close the window")

------------------------------------------------------------------------------
-- Start here (0.5.2): one page on how it works, the same window as every Fury addon.
------------------------------------------------------------------------------
local START = {
    { title = "1. Pick your main account", lines = {
        "Every account on this PC shares this addon's saved file. Log in on the account the others should look like, type /fas and press Make this account the main.",
    } },
    { title = "2. Take a snapshot", lines = {
        "Press Take snapshot on the main (or turn on Take a snapshot automatically in the settings). The window tells you when something changed since the last one.",
    } },
    { title = "3. Copy it to your other accounts", lines = {
        "Log in on another account and type /fas. Show changes lists exactly what will change; Apply to this character copies it.",
        "The game keeps settings, keybinds and chat colors per character, so each character copies once. Click At login until it says Ask me or Automatic to have that happen by itself.",
    } },
    { title = "4. Builds", lines = {
        "Turn on Character builds in the settings to save a character's skill bars, champion stars, quickslots and gear as a build, and load it onto any character on any account. Anything a character can't use is skipped.",
    } },
    { title = "5. If something goes wrong", lines = {
        "Copying addon settings can break an addon. Undo addon copies puts this account's own addon settings back, and /fas undo NAME does it for one addon.",
        "Everything starts turned off. The gear at the top right opens the settings, and /fas help lists every command.",
    } },
}

function AS.ShowStart()
    AS.Theme.StartPage(FurysAccountSync_StartHere,
        AS.title .. " v" .. AS.version .. ": set up one account, and every other account on your PC matches it.", START)
end

function AS.Tip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end

local function SetBodyText(text)
    bodyText:SetText(text)
    ZO_Scroll_ResetToTop(body)
end

local function StatusLine()
    local sv = AS.SV()
    local me = GetDisplayName()
    if not sv.main then return me .. "  -  no main account chosen yet" end
    if AS.IsMain() then return me .. "  -  main account" end
    local mode = AS.AccountRecord().mode
    local modeText = (mode == "auto" and "copies by itself at login")
                  or (mode == "ask" and "asks at login before copying")
                  or "copies only when you press Apply"
    return me .. "  -  copies from " .. sv.main .. "  -  " .. modeText
end

local function FillCombo()
    combo:ClearItems()
    local names = AS.BuildNames()
    local found = false
    for _, name in ipairs(names) do
        local b = AS.SV().builds[name]
        local label = name .. "  |c8A86B0(" .. (b.class or "?") .. ", " .. (b.char or "?") .. ")|r"
        local entry = combo:CreateItemEntry(label, function()
            chosenBuild = name
            deleteArmed = false
            win:GetNamedChild("BuildsDelete"):SetText("Delete")
        end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if name == chosenBuild then found = true end
    end
    if not found then chosenBuild = names[1] end
    combo:UpdateItems()
    if chosenBuild then
        combo:SetSelectedItemText(chosenBuild)
    else
        combo:SetSelectedItemText("No builds saved yet")
    end
end

local function SyncParts()
    local parts = AS.SV().buildParts
    for _, part in ipairs(PARTS) do
        ZO_CheckButton_SetCheckState(partBoxes[part.key], parts[part.key] == true)
    end
end

local function MakePartBoxes(builds)
    for index, part in ipairs(PARTS) do
        local box = WINDOW_MANAGER:CreateControlFromVirtual("FurysAccountSync_WindowBuildsPart" .. index, builds, "ZO_CheckButton")
        box:SetAnchor(TOPLEFT, builds, TOPLEFT, part.x, 138)
        ZO_CheckButton_SetToggleFunction(box, function(_, checked)
            AS.SV().buildParts[part.key] = checked
        end)
        box:SetHandler("OnMouseEnter", function(self) AS.Tip(self, part.tip) end)
        box:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

        -- the words next to the box tick it too
        local label = WINDOW_MANAGER:CreateControl("FurysAccountSync_WindowBuildsPartLabel" .. index, builds, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetColor(AS.Theme.TEXT:UnpackRGBA())
        label:SetText(part.text)
        label:SetAnchor(LEFT, box, RIGHT, 6, 0)
        label:SetMouseEnabled(true)
        label:SetHandler("OnMouseEnter", function(self) AS.Tip(self, part.tip) end)
        label:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        label:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                local parts = AS.SV().buildParts
                parts[part.key] = not parts[part.key]
                ZO_CheckButton_SetCheckState(box, parts[part.key])
                PlaySound(SOUNDS.DEFAULT_CLICK)
            end
        end)
        partBoxes[part.key] = box
    end
end

-- The first button does what this account needs: choose the main while there is none, take a
-- snapshot on the main, and on every other account choose what happens at login.
local function FirstRole()
    if not AS.SV().main then return "main" end
    if AS.IsMain() then return "snapshot" end
    return "mode"
end

local MODE_TEXT = { off = "At login: Off", ask = "At login: Ask me", auto = "At login: Automatic" }
local MODE_NEXT = { off = "ask", ask = "auto", auto = "off" }
local MODE_SAID = {
    off  = "At login this account now does nothing by itself. /fas and Apply still copy when you ask.",
    ask  = "At login this account now opens the window when the main has a newer snapshot, and waits for Apply.",
    auto = "At login this account now copies a newer snapshot from the main by itself, once per character.",
}

function AS.FirstButton()
    local role = FirstRole()
    if role == "main" then
        AS.MakeMain()
    elseif role == "snapshot" then
        AS.TakeSnapshot()
    else
        local rec = AS.AccountRecord()
        rec.mode = MODE_NEXT[rec.mode] or "ask"
        AS.Msg(MODE_SAID[rec.mode])
        AS.RefreshWindow()
    end
end

-- Hover tips for the three buttons at the top. A greyed-out button says why it is greyed out.
function AS.ButtonTip(control, which)
    local sv = AS.SV()
    local text
    if which == "first" then
        local role = FirstRole()
        if role == "main" then
            text = "The account you're on becomes the main: the one your other accounts copy. Pick the account that already looks the way you want. You can change it later in the settings"
        elseif role == "snapshot" then
            text = "Saves this account's game settings, keybinds and chat look so your other accounts can copy them. Take a new one after you change something"
        else
            text = "What this account does at login when the main has a newer snapshot than the character you log in on. Off: nothing. Ask me: this window opens with the changes and waits for Apply. Automatic: it copies straight away. Click to change"
        end
    elseif which == "apply" then
        if not sv.main then
            text = "Greyed out because no main account is chosen yet. That is step 1 below"
        elseif AS.IsMain() then
            text = "Greyed out because this is the main account. Apply is for your other accounts: log in on one and type /fas"
        elseif not sv.snapshot then
            text = "Greyed out because there is no snapshot yet. Log in on " .. sv.main .. ", type /fas and press Take snapshot"
        else
            text = "Copies the main account's setup onto this character: the changes listed below. Each character copies once, because the game keeps these per character. When addon settings or window layout were copied, a pop-up asks to reload the UI at the end"
        end
    end
    AS.Tip(control, text)
end

local function Layout()
    local buildsOn = AS.SV().builds_on
    local builds = win:GetNamedChild("Builds")
    builds:SetHidden(not buildsOn)
    body:ClearAnchors()
    body:SetAnchor(TOPLEFT, win, TOPLEFT, 20, reportShown and 166 or 134)
    body:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, buildsOn and -240 or -16)
    win:GetNamedChild("ReportBg"):SetHidden(not reportShown)

    local role = FirstRole()
    local first = win:GetNamedChild("Snapshot")
    if role == "main" then
        first:SetText("Make this account the main")
    elseif role == "snapshot" then
        first:SetText("Take snapshot")
    else
        first:SetText(MODE_TEXT[AS.AccountRecord().mode] or MODE_TEXT.off)
    end
    win:GetNamedChild("Apply"):SetEnabled(role == "mode" and AS.SV().snapshot ~= nil)
end

-- The window opens where it was last left.
function AS.SaveWindowPlace()
    AS.SV().window = { x = math.floor(win:GetLeft()), y = math.floor(win:GetTop()) }
end

-- Shows the given text in the body, or the preview of what Apply would change when there is none.
local function Refresh(report)
    win:GetNamedChild("Sub"):SetText(StatusLine())
    Layout()
    if AS.SV().builds_on then
        FillCombo()
        SyncParts()
    end
    local text = report or AS.PreviewText()
    if note then text = "|cFFC857" .. note .. "|r\n\n" .. text end
    note = nil
    SetBodyText(text)
end

function AS.RefreshWindow(report)
    if not win or win:IsHidden() then return end
    Refresh(report)
end

function AS.ShowReport(text)
    if not win then return end
    if win:IsHidden() then
        SCENE_MANAGER:Show(AS.SCENE)
        Refresh()
    end
    SetBodyText(text)
end

function AS.OpenWindow(message)
    note = message
    SCENE_MANAGER:Show(AS.SCENE)
    -- a report that was kept across the UI reload after a copy is shown once
    local rec = AS.AccountRecord()
    local report = rec.report
    rec.report = nil
    Refresh(report)
end

function AS.CloseWindow()
    reportShown = false
    if SCENE_MANAGER:IsShowing(AS.SCENE) then SCENE_MANAGER:Hide(AS.SCENE) end
end

-- Opens the window with the report line in a box under the buttons, selected for Ctrl+C.
function AS.ShowReportBox()
    reportShown = true
    AS.OpenWindow("The report line is in the box above, selected. Press Ctrl+C, then paste it into your comment with what went wrong. It holds no account or character names.")
    local edit = win:GetNamedChild("ReportBgEdit")
    edit:SetText(AS.ReportLine())
    edit:SelectAll()
    edit:TakeFocus()
end

function AS.ToggleWindow()
    if SCENE_MANAGER:IsShowing(AS.SCENE) then
        AS.CloseWindow()
    else
        AS.OpenWindow()
    end
end

------------------------------------------------------------------------------
-- Builds buttons
------------------------------------------------------------------------------
function AS.SaveBuildFromWindow()
    local edit = win:GetNamedChild("BuildsNameBgEdit")
    local button = win:GetNamedChild("BuildsSave")
    local name = zo_strtrim(edit:GetText())
    -- A name that is already taken asks before it replaces that build.
    if AS.SV().builds[name] and replaceArmed ~= name then
        replaceArmed = name
        button:SetText("Replace? Click again")
        AS.Msg("There is already a build called \"" .. name .. "\". Press Save build again to replace it, or type another name.")
        return
    end
    replaceArmed = nil
    button:SetText("Save build")
    if AS.SaveBuild(name) then
        chosenBuild = name
        edit:SetText("")
        edit:LoseFocus()
        FillCombo()
    end
end

function AS.LoadBuildFromWindow()
    if chosenBuild then
        AS.LoadBuild(chosenBuild)
    else
        AS.Msg("No build chosen.")
    end
end

-- Puts the chosen build into the text box as one line, selected, ready for Ctrl+C.
function AS.ShowBuildText()
    local edit = win:GetNamedChild("BuildsTextBgEdit")
    if not chosenBuild then
        AS.Msg("Pick a build in the list first.")
        return
    end
    edit:SetText(AS.BuildToText(chosenBuild))
    edit:SelectAll()
    edit:TakeFocus()
    AS.Msg("The text of \"" .. chosenBuild .. "\" is in the box and selected. Press Ctrl+C to copy it.")
end

-- Adds the build whose text was pasted into the text box. A name that is taken gets a number.
function AS.AddBuildFromText()
    local edit = win:GetNamedChild("BuildsTextBgEdit")
    local name, build = AS.BuildFromText(edit:GetText())
    if not name then
        AS.Msg(build)
        return
    end
    local builds = AS.SV().builds
    local final, n = name, 2
    while builds[final] do
        final = name .. " (" .. n .. ")"
        n = n + 1
    end
    builds[final] = build
    chosenBuild = final
    edit:SetText("")
    edit:LoseFocus()
    AS.Msg("Added build \"" .. final .. "\" from text. Load build puts it on this character.")
    FillCombo()
end

function AS.DeleteBuildFromWindow()
    local button = win:GetNamedChild("BuildsDelete")
    if not chosenBuild then return end
    if not deleteArmed then
        deleteArmed = true
        button:SetText("Click to confirm")
        return
    end
    deleteArmed = false
    button:SetText("Delete")
    AS.DeleteBuild(chosenBuild)
    chosenBuild = nil
    FillCombo()
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------
function AS.InitWindow()
    win = FurysAccountSync_Window
    body = win:GetNamedChild("Body")
    local child = body:GetNamedChild("ScrollChild")
    bodyText = WINDOW_MANAGER:CreateControl("FurysAccountSync_WindowBodyText", child, CT_LABEL)
    bodyText:SetAnchor(TOPLEFT, child, TOPLEFT, 0, 0)
    bodyText:SetWidth(700)
    bodyText:SetFont("ZoFontGame")
    bodyText:SetColor(AS.Theme.TEXT:UnpackRGBA())

    combo = ZO_ComboBox_ObjectFromContainer(win:GetNamedChild("BuildsCombo"))
    combo:SetSortsItems(false)
    MakePartBoxes(win:GetNamedChild("Builds"))

    local scene = ZO_Scene:New(AS.SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragment(ZO_SimpleSceneFragment:New(win))

    AS.Theme.Window(win)
    -- 0.5.2: the same header as every Fury addon (Theme.lua): title and version, Start here
    -- after them, the gear and close button at the right, each with a hover tip.
    AS.Theme.SetTitle(win, AS.title, AS.version)
    AS.Theme.StartButton(win, AS.ShowStart,
        "New here? One page on how it works: the main account, snapshots, copying to your other accounts, builds and undo.\n(also /fas start)")
    AS.Theme.CloseTip(win:GetNamedChild("Close"))
    -- The other Fury addons, one click each, in the title bar (Theme.lua).
    AS.Theme.TitleIcons(win, win:GetNamedChild("Settings"))

    local place = AS.SV().window
    if type(place) == "table" and type(place.x) == "number" and type(place.y) == "number" then
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, place.x, place.y)
    end
    AS.Theme.Paint(win:GetNamedChild("BuildsHeader"), AS.Theme.TEXT)
end

-- Fury's Account Sync - the window (/fas)

local AS = FurysAccountSync

local win, body, bodyText, combo
local partBoxes = {}

-- What Load build puts on the character: one tickbox each, next to the Load build button.
local PARTS = {
    { key = "skills", text = "Skill bars",    x = 150, tip = "Load the five skills and the ultimate of the build's front bar and back bar" },
    { key = "cp",    text = "Champion stars", x = 290, tip = "Slot the build's champion stars that this character has unlocked. Points spent in the trees are not changed" },
    { key = "quick", text = "Quickslots",     x = 460, tip = "Put the build's potions, food and collectibles on the quickslot wheel, as far as this character carries or owns them" },
}
local chosenBuild
local deleteArmed = false
local note        -- one-off line shown above the preview (e.g. "the main's setup changed")

ZO_CreateStringId("SI_BINDING_NAME_FURYSACCOUNTSYNC_TOGGLE", "Open Fury's Account Sync")

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
    local me = "v" .. AS.version .. "  -  " .. GetDisplayName()
    if not sv.main then return me .. "  -  no main account chosen yet" end
    if AS.IsMain() then return me .. "  -  main account" end
    local mode = AS.AccountRecord().mode
    local modeText = (mode == "auto" and "copies the main automatically")
                  or (mode == "ask" and "asks before copying the main")
                  or "doesn't copy the main (turn it on in settings)"
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

local function Layout()
    local buildsOn = AS.SV().builds_on
    local builds = win:GetNamedChild("Builds")
    builds:SetHidden(not buildsOn)
    body:ClearAnchors()
    body:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 134)
    body:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, buildsOn and -198 or -16)

    local isMain = AS.IsMain()
    win:GetNamedChild("Snapshot"):SetEnabled(isMain)
    win:GetNamedChild("Apply"):SetEnabled(not isMain and AS.SV().snapshot ~= nil and AS.SV().main ~= nil)
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
    if SCENE_MANAGER:IsShowing(AS.SCENE) then SCENE_MANAGER:Hide(AS.SCENE) end
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
    local name = zo_strtrim(edit:GetText())
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
    AS.Theme.Paint(win:GetNamedChild("BuildsHeader"), AS.Theme.TEXT)
end

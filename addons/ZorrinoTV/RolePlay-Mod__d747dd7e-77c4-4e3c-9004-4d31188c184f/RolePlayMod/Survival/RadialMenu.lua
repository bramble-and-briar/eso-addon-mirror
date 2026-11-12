if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local buttonTexts = {"Manger", "Boire", "Repos assis", "Repos partiel", "Besoins", "Se renseigner", "Livres", "Familiers"}
local commandNames={"/eatfood","/drinkwater","/rest","/takeanap","/togglesurvival","/openaskforinfo","/openmybook","/openmypets"}
local G={};RolePlayNeeds.GamepadWheel=G
local selected,cursorBefore=1,nil
local initialized=false
local function setWheelOpen(value)
    if type(RolePlayNeeds.SetWheelOpen)=='function' then RolePlayNeeds.SetWheelOpen(value) end
end
local function gamepadMode()
    return type(IsInGamepadPreferredMode)=='function' and IsInGamepadPreferredMode()
        or type(IsConsoleUI)=='function' and IsConsoleUI()
end
local function wheelButton(index) return _G['MyFakeRadialButton'..index] end
local function available(index)
    local button=wheelButton(index)
    if not button or button:IsHidden() or type(SLASH_COMMANDS[commandNames[index]])~='function' then return false end
    local key=({[1]='hunger',[2]='water',[3]='fatigue',[4]='partialRests'})[index]
    if key and RolePlayMod and not RolePlayMod.Enabled(key) then return false end
    return true
end
local function restoreCursor()
    if cursorBefore==nil then return end
    local previous=cursorBefore;cursorBefore=nil;SetGameCameraUIMode(previous)
end
function G.IsOpen() return MyFakeRadial and not MyFakeRadial:IsHidden() or false end
function G.ClearFocus()
    for index=1,8 do
        local button=wheelButton(index)
        if button then button:SetDimensions(50,50);if button.rpmGamepadFocus then button.rpmGamepadFocus:SetHidden(true) end end
    end
    if MyFakeRadialHoverLabel then MyFakeRadialHoverLabel:SetHidden(true) end
end
local function focus(index)
    if not available(index) then return false end
    G.ClearFocus();selected=index
    local button=wheelButton(index)
    button:SetDimensions(64,64)
    if not button.rpmGamepadFocus then
        local mark=WINDOW_MANAGER:CreateControl(nil,button,CT_BACKDROP)
        mark:SetAnchorFill();mark:SetCenterColor(0,0,0,0);mark:SetEdgeColor(.92,.83,.62,.9)
        mark:SetEdgeTexture(nil,1,1,1,1);mark:SetMouseEnabled(false);button.rpmGamepadFocus=mark
    end
    button.rpmGamepadFocus:SetHidden(false)
    local text=buttonTexts[index]
    if index==4 and RolePlayNeeds.GetPartialRestsRemaining then text=text..' : '..RolePlayNeeds.GetPartialRestsRemaining()..'/2'
    elseif index==5 then text='Mode survie : '..((RolePlayMod and RolePlayMod.Enabled('survival')) and 'activé' or 'désactivé') end
    MyFakeRadialHoverLabel:SetText(text);MyFakeRadialHoverLabel:SetHidden(false)
    return true
end
local function cycle(delta)
    for step=1,8 do local index=(selected-1+step*delta)%8+1;if available(index) then return focus(index) end end
    return false
end
function G.Move(direction)
    if not G.IsOpen() then return false end
    if direction=='next' then return cycle(1) elseif direction=='previous' then return cycle(-1) end
    local index=({up=1,['up-right']=2,upright=2,right=3,['down-right']=4,downright=4,down=5,['down-left']=6,downleft=6,left=7,['up-left']=8,upleft=8})[direction]
    if index then return focus(index) end
    return false
end
function G.Page(delta) if not G.IsOpen() then return false end;return cycle(delta and delta<0 and -1 or 1) end
function G.Label() return G.IsOpen() and available(selected) and buttonTexts[selected] or 'Besoins vitaux' end
function G.Back()
    if not G.IsOpen() then return false end
    MyFakeRadial:SetHidden(true);setWheelOpen(false);G.ClearFocus();restoreCursor();return true
end
function G.Toggle()
    if G.IsOpen() then return G.Back() end
    if not MyFakeRadial then return false end
    if not initialized then InitializeWheel() end
    if RolePlayMod and RolePlayMod.RefreshWheel then RolePlayMod.RefreshWheel() end
    cursorBefore=type(IsGameCameraUIModeActive)=='function' and not not IsGameCameraUIModeActive() or false
    MyFakeRadial:SetHidden(false);setWheelOpen(true);SetGameCameraUIMode(true)
    if gamepadMode() then if not focus(selected) then cycle(1) end end
    return true
end
local buttonActions = {
    function() SLASH_COMMANDS["/eatfood"]() end,
    function() SLASH_COMMANDS["/drinkwater"]() end,
    function() SLASH_COMMANDS["/rest"]() end,
    function() SLASH_COMMANDS["/takeanap"]() end,
    function() SLASH_COMMANDS["/togglesurvival"]() end,
    function() SLASH_COMMANDS["/openaskforinfo"]() end,
    function() SLASH_COMMANDS["/openmybook"]() end,
    function() SLASH_COMMANDS["/openmypets"]() end,
}
function G.Confirm()
    if not G.IsOpen() then return false end
    if not available(selected) then return false end
    local action=buttonActions[selected]
    if not action then return false end
    -- Existing command wrappers enforce need switches and partial-rest limits.
    -- Let legacy actions close their own wheel first, then close it if needed.
    action()
    if G.IsOpen() then G.Back() else restoreCursor() end
    return true
end
function G.GetGamepadContext()
    if not G.IsOpen() then return end
    return {kind='survival',root=MyFakeRadial,move=G.Move,confirm=G.Confirm,back=G.Back,page=G.Page,clear=G.ClearFocus,label=G.Label}
end

local function IsAddonLoaded(target)
    local t = _G[target]
    return type(t) == "table"
end

local function SetupHoverLabel(button, labelText)
    button:SetHandler("OnMouseEnter", function()
    local state = SLASH_COMMANDS["/isSurvivalOn"]()
    if state then
        state = " activé"
        MyFakeRadialButton5:SetNormalTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")
        MyFakeRadialButton5:SetPressedTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")
        MyFakeRadialButton5:SetMouseOverTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")
    else
        state= " désactivé"
        MyFakeRadialButton5:SetNormalTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")
        MyFakeRadialButton5:SetPressedTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")
        MyFakeRadialButton5:SetMouseOverTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")
    end
        if (button == MyFakeRadialButton4) and RolePlayNeeds.GetPartialRestsRemaining then
            labelText = "Repos partiel : " .. RolePlayNeeds.GetPartialRestsRemaining() .. "/2"
        end
        MyFakeRadialHoverLabel:SetText(labelText)
        if button == MyFakeRadialButton5 then
        MyFakeRadialHoverLabel:SetText(labelText .. state)
        end

        MyFakeRadialHoverLabel:SetHidden(false)
        button:SetDimensions(64, 64)
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end)
    button:SetHandler("OnMouseExit", function()
        MyFakeRadialHoverLabel:SetText("")
        MyFakeRadialHoverLabel:SetHidden(true)
        button:SetDimensions(50, 50)
    end)
end
function InitializeWheel()
    if initialized then return end
    local base = MyFakeRadial
    base:SetHidden(true)
    base:ClearAnchors()
    base:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    base:SetDrawTier(DT_HIGH)
    base:SetHandler('OnHide',function() setWheelOpen(false);G.ClearFocus();restoreCursor() end)

    local hasAsk = IsAddonLoaded("IHeardARumor")
    local hasBooks = IsAddonLoaded("TamrielBooks")
    local hasPets = IsAddonLoaded("ImmersivePets")

    for i = 1, 8 do
        local btn = base:GetNamedChild("Button" .. i)
        if btn then
            local show = true

            if i == 6 and not hasAsk then
                show = false
                d("Renseignements indisponibles : IHeardARumor est désactivé.")
            elseif i == 7 and not hasBooks then
                show = false
                d("Livres indisponibles : TamrielBooks est désactivé.")
            elseif i == 8 and not hasPets then
                show = false
                d("Familiers indisponibles : ImmersivePets est désactivé.")
            end

            btn:SetHidden(not show)

            if show then
                btn:SetHandler("OnClicked", buttonActions[i])
            else
                btn:SetHandler("OnClicked", nil)  -- remove handler just in case
            end
        end
    end
local label = WINDOW_MANAGER:CreateControl("MyFakeRadialHoverLabel", MyFakeRadial, CT_LABEL)
label:SetFont("ZoFontGamepadBold27")
label:SetDimensions(300, 40)
label:SetAnchor(CENTER, MyFakeRadial, CENTER, 0, 0)
label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
label:SetColor(1, 1, 1, 1)
label:SetHidden(true)
SetupHoverLabel(MyFakeRadialButton1, "Manger")
SetupHoverLabel(MyFakeRadialButton2, "Boire")
SetupHoverLabel(MyFakeRadialButton3, "Repos assis : récupération lente")
SetupHoverLabel(MyFakeRadialButton4, "Repos partiel")
SetupHoverLabel(MyFakeRadialButton5, "Mode survie :")
SetupHoverLabel(MyFakeRadialButton6, "Se renseigner")
SetupHoverLabel(MyFakeRadialButton7, "Livres")
SetupHoverLabel(MyFakeRadialButton8, "Familiers")
    SLASH_COMMANDS["/mywheel"] = G.Toggle
    initialized=true
end
SLASH_COMMANDS['/mywheel']=G.Toggle
-- The existing needs shortcut keeps its keyboard behaviour. In gamepad mode
-- it opens the usable radial directly instead of requiring repeated checks.
local checkNeeds=RolePlayNeeds.CheckNeeds
function RolePlayNeeds.CheckNeeds(...)
    if gamepadMode() then return G.Toggle() end
    return checkNeeds(...)
end

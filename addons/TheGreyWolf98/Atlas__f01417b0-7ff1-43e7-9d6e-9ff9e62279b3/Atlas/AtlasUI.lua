local A=Atlas
local W,H=1460,860
local gold,muted,white={0.95,0.73,0.35},{0.65,0.72,0.8},{0.94,0.96,1}
local function label(parent,x,y,w,h,size,color)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetDimensions(w,h)
    c:SetFont("$(BOLD_FONT)|"..size.."|soft-shadow-thin")
    c:SetColor(unpack(color or white))
    c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return c
end
function A.Resize()
    A.window:SetScale(math.min(GuiRoot:GetWidth()*0.94/W,GuiRoot:GetHeight()*0.88/H))
end
function A.MoveSelection(direction)
    local index=A.selected or 1
    local column=math.floor((index-1)/8)
    local row=(index-1)%8
    local length=math.min(8,#A.options-column*8)
    if direction==ZO_DIRECTION_UP then row=(row-1)%length
    elseif direction==ZO_DIRECTION_DOWN then row=(row+1)%length
    elseif direction==ZO_DIRECTION_LEFT then column=0
    elseif direction==ZO_DIRECTION_RIGHT then column=1
    else return end
    A.selected=math.min(column*8+row+1,#A.options)
    A.Paint()
end
function A.CreateUI()
    local root=WINDOW_MANAGER:CreateTopLevelWindow("AtlasWindow")
    A.window=root
    root:SetDimensions(W,H)
    root:SetAnchor(CENTER,GuiRoot,CENTER,0,-15)
    root:SetHidden(true)
    local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.025,0.035,0.05,1)
    bg:SetEdgeColor(0.55,0.36,0.13,1)
    bg:SetEdgeTexture(nil,1,1,2)
    label(root,36,24,750,50,36,gold):SetText("ATLAS")
    label(root,1050,32,370,30,20,muted):SetText(A.version.." | @TheGreyWolf98")
    label(root,36,82,1380,30,23):SetText("Your map. Your layers. Settings shared across your characters.")
    A.mapLabel=label(root,36,122,1380,28,19,muted)
    A.rows={}
    for i,o in ipairs(A.options) do
        local index=i
        local button=WINDOW_MANAGER:CreateControl(nil,root,CT_BUTTON)
        button:SetAnchor(TOPLEFT,root,TOPLEFT,30+math.floor((i-1)/8)*710,166+((i-1)%8)*59)
        button:SetDimensions(690,55)
        button:SetMouseEnabled(true)
        button:SetHandler("OnClicked",function() A.Toggle(index) end)
        local selected=WINDOW_MANAGER:CreateControl(nil,button,CT_BACKDROP)
        selected:SetAnchorFill(button)
        selected:SetCenterColor(0.15,0.18,0.23,1)
        selected:SetEdgeColor(0.8,0.6,0.25,1)
        selected:SetEdgeTexture(nil,1,1,1)
        selected:SetMouseEnabled(false)
        label(button,16,3,510,26,22,o.color or white):SetText(o.title)
        local description=label(button,16,30,650,20,14,muted)
        description:SetText(o.detail)
        A.rows[i]={button=button,highlight=selected,state=label(button,548,3,125,26,20)}
    end
    A.detailLabel=label(root,36,662,1380,60,21,gold)
    label(root,36,732,1380,65,17,muted):SetText("D-pad: choose a switch. Changes apply immediately; close to view the map.\nSurveys and maps: backpack filter available. Boss pins stay visible.\nRecorded coverage varies; group-dungeon boss interiors are incomplete. ESO's own pins remain separate.")
    A.scene=ZO_Scene:New("atlas",SCENE_MANAGER)
    A.scene:AddFragment(ZO_SimpleSceneFragment:New(root))
    A.scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    A.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="Toggle feature",keybind="UI_SHORTCUT_PRIMARY",callback=function() A.Toggle() end},
        {name="Refresh pins",keybind="UI_SHORTCUT_TERTIARY",callback=A.Refresh},
        {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function() SCENE_MANAGER:Hide("atlas") end},
    }
    -- Use ordinary keybind callbacks. DIRECTIONAL_INPUT:GetXY reaches private
    -- IsKeyDown on console and must never be called from this addon.
    local function navigation(keybind,direction)
        return {keybind=keybind,ethereal=true,
            callback=function()
                if not A.scene:IsShowing() then return false end
                A.MoveSelection(direction)
                return true
            end}
    end
    A.keys[#A.keys+1]=navigation("UI_SHORTCUT_INPUT_UP",ZO_DIRECTION_UP)
    A.keys[#A.keys+1]=navigation("UI_SHORTCUT_INPUT_DOWN",ZO_DIRECTION_DOWN)
    A.keys[#A.keys+1]=navigation("UI_SHORTCUT_INPUT_LEFT",ZO_DIRECTION_LEFT)
    A.keys[#A.keys+1]=navigation("UI_SHORTCUT_INPUT_RIGHT",ZO_DIRECTION_RIGHT)
    A.scene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWING then
            A.Resize(); A.Refresh()
            if not A.keysActive then
                KEYBIND_STRIP:AddKeybindButtonGroup(A.keys)
                A.keysActive=true
            end
        elseif state==SCENE_HIDING or state==SCENE_HIDDEN then
            if A.keysActive then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(A.keys)
                A.keysActive=false
            end
        end
    end)
    root:RegisterForEvent(EVENT_SCREEN_RESIZED,A.Resize)
    A.Resize()
end
function A.Paint()
    if not A.rows or not A.saved then return end
    A.mapLabel:SetText("Current map: "..zo_strformat("<<1>>",GetMapName() or "Unknown map").." | Counts apply to this map")
    for i,o in ipairs(A.options) do
        local r=A.rows[i]
        r.highlight:SetHidden(i~=A.selected)
        local enabled=A.saved[o.key]
        r.state:SetText(enabled and (i<=A.layerCount and "ON ("..#A.Locations(o.key)..")" or "ON") or "OFF")
        r.state:SetColor(unpack(enabled and {0.4,0.9,0.6} or muted))
    end
    local o=A.options[A.selected or 1]
    A.detailLabel:SetText(o.title.."\n"..o.detail)
end

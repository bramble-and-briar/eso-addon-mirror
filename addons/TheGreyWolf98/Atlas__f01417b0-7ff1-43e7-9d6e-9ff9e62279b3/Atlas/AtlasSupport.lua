local A=Atlas
local W,H=1080,660
local function text(parent,value,x,y,width,height,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetDimensions(width,height)
    c:SetFont("$(GAMEPAD_MEDIUM_FONT)|"..size.."|soft-shadow-thin")
    c:SetColor(0.94,0.96,1,1)
    c:SetText(value)
    return c
end
function A.CreateSupportUI()
    local root=WINDOW_MANAGER:CreateTopLevelWindow("AtlasSupportWindow")
    root:SetDimensions(W,H)
    root:SetAnchor(CENTER,GuiRoot,CENTER,0,-15)
    root:SetHidden(true)
    local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.025,0.035,0.05,1)
    bg:SetEdgeColor(0.55,0.36,0.13,1)
    bg:SetEdgeTexture(nil,1,1,2)
    text(root,"ATLAS / SOCIALS & SUPPORT",36,24,1008,50,36)
    text(root,A.author,36,80,1008,36,26)
    text(root,"Enjoying Atlas? Buy me a beer on Ko-fi.",36,134,1008,40,28)
    local qr=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE)
    qr:SetAnchor(TOPLEFT,root,TOPLEFT,36,190)
    qr:SetDimensions(320,320)
    qr:SetTexture("Atlas/Textures/KoFiQR.dds")
    text(root,"Scan to open Ko-fi",36,520,350,36,24)
    text(root,"ko-fi.com/thegreywolf98",396,204,648,40,28)
    text(root,"Instagram",396,286,648,36,24)
    text(root,"@thegreywolf_98",396,322,648,40,28)
    text(root,"Discord / updates & bug reports",396,402,648,36,24)
    text(root,"discord.gg/Fp9RSaeU8h",396,438,648,40,28)
    text(root,"Always free. Support is optional.",36,590,1008,36,24)
    local function resize()
        root:SetScale(math.min(GuiRoot:GetWidth()*0.94/W,GuiRoot:GetHeight()*0.88/H))
    end
    A.supportScene=ZO_Scene:New("atlasSupport",SCENE_MANAGER)
    A.supportScene:AddFragment(ZO_SimpleSceneFragment:New(root))
    A.supportScene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    local keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="Back to Atlas",keybind="UI_SHORTCUT_NEGATIVE",callback=function() SCENE_MANAGER:Show("atlas") end}}
    local active=false
    A.supportScene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWING then
            resize()
            if not active then KEYBIND_STRIP:AddKeybindButtonGroup(keys);active=true end
        elseif state==SCENE_HIDING or state==SCENE_HIDDEN then
            if active then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys);active=false end
        end
    end)
    root:RegisterForEvent(EVENT_SCREEN_RESIZED,resize)
    resize()
end

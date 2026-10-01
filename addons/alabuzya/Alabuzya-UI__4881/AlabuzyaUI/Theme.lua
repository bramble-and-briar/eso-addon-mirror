local AlabuzyaUI = AlabuzyaUI
-- AlabuzyaUI original theme, alabuzya, 2026. Generated artwork; see art provenance.
AlabuzyaUI.Theme={}
local T=AlabuzyaUI.Theme
T.atlas='AlabuzyaUI/Textures/EmberAtlas.dds'
-- ESO's antique face matches the engraved fantasy lettering of the AlabuzyaUI frame
-- and is supplied by the client with localized glyph coverage.
T.font='$(ANTIQUE_FONT)'
function T.Configure()
    if AlabuzyaUI.Settings.Style()=='wow' then AlabuzyaUI.ClassicTheme.Configure() end
end
function T.MapHost() return T.Sidebar() end
function T.QuestHost() return T.Sidebar() end
function T.Font(size,outline)
    return T.font..'|'..(size or 18)..'|'..(outline or 'soft-shadow-thick')
end
function T.Texture(parent,u1,u2,v1,v2,layer)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    c:SetTexture(T.atlas) c:SetTextureCoords(u1,u2,v1,v2)
    c:SetMouseEnabled(false) c:SetDrawLayer(layer or DL_OVERLAY)
    return c
end
function T.Text(c,size)
    c:SetFont(T.Font(size))
    c:SetColor(1,0.69,0.34,1)
end
local function SetFont(control,size,outline)
    if control and control.SetFont then control:SetFont(T.Font(size,outline)) end
end
function T.ApplyHUDFonts()
    -- Named native HUD labels which remain visible around AlabuzyaUI.
    SetFont(ZO_CompassFrameCenterOverPinLabel,20)
    SetFont(ZO_CompassFrameCenterOverPinLabelBoss,20)
    SetFont(ZO_InteractWindowTargetAreaTitle,22)
    SetFont(ZO_InteractWindowTargetAreaBodyText,18)
    SetFont(ZO_ChatWindowTextEntryEditBox,18)
    local primary=CHAT_SYSTEM and CHAT_SYSTEM.primaryContainer
    if primary then
        SetFont(primary.currentBuffer,17)
        for _,window in ipairs(primary.windows or {}) do SetFont(window.buffer,17) end
    end
    if ZO_ActionBar_GetButton then
        local last=ACTION_BAR_ULTIMATE_SLOT_INDEX or (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+5)
        for index=ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+1,last+1 do
            local button=ZO_ActionBar_GetButton(index)
            if button then
                SetFont(button.buttonText,15,'thick-outline')
                SetFont(button.stackCountText,15,'thick-outline')
                SetFont(button.timerText,15,'thick-outline')
            end
        end
    end
end
function T.Panel(parent,inset)
    if parent.alabuzyauiFrame then return end
    parent.alabuzyauiFrame=true
    -- Keep the visible metal on the boundary, outside the content area.
    -- Eight slices preserve the corner ornaments as the panel changes size.
    local uvx={0.51,0.62,0.88,0.99}
    local uvy={0.02,0.14,0.38,0.49}
    local edges={}
    for y=1,3 do for x=1,3 do
        if x~=2 or y~=2 then
            local c=T.Texture(parent,uvx[x],uvx[x+1],uvy[y],uvy[y+1])
            -- Crop straight strips tightly so the actual metal does not become a hairline.
            if x==2 then c:SetTextureCoords(0.62,0.88,y==1 and 0.068 or 0.425,y==1 and 0.096 or 0.448) end
            if y==2 then c:SetTextureCoords(x==1 and 0.55 or 0.918,x==1 and 0.574 or 0.942,0.14,0.38) end
            c:SetDrawLevel(5)
            edges[#edges+1]={c=c,x=x,y=y}
        end
    end end
    local function Layout()
        local w,h=parent:GetWidth(),parent:GetHeight()
        local border=math.min(44,w/3,math.max(12,h))
        local half=border/2
        local xs={-half,half,w-half,w+half}
        local ys={-half,half,h-half,h+half}
        for _,e in ipairs(edges) do
            e.c:ClearAnchors()
            if e.x==2 then
                e.c:SetAnchor(TOPLEFT,parent,TOPLEFT,half,e.y==1 and -2.5 or h-2.5)
                e.c:SetDimensions(math.max(0,w-border),5)
            elseif e.y==2 then
                e.c:SetAnchor(TOPLEFT,parent,TOPLEFT,e.x==1 and -2.5 or w-2.5,half)
                e.c:SetDimensions(5,math.max(0,h-border))
            else
                e.c:SetAnchor(TOPLEFT,parent,TOPLEFT,xs[e.x],ys[e.y])
                e.c:SetDimensions(border,border)
            end
        end
    end
    Layout()
    ZO_PostHookHandler(parent,'OnRectChanged',Layout)
end
function T.Backdrop(parent)
    local b=WINDOW_MANAGER:CreateControl(nil,parent,CT_BACKDROP)
    b:SetAnchorFill() b:SetCenterColor(0.025,0.018,0.012,0.88)
    b:SetEdgeColor(0.34,0.18,0.07,1) b:SetEdgeTexture(nil,1,1,1)
    b:SetMouseEnabled(false) b:SetDrawLayer(DL_BACKGROUND)
    return b
end
-- One owning window and one position for map, clocks and quest list.
function T.Sidebar()
    if T.sidebar then return T.sidebar end
    local saved=AlabuzyaUI.SavedVariables.Account('sidebar',{})
    local c=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUISidebar')
    c:SetDimensions(342,650)
    c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,saved.x or GuiRoot:GetWidth()-354,saved.y or 14)
    c:SetMouseEnabled(true) c:SetMovable(true) c:SetClampedToScreen(true)
    c:SetHandler('OnMoveStop',function() saved.x=c:GetLeft() saved.y=c:GetTop() end)
    T.Backdrop(c) T.Panel(c,12)
    local f=ZO_HUDFadeSceneFragment:New(c)
    HUD_SCENE:AddFragment(f) HUD_UI_SCENE:AddFragment(f)
    T.sidebar=c
    return c
end
function T.SidebarHeight(h)
    T.Sidebar():SetHeight((T.mapHeight or 406)+h)
end
function T.Separator(parent,y)
    local c=T.Texture(parent,0.62,0.88,0.068,0.096)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,8,y) c:SetAnchor(TOPRIGHT,parent,TOPRIGHT,-8,y)
    c:SetHeight(5)
end

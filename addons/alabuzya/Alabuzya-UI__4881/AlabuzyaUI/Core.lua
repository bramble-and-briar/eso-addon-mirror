local AlabuzyaUI = AlabuzyaUI
AlabuzyaUI.Core = {}
-- Original AlabuzyaUI resource display. No DiabloFrames textures or core code.
local T=AlabuzyaUI.Theme
local root,health,magicka,stamina,shield,mount,xp,compassFrame
local function Label(parent,x,y,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(CENTER,parent,CENTER,x,y) c:SetDimensions(100,28)
    c:SetHorizontalAlignment(TEXT_ALIGN_CENTER) T.Text(c,size or 19)
    c:SetMouseEnabled(false) c:SetDrawLayer(DL_OVERLAY) c:SetDrawLevel(30)
    return c
end
local function Short(n)
    return n>=1000 and string.format('%.0fk',n/1000) or tostring(math.floor(n))
end
local function Orb(parent,x,power,half,color,shared)
    local c=shared or WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    c:SetDimensions(230,230) c:SetAnchor(BOTTOM,parent,BOTTOM,x,0)
    c:SetMouseEnabled(false)
    -- Atlas orb occupies x=.065..435, y=.557..925; crop fill vertically.
    local dark=T.Texture(c,0.065,0.435,0.557,0.925,DL_BACKGROUND)
    dark:SetDimensions(154,154) dark:SetAnchor(CENTER,c,CENTER,0,3)
    dark:SetHidden(true)
    local fill=T.Texture(c,0.065,0.435,0.557,0.925,DL_CONTROLS)
    fill:SetDrawLayer(DL_OVERLAY) fill:SetDrawLevel(10)
    if half then fill:SetTexture('AlabuzyaUI/Textures/MagickaStamina.dds') end
    local bezel=T.Texture(c,0,0.5,0,0.51)
    bezel:SetAnchorFill() bezel:SetDrawLevel(20) bezel:SetHidden(true)
    local lx=half=='left' and -47 or half=='right' and 47 or 0
    local badge=T.Texture(c,0.065,0.435,0.557,0.925)
    badge:SetDesaturation(1) badge:SetColor(0.075,0.065,0.055,1)
    badge:SetDimensions(46,46) badge:SetAnchor(CENTER,c,CENTER,lx,-130)
    badge:SetDrawLevel(22)
    local rim=T.Texture(c,0,0.5,0,0.51)
    rim:SetDimensions(60,60) rim:SetAnchor(CENTER,c,CENTER,lx,-130)
    rim:SetDrawLevel(23)
    local label=Label(c,lx,-130,19)
    return {control=c,fill=fill,label=label,power=power,half=half,dark=dark,bezel=bezel}
end
local function UpdateOrb(o)
    local value,maximum=GetUnitPower('player',o.power)
    local f=maximum>0 and math.max(0,math.min(1,value/maximum)) or 0
    o.fill:ClearAnchors()
    local left=o.half=='left' local right=o.half=='right'
    -- Compensate for the transparent antialiasing at the fluid texture edges.
    o.fill:SetAnchor(BOTTOM,o.control,CENTER,left and -41.5 or right and 41.5 or 0,39)
    o.fill:SetDimensions((left or right) and 83 or 166,math.max(0.01,166*f))
    if o.half then
        o.fill:SetTextureCoords(right and 0.5 or 0.05,left and 0.5 or 0.95,0.95-0.9*f,0.95)
    else
        o.fill:SetTextureCoords(0.065,0.435,0.925-0.368*f,0.925)
    end
    o.fill:SetColor(0.72,0.72,0.72,1)
    o.fill:SetHidden(f<=0)
    o.label:SetText(Short(value))
end
local function LayoutBar()
    if not root or IsInGamepadPreferredMode() then return end
    local container=GetControl(root,'ActionBarContainer')
    AlabuzyaUI.DualBar.Layout(root,{abilitySlotWidth=44,abilitySlotOffsetX=3})
    AlabuzyaUI.Companion.ApplyPolicy()
end
-- Skin native controls; never substitute a non-interactive plus at fixed coordinates.
local function Child(c,name)
    return c and c.GetNamedChild and c:GetNamedChild(name)
end
local function ChatTab(tab,isPlus)
    if not tab or tab.alabuzyauiTabSkin then return end
    tab.alabuzyauiTabSkin=true
    local bg=T.Backdrop(tab)
    bg:ClearAnchors()
    bg:SetAnchor(TOPLEFT,tab,TOPLEFT,-3,0)
    bg:SetAnchor(BOTTOMRIGHT,tab,BOTTOMRIGHT,3,0)
    bg:SetEdgeColor(0,0,0,0)
    -- Open-bottom borders share the main window's upper edge.
    local top=T.Texture(tab,0.62,0.88,0.068,0.096,DL_BACKGROUND)
    top:SetHeight(5)
    top:SetAnchor(TOPLEFT,tab,TOPLEFT,-3,-2)
    top:SetAnchor(TOPRIGHT,tab,TOPRIGHT,3,-2)
    local right=T.Texture(tab,0.918,0.942,0.14,0.38,DL_BACKGROUND)
    right:SetWidth(5)
    right:SetAnchor(TOPRIGHT,tab,TOPRIGHT,3,0)
    right:SetAnchor(BOTTOMRIGHT,tab,BOTTOMRIGHT,3,0)
    if isPlus then
        -- SimpleIconHighlight owns the native icon and interaction handlers.
        -- Hide only its artwork, keeping the real add-tab control clickable.
        for _,name in ipairs({'Icon','Highlight'}) do
            local icon=Child(tab,name)
            if icon then icon:SetAlpha(0) end
        end
        local art=WINDOW_MANAGER:CreateControl(nil,tab,CT_TEXTURE)
        art:SetTexture('AlabuzyaUI/Textures/ChatPlus.dds')
        art:SetAnchorFill() art:SetDrawLayer(DL_OVERLAY)
        art:SetMouseEnabled(false)
        local sign=WINDOW_MANAGER:CreateControl(nil,tab,CT_LABEL)
        sign:SetFont(T.Font(26,'thick-outline'))
        sign:SetText('+') sign:SetColor(1,0.76,0.40,1)
        sign:SetAnchor(CENTER,tab,CENTER,0,-1)
        sign:SetDrawLayer(DL_OVERLAY) sign:SetDrawLevel(40)
        sign:SetMouseEnabled(false)
    else
        local label=Child(tab,'Text')
        if label then T.Text(label,20) end
    end
end
local function SkinChat()
    local system=CHAT_SYSTEM
    local primary=system and system.primaryContainer
    local chat=primary and primary.control or ZO_ChatWindow
    if not chat then return end
    if not chat.alabuzyauiLayout then
        chat.alabuzyauiLayout=true
        chat:ClearAnchors()
        chat:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT,16,-72)
        chat:SetDimensions(438,284)
        local nativeBG=Child(chat,'Bg')
        if nativeBG then nativeBG:SetAlpha(0) end
        T.Backdrop(chat)
        T.Panel(chat)
        -- Native divider is already below mail/friends/notifications.
        -- Frame the actual input controls, so channel-name changes stay aligned.
        local entry=Child(chat,'TextEntry')
        if entry then
            local label=Child(entry,'Label')
            local edit=Child(entry,'Edit')
            -- One thin input frame; no large corner ornaments over the text.
            local inputBG=T.Backdrop(entry)
            inputBG:SetCenterColor(0.035,0.022,0.018,0.94)
            if label then
                T.Text(label,18)
                label:ClearAnchors()
                label:SetAnchor(TOPLEFT,entry,TOPLEFT,10,0)
                label:SetAnchor(BOTTOMLEFT,entry,BOTTOMLEFT,10,0)
                -- Keep native auto-sizing for Say, Group, Guild and whisper targets.
                local divider=WINDOW_MANAGER:CreateControl(nil,entry,CT_TEXTURE)
                divider:SetColor(0.48,0.27,0.12,0.95)
                divider:SetWidth(1)
                divider:SetAnchor(TOPLEFT,label,TOPRIGHT,9,4)
                divider:SetAnchor(BOTTOMLEFT,label,BOTTOMRIGHT,9,-4)
                divider:SetMouseEnabled(false)
            end
            if edit and label then
                edit:ClearAnchors()
                edit:SetAnchor(TOPLEFT,label,TOPRIGHT,19,0)
                edit:SetAnchor(TOPRIGHT,entry,TOPRIGHT,-8,0)
                edit:SetCenterColor(0,0,0,0)
                edit:SetEdgeColor(0,0,0,0)
            end
        end
    end
    if primary then
        for _,window in ipairs(primary.windows or {}) do ChatTab(window.tab,false) end
        ChatTab(primary.newWindowTab,true)
        if not primary.alabuzyauiLayoutHook and ZO_PostHook then
            primary.alabuzyauiLayoutHook=true
            ZO_PostHook(primary,'PerformLayout',SkinChat)
        end
    end
end
local function HideNativeCompassFrame()
    -- These three leaves are the stock compass border, verified against ESO XML.
    -- Never force visibility of the frame or compass: their scene owns that state.
    for _,name in ipairs({'ZO_CompassFrameLeft','ZO_CompassFrameCenter','ZO_CompassFrameRight'}) do
        local texture=_G[name]
        if texture then
            texture:SetAlpha(0)
            texture:SetHidden(true)
        end
    end
end
local function SkinCompass()
    if not ZO_Compass or not ZO_CompassFrame then return end
    HideNativeCompassFrame()
    if compassFrame then return end
    -- ESO reapplies the platform template on boss-bar and input-mode changes.
    -- Hide only the decorative leaves after that operation; pins stay intact.
    if COMPASS_FRAME and COMPASS_FRAME.ApplyStyle then
        SecurePostHook(COMPASS_FRAME,'ApplyStyle',HideNativeCompassFrame)
    end
    -- Preserve ESO's frame/compass hierarchy and scene fragments.
    local frame=ZO_CompassFrame
    frame:ClearAnchors()
    frame:SetAnchor(TOP,GuiRoot,TOP,0,40)
    frame:SetDimensions(740,40)
    ZO_Compass:ClearAnchors()
    ZO_Compass:SetAnchor(TOPLEFT,frame,TOPLEFT,0,0)
    ZO_Compass:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,0,0)
    compassFrame=WINDOW_MANAGER:CreateControl('AlabuzyaUICompassFrame',ZO_Compass,CT_CONTROL)
    compassFrame:SetAnchorFill() compassFrame:SetMouseEnabled(false)
    local bg=WINDOW_MANAGER:CreateControl('AlabuzyaUICompassTrackBackground',compassFrame,CT_BACKDROP)
    -- Match the artwork opening rather than the larger native pin container.
    bg:SetDimensions(688,28)
    bg:SetAnchor(CENTER,compassFrame,CENTER,0,2)
    bg:SetCenterColor(0.10,0.10,0.11,0.65)
    bg:SetEdgeColor(0,0,0,0) bg:SetEdgeTexture(nil,1,1,1)
    bg:SetDrawLayer(DL_BACKGROUND) bg:SetDrawLevel(0)
    bg:SetMouseEnabled(false)
    local art=WINDOW_MANAGER:CreateControl('AlabuzyaUICompassArtwork',compassFrame,CT_TEXTURE)
    art:SetTexture('AlabuzyaUI/Textures/CompassFrame.dds')
    art:SetDimensions(840,200) art:SetAnchor(CENTER,compassFrame,CENTER,0,0)
    -- Below pins and text, including the central jewel.
    art:SetDrawLayer(DL_BACKGROUND) art:SetDrawLevel(1)
    art:SetMouseEnabled(false)
end
local function Update()
    if not root then return end
    UpdateOrb(health) UpdateOrb(magicka) UpdateOrb(stamina)
    if POWERTYPE_DAMAGE_SHIELD then
        local v=GetUnitPower('player',POWERTYPE_DAMAGE_SHIELD)
        shield:SetText(v>0 and ('+'..Short(v)) or '')
    end
    -- Mount stamina is intentionally omitted: it bisects the two skill rows.
    mount:SetHidden(true)
    local earned,needed=0,0
    if IsUnitChampion and IsUnitChampion('player') and GetPlayerChampionXP
            and GetPlayerChampionPointsEarned and GetNumChampionXPInChampionPoint then
        earned=GetPlayerChampionXP()
        needed=GetNumChampionXPInChampionPoint(GetPlayerChampionPointsEarned())
    elseif GetUnitXP and GetUnitXPMax then
        earned=GetUnitXP('player') needed=GetUnitXPMax('player')
    end
    xp:SetMinMax(0,math.max(1,needed or 0)) xp:SetValue(earned or 0)
end

local function HideNativeSwapDecor()
    local arrow=ZO_ActionBar1 and ZO_ActionBar1.GetNamedChild
        and ZO_ActionBar1:GetNamedChild('Arrow') or ZO_ActionBar1Arrow
    if arrow then arrow:SetHidden(true) end
    if ZO_ActionBar1WeaponSwap then
        ZO_ActionBar1WeaponSwap:SetHidden(true)
        if ZO_WeaponSwap_SetPermanentlyHidden then
            ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap,true)
        end
    end
end
function AlabuzyaUI.Core.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.StyleEnabled() then return end
    root=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUIFrameTLC')
    root:SetDimensions(1020,350) root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,0,55)
    root:SetMouseEnabled(false)
    local fragment=ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    -- One generated chassis replaces the former collection of disconnected pieces.
    local chassis=WINDOW_MANAGER:CreateControl('AlabuzyaUIChassis',root,CT_TEXTURE)
    chassis:SetTexture('AlabuzyaUI/Textures/Chassis.dds')
    chassis:SetDimensions(1020,340) chassis:SetAnchor(BOTTOM,root,BOTTOM,0,0)
    chassis:SetDrawLayer(DL_BACKGROUND) chassis:SetDrawLevel(1)
    chassis:SetMouseEnabled(false)
    local container=WINDOW_MANAGER:CreateControl('AlabuzyaUIFrameTLCActionBarContainer',root,CT_CONTROL)
    container:SetDimensions(390,44) container:SetAnchor(BOTTOM,root,BOTTOM,0,-126)
    -- Generated ring centers are x=430/1742 on the 2172 px source: ±308 at 1020 px.
    health=Orb(root,-308,POWERTYPE_HEALTH)
    magicka=Orb(root,308,POWERTYPE_MAGICKA,'left',{0.16,0.5,1,1})
    stamina=Orb(root,308,POWERTYPE_STAMINA,'right',nil,magicka.control)
    -- The two resource halves share one bezel; prevent duplicate dark backplates.
    stamina.dark:SetHidden(true) stamina.bezel:SetHidden(true)
    shield=Label(health.control,0,0,18) shield:SetColor(0.4,0.85,1,1)
    mount=WINDOW_MANAGER:CreateControl(nil,root,CT_STATUSBAR)
    mount:SetDimensions(388,5) mount:SetAnchor(BOTTOM,root,BOTTOM,0,-123)
    mount:SetColor(1,0.38,0.035,1)
    local xpBG=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
    xpBG:SetDimensions(360,9) xpBG:SetAnchor(BOTTOM,root,BOTTOM,0,-171)
    xpBG:SetCenterColor(0.015,0.01,0.008,0.96)
    xpBG:SetEdgeColor(0.30,0.13,0.035,1) xpBG:SetEdgeTexture(nil,1,1,1)
    xpBG:SetDrawLayer(DL_OVERLAY) xpBG:SetDrawLevel(11) xpBG:SetMouseEnabled(false)
    xp=WINDOW_MANAGER:CreateControl('AlabuzyaUIExperienceBar',root,CT_STATUSBAR)
    xp:SetDimensions(358,5) xp:SetAnchor(CENTER,xpBG,CENTER,0,0)
    xp:SetColor(0.94,0.28,0.025,1)
    xp:SetDrawLayer(DL_OVERLAY) xp:SetDrawLevel(12) xp:SetMouseEnabled(false)
    for i=1,9 do
        local divider=WINDOW_MANAGER:CreateControl(nil,xpBG,CT_TEXTURE)
        divider:SetColor(0.08,0.035,0.012,1)
        divider:SetDimensions(2,7)
        divider:SetAnchor(CENTER,xpBG,LEFT,i*36,0)
        divider:SetDrawLayer(DL_OVERLAY) divider:SetDrawLevel(13)
        divider:SetMouseEnabled(false)
    end
    -- Foreground pass restores claws, spikes and rim details above fluids/buttons.
    local foreground=WINDOW_MANAGER:CreateControl('AlabuzyaUIChassisForeground',root,CT_TEXTURE)
    foreground:SetTexture('AlabuzyaUI/Textures/ChassisOverlay.dds')
    foreground:SetDimensions(1020,340) foreground:SetAnchor(BOTTOM,root,BOTTOM,0,0)
    foreground:SetDrawLayer(DL_OVERLAY) foreground:SetDrawLevel(18)
    foreground:SetMouseEnabled(false)
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('AlabuzyaUI',true) end
    if ZO_ActionBar1KeybindBG then ZO_ActionBar1KeybindBG:SetHidden(true) end
    HideNativeSwapDecor()
    zo_callLater(HideNativeSwapDecor,150)
    SkinCompass()
    SkinChat()
    T.ApplyHUDFonts()
    LayoutBar() Update()
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUICore',EVENT_PLAYER_ACTIVATED,function()
        LayoutBar() Update() SkinChat() SkinCompass() T.ApplyHUDFonts() HideNativeSwapDecor()
        zo_callLater(HideNativeSwapDecor,150)
        zo_callLater(HideNativeCompassFrame,150)
    end)
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIResources',100,Update)
end

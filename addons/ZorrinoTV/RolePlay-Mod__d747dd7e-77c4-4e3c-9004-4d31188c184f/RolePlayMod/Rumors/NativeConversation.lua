if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Keep the real conversation (and its camera/idle animations) alive. No interaction is forced.
local B=IHR_Runtime.Beta
local N={};B.Native=N
local entry,entryIcon,entryHighlight,entryTooltip,hiddenControls,customTitleState
local wheelDividerState
local dialogueArea,areaViewport
local wheelAnchor,wheelViewport
local presentationWasVisible,presentationWasGamepad
local chatterActive=false
local ICON_SIZE=40
local ICON_TEXTURE='RolePlayMod/ui/conversation/dialogue.dds'
function N.IsConversing()
    return type(IsInteracting)=="function" and IsInteracting() and DoesUnitExist("interact")
        and GetUnitName("interact")~="" and not IsUnitPlayer("interact")
end
function N.IsGamepadMode()
    if type(IsInGamepadPreferredMode)=='function' and IsInGamepadPreferredMode() then return true end
    return type(IsConsoleUI)=='function' and IsConsoleUI() or false
end
local function control(value)
    if (type(value)=='table' or type(value)=='userdata') and type(value.SetHidden)=='function'
        and type(value.GetWidth)=='function' then return value end
end
local function named(owner,name)
    if owner and type(owner.GetNamedChild)=='function' then
        local ok,value=pcall(owner.GetNamedChild,owner,name)
        if ok then return control(value) end
    end
end
local function objectControl(value)
    local direct=control(value)
    if direct then return direct end
    if type(value)~='table' then return end
    direct=control(value.control) or control(value.listControl)
    if direct then return direct end
    if type(value.GetControl)=='function' then
        local ok,result=pcall(value.GetControl,value)
        if ok then return control(result) end
    end
end
local function contains(owner,child)
    for _=1,16 do
        if not child then return false end
        if child==owner then return true end
        if type(child.GetParent)~='function' then return false end
        child=child:GetParent()
    end
    return false
end
local function gamepadOptions(interaction,window,body,title,initial)
    local function valid(candidate)
        candidate=objectControl(candidate)
        if candidate and candidate~=window and candidate~=GuiRoot
            and not contains(candidate,body) and not contains(candidate,title) then return candidate end
    end
    local result=valid(initial)
    if result then return result end
    for _,key in ipairs({'optionList','options','itemList','list','optionsList','currentList'}) do
        result=valid(interaction[key])
        if result then return result end
    end
    -- ESO parametric screens can expose their list through a method instead of
    -- a fixed XML/global name. Use only getters that actually exist.
    for _,key in ipairs({'GetCurrentParametricList','GetMainList','GetList'}) do
        if type(interaction[key])=='function' then
            local ok,value=pcall(interaction[key],interaction)
            if ok then result=valid(value);if result then return result end end
        end
    end
    -- Last resort: inspect the live hierarchy, prioritising Options/Chatter
    -- over generic List names. A containing group is explicitly forbidden.
    local queue={{window,0}};local seen={};local index=1;local generic
    while index<=#queue and index<=160 do
        local item=queue[index];index=index+1
        local owner,depth=item[1],item[2]
        if owner and not seen[owner] then
            seen[owner]=true
            if owner~=window and type(owner.GetName)=='function' then
                local ok,name=pcall(owner.GetName,owner)
                if ok and type(name)=='string' then
                    name=name:lower()
                    local candidate=valid(owner)
                    if candidate and (name:find('options',1,true) or name:find('chatter',1,true)) then return candidate end
                    if candidate and not generic and name:find('list',1,true) then generic=candidate end
                end
            end
            if depth<7 and type(owner.GetNumChildren)=='function' and type(owner.GetChild)=='function' then
                local ok,count=pcall(owner.GetNumChildren,owner)
                if ok and type(count)=='number' then
                    for i=1,math.min(80,count) do
                        local found,child=pcall(owner.GetChild,owner,i)
                        if found and control(child) then queue[#queue+1]={child,depth+1} end
                    end
                end
            end
        end
    end
    return generic
end
-- Immersive Interactions moves the native controls rather than replacing the
-- dialogue scene. Resolve these handles when needed: it can initialise later.
function N.DialogueControls()
    if N.IsGamepadMode() then
        local interaction=GAMEPAD_INTERACTION or {}
        local window=control(ZO_InteractWindow_Gamepad) or control(interaction.control)
        local container=control(ZO_InteractWindow_GamepadContainer) or named(window,'Container')
        -- The native body name is also used by the installed StorySaver addon.
        -- Other children are resolved at runtime, including renamed/mixin lists.
        local body=control(ZO_InteractWindow_GamepadContainerText) or named(container,'Text')
            or named(window,'ContainerText') or control(interaction.text) or control(interaction.bodyText)
        local title=control(ZO_InteractWindow_GamepadContainerTitle) or control(ZO_InteractWindow_GamepadContainerName)
            or control(ZO_InteractWindow_GamepadTitle)
            or named(container,'Title') or named(container,'Name') or named(window,'ContainerTitle')
            or named(window,'ContainerName') or control(interaction.titleLabel) or control(interaction.title)
            or control(interaction.titleControl) or named(window,'Title')
            or named(named(window,'Header'),'Title')
        local options=gamepadOptions(interaction,window,body,title,
            control(ZO_InteractWindow_GamepadContainerOptions) or named(container,'Options') or named(window,'ContainerOptions'))
        return body,title,options,window
    end
    local handles=ImmersiveData and ImmersiveData.handles or {}
    return handles.TargetAreaBodyText or ZO_InteractWindowTargetAreaBodyText,
        handles.TargetAreaTitle or ZO_InteractWindowTargetAreaTitle,
        handles.PlayerAreaOptions or ZO_InteractWindowPlayerAreaOptions,
        handles.InteractWindow or ZO_InteractWindow
end
local function fragmentHidden(fragment)
    if not fragment then return false end
    local state=fragment.state
    if type(fragment.GetState)=='function' then
        local ok,value=pcall(fragment.GetState,fragment)
        if ok then state=value end
    end
    return state=='hidden' or state=='hiding'
        or (ZO_STATE and ((ZO_STATE.HIDDEN~=nil and state==ZO_STATE.HIDDEN)
            or (ZO_STATE.HIDING~=nil and state==ZO_STATE.HIDING))) or false
end
function N.GamepadDialogueVisible()
    if not N.IsGamepadMode() or not N.IsConversing() or fragmentHidden(GAMEPAD_INTERACT_FRAGMENT) then return false end
    local _,_,_,window=N.DialogueControls()
    -- Body/options may be locally hidden by N.Begin. Only the native parent
    -- and fragment describe X Hide/Show while the RP replacement is active.
    return window~=nil and (type(window.IsHidden)~='function' or not window:IsHidden())
end
function N.DialogueVisible()
    if N.IsGamepadMode() then return N.GamepadDialogueVisible() end
    if not N.IsConversing() or fragmentHidden(INTERACT_FRAGMENT) or (ImmersiveData and ImmersiveData.uiHidden) then return false end
    local _,_,_,window=N.DialogueControls()
    return window~=nil and (type(window.IsHidden)~='function' or not window:IsHidden())
end
function N.IsDialogueHidden() return not N.DialogueVisible() end
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge
end
local function number(control,method,fallback)
    if control and type(control[method])=='function' then
        local ok,value=pcall(control[method],control)
        if ok and finite(value) then return value end
    end
    return fallback
end
local function viewport()
    local scale=number(GuiRoot,'GetScale',1)
    if scale<=0 then scale=1 end
    return {width=number(GuiRoot,'GetWidth',1920),height=number(GuiRoot,'GetHeight',1080),
        scale=scale,left=number(GuiRoot,'GetLeft',0),top=number(GuiRoot,'GetTop',0),gamepad=N.IsGamepadMode()}
end
local function sameViewport(a,b)
    return a and b and a.width==b.width and a.height==b.height and a.scale==b.scale
        and a.left==b.left and a.top==b.top and a.gamepad==b.gamepad
end
local function rect(control,view)
    if not control then return end
    local width,height=number(control,'GetWidth',0),number(control,'GetHeight',0)
    local scale=number(control,'GetScale',view.scale)/view.scale
    if width<=0 or height<0 or scale<=0 then return end
    local x=(number(control,'GetLeft',0)-view.left)/view.scale
    local y=(number(control,'GetTop',0)-view.top)/view.scale
    return {x=x,y=y,width=width*scale,height=height*scale,
        right=x+width*scale,bottom=y+height*scale}
end
local function parent(control)
    if control and type(control.GetParent)=='function' then
        local ok,value=pcall(control.GetParent,control)
        if ok then return value end
    end
end
local function liveArea(view)
    local body,title,options,window=N.DialogueControls()
    local bodyRect=rect(body,view)
    if not bodyRect then return end
    if N.IsGamepadMode() then
        local group=rect(parent(body),view)
        if parent(body)==window or not group or group.height<80 or group.height>view.height*.9
            or group.width>view.width*.8 then group=nil end
        local left=math.max(12,(group or bodyRect).x)
        local right=math.min(view.width-20,(group or bodyRect).right)
        local top,bottom=(group or bodyRect).y,(group or bodyRect).bottom
        for _,candidate in ipairs({title or false,options or false}) do
            local r=candidate and rect(candidate,view)
            if r and r.x<right+64 and r.right>left-64 and r.height<view.height*.9 then
                top=math.min(top,r.y);bottom=math.max(bottom,r.bottom)
            end
        end
        top=math.max(0,top);bottom=math.min(view.height,bottom)
        if right<=left or bottom<=top then return end
        return {x=left,y=top,width=right-left,height=bottom-top,
            centerX=(left+right)/2,centerY=(top+bottom)/2,source='gamepad-column'}
    end
    -- The horizontal divider defines the real dialogue column, including an
    -- Immersive Interactions stream-layout offset. The body can be wider than
    -- that column and its top is only the start of the current greeting.
    local column=rect(ZO_InteractWindowDivider,view) or bodyRect
    local left=math.max(12,column.x)
    local right=math.min(view.width-20,column.right)
    if right<=left then return end
    local top,bottom
    local seen={}
    local function add(control)
        if not control or control==GuiRoot or control==window or seen[control] then return end
        seen[control]=true
        local r=rect(control,view)
        if not r or r.height<=0 or r.height>view.height*.9 then return end
        if r.right<left-64 or r.x>right+64 then return end
        local a,b=math.max(0,r.y),math.min(view.height,r.bottom)
        if b<=a then return end
        top=top and math.min(top,a) or a;bottom=bottom and math.max(bottom,b) or b
    end
    -- Capture the containing areas before greeting/options are hidden. Their
    -- union preserves the asymmetry of the native upper/lower dialogue parts.
    add(parent(body) or ZO_InteractWindowTargetArea)
    add(parent(options) or ZO_InteractWindowPlayerArea)
    if not top then add(body);add(options) end
    local source='areas'
    local handles=ImmersiveData and ImmersiveData.handles or {}
    local separator=rect(handles.VerticalSeparator or ZO_InteractWindowVerticalSeparator,view)
    if separator and separator.height>=80 and separator.height<=view.height*.9
        and separator.y>=0 and separator.bottom<=view.height
        and separator.width<=math.max(32,(right-left)*.1)
        and math.abs(separator.x-left)<=math.max(64,(right-left)*.15) then
        local plausible=not top
        if top then
            local h=bottom-top
            local overlap=math.max(0,math.min(bottom,separator.bottom)-math.max(top,separator.y))
            plausible=separator.height>=h*.55 and separator.height<=h*1.7 and overlap>=h*.5
        end
        if plausible then top=separator.y;bottom=separator.bottom;source='vertical-separator' end
    end
    if not top or bottom<=top then return end
    return {x=left,y=top,width=right-left,height=bottom-top,
        centerX=(left+right)/2,centerY=(top+bottom)/2,source=source}
end
function N.Area()
    if not N.IsConversing() then return end
    local view=viewport()
    if hiddenControls and dialogueArea and sameViewport(view,areaViewport) then return dialogueArea end
    local area=liveArea(view)
    if area and B.nativeSession then dialogueArea=area;areaViewport=view end
    return area
end
local function liveWheelAnchor(view,area)
    if N.IsGamepadMode() then
        if area then return {x=area.x,centerY=area.centerY,source='gamepad-column'} end
        return
    end
    local body=N.DialogueControls()
    local column=rect(ZO_InteractWindowDivider,view) or rect(body,view)
    if column then
        local left=math.max(12,column.x)
        local right=math.min(view.width-20,column.right)
        if right>left then
            local function fromSeparator(control)
                local separator=rect(control,view)
                -- Unlike the content-area bounds, the wheel's separator anchor
                -- is independent of greeting length. A long line next to a
                -- one-line response remains the correct visual reference.
                if separator and separator.height>=80 and separator.height<=view.height*.9
                    and separator.y>=0 and separator.bottom<=view.height
                    and separator.width<=math.max(8,math.min(32,(right-left)*.05))
                    and math.abs(separator.x-left)<=math.max(64,(right-left)*.15) then
                    return {x=separator.right+12,centerY=separator.y+separator.height/2,source='vertical-separator'}
                end
            end
            local handles=ImmersiveData and ImmersiveData.handles or {}
            local anchor=fromSeparator(handles.VerticalSeparator)
            if not anchor then anchor=fromSeparator(ZO_InteractWindowVerticalSeparator) end
            if anchor then return anchor end
        end
    end
    if area then return {x=area.x,centerY=area.centerY,source='dialogue-area'} end
end
function N.WheelAnchor()
    if not N.IsConversing() then return end
    local view=viewport()
    if hiddenControls and wheelAnchor and sameViewport(view,wheelViewport) then return wheelAnchor end
    local anchor=liveWheelAnchor(view,N.Area())
    if anchor and B.nativeSession then wheelAnchor=anchor;wheelViewport=view end
    return anchor
end
local function completeFont(face,size,option)
    if type(face)~='string' or face=='' then return end
    local descriptorSize=tonumber(face:match('^[^|]+|([%d%.]+)'))
    if descriptorSize and descriptorSize>=8 and descriptorSize<=256 then return face end
    if face:match('^ZoFont[%w_]+$') then return face end
    size=tonumber(size)
    if not face:find('|',1,true) and size and size>=8 and size<=256 then
        return face..'|'..size..'|'..(type(option)=='string' and option or '')
    end
end
local function font(control,fallback)
    if control and type(control.GetFont)=='function' then
        local ok,face,size,option=pcall(control.GetFont,control)
        if ok then local descriptor=completeFont(face,size,option);if descriptor then return descriptor end end
    end
    -- Some font-aware controls/mixins expose the FontObject getter too. Never
    -- assume that every LabelControl implements it, and never pass a bare face
    -- path to SetFont: that drops the configured size in immersive dialogues.
    if control and type(control.GetFontInfo)=='function' then
        local ok,face,size,option=pcall(control.GetFontInfo,control)
        if ok then local descriptor=completeFont(face,size,option);if descriptor then return descriptor end end
    end
    return fallback
end
local function immersiveFont(key,fallback)
    if ImmersiveFunctions and type(ImmersiveFunctions.GetSetting)=='function'
        and type(ImmersiveFunctions.GetFont)=='function' then
        local ok,enabled=pcall(ImmersiveFunctions.GetSetting,'bEnabled')
        if ok and enabled then
            local valid,value=pcall(ImmersiveFunctions.GetFont,key)
            if valid then local descriptor=completeFont(value);if descriptor then return descriptor end end
        end
    end
    return fallback
end
-- Geometry is in the same GUI coordinate space as GuiRoot anchors. GetScale
-- includes ancestor scale; GetControlScale is the control's local scale only.
-- There is no GetEffectiveScale API in ESO. Hidden labels retain their geometry.
function N.LayoutMetrics(allowInactive)
    local conversing=N.IsConversing()
    if not conversing and not allowInactive then return end
    local gamepad=N.IsGamepadMode()
    local body,title,options=N.DialogueControls()
    if not body then
        if not gamepad or not allowInactive then return end
        local view=viewport()
        local x=math.max(12,view.width*.55)
        local width=math.max(1,math.min(640,view.width-x-20))
        return {x=x,y=view.height*.15,width=width,height=0,scale=1,
            screenWidth=width,screenHeight=0,availableHeight=view.height*.85-16,
            bodyFont='ZoFontGamepad34',optionFont='ZoFontGamepad34',nameFont='ZoFontGamepad42',gamepad=true}
    end
    local rootScale=number(GuiRoot,'GetScale',1)
    if rootScale<=0 then rootScale=1 end
    local scale=number(body,'GetScale',rootScale)/rootScale
    if scale<=0 then scale=1 end
    local width=number(body,'GetWidth',0)
    if width<=0 then
        if not allowInactive then return end
        width=640 -- Fonts can already be configured before a first E dialogue.
    end
    local firstOption
    if options and type(options.GetNumChildren)=='function' and type(options.GetChild)=='function'
        and options:GetNumChildren()>0 then firstOption=options:GetChild(1) end
    -- Its complete configured descriptors also take priority during E. The
    -- native getter may expose only the face after another addon changes it.
    local bodyFont=font(body,gamepad and 'ZoFontGamepad34' or 'ZoFontGamepad22')
    local nameFont=font(title,gamepad and 'ZoFontGamepad42' or 'ZoFontGamepadBold27')
    local optionFont=font(firstOption,gamepad and 'ZoFontGamepad34' or 'ZoFontGamepad22')
    if not gamepad then
        bodyFont=immersiveFont('tab',bodyFont)
        nameFont=immersiveFont('tat',nameFont)
        optionFont=immersiveFont('opt',optionFont)
    end
    local x=(number(body,'GetLeft',0)-number(GuiRoot,'GetLeft',0))/rootScale
    local y=(number(body,'GetTop',0)-number(GuiRoot,'GetTop',0))/rootScale
    local height=number(body,'GetHeight',0)
    local screenWidth=number(GuiRoot,'GetWidth',1920)
    -- Native labels may be wider than the visible right-hand column. Centering
    -- against that clipped tail puts the wheel off screen.
    width=math.min(width,math.max(1,screenWidth-x-20)/scale)
    local gamepadLayout
    if gamepad then
        local view=viewport()
        local container=control(ZO_InteractWindow_GamepadContainer) or parent(body)
        local divider=rect(control(ZO_InteractWindow_GamepadContainerDivider) or named(container,'Divider'),view)
        if divider then
            -- The spoken reply ends above the divider; the selected response
            -- sits on the same horizontal axis as ESO's lateral NPC name.
            local nameRect=rect(title,view)
            local listRect=rect(options,view)
            local bottom=math.min(view.height-100*scale,listRect and listRect.bottom or view.height-100*scale)
            bottom=math.max(divider.bottom+80*scale,bottom)
            local center=nameRect and nameRect.y+nameRect.height/2 or (divider.bottom+bottom)/2
            gamepadLayout={dividerY=divider.y,dividerBottom=divider.bottom,
                choiceCenterY=math.max(divider.bottom+32*scale,math.min(center,bottom-32*scale)),
                bottom=bottom,bodyBottom=divider.y-24*scale,
                bodyTop=math.max(24,divider.y-math.min(300*scale,view.height*.38))}
        end
    end
    return {
        x=x,y=y,width=width,height=height,scale=scale,gamepad=gamepad,
        screenWidth=width*scale,screenHeight=height*scale,
        availableHeight=math.max(1,number(GuiRoot,'GetHeight',1080)-y-16),
        bodyFont=bodyFont,optionFont=optionFont,nameFont=nameFont,
        body=body,title=title,options=options,
        gamepadLayout=gamepadLayout,
        dialogueArea=N.Area(),
        wheelAnchor=N.WheelAnchor(),
    }
end
function N.UseCustomTitle(enabled)
    if not enabled then
        if customTitleState then
            customTitleState.control:SetHidden(customTitleState.hidden)
            customTitleState=nil
        end
        return
    end
    if customTitleState or not B.nativeSession or not N.IsConversing() then return end
    local _,title=N.DialogueControls()
    if title then
        local hidden
        if type(title.IsControlHidden)=='function' then hidden=title:IsControlHidden() else hidden=title:IsHidden() end
        customTitleState={control=title,hidden=hidden}
        title:SetHidden(true)
    end
end
function N.UseWheelPresentation(enabled)
    if not enabled then
        if wheelDividerState then
            wheelDividerState.control:SetHidden(wheelDividerState.hidden)
            wheelDividerState=nil
        end
        return
    end
    if wheelDividerState or not B.nativeSession or not N.IsGamepadMode() then return end
    local _,_,_,window=N.DialogueControls()
    local container=control(ZO_InteractWindow_GamepadContainer) or named(window,'Container')
    local divider=control(ZO_InteractWindow_GamepadContainerDivider) or named(container,'Divider')
    if divider then
        local hidden
        if type(divider.IsControlHidden)=='function' then hidden=divider:IsControlHidden() else hidden=divider:IsHidden() end
        wheelDividerState={control=divider,hidden=hidden}
        divider:SetHidden(true)
    end
end
local function settingsAllow()
    return B.saved and B.saved.enabled and B.saved.nativeConversation
end
function N.CanOpenEntry()
    if not chatterActive or not settingsAllow() or B.IsOpen() or not N.DialogueVisible() then return false end
    local body=N.DialogueControls()
    return body~=nil
end
local function hideTooltip()
    if entryTooltip then entryTooltip:SetHidden(true) end
    if entryHighlight then entryHighlight:SetHidden(true) end
    if entryIcon then entryIcon:SetColor(.88,.83,.72,1) end
end
local function canShowEntry()
    if not N.CanOpenEntry() then return false end
    -- The controller owns the manette entry and keybind strip. Keep this mouse
    -- icon exclusive to the keyboard presentation.
    if N.IsGamepadMode() or not N.DialogueVisible() then return false end
    local body,_,_,window=N.DialogueControls()
    if not body then return false end
    if window and window:IsHidden() then return false end
    if body:IsHidden() or (ImmersiveData and ImmersiveData.uiHidden) then return false end
    return true
end
local function anchorEntry()
    if not entry then return end
    local body=N.DialogueControls()
    if not body then return end
    -- Follow the actual body control, including its UI scale and any external
    -- layout. No screen-specific pixel position or 16:9 assumption is needed.
    entry:ClearAnchors()
    entry:SetAnchor(BOTTOMLEFT,body,TOPLEFT,0,-52)
end
local function snapshot(control,seen)
    if not control or seen[control] then return end
    seen[control]=true
    -- IsHidden can inherit an ancestor's hidden state. Save the local flag if
    -- available, before changing any of the selected controls.
    local hidden
    if type(control.IsControlHidden)=='function' then hidden=control:IsControlHidden()
    else hidden=control:IsHidden() end
    hiddenControls[#hiddenControls+1]={control=control,hidden=hidden}
end
function N.Begin()
    if hiddenControls then return end
    presentationWasVisible=N.DialogueVisible()
    presentationWasGamepad=N.IsGamepadMode()
    N.Area() -- Freeze the visible area before any resize-to-fit child is hidden.
    N.WheelAnchor()
    hiddenControls={}
    local seen={}
    -- The native NPC name remains visible. Never hide an area parent and then
    -- snapshot its children: inherited IsHidden would poison their restore.
    -- Only the greeting and response list are replaced by the addon UI.
    local body,_,options=N.DialogueControls()
    snapshot(body,seen);snapshot(options,seen)
    for _,state in ipairs(hiddenControls) do state.control:SetHidden(true) end
    if entry then entry:SetHidden(true) end
    hideTooltip()
end
function N.Restore()
    local hadSession=hiddenControls~=nil
    N.UseWheelPresentation(false)
    N.UseCustomTitle(false)
    for _,state in ipairs(hiddenControls or {}) do state.control:SetHidden(state.hidden) end
    hiddenControls=nil
    dialogueArea=nil;areaViewport=nil
    wheelAnchor=nil;wheelViewport=nil
    -- Its VO-ended event may already have fired while our conversation was
    -- open. Ask the optional presentation addon to reveal its native fragment;
    -- this only changes visibility and never restarts or selects dialogue.
    if hadSession and presentationWasVisible and not presentationWasGamepad and not N.IsGamepadMode()
        and chatterActive and N.IsConversing()
        and type(ImmersiveDialogue_ShowDialogue)=='function' then
        pcall(ImmersiveDialogue_ShowDialogue)
    end
    presentationWasVisible=nil;presentationWasGamepad=nil
    hideTooltip()
    anchorEntry()
    if entry then entry:SetHidden(not canShowEntry()) end
end
local function createEntry()
    if entry then return end
    entry=WINDOW_MANAGER:CreateTopLevelWindow("IHRConversationEntry")
    entry:SetDimensions(ICON_SIZE,ICON_SIZE);entry:SetMouseEnabled(true);entry:SetHidden(true)
    entry:SetClampedToScreen(true)
    if entry.SetDrawTier and DT_HIGH then entry:SetDrawTier(DT_HIGH) end
    entryHighlight=WINDOW_MANAGER:CreateControl(nil,entry,CT_BACKDROP)
    entryHighlight:SetAnchorFill();entryHighlight:SetCenterColor(.82,.69,.35,.20)
    entryHighlight:SetEdgeColor(.93,.85,.55,.8);entryHighlight:SetEdgeTexture(nil,1,1,1,1)
    entryHighlight:SetHidden(true)
    entryIcon=WINDOW_MANAGER:CreateControl(nil,entry,CT_TEXTURE)
    entryIcon:SetAnchorFill();entryIcon:SetTexture(ICON_TEXTURE);entryIcon:SetColor(.88,.83,.72,1)
    entryTooltip=WINDOW_MANAGER:CreateControl(nil,entry,CT_BACKDROP)
    entryTooltip:SetAnchor(BOTTOM,entry,TOP,0,-5);entryTooltip:SetDimensions(112,25)
    entryTooltip:SetCenterColor(.02,.018,.012,.95);entryTooltip:SetEdgeColor(.55,.48,.32,.8)
    entryTooltip:SetEdgeTexture(nil,1,1,1,1);entryTooltip:SetHidden(true)
    local tooltipLabel=WINDOW_MANAGER:CreateControl(nil,entryTooltip,CT_LABEL)
    tooltipLabel:SetAnchorFill();tooltipLabel:SetFont('ZoFontGamepad18')
    tooltipLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER);tooltipLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    tooltipLabel:SetColor(1,.96,.85,1);tooltipLabel:SetText('RolePlay Mod')
    local button=WINDOW_MANAGER:CreateControl(nil,entry,CT_BUTTON)
    button:SetAnchorFill();button:SetMouseEnabled(true);button:SetClickSound('Click')
    button:SetHandler('OnMouseEnter',function()
        entryHighlight:SetHidden(false);entryTooltip:SetHidden(false);entryIcon:SetColor(1,1,1,1)
    end)
    button:SetHandler('OnMouseExit',hideTooltip)
    button:SetHandler('OnClicked',function()
        hideTooltip()
        if canShowEntry() then B.Open(true) end
    end)
end
local function show()
    chatterActive=true
    if not settingsAllow() then return end
    createEntry()
    anchorEntry()
    -- Other dialogue addons may finish their layout later in this event.
    zo_callLater(function()
        anchorEntry()
        entry:SetHidden(not canShowEntry())
    end,200)
end
EVENT_MANAGER:RegisterForEvent("IHRNativeChatter",EVENT_CHATTER_BEGIN,show)
if EVENT_CHATTER_END then
    EVENT_MANAGER:RegisterForEvent("IHRNativeEnd",EVENT_CHATTER_END,function()
        chatterActive=false
        if B.nativeSession then B.Close() end
        if entry then entry:SetHidden(true) end
        hideTooltip()
    end)
end
local function questDialogue()
    chatterActive=false
    if B.nativeSession then B.Close() end
    if entry then entry:SetHidden(true) end
    hideTooltip()
end
EVENT_MANAGER:RegisterForEvent("IHRNativeOffer",EVENT_QUEST_OFFERED,questDialogue)
if EVENT_QUEST_COMPLETE_DIALOG then EVENT_MANAGER:RegisterForEvent("IHRNativeReward",EVENT_QUEST_COMPLETE_DIALOG,questDialogue) end
EVENT_MANAGER:RegisterForUpdate("IHRNativeWatch",250,function()
    if B.nativeSession and (not B.npc or not N.IsConversing() or B.Name(GetUnitName("interact"))~=B.npc.name) then B.Close() end
    if entry then
        anchorEntry()
        local hidden=not canShowEntry()
        entry:SetHidden(hidden)
        if hidden then hideTooltip() end
    end
end)

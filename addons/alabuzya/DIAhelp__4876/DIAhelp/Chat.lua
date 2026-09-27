-- Original chat formatting and copy helper. No pChat code included.
DIAhelpChat={}
local M=DIAhelpChat
local history,serial={},0
local copyWindow,edit
function M.Plain(text)
    return (text:gsub('|H.-|h(.-)|h','%1'):gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]',''):gsub('|t.-|t',''):gsub('|u.-|u',''))
end
local function Copy(text)
    if not copyWindow then
        copyWindow=WINDOW_MANAGER:CreateTopLevelWindow('DIAhelpChatCopy')
        copyWindow:SetDimensions(720,320) copyWindow:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        copyWindow:SetDrawTier(DT_HIGH) copyWindow:SetMouseEnabled(true) copyWindow:SetMovable(true)
        local bg=WINDOW_MANAGER:CreateControl(nil,copyWindow,CT_BACKDROP)
        bg:SetAnchorFill() bg:SetCenterColor(0.03,0.03,0.03,0.98)
        bg:SetEdgeTexture(nil,1,1,2) bg:SetEdgeColor(0.6,0.55,0.35,1)
        local title=WINDOW_MANAGER:CreateControl(nil,copyWindow,CT_LABEL)
        title:SetAnchor(TOPLEFT,copyWindow,TOPLEFT,14,8) title:SetFont('ZoFontGameBold')
        title:SetText('Ctrl+C - copy / Esc - close')
        edit=WINDOW_MANAGER:CreateControl(nil,copyWindow,CT_EDITBOX)
        edit:SetAnchor(TOPLEFT,copyWindow,TOPLEFT,14,42) edit:SetDimensions(690,222)
        edit:SetFont('ZoFontGame') edit:SetMultiLine(true) edit:SetMaxInputChars(30000)
        edit:SetMouseEnabled(true)
        local function Close() edit:LoseFocus() copyWindow:SetHidden(true) end
        edit:SetHandler('OnEscape',Close)
        local close=WINDOW_MANAGER:CreateControlFromVirtual(nil,copyWindow,'ZO_DefaultButton')
        close:SetDimensions(130,28) close:SetAnchor(BOTTOMRIGHT,copyWindow,BOTTOMRIGHT,-14,-12)
        close:SetText(GetCVar('language.2')=='ru' and 'Закрыть' or 'Close')
        close:SetHandler('OnClicked',Close)
    end
    copyWindow:SetHidden(false) edit:SetText(text) edit:TakeFocus() edit:SelectAll()
end
local palette={}
local function Color(name,r,g,b)
    local category=_G[name] if category then palette[category]={r,g,b} end
end
EVENT_MANAGER:RegisterForEvent('DIAhelpChat',EVENT_ADD_ON_LOADED,function(_,name)
    if name~='DIAhelp' then return end
    EVENT_MANAGER:UnregisterForEvent('DIAhelpChat',EVENT_ADD_ON_LOADED)
    -- Respect a deliberately enabled standalone chat replacement.
    if pChat then return end
    Color('CHAT_CATEGORY_SAY',0.92,0.90,0.78)
    Color('CHAT_CATEGORY_ZONE',0.85,0.81,0.59)
    Color('CHAT_CATEGORY_PARTY',0.55,0.80,1)
    Color('CHAT_CATEGORY_SYSTEM',1,0.9,0.35)
    Color('CHAT_CATEGORY_WHISPER_INCOMING',0.95,0.6,0.95)
    Color('CHAT_CATEGORY_WHISPER_OUTGOING',0.95,0.6,0.95)
    for i=1,5 do Color('CHAT_CATEGORY_GUILD_'..i,0.45,0.88,0.57) Color('CHAT_CATEGORY_OFFICER_'..i,0.4,0.9,0.8) end
    for _,lang in ipairs({'ENGLISH','FRENCH','GERMAN','RUSSIAN','SPANISH','JAPANESE','CHINESE_S'}) do Color('CHAT_CATEGORY_ZONE_'..lang,0.85,0.81,0.59) end
    local original=SharedChatContainer.AddMessageToWindow
    SharedChatContainer.AddMessageToWindow=function(self,window,message,r,g,b,category,...)
        if type(message)=='string' and not message:find('|H1:diachat:',1,true) then
            local seconds=GetSecondsSinceMidnight()
            local stamp=string.format('[%02d:%02d]',math.floor(seconds/3600)%24,math.floor(seconds/60)%60)
            serial=serial+1 history[serial]=stamp..' '..M.Plain(message)
            history[serial-5000]=nil
            message='|c999999|H1:diachat:'..serial..'|h'..stamp..'|h|r '..message
        end
        local color=palette[category]
        if color then r,g,b=unpack(color) end
        return original(self,window,message,r,g,b,category,...)
    end
    local function Click(_,button,_,_,kind,id)
        if kind~='diachat' then return end
        local text=history[tonumber(id)]
        if text and button==MOUSE_BUTTON_INDEX_RIGHT then
            ClearMenu()
            AddMenuItem(GetCVar('language.2')=='ru' and 'Копировать сообщение' or 'Copy message',function() Copy(text) end)
            ShowMenu()
        end
        return true
    end
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT,Click)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT,Click)
end)

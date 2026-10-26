local A=ALTHarvestItems
-- Item identities only; names, quality and icons always come from the client.
-- Perfect Roe is reserved for the future fishing/filleting module. Registering
-- its ID here does not admit it into the resource session or invent a source.
A.rareNoticeIds={ [45854]=true,[115026]=true,[64222]=true,[56862]=true,[56863]=true,[139411]=true }
function A:ClearNotices()
    EVENT_MANAGER:UnregisterForUpdate("ALTHIRareNotice")
    self.noticeQueue={}; self.activeNotice=nil
    if self.noticeWindow then self.noticeWindow:SetHidden(true) end
end
function A:CreateNoticeWindow()
    if self.noticeWindow then return end
    local window=WINDOW_MANAGER:CreateTopLevelWindow("ALTHIRareNotice")
    local screenWidth,screenHeight=GuiRoot:GetWidth() or 1920,GuiRoot:GetHeight() or 1080
    local scale=0.6*math.max(1,math.min(5,(screenHeight*2/3-24)/128))
    local width=math.max(100,(screenWidth-48)/scale)
    window:SetDimensions(width*scale,128*scale)
    window:SetAnchor(CENTER,GuiRoot,TOPLEFT,screenWidth/2,screenHeight/3)
    window:SetMouseEnabled(false); window:SetKeyboardEnabled(false); window:SetDrawTier(DT_HIGH)
    local content=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
    content:SetDimensions(width,128); content:SetAnchor(TOPLEFT,window,TOPLEFT,0,0); content:SetScale(scale)
    content:SetMouseEnabled(false); window.content=content
    window.icon=WINDOW_MANAGER:CreateControl(nil,content,CT_TEXTURE)
    window.icon:SetDimensions(72,72); window.icon:SetAnchor(TOPLEFT,content,TOPLEFT,(width-72)/2,0)
    window.icon:SetMouseEnabled(false)
    window.text=self:Label(content,"ZoFontWinH2")
    window.text:SetAnchor(TOPLEFT,content,TOPLEFT,0,76); window.text:SetDimensions(width,52)
    window.text:SetHorizontalAlignment(TEXT_ALIGN_CENTER); window.text:SetMaxLineCount(2)
    window.text:SetMouseEnabled(false)
    window:SetHidden(true); self.noticeWindow=window
end
function A:NoticeText(notice)
    local name=GetItemQualityColor(notice.quality):Colorize(notice.name)
    local text=string.format(self:T("S_WAS_COLLECTED"),name)
    if notice.count>1 then text=text.."  ×"..self.Integer(notice.count) end
    if notice.preview then text=self:T("PREVIEW")..text end
    return text
end
function A:NextNotice()
    local notice=table.remove(self.noticeQueue,1)
    if not notice then
        self.activeNotice=nil; self.noticeWindow:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate("ALTHIRareNotice"); return
    end
    self.activeNotice=notice; notice.started=self.Now()
    self.noticeWindow.icon:SetTexture(notice.icon)
    self.noticeWindow.text:SetText(self:NoticeText(notice))
    self.noticeWindow:SetAlpha(0); self.noticeWindow:SetHidden(false); self.noticeWindow:BringWindowToTop()
    -- Quiet native menu cue, not an achievement fanfare or an error sound.
    if PlaySound and SOUNDS and SOUNDS.MENU_BAR_CLICK then PlaySound(SOUNDS.MENU_BAR_CLICK) end
end
function A:NotifyRare(link,count,preview)
    local id=self.ValidId(GetItemLinkItemId(link))
    if not id or not self.rareNoticeIds[id] then return false end
    count=tonumber(count)
    if not count or count<=0 or count~=math.floor(count) then return false end
    local name=zo_strformat("<<C:1>>",GetItemLinkName(link))
    if not name or name=="" then return false end
    self:CreateNoticeWindow(); self.noticeQueue=self.noticeQueue or {}
    -- Combine rapid repeats without prolonging a popup indefinitely.
    local active=self.activeNotice
    if active and active.id==id and active.preview==preview and self.Now()-active.started<2.6 then
        active.count=active.count+count; self.noticeWindow.text:SetText(self:NoticeText(active)); return true
    end
    for _,notice in ipairs(self.noticeQueue) do
        if notice.id==id and notice.preview==preview then notice.count=notice.count+count; return true end
    end
    self.noticeQueue[#self.noticeQueue+1]={id=id,name=name,icon=GetItemLinkIcon(link),
        quality=GetItemLinkDisplayQuality(link),count=count,preview=preview}
    if not self.activeNotice then
        self:NextNotice()
        EVENT_MANAGER:RegisterForUpdate("ALTHIRareNotice",40,function()
            local current=self.activeNotice
            if not current then return end
            local elapsed=self.Now()-current.started
            if elapsed>=3.6 then self:NextNotice(); return end
            self.noticeWindow:SetAlpha(math.max(0,math.min(1,elapsed/0.2,(3.6-elapsed)/0.6)))
        end)
    end
    return true
end

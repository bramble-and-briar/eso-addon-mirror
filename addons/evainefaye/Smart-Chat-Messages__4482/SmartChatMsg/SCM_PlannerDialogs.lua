-- Account settings and transfer tools use native planner controls and private drafts.
SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local UI=S.PlannerUI
local function modal(self,key,w,h)
    local c=UI.box(self.plannerWindow,key,0,0,w,h,true)
    c:ClearAnchors();c:SetAnchor(CENTER,self.plannerWindow,CENTER,0,0)
    c:SetDrawTier(DT_HIGH);c:SetMouseEnabled(true);UI.hide(c)
    return c
end
function S:RefreshPlannerAfterExternalChange()
    local old=self.plannerModel
    if old then
        self.plannerModel=self:CreatePlannerDraft(old.commandId,old.guild)
        self.plannerModel.tab=old.tab
        self:SelectPlannerPeriod(self.plannerModel,old.periodId)
    end
    self:RefreshEventPlanner()
end
function S:ShowPlannerConfirmation(title,text,accept,cancel)
    local c=modal(self,'confirmation',600,230)
    UI.label(c,'title',title,20,16,560,32,true)
    UI.label(c,'body',text,20,58,560,104)
    UI.button(c,'accept','Confirm',20,182,265,function()c:SetHidden(true);accept()end,true)
    UI.button(c,'cancel','Cancel',305,182,275,function()c:SetHidden(true);if cancel then cancel() end end)
    return c
end
function S:OpenPlannerGlobalSettings()
    self:RequestPlannerAction(function()
        -- Opening after the discard prompt actually replaces the discarded draft.
        self:RefreshPlannerAfterExternalChange()
        local draft={guild=self:GetDefaultGuildIndex() or 0,zone=self:GetSchedulingTimeZone(),seconds=self:GetRevertChatSeconds()}
        local c=modal(self,'globalSettings',680,482)
        c.draft=draft
        UI.label(c,'title','Global settings',22,16,636,32,true)
        UI.label(c,'help','Account defaults apply to all commands. Changes take effect only when you Save.',22,57,636,52)
        local labels,values={'None'},{0}
        for _,option in ipairs(self:GetDefaultGuildOptions())do
            if option.value then labels[#labels+1]=option.name;values[#values+1]=option.value end
        end
        UI.label(c,'guildLabel','Default guild',22,111,636,26)
        UI.combo(c,'guild',labels,values,draft.guild,22,141,636,function(v)draft.guild=v end,'Guild used when a command does not specify a guild. None clears the default.')
        UI.label(c,'zoneLabel','Default scheduling timezone',22,188,636,26)
        UI.combo(c,'zone',{'Eastern (ET)','Central (CT)','Mountain (MT)','Pacific (PT)'},{'ET','CT','MT','PT'},draft.zone,22,218,636,function(v)draft.zone=v end)
        UI.label(c,'zoneHelp','US daylight saving applies automatically. Schedules using the global default keep their clock times in the new zone. Explicit guild timezones and timezone text in messages keep their values.',22,258,636,72)
        UI.slider(c,'seconds','Auto-remove pending chat after',draft.seconds,30,300,22,336,636,function(v)draft.seconds=v end,function(v)return v..' seconds'end,'Clears unsent prepared chat and restores its previous channel after 30 seconds to 5 minutes.')
        local errorLabel=UI.label(c,'error','',22,400,636,25)
        UI.button(c,'save','Save',22,438,304,function()
            if type(draft.seconds)~='number' or draft.seconds<30 or draft.seconds>300 or draft.seconds~=math.floor(draft.seconds) then errorLabel:SetText('Choose a whole number of seconds from 30 to 300.');return end
            local ok,reason=self:SetSchedulingTimeZone(draft.zone)
            if not ok then errorLabel:SetText(tostring(reason));return end
            self:SetDefaultGuildIndex(draft.guild~=0 and draft.guild or nil)
            self:SetRevertChatSeconds(draft.seconds)
            c:SetHidden(true);self:RefreshPlannerAfterExternalChange()
        end,true)
        UI.button(c,'cancel','Cancel',346,438,312,function()c:SetHidden(true)end)
    end)
end
function S:OpenPlannerTransfer()
    local c=modal(self,'transfer',820,580)
    UI.label(c,'title','Import / export settings',22,16,776,32,true)
    UI.label(c,'help','Export copies saved settings only. Save your event draft first. Import merges commands, messages and settings; existing data is retained. Paste an export below, then review the confirmation.',22,58,776,76)
    local text=self.plannerTransferText or ''
    local box=UI.edit(c,'text',text,22,140,776,330,function(v)text=v;self.plannerTransferText=v end,true,nil,300000)
    box.edit:SetMaxInputChars(300000)
    local status=UI.label(c,'status','',22,480,776,40)
    local function selectAll()
        box.edit:TakeFocus();box.edit:SelectAll()
        status:SetText('All text selected. Press Ctrl+C to copy it to your clipboard.')
    end
    UI.button(c,'export','Export',22,532,144,function()
        if self.plannerModel and self.plannerModel.dirty then status:SetText('Save your event draft before exporting. Your draft is still open and unchanged.');return end
        text=self:BuildExportString();self.plannerTransferText=text;box.edit:SetText(text)
        selectAll()
    end)
    UI.button(c,'selectAll','Select all',180,532,144,selectAll,false,'Focus and select the entire text, including lines outside the visible box. Then press Ctrl+C.')
    UI.button(c,'import','Import',338,532,144,function()
        text=box.edit:GetText();self.plannerTransferText=text
        if self:Trim(text)=='' then status:SetText('Paste exported settings first.');return end
        self:RequestPlannerAction(function()
            self:ShowPlannerConfirmation('Merge imported settings?','This merges the pasted export into your saved settings. Existing commands and messages are retained. Confirm to apply the import.',function()
                local ok,reason=self:ImportSettingsFromString(text)
                if not ok then c:SetHidden(false);status:SetText(tostring(reason or 'Import failed.'));return end
                self:RefreshPlannerAfterExternalChange();c:SetHidden(false);status:SetText('Import complete. Saved settings and the selected event have been refreshed.')
            end)
        end)
    end,true)
    UI.button(c,'clear','Clear',496,532,144,function()text='';self.plannerTransferText='';box.edit:SetText('');status:SetText('')end)
    UI.button(c,'cancel','Cancel',654,532,144,function()c:SetHidden(true)end)
    return c
end

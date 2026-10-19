-- ESO adapter for ShareSession.lua. No chat messages are sent to other players.
local addon, T, S = PBS_TRANSLATE, PBsTranslate, PBsTranslateShare
if not addon or not S then return end
local UI = { hooked = {} }
addon.sharing = UI
-- Registered at https://wiki.esoui.com/LibGroupBroadcast_IDs (460-469 are PinkBanther's block).
-- Both peers must use the same id and name, so never change them for a released version.
UI.PROTOCOL_ID = 462
UI.PROTOCOL_NAME = "PBsTranslateDictionary"
-- A share is started from the interaction wheel, /pbshare or the settings panel. The social
-- menus are not hooked. On the wheel, only AddMenuEntry is post-hooked: a hook on
-- ShowPlayerInteractMenu raised a private-function error on console (1.1.2-dev), while the
-- AddMenuEntry hook ran without trouble on a PS5 (1.1.9-dev).
local jp = not GetCVar or GetCVar("language.2") == "jp"
local function L(ja,en) return jp and ja or en end
local TITLE = L("辞書内容を共有", "Share dictionary")
local CANCEL = L("キャンセル", "Cancel")
local errors = {
    busy=L("共有中、または取り込み待ちの辞書があります。", "A transfer or dictionary review is already pending."),
    group=L("同じグループのオンラインの相手を選んでください。", "Choose an online member of your group."),
    empty=L("自分で登録した辞書がありません。", "Your personal dictionary is empty."),
    limit=L("1回の共有は200件・16KBまでです。", "A transfer is limited to 200 entries and 16 KB."),
    invalid=L("共有できない辞書データです。文字数・品詞・制御文字を確認してください。", "Invalid dictionary data. Check lengths, part of speech and control characters."),
    transport=L("共有通信が利用できません。LibGroupBroadcastの導入・設定を確認してください。", "Sharing is unavailable. Check LibGroupBroadcast and its settings."),
    timeout=L("相手から応答がありません。共有対応版・通信設定を確認してやり直してください。", "The peer did not respond. Check compatible versions and communication settings, then retry."),
    cancelled=L("辞書共有を中止しました。", "Dictionary transfer cancelled."),
    combat=L("戦闘中は辞書共有を開始できません。", "Dictionary sharing cannot start in combat."),
}
local function Say(text) UI.lastMessage=text;if addon.Say then addon.Say("[PBs] "..text) end end
local function Name(value) return T.Lower(T.Trim(value or "")) end
local function Now() return GetFrameTimeSeconds() end
local function Later(fn) if zo_callLater then zo_callLater(fn,200) else fn() end end
function UI:Resolve(name)
    if type(name)~="string" or name=="" or not GetGroupSize then return nil end
    for i=1,GetGroupSize() do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local display=GetUnitDisplayName(tag)
            if Name(display)==Name(name) or Name(GetUnitName(tag))==Name(name) then
                if Name(display)~=Name(GetDisplayName()) and (not IsUnitOnline or IsUnitOnline(tag)) then return display end
            end
        end
    end
end
function UI:Show(text,buttons,onDismiss)
    if not ZO_Dialogs_ShowPlatformDialog or not self.dialogReady then Say(text);return end
    local data={text=text,buttons=buttons,onDismiss=onDismiss}
    Later(function() ZO_Dialogs_ShowPlatformDialog("PBSTR_SHARE_DIALOG",data) end)
end
function UI:InitDialog()
    if not ZO_Dialogs_RegisterCustomDialog or not GAMEPAD_DIALOGS then return end
    local buttons={}
    for index,key in ipairs({"DIALOG_PRIMARY","DIALOG_SECONDARY","DIALOG_NEGATIVE"}) do
        local i=index
        buttons[i]={keybind=key,
            text=function(dialog) local b=dialog.data.buttons[i];return b and b.text or "" end,
            visible=function(dialog) return dialog.data.buttons[i]~=nil end,
            callback=function(dialog) local b=dialog.data.buttons[i];if b and b.callback then Later(b.callback) end end}
    end
    ZO_Dialogs_RegisterCustomDialog("PBSTR_SHARE_DIALOG",{
        canQueue=true,gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text=TITLE},
        mainText={text=function(dialog) return dialog.data.text end},buttons=buttons,
        noChoiceCallback=function(dialog) if dialog.data.onDismiss then dialog.data.onDismiss() end end,
    })
    self.dialogReady=true
end
function UI:InitTransport()
    if self.protocol then return true end
    if self.transportAttempted then return false end
    local lib=LibGroupBroadcast
    if not lib or not lib.RegisterHandler or not lib.CreateStringField then return false end
    self.transportAttempted=true
    local ok, result=pcall(function()
        local handler=lib:RegisterHandler(addon.name)
        handler:SetDisplayName(TITLE)
        local p=handler:DeclareProtocol(self.PROTOCOL_ID,self.PROTOCOL_NAME)
        p:SetDisplayName(TITLE)
        p:AddField(lib.CreateNumericField("magic",{numBits=32}))
        p:AddField(lib.CreateNumericField("target",{numBits=32}))
        p:AddField(lib.CreateNumericField("sid",{numBits=24}))
        p:AddField(lib.CreateNumericField("kind",{numBits=3}))
        p:AddField(lib.CreateNumericField("seq",{numBits=16}))
        p:AddField(lib.CreateStringField("text",{maxLength=96}))
        p:OnData(function(tag,data)
            local peer=GetUnitDisplayName(tag)
            if not self.protocol or not self.protocol:IsEnabled() or (IsIgnored and IsIgnored(peer)) then return end
            if type(data)=="table" and data.kind==S.OFFER and addon.sv.shareAllowRequests==false then return end
            if self.session then self.session:Receive(peer,data) end
        end)
        if not p:Finalize({isRelevantInCombat=false,replaceQueuedMessages=false}) then error("protocol finalization failed") end
        return p
    end)
    if ok then self.protocol=result else self.transportError=tostring(result) end
    return self.protocol~=nil
end
function UI:CanSend()
    return self:InitTransport() and self.protocol:IsEnabled()
end
function UI:Start(peer)
    if IsUnitInCombat and IsUnitInCombat("player") then Say(errors.combat);return end
    if not self:CanSend() then
        if self.transportError and self.transportError:find("already exists",1,true) then
            Say(string.format(L("通信ID %d を別のアドオンが使っているため、辞書共有を利用できません。", "Dictionary sharing is unavailable: another add-on uses protocol ID %d."),self.PROTOCOL_ID))
        else Say(errors.transport) end
        return
    end
    peer=self:Resolve(peer)
    if not peer then Say(errors.group);return end
    if self.session.active or self.session.review then Say(errors.busy);return end
    local data,count=S.Encode(addon.sv.userWords)
    if not data then Say(errors[count]);return end
    -- Snapshot exactly what the sender approved; edits while confirming are excluded.
    local words=S.Decode(data,count)
    local keys,preview={},{}
    for key in pairs(words) do keys[#keys+1]=key end
    table.sort(keys)
    for i=1,math.min(#keys,5) do
        local key=keys[i]
        preview[#preview+1]=key.." = "..words[key]
    end
    if #keys>5 then preview[#preview+1]=string.format(L("ほか%d件","%d more entries"),#keys-5) end
    local details="\n\n"..L("共有する登録内容：","Entries to share:").."\n"..table.concat(preview,"\n")
    self:Show(string.format(L("%s に自分の登録辞書 %d件を共有します。\n相手の承諾後に転送します。転送中はグループを維持してください。\nグループ通信のため、データはグループ全体へ配信され、選んだ相手のアドオンが取り込みます。", "Share %d personal entries with %s? The peer must accept first. Stay grouped during transfer. Data is broadcast to the whole group; the selected recipient imports it."), jp and peer or count, jp and count or peer)..details,{
        {text=L("共有する","Share"),callback=function()
            if IsUnitInCombat and IsUnitInCombat("player") then Say(errors.combat);return end
            local ok,reason=self.session:Start(peer,words)
            if not ok then Say(errors[reason]) end
        end},
        {text=CANCEL},
    })
end
function UI:Offer(state)
    self:Show(string.format(L("%s から辞書 %d件（%dバイト）の共有依頼です。\n受信しても、内容を確認して取り込むまで辞書は変わりません。", "%s offers %d entries (%d bytes). Your dictionary is unchanged until you review and import."),state.peer,state.count,state.bytes),{
        {text=L("受信する","Receive"),callback=function()
            if self.session.active~=state then return end
            if IsUnitInCombat and IsUnitInCombat("player") then self.session:Cancel("combat");return end
            self.session:Accept()
        end},
        {text=L("辞退する","Decline"),callback=function() if self.session.active==state then self.session:Cancel() end end},
    },function() if self.session.active==state then self.session:Cancel() end end)
end
function UI:Review(page)
    local review=self.session.review
    if not review then Say(L("取り込み待ちの辞書はありません。","No dictionary is waiting for review."));return end
    local keys={};for k in pairs(review.words) do keys[#keys+1]=k end;table.sort(keys)
    local pages=math.ceil(#keys/3)
    page=math.max(1,math.min(page or 1,pages))
    local lines={string.format(L("%s の辞書：%d / %d ページ","Dictionary from %s: page %d / %d"),review.peer,page,pages)}
    for i=(page-1)*3+1,math.min(page*3,#keys) do
        local k=keys[i];local old=addon.sv.userWords[k]
        lines[#lines+1]="\n"..k.." = "..review.words[k]
        if old and old~=review.words[k] then
            -- Local text might contain markup; do not let it become a link in this dialog.
            lines[#lines+1]=L("現在：","Current: ")..old:gsub("|","｜")
        elseif old then lines[#lines+1]=L("登録済み（同じ内容）","Already registered (identical)") end
    end
    self:Show(table.concat(lines,"\n"),{
        {text=page<pages and L("次のページ","Next page") or L("最初のページ","First page"),callback=function() if self.session.review==review then self:Review(page<pages and page+1 or 1) end end},
        {text=L("取り込み方法を選ぶ","Import options"),callback=function() if self.session.review==review then self:ImportOptions() end end},
        {text=L("閉じる（保留）","Close (keep pending)")},
    })
end
function UI:ImportOptions()
    local review=self.session.review;if not review then return end
    local _,added,_,same,conflicts=S.Merge(addon.sv.userWords,review.words,false)
    self:Show(string.format(L("新規 %d件・同じ内容 %d件・訳が異なるもの %d件。\n新規のみ追加：既存の訳を維持します。\n上書きも行う：訳が異なる項目も受信した訳に変更します。", "New: %d. Identical: %d. Conflicts: %d.\nAdd new only keeps existing translations. Overwrite also replaces conflicts."),added,same,conflicts),{
        {text=L("新規のみ追加","Add new only"),callback=function() self:Import(review,false) end},
        {text=L("上書きも行う","Include overwrites"),callback=function() self:ConfirmOverwrite(review) end},
        {text=L("内容へ戻る","Back to review"),callback=function() if self.session.review==review then self:Review() end end},
    })
end
function UI:ConfirmOverwrite(review)
    if self.session.review~=review then return end
    self:Show(L("同じ英語に別の訳を登録している項目も上書きします。実行しますか？\n直前の辞書はバックアップに保存します。", "Replace conflicting translations too? A backup of your current dictionary will be saved."),{
        {text=L("上書きして取り込む","Import and overwrite"),callback=function() self:Import(review,true) end},
        {text=CANCEL},
    })
end
function UI:Import(review,overwrite)
    if self.session.review~=review then return end
    -- Revalidate and merge against current words, including edits made during preview.
    local encoded,count=S.Encode(review.words)
    if not encoded or not S.Decode(encoded,count) then Say(errors.invalid);return end
    local merged,added,replaced,_,skipped=S.Merge(addon.sv.userWords,review.words,overwrite)
    if not T.CheckUserWordBudget(merged) then Say(GetString(SI_PBSTR_ERROR_WORD_BUDGET));return end
    addon.sv.shareBackup={};for k,v in pairs(addon.sv.userWords) do addon.sv.shareBackup[k]=v end
    addon.sv.userWords=merged;addon:ApplyUserWords()
    self.session.review=nil
    Say(string.format(L("取り込み完了：追加%d件、上書き%d件、既存維持%d件。", "Imported: %d new, %d overwritten, %d conflicts kept."),added,replaced,skipped))
end
function UI:Restore()
    if not addon.sv.shareBackup then Say(L("復元できるバックアップがありません。","No backup to restore."));return end
    self:Show(L("辞書を直前の取り込み前へ戻します。取り込み後の手動登録も元に戻ります。", "Restore the dictionary before the last import? This also undoes manual edits made since."),{
        {text=L("復元する","Restore"),callback=function()
            local words=addon.sv.shareBackup
            if words and not T.CheckUserWordBudget(words) then Say(GetString(SI_PBSTR_ERROR_WORD_BUDGET));return end
            if words then addon.sv.userWords=words;addon.sv.shareBackup=nil;addon:ApplyUserWords();Say(L("復元しました。","Restored.")) end
        end}, {text=CANCEL},
    })
end
function UI:Notify(event,state)
    if self.session.active and not self.timerActive then
        EVENT_MANAGER:RegisterForUpdate(addon.name.."Sharing",1000,function() self.session:Tick() end)
        self.timerActive=true
    elseif not self.session.active and self.timerActive then
        EVENT_MANAGER:UnregisterForUpdate(addon.name.."Sharing")
        self.timerActive=false
    end
    if event=="offer" then self:Offer(state)
    elseif event=="review" then Say(L("辞書を受信しました。内容を確認して取り込んでください。","Dictionary received. Review before importing."));self:Review()
    elseif event=="sending" then Say(L("共有を依頼しました。相手の承諾を待っています。","Share request sent. Waiting for acceptance."))
    elseif event=="receiving" then Say(L("辞書を受信中です。","Receiving dictionary."))
    elseif event=="progress" then
        local size=state.direction=="send" and #state.data or state.bytes
        local done=state.direction=="send" and math.min(math.max(0,state.seq-1)*S.CHUNK,size) or state.size
        self.lastMessage=string.format(L("転送中：%d / %d バイト", "Transferring: %d / %d bytes"),done,size)
    elseif event=="delivered" then Say(L("相手への転送が完了しました。取り込みは相手の確認待ちです。","Delivery complete. Import is up to the recipient."))
    elseif event~="progress" then
        if ZO_Dialogs_ReleaseAllDialogsOfName then ZO_Dialogs_ReleaseAllDialogsOfName("PBSTR_SHARE_DIALOG") end
        Say(errors[event] or errors.transport)
    end
end
function UI:Status()
    local state=self.session.active
    if state then
        local size=state.direction=="send" and #state.data or state.bytes
        local done=state.direction=="send" and math.min(math.max(0,state.seq-1)*S.CHUNK,size) or state.size
        Say(string.format(L("%s：%d / %d バイト。/pbshare cancel で中止できます。","%s: %d / %d bytes. /pbshare cancel to cancel."),state.peer,done,size))
    elseif self.session.review then self:Review()
    else Say(L("共有待機中。/pbshare @名前 で共有、review で受信内容、restore で復元。","Ready. /pbshare @name to share; review to inspect; restore to restore a backup.")) end
end
-- Online group members other than you, for the panel's recipient list.
function UI:GroupMembers()
    local members={}
    if not GetGroupSize then return members end
    for i=1,GetGroupSize() do
        local tag=GetGroupUnitTagByIndex(i)
        local display=tag and GetUnitDisplayName(tag)
        if display and display~="" and Name(display)~=Name(GetDisplayName()) and (not IsUnitOnline or IsUnitOnline(tag)) then
            members[#members+1]=display
        end
    end
    table.sort(members)
    return members
end
-- Never empty: the library selects an entry by name, so an empty group gets a placeholder.
function UI:MemberItems()
    local items={}
    for _,display in ipairs(self:GroupMembers()) do items[#items+1]={name=display,data=display} end
    if #items==0 then items[1]={name=L("（グループに相手がいません）","(nobody else in your group)"),data=nil} end
    return items
end
function UI:InitInteractMenu()
    local object=PLAYER_TO_PLAYER
    if not ZO_PostHook or not object or self.hooked[object]
        or type(object.AddMenuEntry)~="function" or type(object.GetRadialMenu)~="function" then return end
    -- Never wrap ShowPlayerInteractMenu: it invokes private console APIs and must
    -- retain ESO's secure calling context. AddMenuEntry only appends a UI entry.
    -- The native Trade entry has already checked ignore/communication restrictions.
    ZO_PostHook(object,"AddMenuEntry",function(owner,text,_,enabled)
        if text~=GetString(SI_PLAYER_TO_PLAYER_INVITE_TRADE) or not enabled then return end
        local peer=owner.currentTargetDisplayName
        if type(peer)~="string" or peer=="" or Name(peer)==Name(GetDisplayName()) then return end
        local menu=owner:GetRadialMenu()
        if not menu or type(menu.entries)~="table" then return end
        local label=L("辞書データを共有","Share dictionary data")
        for _,entry in ipairs(menu.entries) do
            if entry.name==label then return end
        end
        local gamepad=IsInGamepadPreferredMode and IsInGamepadPreferredMode()
        local normal=gamepad and "EsoUI/Art/HUD/Gamepad/gp_radialIcon_whisper_down.dds" or "EsoUI/Art/HUD/radialIcon_whisper_up.dds"
        local selected=gamepad and normal or "EsoUI/Art/HUD/radialIcon_whisper_over.dds"
        local icons={enabledNormal=normal,enabledSelected=selected,disabledNormal=normal,disabledSelected=selected}
        owner:AddMenuEntry(label,icons,true,function()
            -- Capture this account; the reticle may point elsewhere by execution.
            Later(function() self:Start(peer) end)
        end)
    end)
    self.hooked[object]=true
end
function UI:InitSettings()
    local settings,lib=addon.settingsControls,LibHarvensAddonSettings
    if not settings or not lib then return end
    settings:AddSetting({type=lib.ST_LABEL,label=L("辞書共有（グループ内）","Dictionary sharing (group)")})
    settings:AddSetting({type=lib.ST_CHECKBOX,label=L("辞書の共有依頼を受け付ける","Allow dictionary share requests"),default=true,
        getFunction=function() return addon.sv.shareAllowRequests~=false end,
        setFunction=function(value)
            addon.sv.shareAllowRequests=value
            if not value and self.session.active and self.session.active.direction=="receive" then self.session:Cancel() end
        end})
    local function Button(label,fn) settings:AddSetting({type=lib.ST_BUTTON,label=label,buttonText=label,clickHandler=fn}) end
    if lib.ST_DROPDOWN then
        -- Items is a function so the list follows the group each time the panel refreshes.
        settings:AddSetting({type=lib.ST_DROPDOWN,label=L("共有する相手","Share with"),
            tooltip=L("同じグループのオンラインの相手から選びます。","Pick an online member of your group."),
            items=function() return self:MemberItems() end,ignoreDefault=true,
            getFunction=function()
                local items=self:MemberItems()
                for _,item in ipairs(items) do if item.data==self.target then return item.name end end
                self.target=items[1].data
                return items[1].name
            end,
            setFunction=function(_,_,item) self.target=item and item.data or nil end})
        Button(L("選んだ相手に辞書を共有","Share dictionary with selected member"),function()
            if not self.target then Say(errors.group) else self:Start(self.target) end
            addon:RefreshPanel()
        end)
    end
    settings:AddSetting({type=lib.ST_LABEL,label=function() return self.lastMessage or L("共有待機中", "Ready to share") end})
    Button(L("受信した辞書を確認","Review received dictionary"),function() self:Review() end)
    Button(L("転送状況を確認","Transfer status"),function() self:Status() end)
    Button(L("共有・取り込み待ちを中止","Cancel transfer / discard pending review"),function() self.session:Cancel();self.session.review=nil end)
    Button(L("取り込み前の辞書に戻す","Restore dictionary before import"),function() self:Restore() end)
end
function addon:InitSharing()
    if UI.session then return end
    UI.session=S.New({now=Now,name=GetDisplayName,member=function(peer) return UI:Resolve(peer)~=nil end,
        send=function(packet)
            if not UI:CanSend() then return false end
            local ok,sent=pcall(UI.protocol.Send,UI.protocol,packet)
            return ok and sent
        end,
        notify=function(event,state) UI:Notify(event,state) end})
    UI:InitDialog();UI:InitTransport();UI:InitInteractMenu();UI:InitSettings()
    SLASH_COMMANDS["/pbshare"]=function(text)
        text=T.Trim(text or "")
        if text=="review" then UI:Review()
        elseif text=="cancel" then UI.session:Cancel();UI.session.review=nil
        elseif text=="restore" then UI:Restore()
        elseif text=="accept" then
            if IsUnitInCombat and IsUnitInCombat("player") then Say(errors.combat) else UI.session:Accept() end
        elseif text=="" or text=="status" then UI:Status()
        else UI:Start(text) end
    end
    EVENT_MANAGER:RegisterForEvent(addon.name.."Sharing",EVENT_PLAYER_ACTIVATED,function() UI:InitInteractMenu() end)
end

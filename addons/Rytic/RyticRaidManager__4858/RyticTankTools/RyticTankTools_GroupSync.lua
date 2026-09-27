------------------------------------------------------------
-- RYTIC COMBAT & RAID TOOLS GROUP SYNC v3.0.0
-- LibGroupBroadcast transport for raid Team A/B assignments.
-- Existing wire IDs 180/181/182 retained; registry ownership requires verification.
------------------------------------------------------------
RyticTank=RyticTank or {}
local RyticTank=RyticTank
RyticTank.GroupSync=RyticTank.GroupSync or {}
local Sync=RyticTank.GroupSync
local EM,WM=EVENT_MANAGER,WINDOW_MANAGER

local PROTOCOL_ID=180
local PROTOCOL_NAME="RyticRaidSync"
local HANDLER_NAME="RyticTankTools"
local MAX_RAID=24
local MAX_NAME=64
local refreshSession
local queueAuthorityRefresh

local function norm(v) return zo_strformat("<<z:1>>",tostring(v or "")):lower():gsub("%s+","") end
local function account(tag) return tag and GetUnitDisplayName(tag) or "" end
local function leaderTag()
    local n=GetGroupSize and GetGroupSize() or 0
    for i=1,n do local t=GetGroupUnitTagByIndex(i); if t and IsUnitGroupLeader and IsUnitGroupLeader(t) then return t end end
    if IsUnitGroupLeader and IsUnitGroupLeader("player") then return "player" end
end
local function isSenderAllowed(tag)
    if not IsUnitGrouped("player") or not tag or not DoesUnitExist(tag) then return false end
    if IsUnitGroupLeader and IsUnitGroupLeader(tag) then return true end
    local a=norm(account(tag))
    if Sync.sessionAssistantsInitialized then
        -- Once crown has published the session authority list, it is authoritative.
        -- Anyone crown removed is denied until crown restores/pushes them again.
        return Sync.sessionAssistants and Sync.sessionAssistants[a] == true
    end

    -- No crown authority list has been published yet: an RCRT sender defaults to
    -- ASSIST while grouped. Reaching this function through protocols 180/181/182
    -- already proves the sender is participating in RCRT transport.
    if IsUnitGrouped and IsUnitGrouped("player") then
        return true
    end

    return false
end

local function popup(sender)
    if not Sync.notice then
        local w=WM:CreateTopLevelWindow("RyticRaidSyncNotice"); Sync.notice=w
        w:SetDimensions(620,105); w:SetAnchor(TOP,GuiRoot,TOP,0,150); w:SetDrawTier(DT_HIGH); w:SetDrawLayer(DL_OVERLAY); w:SetHidden(true)
        local bg=WM:CreateControl(nil,w,CT_BACKDROP); bg:SetAnchorFill(); bg:SetCenterColor(.02,.08,.14,.96); bg:SetEdgeColor(.2,.65,1,1); bg:SetEdgeTexture("",1,1,3,0)
        local title=WM:CreateControl(nil,w,CT_LABEL); title:SetFont("ZoFontWinH2"); title:SetAnchor(TOP,w,TOP,0,12); title:SetDimensions(590,34); title:SetHorizontalAlignment(TEXT_ALIGN_CENTER); title:SetText("RYTIC RAID ASSIGNMENTS UPDATED")
        local sub=WM:CreateControl(nil,w,CT_LABEL); Sync.noticeSub=sub; sub:SetFont("ZoFontGameBold"); sub:SetAnchor(TOP,w,TOP,0,53); sub:SetDimensions(590,32); sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    Sync.noticeSub:SetText("Pushed by "..tostring(sender or "raid lead").." â€” CHECK TEAM / POSITION")
    Sync.noticeUntil=GetFrameTimeMilliseconds()+2000
    if not Sync.noticeFragment then
        Sync.noticeFragment=RyticTank.UI.Attach(Sync.notice,function()
            return GetFrameTimeMilliseconds()<(Sync.noticeUntil or 0)
        end)
    end
    RyticTank.UI.Refresh(Sync.notice)
    if PlaySound and SOUNDS then PlaySound(SOUNDS.READY_CHECK or SOUNDS.DUEL_START) end
    Sync.noticeGeneration=(Sync.noticeGeneration or 0)+1
    local generation=Sync.noticeGeneration
    zo_callLater(function()
        if Sync.notice and Sync.noticeGeneration==generation then Sync.noticeUntil=0; RyticTank.UI.Refresh(Sync.notice) end
    end,2000)
end

local function raidWarningPopup(message)
    -- Local presentation preference only. Protocol 182 remains active so this
    -- client can still receive RCRT traffic and other players are unaffected.
    RyticTank.saved=RyticTank.saved or {}
    if RyticTank.saved.raidWarningsEnabled==false then return end
    message=tostring(message or "")
    if message=="" then return end
    if not Sync.rwNotice then
        local w=WM:CreateTopLevelWindow("RyticRaidWarningNotice"); Sync.rwNotice=w
        w:SetDimensions(720,92); w:SetAnchor(TOP,GuiRoot,TOP,0,145); w:SetDrawTier(DT_HIGH); w:SetDrawLayer(DL_OVERLAY); w:SetHidden(true)
        local bg=WM:CreateControl(nil,w,CT_BACKDROP); bg:SetAnchorFill(); bg:SetCenterColor(.02,.08,.14,.96); bg:SetEdgeColor(.2,.65,1,1); bg:SetEdgeTexture("",1,1,3,0)
        local label=WM:CreateControl(nil,w,CT_LABEL); Sync.rwLabel=label
        label:SetFont("ZoFontWinH2"); label:SetAnchorFill(); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER); label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    Sync.rwLabel:SetText(message)
    Sync.warningUntil=GetFrameTimeMilliseconds()+2000
    if not Sync.warningFragment then
        Sync.warningFragment=RyticTank.UI.Attach(Sync.rwNotice,function()
            return RyticTank.saved.raidWarningsEnabled~=false and GetFrameTimeMilliseconds()<(Sync.warningUntil or 0)
        end)
    end
    RyticTank.UI.Refresh(Sync.rwNotice)
    if PlaySound and SOUNDS then PlaySound(SOUNDS.READY_CHECK or SOUNDS.DUEL_START) end
    Sync.rwGeneration=(Sync.rwGeneration or 0)+1
    local generation=Sync.rwGeneration
    zo_callLater(function()
        if Sync.rwNotice and Sync.rwGeneration==generation then Sync.warningUntil=0; RyticTank.UI.Refresh(Sync.rwNotice) end
    end,2000)
end

local function setSessionAssistants(list)
    Sync.sessionAssistants={}
    Sync.sessionAssistantsInitialized=true
    for _,a in ipairs(list or {}) do Sync.sessionAssistants[norm(a)]=true end
    if RyticTank.GroupFrames and RyticTank.GroupFrames.SetSessionAssistants then
        RyticTank.GroupFrames.SetSessionAssistants(list or {})
    end
end

local function assignmentsMatchCurrent(incoming)
    local G=RyticTank.GroupFrames
    if not G or not G.ExportSyncState then return false end
    local current=G.ExportSyncState()
    local function signature(rows)
        local out={}
        for _,row in ipairs(rows or {}) do
            out[#out+1]=norm(row.account)..":"..tostring(tonumber(row.team) or 0)..":"..(row.locked and "1" or "0")
        end
        table.sort(out)
        return table.concat(out,";")
    end
    return signature(current)==signature(incoming)
end

local function refreshGroupManagerIfOpen()
    local R=RyticTank.RaidLead
    if R and R.groupManager and not R.groupManager:IsHidden() then R.RefreshGroupManager() end
end

local function isSelf(tag) return norm(account(tag))==norm(account("player")) end

local function isNewRevision(previous,revision)
    if previous==nil then return true end
    local distance=(revision-previous)%65536
    return distance>0 and distance<32768
end

local function validRevision(data)
    local revision=type(data)=="table" and tonumber(data.revision)
    if not revision or revision<0 or revision>65535 or revision%1~=0 then return nil end
    return revision
end

local function applyRemote(assignments,names)
    local G=RyticTank.GroupFrames
    if not G or not G.ApplySyncState then return false end
    Sync.applyingRemote=true
    local ok,result=pcall(G.ApplySyncState,assignments,names)
    Sync.applyingRemote=false
    if not ok then d("|cFF4444Rytic: unable to apply raid state: "..tostring(result).."|r") end
    return ok and result~=false
end

local function receive(unitTag,data)
    refreshSession()
    if not isSenderAllowed(unitTag) or isSelf(unitTag) then return end
    local rev=validRevision(data); if not rev then return end
    local sender=norm(account(unitTag))
    if not isNewRevision(Sync.receivedAssignments[sender],rev) then return end
    local names=Sync.receivedNames[sender]
    local matching=names and names.revision==rev
    local changed=not assignmentsMatchCurrent(data.assignments or {})
    if not applyRemote(data.assignments or {},matching and {names.a,names.b} or nil) then return end
    Sync.receivedAssignments[sender]=rev
    Sync.currentSender=sender; Sync.currentRevision=rev
    -- A leader's list is authoritative, regardless of an assistant's sequence.
    if IsUnitGroupLeader(unitTag) then setSessionAssistants(data.assistants) end
    refreshGroupManagerIfOpen()
    if changed then popup(account(unitTag)) end
end

local function receiveNames(unitTag,data)
    refreshSession()
    if not isSenderAllowed(unitTag) or isSelf(unitTag) then return end
    local rev=validRevision(data); if not rev then return end
    local sender=norm(account(unitTag)); local prior=Sync.receivedNames[sender]
    if prior and not isNewRevision(prior.revision,rev) then return end
    Sync.receivedNames[sender]={revision=rev,a=data.teamNameA,b=data.teamNameB}
    if Sync.currentSender==sender and Sync.currentRevision==rev then
        local G=RyticTank.GroupFrames
        local assignments=G.ExportSyncState()
        applyRemote(assignments,{data.teamNameA,data.teamNameB})
    end
end

local function initProtocol()
    local LGB=LibGroupBroadcast
    if not LGB then d("|cFF4444Rytic: LibGroupBroadcast is required for raid sync.|r"); return false end
    local ok,err=pcall(function()
        local h=LGB:RegisterHandler(HANDLER_NAME,"RyticRaid")
        if not h then error("handler registration failed") end
        h:SetDisplayName("Rytic Raid Sync")
        h:SetDescription("Shares RyticTankTools raid assignments and team titles with grouped addon users.")
        local row=LGB.CreateTableField("assignments",{
            LGB.CreateStringField("account",{maxLength=MAX_NAME}),
            LGB.CreateNumericField("team",{minValue=1,maxValue=2}),
            LGB.CreateFlagField("locked"),
        })
        local assistant=LGB.CreateStringField("assistants",{maxLength=MAX_NAME})
        local p=h:DeclareProtocol(180,"RyticRaidSync")
        p:AddField(LGB.CreateNumericField("revision",{minValue=0,maxValue=65535}))
        p:AddField(LGB.CreateArrayField(row,{maxLength=MAX_RAID}))
        p:AddField(LGB.CreateArrayField(assistant,{maxLength=MAX_RAID}))
        p:OnData(receive)
        if not p:Finalize({isRelevantInCombat=false,replaceQueuedMessages=true}) then error("protocol 180 finalize failed") end
        Sync.protocol=p

        local names=h:DeclareProtocol(181,"RyticRaidTeamNames")
        names:AddField(LGB.CreateNumericField("revision",{minValue=0,maxValue=65535}))
        names:AddField(LGB.CreateStringField("teamNameA",{maxLength=18}))
        names:AddField(LGB.CreateStringField("teamNameB",{maxLength=18}))
        names:OnData(receiveNames)
        if not names:Finalize({isRelevantInCombat=false,replaceQueuedMessages=true}) then error("protocol 181 finalize failed") end
        Sync.nameProtocol=names

        -- Custom RCRT raid warning transport. Kept separate from assignment
        -- protocols so /rw never mutates team/mechanic state.
        local rw=h:DeclareProtocol(182,"RyticRaidWarning")
        rw:AddField(LGB.CreateStringField("message",{maxLength=180}))
        rw:OnData(function(unitTag,data)
            refreshSession()
            if not isSenderAllowed(unitTag) or isSelf(unitTag) then return end
            local sender=norm(account(unitTag)); local now=GetFrameTimeMilliseconds()
            if Sync.warningTimes[sender] and now-Sync.warningTimes[sender]<1000 then return end
            Sync.warningTimes[sender]=now
            raidWarningPopup(data and data.message or "")
        end)
        if not rw:Finalize({isRelevantInCombat=true,replaceQueuedMessages=false}) then error("protocol 182 finalize failed") end
        Sync.rwProtocol=rw
    end)
    if not ok then d("|cFF4444Rytic raid sync protocol failed: "..tostring(err).."|r"); return false end
    return true
end

function Sync.SendRaidWarning(message)
    message=tostring(message or ""):gsub("^%s+",""):gsub("%s+$","")
    if message=="" then return false,"message is empty" end
    if #message>180 then return false,"raid warnings must fit within 180 UTF-8 bytes" end
    refreshSession()
    if not IsUnitGrouped("player") then return false,"you are not grouped" end
    if not isSenderAllowed("player") then return false,"group lead or Rytic assistant authority is required" end
    if not Sync.rwProtocol then return false,"Rytic raid-warning transport is unavailable" end
    if Sync.rwProtocol.IsEnabled and not Sync.rwProtocol:IsEnabled() then return false,"Rytic raid-warning transport is disabled" end
    local ok=Sync.rwProtocol:Send({message=message})
    if not ok then return false,"Rytic raid warning could not be queued" end
    -- Show immediately for the sender too; remote clients render on receive.
    raidWarningPopup(message)
    return true
end

function Sync.SendUpdateNotice(message)
    return Sync.SendRaidWarning(message)
end

local function nextRevision()
    local saved=RyticTank.saved
    local revision=((tonumber(saved.syncRevision) or 0)+1)%65536
    saved.syncRevision=revision
    Sync.lastRevision=revision
    return revision
end

function Sync.SaveAuthority()
    if not IsUnitGroupLeader("player") then return end
    local G=RyticTank.GroupFrames; local overrides={}
    for k,v in pairs(G.sessionAssistantOverrides or {}) do overrides[k]=v end
    RyticTank.saved.raidAuthority={leader=Sync.leader,roster=Sync.roster,overrides=overrides}
end

local function sendState(quiet)
    if Sync.applyingRemote then return true,"remote-apply-suppressed" end
    refreshSession()
    if not isSenderAllowed("player") then return false,"group lead or Rytic assistant authority is required" end
    local G=RyticTank.GroupFrames
    if not G or not G.ExportSyncState then return false,"Group frame sync state is unavailable" end
    for _,protocol in ipairs({Sync.protocol,Sync.nameProtocol}) do
        if protocol.IsEnabled and not protocol:IsEnabled() then return false,"Rytic raid sync is disabled in LibGroupBroadcast settings" end
    end
    if not Sync.protocol or not Sync.nameProtocol then return false,"Raid sync transport is unavailable" end
    local assignments,assistants,names=G.ExportSyncState()
    local rev=nextRevision()
    local sent=Sync.protocol:Send({revision=rev,assignments=assignments,assistants=assistants})
    if not sent then return false,"Could not queue assignments" end
    local named=Sync.nameProtocol:Send({revision=rev,teamNameA=names[1],teamNameB=names[2]})
    if IsUnitGroupLeader("player") then setSessionAssistants(assistants); Sync.SaveAuthority() end
    if not named then return false,"Assignments queued, but team titles failed; use PUSH again" end
    -- Explicit PUSH is a resend, including an unchanged snapshot.
    if not quiet then popup(account("player")); d("|c55FF55Rytic: raid assignments queued.|r") end
    return true
end

function Sync.PushAssistants()
    if not IsUnitGroupLeader("player") then return false,"Only the current ESO group leader can change assistants" end
    local ok,err=sendState(true)
    refreshGroupManagerIfOpen()
    return ok,err
end

function Sync.Push() return sendState(false) end

local function resetSession()
    Sync.sessionAssistants={}; Sync.sessionAssistantsInitialized=false
    Sync.receivedAssignments={}; Sync.receivedNames={}; Sync.warningTimes={}
    Sync.currentSender=nil; Sync.currentRevision=nil
    Sync.noticeUntil=0; Sync.warningUntil=0
    Sync.applyingRemote=false
    local G=RyticTank.GroupFrames
    if G then
        G.sessionAssistants={}; G.sessionAssistantsInitialized=false; G.sessionAssistantOverrides={}
    end
    Sync.generation=(Sync.generation or 0)+1
    Sync.autoQueued=false
    if RyticTank.UI then RyticTank.UI.RefreshAll() end
end

queueAuthorityRefresh=function()
    if Sync.autoQueued or not IsUnitGrouped("player") or not IsUnitGroupLeader("player") then return end
    Sync.autoQueued=true
    local generation=Sync.generation
    zo_callLater(function()
        if generation~=Sync.generation then return end
        Sync.autoQueued=false
        if IsUnitGrouped("player") and IsUnitGroupLeader("player") then sendState(true) end
    end,1000)
end

refreshSession=function()
    local roster={}
    if IsUnitGrouped("player") then
        for i=1,GetGroupSize() do roster[#roster+1]=norm(account(GetGroupUnitTagByIndex(i))) end
    end
    table.sort(roster)
    local signature=table.concat(roster,";")
    local tag=leaderTag()
    -- Roster discovery can precede the crown tag during loading.
    if signature~="" and not tag then return end
    local leader=signature~="" and norm(account(tag)) or ""
    local oldRoster=Sync.roster; local oldLeader=Sync.leader
    if oldLeader~=leader or signature=="" then
        resetSession()
        Sync.leader=leader
        Sync.roster=signature
        -- Restore only this exact leader/roster on the leader's own reload.
        local saved=RyticTank.saved.raidAuthority
        if oldLeader==nil and IsUnitGroupLeader("player") and saved and saved.leader==leader and saved.roster==signature then
            local G=RyticTank.GroupFrames
            if G then for k,v in pairs(saved.overrides or {}) do G.sessionAssistantOverrides[k]=v end end
        elseif oldLeader~=nil and oldLeader~=leader then
            RyticTank.saved.raidAuthority=nil
        end
    else
        Sync.roster=signature
        local present={}; for _,who in ipairs(roster) do present[who]=true end
        for _,cache in ipairs({Sync.receivedAssignments,Sync.receivedNames,Sync.warningTimes,Sync.sessionAssistants}) do
            for who in pairs(cache) do if not present[who] then cache[who]=nil end end
        end
        local G=RyticTank.GroupFrames
        if G then
            for _,cache in ipairs({G.sessionAssistantOverrides or {},G.sessionAssistants or {}}) do
                for who in pairs(cache) do if not present[who] then cache[who]=nil end end
            end
        end
    end
    if oldRoster~=signature or oldLeader~=leader then
        queueAuthorityRefresh()
        refreshGroupManagerIfOpen()
    end
end

EM:RegisterForEvent("RyticRaidSyncBootstrap",EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~="RyticTankTools" then return end
    EM:UnregisterForEvent("RyticRaidSyncBootstrap",EVENT_ADD_ON_LOADED)
    resetSession(); initProtocol(); refreshSession()
    EM:RegisterForEvent("RyticRaidSyncGroupUpdate",EVENT_GROUP_UPDATE,refreshSession)
    EM:RegisterForEvent("RyticRaidSyncActivated",EVENT_PLAYER_ACTIVATED,function() refreshSession(); queueAuthorityRefresh() end)
    -- Optional standard reload notification avoids inventing an unregistered ID.
    local reload=LibGroupBroadcast and LibGroupBroadcast.GetHandlerApi and LibGroupBroadcast:GetHandlerApi("UIReload")
    if reload then
        reload:RegisterForUIReload(function(tag)
            local who=norm(account(tag))
            Sync.receivedAssignments[who]=nil; Sync.receivedNames[who]=nil
            if not isSelf(tag) then queueAuthorityRefresh() end
        end)
    end
end)

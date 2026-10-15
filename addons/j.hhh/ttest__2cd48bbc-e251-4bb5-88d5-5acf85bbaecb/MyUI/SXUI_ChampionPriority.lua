-- Satuve Xbox UI - Champion Point Step List Helper
-- v1.1.14: validate every CP step against ESO before sending; reject/limit invalid steps instead of sending a broken request.
-- ONE character-specific list. Each star is detected automatically
-- as BLUE/Warfare, RED/Fitness or GREEN/Craft and consumes only that tree's CP.

BUI = BUI or {}
BUI.ChampionPriority = BUI.ChampionPriority or {}
local CP = BUI.ChampionPriority

local TREE_ORDER={"blue","red","green"}
local TREES={
    blue={label="BLUE / WARFARE", disciplineType=CHAMPION_DISCIPLINE_TYPE_COMBAT},
    red={label="RED / FITNESS", disciplineType=CHAMPION_DISCIPLINE_TYPE_CONDITIONING},
    green={label="GREEN / CRAFT", disciplineType=CHAMPION_DISCIPLINE_TYPE_WORLD},
}

local function Alert(text)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT,nil,tostring(text))
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage(tostring(text))
    elseif d then d(tostring(text)) end
end
local function Chat(text)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("|c4B8BFE[Satuve CP]|r "..tostring(text))
    elseif d then d("[Satuve CP] "..tostring(text)) end
end
local function Trim(text) return (tostring(text or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function Normalize(text)
    text=zo_strformat("<<!aC:1>>",text or "")
    text=string.lower(text)
    text=string.gsub(text,"[^%w]","")
    return text
end

function CP:Initialize()
    local defaults={characters={}}
    self.Storage=ZO_SavedVars:NewAccountWide('SATUVE_XBOX_UI_CP_CHAR',3,nil,defaults)
    local charId=tostring((GetCurrentCharacterId and GetCurrentCharacterId()) or 0)
    if charId=="0" or charId=="" then charId=tostring((GetUnitName and GetUnitName("player")) or "unknown") end
    self.CharacterId=charId
    self.Storage.characters=self.Storage.characters or {}
    self.Storage.characters[charId]=self.Storage.characters[charId] or {list=""}
    local cv=self.Storage.characters[charId]
    -- One-time migration: join old separated lists if present.
    if (not cv.list or cv.list=="") and (cv.blue or cv.red or cv.green) then
        local parts={}
        for _,k in ipairs(TREE_ORDER) do if type(cv[k])=="string" and Trim(cv[k])~="" then parts[#parts+1]=cv[k] end end
        cv.list=table.concat(parts,"\n")
    end
    cv.list=tostring(cv.list or "")
    self.CharVars=cv
end

function CP:GetList()
    if not self.CharVars then self:Initialize() end
    return tostring((self.CharVars and self.CharVars.list) or "")
end
function CP:SetList(text)
    if not self.CharVars then self:Initialize() end
    local value=tostring(text or "")
    self.CharVars.list=value
    if self.Storage and self.Storage.characters and self.CharacterId then
        self.Storage.characters[self.CharacterId]=self.CharVars
        self.Storage.characters[self.CharacterId].list=value
    end
    return self:GetList()==value
end

function CP:ParseList()
    local text=self:GetList()
    local steps,errors={},{}
    local lineNo=0
    for raw in string.gmatch(text.."\n","([^\n]*)\n") do
        lineNo=lineNo+1
        local line=Trim(raw)
        if line~="" then
            local n,name,points=line:match("^(%d+)%s*[%.%):%-]%s*(.-)%s+(%d+)%s*$")
            if not n then n,name,points=line:match("^(%d+)%s+(.-)%s+(%d+)%s*$") end
            if n and name and points and Trim(name)~="" then
                steps[#steps+1]={step=tonumber(n),name=Trim(name),points=tonumber(points),line=lineNo}
            else errors[#errors+1]="Line "..lineNo..": "..line end
        end
    end
    table.sort(steps,function(a,b) if a.step==b.step then return a.line<b.line end return a.step<b.step end)
    local seen,last={},0
    for _,s in ipairs(steps) do
        if seen[s.step] then errors[#errors+1]="Duplicate step "..s.step end
        seen[s.step]=true
        if last>0 and s.step>last+1 then errors[#errors+1]="Missing step "..(last+1) end
        if s.step>last then last=s.step end
    end
    return steps,errors
end

local function GetTreeForDisciplineIndex(di)
    local disciplineId=GetChampionDisciplineId and GetChampionDisciplineId(di)
    if not disciplineId then return nil end
    if GetChampionDisciplineType then
        local dtype=GetChampionDisciplineType(disciplineId)
        if dtype==CHAMPION_DISCIPLINE_TYPE_COMBAT then return "blue" end
        if dtype==CHAMPION_DISCIPLINE_TYPE_CONDITIONING then return "red" end
        if dtype==CHAMPION_DISCIPLINE_TYPE_WORLD then return "green" end
    end
    return nil
end

function CP:BuildGlobalSkillIndex()
    local byName,skillsByTree,allSkills={},{blue={},red={},green={}},{}
    if not GetNumChampionDisciplines or not GetNumChampionDisciplineSkills or not GetChampionSkillId then return byName,skillsByTree,allSkills end
    for di=1,GetNumChampionDisciplines() do
        local tree=GetTreeForDisciplineIndex(di)
        if tree then
            for si=1,GetNumChampionDisciplineSkills(di) do
                local id=GetChampionSkillId(di,si)
                if id then
                    local name=GetChampionSkillName(id) or tostring(id)
                    local key=Normalize(name)
                    byName[key]={id=id,name=name,tree=tree}
                    skillsByTree[tree][id]=name
                    allSkills[id]={name=name,tree=tree}
                end
            end
        end
    end
    return byName,skillsByTree,allSkills
end

local TREE_CHAMPION_ATTRIBUTE={
    blue=ATTRIBUTE_HEALTH,
    red=ATTRIBUTE_MAGICKA,
    green=ATTRIBUTE_STAMINA,
}

local function GetTreeChampionAttribute(tree)
    -- Update 29+ maps the CP pools as Warfare=Health, Fitness=Magicka, Craft=Stamina
    -- for GetNumUnspentChampionPoints(). This looks counter-intuitive but matches ESO's API.
    return TREE_CHAMPION_ATTRIBUTE[tree]
end

function CP:GetTreeBudget(tree,skills)
    local spent=0
    if GetNumPointsSpentOnChampionSkill then
        for id in pairs(skills or {}) do spent=spent+(GetNumPointsSpentOnChampionSkill(id) or 0) end
    end
    local attribute=GetTreeChampionAttribute(tree)
    local unspent=0
    if attribute~=nil and GetNumUnspentChampionPoints then unspent=GetNumUnspentChampionPoints(attribute) or 0 end
    return spent+unspent,spent,unspent,attribute
end

function CP:ResolvePlan()
    local steps,parseErrors=self:ParseList()
    local byName,skillsByTree,allSkills=self:BuildGlobalSkillIndex()
    local plan={steps={},missing={},parseErrors=parseErrors,desiredById={},skillsByTree=skillsByTree,allSkills=allSkills,budgets={}}
    local remaining={}
    for _,tree in ipairs(TREE_ORDER) do
        local budget,spent,unspent,attribute=self:GetTreeBudget(tree,skillsByTree[tree])
        plan.budgets[tree]={budget=budget,spent=spent,unspent=unspent,attribute=attribute,used=0,left=budget}
        remaining[tree]=budget
    end
    for _,step in ipairs(steps) do
        local found=byName[Normalize(step.name)]
        if not found then
            plan.missing[#plan.missing+1]=step.name
            plan.steps[#plan.steps+1]={step=step.step,name=step.name,requested=step.points,added=0,tree=nil,missing=true}
        else
            local tree=found.tree
            local requested=math.max(0,step.points or 0)
            local add=math.min(requested,math.max(0,remaining[tree] or 0))
            plan.desiredById[found.id]=(plan.desiredById[found.id] or 0)+add
            remaining[tree]=math.max(0,(remaining[tree] or 0)-add)
            local b=plan.budgets[tree]
            b.used=b.used+add; b.left=remaining[tree]
            plan.steps[#plan.steps+1]={step=step.step,name=found.name,requested=requested,added=add,tree=tree,complete=(add==requested),id=found.id}
        end
    end
    return plan
end

function CP:CreatePreviewWindow()
    if self.PreviewWindow then return self.PreviewWindow end
    local win=WINDOW_MANAGER:CreateTopLevelWindow("SXUI_CPPreview")
    win:SetDimensions(1180,820); win:SetAnchor(CENTER,GuiRoot,CENTER,0,0); win:SetDrawTier(DT_HIGH); win:SetDrawLayer(DL_OVERLAY); win:SetMouseEnabled(true)
    if win.SetKeyboardEnabled then win:SetKeyboardEnabled(true) end
    win:SetHidden(true)
    local bg=WINDOW_MANAGER:CreateControlFromVirtual("SXUI_CPPreviewBG",win,"ZO_DefaultBackdrop"); bg:SetAnchorFill(); bg:SetCenterColor(0,0,0,.96); bg:SetEdgeColor(.85,.72,.25,1)
    local title=WINDOW_MANAGER:CreateControl("SXUI_CPPreviewTitle",win,CT_LABEL); title:SetDimensions(1100,48); title:SetAnchor(TOP,win,TOP,0,24); title:SetFont("$(BOLD_FONT)|30|soft-shadow-thick"); title:SetHorizontalAlignment(TEXT_ALIGN_CENTER); title:SetText("CHAMPION POINT STEP PREVIEW")
    local body=WINDOW_MANAGER:CreateControl("SXUI_CPPreviewBody",win,CT_LABEL); body:SetDimensions(1080,680); body:SetAnchor(TOP,win,TOP,0,86); body:SetFont("$(MEDIUM_FONT)|20|soft-shadow-thick"); body:SetVerticalAlignment(TEXT_ALIGN_TOP); body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    local hint=WINDOW_MANAGER:CreateControl("SXUI_CPPreviewHint",win,CT_LABEL); hint:SetDimensions(1080,32); hint:SetAnchor(BOTTOM,win,BOTTOM,0,-14); hint:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thick"); hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER); hint:SetText("ESC / Xbox View (Back) = Close")
    win:SetHandler("OnKeyDown",function(self,key) if key==KEY_ESCAPE or key==KEY_GAMEPAD_BACK or key==KEY_GAMEPAD_BACK_HOLD then self:SetHidden(true); return true end return true end)
    self.PreviewWindow=win; self.PreviewBody=body; return win
end

local TREE_SHORT={blue="BLUE",red="RED",green="GREEN"}
function CP:Preview()
    local plan=self:ValidatePlan(self:ResolvePlan())
    if #plan.steps==0 then Alert("No valid CP steps saved. Open Edit CP Step List first."); return plan end
    local lines={}
    for _,tree in ipairs(TREE_ORDER) do
        local b=plan.budgets[tree]
        lines[#lines+1]=string.format("%s: available %d (spent %d + free %d)  planned %d  remaining %d",TREE_SHORT[tree],b.budget,b.spent,b.unspent,b.used,b.left)
    end
    lines[#lines+1]=""
    for _,s in ipairs(plan.steps) do
        if s.missing then lines[#lines+1]=string.format("! %d. %s  NOT FOUND",s.step,s.name)
        else
            local valid=s.validatedAdded or 0
            local mark=(valid==s.requested) and "✓" or (valid>0 and "→" or "!")
            lines[#lines+1]=string.format("%s %d. [%s] %s  +%d / %d",mark,s.step,TREE_SHORT[s.tree],s.name,valid,s.requested)
            if s.validationMessage then lines[#lines+1]="    "..s.validationMessage end
        end
    end
    lines[#lines+1]=""
    lines[#lines+1]=plan.validationOK and "ESO VALIDATION: OK — request can be sent." or ("ESO VALIDATION: BLOCKED — code "..tostring(plan.validationResult))
    if #plan.parseErrors>0 then lines[#lines+1]=""; lines[#lines+1]="LIST WARNINGS:"; for _,v in ipairs(plan.parseErrors) do lines[#lines+1]="• "..v end end
    if #plan.missing>0 then lines[#lines+1]=""; lines[#lines+1]="STARS NOT FOUND: "..table.concat(plan.missing,", ") end
    self:CreatePreviewWindow(); self.PreviewBody:SetText(table.concat(lines,"\n")); self.PreviewWindow:SetHidden(false)
    if SCENE_MANAGER and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(true) end
    return plan
end

local function APIAvailable()
    return type(PrepareChampionPurchaseRequest)=="function" and type(AddSkillToChampionPurchaseRequest)=="function" and type(SendChampionPurchaseRequest)=="function"
end
function CP:NeedsRespec(plan)
    if not GetNumPointsSpentOnChampionSkill then return false end
    for id,info in pairs(plan.allSkills or {}) do
        local current=GetNumPointsSpentOnChampionSkill(id) or 0
        local desired=plan.desiredById[id] or 0
        if current>desired then return true end
    end
    return false
end

local function ClearRequest()
    if ClearChampionPurchaseRequest then ClearChampionPurchaseRequest() end
end

local function ExpectedRequestResult()
    if GetExpectedResultForChampionPurchaseRequest then
        return GetExpectedResultForChampionPurchaseRequest()
    end
    return CHAMPION_PURCHASE_SUCCESS
end

local function RequestSucceeded(result)
    if CHAMPION_PURCHASE_SUCCESS==nil then return result==nil or result==0 end
    return result==CHAMPION_PURCHASE_SUCCESS
end

-- Rebuild a complete request from a desired-by-skill table and ask ESO whether
-- that exact request is legal. Nothing is sent here.
function CP:TestPurchaseRequest(desiredById,respec)
    ClearRequest()
    PrepareChampionPurchaseRequest(respec)
    local count=0
    for id,points in pairs(desiredById or {}) do
        if points and points>0 then
            AddSkillToChampionPurchaseRequest(id,points)
            count=count+1
        end
    end
    if count==0 then return true,CHAMPION_PURCHASE_SUCCESS end
    local result=ExpectedRequestResult()
    return RequestSucceeded(result),result
end

-- ESO validation is authoritative. Walk the user's steps in order and only keep
-- increments that ESO accepts. If the full increment is rejected, find the
-- largest smaller increment that is accepted. This catches prerequisites,
-- max-rank limits and other Champion purchase rules before SendChampionPurchaseRequest().
function CP:ValidatePlan(plan)
    plan=plan or self:ResolvePlan()
    plan.validatedById={}
    plan.validationErrors={}
    plan.validationResult=CHAMPION_PURCHASE_SUCCESS
    local respec=self:NeedsRespec(plan)
    plan.respec=respec

    if not APIAvailable() then
        plan.validationErrors[#plan.validationErrors+1]="Champion purchase API is not available on this client."
        return plan
    end

    for _,s in ipairs(plan.steps or {}) do
        s.validatedAdded=0
        s.validationCode=nil
        s.validationMessage=nil
        if not s.missing and s.id and (s.added or 0)>0 then
            local old=plan.validatedById[s.id] or 0
            local requestedAdd=s.added
            local function testAdd(add)
                local candidate={}
                for id,v in pairs(plan.validatedById) do candidate[id]=v end
                candidate[s.id]=old+add
                local ok,code=self:TestPurchaseRequest(candidate,respec)
                return ok,code,candidate
            end

            local ok,code,candidate=testAdd(requestedAdd)
            if ok then
                plan.validatedById=candidate
                s.validatedAdded=requestedAdd
            else
                -- Find the largest legal partial increment. CP step sizes are small,
                -- so a descending search is robust even if ESO's rule is not monotonic.
                local accepted,acceptedCandidate,lastCode=0,nil,code
                for add=requestedAdd-1,1,-1 do
                    local pok,pcode,pcandidate=testAdd(add)
                    lastCode=pcode
                    if pok then accepted=add; acceptedCandidate=pcandidate; break end
                end
                if accepted>0 then
                    plan.validatedById=acceptedCandidate
                    s.validatedAdded=accepted
                    s.validationCode=code
                    s.validationMessage="ESO limited this step (prerequisite / max rank / purchase rule), code "..tostring(code)
                else
                    s.validationCode=lastCode or code
                    s.validationMessage="ESO blocked this step (prerequisite / max rank / purchase rule), code "..tostring(s.validationCode)
                    plan.validationErrors[#plan.validationErrors+1]=string.format("Step %d %s: %s",s.step,s.name,s.validationMessage)
                end
            end
        end
    end

    local ok,result=self:TestPurchaseRequest(plan.validatedById,respec)
    plan.validationResult=result
    plan.validationOK=ok
    ClearRequest()
    return plan
end

function CP:ApplyNow()
    if not APIAvailable() then Alert("Champion purchase API is not available on this client."); return end
    local plan=self:ValidatePlan(self:ResolvePlan())
    if #plan.steps==0 then Alert("No valid CP steps saved."); return end
    if #plan.missing>0 then self:Preview(); Alert("Not applied: at least one Champion star was not found."); return end
    if GetChampionPurchaseAvailability then
        local availability=GetChampionPurchaseAvailability()
        if CHAMPION_PURCHASE_SUCCESS~=nil and availability~=CHAMPION_PURCHASE_SUCCESS then Alert("Champion points cannot be changed right now. ESO code: "..tostring(availability)); return end
    end
    if not plan.validationOK then
        self:Preview()
        Alert("Not applied: ESO still rejects the validated CP plan. Code: "..tostring(plan.validationResult))
        return
    end
    ClearRequest()
    PrepareChampionPurchaseRequest(plan.respec)
    local count=0
    for id,points in pairs(plan.validatedById or {}) do
        if points>0 then AddSkillToChampionPurchaseRequest(id,points); count=count+1 end
    end
    if count==0 then ClearRequest(); self:Preview(); Alert("No legal Champion Point changes were generated. Check the validation messages in Preview."); return end
    local result=ExpectedRequestResult()
    if not RequestSucceeded(result) then ClearRequest(); self:Preview(); Alert("ESO rejected the validated CP plan. Error code: "..tostring(result)); return end
    SendChampionPurchaseRequest()
    Chat("Validated Champion request sent for "..count.." stars"..(plan.respec and " (redistribution)" or "")..".")
end

function CP:CreateApplyConfirm()
    if self.ApplyConfirm then return self.ApplyConfirm end
    local win=WINDOW_MANAGER:CreateTopLevelWindow("SXUI_CPApplyConfirm"); win:SetDimensions(1120,650); win:SetAnchor(CENTER,GuiRoot,CENTER,0,0); win:SetDrawTier(DT_HIGH); win:SetDrawLayer(DL_OVERLAY); win:SetMouseEnabled(true); if win.SetKeyboardEnabled then win:SetKeyboardEnabled(true) end; win:SetHidden(true)
    local bg=WINDOW_MANAGER:CreateControlFromVirtual("SXUI_CPApplyConfirmBG",win,"ZO_DefaultBackdrop"); bg:SetAnchorFill(); bg:SetCenterColor(0,0,0,.96); bg:SetEdgeColor(.85,.72,.25,1)
    local title=WINDOW_MANAGER:CreateControl("SXUI_CPApplyConfirmTitle",win,CT_LABEL); title:SetDimensions(1040,55); title:SetAnchor(TOP,win,TOP,0,30); title:SetFont("$(BOLD_FONT)|32|soft-shadow-thick"); title:SetHorizontalAlignment(TEXT_ALIGN_CENTER); title:SetText("APPLY CHAMPION POINT STEP LIST")
    local body=WINDOW_MANAGER:CreateControl("SXUI_CPApplyConfirmBody",win,CT_LABEL); body:SetDimensions(980,350); body:SetAnchor(TOP,win,TOP,0,110); body:SetFont("$(MEDIUM_FONT)|24|soft-shadow-thick"); body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    local apply=WINDOW_MANAGER:CreateControl("SXUI_CPApplyConfirmApply",win,CT_BUTTON); apply:SetDimensions(380,70); apply:SetAnchor(BOTTOMLEFT,win,BOTTOMLEFT,95,-55); apply:SetFont("$(BOLD_FONT)|27|soft-shadow-thick"); apply:SetText("APPLY"); apply:SetMouseEnabled(true)
    local cancel=WINDOW_MANAGER:CreateControl("SXUI_CPApplyConfirmCancel",win,CT_BUTTON); cancel:SetDimensions(380,70); cancel:SetAnchor(BOTTOMRIGHT,win,BOTTOMRIGHT,-95,-55); cancel:SetFont("$(BOLD_FONT)|27|soft-shadow-thick"); cancel:SetText("CANCEL"); cancel:SetMouseEnabled(true)
    local function close() win:SetHidden(true) end
    local function doApply() win:SetHidden(true); CP:ApplyNow() end
    apply:SetHandler("OnClicked",doApply); cancel:SetHandler("OnClicked",close)
    win:SetHandler("OnKeyDown",function(self,key) if key==KEY_ENTER or key==KEY_GAMEPAD_BUTTON_1 then doApply(); return true end if key==KEY_ESCAPE or key==KEY_GAMEPAD_BUTTON_2 or key==KEY_GAMEPAD_BACK or key==KEY_GAMEPAD_BACK_HOLD then close(); return true end return true end)
    self.ApplyConfirm=win; self.ApplyConfirmBody=body; return win
end
function CP:Apply()
    local plan=self:ResolvePlan()
    if #plan.steps==0 then Alert("No valid CP steps saved."); return end
    if #plan.missing>0 then self:Preview(); Alert("Not applied: at least one Champion star was not found."); return end
    local lines={"The list will be processed from step 1 downward.","Each star automatically uses BLUE, RED or GREEN CP.",""}
    for _,tree in ipairs(TREE_ORDER) do local b=plan.budgets[tree]; lines[#lines+1]=string.format("%s: %d / %d CP planned",TREE_SHORT[tree],b.used,b.budget) end
    lines[#lines+1]=""; lines[#lines+1]="Apply this build now?"
    self:CreateApplyConfirm(); self.ApplyConfirmBody:SetText(table.concat(lines,"\n")); self.ApplyConfirm:SetHidden(false); if SCENE_MANAGER and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(true) end
end

function CP:CreateEditor()
    if self.Editor then return self.Editor end
    local win=WINDOW_MANAGER:CreateTopLevelWindow("SXUI_CPEditor"); win:SetDimensions(1100,800); win:SetAnchor(CENTER,GuiRoot,CENTER,0,0); win:SetDrawTier(DT_HIGH); win:SetDrawLayer(DL_OVERLAY); win:SetMouseEnabled(true); if win.SetKeyboardEnabled then win:SetKeyboardEnabled(true) end; win:SetHidden(true)
    local bg=WINDOW_MANAGER:CreateControlFromVirtual("SXUI_CPEditorBG",win,"ZO_DefaultBackdrop"); bg:SetAnchorFill(); bg:SetCenterColor(0,0,0,.96)
    local title=WINDOW_MANAGER:CreateControl("SXUI_CPEditorTitle",win,CT_LABEL); title:SetDimensions(1020,45); title:SetAnchor(TOP,win,TOP,0,22); title:SetFont("$(BOLD_FONT)|30|soft-shadow-thick"); title:SetHorizontalAlignment(TEXT_ALIGN_CENTER); title:SetText("CHAMPION POINT STEP LIST")
    local help=WINDOW_MANAGER:CreateControl("SXUI_CPEditorHelp",win,CT_LABEL); help:SetDimensions(1000,80); help:SetAnchor(TOP,win,TOP,0,72); help:SetFont("$(MEDIUM_FONT)|19|soft-shadow-thick"); help:SetHorizontalAlignment(TEXT_ALIGN_CENTER); help:SetText("Paste ONE numbered list. BLUE, RED and GREEN can be mixed or grouped.\nExample: 1. Eldritch Insight 10   •   2. Boundless Vitality 50")
    local box=WINDOW_MANAGER:CreateControl("SXUI_CPEditorBox",win,CT_EDITBOX); box:SetDimensions(980,520); box:SetAnchor(TOP,win,TOP,0,155); box:SetFont("$(MEDIUM_FONT)|21|soft-shadow-thick"); box:SetMaxInputChars(12000); if box.SetMultiLine then box:SetMultiLine(true) end; if box.SetNewLineEnabled then box:SetNewLineEnabled(true) end; box:SetMouseEnabled(true); box:SetEditEnabled(true); box:SetColor(1,1,1,1)
    local boxbg=WINDOW_MANAGER:CreateControlFromVirtual("SXUI_CPEditorBoxBG",box,"ZO_EditBackdrop_Gamepad"); boxbg:SetAnchorFill(); boxbg:SetDrawLayer(DL_BACKGROUND)
    local status=WINDOW_MANAGER:CreateControl("SXUI_CPEditorStatus",win,CT_LABEL); status:SetDimensions(980,32); status:SetAnchor(TOP,box,BOTTOM,0,8); status:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thick"); status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local save=WINDOW_MANAGER:CreateControl("SXUI_CPEditorSave",win,CT_BUTTON); save:SetDimensions(380,58); save:SetAnchor(BOTTOM,win,BOTTOM,-210,-24); save:SetFont("$(BOLD_FONT)|22|soft-shadow-thick"); save:SetText("SAVE & CLOSE"); save:SetMouseEnabled(true)
    local preview=WINDOW_MANAGER:CreateControl("SXUI_CPEditorPreview",win,CT_BUTTON); preview:SetDimensions(380,58); preview:SetAnchor(BOTTOM,win,BOTTOM,210,-24); preview:SetFont("$(BOLD_FONT)|22|soft-shadow-thick"); preview:SetText("SAVE & PREVIEW"); preview:SetMouseEnabled(true)
    local function saveText()
        local text=box:GetText() or ""; local ok=CP:SetList(text); local steps,errs=CP:ParseList(); status:SetText(string.format("Saved for this character: %d chars • %d valid steps%s",#text,#steps,(#errs>0 and (" • "..#errs.." warning(s)") or ""))); return ok,#steps
    end
    box:SetHandler("OnTextChanged",function() saveText() end)
    save:SetHandler("OnClicked",function() saveText(); win:SetHidden(true) end)
    preview:SetHandler("OnClicked",function() local _,n=saveText(); win:SetHidden(true); if n>0 then CP:Preview() else Alert("No valid CP steps found in the pasted list.") end end)
    win:SetHandler("OnKeyDown",function(self,key) if key==KEY_ESCAPE or key==KEY_GAMEPAD_BACK or key==KEY_GAMEPAD_BACK_HOLD then saveText(); self:SetHidden(true); return true end return false end)
    self.Editor=win; self.EditorBox=box; self.EditorStatus=status; return win
end
function CP:Edit()
    local win=self:CreateEditor(); self.EditorBox:SetText(self:GetList()); local steps,errs=self:ParseList(); self.EditorStatus:SetText(string.format("This character: %d valid steps%s",#steps,(#errs>0 and (" • "..#errs.." warning(s)") or ""))); win:SetHidden(false); if SCENE_MANAGER and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(true) end; self.EditorBox:TakeFocus()
end
function CP:ClearList() self:SetList(""); if self.EditorBox then self.EditorBox:SetText("") end; Alert("Champion Point step list cleared for this character.") end

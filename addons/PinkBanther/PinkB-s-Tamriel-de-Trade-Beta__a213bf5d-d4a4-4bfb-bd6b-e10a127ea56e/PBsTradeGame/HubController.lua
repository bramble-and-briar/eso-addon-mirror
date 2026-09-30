local A=PBTrade.Controller
local H,K,M=PBTrade.Hub,PBTrade.HubData,PBTrade.Model
local operations={{id="upgrade",name="改築"},{id="move",name="移設"},{id="demolish",name="撤去"}}
function A:HubCanEdit() return self.admin and self.hubReturn and self.hubReturn.screen=="admin" end
function A:HubContext() return {chapter=self.state.chapter,cash=self.state.cash,average=M.HubCostBase(self.state)} end
function A:HubCandidate()
    local list=H.Catalogue(self.state.chapter)
    self.hubFacility=math.max(1,math.min(#list,self.hubFacility or 1))
    return list[self.hubFacility]
end
function A:HubOperation() return operations[self.hubOperation or 1] end
local function districts(e)
    local names={}; for _,d in ipairs(e.districts) do names[#names+1]=d.name end
    return #names>0 and table.concat(names,"・") or "なし"
end
function A:OpenHub()
    if self.state.chapter<K.minChapter then return end
    M.RefreshHub(self.state)
    self.fx=nil
    self.hubReturn={screen=self.screen,index=self.index}
    self.hubOperation=1; self.hubMoving=nil; self.hubOrder=nil
    self.hubCursor={x=1,y=1}; self.hubFacility=1; self.screen="hub"; self.index=1
    self.notice="建設候補 "..#H.Catalogue(self.state.chapter).."種類。□で運営方針・事件・手引。工事と収益は決算で進みます"
    if not self.state.hub.introSeen then
        self.state.hub.introSeen=true; self:Save(); self:FlushSave()
        self.modal={text="交易拠点が解禁されました\n\n区画を選び、L1/R1で施設を切り替えて×で建設します。\n同時工事は2件。工事は決算ごとに1期進みます。\n完成の翌期から収益が発生します。内政の行動数は消費しません。\n\n銀行・市場・倉庫・酒場・商館を組み合わせ、5つの拠点能力を育てましょう。\n\n× / ○：都市へ"}
    end
end
function A:HubMove(dx,dy)
    if self.modal then return end
    local c=self.hubCursor
    c.x=math.max(1,math.min(H.Size(self.state.chapter),c.x+dx)); c.y=math.max(1,math.min(H.Size(self.state.chapter),c.y+dy))
    self.notice="区画 "..c.x.." / "..c.y
end
function A:HubDetail()
    local c=self.hubCursor; local b=H.At(self.state.hub,c.x,c.y)
    local f=K.byId[b and b.type or self:HubCandidate().id]
    local cost=b and b.paidCost or H.Cost(f.id,M.HubCostBase(self.state))
    local effects=H.Effects(self.state.hub,self.state.chapter,M.HubSupply(self.state))
    local t={b and (f.name.."  Lv."..b.level..(b.targetLevel and (" → "..b.targetLevel) or "")) or ("建設候補："..f.name),b and (b.remainingPeriods>0 and ("工事中：あと"..b.remainingPeriods.."期") or "稼働中") or ("工期："..f.periods.."期")}
    local supply=M.HubSupply(self.state)
    local abilityBonus=(self.state.hub.blueprints[f.id] and K.blueprintBonus or 0)+math.min(K.supplyLimit,supply[f.id] or 0)*K.supplyPerProperty
    for _,a in ipairs(K.abilities) do t[#t+1]=a.name.."：+"..math.floor((f.abilities[a.id] or 0)*(1+((b and b.level or 1)-1)*K.levelAbilityStep)*(1+abilityBonus)+.5) end
    t[#t+1]=(b and "累計投資：" or "建設費：")..M.FormatCompact(cost)
    local road=H.RoadAccess(self.state.hub,c.x,c.y,self.state.chapter)
    local bonus=b and (effects.income[b.id] or 0) or (road and K.roadIncome or 0)
    t[#t+1]="収益/維持："..M.FormatCompact(math.floor(cost*K.incomeShare*(f.income or 1)*(1+bonus)*H.Operating(self.state.hub).income)).." / "..M.FormatCompact(math.floor(cost*K.upkeepShare*(f.upkeep or 1)*H.Operating(self.state.hub).upkeep))
    local links={}; if b then for _,pair in ipairs(effects.pairs) do if pair.a==b.id or pair.b==b.id then links[#links+1]=pair.name end end end
    t[#t+1]="隣接："..(#links>0 and table.concat(links,"・") or "なし")
    t[#t+1]="地区："..(b and effects.membership[b.id] and effects.membership[b.id].name or (self.state.chapter<4 and "第4章から" or "なし"))
    do -- the stance this facility's strongest ability helps to soften
        local best,bestValue
        for _,a in ipairs(K.abilities) do local v=f.abilities[a.id] or 0; if v>0 and (not bestValue or v>bestValue) then best,bestValue=a.id,v end end
        for sid,ability in pairs(K.stanceAbility) do
            if ability==best then t[#t+1]="構えへの効果："..PBTrade.Data.stanceById[sid].name.."を緩和（"..K.abilities[({capital=1,commerce=2,logistics=3,information=4,influence=5})[ability]].name.."）" end
        end
    end
    t[#t+1]="設計図："..(self.state.hub.blueprints[f.id] and "習得済" or "未習得").." / 供給 "..(supply[f.id] or 0).."件"
    t[#t+1]="道路沿い："..(road and ("収益+"..math.floor(K.roadIncome*100+.5).."%（稼働時）") or "なし")
    t[#t+1]="配置収益補正：+"..math.floor(bonus*100+.5).."%"
    if b and b.remainingPeriods>0 then t[#t+1]="工事中は能力・収益・維持費停止" end
    if self.hubMoving then t[#t+1]="移設先を選択 → ×確認 / ○取消"
    elseif b then t[#t+1]="L1/R1 操作："..self:HubOperation().name.."　×確認" end
    return table.concat(t,"\n")
end
function A:HubReview(operation,id,x,y)
    local q,why=H.Quote(self.state.hub,self:HubContext(),operation,id,x,y)
    if not q then self.notice=why; return end
    local before=H.Effects(self.state.hub,self.state.chapter,M.HubSupply(self.state))
    local preview=M.Copy(self.state.hub)
    H.Change(preview,self:HubContext(),operation,id,x,y)
    local changed=H.Find(preview,id)
    if changed then changed.remainingPeriods=0; changed.level=changed.targetLevel or changed.level; changed.targetLevel=nil end
    local after=H.Effects(preview,self.state.chapter,M.HubSupply(self.state))
    local name=K.byId[H.Find(self.state.hub,id).type].name
    self.hubOrder={operation=operation,id=id,x=x,y=y}
    local t={name.."："..({upgrade="改築",move="移設",demolish="撤去"})[operation],
        "費用："..M.FormatCompact(q.cost).." ゴールド　返還："..M.FormatCompact(q.refund),
        "工期："..q.periods.."期（工事中は能力・収益停止）",
        "地区："..districts(before).." → "..districts(after),"完成後の拠点能力："}
    for _,a in ipairs(K.abilities) do t[#t+1]=a.name.." "..before.abilities[a.id].." → "..after.abilities[a.id] end
    t[#t+1]="\n×：確定　○：取消"
    self.modal={action="hubChange",text=table.concat(t,"\n")}
end
function A:HubAct(action)
    if action=="back" then
        if self.hubMoving then self.hubMoving=nil; self.hubOrder=nil; self.notice="移設を取り消しました"; return end
        local r=self.hubReturn; self.screen=r.screen; self.index=r.index; self.hubReturn=nil
        self.notice="交易拠点の工事は決算で進みます"; return
    end
    if action=="previous" or action=="next" then
        if self.hubMoving then return end
        if H.At(self.state.hub,self.hubCursor.x,self.hubCursor.y) then
            self.hubOperation=((self.hubOperation or 1)-1+(action=="next" and 1 or -1))%#operations+1
            self.notice="施設操作："..self:HubOperation().name; return
        end
        self.hubFacility=(self.hubFacility-1+(action=="next" and 1 or -1))%#H.Catalogue(self.state.chapter)+1
        self.notice="建設候補："..self:HubCandidate().name; return
    end
    if action=="detail" then self.modal={text=self:HubDetail()}; return end
    if action=="info" then self:ShowHubPolicy(); return end
    if action~="confirm" then return end
    local c=self.hubCursor
    if not self:HubCanEdit() then self.notice="変更は内政フェーズから行ってください"; return end
    if self.hubMoving then self:HubReview("move",self.hubMoving,c.x,c.y); return end
    local b=H.At(self.state.hub,c.x,c.y)
    if b then
        local op=self:HubOperation().id
        if op=="move" then
            if b.remainingPeriods>0 then self.notice="工事中の施設は移設できません"; return end
            self.hubMoving=b.id; self.notice="移設先の空き区画を選択してください。○で取消"; return
        end
        self:HubReview(op,b.id); return
    end
    self.hubOrder={id=self:HubCandidate().id,x=c.x,y=c.y}
    self.modal={action="hubBuild",text=self:HubDetail().."\n\n×：建設を発注　○：取消"}
end
function A:ConfirmHubBuild()
    local o=self.hubOrder; self.hubOrder=nil
    if self.screen~="hub" or not self:HubCanEdit() or not o or o.operation then return end
    local ok,cost=H.Build(self.state.hub,{chapter=self.state.chapter,cash=self.state.cash,average=M.HubCostBase(self.state)},o.id,o.x,o.y)
    if not ok then self.notice=cost; return end
    self.state.cash=self.state.cash-cost
    self.notice=K.byId[o.id].name.."の建設を開始（"..M.FormatCompact(cost).." ゴールド）"
    self:Save(); self:FlushSave()
end

function A:ConfirmHubChange()
    local o=self.hubOrder; self.hubOrder=nil
    if self.screen~="hub" or not self:HubCanEdit() or not o or not o.operation then return end
    local ok,q=H.Change(self.state.hub,self:HubContext(),o.operation,o.id,o.x,o.y)
    if not ok then self.notice=q; return end
    self.state.cash=self.state.cash-q.cost+q.refund
    self.hubMoving=nil
    self.notice="施設の"..({upgrade="改築を開始",move="移設を開始",demolish="撤去が完了"})[o.operation]
    self:Save(); self:FlushSave()
end

function A:ShowHubPolicy()
    local h=self.state.hub
    local selected=K.policies[self.hubPolicyIndex or 1]
    local text
    if self.hubGuide then
        text="交易拠点の手引\n\n↑↓←→ 区画 / L1・R1 候補・操作 / × 確認\n第3章：5×5・5施設　第4章：7×7・8施設　第5章：9×9・11施設\n改築Lv.3まで。移設1期。撤去返還40%、工事中25%。\n工事は同時2件、決算で進行。完成翌期から収益。\n上下左右の異種施設を組み合わせると能力と収益が増加。\n空いた歩道に上下左右で接する施設は収益+5%。配置補正は合計25%まで。\n第4章から専門地区（同種1つ、同一施設の重複所属なし）。\n金融＝銀行2＋商館1、交易＝市場2＋倉庫1、情報＝酒場2＋商館1\n外交＝大使館＋情報局＋商館、次元＝交易門＋異界市場＋契約銀行\n関連物件を所有すると設計図習得。供給を失っても設計図は保持。\n運営方針は次の決算から適用。拠点イベントは決算で自動進行。\n土地・施設が事件で突然消えることはありません。\n\n△ / □：運営へ　○：閉じる"
    else
        text="交易拠点の運営\n\n現在："..K.policyById[h.policy].name..(h.pendingPolicy and ("　予約："..K.policyById[h.pendingPolicy].name) or "")
            .."\nL1 / R1 候補："..selected.name.."\n"..selected.description.."\n×：次回決算から適用（無料）"
        local event=h.activeEvent and K.eventById[h.activeEvent.id]
        text=text.."\n\n現在の事件："..(event and (event.name.." / あと"..h.activeEvent.remaining.."期\n"..event.description) or "なし").."\n最近の記録："
        for _,entry in ipairs(h.eventLog) do text=text.."\n第"..entry.cycle.."期："..K.eventById[entry.id].name end
        if #h.eventLog==0 then text=text.."なし" end
        text=text.."\n\n△ / □：手引　○：閉じる"
        if not self:HubCanEdit() then text=text.."\n閲覧中：方針変更は内政で行えます" end
    end
    self.modal={hubPolicy=true,text=text}
end
function A:HubPolicyAct(action)
    if action=="back" then self.modal=nil; self.hubGuide=nil; return end
    if action=="info" or action=="detail" then self.hubGuide=not self.hubGuide
    elseif action=="previous" or action=="next" then
        self.hubPolicyIndex=((self.hubPolicyIndex or 1)-1+(action=="next" and 1 or -1))%#K.policies+1
    elseif action=="confirm" and not self.hubGuide then
        if not self:HubCanEdit() then self.notice="方針変更は内政フェーズで行ってください"; return end
        local p=K.policies[self.hubPolicyIndex or 1]
        if H.QueuePolicy(self.state.hub,self.state.chapter,p.id) then
            self.notice=p.name.."を予約（次回決算から適用）"; self:Save(); self:FlushSave()
        end
    end
    self:ShowHubPolicy()
end

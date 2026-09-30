local A={}; A.__index=A; PBTrade.Controller=A
local C,D,M=PBTrade.Config,PBTrade.Data,PBTrade.Model
local tutorial={
    "交易台帳へようこそ\n\n各地域の物件を買収し、商会の総資産を伸ばします。L1 / R1で地図・所有物件・連合・駆け引き・経営を切り替えます。",
    "買収交渉\n\n交渉はリアルタイムです。相手は左、自社は右。資金要求や駆け引きで青い帯を伸ばし、赤との境目を左端まで押し切ってください。\nコマンドは「資金要求・グループ要求・駆け引き・自社資金」の4分類。←→ / L1 R1で分類、↑↓で項目を選びます。撤退は□ボタンです。",
    "資金と離反\n\n所有物件へ要求すると独立危険度が上昇します。強い物件を使い続けるほど失う危険が増え、根回しが重要になります。",
    "連合・交易会議・委任\n\n同地域・同業種をそろえると大口の連合調達を閃きます。10期ごとの交易会議では市場事件に合わせて経営方針を選びます。通常物件は支配人へ委任できますが、章目標・商会本体・中枢・最終居城は必ず自分でリアルタイム交渉を行います。",
}
function A.New(random,saved)
    if PBTrade.LiveCatalog then PBTrade.LiveCatalog.Import() end
    local self=setmetatable({tab=1,index=1,screen="map",zone="auridon",notice="Phase 5：全開発フェーズ実装済み"},A)
    self.random=random or math.random
    self.saved=saved; self.tutorialComplete=saved and saved.tutorialComplete or false
    if PBTrade.Audio and PBTrade.Audio.SetMusicEnabled and saved and saved.music==false then PBTrade.Audio.musicEnabled=false end
    self.state=saved and saved.state and M.Load(saved.state) or M.New(); self.engine=PBTrade.Engine.New(self.state,self.random)
    if PBTrade.LiveCatalog then self:RefreshCurrentLocation() end
    -- Saves that reached chapter 5 before the takeover existed receive it on load.
    if not self.state.campaignComplete then self.molagReport=M.MolagTakeover(self.state,self.random) end
    self.previousRanks={}; for _,r in ipairs(M.Rankings(self.state)) do self.previousRanks[r.id]=r.rank end
    return self
end
-- Saving is deferred: a full export of thousands of property records costs ~1 MB of garbage,
-- so gameplay only marks the state dirty and FlushSave writes it at safe points (battle
-- result, settlement, naming, closing the ledger, loading screens, and a 60 s backstop).
-- ESO writes saved variables to disk only on logout / reload, so nothing is lost.
function A:Save() self.saveDirty=true end
function A:FlushSave()
    if not self.saved or (not self.saveDirty and self.saved.state) then return false end
    self.saveDirty=false; self.saveTimer=0
    self.saved.state=M.Export(self.state); self.saved.tutorialComplete=self.tutorialComplete
    return true
end
function A:Flash(kind,text,duration)
    self.fx={kind=kind,text=text,remaining=duration or 2.2,duration=duration or 2.2}
    if PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play(kind) end
end
local function comma(n)
    return M.FormatMoney(n)
end
-- Round steps: 1, 2, 2.5, 5 x 10^k.
local function ladder(limit)
    local steps={}; local scale=10
    while scale<=limit*10 do
        for _,f in ipairs({1,2,2.5,5}) do steps[#steps+1]=math.floor(f*scale+.5) end
        scale=scale*10
    end
    return steps
end
local function roundUpTwoDigits(n)
    local magnitude=1; while n>=magnitude*100 do magnitude=magnitude*10 end
    return math.ceil(n/magnitude)*magnitude
end
-- Treasury amounts built around the bid gap: the base closes the gap (or, when leading,
-- extends the lead by a share of the value); round ladder steps are added either side.
function A:TreasuryOptions()
    local b=self.engine.battle; local B=C.battle
    -- Under a stance the gap is in weighted money: show what it takes in real gold.
    local gap=b and (b.enemyBid-self.engine:PlayerForce()) or 0
    if gap>0 then gap=gap/self.engine:FundWeight("treasury") end
    local base,tag
    if gap>0 then base,tag=roundUpTwoDigits(gap),"差額を埋める"
    else base,tag=roundUpTwoDigits((b and b.effectiveValue or 0)*B.treasuryLeadShare),"リードを広げる" end
    base=math.max(B.treasuryMinimum,base)
    local below,above={}, {}
    for _,step in ipairs(ladder(base)) do
        if step>=B.treasuryMinimum and step<base then below[#below+1]=step elseif step>base and #above<B.treasuryStepsEachSide then above[#above+1]=step end
    end
    local options={}
    for i=math.max(1,#below-B.treasuryStepsEachSide+1),#below do options[#options+1]={amount=below[i]} end
    options[#options+1]={amount=base,tag=tag,base=true}
    for _,step in ipairs(above) do options[#options+1]={amount=step} end
    -- Never leave the treasury unusable: offer the whole balance when every step is too large.
    local cash=self.state.cash
    if cash>0 and cash<options[1].amount then table.insert(options,1,{amount=cash,tag="手元の全額"}) end
    return options,gap
end
function A:Rows()
    local rows={}
    if self.screen=="hub" then return {{label="交易拠点"}} end
    if self.screen=="title" then
        if not self.state.companyName then rows[1]={label="新しい商会を興す",command="found"}
        else
            if self.currentRegistration then
                rows[#rows+1]={label="現在地「"..self.currentRegistration.name.."」を物件登録",command="registerCurrent",property=self.currentRegistration}
            end
            rows[#rows+1]={label="交易を続ける",command="continue"}
            rows[#rows+1]={label="商会名を変更",command="rename"}
            rows[#rows+1]={label="オープニングを見る",command="opening"}
            if self.state.trueEnding then rows[#rows+1]={label="真のエンディングを見る",command="trueEnding"} end
        end
    elseif self.screen=="naming" then
        rows[1]={label="キーボードで入力する",command="keyboard"}
        for _,name in ipairs(C.campaign.companyNameCandidates) do rows[#rows+1]={label=name,command="pick",name=name} end
        rows[#rows+1]={label=self.pendingName and ("「"..self.pendingName.."」で決定") or "名前を選ぶか入力してください",command="accept",enabled=self.pendingName~=nil}
    elseif self.screen=="map" then
        for _,z in ipairs(D.zones) do if (z.minChapter or 1)<=self.state.chapter then rows[#rows+1]={id=z.id,label=z.name,zone=z} end end
    elseif self.screen=="properties" or self.screen=="owned" then
        local definitions=self.screen=="properties" and D.propertyIdsByZone[self.zone] or D.properties
        -- Registered real places lead the list and remain buyable from anywhere.  Places not
        -- registered at their ESO location trail the ordinary catalog.
        local visited,regular,unvisited={},{},{}
        for _,def in ipairs(definitions) do
            local p=self.state.properties[type(def)=="string" and def or def.id]
            if M.IsAvailable(self.state,p) and ((self.screen=="properties" and p.zone==self.zone) or (self.screen=="owned" and p.owner==C.playerId)) then
                local row={id=p.id,label=p.name,property=p}
                if self.screen~="properties" or not p.canonical then regular[#regular+1]=row
                elseif M.IsPropertyVisited(self.state,p) then visited[#visited+1]=row
                else unvisited[#unvisited+1]=row end
            end
        end
        for _,list in ipairs({visited,regular,unvisited}) do for _,row in ipairs(list) do rows[#rows+1]=row end end
    elseif self.screen=="groups" then
        -- Groups stay secret until discovered: only learned ones are listed.
        local ids={}; for id in pairs(self.state.learnedGroups) do if D.groups[id] then ids[#ids+1]=id end end
        table.sort(ids,function(x,y)
            local rx,ry=A.tierRank[D.groups[x].tier] or 9,A.tierRank[D.groups[y].tier] or 9
            if rx~=ry then return rx<ry end; return D.groups[x].name<D.groups[y].name end)
        local statuses=M.GroupStatusAll(self.state,ids)
        for _,id in ipairs(ids) do local status=statuses[id]; rows[#rows+1]={id=id,label=status.name,group=status} end
        if #rows==0 then rows[1]={label="まだ閃いた連合はありません",detailText="連合\n\nまだ閃いた連合はありません。"} end
    elseif self.screen=="tactics" then
        for _,tactic in ipairs(D.tactics) do rows[#rows+1]={id=tactic.id,label=tactic.name,tactic=tactic,learned=self.state.learnedTactics[tactic.id]} end
    elseif self.screen=="management" then
        if self.state.chapter>=3 then rows[#rows+1]={label="交易拠点を見る（建設は内政で）",command="hub"} end
        local status=M.CampaignStatus(self.state)
        rows[#rows+1]={label="第"..self.state.chapter.."章の進行  "..status.short,command="campaign",status=status}
        rows[#rows+1]={label="決算と財務  第"..M.CurrentPeriod(self.state).."期 進行中 / 負債 "..self.state.debt,command="finance"}
        local policy,event=M.ActivePolicy(self.state),M.ActiveMarketEvent(self.state)
        rows[#rows+1]={label="交易会議  "..(policy and policy.name or "方針未選択")..(event and (" / "..event.name) or ""),command="strategyStatus",policy=policy,event=event}
        if self.state.chapter>=C.delegation.minimumChapter then
            rows[#rows+1]={label="通常買収を支配人へ委任",command="delegate",enabled=#M.DelegationCandidates(self.state)>0}
        end
        local _,grant=M.RebuildTerms(self.state)
        rows[#rows+1]={label="再建融資を申請  +"..comma(grant).." ゴールド",command="rebuild",enabled=M.CanRebuild(self.state)}
        if self.state.campaignComplete and not self.state.endless and not self.state.trueEnding then
            rows[#rows+1]={label="最後の大買収を開始",command="endless"}
        end
        rows[#rows+1]={label="今期の交渉を見送る（内政・決算へ）",command="skip"}
        local Au=PBTrade.Audio or {}
        rows[#rows+1]={label="BGM："..(Au.musicBroken and "この環境では利用できません" or (Au.musicEnabled~=false and "オン" or "オフ")),command="music",enabled=not Au.musicBroken}
        rows[#rows+1]={label="現在地の確認（実在地点）",command="here"}
        rows[#rows+1]={label="画像の読み込み確認",command="assets"}
        local As=PBTrade.Assets
        rows[#rows+1]={label="画像の読み込み先："..((As.rootIndex or 1)==1 and "① アドオン相対（標準）" or "② ESOの格納先")..(#(As.roots or {})<2 and "（切替先なし）" or ""),
            command="assetRoot",enabled=#(As.roots or {})>=2,hint=#(As.roots or {})<2 and "ESOが別の格納先を報告していません" or nil}
    elseif self.screen=="strategy" then
        for _,policy in ipairs(D.tradePolicies) do
            rows[#rows+1]={id=policy.id,label=policy.name,command="choosePolicy",policy=policy}
        end
    elseif self.screen=="delegate_pick" then
        for _,p in ipairs(M.DelegationCandidates(self.state)) do
            local cost,loss,chance=M.DelegationTerms(self.state,p)
            local stances=""; for _,sid in ipairs(M.NegotiationStances(self.state,p)) do stances=stances.."〈"..D.stanceById[sid].name.."〉" end
            rows[#rows+1]={id=p.id,label=p.name..stances.."　成功率 "..math.floor(chance*100+.5).."%　必要 "..M.FormatCompact(cost),
                command="delegateProperty",property=p,cost=cost,failureCost=loss,chance=chance,enabled=self.state.cash>=cost}
        end
        if #rows==0 then rows[1]={label="委任できる通常物件がありません",command="none",enabled=false} end
    elseif self.screen=="battle" then
        -- Four command categories; ←→ / L1 R1 switch category, ↑↓ pick within it.
        local category=A.battleCategories[self.battleCategory or 1].id
        if category=="request" then
            for _,p in ipairs(M.Owned(self.state)) do rows[#rows+1]={id=p.id,label=p.name,property=p,command="request"} end
            if #rows==0 then rows[1]={label="資金を要求できる自社物件がありません",command="none",enabled=false,hint="物件を買収すると、その手元資金を要求できます"} end
        elseif category=="group" then
            -- Largest tiers first; super-scale groups carry a tag.
            local ids={}; for id in pairs(self.state.learnedGroups) do if D.groups[id] then ids[#ids+1]=id end end
            table.sort(ids,function(x,y)
                local rx,ry=A.tierRank[D.groups[x].tier] or 9,A.tierRank[D.groups[y].tier] or 9
                if rx~=ry then return rx<ry end; return D.groups[x].name<D.groups[y].name end)
            local b=self.engine.battle
            local allyIds={}; for id in pairs(self.state.alliances) do if M.IsAllied(self.state,id) then allyIds[#allyIds+1]=id end end
            table.sort(allyIds)
            for _,id in ipairs(allyIds) do
                local c=self.state.companies[id]; local amount=M.AllianceFundAmount(self.state,id)
                local used=b and b.allyRequests and b.allyRequests[id]; local against=b and b.defender==id
                rows[#rows+1]={id=id,command="ally",label="【同盟】"..c.name.."に資金を要求（+"..comma(amount).."）",
                    enabled=not used and not against and amount>0,
                    hint=used and "この交渉ではすでに支援を受けています" or (against and "交渉相手の同盟商会には頼めません")
                        or ("信頼 "..self.state.alliances[id].trust.." → "..(self.state.alliances[id].trust-C.alliance.fundTrust).."  /  0で同盟解消")}
            end
            local statuses=M.GroupStatusAll(self.state,ids)
            for _,id in ipairs(ids) do
                local group=statuses[id]; local tag=A.tierTag[group.tier] or ""
                if group then rows[#rows+1]={id=id,label=tag..group.name.."（"..group.count.."/"..group.minimum.."件）",group=group,command="group",
                    enabled=group.usable and true or false,hint=not group.usable and ("構成物件が不足（"..group.count.."/"..group.minimum.."件）") or nil} end
            end
            if #rows==0 then rows[1]={label="まだ閃いた連合や同盟はありません",command="none",enabled=false,hint="まだ閃いた連合や同盟はありません"} end
        elseif category=="tactic" then
            for _,tactic in ipairs(D.tactics) do if self.state.learnedTactics[tactic.id] then
                rows[#rows+1]={id=tactic.id,label=tactic.name.."（"..M.FormatMoney(tactic.cost).."）",tactic=tactic,command="tactic"}
            end end
            rows[#rows+1]={label="地元評議会へ根回し（"..M.FormatMoney(C.independence.stabilizeCost).."）",command="stabilize"}
        else
            local options,gap=self:TreasuryOptions()
            local situation=gap>0 and ("相手との差 "..comma(gap)) or ("自社が "..comma(-gap).." リード")
            for _,o in ipairs(options) do
                local enough=self.state.cash>=o.amount
                rows[#rows+1]={label=comma(o.amount).." ゴールド"..(o.tag and "（"..o.tag.."）" or ""),amount=o.amount,base=o.base,
                    command="treasury",enabled=enough,
                    hint=situation.."  /  "..(enough and ("商会資金 "..comma(self.state.cash).." → "..comma(self.state.cash-o.amount))
                        or ("商会資金が不足（現在 "..comma(self.state.cash).."）"))}
            end
        end
    elseif self.screen=="admin" then
        local left=self.admin and self.admin.left or 0; local s=self.state; local K=C.admin
        local function action(command,label,detail,enabled,hint)
            rows[#rows+1]={command=command,label=label,enabled=left>0 and enabled~=false,detailText=detail,
                hint=left<=0 and "今期の内政行動はすべて使いました" or hint}
        end
        local pct=function(x) return math.floor(x*100+.5).."%" end
        action("invest","増資　物件へ設備投資する","増資\n\n自社物件を1件選んで設備投資します。\n評価額 +"..pct(K.investValueGain).."・予想収益 +"..pct(K.investProfitGain).." が恒久的に上がります。\n費用は評価額の"..pct(K.investCostShare).."で、同じ物件へ重ねるたびに割高になります。")
        action("lobby","根回し　物件の負担を和らげる","根回し\n\n自社物件を1件選び、独立危険度を "..K.lobbyAmount.." 下げます。\n資金要求を重ねた物件の離反を防ぎます。\n費用は評価額の"..pct(K.lobbyCostShare).."（最低 "..K.lobbyMinimumCost.."）。")
        action("divest","売却　物件を傘下から外す","売却\n\n自社物件を1件選び、評価額の"..pct(K.divestShare).."で手放して中立に戻します。\n資金繰りは楽になりますが、総資産・収益・連合の構成物件は減ります。\n章の目標物件や本社を手放すと、目標達成から遠のきます。",#M.Owned(s)>0)
        local guardCost=M.GuardCost(s)
        action("guard","警備契約　買収攻撃に備える（"..comma(guardCost).."）","警備契約\n\n今後 "..K.guardPeriods.." 期のあいだ、敵商会が買収攻撃を仕掛けてくる確率を半分にします。\n費用は総資産の"..pct(K.guardCostShare).."（最低 "..comma(K.guardMinimumCost).."）。"
            ..((s.guardPeriods or 0)>0 and ("\n\n現在の警備契約：残り "..s.guardPeriods.." 期") or ""),s.cash>=guardCost,s.cash<guardCost and "商会資金が不足しています" or nil)
        local repay=math.min(s.debt or 0,math.floor(s.cash*K.repayCashShare))
        action("repay","債務返済　負債を繰り上げ返済する"..((s.debt or 0)>0 and ("（"..comma(repay).."）") or ""),"債務返済\n\n商会資金の半分までを使って負債を返し、評判を "..K.repayReputation.." 上げます。\n負債："..comma(s.debt or 0),
            (s.debt or 0)>0 and repay>0,(s.debt or 0)<=0 and "負債はありません" or (repay<=0 and "返済に回せる商会資金がありません" or nil))
        local room,bond=M.BondRoom(s)
        action("bond","社債発行　資金を借り入れる（+"..comma(bond).."）","社債発行\n\n総資産の"..pct(K.bondShare).."（最低 "..comma(K.bondMinimum).."）をすぐに調達します。\n返済額は利息 "..pct(K.bondInterest).." を加えた "..comma(math.ceil(bond*(1+K.bondInterest))).." で、決算ごとに利益から返します。\n負債が総資産の"..pct(K.bondDebtCap).."を超える発行はできません。",
            room,not room and "信用枠の上限に達しています" or nil)
        local sabotageCost=M.SabotageCost(s)
        action("sabotage","諜報工作　敵商会の資金を削る（"..comma(sabotageCost).."）","諜報工作\n\n敵商会を1つ選び、帳簿に手を回して資金の"..pct(K.sabotageDrain).."を失わせます。\n成功率は相手の守りの堅さで変わります（30〜80%）。\n失敗すると醜聞となり、評判 -"..K.scandalReputation.."、次の決算まで買収攻撃を受けやすくなります。",
            s.cash>=sabotageCost,s.cash<sabotageCost and "商会資金が不足しています" or nil)
        local hireCost=M.HireCost(s); local waiting=(s.envoyBattles or 0)>0
        action("hire","人材登用　腕利きの交渉役を雇う（"..comma(hireCost).."）","人材登用\n\n次の交渉（買収・防衛のどちらでも）に腕利きの交渉役が同席します。\n開始時から勢いが付き、自社の伝令待ちが "..K.hireSeconds.." 秒間 "..pct(K.hireWaitFactor).." に短縮されます。"
            ..(waiting and "\n\n交渉役はすでに待機しています" or ""),s.cash>=hireCost and not waiting,waiting and "交渉役はすでに待機しています" or (s.cash<hireCost and "商会資金が不足しています" or nil))
        local allies={}; for id,al in pairs(s.alliances) do if M.IsAllied(s,id) then allies[#allies+1]=s.companies[id].name.."（信頼 "..al.trust.."）" end end
        local allianceCost=M.AllianceCost(s); local full=M.AllianceCount(s)>=C.alliance.maxAlliances
        action("alliance","同盟交渉　他商会と同盟を結ぶ（"..comma(allianceCost).."）","同盟交渉\n\n敵商会を1つ選び、贈り物を添えて同盟を申し込みます（成功率10〜85%、失敗しても費用は戻りません）。\n同盟商会は買収攻撃を仕掛けてこず、交渉中は「グループ要求」から資金を要求できます。\n同盟商会の物件を買収すると信頼 -"..C.alliance.acquireTrust.."、資金を要求すると -"..C.alliance.fundTrust.."。信頼が0になると同盟は解消されます（決算ごとに +"..C.alliance.trustRecovery.."）。"
            .."\n\n現在の同盟："..(#allies>0 and table.concat(allies,"　") or "なし").."（最大 "..C.alliance.maxAlliances.."）",
            s.cash>=allianceCost and not full,full and "同盟は上限に達しています" or (s.cash<allianceCost and "商会資金が不足しています" or nil))
        -- "Finish" leads the list so all actions fit on one ledger page.
        local log=self.admin and self.admin.log or {}
        table.insert(rows,1,{command="finish",label="▶ 内政を終えて決算へ",detailText="内政を終える\n\n"
            ..(left>0 and ("残り "..left.." 行動を使わずに、") or "").."資金力ランキングと決算へ進みます。"
            .."\n\n今期の内政："..(#log>0 and ("\n"..table.concat(log,"\n")) or "なし")})
        if self.state.chapter>=3 then table.insert(rows,2,{label="交易拠点を育てる（内政行動の消費なし）",command="hub",detailText="交易拠点\n\n施設を建設して5つの能力を育てます。\n内政行動は使わず、同時工事2枠で運営します。\n工事・収益は決算で自動進行します。"}) end
    elseif self.screen=="admin_pick" then
        local kind=self.admin and self.admin.kind; local K=C.admin
        if kind=="alliance" then
            local ids={}; for id,c in pairs(self.state.companies) do
                if id~=C.playerId and id~=C.neutralId and not c.dissolved and (c.minChapter or 1)<=self.state.chapter then ids[#ids+1]=id end end
            table.sort(ids)
            local cost=M.AllianceCost(self.state)
            for _,id in ipairs(ids) do local c=self.state.companies[id]; local ok,why=M.CanAlly(self.state,id)
                rows[#rows+1]={id=id,command=kind,company=c,enabled=ok and self.state.cash>=cost,hint=not ok and why or (self.state.cash<cost and "商会資金が不足しています" or nil),
                    label=c.name..(ok and ("　成功率 "..math.floor(M.AllianceChance(self.state,c)*100+.5).."%") or ("　"..why)),
                    detailText=c.name.."\n\n資金："..comma(c.cash).."\n攻撃性："..math.floor((c.aggression or .5)*100).."\n所有物件："..#M.Owned(self.state,id).." 件"
                        .."\n\n贈り物の費用："..comma(cost)}
            end
        elseif kind=="sabotage" then
            local ids={}; for id,c in pairs(self.state.companies) do
                if id~=C.playerId and id~=C.neutralId and not c.dissolved and (c.minChapter or 1)<=self.state.chapter then ids[#ids+1]=id end end
            table.sort(ids)
            local cost=M.SabotageCost(self.state)
            for _,id in ipairs(ids) do local c=self.state.companies[id]
                rows[#rows+1]={id=id,command=kind,label=c.name.."　資金 "..M.FormatCompact(c.cash).."　成功率 "..math.floor(M.SabotageChance(self.state,c)*100+.5).."%",
                    enabled=self.state.cash>=cost,hint=self.state.cash<cost and "商会資金が不足しています" or nil,company=c,
                    detailText=c.name.."\n\n資金："..comma(c.cash).."\n守りの堅さ："..math.floor((c.defense or .5)*100).."\n所有物件："..#M.Owned(self.state,id).." 件"
                        .."\n\n成功すると資金 -"..comma(math.floor(c.cash*K.sabotageDrain)).."\n費用："..comma(cost)}
            end
            if #rows==0 then rows[1]={command="none",label="工作できる商会がありません",enabled=false,detailText="対象の商会がありません。"} end
        else
            for _,p in ipairs(M.Owned(self.state)) do
                local cost,after,enough
                if kind=="invest" then cost=M.InvestCost(self.state,p); after="評価額 "..M.FormatCompact(p.marketValue).." → "..M.FormatCompact(math.floor(p.marketValue*(1+K.investValueGain))); enough=self.state.cash>=cost
                elseif kind=="lobby" then cost=M.LobbyCost(self.state,p); after="負担 "..p.independenceRisk.." → "..math.max(0,p.independenceRisk-K.lobbyAmount); enough=self.state.cash>=cost and p.independenceRisk>0
                else cost=M.DivestPrice(self.state,p); after="売却額 +"..M.FormatCompact(cost); enough=true end
                local special=(p.companyHeadquarters or M.IsObjective(self.state,p.id)) and "　★目標・本社" or ""
                rows[#rows+1]={id=p.id,command=kind,label=p.name.."　"..after..(kind~="divest" and ("　費用 "..comma(cost)) or "")..special,enabled=enough,target=p,
                    hint=not enough and (self.state.cash<cost and "商会資金が不足しています" or "負担はすでにありません") or nil,
                    detailText=self:Detail(p).."\n\n"..(kind=="invest" and ("増資の費用："..comma(cost)) or (kind=="lobby" and ("根回しの費用："..comma(cost)) or ("売却額："..comma(cost).."（評価額の"..math.floor(K.divestShare*100).."%）")))}
            end
            if #rows==0 then rows[1]={command="none",label="自社物件がありません",enabled=false,detailText="対象となる自社物件がありません。"} end
        end
    elseif self.screen=="rankings" then
        for _,r in ipairs(self.rankingRows or {}) do rows[#rows+1]={id=r.id,label=r.name,ranking=r} end
    end
    return rows
end
function A:Selected(rows)
    rows=rows or self:Rows(); self.index=math.max(1,math.min(self.index,#rows)); return rows[self.index]
end
function A:Move(delta)
    if self.modal or self.screen=="result" then return end
    local rows=self:Rows(); if #rows>0 then self.index=(self.index-1+delta)%#rows+1 end
end
A.tierRank={tamriel=1,alliance=2,grand=3}
A.adminPickPrompt={alliance="同盟を申し込む商会を選んでください",invest="増資する物件を選んでください",lobby="根回しする物件を選んでください",divest="傘下から外す物件を選んでください",sabotage="工作を仕掛ける商会を選んでください"}
A.adminPickName={alliance="同盟交渉",invest="増資",lobby="根回し",divest="売却",sabotage="諜報工作"}
A.tierTag={tamriel="【全土】",alliance="【同盟】",grand="【大商圏】"}
A.battleCategories={{id="request",name="資金要求"},{id="group",name="グループ要求"},{id="tactic",name="駆け引き"},{id="treasury",name="自社資金"}}
function A:SwitchBattleCategory(delta)
    self.battleIndexes=self.battleIndexes or {}
    local current=self.battleCategory or 1
    self.battleIndexes[current]=self.index
    self.battleCategory=(current-1+delta)%#A.battleCategories+1
    self.index=self.battleIndexes[self.battleCategory] or 1
    -- The treasury list moves with the bids, so it always opens on the gap-closing amount.
    if A.battleCategories[self.battleCategory].id=="treasury" then
        for i,row in ipairs(self:Rows()) do if row.base then self.index=i end end
    end
end
-- Test/automation helper: jump to the category holding a command and select it.
function A:SelectBattleCommand(command,id)
    for c,category in ipairs(A.battleCategories) do
        self.battleCategory=c
        for i,row in ipairs(self:Rows()) do
            if row.command==command and (id==nil or row.id==id or row.amount==id) then self.index=i; return row end
        end
    end
end
function A:MovePage(delta)
    if self.screen=="battle" then
        if self.modal then return end
        return self:SwitchBattleCategory(delta)
    end
    self:Move(delta*(self.screen=="map" and C.ui.mapPageSize or C.ui.pageSize))
end
function A:Tab(delta)
    if self.screen=="battle" and not self.modal then return self:SwitchBattleCategory(delta) end
    if self.modal or self.screen=="battle" or self.screen=="result" or self.screen=="rankings"
        or self.screen=="admin" or self.screen=="admin_pick" or self.screen=="strategy" or self.screen=="delegate_pick" then return end
    self.tab=(self.tab-1+delta)%5+1
    self.screen=self.tab==1 and "map" or (self.tab==2 and "owned" or (self.tab==3 and "groups" or (self.tab==4 and "tactics" or "management"))); self.index=1
end
function A:ShowChapterIntro()
    local chapter=D.campaigns[self.state.chapter]; if not chapter then return end
    local status=M.CampaignStatus(self.state)
    local takeover=""
    local r=self.molagReport
    if r then
        self.molagReport=nil
        if r.count>0 then
            takeover="\n\n鎖の侵食：タムリエル全土の物件 "..r.count.." 件がモラグ・バル コンツェルンへ離反"
                .."\n（自社 "..r.fromPlayer.." 件 / 他商会 "..r.fromRivals.." 件 / 中立 "..r.fromNeutral.." 件）"
        end
        if r.fortification then
            takeover=takeover.."\n\n異界三中枢と最終居城が経済要塞化：総評価額 "..M.FormatCompact(r.fortification.totalValue)
                .."\nコンツェルン防衛資金 "..M.FormatCompact(r.fortification.treasury)
        end
    end
    local alliance=""
    if chapter.id==2 and M.IsAllied(self.state,C.campaign.chapterTwoAlly) then
        alliance="\n\n◆ フルブライト商会が盟約に応じ、自動的に同盟商会となりました。"
    end
    local newFacilities={}
    for _,f in ipairs(PBTrade.HubData.facilities) do if (f.minChapter or 3)==self.state.chapter then newFacilities[#newFacilities+1]=f.name end end
    local hubUnlock=#newFacilities>0 and ("\n新施設："..table.concat(newFacilities,"・")) or ""
    self.modal={campaign=true,background=chapter.background,text=chapter.title.."\n"..chapter.subtitle.."\n\n"..chapter.description
        ..alliance..takeover..hubUnlock..(self.state.chapter>=3 and ("\n\n交易拠点："..PBTrade.Hub.Size(self.state.chapter).."×"..PBTrade.Hub.Size(self.state.chapter).."区画 / 建設"..#PBTrade.Hub.Catalogue(self.state.chapter).."種類が利用可能") or "").."\n\n目標\n"..status.summary.."\n\n× / ○：交易地図へ"}
    if r then
        local flash=r.count>0 and ("鎖の侵食  "..r.count.."件が離反") or "最終居城が経済要塞化"
        self:Flash("defection",flash,3.2); self:Save()
    else self:Flash("chapter",chapter.title,2.8) end
end
function A:ShowTutorialPage()
    self.modal={action="tutorial",text="初回指南  "..self.tutorialPage.." / "..#tutorial.."\n\n"..tutorial[self.tutorialPage].."\n\n×：次へ　○：指南を終了"}
end
-- Title screen: shown whenever the ledger opens outside a negotiation.
function A:ShowTitle()
    -- A deliberate return to the title also ends any story playback.  Scene
    -- restoration must not call this while an opening is still in progress.
    self.opening=nil; self.screen="title"; self.index=1; self.modal=nil
    self:RefreshCurrentLocation()
end
function A:TitleStatus()
    local s=self.state
    if not s.companyName then return "商会はまだ興されていません" end
    if s.campaignComplete then
        local status=M.CampaignStatus(s)
        return (s.trueEnding and "真のエンディング到達" or "最後の大買収").."    "..status.short.."    第"..M.CurrentPeriod(s).."期"
    end
    local chapter=D.campaigns[s.chapter]
    return (chapter and chapter.title or ("第"..s.chapter.."章")).."    第"..M.CurrentPeriod(s).."期    総資産 "..M.FormatCompact(M.Assets(s))
end
-- Preview the current ESO place.  An unregistered place becomes a title command; registration
-- itself happens only when the player selects it.  Buying still starts from the regional map.
function A:RefreshCurrentLocation(record)
    local catalog=PBTrade.LiveCatalog
    if not catalog then return nil,false end
    local property,observed,registered=catalog.PreviewCurrent(self.state,record)
    self.currentLocationRecord=observed
    self.currentRegistration=property and not registered and property or nil
    return property,registered
end
function A:ConfirmCurrentRegistration()
    local catalog=PBTrade.LiveCatalog
    if not catalog then self.notice="現在地を物件として登録できませんでした"; return false end
    local property,newlyVisited=catalog.Apply(self.state,self.currentLocationRecord)
    if not property then self.notice="現在地を物件として登録できませんでした"; self:RefreshCurrentLocation(); return false end
    self.currentRegistration=nil
    if self.saved then self.saved.pendingVisits=nil end
    local zone=D.zoneById[property.zone]
    self.notice=property.name.."を物件登録しました。交易地図の「"..(zone and zone.name or "該当地域").."」から買収できます"
    if newlyVisited then self:Flash("discovery",property.name.."を物件登録！",2.8) end
    self:Save(); self:FlushSave()
    return newlyVisited
end
function A:PromptAcquisition(property)
    if not property then self.notice="現在地に買収できる物件が見つかりません"; return false end
    if property.owner==C.playerId then self.modal={text=self:Detail(property).."\n\n× / ○：閉じる"}; return false end
    if not M.IsAvailable(self.state,property) then self.notice="この物件は現在の章ではまだ買収できません"; return false end
    if not self.state.unlocked[property.zone] then self.notice="この地域への交易路がまだ開いていません"; return false end
    if not M.IsPropertyVisited(self.state,property) then self.notice="実在地点がまだ物件登録されていません"; return false end
    local ally=M.IsAllied(self.state,property.owner) and self.state.alliances[property.owner]
    local warning=ally and ("\n\n◆ 同盟商会 "..self.state.companies[property.owner].name.." の物件です。\n買収に成功すると信頼 -"..C.alliance.acquireTrust.."（現在 "..ally.trust.."）。0になると同盟は解消されます。") or ""
    local value,headquarters=M.NegotiationValue(self.state,property)
    if property.finalAcquisition then
        warning=warning.."\n\n◆ 真の最終物件です。買収成立で真のエンディングへ進みます。\nこの交渉は支配人へ委任できません。"
    end
    if headquarters then
        local body=property.companyBody
        warning=warning.."\n\n◆ "..self.state.companies[property.owner].name..(body and "の商会本体です。" or "の中枢本社です。")
            .."グループ全体が総力で守ります。\n交渉価値："..comma(value).."（グループ総資産）\n"
            ..(body and "この商会本体を買収すると、全傘下物件を取得します。" or "全中枢を買収すると、商会ごと傘下に収められます。")
    end
    local advice=self:StanceAdvice(M.NegotiationStances(self.state,property))
    if advice then warning=warning.."\n\n"..advice end
    local hubAdvice=M.HubSummary(self.state,property)
    if hubAdvice then warning=warning.."\n\n"..hubAdvice end
    self.pendingId=property.id
    self.modal={action="start",text=property.name
        .."\n\n買収交渉を始めますか？\n単体調達で物件の負担が増えます。\n投入資金は結果にかかわらず消費します。"
        ..warning.."\n\n×：開始　○：戻る"}
    return true
end
-- Opening: × completes the text, then turns the page; ○ skips.
local function play(kind) if PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play(kind) end end
-- Plays a sound-novel page set: the opening by default, or the true ending.
function A:ShowOpening(nextStep,story)
    local storyId=story or "opening"
    local source=D[storyId]
    if type(source)~="table" or #source==0 then
        self.notice="物語データを読み込めませんでした"
        return false
    end
    local pages={}; local company=M.CompanyName(self.state):gsub("%%","%%%%")
    for _,page in ipairs(source) do
        if type(page)=="table" and type(page.bg)=="string" and type(page.text)=="string" and page.text~="" then
            pages[#pages+1]={bg=page.bg,text=(page.text:gsub("{company}",company)),speaker=page.speaker,portrait=page.portrait}
        end
    end
    if #pages==0 then self.notice="物語データを読み込めませんでした"; return false end
    self.opening={page=1,time=0,pageTime=0,next=nextStep or "title",pages=pages,story=storyId}
    self.screen="opening"; self.modal=nil; play("openingStart")
    return true
end
function A:OpeningPage()
    local o=self.opening; if not o then return nil end
    local page=o.pages[o.page]; if not page then return nil end
    return page,PBTrade.Story.Timeline(page.text)
end
function A:FinishOpening()
    local o=self.opening; if not o then return end
    self.opening=nil; play("openingEnd")
    if o.next=="map" then self.screen="map"; self.tab=1; self.index=1
    elseif o.next=="naming" then
        self.namingFirst=true; self.pendingName=self.state.companyName
        self.screen="naming"; self.index=1; self.notice="あなたの商会の名前を決めてください"
    else self:ShowTitle() end
end
function A:OpeningAct(action)
    local o=self.opening; if not o then return end
    if action=="back" then return self:FinishOpening() end
    if action~="confirm" then return end
    local page,timeline=self:OpeningPage()
    if not page then return self:FinishOpening() end
    if o.time<timeline.total then o.time=timeline.total; return end
    if o.page>=#o.pages then return self:FinishOpening() end
    o.page=o.page+1; o.time=0; o.pageTime=0; play("openingPage")
end
-- Typed names arrive from the UI's edit box; invalid (empty) input keeps the previous choice.
-- A typed name is final: it is applied at once (no second confirmation step to miss).
function A:SubmitTypedName(text)
    local name=M.NormalizeCompanyName(text)
    if not name then self.notice="商会名が空です。入力し直すか候補から選んでください"; return false end
    self.pendingName=name
    return self:AcceptCompanyName()
end
function A:AcceptCompanyName()
    if not self.pendingName then self.notice="名前を選ぶか入力してください"; return false end
    if not M.SetCompanyName(self.state,self.pendingName) then
        self.pendingName=nil; self.notice="その名前は使えません。入力し直すか候補から選んでください"; return false
    end
    self:Save(); self:FlushSave()
    if self.namingFirst then
        self.namingFirst=false; self.screen="map"; self.tab=1; self.index=1
        self.notice="「"..self.state.companyName.."」の帳簿が開かれました"
        self:Flash("chapter",self.state.companyName.." 設立",2.8)
        self:BeginSession()
    else self:ShowTitle(); self.notice="商会名を「"..self.state.companyName.."」に変更しました" end
    return true
end
function A:TitleAct(action)
    if action=="back" then
        if self.screen=="naming" then self:ShowTitle() else self.closeRequested=true end
        return
    end
    if action~="confirm" then return end
    local row=self:Selected(); if not row then return end
    if row.command=="registerCurrent" then self:ConfirmCurrentRegistration(); self.index=1; return end
    if row.command=="found" then self:ShowOpening("naming"); return end
    if row.command=="opening" then self:ShowOpening("title"); return end
    if row.command=="trueEnding" then self:ShowOpening("title","trueEnding"); return end
    if row.command=="found" or row.command=="rename" then
        self.namingFirst=row.command=="found"; self.pendingName=self.state.companyName
        self.screen="naming"; self.index=1
        self.notice=self.namingFirst and "あなたの商会の名前を決めてください" or "新しい商会名を決めてください"
    elseif row.command=="continue" then
        self.screen="map"; self.tab=1; self.index=1; self:BeginSession()
    elseif row.command=="keyboard" then self.keyboardRequested=true
    elseif row.command=="pick" then
        self.pendingName=row.name; self.notice="「"..row.name.."」でよければ「決定」を選んでください"
        for i,r in ipairs(self:Rows()) do if r.command=="accept" then self.index=i end end
    elseif row.command=="accept" then self:AcceptCompanyName()
    end
end
function A:BeginEndless()
    local report=M.StartEndless(self.state,self.random)
    if not report then return end
    self:Save(); self.screen="map"; self.tab=1; self.index=1
    local target=report.target
    local state=report.registered and "登録済み。グレナンブラの交易地図から交渉できます。"
        or "未登録。ESO本編で現地へ行き、タイトル画面から物件登録してください。"
    self.modal={campaign=true,background="chapter_5",text="最後の大買収\n\n戦は終わっても、帳簿には最後の一頁が残されています。\n\n目標：トール・ドライオク\n評価額："..(target and comma(target.marketValue) or "100京").." ゴールド\n"..state.."\n\nこの買収を成立させると、真のエンディングを迎えます。\n\n× / ○：交易地図へ"}
    self:Flash("chapter","最後の大買収　開幕",3)
end
function A:BeginSession()
    if self.introShown then return end; self.introShown=true
    if not self.tutorialComplete then self.tutorialPage=1; self:ShowTutorialPage()
    elseif self.state.strategyPending then
        self.strategySeason=M.BeginStrategicSeason(self.state,self.random)
        self.strategyReturnScreen="map"; self.screen="strategy"; self.index=1; self.modal=nil
        self.notice="未決の交易会議があります。次の10期の経営方針を選択してください"
    else self:ShowChapterIntro() end
end
function A:ChooseTradePolicy(id)
    local ok,policy=M.ChooseTradePolicy(self.state,id); if not ok then self.notice=policy; return end
    local season=self.strategySeason; local report=self.pendingSettlementText or ""
    local chapterIntro=self.strategyChapterIntro
    self.strategySeason=nil; self.pendingSettlementText=nil; self.strategyChapterIntro=nil
    self.screen=chapterIntro and "map" or (self.strategyReturnScreen or "properties"); self.strategyReturnScreen=nil; self.index=1
    self:Save(); self:FlushSave(); self:Flash("period",policy.name.."を採択",3)
    if chapterIntro then self.notice=report:gsub("\n","  "); self:ShowChapterIntro()
    else
        self.modal={text=report.."\n\n◆ 市場情勢："..season.event.name.."\n"..season.event.description
            .."\n\n◆ 採択方針："..policy.name.."\n"..policy.description.."\n\n× / ○：台帳へ戻る"}
    end
end
function A:ExecuteDelegation(id)
    local ok,report=M.DelegateAcquisition(self.state,id,self.random)
    if not ok then self.notice=report; self.screen="delegate_pick"; return end
    self.engine.battle=nil; self.counterattackChecked=false
    self.delegationNotice=report.success and (report.property.name.."の委任買収に成功（"..comma(report.cost).."）")
        or (report.property.name.."の委任買収に失敗（調査費 "..comma(report.cost).."）")
    self.notice=self.delegationNotice
    self:Flash(report.success and "settlement" or "defection",self.delegationNotice,3)
    self:Save(); self:CounterattackCheck()
end
function A:Act(action)
    if self.screen=="hub" and self.modal and self.modal.hubPolicy then return self:HubPolicyAct(action) end
    if self.screen=="hub" and not self.modal then return self:HubAct(action) end
    if self.screen=="opening" then return self:OpeningAct(action) end
    if (self.screen=="admin" or self.screen=="admin_pick") and not self.modal then return self:AdminAct(action) end
    if (self.screen=="title" or self.screen=="naming") and not self.modal then return self:TitleAct(action) end
    if self.modal then
        if action=="confirm" then
            local pending=self.modal.action; self.modal=nil
            if pending=="hubBuild" then self:ConfirmHubBuild()
            elseif pending=="hubChange" then self:ConfirmHubChange()
            elseif pending=="tutorial" then
                self.tutorialPage=self.tutorialPage+1
                if self.tutorialPage<=#tutorial then self:ShowTutorialPage() else self.tutorialComplete=true; self:Save(); self:FlushSave(); self:ShowChapterIntro() end
            elseif pending=="start" then
                local ok,why=self.engine:Start(self.pendingId)
                if ok then self.screen="battle"; self.index=1; self.battleCategory=1; self.battleIndexes={}; self.counterattackChecked=false else self.notice=why end
            elseif pending=="withdraw" then self.engine:Finish("withdrawn"); self.screen="result"
            elseif pending=="delegate" then self:ExecuteDelegation(self.pendingDelegateId)
            elseif pending=="endlessOffer" then self:BeginEndless() end
        elseif action=="back" and self.modal.action=="tutorial" then self.modal=nil; self.tutorialComplete=true; self:Save(); self:FlushSave(); self:ShowChapterIntro()
        elseif action=="back" or action=="info" or action=="detail" then self.modal=nil; self.hubOrder=nil end
        return
    end
    if action=="previous" then return self:Tab(-1) end
    if action=="next" then return self:Tab(1) end
    if action=="info" and self.screen=="battle" then return self:RequestWithdraw() end
    if action=="info" then
        self.modal={text="交易の手引き\n\n地域 → 物件 → ×で交渉開始。\n相手は左、自社は右。交渉は待ち時間中もリアルタイムで進みます。\n資金要求は独立危険度を上げ、離反判定を発生させます。\n必要数がそろった系列の構成物件へ資金要求すると連合を閃くことがあり、その場で連合調達が発動します。\n根回しは最も危険な自社物件を安定させます。\n投入資金は不成立・撤退でも戻りません。\n10期ごとの交易会議で市場事件に対応する経営方針を選びます。\n第2章からは相手が「構え」で守ることがあります。構えが立つ間は資金が効きにくく、対応する駆け引き・グループ・同盟で崩すと積んだ出資が満額で効き始めます。\n通常物件は経営台帳から委任できます。商会本体は地域の物件一覧から直接買収でき、成功すると傘下物件も取得します。章目標・商会本体・中枢・最終居城は委任不可の重要交渉です。\n各交渉後に敵の攻撃判定、内政、資金力ランキング、決算があります。"}; return
    end
    if self.screen=="strategy" then
        local row=self:Selected()
        if action=="confirm" and row and row.policy then self:ChooseTradePolicy(row.id)
        elseif action=="detail" and row and row.policy then self.modal={text=row.policy.name.."\n\n"..row.policy.description.."\n\n× / ○：閉じる"} end
        return
    end
    if self.screen=="result" then
        if action=="confirm" or action=="back" then self:AfterBattle() end
        return
    end
    if self.screen=="rankings" and (action=="confirm" or action=="back") then
        local report=M.SettleCycle(self.state)
        local deals=M.RivalTurn(self.state,self.random)
        local nextChapter=M.AdvanceCampaign(self.state)
        local season=M.BeginStrategicSeason(self.state,self.random)
        if M.CheckTrueEnding(self.state) then
            -- Every property is ours: the true ending plays, then the ledger (free play) resumes.
            self:Save(); self:FlushSave(); self:ShowOpening("title","trueEnding"); self:Flash("ending","真のエンディング",4)
            return
        end
        local chapterTakeovers=nextChapter and not nextChapter.ending and M.CheckTakeovers(self.state) or {}
        if nextChapter and not nextChapter.ending then self.molagReport=M.MolagTakeover(self.state,self.random) or self.molagReport end
        self.screen=nextChapter and "map" or "properties"; self.index=1; self:Save(); self:FlushSave()
        local reportText="第"..report.cycle.."期 決算\n\n事業収益："..comma(report.gross).." ゴールド\n負債返済："..comma(report.debtPayment)
            .."\n手取："..comma(report.net).."\n調達余力回復："..comma(report.reserveRecovered)
            .."\n全市場の評価増："..M.FormatCompact(report.marketGrowth).."\n最高物件価格："..M.FormatCompact(report.highestValue)
        if self.state.chapter>=3 then
            reportText=reportText.."\n拠点純収益："..comma(report.hub.net).." ゴールド"
            if #report.hub.completed>0 then
                reportText=reportText.."\n工事完了："..table.concat(report.hub.completed,"・")
                PBTrade.Audio.Play("discovery")
            end
            if report.hub.policy then reportText=reportText.."\n拠点方針："..report.hub.policy end
            if report.hub.event then
                reportText=reportText.."\n拠点事件："..report.hub.event.name.."（"..report.hub.event.description.." / "..report.hub.event.duration.."期）"
                PBTrade.Audio.Play(report.hub.event.adverse and "statusNegative" or "statusPositive")
            end
            if #(report.hub.districts or {})>0 then
                reportText=reportText.."\n専門地区成立："..table.concat(report.hub.districts,"・")
                PBTrade.Audio.Play("discovery")
            end
        end
        if #deals>0 then
            local lines={}
            for i=1,math.min(#deals,C.rivals.reportLines) do local d=deals[i]
                lines[#lines+1]=self.state.companies[d.buyer].name.." ← "..d.property.name
                    .."（"..(d.seller==C.neutralId and "中立" or self.state.companies[d.seller].name).."）"
            end
            reportText=reportText.."\n\n商会動向：買収 "..#deals.." 件\n"..table.concat(lines,"\n")..(#deals>C.rivals.reportLines and ("\nほか "..(#deals-C.rivals.reportLines).." 件") or "")
        end
        for _,t in ipairs(chapterTakeovers) do
            reportText=reportText.."\n\n◆ "..t.name.."を傘下に収めた！（押さえていた本社により商会を解体）\n傘下物件 "..t.count.." 件と資金 "..comma(t.cash).." を獲得"
            self:Flash("takeover",t.name.."を傘下に！　物件 "..t.count.." 件",4)
        end
        if M.CanRebuild(self.state) then
            local _,grant=M.RebuildTerms(self.state)
            reportText=reportText.."\n\n資金が尽きかけています。経営台帳から再建融資（+"..comma(grant).."）を申請できます"
        end
        if nextChapter and nextChapter.ending then
            self.tab=1; self.modal={campaign=true,background="chapter_5",text="交易戦終結\n\nモラグ・バル コンツェルンの中枢契約は破棄され、異界へ延びた鎖は断たれました。\n"..M.CompanyName(self.state).."はタムリエル第一の交易組織として新しい帳簿を開きます。\n\n"..reportText.."\n\nしかし、最後の証文――トール・ドライオクが残されています。\n\n×：最後の大買収へ　○：自由経営のまま（経営台帳からいつでも開始）",action="endlessOffer"}; self:Flash("ending","交易戦終結",4)
        elseif season then
            self.strategySeason=season; self.pendingSettlementText=reportText; self.strategyChapterIntro=nextChapter and true or nil
            self.strategyReturnScreen=nextChapter and "map" or "properties"; self.screen="strategy"; self.index=1; self.modal=nil
            self.notice="第"..report.cycle.."期 交易会議　市場情勢「"..season.event.name.."」を受け、次の10期の方針を選択してください"
            self:Flash("period","交易会議　"..season.event.name,3)
        elseif nextChapter then self.tab=1; self.notice=reportText:gsub("\n","  "); self:ShowChapterIntro()
        else self.modal={text=reportText.."\n\n× / ○：台帳へ戻る"}; self:Flash("settlement","決算  +"..M.FormatMoney(report.net),2.4) end
        return
    end
    local row=self:Selected()
    if action=="detail" and row and (row.property or row.group or row.tactic or row.command) then
        local text=row.property and self:Detail(row.property)
            or (row.group and self:GroupDetail(row.group)
            or (row.tactic and self:TacticDetail(row.tactic) or self:ManagementDetail(row)))
        self.modal={text=text.."\n\n× / ○：閉じる"}; return
    end
    if action=="back" then
        if self.screen=="battle" then self.closeRequested=true
        elseif self.screen=="properties" then self.screen="map"; self.index=1
        elseif self.screen=="delegate_pick" then self.screen="management"; self.index=1
        else self.closeRequested=true end
        return
    end
    if action~="confirm" or not row then return end
    if self.screen=="map" then
        if not self.state.unlocked[row.id] then self.notice="所有物件を増やすと交易路が開きます（初期2件から2件ごとに拡張）"; return end
        self.zone=row.id; self.state.visited[row.id]=true; self.screen="properties"; self.index=1
    elseif self.screen=="properties" or self.screen=="owned" then
        if row.property.owner==C.playerId then self.modal={text=self:Detail(row.property)}
        elseif not M.IsPropertyVisited(self.state,row.property) then
            self.notice="実在地点は現地で物件登録すると、以後どこからでも買収できます"
            self.modal={text=row.label.."\n\n未登録の実在地点です。\nESO本編でこの場所へ移動して物件登録すると、以後は交易地図からどこにいても買収できます。\n\n× / ○：閉じる"}
        else self:PromptAcquisition(row.property) end
    elseif self.screen=="delegate_pick" then
        if row.enabled==false or not row.property then self.notice=row.hint or "委任できません"; return end
        self.pendingDelegateId=row.id
        self.modal={action="delegate",text=row.property.name.."\n\n支配人へ通常買収を委任しますか？\n成功率："..math.floor(row.chance*100+.5).."%"
            .."\n成功時："..comma(row.cost).." ゴールド\n失敗時："..comma(row.failureCost).." ゴールド"
            .."\n\nこの買収で今期が進み、敵の買収攻撃判定も行われます。\n\n×：委任する　○：戻る"}
    elseif self.screen=="groups" then
        if row.group then self.modal={text=self:GroupDetail(row.group).."\n\n× / ○：閉じる"} end
    elseif self.screen=="tactics" then
        self.modal={text=self:TacticDetail(row.tactic).."\n\n× / ○：閉じる"}
    elseif self.screen=="management" then
        if row.command=="hub" then return self:OpenHub()
        elseif row.command=="rebuild" then
            local ok,value=M.Rebuild(self.state); self.notice=ok and "再建融資を受けました" or value
            if ok then self:Save(); self:Flash("settlement","再建融資  +"..value,2.5) end
        elseif row.command=="skip" then return self:SkipPeriod()
        elseif row.command=="delegate" then self.screen="delegate_pick"; self.index=1; self.notice="通常物件を選択してください。章目標・本社・最終居城は委任できません"
        elseif row.command=="endless" then return self:BeginEndless()
        elseif row.command=="assetRoot" then
            if row.enabled==false then self.notice=row.hint; return end
            local index=PBTrade.Assets.NextRoot()
            self.notice="画像の読み込み先を "..(index==1 and "① アドオン相対" or "② ESOの格納先").." に切り替えました。表示されるか確認してください"
        elseif row.command=="music" then
            local Au=PBTrade.Audio; if not Au or Au.musicBroken then self.notice="BGMはこの環境では利用できません"; return end
            Au.SetMusicEnabled(not Au.musicEnabled,self.screen); if self.saved then self.saved.music=Au.musicEnabled end
            self.notice="BGMを"..(Au.musicEnabled and "オン" or "オフ").."にしました"
        elseif row.command=="here" or row.command=="assets" then self.modal={text=self:ManagementDetail(row).."\n\n× / ○：閉じる"}
        elseif row.command=="campaign" then self.modal={text=row.status.chapter.title.."\n\n"..row.status.chapter.description.."\n\n進行\n"..row.status.summary}
        else self.modal={text="経営状況\n\n商会資金："..comma(self.state.cash).."\n資金力："..comma(M.FundingPower(self.state)).."\n負債："..comma(self.state.debt).."\n評判："..self.state.reputation.."\n現在：第"..M.CurrentPeriod(self.state).."期\n決算回数："..self.state.cycles.."\n再建回数："..self.state.rebuilds} end
    elseif self.screen=="battle" then
        local ok,why,info
        if row.enabled==false then self.notice=row.hint or "今は実行できません"; return end
        local bidBefore=self.engine.battle.playerBid
        if row.command=="request" then ok,why,info=self.engine:Request(row.id)
        elseif row.command=="group" then ok,why,info=self.engine:RequestGroup(row.id)
        elseif row.command=="ally" then ok,why,info=self.engine:RequestAlly(row.id)
            if ok and info.broken then self:Flash("defection",self.state.companies[row.id].name.."との同盟が解消された",3) end
        elseif row.command=="tactic" then ok,info=self.engine:UseTactic(row.id); why=not ok and info or nil
        elseif row.command=="stabilize" then ok,why=self.engine:Stabilize()
        else ok,why=self.engine:Treasury(row.amount) end
        self.notice=ok and "出資・工作が届きました" or why
        if ok then self:Save(); if row.command=="tactic" then self:StartTacticScene(info) end end
        if ok and info and info.group then
            -- The call goes out first; the group's coins only start falling once it has been heard.
            self.groupCall={name=info.group.name,time=0,heldBid=bidBefore}
            if PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play("groupCall") end
        end
        if ok and info then
            local messages={}
            for _,id in ipairs(info.discoveries or {}) do messages[#messages+1]=D.groups[id].name.."を閃いた！" end
            if #(info.discoveries or {})>0 and info.group then messages[#messages+1]=info.group.name.."をそのまま発動します。" end
            if info.defected==true then messages[#messages+1]=info.property.name.."が離反しました。"
            elseif type(info.defected)=="table" then for _,p in ipairs(info.defected) do messages[#messages+1]=p.name.."が離反しました。" end end
            if #messages>0 then
                local defected=info.defected==true or (type(info.defected)=="table" and #info.defected>0)
                local discovered=#(info.discoveries or {})>0
                self.modal={pauseBattle=discovered,text=table.concat(messages,"\n").."\n\n× / ○：交渉へ戻る"}
                self:Flash(defected and "defection" or (discovered and "groupDiscovery" or "discovery"),messages[1],2.5)
                -- A group discovery always gets its own cue, even alongside a defection alert.
                if defected and discovered and PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play("groupDiscovery") end
            end
        end
    end
end
function A:ManagementDetail(row)
    if row.command=="campaign" then
        return row.status.chapter.title.."\n\n"..row.status.chapter.description.."\n\n進行\n"..row.status.summary
    elseif row.command=="strategyStatus" then
        local policy,event=M.ActivePolicy(self.state),M.ActiveMarketEvent(self.state)
        return "交易会議\n\n10期ごとに市場事件が発生し、次の10期の経営方針を選びます。"
            .."\n\n現在の方針："..(policy and (policy.name.."\n"..policy.description.."\n残り "..math.max(0,(self.state.policyUntil or 0)-self.state.cycles).." 期") or "なし")
            .."\n\n市場情勢："..(event and (event.name.."\n"..event.description) or "平常")
    elseif row.command=="delegate" then
        return "委任買収\n\n通常物件の買収を支配人へ任せ、リアルタイム交渉を省略します。成功時は評価額の"
            ..math.floor(C.delegation.successCostShare*100).."%、失敗時は調査費として"..math.floor(C.delegation.failureCostShare*100)
            .."%を支払います。評判・相手の防衛力・経営方針・市場事件で成功率が変わります。"
            .."\n\n章目標、本社、モラグ・バルの居城、同盟商会の物件は必ずプレイヤー自身が交渉します。"
    elseif row.command=="music" then
        return "BGM\n\nESOのUI音楽を画面ごとに切り替えます。\nタイトル・オープニング：エンディングの曲\n台帳・内政・ランキング：トリビュート（カード遊戯）の曲\n交渉：決闘の曲\n\n× でオン／オフを切り替えます。"
    elseif row.command=="endless" then
        local status=M.CampaignStatus(self.state)
        return "最後の大買収\n\nグレナンブラの実在地点「トール・ドライオク」を現地で物件登録し、交易地図から買収してください。\n評価額は100京ゴールド。第5章クリア時点の商会資金と傘下物件を総動員する最終交渉です。\n成立すると真のエンディングを見られます。\n\n現在："..status.short
    elseif row.command=="assetRoot" then
        return "画像の読み込み先\n\n独自画像を読み込むフォルダの指定です。\n① アドオン相対：PBsTradeGame/assets/…（PBsTetrisと同じ標準の方式）\n② ESOの格納先：ESOが報告するアドオンの実フォルダ\n\n画像が表示されない場合に × で切り替えて、表示されるほうを選んでください。\n切り替えはこのプレイ中だけ有効で、次に起動すると①に戻ります。"
    elseif row.command=="skip" then
        return "今期の交渉を見送る\n\n買収交渉を行わずに今期を終えます。\n敵商会の攻撃判定・内政・資金力ランキング・決算はいつもどおり行われます。\n買収できる物件が残っていない時や、資金を貯めたい時に。"
    elseif row.command=="assets" then
        return "画像の読み込み確認\n\n"..PBTrade.Assets.Describe()
    elseif row.command=="here" then
        return "現在地の確認\n\n"..(PBTrade.LiveCatalog and PBTrade.LiveCatalog.Describe(self.state) or "取得できません")
            .."\n\nESOの実在地点は現地で一度物件登録すると、以後はどこからでも交易地図を通じて買収できます。\n屋内（住宅・一部の酒場・洞窟）では、その場所の名前で照合します。"
    elseif row.command=="rebuild" then
        local need,grant,cheapest=M.RebuildTerms(self.state)
        return "再建融資\n\n資金力が"..comma(need).."未満のとき、"..comma(grant)
            .."ゴールドを借り入れます。\n（最も安い買収候補"..(cheapest and ("「"..cheapest.name.."」評価額 "..comma(cheapest.marketValue)) or "なし").."に合わせて変動）"
            .."\n返済は各決算の利益から行い、評判が"..C.economy.rebuildReputationCost.."低下します。"
            .."\n\n現在："..(M.CanRebuild(self.state) and "申請可能" or "申請条件を満たしていません")
    end
    return "経営状況\n\n商会資金："..comma(self.state.cash).."\n資金力："..comma(M.FundingPower(self.state))
        .."\n負債："..comma(self.state.debt).."\n評判："..self.state.reputation.."\n決算回数："..self.state.cycles
        .."\n再建回数："..self.state.rebuilds.."\n\n決算では所有物件から利益を得て、物件の調達余力が回復します。"
end
function A:TacticDetail(tactic)
    local rule=tactic.learn; local condition=rule.starting and "初期習得"
        or rule.category and (D.categories[rule.category].."を所有して交渉終了")
        or rule.defense and "防衛戦終了" or rule.result=="won" and "買収成功" or "買収失敗"
    return tactic.name.."\n\n"..tactic.description.."\nコスト："..M.FormatMoney(tactic.cost).." ゴールド"
        .."\n習得："..condition..(rule.chance and " / "..math.floor(rule.chance*100).."%" or "")
        .."\n状態："..(self.state.learnedTactics[tactic.id] and "習得済み" or "未習得")
        .."\n抵抗判定："..tactic.resistanceKey
end
-- Special action (□ during a negotiation): one press opens the withdraw confirmation.
function A:RequestWithdraw()
    local b=self.engine.battle
    if not b or b.result then return end
    self.modal={action="withdraw",text="交渉から撤退しますか？\n投入した資金は戻りません。\n"..(b.mode=="defense" and "防衛対象の物件を失います。\n" or "").."\n×：撤退する　○ / □：続行"}
end
function A:ShowRankings()
    if self.lastRecoveredBattle~=self.engine.battle then
        self.lastRecoveredBattle=self.engine.battle
        local recovery=M.PassiveRecoveryAmount(self.state)
        for _,p in ipairs(M.Owned(self.state)) do p.independenceRisk=math.max(0,p.independenceRisk-recovery) end
    end
    self.rankingRows=M.Rankings(self.state)
    self.rankingPeriod=M.CurrentPeriod(self.state)
    self.index=1
    for i,r in ipairs(self.rankingRows) do
        r.previousRank=self.previousRanks[r.id] or r.rank
        r.rankChange=r.previousRank-r.rank
        self.previousRanks[r.id]=r.rank
        if r.id==C.playerId then self.index=i end
    end
    self.screen="rankings"; self.modal=nil
    self.notice=self.counterattackNotice or "交渉と防衛処理が完了しました"
    self:Flash("period","第"..self.rankingPeriod.."期  資金力ランキング",2.4)
end
function A:AfterBattle()
    local b=self.engine.battle
    if not b or not b.result then return end
    local target=self.state.properties[b.targetId]
    if b.mode~="defense" and b.result=="won" and target and target.finalAcquisition and M.CheckTrueEnding(self.state) then
        -- The final deed closes the story immediately; no routine counterattack or settlement
        -- is allowed to interrupt the true-ending payoff.
        self:Save(); self:FlushSave(); self:ShowOpening("title","trueEnding"); self:Flash("ending","真のエンディング",4)
        return
    end
    if b.mode=="defense" or self.counterattackChecked then self:StartAdministration(); return end
    self:CounterattackCheck()
end
-- Skip this period's negotiation: the counterattack check, domestic affairs, rankings and
-- settlement still run, so periods can always advance even when nothing is left to buy.
function A:SkipPeriod()
    self.engine.battle=nil; self.counterattackChecked=false
    self:CounterattackCheck()
end
function A:CounterattackCheck()
    self.counterattackChecked=true
    local attack,message=M.RollCounterattack(self.state,self.random)
    self.counterattackNotice=self.delegationNotice and (self.delegationNotice.." / "..message) or message
    self.delegationNotice=nil
    if attack then
        local ok,why=self.engine:Start(attack.propertyId,attack.companyId)
        if ok then
            self.screen="battle"; self.index=1; self.battleCategory=1; self.battleIndexes={}
            self.notice=message
            if PBTrade.Audio and PBTrade.Audio.Play then
                -- A sharp warning followed by the battle horn makes an incoming acquisition
                -- unmistakable even when the player is not looking at the result flow.
                PBTrade.Audio.Play("counterattackWarning")
                PBTrade.Audio.Play("counterattack")
            end
            self.modal={pauseBattle=true,text="敵商会が買収を仕掛けました\n\n"..message.."\n攻撃元："..self.state.properties[attack.sourcePropertyId].name
                .."\n攻勢："..(attack.threat or "買収攻勢").."\n敵の動員可能資金："..M.FormatMoney(attack.funding or 0)
                ..(M.HubSummary(self.state,self.state.properties[attack.propertyId],attack.companyId) and ("\n"..M.HubSummary(self.state,self.state.properties[attack.propertyId],attack.companyId)) or "")
                .."\n\n境目を左端まで押し返せば防衛成功。\n右端到達・期限切れ・撤退では物件を失います。\n防衛が終わると内政へ進みます。\n\n×：防衛戦へ"}
            return
        end
        self.counterattackNotice="買収攻撃を開始できませんでした："..why
    end
    self:StartAdministration()
end
-- Domestic affairs: after the defense check and before rankings and the settlement.
function A:StartAdministration()
    self.admin={left=C.admin.actions,log={}}; self.screen="admin"; self.index=2; self.modal=nil
    self.notice=(self.counterattackNotice and (self.counterattackNotice.."。") or "").."内政：今期は "..C.admin.actions.." つまで行動できます"
    self:Flash("period","第"..M.CurrentPeriod(self.state).."期　内政",2)
end
function A:FinishAdministration()
    self.admin=nil; self:ShowRankings()
end
function A:AdminAct(action)
    local a=self.admin; if not a then return self:ShowRankings() end
    if self.screen=="admin_pick" then
        if action=="back" then self.screen="admin"; self.index=a.returnIndex or 2; return end
        if action~="confirm" then return end
        local row=self:Selected(); if not row then return end
        if row.enabled==false then self.notice=row.hint or "実行できません"; return end
        local ok,cost,extra
        if a.kind=="invest" then ok,cost=M.Invest(self.state,row.id)
        elseif a.kind=="lobby" then ok,cost,extra=M.Lobby(self.state,row.id)
        elseif a.kind=="divest" then ok,cost=M.Divest(self.state,row.id)
        elseif a.kind=="alliance" then ok,cost,extra=M.ProposeAlliance(self.state,row.id,self.random)
        else ok,cost,extra=M.Sabotage(self.state,row.id,self.random) end
        if not ok then self.notice=cost; return end
        a.left=a.left-1
        local line
        if a.kind=="invest" then line=row.target.name.."へ増資（"..comma(cost).."）　評価額 "..M.FormatCompact(row.target.marketValue)
        elseif a.kind=="lobby" then line=row.target.name.."へ根回し（"..comma(cost).."）　負担 -"..extra
        elseif a.kind=="divest" then line=row.target.name.."を売却（+"..comma(cost).."）"
        elseif a.kind=="alliance" then
            if extra then line=row.company.name.."と同盟を結んだ（贈り物 "..comma(cost).."）"; self:Flash("groupDiscovery",row.company.name.."と同盟締結",2.5)
            else line=row.company.name.."は同盟の申し出を断った（贈り物 "..comma(cost).." は戻らない）" end
        elseif extra.success then line=row.company.name.."への諜報工作が成功　資金 -"..comma(extra.drained)
        else line=row.company.name.."への諜報工作が露見した！　評判 -"..C.admin.scandalReputation.."・攻撃を受けやすくなった"
            self:Flash("defection","醜聞：諜報工作が露見",2.5) end
        a.log[#a.log+1]=line; self.notice=line.."　残り行動 "..a.left
        self:Save(); self.screen="admin"; self.index=a.returnIndex or 2
        if a.left<=0 then self.index=1 end
        return
    end
    if action=="back" then self.notice="内政を終えるには「内政を終えて決算へ」を選んでください"; return end
    if action~="confirm" then return end
    local row=self:Selected(); if not row then return end
    if row.command=="hub" then return self:OpenHub() end
    if row.command=="finish" then return self:FinishAdministration() end
    if row.enabled==false then self.notice=row.hint or "実行できません"; return end
    if row.command=="invest" or row.command=="lobby" or row.command=="divest" or row.command=="sabotage" or row.command=="alliance" then
        a.kind=row.command; a.returnIndex=self.index; self.screen="admin_pick"; self.index=1
        self.notice=A.adminPickPrompt[row.command].."　○：戻る"
        return
    end
    local ok,value,owed
    if row.command=="guard" then ok,value=M.Guard(self.state)
    elseif row.command=="repay" then ok,value=M.Repay(self.state)
    elseif row.command=="bond" then ok,value,owed=M.Bond(self.state)
    else ok,value=M.Hire(self.state) end
    if not ok then self.notice=value; return end
    a.left=a.left-1
    local line=row.command=="guard" and ("警備契約を結んだ（"..comma(value).."）　"..C.admin.guardPeriods.."期のあいだ攻撃確率半減")
        or (row.command=="repay" and ("負債を "..comma(value).." 返済した　評判 +"..C.admin.repayReputation)
        or (row.command=="bond" and ("社債を発行した（+"..comma(value).."）　返済額 "..comma(owed))
        or ("腕利きの交渉役を雇った（"..comma(value).."）　次の交渉に同席")))
    a.log[#a.log+1]=line; self.notice=line.."　残り行動 "..a.left; self:Save()
    if a.left<=0 then self.index=1 end
end
-- Stance lines for a dialog: what each stance does and which counters the player holds now.
function A:StanceAdvice(ids)
    local lines={}
    for _,sid in ipairs(ids or {}) do
        local st=D.stanceById[sid]; local counters={}
        for _,tactic in ipairs(D.tactics) do
            if st.breakers[tactic.id] and self.state.learnedTactics[tactic.id] then counters[#counters+1]=tactic.name end
        end
        if st.breakByGroup then
            local usable=false
            for id in pairs(self.state.learnedGroups) do local g=M.GroupStatus(self.state,id); if g and g.usable then usable=true; break end end
            if usable then counters[#counters+1]="グループに要求" end
        end
        if st.breakByAlly then for id in pairs(self.state.alliances or {}) do if M.IsAllied(self.state,id) then counters[#counters+1]="同盟の支援"; break end end end
        local relief,ability,have=M.HubStanceRelief(self.state,sid)
        local hubLine=""
        if ability and self.state.chapter>=PBTrade.HubData.minChapter then
            local name; for _,a in ipairs(PBTrade.HubData.abilities) do if a.id==ability then name=a.name end end
            hubLine="\n交易拠点："..name.." "..have.." → 構えを"..math.floor(relief*100+.5).."%緩和"
                ..(relief<.05 and "（"..name.."を育てると和らぎます）" or "")
        end
        lines[#lines+1]="◆ 構え「"..st.name.."」\n"..st.hint.."\n手持ちの対抗手段："
            ..(#counters>0 and table.concat(counters,"・") or "なし（資金で押し切るしかない）")..hubLine
    end
    return #lines>0 and table.concat(lines,"\n\n") or nil
end
function A:Detail(p)
    local company=D.companies[p.owner]
    local groupNames={}; for _,id in ipairs(p.groups) do if self.state.learnedGroups[id] then groupNames[#groupNames+1]=D.groups[id].name end end
    local risk=M.RiskLabel(p.independenceRisk)
    local text=p.name.."\n"..D.categories[p.category]
        ..(p.companyHeadquarters and (p.companyBody and (" / "..D.companies[p.companyHeadquarters].name.."本体（買収すると全傘下を取得）")
            or (" / "..D.companies[p.companyHeadquarters].name.."中枢（全中枢の買収で傘下化）")) or (p.isHeadquarters and " / 地域本部" or ""))
        .."\n\n所有："..company.name..(M.IsAllied(self.state,p.owner) and ("（同盟・信頼 "..self.state.alliances[p.owner].trust.."）") or "")
        .."\n経営："..(p.profileName or "個別設計")..(p.valueTier and ("（種類："..p.valueTier.."）") or (p.canonical and "（種類：一般・市場相場）" or ""))
        ..(p.canonical and "\n物件登録："..(M.IsPropertyVisited(self.state,p) and "登録済み・どこからでも買収可能" or "未登録・買収不可") or "")
        ..(p.finalAcquisition and "\n最終条件：第5章クリア後に手動買収。成立で真のエンディング" or "")
        .."\n評価額："..comma(p.marketValue).."\n予想収益："..comma(p.expectedProfit).." / 期（参考）"
        .."\n調達用手元資金："..comma(p.reserve).."\n独立負担："..risk.." "..p.independenceRisk.." / 128"
        .."\n要求時の負担増：+"..p.independenceIncrease.."\n交渉の推進力："..p.gaugeAcceleration
        .."\n\n系列："..(#groupNames>0 and table.concat(groupNames," / ") or "不明")
        .."\n離反率："..math.floor(self.engine:DefectionChance(p)*100).."%（次回要求時）"
    if p.owner~=C.playerId then
        local advice=self:StanceAdvice(M.NegotiationStances(self.state,p))
        text=text.."\n\n"..(advice or "構え：なし（今期は資金が素直に効く）")
        local hub=M.HubSummary(self.state,p); if hub then text=text.."\n"..hub end
    end
    return text
end
function A:GroupDetail(group)
    local state=group.id and M.GroupStatus(self.state,group.id) or group
    local names={}; for _,p in ipairs(state.members) do names[#names+1]=p.name end
    return state.name.."\n\n"..(state.learned and "習得済み" or "未習得：単体資金要求で閃く可能性あり")
        .."\n系列物件："..state.count.." / 必要 "..state.minimum
        .."\n調達倍率："..M.FormatRatio(state.bonus).."倍"..((state.landmarks or 0)>0 and ("（基本 "..M.FormatRatio(state.baseBonus).." ＋ 実在地点 "..state.landmarks.."件 +"..M.FormatRatio(state.landmarkBonus).."）") or "")
        .."\n使用："..(state.usable and "可能" or "不可")
        .."\n\n構成物件：\n"..(#names>0 and table.concat(names,"\n") or "なし")
end
-- Tactic cut-in: a staged scene (move → reaction → verdict) built from the engine outcome.
local function effectSummary(tactic,info)
    local e=tactic.effect; local a=math.abs(info.amount or 0)
    if e.type=="playerAcceleration" then return string.format("自社の押し込み +%.2f（%d秒）",a,e.duration)
    elseif e.type=="enemyAccelerationPenalty" then return string.format("相手の勢い -%.2f（%d秒）",a,e.duration)
    elseif e.type=="velocity" then return string.format("ゲージ速度 %.1f 自社側へ",a)
    elseif e.type=="randomVelocity" then
        return string.format("ゲージ速度 %.1f %s",a,info.direction==1 and "相手側へ" or "自社側へ")
    elseif e.type=="playerWaitMultiplier" then return string.format("自社の伝令待ち ×%.2f（%d秒）",math.max(.1,1-(1-e.amount)*info.power),e.duration)
    elseif e.type=="enemyWait" then return string.format("相手の次の出資 %.1f秒遅延",a)
    elseif e.type=="delayedAcceleration" then return string.format("%d秒後、自社の押し込み +%.2f（%d秒）",e.delay,a,e.duration)
    elseif e.type=="resetWaits" then return "双方の伝令待ちを初期化"
    elseif e.type=="valueMultiplier" then return string.format("評価額 ×%.2f（%d秒）",1+(e.amount-1)*info.power,e.duration)
    elseif e.type=="enemyRisk" then
        return string.format("%s の独立危険度 +%d%s",info.target.name,math.floor(a+.5),info.targetDefected and "  → 離反！" or "")
    elseif e.type=="ownRisk" then return string.format("%s の独立危険度 -%d",info.target.name,math.floor(a+.5)) end
    return tactic.description
end
function A:StartTacticScene(info)
    local tactic=info.tactic; local lines=tactic.scene or {}
    local verdict,kind
    if info.power<=0 then verdict,kind="無効","void"
    elseif tactic.effect.type=="randomVelocity" then
        if info.direction==1 then verdict,kind="裏目に出た……","backfire" else verdict,kind="大成功！","great" end
    elseif info.targetDefected then verdict,kind="大成功！","great"
    elseif info.power>=.85 then verdict,kind="大成功！","great"
    elseif info.power>=.5 then verdict,kind="成功","good"
    else verdict,kind="効果薄……","weak" end
    -- Breaking a stance outranks the effect itself in the verdict.
    local broken=info.brokenStances and info.brokenStances[1]
    if broken then verdict,kind="構え「"..broken.name.."」を崩した！","great"
    elseif info.shakenStance and kind~="void" then verdict=verdict.."　構えが揺らいだ" end
    local failed=kind=="void" or kind=="backfire"
    self.tacticScene={time=0,tactic=tactic,kind=kind,verdict=verdict,power=info.power,
        act=lines.act or tactic.description,
        reaction=(failed and lines.resist or lines.success) or "",
        detail=failed and kind=="void" and "効果なし（抵抗 100%）"
            or (effectSummary(tactic,info).."  /  相手の抵抗 "..math.floor(info.resistance*100+.5).."%")}
    if PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play("tactic") end
end
function A:TacticVerdictCue()
    local scene=self.tacticScene
    if not scene or scene.cued then return end
    scene.cued=true
    local failed=scene.kind=="void" or scene.kind=="backfire" or scene.kind=="weak"
    if PBTrade.Audio and PBTrade.Audio.Play then PBTrade.Audio.Play(failed and "tacticFail" or "tacticSuccess") end
end
function A:TacticStage()
    local scene=self.tacticScene; if not scene then return nil end
    local S=C.tacticScene
    if scene.time<S.intro then return "intro",scene.time/S.intro end
    if scene.time<S.intro+S.react then return "react",(scene.time-S.intro)/S.react end
    return "result",math.min(1,(scene.time-S.intro-S.react)/S.result)
end
function A:Tick(dt)
    if self.saveDirty then
        self.saveTimer=(self.saveTimer or 0)+dt
        if self.saveTimer>=60 then self:FlushSave() end
    end
    if self.fx then self.fx.remaining=self.fx.remaining-dt; if self.fx.remaining<=0 then self.fx=nil end end
    if self.opening then self.opening.time=self.opening.time+dt; self.opening.pageTime=self.opening.pageTime+dt end
    if self.groupCall and not (self.modal and self.modal.pauseBattle) then
        self.groupCall.time=self.groupCall.time+dt
        if self.groupCall.time>=C.groupCall.seconds or self.screen~="battle" then self.groupCall=nil end
    end
    if self.tacticScene then
        -- The banner plays alongside the negotiation; it never holds the clock.
        local scene=self.tacticScene; scene.time=scene.time+dt
        local S=C.tacticScene
        if scene.time>=S.intro+S.react then self:TacticVerdictCue() end
        if scene.time>=S.intro+S.react+S.result then self.tacticScene=nil end
    end
    if self.screen=="battle" and not (self.modal and self.modal.pauseBattle) then
        self.engine:Tick(dt)
        if self.engine.battle.result then
            self.screen="result"; self.modal=nil; self:Save(); self:FlushSave()
            local learned=self.engine.battle.learnedTactics or {}
            local takeover=self.engine.battle.takeover
            local stronghold=self.engine.battle.finalStrongholdUnlocked
            local broken=self.engine.battle.allianceBroken
            if takeover then self:Flash("takeover",takeover.name.."を傘下に！　物件 "..takeover.count.." 件",4)
            elseif stronghold then self:Flash("discovery","最終物件出現：「"..stronghold.name.."」",4)
            elseif broken then self:Flash("defection",self.state.companies[broken].name.."との同盟が解消された",3)
            elseif #learned>0 then self:Flash("discovery",D.tacticById[learned[1]].name.."を習得！",3) end
        end
    end
end

-- Original transparent DDS architecture, fixed pool and explicit native draw order.
local V={}; PBTrade.HubUI=V
local H,K,M=PBTrade.Hub,PBTrade.HubData,PBTrade.Model
-- Match each sprite's visible foundation, not its transparent square canvas.
-- Foundation front sits inside the tile; tall roofs can overlap the tiles behind.
local foundations={
    bureau={size=96,x=.504,y=1215/1254},
    gate={size=96,x=.500,y=1180/1254},
    bank={size=92,x=.500,y=1181/1254},
    market={size=88,x=.499,y=1193/1254},
    warehouse={size=94,x=.513,y=1112/1254},
    tavern={size=92,x=.506,y=1206/1254},
    guildhall={size=92,x=.500,y=1192/1254},
}
function V.New(parent,panel,box,label,texture)
    local function layer(c,level)
        c:SetDrawTier(DT_MEDIUM); c:SetDrawLayer(DL_OVERLAY); c:SetDrawLevel(level)
        return c
    end
    local v={cells={}}
    v.root=panel(parent,40,158,1160,500)
    layer(box(v.root,0,0,1160,500,{.025,.040,.035,.97},{.45,.37,.20,1}),0)
    v.title=layer(label(v.root,24,15,720,36,"交易拠点 ― 開拓地",27),100)
    v.stats=layer(label(v.root,24,54,720,60,"",22),100)
    layer(box(v.root,755,18,1,464,{.45,.37,.20,1},{0,0,0,0}),0)
    v.detail=layer(label(v.root,785,24,350,328,"",18),100)
    v.portrait=layer(texture(v.root,875,338,150,150,"hub_bank"),50)
    v.footer=layer(label(v.root,24,470,720,28,"",18),100)
    for sum=2,K.size*2 do for x=1,K.size do local y=sum-x
        if y>=1 and y<=K.size then
            local px,py=375+(x-y)*68,180+(x+y-2)*27
            local p=panel(v.root,px-64,py,128,64)
            local ground=layer(texture(p,0,-32,128,128,"hub_ground"),1)
            local building=layer(texture(v.root,px-46,py-36,92,92,"hub_bank"),10+sum*K.size+x)
            local decoration=layer(texture(v.root,px-47,py-58,94,100,"hub_tree"),10+sum*K.size+x)
            local caption=layer(label(v.root,px-45,py+45,128,26,"",18),200)
            local cell={x=x,y=y,localX=x,localY=y,px=px,py=py,panel=p,tile=ground,building=building,decoration=decoration,caption=caption}
            p:SetMouseEnabled(true)
            local function select()
                local a=v.app; if not a or a.modal then return end
                a.hubCursor={x=cell.x,y=cell.y}; a:HubAct("confirm"); v.refresh()
            end
            p:SetHandler("OnMouseUp",select)
            v.cells[#v.cells+1]=cell
        end
    end end
    v.root:SetHidden(true)
    return v
end
local function asset(control,name)
    if control.pbtradeAsset~=name then PBTrade.Assets.Apply(control,name) end
end
function V.Refresh(v,a,refresh)
    v.app=a; v.refresh=refresh
    v.root:SetHidden(a.screen~="hub")
    if a.screen~="hub" then return end
    local sx,sy=v.root:GetWidth()/1160,v.root:GetHeight()/500
    local size=H.Size(a.state.chapter)
    local firstX=math.max(1,math.min(size-4,a.hubCursor.x-2))
    local firstY=math.max(1,math.min(size-4,a.hubCursor.y-2))
    local h=a.state.hub; local effects=H.Effects(h,a.state.chapter,M.HubSupply(a.state)); local abilities=effects.abilities; local t={}
    for _,k in ipairs(K.abilities) do t[#t+1]=k.name.." "..abilities[k.id] end
    local stage=#h.buildings==0 and "開拓地" or (#h.buildings<8 and "小さな交易所" or (#h.buildings<18 and "交易都市" or "大交易都市"))
    v.title:SetText("交易拠点 ― "..stage.."　"..size.."×"..size.." / "..(#H.All(h)>H.Capacity(a.state.chapter) and (#H.All(h).."施設（上限"..H.Capacity(a.state.chapter).."超過・新設不可）") or (#H.All(h).."/"..H.Capacity(a.state.chapter).."施設"))..(#(h.annex or {})>0 and ("・旧街区 "..#h.annex) or ""))
    local current=H.At(h,a.hubCursor.x,a.hubCursor.y)
    local choice=a.hubMoving and "移設先を選択" or (current and ("操作："..a:HubOperation().name) or ("建設："..a:HubCandidate().name))
    v.stats:SetText(table.concat(t,"  ").."\n"..choice.."　区画 "..a.hubCursor.x.." / "..a.hubCursor.y.."　"..K.policyById[h.policy].name)
    v.footer:SetText(a.hubMoving and "↑↓←→ 移設先　× 確認　○ 移設取消" or "↑↓←→ 区画　L1/R1 候補・操作　× 確認　△ 詳細　□ 運営/手引")
    v.detail:SetText(a:HubDetail().."\n表示："..firstX.."–"..(firstX+4).." / "..firstY.."–"..(firstY+4))
    local selectedBuilding=H.At(h,a.hubCursor.x,a.hubCursor.y)
    local selectedType=K.byId[selectedBuilding and selectedBuilding.type or a:HubCandidate().id]
    asset(v.portrait,"hub_"..(selectedType.asset or selectedType.id))
    v.portrait:SetColor(unpack(selectedType.tint or {1,1,1,1}))
    for _,c in ipairs(v.cells) do
        c.x,c.y=firstX+c.localX-1,firstY+c.localY-1
        local b=H.At(h,c.x,c.y); local selected=a.hubCursor.x==c.x and a.hubCursor.y==c.y
        local decor,variant=H.Decoration(h,c.x,c.y,size)
        local ground=H.Ground(c.x,c.y,size)
        asset(c.tile,ground)
        local shades={{.60,.66,.57,1},{.69,.67,.58,1},{.58,.63,.61,1}}
        local district=b and effects.membership[b.id]
        c.tile:SetColor(unpack(selected and {1,.84,.48,1} or (district and district.color) or (ground=="hub_walkway" and {.68,.68,.60,1} or shades[variant+1])))
        c.decoration:SetHidden(b~=nil or decor==nil)
        if not b and decor then asset(c.decoration,"hub_"..decor) end
        c.building:SetHidden(not b)
        c.caption:SetText((selected or (b and b.remainingPeriods>0)) and (b and (K.byId[b.type].short.." Lv."..b.level..(b.remainingPeriods>0 and (" "..b.remainingPeriods.."期") or "")) or "◆ 空き区画") or "")
        if b then
            local definition=K.byId[b.type]
            local f=foundations[definition.asset or b.type]
            c.building:SetDimensions(f.size*sx,f.size*sy)
            c.building:ClearAnchors()
            c.building:SetAnchor(TOPLEFT,v.root,TOPLEFT,(c.px-f.x*f.size)*sx,(c.py+56-f.y*f.size)*sy)
            asset(c.building,"hub_"..(definition.asset or b.type))
            c.building:SetColor(unpack(b.remainingPeriods>0 and {.55,.55,.48,.8} or definition.tint or {1,1,1,1}))
        end
    end
end

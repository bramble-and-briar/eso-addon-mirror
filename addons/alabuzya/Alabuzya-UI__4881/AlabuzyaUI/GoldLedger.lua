local A=AlabuzyaUI
A.GoldLedger={}
local M=A.GoldLedger
local db,current,widget,value,window,child,more,title,countHeader
local labels={}
local enabled,started=false,false
local limit,cutoff=12,nil
local ru
local function L(a,b) return ru and a or b end
local function Money() return GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER) end
local function Number(n)
    local text=tostring(math.floor(n or 0))
    local sign=text:sub(1,1)=='-' and '-' or ''
    text=text:gsub('^-','')
    repeat local count text,count=text:gsub('^(%d+)(%d%d%d)','%1 %2') if count==0 then break end until false
    return sign..text
end
local function Text(parent,text,x,y,w)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont(A.Theme.Font(16)) c:SetText(text)
    c:SetDimensions(w,24) c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetMouseEnabled(false) return c
end
local function Button(parent,text,x,y,w,fn)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_BUTTON)
    c:SetDimensions(w,28) c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetFont(A.Theme.Font(16)) c:SetText(text) c:SetMouseEnabled(true)
    c:SetNormalFontColor(.95,.83,.5,1) c:SetMouseOverFontColor(1,1,1,1)
    c:SetHandler('OnClicked',fn) return c
end
local function Day(timestamp)
    local y,m,d=GetDateElementsFromTimestamp(timestamp)
    return string.format('%04d-%02d-%02d',y,m,d)
end
local function Daily() return A.Settings.Get and A.Settings.Get().goldLedgerMode~='session' end
function M.Rows(daily)
    if not daily then return db.sessions end
    local byDay,rows={},{}
    for _,session in ipairs(db.sessions) do
        -- Older versions only retained whole-session totals; preserve them on the start date.
        local buckets=session.days or {[Day(session.start)]={start=session.start,income=session.income,
            expense=session.expense,balance=session.balance,finish=session.finish or session.start}}
        for date,bucket in pairs(buckets) do
            local row=byDay[date]
            if not row then
                row={start=bucket.start,income=0,expense=0,id=0,name=session.name,characters={},balance=0}
                byDay[date]=row rows[#rows+1]=row
            end
            row.start=math.min(row.start,bucket.start)
            row.income=row.income+bucket.income row.expense=row.expense+bucket.expense row.id=row.id+1
            local previous=row.characters[session.character]
            if not previous or previous.finish<=(bucket.finish or bucket.start) then
                row.characters[session.character]={balance=bucket.balance,finish=bucket.finish or bucket.start}
            end
            if row.name~=session.name then row.name=L('Все персонажи','All characters') end
        end
    end
    for _,row in ipairs(rows) do
        for _,c in pairs(row.characters) do row.balance=row.balance+c.balance end
    end
    table.sort(rows,function(a,b) return a.start<b.start end)
    return rows
end
local function CurrentDayBucket()
    current.days=current.days or {[Day(current.start)]={start=current.start,income=current.income,
        expense=current.expense,balance=current.balance,finish=current.finish or current.start}}
    local date=Day(GetTimeStamp())
    current.days[date]=current.days[date] or {start=GetTimeStamp(),income=0,expense=0,balance=Money(),finish=GetTimeStamp()}
    return current.days[date]
end
function M.Refresh()
    local daily=Daily()
    local rows=M.Rows(daily)
    if value then
        local net=current and current.income-current.expense or 0
        if daily then
            net=0
            for _,row in ipairs(rows) do
                if Day(row.start)==Day(GetTimeStamp()) then net=net+row.income-row.expense end
            end
        end
        value:SetText((net>0 and '+' or '')..Number(net))
        value:SetColor(net<0 and 1 or .9,net<0 and .35 or .8,.3,1)
    end
    if not window or window:IsHidden() then return end
    title:SetText(daily and L('Золото: история по дням','Gold: daily history') or L('Золото: история сессий','Gold: session history'))
    countHeader:SetText(daily and L('Сессий','Sessions') or L('Сессия','Session'))
    local shown=0
    for i=#rows,1,-1 do
        local row=rows[i]
        if (not cutoff and shown<limit) or (cutoff and row.start>=cutoff) then
            shown=shown+1
            local cells=labels[shown]
            if not cells then
                cells={}
                for col,spec in ipairs({{0,105},{108,195},{307,90},{403,115},{521,130}}) do
                    cells[col]=Text(child,'',spec[1],(shown-1)*28,spec[2])
                end
                labels[shown]=cells
            end
            local year,month,day=GetDateElementsFromTimestamp(row.start)
            local texts={string.format('%02d.%02d.%04d',day,month,year),row.name,
                tostring(row.id),Number(row.income-row.expense),Number(row.balance)}
            for col,c in ipairs(cells) do c:SetText(texts[col]) c:SetHidden(false) end
        end
    end
    for i=shown+1,#labels do for _,c in ipairs(labels[i]) do c:SetHidden(true) end end
    child:SetHeight(math.max(1,shown*28))
    more:SetHidden(shown>=#rows)
    more:SetText(cutoff and L('Ещё месяц','Another month') or L('Показать последний месяц','Show last month'))
end
local function ShowHistory()
    if not window then
        window=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUIGoldHistory')
        window:SetDimensions(710,470) window:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        window:SetClampedToScreen(true) window:SetMouseEnabled(true) window:SetMovable(true)
        local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_BACKDROP)
        bg:SetAnchorFill() bg:SetCenterColor(.025,.025,.025,.96)
        bg:SetEdgeTexture(nil,1,1,1) bg:SetEdgeColor(.55,.45,.25,1)
        title=Text(window,L('Золото: история сессий','Gold: session history'),18,12,550)
        Button(window,'X',665,8,28,function() window:SetHidden(true) end)
        local names={L('Дата','Date'),L('Персонаж','Character'),L('Сессия','Session'),L('Сальдо','Net'),L('Золото','Gold')}
        for i,x in ipairs({18,126,325,421,539}) do
            local header=Text(window,names[i],x,46,130) if i==3 then countHeader=header end
        end
        local scroll=WINDOW_MANAGER:CreateControlFromVirtual('AlabuzyaUIGoldHistoryScroll',window,'ZO_ScrollContainer')
        scroll:SetAnchor(TOPLEFT,window,TOPLEFT,18,76)
        scroll:SetAnchor(BOTTOMRIGHT,window,BOTTOMRIGHT,-18,-48)
        child=scroll:GetNamedChild('Scroll'):GetNamedChild('Child')
        child:SetWidth(654)
        more=Button(window,'',18,428,420,function()
            cutoff=(cutoff or GetTimeStamp())-30*86400 M.Refresh()
        end)
    end
    limit=12 cutoff=nil window:SetHidden(false) M.Refresh()
end
function M.Record(newMoney,oldMoney,reason)
    if not enabled or not current or not started then return end
    local bucket=CurrentDayBucket()
    bucket.balance=newMoney bucket.finish=GetTimeStamp()
    current.balance=newMoney current.finish=GetTimeStamp()
    if reason~=CURRENCY_CHANGE_REASON_BANK_DEPOSIT and reason~=CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
        and reason~=CURRENCY_CHANGE_REASON_PLAYER_INIT then
        local change=newMoney-oldMoney
        if change>0 then current.income=current.income+change bucket.income=bucket.income+change
        elseif change<0 then current.expense=current.expense-change bucket.expense=bucket.expense-change end
    end
    M.Refresh()
end
local function Start()
    if started or not enabled then return end
    started=true
    local id=GetCurrentCharacterId()
    local last=db.sessions[#db.sessions]
    if db.resume==id and last and last.character==id then current=last
    else
        db.nextId=db.nextId+1
        current={id=db.nextId,character=id,name=GetUnitName('player'),start=GetTimeStamp(),
            finish=GetTimeStamp(),income=0,expense=0,balance=Money()}
        db.sessions[#db.sessions+1]=current
    end
    db.resume=nil current.balance=Money() CurrentDayBucket() M.Refresh()
end
function M.SetEnabled(v)
    enabled=v
    if widget then widget:SetHidden(not enabled) end
    if not enabled and window then window:SetHidden(true) end
    if enabled then Start() end
end
function M.Initialize()
    ru=GetCVar('language.2')=='ru'
    db=A.SavedVariables.Account('goldLedger',{sessions={},nextId=0})
    widget=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUIGoldSession')
    widget:SetDimensions(138,34) widget:SetClampedToScreen(true)
    widget:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,db.x or 340,db.y or 8)
    widget:SetMouseEnabled(true) widget:SetMovable(true)
    local bg=WINDOW_MANAGER:CreateControl(nil,widget,CT_BACKDROP)
    bg:SetAnchorFill() bg:SetCenterColor(.025,.025,.025,.8)
    bg:SetEdgeTexture(nil,1,1,1) bg:SetEdgeColor(.45,.36,.18,1)
    local icon=WINDOW_MANAGER:CreateControl(nil,widget,CT_TEXTURE)
    icon:SetDimensions(24,24) icon:SetAnchor(LEFT,widget,LEFT,5,0)
    icon:SetTexture('EsoUI/Art/currency/currency_gold.dds') icon:SetMouseEnabled(false)
    value=Text(widget,'0',34,6,100)
    widget:SetHandler('OnMouseDown',function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and IsShiftKeyDown() then widget:StartMoving() end
    end)
    widget:SetHandler('OnMoveStop',function() db.x=widget:GetLeft() db.y=widget:GetTop() end)
    widget:SetHandler('OnMouseUp',function(_,button,inside)
        widget:StopMovingOrResizing()
        if button==MOUSE_BUTTON_INDEX_LEFT and inside and not IsShiftKeyDown() then ShowHistory() end
    end)
    widget:SetHandler('OnMouseEnter',function(c)
        ZO_Tooltips_ShowTextTooltip(c,TOPLEFT,L('Сальдо выбранного периода. Клик: история. Shift + перетаскивание: переместить.','Net for selected period. Click: history. Shift + drag: move.'))
    end)
    widget:SetHandler('OnMouseExit',function() ZO_Tooltips_HideTextTooltip() end)
    local fragment=ZO_HUDFadeSceneFragment:New(widget)
    if fragment.SetConditional then fragment:SetConditional(function() return enabled end) end
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    enabled=A.Settings.Enabled('goldLedger') widget:SetHidden(not enabled)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIGold',EVENT_PLAYER_ACTIVATED,Start)
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIGoldDay',1000,function() if enabled and Daily() then M.Refresh() end end)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIGold',EVENT_MONEY_UPDATE,function(_,new,old,reason) M.Record(new,old,reason) end)
    -- Use ESO's Lua pre-hook; save before the native ReloadUI call.
    ZO_PreHook(_G,'ReloadUI',function()
        if started and current then db.resume=GetCurrentCharacterId() end
    end)
end

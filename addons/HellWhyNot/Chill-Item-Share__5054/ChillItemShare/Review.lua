local A = ChillItemShare
local pairs, ipairs = pairs, ipairs
local math = math
local min, max = math.min, math.max
local GuiRoot = GuiRoot
local SUB_BANK = BAG_SUBSCRIBER_BANK
local EM = EVENT_MANAGER
local HIGH = DT_HIGH
local sceneManager
local format = string.format
local TL, BR, CENTER = TOPLEFT, BOTTOMRIGHT, CENTER
local TEXT, BUTTON, BACKDROP = CT_LABEL, CT_BUTTON, CT_BACKDROP
local ELLIPSIS = TEXT_WRAP_MODE_ELLIPSIS
local unpack = unpack
local clearList, dataList = ZO_ScrollList_Clear, ZO_ScrollList_GetDataList
local commitList, dataEntry = ZO_ScrollList_Commit, ZO_ScrollList_CreateDataEntry
local showTip, clearTip = InitializeTooltip, ClearTooltip
local base = {37/255,31/255,43/255,1}
local header = {59/255,48/255,66/255,1}
local field = {25/255,21/255,31/255,1}
local border = {165/255,156/255,174/255,1}
local accent = {205/255,177/255,229/255,1}
local textColor = {244/255,240/255,248/255,1}
local hover = {73/255,58/255,82/255,1}
local function Box(parent, color, edge)
    local box = A.wm:CreateControl(nil, parent, BACKDROP)
    box:SetAnchorFill(parent); box:SetCenterColor(unpack(color))
    box:SetEdgeTexture(nil, 1, 1, 1); box:SetEdgeColor(unpack(edge or color))
    box:SetDrawLayer(DL_BACKGROUND)
    return box
end
local function Label(parent, text, x, y, width, font, height)
    local label = A.wm:CreateControl(nil, parent, TEXT)
    label:SetAnchor(TL, parent, TL, x, y); label:SetDimensions(width, height or 26)
    label:SetFont(font or "ZoFontGame"); label:SetColor(unpack(textColor))
    label:SetText(text)
    return label
end
local function Button(parent, caption, x, y, width, callback, primary)
    local button = A.wm:CreateControl(nil, parent, BUTTON)
    button:SetAnchor(TL, parent, TL, x, y); button:SetDimensions(width, 34)
    button:SetFont("ZoFontGameBold"); button:SetText(caption)
    button:SetNormalFontColor(unpack(textColor)); button:SetMouseOverFontColor(unpack(accent))
    local backdrop = Box(button, header, primary and accent or border)
    button:SetHandler("OnMouseEnter", function() backdrop:SetCenterColor(unpack(hover)) end)
    button:SetHandler("OnMouseExit", function() backdrop:SetCenterColor(unpack(header)) end)
    button:SetHandler("OnClicked", callback)
    return button
end
local function HideTooltip() clearTip(A.tooltip) end
local function SetupRow(control, data)
    if not control.nameText then
        Box(control, field)
        control.mark = Label(control, "", 8, 5, 34, "ZoFontGameBold")
        control.nameText = Label(control, "", 46, 5, 620, "ZoFontGameBold")
        control.nameText:SetMaxLineCount(1); control.nameText:SetWrapMode(ELLIPSIS)
        control.sourceText = Label(control, "", 46, 30, 620, "ZoFontGameSmall")
        control.sourceText:SetMaxLineCount(1); control.sourceText:SetWrapMode(ELLIPSIS)
        control.quantity = Label(control, "", 675, 13, 70, "ZoFontGameBold")
        control.remove = Button(control, "Remove", 760, 12, 100, function()
            A.Invalidate(); A.saved.selected[control.data.uid] = nil; A.Update()
        end)
        control:SetHandler("OnMouseEnter", function(self)
            local row = self.data
            showTip(A.tooltip, self, RIGHT, -10, 0, LEFT)
            if row.item.collectibleId and row.item.collectibleId ~= 0 then
                A.tooltip:SetCollectible(row.item.collectibleId, true)
            elseif row.available and row.item.kind ~= "house" then
                A.tooltip:SetBagItem(row.item.bag, row.item.slot)
            else A.tooltip:SetLink(row.item.link) end
            A.tooltip:AddLine("Source: " .. row.item.source)
        end)
        control:SetHandler("OnMouseExit", HideTooltip)
    end
    control.data = data
    control.mark:SetText(data.available and "[X]" or "[!]")
    control.mark:SetColor(unpack(data.available and accent or {1,.72,.40,1}))
    control.nameText:SetText(data.item.name)
    control.sourceText:SetText(data.item.source .. (data.available and "" or "  |  UNAVAILABLE: revisit source to verify"))
    control.quantity:SetText("x" .. data.item.count)
end
local function FitWindow()
    local window = A.window
    window:SetScale(min(1, max(.25, (GuiRoot:GetWidth()-32)/940), max(.25, (GuiRoot:GetHeight()-32)/660)))
    window:SetClampedToScreen(true)
end
local function BulkMenu(button, category)
    local add, clear, show = AddCustomMenuItem, ClearMenu, ShowMenu
    clear()
    if category then
        local found = false
        for _, bag in ipairs(A.bags) do
            local items, title = A.CategoryScope(bag)
            if items then
                found = true
                add("Select " .. title, function() A.SetItems(items, true, title) end)
                add("Deselect " .. title, function() A.SetItems(items, false, title) end)
                break
            end
        end
        if not found then A.Say("Open an inventory or storage category first. Its search filters will apply."); return end
    else
        for _, bag in ipairs(A.bags) do
            if A.IsAccessible(bag) and bag ~= SUB_BANK then
                local sourceBag, name = bag, A.SourceName(bag)
                add("Select entire " .. name, function() A.SelectBag(sourceBag, true) end)
                add("Deselect entire " .. name, function() A.SelectBag(sourceBag, false) end)
            end
        end
    end
    if not category then
        local key, houseName = A.HouseScope()
        if key then
            add("Select placed furnishings: " .. houseName, function()
                if A.HouseScope() == key then A.SelectHouse(true) else A.Say("House changed. Reopen the source menu.") end
            end)
            add("Deselect placed furnishings: " .. houseName, function()
                if A.HouseScope() == key then A.SelectHouse(false) else A.Say("House changed. Reopen the source menu.") end
            end)
        end
    end
    show(button)
end
function A.CreateWindow()
    sceneManager = SCENE_MANAGER
    local w = A.wm:CreateTopLevelWindow("ChillItemShareWindow")
    A.window = w
    w:SetDimensions(940,660); w:SetDrawTier(HIGH); w:SetMouseEnabled(true); w:SetMovable(true); w:SetHidden(true)
    w:SetAnchor(CENTER, GuiRoot, CENTER)
    Box(w, base, border)
    local titleBar = A.wm:CreateControl(nil,w,CT_CONTROL)
    titleBar:SetAnchor(TL,w,TL,0,0); titleBar:SetDimensions(940,62)
    Box(titleBar,header)
    local title = Label(titleBar,"Chill Item Share",22,14,650,"ZoFontWinH1",36)
    title:SetColor(1, 102/255, 243/255, 1)
    Button(w,"Close",824,14,94,function() sceneManager:HideTopLevel(w) end)
    local sources, category
    sources=Button(w,"Entire source",22,76,160,function() BulkMenu(sources,false) end)
    category=Button(w,"Current category",194,76,180,function() BulkMenu(category,true) end)
    Button(w,"Refresh",386,76,108,A.Update)
    Button(w,"Settings",506,76,120,function() sceneManager:HideTopLevel(w); LibAddonMenu2:OpenToPanel(A.settingsPanel) end)
    A.summary=Label(w,"",22,120,896,"ZoFontGameBold",30)
    Label(w,"SELECTED ITEM / SOURCE",30,158,640,"ZoFontGameSmall")
    Label(w,"QTY",697,158,70,"ZoFontGameSmall")
    local list=A.wm:CreateControlFromVirtual("ChillItemShareReviewList",w,"ZO_ScrollList")
    list:SetAnchor(TL,w,TL,22,186); list:SetAnchor(BR,w,BR,-22,-156)
    A.list=list
    ZO_ScrollList_AddDataType(list,1,"ChillItemShareReviewRow",60,SetupRow,HideTooltip)
    A.empty=Label(w,"No items selected. Right-click an item and choose Share item.",46,226,840,"ZoFontGame",60)
    A.detail=Label(w,"",22,520,896,"ZoFontGame",64)
    Button(w,"Remove unavailable",22,602,200,function()
        A.Invalidate(); A.Reconcile()
        for uid in pairs(A.saved.selected) do if not A.current[uid] then A.saved.selected[uid]=nil end end
        A.Update()
    end)
    Button(w,"Clear list",236,602,132,A.Clear)
    Button(w,"Post share list",716,602,202,A.Post,true)
    w:SetHandler("OnMoveStop",function(self)
        A.saved.windowPosition={x=self:GetLeft(),y=self:GetTop()}
    end)
    local pos=A.saved.windowPosition
    if pos and type(pos.x)=="number" and type(pos.y)=="number" then
        w:ClearAnchors(); w:SetAnchor(TL,GuiRoot,TL,pos.x,pos.y)
    end
    sceneManager:RegisterTopLevel(w, true)
    w:SetHandler("OnHide",HideTooltip)
    FitWindow()
    EM:RegisterForEvent(A.name .. "Review", EVENT_SCREEN_RESIZED, FitWindow)
end
function A.RefreshUI()
    if not A.window or A.window:IsHidden() then return end
    local plan, err, rows=A.Plan()
    clearList(A.list)
    local data=dataList(A.list)
    local quantity,unavailable=0,0
    for _,row in ipairs(rows) do
        data[#data+1]=dataEntry(1,row)
        quantity=quantity+row.item.count
        if not row.available then unavailable=unavailable+1 end
    end
    commitList(A.list)
    A.empty:SetHidden(#rows>0)
    local count=plan and #plan.messages or 0
    A.summary:SetText(format("%d stacks  |  %d items  |  %d unavailable  |  %s",#rows,quantity,unavailable,
        count==1 and "ONE MESSAGE ONLY" or (count>1 and count .. " messages" or "Posting unavailable")))
    A.detail:SetText(err or (format("Pre-text is first-message only. Press Enter for each part; delay: %g seconds.\n", A.DelayMilliseconds()/1000) ..
        "Moving, removing or changing selected stacks cancels pending messages for a fresh /sharepost."))
end
function A.Toggle()
    if not A.saved then return end
    if not A.window then A.CreateWindow() end
    sceneManager:ToggleTopLevel(A.window)
    if not A.window:IsHidden() then FitWindow(); A.Update() end
end

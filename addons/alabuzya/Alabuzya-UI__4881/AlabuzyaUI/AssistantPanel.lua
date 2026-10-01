local AlabuzyaUI = AlabuzyaUI
-- Shared helper: independent of the selected visual theme. GPL-3.0-or-later.
AlabuzyaUI.AssistantPanel={}
local M=AlabuzyaUI.AssistantPanel
-- Collectible IDs cross-checked against tralce/tralceCollectibles (data only).
-- Keep roles explicit: localized names/descriptions are not stable identifiers.
M.categories={
    {key='bank',en='Banker',ru='Банкир',ids={267,6376,8994,9743,11059,12413}},
    {key='merchant',en='Merchant',ru='Торговец',ids={301,6378,8995,9744,11097,12414}},
    {key='deconstruction',en='Deconstruction',ru='Разборщик',ids={10184,10617,11877}},
    {key='armory',en='Armory',ru='Оружейная',ids={9745,10618,11876,13063}},
    {key='fence',en='Smuggler',ru='Контрабандист',ids={300}},
}
local panel,container,buttons,ru,hoverReference
local function L(a,b) return ru and a or b end
function M.Owned(category,usableOnly)
    local found={}
    for _,id in ipairs(category.ids) do
        if IsCollectibleUnlocked(id) and (not usableOnly or IsCollectibleUsable(id,GAMEPLAY_ACTOR_CATEGORY_PLAYER)) then
            found[#found+1]=id
        end
    end
    return found
end
function M.Summon(category)
    if not AlabuzyaUI.Settings.Enabled('assistantPanel') then return end
    local available=M.Owned(category,true)
    if #available==0 then return end
    -- Only a direct button click calls this function. Native restrictions apply.
    UseCollectible(available[math.random(#available)],GAMEPLAY_ACTOR_CATEGORY_PLAYER)
end
local function ReleaseHover()
    if hoverReference then
        hoverReference=false
        container:RemoveFadeInReference()
    end
end
local function Enter()
    if not hoverReference then
        hoverReference=true
        container:AddFadeInReference()
    end
end
local function Position()
    panel:ClearAnchors()
    -- Chat can touch the screen edge. Prefer its left side, otherwise fit on
    -- its right rather than placing buttons outside the screen or over text.
    if container.control:GetLeft()>=50 then
        panel:SetAnchor(TOPRIGHT,container.control,TOPLEFT,-6,38)
    else
        panel:SetAnchor(TOPLEFT,container.control,TOPRIGHT,6,38)
    end
end
function M.Refresh()
    if not panel then return end
    local chat=container.control
    local hidden=not AlabuzyaUI.Settings.Enabled('assistantPanel') or chat:IsHidden()
        or (CHAT_SYSTEM.IsMinimized and CHAT_SYSTEM:IsMinimized())
        or (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
    if hoverReference and (hidden or not MouseIsOver(panel)) then ReleaseHover() end
    local minimum,maximum=container.minAlpha or 0,container.maxAlpha or 1
    local alpha=maximum>minimum and math.max(0,math.min(1,(chat:GetAlpha()-minimum)/(maximum-minimum)))
        or (container.alabuzyaAssistantAwake and 1 or 0)
    -- Text input can be active even with a transparent chat background.
    if CHAT_SYSTEM.IsTextEntryOpen and CHAT_SYSTEM:IsTextEntryOpen() then alpha=1 end
    panel:SetHidden(hidden or alpha<=.01)
    panel:SetAlpha(alpha)
    if hidden or alpha<=.01 then return end
    Position()
    for i,category in ipairs(M.categories) do
        local owned=M.Owned(category,false)
        local usable=M.Owned(category,true)
        local b=buttons[i]
        b:SetEnabled(#usable>0)
        b.icon:SetAlpha(#usable>0 and 1 or .25)
        local _,_,icon=GetCollectibleInfo(owned[1] or category.ids[1])
        if icon and icon~='' then b.icon:SetTexture(icon) end
        b.tooltip=(ru and category.ru or category.en)..'\n'..
            (#owned==0 and L('Нет разблокированных помощников.','No unlocked assistants.') or
            (#usable==0 and L('Сейчас нельзя вызвать.','Cannot summon here right now.') or
            L('Вызвать случайного доступного помощника. Повторный вызов активного убирает его.',
              'Summon a random available assistant. Using the active assistant dismisses it.')))
    end
end
function M.TryCreate()
    if panel then return end
    container=CHAT_SYSTEM and CHAT_SYSTEM.primaryContainer
    if not container or not container.control then return end
    ru=GetCVar('language.2')=='ru'
    -- Separate window: do not clip outside the chat container bounds.
    panel=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUIAssistantPanel')
    panel:SetClampedToScreen(true)
    panel:SetDimensions(40,#M.categories*42-2)
    panel:SetInheritAlpha(false) panel:SetMouseEnabled(true) panel:SetHidden(true)
    panel:SetDrawTier(DT_HIGH) panel:SetDrawLayer(DL_OVERLAY)
    panel:SetHandler('OnMouseEnter',Enter)
    panel:SetHandler('OnHide',ReleaseHover)
    buttons={}
    for i,category in ipairs(M.categories) do
        local b=WINDOW_MANAGER:CreateControl(nil,panel,CT_BUTTON)
        b:SetMouseEnabled(true) b:SetDimensions(40,40) b:SetAnchor(TOPLEFT,panel,TOPLEFT,0,(i-1)*42)
        local bg=WINDOW_MANAGER:CreateControl(nil,b,CT_BACKDROP)
        bg:SetAnchorFill() bg:SetCenterColor(.035,.03,.025,.94)
        bg:SetEdgeTexture(nil,1,1,1) bg:SetEdgeColor(.5,.38,.19,1) bg:SetMouseEnabled(false)
        local icon=WINDOW_MANAGER:CreateControl(nil,b,CT_TEXTURE)
        icon:SetDimensions(32,32) icon:SetAnchor(CENTER,b,CENTER,0,0) icon:SetMouseEnabled(false)
        b.icon=icon
        b:SetHandler('OnClicked',function() M.Summon(category) end)
        b:SetHandler('OnMouseEnter',function()
            Enter() bg:SetEdgeColor(.95,.75,.35,1)
            ZO_Tooltips_ShowTextTooltip(b,RIGHT,b.tooltip or '')
        end)
        b:SetHandler('OnMouseExit',function()
            bg:SetEdgeColor(.5,.38,.19,1) ZO_Tooltips_HideTextTooltip()
        end)
        b:SetHandler('OnHide',function() ZO_Tooltips_HideTextTooltip() end)
        buttons[i]=b
    end
    SecurePostHook(container,'FadeIn',function() container.alabuzyaAssistantAwake=true end)
    SecurePostHook(container,'FadeOut',function()
        if (container.fadeInReferences or 0)==0 then container.alabuzyaAssistantAwake=false end
    end)
    M.Refresh()
end
function M.Initialize()
    -- Chat containers may be created after EVENT_ADD_ON_LOADED. Retry until ready.
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIAssistantPanel',100,function()
        if not panel then M.TryCreate() end
        M.Refresh()
    end)
    M.TryCreate()
end

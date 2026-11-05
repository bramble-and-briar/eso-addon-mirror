-- Ramaladni Buff & Debuff Tracker v1.0.0 STABLE (release from user-tested v1.0.4g RC5)
-- No external libraries. Player buffs do not depend on reticle target.
-- Debuffs are tracked from effect events even if reticle moves away.
-- Effect duration comes from observed ESO start/end. User cooldown is editable only for manual IDs.

local ADDON = 'Ramaladni_buff_debuff_tracker'
local MASTERY=RamaladniMastery or {byKey={},byClass={},classes={}}
local GROUPS=RamaladniEffectGroups or {Find=function()return nil end,Members=function()return nil end,Count=function()return 0 end}
local SEARCH=RamaladniEffectSearch
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER
local R = {sv=nil, ui={}, widgets={}, states={}, observed={buff={},debuff={}}, selected={},
           widgetsFree={}, widgetsMade=0, cacheSize={buff=0,debuff=0},
           learnedCount={buff=0,debuff=0}, index={byId={},byName={},hasNames=false},
           combat=false, cleanupPending=false, debug=false, hudVisible=true, hudSceneVisible=false,
           debugWindow=0, debugPrinted=0, debugSuppressed=0}
local CACHE_LIMIT=256
local MAX_TARGETS_PER_EFFECT=64
local DEBUG_MESSAGES_PER_SECOND=6
local MAX = 12
local DEFAULTS = {nextId=1,entries={},window={x=240,y=120},learned={buff={},debuff={}}}
local PRESETS = {
    buff = {
        { name='Малая свирепость / Minor Savagery', id=61898 },
        { name='Великая ярость / Major Berserk', id=61745 },
        { name='Великий эгид / Major Aegis', id=93123 },
        -- U52 SkillData34: Quick Cloak 38901 -> 2 distinct buff effects.
        -- Additional variant 260255 uses the aliases below; it is not a third buff.
        { name='Ускоряющий покров: Великое уклонение / Quick Cloak: Major Evasion', id=123652, aliases={260259} },
        { name='Ускоряющий покров: Великое ускорение / Quick Cloak: Major Expedition', id=62531, aliases={260258} },
    },
    debuff = {
        { name='Насмешка головореза / Cutthroat\'s Mockery', id=268259 },
        -- Historical ability IDs documented by Untaunted and Bandits UI;
        -- valid per source, but some sources/skill ranks have other IDs.
        { name='Крушитель / Crusher', id=17906 },
        { name='Великий прорыв / Major Breach', id=62787 },
        -- ID 62588 does not exist in the imported U52 database.
        -- No safe universal Minor Breach effect ID; keep it in the manual/catalog path.
        -- U52 Major Brittle: 145977 is the generic status record (duration 0).
        -- Effect variants 263825 (Chilled, 2.1s) and 167681 (Nunatak, 4s)
        -- have the same major_minor_id=12. Track all by exact ID, use ESO expiry.
        { name='Великая хрупкость / Major Brittle', id=145977, aliases={263825,167681} },
        { name='Великая уязвимость / Major Vulnerability', id=122389 },
        { name='Малая уязвимость / Minor Vulnerability', id=81519 },
        { name='Малое похищение здоровья / Minor Lifesteal', id=80020 },
        { name='Малое похищение магии / Minor Magickasteal', id=39100 },
        { name='Потеря равновесия / Off Balance', id=45902 },
        { name='Ослабление / Weakening', id=17945 },
    },
}
-- Only positively matched (kind, ID, name) U52 builtin entries are locked.
-- Source-specific IDs and morph variants must not be guessed by status name.
local U52_PRESETS={buff={},debuff={}}
local U52_ALIASES={buff={},debuff={}}
for kind,presets in pairs(PRESETS) do
  for _,preset in ipairs(presets) do
    U52_PRESETS[kind][preset.id]=preset
    U52_ALIASES[kind][preset.id]=preset.aliases or {}
  end
end
local function IsKnownU52Effect(kind,id)
  return U52_PRESETS[kind] and U52_PRESETS[kind][id]~=nil
end
-- Names from the named-buffs overview on ESO-Hub. No fabricated IDs or cooldowns:
-- a named status can be applied by multiple skills with different durations.
local CATALOG = {
 buff={
  'Major Aegis','Minor Aegis','Major Berserk','Minor Berserk','Major Brutality','Minor Brutality',
  'Major Courage','Minor Courage','Major Evasion','Minor Evasion','Major Expedition','Minor Expedition',
  'Major Force','Minor Force','Major Fortitude','Minor Fortitude','Gallop','Major Heroism',
  'Minor Heroism','Major Intellect','Minor Intellect','Major Mending','Minor Mending',
  'Major Protection','Minor Protection','Major Resolve','Minor Resolve','Major Savagery',
  'Minor Savagery','Major Sorcery','Minor Sorcery','Major Prophecy','Minor Prophecy',
  'Major Endurance','Minor Endurance','Major Vitality','Minor Vitality',
  'Empower','Major Slayer','Minor Slayer',
 },
 debuff={
  'Major Breach','Minor Breach','Major Vulnerability','Minor Vulnerability',
  'Major Maim','Minor Maim','Major Defile','Minor Defile','Major Cowardice',
  'Minor Cowardice','Major Enervation','Minor Enervation','Major Uncertainty',
  'Minor Uncertainty','Major Lifesteal','Minor Lifesteal','Minor Magickasteal',
  'Major Timidity','Minor Timidity','Major Brittle','Minor Brittle','Off Balance',
  'Chilled','Concussed','Burning','Poisoned','Diseased','Hemorrhaging','Sundered',
  'Overcharged','Stagger','Heat Shock','Crusher','Weakening','Cutthroat\'s Mockery',
 }
}

-- RU/EN labels for the status catalog. RU labels are readable descriptions,
-- not guaranteed to be literal client-localization strings on every server.
local RU = {
 ['Major Aegis']='Великий эгид',['Minor Aegis']='Малый эгид',
 ['Major Berserk']='Великая ярость',['Minor Berserk']='Малая ярость',
 ['Major Brutality']='Великая жестокость',['Minor Brutality']='Малая жестокость',
 ['Major Courage']='Великая храбрость',['Minor Courage']='Малая храбрость',
 ['Major Evasion']='Великое уклонение',['Minor Evasion']='Малое уклонение',
 ['Major Expedition']='Великое ускорение',['Minor Expedition']='Малое ускорение',
 ['Major Force']='Великая сила',['Minor Force']='Малая сила',
 ['Major Fortitude']='Великая стойкость',['Minor Fortitude']='Малая стойкость',
 ['Major Gallop']='Великий галоп',['Gallop']='Галоп',['Major Heroism']='Великий героизм',
 ['Minor Heroism']='Малый героизм',['Major Intellect']='Великий интеллект',
 ['Minor Intellect']='Малый интеллект',['Major Mending']='Великое исцеление',
 ['Minor Mending']='Малое исцеление',['Major Protection']='Великая защита',
 ['Minor Protection']='Малая защита',['Major Resolve']='Великая решимость',
 ['Minor Resolve']='Малая решимость',['Major Savagery']='Великая свирепость',
 ['Minor Savagery']='Малая свирепость',['Major Sorcery']='Великое колдовство',
 ['Minor Sorcery']='Малое колдовство',['Major Prophecy']='Великое пророчество',
 ['Minor Prophecy']='Малое пророчество',['Major Endurance']='Великая выносливость',
 ['Minor Endurance']='Малая выносливость',['Major Vitality']='Великая живучесть',
 ['Minor Vitality']='Малая живучесть',['Empower']='Усиление',
 ['Major Slayer']='Великий истребитель',['Minor Slayer']='Малый истребитель',
 ['Major Breach']='Великий прорыв',['Minor Breach']='Малый прорыв',
 ['Major Vulnerability']='Великая уязвимость',['Minor Vulnerability']='Малая уязвимость',
 ['Major Maim']='Великое повреждение',['Minor Maim']='Малое повреждение',
 ['Major Defile']='Великое осквернение',['Minor Defile']='Малое осквернение',
 ['Major Cowardice']='Великая трусость',['Minor Cowardice']='Малая трусость',
 ['Major Enervation']='Великое ослабление',['Minor Enervation']='Малое ослабление',
 ['Major Uncertainty']='Великая неуверенность',['Minor Uncertainty']='Малая неуверенность',
 ['Major Lifesteal']='Великое похищение здоровья',['Minor Lifesteal']='Малое похищение здоровья',
 ['Major Magickasteal']='Великое похищение магии',['Minor Magickasteal']='Малое похищение магии',
 ['Major Timidity']='Великая робость',['Minor Timidity']='Малая робость',
 ['Major Brittle']='Великая хрупкость',['Minor Brittle']='Малая хрупкость',
 ['Off Balance']='Потеря равновесия',['Chilled']='Обморожение',
 ['Concussed']='Контузия',['Burning']='Горение',['Poisoned']='Отравление',
 ['Diseased']='Болезнь',['Hemorrhaging']='Кровотечение',['Sundered']='Раскол',
 ['Overcharged']='Перегрузка',['Stagger']='Пошатывание',
 ['Heat Shock']='Тепловой шок',['Crusher']='Крушитель',['Weakening']='Ослабление',["Cutthroat's Mockery"]='Насмешка головореза',
 ['Minor Toughness']='Малая прочность',['Major Vexation']='Великое раздражение',
 ['Minor Vexation']='Малое раздражение',['Minor Mangle']='Малое увечье',
}
local function BiName(en)
  return (RU[en] or en)..' / '..en
end
-- These are example effect IDs, NOT a universal ID for every source.
local VERIFIED = {buff={['Minor Savagery']=61898,['Major Berserk']=61745,['Major Aegis']=93123},
                  debuff={["Cutthroat's Mockery"]=268259,['Crusher']=17906,
                      ['Major Breach']=62787,
                      ['Major Vulnerability']=122389,['Minor Vulnerability']=81519,
                      ['Minor Lifesteal']=80020,['Minor Magickasteal']=39100,
                      ['Off Balance']=45902,['Weakening']=17945}}
local function NormalizeTitle(value)
  return tostring(value or ''):lower():gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
end

-- Off Balance has source-specific effect IDs. These aliases are verified
-- as 'Off Balance' in the imported ESO Logs ability catalog; older addons
-- independently document 39077, 62988 and other source-specific IDs.
-- Do NOT add Off Balance Immunity IDs here (134599 is a distinct effect).
-- 62998 and 63003 were present in the older ESO Logs list, but are
-- absent in U52; do not register unverified aliases for all players.
local OFF_BALANCE_IDS={45902,1347,2727,29598,39077,62988,131562}
local OFF_BALANCE_SET={}
for _,id in ipairs(OFF_BALANCE_IDS) do OFF_BALANCE_SET[id]=true end
local function IsOffBalanceEntry(entry)
  if entry.kind~='debuff' then return false end
  if OFF_BALANCE_SET[entry.abilityId] then return true end
  local name=NormalizeTitle(entry.name or '')
  return name=='off balance' or name=='off-balance' or
         name=='потеря равновесия' or
         name=='потеря равновесия / off balance'
end
local function StatusFromObserved(name)
  local normalized=NormalizeTitle(name)
  for _,kind in ipairs({'buff','debuff'}) do
    for _,english in ipairs(CATALOG[kind]) do
      if normalized==NormalizeTitle(english) or normalized==NormalizeTitle(RU[english]) then
        return english
      end
    end
  end
  return nil
end

local ICON_CHOICES = {
 {name='Авто / Auto: иконка эффекта', iconId=0},
 {name='Клинок / Nightblade: Blade', iconId=33375},
 {name='Метка / Nightblade: Mark', iconId=36968},
 {name='Тень / Nightblade: Shadow', iconId=35441},
 {name='ДК: штандарт', iconId=28988},
 {name='ДК: каменный кулак', iconId=31837},
 {name='Оружие: колющий удар', iconId=38250},
 {name='Посох: сила стихий', iconId=39011},
 {name='Оборотень: рёв', iconId=32632},
 {name='НБ: кровоизлияние', iconId=61898},
 {name='Насмешка головореза', iconId=268259},
}
local FALLBACK = { mastery='/esoui/art/icons/ability_nightblade_020.dds',buff='/esoui/art/icons/ability_nightblade_020.dds',debuff='/esoui/art/icons/ability_nightblade_011.dds'}

local function Now() return GetFrameTimeSeconds() end
local function Say(t) d('|cDBAC65[Ramaladni]|r '..tostring(t)) end
-- Limit chat output even when the ESO effect bus is flooded with events.
local function DebugSay(message)
  if not R.debug then return end
  local now=Now()
  if now-R.debugWindow>=1 then
    if R.debugSuppressed>0 then Say('Debug: пропущено '..R.debugSuppressed..' повторных сообщений') end
    R.debugWindow=now;R.debugPrinted=0;R.debugSuppressed=0
  end
  if R.debugPrinted<DEBUG_MESSAGES_PER_SECOND then
    R.debugPrinted=R.debugPrinted+1
    Say(message)
  else
    R.debugSuppressed=R.debugSuppressed+1
  end
end
local function ValidId(value)
  local n=tonumber(value)
  if n and n>=1 and n<=2147483647 and n==math.floor(n) then return n end
  return nil
end
local function TextureFor(id,kind)
  if ValidId(id) then
    local texture=GetAbilityIcon(id)
    if type(texture)=='string' and texture~='' and not string.find(texture,'icon_missing',1,true) then return texture end
  end
  return FALLBACK[kind]
end
-- Pick the actual texture from the selected group, not a manually chosen
-- icon. Try source variants if the representative ID has no ESO icon.
local function AutoTexture(id,kind,ids)
  local tex=TextureFor(id,kind)
  if tex~=FALLBACK[kind] then return tex,id end
  for _,candidate in ipairs(ids or {}) do
    local icon=TextureFor(candidate,kind)
    if icon~=FALLBACK[kind] then return icon,candidate end
  end
  return FALLBACK[kind],id
end
local function Background(name,parent)
  local control=WM:CreateControl(name,parent,CT_BACKDROP)
  control:SetAnchorFill(parent)
  control:SetCenterTexture('/esoui/art/tooltips/UI-TooltipCenter.dds')
  control:SetEdgeTexture('/esoui/art/tooltips/UI-Border.dds',128,16,16)
  control:SetCenterColor(.07,.075,.11,.94)
  control:SetEdgeColor(.45,.45,.55,1)
  control:SetMouseEnabled(false)
  return control
end
local function Label(parent,text,x,y,w,h,font)
  local ctrl=WM:CreateControl(nil,parent,CT_LABEL)
  ctrl:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
  ctrl:SetDimensions(w,h)
  ctrl:SetFont(font or 'ZoFontGame')
  ctrl:SetText(text)
  ctrl:SetColor(.93,.92,.88,1)
  ctrl:SetMouseEnabled(false)
  return ctrl
end
-- Use a centered child label instead of the native button caption: ESO's
-- button textures/fonts can shift the native caption toward the upper edge.
-- The child label never captures mouse clicks; button handlers stay unchanged.
local function Button(name,parent,text,x,y,w,h,handler)
  local ctrl=WM:CreateControl(name,parent,CT_BUTTON)
  ctrl:SetDimensions(w,h)
  ctrl:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
  ctrl:SetNormalTexture(ADDON..'/textures/button_trim.dds')
  ctrl:SetPressedTexture(ADDON..'/textures/button_trim.dds')
  ctrl:SetMouseOverTexture(ADDON..'/textures/button_trim.dds')
  local rim=WM:CreateControl(nil,ctrl,CT_BACKDROP)
  rim:SetAnchorFill(ctrl)
  rim:SetCenterColor(0,0,0,0)
  rim:SetEdgeTexture('/esoui/art/tooltips/UI-Border.dds',128,16,1)
  rim:SetEdgeColor(.58,.48,.28,.82)
  rim:SetMouseEnabled(false)
  ctrl:SetText('')
  local caption=WM:CreateControl(nil,ctrl,CT_LABEL)
  caption:SetAnchorFill(ctrl)
  caption:SetFont((h<=24) and '$(BOLD_FONT)|13|soft-shadow-thin'
                or '$(BOLD_FONT)|17|soft-shadow-thin')
  caption:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  caption:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  caption:SetMouseEnabled(false)
  caption:SetColor(.85,.81,.70,1)
  caption:SetText(text or '')
  ctrl.ramaladniCaption=caption
  ctrl:SetHandler('OnMouseEnter',function() caption:SetColor(.98,.94,.81,1) end)
  ctrl:SetHandler('OnMouseExit',function() caption:SetColor(.85,.81,.70,1) end)
  ctrl:SetHandler('OnClicked',handler)
  return ctrl
end

local function Edit(name,parent,x,y,w,initial)
  local bg=WM:CreateControlFromVirtual(name..'Bg',parent,'ZO_EditBackdrop')
  bg:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
  bg:SetDimensions(w,30)
  local e=WM:CreateControlFromVirtual(name,bg,'ZO_DefaultEditForBackdrop')
  e:ClearAnchors()
  e:SetAnchor(TOPLEFT,bg,TOPLEFT,10,2)
  e:SetDimensions(w-20,26)
  e:SetMaxInputChars(12)
  e:SetText(initial or '')
  return e
end
local function Combo(name,parent,x,y,w)
  local container=WM:CreateControlFromVirtual(name,parent,'ZO_ComboBox')
  container:SetDimensions(w,30)
  container:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
  local combo=ZO_ComboBox_ObjectFromContainer(container)
  combo:SetSortsItems(false)
  -- Decorative border only. Mouse input stays on the original combo box.
  local rim=WM:CreateControl(nil,parent,CT_BACKDROP)
  rim:SetAnchor(TOPLEFT,container,TOPLEFT,0,0)
  rim:SetDimensions(w,30)
  rim:SetCenterColor(0,0,0,0)
  rim:SetEdgeTexture('/esoui/art/tooltips/UI-Border.dds',128,16,1)
  rim:SetEdgeColor(.55,.47,.29,.6)
  rim:SetMouseEnabled(false)
  return combo
end
local function SavePos(entry,control)
  if not R.sv then return end
  local x,y=control:GetLeft(),control:GetTop()
  if x and y then entry.x,entry.y=math.floor(x+.5),math.floor(y+.5) end
end
local function DisplayName(entry)
  if type(entry.name)=='string' and entry.name~='' then return entry.name end
  local name=GetAbilityName(entry.abilityId)
  if type(name)=='string' and name~='' then return name end
  return 'Неизвестный эффект'
end
-- HUD deliberately shows ONLY the texture and countdown, never effect names.
-- Names remain in the settings dropdown/list and SavedVariables.
local HUD_SIZE=56  -- +5% from 53, rounded to nearest pixel
local HUD_ICON=50  -- +5% from 48, rounded to nearest pixel
local function FormatRemaining(seconds)
  -- ProcSetTimer-style integer countdown; color comes from the effect state.
  return tostring(math.max(1,math.ceil(seconds)))
end
-- Render UI only on changes of visible time or state. No frame-by-frame SetText.
local function SetHudTime(widget,seconds,estimated)
  local remaining=math.max(0,seconds)
  local text=(estimated and '~' or '')..FormatRemaining(remaining)
  local font=(remaining>=100) and '$(BOLD_FONT)|21|soft-shadow-thick'
                                   or '$(BOLD_FONT)|29|soft-shadow-thick'
  if widget.font~=font then widget.timer:SetFont(font);widget.font=font end
  if widget.lastText~=text then widget.timer:SetText(text);widget.lastText=text end
end
local function SetHudMode(w,mode)
  if w.mode==mode then return end
  w.mode=mode
  if mode=='active' then
    w.timer:SetColor(.29,1,.45,1)
    w.tex:SetAlpha(1)
    w.bg:SetCenterColor(.20,.84,.34,1)
    w.bg:SetEdgeColor(.20,.84,.34,1)
  elseif mode=='cooldown' then
    w.timer:SetColor(1,.25,.25,1)
    w.tex:SetAlpha(.8)
    w.bg:SetCenterColor(.93,.22,.22,1)
    w.bg:SetEdgeColor(.93,.22,.22,1)
  else
    w.timer:SetColor(.73,.73,.73,1)
    w.tex:SetAlpha(.38)
    w.bg:SetCenterColor(.42,.42,.48,.7)
    w.bg:SetEdgeColor(.42,.42,.48,.7)
  end
end
-- UI pool: ESO top-level controls cannot be destroyed. Rebind instead of
-- hiding and leaking another set of control references on each Add/Remove.
-- ESO's HUD and HUD_UI are the only scenes where combat indicators belong.
-- Draw tiers alone cannot guarantee that standalone HUD windows stay behind
-- inventory/skills; hide them while game menus own the active scene instead.
local function IsGameplayHudScene()
  if not SCENE_MANAGER then return false end
  if SCENE_MANAGER.IsShowing then
    return SCENE_MANAGER:IsShowing('hud') or SCENE_MANAGER:IsShowing('hudui')
  end
  local scene=SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
  local name=scene and scene.GetName and scene:GetName()
  return name=='hud' or name=='hudui'
end
local function UpdateHudSceneVisibility()
  local visible=IsGameplayHudScene()
  if R.hudSceneVisible==visible then return end
  R.hudSceneVisible=visible
  local show=R.hudVisible and visible
  for _,widget in pairs(R.widgets) do
    widget.win:SetHidden(not show)
  end
end
local function RegisterHudSceneCallbacks()
  if R.hudSceneCallbacks then return end
  R.hudSceneCallbacks=true
  if not SCENE_MANAGER or not SCENE_MANAGER.GetScene then return end
  local function OnGameplaySceneStateChanged()
    UpdateHudSceneVisibility()
  end
  for _,sceneName in ipairs({'hud','hudui'}) do
    local scene=SCENE_MANAGER:GetScene(sceneName)
    if scene and scene.RegisterCallback then
      scene:RegisterCallback('StateChange',OnGameplaySceneStateChanged)
    end
  end
  -- Scene changes are uncommon; this does not touch the combat effect pipeline.
  UpdateHudSceneVisibility()
end

local function MakeWidget(entry)
  local w=table.remove(R.widgetsFree)
  if not w then
    R.widgetsMade=R.widgetsMade+1
    local name='RamaladniTrackerV2_'..tostring(R.widgetsMade)
    local win=WM:CreateTopLevelWindow(name)
    win:SetDimensions(HUD_SIZE,HUD_SIZE)
    win:SetClampedToScreen(true)
    -- HUD icons must stay below inventory, skills and other native panels.
    -- In particular, never put persistent tracker windows in DL_OVERLAY.
    win:SetDrawTier(DT_LOW)
    win:SetDrawLayer(DL_CONTROLS)
    win:SetDrawLevel(0)
    win:SetMovable(true)
    local bg=Background(nil,win)
    local tex=WM:CreateControl(nil,win,CT_TEXTURE)
    tex:SetAnchor(TOPLEFT,win,TOPLEFT,3,3)
    tex:SetDimensions(HUD_ICON,HUD_ICON)
    tex:SetMouseEnabled(false)
    local timer=WM:CreateControl(nil,win,CT_LABEL)
    timer:SetAnchor(BOTTOMRIGHT,win,BOTTOMRIGHT,-3,-3)
    timer:SetDimensions(HUD_ICON,34)
    timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    timer:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    timer:SetMouseEnabled(false)
    local amount=WM:CreateControl(nil,win,CT_LABEL)
    amount:SetAnchor(TOPRIGHT,win,TOPRIGHT,-2,2)
    amount:SetDimensions(HUD_ICON,21)
    amount:SetFont('$(BOLD_FONT)|19|soft-shadow-thick')
    amount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    amount:SetColor(1,1,.67,1)
    amount:SetMouseEnabled(false)
    local drag=WM:CreateControl(nil,win,CT_CONTROL)
    drag:SetAnchorFill(win)
    drag:SetMouseEnabled(true)
    w={win=win,tex=tex,timer=timer,amount=amount,bg=bg,drag=drag,entry=nil}
    local function StartDrag(self,button)
      if button==MOUSE_BUTTON_INDEX_LEFT and w.entry then self:GetParent():StartMoving() end
    end
    local function FinishDrag(self,button)
      if button==MOUSE_BUTTON_INDEX_LEFT and w.entry then
        local parent=self:GetParent()
        parent:StopMovingOrResizing()
        SavePos(w.entry,parent)
      end
    end
    drag:SetHandler('OnMouseDown',StartDrag)
    drag:SetHandler('OnMouseUp',FinishDrag)
    win:SetHandler('OnMoveStop',function(self) if w.entry then SavePos(w.entry,self) end end)
    win:SetHandler('OnMouseDown',function(self,b) if b==MOUSE_BUTTON_INDEX_LEFT and w.entry then self:StartMoving() end end)
    win:SetHandler('OnMouseUp',function(self,b)
      if b==MOUSE_BUTTON_INDEX_LEFT and w.entry then self:StopMovingOrResizing();SavePos(w.entry,self) end
    end)
  end
  w.entry=entry   -- all mouse handlers use current entry, NOT removed entries
  w.amount:SetHidden(entry.kind~='mastery')
  w.amount:SetText('')
  w.lastAmount=nil
  w.mode=nil;w.font=nil;w.lastText=nil
  w.win:ClearAnchors()
  w.win:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,entry.x,entry.y)
  w.win:SetMouseEnabled(true)
  w.win:SetHidden(not (R.hudVisible and R.hudSceneVisible))
  w.tex:SetTexture(entry.kind=='mastery' and
    (entry.iconId and TextureFor(entry.iconId,entry.kind) or entry.iconPath or TextureFor(entry.abilityId,entry.kind))
    or TextureFor(entry.autoIconId or entry.abilityId,entry.kind))
  R.widgets[entry.uid]=w
  R.states[entry.uid]={untilTime=0,cooldownUntil=0,lastBegin=nil,stacks=0,activeFlag=false,observedId=nil,
                       testUntil=0,testCD=0,targets={},targetCount=0}
  SetHudMode(w,'idle')
  w.font='$(BOLD_FONT)|29|soft-shadow-thick'; w.timer:SetFont(w.font)
  w.timer:SetText('--');w.lastText='--'
end
local function RemoveWidget(entry)
  local w=R.widgets[entry.uid]
  if w then
    w.win:StopMovingOrResizing()
    w.win:SetHidden(true)
    w.win:SetMouseEnabled(false)
    w.entry=nil
    R.widgetsFree[#R.widgetsFree+1]=w
  end
  R.widgets[entry.uid]=nil;R.states[entry.uid]=nil
end
-- Fast ability/name indices; avoid checking all indicators for each irrelevant event.
local function AddIndexedName(byName,normalized,entry)
  if normalized=='' then return end
  local entries=byName[normalized]
  if not entries then entries={};byName[normalized]=entries end
  for _,present in ipairs(entries) do
    if present.uid==entry.uid then return end
  end
  table.insert(entries,entry)
end
-- Each selected effect owns its private array of observed candidate IDs in
-- SavedVariables. UI never displays this array; the tracker needs it only.
local function CopyIds(ids,first)
  local copy,used={},{}
  local function Take(value)
    local n=ValidId(value)
    if n and not used[n] then used[n]=true;copy[#copy+1]=n end
  end
  if first then Take(first) end
  if type(ids)=='table' then
    for _,id in ipairs(ids) do Take(id) end
  end
  return copy
end
local function ResolvedGroup(entry)
  if entry.kind=='mastery' then return nil end
  if entry.groupKey and GROUPS.Contains and GROUPS.Contains(entry.groupKey,entry.abilityId) then
    return entry.groupKey
  end
  return GROUPS.Find(entry.kind,entry.abilityId)
end
local function Grouped(entry)
  return entry.kind~='mastery' and type(entry.effectIds)=='table' and #entry.effectIds>1
end
local function SyncEffectIds(entry)
  if entry.kind=='mastery' then return end
  local key=ResolvedGroup(entry)
  entry.groupKey=key
  if key then
    entry.effectIds=CopyIds(GROUPS.Members(key),entry.abilityId)
    local en=GROUPS.Name(key)
    entry.name=BiName(en)
  elseif IsOffBalanceEntry(entry) then
    entry.effectIds=CopyIds(OFF_BALANCE_IDS,entry.abilityId)
    entry.name=BiName('Off Balance')
  else
    local aliases=U52_ALIASES[entry.kind] and U52_ALIASES[entry.kind][entry.abilityId]
    -- An ungrouped effect from a previous version retains its own IDs.
    entry.effectIds=CopyIds(aliases or entry.effectIds,entry.abilityId)
  end
  if not ValidId(entry.autoIconId) or (key and not GROUPS.Contains(key,entry.autoIconId)) then
    local _,iconId=AutoTexture(entry.abilityId,entry.kind,entry.effectIds)
    entry.autoIconId=iconId
  end
end
local function RebuildTrackingIndex()
  local byId,byName={},{}
  for _,entry in ipairs(R.sv.entries) do
    local id=entry.abilityId
    SyncEffectIds(entry)
    local assigned=entry.groupKey
    local added={}
    local function Register(candidateId)
      if candidateId and not added[candidateId] then
        added[candidateId]=true
        if not byId[candidateId] then byId[candidateId]={} end
        table.insert(byId[candidateId],entry)
      end
    end
    Register(id)
    if entry.kind~='mastery' then
      for _,candidateId in ipairs(entry.effectIds or {}) do Register(candidateId) end
    end
    if entry.kind=='mastery' then
      local mastery=MASTERY.byKey[entry.masteryKey]
      if mastery then
        for _,candidateId in ipairs(mastery.candidateIDs) do Register(candidateId) end
      end
    end
    if IsOffBalanceEntry(entry) then
      -- Off Balance is a separate mechanic with its own source-ID list.
      for _,aliasId in ipairs(OFF_BALANCE_IDS) do Register(aliasId) end
      for _,aliasId in ipairs({45902,39077,62988}) do
        local localized=NormalizeTitle(GetAbilityName(aliasId))
        if localized~='' and localized~='off balance immunity' then
          AddIndexedName(byName,localized,entry)
        end
      end
    end
    local left,right=(entry.name or ''):match('^(.-)%s+/%s+(.+)$')
    -- A grouped effect is identified by real event IDs, not an ambiguous
    -- localized-name match (which may refer to a different source).
    if left and entry.kind~='mastery' and not assigned and not IsKnownU52Effect(entry.kind,id) then
      for _,part in ipairs({left,right}) do
        local normalized=NormalizeTitle(part)
        if normalized~='' then AddIndexedName(byName,normalized,entry) end
      end
    end
  end
  R.index={byId=byId,byName=byName,hasNames=(next(byName)~=nil),
           nameMemo={},nameMemoRing={},memoNext=1}
end
local EMPTY_MATCHES={}
local NAME_MEMO_CAP=256
local function MatchingEntries(id,name)
  local idx=R.index
  local byId=idx.byId[id]
  -- Most tracked IDs do not require localized-name fallback. Skip all string
  -- conversions when there are no name-based entries at all.
  if not idx.hasNames or type(name)~='string' or name=='' then return byId or EMPTY_MATCHES end
  local normalized=idx.nameMemo[name]
  if not normalized then
    normalized=NormalizeTitle(name)
    local slot=idx.memoNext
    local previous=idx.nameMemoRing[slot]
    if previous then idx.nameMemo[previous]=nil end
    idx.nameMemoRing[slot]=name
    idx.nameMemo[name]=normalized
    idx.memoNext=(slot%NAME_MEMO_CAP)+1
  end
  local byName=idx.byName[normalized]
  if not byId then return byName or EMPTY_MATCHES end
  if not byName or byId==byName then return byId end
  -- At most 12 entries are tracked, so prefer a short scan over allocating
  -- a second hash table for every event where ID and name both match.
  local candidates={}
  local found={}
  for _,entry in ipairs(byId) do found[entry.uid]=true; candidates[#candidates+1]=entry end
  for _,entry in ipairs(byName) do
    if not found[entry.uid] then found[entry.uid]=true; candidates[#candidates+1]=entry end
  end
  return candidates
end
local function RefreshGroupBuff(state,now)
  local maxEnd=0
  for id,finish in pairs(state.buffSources or {}) do
    if finish<=now then state.buffSources[id]=nil
    elseif finish>maxEnd then maxEnd=finish end
  end
  state.untilTime=maxEnd
end
local function ApplyEffect(entry,beginTime,endTime,source,actualId)
  local state=R.states[entry.uid]
  if not state then return end
  local now=Now()
  if type(endTime)~='number' or endTime<=now then return end
  local begin=(type(beginTime)=='number' and beginTime>0) and beginTime or now
  if Grouped(entry) then
    local id=ValidId(actualId) or entry.abilityId
    if not state.buffSources then state.buffSources={} end
    local oldEnd=state.buffSources[id]
    if entry.cooldown and entry.cooldown>0 and (not oldEnd or oldEnd<=now) then
      state.cooldownUntil=math.max(state.cooldownUntil,begin+entry.cooldown)
    end
    state.buffSources[id]=endTime
    RefreshGroupBuff(state,now)
    return
  end
  local newlyApplied=not state.lastBegin or math.abs(begin-state.lastBegin)>.15
  if newlyApplied then
    state.lastBegin=begin
    if entry.cooldown and entry.cooldown>0 then state.cooldownUntil=math.max(state.cooldownUntil,begin+entry.cooldown) end
    if R.debug then DebugSay(string.format('START %s id=%d begin=%.1f end=%.1f cooldown=%.1f via=%s',entry.kind,entry.abilityId,begin,endTime,entry.cooldown or 0,source)) end
  end
  state.untilTime=endTime
end
-- ESO can reuse a named effect for several sources and IDs. The catalog
-- displays RU/EN names, so match by name as a fallback when a preset ID
-- does not match the real effect ID returned by this character's client.
local function EntryMatches(entry,seenId,seenName)
  if entry.abilityId==seenId then return true end
  if type(seenName)~='string' or seenName=='' then return false end
  local left,right=(entry.name or ''):match('^(.-)%s+/%s+(.+)$')
  if not left then return false end -- Manual custom labels are ID-only.
  local actual=NormalizeTitle(seenName)
  return actual==NormalizeTitle(left) or actual==NormalizeTitle(right)
end
local function IsPlayerUnit(unitTag,unitName)
  if unitTag=='player' then return true end
  if unitTag and unitTag~='' and AreUnitsEqual and AreUnitsEqual(unitTag,'player') then return true end
  -- Some events have no unit tag. Compare the player name rather than
  -- requiring a current reticle or a focus target.
  if (unitTag==nil or unitTag=='') and type(unitName)=='string' and unitName~='' and GetUnitName then
    local myName=GetUnitName('player')
    return type(myName)=='string' and myName~='' and NormalizeTitle(myName)==NormalizeTitle(unitName)
  end
  return false
end
local function IsEnemyDebuff(unitTag,unitName,effectType)
  if IsPlayerUnit(unitTag,unitName) then return false end
  if type(effectType)=='number' then
    -- BuffEffectType: 1 = buff, 2 = debuff. Do not mistake a group
    -- member's benefit for a debuff when the same ability ID is reused.
    local debuffType=BUFF_EFFECT_TYPE_DEBUFF or 2
    if effectType~=debuffType then return false end
  end
  return true
end
local function TargetKey(unitId,unitName,unitTag)
  local id=tonumber(unitId)
  if id and id>0 then return 'id:'..tostring(id) end
  if type(unitName)=='string' and unitName~='' then return 'name:'..NormalizeTitle(unitName) end
  if unitTag=='reticleover' and GetUnitName then
    local name=GetUnitName('reticleover')
    if type(name)=='string' and name~='' then return 'name:'..NormalizeTitle(name) end
  end
  return 'unknown'
end
local function RefreshDebuffState(state,now)
  local maxEnd=0
  local estimated=false
  local count=0
  for key,target in pairs(state.targets) do
    if type(target.untilTime)~='number' or target.untilTime<=now then
      state.targets[key]=nil
    else
      count=count+1
      if target.untilTime>maxEnd then
        maxEnd=target.untilTime
        estimated=(target.estimated==true)
      end
    end
  end
  state.targetCount=count
  state.untilTime=maxEnd
  state.timerEstimated=estimated
end
-- Prevent unusual mass target effects from growing state.targets unbounded.
local function CapTargets(state)
  local n=0
  local earliestKey,earliestEnd=nil,math.huge
  for key,info in pairs(state.targets) do
    n=n+1
    if (info.untilTime or 0)<earliestEnd then earliestEnd=info.untilTime or 0;earliestKey=key end
  end
  if n>MAX_TARGETS_PER_EFFECT and earliestKey then state.targets[earliestKey]=nil end
end
-- Map an untagged EVENT_EFFECT_CHANGED and a reticle scan to the same enemy
-- where possible. The reticle scan has only a name (not a reliable unitId).
-- Do NOT merge two enemies with identical names: the source has to be unique.
local function ExistingTargetKey(state,unitId,unitName,unitTag)
  local key=TargetKey(unitId,unitName,unitTag)
  local name=(type(unitName)=='string' and unitName~='') and NormalizeTitle(unitName) or nil
  local named=name and ('name:'..name) or nil
  if key:sub(1,3)=='id:' then
    -- A prior reticle scan may have recorded the same boss under its name.
    if named and state.targets[named] then
      local stale=state.targets[named]
      local byId=state.targets[key]
      if not byId or stale.untilTime>(byId.untilTime or 0) then
        state.targets[key]=stale
      end
      state.targets[named]=nil
    end
    return key
  end
  if named then
    local found=nil
    for otherKey,info in pairs(state.targets) do
      if otherKey:sub(1,3)=='id:' and info.unitName==name then
        if found then return key end -- ambiguous: different enemies, same name
        found=otherKey
      end
    end
    if found then return found end
  end
  return key
end

-- The endTime is SERVER-REPORTED absolute expiry, not a guessed spell duration.
-- Nazaray increases this expiry on Major/Minor debuffs, without reapplying them.
-- EFFECT_RESULT_UPDATED and periodic target scans both refresh the same timer.
local function ApplyDebuff(entry,beginTime,endTime,unitId,unitName,unitTag,source,change,actualId)
  local state=R.states[entry.uid]
  if not state then return end
  local now=Now()
  local grouped=Grouped(entry)
  local observedId=ValidId(actualId) or entry.abilityId
  local key
  if grouped then
    local base=TargetKey(unitId,unitName,unitTag)
    local suffix='|effect:'..tostring(observedId)
    key=base..suffix
    -- A reticle name-only scan can precede the identified target event.
    -- Migrate its one specific source entry; never merge other group IDs.
    if base:sub(1,3)=='id:' and type(unitName)=='string' and unitName~='' then
      local nameKey='name:'..NormalizeTitle(unitName)..suffix
      local scanned=state.targets[nameKey]
      if scanned then
        local previous=state.targets[key]
        if not previous or scanned.untilTime>(previous.untilTime or 0) then
          state.targets[key]=scanned
        end
        state.targets[nameKey]=nil
      end
    end
  else
    key=ExistingTargetKey(state,unitId,unitName,unitTag)
  end
  local old=state.targets[key]
  local begin=(type(beginTime)=='number' and beginTime>0) and beginTime or now
  local estimated=false
  if type(endTime)~='number' or endTime<=now then
    -- Rare case: ESO reports an Off Balance GAIN event without expiry.
    -- Its game-mechanic duration is 7s. We show '~' for this estimate.
    -- Never start a new 7s timer from periodic scan/update: doing so
    -- would create a permanent, incorrectly refreshed indicator.
    if not IsOffBalanceEntry(entry) then return end
    if change==EFFECT_RESULT_GAINED then
      begin=now
      endTime=now+7
      estimated=true
    elseif source=='reticle-scan' and type(beginTime)=='number'
           and beginTime>0 and beginTime<=now and now-beginTime<7 then
      -- Scanned start timestamp is known; remaining time is estimated.
      begin=beginTime
      endTime=beginTime+7
      estimated=true
    else
      if R.debug and (change==EFFECT_RESULT_UPDATED or change==EFFECT_RESULT_FULL_REFRESH) then
        DebugSay('OFFBALANCE: no valid endTime, no new timer; check /ramaladni offbalance')
      end
      return
    end
  end
  if endTime<=now then return end
  local prevEnd=old and old.untilTime or nil
  -- The reticle scan can lag behind a Nazaray extension event. Never let
  -- an older scan shorten an authoritative, still-active expiry. Fades and
  -- genuine new event applications remain authoritative.
  if old and source=='reticle-scan' and endTime<old.untilTime-.20 and old.untilTime>now then return end
  -- An increase of absolute expiry can be Nazaray, a refresh, or another
  -- extender. We do not assume Nazaray unless the game reports the change.
  local extended=prevEnd and endTime>prevEnd+.20
  local changedBegin=old and math.abs(begin-(old.beginTime or 0))>.15
  local gained=(change==EFFECT_RESULT_GAINED)
  local newCast=not old or (changedBegin and not extended and (gained or source=='reticle-scan'))
  -- Preserve original application time for a true prolongation: no cooldown
  -- restart and no artificial timer reset. For a new cast use its new begin.
  local effectiveBegin=(old and extended) and old.beginTime or begin
  state.targets[key]={beginTime=effectiveBegin,untilTime=endTime,estimated=estimated,
                      unitName=(type(unitName)=='string' and NormalizeTitle(unitName)) or (old and old.unitName)}
  if not old then CapTargets(state) end
  if newCast and entry.cooldown and entry.cooldown>0 then
    state.cooldownUntil=math.max(state.cooldownUntil,begin+entry.cooldown)
  end
  if IsOffBalanceEntry(entry) then
    -- Off Balance immunity: 15s AFTER the actual 7s debuff expires.
    -- It is deliberately a separate RED cooldown, not a green debuff.
    state.cooldownUntil=math.max(state.cooldownUntil,endTime+15)
  end
  RefreshDebuffState(state,now)
  if R.debug then
    if extended and old then
      DebugSay(string.format('EXTEND %s target=%s +%.1fs remaining=%.1fs via=%s',
        DisplayName(entry),key,endTime-prevEnd,endTime-now,source))
    elseif newCast then
      DebugSay(string.format('START debuff %s target=%s end=%.1f via=%s',
        DisplayName(entry),key,endTime,source))
    elseif prevEnd and math.abs(endTime-prevEnd)>.20 then
      DebugSay(string.format('REFRESH debuff %s target=%s remaining=%.1f via=%s',
        DisplayName(entry),key,endTime-now,source))
    end
  end
end
local function FadeDebuff(entry,unitId,unitName,unitTag,actualId)
  local state=R.states[entry.uid]
  if not state then return end
  if Grouped(entry) then
    local suffix='|effect:'..tostring(ValidId(actualId) or entry.abilityId)
    local key=TargetKey(unitId,unitName,unitTag)..suffix
    state.targets[key]=nil
    if type(unitName)=='string' and unitName~='' then
      local normalized=NormalizeTitle(unitName)
      state.targets['name:'..normalized..suffix]=nil
      if not tonumber(unitId) or tonumber(unitId)<=0 then
        for otherKey,info in pairs(state.targets) do
          if otherKey:sub(-#suffix)==suffix and info.unitName==normalized then
            state.targets[otherKey]=nil
          end
        end
      end
    end
    RefreshDebuffState(state,Now())
    return
  end
  local key=TargetKey(unitId,unitName,unitTag)
  state.targets[key]=nil
  -- The ID-based state may have been updated via a name-only reticle scan;
  -- remove its corresponding state when a named (ID-less) fade is reported.
  if (not tonumber(unitId) or tonumber(unitId)<=0) and type(unitName)=='string' and unitName~='' then
    local normalized=NormalizeTitle(unitName)
    for otherKey,info in pairs(state.targets) do
      if info.unitName==normalized then state.targets[otherKey]=nil end
    end
  end
  -- Reticle scans have names but no numeric unit ID. Remove their shadow
  -- entry too when the corresponding target's event explicitly fades.
  if type(unitName)=='string' and unitName~='' then
    state.targets['name:'..NormalizeTitle(unitName)]=nil
  end
  RefreshDebuffState(state,Now())
end
-- Mastery values are derived ONLY from genuine observed state.
-- Unsupported context-dependent models remain unknown instead of inventing a percentage.
local function MasteryAmount(entry,state,now)
  local meta=MASTERY.byKey[entry.masteryKey]
  if not meta then return nil end
  if MASTERY.DisplayAmount then
    local handled,amount=MASTERY.DisplayAmount(entry,state,now)
    if handled then return amount end
  end
  local n=tonumber(state.stacks) or 0
  if meta.model=='stacks_percent' and n>0 and (state.activeFlag or state.untilTime>now) then
    if meta.cap>0 then n=math.min(n,meta.cap) end
    return tostring(math.floor(n*(meta.value or 0)+.5))..'%'
  elseif meta.model=='timed_percent' and state.untilTime>now then
    return tostring(meta.value)..'%'
  elseif meta.model=='timed_number' and state.untilTime>now then
    return '+'..tostring(meta.value)
  elseif n>0 and (state.activeFlag or state.untilTime>now) then
    return 'x'..tostring(n)
  end
  return nil
end
local function UpdateWidgets()
  local now=Now()
  for _,entry in ipairs(R.sv.entries) do
    local w,s=R.widgets[entry.uid],R.states[entry.uid]
    if w and s then
      -- One constant Nightblade passive uses the large label for a static
      -- CRITICAL DAMAGE CAP, not a countdown. Do not overwrite its text
      -- with '--' on every 200ms redraw; all other entries are unchanged.
      local staticCritCap=entry.kind=='mastery' and entry.masteryKey=='Nightblade:Above and Beyond'
      if entry.kind=='debuff' or (entry.kind=='mastery' and MASTERY.byKey[entry.masteryKey] and MASTERY.byKey[entry.masteryKey].target) then
        RefreshDebuffState(s,now)
      end
      if entry.kind=='buff' and Grouped(entry) then RefreshGroupBuff(s,now) end
      if entry.kind=='mastery' then
        local amount=MasteryAmount(entry,s,now) or ''
        if w.lastAmount~=amount then w.amount:SetText(amount);w.lastAmount=amount end
      end
      local untilTime=(s.testUntil>now) and s.testUntil or s.untilTime
      local cooldownUntil=(s.testCD>now) and s.testCD or s.cooldownUntil
      if untilTime>now then
        SetHudMode(w,'active')
        SetHudTime(w,untilTime-now,s.timerEstimated and (entry.kind=='mastery' or IsOffBalanceEntry(entry)))
      elseif entry.kind=='mastery' and s.activeFlag then
        SetHudMode(w,'active')
        if not staticCritCap and w.lastText~='--' then w.timer:SetText('--');w.lastText='--' end
      elseif cooldownUntil>now then
        SetHudMode(w,'cooldown')
        SetHudTime(w,cooldownUntil-now)
      else
        SetHudMode(w,'idle')
        if not staticCritCap then
          if w.font~='$(BOLD_FONT)|29|soft-shadow-thick' then
            w.timer:SetFont('$(BOLD_FONT)|29|soft-shadow-thick');w.font='$(BOLD_FONT)|29|soft-shadow-thick'
          end
          if w.lastText~='--' then w.timer:SetText('--');w.lastText='--' end
        end
      end
      -- Optional module-specific HUD extras; currently used only by
      -- Sorcerer's Sphere of Influence dual timer.
      if MASTERY.UpdateWidgetExtras then MASTERY.UpdateWidgetExtras(entry,w,now) end
    end
  end
end
-- Runtime discovery uses a bounded, replaceable LRU cache. Saved discoveries
-- remain in SavedVariables (up to the existing 500-per-kind limit).
local function Learn(kind,id,name,icon,start,finish,now)
  if not ValidId(id) then return end
  local list=R.observed[kind]
  local old=list[id]
  now=now or Now()
  if not old then
    if R.cacheSize[kind]>=CACHE_LIMIT then
      local oldestId,oldestSeen=nil,math.huge
      for key,value in pairs(list) do
        if (value.seen or 0)<oldestSeen then oldestId=key;oldestSeen=value.seen or 0 end
      end
      if oldestId then list[oldestId]=nil;R.cacheSize[kind]=R.cacheSize[kind]-1 end
    end
    list[id]={name=name or GetAbilityName(id) or ('ID '..id),icon=icon,seen=now}
    R.cacheSize[kind]=R.cacheSize[kind]+1
    R.ui.dirty=true
    if R.sv and R.sv.learned and not R.sv.learned[kind][id] and R.learnedCount[kind]<500 then
      R.sv.learned[kind][id]={name=name or GetAbilityName(id) or ('ID '..id),icon=icon}
      R.learnedCount[kind]=R.learnedCount[kind]+1
    end
  else
    old.seen=now
    if type(icon)=='string' and icon~='' then old.icon=icon end
    if type(name)=='string' and name~='' then old.name=name end
  end
end
local ApplyMastery
-- Reused only for player buff scans; no temporary table allocation per tick.
local buffSeen={}
local function ScanUnit(kind)
  local unitTag=(kind=='buff') and 'player' or 'reticleover'
  if kind=='debuff' and not DoesUnitExist(unitTag) then return end
  local now=Now()
  local count=GetNumBuffs(unitTag) or 0
  local seen=nil
  if kind=='buff' then
    for uid in pairs(buffSeen) do buffSeen[uid]=nil end
    seen=buffSeen
  end
  local unitName=(kind=='debuff' and GetUnitName and GetUnitName(unitTag)) or ''
  for i=1,count do
    local name,start,finish,_,stacks,icon,_,_,_,_,id=GetUnitBuffInfo(unitTag,i)
    if ValidId(id) then
      Learn(kind,id,name,icon,start,finish,now)
      for _,entry in ipairs(MatchingEntries(id,name)) do
        if entry.kind=='mastery' then
          local meta=MASTERY.byKey[entry.masteryKey]
          if meta and ((meta.target and kind=='debuff') or (not meta.target and kind=='buff')) then
            local state=R.states[entry.uid]
            if state then
              local countStacks=stacks
              if kind=='buff' then seen[entry.uid]=true end
              ApplyMastery(entry,EFFECT_RESULT_UPDATED,start,finish,countStacks,unitTag,unitName,nil,'unit-scan',id)
            end
          end
        elseif entry.kind==kind then
          if kind=='buff' then
            seen[entry.uid]=true
            ApplyEffect(entry,start,finish,'player-scan',id)
          else
            -- Scanning the current target is only a fallback; it does not
            -- constrain the tracking to that target after the reticle moves.
            ApplyDebuff(entry,start,finish,nil,unitName,unitTag,'reticle-scan',nil,id)
          end
        end
      end
    end
  end
  if kind=='buff' then
    for _,entry in ipairs(R.sv.entries) do
      if entry.kind=='buff' and not seen[entry.uid] then
        local state=R.states[entry.uid]
        if state and state.untilTime>now then
          state.untilTime=0
          state.lastBegin=nil
          if Grouped(entry) then state.buffSources={} end
          if R.debug then DebugSay('END buff '..DisplayName(entry)..' via=player-scan') end
        end
      end
    end
  end
end
local function Tick()
  if not R.sv then return end
  -- Recheck as a safety net after load screens and scene transitions where
  -- the HUD scene callback order varies between ESO client versions.
  UpdateHudSceneVisibility()
  -- All player buffs are sampled regardless of what the camera points at.
  ScanUnit('buff')
  -- Reticle is an optional extra source for debuffs. EVENT_EFFECT_CHANGED
  -- tracks debuffs even after the reticle leaves the affected enemy.
  ScanUnit('debuff')
  UpdateWidgets()
end
ApplyMastery=function(entry,change,start,finish,stacks,unitTag,unitName,unitId,source,actualId,effectType)
  local state=R.states[entry.uid]
  local meta=MASTERY.byKey[entry.masteryKey]
  if not state or not meta then return false end
  local isTarget=meta.target
  if isTarget then
    if not IsEnemyDebuff(unitTag,unitName,effectType) then return false end
  elseif not IsPlayerUnit(unitTag,unitName) then
    return false
  end
  local ended=(change==EFFECT_RESULT_FADED)
  if isTarget then
    if ended then FadeDebuff(entry,unitId,unitName,unitTag)
      if state.untilTime<=Now() then state.stacks=0;state.activeFlag=false end
    elseif type(finish)=='number' and finish>Now() then
      ApplyDebuff(entry,start,finish,unitId,unitName,unitTag,source,change,actualId)
      state.stacks=tonumber(stacks) or 0
      state.observedId=actualId
    end
  elseif ended then
    state.untilTime=0;state.activeFlag=false;state.stacks=0;state.lastBegin=nil
  else
    state.activeFlag=true
    state.stacks=tonumber(stacks) or 0
    state.observedId=actualId
    if type(finish)=='number' and finish>Now() then
      ApplyEffect(entry,start,finish,source)
    else state.untilTime=0 end
  end
  if MASTERY.OnObservedEffect then
    MASTERY.OnObservedEffect(entry,meta,state,change,start,finish,stacks,source,actualId,Now())
  end
  if R.debug then DebugSay(string.format('MASTERY %s observedID=%s stacks=%s end=%s source=%s',
    meta.en,tostring(state.observedId),tostring(state.stacks),tostring(finish),source)) end
  return true
end
local function OnEffectChanged(_,change,slot,effectName,unitTag,start,finish,stacks,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
  if not ValidId(abilityId) then return end
  local entries=MatchingEntries(abilityId,effectName)
  if #entries==0 then return end -- irrelevant event: no UI work, no timer scan
  local changed=false
  for _,entry in ipairs(entries) do
    if entry.kind=='mastery' then
      if ApplyMastery(entry,change,start,finish,stacks,unitTag,unitName,unitId,'effect-event',abilityId,effectType) then changed=true end
    else
    local relevant=(entry.kind=='buff') and IsPlayerUnit(unitTag,unitName) or IsEnemyDebuff(unitTag,unitName,effectType)
    if R.debug then
      DebugSay(string.format('EVENT %s kind=%s unit=%s change=%s until=%s relevant=%s',
        DisplayName(entry),entry.kind,tostring(unitTag),tostring(change),tostring(finish),tostring(relevant)))
    end
    if relevant then
      changed=true
      Learn(entry.kind,abilityId,effectName,iconName,start,finish)
      if entry.kind=='buff' then
        local state=R.states[entry.uid]
        if state then
          if change==EFFECT_RESULT_FADED then
            if Grouped(entry) then
              if state.buffSources then state.buffSources[abilityId]=nil end
              RefreshGroupBuff(state,Now())
            else
              state.untilTime=0;state.lastBegin=nil
            end
          else ApplyEffect(entry,start,finish,'effect-event',abilityId) end
        end
      else
        if change==EFFECT_RESULT_FADED then FadeDebuff(entry,unitId,unitName,unitTag,abilityId)
        else ApplyDebuff(entry,start,finish,unitId,unitName,unitTag,'effect-event',change,abilityId) end
      end
    end
    end -- regular buff/debuff
  end
  if changed then UpdateWidgets() end
end
-- Combat exit is delayed and cancellable. Retain still-valid debuffs and
-- cooldowns: a tank can leave combat while the raid is still fighting.
local function CombatCleanup()
  EM:UnregisterForUpdate(ADDON..'CombatCleanup')
  R.cleanupPending=false
  if R.combat or (IsUnitInCombat and IsUnitInCombat('player')) then return end
  local now=Now()
  for _,state in pairs(R.states) do
    for key,target in pairs(state.targets) do
      if (target.untilTime or 0)<=now then state.targets[key]=nil end
    end
    RefreshDebuffState(state,now)
    if state.untilTime<=now then state.untilTime=0;state.lastBegin=nil end
    if state.cooldownUntil<=now then state.cooldownUntil=0 end
    if state.untilTime<=now then state.activeFlag=false;state.stacks=0 end
    if state.testUntil<=now then state.testUntil=0 end
    if state.testCD<=now then state.testCD=0 end
  end
  -- Free transient discovery cache, while learned IDs persist in SavedVars.
  R.observed={buff={},debuff={}}
  R.cacheSize={buff=0,debuff=0}
  R.ui.dirty=true
  UpdateWidgets()
end
local function OnCombatStateChanged(_,inCombat)
  R.combat=(inCombat==true)
  if R.cleanupPending then EM:UnregisterForUpdate(ADDON..'CombatCleanup');R.cleanupPending=false end
  if not inCombat then
    R.cleanupPending=true
    EM:RegisterForUpdate(ADDON..'CombatCleanup',2000,CombatCleanup)
  end
end
local function OnTargetChange()
  -- v0.4 cleared all debuffs here, making tracking impossible as soon as
  -- the player looked away. Keep per-enemy timers until their real expiry.
  ScanUnit('debuff')
  UpdateWidgets()
end
-- Search catalogs are refreshed on demand; they contain group names in RU/EN
-- and individual effects previously seen by the game. UI never shows IDs.
local function BuildCatalog(kind)
  local cat=SEARCH.Build(kind,GROUPS,RU,VERIFIED[kind],PRESETS[kind],
    R.sv.learned[kind],R.observed[kind])
  R.searchCatalog=R.searchCatalog or {}
  R.searchCatalog[kind]=cat
  return cat
end
local function Refill(kind)
  BuildCatalog(kind)
  local ui=R.ui.lines[kind]
  if ui and ui.preview then
    local sel=R.selected[kind]
    if sel and sel.id then
      ui.preview:SetTexture(AutoTexture(sel.id,kind,sel.effectIds))
      ui.preview:SetHidden(false)
    else
      -- No active selection: do not leave a stale or fallback icon in the UI.
      ui.preview:SetHidden(true)
    end
  end
end
local function SelectedEffectName(kind)
  local selected=R.selected[kind]
  return (selected and selected.name) or 'Эффект не выбран'
end
local function HideResults()
  if R.ui.searchPopup then R.ui.searchPopup.window:SetHidden(true) end
end
-- Keep the search panel consistent with the list of actual indicators.
-- Selecting an effect is UI-only state; removing its indicator must clear
-- the preview, selected title and success message as a single operation.
local function ClearSearchSelection(kind)
  if kind~='buff' and kind~='debuff' then return end
  R.selected[kind]={}
  local line=R.ui.lines and R.ui.lines[kind]
  if not line then return end
  if line.search and line.search:GetText()~='' then line.search:SetText('') end
  if line.preview then line.preview:SetHidden(true) end
  if line.selected then line.selected:SetText('Эффект не выбран') end
  if line.status then line.status:SetText('') end
  HideResults()
end
local AddEffect -- forward declaration: result click immediately adds a tracked indicator
local function SelectSearchResult(kind,entry)
  if not entry then return end
  local sel=R.selected[kind]
  sel.id=entry.id;sel.name=entry.title;sel.groupKey=entry.groupKey
  sel.effectIds=CopyIds(entry.ids,entry.id)
  local ui=R.ui.lines[kind]
  ui.selected:SetText(SelectedEffectName(kind))
  local icon,iconId=AutoTexture(entry.id,kind,entry.ids)
  sel.autoIconId=iconId
  ui.preview:SetTexture(icon)
  ui.preview:SetHidden(false)
  -- The result itself is the Add action. No secondary selection or button.
  -- Duplicate and MAX checks remain centralized in AddEffect.
  local added=AddEffect(kind)
  HideResults()
  if added then
    ui.search:SetText('')
    ui.selected:SetText('Добавлен: '..entry.title)
    ui.status:SetText('Индикатор добавлен. Удалить его можно через X в списке ниже.')
    if ui.search.LoseFocus then ui.search:LoseFocus() end
  else
    ui.status:SetText('Эффект не добавлен: возможно, он уже есть или достигнут лимит.')
  end
end
local function ShowResults(kind)
  local ui=R.ui.lines[kind]
  local popup=R.ui.searchPopup
  if not ui or not popup then return end
  local typed=ui.search:GetText()
  if not typed or typed=='' then HideResults();return end
  local cat=R.searchCatalog and R.searchCatalog[kind] or BuildCatalog(kind)
  local matches=SEARCH.Match(cat,typed,#popup.rows)
  if #matches==0 then
    -- The player can search for an ability not yet observed by this addon.
    -- Accept it only if the ESO client itself recognizes that ID.
    local requested=ValidId(typed)
    if requested and type(GetAbilityName)=='function' then
      local apiName=GetAbilityName(requested)
      if type(apiName)=='string' and apiName~='' and apiName~='Unknown' then
        matches={{id=requested,ids={requested},title=apiName,en=apiName,ru=apiName}}
      end
    end
  end
  if #matches==0 then HideResults();ui.status:SetText('Ничего не найдено');return end
  ui.status:SetText('Выбери эффект из найденных')
  popup.kind=kind
  -- Never render a detached popover while the settings panel is closed.
  local parent=R.ui.window
  if not parent or parent:IsHidden() then HideResults();return end
  popup.window:ClearAnchors()
  popup.window:SetAnchor(TOPLEFT,parent,TOPLEFT,138,ui.searchY+33)
  popup.window:SetDimensions(574,8+#matches*35)
  for i,row in ipairs(popup.rows) do
    local match=matches[i]
    row.item=match
    if match then
      row.button.ramaladniCaption:SetText(match.title)
      row.button:SetHidden(false)
      row.icon:SetTexture(AutoTexture(match.id,kind,match.ids))
      row.icon:SetHidden(false)
    else
      row.button:SetHidden(true)
      row.icon:SetHidden(true)
    end
  end
  popup.window:SetHidden(false)
end
local function CreateSearchPopup()
  -- Popup is a CHILD of settings, not an independent top-level window.
  -- Closing the settings by Escape/another scene can never leave text behind.
  -- A separate TOP LEVEL popover is necessary here: as a child control it
  -- was visually visible but lay below sibling settings rows, blocking clicks.
  -- Config.OnHide always closes this popover, including Escape/scene switches.
  local pane=WM:CreateTopLevelWindow('RamaladniSearchResultsV104')
  pane:SetDimensions(574,225)
  pane:SetDrawTier(DT_HIGH)
  pane:SetDrawLayer(DL_OVERLAY)
  pane:SetDrawLevel(100)
  pane:SetClampedToScreen(true)
  pane:SetMouseEnabled(true)
  pane:SetHidden(true)
  local bg=Background(nil,pane)
  bg:SetCenterColor(.035,.045,.064,.99)
  bg:SetEdgeColor(.60,.46,.25,.96)
  local popup={window=pane,kind=nil,rows={}}
  R.ui.searchPopup=popup
  for i=1,6 do
    local rowIndex=i
    local button=Button('RamaladniResultV104_'..i,pane,'',40,4+(i-1)*35,526,31,function()
      local result=popup.rows[rowIndex].item
      if result then SelectSearchResult(popup.kind,result) end
    end)
    button.ramaladniCaption:SetFont('$(MEDIUM_FONT)|15|soft-shadow-thin')
    local tex=WM:CreateControl(nil,pane,CT_TEXTURE)
    tex:SetAnchor(TOPLEFT,pane,TOPLEFT,9,6+(i-1)*35)
    tex:SetDimensions(27,27)
    tex:SetMouseEnabled(false)
    button:SetHidden(true)
    tex:SetHidden(true)
    popup.rows[i]={button=button,icon=tex}
  end
end
local function RefreshList()
  if not R.ui.rows then return end
  for i,row in ipairs(R.ui.rows) do
    local e=R.sv.entries[i]
    if e then
      local cd=(e.cooldown and e.cooldown>0) and string.format(' | откат %.1f c',e.cooldown) or ''
      local kindLabel=e.kind=='buff' and '+' or (e.kind=='debuff' and '-' or '*')
      row.text:SetText(kindLabel..'  '..DisplayName(e)..cd)
      row.icon:SetTexture(e.kind=='mastery' and
        (e.iconId and TextureFor(e.iconId,e.kind) or e.iconPath or TextureFor(e.abilityId,e.kind))
        or TextureFor(e.autoIconId or e.abilityId,e.kind))
      row.icon:SetHidden(false)
      row.delete:SetHidden(false);row.delete.uid=e.uid
    else row.text:SetText('');row.icon:SetHidden(true);row.delete:SetHidden(true);row.delete.uid=nil end
  end
  R.ui.count:SetText(string.format('Индикаторов: %d / %d',#R.sv.entries,MAX))
end
local DeleteEffect
-- A selection, not an individual ability ID, is the unit of configuration.
AddEffect=function(kind)
  if #R.sv.entries>=MAX then Say('Максимум '..MAX..' индикаторов');return false end
  local sel=R.selected[kind]
  local id=sel and ValidId(sel.id)
  if not id then Say('Найди и выбери эффект.');return false end
  local group=sel.groupKey or GROUPS.Find(kind,id)
  for _,e in ipairs(R.sv.entries) do
    if e.kind==kind and ((group and ResolvedGroup(e)==group) or e.abilityId==id) then
      Say('Этот эффект уже добавлен.');return false
    end
  end
  local slot=#R.sv.entries
  local entry={uid=R.sv.nextId,kind=kind,abilityId=id,name=sel.name,
    groupKey=group,effectIds=CopyIds(sel.effectIds,id),autoIconId=sel.autoIconId,
    cooldown=0,x=260+(slot%7)*83,y=220+math.floor(slot/7)*73}
  R.sv.nextId=R.sv.nextId+1
  R.sv.entries[#R.sv.entries+1]=entry
  RebuildTrackingIndex();MakeWidget(entry);RefreshList();Tick()
  Say((kind=='buff' and 'Бафф: ' or 'Дебафф: ')..DisplayName(entry)..' добавлен; перетащи иконку ЛКМ.')
  return true
end
DeleteEffect=function(uid)
  for i,e in ipairs(R.sv.entries) do
    if e.uid==uid then
      -- Clear only the selected effect that is actually being deleted.
      -- Deleting a different indicator must not erase the current search UI.
      local sel=R.selected[e.kind]
      local selectedGroup=sel and sel.groupKey
      local isSelected=sel and (sel.id==e.abilityId or
        (selectedGroup and selectedGroup==ResolvedGroup(e)))
      RemoveWidget(e)
      table.remove(R.sv.entries,i)
      RebuildTrackingIndex()
      if isSelected then ClearSearchSelection(e.kind) end
      RefreshList()
      Say('Индикатор удалён')
      return
    end
  end
end
local function DeleteAllEffects()
  if not R.sv then return end
  local count=#R.sv.entries
  for _,entry in ipairs(R.sv.entries) do RemoveWidget(entry) end
  -- No new SavedVariables schema: clearing this list persists after /reloadui.
  R.sv.entries={}
  RebuildTrackingIndex()
  ClearSearchSelection('buff')
  ClearSearchSelection('debuff')
  RefreshList()
  Say('Удалено индикаторов: '..count..'. Экран и сохранённый список очищены.')
end
local function Test()
  if #R.sv.entries==0 then Say('Сначала добавь эффект.');return end
  for _,e in ipairs(R.sv.entries) do
    local s=R.states[e.uid]
    if s then
      s.testUntil=Now()+5
      s.testCD=Now()+12
    end
  end
  UpdateWidgets()
  Say('Тест: 5 сек. зелёным, затем 7 сек. красным (только тест интерфейса).')
end
local function BuildLine(win,kind,y)
  local human=kind=='buff' and 'БАФФ / BUFF' or 'ДЕБАФФ / DEBUFF'
  Label(win,human,17,y+5,122,28,'ZoFontGameBold')
  local search=Edit('RamaladniSearchV104_'..kind,win,139,y,553,'')
  search:SetMaxInputChars(96)
  local preview=WM:CreateControl(nil,win,CT_TEXTURE)
  preview:SetAnchor(TOPLEFT,win,TOPLEFT,704,y-3)
  preview:SetDimensions(38,38)
  preview:SetTexture(FALLBACK[kind])
  preview:SetMouseEnabled(false)
  preview:SetHidden(true)
  local selected=Label(win,'Эффект не выбран',139,y+37,558,23,'ZoFontGameSmall')
  local status=Label(win,'Выбери результат поиска — он добавится автоматически.',139,y+64,608,21,'ZoFontGameSmall')
  -- White placeholder is a NON-INTERACTIVE label over the empty search box.
  -- It is never inserted into the actual search text, and cannot capture input.
  local hint=WM:CreateControl(nil,search:GetParent(),CT_LABEL)
  hint:SetAnchor(TOPLEFT,search,TOPLEFT,2,2)
  hint:SetDimensions(480,23)
  hint:SetFont('ZoFontGame')
  hint:SetText('Введите')
  hint:SetColor(1,1,1,1)
  hint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  hint:SetMouseEnabled(false)
  local ui={search=search,preview=preview,selected=selected,status=status,searchY=y,hint=hint}
  R.ui.lines[kind]=ui
  local function RefreshHint()
    hint:SetHidden(search:GetText()~='' or search:HasFocus())
  end
  search:SetHandler('OnTextChanged',function() RefreshHint();ShowResults(kind) end)
  search:SetHandler('OnFocusGained',function() RefreshHint();ShowResults(kind) end)
  search:SetHandler('OnFocusLost',RefreshHint)
  RefreshHint()
  Refill(kind)
end

-- Third row: Class Mastery, with independent class / passive / icon dropdowns.
local function MasteryClassSelected(item)
  R.selected.mastery.class=item.id
  R.selected.mastery.key=nil
  R.selected.mastery.iconId=0
  local opts=MASTERY.byClass[item.id] or {}
  if opts[1] then R.selected.mastery.key=opts[1].key end
  local ui=R.ui.mastery
  ui.passiveCombo:ClearItems()
  for _,meta in ipairs(opts) do
    local m=meta
    ui.passiveCombo:AddItem(ui.passiveCombo:CreateItemEntry(meta.title,function()
      R.selected.mastery.key=m.key
    end))
  end
  if opts[1] then
    ui.passiveCombo:SetSelectedItemText(opts[1].title)
  end
end
local function AddMastery()
  if #R.sv.entries>=MAX then Say('Максимум '..MAX..' индикаторов');return end
  local sel=R.selected.mastery
  local meta=sel and MASTERY.byKey[sel.key]
  if not meta then Say('Выбери класс и мастерство.');return end
  for _,e in ipairs(R.sv.entries) do
    if e.kind=='mastery' and e.masteryKey==meta.key then Say('Эта пассивка уже добавлена');return end
  end
  local slot=#R.sv.entries
  local entry={uid=R.sv.nextId,kind='mastery',masteryKey=meta.key,
    abilityId=meta.passiveId,name=meta.title,
    iconId=ValidId(sel.iconId),cooldown=0,
    x=260+(slot%7)*83,y=220+math.floor(slot/7)*73}
  R.sv.nextId=R.sv.nextId+1
  R.sv.entries[#R.sv.entries+1]=entry
  RebuildTrackingIndex();MakeWidget(entry);RefreshList();Tick()
  Say('Мастерство: '..meta.en..'. Процент/стаки только из ESO. ID пассивки может отличаться от ID эффекта.')
end
local function BuildMasteryLine(win)
  R.selected.mastery={class='Necromancer',key='Necromancer:Nothing Wasted',iconId=0}
  local ui={}
  R.ui.mastery=ui
  Label(win,'МАСТЕРСТВО КЛАССА / CLASS MASTERY',20,362,520,25,'ZoFontGameBold')
  ui.classCombo=Combo('RamaladniMasteryClassV09',win,20,389,195)
  ui.passiveCombo=Combo('RamaladniMasteryPassiveV09',win,220,389,290)
  ui.iconCombo=Combo('RamaladniMasteryIconV09',win,516,389,183)
  ui.classCombo:ClearItems()
  ui.iconCombo:ClearItems()
  for _,cl in ipairs(MASTERY.classes) do
    local c=cl
    ui.classCombo:AddItem(ui.classCombo:CreateItemEntry(c.name,function() MasteryClassSelected(c) end))
  end
  for _,ic in ipairs(ICON_CHOICES) do
    local option=ic
    ui.iconCombo:AddItem(ui.iconCombo:CreateItemEntry(option.name,function()
      R.selected.mastery.iconId=option.iconId
    end))
  end
  ui.iconCombo:SetSelectedItemText('Авто: иконка пассивки')
  ui.classCombo:SetSelectedItemText('Некромант / Necromancer')
  MasteryClassSelected({id='Necromancer'})
  -- Mastery selection still supports automatic/manual icons internally.
  -- The redundant ability preview is removed from this row.
  Label(win,'%/стаки — ESO; ~12с — оценка Бережливости, если ESO не сообщает время.',20,429,505,39,'ZoFontGameSmall')
  Button('RamaladniAddMasteryV09',win,'Добавить мастерство',537,428,205,29,AddMastery)
end

-- v0.9.24: presentation-only layout, identical handlers and SavedVariables.
local function Config()
  local win=WM:CreateTopLevelWindow('RamaladniConfigV3')
  win:SetDimensions(775,936)
  win:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,R.sv.window.x,R.sv.window.y)
  win:SetClampedToScreen(true)
  win:SetMouseEnabled(true)
  win:SetMovable(true)
  win:SetDrawLayer(DL_OVERLAY)
  win:SetHidden(true)
  local backdrop=Background(nil,win)
  backdrop:SetCenterColor(.017,.021,.033,.93)
  backdrop:SetEdgeColor(.35,.29,.17,.38)
  local frame=WM:CreateControl(nil,win,CT_TEXTURE)
  frame:SetAnchorFill(win)
  frame:SetTexture(ADDON..'/textures/panel_frame.dds')
  frame:SetMouseEnabled(false)
  R.ui.window=win;R.ui.lines={}
  win:SetHandler('OnHide',function()
    -- Also covers closing settings via Escape / scene changes, not only X.
    HideResults()
    for _,line in pairs(R.ui.lines or {}) do
      if line.search and line.search.LoseFocus then line.search:LoseFocus() end
    end
  end)
  SCENE_MANAGER:RegisterTopLevel(win,false)

  local copyright=Label(win,'Copyright © 2026 Northknightwest (Ramaladni).',110,14,555,26,'$(MEDIUM_FONT)|16|soft-shadow-thin')
  copyright:SetColor(.83,.77,.59,1)
  copyright:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  local heading=Label(win,'RAMALADNI BUFF & DEBUFF TRACKER v1.0.0',80,48,615,36,'$(BOLD_FONT)|25|soft-shadow-thick')
  heading:SetColor(1,1,1,1)
  heading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  Button('RamaladniCloseV3',win,'X',723,15,30,30,function()
    HideResults()
    SCENE_MANAGER:HideTopLevel(win)
  end)

  Label(win,'Поиск эффекта / Effect search                             Иконка / Icon',139,98,555,23,'ZoFontGameSmall')
  BuildLine(win,'buff',120)
  BuildLine(win,'debuff',240)
  BuildMasteryLine(win)
  Label(win,'Зелёный = длительность ESO; красный = откат или особый игровой эффект.',22,473,728,22,'ZoFontGameSmall')
  Label(win,'Названия и иконки — для игрока; служебные идентификаторы скрыты.',22,493,728,22,'ZoFontGameSmall')
  Button('RamaladniTestV3',win,'Тест: зелёный → красный',20,520,245,33,Test)
  Button('RamaladniRefreshV3',win,'Обновить поиск',278,520,210,33,function()
    Refill('buff');Refill('debuff');HideResults();Say('Поисковая база обновлена.')
  end)
  Button('RamaladniDeleteAllV4',win,'Удалить всё',503,520,239,33,DeleteAllEffects)
  Label(win,'Добавленные индикаторы (ЛКМ — перемещение):',22,570,580,26,'ZoFontGameBold')
  R.ui.count=Label(win,'',22,594,500,20,'ZoFontGameSmall')
  R.ui.rows={}
  for i=1,MAX do
    local y=615+(i-1)*20
    local icon=WM:CreateControl(nil,win,CT_TEXTURE)
    icon:SetAnchor(TOPLEFT,win,TOPLEFT,28,y)
    icon:SetDimensions(18,18)
    icon:SetHidden(true)
    icon:SetMouseEnabled(false)
    local label=Label(win,'',58,y,625,20,'ZoFontGameSmall')
    local del=Button('RamaladniRemoveV3_'..i,win,'X',693,y-2,54,23,function(button)
      if button.uid then DeleteEffect(button.uid) end
    end)
    del:SetHidden(true)
    R.ui.rows[i]={text=label,icon=icon,delete=del}
  end

  -- Footer: branding and outgoing links use ESO's opt-in browser confirmation.
  local function OpenExternal(url)
    if type(RequestOpenUnsafeURL)=='function' then
      RequestOpenUnsafeURL(url)
    else
      Say(url)
    end
  end
  -- Three-zone footer: effect base LEFT, clickable MD emblem CENTER,
  -- Discord RIGHT. No external URL text is rendered in the interface.
  local effectBaseURL='https://md-eso.ru/topic/8229-%D0%B1%D0%B0%D1%84%D1%84%D1%8B-%D0%B4%D0%B5%D0%B1%D0%B0%D1%84%D1%84%D1%8B-%D0%B8-%D1%81%D1%82%D0%B0%D1%82%D1%83%D1%81-%D1%8D%D1%84%D1%84%D0%B5%D0%BA%D1%82%D1%8B/'
  Button('RamaladniBuffDebuffBaseLinkV104c',win,'Buff/Debuff Base',26,878,199,35,function()
    OpenExternal(effectBaseURL)
  end)

  local mdLogo=WM:CreateControl(nil,win,CT_TEXTURE)
  mdLogo:SetAnchor(TOP,win,TOP,0,850)
  mdLogo:SetDimensions(72,63)
  mdLogo:SetTexture(ADDON..'/textures/md_logo.dds')
  mdLogo:SetMouseEnabled(true)
  mdLogo:SetHandler('OnMouseUp',function(_,button)
    if button==MOUSE_BUTTON_INDEX_LEFT then OpenExternal('https://md-eso.ru/') end
  end)

  local discordIcon=WM:CreateControl(nil,win,CT_TEXTURE)
  discordIcon:SetAnchor(TOPLEFT,win,TOPLEFT,555,882)
  discordIcon:SetDimensions(27,27)
  discordIcon:SetTexture(ADDON..'/textures/discord_icon.dds')
  discordIcon:SetMouseEnabled(false)
  Button('RamaladniDiscordLinkV024',win,'Discord',589,878,164,35,function()
    OpenExternal('https://discord.gg/azr8QDYhyJ')
  end)

  local handle=WM:CreateControl(nil,win,CT_CONTROL)
  handle:SetDimensions(690,39)
  handle:SetAnchor(TOPLEFT,win,TOPLEFT,12,4)
  handle:SetMouseEnabled(true)
  handle:SetHandler('OnMouseDown',function(self,button)
    if button==MOUSE_BUTTON_INDEX_LEFT then self:GetParent():StartMoving() end
  end)
  handle:SetHandler('OnMouseUp',function(self,button)
    if button==MOUSE_BUTTON_INDEX_LEFT then
      local parent=self:GetParent()
      parent:StopMovingOrResizing()
      R.sv.window.x=math.floor(parent:GetLeft()+.5)
      R.sv.window.y=math.floor(parent:GetTop()+.5)
      HideResults()
    end
  end)
  RefreshList()
  -- Dedicated search-result surface, separate from the static settings panel.
  CreateSearchPopup()
end
local function ToggleConfig()
  local win=R.ui.window
  if not win then return end
  if win:IsHidden() then
    Refill('buff');Refill('debuff');RefreshList()
    SCENE_MANAGER:ShowTopLevel(win)
  else
    HideResults()
    SCENE_MANAGER:HideTopLevel(win)
  end
end
-- Public handlers called by Bindings.xml.  These affect presentation only.
-- The existing event pipeline, cooldowns, timers and SavedVariables are unchanged.
RamaladniKeybinds = RamaladniKeybinds or {}
function RamaladniKeybinds.ToggleSettings()
  if not R.ui.window then return end
  ToggleConfig()
end
function RamaladniKeybinds.ToggleHud()
  if not R.sv then return end
  R.hudVisible=not R.hudVisible
  for _,widget in pairs(R.widgets) do
    widget.win:SetHidden(not (R.hudVisible and R.hudSceneVisible))
  end
end

local function Inspect(kind)
  local tag=kind=='buff' and 'player' or 'reticleover'
  if kind=='debuff' and not DoesUnitExist(tag) then Say('Нет цели под прицелом.');return end
  local n=GetNumBuffs(tag) or 0
  Say('Скан '..tag..': '..n..' эффектов; печатаем первые 30')
  for i=1,math.min(n,30) do
    local name,start,finish,_,_,icon,_,_,_,_,id=GetUnitBuffInfo(tag,i)
    Say(string.format('%s осталось=%.1f',tostring(name),math.max(0,(finish or 0)-Now())))
  end
end
local function InspectOffBalance()
  local tag='reticleover'
  if not DoesUnitExist(tag) then Say('Нет цели под прицелом.');return end
  local n=GetNumBuffs(tag) or 0
  local found=0
  for i=1,n do
    local name,start,finish,_,_,_,_,effectType,_,_,id=GetUnitBuffInfo(tag,i)
    local normalized=NormalizeTitle(name)
    local localized=NormalizeTitle(GetAbilityName(45902))
    if OFF_BALANCE_SET[id] or normalized=='off balance' or
       normalized=='off-balance' or normalized=='потеря равновесия' or
       (localized~='' and localized==normalized) then
      found=found+1
      local remaining=type(finish)=='number' and (finish-Now()) or -1
      Say(string.format('OFF BALANCE: name=%s type=%s start=%s end=%s left=%.1fs',
        tostring(name),tostring(effectType),tostring(start),
        tostring(finish),remaining))
    end
  end
  if found==0 then Say('На текущей цели Off Balance не обнаружен в GetUnitBuffInfo.') end
end
local function NormalizeEntries()
  local valid={}
  local usedUid={}
  local maxId=0
  for _,e in ipairs(R.sv.entries) do
    if type(e)=='table' and
       (e.kind=='buff' or e.kind=='debuff' or (e.kind=='mastery' and MASTERY.byKey[e.masteryKey])) and
       ValidId(e.abilityId) and #valid<MAX then
      -- One-time compatibility fix for the old default preset. Keep the
      -- existing entry UID/icon/position intact; confirmed builtins lose manual cooldown.
      if e.kind=='debuff' and e.abilityId==62988 and IsOffBalanceEntry(e) then
        e.abilityId=45902
      end
      local uid=ValidId(e.uid)
      if not uid or usedUid[uid] then uid=maxId+1 end
      while usedUid[uid] do uid=uid+1 end
      e.uid=uid
      usedUid[uid]=true
      e.abilityId=ValidId(e.abilityId)
      if type(e.name)~='string' then e.name=GetAbilityName(e.abilityId) or 'Неизвестный эффект' end
      if e.kind~='mastery' then
        e.iconId=nil;e.iconPath=nil -- icons are automatic for regular effects
        e.name=e.name:gsub('%s*%[U52 ID %d+%]',''):gsub('%s*%[ID %d+%]','')
        if e.name:match('^ID%s+%d+$') then
          local localized=GetAbilityName(e.abilityId)
          e.name=(type(localized)=='string' and localized~='') and localized or 'Неизвестный эффект'
        end
      end
      e.cooldown=tonumber(e.cooldown) or 0
      e.cooldown=math.max(0,math.min(e.cooldown,3600))
      if e.kind~='mastery' and IsKnownU52Effect(e.kind,e.abilityId) then
        -- U52 builtin: do not use a manually guessed cooldown. A special
        -- game-driven timer (Off Balance immunity) is handled separately.
        e.cooldown=0
      end
      e.x=tonumber(e.x) or 340
      e.y=tonumber(e.y) or 310
      maxId=math.max(maxId,e.uid)
      valid[#valid+1]=e
    end
  end
  R.sv.entries=valid
  R.sv.nextId=math.max(maxId+1,tonumber(R.sv.nextId) or 1)
end
-- Names shown in ESO Settings > Controls.  ESO adds the SI_BINDING_NAME_ prefix.
if type(ZO_CreateStringId)=='function' then
  local lang=(type(GetCVar)=='function' and GetCVar('language.2')) or 'en'
  local russian=(type(lang)=='string' and lang:lower():sub(1,2)=='ru')
  ZO_CreateStringId('SI_BINDING_NAME_RAMALADNI_TOGGLE_SETTINGS',
    russian and 'Ramaladni: открыть / закрыть настройки' or 'Ramaladni: Toggle settings')
  ZO_CreateStringId('SI_BINDING_NAME_RAMALADNI_TOGGLE_HUD',
    russian and 'Ramaladni: показать / скрыть индикаторы' or 'Ramaladni: Show / hide HUD')
end

local function OnLoaded(_,name)
  if name~=ADDON then return end
  EM:UnregisterForEvent(ADDON..'Load',EVENT_ADD_ON_LOADED)
  R.sv=MASTERY.SelectCharacterProfile(ZO_SavedVars:NewAccountWide('RamaladniTrackerSaved',1,nil,DEFAULTS),DEFAULTS)
  if type(R.sv.entries)~='table' then R.sv.entries={} end
  if type(R.sv.window)~='table' then R.sv.window={x=240,y=120} end
  NormalizeEntries()
  if type(R.sv.learned)~='table' then R.sv.learned={buff={},debuff={}} end
  if type(R.sv.learned.buff)~='table' then R.sv.learned.buff={} end
  if type(R.sv.learned.debuff)~='table' then R.sv.learned.debuff={} end
  for _,kind in ipairs({'buff','debuff'}) do
    for id,info in pairs(R.sv.learned[kind]) do
      if ValidId(id) and type(info)=='table' then
        R.learnedCount[kind]=R.learnedCount[kind]+1
      else
        -- Bad SavedVariables data must not crash the settings combo boxes.
        R.sv.learned[kind][id]=nil
      end
    end
  end
  RebuildTrackingIndex()
  R.selected={buff={},debuff={}}
  SLASH_COMMANDS['/ramaladni']=function(argument)
    if not R.ui.window then Say('Настройки доступны после входа в мир.');return end
    local arg=(argument or ''):lower():match('^%s*(.-)%s*$')
    if arg=='' then ToggleConfig()
    elseif arg=='debug' then R.debug=not R.debug;R.debugWindow=Now();R.debugPrinted=0;R.debugSuppressed=0;Say('Режим диагностики: '..(R.debug and 'ON' or 'OFF'))
    elseif arg=='inspect' then Inspect('debuff')
    elseif arg=='inspect self' then Inspect('buff')
    elseif arg=='offbalance' then InspectOffBalance()
    elseif arg=='test' then Test()
    else Say('Команды: /ramaladni, debug, inspect, inspect self, offbalance, test.') end
  end
  EM:RegisterForEvent(ADDON..'Ready',EVENT_PLAYER_ACTIVATED,function()
    EM:UnregisterForEvent(ADDON..'Ready',EVENT_PLAYER_ACTIVATED)
    RegisterHudSceneCallbacks()
    for _,e in ipairs(R.sv.entries) do MakeWidget(e) end
    Config()
    EM:RegisterForEvent(ADDON..'Effects',EVENT_EFFECT_CHANGED,OnEffectChanged)
    EM:RegisterForEvent(ADDON..'Target',EVENT_RETICLE_TARGET_CHANGED,OnTargetChange)
    EM:RegisterForEvent(ADDON..'Full',EVENT_EFFECTS_FULL_UPDATE,Tick)
    EM:RegisterForEvent(ADDON..'Combat',EVENT_PLAYER_COMBAT_STATE,OnCombatStateChanged)
    R.combat=(IsUnitInCombat and IsUnitInCombat('player')) or false
    EM:RegisterForUpdate(ADDON..'Tick',200,Tick)
    Tick()
    Say('Ramaladni Buff & Debuff Tracker v1.0.0 — STABLE')
  end)
end
EM:RegisterForEvent(ADDON..'Load',EVENT_ADD_ON_LOADED,OnLoaded)

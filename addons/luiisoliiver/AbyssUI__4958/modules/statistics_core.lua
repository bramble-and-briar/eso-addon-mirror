-- NAGA / AbyssUI Bandits-style Damage Statistics compatibility core
-- Isolated namespace: never conflicts with the Bandits BUI globals.
local ADDON_NAME = "AbyssUI"
NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
NAGA_UI.BUI = NAGA_UI.BUI or {}
local NAGA_BUI = NAGA_UI.BUI
_G.NAGA_BUI = NAGA_BUI

NAGA_BUI.name = ADDON_NAME
NAGA_BUI.DisplayName = "AbyssUI"
NAGA_BUI.Version = "1.0"
NAGA_BUI.API = GetAPIVersion and GetAPIVersion() or 0
NAGA_BUI.ESOVersion = tostring(NAGA_BUI.API)
NAGA_BUI.language = "br"
NAGA_BUI.inMenu = false
NAGA_BUI.inCombat = false
NAGA_BUI.InGroup = false
NAGA_BUI.init = NAGA_BUI.init or {}
NAGA_BUI.Defaults = NAGA_BUI.Defaults or {}
NAGA_BUI.Vars = NAGA_BUI.Vars or {}
NAGA_BUI.Stats = NAGA_BUI.Stats or {}
NAGA_BUI.Damage = NAGA_BUI.Damage or {}
NAGA_BUI.Group = NAGA_BUI.Group or {members=0}
NAGA_BUI.GroupMembers = NAGA_BUI.GroupMembers or {}
NAGA_BUI.Enemy = NAGA_BUI.Enemy or {}
NAGA_BUI.Attacker = NAGA_BUI.Attacker or {}
NAGA_BUI.Log = NAGA_BUI.Log or {}
NAGA_BUI.Penetration = NAGA_BUI.Penetration or {Self={},Target={}}
NAGA_BUI.PassiveBuffs = NAGA_BUI.PassiveBuffs or {}
NAGA_BUI.Actions = NAGA_BUI.Actions or {AbilitySlots={},AbilityBar={}}
NAGA_BUI.Cloudrest = NAGA_BUI.Cloudrest or {Plus=0,Group=0}
NAGA_BUI.BossFight = false
NAGA_BUI.BossKilledMs = 0
NAGA_BUI.BossName = ""
NAGA_BUI.GroupDPS_text = ""
NAGA_BUI.GroupDPS_tip = ""

local defaults = {
    EnableStats=true,
    NAGA_Statistics_MiniMeter={TOPRIGHT,TOP,-400,0},
    NAGA_Statistics_GroupDPS={TOPLEFT,TOP,-400,120},
    NAGA_Statistics_Targets={TOPRIGHT,TOPRIGHT,-260,0},
    NAGA_Statistics_BuffsUp={TOPLEFT,TOPLEFT,260,0},
    ReportScale=1,
    StatTriggerHeals=false,
    StatsShareDPS=true,
    StatsUpdateDPS=false,
    StatsGroupDPS=false,
    StatsGroupDPSframe=false,
    StatsMiniMeter=true,
    ReticleDpS=false,
    MiniMeterAplha=.8,
    StatsMiniHealing=false,
    StatsMiniGroupDps=true,
    StatsMiniSpeed=false,
    StatsFontSize=18,
    StatsTransparent=true,
    StatsSplitElements=true,
    StatsBuffs=false,
    StatsBuffsSource=false,
    StatsLog=false,
    RaidFrames=false,
    PlayerBuffs=false,
    ActionsPrecise=false,
    FramesTexture="grainy",
    FrameHealthColor={150/255,30/255,60/255,1},
    FrameHealthColor1={255/255,40/255,70/255,1},
    CustomEdgeColor={.7,.7,.5,1},
    AdvancedThemeColor={1,1,1,1},
    Theme=0,
    RaidFontSize=17,
    AttackersWidth=280,
    AttackersHeight=28,
    NAGA_Statistics_Attackers={TOPLEFT,TOP,355,5},
    OnScreen={Message={}},
    FrameFont1="esobold",
    FrameFont2="esobold",
    DeveloperMode=false,
    Attackers=false,
    Log=false,
}
for k,v in pairs(defaults) do if NAGA_BUI.Defaults[k] == nil then NAGA_BUI.Defaults[k]=v end end
for k,v in pairs(defaults) do if NAGA_BUI.Vars[k] == nil then NAGA_BUI.Vars[k]=v end end

function NAGA_BUI:JoinTables(dest, src)
    for k,v in pairs(src or {}) do
        if type(v)=="table" then
            if type(dest[k])~="table" then dest[k]={} end
            self:JoinTables(dest[k],v)
        elseif dest[k]==nil then dest[k]=v end
    end
    return dest
end

-- Brazilian strings used by the Bandits report UI.
local L={
    MiniMeterDPSToolTip='|t16:16:'..(NAGA_UI:GetAssetPath("ui/statistics/lmb.dds"))..'|t Exibir Relatório de Danos\n|t16:16:'..NAGA_UI:GetAssetPath("ui/statistics/rmb.dds")..'|t Postar Resultados de Danos\n|t16:16:'..NAGA_UI:GetAssetPath("ui/statistics/mmb.dds")..'|t Reiniciar luta atual',
    MiniMeterHPSToolTip='Mostrar Ajudante do Curandeiro',
    MiniMeterGDPSToolTip1='Exibir Relatório de Grupo', MiniMeterGDPSToolTip2='Postar DPS do grupo',
    DReport='Relatório de Danos', HReport='Relatório de Cura', PReport='Ganho de Recursos', IReport='Dano Recebido',
    NoDamage='Nenhum dado para relatar!', NoDamageToReport='Nenhum dano ou cura para relatar!', AllTargets='Todos os Alvos',
    Ability='Habilidade', Crit='Crit', Average='Med', Max='Max', Hit='Crit/Hit', Damage='Dano', Healing='Curando', Power='Recurso', DPS='DPS', HPS='CPS',
    NoDPSToReport='Nenhum DPS do grupo para relatar!', ReportDesc='Postar DPS no chat\nExpandir buffs do alvo\nExpandir o dano do alvo\n v = lançado pelo jogador',
    ReportEinfo='Informação do equipamento', ReportPBHeader='Tempo dos Buffs do Jogador', ReportTBHeader='Tempo dos Buffs do Alvo', ReportBuffHeader='Buff', ReportTimeHeader='Tempo ', ReportTargetName='Nome do Alvo', ReportTotalDamage='Dano Total', ReportCount='Contador', ReportTotal='Total', Boss='Chefe',
    GroupDPS='DPS do Grupo', STATISTICS_Incoming='Recebido', STATISTICS_Group='Grupo', STATISTICS_GroupMember='Membro do grupo', STATISTICS_Item='Item', STATISTICS_Trait='Traço', STATISTICS_Enchant='Encantamento', STATISTICS_Recovery='Recuperação', STATISTICS_PEN_AVG_MAX='Penetração média/máx.', STATISTICS_Fire='Fogo', STATISTICS_Shock='Choque', STATISTICS_Cold='Gelo', STATISTICS_Magic='Mágico', STATISTICS_Physical='Físico', STATISTICS_Poison='Veneno', STATISTICS_Disease='Doença', STATISTICS_Bleed='Sangramento', STATISTICS_Direct_Dmg='Dano direto', STATISTICS_Weapon_Attack='Ataque/Habilidade de arma', STATISTICS_Rotation_Speed='Velocidade de rotação', STATISTICS_Weapon='Arma', STATISTICS_Spell='Feitiço', STATISTICS_Uptimes='Uptimes', STATISTICS_Uptimes_For='Uptimes de', STATISTICS_Swap='Troca', STATISTICS_Up='Ativo', STATISTICS_Death='Morte', STATISTICS_Report='Relatório', STATISTICS_Report_Deleted='foi excluído', STATISTICS_Report_Saved='foi salvo', STATISTICS_Group_DMG_Results='Resultados de dano do grupo', STATISTICS_In='em', STATISTICS_TotalDamage='Dano Total', STATISTICS_Over='por', STATISTICS_Every='a cada', STATISTICS_Boss='Chefe',
    StatMiniHeader='Minimedidor', StatsMiniMeter='Mostrar Minimedidor', MiniMeterAplha='Transparência do Minimedidor', StatsMiniHealing='Mostrar cura no Minimedidor', StatsMiniGroupDps='Mostrar DPS do grupo no Minimedidor', StatsMiniSpeed='Mostrar velocidade no Minimedidor',
    StatsUpdateDPS='Compartilhar DPS com o grupo', StatsGroupDPS='Mostrar DPS nos quadros do grupo', StatsGroupDPSframe='Mostrar quadro de DPS do grupo', StatsSplitElements='Separar dano por elemento', StatsBuffs='Mostrar buffs no relatório', Log='Registro de combate', StatsReset='Redefinir estatísticas',
    STATISTICS_Report_Saved='foi salvo', STATISTICS_Report_Deleted='foi excluído', STATISTICS_TotalDamage='Dano Total',
}
function NAGA_BUI.Loc(key) return L[key] or key end
function NAGA_BUI.Alert(text,sound) if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT,sound,text) else d(text) end end
function NAGA_BUI.FormatTime(sec) sec=tonumber(sec) or 0 return ZO_FormatTime and ZO_FormatTime(sec,SI_TIME_FORMAT_TIMESTAMP) or string.format("%.1fs",sec) end
function NAGA_BUI.GetAbilityDuration(id) return GetAbilityDuration and GetAbilityDuration(id) or 0 end
function NAGA_BUI.GetAbilityTickTime(id) return 0 end
function NAGA_BUI.GetFoodBuff() return nil end
function NAGA_BUI.GetBlockCost() return 0,0 end
function NAGA_BUI.GetCritDamage() return 0,0 end
function NAGA_BUI.PingMap(...) if PingMap then return PingMap(...) end end
function NAGA_BUI.Helper_Toggle() end

local player={}
NAGA_BUI.Player=player
function player:GetColoredLevel() return tostring(GetUnitLevel("player") or 0) end
local function RefreshPlayer()
    player.name=GetUnitName("player") or ""
    player.accname=GetDisplayName() or player.name
    do local _, max = GetUnitPower("player", POWERTYPE_HEALTH); player.health={max=max or 0} end
    do local _, max = GetUnitPower("player", POWERTYPE_STAMINA); player.stamina={max=max or 0} end
    do local _, max = GetUnitPower("player", POWERTYPE_MAGICKA); player.magicka={max=max or 0} end
end
RefreshPlayer()

function NAGA_BUI.DisplayNumber(number,places)
    number=tonumber(number) or 0; places=places or 0
    if number<1000 then return string.format("%."..places.."f",number):gsub("%.",",") end
    return FormatIntegerWithDigitGrouping(number,".")
end
function NAGA_BUI.ColorString(r,g,b,a)
    a=a or 1; local out=""
    for _,v in ipairs({r,g,b}) do local n=math.floor(math.min(v,1)*255*a); out=out..string.format("%02X",n) end
    return out
end
function NAGA_BUI.TimeStamp(now) return tostring(now or GetGameTimeMilliseconds()) end
function NAGA_BUI.CallLater(name,ms,func,...) if zo_callLater then return zo_callLater(func,ms,...) end return func(...) end

NAGA_BUI.Menu=NAGA_BUI.Menu or {}
function NAGA_BUI.Menu:SaveAnchor(_) end
function NAGA_BUI.Menu:Reset(section) if section=="Stats" and NAGA_BUI.Stats then NAGA_BUI.Stats.Reset() end end

NAGA_BUI.Textures={
    grainy=NAGA_UI:GetAssetPath("ui/statistics/meter.dds"),
    rounded=NAGA_UI:GetAssetPath("ui/statistics/meter.dds"),
}
if NAGA_UI.MigrateLegacySV then NAGA_UI.MigrateLegacySV() end
NAGA_BUI.Reports=ZO_SavedVars:NewAccountWide("NAGA_StatisticsReports",1,nil,{data={}})

local function RefreshGroup()
    NAGA_BUI.GroupMembers={}
    NAGA_BUI.Group={members=0}
    local size=GetGroupSize and GetGroupSize() or 0
    NAGA_BUI.InGroup=size>0
    NAGA_BUI.Group.members=size
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            local name=GetUnitName(tag) or ""
            local acc=GetUnitDisplayName(tag) or name
            NAGA_BUI.GroupMembers[GetUnitUniqueId and GetUnitUniqueId(tag) or tag]=name
            NAGA_BUI.Group[tag]={name=name,accname=acc,role=GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag) or nil}
            NAGA_BUI.Group[acc]={name=name,accname=acc,role=NAGA_BUI.Group[tag].role}
        end
    end
end
RefreshGroup()

local function OnCombatState(_,inCombat)
    NAGA_BUI.inCombat=inCombat==true
end
local function CombatEvent(eventCode,result,isError,abilityName,abilityGraphic,abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,damageType2,sourceUnitId,targetUnitId,abilityId)
    if not NAGA_BUI.init.Stats then return end
    if isError or not abilityId or not hitValue or hitValue<5 or hitValue>200000 or targetUnitId==nil or targetType==COMBAT_UNIT_TYPE_PLAYER_PET then return end
    local damageResults={
        [ACTION_RESULT_DAMAGE]=true,[ACTION_RESULT_DOT_TICK]=true,[ACTION_RESULT_BLOCKED_DAMAGE]=true,[ACTION_RESULT_DAMAGE_SHIELDED]=true,[ACTION_RESULT_CRITICAL_DAMAGE]=true,[ACTION_RESULT_DOT_TICK_CRITICAL]=true,
    }
    local healResults={ [ACTION_RESULT_HOT_TICK]=true,[ACTION_RESULT_HEAL]=true,[ACTION_RESULT_CRITICAL_HEAL]=true,[ACTION_RESULT_HOT_TICK_CRITICAL]=true }
    local powerResults={ [ACTION_RESULT_POWER_ENERGIZE]=true,[ACTION_RESULT_POWER_DRAIN]=true }
    local isDamage=damageResults[result]; local isHeal=healResults[result]; local isPower=powerResults[result]
    if isDamage and (sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET) then NAGA_BUI.inCombat=true end
    if not NAGA_BUI.inCombat and not isDamage then return end
    targetName=targetName=="" and targetName or string.gsub(targetName or "","%^%w+","")
    NAGA_BUI.Damage.New(result,abilityName,sourceName or "",sourceType,targetName,hitValue,powerType,damageType,sourceUnitId,targetUnitId,abilityId,isDamage)
end

local registered=false
local function RegisterCombatEvents()
    if registered then return end
    local filters={ACTION_RESULT_DAMAGE,ACTION_RESULT_DOT_TICK,ACTION_RESULT_BLOCKED_DAMAGE,ACTION_RESULT_DAMAGE_SHIELDED,ACTION_RESULT_CRITICAL_DAMAGE,ACTION_RESULT_DOT_TICK_CRITICAL,ACTION_RESULT_HOT_TICK,ACTION_RESULT_HEAL,ACTION_RESULT_CRITICAL_HEAL,ACTION_RESULT_HOT_TICK_CRITICAL,ACTION_RESULT_POWER_ENERGIZE,ACTION_RESULT_POWER_DRAIN}
    for i,result in ipairs(filters) do
        local id="NAGA_Statistics_Combat"..i
        EVENT_MANAGER:RegisterForEvent(id,EVENT_COMBAT_EVENT,CombatEvent)
        EVENT_MANAGER:AddFilterForEvent(id,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,result,REGISTER_FILTER_IS_ERROR,false)
    end
    EVENT_MANAGER:RegisterForEvent("NAGA_Statistics_CombatState",EVENT_PLAYER_COMBAT_STATE,OnCombatState)
    EVENT_MANAGER:RegisterForEvent("NAGA_Statistics_Group",EVENT_GROUP_MEMBER_JOINED,RefreshGroup)
    EVENT_MANAGER:RegisterForEvent("NAGA_Statistics_GroupLeft",EVENT_GROUP_MEMBER_LEFT,RefreshGroup)
    EVENT_MANAGER:RegisterForEvent("NAGA_Statistics_GroupRole",EVENT_GROUP_MEMBER_ROLES_CHANGED,RefreshGroup)
    registered=true
end

function NAGA_BUI.StatisticsRefreshPlayer() RefreshPlayer() RefreshGroup() end

NAGA_UI.OnAddonLoaded(function()
    if NAGA_BUI.UI and not _G.NAGA_StatisticsLayer then
        NAGA_BUI.UI.TopLevelWindow("NAGA_StatisticsLayer", GuiRoot, {GuiRoot:GetWidth(),GuiRoot:GetHeight()}, {CENTER,CENTER,0,0}, false)
        NAGA_StatisticsLayer:SetDrawLayer(0)
    end
    NAGA_BUI.StatisticsRefreshPlayer()
    if NAGA_BUI.Damage.Initialize then NAGA_BUI.Damage.Initialize() end
    if NAGA_BUI.Stats.Initialize then NAGA_BUI.Stats.Initialize() end
    RegisterCombatEvents()

    -- A estatística de dano é HUD-only. O TopLevelWindow foi criado em
    -- GuiRoot, portanto ele não é automaticamente ocultado quando o ESO
    -- troca para Inventário, Mapa, Skills, Companheiros, Configurações etc.
    -- Controle a visibilidade pela cena para impedir que o medidor/relatório
    -- apareça por cima dos menus.
    local function UpdateStatisticsVisibility()
        local editor = SCENE_MANAGER and SCENE_MANAGER.IsShowing and
            (SCENE_MANAGER:IsShowing("hud_editor_keyboard") or SCENE_MANAGER:IsShowing("hud_editor_gamepad"))
        local hud = (HUD_SCENE and HUD_SCENE.IsShowing and HUD_SCENE:IsShowing()) or
            (HUD_UI_SCENE and HUD_UI_SCENE.IsShowing and HUD_UI_SCENE:IsShowing())
        local visible = editor or hud
        if _G.NAGA_StatisticsLayer then NAGA_StatisticsLayer:SetHidden(not visible) end
        if _G.NAGA_Statistics_Report and not visible then NAGA_Statistics_Report:SetHidden(true) end
        NAGA_BUI.inMenu = not visible
    end
    NAGA_BUI.UpdateStatisticsVisibility = UpdateStatisticsVisibility
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", UpdateStatisticsVisibility)
    end
    UpdateStatisticsVisibility()
    if NAGA_BUI.Stats and NAGA_BUI.Stats.Analistics_Init then
        zo_callLater(function()
            if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then NAGA_UI.MasterMover:RegisterAll() end
        end,500)
    end
end)
EVENT_MANAGER:RegisterForEvent("NAGA_Statistics_Activated",EVENT_PLAYER_ACTIVATED,function()
    NAGA_BUI.StatisticsRefreshPlayer()
    if NAGA_BUI.init.Stats and NAGA_BUI.Stats.Update then NAGA_BUI.Stats.Update() end
    if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then zo_callLater(function() NAGA_UI.MasterMover:RegisterAll() end,500) end
end)

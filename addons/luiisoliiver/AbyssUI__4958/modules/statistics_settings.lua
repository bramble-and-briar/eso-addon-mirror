-- NAGA Bandits-style damage statistics settings.
NAGA_UI = NAGA_UI or {}

local function T(s)
    if NAGA_UI and NAGA_UI.T then return NAGA_UI.T(s) end
    return s
end
NAGA_UI.Statistics = NAGA_UI.Statistics or {}
local Statistics = NAGA_UI.Statistics

local function B() return _G.NAGA_BUI end
function Statistics:GetOptions()
    local b=B()
    return {
        {type="checkbox", name=T("Ativar estatística de dano"), tooltip=T("Ativa o registro de dano, cura e recursos e o relatório de combate."), getFunc=function() return b.Vars.EnableStats end, setFunc=function(v) b.Vars.EnableStats=v if b.Stats and b.Stats.Initialize then b.Stats.Initialize(not v) end end, default=true},
        {type="header", name=T("Relatório de Danos")},
        {type="checkbox", name=T("Mostrar Minimedidor"), tooltip=T("Mostra o pequeno medidor de DPS no HUD. Clique nele para abrir o relatório; botão direito publica o resultado; botão do meio reinicia a luta."), getFunc=function() return b.Vars.StatsMiniMeter end, setFunc=function(v) b.Vars.StatsMiniMeter=v if b.Stats then b.Stats.Initialize() end end, default=true},
        {type="slider", name=T("Transparência do Minimedidor"), tooltip=T("Controla a transparência do fundo do minimedidor."), min=0,max=100,step=5,getFunc=function() return math.floor((b.Vars.MiniMeterAplha or .8)*100) end,setFunc=function(v) b.Vars.MiniMeterAplha=v/100 if _G.NAGA_Statistics_MiniMeter_BG then _G.NAGA_Statistics_MiniMeter_BG:SetEdgeColor(0,0,0,b.Vars.MiniMeterAplha) end end,disabled=function() return not b.Vars.StatsMiniMeter end},
        {type="slider", name=T("Tamanho da fonte"), tooltip=T("Tamanho das letras do relatório de danos."), min=12,max=28,step=1,getFunc=function() return b.Vars.StatsFontSize end,setFunc=function(v) b.Vars.StatsFontSize=v if b.Stats then b.Stats.Analistics_Init() end end},
        {type="checkbox", name=T("Separar dano por elemento"), tooltip=T("Separa habilidades de múltiplos elementos por tipo de dano."), getFunc=function() return b.Vars.StatsSplitElements end,setFunc=function(v) b.Vars.StatsSplitElements=v end,default=true},
        {type="checkbox", name=T("Mostrar buffs no relatório"), tooltip=T("Mostra a seção de uptime de buffs quando houver dados disponíveis."), getFunc=function() return b.Vars.StatsBuffs end,setFunc=function(v) b.Vars.StatsBuffs=v if b.Stats then b.Stats.Analistics_Init() end end,default=false},
        {type="checkbox", name=T("Mostrar cura no Minimedidor"), tooltip=T("Adiciona HPS ao minimedidor."), getFunc=function() return b.Vars.StatsMiniHealing end,setFunc=function(v) b.Vars.StatsMiniHealing=v if b.Stats then b.Stats.Minimeter_Init() end end,disabled=function() return not b.Vars.StatsMiniMeter end},
        {type="checkbox", name=T("Mostrar DPS do grupo no Minimedidor"), tooltip=T("Adiciona o DPS do grupo ao minimedidor."), getFunc=function() return b.Vars.StatsMiniGroupDps end,setFunc=function(v) b.Vars.StatsMiniGroupDps=v if b.Stats then b.Stats.Minimeter_Init() end end,disabled=function() return not b.Vars.StatsMiniMeter end},
        {type="checkbox", name=T("Mostrar velocidade no Minimedidor"), tooltip=T("Adiciona a velocidade ao minimedidor."), getFunc=function() return b.Vars.StatsMiniSpeed end,setFunc=function(v) b.Vars.StatsMiniSpeed=v if b.Stats then b.Stats.Minimeter_Init() end end,disabled=function() return not b.Vars.StatsMiniMeter end},
        {type="checkbox", name=T("DPS no retículo"), tooltip=T("Mostra DPS próximo ao retículo."), getFunc=function() return b.Vars.ReticleDpS end,setFunc=function(v) b.Vars.ReticleDpS=v if b.Stats then b.Stats.Minimeter_Init() end end},
        {type="checkbox", name=T("Compartilhar DPS com o grupo"), tooltip=T("Usa os pings do mapa para compartilhar DPS. O recurso permanece desligado por padrão."), getFunc=function() return b.Vars.StatsUpdateDPS end,setFunc=function(v) b.Vars.StatsUpdateDPS=v if b.Stats then b.Stats.Initialize() end end,default=false},
        {type="checkbox", name=T("Mostrar DPS nos quadros do grupo"), tooltip=T("Mostra DPS nos quadros de grupo do próprio módulo quando houver integração disponível."), getFunc=function() return b.Vars.StatsGroupDPS end,setFunc=function(v) b.Vars.StatsGroupDPS=v end,disabled=function() return not b.Vars.RaidFrames end},
        {type="checkbox", name=T("Mostrar quadro de DPS do grupo"), tooltip=T("Cria o quadro separado de DPS do grupo."), getFunc=function() return b.Vars.StatsGroupDPSframe end,setFunc=function(v) b.Vars.StatsGroupDPSframe=v if v and b.Stats then b.Stats.GroupDPS_Init() end end},
        {type="checkbox", name=T("Registro de combate"), tooltip=T("Mantém o registro usado pelo relatório para depuração e análise."), getFunc=function() return b.Vars.Log end,setFunc=function(v) b.Vars.Log=v end,default=false},
        {type="button", name=T("Redefinir luta atual"), tooltip=T("Apaga a luta atual e inicia um novo relatório."), func=function() if b.Stats then b.Stats.Reset() end end},
        {type="button", name=T("Mostrar relatório agora"), tooltip=T("Abre o relatório de danos do Bandits."), func=function() if b.Stats then b.Stats.Toggle() end end},
        {type="button", name=T("Redefinir posição pelo Mover HUD"), tooltip=T("O relatório é registrado no Edit HUD nativo do ESO. Use o Mover HUD para reposicioná-lo."), func=function() if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then NAGA_UI.MasterMover:RegisterAll() end end},
    }
end

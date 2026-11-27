HUDMoveUI = {name="HUDMoveUI",version="1.1.0-test",entries={}}
local H=HUDMoveUI
local function add(key,title,section,names,w,h,x,y,resolve)
    H.entries[#H.entries+1]={key=key,title=title,section=section,names=names,w=w,h=h,x=x,y=y,resolve=resolve}
end
add("health","Lebensleiste","01 Ressourcen",{"ZO_PlayerAttributeHealth"},300,40,.5,.82)
add("magicka","Magickaleiste","01 Ressourcen",{"ZO_PlayerAttributeMagicka"},300,40,.38,.87)
add("stamina","Ausdauerleiste","01 Ressourcen",{"ZO_PlayerAttributeStamina"},300,40,.62,.87)
add("mount","Reittier-Ausdauer","01 Ressourcen",{"ZO_PlayerAttributeMountStamina"},300,32,.62,.9)
add("werewolf","Werwolf-Zeitleiste","01 Ressourcen",{"ZO_PlayerAttributeWerewolf"},300,32,.38,.9)
add("siege","Belagerungswaffen-Leben","01 Ressourcen",{"ZO_PlayerAttributeSiegeHealth"},300,32,.5,.85)
add("skills","Skillleiste mit Ultimate und Schnellzugriff","02 Kampf",{"ZO_ActionBar1"},620,90,.5,.93)
add("synergy","Synergie-Hinweis","02 Kampf",{"ZO_SynergyTopLevelContainer"},340,64,.5,.73,function()
    return (SYNERGY and SYNERGY.container) or ZO_SynergyTopLevelContainer
end)
add("target","Ziel-Lebensleiste","02 Kampf",{"ZO_TargetUnitFramereticleover"},450,80,.5,.15)
add("boss","Boss-Lebensleiste","02 Kampf",{"ZO_BossBarHealth"},550,50,.5,.08)
add("combatTips","Kampfhinweise","02 Kampf",{"ZO_ActiveCombatTipsTip"},500,70,.5,.68)
add("selfBuffs","Eigene Buffs und Debuffs","03 Effekte",{"ZO_BuffDebuffTopLevelSelfContainer"},500,64,.5,.8)
add("targetBuffs","Ziel-Buffs und Debuffs","03 Effekte",{"ZO_BuffDebuffTopLevelTargetContainer"},500,64,.5,.22)
add("compass","Kompass","04 Orientierung",{"ZO_Compass"},550,70,.5,.06)
add("interact","Interaktionshinweis","04 Orientierung",{"ZO_ReticleContainerInteract"},400,80,.5,.58)
add("progress","Erfahrung und Champion-Fortschritt","04 Orientierung",{"ZO_PlayerProgress"},550,50,.5,.1)
add("quests","Questanzeige","05 Gruppe und Aufgaben",{"ZO_FocusedQuestTrackerPanel"},360,300,.82,.35)
add("smallGroup","Kleine Gruppenanzeige","05 Gruppe und Aufgaben",{"ZO_SmallGroupAnchorFrame"},300,200,.15,.35)
add("obsidian","Obsidian HUD: Ressourcenblock","06 Eigene Addons",{},520,180,.5,.78,function()
    return ObsidianHUD and ObsidianHUD.root
end)
H.byKey={}
for _,entry in ipairs(H.entries) do H.byKey[entry.key]=entry end

function H.Resolve(entry)
    if entry.resolve then return entry.resolve() end
    for _,name in ipairs(entry.names) do if _G[name] then return _G[name] end end
end

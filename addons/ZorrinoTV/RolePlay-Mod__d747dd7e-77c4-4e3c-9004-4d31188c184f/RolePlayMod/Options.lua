if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local R=RolePlayMod
local function desc(text) return {type='description',text=text,width='full'} end
local function check(key,name,parent,tooltip)
    return {type='checkbox',name=name,tooltip=tooltip,default=R.defaults[key]~=false,
        getFunc=function() return R.Options()[key]~=false end,setFunc=function(v) R.Set(key,v) end,
        disabled=parent and function() return not R.Enabled(parent) end or nil}
end
local function nativeCheck(get,set,name,parent,tooltip,default)
    return {type='checkbox',name=name,tooltip=tooltip,default=default~=false,getFunc=get,
        setFunc=function(v) set(v);R.Apply(true) end,disabled=parent and function() return not R.Enabled(parent) end or nil}
end
local function slider(name,get,set,min,max,step,default,parent,tooltip)
    return {type='slider',name=name,min=min,max=max,step=step,decimals=step<1 and 2 or 0,default=default,tooltip=tooltip,getFunc=get,
        setFunc=function(v) set(v);R.Apply(true) end,disabled=parent and function() return not R.Enabled(parent) end or nil}
end
local function submenu(name,controls) return {type='submenu',name=name,controls=controls} end
function R.CreateOptions()
    local S=RolePlayNeeds;local B=IHR_Runtime.Beta
    local function setting(key,fallback) return function() local v=S.settings[key];if v==nil then return fallback end;return v end end
    local function setSetting(key) return function(v) S.settings[key]=v end end
    local survival={check('survival','Mode survie'),desc('Chaque besoin peut être désactivé séparément. Ses valeurs restent sauvegardées et reprennent à la réactivation.'),
        check('hunger','Faim','survival'),slider('Diminution de la satiété : intervalle en minutes',function() return S.settings.hungerTickSeconds/60 end,function(v) S.settings.hungerTickSeconds=v*60 end,1,60,0.5,12.5,'hunger'),
        check('water','Soif','survival'),slider('Diminution de l’hydratation : intervalle en minutes',function() return S.settings.waterTickSeconds/60 end,function(v) S.settings.waterTickSeconds=v*60 end,1,60,0.5,12.5,'water'),
        check('fatigue','Fatigue','survival'),desc('Fatigue désactivée : les aubergistes ne proposent plus de chambre ; les repos et les restrictions de déplacement sont désactivés.'),
        submenu('Repos et épuisement',{
            check('partialRests','Repos partiels','fatigue','Deux repos maximum entre deux nuits à l’auberge. Chaque repos rend 50 % de la réserve de fatigue.'),
            check('rooms','Louer une chambre','fatigue','Repos complet : fatigue entièrement restaurée et deux repos partiels disponibles. Réservation RP, sans retrait d’or réel.'),
            desc('Si les chambres sont désactivées, le repos assis lent reste disponible. Les deux repos partiels ne se rechargent qu’après un repos complet à l’auberge, une fois cette option réactivée.'),
            slider('Durée de base de la réserve — minutes',function() return R.Options().fatigueMinutes end,function(v) R.Set('fatigueMinutes',v) end,60,1440,30,360,'fatigue'),
            slider('Vitesse de fatigue',function() return R.Options().fatigueSpeed end,function(v) R.Set('fatigueSpeed',v) end,0.25,4,0.25,1.5,'fatigue','1 = rythme de base ; 1,5 = fatigue 50 % plus rapide ; 2 = deux fois plus rapide. Par défaut : 360 minutes de base / 1,5 = 240 minutes au calme.'),
            check('restConsumesNeeds','Faim et soif pendant les repos','fatigue','Repos partiel : environ 11 points de satiété et 11 points d’hydratation. Nuit complète : environ 22 et 33 points. Un besoin désactivé ne diminue pas. Seul un repos mené à son terme applique cette perte.'),
            nativeCheck(setting('fatigueSprintLock',true),setSetting('fatigueSprintLock'),'Bloquer le sprint sous 30 %','fatigue'),
            nativeCheck(setting('fatigueRunLock',true),setSetting('fatigueRunLock'),'Interrompre la course sous 5 %','fatigue'),
            slider('Seuil de course estimée',setting('fatigueRunThreshold',350),setSetting('fatigueRunThreshold'),200,650,25,350,'fatigue'),
            slider('Seuil de sprint estimé',setting('fatigueSprintThreshold',700),setSetting('fatigueSprintThreshold'),400,2000,25,700,'fatigue'),
        }),
        check('disease','Maladies','survival'),slider('Risque de maladie',setting('diseaseChance',1),setSetting('diseaseChance'),0,100,1,1,'disease'),
        check('alcohol','Effets de l’alcool','survival'),
        nativeCheck(setting('canEatRaw',false),setSetting('canEatRaw'),'Manger les aliments récoltés','hunger',nil,false),
        nativeCheck(setting('canDrinkRaw',true),setSetting('canDrinkRaw'),'Boire l’eau récoltée','water'),
    }
    local conversations={check('conversations','Conversations et renseignements'),
        check('questions','Questions sur les quêtes en cours','conversations'),check('services','Localiser un marchand ou un service','conversations'),
        check('journal','Afficher les renseignements obtenus dans les tâches du journal',nil,'Masquer cet affichage ne supprime pas les indices déjà appris.'),
        check('nativeConversation','Accès depuis les dialogues habituels du jeu',nil,'Le raccourci de conversation reste utilisable avec les autres PNJ.'),
        desc('Seuls les objectifs actuels et les renseignements réellement obtenus servent à l’enquête. Aucun itinéraire n’est inventé pour satisfaire un jet réussi.'),
    }
    local mode={type='dropdown',name='Mode de roleplay',choices={'Jet de dés','Speechcraft'},choicesValues={'dice','speechcraft'},default='dice',
        getFunc=function() return R.Options().roleplayMode or 'dice' end,setFunc=function(v) R.Set('roleplayMode',v) end,
        tooltip='Deux modes exclusifs. Choisir Speechcraft désactive automatiquement les jets de dé ; choisir Jet de dés les réactive.'}
    local social={mode,check('dice','Jets de dé',nil,'Désactivé : les PNJ coopèrent sans jet ni limite quotidienne. Cela ne leur donne aucune connaissance supplémentaire.'),
        slider('Durée de l’animation du dé — secondes',function() return R.Options().diceSeconds end,function(v) R.Set('diceSeconds',v) end,1,15,1,5,'dice'),
        check('trust','Confiance et personnalité'),check('reputation','Influence des exploits et de la réputation','trust'),check('crime','Influence de la prime et des poursuites','trust'),
        check('origins','Affiliations et contexte géopolitique','trust'),check('negativeQuota','Une tentative par 24 h pour les PNJ négatifs','trust'),
        desc('Les personnalités simulées influencent le ton. Un jet réussi mesure la coopération ; un PNJ éloigné peut ignorer un détail que les habitants sur place connaissent.'),
    }
    social[2].disabled=function() return R.Options().roleplayMode=='speechcraft' end
    social[2].getFunc=function() return R.Enabled('dice') end
    for _,option in ipairs(social) do
        if option.name=='Confiance et personnalité' then
            option.disabled=function() return R.Options().roleplayMode=='speechcraft' end
            option.getFunc=function() return R.Enabled('trust') end
        end
    end
    local rumors={check('rumors','Rumeurs — départs de quête'),check('travelJournal','Carnet de voyage','rumors'),
        slider('Renouvellement des rumeurs — heures réelles',function() return R.Options().rumorCooldownHours or 2 end,function(v) R.Set('rumorCooldownHours',v) end,1,24,1,2,'rumors','Délai commun aux personnages d’un même établissement, compté depuis sa dernière rumeur transmise. Un autre établissement repéré dispose de ses propres réserves. Si le lieu est inconnu, un délai commun sert de secours. Fermer le dialogue ne recharge rien.'),
        desc('Par renouvellement : 2 rumeurs au maximum par aubergiste ou brasseur, 1 par client. Parlez à d’autres voyageurs, changez d’auberge ou attendez le délai choisi. Les rumeurs obtenues sont notées automatiquement si le carnet est activé ; les pistes déjà notées, commencées ou terminées ne reviennent pas. Sans carnet, une piste peut revenir après le délai. Les notes existantes restent sauvegardées.'),
    }
    local interface={
        check('animations','Animations du personnage liées à la survie','survival'),
        nativeCheck(function() return not S.settings.needsHUD or S.settings.needsHUD.enabled~=false end,function(v) S.settings.needsHUD=S.settings.needsHUD or {};S.settings.needsHUD.enabled=v end,'Afficher les jauges de survie','survival'),
        nativeCheck(function() return (S.settings.needsHUD or {}).legacyIcons==true end,function(v) S.settings.needsHUD=S.settings.needsHUD or {};S.settings.needsHUD.legacyIcons=v end,'Conserver les anciennes icônes de besoin','survival',nil,false),
        nativeCheck(function() return IHeardARumor.savedVars.hidePlayerPin==true end,function(v) IHR_Runtime.Base.TogglePlayerPin(v) end,'Masquer le marqueur du joueur sur la carte',nil,nil,false),
        slider('Taille des jauges — %',function() return ((S.settings.needsHUD or {}).scale or 1)*100 end,function(v) S.settings.needsHUD=S.settings.needsHUD or {};S.settings.needsHUD.scale=v/100;S.NeedsHUD.ApplyPosition() end,70,150,5,100,'survival'),
        slider('Opacité de l’effet de maladie — %',function() return (S.settings.diseaseOverlayalpha1 or .75)*100 end,function(v) S.settings.diseaseOverlayalpha1=v/100 end,0,100,5,75,'disease'),
        slider('Opacité de l’effet de blessure — %',function() return (S.settings.diseaseOverlayalpha2 or .75)*100 end,function(v) S.settings.diseaseOverlayalpha2=v/100 end,0,100,5,75,'disease'),
        slider('Opacité de l’affliction magique — %',function() return (S.settings.diseaseOverlayalpha3 or .75)*100 end,function(v) S.settings.diseaseOverlayalpha3=v/100 end,0,100,5,75,'disease'),
        {type='button',name='Réinitialiser la position des jauges',func=function() S.settings.needsHUD.position=nil;S.NeedsHUD.ApplyPosition() end},
        {type='button',name='Réinitialiser la position du dialogue',func=function() B.saved.dialoguePosition=nil;if B.ResetPosition then B.ResetPosition() end;B.Close() end},
        {type='button',name='Réinitialiser la position de la roue',func=function() if B.ResetWheelPosition then B.ResetWheelPosition() end end},
        desc('Croix directionnelle ou stick pour choisir, touche Croix pour valider, Rond pour revenir. Maintenez Rond pour quitter. En dialogue ESO ou au premier niveau du menu principal, R1 ouvre RolePlay Mod.'),
    }
    return {
        desc('Survie, rencontres et exploration en Tamriel. Les options grisées dépendent du module parent. Désactiver une fonction ne supprime pas sa progression.'),
        submenu('Survie',survival),submenu('Conversations et enquêtes',conversations),submenu('Mode de roleplay et relations',social),submenu('Rumeurs et carnet de voyage',rumors),submenu('Speechcraft — réglages',R.Speechcraft.Options()),submenu('Interface',interface),
    }
end

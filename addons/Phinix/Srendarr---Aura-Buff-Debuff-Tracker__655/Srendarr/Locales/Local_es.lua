--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local L = {}

------------------------------------------------------------------------------------------------------------------
-- Spanish (es)
-- Indented or commented lines still require human translation and may not make sense!
------------------------------------------------------------------------------------------------------------------

L.Srendarr = "|c67b1e9S|c4779ce'rendarr|r"
L.Srendarr_Basic = "S'rendarr"
L.Usage = "|c67b1e9S|c4779ce'rendarr|r - Uso: /srendarr lock|unlock para alternar el movimiento de la ventana de visualización."
L.CastBar = 'Barra de Cast'
L.Sound_DefaultProc = 'Srendarr (Por defecto Proc)'
L.ToggleVisibility = 'Alternar la visibilidad de Srendarr'
L.UpdateGearSets = 'Actualizar conjuntos de engranajes equipados'

-- time format						
L.Time_Tenths = '%.1fs'
L.Time_TenthsNS = '%.1f'
L.Time_Seconds = '%ds'
L.Time_SecondsNS = '%d'
L.Time_Minutes = '%dm'
L.Time_Hours = '%dh'
L.Time_Days = '%dd'

-- aura grouping
L.Group_Displayed_Here = 'Grupos mostrados'
L.Group_Displayed_None = 'Ninguno'
L.Group_Player_Short = 'Tus buffs cortos'
L.Group_Player_Long = 'Tus buffs largos'
L.Group_Player_Major = 'Tu buffs mayor'
L.Group_Player_Minor = 'Tu buffs menor'
L.Group_Player_Toggled = 'Tu buffs alternado'
L.Group_Player_Ground = 'Tu Aoe de tierra'
L.Group_Player_Enchant = 'Tus encantadores procs'
L.Group_Player_Cooldowns = 'Tus grietas procs'
L.Group_Player_CABar = 'Barra de enfriarse acción'
L.Group_Player_Passive = 'Tus pasivos'
L.Group_Player_Debuff = 'Tus debuffs'
L.Group_Target_Buff = 'Buffs de Target'
L.Group_Target_Debuff = 'Debuffs de Target'
L.Group_ProminentType = 'Tipo prominente'
L.Group_ProminentTypeTip = 'Seleccione el tipo de aura para observar (Buff, Debuff).'
L.Group_ProminentTarget = 'Objetivo prominente'
L.Group_ProminentTargetTip = 'Seleccione el objetivo del aura para observar (jugador, objetivo, AOE).'
L.Group_GroupBuffs = 'Grupo Buff marcos'
L.Group_RaidBuffs = 'Raid Buff marcos'
L.Group_GroupDebuffs = 'Grupo Debuff marcos'
L.Group_RaidDebuffs = 'Raid Debuff marcos'
L.Group_Cooldowns = 'Rastreador de enfriamiento'
L.Group_CooldownBar = 'Barra enfriarse activa'
L.Group_Cooldown = 'Enfriarse'

-- whitelist & blacklist control
L.Prominent_RemoveByRecent = 'eliminado del prominente debido a la clasificación incorrecta, debe ser el tipo'
L.Prominent_AuraAddSuccess = 'agregado al marco'
L.Prominent_AuraAddAs = 'ya que'
L.Prominent_AuraAddFail = 'no se encontró y no se pudo agregar.'
L.Prominent_AuraAddFailByID = 'no es un abilityID válido.'
L.Prominent_AuraAddFailByName = 'Parámetros faltantes o incorrectos.'
L.Prominent_AuraRemoveFail = 'Para eliminar un aura prominente, primero debe hacer clic en un nombre de un menú Modify Aura Poura. No modifique ningún valor después de hacer clic en un aura o la eliminación fallará.'
L.Prominent_AuraRemoveSuccess = 'ha sido eliminado de la lista prominente.'
L.Blacklist_AuraAddSuccess = 'se ha agregado a la lista negra y ya no se mostrará.'
L.Blacklist_AuraAddFail = 'no se encontró y no se pudo agregar a la lista negra.'
L.Blacklist_AuraAddFailByID = 'no es una habilidad válida y no se pudo agregar a la lista negra.'
L.Blacklist_AuraRemoved = 'ha sido retirado de la lista negra.'
L.Group_AuraAddSuccess = 'se ha agregado a la lista blanca de buff de grupo.'
L.Group_AuraAddSuccess2 = 'se ha agregado a la lista blanca del grupo.'
L.Group_AuraRemoved = 'se ha eliminado de la lista blanca de buffes grupales.'
L.Group_AuraRemoved2 = 'ha sido retirado de la lista blanca del grupo.'

-- settings: base
L.Show_Example_Auras = 'Ejemplo de auras'
L.Show_Example_Castbar = 'Ejemplo Castbar'

L.SampleAura_PlayerTimed = 'Jugador cronometrado'
L.SampleAura_PlayerToggled = 'Jugador alternado'
L.SampleAura_PlayerPassive = 'Jugador pasivo'
L.SampleAura_PlayerDebuff = 'Jugador Debuff'
L.SampleAura_PlayerGround = 'Efecto de tierra'
L.SampleAura_PlayerMajor = 'Mayor efecto'
L.SampleAura_PlayerMinor = 'Menor efecto'
L.SampleAura_TargetBuff = 'Objetivo Buff'
L.SampleAura_TargetDebuff = 'Objetivo Debuff'

L.TabButton1 = 'General'
L.TabButton2 = 'Filtros'
L.TabButton3 = 'Barra de Cast'
L.TabButton4 = 'Pantalla de aura'
L.TabButton5 = 'Perfiles'

L.TabHeader1 = 'Configuración general'
L.TabHeader2 = 'Configuración de filtro'
L.TabHeader3 = 'Configuración de barra de cast'
L.TabHeader5 = 'Configuración de perfil'
L.TabHeaderDisplay = 'Mostrar configuración de ventana'

-- settings: generic
L.GenericSetting_ClickToViewAuras = '|cffd100Haga clic para ver auras|r'
L.GenericSetting_NameFont = 'Nombre Fuente de texto'
L.GenericSetting_NameStyle = 'Nombre de color y estilo de texto'
L.GenericSetting_NameSize = 'Nombre Tamaño del texto'
L.GenericSetting_TimerFont = 'Fuente de texto de temporizador'
L.GenericSetting_TimerStyle = 'Color y estilo de fuente de temporizador'
L.GenericSetting_TimerSize = 'Tamaño del texto del temporizador'
L.GenericSetting_BarWidth = 'Ancho de barra'
L.GenericSetting_BarWidthTip = 'Establezca cuán anchas deben ser las barras de temporizador cuando se muestran.'


-- ----------------------------
-- SETTINGS: DROPDOWN ENTRIES
-- ----------------------------
L.DropGroup_1 = 'En ventana de visualización [|cffd1001|r]'
L.DropGroup_2 = 'En ventana de visualización [|cffd1002|r]'
L.DropGroup_3 = 'En ventana de visualización [|cffd1003|r]'
L.DropGroup_4 = 'En ventana de visualización [|cffd1004|r]'
L.DropGroup_5 = 'En ventana de visualización [|cffd1005|r]'
L.DropGroup_6 = 'En ventana de visualización [|cffd1006|r]'
L.DropGroup_7 = 'En ventana de visualización [|cffd1007|r]'
L.DropGroup_8 = 'En ventana de visualización [|cffd1008|r]'
L.DropGroup_9 = 'En ventana de visualización [|cffd1009|r]'
L.DropGroup_10 = 'En ventana de visualización [|cffd10010|r]'
L.DropGroup_11 = 'En ventana de visualización [|cffd10011|r]'
L.DropGroup_12 = 'En ventana de visualización [|cffd10012|r]'
L.DropGroup_13 = 'En ventana de visualización [|cffd10013|r]'
L.DropGroup_14 = 'En ventana de visualización [|cffd10014|r]'
L.DropGroup_None = 'No se muestran'

L.DropStyle_Full = 'Pantalla completa'
L.DropStyle_Icon = 'Solo icono'
L.DropStyle_Mini = 'Visualización mínima'

L.DropGrowth_Up = 'Arriba'
L.DropGrowth_Down = 'Abajo'
L.DropGrowth_Left = 'Izquierda'
L.DropGrowth_Right = 'Derecha'
L.DropGrowth_CenterLeft = 'Centrado (Izquierda)'
L.DropGrowth_CenterRight = 'Centrado (Derecha)'
L.DropGrowth_CenterUp = 'Centrado (Arriba)'
L.DropGrowth_CenterDown = 'Centrado (Abajo)'

L.DropSort_NameAsc = 'Nombre de habilidad (Asc)'
L.DropSort_TimeAsc = 'Tiempo restante (Asc)'
L.DropSort_CastAsc = 'Orden de fundición (Asc)'
L.DropSort_NameDesc = 'Nombre de habilidad (Desc)'
L.DropSort_TimeDesc = 'Tiempo restante (Desc)'
L.DropSort_CastDesc = 'Orden de lanzamiento (Desc)'

L.DropTimer_Above = 'Arriba icono'
L.DropTimer_Below = 'Bajo icono'
L.DropTimer_Over = 'Sobre icono'
L.DropTimer_Hidden = 'Oculta'

L.DropAuraClassBuff = 'Buff'
L.DropAuraClassDebuff = 'Debuff'
L.DropAuraTargetPlayer = 'Jugador'
L.DropAuraTargetTarget = 'Objetivo'
L.DropAuraTargetAOE = 'AOE'
L.DropAuraClassDefault = 'Sin anulación'

L.DropGroupMode1 = 'Defecto'
-- L.DropGroupMode2							= "Foundry Tactical Combat"
-- L.DropGroupMode3							= "Lui Extended"
-- L.DropGroupMode4							= "Bandits User Interface"
-- L.DropGroupMode5							= "AUI"


-- ------------------------
-- SETTINGS: GENERAL
-- ------------------------
-- general (general options)
L.General_GeneralOptions = 'Opciones generales'
L.General_GeneralOptionsDesc = 'Varias opciones generales que controlan el comportamiento del complemento.'
L.General_UnlockDesc = 'Desbloquee para permitir que las ventanas de visualización de aura se arrastren con el mouse. RESET Revertirá todos los cambios de posición ya que la última recarga y los valores predeterminados devolverán todas las ventanas a su ubicación predeterminada.'
L.General_UnlockLock = 'Trabar'
L.General_UnlockUnlock = 'Abrir cerradura'
L.General_UnlockDefaults = 'Predeterminados'
L.General_UnlockDefaultsAgain = 'Confirmar predeterminados'
L.General_UnlockReset = 'Reajustar'
L.General_PassivesAlways = 'Siempre muestra pasivos'
L.General_PassivesAlwaysTip = 'Mostrar auras pasivas/de larga duración incluso cuando no está en combate y se verifica la opción anterior.'
L.HideOnDeadTargets = 'Esconderse en objetivos muertos'
L.HideOnDeadTargetsTip = 'Establezca si ocultar todas las auras en objetivos muertos. (Ocultará cosas potencialmente útiles como el arrepentimiento use debuff).'
L.PVPJoinTimer = 'Temporizador de unión de PvP'
L.PVPJoinTimerTip = 'El juego bloquea los eventos registrados en complemento mientras inicializa PvP. Esta es la cantidad de segundos que Srendarr esperará a que esto se complete, que puede depender de su CPU y/o retraso del servidor. Si las auras desaparecen al unirse o dejar PVP, establezca este valor más alto.'
L.ShowTenths = 'Décimas de segundos'
L.ShowTenthsTip = 'Muestre décimas al lado de los temporizadores con solo segundos restantes. El control deslizante se establece en cuántos segundos restantes por debajo de los cuales comenzarán a aparecer las décimas. Configurar este valor en 0 deshabilitará mostrando décimas.'
L.ShowSSeconds = "Mostrar 's' segundos"
L.ShowSSecondsTip = "Muestre la letra 's' después de los temporizadores con solo segundos restantes. Los temporizadores que muestran minutos y segundos no se ven afectados por esto."
L.ShowSeconds = 'Mostrar segundos restantes'
L.ShowSecondsTip = 'Muestre los segundos restantes al lado de los temporizadores que muestran minutos. Los temporizadores que muestran horas no se ven afectados por esto.'
L.General_ConsolidateEnabled = 'Consolidar multi-auras'
L.General_ConsolidateEnabledTip = 'Ciertas habilidades como el aura de restauración de Templar tienen múltiples efectos de aficionado, y normalmente todas se mostrarán en su ventana de aura seleccionada con el mismo icono, lo que lleva al desorden. Esta opción los consolida en un solo aura. W.I.P.'
L.General_AlternateEnchantIcons = 'Iconos de encantamiento alternativos'
L.General_AlternateEnchantIconsTip = 'Habilitar: use un conjunto personalizado de iconos para efectos encantadores. Desactivar: use iconos de encantamiento de juego predeterminados.'
L.General_PassiveEffectsAsPassive = 'Buffs pasivos mayores y menores'
L.General_PassiveEffectsAsPassiveTip = "Establezca si los beneficios mayores y menores que son pasivos (sin duración) se agrupan junto con otras auras pasivas en el jugador de acuerdo con el entorno 'sus pasivos'.\n\nSi no está habilitado, todos los beneficios principales y menores se agruparán independientemente de si están cronometrados o pasivos."
L.General_AuraFadeout = 'Tiempo de desvanecimiento del aura'
L.General_AuraFadeoutTip = 'Establezca cuánto tiempo debe tomar un aura vencida para desvanecerse de la vista. Con un escenario de 0, Auras desaparecerá tan pronto como expire sin ningún desvanecimiento.'
L.General_ShortThreshold = 'Umbral de Buffs cortos'
L.General_ShortThresholdTip = "Establezca la duración mínima de los beneficios de los jugadores (en segundos) que se considerará parte del grupo de 'Buffs' Long '. Cualquier beneficio por debajo de este umbral será parte del grupo de 'Breve Buffs' en su lugar."
L.General_ProcEnableAnims = 'Habilitar animaciones de Proc de bar'
L.General_ProcEnableAnimsTip = "Establezca si muestra una animación en la barra de acción para las habilidades que han superado y ahora tienen una acción especial para actuar. Los abilitas que pueden tener procs incluyen:\n   Crystal Fragments\n   Grim Focus & It's Morphs\n   Flame Lash\n   Deadly Cloak"
L.General_GrimProcAnims = 'Animaciones de Proc Focus Grim'
L.General_GrimProcAnimsTip = 'Establezca si mostrar una animación en el aura en sí cuando Nightblade Grim Dawn o sus morfos tienen suficientes pilas para lanzar el arco de especie.'
L.General_GearProcAnims = 'Animaciones de barra de acción de enfriamiento'
L.General_GearProcAnimsTip = 'Establezca si muestra una animación en la barra de acción de enfriamiento cuando las habilidades de los engranajes están fuera del enfriamiento y listas para proc. (Debe asignar la barra de acción de enfriamiento a un marco en el control de aura - grupos de visualización).'
L.General_gearProcCDText = 'Duración de la barra de acción de enfriamiento'
L.General_gearProcCDTextTip = 'Muestre la duración del enfriamiento en la barra de acción de enfriamiento al lado del nombre de proceso establecido de las habilidades de equipo que están listas para ser utilizadas.'
L.General_ProcEnableAnimsWarn = 'Si está utilizando un mod que modifica o oculta la barra de acción predeterminada, las animaciones pueden no mostrar.'
L.General_ProcPlaySound = 'Reproducir sonido en proc'
L.General_ProcPlaySoundTip = 'Establezca un sonido para reproducir cuando una habilidad se realiza. Una configuración de Ninguno impedirá una alerta de audio sobre sus procs.'
L.General_ModifyVolume = 'Modificar el volumen de proc'
L.General_ModifyVolumeTip = 'Habilite el uso de un control deslizante de volumen de proc.'
L.General_ProcVolume = 'Volumen de sonido de proc'
L.General_ProcVolumeTip = 'Anula temporalmente el volumen de efectos de audio al reproducir el sonido Srendarr Proc.'
L.General_GroupAuraMode = 'Modo de aura de grupo'
L.General_GroupAuraModeTip = 'Seleccione el módulo de soporte para los marcos de la unidad de grupo que usa actualmente. El valor predeterminado es los marcos normales del juego.'
L.General_RaidAuraMode = 'Modo Raid Aura'
L.General_RaidAuraModeTip = 'Seleccione el módulo de soporte para los marcos de la unidad raid que usa actualmente. El valor predeterminado es los marcos normales del juego.'

-- general (display groups)
L.General_ControlHeader = 'Control de aura - Grupos de visualización'
L.General_ControlBaseTip = 'Establezca qué ventana de visualización para mostrar cada grupo de aura o esconderlos de la pantalla por completo. NOTA: Habilitar filtros específicos o agregar un aura a la lista negra o en la lista blanca anulará esta configuración.'
L.General_ControlShortTip = "Este grupo aura contiene todos los beneficios con una duración por debajo del 'umbral de breve breve'."
L.General_ControlLongTip = "Este grupo aura contiene todos los beneficios sobre usted mismo con una duración por encima del 'umbral de aficionado corto'."
L.General_ControlMajorTip = 'Este grupo aura contiene todos los efectos principales beneficiosos que son activos en usted (por ejemplo, la brutalidad mayor). Los principales efectos perjudiciales son parte del grupo debuffs.'
L.General_ControlMinorTip = 'Este grupo aura contiene todos los efectos menores beneficiosos que son activos en usted (por ejemplo, brutalidad menor). Los efectos menores perjudiciales son parte del grupo debuffs.'
L.General_ControlToggledTip = 'Este grupo aura contiene todos los beneficios alternados que están activos en usted mismo.'
L.General_ControlGroundTip = 'Este grupo aura contiene todas las áreas de efecto de efectos (AOE) que se encuentran por usted mismo.'
L.General_ControlEnchantTip = 'Este grupo aura contiene todos los efectos encantados que están activos en usted mismo (por ejemplo, endurecimiento, berserker).'
L.General_ControlGearTip = 'Este grupo aura contiene todos los procesos de engranajes normalmente invisibles que están activos en usted (por ejemplo, Bloodspwn).'
L.General_ControlCooldownTip = 'Este grupo Aura rastrea el enfriamiento de reutilización interna de sus procesos de equipo.'
L.Group_Player_CABarTip = 'Rastree sus enfriamientos equipados y se le notifiquen cuando estén listos para proc.'
L.General_ControlPassiveTip = 'Este grupo aura contiene todos los efectos pasivos que están activos en usted mismo.'
L.General_ControlDebuffTip = 'Este grupo aura contiene todos los debuffs hostiles activos en usted mismo lanzados por otras turbas, jugadores o el entorno.'
L.General_ControlTargetBuffTip = 'Este grupo aura contiene todos los beneficios en su objetivo, ya sean cronometrados, pasivos o alternados, a menos que se filtren especialmente.'
L.General_ControlTargetDebuffTip = 'Este grupo aura contiene todos los debuffs aplicados a su objetivo.'
L.General_ControlProminentFrame = 'Marco prominente'
L.General_ControlProminentFrameTip = 'Seleccione el marco para mostrar este aura prominente. Esto anulará las categorías normales de filtro que de otro modo se aplicarían al aura configurada.'

-- general (debug)
L.General_DebugOptions = 'Opciones de depuración'
L.General_DebugOptionsDesc = '¡Ayuda a rastrear Auras faltantes o incorrectas!'
L.General_DisplayAbilityID = "Habilitar la visualización de Aura's AbilityID"
L.General_DisplayAbilityIDTip = 'Establezca si muestra la habilidad interna de todas las auras. Esto se puede usar para encontrar la identificación exacta de AURAS que puede que desee una lista negra de la pantalla o agregar al grupo de pantalla de la lista blanca aura.\n\nEsta opción también se puede usar para ayudar a arreglar la pantalla de aura inexacta al informar las ID errantes al autor complementario.'
L.General_ShowCombatEvents = 'Mostrar todos los eventos de combate'
L.General_ShowCombatEventsTip = 'Cuando se habilitó el INDIVIO y el nombre de todos los efectos (aficionados y debuffs) causados y recibidos por el jugador se mostrarán en el chat, seguido de información sobre la fuente y el objetivo, y el código de resultados del evento (obtenido, perdido, etc.).\n\nPara evitar la inundación de chat y la revisión de la facilidad, cada habilidad solo se mostrará una vez hasta que vuelva a cargar. Sin embargo, puede escribir /sdbclear en cualquier momento para restablecer manualmente el caché.\n\nAdvertencia: dejar esta opción disminuirá el rendimiento del juego en grupos grandes. Solo habilite cuando sea necesario para las pruebas.'
L.General_ShowCombatEventsH1 = 'AVISO:'
L.General_ShowCombatEventsH2 = 'Dejando '
L.General_ShowCombatEventsH3 = ' en todo momento disminuirá el rendimiento del juego en grupos grandes. Solo habilitado cuando sea necesario para la prueba.'
L.General_AllowManualDebug = 'Permitir la depuración manual editar'
L.General_AllowManualDebugTip = 'Cuando está habilitado, puede escribir /sdbadd xxxxxx o /sdbremove xxxxxx para agregar /eliminar una sola ID del filtro de inundación. Además, la escritura /sdbignore xxxxxx siempre permitirá que las identificaciones selectas estén buscando más allá del filtro de inundación. Escribir /sdbclear aún restablecerá el filtro por completo.'
L.General_DisableSpamControl = 'Deshabilitar el control de inundaciones'
L.General_DisableSpamControlTip = 'Cuando se habilitó, el filtro de evento de combate imprimirá el mismo evento cada vez que ocurra sin tener que escribir /sdbclear o recargar para borrar la base de datos.'
L.General_VerboseDebug = 'Mostrar depuración detallada'
L.General_VerboseDebugTip = 'Muestre todo el bloque de datos recibido de EVENT_COMBAT_EVENT y la ruta de icono de habilidad para cada identificación que pasa los filtros anteriores en un formato legible humano (en su mayoría) (esto llenará rápidamente su registro de chat).'
L.General_OnlyPlayerDebug = 'Solo eventos de jugadores'
L.General_OnlyPlayerDebugTip = 'Solo muestre eventos de combate de depuración que son el resultado de las acciones de los jugadores.'
L.General_ShowNoNames = 'Mostrar eventos sin nombre'
L.General_ShowNoNamesTip = 'Cuando se habilitó, el filtro de eventos de combate muestra ID de eventos incluso cuando no tienen texto de nombre (generalmente no es necesario).'
L.General_ShowSetIds = 'Mostrar identificación de set de Equip'
L.General_ShowSetIdsTip = 'Cuando habilitó, muestra el nombre y SETID de todo el equipo de conjunto equipado al cambiar cualquier pieza.'


-- ------------------------
-- SETTINGS: FILTERS
-- ------------------------
L.FilterHeader = 'Listas de filtros y alternar'
L.Filter_Desc = 'Aquí puede incluir a la lista negra auras, aficionados a la lista blanca o a los debuffes para que parezcan prominentes y asignarlos a una ventana personalizada, o alternar filtros para mostrar o ocultar diferentes tipos de efectos.'
L.Filter_RemoveSelected = 'Eliminar selección'
L.Filter_ListAddWarn = 'Al agregar un aura por su nombre, requiere escanear todas las auras en el juego para encontrar los números de identificación internos de la habilidad. Esto puede hacer que el juego se cuelgue por un momento mientras busca.'
L.FilterToggle_Desc = 'Para estos filtros, habilitando uno evita la visualización de esa categoría (auras prominentes con la lista blanca ignora estos filtros).'

L.Filter_PlayerHeader = 'Filtros de aura para el jugador'
L.Filter_TargetHeader = 'Filtros de aura para el objetivo'
L.Filter_OnlyPlayerDebuffs = 'Solo los debuffs del jugador'
L.Filter_OnlyPlayerDebuffsTip = 'Evite la exhibición de auras debuffes en el objetivo que no fueron creados por el jugador.'
L.Filter_OnlyTargetMajor = 'Solo un mayor objetivo'
L.Filter_OnlyTargetMajorTip = 'Mostrar solo los grandes debuffs de efectos en el objetivo. No se mostrarán todos los demás debuffs objetivo.'

-- filters (blacklist auras)
L.Filter_BlacklistHeader = 'Lista negra del aura global'
L.Filter_BlacklistDesc = 'Las auras específicas pueden estar en la lista negra aquí para nunca aparecer en ninguna ventana de seguimiento de aura.'
L.Filter_BlacklistAdd = 'Agregar aura de lista negra'
L.Filter_BlacklistAddTip = 'El aura que desea que la lista negra debe ingresar su nombre exactamente como aparece Ingame, o puede ingresar el Numérico anilityID (si se conoce) para bloquear un aura específica.\n\nPresione Entrar para agregar el aura de entrada a la lista negra.'
L.Filter_BlacklistList = 'Auras en la lista negra actual'
L.Filter_BlacklistListTip = 'Lista de todas las auras actualmente en la lista negra. Para eliminar un aura de la lista negra, seleccione en la lista y haga clic en el botón Eliminar.'

-- filters (prominent auras)
L.Filter_ProminentHead = 'Asignaciones de aura prominentes'
L.Filter_ProminentHeadTip = 'Se puede asignar AURAS para que aparezcan en marcos específicos para tipos específicos (Buff, Debuff, etc.) en objetivos específicos (jugador, objetivo, grupo, etc.).'
L.Filter_ProminentOnlyPlayer = 'El único elenco de jugador'
L.Filter_ProminentOnlyPlayerTip = 'Solo observe el aura seleccionada si el jugador emite.'
L.Filter_ProminentAddRecent = 'Agregar aura visto recientemente:'
L.Filter_ProminentAddRecentTip = 'Haga clic para mostrar auras detectadas recientemente en varias categorías. Al hacer clic en un aura que se muestra, llenará el panel de configuración prominente con estos datos para que pueda agregarlos fácilmente a un marco de visualización personalizado.'
L.Filter_ProminentResetRecent = 'Restablecer reciente'
L.Filter_ProminentResetRecentTip = 'Borre la base de datos de la lista de auras detectadas recientemente.'
L.Filter_ProminentModify = 'Modificar auras prominentes existentes:'
L.Filter_ProminentModifyTip = 'Haga clic para mostrar una lista de auras prominentes que se han definido para cada categoría. Al hacer clic en un aura que se muestra, llenará el panel de configuración prominente con estos datos para que pueda modificarlos o eliminarlos.'
L.Filter_ProminentTypePB = 'Buffs de jugador'
L.Filter_ProminentTypePD = 'Debuffs de jugador'
L.Filter_ProminentTypeTB = 'Buffs objetivo'
L.Filter_ProminentTypeTD = 'Debuffs objetivo'
L.Filter_ProminentTypeAOE = 'Efectos de área'
L.Filter_ProminentResetAll = 'Menús claros'
L.Filter_ProminentResetAllTip = 'Borre y reinicie todos los campos de menú en el panel Aura prominente.'
L.Filter_ProminentTypeGB = 'Buffs grupo'
L.Filter_ProminentTypeGD = 'Debuffs grupo'
L.Filter_ProminentAdd = 'Agregar/actualizar'
L.Filter_ProminentRemove = 'Eliminar'
L.Filter_ProminentEdit = 'Aura seleccionada:'
L.Filter_ProminentEditTip1 = 'Seleccione un aura de una lista recientemente vista para agregar, o seleccione uno de la lista existente para modificar.'
L.Filter_ProminentEditTip2 = 'Al agregar un aura, requiere escanear todas las auras en el juego para encontrar los números de identificación internos de la habilidad. Esto puede hacer que el juego se cuelgue por un momento mientras busca.'
L.Filter_ProminentShowIDs = 'Mostrar IDs de aura'
L.Filter_ProminentExpert = 'Experto'
L.Filter_ProminentExpertTip = 'Permita la entrada manual de auras por nombre o identificación, y habilite la función eliminar todas.\n\n|cffffffAVISO:|r No agregue AURAS que ya aparezcan en Srendarr (cuando su categoría se asigna a un marco) de esta manera. Hacerlo puede costar rendimiento y romper cosas. Agregue estos a un marco personalizado utilizando un menú recientemente visto en su lugar. Las auras que se ingresan como tipo incorrecta se eliminarán automáticamente cuando Srendarr ve que el juego los envía con diferentes parámetros.\n\n|cffffffEXPERIMENTAL:|r Puede ingresar a Aura ID aquí que el juego y Srendarr no rastrean, sin embargo, no hay garantía de que funcionen ya que el juego envía cero duración e información incorrecta a veces para esto. Es mejor solicitar que se agregue el soporte de Srendarr que intentar forzar las cosas manualmente.'
L.Filter_ProminentRemoveAll = 'Eliminar todo'
L.Filter_ProminentRemoveAllTip = 'Elimina todas las auras prominentes para el perfil activo actual. ADVERTENCIA: si está utilizando la configuración amplia de la cuenta, esto eliminará todas las auras prominentes de la cuenta.'
L.Filter_ProminentRemoveConfirm = '¿Eliminar todas las auras prominentes para el perfil activo actual?'
L.Filter_ProminentWaitForSearch = 'Buscar en progreso, por favor espere.'

-- filters (group frame buffs)
L.Filter_GroupBuffHeader = 'Asignaciones de aficionados al grupo'
L.Filter_GroupBuffDesc = 'Esta lista determina qué Buffs mostrará junto al grupo o marco de raid de cada jugador.'
L.Filter_GroupBuffAdd = 'Agregue el grupo Whitelist Buff'
L.Filter_GroupBuffAddTip = 'Para agregar un aura de Buff para rastrear en los marcos de grupo, debe ingresar su nombre exactamente como aparece en el juego. Presione Entrar para agregar el aura de entrada a la lista.\n\nADVERTENCIA: No ingrese Aura ID aquí a menos que normalmente no sea rastreado por el juego (ingrese el nombre del aura). AURAS ingresó por ID aquí usa el sistema de aura falso de Srendarr y costará el rendimiento cuanto más se ingresan.'
L.Filter_GroupBuffList = 'Buff de grupo actual Whitelist'
L.Filter_GroupBuffListTip = 'Lista de todos los beneficios establecidos para aparecer en cuadros grupales. Para eliminar las AURAS existentes, seleccione en la lista y use el botón de eliminar a continuación.'
L.Filter_GroupBuffsByDuration = 'Excluir buffs por duración'
L.Filter_GroupBuffsByDurationTip = 'Solo muestre los buffs de grupo con una duración más corta que la seleccionada a continuación (en segundos).'
L.Filter_GroupBuffThreshold = 'Umbral de duración de buff'
L.Filter_GroupBuffWhitelistOff = 'Úselo como lista negra de Buff'
L.Filter_GroupBuffWhitelistOffTip = 'Convierta la lista blanca del grupo en una lista negra y muestre todas las auras con una duración, excepto la entrada aquí.'
L.Filter_GroupBuffOnlyPlayer = 'Solo el grupo de jugadores Buffs'
L.Filter_GroupBuffOnlyPlayerTip = 'Solo muestre el Grupo buffs que fue lanzado por el jugador o una de sus mascotas.'
L.Filter_GroupBuffsEnabled = 'Habilitar el grupo buffs'
L.Filter_GroupBuffsEnabledTip = 'Si está deshabilitado, el Grupo buffs no se mostrará en absoluto.'

-- filters (group frame debuffs)
L.Filter_GroupDebuffHeader = 'Asignaciones de debuff de grupo'
L.Filter_GroupDebuffDesc = 'Esta lista determina qué mostrará debuffs al lado del grupo o el marco raid de cada jugador.'
L.Filter_GroupDebuffAdd = 'Agregar debuff del grupo Whitelist'
L.Filter_GroupDebuffAddTip = 'Para agregar un aura debuff para rastrear en los marcos grupales, debe ingresar su nombre exactamente como aparece en el juego. Presione Entrar para agregar el aura de entrada a la lista.\n\nADVERTENCIA: No ingrese Aura ID aquí a menos que normalmente no sea rastreado por el juego (ingrese el nombre del aura). AURAS ingresó por ID aquí usa el sistema de aura falso de Srendarr y costará el rendimiento cuanto más se ingresan.'
L.Filter_GroupDebuffList = 'Grupo actual debuff whitelist'
L.Filter_GroupDebuffListTip = 'Lista de todos los debuffs que aparecerán en cuadros grupales. Para eliminar las AURAS existentes, seleccione en la lista y use el botón de eliminar a continuación.'
L.Filter_GroupDebuffsByDuration = 'Excluir debuffs por duración'
L.Filter_GroupDebuffsByDurationTip = 'Solo muestre los debuffs grupales con una duración más corta que la seleccionada a continuación (en segundos).'
L.Filter_GroupDebuffThreshold = 'Umbral de duración de debuff'
L.Filter_GroupDebuffWhitelistOff = 'Usar como lista negra debuff'
L.Filter_GroupDebuffWhitelistOffTip = 'Convierta la lista blanca del Grupo debuff en una lista negra y muestre todas las auras con una duración, excepto la entrada aquí.'
L.Filter_GroupDebuffsEnabled = 'Habilitar debuffs grupal'
L.Filter_GroupDebuffsEnabledTip = 'Si está deshabilitado, el grupo de debuffs no se mostrará en absoluto.'

-- filters (unit options)
L.Filter_ESOPlus = 'Filtro ESO Plus'
L.Filter_ESOPlusPlayerTip = 'Establezca si debe evitar la visualización de ESO Plus Status en usted mismo.'
L.Filter_ESOPlusTargetTip = 'Establezca si debe evitar la visualización del estado de ESO Plus en su objetivo.'
L.Filter_BlockPlayerTip = "Establezca si debe evitar la visualización de la alternancia 'Brace' mientras está bloqueando."
L.Filter_BlockTargetTip = "Establezca si debe evitar la visualización de la alternancia 'Brace' cuando su oponente está bloqueando."
L.Filter_MundusBoon = 'Filtrar boones Mundus'
L.Filter_MundusBoonPlayerTip = 'Establezca si debe evitar la exhibición de boons de piedra Mundus en usted mismo.'
L.Filter_MundusBoonTargetTip = 'Establezca si debe evitar la exhibición de boons de piedra Mundus en su objetivo.'
L.Filter_Cyrodiil = 'Filtro de bonos de cyrodiil'
L.Filter_CyrodiilPlayerTip = 'Establezca si debe evitar la visualización de buffs proporcionados durante Cyrodiil Ava en usted mismo.'
L.Filter_CyrodiilTargetTip = 'Establezca si debe evitar la visualización de buffs proporcionados durante Cyrodiil AVA en su objetivo.'
L.Filter_Disguise = 'Disfraz de filtro'
L.Filter_DisguisePlayerTip = 'Establezca si debe evitar la visualización de disfraces activos en usted mismo.'
L.Filter_DisguiseTargeTtip = 'Establezca si debe evitar la visualización de disfraces activos en su objetivo.'
L.Filter_MajorEffects = 'Filtrar efectos principales'
L.Filter_MajorEffectsTargetTip = 'Establezca si debe prevenir la exhibición de efectos importantes (por ejemplo, mutilación mayor, brutalidad mayor) en su objetivo.'
L.Filter_MinorEffects = 'Filtrar efectos menores'
L.Filter_MinorEffectsTargetTip = 'Establezca si debe evitar la exhibición de efectos menores (por ejemplo, mutilación menor, brutalidad menor) en su objetivo.'
L.Filter_SoulSummons = 'Filtro Soul Summons enfriamiento'
L.Filter_SoulSummonsPlayerTip = "Establezca si debe evitar la exhibición del 'aura' de enfriamiento para la citación del alma en usted mismo."
L.Filter_SoulSummonsTargetTip = "Establezca si debe evitar la visualización del 'aura' de enfriamiento para la citación del alma en su objetivo."
L.Filter_VampLycan = 'Filtro de vampiros y efectos de hombre lobo'
L.Filter_VampLycanPlayerTip = 'Establezca si debe evitar la visualización de vampirismo y los beneficios de licantropía en usted mismo.'
L.Filter_VampLycanTargetTip = 'Establezca si debe evitar la visualización de vampirismo y beneficios de licantropía en su objetivo.'
L.Filter_VampLycanBite = 'Filtro de vampiros y temporizadores de mordeduras de hombres lobo'
L.Filter_VampLycanBitePlayerTip = 'Establezca si debe evitar la exhibición de los temporizadores de vampiros y bocadillos de hombres lobo en sí mismo.'
L.Filter_VampLycanBiteTargetTip = 'Establezca si debe evitar la exhibición del vampiro y los temporizadores de enfriamiento del hombre lobo en su objetivo.'
L.Filter_GroupDurationThreshold = 'No se mostrará auras del grupo más tiempo que esta duración (en segundos).'


-- ------------------------
-- SETTINGS: CAST BAR
-- ------------------------
L.CastBar_Enable = 'Habilitar barra de casting y canal'
L.CastBar_EnableTip = 'Establezca si habilita una barra de casting móvil para mostrar progreso en las habilidades que tienen un tiempo de reparto o canal antes de la activación.'
L.CastBar_AlphaTip = 'Establece el grado de opacidad de la barra de lanzamiento cuando no estás en combate. Un valor de 0 hace que la barra sea totalmente invisible.'
L.CastBar_CAlphaTip = 'Establece el grado de opacidad de la barra de lanzamiento durante el combate. Un valor de 0 hace que la barra sea totalmente invisible.'
L.CastBar_Scale = 'Escala'
L.CastBar_ScaleTip = 'Establezca el tamaño de la barra de fundición como porcentaje. Una configuración de 100 es el tamaño predeterminado.'

-- cast bar (name)
L.CastBar_NameHeader = 'Texto del nombre de habilidad de lanzar'
L.CastBar_NameShow = 'Mostrar texto de nombre de habilidad'

-- cast bar (timer)
L.CastBar_TimerHeader = 'Texto del temporizador de fundición'
L.CastBar_TimerShow = 'Mostrar texto del temporizador de reparto'

-- cast bar (bar)
L.CastBar_BarHeader = 'Barra de temporizador'
L.CastBar_BarReverse = 'Dirección de cuenta regresiva inversa'
L.CastBar_BarReverseTip = 'Establezca si revertir la dirección de cuenta regresiva de la barra del temporizador de fundición, lo que hace que el temporizador disminuya hacia la derecha. En cualquier caso, las habilidades canalizadas aumentarán en la dirección opuesta.'
L.CastBar_BarGloss = 'Barra brillante'
L.CastBar_BarGlossTip = 'Establezca si la barra del temporizador de fundición debe ser brillante cuando se muestra.'
L.CastBar_BarColor = 'Color de barra'
L.CastBar_BarColorTip = 'Establezca los colores de la barra del temporizador de fundición. La elección de color izquierda determina el inicio de la barra (cuando comienza a contar hacia abajo) y el segundo el acabado de la barra (cuando casi ha expirado).'


-- ------------------------
-- SETTINGS: DISPLAY FRAMES
-- ------------------------
L.DisplayFrame_Alpha = 'Transparencia no en combate'
L.DisplayFrame_AlphaTip = 'Establece el grado de opacidad de esta ventana del aura cuando no está en combate. Un valor de 0 hace que la ventana sea totalmente invisible.'
L.DisplayFrame_CAlpha = 'Transparencia en combate'
L.DisplayFrame_CAlphaTip = 'Establece el grado de opacidad de esta ventana del aura durante el combate. Un valor de 0 hace que la ventana sea totalmente invisible.'
L.DisplayFrame_Scale = 'Escala de ventana'
L.DisplayFrame_ScaleTip = 'Establezca el tamaño de esta ventana de aura como porcentaje. Una configuración de 100 es el tamaño predeterminado.'

-- display frames (aura)
L.DisplayFrame_AuraHeader = 'Visualización de aura'
L.DisplayFrame_Style = 'Estilo aura'
L.DisplayFrame_StyleTip = 'Establezca el estilo que mostrará las auras de esta ventana de aura.\n\n|cffd100Pantalla completa|r - Muestre el nombre de la habilidad y el icono, la barra de temporizador (puede deshabilitar) y el texto.\n\n|cffd100Solo icono|r - Mostrar icono de habilidad y texto de temporizador solamente, este estilo proporciona más opciones para la dirección de crecimiento del aura que los demás.\n\n|cffd100Visualización mínima|r - Mostrar el nombre de la habilidad y solo una barra de temporizador más pequeña.'
L.DisplayFrame_AuraCooldown = 'Mostrar animación de temporizador'
L.DisplayFrame_AuraCooldownTip = 'Muestre una animación de temporizador alrededor de los íconos de aura. Esto también hace que Auras sea más fácil de ver que el modo de visualización anterior. Personalice el uso de la configuración de color a continuación.'
L.DisplayFrame_AuraBackground = 'Usar fondo de icono'
L.DisplayFrame_AuraBackgroundTip = 'Muestra un fondo negro detrás de la visualización del icono de aura. Solo se puede desactivar si no se utilizan animaciones con temporizador, que dependen de esto para mostrarse correctamente.'
L.DisplayFrame_AuraBorder = 'Usar borde de icono'
L.DisplayFrame_AuraBorderTip = 'Muestra el borde de estilo predeterminado del juego alrededor del ícono cuando no se usa el fondo del ícono negro de Srendarr.'
L.DisplayFrame_CooldownTimed = 'Color: Buffs y debuffs cronometrados'
L.DisplayFrame_CooldownTimedB = 'Color: Buffs cronometrados'
L.DisplayFrame_CooldownTimedD = 'Color: Debuffs cronometrado'
L.DisplayFrame_CooldownTimedTip = 'Establezca el color de animación del temporizador de iconos para Auras con una duración establecida.\n\nIzquierda = Buffs\nCorrecto = debuffs.'
L.DisplayFrame_CooldownTimedBTip = 'Establezca el color de animación del temporizador de icono para los buffs con una duración establecida.'
L.DisplayFrame_CooldownTimedDTip = 'Establezca el color de animación del temporizador de icono para debuffs con una duración establecida.'
L.DisplayFrame_Growth = 'Dirección de crecimiento del aura'
L.DisplayFrame_GrowthTip = 'Establezca en qué dirección crecerán las nuevas auras desde el punto de anclaje. Para la configuración central, AURAS crecerá en cualquier dirección desde el ancla con el orden determinado por la opción de clasificación y la dirección seleccionada (izquierda, derecha, hacia arriba, hacia abajo).\n\nAl mostrar en el |cffd100Completo|r o |cffd100Mini|r estilos, Auras solo pueden crecer o bajar.'
L.DisplayFrame_Padding = 'Acolchado de crecimiento de aura'
L.DisplayFrame_PaddingTip = 'Establezca el espacio entre cada aura mostrada.'
L.DisplayFrame_Sort = 'Orden de clasificación de aura'
L.DisplayFrame_SortTip = 'Establezca cómo se ordenan las auras. Ya sea por nombre alfabético, duración restante o por el orden en que fueron lanzados; También se puede establecer si este orden es ascendente o descendente.\n\nAl clasificar por duración, cualquier pasivo o habilidades alternativas se clasificará por nombre y se mostrará más cerca del ancla (ascendente), o más lejos del ancla (descendente), con habilidades cronometradas que vienen antes (o después) de ellos.'
L.DisplayFrame_Highlight = 'Resaltado de icono de aura alternado'
L.DisplayFrame_HighlightTip = 'Establezca si las auras alternativas tienen su ícono destacado para ayudar a distinguir de las auras pasivas.\n\nNo está disponible en el estilo |cffd100Mini|r, ya que no se muestra ningún icono.'
L.DisplayFrame_Tooltips = 'Habilitar información sobre de nombre de aura'
L.DisplayFrame_TooltipsTip = 'Establezca si permitir que la pantalla de información de herramientas de Mouseover para el nombre de un aura cuando esté en el estilo |cffd100Solo icono|r.'
L.DisplayFrame_TooltipsWarn = 'Las información sobre herramientas deben desactivarse temporalmente para el movimiento de la ventana de visualización, o las información sobre herramientas bloquearán el movimiento.'
L.DisplayFrame_AuraClassOverride = 'Anulación de clase de aura'
L.DisplayFrame_AuraClassOverrideTip = 'Le permite hacer que Srendarr trate a todas las auras cronometradas (alternar y los pasivos ignorados) en esta barra como buffs o debuffs, independientemente de su clase real.\n\nÚtil al agregar tanto debuffs como AoE a una ventana para que ambos usen los mismos colores de animación de barra e iconos.'

-- display frames (group)
L.DisplayFrame_GRX = 'Desplazamiento horizontal'
L.DisplayFrame_GRXTip = 'Ajuste la posición del grupo/marco raid buffs iconos a la izquierda y a la derecha.'
L.DisplayFrame_GRY = 'Desplazamiento vertical'
L.DisplayFrame_GRYTip = 'Ajuste la posición del marco de grupo/raid buffs iconos hacia arriba y hacia abajo.'

-- display frames (name)
L.DisplayFrame_NameHeader = 'Texto de nombre de habilidad'

-- display frames (timer)
L.DisplayFrame_TimerHeader = 'Texto de tiempo'
L.DisplayFrame_TimerLocation = 'Ubicación del texto del temporizador'
L.DisplayFrame_TimerLocationTip = 'Establezca la posición del temporizador para cada aura con respecto al ícono de ese aura. Una configuración de Hidden detendrá la etiqueta del temporizador que se muestra para todo el exhibidor AURAS aquí.\n\nSolo hay ciertas opciones de colocación disponibles dependiendo del estilo actual.'
L.DisplayFrame_TimerHMS = 'Mostrar minutos para temporizadores> 1 hora'
L.DisplayFrame_TimerHMSTip = 'Establezca si también muestra minutos restantes cuando un temporizador tiene más de 1 hora.'

-- display frames (bar)
L.DisplayFrame_BarHeader = 'Barra de temporizador'
L.DisplayFrame_HideFullBar = 'Ocultar barra de temporizador'
L.DisplayFrame_HideFullBarTip = 'Oculte la barra por completo y solo muestre el texto del nombre del aura junto al icono cuando está en modo de visualización completo.'
L.DisplayFrame_BarReverse = 'Dirección de cuenta regresiva inversa'
L.DisplayFrame_BarReverseTip = 'Establezca si debe revertir la dirección de cuenta regresiva de la barra del temporizador, lo que hace que el temporizador disminuya hacia la derecha. En el estilo |cffd100Full|r, esto también colocará el ícono del aura a la derecha de la barra en lugar de la izquierda.'
L.DisplayFrame_BarGloss = 'Barras brillantes'
L.DisplayFrame_BarGlossTip = 'Establezca si la barra de temporizador debe ser brillante cuando se muestre.'
L.DisplayFrame_BarBuffTimed = 'Color: Cronometrado Buffs'
L.DisplayFrame_BarBuffTimedTip = 'Establezca los colores de la barra del temporizador para buff auras con una duración establecida. La elección de color izquierda determina el inicio de la barra (cuando comienza a contar hacia abajo) y el segundo el acabado de la barra (cuando casi ha expirado).'
L.DisplayFrame_BarBuffPassive = 'Color: Pasivo Buffs'
L.DisplayFrame_BarBuffPassiveTip = 'Establezca los colores de la barra del temporizador para auras pasivas sin duración. La elección de color izquierda determina el inicio de la barra (el lado más alejado del icono) y el segundo el acabado de la barra (más cercano al icono).'
L.DisplayFrame_BarDebuffTimed = 'Color: Cronometrado Debuffs'
L.DisplayFrame_BarDebuffTimedTip = 'Establezca los colores de la barra del temporizador para debuff auras con una duración establecida. La elección de color izquierda determina el inicio de la barra (cuando comienza a contar hacia abajo) y el segundo el acabado de la barra (cuando casi ha expirado).'
L.DisplayFrame_BarDebuffPassive = 'Color: Pasivo Debuffs'
L.DisplayFrame_BarDebuffPassiveTip = 'Establezca los colores de la barra del temporizador para debuff auras pasivos sin duración de establecimiento. La elección de color izquierda determina el inicio de la barra (el lado más alejado del icono) y el segundo el acabado de la barra (más cercano al icono).'
L.DisplayFrame_BarToggled = 'Color: Auras Allajed'
L.DisplayFrame_BarToggledTip = 'Establezca los colores de la barra del temporizador para auras alternas sin duración de establecimiento. La elección de color izquierda determina el inicio de la barra (el lado más alejado del icono) y el segundo el acabado de la barra (más cercano al icono).'


-- ------------------------
-- SETTINGS: PROFILES
-- ------------------------
L.Profile_Desc = 'Los perfiles de configuración se pueden gestionar aquí, incluida la opción para habilitar un perfil amplio de cuenta que aplicará la misma configuración a todos los personajes en esta cuenta. Debido a la permanencia de estas opciones, la administración primero debe habilitarse utilizando la casilla de verificación en la parte inferior del panel.'
L.Profile_UseGlobal = 'Utilice el perfil de la cuenta amplia'
L.Profile_AccountWide = 'Cuenta amplia'
L.Profile_UseGlobalWarn = 'El cambio entre perfiles locales y globales volverá a cargar la interfaz.'
L.Profile_Copy = 'Seleccione un perfil para copiar'
L.Profile_CopyTip = 'Seleccione un perfil para copiar su configuración en el perfil actualmente activo. El perfil activo será para el personaje registrado en el personaje o el perfil de todo el mundo si está habilitado. La configuración del perfil existente se sobrescribirá permanentemente.\n\n¡Esto no se puede deshacer!'
L.Profile_CopyButton1 = 'Copiar todo el perfil'
L.Profile_CopyButton1Tip = 'Copie todo el perfil seleccionado, incluidas las configuraciones de aura prominentes. Vea la opción a continuación para la alternativa.'
L.Profile_CopyButton2 = 'Copiar perfil base'
L.Profile_CopyButton2Tip = 'Copie todo del perfil seleccionado, excepto las configuraciones de aura prominentes. Útil para configurar una configuración de pantalla base sin copiar la configuración de Aura específica de clase.'
L.Profile_CopyButtonWarn = 'Copiar un perfil recargará la interfaz.'
L.Profile_CopyCannotCopy = 'No se puede copiar el perfil seleccionado. Vuelva a intentarlo o seleccione otro perfil.'
L.Profile_Delete = 'Seleccione un perfil para eliminar'
L.Profile_DeleteTip = 'Seleccione un perfil para eliminar su configuración de la base de datos. Si ese personaje se registra más tarde y no está utilizando el perfil de amplio cuento, se creará una nueva configuración predeterminada.\n\n¡Eliminar un perfil es permanente!'
L.Profile_DeleteButton = 'Eliminar perfil'
L.Profile_Guard = 'Habilitar la gestión del perfil'


-- ------------------------
-- Alt Names
-- ------------------------
L.YoungWasp = 'Avispa Joven'
L.MolagKenaHit1 = ' 1er golpe'
L.VolatileAOE = 'Habilidad Familiar Volátil'


if (GetCVar('language.2') == 'es') then -- overwrite GetLanguage for new language
    for k, v in pairs(Srendarr:GetLocale()) do
        if (not L[k]) then              -- no translation for this string, use default
            L[k] = v
        end
    end
    function Srendarr:GetLocale() -- set new locale return
        return L
    end
end
local OS = OneSettings
local en = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "UI reload required", reloadNow = "Reload UI", reloadLater = "Later",
    reloadWarning = "Changing the addon set may require a UI reload. It will wait until you leave addon settings and confirm the reload. Choosing Later keeps your changes for the next reload or login.",
    settings = "Game settings", bindings = "Keybindings", windows = "Windows", addons = "Addons",
    settingsTip = "Share the accessible settings from the standard game menu, including chat font, opacity and channel colors. The first character is the source; later changes become shared. Account services and settings unavailable to addons are excluded. Settings that require a game restart take effect after you restart it.",
    bindingsTip = "Share rebindable game and available addon actions. Actions from absent addons are kept for later. Protected changes wait until combat ends. Other keybinding managers may overwrite the same bindings.",
    windowsTip = "Share stock HUD and ping/FPS positions, chat windows and tabs (number, order, names, channel filters, locking, interactivity and background), and the small world map. Addon windows are excluded. Known geometry managers take priority, including OneFrame for HUD and OneMap for the map. When OneChat is loaded, also share its formatting, toolbar, guild abbreviations and per-tab incoming/outgoing channel preferences. ESO cannot identify every external window owner: unknown movers can conflict. Fixed scene layouts and automatic content sizes are excluded.",
    addonsTip = "Share enabled and disabled addons. While this character is active, changes are written in advance to the other existing characters' configurations, so their next login can load the new set directly. If a configuration still differs at login, or a preset changes the currently loaded set, the UI may reload automatically once. OneSettings itself is excluded from synchronization. Characters with OneSettings disabled are skipped; when re-enabled, they receive the shared configuration. Other managers and character-select changes can overwrite prepared configurations.",
    save = "Save", load = "Load", rename = "Rename", delete = "Delete", cancel = "Cancel",
    saveTitle = "Save addon preset", renameTitle = "Rename addon preset", loadTitle = "Load addon preset",
    presetName = "Preset name", noPresets = "No saved presets",
    invalidName = "Enter a name without line breaks or the | character.",
    duplicateName = "A preset with that name already exists.", missingPreset = "This preset no longer exists.",
    missingComponents = "Unavailable or outdated components: %s. Missing components were skipped; their entries remain in the preset.",
}
en.addonsTip = en.addonsTip .. " Disabling a base addon also disables its mandatory dependent modules. Enabling a module enables its required base addon."
local language = GetCVar("language.2")
local selected
if language == "ru" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "Требуется перезагрузка интерфейса", reloadNow = "Перезагрузить", reloadLater = "Позже",
    reloadWarning = "Изменение набора аддонов может потребовать перезагрузки интерфейса. Она будет предложена после выхода из настроек аддонов. При выборе «Позже» изменения сохранятся до следующей перезагрузки или входа.",
    settings = "Настройки игры", bindings = "Назначения клавиш", windows = "Окна", addons = "Аддоны",
    settingsTip = "Общие доступные настройки стандартного меню игры, включая шрифт, прозрачность и цвета каналов чата. Первый персонаж становится источником; последующие изменения становятся общими. Сервисы аккаунта и недоступные аддонам настройки исключены. Параметры, требующие перезапуска игры, вступят в силу после её перезапуска.",
    bindingsTip = "Общие изменяемые привязки игры и доступных действий аддонов. Действия отсутствующих аддонов сохраняются на будущее. Защищённые изменения откладываются до выхода из боя. Другие менеджеры клавиш могут перезаписать те же привязки.",
    windowsTip = "Общие позиции штатных элементов HUD и индикатора пинга/FPS, положение и размеры окон чата, количество, порядок, названия и настройки вкладок (каналы, блокировка, интерактивность), фон окон и небольшая карта мира. Окна аддонов исключены. Известные менеджеры геометрии имеют приоритет, включая OneFrame для HUD и OneMap для карты. При загруженном OneChat также переносятся его оформление, кнопки, сокращения гильдий и входящие/исходящие каналы каждой вкладки. ESO не позволяет определить всех внешних владельцев окон: с неизвестными менеджерами возможны конфликты. Фиксированные окна сцен и автоматические размеры содержимого исключены.",
    addonsTip = "Общий список включённых и отключённых аддонов. Пока текущий персонаж активен, изменения заранее записываются в конфигурации остальных существующих персонажей, чтобы при следующем входе сразу загрузился новый набор. Если при входе конфигурация всё же отличается или пресет меняет текущий загруженный набор, интерфейс может автоматически перезагрузиться один раз. Сам OneSettings исключён из синхронизации. Персонажи с отключённым OneSettings пропускаются; после повторного включения они получают общую конфигурацию. Другие менеджеры и изменения на экране выбора персонажа могут перезаписать подготовленные конфигурации.",
    save = "Сохранить", load = "Загрузить", rename = "Переименовать", delete = "Удалить", cancel = "Отмена",
    saveTitle = "Сохранить пресет аддонов", renameTitle = "Переименовать пресет", loadTitle = "Загрузить пресет аддонов",
    presetName = "Название пресета", noPresets = "Нет сохранённых пресетов",
    invalidName = "Введите название без переноса строки и символа |.",
    duplicateName = "Пресет с таким названием уже существует.", missingPreset = "Этот пресет больше не существует.",
    missingComponents = "Недоступные или устаревшие компоненты: %s. Отсутствующие компоненты пропущены; записи сохранены в пресете.",
}
selected.addonsTip = selected.addonsTip .. " Отключение основного аддона также отключает его обязательные зависимые модули. Включение модуля включает необходимый основной аддон."
elseif language == "de" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "Neuladen der Benutzeroberfläche erforderlich", reloadNow = "UI neu laden", reloadLater = "Später",
    reloadWarning = "Änderungen an der Addon-Auswahl können ein Neuladen der Benutzeroberfläche erfordern. Es erfolgt erst, nachdem Ihr die Addon-Einstellungen verlassen und das Neuladen bestätigt habt. Mit Später bleiben Eure Änderungen bis zum nächsten Neuladen oder Einloggen gespeichert.",
    settings = "Spieleinstellungen", bindings = "Tastenbelegung", windows = "Fenster", addons = "Addons",
    settingsTip = "Teilt die zugänglichen Einstellungen des normalen Spielmenüs, einschließlich Schriftgröße, Transparenz und Kanalfarben des Chats. Der erste Charakter dient als Quelle; spätere Änderungen werden gemeinsam übernommen. Kontodienste und für Addons unzugängliche Einstellungen sind ausgeschlossen. Einstellungen, die einen Spielneustart erfordern, werden nach dem Neustart wirksam.",
    bindingsTip = "Teilt änderbare Tastenbelegungen des Spiels und verfügbarer Addon-Aktionen. Aktionen fehlender Addons bleiben für später gespeichert. Geschützte Änderungen warten bis zum Ende des Kampfes. Andere Addons zur Tastenverwaltung können dieselben Belegungen überschreiben.",
    windowsTip = "Teilt die Positionen der normalen HUD- und Ping/FPS-Anzeigen, Chatfenster und deren Reiter (Anzahl, Reihenfolge, Namen, Kanalfilter, Sperre, Interaktivität und Hintergrund) sowie die kleine Weltkarte. Addon-Fenster sind ausgeschlossen. Bekannte Addons zur Fensterverwaltung haben Vorrang, darunter OneFrame für das HUD und OneMap für die Karte. Ist OneChat geladen, werden auch dessen Formatierung, Symbolleiste, Gildenabkürzungen und die Einstellungen für eingehende und ausgehende Kanäle jedes Reiters geteilt. ESO kann nicht alle externen Fensterverwalter erkennen; unbekannte können Konflikte verursachen. Feste Szenenanordnungen und automatisch vom Inhalt bestimmte Größen sind ausgeschlossen.",
    addonsTip = "Teilt aktivierte und deaktivierte Addons. Solange dieser Charakter aktiv ist, werden Änderungen vorab in die Konfigurationen der anderen vorhandenen Charaktere geschrieben, damit beim nächsten Einloggen die neue Auswahl geladen werden kann. Weicht eine Konfiguration beim Einloggen noch ab oder ändert eine Vorlage die aktuell geladene Auswahl, kann die Benutzeroberfläche einmal automatisch neu geladen werden. OneSettings selbst ist von der Synchronisierung ausgeschlossen. Charaktere mit deaktiviertem OneSettings werden übersprungen; nach erneuter Aktivierung erhalten sie die gemeinsame Konfiguration. Andere Addon-Verwalter und Änderungen bei der Charakterauswahl können vorbereitete Konfigurationen überschreiben. Das Deaktivieren eines Basis-Addons deaktiviert auch dessen zwingend abhängige Module. Das Aktivieren eines Moduls aktiviert das benötigte Basis-Addon.",
    save = "Speichern", load = "Laden", rename = "Umbenennen", delete = "Löschen", cancel = "Abbrechen",
    saveTitle = "Addon-Vorlage speichern", renameTitle = "Addon-Vorlage umbenennen", loadTitle = "Addon-Vorlage laden",
    presetName = "Name der Vorlage", noPresets = "Keine gespeicherten Vorlagen",
    invalidName = "Gebt einen Namen ohne Zeilenumbrüche oder das Zeichen | ein.",
    duplicateName = "Eine Vorlage mit diesem Namen ist bereits vorhanden.", missingPreset = "Diese Vorlage ist nicht mehr vorhanden.",
    missingComponents = "Nicht verfügbare oder veraltete Komponenten: %s. Fehlende Komponenten wurden übersprungen; ihre Einträge bleiben in der Vorlage gespeichert.",
}
elseif language == "fr" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "Rechargement de l’interface requis", reloadNow = "Recharger l’interface", reloadLater = "Plus tard",
    reloadWarning = "Modifier la sélection d’extensions peut nécessiter de recharger l’interface. Le rechargement attendra que vous quittiez les réglages des extensions et le confirmiez. Choisir Plus tard conserve vos modifications jusqu’au prochain rechargement ou à la prochaine connexion.",
    settings = "Réglages du jeu", bindings = "Raccourcis clavier", windows = "Fenêtres", addons = "Extensions",
    settingsTip = "Partage les réglages accessibles du menu standard du jeu, dont la taille de police, l’opacité et les couleurs des canaux de discussion. Le premier personnage sert de source ; les modifications suivantes deviennent communes. Les services du compte et les réglages inaccessibles aux extensions sont exclus. Les réglages nécessitant un redémarrage du jeu prennent effet après celui-ci.",
    bindingsTip = "Partage les raccourcis modifiables du jeu et des actions d’extensions disponibles. Les actions des extensions absentes sont conservées pour plus tard. Les modifications protégées attendent la fin du combat. D’autres gestionnaires de raccourcis peuvent écraser ces mêmes affectations.",
    windowsTip = "Partage la position des éléments standard de l’ATH et des indicateurs de latence/FPS, les fenêtres et onglets de discussion (nombre, ordre, noms, filtres de canaux, verrouillage, interactivité et fond), ainsi que la petite carte du monde. Les fenêtres des extensions sont exclues. Les gestionnaires de position connus sont prioritaires, dont OneFrame pour l’ATH et OneMap pour la carte. Si OneChat est chargé, partage aussi sa mise en forme, sa barre d’outils, ses abréviations de guildes et les préférences de canaux entrants et sortants de chaque onglet. ESO ne peut pas identifier tous les gestionnaires externes : les gestionnaires inconnus peuvent entrer en conflit. Les dispositions fixes des scènes et les dimensions calculées automatiquement selon le contenu sont exclues.",
    addonsTip = "Partage les extensions activées et désactivées. Tant que ce personnage est actif, les modifications sont écrites à l’avance dans les configurations des autres personnages existants pour charger directement la nouvelle sélection à leur prochaine connexion. Si une configuration diffère encore à la connexion, ou si un préréglage modifie la sélection actuellement chargée, l’interface peut être rechargée automatiquement une fois. OneSettings lui-même est exclu de la synchronisation. Les personnages pour lesquels OneSettings est désactivé sont ignorés ; à sa réactivation, ils reçoivent la configuration commune. D’autres gestionnaires et les modifications à l’écran de sélection des personnages peuvent écraser les configurations préparées. Désactiver une extension de base désactive aussi les modules qui en dépendent obligatoirement. Activer un module active l’extension de base requise.",
    save = "Enregistrer", load = "Charger", rename = "Renommer", delete = "Supprimer", cancel = "Annuler",
    saveTitle = "Enregistrer un préréglage", renameTitle = "Renommer un préréglage", loadTitle = "Charger un préréglage",
    presetName = "Nom du préréglage", noPresets = "Aucun préréglage enregistré",
    invalidName = "Saisissez un nom sans saut de ligne ni caractère |.",
    duplicateName = "Un préréglage portant ce nom existe déjà.", missingPreset = "Ce préréglage n’existe plus.",
    missingComponents = "Composants indisponibles ou obsolètes : %s. Les composants manquants ont été ignorés ; leurs entrées restent dans le préréglage.",
}
elseif language == "es" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "Es necesario recargar la interfaz", reloadNow = "Recargar interfaz", reloadLater = "Más tarde",
    reloadWarning = "Cambiar la selección de complementos puede requerir recargar la interfaz. Se esperará a que salgas de los ajustes de complementos y confirmes la recarga. Si eliges Más tarde, los cambios se conservarán hasta la próxima recarga o inicio de sesión.",
    settings = "Ajustes del juego", bindings = "Asignación de teclas", windows = "Ventanas", addons = "Complementos",
    settingsTip = "Comparte los ajustes accesibles del menú estándar del juego, incluidos el tamaño de letra, la opacidad y los colores de los canales del chat. El primer personaje es la fuente; los cambios posteriores se comparten. Se excluyen los servicios de la cuenta y los ajustes inaccesibles para los complementos. Los ajustes que requieren reiniciar el juego se aplican tras reiniciarlo.",
    bindingsTip = "Comparte las asignaciones de teclas modificables del juego y de las acciones disponibles de los complementos. Las acciones de complementos ausentes se conservan para más adelante. Los cambios protegidos esperan hasta que termine el combate. Otros gestores de teclas pueden sobrescribir las mismas asignaciones.",
    windowsTip = "Comparte las posiciones del HUD estándar y de los indicadores de latencia/FPS, las ventanas y pestañas del chat (cantidad, orden, nombres, filtros de canales, bloqueo, interactividad y fondo) y el mapa del mundo pequeño. Se excluyen las ventanas de los complementos. Los gestores de posición conocidos tienen prioridad, incluidos OneFrame para el HUD y OneMap para el mapa. Si OneChat está cargado, también comparte su formato, barra de herramientas, abreviaturas de gremios y preferencias de canales entrantes y salientes de cada pestaña. ESO no puede identificar todos los gestores externos: los desconocidos pueden causar conflictos. Se excluyen las disposiciones fijas de las escenas y los tamaños calculados automáticamente según el contenido.",
    addonsTip = "Comparte los complementos activados y desactivados. Mientras este personaje está activo, los cambios se escriben por adelantado en las configuraciones de los demás personajes existentes para que carguen la nueva selección al iniciar sesión. Si una configuración aún difiere al entrar, o si un preajuste cambia la selección actualmente cargada, la interfaz puede recargarse automáticamente una vez. OneSettings queda excluido de la sincronización. Se omiten los personajes con OneSettings desactivado; al reactivarlo, reciben la configuración compartida. Otros gestores y los cambios en la selección de personajes pueden sobrescribir las configuraciones preparadas. Desactivar un complemento base también desactiva los módulos que dependen obligatoriamente de él. Activar un módulo activa el complemento base necesario.",
    save = "Guardar", load = "Cargar", rename = "Renombrar", delete = "Eliminar", cancel = "Cancelar",
    saveTitle = "Guardar preajuste", renameTitle = "Renombrar preajuste", loadTitle = "Cargar preajuste",
    presetName = "Nombre del preajuste", noPresets = "No hay preajustes guardados",
    invalidName = "Introduce un nombre sin saltos de línea ni el carácter |.",
    duplicateName = "Ya existe un preajuste con ese nombre.", missingPreset = "Este preajuste ya no existe.",
    missingComponents = "Componentes no disponibles o desactualizados: %s. Se han omitido los componentes ausentes; sus entradas se conservan en el preajuste.",
}
elseif language == "jp" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "UIの再読み込みが必要です", reloadNow = "UIを再読み込み", reloadLater = "後で",
    reloadWarning = "アドオンの構成を変更すると、UIの再読み込みが必要になる場合があります。アドオン設定を閉じて再読み込みを確認するまで実行されません。「後で」を選ぶと、変更は次の再読み込みまたはログインまで保存されます。",
    settings = "ゲーム設定", bindings = "キー割り当て", windows = "ウィンドウ", addons = "アドオン",
    settingsTip = "標準のゲームメニューから取得できる設定を共有します。チャットの文字サイズ、透明度、チャンネルの色も含まれます。最初のキャラクターの設定が共有元となり、その後の変更も共有されます。アカウントサービスやアドオンからアクセスできない設定は対象外です。ゲームの再起動が必要な設定は、再起動後に反映されます。",
    bindingsTip = "ゲームおよび利用可能なアドオンの、変更可能なキー割り当てを共有します。未導入のアドオンのアクションも後で使えるように保持されます。保護された変更は戦闘終了まで保留されます。他のキー管理アドオンが同じ割り当てを上書きする場合があります。",
    windowsTip = "標準HUDと遅延・FPS表示の位置、チャットのウィンドウとタブ（数、順序、名前、チャンネルフィルター、ロック、操作可否、背景）、小型ワールドマップを共有します。アドオン独自のウィンドウは対象外です。既知の配置管理アドオンが優先され、HUDではOneFrame、マップではOneMapなどが該当します。OneChatが読み込まれている場合は、表示形式、ツールバー、ギルドの略称、各タブの受信・送信チャンネル設定も共有します。ESOはすべての外部配置管理アドオンを識別できないため、未知のものと競合する場合があります。シーン固定の配置や内容に応じて自動決定されるサイズは対象外です。",
    addonsTip = "アドオンの有効・無効状態を共有します。このキャラクターでプレイしている間、他の既存キャラクターの設定にも変更を事前に書き込み、次のログインで新しい構成を読み込めるようにします。ログイン時に設定が一致しない場合や、プリセットで現在読み込まれている構成を変更した場合、UIが自動で1回再読み込みされることがあります。OneSettings自体は同期対象外です。OneSettingsが無効なキャラクターは対象から除外され、再び有効にすると共有設定が適用されます。他の管理アドオンやキャラクター選択画面での変更により、準備済みの設定が上書きされる場合があります。基幹アドオンを無効にすると、それを必須とするモジュールも無効になります。モジュールを有効にすると、必要な基幹アドオンも有効になります。",
    save = "保存", load = "読み込み", rename = "名前変更", delete = "削除", cancel = "キャンセル",
    saveTitle = "アドオンのプリセットを保存", renameTitle = "プリセットの名前変更", loadTitle = "アドオンのプリセットを読み込み",
    presetName = "プリセット名", noPresets = "保存済みプリセットはありません",
    invalidName = "改行や | を含まない名前を入力してください。",
    duplicateName = "同じ名前のプリセットが既に存在します。", missingPreset = "このプリセットは既に削除されています。",
    missingComponents = "利用できない、または古いコンポーネント: %s。未導入のコンポーネントはスキップされましたが、その項目はプリセットに保持されます。",
}
elseif language == "zh" then
selected = {
    reloadTooltip = "Reload UI required",
    reloadTitle = "需要重新加载界面", reloadNow = "重新加载界面", reloadLater = "稍后",
    reloadWarning = "更改插件组合可能需要重新加载界面。系统会等到你关闭插件设置并确认后再重新加载。选择“稍后”会保留更改，直到下次重新加载或登录。",
    settings = "游戏设置", bindings = "按键绑定", windows = "窗口", addons = "插件",
    settingsTip = "共享标准游戏菜单中可访问的设置，包括聊天字体大小、透明度和频道颜色。首个角色作为设置来源，后续更改也会共享。不包括账号服务及插件无法访问的设置。需要重启游戏的设置会在重启后生效。",
    bindingsTip = "共享游戏和可用插件操作中可修改的按键绑定。未安装插件的操作会保留以供日后使用。受保护的更改会等到战斗结束后应用。其他按键管理插件可能会覆盖相同的绑定。",
    windowsTip = "共享默认HUD与延迟/FPS指示器的位置、聊天窗口和标签页（数量、顺序、名称、频道过滤、锁定、交互和背景），以及小型世界地图。不包括插件自身的窗口。已知的布局管理插件具有优先权，例如管理HUD的OneFrame和管理地图的OneMap。加载OneChat时，还会共享其格式、工具栏、公会简称以及各标签页的接收和发送频道偏好。ESO无法识别所有外部窗口管理插件，未知插件可能产生冲突。不包括场景固定布局以及根据内容自动计算的尺寸。",
    addonsTip = "共享插件的启用和禁用状态。当前角色在线时，更改会预先写入其他现有角色的配置，以便它们下次登录时直接加载新的插件组合。如果登录时配置仍不一致，或预设更改了当前已加载的组合，界面可能会自动重新加载一次。OneSettings自身不参与同步。禁用了OneSettings的角色会被跳过，重新启用后会应用共享配置。其他管理插件和角色选择界面中的更改可能覆盖预先准备的配置。禁用基础插件也会禁用以其为必需依赖的模块。启用模块时会同时启用所需的基础插件。",
    save = "保存", load = "加载", rename = "重命名", delete = "删除", cancel = "取消",
    saveTitle = "保存插件预设", renameTitle = "重命名插件预设", loadTitle = "加载插件预设",
    presetName = "预设名称", noPresets = "没有已保存的预设",
    invalidName = "请输入不含换行或 | 字符的名称。",
    duplicateName = "已存在同名预设。", missingPreset = "此预设已不存在。",
    missingComponents = "不可用或过时的组件：%s。已跳过缺失的组件，其条目仍保留在预设中。",
}
end
OS.strings = selected or en

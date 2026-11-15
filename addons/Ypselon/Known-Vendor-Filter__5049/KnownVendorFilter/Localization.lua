KnownVendorFilter = KnownVendorFilter or {}

-- Keys are shared by the merchant, bank and both settings interfaces.
-- English is the fallback for unknown languages or missing translations.
local translations = {
    en = {
        on = "Hide known: ON", off = "Hide known: OFF", options = "Filter options",
        title = "Known Vendor Filter – Options", description = "Hide these known items:", close = "Close",
        note = "Applies to merchants, bank and guild traders. Filters are separate.",
        recipes = "Food and drink recipes", plans = "Furnishing plans", motifs = "Crafting motifs",
        stylePages = "Outfit style pages", scribing = "Scribing: grimoires and scripts",
        collectibles = "Collectibles and runeboxes", sets = "Collected set items",
        guildShow = "Show guild trader buttons", guildCompatibility = "Guild trader buttons are hidden while AwesomeGuildStore is active.",
        buttonsTitle = "Buttons and position", storeShow = "Show merchant buttons", bankShow = "Show bank buttons", positionHint = "While these options are open, drag the buttons to move them. /kvf opens options.", resetPositions = "Reset positions",
    },
    de = {
        on = "Bekannte ausblenden: AN", off = "Bekannte ausblenden: AUS", options = "Filteroptionen",
        title = "Known Vendor Filter – Optionen", description = "Diese bekannten Gegenstände ausblenden:", close = "Schließen",
        note = "Die Auswahl gilt für Händler, Bank und Gildenhändler. Filter einzeln aktivieren.",
        recipes = "Rezepte für Essen und Getränke", plans = "Einrichtungspläne", motifs = "Handwerksstile",
        stylePages = "Monturstilseiten", scribing = "Schriftlehre: Grimoires und Skripte",
        collectibles = "Sammlungsstücke und Runenkisten", sets = "Gesammelte Setbuch-Gegenstände",
        guildShow = "Schaltflächen beim Gildenhändler anzeigen", guildCompatibility = "Bei aktivem AwesomeGuildStore werden die Gildenhändler-Schaltflächen ausgeblendet.",
        buttonsTitle = "Schaltflächen und Position", storeShow = "Schaltflächen beim Händler anzeigen", bankShow = "Schaltflächen bei der Bank anzeigen", positionHint = "Solange dieses Fenster offen ist, kannst du die Schaltflächen verschieben. /kvf öffnet die Optionen.", resetPositions = "Positionen zurücksetzen",
    },
    fr = {
        on = "Masquer les connus : OUI", off = "Masquer les connus : NON", options = "Options du filtre",
        title = "Known Vendor Filter – Options", description = "Masquer ces objets connus :", close = "Fermer",
        note = "Choix commun aux marchands, marchands de guilde et à la banque. Filtres indépendants.",
        recipes = "Recettes de cuisine et de boissons", plans = "Plans d'ameublement", motifs = "Motifs d'artisanat",
        stylePages = "Pages de style de tenue", scribing = "Écriture : grimoires et inscriptions",
        collectibles = "Objets de collection et boîtes runiques", sets = "Objets d'ensemble déjà collectionnés",
        guildShow = "Afficher les boutons du marchand de guilde", guildCompatibility = "Boutons masqués lorsque AwesomeGuildStore est activé.",
        buttonsTitle = "Boutons et position", storeShow = "Afficher les boutons du marchand", bankShow = "Afficher les boutons de la banque", positionHint = "Déplacez les boutons pendant que ces options sont ouvertes. /kvf ouvre les options.", resetPositions = "Réinitialiser les positions",
    },
    es = {
        on = "Ocultar conocidos: SÍ", off = "Ocultar conocidos: NO", options = "Opciones del filtro",
        title = "Known Vendor Filter – Opciones", description = "Ocultar estos objetos conocidos:", close = "Cerrar",
        note = "Selección común para mercaderes, gremios y banco. Filtros independientes.",
        recipes = "Recetas de comida y bebida", plans = "Planos de mobiliario", motifs = "Estilos de artesanía",
        stylePages = "Páginas de estilo de atuendo", scribing = "Escribanía: grimorios y escrituras",
        collectibles = "Coleccionables y cajas de runas", sets = "Piezas de conjunto ya coleccionadas",
        guildShow = "Mostrar botones del mercader de gremio", guildCompatibility = "Los botones se ocultan si AwesomeGuildStore está activo.",
        buttonsTitle = "Botones y posición", storeShow = "Mostrar botones del mercader", bankShow = "Mostrar botones del banco", positionHint = "Arrastra los botones mientras estén abiertas las opciones. /kvf abre las opciones.", resetPositions = "Restablecer posiciones",
    },
    ru = {
        on = "Скрывать известное: ДА", off = "Скрывать известное: НЕТ", options = "Настройки фильтра",
        title = "Known Vendor Filter – Настройки", description = "Скрывать известные предметы:", close = "Закрыть",
        note = "Общий выбор для торговцев, гильдии и банка. Фильтры включаются отдельно.",
        recipes = "Рецепты еды и напитков", plans = "Чертежи мебели", motifs = "Ремесленные стили",
        stylePages = "Страницы стилей нарядов", scribing = "Начертание: гримуары и надписи",
        collectibles = "Коллекционные предметы и рунные шкатулки", sets = "Собранные предметы комплектов",
        guildShow = "Показывать кнопки у гильдейского торговца", guildCompatibility = "Кнопки скрыты, если активен AwesomeGuildStore.",
        buttonsTitle = "Кнопки и положение", storeShow = "Показывать кнопки у торговца", bankShow = "Показывать кнопки в банке", positionHint = "Перетаскивайте кнопки при открытых настройках. /kvf открывает настройки.", resetPositions = "Сбросить положение",
    },
    jp = {
        on = "習得済みを隠す: オン", off = "習得済みを隠す: オフ", options = "フィルター設定",
        title = "Known Vendor Filter – 設定", description = "習得・入手済みの次のアイテムを隠す:", close = "閉じる",
        note = "商人、ギルド商人、銀行で項目を共有し、個別に切り替えます。",
        recipes = "食べ物・飲み物のレシピ", plans = "家具の設計図", motifs = "クラフトモチーフ",
        stylePages = "衣装スタイルのページ", scribing = "書記: グリモアとスクリプト",
        collectibles = "収集品とルーンボックス", sets = "登録済みのセット装備",
        guildShow = "ギルド商人にボタンを表示", guildCompatibility = "AwesomeGuildStoreの使用中はボタンが非表示になります。",
        buttonsTitle = "ボタンと位置", storeShow = "商人のボタンを表示", bankShow = "銀行のボタンを表示", positionHint = "設定を開いている間はボタンを移動できます。/kvf で設定を開きます。", resetPositions = "位置をリセット",
    },
    zh = {
        on = "隐藏已知物品：开", off = "隐藏已知物品：关", options = "筛选选项",
        title = "Known Vendor Filter – 选项", description = "隐藏以下已知或已收集的物品：", close = "关闭",
        note = "商人、公会商人与银行共用选项，筛选开关分别控制。",
        recipes = "食物与饮品配方", plans = "家具设计图", motifs = "工艺风格书",
        stylePages = "外观风格页", scribing = "抄写：魔典与手稿",
        collectibles = "收藏品与符文箱", sets = "已收集的套装物品",
        guildShow = "在公会商人处显示按钮", guildCompatibility = "启用 AwesomeGuildStore 时隐藏公会商人按钮。",
        buttonsTitle = "按钮与位置", storeShow = "显示商人按钮", bankShow = "显示银行按钮", positionHint = "选项窗口打开时可拖动按钮。输入 /kvf 可打开选项。", resetPositions = "重置位置",
    },
}

function KnownVendorFilter:GetTranslation(clientLanguage)
    local code = type(clientLanguage) == "string" and clientLanguage:lower():match("^[a-z]+") or "en"
    if code == "ja" then code = "jp" end
    local chosen = translations[code] or translations.en
    local result = {}
    for key, fallback in pairs(translations.en) do result[key] = chosen[key] or fallback end
    return result
end

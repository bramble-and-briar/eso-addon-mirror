KnownVendorFilter = KnownVendorFilter or {}

-- Keys are shared by the merchant, bank and both settings interfaces.
-- English is the fallback for unknown languages or missing translations.
local translations = {
    en = {
        on = "Hide known: ON", off = "Hide known: OFF", options = "Filter options",
        title = "Known Vendor Filter – Options", description = "Hide these known items:", close = "Close",
        note = "Applies to merchant and bank. Enable each filter separately.",
        recipes = "Food and drink recipes", plans = "Furnishing plans", motifs = "Crafting motifs",
        stylePages = "Outfit style pages", scribing = "Scribing: grimoires and scripts",
        collectibles = "Collectibles and runeboxes", sets = "Collected set items",
    },
    de = {
        on = "Bekannte ausblenden: AN", off = "Bekannte ausblenden: AUS", options = "Filteroptionen",
        title = "Known Vendor Filter – Optionen", description = "Diese bekannten Gegenstände ausblenden:", close = "Schließen",
        note = "Die Auswahl gilt für Händler und Bank. Filter einzeln aktivieren.",
        recipes = "Rezepte für Essen und Getränke", plans = "Einrichtungspläne", motifs = "Handwerksstile",
        stylePages = "Monturstilseiten", scribing = "Schriftlehre: Grimoires und Skripte",
        collectibles = "Sammlungsstücke und Runenkisten", sets = "Gesammelte Setbuch-Gegenstände",
    },
    fr = {
        on = "Masquer les connus : OUI", off = "Masquer les connus : NON", options = "Options du filtre",
        title = "Known Vendor Filter – Options", description = "Masquer ces objets connus :", close = "Fermer",
        note = "Même choix pour la banque et les marchands. Filtres indépendants.",
        recipes = "Recettes de cuisine et de boissons", plans = "Plans d'ameublement", motifs = "Motifs d'artisanat",
        stylePages = "Pages de style de tenue", scribing = "Écriture : grimoires et inscriptions",
        collectibles = "Objets de collection et boîtes runiques", sets = "Objets d'ensemble déjà collectionnés",
    },
    es = {
        on = "Ocultar conocidos: SÍ", off = "Ocultar conocidos: NO", options = "Opciones del filtro",
        title = "Known Vendor Filter – Opciones", description = "Ocultar estos objetos conocidos:", close = "Cerrar",
        note = "La selección vale para banco y mercader. Filtros independientes.",
        recipes = "Recetas de comida y bebida", plans = "Planos de mobiliario", motifs = "Estilos de artesanía",
        stylePages = "Páginas de estilo de atuendo", scribing = "Escribanía: grimorios y escrituras",
        collectibles = "Coleccionables y cajas de runas", sets = "Piezas de conjunto ya coleccionadas",
    },
    ru = {
        on = "Скрывать известное: ДА", off = "Скрывать известное: НЕТ", options = "Настройки фильтра",
        title = "Known Vendor Filter – Настройки", description = "Скрывать известные предметы:", close = "Закрыть",
        note = "Выбор общий для торговца и банка. Фильтры включаются отдельно.",
        recipes = "Рецепты еды и напитков", plans = "Чертежи мебели", motifs = "Ремесленные стили",
        stylePages = "Страницы стилей нарядов", scribing = "Начертание: гримуары и надписи",
        collectibles = "Коллекционные предметы и рунные шкатулки", sets = "Собранные предметы комплектов",
    },
    jp = {
        on = "習得済みを隠す: オン", off = "習得済みを隠す: オフ", options = "フィルター設定",
        title = "Known Vendor Filter – 設定", description = "習得・入手済みの次のアイテムを隠す:", close = "閉じる",
        note = "項目の選択は商人と銀行で共通です。各フィルターは個別に切り替えます。",
        recipes = "食べ物・飲み物のレシピ", plans = "家具の設計図", motifs = "クラフトモチーフ",
        stylePages = "衣装スタイルのページ", scribing = "書記: グリモアとスクリプト",
        collectibles = "収集品とルーンボックス", sets = "登録済みのセット装備",
    },
    zh = {
        on = "隐藏已知物品：开", off = "隐藏已知物品：关", options = "筛选选项",
        title = "Known Vendor Filter – 选项", description = "隐藏以下已知或已收集的物品：", close = "关闭",
        note = "商人与银行共用选项，但筛选开关可分别控制。",
        recipes = "食物与饮品配方", plans = "家具设计图", motifs = "工艺风格书",
        stylePages = "外观风格页", scribing = "抄写：魔典与手稿",
        collectibles = "收藏品与符文箱", sets = "已收集的套装物品",
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

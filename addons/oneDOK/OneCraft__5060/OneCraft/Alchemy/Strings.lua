local A = OneCraft.Alchemy
local en = {
    level = "Level", effects = "Effects", choose = "Select up to three effects.",
    none = "No recipe produces exactly these effects with the available reagents.",
    solvent = "Select an available solvent.", locked = "Requires Solvent Proficiency %d",
    missing = "No solvent available", rejected = "The game's result does not match the selected effects.",
    ready = "Use the standard Create button.", unknown = "Some reagents cannot be verified and were excluded.",
    conflict = "OneCraft: another addon changed the selected materials. Select the recipe again.",
    count = "%d available", page = "%d/%d", levelFormat = "Level %d", cpFormat = "CP %d",
    next = "Mouse wheel: more alternatives", unsupported = "OneCraft supports alchemy API 101051. Integration is disabled for this API version.",
    potion = "Potion", poison = "Poison", noDescription = "The game could not provide a description for this effect.",
    alternativeUnavailable = "This alternative is no longer available. The previous recipe was retained.",
}
local ru = {
    level = "Уровень", effects = "Эффекты", choose = "Выберите до трёх эффектов.",
    none = "Нет рецепта строго с выбранными эффектами из доступных реагентов.",
    solvent = "Выберите доступный растворитель.", locked = "Нужно владение растворителями: %d",
    missing = "Нет растворителя", rejected = "Результат игры не совпадает с выбранными эффектами.",
    ready = "Используйте стандартную кнопку создания.", unknown = "Непроверенные реагенты исключены из подбора.",
    conflict = "OneCraft: другой аддон изменил материалы. Выберите рецепт заново.",
    count = "В наличии: %d", page = "%d/%d", levelFormat = "Уровень %d", cpFormat = "ОГ %d",
    next = "Колесо мыши: другие варианты", unsupported = "OneCraft поддерживает API алхимии 101051. Для этой версии API интеграция отключена.",
    potion = "Зелье", poison = "Яд", noDescription = "Игра не предоставила описание этого эффекта.",
    alternativeUnavailable = "Этот вариант больше недоступен. Предыдущий рецепт сохранён.",
}
A.text = OneCraft.Localize(GetCVar("language.2") == "ru" and ru or en)

-- Fallback names only. Known trait names and icons come from the game.
A.effectNames = {
    RestoreHealth = {"Restore Health", "Восстановление здоровья"},
    RavageHealth = {"Ravage Health", "Опустошение здоровья"},
    RestoreMagicka = {"Restore Magicka", "Восстановление магии"},
    RavageMagicka = {"Ravage Magicka", "Опустошение магии"},
    RestoreStamina = {"Restore Stamina", "Восстановление запаса сил"},
    RavageStamina = {"Ravage Stamina", "Опустошение запаса сил"},
    IncreaseSpellResist = {"Increase Spell Resist", "Повышение сопротивления заклинаниям"},
    Breach = {"Breach", "Брешь"}, IncreaseArmor = {"Increase Armor", "Повышение брони"},
    Fracture = {"Fracture", "Перелом"}, IncreasePower = {"Increase Power", "Повышение силы"},
    Cowardice = {"Cowardice", "Трусость"}, Critical = {"Critical", "Критический удар"},
    Uncertainty = {"Uncertainty", "Неуверенность"}, Force = {"Force", "Сила"},
    Enervation = {"Enervation", "Обессиливание"}, Unstoppable = {"Unstoppable", "Неудержимость"},
    Entrapment = {"Entrapment", "Обездвиживание"}, Detection = {"Detection", "Обнаружение"},
    Invisible = {"Invisibility", "Невидимость"}, Speed = {"Speed", "Скорость"},
    Hindrance = {"Hindrance", "Замедление"}, Protection = {"Protection", "Защита"},
    Vulnerability = {"Vulnerability", "Уязвимость"}, LingeringHealth = {"Lingering Health", "Длительное восстановление здоровья"},
    GradualRavageHealth = {"Gradual Ravage Health", "Постепенное опустошение здоровья"},
    Vitality = {"Vitality", "Живучесть"}, Defile = {"Defile", "Осквернение"},
    Heroism = {"Heroism", "Героизм"}, Timidity = {"Timidity", "Робость"},
    DamageShield = {"Damage Shield", "Щит"}, HealAbsorption = {"Heal Absorption", "Поглощение лечения"},
    Mending = {"Mending", "Исцеление"}, Vexation = {"Vexation", "Раздражение"},
}

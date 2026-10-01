local strings = {
    LOCKED_APPEARANCE = "Заблокировано в версии 1.0. Измените Core/Config.lua и перезагрузите интерфейс.",
    PRESET_LARGE_DOT = "Крупные точки (×5)",
    PRESET_RAYS = "Лучи", PRESET_DIAMONDS = "Ромбы", PRESET_ESO = "Стандартный ESO",
    PRESET_DOT = "Точка", NORMAL = "Обычный", TARGET = "Цель", BLOCK = "Блок",
    CROSSHAIR = "Прицел", PRESET = "Пресет", APPEARANCE = "Внешний вид",
    CROSSHAIR_OPACITY = "Непрозрачность прицела", HUD_OPACITY = "Непрозрачность HUD", HUD = "HUD",
    RESOURCES = "Ресурсы", GCD = "Глобальная перезарядка", VISIBILITY = "Видимость",
    ALWAYS = "Всегда", COMBAT_ONLY = "Только в бою", DYNAMIC = "Динамически", OFF = "Выключено",
    EFFECTS = "Эффекты", LOW_RESOURCE = "Предупреждение о низком ресурсе",
    SHIELD = "Щит", COMBAT_FEEDBACK = "Отклик на атаку",
    RESOURCE_GEOMETRY = "Геометрия ресурсов", RESOURCE_THICKNESS = "Толщина линий",
    RESOURCE_LENGTH = "Длина дуг (0–100%)", RESOURCE_RADIUS = "Радиус кольца",
}
for key, value in pairs(strings) do SafeAddString(_G["SI_ONECROSSHAIR_" .. key], value, 1) end

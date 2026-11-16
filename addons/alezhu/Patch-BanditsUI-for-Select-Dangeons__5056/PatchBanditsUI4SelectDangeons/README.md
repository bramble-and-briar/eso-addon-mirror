# PatchBanditsUI4SelectDangeons

Патч-аддон для **Bandits User Interface** (BUI) в игре The Elder Scrolls Online (ESO).

## Описание

В оригинальном Bandits User Interface присутствует кнопка **«Выбрать активные задания»**, которая выбирает подземелья с ежедневными обетами Неустрашимых. Однако сложность (обычная или ветеранская) в BUI жестко привязана к уровню персонажа: если у персонажа менее 160 CP — выбираются обычные, если 160 CP и более — ветеранские. Это неудобно, если игрок высокого уровня хочет пройти обеты на нормальной сложности.

**PatchBanditsUI4SelectDangeons решает эту проблему и добавляет новые возможности:**

1. **Выбор сложности по настройке группы:**
   - Кнопка **«Выбрать активные задания»** теперь выбирает сложность (обычная / ветеранская) строго в соответствии с тем, что выбрано в разделе **Группа** (Group menu).
   - Если в группе выбрана обычная сложность — выбираются обычные подземелья.
   - Если выбрана ветеранская — ветеранские.

2. **Новая кнопка «Непройденные»:**
   - Расположена рядом с кнопкой «Выбрать активные задания».
   - При нажатии выбирает **только непройденные сюжетные задания подземелий** (за которые дают очко навыков / Skill Point).
   - Автоматически учитывает купленные DLC и доступность: закрытые / не купленные подземелья пропускаются.
   - Учитывает выбранную сложность группы (обычная / ветеранская).
   - Очищает предыдущий выбор, чтобы были выбраны именно непройденные подземелья.

## Требования

- **The Elder Scrolls Online**
- Аддон **Bandits User Interface** (BanditsUI)

## Установка

1. Скопируйте папку `PatchBanditsUI4SelectDangeons` в директорию аддонов ESO:
   `Documents\Elder Scrolls Online\live\AddOns\` (или в папку OneDrive, если документы синхронизируются).
2. Запустите игру или введите в чате `/reloadui`.
3. В меню модификаций убедитесь, что включены **Bandits User Interface** и **PatchBanditsUI4SelectDangeons**.

## English Description

Patch addon for **Bandits User Interface** (BUI) in The Elder Scrolls Online:
- **Difficulty by Group Setting:** Changes the "Check active pledges" button to select Normal or Veteran pledges based on the difficulty chosen in the Group menu, rather than character Champion Points.
- **Uncompleted Quests Button:** Adds an "Uncompleted" button beside the pledges button to queue only for accessible dungeons where the story quest (skill point) has not yet been completed.

-- PithkaLocalizer.lua
local ADDON_NAME = "PithkaLocalizer"
local TARGET_ADDON = "PithkaAchievementTracker"

-----------------------------------------------------------------------------------------
-- 1. ЛОГИКА ПЕРЕВОДА
-----------------------------------------------------------------------------------------
local function applyTranslations()
    if not PITHKA or not PITHKA.data or not PITHKA.data.achievements then return false end
    local zoneMap = PithkaLocalizer and PithkaLocalizer.ZoneIdMap
    if not zoneMap then return false end

    local fields = {"NAME", "PHM1NAME", "PHM2NAME", "HMNAME", "TRINAME", "EXTNAME", "SRNAME", "NDNAME"}
    for _, ach in ipairs(PITHKA.data.achievements) do
        for _, field in ipairs(fields) do
            local orig = ach[field]
            if orig and zoneMap[orig] then
                ach[field] = zo_strformat(SI_ZONE_NAME, GetZoneNameById(zoneMap[orig]))
            end
        end
    end
    return true
end

-----------------------------------------------------------------------------------------
-- 2. ПОЛНАЯ ПОДМЕНА ИНТЕРФЕЙСА (ИСПРАВЛЕННАЯ)
-----------------------------------------------------------------------------------------
local function applyLayoutOverrides()
    local layout    = PITHKA.layout
    local constants = PITHKA.common.constants
    local ui        = PITHKA.ui
    local data      = PITHKA.data

    -- ПРАВИМ КОНСТАНТЫ ОКОН
    constants.screenDimensions.baseDungeons     = {750, 550}
    constants.screenDimensions.trifectaDungeons = {1045, 850}
    constants.screenDimensions.trials           = {1200, 500}
    constants.screenDimensions.scoresAndTris    = {1070, 850}

    -- TAB 1: Starter Dungeons
    PITHKA.views.baseDungeons.initialize = function()
        local baseDungeonScreen = nil
        local function populateBaseDungeonScreen()
            local function createHeader() 
                return { ui.label.basic{text="Dungeons with I/II", width=240, tooltipText="Click to Port"}, ui.label.basic{text="VET", tooltipText="Veteran"}, ui.label.basic{text="HM", tooltipText="Hard Mode"}, ui.label.basic{text="SR", tooltipText="Speed Run"}, ui.label.basic{text="ND", tooltipText="No Death"} }
            end
            local function createRowUI(row)
                -- ВАЖНО: vQueue должен быть row.vQueue, а не row.VET
                return { 
                    ui.label.teleport{text=row.NAME, width=240, tooltipText="Click to Port", vQueue=row.vQueue, nQueue=row.nQueue, portId=row.portID}, 
                    ui.icon.achievement(row.VET), ui.icon.achievement(row.HM), ui.icon.achievement(row.SR), ui.icon.achievement(row.ND) 
                }
            end
            local gridL = layout.grid.new(30,50); baseDungeonScreen:addObject(gridL); gridL:addRow(createHeader())
            for _, row in pairs(data.filterAchievements({TYPE='baseDungeon-wI'})) do gridL:addRow(createRowUI(row)) end
            local gridR = layout.grid.new(390,50); baseDungeonScreen:addObject(gridR); gridR:addRow(createHeader())
            for _, row in pairs(data.filterAchievements({TYPE='baseDungeon-noI'})) do gridR:addRow(createRowUI(row)) end
        end
        baseDungeonScreen = layout.screen.new(constants.textures.DUNGEON, 750, 550, 'Starter Dungeons', populateBaseDungeonScreen)
        return baseDungeonScreen
    end

    -- TAB 2: 4 Man Trifectas
    PITHKA.views.trifectaDungeons.initialize = function()
        local triDungeonScreen = nil
        local function populateTriDungeonScreen()
            local grid = layout.grid.new(30,50); triDungeonScreen:addObject(grid)
            grid:addRow{ ui.label.basic{text="TRIFECTA DUNGEONS", width=300, tooltipText="Click to Port"}, ui.label.basic{text="VET", tooltipText="Veteran"}, ui.other.spacer(20), ui.label.basic{text="HM", tooltipText="Hard Mode"}, ui.label.basic{text="SR", tooltipText="Speed Run"}, ui.label.basic{text="ND", tooltipText="No Death"}, ui.other.spacer(20), ui.label.basic{text="CHALLENGER & TRIFECTA", width=270}, ui.label.basic{text="EXTRAS", width=200} }
            local rows = data.filterAchievements({TYPE='triDungeon'}); table.insert(rows, data.filterAchievements({ABBV='BRP'}))
            for _, row in pairs(rows) do
                grid:addRow{ 
                    -- ВАЖНО: Тут тоже исправляем vQueue на row.vQueue
                    ui.label.teleport{text=row.NAME, width=300, tooltipText="Click to Port", vQueue=row.vQueue, nQueue=row.nQueue, portId=row.portID}, 
                    ui.icon.achievement(row.VET), ui.other.spacer(20), ui.icon.achievement(row.HM), ui.icon.achievement(row.SR), ui.icon.achievement(row.ND), ui.other.spacer(20), ui.icon.achievement(row.CHA), ui.icon.achievement(row.TRI), ui.label.achievement{text=row.TRINAME, width=220, AID=row.TRI}, ui.icon.achievement(row.EXT), ui.label.achievement{text=row.EXTNAME, width=200, AID=row.EXT} 
                }
            end
        end
        triDungeonScreen = layout.screen.new(constants.textures.INSTANCE, 1045, 850, '4 Man Trifectas', populateTriDungeonScreen)
        return triDungeonScreen
    end

    -- TAB 3: Trials (Триалы не имеют очередей LFG, только порт, поэтому vQueue/nQueue тут обычно nil)
    PITHKA.views.trials.initialize = function()
        local trialScreen = nil
        local function populateTrialScreen()
            local grid = layout.grid.new(30,50); trialScreen:addObject(grid)
            grid:addRow{ ui.label.basic{text="TRIALS", width=215, tooltipText="Click to Port"}, ui.label.basic{text="BEST SCORE", width=75, align=TEXT_ALIGN_RIGHT}, ui.other.spacer(20), ui.label.basic{text="VET", width=46, tooltipText="Veteran"}, ui.label.basic{text="PARTIAL HM", width=105}, ui.label.basic{text="PARTIAL HM", width=105}, ui.label.basic{text="HARDMODE", width=150}, ui.label.basic{text="TRIFECTA", width=215}, ui.label.basic{text="EXTRA", width=250} }
            for _, row in pairs(data.filterAchievements({TYPE='trial'})) do
                grid:addRow{ 
                    ui.label.teleport{text=row.NAME, width=215, tooltipText="Click to Port", portId=row.portID}, 
                    ui.label.score(row), ui.other.spacer(20), ui.icon.achievement(row.VET), ui.other.spacer(20), ui.icon.achievement(row.PHM1), ui.label.achievement{text=row.PHM1NAME, width=80, AID=row.PHM1}, ui.icon.achievement(row.PHM2), ui.label.achievement{text=row.PHM2NAME, width=80, AID=row.PHM2}, ui.icon.achievement(row.HM), ui.label.achievement{text=row.HMNAME, width=120, AID=row.HM}, ui.icon.achievement(row.TRI), ui.label.achievement{text=row.TRINAME, width=190, AID=row.TRI}, ui.icon.achievement(row.EXT), ui.label.achievement{text=row.EXTNAME, width=250, AID=row.EXT} 
                }
            end
        end
        trialScreen = layout.screen.new(constants.textures.TRIAL, 1200, 500, 'Trials', populateTrialScreen)
        return trialScreen
    end

    -- TAB 4: All Scores and Tris
    PITHKA.views.scoresAndTris.initialize = function()
        local allScoreScreen = nil
        local function populateAllTrifectasScreen()
            local leftGrid = layout.grid.new(30,50); allScoreScreen:addObject(leftGrid)
            leftGrid:addRow{ ui.label.basic{text="TRIALS", width=215, tooltipText="Click to Port"}, ui.label.basic{text="BEST SCORE", width=75, align=TEXT_ALIGN_RIGHT}, ui.other.spacer(20), ui.label.basic{text="TRIFECTA", width=215} }
            for _, row in pairs(data.filterAchievements({TYPE='trial'})) do
                leftGrid:addRow{ ui.label.teleport{text=row.NAME, width=215, tooltipText="Click to Port", portId=row.portID}, ui.label.score(row), ui.other.spacer(20), ui.icon.achievement(row.TRI), ui.label.achievement{text=row.TRINAME, width=190, AID=row.TRI} }
            end
            leftGrid:addRow{ui.other.spacer(20)}
            leftGrid:addRow{ ui.label.basic{text="ARENAS", width=235, tooltipText="Click to Port"}, ui.label.basic{text="BEST SCORE", width=75, align=TEXT_ALIGN_RIGHT}, ui.other.spacer(20), ui.label.basic{text="TRIFECTA", width=215} }
            for _, row in pairs(data.filterAchievements({TYPE='arena'})) do
                leftGrid:addRow{ ui.label.teleport{text=row.NAME, width=235, tooltipText="Click to Port", portId=row.portID}, ui.label.score(row), ui.other.spacer(20), ui.icon.achievement(row.TRI), ui.label.achievement{text=row.TRINAME, width=190, AID=row.TRI} }
            end
            leftGrid:addRow{ui.other.spacer(20)}
            leftGrid:addRow{ ui.label.basic{text="INFINITE ARCHIVE", width=155, tooltipText="Click to Port"} }
            for _, row in pairs(data.filterAchievements({TYPE='endless'})) do
                leftGrid:addRow{ ui.label.teleport{text=row.NAME, width=155, tooltipText="Click to Port", portId=row.portID}, ui.label.score(row), ui.other.spacer(20), ui.icon.achievement(row.TRI) }
            end
            local rightGrid = layout.grid.new(550,50); allScoreScreen:addObject(rightGrid)
            rightGrid:addRow{ ui.label.basic{text="TRIFECTA DUNGEONS", width=300, tooltipText="Click to Port"}, ui.label.basic{text="TRIFECTAS", width=270} }
            for _, row in pairs(data.filterAchievements({TYPE='triDungeon'})) do
                rightGrid:addRow{ ui.label.teleport{text=row.NAME, width=300, tooltipText="Click to Port", vQueue=row.vQueue, nQueue=row.nQueue, portId=row.portID}, ui.icon.achievement(row.TRI), ui.label.achievement{text=row.TRINAME, width=220, AID=row.TRI} }
            end
        end
        allScoreScreen = layout.screen.new(constants.textures.STAR, 1070, 850, 'All Scores and Tris', populateAllTrifectasScreen)
        return allScoreScreen
    end
end

-----------------------------------------------------------------------------------------
-- 3. ЗАПУСК
-----------------------------------------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    applyLayoutOverrides()

    zo_callLater(function()
        applyTranslations()
        -- d("|cFFFF00Pithka Localizer:|r Финальная версия (Очереди + Телепорт + Разметка) загружена.")
    end, 200)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
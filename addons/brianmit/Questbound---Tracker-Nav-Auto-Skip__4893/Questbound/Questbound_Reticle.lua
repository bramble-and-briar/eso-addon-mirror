-- Questbound_Reticle.lua : when your crosshair is on a monster one of your quests
-- wants dead, a small red quest badge with the count ("3 / 5") shows next to the
-- crosshair (like quest mobs in WoW / FFXIV). The game doesn't tell addons where
-- monsters are, but it does tell the name of what you aim at: that name is
-- matched against the open "kill" objectives of all your quests.

local W = Questbound
local L = W.L
local Reticle = {}
W.Reticle = Reticle

local NAME = "Questbound_Reticle"
local ui = {}
local objectives = {}   -- open kill objectives: { key = squashed text, cur, max }

local function Squash(text)
    return (zo_strlower(zo_strformat("<<1>>", text or "")):gsub("[^%w]", ""))
end

local function Collect()
    ZO_ClearTable(objectives)
    for qi = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(qi) then
            for step = 1, GetJournalQuestNumSteps(qi) do
                local _, visibility, _, _, numConditions = GetJournalQuestStepInfo(qi, step)
                if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
                    for cond = 1, numConditions or 0 do
                        local text, cur, max, isFail, isComplete, _, isVisible, conditionType = GetJournalQuestConditionInfo(qi, step, cond)
                        if text and text ~= "" and not isFail and not isComplete and isVisible ~= false
                            and W.Nav.IsKillCondition(conditionType) then
                            objectives[#objectives + 1] = { key = Squash(text), cur = cur, max = max }
                        end
                    end
                end
            end
        end
    end
end

-- Objective naming this monster ("Wolf" also matches "Kill Wolves").
local function Match(name)
    local key = Squash(name)
    if #key < 3 then return nil end
    local stem = #key >= 4 and key:sub(1, #key - 1) or key
    for _, o in ipairs(objectives) do
        if o.key:find(key, 1, true) or o.key:find(stem, 1, true) then return o end
    end
end

local function Update()
    if not ui.win then return end
    local show = false
    if W.sv.killBadge and DoesUnitExist("reticleover") and not IsUnitDead("reticleover")
        and IsUnitAttackable("reticleover") and W.TextureLoaded("badge_kill.dds") then
        local o = Match(GetUnitName("reticleover"))
        if o then
            show = true
            ui.count:SetText((o.max and o.max > 1) and string.format("%d / %d", o.cur or 0, o.max) or "")
        end
    end
    ui.box:SetHidden(not show)
end

function Reticle.Init()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Reticle")
    ui.win = win
    win:SetDimensions(120, 28)
    win:SetAnchor(LEFT, GuiRoot, CENTER, 26, -12)   -- just right of the crosshair
    win:SetMouseEnabled(false)
    ui.box = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.box:SetAnchorFill(win)
    ui.box:SetHidden(true)
    ui.badge = WINDOW_MANAGER:CreateControl(nil, ui.box, CT_TEXTURE)
    ui.badge:SetTexture(W.TEX .. "badge_kill.dds")
    ui.badge:SetDimensions(22, 22)
    ui.badge:SetAnchor(LEFT, ui.box, LEFT, 0, 0)
    ui.count = WINDOW_MANAGER:CreateControl(nil, ui.box, CT_LABEL)
    ui.count:SetFont(W.Font("title", 14))
    ui.count:SetColor(0.94, 0.82, 0.66, 1)
    ui.count:SetAnchor(LEFT, ui.badge, RIGHT, 5, 1)
    W.HudFragment(win)

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, Update)
    W.callbacks:RegisterCallback("QuestsChanged", function()
        Collect()
        Update()
    end)
    W.callbacks:RegisterCallback("SettingsChanged", function()
        ui.count:SetFont(W.Font("title", 14))
        Update()
    end)
    Collect()
end

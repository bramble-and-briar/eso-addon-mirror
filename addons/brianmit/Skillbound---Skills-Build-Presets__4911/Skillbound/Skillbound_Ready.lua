-- Skillbound_Ready.lua : the ready check card (2026-10-03). When you arrive in a dungeon, trial or
-- other instance, a small card slides in for a few seconds: one line each for
--   Food      running, minutes left (and "only 3 left" in your bag)
--   Potions   on your quickslots, how many you carry
--   Poisons   the build's poisons, how many
--   Repair    lowest condition, repair kits
--   Charge    lowest weapon charge, filled soul gems
--   Mundus    the build's stone or not
-- each with a green / orange / red dot. Hover keeps it; a click pins it (X closes); it updates
-- live while shown (food eaten a moment later turns green). sv.readyCard, /sb ready.

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Items, Capture = B.Items, B.Capture
local Ready = {}
B.Ready = Ready

local CARD_W, ROW_H = 340, 22
local SHOW_S = 10                -- seconds it stays (unless hovered / pinned)
local LOW_FOOD, LOW_POTIONS, LOW_POISON = 3, 10, 20

local ui = { rows = {} }

-- one line: { label, level ("good" | "warn" | "bad"), text }
local function Lines()
    local out = {}
    local function Add(key, level, text) out[#out + 1] = { L(key), level, text } end
    local b = B.Apply.FoodBuild()

    -- food
    local food = b and b.parts and b.parts.food and b.food
    if food and food.id then
        local left = B.Apply.FoodLeft(food.id)
        local n = B.Apply.BagCount(food.id)
        local name = B.Apply.FoodName(food)
        local text, level
        if left then
            text = L("READY_FOOD_LEFT", name, math.floor(left / 60))
            level = left > (B.sv.foodRenewMin or 0) * 60 and "good" or "warn"
        elseif B.Apply.OtherFoodRunning(food.id) then
            text, level = L("READY_FOOD_OTHER"), "good"
        else
            text, level = L("READY_FOOD_NONE", name), "bad"
        end
        if n <= LOW_FOOD then
            text = text .. "  ·  " .. B.Colorize(n == 0 and C.bad or C.warn, L("READY_ONLY_LEFT", n))
            if level == "good" then level = "warn" end
        end
        Add("READY_FOOD", level, text)
    else
        local running = B.Apply.OtherFoodRunning(-1)
        Add("READY_FOOD", running and "good" or "bad", L(running and "READY_FOOD_OTHER" or "READY_FOOD_NOTHING"))
    end

    -- potions on the quickslot wheel
    local cat = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    if cat and GetSlotItemLink then
        local seen, total = {}, 0
        for i = 1, (ACTION_BAR_UTILITY_BAR_SIZE or 8) do
            if GetSlotType(i, cat) == ACTION_TYPE_ITEM then
                local link = GetSlotItemLink(i, cat) or ""
                if link ~= "" and GetItemLinkItemType(link) == ITEMTYPE_POTION then
                    local id = GetItemLinkItemId(link)
                    if not seen[id] then
                        seen[id] = true
                        total = total + B.Apply.BagCount(id)
                    end
                end
            end
        end
        local level = total >= LOW_POTIONS and "good" or (total > 0 and "warn" or "bad")
        Add("READY_POTIONS", level, total > 0 and L("READY_POTIONS_N", total) or L("READY_POTIONS_NONE"))
    end

    -- the build's poisons
    if b and b.gear then
        local total, any = 0, false
        for _, s in ipairs({ EQUIP_SLOT_POISON, EQUIP_SLOT_BACKUP_POISON }) do
            local p = b.gear[s]
            if p and p.id then
                any = true
                total = total + select(3, Items.FindPoison(p))
            end
        end
        if any then
            local level = total >= LOW_POISON and "good" or (total > 0 and "warn" or "bad")
            Add("READY_POISONS", level, L("READY_POISONS_N", total))
        end
    end

    -- repair and charge
    local s = B.Fix.Status()
    local repairLevel = s.minCond >= B.Fix.RepairAt() and "good" or (s.kits > 0 and "warn" or "bad")
    Add("READY_REPAIR", repairLevel, L("READY_REPAIR_N", s.minCond, s.kits))
    local chargeLevel = s.minCharge >= B.Fix.ChargeAt() and "good" or (s.gems > 0 and "warn" or "bad")
    Add("READY_CHARGE", chargeLevel, L("READY_CHARGE_N", s.minCharge, s.gems))

    -- mundus
    if b and b.mundus and b.mundus[1] then
        local now = {}
        for _, id in ipairs(Capture.Mundus()) do now[id] = true end
        local ok = false
        for _, id in ipairs(b.mundus) do if now[id] then ok = true end end
        local name = B.Name(GetAbilityName(b.mundus[1]))
        Add("READY_MUNDUS", ok and "good" or "bad", ok and name or L("READY_MUNDUS_WRONG", name))
    end
    return out
end

local DOT = { good = C.good, warn = C.warn, bad = C.bad }

local function Paint()
    if not ui.win or ui.win:IsHidden() then return end
    local lines = Lines()
    local worst = "good"
    for _, line in ipairs(lines) do
        if line[2] == "bad" then worst = "bad" elseif line[2] == "warn" and worst ~= "bad" then worst = "warn" end
    end
    for i, line in ipairs(lines) do
        local r = ui.rows[i]
        if not r then
            r = {}
            r.label = W.Label(ui.list, B.Font("head", 11), C.dim, "")
            r.label:SetAnchor(TOPLEFT, ui.list, TOPLEFT, 0, (i - 1) * ROW_H + 3)
            r.dot = W.Tex(ui.list, B.TEX .. "disc.dds", 8, 8)
            r.dot:SetAnchor(TOPLEFT, ui.list, TOPLEFT, 82, (i - 1) * ROW_H + 7)
            r.text = W.Label(ui.list, B.Font("text", 12), C.soft, "")
            r.text:SetAnchor(TOPLEFT, ui.list, TOPLEFT, 96, (i - 1) * ROW_H + 2)
            r.text:SetWidth(CARD_W - 28 - 96)
            r.text:SetMaxLineCount(1)
            ui.rows[i] = r
        end
        r.label:SetHidden(false)
        r.dot:SetHidden(false)
        r.text:SetHidden(false)
        r.label:SetText(zo_strupper(line[1]))
        r.dot:SetColor(B.RGBA(DOT[line[2]]))
        r.text:SetText(line[3])
        r.text:SetColor(B.RGBA(line[2] == "good" and C.soft or (line[2] == "warn" and C.warn or C.bad)))
    end
    for i = #lines + 1, #ui.rows do
        ui.rows[i].label:SetHidden(true)
        ui.rows[i].dot:SetHidden(true)
        ui.rows[i].text:SetHidden(true)
    end
    ui.top:SetColor(B.RGBA(DOT[worst], 0.9))
    ui.summary:SetText(B.Colorize(DOT[worst], L(worst == "good" and "READY_ALL_GOOD" or "READY_SOME", #lines)))
    ui.win:SetHeight(64 + #lines * ROW_H + 12)
end

function Ready.Hide()
    if not ui.win or ui.win:IsHidden() then return end
    local win = ui.win
    Anim.Run("Skillbound_ReadyCard", Anim.CLOSE, Anim.In, function(p) win:SetAlpha(1 - p) end, function()
        win:SetHidden(true)
        win:SetAlpha(1)
    end)
end

local function Create()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Ready")
    ui.win = win
    win:SetDimensions(CARD_W, 200)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if not W.RememberPlace(win, "ready") then Anim.Anchor(win, TOP, GuiRoot, TOP, 0, 110) end
    B.callbacks:RegisterCallback("PositionsReset", function() Anim.Anchor(win, TOP, GuiRoot, TOP, 0, 110) end)
    local fill = W.Tex(win, B.BG)
    fill:SetAnchorFill(win)
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    ui.top = W.Tex(win, nil, 10, 2, C.good, 0.9)
    ui.top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    ui.top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    local logo = W.Tex(win, B.LOGO, 22, 22)
    logo:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 12)
    ui.title = W.Label(win, B.Font("title", 15), C.text, zo_strupper(L("READY_TITLE")))
    ui.title:SetAnchor(LEFT, logo, RIGHT, 8, 1)
    ui.summary = W.Label(win, B.Font("text", 12), C.soft, "")
    ui.summary:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 38)
    ui.summary:SetWidth(CARD_W - 28)
    ui.summary:SetMaxLineCount(1)
    ui.pin = W.Label(win, B.Font("text", 10), C.faint, L("READY_PIN_HINT"), TEXT_ALIGN_RIGHT)
    ui.pin:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -12, -5)
    local close = W.CloseButton(win, Ready.Hide, 14, L("CLOSE"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 10)
    ui.list = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.list:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 60)
    ui.list:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -14, -12)
    -- hover keeps it, a click pins it; it updates once a second while shown
    win:SetHandler("OnMouseEnter", function() ui.hover = true end)
    win:SetHandler("OnMouseExit", function()
        ui.hover = false
        ui.hideAt = math.max(ui.hideAt or 0, GetFrameTimeSeconds() + 3)
    end)
    win:SetHandler("OnMouseDown", function(self) ui.downX, ui.downY = self:GetLeft(), self:GetTop() end)
    win:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        -- (a drag moves it, it doesn't pin it)
        if ui.downX and (math.abs(self:GetLeft() - ui.downX) > 3 or math.abs(self:GetTop() - ui.downY) > 3) then return end
        ui.pinned = not ui.pinned
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ui.pin:SetText(L(ui.pinned and "READY_PINNED" or "READY_PIN_HINT"))
    end)
    local nextPaint = 0
    win:SetHandler("OnUpdate", B.Safe(function()
        local now = GetFrameTimeSeconds()
        if now >= nextPaint then
            nextPaint = now + 1
            Paint()
        end
        if not ui.pinned and not ui.hover and ui.hideAt and now >= ui.hideAt then
            ui.hideAt = nil
            Ready.Hide()
        end
    end, "ready card"))
end

-- pinned = stays until you close it (/sb ready)
function Ready.Show(pinned)
    if not ui.win then Create() end
    ui.pinned = pinned and true or false
    ui.pin:SetText(L(ui.pinned and "READY_PINNED" or "READY_PIN_HINT"))
    ui.hideAt = GetFrameTimeSeconds() + SHOW_S
    Anim.Stop("Skillbound_ReadyCard")
    ui.win:SetHidden(false)
    Paint()
    Anim.SlideIn(ui.win, 0, -12, Anim.OPEN, "Skillbound_ReadyCard")
end

function Ready.Init()
    B.EM:RegisterForEvent("Skillbound_ReadyZone", EVENT_PLAYER_ACTIVATED, function()
        -- (after the auto eat had its go at 3 s, so the food line shows the result)
        B.Later(function()
            -- only once, when you come INTO an instance: loading screens inside it (boss portals,
            -- reviving at a wayshrine, /reloadui) fired this again and the card showed mid-run.
            -- c.readyZone = the instance it last showed in, cleared once you're outside again.
            local c = B.Char()
            if not B.Apply.InInstance() then
                c.readyZone = nil
                return
            end
            local zoneId = GetZoneId(GetUnitZoneIndex("player"))
            if c.readyZone == zoneId then return end
            c.readyZone = zoneId
            if B.sv.readyCard then Ready.Show(false) end
        end, 5000)
    end)
end

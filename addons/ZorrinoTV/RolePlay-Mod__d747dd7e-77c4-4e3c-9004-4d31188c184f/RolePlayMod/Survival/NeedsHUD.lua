if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Jauges françaises. Lecture seule des besoins : aucune modification des règles de survie.
RolePlayNeeds.NeedsHUD = {}
local H = RolePlayNeeds.NeedsHUD
local WIDTH, HEIGHT, TRACK_WIDTH = 310, 204, 278
local function Clamp(value, low, high)
    return math.max(low, math.min(high, tonumber(value) or low))
end
local function Settings()
    local s = RolePlayNeeds.settings
    s.needsHUD = s.needsHUD or {}
    local h = s.needsHUD
    if h.enabled == nil then h.enabled = true end
    if h.scale == nil then h.scale = 1 end
    if h.legacyIcons == nil then h.legacyIcons = false end
    return h
end
-- Full always means well: satiated, hydrated, rested.
function H.GetPercentages()
    local s = RolePlayNeeds.settings
    local function Stage(key)
        local meter = RolePlayNeeds[key] or s[key] or {}
        return (Clamp(meter.currentStage, 1, 10) - 1) * 100 / 9
    end
    local fatigue = Clamp(s.fatigueLv, 0, math.max(1, tonumber(s.MAX_FATIGUE) or 2500))
    return Stage('hunger'), Stage('water'), 100 * (1 - fatigue / math.max(1, tonumber(s.MAX_FATIGUE) or 2500))
end
local function SavePosition()
    local x, y = H.window:GetLeft(), H.window:GetTop()
    Settings().position = { x = x / GuiRoot:GetWidth(), y = y / GuiRoot:GetHeight() }
end
function H.ApplyPosition()
    if not H.window then return end
    local h = Settings()
    local w, ht = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local scale = Clamp(h.scale, 0.7, 1.5)
    H.window:SetScale(scale)
    local pos = h.position
    local safeWidth = math.min(w, ht * 16 / 9)
    local x = pos and tonumber(pos.x) and pos.x * w or (w - safeWidth) / 2 + 24
    local y = pos and tonumber(pos.y) and pos.y * ht or ht - HEIGHT * scale - 80
    H.window:ClearAnchors()
    H.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Clamp(x, 0, math.max(0, w - WIDTH * scale)), Clamp(y, 0, math.max(0, ht - HEIGHT * scale)))
    H.screenWidth, H.screenHeight = w, ht
end
function H.EndEdit()
    if not H.editing then return end
    SavePosition()
    H.editing = false
    H.window:SetMovable(false)
    H.window:SetMouseEnabled(false)
    H.window:SetKeyboardEnabled(false)
    H.window:SetDrawTier(DT_LOW)
    H.done:SetHidden(true)
    if H.ownsCursor then SetGameCameraUIMode(false) end
    H.ownsCursor = false
    H.Update()
end
function H.BeginEdit()
    if not H.window then return end
    Settings().enabled = true
    H.editing = true
    H.ownsCursor = not IsGameCameraUIModeActive()
    if H.ownsCursor then SetGameCameraUIMode(true) end
    H.window:SetMovable(true)
    H.window:SetMouseEnabled(true)
    H.window:SetKeyboardEnabled(true)
    H.window:SetDrawTier(DT_HIGH)
    H.done:SetHidden(false)
    H.Update()
end
local function Label(parent, name, text, font, x, y)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    c:SetFont(font)
    c:SetColor(0.92, 0.88, 0.76, 1)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetText(text)
    return c
end
local function MakeRow(index, text)
    local y = 36 + (index - 1) * 47
    local label = Label(H.window, 'RPNNeedsHUDLabel' .. index, text, 'ZoFontGamepad18', 16, y)
    local percent = Label(H.window, 'RPNNeedsHUDValue' .. index, '', 'ZoFontGamepad18', 230, y)
    percent:SetDimensions(64, 22)
    percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local track = WINDOW_MANAGER:CreateControl('RPNNeedsHUDTrack' .. index, H.window, CT_BACKDROP)
    track:SetAnchor(TOPLEFT, H.window, TOPLEFT, 16, y + 24)
    track:SetDimensions(TRACK_WIDTH, 12)
    track:SetCenterColor(0.04, 0.035, 0.025, 0.96)
    track:SetEdgeColor(0.50, 0.40, 0.23, 0.9)
    track:SetEdgeTexture('', 1, 1, 1)
    local fill = WINDOW_MANAGER:CreateControl('RPNNeedsHUDFill' .. index, track, CT_BACKDROP)
    fill:SetAnchor(TOPLEFT, track, TOPLEFT, 2, 2)
    fill:SetDimensions(TRACK_WIDTH - 4, 8)
    fill:SetEdgeTexture('', 1, 1, 0)
    return {fill = fill, percent = percent, label = label, track = track}
end
function H.Update()
    if not H.window then return end
    local h = Settings()
    if H.screenWidth ~= GuiRoot:GetWidth() or H.screenHeight ~= GuiRoot:GetHeight() then H.ApplyPosition() end
    local scene = SCENE_MANAGER:GetCurrentScene()
    local sceneName = scene and scene:GetName() or ''
    local outsideWorld = sceneName == '' or sceneName == 'loadingscreen' or sceneName == 'loading' or sceneName == 'login' or sceneName == 'characterselect' or sceneName == 'charactercreate'
    local visible = H.editing or (h.enabled and RolePlayMod.Enabled('survival') and (RolePlayMod.Enabled('hunger') or RolePlayMod.Enabled('water') or RolePlayMod.Enabled('fatigue')) and not outsideWorld)
    H.window:SetHidden(not visible)
    local legacy = not h.enabled or h.legacyIcons
    for _, key in ipairs({'hunger', 'water', 'fatigue'}) do
        local meter = RolePlayNeeds[key]
        if meter and meter.control then meter.control:SetHidden(not legacy or not RolePlayMod.Enabled(key)) end
    end
    local values = {H.GetPercentages()}
    for i, value in ipairs(values) do
        local row = H.rows[i]
        local active=RolePlayMod.Enabled(({'hunger','water','fatigue'})[i])
        row.label:SetHidden(not active);row.track:SetHidden(not active);row.percent:SetHidden(not active)
        if i == 3 then
            local number=string.format('%.1f %%', value)
            row.percent:SetText(RPM_LOCALE.english and number or (number:gsub('%.', ',')))
        else
            row.percent:SetText(string.format('%d %%', math.floor(value + 0.5)))
        end
        row.fill:SetHidden(value <= 0)
        row.fill:SetWidth(math.max(1, (TRACK_WIDTH - 4) * value / 100))
        if value <= 25 then row.fill:SetCenterColor(0.78, 0.22, 0.16, 1)
        elseif value <= 60 then row.fill:SetCenterColor(0.86, 0.60, 0.20, 1)
        else row.fill:SetCenterColor(0.34, 0.66, 0.36, 1) end
    end
end
function H.Initialize()
    if H.window then return end
    Settings()
    local win = WINDOW_MANAGER:CreateTopLevelWindow('RPNNeedsHUD')
    H.window = win
    win:SetDimensions(WIDTH, HEIGHT)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetMovable(false)
    win:SetMouseEnabled(false)
    win:SetKeyboardEnabled(false)
    local bg = WINDOW_MANAGER:CreateControl('RPNNeedsHUDBackground', win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.035, 0.028, 0.018, 0.83)
    bg:SetEdgeColor(0.65, 0.52, 0.29, 0.8)
    bg:SetEdgeTexture('', 1, 1, 1)
    Label(win, 'RPNNeedsHUDTitle', 'BESOINS VITAUX', 'ZoFontGamepadBold18', 16, 9)
    H.rows = {MakeRow(1, 'Faim · Satiété'), MakeRow(2, 'Soif · Hydratation'), MakeRow(3, 'Fatigue · Repos')}
    Label(win, 'RPNNeedsHUDFooter', 'Plein = tout va bien', 'ZoFontGamepad18', 16, 181)
    local done = WINDOW_MANAGER:CreateControl('RPNNeedsHUDDone', win, CT_BUTTON)
    H.done = done
    done:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 8)
    done:SetDimensions(80, 24)
    done:SetFont('ZoFontGamepadBold18')
    done:SetNormalFontColor(1, 0.85, 0.5, 1)
    done:SetText('Terminer')
    done:SetMouseEnabled(true)
    done:SetHandler('OnClicked', H.EndEdit)
    done:SetHidden(true)
    win:SetHandler('OnMouseDown', function(self, button) if H.editing and button == MOUSE_BUTTON_INDEX_LEFT then self:StartMoving() end end)
    win:SetHandler('OnMouseUp', function(self) if H.editing then self:StopMovingOrResizing(); SavePosition() end end)
    win:SetHandler('OnMoveStop', SavePosition)
    win:SetHandler('OnKeyUp', function(_, key) if key == KEY_ESCAPE then H.EndEdit() end end)
    H.ApplyPosition()
    H.Update()
    EVENT_MANAGER:RegisterForUpdate('RPNNeedsHUDUpdate', 250, H.Update)
    SLASH_COMMANDS['/jauges'] = function() if H.editing then H.EndEdit() else H.BeginEdit() end end
    SLASH_COMMANDS['/rpnjauges'] = SLASH_COMMANDS['/jauges']
end
function H.AddOptions(options)
    local function Add(item) options[#options + 1] = item end
    Add({type = 'header', name = 'Jauges de survie'})
    Add({type = 'description', text = 'Une jauge pleine indique que le besoin est satisfait. La jauge de fatigue représente votre réserve de repos.'})
    Add({type = 'checkbox', name = 'Afficher les trois jauges', default = true,
        getFunc = function() return Settings().enabled end,
        setFunc = function(v) Settings().enabled = v; if not v then H.EndEdit() end; H.Update() end})
    Add({type = 'slider', name = 'Taille des jauges', min = 70, max = 150, step = 5, default = 100,
        getFunc = function() return math.floor(Settings().scale * 100 + 0.5) end,
        setFunc = function(v) Settings().scale = v / 100; H.ApplyPosition() end})
    Add({type = 'checkbox', name = 'Conserver aussi les anciennes icônes', default = false,
        getFunc = function() return Settings().legacyIcons end,
        setFunc = function(v) Settings().legacyIcons = v; H.Update() end})
    Add({type = 'button', name = 'Déplacer les jauges', tooltip = 'Déplacez le panneau, puis cliquez sur Terminer. La commande /jauges permet aussi de le faire en jeu.', func = H.BeginEdit, width = 'half'})
    Add({type = 'button', name = 'Réinitialiser la position', func = function() Settings().position = nil; H.ApplyPosition() end, width = 'half'})
end

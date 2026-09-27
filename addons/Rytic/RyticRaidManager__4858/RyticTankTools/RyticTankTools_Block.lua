------------------------------------------------------------
-- RYTICTANK BLOCK HUD v3.2 - local-reference optimization
-- Uses Hyper Tanking Tools' proven block-state pattern:
-- keep widget visible, toggle indicator opacity from IsBlockActive().
------------------------------------------------------------

local RyticTank = RyticTank

RyticTank.Block = {}
local Block = RyticTank.Block

-- Cache hot globals/functions used by the lightweight block update path.
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local IsBlockActive = IsBlockActive
local GetAdvancedStatValue = GetAdvancedStatValue
local string_format = string.format

local function GetBlockMitigation()
    -- Block cost is intentionally not sampled/displayed anymore. The useful
    -- combat information is the live BLOCKING state plus block mitigation.
    if not GetAdvancedStatValue then return 0 end
    local _, _, mitigationValue = GetAdvancedStatValue(7)
    return tonumber(mitigationValue) or 0
end

function Block.CreateHUD()
    local wm = WM

    local window = wm:CreateTopLevelWindow("RyticTankBlockHUD")
    Block.window = window
    -- ESOUI HUD fragment: automatically hide this HUD when menus open.
    local hudFragment = ZO_HUDFadeSceneFragment:New(window, nil, 0)
    HUD_SCENE:AddFragment(hudFragment)
    HUD_UI_SCENE:AddFragment(hudFragment)
    Block.hudFragment = hudFragment

    -- Let ESO scene/fragment state own HUD visibility.  The Block.Update
    -- loop must never force this window back on top of MAP/MENU scenes.
    Block.fragmentVisible = false
    hudFragment:RegisterCallback("StateChange", function(oldState, newState)
        local visible = (newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN)
        Block.fragmentVisible = visible
        local s = RyticTank.saved.block
        local hideForCombat = s.combatOnly and not IsUnitInCombat("player")
        window:SetHidden(not (visible and s.enabled and not hideForCombat))
    end)
    window:SetDimensions(430, 92)
    window:ClearAnchors()
    window:SetAnchor(
        TOPLEFT, GuiRoot, TOPLEFT,
        RyticTank.saved.block.position.x,
        RyticTank.saved.block.position.y
    )
    window:SetClampedToScreen(true)

    -- This is the actual state indicator. Like HTT's shield:
    -- full alpha while blocking, low alpha while not blocking.
    local state = wm:CreateControl(nil, window, CT_LABEL)
    state:SetFont("ZoFontWinH2")
    state:SetDimensions(210, 40)
    state:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    state:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    state:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    state:SetText("BLOCK")
    Block.state = state

    local stats = wm:CreateControl(nil, window, CT_LABEL)
    stats:SetFont("ZoFontGameBold")
    stats:SetDimensions(210, 40)
    stats:SetAnchor(LEFT, state, RIGHT, 10, 0)
    stats:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stats:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    Block.stats = stats

    window:SetHandler("OnMoveStop", function()
        RyticTank.saved.block.position.x = window:GetLeft()
        RyticTank.saved.block.position.y = window:GetTop()
    end)

    Block.ApplyLock()
end

function Block.ApplyLock()
    local window = Block.window
    if not window then return end

    local movable = not RyticTank.saved.block.locked
    window:SetMovable(movable)
    window:SetMouseEnabled(movable)
    window:SetScale(RyticTank.saved.block.scale or 1.0)
end

function Block.Update()
    local window = Block.window
    if not window then return end

    local s = RyticTank.saved.block

    if not s.enabled then
        window:SetHidden(true)
        return
    end

    -- Hide OOC: when enabled, the Block HUD exists only while the player is
    -- actually in combat.  Master OFF and ESO scene/fragment visibility still
    -- remain authoritative.
    -- Settings stores this option as block.combatOnly.
    if s.combatOnly and not IsUnitInCombat("player") then
        window:SetHidden(true)
        return
    end

    -- Scene/fragment state is authoritative.  Do not call SetHidden(false)
    -- here: doing so every 50 ms overrides ESO hiding the HUD for the map/menu.
    if not Block.fragmentVisible then
        window:SetHidden(true)
        return
    end
    window:SetHidden(false)

    local blocking = IsBlockActive()
    local blockMit = GetBlockMitigation()

    if blocking then
        Block.state:SetText("BLOCKING")

        -- Full mitigation: make BLOCKING bright green too.
        if blockMit >= 90 then
            Block.state:SetColor(0.10, 1.00, 0.15, 1)
            Block.stats:SetColor(0.10, 1.00, 0.15, 1)
        else
            Block.state:SetColor(1.00, 0.08, 0.08, 1)
            Block.stats:SetColor(1.00, 0.55, 0.55, 1)
        end
        Block.state:SetAlpha(1.0)

        Block.stats:SetAlpha(1.0)
    else
        -- Mimic HTT: still present, but clearly inactive/faded.
        Block.state:SetText("NOT BLOCKING")
        Block.state:SetColor(0.55, 0.55, 0.55, 1)
        Block.state:SetAlpha(0.20)

        if blockMit >= 90 then
            Block.stats:SetColor(0.10, 1.00, 0.15, 1)
            Block.stats:SetAlpha(1.0)
        else
            Block.stats:SetColor(0.55, 0.55, 0.55, 1)
            Block.stats:SetAlpha(0.35)
        end
    end

    Block.stats:SetText(
        string_format("BLOCK MIT %.0f%%", blockMit)
    )
end

local UPDATE_NAME = "RyticTankBlockStateUpdate"
local runtimeRegistered = false

local function registerRuntime()
    if runtimeRegistered then return end
    -- 100 ms is still effectively instant to the player while halving this
    -- background polling path compared with the old 50 ms refresh.
    EM:RegisterForUpdate(UPDATE_NAME, 100, Block.Update)
    runtimeRegistered = true
end

local function unregisterRuntime()
    if not runtimeRegistered then return end
    EM:UnregisterForUpdate(UPDATE_NAME)
    runtimeRegistered = false
end

function Block.SetEnabled(enabled)
    if not RyticTank.saved or not RyticTank.saved.block then return end

    enabled = enabled and true or false
    RyticTank.saved.block.enabled = enabled

    if enabled then
        registerRuntime()
        Block.Update()
    else
        unregisterRuntime()
        if Block.window then
            Block.window:SetHidden(true)
        end
    end
end

function Block.SetLocked(locked)
    if not RyticTank.saved or not RyticTank.saved.block then return end
    RyticTank.saved.block.locked = locked and true or false
    Block.ApplyLock()
end

function Block.SetScale(scale)
    if not RyticTank.saved or not RyticTank.saved.block then return end
    scale = tonumber(scale) or 1.0
    RyticTank.saved.block.scale = scale
    Block.ApplyLock()
end

function Block.Initialize()
    if not RyticTank.saved.block then
        RyticTank.saved.block = ZO_DeepTableCopy(RyticTank.defaults.block)
    end

    if not RyticTank.saved.block.position then
        RyticTank.saved.block.position = { x = 800, y = 500 }
    end

    Block.CreateHUD()
    Block.SetEnabled(RyticTank.saved.block.enabled ~= false)
end

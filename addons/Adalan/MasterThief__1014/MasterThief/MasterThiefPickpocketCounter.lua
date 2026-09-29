-- MasterThief - Pickpocket Counter Module

if not MasterThief then MasterThief = {} end
local MT = MasterThief

----------------------------------------
-- Constants
----------------------------------------
local ICON_TEX  = "/esoui/art/icons/ability_legerdemain_sly.dds"
local ICON_SIZE = 52
local ICON_Y    = -90
local LABEL_Y   = ICON_Y - 40
local SNAP      = 300    -- world-unit grid for NPC identity key

local COLOR_1 = { r=0.3,  g=1.0,  b=0.3,  a=1 }
local COLOR_2 = { r=1.0,  g=0.75, b=0.0,  a=1 }
local COLOR_3 = { r=1.0,  g=0.2,  b=0.1,  a=1 }

----------------------------------------
-- Module state
----------------------------------------
local _entries    = {}
local _icon       = nil
local _label      = nil
local _pollActive = false

----------------------------------------
-- NPC identity helpers
----------------------------------------
local function SnapCoord(v)
    return math.floor(v / SNAP + 0.5) * SNAP
end

local function GetReticleKey()
    if not DoesUnitExist("reticleover") then return nil end
    if IsUnitPlayer("reticleover") then return nil end
    local name = GetUnitName("reticleover")
    if not name or name == "" then return nil end
    local _, wx, _, wz = GetUnitRawWorldPosition("reticleover")
    return string.format("%s|%d|%d", name, SnapCoord(wx), SnapCoord(wz))
end

----------------------------------------
-- Display helpers
----------------------------------------
local function EnsureControls()
    if _icon then return end

    -- Anchor to ZO_ReticleContainer so the display tracks exactly what the
    -- player is looking at, the same way GuardWarner's shield icon does.
    _icon = WINDOW_MANAGER:CreateControl(
        "MasterThiefPPIcon", ZO_ReticleContainer, CT_TEXTURE)
    _icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    _icon:SetTexture(ICON_TEX)
    _icon:SetDrawLayer(DL_OVERLAY)
    _icon:SetDrawLevel(2)
    _icon:ClearAnchors()
    _icon:SetAnchor(CENTER, ZO_ReticleContainer, CENTER, 0, ICON_Y)
    _icon:SetHidden(true)

    _label = WINDOW_MANAGER:CreateControl(
        "MasterThiefPPLabel", ZO_ReticleContainer, CT_LABEL)
    _label:SetFont("ZoFontGame")
    _label:SetDrawLayer(DL_OVERLAY)
    _label:SetDrawLevel(3)
    _label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    _label:ClearAnchors()
    _label:SetAnchor(CENTER, ZO_ReticleContainer, CENTER, 0, LABEL_Y)
    _label:SetHidden(true)
end

local function GetCountColor(count)
    if count >= 3 then return COLOR_3
    elseif count == 2 then return COLOR_2
    else return COLOR_1 end
end

local function ShowDisplay(entry)
    if not _icon or not entry then return end
    local c = GetCountColor(entry.count)
    _icon:SetColor(c.r, c.g, c.b, c.a)
    _icon:SetHidden(false)
    if entry.count > 1 then
        _label:SetColor(c.r, c.g, c.b, c.a)
        _label:SetText(string.format("x%d", entry.count))
        _label:SetHidden(false)
    else
        _label:SetHidden(true)
    end
end

local function HideDisplay()
    if _icon  then _icon:SetHidden(true) end
    if _label then _label:SetHidden(true) end
end

local function StopPoll()
    if _pollActive then
        EVENT_MANAGER:UnregisterForUpdate("MasterThiefPPCounterPoll")
        _pollActive = false
    end
end

local function PollTick()
    -- Stop if nothing left to watch
    local any = false
    for _ in pairs(_entries) do any = true; break end
    if not any then StopPoll(); HideDisplay(); return end

    local key = GetReticleKey()
    if key and _entries[key] then
        local hp = GetUnitPower("reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
        if hp and hp <= 0 then
            _entries[key] = nil
            HideDisplay()
        else
            ShowDisplay(_entries[key])
        end
    else
        HideDisplay()
    end
end

local function StartPoll()
    if not _pollActive then
        EVENT_MANAGER:RegisterForUpdate("MasterThiefPPCounterPoll", 250, PollTick)
        _pollActive = true
    end
end

----------------------------------------
-- Core: record a pickpocket on the current reticle target
----------------------------------------
function MT:RecordPickpocketForReticle()
    if not MasterThief.SavedVarsOptions.PickpocketCounterEnabled then return end
	
    local key = GetReticleKey()
    if not key then return end

    if _entries[key] then
        _entries[key].count = _entries[key].count + 1
    else
        _entries[key] = {
            count = 1,
            name  = GetUnitName("reticleover") or "",
        }
    end

    ShowDisplay(_entries[key])
    StartPoll()
end

----------------------------------------
-- Events
----------------------------------------
local function OnUnitDeathStateChanged(_, unitTag, isDead)
    if not isDead then return end
    if not DoesUnitExist(unitTag) then return end
    if IsUnitPlayer(unitTag) then return end
    local name = GetUnitName(unitTag)
    if not name or name == "" then return end
    local _, wx, _, wz = GetUnitRawWorldPosition(unitTag)
    local key = string.format("%s|%d|%d", name, SnapCoord(wx), SnapCoord(wz))
    if _entries[key] then
        _entries[key] = nil
        HideDisplay()
    end
end

local function OnReticleTargetChanged()
    local key = GetReticleKey()
    if key and _entries[key] then
        ShowDisplay(_entries[key])
    else
        HideDisplay()
    end
end

local function OnZoneChange()
    _entries = {}
    StopPoll()
    HideDisplay()
end

----------------------------------------
-- Public init
----------------------------------------
function MT:SetPickpocketCounterEnabled(enabled)
    MasterThief.SavedVarsOptions.PickpocketCounterEnabled = enabled
    if not enabled then
        _entries = {}
        StopPoll()
        HideDisplay()
    end
end

function MT:InitPickpocketCounter()
    EnsureControls()

    EVENT_MANAGER:RegisterForEvent(MT.name .. "_PPCtr_Death",
        EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathStateChanged)
    EVENT_MANAGER:RegisterForEvent(MT.name .. "_PPCtr_Reticle",
        EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
    EVENT_MANAGER:RegisterForEvent(MT.name .. "_PPCtr_Zone",
        EVENT_PLAYER_ACTIVATED, OnZoneChange)
end
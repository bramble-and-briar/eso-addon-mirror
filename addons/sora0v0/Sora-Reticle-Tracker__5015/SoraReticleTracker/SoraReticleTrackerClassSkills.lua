-- Class Skills module: first migrated tracker. Others still run from the stable core.
local SSRT = SoraReticleTracker
SSRT.ClassSkills = SSRT.ClassSkills or {}

local WARDEN_FLY_READY_BUFF_ID = 91416
local function ScanWardenFlyReady()
    local ready = false
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if id == WARDEN_FLY_READY_BUFF_ID then ready = true; break end
    end
    SSRT.wardenFlyReady = ready
end
local function OnWardenFlyEffect(_, change, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
    if abilityId ~= WARDEN_FLY_READY_BUFF_ID or unitTag ~= "player" then return end
    -- Re-read the actual buff list to avoid assuming EVENT_EFFECT_CHANGED result order.
    ScanWardenFlyReady()
end


SSRT.ClassSkills.WardenFlyBuffId = WARDEN_FLY_READY_BUFF_ID
SSRT.ClassSkills.ScanWardenFlyReady = ScanWardenFlyReady
SSRT.ClassSkills.OnWardenFlyEffect = OnWardenFlyEffect

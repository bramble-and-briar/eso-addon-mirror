------------------------------------------------------------
-- Key Chording (merged from KeyChording by @R1K3R)
-- Lets Shift/Ctrl/Alt act as modifiers in Settings > Controls,
-- e.g. binding Alt+1..9 to Wizard's Wardrobe setups.
------------------------------------------------------------

function FrankGrinder:ApplyKeyChording(enabled)
    -- ESO shipped two different manager names across API versions.
    local manager = KEYBINDINGS_MANAGER or KEYBINDING_MANAGER
    if manager and manager.SetChordingAlwaysEnabled then
        manager:SetChordingAlwaysEnabled(enabled == true)
    end
end

function FrankGrinder:InitializeKeyChording()
    -- Only touch the game's chording state when enabled, so a default-off
    -- install doesn't override another addon that manages it.
    if self:GetSettingKeyChordingEnabled() then
        self:ApplyKeyChording(true)
    end
end

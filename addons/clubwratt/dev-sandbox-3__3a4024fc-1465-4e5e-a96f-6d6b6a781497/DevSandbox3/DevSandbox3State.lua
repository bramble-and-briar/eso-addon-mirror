-- DevSandbox3State.lua: SavedVars defaults
local State = {}

function State.CreateSavedVarsDefaults()
    return {
        -- persisted memory, per zone and slot index, with an os-seconds expiry (0 = until cleared manually):
        --   checkpoints[zone][slot] = expiry           the player came within checkedM
        --   verdicts[zone][slot]    = { e = 0|1, x = expiry }   last judgment inside confirmed range (1 = empty)
        checkpoints = {},
        verdicts = {},
        settings = {
            dotSizeCm = 40,                               -- apparent size at 10 m
            farScalePct = 50,                             -- dot size at farScaleM relative to near size (100 = constant)
            farScaleM = 100,                              -- distance at which farScalePct applies
            outline = true,                               -- black ring behind each dot
            cyrodiilOnly = true,                          -- nothing at all outside Cyrodiil (not even runestone / Psijic dots)
            markWarTorte = true,                          -- orange: any empty harvestable location in Cyrodiil
            warTorteColor = { r = 1.0, g = 0.55, b = 0.15, a = 0.9 },
            markPsijic = true,                            -- purple: any empty enchanting location, every zone
            psijicColor = { r = 0.7, g = 0.3, b = 1.0, a = 0.9 },
            markUnknown = true,                           -- yellow: no node seen, but beyond the confirmed distance
            unknownColor = { r = 1.0, g = 0.9, b = 0.2, a = 0.9 }, -- yellow
            unknownM = 80,                                -- unknown starts here (field log 2026-10-05: false-empties cleared at 80-138 m)
            unknownLimitM = 150,                          -- unknown dots are not drawn beyond this
            checkedM = 36,                                -- coming within this distance marks a slot checked...
            checkedMin = 60,                              -- ...and verdicts are remembered this many minutes; 0 = until cleared manually
            checkedColor = { r = 0.0, g = 0.9, b = 0.9, a = 0.5 }, -- neon teal, half transparent
            debugNodes = false,                           -- cyan: every located node
            debug = false,
        },
    }
end

function State.Create()
    return { savedVars = State.CreateSavedVarsDefaults() }
end

DevSandbox3.State = State

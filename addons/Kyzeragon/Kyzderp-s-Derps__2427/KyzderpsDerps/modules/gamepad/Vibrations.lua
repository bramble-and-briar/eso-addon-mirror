local KD = KyzderpsDerps

local function ColorNumber(motorValue)
    motorValue = motorValue or 0
    return string.format("|cFF%02x00%f|r", math.floor((1 - motorValue) * 255), motorValue)
end

local function MySetGamepadVibration(duration, firstMotor, secondMotor, thirdMotor, fourthMotor, debugSourceInfo)
    if (not KD.savedOptions.gamepad.modifyVibes) then return end

    if (duration > 0) then
        KD:dbg(string.format("%d - %s %s %s %s - " .. tostring(debugSourceInfo),
            duration,
            ColorNumber(firstMotor),
            ColorNumber(secondMotor),
            ColorNumber(thirdMotor),
            ColorNumber(fourthMotor)))
    end

    if (debugSourceInfo == "KDDfishing" or debugSourceInfo == "KDDlockpick") then return end -- because we call this too

    if (debugSourceInfo == "lockpick feedback") then
        if (firstMotor <= 0.18 and secondMotor <= 0.18) then
            return true
        else
            SetGamepadVibration(duration, zo_clamp(firstMotor * 2, 0, 1), zo_clamp(secondMotor * 2, 0, 1), 0, 0, "KDDlockpick")
            return true
        end
    elseif (duration <= 500 and firstMotor <= 0.25 and secondMotor <= 0.25) then
        return true
    end

    if (duration == 2500 and firstMotor == 0.01 and secondMotor == 0.05) then
        SetGamepadVibration(1000, 1, 1, 0, 0, "KDDfishing")
        return true
    end
end

local hooked
function KD.InitializeVibrations()
    if (KD.savedOptions.gamepad.modifyVibes and not hooked) then
        hooked = true
        ZO_PreHook("SetGamepadVibration", MySetGamepadVibration)
    end
end
-- /script SetGamepadVibration(1000, 1, 1, 0, 0)

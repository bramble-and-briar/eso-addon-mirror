local CLASS_ICONS = {
    [1]   = "Icons/dragonknight.dds",
    [2]   = "Icons/sorcerer.dds",
    [3]   = "Icons/nightblade.dds",
    [4]   = "Icons/warden.dds",
    [5]   = "Icons/necromancer.dds",
    [6]   = "Icons/templar.dds",
    [117] = "Icons/arcanist.dds",
}

local COMPASS_MARK_OFFSETS = { -128, -77, -26, 26, 77, 128 }

local function CreateMaster()
    local master = WINDOW_MANAGER:CreateControl("ERUI_SimpleImgMaster", GuiRoot, CT_TOPLEVELCONTROL)
    master:SetAnchorFill(GuiRoot)
    master:SetDrawLayer(DL_BACKGROUND)
    master:SetDrawTier(DT_LOW)
    master:SetDrawLevel(0)
    return master
end

local function AddImg(master, name, file, relToEdge, x, y, w, h)
    local control = WINDOW_MANAGER:CreateControl(name, master, CT_CONTROL)
    control:SetDimensions(w, h)
    control:SetAnchor(CENTER, master, relToEdge, x, y)
    control:SetDrawLayer(DL_BACKGROUND)
    control:SetDrawTier(DT_LOW)
    control:SetDrawLevel(0)

    local texture = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    texture:SetAnchorFill()
    texture:SetTexture("EldenRingUI/Textures/" .. file)

    return control
end

local function CreateOverlay(master, name, file, width, height, point, offsetY, tier)
    local overlay = WINDOW_MANAGER:CreateControl(name, master, CT_TEXTURE)
    overlay:SetTexture("EldenRingUI/Textures/" .. file)
    overlay:SetDimensions(width, height)
    overlay:SetAnchor(point, GuiRoot, point, 0, offsetY)
    overlay:SetDrawLayer(DL_OVERLAY)
    overlay:SetDrawTier(tier)
    overlay:SetHidden(true)
    return overlay
end

local function SetMarksHidden(marks, hidden)
    for _, mark in ipairs(marks) do
        mark:SetHidden(hidden)
    end
end

EVENT_MANAGER:RegisterForEvent("ERUI_SimpleImage", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= "EldenRingUI" then return end

    local master = CreateMaster()

    AddImg(master, "ERUI_Img1", "ClassHolder.dds", TOPLEFT, 91, 70, 128, 128)
    AddImg(master, "ERUI_Img0", CLASS_ICONS[GetUnitClassId("player")] or "empty.dds", TOPLEFT, 91, 70, 80, 80)

    AddImg(master, "ERUI_Img2", "Slot.dds", BOTTOMLEFT, 92, -171, 128, 128)
    AddImg(master, "ERUI_Img3", "Slot.dds", BOTTOMLEFT, 187, -225, 128, 128)
    AddImg(master, "ERUI_Img4", "Slot.dds", BOTTOMLEFT, 187, -115, 128, 128)
    AddImg(master, "ERUI_Img5", "Slot.dds", BOTTOMLEFT, 281, -171, 128, 128)

    AddImg(master, "ERUI_Img6", "Souls.dds", BOTTOMRIGHT, -150, -45, 512, 256)
    AddImg(master, "ERUI_Img7", "Mastery.dds", BOTTOMLEFT, 236, -391, 512, 64)

    AddImg(master, "ERUI_Img8", "ERCompass.dds", TOP, 0, 135, 500, 12)

    local compassMarks = {}
    for i, x in ipairs(COMPASS_MARK_OFFSETS) do
        compassMarks[i] = AddImg(master, "ERUI_Img" .. (8 + i), "CompassMark.dds", TOP, x, 135, 4, 24)
    end

    local scaleFactor = GuiRoot:GetWidth() / 1920
    local deathImg = CreateOverlay(master, "ERUI_DeathImageDisplay", "died.dds", GuiRoot:GetWidth(), 240 * scaleFactor, CENTER, 0, DT_HIGH)
    local deathImg2 = CreateOverlay(master, "ERUI_DeathImageDisplay2", "DeadBG.dds", 1024, 128, BOTTOM, -28, DT_MEDIUM)

    EVENT_MANAGER:RegisterForEvent("ERUI_SimpleImage_Death", EVENT_PLAYER_DEAD, function()
        for _ = 1, 3 do
            PlaySound(SOUNDS.BATTLEGROUND_MATCH_LOST)
        end
        PlaySound(SOUNDS.BATTLEGROUND_ROUND_RECAP_FLAG_SCORE_COUNT)

        deathImg:SetHidden(false)
        SetMarksHidden(compassMarks, true)

        zo_callLater(function()
            if IsUnitDead("player") then
                deathImg2:SetHidden(false)
            end
        end, 2000)

        zo_callLater(function()
            deathImg:SetHidden(true)
        end, 2500)
    end)

    EVENT_MANAGER:RegisterForEvent("ERUI_SimpleImage_Alive", EVENT_PLAYER_ALIVE, function()
        deathImg:SetHidden(true)
        deathImg2:SetHidden(true)
        SetMarksHidden(compassMarks, false)
    end)

    COMPASS_FRAME:SetBossBarHiddenForReason("modded", true)

    local function UpdateVisibility()
        master:SetHidden(not (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")))
    end

    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", UpdateVisibility)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", UpdateVisibility)
    UpdateVisibility()
end)
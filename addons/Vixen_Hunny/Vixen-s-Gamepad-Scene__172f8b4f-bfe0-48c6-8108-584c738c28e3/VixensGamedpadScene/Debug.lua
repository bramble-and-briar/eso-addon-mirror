-- Display test: shows the building blocks the theme now uses, so we can tell
-- which ones this client draws.
--   1: plain magenta block
--   2: pink gradient block
--   3: pixel heart (several small blocks)
-- It also paints every skinned menu panel magenta (to confirm the panels are
-- the visible ones) and prints each panel's size to chat.
local VGS = VGS

VGS.testActive = false

local function CreateTestWindow()
    if VGS.testWindow then return VGS.testWindow end

    local win = WINDOW_MANAGER:CreateTopLevelWindow("VGS_TestWindow")
    win:SetDrawTier(DT_HIGH)
    win:SetDimensions(1080, 330)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(false)

    local function slot(name, x, labelText)
        local box = WINDOW_MANAGER:CreateControl("VGS_TestWindow" .. name, win, CT_CONTROL)
        box:SetDimensions(220, 220)
        box:SetAnchor(TOPLEFT, win, TOPLEFT, x, 20)
        local label = WINDOW_MANAGER:CreateControl("VGS_TestWindow" .. name .. "Label", win, CT_LABEL)
        label:SetFont("ZoFontGamepad34")
        label:SetColor(1, 1, 1, 1)
        label:SetText(labelText)
        label:SetAnchor(TOP, box, BOTTOM, 0, 10)
        return box
    end

    local function block(parent)
        local tex = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
        tex:SetDrawLevel(1)
        return tex
    end

    local plain = block(slot("Plain", 40, "1: plain"))
    plain:SetAnchorFill(plain:GetParent())
    plain:SetColor(1, 0, 1, 1)

    local grad = block(slot("Gradient", 300, "2: gradient"))
    grad:SetAnchorFill(grad:GetParent())
    grad:SetGradientColors(ORIENTATION_VERTICAL, 1, 0.47, 0.72, 1, 0.45, 0.1, 0.3, 1)

    local img = block(slot("Image", 820, "4: image"))
    img:SetAnchorFill(img:GetParent())
    img:SetTexture("VixensGamedpadScene/textures/" .. VGS.GetTheme().id .. "/corner.dds")
    VGS.testImage = img

    local heartBox = slot("Heart", 560, "3: heart")
    local runs = { {0,1,2}, {0,4,5}, {1,0,6}, {2,0,6}, {3,1,5}, {4,2,4}, {5,3,3} }
    local cell = 30
    for _, r in ipairs(runs) do
        local t = block(heartBox)
        t:SetAnchor(TOPLEFT, heartBox, TOPLEFT, 5 + r[2] * cell, 20 + r[1] * cell)
        t:SetDimensions((r[3] - r[2] + 1) * cell, cell)
        t:SetColor(1, 0.38, 0.66, 1)
    end

    VGS.testWindow = win
    return win
end

local function SetProbes(show)
    for _, skin in ipairs(VGS.skins) do
        if not skin.probe then
            local p = WINDOW_MANAGER:CreateControl(nil, skin.bg, CT_TEXTURE)
            p:SetAnchorFill(skin.bg)
            p:SetDrawLayer(DL_OVERLAY)
            p:SetDrawLevel(10000)
            p:SetColor(1, 0, 1, 0.6)
            p:SetMouseEnabled(false)
            skin.probe = p
        end
        skin.probe:SetHidden(not show)
    end
end

local function ReportPanels()
    for _, skin in ipairs(VGS.skins) do
        local bg = skin.bg
        local w, h = bg:GetDimensions()
        d(string.format("[VGS test] %s  size %dx%d  hidden %s",
            (bg:GetName():gsub("^ZO_SharedGamepadNavQuadrant_", "Q")),
            w, h, tostring(bg:IsHidden())))
    end
end

function VGS.ToggleTest()
    VGS.testActive = not VGS.testActive
    local win = CreateTestWindow()
    win:SetHidden(not VGS.testActive)
    SetProbes(VGS.testActive)
    if VGS.testActive then
        d("[VGS test] ON. Note which squares show (1-4), then open your inventory and look for magenta. Run the test again to turn it off.")
        ReportPanels()
        -- images load in the background; report after a moment
        zo_callLater(function()
            if VGS.testImage then
                d("[VGS test] heart image loaded: " .. tostring(VGS.testImage:IsTextureLoaded()))
            end
        end, 1500)
    else
        d("[VGS test] OFF.")
    end
end

SLASH_COMMANDS["/vgstest"] = VGS.ToggleTest

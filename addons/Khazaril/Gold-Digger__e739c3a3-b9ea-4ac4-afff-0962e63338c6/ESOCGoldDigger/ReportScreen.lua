-- Gold Digger's full-screen report: large text, split into pages, LB and RB to move between them.

local GP = ESOC_GoldDigger
local Screen = {}
GP.ReportScreen = Screen

local SCENE_NAME = "ESOCGoldDiggerReport"
local WIDTH, HEIGHT = 1640, 850
local PADDING = 30
local LINES_PER_PAGE = 16
local CHARS_PER_LINE = 76

local scene, window, titleLabel, bodyLabel, pageLabel, keybinds
local title, build = "Gold Digger", nil
local pages, pageIndex = { "" }, 1
local currentText = ""

local function linesUsed(line)
    return math.max(1, math.ceil(#line / CHARS_PER_LINE))
end

-- Splits text into screens, keeping each block together where it can.
function Screen.Paginate(text, maxLines)
    maxLines = maxLines or LINES_PER_PAGE
    local result, current, used = {}, {}, 0
    local function flush()
        while current[#current] == "" do current[#current] = nil end
        if #current > 0 then result[#result + 1] = table.concat(current, "\n") end
        current, used = {}, 0
    end
    local blocks, block = {}, {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if line == "" then
            if #block > 0 then blocks[#blocks + 1] = block end
            block = {}
        else
            block[#block + 1] = line
        end
    end
    if #block > 0 then blocks[#blocks + 1] = block end
    for _, lines in ipairs(blocks) do
        local size = 0
        for _, line in ipairs(lines) do size = size + linesUsed(line) end
        if used > 0 and used + 1 + size > maxLines then flush() end
        if used > 0 then
            current[#current + 1] = ""
            used = used + 1
        end
        for _, line in ipairs(lines) do
            local need = linesUsed(line)
            if used > 0 and used + need > maxLines then flush() end
            current[#current + 1] = line
            used = used + need
        end
    end
    flush()
    if #result == 0 then result[1] = "" end
    return result
end

local function showPage()
    if not bodyLabel then return end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    titleLabel:SetText(title)
    bodyLabel:SetText(pages[pageIndex])
    pageLabel:SetText("Page " .. pageIndex .. " of " .. #pages)
    if keybinds then pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end) end
end

-- Rebuilds the text, staying on the same page where possible.
function Screen.Refresh()
    if not build then return end
    currentText = build()
    pages = Screen.Paginate(currentText)
    showPage()
end

function Screen.CurrentText()
    return currentText
end

function Screen.IsShowing()
    local showing = false
    if scene then pcall(function() showing = SCENE_MANAGER:IsShowing(SCENE_NAME) end) end
    return showing
end

local function createWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCGoldDiggerReportWindow")
    window:SetDimensions(WIDTH, HEIGHT)
    window:SetAnchor(TOP, GuiRoot, TOP, 0, 60)
    window:SetHidden(true)
    local background = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    background:SetAnchorFill(window)
    background:SetColor(0, 0, 0, 0.88)
    titleLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    titleLabel:SetFont("ZoFontGamepad42")
    titleLabel:SetColor(0.95, 0.8, 0.4, 1)
    titleLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 18)
    pageLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    pageLabel:SetFont("ZoFontGamepad34")
    pageLabel:SetColor(0.8, 0.8, 0.8, 1)
    pageLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PADDING, 24)
    bodyLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    bodyLabel:SetFont("ZoFontGamepad34")
    bodyLabel:SetColor(0.96, 0.94, 0.86, 1)
    bodyLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 90)
    bodyLabel:SetWidth(WIDTH - PADDING * 2)
end

local function createScene()
    createWindow()
    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    if IsInGamepadPreferredMode() then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    else
        scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    end
    scene:AddFragment(ZO_SimpleSceneFragment:New(window))
    keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
        {
            name = "Start buy run", keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                local report = GP.Scanner.CachedReport()
                return title == "Gold Digger Report" and report ~= nil and #report.rows > 0 and not GP.Run.IsActive()
            end,
            callback = function()
                if GP.Run.Start() then SCENE_MANAGER:ShowBaseScene() end
            end,
        },
        {
            name = "Previous page", keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function() return pageIndex > 1 end,
            callback = function() Screen.Turn(-1) end,
        },
        {
            name = "Next page", keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function() return pageIndex < #pages end,
            callback = function() Screen.Turn(1) end,
        },
        {
            name = "Refresh", keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                GP.Scanner.MarkDirty()
                GP.Scanner.Report()
                Screen.Refresh()
            end,
        },
    }
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
            Screen.Refresh()
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
        end
    end)
end

function Screen.Turn(delta)
    pageIndex = pageIndex + delta
    showPage()
end

-- Leaves the Settings menu first, then opens the screen once that has finished.
function Screen.Open(newTitle, builder)
    title, build, pageIndex = newTitle, builder, 1
    currentText = builder()
    pages = Screen.Paginate(currentText)
    pcall(function() SCENE_MANAGER:ShowBaseScene() end)
    zo_callLater(function()
        local ok, err = pcall(function()
            if not scene then createScene() end
            SCENE_MANAGER:Show(SCENE_NAME)
        end)
        if not ok then GP.Alert("couldn't open the report: " .. tostring(err)) end
    end, 300)
end

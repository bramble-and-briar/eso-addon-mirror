-- Skill Point Finder: the full-screen view. LT/RT change tab, LB/RB change page.

local SP = ESOC_SkillPointFinder
local Screen = {}
SP.Screen = Screen

local SCENE_NAME = "ESOCSkillPointFinderScreen"
local WIDTH, HEIGHT = 1640, 860
local PADDING = 30
local LINES_PER_PAGE = 16
local CHARS_PER_LINE = 80

local scene, window, titleLabel, tabsLabel, bodyLabel, pageLabel, keybinds
local tabIndex, pageIndex, pages = 1, 1, { "" }

local function visibleLength(line)
    -- Colour codes take no space on screen
    return #(string.gsub(string.gsub(line, "|c%x%x%x%x%x%x", ""), "|r", ""))
end

local function linesUsed(line)
    return math.max(1, math.ceil(visibleLength(line) / CHARS_PER_LINE))
end

-- Splits text into pages, keeping blocks (separated by blank lines) together where it can.
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

local function tabsText()
    local parts = {}
    for i, tab in ipairs(SP.Lists.TABS) do
        parts[#parts + 1] = i == tabIndex and SP.Colour(SP.GOLD, tab.name) or SP.Colour(SP.GREY, tab.name)
    end
    return table.concat(parts, "   ")
end

local function showPage()
    if not bodyLabel then return end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    titleLabel:SetText(SP.TITLE)
    tabsLabel:SetText(tabsText())
    bodyLabel:SetText(pages[pageIndex])
    pageLabel:SetText(#pages > 1 and ("Page " .. pageIndex .. " of " .. #pages) or "")
    if keybinds then pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end) end
end

-- Builds the current tab's text again, staying on the same page where possible.
function Screen.Refresh()
    local tab = SP.Lists.TABS[tabIndex]
    local ok, text = pcall(tab.build, SP.Scan.Get())
    if not ok then text = "Something went wrong reading this tab:\n" .. tostring(text) end
    pages = Screen.Paginate(text)
    showPage()
end

function Screen.CurrentText()
    return pages[pageIndex]
end

local function onChecklist()
    return SP.Lists.TABS[tabIndex].name == "Checklist"
end

local function createWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCSkillPointFinderWindow")
    window:SetDimensions(WIDTH, HEIGHT)
    window:SetAnchor(TOP, GuiRoot, TOP, 0, 50)
    window:SetHidden(true)
    local background = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    background:SetAnchorFill(window)
    background:SetColor(0, 0, 0, 0.88)
    titleLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    titleLabel:SetFont("ZoFontGamepad42")
    titleLabel:SetColor(0.95, 0.8, 0.4, 1)
    titleLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 16)
    pageLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    pageLabel:SetFont("ZoFontGamepad34")
    pageLabel:SetColor(0.8, 0.8, 0.8, 1)
    pageLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PADDING, 22)
    tabsLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    tabsLabel:SetFont("ZoFontGamepad27")
    tabsLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 74)
    bodyLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    bodyLabel:SetFont("ZoFontGamepad34")
    bodyLabel:SetColor(0.96, 0.94, 0.86, 1)
    bodyLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 124)
    bodyLabel:SetWidth(WIDTH - PADDING * 2)
end

function Screen.Tab(delta)
    local count = #SP.Lists.TABS
    tabIndex = ((tabIndex - 1 + delta) % count) + 1
    pageIndex = 1
    Screen.Refresh()
end

function Screen.Turn(delta)
    pageIndex = pageIndex + delta
    showPage()
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
            name = "Queue missing (normal)", keybind = "UI_SHORTCUT_PRIMARY",
            visible = onChecklist,
            callback = function() SP.Queue.Start(false) end,
        },
        {
            name = "Queue missing (veteran)", keybind = "UI_SHORTCUT_TERTIARY",
            visible = onChecklist,
            callback = function() SP.Queue.Start(true) end,
        },
        {
            name = function() return SP.sv.options.missingOnly and "Show everything" or "Missing only" end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = onChecklist,
            callback = function()
                SP.sv.options.missingOnly = not SP.sv.options.missingOnly
                Screen.Refresh()
            end,
        },
        { name = "Previous tab", keybind = "UI_SHORTCUT_LEFT_TRIGGER", callback = function() Screen.Tab(-1) end },
        { name = "Next tab", keybind = "UI_SHORTCUT_RIGHT_TRIGGER", callback = function() Screen.Tab(1) end },
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
    }
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
            SP.MarkDirty()
            Screen.Refresh()
            if not SP.Scan.IndexReady() then
                SP.Scan.StartIndex(function()
                    if SCENE_MANAGER:IsShowing(SCENE_NAME) then Screen.Refresh() end
                end)
            end
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
        end
    end)
end

-- Leaves the Settings menu first, then opens the screen on the chosen tab.
function Screen.Open(tabName)
    for i, tab in ipairs(SP.Lists.TABS) do
        if tab.name == tabName then tabIndex = i end
    end
    pageIndex = 1
    pcall(function() SCENE_MANAGER:ShowBaseScene() end)
    zo_callLater(function()
        local ok, err = pcall(function()
            if not scene then createScene() end
            SCENE_MANAGER:Show(SCENE_NAME)
        end)
        if not ok then SP.Alert("couldn't open the screen: " .. tostring(err)) end
    end, 300)
end

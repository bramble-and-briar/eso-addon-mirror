-- TCM 0.2.45: motif Show on Map now uses ESO's native quest-ping flow after the target map is open.
local TC = TamrielCollections
local CATEGORY_DEFS = {
    { name = 'Motifs', key = 'motifs' },
    { name = 'Style Pages', key = 'stylePages', icon = 'EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds' },
    { name = 'Antiquities', key = 'antiquities', icon = 'EsoUI/Art/TreeIcons/gamepad/GP_antiquities_indexIcon_scryable.dds' },
    { name = 'Furnishing Plans', key = 'furnishingPlans', icon = 'EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_up.dds' },
    { name = 'Lorebooks', key = 'lorebooks', icon = 'EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds' },
}
local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()
local motifMiddleContent = nil
local motifMiddlePane = nil
-- Style entries use the existing native Quest Journal template, with the
-- label aligned centrally in its available row rather than left aligned.
local function SetupCenteredStyleEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    -- The icon is now part of the centered label text, not a separate
    -- Quest Journal control anchored to the original row's left edge.
    local nativeIcon = control:GetNamedChild('Icon')
    if nativeIcon then nativeIcon:SetHidden(true) end
    local selectedIcon = control:GetNamedChild('SelectedIcon')
    if selectedIcon then selectedIcon:SetHidden(true) end
    local label = control:GetNamedChild('Label')
    if label then
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        if motifMiddleContent then
            -- Native rows are positioned by the middle list itself. Never
            -- derive a label anchor from GetLeft() screen coordinates: rows
            -- can be recycled before their screen positions are finalized.
            -- Keep a constant local anchor through first load and reopening.
            -- The Content viewport can be narrower than its parent quadrant.
            -- Size the label against the actual middle pane, not the native
            -- Quest Journal entry's original narrow label bounds.
            local paneWidth = motifMiddlePane and motifMiddlePane:GetWidth() or 0
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, control, TOPLEFT, 20, 0)
            if paneWidth > 120 then
                label:SetWidth(paneWidth - 60)
            end
        end
    end
end

local function SetupCompactDetailEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    local label = control:GetNamedChild('Label')
    if label then label:SetFont('ZoFontGamepad27') end
end

local function MakeDetailLabel(parent, name, font, height)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetHeight(height)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function MakeDivider(parent, name)
    local line = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    line:SetTexture('EsoUI/Art/Miscellaneous/horizontalDivider.dds')
    line:SetColor(1, 0.92, 0.70, 1)
    line:SetHeight(4)
    return line
end


local function MotifCollections()
    local result = {}
    if not (GetNumLoreCategories and GetLoreCategoryInfo and GetLoreCollectionInfo) then return result end
    for category = 1, GetNumLoreCategories() do
        local name, count = GetLoreCategoryInfo(category)
        -- Localized ESO category label; the game supplies the motif category.
        if name and (zo_strlower(name):find('motif', 1, true) or zo_strlower(name):find('crafting', 1, true)) then
            for collection = 1, count do
                local title, description, known, total, hidden, icon = GetLoreCollectionInfo(category, collection)
                if not hidden and total and total > 0 then
                    result[#result + 1] = { name = title, description = description, known = known or 0,
                        total = total, category = category, collection = collection, icon = icon }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        -- Prioritize motifs closest to completion. Fully completed motifs
        -- are always placed after every incomplete motif.
        local aMissing = math.max((a.total or 0) - (a.known or 0), 0)
        local bMissing = math.max((b.total or 0) - (b.known or 0), 0)
        local aComplete = aMissing == 0
        local bComplete = bMissing == 0
        if aComplete ~= bComplete then
            return not aComplete
        end
        if not aComplete and aMissing ~= bMissing then
            return aMissing < bMissing
        end
        -- Stable, predictable tie-breaker for motifs with equal completion.
        return zo_strlower(a.name or '') < zo_strlower(b.name or '')
    end)
    return result
end

local function GetMotifNumber(style)
    if not style then return nil end
    if style.motifNumber ~= nil then
        return style.motifNumber ~= false and style.motifNumber or nil
    end
    if GetLoreBookInfo and style.category and style.collection then
        for bookIndex = 1, (style.total or 0) do
            local title = GetLoreBookInfo(style.category, style.collection, bookIndex)
            if title and title ~= '' then
                local number = title:match('^[Cc]rafting [Mm]otif%s+(%d+)%s*:')
                if number then
                    style.motifNumber = tonumber(number) or number
                    return style.motifNumber
                end
            end
        end
    end
    -- Cache a miss as false so typing several characters does not repeatedly
    -- rescan every chapter of styles that do not expose a numbered title.
    style.motifNumber = false
    return nil
end


local styleAchievementIndex = nil

local function NormalizeMatchText(text)
    text = zo_strlower(zo_strformat(text or ''))
    text = text:gsub('[%p%c]+', ' ')
    text = text:gsub('%s+', ' ')
    return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local function GetStyleBaseName(styleName)
    return (styleName or ''):gsub('%s+[Ss]tyle%s*$', '')
end

local function BuildStyleAchievementIndex()
    if styleAchievementIndex then return styleAchievementIndex end
    styleAchievementIndex = {}
    if not (GetNumAchievementCategories and GetAchievementCategoryInfo and GetAchievementId and GetAchievementInfo) then
        return styleAchievementIndex
    end

    local generalName = (GetString and SI_JOURNAL_PROGRESS_CATEGORY_GENERAL)
        and GetString(SI_JOURNAL_PROGRESS_CATEGORY_GENERAL) or 'General'

    local function AddAchievement(categoryIndex, subCategoryIndex, categoryName, subCategoryName, achievementIndex)
        local achievementId = GetAchievementId(categoryIndex, subCategoryIndex, achievementIndex)
        if not achievementId or achievementId == 0 then return end
        local name, description, points, icon, completed = GetAchievementInfo(achievementId)
        local normalizedName = NormalizeMatchText(name)
        local normalizedDescription = NormalizeMatchText(description)
        if not (normalizedName:find('style', 1, true) and normalizedName:find('master', 1, true))
            and not normalizedDescription:find('style book', 1, true) then
            return
        end
        local location = categoryName
        if subCategoryName and subCategoryName ~= '' and subCategoryName ~= generalName then
            location = subCategoryName
        end
        styleAchievementIndex[#styleAchievementIndex + 1] = {
            id = achievementId,
            name = zo_strformat(name or ''),
            description = zo_strformat(description or ''),
            points = points,
            icon = icon,
            completed = completed,
            categoryName = categoryName,
            subCategoryName = subCategoryName,
            location = location,
            normalizedName = normalizedName,
            normalizedDescription = normalizedDescription,
        }
    end

    for categoryIndex = 1, GetNumAchievementCategories() do
        local categoryName, numSubCategories, numAchievements = GetAchievementCategoryInfo(categoryIndex)
        for achievementIndex = 1, (numAchievements or 0) do
            AddAchievement(categoryIndex, nil, categoryName, nil, achievementIndex)
        end
        for subCategoryIndex = 1, (numSubCategories or 0) do
            local subCategoryName, subNumAchievements = GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)
            for achievementIndex = 1, (subNumAchievements or 0) do
                AddAchievement(categoryIndex, subCategoryIndex, categoryName, subCategoryName, achievementIndex)
            end
        end
    end
    return styleAchievementIndex
end

local function FindStyleAchievement(styleName)
    local baseName = GetStyleBaseName(styleName)
    local normalizedBase = NormalizeMatchText(baseName)
    local normalizedExact = NormalizeMatchText(baseName .. ' Style Master')
    local best, bestScore = nil, 0
    for _, achievement in ipairs(BuildStyleAchievementIndex()) do
        local score = 0
        if achievement.normalizedName == normalizedExact then
            score = 100
        elseif achievement.normalizedName:find(normalizedBase, 1, true)
            and achievement.normalizedName:find('style', 1, true)
            and achievement.normalizedName:find('master', 1, true) then
            score = 80
        elseif achievement.normalizedDescription:find(normalizedBase, 1, true) then
            score = 60
        end
        if score > bestScore then
            best, bestScore = achievement, score
        end
    end
    return best
end

local function AcquisitionSourceFromAchievement(description)
    local text = zo_strformat(description or '')
    local trimmed = text:gsub('^Learn every chapter in the .- style book,%s*', '')
    trimmed = trimmed:gsub('^Learn every chapter in the .- style,%s*', '')
    if trimmed == '' then return text end
    return trimmed
end


-- Map support ---------------------------------------------------------------
-- Most dungeon/trial motifs can be resolved directly from ESO's own
-- acquisition text because the source description contains the activity name.
-- A small override table handles repeatable-quest motifs whose source text
-- names only the quest/zone rather than the actual quest hub.
local MOTIF_MAP_PIN_TYPE_STRING = 'TCM_MOTIF_SOURCE_PIN'
local activeMotifMapTarget = nil
local fastTravelNodes = nil

local MOTIF_MAP_TARGET_OVERRIDES = {
    ['minotaur style'] = 'Kvatch',
    ['order hour style'] = 'Kvatch',
    ['order of the hour style'] = 'Kvatch',
}

local MAP_NODE_GENERIC_WORDS = {
    wayshrine = true,
    dungeon = true,
    trial = true,
    arena = false, -- Arena is often part of the meaningful activity name.
}

local function GetNodeCoreName(name)
    local normalized = NormalizeMatchText(name)
    local words = {}
    for word in normalized:gmatch('%S+') do
        if not MAP_NODE_GENERIC_WORDS[word] then
            words[#words + 1] = word
        end
    end
    return table.concat(words, ' ')
end

local function BuildFastTravelNodeIndex()
    if fastTravelNodes then return fastTravelNodes end
    fastTravelNodes = {}
    if not (GetNumFastTravelNodes and GetFastTravelNodeInfo and GetFastTravelNodePOIIndicies) then
        return fastTravelNodes
    end
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, name = GetFastTravelNodeInfo(nodeIndex)
        local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
        if name and name ~= '' and zoneIndex and poiIndex then
            fastTravelNodes[#fastTravelNodes + 1] = {
                nodeIndex = nodeIndex,
                name = zo_strformat(name),
                normalizedName = NormalizeMatchText(name),
                coreName = GetNodeCoreName(name),
                zoneIndex = zoneIndex,
                poiIndex = poiIndex,
            }
        end
    end
    return fastTravelNodes
end

local function ScoreNodeAgainstText(node, sourceText, styleText)
    local score = 0
    local core = node.coreName
    if core ~= '' and #core >= 4 then
        if sourceText:find(core, 1, true) then
            score = math.max(score, 100 + #core)
        end
        if styleText ~= '' and (core:find(styleText, 1, true) or styleText:find(core, 1, true)) then
            score = math.max(score, 80 + math.min(#core, #styleText))
        end

        -- When a source says "Kvatch Arena" while the map node is
        -- "Kvatch Wayshrine", the significant shared word still identifies
        -- the correct hub. Require a reasonably specific word to avoid noisy
        -- matches such as "city" or "the".
        for word in core:gmatch('%S+') do
            if #word >= 5 and sourceText:find(word, 1, true) then
                score = math.max(score, 40 + #word)
            end
        end
    end
    return score
end

local function FindFastTravelNodeForStyle(style)
    if not style then return nil end
    if style._tcmMapTargetResolved then
        return style._tcmMapTarget ~= false and style._tcmMapTarget or nil
    end

    local styleName = style.name or ''
    local normalizedStyleName = NormalizeMatchText(styleName)
    local styleBase = NormalizeMatchText(GetStyleBaseName(styleName))
    local achievement = FindStyleAchievement(styleName)
    local sourceText = NormalizeMatchText(achievement and AcquisitionSourceFromAchievement(achievement.description)
        or style.description or '')

    local overrideTarget = MOTIF_MAP_TARGET_OVERRIDES[normalizedStyleName]
    local bestNode, bestScore = nil, 0

    for _, node in ipairs(BuildFastTravelNodeIndex()) do
        local score = 0
        if overrideTarget then
            local target = NormalizeMatchText(overrideTarget)
            if node.normalizedName == target or node.coreName == target then
                score = 1000
            elseif node.normalizedName:find(target, 1, true) or node.coreName:find(target, 1, true) then
                score = 950
            end
        else
            score = ScoreNodeAgainstText(node, sourceText, styleBase)
        end

        if score > bestScore then
            bestNode, bestScore = node, score
        end
    end

    -- Require a meaningful automatic match. Overrides always score >= 950.
    if bestNode and bestScore >= 45 then
        style._tcmMapTarget = bestNode
    else
        style._tcmMapTarget = false
    end
    style._tcmMapTargetResolved = true
    return style._tcmMapTarget ~= false and style._tcmMapTarget or nil
end

local function FindMapIndexForZoneIndex(zoneIndex)
    if not zoneIndex then return nil end
    if GetZoneId and GetMapIndexByZoneId then
        local zoneId = GetZoneId(zoneIndex)
        if zoneId then
            local mapIndex = GetMapIndexByZoneId(zoneId)
            if mapIndex and mapIndex > 0 then return mapIndex end
        end
    end
    if GetNumMaps and GetMapInfoByIndex then
        for mapIndex = 1, GetNumMaps() do
            local _, _, _, candidateZoneIndex = GetMapInfoByIndex(mapIndex)
            if candidateZoneIndex == zoneIndex then return mapIndex end
        end
    end
    return nil
end

local function EnsureMotifMapPinType()
    local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
    if not pinManager then return nil, nil end

    if _G[MOTIF_MAP_PIN_TYPE_STRING] == nil then
        pinManager:AddCustomPin(
            MOTIF_MAP_PIN_TYPE_STRING,
            function(manager)
                if activeMotifMapTarget
                    and activeMotifMapTarget.mapIndex == GetCurrentMapIndex()
                    and activeMotifMapTarget.x and activeMotifMapTarget.y then
                    manager:CreatePin(_G[MOTIF_MAP_PIN_TYPE_STRING], activeMotifMapTarget.label,
                        activeMotifMapTarget.x, activeMotifMapTarget.y)
                end
            end,
            nil,
            {
                level = 145,
                minSize = 100,
                texture = 'EsoUI/Art/MapPins/QuestPing.dds',
                isAnimated = true,
                framesWide = 32,
                framesHigh = 1,
                framesPerSecond = 32,
            },
            nil
        )
    end

    local pinType = _G[MOTIF_MAP_PIN_TYPE_STRING]
    if pinType then pinManager:SetCustomPinEnabled(pinType, true) end
    return pinManager, pinType
end

local function GetMapCoordinatesForNode(node)
    if not node then return nil, nil end
    local x, y = nil, nil
    if GetPOIMapInfo then
        x, y = GetPOIMapInfo(node.zoneIndex, node.poiIndex)
    end
    if (not x or not y or (x == 0 and y == 0)) and GetFastTravelNodeInfo then
        local _, _, nodeX, nodeY = GetFastTravelNodeInfo(node.nodeIndex)
        x, y = nodeX, nodeY
    end
    return x, y
end


function Screen:Initialize(control)
    TC.initStage = 'scene'
    self.scene = ZO_Scene:New('tamrielCollectionsGamepad', SCENE_MANAGER)
    -- The Quest Journal normally inherits these through the game's UI
    -- scene stack. A standalone addon scene must explicitly acquire them.
    if GAMEPAD_UI_MODE_FRAGMENT then
        self.scene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT)
    end
    if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then
        self.scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT)
    end
    -- Native ESO scenes include both of these fragments. Without them
    -- the bottom action bar does not appear or own shortcut bindings.
    if KEYBIND_STRIP_GAMEPAD_FRAGMENT then
        self.scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
    end
    if KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT then
        self.scene:AddFragment(KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT)
    end

    -- Exact native Quest Journal screen template, including MiddlePane and RightPane.
    TC.initStage = 'native screen constructor'
    assert(control, 'TCMQuestJournalTL missing (XML did not create control)')
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, self.scene)
    self.fragment = ZO_FadeSceneFragment:New(control, true)
    -- Do NOT call SetParentFragment: it detaches the scene state callback.
    self.scene:AddFragment(self.fragment)
    if GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then self.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT) end
    if GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT then self.scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT) end
    if GAMEPAD_NAV_QUADRANT_4_BACKGROUND_FRAGMENT then self.scene:AddFragment(GAMEPAD_NAV_QUADRANT_4_BACKGROUND_FRAGMENT) end

    TC.initStage = 'native lists'
    self.categoryList = self:GetMainList()
    self.styleList = self:AddList('MotifStyles')
    self.detailList = self:AddList('MotifDetails')
    self.categoryList:AddDataTemplate('ZO_QuestJournal_Gamepad_MenuEntryTemplate', ZO_SharedGamepadEntry_OnSetup)
    self.styleList:AddDataTemplate('ZO_QuestJournal_Gamepad_MenuEntryTemplate', SetupCenteredStyleEntry)
    self.detailList:AddDataTemplate('ZO_QuestJournal_Gamepad_MenuEntryTemplate', SetupCompactDetailEntry)
    -- Native parametric lists add up to 40px around the selected entry.
    -- The motif chapter list is deliberately denser, while preserving
    -- native scrolling/selection behavior.
    self.detailList:SetSelectedItemOffsets(0, 12)
    -- Add each list's fragment to the scene permanently. The stock screen
    -- removes the previous list fragment on focus changes, which makes its
    -- entire panel disappear. We only want to deactivate its input.
    for _, list in ipairs({ self.categoryList, self.styleList, self.detailList }) do
        local fragment = self:GetListFragment(list)
        if fragment then self.scene:AddFragment(fragment) end
    end
    self.categoryList:SetOnTargetDataChangedCallback(function(_, data)
        if self.mode == 'categories' then self:ShowCategory(data) end
        self:RefreshKeybinds()
    end)
    self.styleList:SetOnTargetDataChangedCallback(function(_, data)
        if self.mode == 'styles' or self.mode == 'details' then self:ShowStyle(data) end
        self:RefreshKeybinds()
    end)
    TC.initStage = 'quest journal panels'
    self.middle = assert(control:GetNamedChild('MiddlePane'), 'MiddlePane missing')
    self.right = assert(control:GetNamedChild('RightPane'), 'RightPane missing')
    self.middleText = self.middle:GetNamedChild('Container'):GetNamedChild('Content'):
        GetNamedChild('QuestInfoContainer'):GetNamedChild('ScrollChild'):GetNamedChild('BGText')
    self.middleSteps = self.middle:GetNamedChild('Container'):GetNamedChild('Content'):
        GetNamedChild('QuestInfoContainer'):GetNamedChild('ScrollChild'):GetNamedChild('StepText')
    self.rightText = self.right:GetNamedChild('ContainerContent'):GetNamedChild('QuestStep'):
        GetNamedChild('ScrollChild'):GetNamedChild('ConditionLabel')
    -- The right quadrant's actual content viewport is Container > Content.
    -- Never anchor the list to the old quest step's scroll child or the
    -- native parametric list's original full-screen parent.
    local rightContent = self.right:GetNamedChild('Container'):GetNamedChild('Content')
    local detailControl = self.detailList:GetControl()
    self.detailControl = detailControl
    detailControl:SetParent(rightContent)
    detailControl:ClearAnchors()
    detailControl:SetAnchor(TOPLEFT, rightContent, TOPLEFT, 0, 0)
    detailControl:SetAnchor(BOTTOMRIGHT, rightContent, BOTTOMRIGHT, 0, 0)
    self.detailList:SetAlignToScreenCenter(false)
    -- The right pane is one stable information card: heading / chapter list /
    -- acquisition text. Only the chapter list receives gamepad scroll focus.
    self.detailHeading = MakeDetailLabel(rightContent, 'TCMMotifDetailHeading', 'ZoFontGamepad27', 42)
    self.detailHeading:SetAnchor(TOPLEFT, rightContent, TOPLEFT, 18, 0)
    self.detailHeading:SetAnchor(TOPRIGHT, rightContent, TOPRIGHT, -18, 0)
    self.detailHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailHeading:SetText('')
    self.detailIcon = WINDOW_MANAGER:CreateControl('TCMMotifDetailIcon', rightContent, CT_TEXTURE)
    self.detailIcon:SetDimensions(128, 128)
    -- This texture is reserved for the category-focus splash. Motif detail
    -- headings continue to use their inline icon so icon + title center together.
    -- The -82 offset is the midpoint of the space between the two fixed dividers
    -- (top at 56, bottom at content height - 220).
    self.detailIcon:SetAnchor(CENTER, rightContent, CENTER, 0, -82)
    self.detailIcon:SetHidden(true)

    self.detailTopLine = MakeDivider(rightContent, 'TCMMotifDetailTopLine')
    self.detailTopLine:SetAnchor(TOPLEFT, rightContent, TOPLEFT, 0, 56)
    self.detailTopLine:SetAnchor(TOPRIGHT, rightContent, TOPRIGHT, 0, 56)
    self.detailBottomLine = MakeDivider(rightContent, 'TCMMotifDetailBottomLine')
    -- Reserve a real acquisition/details block below the chapter list.
    self.detailBottomLine:SetAnchor(BOTTOMLEFT, rightContent, BOTTOMLEFT, 0, -220)
    self.detailBottomLine:SetAnchor(BOTTOMRIGHT, rightContent, BOTTOMRIGHT, 0, -220)

    self.detailAcquisition = MakeDetailLabel(rightContent, 'TCMMotifAcquisition', 'ZoFontGamepad25', 30)
    self.detailAcquisition:SetAnchor(TOPLEFT, self.detailBottomLine, BOTTOMLEFT, 18, 7)
    self.detailAcquisition:SetAnchor(TOPRIGHT, self.detailBottomLine, BOTTOMRIGHT, -18, 7)
    self.detailAcquisition:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailAcquisition:SetText('')

    self.detailWhereTitle = MakeDetailLabel(rightContent, 'TCMMotifWhereTitle', 'ZoFontGamepad25', 28)
    self.detailWhereTitle:SetAnchor(TOPLEFT, self.detailAcquisition, BOTTOMLEFT, 0, 4)
    self.detailWhereTitle:SetAnchor(TOPRIGHT, self.detailAcquisition, BOTTOMRIGHT, 0, 4)
    self.detailWhereTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailWhereTitle:SetText('Where to obtain:')

    self.detailLocation = MakeDetailLabel(rightContent, 'TCMMotifLocation', 'ZoFontGamepad25', 30)
    self.detailLocation:SetAnchor(TOPLEFT, self.detailWhereTitle, BOTTOMLEFT, 0, 3)
    self.detailLocation:SetAnchor(TOPRIGHT, self.detailWhereTitle, BOTTOMRIGHT, 0, 3)
    self.detailLocation:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailLocation:SetText('')

    self.detailSource = MakeDetailLabel(rightContent, 'TCMMotifSource', 'ZoFontGamepad22', 58)
    self.detailSource:SetAnchor(TOPLEFT, self.detailLocation, BOTTOMLEFT, 4, 4)
    self.detailSource:SetAnchor(TOPRIGHT, self.detailLocation, BOTTOMRIGHT, -4, 4)
    self.detailSource:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailSource:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.detailSource:SetMaxLineCount(3)
    self.detailSource:SetText('')

    self.detailAchievement = MakeDetailLabel(rightContent, 'TCMMotifAchievement', 'ZoFontGamepad22', 34)
    self.detailAchievement:SetAnchor(TOPLEFT, self.detailSource, BOTTOMLEFT, 0, 6)
    self.detailAchievement:SetAnchor(TOPRIGHT, self.detailSource, BOTTOMRIGHT, 0, 6)
    self.detailAchievement:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.detailAchievement:SetMaxLineCount(2)
    self.detailAchievement:SetText('')

    detailControl:ClearAnchors()
    detailControl:SetAnchor(TOPLEFT, rightContent, TOPLEFT, 0, 53)
    detailControl:SetAnchor(BOTTOMRIGHT, rightContent, BOTTOMRIGHT, 0, -250)

    self.rightText:SetHidden(true)
    -- Hide original quest tasks, which are unrelated to motif chapters.
    self.right:GetNamedChild('Container'):GetNamedChild('Content'):
        GetNamedChild('QuestStep'):SetHidden(true)
    -- Reparent the native style list into the Quest Journal's middle pane.
    -- It remains a real gamepad parametric list, with native analog scrolling.
    local content = self.middle:GetNamedChild('Container'):GetNamedChild('Content')

    -- Native ESO gamepad search control, relocated into the top of the motif
    -- pane instead of the global screen header. Keep its original transparent
    -- presentation; the motif scroll viewport itself is hard-clipped below the
    -- gold divider so recycled rows can never draw through the search header.
    -- Solid visual shield for the search header. It deliberately lives on
    -- the controls layer ABOVE recycled motif rows, but BELOW the search box
    -- and divider, so list text cannot bleed through without changing the
    -- search icon/text/divider presentation.
    -- Use ESO's own gamepad panel texture as the visual shield instead of
    -- a flat black rectangle. This keeps the header visually consistent with
    -- the surrounding quadrant while still covering recycled list rows.
    self.motifSearchBackdrop = WINDOW_MANAGER:CreateControl('TCMMotifSearchBackdrop', content, CT_TEXTURE)
    self.motifSearchBackdrop:ClearAnchors()
    self.motifSearchBackdrop:SetAnchor(TOPLEFT, content, TOPLEFT, 0, -2)
    self.motifSearchBackdrop:SetAnchor(TOPRIGHT, content, TOPRIGHT, 0, -2)
    self.motifSearchBackdrop:SetHeight(76)
    self.motifSearchBackdrop:SetTexture('EsoUI/Art/Windows/Gamepad/panelBG_focus_512.dds')
    self.motifSearchBackdrop:SetColor(1, 1, 1, 0.96)
    self.motifSearchBackdrop:SetDrawLayer(DL_CONTROLS)
    self.motifSearchBackdrop:SetDrawLevel(50)

    self.motifSearchControl = CreateControlFromVirtual('TCMMotifSearchContainer', content, 'ZO_Gamepad_TextSearch_HeaderEditbox')
    self.motifSearchControl:SetDimensions(374, 72)
    self.motifSearchControl:SetAnchor(TOP, content, TOP, 0, -4)
    self.motifSearchControl:SetDrawLayer(DL_CONTROLS)
    self.motifSearchControl:SetDrawLevel(60)
    self.motifSearchFocus = ZO_TextSearch_Header_Gamepad:New(self.motifSearchControl, function(editBox)
        self:OnMotifSearchTextChanged(editBox:GetText())
    end)
    local motifSearchEdit = self.motifSearchFocus:GetEditBox()
    motifSearchEdit:SetDefaultText('Search Motifs')
    -- Keep search affordances bright above the shield; the native template
    -- defaults both the icon and edit text to the disabled text color.
    if motifSearchEdit.SetColor then motifSearchEdit:SetColor(1, 1, 1, 1) end
    local motifSearchFilter = self.motifSearchControl:GetNamedChild('Filter')
    if motifSearchFilter then
        local motifSearchIcon = motifSearchFilter:GetNamedChild('Icon')
        if motifSearchIcon then motifSearchIcon:SetColor(1, 1, 1, 1) end
    end
    self.motifSearchFocus:RegisterCallback('EditBoxFocusLost', function()
        self.motifSearchFocus:Deactivate()
        self:RefreshKeybinds()
    end)

    self.motifSearchLine = MakeDivider(content, 'TCMMotifSearchDivider')
    self.motifSearchLine:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 70)
    self.motifSearchLine:SetAnchor(TOPRIGHT, content, TOPRIGHT, 0, 70)
    self.motifSearchLine:SetDrawLayer(DL_CONTROLS)
    self.motifSearchLine:SetDrawLevel(61)

    local listContainer = self.styleList:GetControl():GetParent()
    listContainer:SetParent(content)
    listContainer:ClearAnchors()
    -- Center the entire list viewport, not only each label within a
    -- left-positioned native Quest Journal row.
    listContainer:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 76)
    listContainer:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, 0, 0)
    -- ESO's parametric list retains a TOPLEFT anchor to its original
    -- screen HeaderContainer even after its parent viewport is reparented.
    -- Anchor the actual scroll list to the relocated viewport instead.
    local scrollControl = self.styleList:GetControl()
    scrollControl:ClearAnchors()
    scrollControl:SetAnchor(TOPLEFT, listContainer, TOPLEFT, 0, 0)
    scrollControl:SetAnchor(BOTTOMRIGHT, listContainer, BOTTOMRIGHT, 0, 0)
    -- Parametric-list rows are children of the native Scroll control. ESO's
    -- Scroll uses fade gradients by default, which allows rows to remain partly
    -- visible outside the intended viewport. Hard-clip children to the viewport
    -- so motif names stop exactly below the search divider without an opaque mask.
    local styleScrollArea = self.styleList:GetScrollControl()
    if styleScrollArea and styleScrollArea.SetAutoRectClipChildren then
        styleScrollArea:SetAutoRectClipChildren(true)
    end
    motifMiddleContent = content
    motifMiddlePane = self.middle
    self.styleList:SetAlignToScreenCenter(false)
    -- The quest description labels are not a motif list; hide them.
    self.middleText:SetHidden(true)
    self.middleSteps:SetHidden(true)
    TC.initStage = 'header and categories'
    self.headerData = { titleText = 'COLLECTIONS' }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)

    -- Replace the stock Quest Journal screen-header divider with the same
    -- gold horizontalDivider texture used by the middle and right panels.
    -- Keep the native divider control in place as the positioning reference.
    local nativeHeaderDivider = self.header:GetNamedChild('DividerSimple')
    if nativeHeaderDivider then
        nativeHeaderDivider:SetHidden(true)
        self.collectionsHeaderLine = MakeDivider(self.header, 'TCMCollectionsHeaderLine')
        self.collectionsHeaderLine:SetAnchor(LEFT, nativeHeaderDivider, LEFT, 0, 0)
        self.collectionsHeaderLine:SetAnchor(RIGHT, nativeHeaderDivider, RIGHT, 0, 0)

        -- Permanent Collections emblem in the left panel. Use the exact
        -- custom texture that is confirmed to render on PlayStation.
        self.collectionsHeaderLogo = WINDOW_MANAGER:CreateControl('TCMCollectionsHeaderLogo', self.header, CT_TEXTURE)
        self.collectionsHeaderLogo:SetDimensions(128, 128)
        self.collectionsHeaderLogo:SetAnchor(TOP, self.collectionsHeaderLine, BOTTOM, 0, 26)
        self.collectionsHeaderLogo:SetTexture('TamrielCollectionsMotifs/art/collections_puzzle_native_v4.dds')
        self.collectionsHeaderLogo:SetDrawLayer(DL_CONTROLS)
        self.collectionsHeaderLogo:SetDrawLevel(20)

        -- Frame the emblem and category menu with matching gold dividers.
        -- Each divider uses only two corner anchors, avoiding the three-anchor
        -- conflict that broke v0.2.40.
        self.collectionsLogoBottomLine = MakeDivider(self.header, 'TCMCollectionsLogoBottomLine')
        self.collectionsLogoBottomLine:SetAnchor(TOPLEFT, self.collectionsHeaderLine, BOTTOMLEFT, 0, 178)
        self.collectionsLogoBottomLine:SetAnchor(TOPRIGHT, self.collectionsHeaderLine, BOTTOMRIGHT, 0, 178)

        self.collectionsMenuBottomLine = MakeDivider(self.header, 'TCMCollectionsMenuBottomLine')
        self.collectionsMenuBottomLine:SetAnchor(TOPLEFT, self.collectionsHeaderLine, BOTTOMLEFT, 0, 610)
        self.collectionsMenuBottomLine:SetAnchor(TOPRIGHT, self.collectionsHeaderLine, BOTTOMRIGHT, 0, 610)

        -- The native Quest Journal main list is anchored below HeaderContainer,
        -- which places the category rows beneath our custom framed area.
        -- Move the whole list viewport into the left header and constrain it
        -- between the emblem divider and the lower menu divider.  Do not touch
        -- individual entry anchors; ESO keeps full parametric scrolling/focus.
        local categoryControl = self.categoryList:GetControl()
        local categoryContainer = categoryControl and categoryControl:GetParent()
        if categoryContainer then
            categoryContainer:SetParent(self.header)
            categoryContainer:ClearAnchors()
            categoryContainer:SetAnchor(TOPLEFT, self.collectionsLogoBottomLine, BOTTOMLEFT, 0, 10)
            categoryContainer:SetAnchor(BOTTOMRIGHT, self.collectionsMenuBottomLine, TOPRIGHT, 0, -10)

            categoryControl:ClearAnchors()
            categoryControl:SetAnchor(TOPLEFT, categoryContainer, TOPLEFT, 0, 0)
            categoryControl:SetAnchor(BOTTOMRIGHT, categoryContainer, BOTTOMRIGHT, 0, 0)
        end
    end
    self.mode = 'categories'
    self.styles = {}
    self:BuildCategories()
end

-- Preserve all list fragments and only transfer analog focus. These
-- overrides intentionally omit the base class fragment add/remove calls.
function Screen:DisableCurrentList()
    if self._currentList then
        self:DeactivateCurrentList()
        self._currentList = nil
    end
end

function Screen:EnableCurrentList()
    if self._currentList then self:ActivateCurrentList() end
end

function Screen:ShowSelectedMotifOnMap()
    local data = self.styleList and self.styleList:GetTargetData() or nil
    local style = data and data.style or nil
    if not style then return end

    if WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
        return
    end

    local node = FindFastTravelNodeForStyle(style)
    if not node then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'No exact map location is available for this motif yet.')
        return
    end

    local mapIndex = FindMapIndexForZoneIndex(node.zoneIndex)
    if not mapIndex then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'The motif location could not be opened on the map.')
        return
    end

    -- ESO's Quest Journal opens the world map, changes to the quest map,
    -- creates a MAP_PIN_TYPE_QUEST_PING, and then jumps the camera to that pin.
    -- Do the same sequence here. Setting the map before opening the gamepad map
    -- lets the map scene reset back to the player's current location, which was
    -- the failure mode in v0.2.44.
    local function ShowTargetOnOpenMap()
        if not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return end

        local result = SetMapToMapListIndex(mapIndex)
        if result == SET_MAP_RESULT_FAILED then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'The motif location could not be opened on the map.')
            return
        end

        if result == SET_MAP_RESULT_MAP_CHANGED then
            CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged')
        else
            -- The map may already be the desired zone. Refresh pings anyway so
            -- the native pin manager has current controls before we add ours.
            WORLD_MAP_MANAGER:RefreshMapPings()
        end

        zo_callLater(function()
            if GetCurrentMapIndex() ~= mapIndex then
                return
            end

            local x, y = nil, nil
            local isShownInCurrentMap = false
            if GetPOIMapInfo then
                x, y, _, _, isShownInCurrentMap = GetPOIMapInfo(node.zoneIndex, node.poiIndex)
            end

            -- Some fast-travel nodes expose their normalized coordinates more
            -- reliably through GetFastTravelNodeInfo once their zone map is active.
            if not isShownInCurrentMap or not x or not y or (x == 0 and y == 0) then
                if GetFastTravelNodeInfo then
                    local _, _, nodeX, nodeY = GetFastTravelNodeInfo(node.nodeIndex)
                    x, y = nodeX, nodeY
                end
            end

            if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'The motif location has no usable map coordinates.')
                return
            end

            local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
            if not pinManager then return end

            -- Clear an earlier motif/quest ping and create ESO's actual animated
            -- quest ping, the same blue-circle pin type used by Show on Map.
            pinManager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING)
            local pinTag = 'TCM_MOTIF_SOURCE'
            local pin = pinManager:CreatePin(MAP_PIN_TYPE_QUEST_PING, pinTag, x, y)
            if not pin then return end

            local panAndZoom = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom() or nil
            if panAndZoom then
                panAndZoom:JumpToPinWhenAvailable(function()
                    return pinManager:FindPin('pings', MAP_PIN_TYPE_QUEST_PING, pinTag)
                end)
            end
        end, 75)
    end

    if not ZO_WorldMap_IsWorldMapShowing() then
        -- Open the map first. Once the gamepad map scene has initialized at the
        -- player's location, switch it to the motif target so it cannot snap back.
        if IsInGamepadPreferredMode() then
            SCENE_MANAGER:Push('gamepad_worldMap')
        else
            ZO_WorldMap_ShowWorldMap()
        end
        zo_callLater(ShowTargetOnOpenMap, 125)
    else
        ShowTargetOnOpenMap()
    end
end

function Screen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = 'Select', keybind = 'UI_SHORTCUT_PRIMARY',
          visible = function()
              return (self.mode == 'categories' and self.categoryList:GetTargetData() ~= nil)
                  or (self.mode == 'styles' and self.styleList:GetTargetData() ~= nil)
          end,
          callback = function()
              local selected = self.categoryList:GetTargetData()
              if self.mode == 'categories' then
                  if selected and selected.categoryKey == 'motifs' then self:OpenMotifs() end
              elseif self.mode == 'styles' then
                  self:OpenDetails()
              end
          end },
        { name = GetString(SI_QUEST_JOURNAL_SHOW_ON_MAP), keybind = 'UI_SHORTCUT_SECONDARY',
          alignment = KEYBIND_STRIP_ALIGN_CENTER,
          visible = function()
              if self.mode ~= 'styles' then return false end
              local data = self.styleList:GetTargetData()
              return data and data.style and FindFastTravelNodeForStyle(data.style) ~= nil
          end,
          callback = function()
              self:ShowSelectedMotifOnMap()
          end },
        { name = 'Search', keybind = 'UI_SHORTCUT_TERTIARY',
          visible = function()
              if self.mode == 'styles' then return true end
              local selected = self.categoryList:GetTargetData()
              return self.mode == 'categories' and selected and selected.categoryKey == 'motifs'
          end,
          callback = function()
              if self.mode == 'categories' then self:OpenMotifs() end
              self:ActivateMotifSearch()
          end },
        { name = 'Back', keybind = 'UI_SHORTCUT_NEGATIVE',
          callback = function()
              if self.mode == 'details' then self:ReturnToStyles()
              elseif self.mode == 'styles' then self:ShowCategories()
              else SCENE_MANAGER:Hide('tamrielCollectionsGamepad') end
          end },
    }
end

-- Base implementation skips adding keybinds unless IsShowing() is true.
-- During the SHOWING transition that check can be premature for addon scenes.
function Screen:AddListKeybinds()
    if self.keybindStripDescriptor then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    end
end

function Screen:BuildCategories()
    self.categoryList:Clear()
    for i, category in ipairs(CATEGORY_DEFS) do
        local icon = category.key == 'motifs' and self.motifIcon or category.icon
        local entry = ZO_GamepadEntryData:New(category.name, icon)
        entry.categoryId = i
        entry.categoryKey = category.key
        -- Unfinished categories stay visible/navigable but non-actionable.
        self.categoryList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
    end
    self.categoryList:Commit()
end

function Screen:ShowCategory(data)
    if data and data.categoryKey == 'motifs' then
        self.styles = MotifCollections() -- Refresh account knowledge when Collections is opened
        -- Reuse the exact motif icon supplied by ESO's Lore Library.
        -- Avoid using the unrelated crafting-tab symbol.
        if not self.motifIcon and self.styles and self.styles[1] then
            self.motifIcon = self.styles[1].icon
            self:BuildCategories()
        end
        self:PopulateMotifList()
        self.middle:SetHidden(false)
        self.right:SetHidden(false)
        self.detailList:Clear()
        self.detailList:Commit()
        -- Category focus uses a clean splash state in the right panel: keep
        -- both gold dividers, hide all motif-specific text, and center one
        -- large native motif icon between the dividers.
        self.detailControl:SetHidden(true)
        self.detailHeading:SetHidden(true)
        self.detailAcquisition:SetHidden(true)
        self.detailWhereTitle:SetHidden(true)
        self.detailLocation:SetHidden(true)
        self.detailSource:SetHidden(true)
        self.detailAchievement:SetHidden(true)
        if self.motifIcon and self.motifIcon ~= '' then
            self.detailIcon:SetTexture(self.motifIcon)
            self.detailIcon:SetHidden(false)
        else
            self.detailIcon:SetHidden(true)
        end
    else
        self.middle:SetHidden(true)
        self.right:SetHidden(true)
    end
end

function Screen:ActivateMotifSearch()
    if self.mode ~= 'styles' or not self.motifSearchFocus then return end
    if not self.motifSearchFocus:HasFocus() then
        if self.motifSearchFocus:GetText() == '' then
            self.motifSearchRestoreIndex = self.styleList:GetSelectedIndex()
        end
        self.motifSearchFocus:Activate()
        self.motifSearchFocus:SetFocused(true)
        self:RefreshKeybinds()
    end
end

function Screen:OnMotifSearchTextChanged(text)
    if self.mode ~= 'styles' then return end
    local query = NormalizeMatchText(text or '')
    if query == '' then
        if self.motifSearchRestoreIndex and self.motifSearchRestoreIndex > 0 then
            self.styleList:SetSelectedIndex(self.motifSearchRestoreIndex)
        end
        return
    end

    -- A bare number, "motif 92", or "crafting motif 92" searches the
    -- real motif number extracted from ESO's Lore Library book titles.
    local queryNumber = query:match('^%d+$') and tonumber(query)
        or tonumber(query:match('motif%s+(%d+)'))

    local bestIndex, bestScore = nil, 0
    for index, style in ipairs(self.styles or {}) do
        local score = 0
        if queryNumber then
            local motifNumber = GetMotifNumber(style)
            if motifNumber and tonumber(motifNumber) == queryNumber then
                score = 100
            end
        else
            local name = NormalizeMatchText(style.name or '')
            if name == query then
                score = 100
            elseif name:find(query, 1, true) == 1 then
                score = 80
            elseif name:find(query, 1, true) then
                score = 60
            end
        end
        if score > bestScore then
            bestIndex, bestScore = index, score
            if score == 100 then break end
        end
    end

    if bestIndex then
        self.styleList:SetSelectedIndex(bestIndex)
    end
end

function Screen:PopulateMotifList()
    self.styleList:Clear()
    for _, style in ipairs(self.styles) do
        local title = style.name or 'Unknown'
        -- ESO inline texture markup keeps icon + name in one centered label.
        -- Do not pass an icon to the native Quest Journal entry template.
        if style.icon and style.icon ~= '' then
            title = string.format('|t26:26:%s|t  %s', style.icon, title)
        end
        local entry = ZO_GamepadEntryData:New(title)
        entry.style = style
        self.styleList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
    end
    self.styleList:Commit()
    self:RefreshKeybinds()
end

function Screen:OpenMotifs()
    self.mode = 'styles'
    self:SetCurrentList(self.styleList)
    self.middle:SetHidden(false)
    self.right:SetHidden(false)
    self:ShowStyle(self.styleList:GetTargetData())
    self:RefreshKeybinds()
end

function Screen:ShowStyle(data)
    if not (data and data.style) then
        self.middleSteps:SetText('')
        self.rightText:SetText('')
        return
    end
    local style = data.style
    -- Leaving category focus restores the normal motif-detail card.
    self.detailControl:SetHidden(false)
    self.detailHeading:SetHidden(false)
    self.detailAcquisition:SetHidden(false)
    self.detailWhereTitle:SetHidden(false)
    self.detailLocation:SetHidden(false)
    self.detailSource:SetHidden(false)
    self.detailAchievement:SetHidden(false)
    self.detailIcon:SetHidden(true)
    -- The ESO Lore Library provides the actual book/chapter names and
    -- whether each book is known. Do not substitute fabricated 14-chapter rows.
    self.detailList:Clear()
    local headingText = string.format('%s (%d/%d)', style.name or 'Motif', style.known or 0, style.total or 0)
    if style.icon and style.icon ~= '' then
        headingText = string.format('|t28:28:%s|t %s', style.icon, headingText)
    end
    self.detailHeading:SetText(headingText)
    self.detailIcon:SetHidden(true)
    local motifNumber = nil
    if GetLoreBookInfo and style.category and style.collection then
        for bookIndex = 1, (style.total or 0) do
            local title, _, known = GetLoreBookInfo(style.category, style.collection, bookIndex)
            if title and title ~= '' then
                -- ESO's Lore Library titles can include the full item name,
                -- e.g. "Crafting Motif 92: Ancestral Akaviri Axes". Extract
                -- the number for the description and show only the chapter
                -- name in the scrolling list. Never hardcode motif numbers.
                local number, remainder = title:match('^[Cc]rafting [Mm]otif%s+(%d+)%s*:%s*(.+)$')
                local chapterName = title
                if number then
                    motifNumber = motifNumber or number
                    local styleBase = (style.name or ''):gsub('%s+[Ss]tyle%s*$', '')
                    local baseStart, baseEnd = remainder:lower():find(styleBase:lower(), 1, true)
                    if baseStart == 1 then
                        local suffix = remainder:sub(baseEnd + 1):gsub('^%s*[:%-–]?%s*', '')
                        chapterName = suffix ~= '' and suffix or 'Complete Book'
                    else
                        chapterName = remainder
                    end
                end
                local status = known and '|c66CC66Learned|r' or '|cE57373Not learned|r'
                local entry = ZO_GamepadEntryData:New(string.format('%s  —  %s', chapterName, status))
                entry.bookIndex = bookIndex
                entry.isKnown = known
                self.detailList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
            end
        end
    end
    -- Only display a motif number actually extracted from ESO's book title.
    local numberText = motifNumber and ('Crafting Motif ' .. motifNumber) or 'Crafting Motif number: pending'
    self.detailAcquisition:SetText(numberText)

    -- ESO's Style Master achievement often contains the native achievement
    -- icon and the motif's acquisition/source text. Use that live game data
    -- when available instead of duplicating it in a manual table.
    local achievement = FindStyleAchievement(style.name)
    if achievement then
        self.detailLocation:SetText(achievement.location or '')
        self.detailSource:SetText(AcquisitionSourceFromAchievement(achievement.description))
        local achievementText = achievement.name or ''
        if achievement.icon and achievement.icon ~= '' then
            achievementText = string.format('|t26:26:%s|t  %s', achievement.icon, achievementText)
        end
        self.detailAchievement:SetText('Achievement: ' .. achievementText)
    else
        self.detailLocation:SetText('')
        self.detailSource:SetText('Source details pending')
        self.detailAchievement:SetText('')
    end
    self.detailList:Commit()
    self.rightText:SetHidden(true)
end

function Screen:OpenDetails()
    if not self.styleList:GetTargetData() then return end
    self.mode = 'details'
    self:SetCurrentList(self.detailList)
    self:RefreshKeybinds()
end

function Screen:ReturnToStyles()
    self.mode = 'styles'
    self:SetCurrentList(self.styleList)
    self:RefreshKeybinds()
end

function Screen:ShowCategories()
    self.mode = 'categories'
    self:SetCurrentList(self.categoryList)
    self:ShowCategory(self.categoryList:GetTargetData())
    self:RefreshKeybinds()
end

function Screen:PerformUpdate()
    self.dirty = false
end

function Screen:OnShowing()
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    self:ShowCategories()
end

function Screen:OnHiding()
    -- Native base class performs final deactivation on scene HIDDEN.
end

function TC:Open()
    if self.questScreen then
        SCENE_MANAGER:Show('tamrielCollectionsGamepad')
    elseif d then d('[TCM] Not initialized. Stage: '..tostring(self.initStage)..' | '..tostring(self.initError or 'no error captured')) end
end

local function Initialize()
    local ok, err = pcall(function()
        TC.initStage = 'constructing Quest Journal screen'
        TC.questScreen = Screen:New(TCMQuestJournalTL)
        TC.initStage = 'ready'
    end)
    if not ok then
        TC.questScreen = nil
        TC.initError = tostring(err)
        if d then d('[TCM v0.2.28] Init failed at '..tostring(TC.initStage)..': '..TC.initError) end
    end
end
EVENT_MANAGER:RegisterForEvent('TCMQuestInit', EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent('TCMQuestInit', EVENT_PLAYER_ACTIVATED)
    Initialize()
end)

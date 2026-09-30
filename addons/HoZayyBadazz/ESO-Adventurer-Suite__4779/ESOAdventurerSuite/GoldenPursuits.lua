-- ESO Adventurer Suite
-- Golden Pursuits HUD.
-- v0.25.05: one Suite-owned, movable/resizable tracker replaces the duplicate
-- native + companion-panel presentation.

local EPC = ESOProgressionCoach
EPC.GoldenPursuits = EPC.GoldenPursuits or {}
local G = EPC.GoldenPursuits
local wm = WINDOW_MANAGER

local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 136
local MIN_WIDTH = 180
local MIN_HEIGHT = 90
local MAX_WIDTH = 900
local MAX_HEIGHT = 420

local function getNativeTrackerControl()
    if PROMOTIONAL_EVENT_TRACKER and PROMOTIONAL_EVENT_TRACKER.control then
        return PROMOTIONAL_EVENT_TRACKER.control
    end
    return ZO_PromotionalEventTracker_TL
end

local function savedNumber(key, fallback)
    local value = EPC.saved and tonumber(EPC.saved[key])
    if value ~= nil then return value end
    return fallback
end

function G:SuppressNativeTracker2505()
    local native = getNativeTrackerControl()
    if not native then return end
    if native.SetAlpha then native:SetAlpha(0) end
    if native.SetMouseEnabled then native:SetMouseEnabled(false) end
end

function G:IsSuiteMenuOpen2496()
    local journal = EPC.Journal
    local window = journal and journal.window
    if window and type(window.IsHidden) == "function" then
        local ok, hidden = pcall(window.IsHidden, window)
        if ok and hidden == false then return true end
    end
    return false
end

function G:Create2505()
    if self.frame2505 then return self.frame2505 end
    if not wm then return nil end

    -- v0.25.09: migrate the older tall HUD once so existing SavedVariables
    -- do not keep the previous 140px height after the compact redesign.
    if EPC.saved and EPC.saved.goldenPursuitsCompactHeightVersion ~= 2871 then
        local oldHeight = tonumber(EPC.saved.goldenPursuitsHeight) or 0
        if oldHeight < MIN_HEIGHT then
            EPC.saved.goldenPursuitsHeight = DEFAULT_HEIGHT
        end
        EPC.saved.goldenPursuitsCompactHeightVersion = 2871
    end

    local frame = wm:CreateTopLevelWindow("EAS_GoldenPursuitsHUD2505")
    local width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, savedNumber("goldenPursuitsWidth", DEFAULT_WIDTH)))
    local height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, savedNumber("goldenPursuitsHeight", DEFAULT_HEIGHT)))
    frame:SetDimensions(width, height)
    frame:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT)
    frame:SetResizeHandleSize(18)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetHidden(true)
    if frame.SetDrawLayer then frame:SetDrawLayer(DL_OVERLAY) end
    if DT_HIGH ~= nil and frame.SetDrawTier then frame:SetDrawTier(DT_HIGH) end

    local left = savedNumber("goldenPursuitsLeft", -1)
    local top = savedNumber("goldenPursuitsTop", -1)
    local side = EPC.saved and EPC.saved.goldenPursuitsAnchorSide339 or nil
    local rightMargin = tonumber(EPC.saved and EPC.saved.goldenPursuitsRightMargin339)
    if side == "RIGHT" and rightMargin and rightMargin >= 0 and top >= 0 then
        frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -rightMargin, top)
    elseif left >= 0 and top >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 34, 360)
    end

    -- Inset the backdrop so all four border strokes remain visible at every size.
    local bg = wm:CreateControl("EAS_GoldenPursuitsHUDBG2505", frame, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    bg:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    bg:SetCenterColor(0.025, 0.022, 0.018, 0.90)
    bg:SetEdgeTexture(nil, 1, 1, 2)
    bg:SetEdgeColor(0.92, 0.72, 0.25, 0.95)
    bg:SetMouseEnabled(false)

    local header = wm:CreateControl("EAS_GoldenPursuitsHUDHeader2505", frame, CT_LABEL)
    header:SetFont("ZoFontGameSmall")
    header:SetColor(0.96, 0.80, 0.36, 1)
    header:SetAnchor(TOPLEFT, frame, TOPLEFT, 12, 8)
    header:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 8)
    header:SetHeight(18)
    header:SetText("GOLDEN PURSUITS")

    local title = wm:CreateControl("EAS_GoldenPursuitsHUDTitle2505", frame, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.96, 0.80, 0.36, 1)
    title:SetAnchor(TOPLEFT, frame, TOPLEFT, 12, 28)
    title:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 28)
    title:SetHeight(38)
    title:SetVerticalAlignment(TEXT_ALIGN_TOP)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local pursuit = wm:CreateControl("EAS_GoldenPursuitsHUDPursuit2505", frame, CT_LABEL)
    pursuit:SetFont("ZoFontGame")
    pursuit:SetColor(0.92, 0.94, 0.97, 1)
    pursuit:SetAnchor(TOPLEFT, frame, TOPLEFT, 12, 68)
    pursuit:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 68)
    pursuit:SetHeight(24)
    pursuit:SetVerticalAlignment(TEXT_ALIGN_TOP)
    pursuit:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local status = wm:CreateControl("EAS_GoldenPursuitsHUDStatus2505", frame, CT_LABEL)
    status:SetFont("ZoFontGameSmall")
    status:SetColor(0.78, 0.80, 0.84, 1)
    status:SetAnchor(TOPLEFT, frame, TOPLEFT, 12, 94)
    status:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -12, -8)
    status:SetVerticalAlignment(TEXT_ALIGN_TOP)
    status:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if status.SetLineSpacing then status:SetLineSpacing(2) end

    local moveHint = wm:CreateControl("EAS_GoldenPursuitsHUDMoveHint2505", frame, CT_LABEL)
    moveHint:SetFont("ZoFontGameSmall")
    moveHint:SetColor(0.96, 0.80, 0.36, 1)
    moveHint:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 8)
    moveHint:SetDimensions(230, 18)
    moveHint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    moveHint:SetText("DRAG TO MOVE - EDGES TO RESIZE")
    moveHint:SetHidden(true)

    local layoutGuide = wm:CreateControl("EAS_GoldenPursuitsHUDLayoutGuide2505", frame, CT_BACKDROP)
    layoutGuide:SetAnchor(TOPLEFT, frame, TOPLEFT, 4, 4)
    layoutGuide:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -4, -4)
    layoutGuide:SetCenterColor(0, 0, 0, 0)
    layoutGuide:SetEdgeTexture(nil, 1, 1, 1)
    layoutGuide:SetEdgeColor(1, 0.84, 0.42, 0.65)
    layoutGuide:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if not EPC.saved then return end
        local left = math.max(0, tonumber(control:GetLeft()) or 0)
        local top = math.max(0, tonumber(control:GetTop()) or 0)
        local right = tonumber(control:GetRight()) or (left + (tonumber(control:GetWidth()) or DEFAULT_WIDTH))
        local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
        EPC.saved.goldenPursuitsLeft = left
        EPC.saved.goldenPursuitsTop = top
        if ((left + right) * 0.5) >= guiWidth * 0.5 then
            EPC.saved.goldenPursuitsAnchorSide339 = "RIGHT"
            EPC.saved.goldenPursuitsRightMargin339 = math.max(0, guiWidth - right)
        else
            EPC.saved.goldenPursuitsAnchorSide339 = "LEFT"
            EPC.saved.goldenPursuitsRightMargin339 = nil
        end
        local w, h = control:GetDimensions()
        EPC.saved.goldenPursuitsPositionWidth338 = tonumber(w) or DEFAULT_WIDTH
        EPC.saved.goldenPursuitsPositionHeight338 = tonumber(h) or DEFAULT_HEIGHT
    end)
    frame:SetHandler("OnResizeStop", function(control)
        if not EPC.saved then return end
        local w, h = control:GetDimensions()
        EPC.saved.goldenPursuitsWidth = math.floor((tonumber(w) or DEFAULT_WIDTH) + 0.5)
        EPC.saved.goldenPursuitsHeight = math.floor((tonumber(h) or DEFAULT_HEIGHT) + 0.5)
        EPC.saved.goldenPursuitsPositionWidth338 = tonumber(w) or DEFAULT_WIDTH
        EPC.saved.goldenPursuitsPositionHeight338 = tonumber(h) or DEFAULT_HEIGHT
        local left = tonumber(control:GetLeft()) or 0
        local right = tonumber(control:GetRight()) or (left + (tonumber(w) or DEFAULT_WIDTH))
        local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
        if ((left + right) * 0.5) >= guiWidth * 0.5 then
            EPC.saved.goldenPursuitsAnchorSide339 = "RIGHT"
            EPC.saved.goldenPursuitsRightMargin339 = math.max(0, guiWidth - right)
        else
            EPC.saved.goldenPursuitsAnchorSide339 = "LEFT"
            EPC.saved.goldenPursuitsRightMargin339 = nil
        end
        EPC.saved.goldenPursuitsManualSize2875 = true
        if self.ApplyCompactLayout2875 then self:ApplyCompactLayout2875() end
    end)

    self.frame2505 = frame
    self.selectedQuestPanel2504 = frame -- compatibility with the v0.25.04 name
    self.bg2505 = bg
    self.header2505 = header
    self.title2505 = title
    self.pursuit2505 = pursuit
    self.status2505 = status
    self.moveHint2505 = moveHint
    self.layoutGuide2505 = layoutGuide
    return frame
end

function G:SetSelectedPursuitQuest2504(pursuitName, questName, campaignKey, activityIndex)
    self.selectedPursuitName2504 = tostring(pursuitName or "")
    self.selectedQuestName2504 = tostring(questName or "")
    self.selectedCampaignKey2871 = campaignKey
    self.selectedActivityIndex2871 = tonumber(activityIndex)
    if EPC.saved then
        EPC.saved.goldenPursuitName = self.selectedPursuitName2504
        EPC.saved.goldenPursuitQuestName = self.selectedQuestName2504
        local keyType = type(campaignKey)
        EPC.saved.goldenPursuitCampaignKey2871 = (keyType == "number" or keyType == "string") and campaignKey or nil
        EPC.saved.goldenPursuitActivityIndex2871 = tonumber(activityIndex)
    end
    self:RefreshSelectedQuestPanel2504()
end

function G:ClearSelectedPursuitQuest2504()
    self.selectedPursuitName2504 = ""
    self.selectedQuestName2504 = ""
    self.selectedCampaignKey2871 = nil
    self.selectedActivityIndex2871 = nil
    if EPC.saved then
        EPC.saved.goldenPursuitName = ""
        EPC.saved.goldenPursuitQuestName = ""
        EPC.saved.goldenPursuitCampaignKey2871 = nil
        EPC.saved.goldenPursuitActivityIndex2871 = nil
    end
    self:RefreshSelectedQuestPanel2504()
end

local function easLower2871(value)
    local text = tostring(value or "")
    if type(zo_strlower) == "function" then return zo_strlower(text) end
    return string.lower(text)
end

local function easSameKey2871(a, b)
    if a == nil or b == nil then return false end
    if tostring(a) == tostring(b) then return true end
    local an, bn = tonumber(a), tonumber(b)
    return an ~= nil and bn ~= nil and an == bn
end

function G:FindSelectedPursuitRow2871()
    local pursuitName = tostring(self.selectedPursuitName2504 or "")
    if pursuitName == "" then return nil end
    local journal = EPC.Journal
    if not journal or type(journal.BuildGoldenPursuitsView2494) ~= "function" then return nil end

    local ok, view = pcall(journal.BuildGoldenPursuitsView2494, journal)
    if not ok or type(view) ~= "table" then return nil end
    local rows = view.allRows or view.rows or {}
    local wantedKey = self.selectedCampaignKey2871
    if wantedKey == nil and EPC.saved then wantedKey = EPC.saved.goldenPursuitCampaignKey2871 end
    local wantedActivity = tonumber(self.selectedActivityIndex2871)
    if not wantedActivity and EPC.saved then wantedActivity = tonumber(EPC.saved.goldenPursuitActivityIndex2871) end

    local nameMatch = nil
    local wantedName = easLower2871(pursuitName)
    for _, row in ipairs(rows) do
        local activityIndex = tonumber(row.activityIndex)
        if wantedActivity and activityIndex == wantedActivity then
            if wantedKey == nil or easSameKey2871(row.campaignKey, wantedKey) then
                return row
            end
        end
        if not nameMatch and easLower2871(row.name) == wantedName then
            nameMatch = row
        end
    end
    return nameMatch
end

function G:GetSelectedProgress2871()
    local row = self:FindSelectedPursuitRow2871()
    if not row then return nil end
    local progress = math.max(0, tonumber(row.progress) or 0)
    local goal = math.max(0, tonumber(row.goal) or 0)
    local complete = row.complete == true
    local percent = nil
    if goal > 0 then
        percent = math.max(0, math.min(100, math.floor((progress / goal) * 100 + 0.5)))
    end
    return {
        row = row,
        name = tostring(row.name or self.selectedPursuitName2504 or "Golden Pursuit"),
        progress = progress,
        goal = goal,
        percent = percent,
        complete = complete,
        campaignCompleted = math.max(0, tonumber(row.campaignCompleted) or 0),
        campaignThreshold = math.max(0, tonumber(row.campaignThreshold) or 0),
    }
end

-- v0.29.337: if the selected Golden Pursuit is linked to a journal quest,
-- mirror every visible incomplete quest objective under the pursuit progress.
-- This uses the same objective builder as the Active Quest overlay so both HUDs
-- stay consistent and no objective is arbitrarily dropped.
function G:FindLinkedQuestIndex337()
    local wanted = easLower2871(self.selectedQuestName2504 or "")
    if wanted == "" then return nil end
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or IsValidQuestIndex(index) == true
        if valid then
            local name = ""
            if type(GetJournalQuestName) == "function" then
                local ok, value = pcall(GetJournalQuestName, index)
                if ok then name = tostring(value or "") end
            elseif type(GetJournalQuestInfo) == "function" then
                local ok, value = pcall(GetJournalQuestInfo, index)
                if ok then name = tostring(value or "") end
            end
            if name ~= "" and easLower2871(name) == wanted then return index end
        end
    end
    return nil
end

function G:GetLinkedQuestObjectives337()
    local index = self:FindLinkedQuestIndex337()
    local active = EPC.ActiveQuest
    if not index or not active or type(active.BuildObjectiveText) ~= "function" then return "" end
    local ok, text = pcall(active.BuildObjectiveText, active, index)
    if not ok then return "" end
    text = tostring(text or "")
    if text == "Follow the quest marker." or text == "Quest ready to complete." then return text end
    return text
end

local function easCountLinesGP337(text)
    text = tostring(text or "")
    if text == "" then return 0 end
    local count = 1
    for _ in string.gmatch(text, "\n") do count = count + 1 end
    return count
end

function G:RefreshSelectedQuestPanel2504()
    local frame = self:Create2505()
    if not frame then return end

    local pursuitName = tostring(self.selectedPursuitName2504 or "")
    local questName = tostring(self.selectedQuestName2504 or "")
    local hasSelection = pursuitName ~= "" or questName ~= ""
    local progressInfo = hasSelection and self:GetSelectedProgress2871() or nil

    if self.layoutMode and not hasSelection then
        self.title2505:SetText("Linked quest preview")
        self.pursuit2505:SetText("Golden Pursuit task preview")
        self.status2505:SetText("• PROGRESS: 3 / 10 (30%)\n• CAMPAIGN: 6 / 20")
        self.status2505:SetColor(1, 1, 1, 1)
    else
        local displayTitle = questName ~= "" and questName or pursuitName
        self.title2505:SetText(displayTitle)

        local taskName = progressInfo and progressInfo.name or pursuitName
        if taskName ~= "" and easLower2871(taskName) ~= easLower2871(displayTitle) then
            self.pursuit2505:SetText(taskName)
        else
            self.pursuit2505:SetText("")
        end

        if progressInfo then
            local progressText
            if progressInfo.complete then
                if progressInfo.goal > 0 then
                    progressText = string.format("• PROGRESS: %d / %d (COMPLETE)", progressInfo.progress, progressInfo.goal)
                else
                    progressText = "• PROGRESS: COMPLETE"
                end
                self.status2505:SetColor(1, 1, 1, 1)
            elseif progressInfo.goal > 0 then
                progressText = string.format("• PROGRESS: %d / %d (%d%%)", progressInfo.progress, progressInfo.goal, progressInfo.percent or 0)
                self.status2505:SetColor(1, 1, 1, 1)
            else
                progressText = string.format("• PROGRESS: %d", progressInfo.progress)
                self.status2505:SetColor(1, 1, 1, 1)
            end
            if progressInfo.campaignThreshold > 0 then
                progressText = progressText .. string.format("\n• CAMPAIGN: %d / %d", progressInfo.campaignCompleted, progressInfo.campaignThreshold)
            end
            self.status2505:SetText(progressText)
        elseif hasSelection then
            self.status2505:SetText("• PROGRESS: Syncing with Golden Pursuits...")
            self.status2505:SetColor(0.78, 0.80, 0.84, 1)
        else
            self.status2505:SetText("")
        end
    end

    if not self.layoutMode and hasSelection then
        local questObjectives337 = self:GetLinkedQuestObjectives337()
        if questObjectives337 ~= "" then
            local existing337 = tostring(self.status2505:GetText() or "")
            if existing337 ~= "" then
                self.status2505:SetText(existing337 .. "\n" .. questObjectives337)
            else
                self.status2505:SetText(questObjectives337)
            end
            self.status2505:SetColor(1, 1, 1, 1)
        end
    end

    local hasPursuitLine = self.pursuit2505:GetText() ~= ""
    self.pursuit2505:SetHidden(not hasPursuitLine)

    -- v0.29.337: gameplay height follows the actual linked quest/objective
    -- content, then shrinks again when a shorter pursuit/quest is selected.
    self:AutoFitHeight337()
    self:RefreshVisibility2496()
end

-- v0.28.75: keep Golden Pursuits usable at compact manual sizes. Rows are
-- stacked from the top and the status label becomes a clipped viewport instead
-- of imposing the old 300x126 minimum footprint.
function G:ApplyCompactLayout2875()
    local frame = self.frame2505 or self:Create2505()
    if not frame or not self.header2505 or not self.title2505 or not self.pursuit2505 or not self.status2505 then return end

    local frameWidth = tonumber(frame:GetWidth()) or DEFAULT_WIDTH
    local frameHeight = math.max(MIN_HEIGHT, tonumber(frame:GetHeight()) or DEFAULT_HEIGHT)
    local pad = frameWidth < 240 and 8 or 12
    local headerTop, headerHeight = 6, 18

    self.header2505:ClearAnchors()
    self.header2505:SetAnchor(TOPLEFT, frame, TOPLEFT, pad, headerTop)
    self.header2505:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -pad, headerTop)
    self.header2505:SetHeight(headerHeight)

    local titleTop = headerTop + headerHeight + 2
    local titleDesired = 38
    if type(self.title2505.GetTextHeight) == "function" then
        local ok, value = pcall(self.title2505.GetTextHeight, self.title2505)
        if ok and tonumber(value) then titleDesired = math.max(18, math.ceil(tonumber(value)) + 2) end
    end
    local titleHeight = math.max(18, math.min(64, titleDesired))
    self.title2505:ClearAnchors()
    self.title2505:SetAnchor(TOPLEFT, frame, TOPLEFT, pad, titleTop)
    self.title2505:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -pad, titleTop)
    self.title2505:SetHeight(titleHeight)

    local cursorY = titleTop + titleHeight + 2
    local hasPursuitLine = not self.pursuit2505:IsHidden() and tostring(self.pursuit2505:GetText() or "") ~= ""
    if hasPursuitLine then
        local pursuitHeight = 20
        if type(self.pursuit2505.GetTextHeight) == "function" then
            local ok, value = pcall(self.pursuit2505.GetTextHeight, self.pursuit2505)
            if ok and tonumber(value) then pursuitHeight = math.max(20, math.min(46, math.ceil(tonumber(value)) + 2)) end
        end
        self.pursuit2505:ClearAnchors()
        self.pursuit2505:SetAnchor(TOPLEFT, frame, TOPLEFT, pad, cursorY)
        self.pursuit2505:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -pad, cursorY)
        self.pursuit2505:SetHeight(pursuitHeight)
        cursorY = cursorY + pursuitHeight + 2
    end

    self.status2505:ClearAnchors()
    self.status2505:SetAnchor(TOPLEFT, frame, TOPLEFT, pad, cursorY)
    self.status2505:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -pad, cursorY)
    local statusHeight = math.max(0, frameHeight - cursorY - 6)
    self.status2505:SetHeight(statusHeight)
    self.status2505:SetHidden(tostring(self.status2505:GetText() or "") == "" or statusHeight < 6)
end

function G:AutoFitHeight337()
    local frame = self.frame2505 or self:Create2505()
    if not frame or not self.title2505 or not self.pursuit2505 or not self.status2505 then return end
    if self.layoutMode then
        self:ApplyCompactLayout2875()
        return
    end

    local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
    local guiHeight = GuiRoot and type(GuiRoot.GetHeight) == "function" and tonumber(GuiRoot:GetHeight()) or 1080
    local baseWidth = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(EPC.saved and EPC.saved.goldenPursuitsWidth) or DEFAULT_WIDTH))
    local rows = easCountLinesGP337(self.status2505:GetText())
    local extraWidth = rows > 4 and math.min(140, (rows - 4) * 28) or 0
    local widthCap = math.max(baseWidth, math.min(MAX_WIDTH, math.floor(guiWidth * 0.48)))
    local targetWidth = math.min(widthCap, baseWidth + extraWidth)
    frame:SetWidth(targetWidth)

    if self.status2505.SetLineSpacing then
        if rows >= 8 then
            self.status2505:SetLineSpacing(0)
        elseif rows >= 5 then
            self.status2505:SetLineSpacing(1)
        else
            self.status2505:SetLineSpacing(2)
        end
    end

    -- Give the labels enough room to report their true wrapped text height,
    -- then size the card from those measurements.
    self:ApplyCompactLayout2875()
    local titleHeight = 38
    if type(self.title2505.GetTextHeight) == "function" then
        local ok, value = pcall(self.title2505.GetTextHeight, self.title2505)
        if ok and tonumber(value) then titleHeight = math.max(18, math.min(64, math.ceil(tonumber(value)) + 2)) end
    end
    local pursuitHeight = 0
    if not self.pursuit2505:IsHidden() and tostring(self.pursuit2505:GetText() or "") ~= "" then
        pursuitHeight = 20
        if type(self.pursuit2505.GetTextHeight) == "function" then
            local ok, value = pcall(self.pursuit2505.GetTextHeight, self.pursuit2505)
            if ok and tonumber(value) then pursuitHeight = math.max(20, math.min(46, math.ceil(tonumber(value)) + 2)) end
        end
    end
    local statusHeight = 0
    if tostring(self.status2505:GetText() or "") ~= "" then
        statusHeight = math.max(20, rows * 18)
        if type(self.status2505.GetTextHeight) == "function" then
            local ok, value = pcall(self.status2505.GetTextHeight, self.status2505)
            if ok and tonumber(value) then statusHeight = math.max(20, math.ceil(tonumber(value)) + 2) end
        end
    end

    local desired = 6 + 18 + 2 + titleHeight + 2 + (pursuitHeight > 0 and pursuitHeight + 2 or 0) + statusHeight + 8
    local userMax = tonumber(EPC.saved and EPC.saved.goldenPursuitsAutoMaxHeight337) or MAX_HEIGHT
    userMax = math.max(180, math.min(MAX_HEIGHT, userMax))
    local screenMax = math.max(180, math.floor(guiHeight * 0.42))
    local finalHeight = math.max(MIN_HEIGHT, math.min(userMax, screenMax, desired))
    frame:SetHeight(finalHeight)
    if EPC.saved then EPC.saved.goldenPursuitsHeight = math.floor(finalHeight + 0.5) end
    self:ApplyCompactLayout2875()

    -- v0.29.339: preserve the edge the player chose in HUD Layout. A card
    -- dropped on the right side uses a real TOPRIGHT anchor, so adaptive width
    -- grows leftward while the right edge stays exactly where the player put it.
    local savedLeft = tonumber(EPC.saved and EPC.saved.goldenPursuitsLeft)
    local savedTop = tonumber(EPC.saved and EPC.saved.goldenPursuitsTop)
    if savedLeft == nil or savedLeft < 0 then savedLeft = tonumber(frame:GetLeft()) or 34 end
    if savedTop == nil or savedTop < 0 then savedTop = tonumber(frame:GetTop()) or 360 end

    local positionedWidth = tonumber(EPC.saved and EPC.saved.goldenPursuitsPositionWidth338) or baseWidth
    local side = EPC.saved and EPC.saved.goldenPursuitsAnchorSide339 or nil
    if side ~= "LEFT" and side ~= "RIGHT" then
        side = (savedLeft + positionedWidth * 0.5 >= guiWidth * 0.5) and "RIGHT" or "LEFT"
    end

    local renderTop = math.max(8, math.min(math.max(8, guiHeight - finalHeight - 8), savedTop))
    frame:ClearAnchors()
    if side == "RIGHT" then
        local rightMargin = tonumber(EPC.saved and EPC.saved.goldenPursuitsRightMargin339)
        if rightMargin == nil then
            rightMargin = math.max(8, guiWidth - (savedLeft + positionedWidth))
        end
        rightMargin = math.max(8, math.min(math.max(8, guiWidth - targetWidth - 8), rightMargin))
        frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -rightMargin, renderTop)
    else
        local renderLeft = math.max(8, math.min(math.max(8, guiWidth - targetWidth - 8), savedLeft))
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, renderLeft, renderTop)
    end
end

function G:RefreshVisibility2496()
    self:SuppressNativeTracker2505()
    local frame = self:Create2505()
    if not frame then return end

    local pursuitName = tostring(self.selectedPursuitName2504 or "")
    local questName = tostring(self.selectedQuestName2504 or "")
    local hasSelection = pursuitName ~= "" or questName ~= ""
    local enabled = not EPC.saved or EPC.saved.showGoldenPursuitsOverlay ~= false
    local show = (enabled and hasSelection) or self.layoutMode

    if show and not self.layoutMode and EPC.OverlayModeAllows then
        show = EPC:OverlayModeAllows("goldenPursuitsVisibility")
    end

    if show and not self.layoutMode then
        if self:IsSuiteMenuOpen2496() then
            show = false
        elseif EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
            show = false
        end
    end

    frame:SetHidden(not show)
    if frame.SetAlpha then frame:SetAlpha(show and 1 or 0) end
end

function G:SetLayoutMode(active)
    self.layoutMode = active == true
    local frame = self:Create2505()
    if not frame then return end
    frame:SetMouseEnabled(self.layoutMode)
    frame:SetMovable(self.layoutMode)
    if self.moveHint2505 then self.moveHint2505:SetHidden(not self.layoutMode) end
    if self.layoutGuide2505 then self.layoutGuide2505:SetHidden(not self.layoutMode) end
    self:RefreshSelectedQuestPanel2504()
end

function G:SetSize(width, height)
    local frame = self:Create2505()
    if not frame or not EPC.saved then return end
    width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(width) or frame:GetWidth()))
    height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, tonumber(height) or frame:GetHeight()))
    frame:SetDimensions(width, height)
    EPC.saved.goldenPursuitsWidth = math.floor(width + 0.5)
    EPC.saved.goldenPursuitsHeight = math.floor(height + 0.5)
    EPC.saved.goldenPursuitsManualSize2875 = false
    self:RefreshSelectedQuestPanel2504()
end

function G:ResetSize()
    local frame = self:Create2505()
    if not frame or not EPC.saved then return end
    EPC.saved.goldenPursuitsWidth = DEFAULT_WIDTH
    EPC.saved.goldenPursuitsHeight = DEFAULT_HEIGHT
    EPC.saved.goldenPursuitsManualSize2875 = false
    frame:SetDimensions(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    self:ApplyCompactLayout2875()
end

function G:ResetPosition()
    local frame = self:Create2505()
    if not frame or not EPC.saved then return end
    EPC.saved.goldenPursuitsLeft = -1
    EPC.saved.goldenPursuitsTop = -1
    EPC.saved.goldenPursuitsPositionWidth338 = nil
    EPC.saved.goldenPursuitsPositionHeight338 = nil
    EPC.saved.goldenPursuitsAnchorSide339 = nil
    EPC.saved.goldenPursuitsRightMargin339 = nil
    frame:ClearAnchors()
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 34, 360)
end

function G:Initialize()
    if EPC.saved and EPC.saved.goldenPursuitsAutoFitVersion337 ~= 337 then
        EPC.saved.goldenPursuitsManualSize2875 = false
        EPC.saved.goldenPursuitsAutoMaxHeight337 = tonumber(EPC.saved.goldenPursuitsAutoMaxHeight337) or MAX_HEIGHT
        EPC.saved.goldenPursuitsAutoFitVersion337 = 337
    end
    self.layoutMode = false
    self.selectedPursuitName2504 = tostring(EPC.saved and EPC.saved.goldenPursuitName or "")
    self.selectedQuestName2504 = tostring(EPC.saved and EPC.saved.goldenPursuitQuestName or "")
    self.selectedCampaignKey2871 = EPC.saved and EPC.saved.goldenPursuitCampaignKey2871 or nil
    self.selectedActivityIndex2871 = EPC.saved and tonumber(EPC.saved.goldenPursuitActivityIndex2871) or nil
    self:SuppressNativeTracker2505()
    self:Create2505()
    self:RefreshSelectedQuestPanel2504()

    local prefix = EPC.name .. "_GoldenPursuits2505"
    if EPC.HudVisibility then
        EPC.HudVisibility:Register("GoldenPursuits", function() self:RefreshVisibility2496() end)
    end
    if EVENT_GAME_CAMERA_UI_MODE_CHANGED then
        EPC.Runtime:RegisterEvent("GoldenPursuits","UIMode",EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
            self:RefreshVisibility2496()
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("GoldenPursuits","Activated",EVENT_PLAYER_ACTIVATED, function()
            self:SuppressNativeTracker2505()
            self:RefreshVisibility2496()
        end)
    end
    if EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED then
        EPC.Runtime:RegisterEvent("GoldenPursuits","Tracking",EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED, function()
            self:RefreshSelectedQuestPanel2504()
        end)
    end
    if PROMOTIONAL_EVENT_MANAGER and type(PROMOTIONAL_EVENT_MANAGER.RegisterCallback) == "function" then
        pcall(PROMOTIONAL_EVENT_MANAGER.RegisterCallback, PROMOTIONAL_EVENT_MANAGER, "ActivityProgressUpdated", function()
            self:RefreshSelectedQuestPanel2504()
        end)
        pcall(PROMOTIONAL_EVENT_MANAGER.RegisterCallback, PROMOTIONAL_EVENT_MANAGER, "RewardsClaimed", function()
            self:RefreshSelectedQuestPanel2504()
        end)
    end
    -- v0.29.341: one safety pulse replaces the two 750 ms legacy pollers.
    -- Promotional-event callbacks still refresh progress immediately.
    EVENT_MANAGER:UnregisterForUpdate(prefix .. "_Visibility")
    EVENT_MANAGER:UnregisterForUpdate(prefix .. "_Progress2871")
    EPC.Runtime:RegisterUpdate("GoldenPursuits","Safety",1200, function()
        self:SuppressNativeTracker2505()
        self:RefreshVisibility2496()
        if self.selectedPursuitName2504 ~= "" and self.frame and not self.frame:IsHidden() then
            self:RefreshSelectedQuestPanel2504()
        end
    end)
end

-- Golden Pursuits visibility is owned by the primary RefreshVisibility2496 implementation.\n\n-- v0.28.74: Golden Pursuits progress/campaign text uses white and the status
-- row collapses upward whenever there is no separate pursuit-task line.

-- v0.28.74: Golden Pursuits progress and campaign values render as separate
-- white bullet rows to match the Active Quest objective presentation.

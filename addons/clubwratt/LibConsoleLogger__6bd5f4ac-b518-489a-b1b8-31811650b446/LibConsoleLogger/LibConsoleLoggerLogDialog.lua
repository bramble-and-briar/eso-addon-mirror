-- LibConsoleLoggerLogDialog.lua: Gamepad log viewer dialog

LibConsoleLogger = LibConsoleLogger or {}

---@class LibConsoleLoggerLogDialog : ZO_Object
local LibConsoleLoggerLogDialog = ZO_Object:Subclass()
local GenericGamepadDialog_OnInitialized = rawget(_G, "ZO_GenericGamepadDialog_OnInitialized")
---@type fun(name: string, data: any|nil, textParams: any|nil)
local ShowGamepadDialog = ZO_Dialogs_ShowGamepadDialog
---@type fun(nameOrDialog: any, releasedFromButton: any|nil, filterFunction: function|nil)
local ReleaseDialog = ZO_Dialogs_ReleaseDialog

---@param lines string[]|nil
---@param statusLine string|nil
---@param scope string the selected scope, "" for all
---@param includeErrors boolean the game's errors show alongside the scope
local function BuildLogText(lines, statusLine, scope, includeErrors)
    local text
    if not lines or #lines == 0 then
        text = "[No buffered logs]"
    else
        text = table.concat(lines, "\n")
    end
    if scope ~= "" then
        local with = (includeErrors and scope ~= LibConsoleLogger.errorsScope) and " + errors" or ""
        text = string.format("Scope: %s%s (change it in the settings)\n\n%s", scope, with, text)
    end
    if statusLine and statusLine ~= "" then
        text = text .. "\n\n" .. statusLine
    end
    return text
end

function LibConsoleLoggerLogDialog:New(...)
    ---@type LibConsoleLoggerLogDialog
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function LibConsoleLoggerLogDialog:Initialize(control)
    self.control = control
    self.headerContainer = control:GetNamedChild("HeaderContainer")
    self.scrollContainer = control:GetNamedChild("Container")
    self.scrollChild = self.scrollContainer:GetNamedChild("ScrollChild")
    self.mainTextLabel = self.scrollChild:GetNamedChild("MainText")
    local backKeybindLabel = control:GetNamedChild("BackKeybind")
    if backKeybindLabel then
        local keybindLabelText = zo_strformat(SI_GAMEPAD_BACK_OPTION)
        backKeybindLabel:SetText(keybindLabelText)
    end

    self:InitializeDialog(control)
    self:BuildDialogInfo()
    ZO_Dialogs_RegisterCustomDialog("LIB_CONSOLE_LOGGER_LOG_DIALOG", self.dialogInfo)
end

function LibConsoleLoggerLogDialog:InitializeDialog(dialog)
    dialog.fragment = ZO_FadeSceneFragment:New(dialog)
    if GenericGamepadDialog_OnInitialized then
        GenericGamepadDialog_OnInitialized(dialog)
    end
    if self.scrollContainer and self.scrollContainer.SetScrollIndicatorEnabled then
        self.scrollContainer:SetScrollIndicatorEnabled(true)
    end
end

function LibConsoleLoggerLogDialog:BuildDialogInfo()
    self.dialogInfo = {
        setup = function(...) self:DialogSetupFunction(...) end,
        customControl = self.control,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.CUSTOM,
        },
        title = {
            text = "Console Logger",
        },
        mainText = {
            text = "",
        },
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = function()
                    self:Hide()
                end,
            },
        },
    }
end

function LibConsoleLoggerLogDialog:IsVisible()
    return self.control and not self.control:IsHidden()
end

function LibConsoleLoggerLogDialog:IsScrolledToBottom()
    local scroll = self.scrollContainer and self.scrollContainer.scroll
    if not scroll then
        return true
    end

    local _, verticalOffset = scroll:GetScrollOffsets()
    local _, verticalExtents = scroll:GetScrollExtents()
    if verticalExtents <= 0 then
        return true
    end

    return verticalOffset >= (verticalExtents - 1)
end

function LibConsoleLoggerLogDialog:ScrollToBottom()
    local scrollContainer = self.scrollContainer
    local scroll = scrollContainer and scrollContainer.scroll
    if not scroll then
        return
    end

    local _, verticalExtents = scroll:GetScrollExtents()
    if verticalExtents <= 0 then
        return
    end

    if ZO_ScrollAnimation_MoveWindow then
        scrollContainer.scrollValue = 100
        ZO_ScrollAnimation_MoveWindow(scrollContainer, scrollContainer.scrollValue)
    else
        scroll:SetVerticalScroll(verticalExtents)
    end

    if ZO_UpdateScrollFade and ZO_GetScrollMaxFadeGradientSize and ZO_SCROLL_DIRECTION_VERTICAL then
        ZO_UpdateScrollFade(scrollContainer.useFadeGradient, scroll, ZO_SCROLL_DIRECTION_VERTICAL,
            ZO_GetScrollMaxFadeGradientSize(scrollContainer))
    end
end

---What the dialog shows, as selected in the settings: the scope ("" for all) and whether the game's errors
---come with it.
---@return string scope
---@return boolean includeErrors
function LibConsoleLoggerLogDialog:GetView()
    return LibConsoleLogger:GetScope(), LibConsoleLogger:IsIncludingErrors()
end

function LibConsoleLoggerLogDialog:GetLogLines()
    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if webExport and webExport.BufferGetLines then
        return webExport.BufferGetLines(self:GetView())
    end
    return nil
end

function LibConsoleLoggerLogDialog:GetStatusLine()
    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if webExport and webExport.GetLastStatus then
        return webExport.GetLastStatus()
    end
    return nil
end

function LibConsoleLoggerLogDialog:CacheLogSignature(lines, statusLine)
    local count = lines and #lines or 0
    local lastLine = count > 0 and lines[count] or nil
    self.lastLineCount = count
    self.lastLineText = lastLine
    self.lastStatusLine = statusLine
    self.lastScope, self.lastIncludeErrors = self:GetView()
end

function LibConsoleLoggerLogDialog:HasLogChanged(lines, statusLine)
    local count = lines and #lines or 0
    local lastLine = count > 0 and lines[count] or nil
    local scope, includeErrors = self:GetView()
    if self.lastScope ~= scope or self.lastIncludeErrors ~= includeErrors then
        return true
    end
    if self.lastLineCount ~= count then
        return true
    end
    if self.lastLineText ~= lastLine then
        return true
    end
    if self.lastStatusLine ~= statusLine then
        return true
    end
    return false
end

function LibConsoleLoggerLogDialog:RefreshLogs(scrollToBottom)
    if not self.mainTextLabel then
        return
    end

    local lines = self:GetLogLines()
    local statusLine = self:GetStatusLine()
    self.mainTextLabel:SetText(BuildLogText(lines, statusLine, self:GetView()))
    if scrollToBottom then
        self:ScrollToBottom()
    end
    self:CacheLogSignature(lines, statusLine)
end

function LibConsoleLoggerLogDialog:RefreshIfVisible()
    if not self:IsVisible() then
        return
    end

    local lines = self:GetLogLines()
    local statusLine = self:GetStatusLine()
    if not self:HasLogChanged(lines, statusLine) then
        return
    end

    local shouldScrollToBottom = self:IsScrolledToBottom()
    if self.mainTextLabel then
        self.mainTextLabel:SetText(BuildLogText(lines, statusLine, self:GetView()))
    end
    if shouldScrollToBottom then
        self:ScrollToBottom()
    end
    self:CacheLogSignature(lines, statusLine)
end

function LibConsoleLoggerLogDialog:DialogSetupFunction(dialog)
    dialog.headerData.titleTextAlignment = TEXT_ALIGN_CENTER
    ZO_GamepadGenericHeader_Refresh(dialog.header, dialog.headerData)
    self:RefreshLogs(true)
end

function LibConsoleLoggerLogDialog:Show()
    ShowGamepadDialog("LIB_CONSOLE_LOGGER_LOG_DIALOG", nil, nil)
end

function LibConsoleLoggerLogDialog:Hide()
    ReleaseDialog("LIB_CONSOLE_LOGGER_LOG_DIALOG", nil, nil)
end

function LibConsoleLoggerLogDialog_OnInitialized(control)
    LibConsoleLogger.LogDialog = LibConsoleLoggerLogDialog:New(control)
end

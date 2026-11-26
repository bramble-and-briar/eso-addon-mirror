if not SemisPlaygroundCheckAccess() then return end

local OVERLAY_LANGUAGE = 'sv'
-- A language's own name, the same in every language (the game lists "Deutsch",
-- "Français" the same way), so it is not a localized string id.
local OVERLAY_LANGUAGE_NAME = 'Svenska'

---@class BS_LanguageOptionData
---@field valid fun(): string[]
---@field valueStrings fun(): (fun(): string)[]

---@param values string[]
---@return integer|nil
local function overlayIndex(values)
    for index, value in ipairs(values) do
        if value:lower() == OVERLAY_LANGUAGE then
            return index
        end
    end
    return nil
end

-- Settings → Interface → Text Language. The options screens call these two
-- callbacks every time they build the list, so wrapping them adds the overlay
-- language to the game's own picker. Choosing it there and pressing Apply runs
-- the game's closures only: the language load is then charged to the engine,
-- while the same load started by SetCVar from add-on code is charged to add-on
-- memory. The screen must be opened by the player; opening it or calling
-- ApplySettings() from here would bring the charge back.
--
-- A switch replaces the loaded game text only when <code>.lang exists. An
-- overlay-only language has none, so choosing it from a language other than
-- English leaves that language's text under the overlay until a full restart.
local function addOverlayLanguageToPicker()
    local panel = ZO_SharedOptions_SettingsData and ZO_SharedOptions_SettingsData[SETTING_PANEL_INTERFACE]
    local settings = panel and panel[SETTING_TYPE_UI]
    ---@type BS_LanguageOptionData|nil
    local data = settings and settings[UI_SETTING_TEXT_LANGUAGE]
    if not data or type(data.valid) ~= 'function' or type(data.valueStrings) ~= 'function' then
        return
    end

    local nativeValid, nativeValueStrings = data.valid, data.valueStrings

    data.valid = function()
        local values = nativeValid()
        -- The game already lists the current language when it is unofficial.
        if not overlayIndex(values) then
            values[#values + 1] = OVERLAY_LANGUAGE
        end
        return values
    end

    data.valueStrings = function()
        local strings = nativeValueStrings()
        -- Same position as in valid(): the game's own entry, labelled
        -- "Custom", or one past the end.
        local index = overlayIndex(nativeValid()) or (#strings + 1)
        strings[index] = function() return OVERLAY_LANGUAGE_NAME end
        return strings
    end
end

addOverlayLanguageToPicker()

-- English strings, always loaded first and used as fallback.
-- Guarded so that loading this file twice (English client) does not redefine ids.
local function add(name, text)
    if _G[name] then
        SafeAddString(_G[name], text, 1)
    else
        ZO_CreateStringId(name, text)
    end
end

add("ZCM_PANEL_TITLE", "Zone Completion Map")
add("ZCM_ENABLED", "Enabled")
add("ZCM_ENABLED_TOOLTIP", "Tint fully completed zones on the Tamriel and Aurbis maps.")
add("ZCM_COLOR", "Tint color")
add("ZCM_COLOR_TOOLTIP", "Color and opacity of the tint.")
add("ZCM_INVERT", "Invert tint")
add("ZCM_INVERT_TOOLTIP", "Tint zones that are not yet complete instead of completed ones. Zones without any tracked activity stay untinted.")
add("ZCM_CATEGORIES", "Categories")
add("ZCM_CATEGORIES_DESC", "A zone counts as complete when all enabled categories are done. Categories without activities in a zone are ignored.")
add("ZCM_DEBUG_HEADER", "Zone Completion Map: <<1>> zones found")
add("ZCM_DEBUG_LINE", "<<1>> (<<2>>): <<3>>")
add("ZCM_DEBUG_COMPLETE", "complete")
add("ZCM_DEBUG_INCOMPLETE", "incomplete")

local description = AC_UI.description

        -- General Settings
AC_UI.GeneralMenu = {
    type = "submenu",
    name = SI_AC_MENU_SUBMENU_GENERAL_SETTING,
    reference = "AC_MENU_SUBMENU_GENERAL_SETTING",
    controls = {

        -- Show message when toggle
        {
            type = "checkbox",
            name = SI_AC_MENU_GS_CHECKBOX_SHOW_MESSAGE_WHEN_TOGGLE,
            tooltip = SI_AC_MENU_GS_CHECKBOX_SHOW_MESSAGE_WHEN_TOGGLE_TOOLTIP,
            getFunc = function() return AutoCategory.saved.general["SHOW_MESSAGE_WHEN_TOGGLE"] end,
            setFunc = function(value) AutoCategory.saved.general["SHOW_MESSAGE_WHEN_TOGGLE"] = value end,
        },
        AC_UI.divider(),
        description("|cf3b600"..GetString(SI_AC_MENU_GS_HEADER_CATEGORY).."|r"),
        -- Show category item count
        {
            type = "checkbox",
            name = SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_ITEM_COUNT,
            tooltip =
                SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_ITEM_COUNT_TOOLTIP,
            getFunc = function()
                return AutoCategory.saved.general["SHOW_CATEGORY_ITEM_COUNT"]
                end,
            setFunc = function(value)
                AutoCategory.saved.general["SHOW_CATEGORY_ITEM_COUNT"] = value
                end,
        },

        -- Show category "SET ()"
        {
            type = "checkbox",
            name = SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_SET_TITLE,
            tooltip = SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_SET_TITLE_TOOLTIP,
            getFunc = function() return AutoCategory.saved.general["SHOW_CATEGORY_SET_TITLE"] end,
            setFunc = function(value)
                AutoCategory.saved.general["SHOW_CATEGORY_SET_TITLE"] = value
                AutoCategory.ResetCollapse(AutoCategory.saved.collapses)
            end,
        },
        AC_UI.divider(),
        -- Show category collapse icon
        {
            type = "checkbox",
            name = SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_COLLAPSE_ICON,
            tooltip = SI_AC_MENU_GS_CHECKBOX_SHOW_CATEGORY_COLLAPSE_ICON_TOOLTIP,
            getFunc = function()
                return AutoCategory.saved.general["SHOW_CATEGORY_COLLAPSE_ICON"]
                end,
            setFunc = function(value)
                AutoCategory.saved.general["SHOW_CATEGORY_COLLAPSE_ICON"] = value
                AutoCategory.RefreshCurrentList(true)
            end,
        },

        -- Save category collapse status
        {
            type = "checkbox",
            name = SI_AC_MENU_GS_CHECKBOX_SAVE_CATEGORY_COLLAPSE_STATUS,
            tooltip = SI_AC_MENU_GS_CHECKBOX_SAVE_CATEGORY_COLLAPSE_STATUS_TOOLTIP,
            getFunc = function() return AutoCategory.saved.general["SAVE_CATEGORY_COLLAPSE_STATUS"] end,
            setFunc = function(value) AutoCategory.saved.general["SAVE_CATEGORY_COLLAPSE_STATUS"] = value end,
            disabled = function() return AutoCategory.saved.general["SHOW_CATEGORY_COLLAPSE_ICON"] == false end,
        },
        AC_UI.divider(),
        -- Save category collapse expiry
        {
            type = "dropdown",
            name = SI_AC_MENU_GS_DROPDOWN_CATEGORY_COLLAPSE_EXPIRY,
            tooltip = SI_AC_MENU_GS_DROPDOWN_CATEGORY_COLLAPSE_EXPIRY_TOOLTIP,
            choices = {
                "1 day",
                "7 days",
                "30 days",
                "90 days",
                "Never",
            },
            choicesValues = {
                86400,
                604800,
                2592000,
                7776000,
                "never",
            },
            getFunc = function()
                local duration = AutoCategory.saved.general["CATEGORY_COLLAPSE_EXPIRY_SECONDS"]
                if duration == "never" then
                    return "never"
                end

                return duration or 604800
            end,
            setFunc = function(value)
                AutoCategory.saved.general["CATEGORY_COLLAPSE_EXPIRY_SECONDS"] = value
                AutoCategory.OnCollapseExpiryDurationChanged()
            end,
            default = 604800,   -- 7 days
        },

    }
}

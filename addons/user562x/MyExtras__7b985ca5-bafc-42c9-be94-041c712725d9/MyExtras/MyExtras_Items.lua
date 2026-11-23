local ME = MyExtras
local Items = {}
ME.Items = Items

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds"

--------------------------------------------------
-- Menu
--------------------------------------------------
function Items:GetOptions()
    local options = {}
    if ME.QualityOfLife and ME.QualityOfLife.ItemPages then
        local pages = ME.QualityOfLife:ItemPages()
        for i = 1, #pages do options[#options + 1] = pages[i] end
    end
    if #options == 0 then return {} end
    return {
        {
            type    = "submenu",
            name    = "Items",
            icon    = SUBMENU_ICON,
            tooltip = "Marks items you're missing, shows your loot in chat, shows what your characters know "
                   .. "and stops you from learning things by accident.",
            options = options,
        },
    }
end

ME:RegisterFeature(Items)

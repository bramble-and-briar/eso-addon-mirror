-- PreviewAnywhereHoverActions.lua: "preview whatever item tooltip is on screen", for every gamepad
-- screen that is not already covered by a host (bank / guild bank / vendor: R3) or by the game
-- itself (inventory: hold Square; chat / mail / guild hub links: hold Square via ZO_GamepadLinks).
--
-- Every gamepad item tooltip (bag rows, trade offers, mail attachments, guild store listings,
-- crafting lists, quest rewards, ...) funnels through ZO_Tooltip:LayoutItem(itemLink, ...) on one
-- of the GAMEPAD_TOOLTIPS tooltip objects. Those objects get ZO_Tooltip's functions copied in at
-- creation, so the hook goes on each tooltip object, not on the class. We remember the last item
-- link laid out per tooltip and offer a D-pad Left "Preview" keybind for it; pressing it pushes the
-- standalone preview scene (an interact-scene twin when an interaction is running, so the host
-- screen underneath stays open).
--
-- D-pad Left (UI_SHORTCUT_INPUT_LEFT) is otherwise the ethereal "back" bind on stick-navigation
-- screens, so the button is only registered when no other button owns that keybind in the scene
-- (the strip would evict the other one), and it is removed again as the scene hides.
local PA = PreviewAnywhere
local ProbeUtils = PA.ProbeUtils

local Hover = {}

local TOOLTIP_TYPES = { "GAMEPAD_LEFT_TOOLTIP", "GAMEPAD_RIGHT_TOOLTIP", "GAMEPAD_QUAD3_TOOLTIP", "GAMEPAD_QUAD1_TOOLTIP", "GAMEPAD_QUAD_2_3_TOOLTIP", "GAMEPAD_MOVABLE_TOOLTIP", "GAMEPAD_LEFT_DIALOG_TOOLTIP" }

-- Scenes where another mechanism already offers the preview.
local EXCLUDED_SCENES = {
    gamepad_inventory_root = true, -- stock hold-Square preview
    gamepadChatMenu = true,        -- ZO_GamepadLinks hold-Square button
}

-- tooltipType -> item link currently laid out on that tooltip (nil when cleared)
local shownLinks = {}
local buttonAdded = false
local suppressedForScene = nil -- scene name where a ZO_GamepadLinks instance owns D-pad Left

local function CurrentHoveredLink()
    for _, tooltipType in ipairs(TOOLTIP_TYPES) do
        local link = shownLinks[tooltipType]
        if link then
            local fragment = GAMEPAD_TOOLTIPS:GetTooltipFragment(tooltipType)
            if fragment and fragment:IsShowing() then
                return link, tooltipType
            end
        end
    end
    return nil
end

local function IsHoverButtonVisible()
    if not PA.state.savedVars.enabled then
        return false
    end
    local link = CurrentHoveredLink()
    return link ~= nil and ProbeUtils.CanPreviewLink(link)
end

local hoverDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    keybind = "UI_SHORTCUT_INPUT_LEFT",
    name = GetString(SI_ITEM_ACTION_PREVIEW),
    order = 50,
    visible = IsHoverButtonVisible,
    callback = function()
        PA.SafeCall("HoverPreview", function()
            local link, tooltipType = CurrentHoveredLink()
            PA.Log("hover Preview pressed in %s: %s '%s'", ProbeUtils.CurrentSceneName(), tostring(tooltipType), link and GetItemLinkName(link) or "nil")
            if link and ProbeUtils.CanPreviewLink(link) then
                PA.LinkPreview.ShowLink(link)
            end
        end)
    end,
}

local function IsSceneEligible(sceneName)
    if not sceneName or EXCLUDED_SCENES[sceneName] or PA.SlotPreview.IsHostScene(sceneName) then
        return false
    end
    if string.find(sceneName, "^" .. PA.LinkPreview.SCENE_NAME) then
        return false
    end
    return true
end

local function RemoveHoverButton()
    if buttonAdded then
        KEYBIND_STRIP:RemoveKeybindButton(hoverDescriptor)
        buttonAdded = false
    end
end

---Register the button for the current scene if nobody else holds D-pad Left there.
local function TryAddHoverButton()
    if buttonAdded then
        return
    end
    local sceneName = ProbeUtils.CurrentSceneName()
    if not IsSceneEligible(sceneName) or suppressedForScene == sceneName then
        return
    end
    local scene = SCENE_MANAGER:GetCurrentScene()
    if not scene or scene:GetState() ~= SCENE_SHOWN then
        return
    end
    -- Dialogs run their own keybind-strip state; a button added there would outlive it.
    if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
        return
    end
    if KEYBIND_STRIP.keybinds and KEYBIND_STRIP.keybinds[hoverDescriptor.keybind] ~= nil then
        PA.Debug("hover: D-pad Left taken in %s; no hover preview button", sceneName)
        suppressedForScene = sceneName
        return
    end
    KEYBIND_STRIP:AddKeybindButton(hoverDescriptor)
    buttonAdded = true
    PA.Count("hoverButtonAdds")
    PA.Debug("hover: preview button added in %s", sceneName)
end

local function RefreshHoverButton()
    if buttonAdded then
        KEYBIND_STRIP:UpdateKeybindButton(hoverDescriptor)
    end
end

local hoverLogs = 0
local function OnTooltipItem(tooltipType, itemLink)
    shownLinks[tooltipType] = itemLink
    if hoverLogs < 20 and itemLink and itemLink ~= "" then
        hoverLogs = hoverLogs + 1
        PA.Debug("hover #%d %s in %s: '%s' canPreview=%s", hoverLogs, tooltipType, ProbeUtils.CurrentSceneName(),
            tostring(GetItemLinkName(itemLink)), tostring(ProbeUtils.CanPreviewLink(itemLink)))
    end
    -- The hover button is registered lazily, the first time an item tooltip appears in a scene,
    -- so screens that never show items never get a stray button. Dialog tooltips never add it.
    if tooltipType ~= GAMEPAD_LEFT_DIALOG_TOOLTIP then
        TryAddHoverButton()
    end
    RefreshHoverButton()
end

local function OnTooltipCleared(tooltipType)
    if shownLinks[tooltipType] then
        shownLinks[tooltipType] = nil
        RefreshHoverButton()
    end
end

local function OnSceneStateChanged(scene, _oldState, newState)
    if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        RemoveHoverButton()
        if newState == SCENE_HIDDEN then
            suppressedForScene = nil
            for tooltipType in pairs(shownLinks) do
                shownLinks[tooltipType] = nil
            end
        end
    end
end

---A ZO_GamepadLinks instance registering its keybinds owns D-pad Left (previous link) in this
---scene: step aside for the scene's lifetime.
function Hover.OnGamepadLinksKeybinds()
    suppressedForScene = ProbeUtils.CurrentSceneName()
    RemoveHoverButton()
end

---Which GAMEPAD_TOOLTIPS slot a tooltip (or its scroll container) object belongs to. Resolved
---lazily and cached: the objects only exist once the game initializes them.
local objectToType = setmetatable({}, { __mode = "k" })
local function ResolveTooltipType(object, getter)
    local cached = objectToType[object]
    if cached ~= nil then
        return cached or nil
    end
    for _, tooltipTypeName in ipairs(TOOLTIP_TYPES) do
        local tooltipKey = rawget(_G, tooltipTypeName)
        if tooltipKey then
            local ok, candidate = pcall(getter, tooltipKey)
            if ok and candidate == object then
                objectToType[object] = tooltipKey
                return tooltipKey
            end
        end
    end
    objectToType[object] = false
    return nil
end

-- Read-only lookups (GetTooltip / GetAndInitializeTooltipContainerTip would initialize tooltips
-- from inside our hook).
local function GetTooltipObject(tooltipKey)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipKey)
    return container and container.tip and container.tip.tooltip
end

local function GetContainerObject(tooltipKey)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipKey)
    return container and container.tip
end

local function OnAnyTooltipLayoutItem(tooltip, itemLink)
    local tooltipKey = ResolveTooltipType(tooltip, GetTooltipObject)
    if tooltipKey then
        OnTooltipItem(tooltipKey, itemLink)
    end
end

local function OnAnyContainerClearLines(containerTip)
    local tooltipKey = ResolveTooltipType(containerTip, GetContainerObject)
    if tooltipKey then
        OnTooltipCleared(tooltipKey)
    end
end

function Hover.Initialize()
    -- The tooltip objects are controls (userdata), which SecurePostHook refuses (0.3.0 init
    -- error). ZO_Tooltip / ZO_ScrollTooltip_Gamepad are zo_mixin'ed INTO those controls when the
    -- game first initializes each tooltip, so hooking the class tables now means every tooltip
    -- initialized from here on carries the secure wrapper. Tooltips the game already initialized
    -- before we loaded keep the plain function; those get a (tainted, but harmless for tooltips)
    -- ZO_PostHook on the object itself and are logged.
    PA.SecureHook(ZO_Tooltip, "LayoutItem", PA.Guard("TooltipLayoutItem", OnAnyTooltipLayoutItem))
    if rawget(_G, "ZO_ScrollTooltip_Gamepad") then
        PA.SecureHook(ZO_ScrollTooltip_Gamepad, "ClearLines", PA.Guard("TooltipClearLines", OnAnyContainerClearLines))
    end

    local alreadyInitialized = {}
    for _, tooltipTypeName in ipairs(TOOLTIP_TYPES) do
        local tooltipKey = rawget(_G, tooltipTypeName)
        if tooltipKey then
            local ok, container = pcall(function() return GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipKey) end)
            local tip = ok and container and container.tip
            if tip and tip.initialized then
                alreadyInitialized[#alreadyInitialized + 1] = tooltipTypeName
                if type(tip.ClearLines) == "function" then
                    ZO_PostHook(tip, "ClearLines", PA.Guard("TooltipClearLines", function(self) OnAnyContainerClearLines(self) end))
                end
                if tip.tooltip and type(tip.tooltip.LayoutItem) == "function" then
                    ZO_PostHook(tip.tooltip, "LayoutItem", PA.Guard("TooltipLayoutItem", function(self, itemLink) OnAnyTooltipLayoutItem(self, itemLink) end))
                end
            end
        end
    end
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", PA.Guard("HoverSceneStateChanged", OnSceneStateChanged))
    PA.Debug("hover: class hooks installed; tooltips already initialized before load: %s", #alreadyInitialized > 0 and table.concat(alreadyInitialized, ", ") or "none")
end

PA.Hover = Hover

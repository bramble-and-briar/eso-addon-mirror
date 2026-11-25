-- PreviewAnywhereHoverActions.lua: "preview whatever item tooltip is on screen", on the gamepad
-- screens named in SCENE_KEYBIND. Every other screen has no button: the hosts (bank / guild bank /
-- vendor / guild trader Sell tab) offer R3 themselves, the game covers its own (inventory: hold
-- Square; chat / mail / guild hub links: hold Square via ZO_GamepadLinks; guild trader: Preview on
-- the search results), and an unnamed screen may navigate with the D-pad.
--
-- Every gamepad item tooltip (bag rows, trade offers, mail attachments, crafting lists, quest
-- rewards, ...) funnels through ZO_Tooltip:LayoutItem(itemLink, ...) on one
-- of the GAMEPAD_TOOLTIPS tooltip objects. Those objects get ZO_Tooltip's functions copied in at
-- creation, so the hook goes on each tooltip object, not on the class. We remember the last item
-- link laid out per tooltip and offer a D-pad Left "Preview" keybind for it; pressing it pushes the
-- standalone preview scene (an interact-scene twin when an interaction is running, so the host
-- screen underneath stays open).
--
-- D-pad Left (UI_SHORTCUT_INPUT_LEFT) is otherwise the ethereal "back" bind on stick-navigation
-- screens, so the button is only registered when no other button owns that keybind in the scene
-- (the strip would evict the other one), and it is removed again as the scene hides.
--
-- Why the screens are named (1.4.1) rather than "every screen but a few": grids, horizontal
-- selectors and spinners take the D-pad through DIRECTIONAL_INPUT, which the keybind strip knows
-- nothing about. On such a screen a D-pad Left press both moves the screen's own selection and
-- opens the preview over it, and backing out of the preview re-opens the screen from scratch. It
-- misfired that way in the set-piece grids (1.3.1) and at the guild trader (1.3.3), each patched
-- with one more exclusion; naming the screens that are known to be free ends the series. A named
-- screen is one whose gamepad source moves a vertical list and nothing else, or a D-pad grid
-- given R3 (the vendor Buy tab's own Preview button) instead.
local PA = PreviewAnywhere
local ProbeUtils = PA.ProbeUtils

local Hover = {}

local TOOLTIP_TYPES = { "GAMEPAD_LEFT_TOOLTIP", "GAMEPAD_RIGHT_TOOLTIP", "GAMEPAD_QUAD3_TOOLTIP", "GAMEPAD_QUAD1_TOOLTIP", "GAMEPAD_QUAD_2_3_TOOLTIP", "GAMEPAD_MOVABLE_TOOLTIP", "GAMEPAD_LEFT_DIALOG_TOOLTIP" }

local D_PAD_LEFT = "UI_SHORTCUT_INPUT_LEFT"
local R3 = "UI_SHORTCUT_RIGHT_STICK"

-- The screens that get the hover Preview button, and the keybind it sits on there. A screen is
-- added once its gamepad source shows what its D-pad does (see the header).
local SCENE_KEYBIND = {
    -- A vertical list and nothing else on the D-pad.
    gamepadTrade = D_PAD_LEFT,                 -- trade window: both offers
    mailGamepad = D_PAD_LEFT,                  -- mail: attachments (links step aside, OnGamepadLinksKeybinds)
    gamepadInteract = D_PAD_LEFT,              -- NPC dialogue: quest reward choices
    lootGamepad = D_PAD_LEFT,                  -- loot window
    lootInventoryGamepad = D_PAD_LEFT,         -- loot window, inventory-style
    companionEquipmentGamepad = D_PAD_LEFT,    -- companion gear
    gamepad_smithing_deconstruct = D_PAD_LEFT, -- crafting station: deconstruct
    -- The D-pad moves a grid: the button goes on R3.
    reconstruct_gamepad = R3, -- transmute station, Reconstruct: set-piece grid
    gamepadItemSetsBook = R3, -- Collections, Sets: the same grid
}

-- tooltipType -> item link currently laid out on that tooltip (nil when cleared)
local shownLinks = {}
local buttonAdded = false
local suppressedForScene = nil -- scene name where another button owns the scene's hover keybind

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

-- keybind is set per scene as the button is added (TryAddHoverButton); the strip indexes a button
-- by its keybind, so it only changes while the button is off the strip.
local hoverDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    keybind = D_PAD_LEFT,
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

local function RemoveHoverButton()
    if buttonAdded then
        KEYBIND_STRIP:RemoveKeybindButton(hoverDescriptor)
        buttonAdded = false
    end
end

---Register the button for the current scene if nobody else holds the scene's hover keybind there.
local function TryAddHoverButton()
    if buttonAdded then
        return
    end
    local sceneName = ProbeUtils.CurrentSceneName()
    local keybind = sceneName and SCENE_KEYBIND[sceneName]
    if not keybind or suppressedForScene == sceneName then
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
    if KEYBIND_STRIP.keybinds and KEYBIND_STRIP.keybinds[keybind] ~= nil then
        PA.Debug("hover: %s taken in %s; no hover preview button", keybind, sceneName)
        suppressedForScene = sceneName
        return
    end
    hoverDescriptor.keybind = keybind
    KEYBIND_STRIP:AddKeybindButton(hoverDescriptor)
    buttonAdded = true
    PA.Count("hoverButtonAdds")
    PA.Debug("hover: preview button added in %s on %s", sceneName, keybind)
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

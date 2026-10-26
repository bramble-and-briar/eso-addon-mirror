-- PreviewAnywhereLinkPreviewActions.lua: previews raw item links (chat, mail, guild hub) in a
-- pushed scene assembled from the same fragments as the guild store's preview scene
-- (TRADING_HOUSE_PREVIEW_GAMEPAD_SCENE in gamepadingamescenes.lua).
--
-- Open question this build answers: does the public PreviewItemLink actually render a link the
-- client did not hand us itself? Every step logs so the exported log shows where it stops.
local PA = PreviewAnywhere
local ProbeUtils = PA.ProbeUtils

local LinkPreview = {}

LinkPreview.SCENE_NAME = "PreviewAnywhere_LinkPreview"
LinkPreview.PREVIEW_TYPE = "PreviewAnywhere_ItemLink" -- string key: cannot collide with ZO_ITEM_PREVIEW_* numbers

local pending = nil -- { links = string[], index = integer }
local sceneCreated = false
-- Pushing a plain scene over a ZO_InteractScene (bank, vendor, guild store, crafting...) ends the
-- interaction. The game's own trading-house preview scene avoids that by being an interact scene
-- of the same interaction, so we create one link-preview scene per interaction type on demand.
local interactScenes = {} -- interactionInfo.type -> scene name

---Preview type that renders an arbitrary item link through PreviewItemLink.
local ItemLinkPreviewType = ZO_ItemPreviewType:Subclass()

---Recipes / furnishing plans resolve to the link of what they craft (the plan itself is not
---previewable); anything else renders as-is. Forced probes pass links the engine rejected.
function ItemLinkPreviewType:SetStaticParameters(itemLink)
    self.itemLink = itemLink
    local resolved, viaRecipe = ProbeUtils.ResolvePreviewLink(itemLink)
    self.renderLink = resolved or itemLink
    if viaRecipe then
        PA.Debug("recipe '%s' previews as result '%s'", tostring(GetItemLinkName(itemLink)), tostring(GetItemLinkName(self.renderLink)))
    end
end

function ItemLinkPreviewType:ResetStaticParameters()
    self.itemLink = nil
    self.renderLink = nil
end

function ItemLinkPreviewType:HasStaticParameters(itemLink)
    return self.itemLink == itemLink
end

function ItemLinkPreviewType:Apply(variationIndex)
    PA.Count("linkApply")
    local ok, err = pcall(PreviewItemLink, self.renderLink, variationIndex)
    PA.Log("PreviewItemLink(%s, %s) -> %s%s", tostring(self.renderLink), tostring(variationIndex), ok and "called" or "ERROR", ok and "" or (" " .. tostring(err)))
    PA.Debug("  after apply: %s", ProbeUtils.PreviewStateLine())
    -- Did the engine accept it? IsCurrentlyPreviewing flips once the preview collection is applied.
    PA.DebugLater(400, "  +400ms: %s")
    PA.DebugLater(1500, "  +1500ms: %s")
end

function ItemLinkPreviewType:GetNumVariations()
    local ok, n = pcall(GetNumItemLinkPreviewVariations, self.renderLink)
    return ok and n or 0
end

function ItemLinkPreviewType:GetVariationName(variationIndex)
    local ok, name = pcall(GetItemLinkPreviewVariationDisplayName, self.renderLink, variationIndex)
    if ok and name and name ~= "" then
        return name
    end
    return tostring(variationIndex)
end

local backKeybinds =
{
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = GetString(SI_GAMEPAD_BACK_OPTION),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function()
            SCENE_MANAGER:HideCurrentScene()
        end,
    },
}

local function OnSceneStateChange(_oldState, newState)
    PA.Debug("link scene state %s | %s", tostring(newState), ProbeUtils.PreviewStateLine())
    if newState == SCENE_SHOWING then
        KEYBIND_STRIP:AddKeybindButtonGroup(backKeybinds)
    elseif newState == SCENE_SHOWN then
        if pending and #pending.links > 0 then
            PA.Log("link scene shown; previewing %d link(s) starting at %d", #pending.links, pending.index)
            PA.SafeCall("PreviewList", function()
                ITEM_PREVIEW_LIST_HELPER_GAMEPAD:PreviewList(LinkPreview.PREVIEW_TYPE, pending.links, pending.index)
            end)
        else
            PA.Log("link scene shown with nothing pending")
        end
    elseif newState == SCENE_HIDDEN then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(backKeybinds)
        pending = nil
    end
end

local function AddPreviewFragments(scene)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_CENTERED_NO_BLUR)
    -- Options fragment must precede the ITEM_PREVIEW_GAMEPAD fragment (inside the list helper group).
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_FURNITURE_ITEM_PREVIEW_OPTIONS_FRAGMENT)
    scene:AddFragmentGroup(ZO_ITEM_PREVIEW_LIST_HELPER_GAMEPAD_FRAGMENT_GROUP)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:RegisterCallback("StateChange", PA.Guard("LinkSceneStateChange", OnSceneStateChange))
end

---Name of the scene to push from the current scene: the plain one, or an interact-scene twin
---carrying the current interaction so the bank/vendor/station stays open underneath.
---@return string|nil
local function GetSceneNameForCurrentContext()
    local current = SCENE_MANAGER:GetCurrentScene()
    local interactionInfo = current and current.GetInteractionInfo and current:GetInteractionInfo()
    if not interactionInfo then
        return LinkPreview.SCENE_NAME
    end
    local key = tostring(interactionInfo.type or interactionInfo)
    if not interactScenes[key] then
        local name = LinkPreview.SCENE_NAME .. "_" .. key
        local ok, err = pcall(function()
            local scene = ZO_InteractScene:New(name, SCENE_MANAGER, interactionInfo)
            AddPreviewFragments(scene)
        end)
        if not ok then
            PA.Log("could not create interact preview scene for %s: %s", key, tostring(err))
            return nil
        end
        interactScenes[key] = name
        PA.Debug("created interact link preview scene %s", name)
    end
    return interactScenes[key]
end

---Push the preview scene for a list of item links.
---@param links string[]
---@param startIndex integer|nil
function LinkPreview.Show(links, startIndex)
    if not sceneCreated then
        PA.Log("link preview scene not available (init failed)")
        return
    end
    local sceneName = GetSceneNameForCurrentContext()
    if not sceneName then
        return
    end
    pending = { links = links, index = startIndex or 1 }
    PA.Log("pushing %s from %s", sceneName, ProbeUtils.CurrentSceneName())
    SCENE_MANAGER:Push(sceneName)
end

---Convenience for a single link.
---@param link string
function LinkPreview.ShowLink(link)
    LinkPreview.Show({ link }, 1)
end

---Collect previewable item links from a ZO_GamepadLinks instance.
---@param gamepadLinks table
---@return string[] links
---@return integer startIndex
local function GetPreviewableLinks(gamepadLinks)
    local links, startIndex = {}, 1
    local current = gamepadLinks:GetCurrentLink()
    for _, linkData in ipairs(gamepadLinks:GetLinks()) do
        if ProbeUtils.CanPreviewLink(linkData.link) then
            links[#links + 1] = linkData.link
            if linkData == current then
                startIndex = #links
            end
        end
    end
    return links, startIndex
end

---Secure post-hook body for ZO_GamepadLinks:AddKeybinds: append our Preview button to the
---instance's group once; the group is already registered on the first pass, so register the new
---button directly this time (RemoveKeybinds later removes the whole group, ours included).
---QUATERNARY ("hold Square" on PS) is unclaimed by the chat menu, mail inbox and guild hub hosts.
local function InjectLinkKeybind(gamepadLinks)
    if PA.Hover then
        PA.Hover.OnGamepadLinksKeybinds()
    end
    if gamepadLinks.previewAnywhereInjected then
        return
    end
    gamepadLinks.previewAnywhereInjected = true
    PA.Count("linkHostsInjected")
    PA.Debug("ZO_GamepadLinks instance injected (scene %s)", ProbeUtils.CurrentSceneName())

    local descriptor = {
        order = 30,
        keybind = "UI_SHORTCUT_QUATERNARY",
        name = GetString(SI_ITEM_ACTION_PREVIEW),
        callback = function()
            local links, startIndex = GetPreviewableLinks(gamepadLinks)
            PA.Log("link Preview pressed: %d previewable of %d links", #links, gamepadLinks:GetNumLinks())
            if #links > 0 then
                LinkPreview.Show(links, startIndex)
            end
        end,
        visible = function()
            if not PA.state.savedVars.enabled then
                return false
            end
            local linkData = gamepadLinks:GetCurrentLink()
            local can = linkData ~= nil and ProbeUtils.CanPreviewLink(linkData.link)
            if linkData and linkData.linkType == ITEM_LINK_TYPE then
                PA.state.lastHoveredLink = linkData.link
            end
            if linkData and linkData.link ~= gamepadLinks.previewAnywhereLastLogged then
                gamepadLinks.previewAnywhereLastLogged = linkData.link
                -- Raw engine answers, separately, so the gate can be told apart from a link-type mismatch.
                local okType, engineType = pcall(GetLinkType, linkData.link)
                local okCan, engineCan = pcall(CanItemLinkBePreviewed, linkData.link)
                local okVar, variations = pcall(GetNumItemLinkPreviewVariations, linkData.link)
                PA.Debug("link shown: parsedType=%s GetLinkType=%s CanItemLinkBePreviewed=%s variations=%s ourCan=%s '%s' itemType=%s %s",
                    tostring(linkData.linkType), okType and tostring(engineType) or ("ERR " .. tostring(engineType)),
                    okCan and tostring(engineCan) or ("ERR " .. tostring(engineCan)), okVar and tostring(variations) or ("ERR " .. tostring(variations)),
                    tostring(can), tostring(GetItemLinkName(linkData.link)), tostring(GetItemLinkItemType(linkData.link)), tostring(linkData.link))
            end
            return can
        end,
    }
    table.insert(gamepadLinks.keybindStripDescriptor, descriptor)
    if gamepadLinks.registeredKeybinds then
        KEYBIND_STRIP:AddKeybindButton(descriptor)
    end
end

function LinkPreview.Initialize()
    ITEM_PREVIEW_GAMEPAD.previewTypeObjects[LinkPreview.PREVIEW_TYPE] = ItemLinkPreviewType:New()

    local scene = ZO_Scene:New(LinkPreview.SCENE_NAME, SCENE_MANAGER)
    AddPreviewFragments(scene)
    sceneCreated = true

    PA.SecureHook(ZO_GamepadLinks, "AddKeybinds", PA.Guard("InjectLinkKeybind", InjectLinkKeybind))
end

PA.LinkPreview = LinkPreview

-- PreviewAnywhereProbeActions.lua: the /pva probe report and link test.
local PA = PreviewAnywhere

---Command replies: always to chat, and into the log buffer when debug mode is on.
local function Say(fmt, ...)
    local line = PA.Fmt(fmt, ...)
    PA.Chat(line)
    PA.Log("%s", line)
end
local ProbeUtils = PA.ProbeUtils
local Fmt = PA.Fmt

local Probe = {}

local GLOBALS_TO_CHECK = {
    "ITEM_PREVIEW_GAMEPAD", "ITEM_PREVIEW_LIST_HELPER_GAMEPAD", "ZO_ITEM_PREVIEW_LIST_HELPER_GAMEPAD_FRAGMENT_GROUP",
    "GAMEPAD_NAV_QUADRANT_2_3_FURNITURE_ITEM_PREVIEW_OPTIONS_FRAGMENT", "FRAME_TARGET_CENTERED_FRAGMENT",
    "FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT", "TRADING_HOUSE_PREVIEW_GAMEPAD_SCENE",
    "GAMEPAD_BANKING", "GAMEPAD_GUILD_BANK", "GAMEPAD_INVENTORY", "CHAT_MENU_GAMEPAD",
    "ZO_GamepadLinks", "ZO_BankingCommon_Gamepad", "ZO_GamepadBanking", "ZO_GamepadInventory", "ZO_ItemPreviewType",
    "ZO_InventorySlot_DiscoverSlotActionsFromActionList", "ZO_Inventory_GetBagAndIndex",
    "IsCharacterPreviewingAvailable", "CanInventoryItemBePreviewed", "PreviewInventoryItem",
    "CanItemLinkBePreviewed", "PreviewItemLink", "PreviewItemLinkAction", "GetNumItemLinkPreviewVariations",
    "IsCurrentlyPreviewing", "GetPreviewModeEnabled", "EndCurrentItemPreview",
    "SetInteractionUsingInteractCamera", "IsInteractionUsingInteractCamera", "GetInteractionType",
    "BAG_BACKPACK", "BAG_BANK", "BAG_SUBSCRIBER_BANK", "BAG_FURNITURE_VAULT", "BAG_GUILDBANK", "ITEMTYPE_FURNISHING",
}

local BAGS_TO_SCAN = { "BAG_BACKPACK", "BAG_BANK", "BAG_SUBSCRIBER_BANK", "BAG_FURNITURE_VAULT", "BAG_HOUSE_BANK_ONE", "BAG_GUILDBANK" }

---Log everything the design depends on. Pure reads: safe to run anywhere, any time.
function Probe.Report()
    local d = PA.diagnostics
    Say("=== probe v%s api=%s gamepad=%s console=%s scene=%s", PA.version, tostring(GetAPIVersion()), tostring(IsInGamepadPreferredMode()),
        tostring(rawget(_G, "IsConsoleUI") and IsConsoleUI()), ProbeUtils.CurrentSceneName())
    Say("init=%s lateInit=%s addonNames=%d initErrors=%d runtimeErrors=%d", tostring(d.initialized), tostring(d.lateInit), #d.addonNames, #d.initErrors, #d.errors)
    for _, err in ipairs(d.initErrors) do Say("  initError: %s", err) end
    for _, err in ipairs(d.errors) do Say("  error: %s", err) end

    local missing = {}
    for _, name in ipairs(GLOBALS_TO_CHECK) do
        if rawget(_G, name) == nil then
            missing[#missing + 1] = name
        end
    end
    Say("globals: %d checked, missing: %s", #GLOBALS_TO_CHECK, #missing == 0 and "none" or table.concat(missing, ", "))
    local preview = rawget(_G, "ITEM_PREVIEW_GAMEPAD")
    if preview then
        Say("ITEM_PREVIEW_GAMEPAD methods: SetInteractionCameraPreviewEnabled=%s previewTypeObjects=%s ourType=%s",
            tostring(preview.SetInteractionCameraPreviewEnabled ~= nil), tostring(type(preview.previewTypeObjects)),
            tostring(preview.previewTypeObjects and preview.previewTypeObjects[PA.LinkPreview.PREVIEW_TYPE] ~= nil))
    end
    for _, sceneName in ipairs({ "gamepad_banking", "gamepad_guild_bank", "gamepad_inventory_root", "gamepadChatMenu", PA.LinkPreview.SCENE_NAME }) do
        Say("scene %s: %s", sceneName, tostring(SCENE_MANAGER:GetScene(sceneName) ~= nil))
    end
    Say("state: %s", ProbeUtils.PreviewStateLine())

    local firstPreviewableLink
    for _, bagName in ipairs(BAGS_TO_SCAN) do
        local bagId = rawget(_G, bagName)
        if bagId then
            local lines, links = ProbeUtils.ScanBag(bagId, 3)
            for _, line in ipairs(lines) do Say("%s", line) end
            firstPreviewableLink = firstPreviewableLink or links[1]
        else
            Say("%s: constant missing", bagName)
        end
    end

    local chatLinks, messages = ProbeUtils.CollectChatItemLinks()
    Say("chat menu: %d messages, %d item links", messages, #chatLinks)
    for i = 1, math.min(#chatLinks, 6) do
        local link = chatLinks[i]
        local okCan, can = pcall(CanItemLinkBePreviewed, link)
        local okVar, n = pcall(GetNumItemLinkPreviewVariations, link)
        Say("  chat link %d: '%s' type=%s canPreview=%s variations=%s", i, tostring(GetItemLinkName(link)), tostring(GetItemLinkItemType(link)),
            okCan and tostring(can) or ("ERR " .. tostring(can)), okVar and tostring(n) or ("ERR " .. tostring(n)))
    end
    if firstPreviewableLink then
        Say("normalized own link: %s -> canPreview=%s", tostring(ProbeUtils.NormalizeItemLink(firstPreviewableLink)),
            tostring(ProbeUtils.CanPreviewLink(ProbeUtils.NormalizeItemLink(firstPreviewableLink))))
    end
    Say("=== probe done; /pva linktest to try PreviewItemLink, /pva export to ship this log")
end

---Push the link preview scene with chat links (or, failing that, normalized links of own
---previewable items) so the log shows whether PreviewItemLink renders anything.
---@param which integer|nil 1-based index into the candidate list
---@param force boolean|nil Ignore CanItemLinkBePreviewed and try PreviewItemLink on chat links anyway
function Probe.LinkTest(which, force)
    local candidates = {}
    local chatLinks = ProbeUtils.CollectChatItemLinks()
    -- The chat menu's message log is not always readable from a slash command; the link whose
    -- tooltip was last shown in the chat menu is the most reliable candidate.
    if PA.state.lastHoveredLink then
        table.insert(chatLinks, 1, PA.state.lastHoveredLink)
        local link = PA.state.lastHoveredLink
        local okType, engineType = pcall(GetLinkType, link)
        local okCan, engineCan = pcall(CanItemLinkBePreviewed, link)
        Say("linktest: last hovered '%s' GetLinkType=%s CanItemLinkBePreviewed=%s", tostring(GetItemLinkName(link)),
            okType and tostring(engineType) or ("ERR " .. tostring(engineType)), okCan and tostring(engineCan) or ("ERR " .. tostring(engineCan)))
    else
        Say("linktest: no link hovered in the chat menu yet this session")
    end
    for _, link in ipairs(chatLinks) do
        if force or ProbeUtils.CanPreviewLink(link) then
            candidates[#candidates + 1] = link
        end
    end
    local source = force and "chat (forced, CanItemLinkBePreviewed ignored)" or "chat"
    if #candidates == 0 then
        source = "normalized own items"
        for _, bagName in ipairs({ "BAG_BACKPACK", "BAG_BANK" }) do
            local bagId = rawget(_G, bagName)
            if bagId then
                local _, links = ProbeUtils.ScanBag(bagId, 0)
                for _, link in ipairs(links) do
                    local normalized = ProbeUtils.NormalizeItemLink(link)
                    if normalized and ProbeUtils.CanPreviewLink(normalized) then
                        candidates[#candidates + 1] = normalized
                    end
                end
            end
        end
    end
    if #candidates == 0 then
        Say("linktest: no previewable item links in chat (%d item links seen) and no previewable own items; post a furnishing link in chat first", #chatLinks)
        return
    end
    local index = math.max(1, math.min(which or 1, #candidates))
    local link = candidates[index]
    Say("linktest: %d candidates from %s; starting at %d '%s' type=%s canPreview=%s", #candidates, source, index,
        tostring(GetItemLinkName(link)), tostring(GetItemLinkItemType(link)), tostring(ProbeUtils.CanPreviewLink(link)))
    PA.LinkPreview.Show(candidates, index)
end

---Style probe: can the engine render your equipped shoulder piece re-styled to the motif whose
---chat link you last hovered (or to the style id given)? PreviewCollectible is private on console,
---so a re-styled gear link is the only public route to a motif preview.
---@param styleArg string|nil
function Probe.StyleTest(styleArg)
    local styleId = tonumber(styleArg)
    local motifLink = PA.state.lastHoveredLink
    if not styleId and motifLink then
        local okStyle, style = pcall(GetItemLinkItemStyle, motifLink)
        Say("styletest: last hovered '%s' type=%s GetItemLinkItemStyle=%s", tostring(GetItemLinkName(motifLink)),
            tostring(GetItemLinkItemType(motifLink)), okStyle and tostring(style) or ("ERR " .. tostring(style)))
        if okStyle and style and style > 0 then
            styleId = style
        end
    end
    if not styleId then
        Say("styletest: no style id (hover a motif link in chat first, or /pva styletest <styleId>)")
        return
    end
    local base
    for _, slot in ipairs({ EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HEAD, EQUIP_SLOT_LEGS }) do
        local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)
        if link and link ~= "" then
            base = link
            break
        end
    end
    if not base then
        Say("styletest: nothing equipped to re-style")
        return
    end
    local restyled = ProbeUtils.WithItemLinkStyle(base, styleId)
    local okCan, can = pcall(CanItemLinkBePreviewed, restyled or "")
    Say("styletest: base '%s' style %s -> %s | restyled style %d CanItemLinkBePreviewed=%s name='%s' %s",
        tostring(GetItemLinkName(base)), tostring(GetItemLinkItemStyle(base)), tostring(GetItemStyleName(styleId)), styleId,
        okCan and tostring(can) or ("ERR " .. tostring(can)), restyled and tostring(GetItemLinkName(restyled)) or "nil", tostring(restyled))
    if restyled then
        PA.LinkPreview.Show({ restyled }, 1)
    end
end

function Probe.Status()
    local d = PA.diagnostics
    local parts = {}
    for key, count in pairs(d.counters) do parts[#parts + 1] = Fmt("%s=%d", key, count) end
    table.sort(parts)
    Say("v%s enabled=%s debug=%s debugChat=%s init=%s errors=%d | %s", PA.version, tostring(PA.state.savedVars.enabled), tostring(PA.state.savedVars.debug), tostring(PA.state.savedVars.debugChat),
        tostring(d.initialized), #d.errors + #d.initErrors, #parts > 0 and table.concat(parts, " ") or "no counters yet")
    for _, err in ipairs(d.initErrors) do Say("  initError: %s", err) end
    for _, err in ipairs(d.errors) do Say("  error: %s", err) end
    if PA.VaultCategories then Say("%s", PA.VaultCategories.StatusLine()) end
    Say("%s", PA.LoggerStateLine())
end

function Probe.Help()
    Say("/pva on | off (toggle the addon) | invframe (inventory hold-Square preview beside the tooltip, or game default) | vault on|off|sub|everywhere (Furnishing Vault category headers) | status | debug (toggle diagnostics; /pva export ships them when LibConsoleLogger is installed)")
    if not PA.IsDebug() then
        return
    end
    Say("debug: /pva probe (log API facts) | linktest [n] (preview a chat link) | linktest force [n] (ignore the CanItemLinkBePreviewed gate) | styletest [styleId] (equipped piece re-styled to the hovered motif) | export | clear | chat (echo diagnostics to chat)")
end

PA.Probe = Probe

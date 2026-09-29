-- -----------------------------------------------------------------------------
-- HUDitorTools - named HUD layouts (snapshots of HUD_MANAGER.savedVars.profiles[1])
-- Live HUD is always profiles[1] (PRIMARY_PROFILE_INDEX in hudmanager.lua).
-- Named layouts live in HUDitorToolsSV. Apply copies snapshot to live, then
-- PropagateSettings / RebuildAllElements.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

HT.LAYOUT_SCOPE_ACCOUNT = "account"
HT.LAYOUT_SCOPE_CHARACTER = "character"
HT.MAX_HUD_LAYOUTS_PER_SCOPE = 20

local PRIMARY_PROFILE_INDEX = 1
local lastCharacterIdAppliedThisSession
local liveLayoutBaselinePayload
local suppressOffsetsChangedRefresh = false

local function GetLiveHudProfile()
    return HUD_MANAGER.savedVars.profiles[PRIMARY_PROFILE_INDEX]
end

local function CopyPayload(payload)
    return HT.NormalizeLayoutPayload(payload)
end

function HT.CollectLiveHudPayload()
    local profile = GetLiveHudProfile()
    return HT.NormalizeLayoutPayload({
        keyboardElements = profile.keyboardElements,
        gamepadElements = profile.gamepadElements,
        elementAppearance = HT.SV.elementAppearance,
        resourceBarGroup = HT.SV.resourceBarGroup,
    })
end

local function SetLiveLayoutBaseline(payload)
    liveLayoutBaselinePayload = CopyPayload(payload)
end

function HT.IsLiveLayoutDirty()
    if not liveLayoutBaselinePayload then
        return false
    end
    return HT.EncodeHudLayoutPayload(HT.CollectLiveHudPayload()) ~= HT.EncodeHudLayoutPayload(liveLayoutBaselinePayload)
end

function HT.GetAccountLayoutList()
    return HT.SV.hudLayoutsAccount
end

function HT.GetCharacterLayoutList()
    local characterId = GetCurrentCharacterId()
    local layoutList = HT.SV.hudLayoutsCharacter[characterId]
    if not layoutList then
        layoutList = {}
        HT.SV.hudLayoutsCharacter[characterId] = layoutList
    end
    return layoutList
end

local function GetLayoutListForScope(scope)
    if scope == HT.LAYOUT_SCOPE_CHARACTER then
        return HT.GetCharacterLayoutList()
    end
    return HT.SV.hudLayoutsAccount
end

function HT.CountLayoutsInScope(scope)
    return #GetLayoutListForScope(scope)
end

function HT.CanCreateLayoutInScope(scope)
    return HT.CountLayoutsInScope(scope) < HT.MAX_HUD_LAYOUTS_PER_SCOPE
end

function HT.FindLayout(scope, layoutId)
    local layoutList = GetLayoutListForScope(scope)
    for _, layoutData in ipairs(layoutList) do
        if layoutData.layoutId == layoutId then
            return layoutData
        end
    end
end

local function CreateLayoutSelection(characterId)
    local selection =
    {
        scope = HT.LAYOUT_SCOPE_ACCOUNT,
        layoutId = HT.SV.hudLayoutsAccount[1] and HT.SV.hudLayoutsAccount[1].layoutId,
    }
    HT.SV.hudLayoutSelectionByCharacter[characterId] = selection
    return selection
end

function HT.GetLayoutSelection()
    local characterId = GetCurrentCharacterId()
    local selection = HT.SV.hudLayoutSelectionByCharacter[characterId]
    if not selection then
        selection = CreateLayoutSelection(characterId)
    end
    return selection
end

function HT.GetActiveLayout()
    local selection = HT.GetLayoutSelection()
    return HT.FindLayout(selection.scope, selection.layoutId), selection.scope
end

function HT.FormatLayoutChoiceName(scope, layoutData, isActive)
    local scopeLabel = GetString(SI_HUDITORTOOLS_LAYOUT_ACCOUNT)
    if scope == HT.LAYOUT_SCOPE_CHARACTER then
        scopeLabel = GetString(SI_HUDITORTOOLS_LAYOUT_CHARACTER)
    end
    local layoutName = layoutData.name
    if isActive and HT.IsLiveLayoutDirty() then
        layoutName = zo_strformat(GetString(SI_HUDITORTOOLS_LAYOUT_DIRTY_MARK), layoutName)
    end
    return zo_strformat(GetString(SI_HUDITORTOOLS_LAYOUT_DROPDOWN_FORMAT), scopeLabel, layoutName)
end

function HT.GetLayoutDropdownChoices()
    local names = {}
    local values = {}
    local activeLayout, activeScope = HT.GetActiveLayout()
    local function AppendScope(scope, layoutList)
        for _, layoutData in ipairs(layoutList) do
            local isActive = activeLayout and activeScope == scope and activeLayout.layoutId == layoutData.layoutId
            names[#names + 1] = HT.FormatLayoutChoiceName(scope, layoutData, isActive)
            values[#values + 1] = scope .. ":" .. tostring(layoutData.layoutId)
        end
    end
    AppendScope(HT.LAYOUT_SCOPE_ACCOUNT, HT.SV.hudLayoutsAccount)
    AppendScope(HT.LAYOUT_SCOPE_CHARACTER, HT.GetCharacterLayoutList())
    return names, values
end

function HT.GetActiveLayoutChoiceValue()
    local layoutData, scope = HT.GetActiveLayout()
    if not layoutData then
        return
    end
    return scope .. ":" .. tostring(layoutData.layoutId)
end

function HT.SwitchHudLayoutFromChoiceValue(choiceValue)
    local scope, layoutIdText = zo_strsplit(":", choiceValue)
    return HT.SwitchHudLayout(scope, tonumber(layoutIdText))
end

function HT.IsLayoutNameUnique(scope, layoutName, ignoreLayoutId)
    local trimmedName = zo_strlower(zo_strtrim(layoutName))
    if trimmedName == "" then
        return false
    end
    local layoutList = GetLayoutListForScope(scope)
    for _, layoutData in ipairs(layoutList) do
        if layoutData.layoutId ~= ignoreLayoutId and zo_strlower(layoutData.name) == trimmedName then
            return false
        end
    end
    return true
end

local function AllocateLayoutId()
    local nextId = HT.SV.hudLayoutNextId
    HT.SV.hudLayoutNextId = nextId + 1
    return nextId
end

local function ReplaceElementMap(destinationMap, sourceMap)
    ZO_ClearTable(destinationMap)
    ZO_DeepTableCopy(sourceMap, destinationMap)
end

local function CoerceOptionValue(option, storedValue)
    if storedValue == nil then
        return ZO_Eval(option.defaultValue)
    end
    if option.type == ZO_HUD_EDITOR_OPTION_TYPES.BOOLEAN then
        return storedValue == true or storedValue == 1
    end
    if option.type == ZO_HUD_EDITOR_OPTION_TYPES.ENUM then
        return tonumber(storedValue) or storedValue
    end
    return storedValue
end

local function GetMultiSelectDefaultValue(option, subKey)
    local defaultValue = option.defaultValue
    if type(defaultValue) == "table" then
        return defaultValue[subKey]
    end
    return defaultValue
end

local function ApplyCustomOptionsForElement(element, savedRow)
    for _, option in ipairs(element:GetCustomOptions()) do
        if not option.dontSave then
            if option.type == ZO_HUD_EDITOR_OPTION_TYPES.MULTI_SELECT_DROPDOWN then
                local savedTable = savedRow and savedRow[option.key]
                for _, valueData in ipairs(option.values) do
                    local subKey = valueData.key
                    local newValue
                    if savedTable and savedTable[subKey] ~= nil then
                        newValue = savedTable[subKey] == true or savedTable[subKey] == 1
                    else
                        newValue = GetMultiSelectDefaultValue(option, subKey)
                    end
                    element:SetCustomOptionValue(option.key, subKey, newValue)
                end
            else
                local storedValue = savedRow and savedRow[option.key]
                element:SetCustomOptionValue(option.key, nil, CoerceOptionValue(option, storedValue))
            end
        end
    end
end

local function CountRegisteredMatches(iterator, elementMap)
    local refreshedCount = 0
    for _, element in iterator() do
        if elementMap[element:GetSaveKey()] then
            refreshedCount = refreshedCount + 1
        end
    end
    return refreshedCount
end

local function ApplyCustomOptionsForRegisteredElements(payload)
    for _, element in HUD_MANAGER:KeyboardElementIterator() do
        ApplyCustomOptionsForElement(element, payload.keyboardElements[element:GetSaveKey()])
    end
    for _, element in HUD_MANAGER:GamepadElementIterator() do
        ApplyCustomOptionsForElement(element, payload.gamepadElements[element:GetSaveKey()])
    end
end

function HT.ApplyHudLayoutPayload(payload, layoutName)
    local profile = GetLiveHudProfile()
    local payloadToApply = CopyPayload(payload)
    suppressOffsetsChangedRefresh = true
    HT.SV.elementAppearance = HT.CopyElementAppearance(payloadToApply.elementAppearance)
    HT.SV.resourceBarGroup = HT.CopyResourceBarGroup(payloadToApply.resourceBarGroup)

    -- Callbacks need the previous SavedVars values as oldValue. Apply options first,
    -- then replace the maps so omitted saveKeys (including unloaded addons) are cleared.
    ApplyCustomOptionsForRegisteredElements(payloadToApply)
    ReplaceElementMap(profile.keyboardElements, payloadToApply.keyboardElements)
    ReplaceElementMap(profile.gamepadElements, payloadToApply.gamepadElements)

    HUD_MANAGER:PropagateSettings()
    if HUD_EDITOR_KEYBOARD:IsShowing() then
        HUD_EDITOR_KEYBOARD:RebuildAllElements()
    end

    suppressOffsetsChangedRefresh = false
    SetLiveLayoutBaseline(payloadToApply)

    if HT.SV.showChatMessages then
        HT.AddChatSystemMessage(zo_strformat(
            GetString(SI_HUDITORTOOLS_LAYOUT_APPLY_RESULT),
            layoutName,
            NonContiguousCount(payloadToApply.keyboardElements),
            CountRegisteredMatches(function()
                return HUD_MANAGER:KeyboardElementIterator()
            end, payloadToApply.keyboardElements),
            NonContiguousCount(payloadToApply.gamepadElements),
            CountRegisteredMatches(function()
                return HUD_MANAGER:GamepadElementIterator()
            end, payloadToApply.gamepadElements)
        ))
    end
    return true
end

function HT.SetActiveLayout(scope, layoutId, skipApply)
    local layoutData = HT.FindLayout(scope, layoutId)
    local selection = HT.GetLayoutSelection()
    selection.scope = scope
    selection.layoutId = layoutId
    if skipApply then
        SetLiveLayoutBaseline(layoutData.payload)
    else
        HT.ApplyHudLayoutPayload(layoutData.payload, layoutData.name)
    end
    HT.RefreshLayoutInfoBoxSection()
    return true
end

function HT.SaveActiveLayout()
    local layoutData = HT.GetActiveLayout()
    layoutData.payload = HT.CollectLiveHudPayload()
    SetLiveLayoutBaseline(layoutData.payload)
    HT.RefreshLayoutInfoBoxSection()
    return true
end

function HT.CreateHudLayout(layoutName, scope, payload)
    local trimmedName = zo_strtrim(layoutName)
    if trimmedName == "" then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_EMPTY)
    end
    if not HT.CanCreateLayoutInScope(scope) then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_CAP)
    end
    if not HT.IsLayoutNameUnique(scope, trimmedName) then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_TAKEN)
    end
    local layoutData =
    {
        layoutId = AllocateLayoutId(),
        name = trimmedName,
        payload = CopyPayload(payload or HT.CollectLiveHudPayload()),
    }
    local layoutList = GetLayoutListForScope(scope)
    layoutList[#layoutList + 1] = layoutData
    return layoutData
end

function HT.RenameHudLayout(scope, layoutId, newName)
    local trimmedName = zo_strtrim(newName)
    if trimmedName == "" then
        return false, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_EMPTY)
    end
    if not HT.IsLayoutNameUnique(scope, trimmedName, layoutId) then
        return false, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_TAKEN)
    end
    local layoutData = HT.FindLayout(scope, layoutId)
    layoutData.name = trimmedName
    HT.RefreshLayoutInfoBoxSection()
    return true
end

local function GetFallbackLayout(excludeScope, excludeLayoutId)
    for _, layoutData in ipairs(HT.SV.hudLayoutsAccount) do
        if not (excludeScope == HT.LAYOUT_SCOPE_ACCOUNT and layoutData.layoutId == excludeLayoutId) then
            return HT.LAYOUT_SCOPE_ACCOUNT, layoutData
        end
    end
    for _, layoutData in ipairs(HT.GetCharacterLayoutList()) do
        if not (excludeScope == HT.LAYOUT_SCOPE_CHARACTER and layoutData.layoutId == excludeLayoutId) then
            return HT.LAYOUT_SCOPE_CHARACTER, layoutData
        end
    end
end

function HT.CountAllLayoutsForCharacter()
    return #HT.SV.hudLayoutsAccount + #HT.GetCharacterLayoutList()
end

function HT.DeleteHudLayout(scope, layoutId)
    if HT.CountAllLayoutsForCharacter() <= 1 then
        return false, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_LAST)
    end
    local layoutList = GetLayoutListForScope(scope)
    local removedLayout
    for index = #layoutList, 1, -1 do
        if layoutList[index].layoutId == layoutId then
            removedLayout = table.remove(layoutList, index)
            break
        end
    end
    if not removedLayout then
        return false, GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_MISSING)
    end

    local selection = HT.GetLayoutSelection()
    if selection.scope == scope and selection.layoutId == layoutId then
        local fallbackScope, fallbackLayout = GetFallbackLayout(scope, layoutId)
        HT.SetActiveLayout(fallbackScope, fallbackLayout.layoutId)
    else
        HT.RefreshLayoutInfoBoxSection()
    end
    return true
end

function HT.SwitchHudLayout(scope, layoutId)
    local layoutData = HT.FindLayout(scope, layoutId)
    local selection = HT.GetLayoutSelection()
    if selection.scope == scope and selection.layoutId == layoutId then
        return true
    end
    if HT.IsLiveLayoutDirty() then
        ZO_Dialogs_ShowDialog("HUDITORTOOLS_LAYOUT_UNSAVED_CONFIRMATION", {
            scope = scope,
            layoutId = layoutId,
        }, {
            mainTextParams = { layoutData.name },
        })
        HT.RefreshLayoutInfoBoxSection()
        return false
    end
    return HT.SetActiveLayout(scope, layoutId)
end

function HT.ConfirmSwitchHudLayout(scope, layoutId)
    return HT.SetActiveLayout(scope, layoutId)
end

function HT.CreateDefaultLayoutIfNeeded()
    local accountList = HT.SV.hudLayoutsAccount
    if #accountList == 0 and #HT.GetCharacterLayoutList() == 0 then
        local defaultLayout = HT.CreateHudLayout(GetString(SI_HUDITORTOOLS_LAYOUT_DEFAULT_NAME), HT.LAYOUT_SCOPE_ACCOUNT, HT.CollectLiveHudPayload())
        local SKIP_APPLY = true
        HT.SetActiveLayout(HT.LAYOUT_SCOPE_ACCOUNT, defaultLayout.layoutId, SKIP_APPLY)
        return
    end

    local selection = HT.GetLayoutSelection()
    local activeLayout = HT.FindLayout(selection.scope, selection.layoutId)
    if not activeLayout then
        local fallbackScope, fallbackLayout = GetFallbackLayout()
        local SKIP_APPLY = true
        HT.SetActiveLayout(fallbackScope, fallbackLayout.layoutId, SKIP_APPLY)
        return
    end
    SetLiveLayoutBaseline(activeLayout.payload)
end

local function ApplyCharacterLayoutOnActivation()
    local characterId = GetCurrentCharacterId()
    if lastCharacterIdAppliedThisSession == characterId then
        return
    end
    lastCharacterIdAppliedThisSession = characterId
    local selection = HT.GetLayoutSelection()
    if selection.scope ~= HT.LAYOUT_SCOPE_CHARACTER then
        return
    end
    local layoutData = HT.FindLayout(selection.scope, selection.layoutId)
    HT.ApplyHudLayoutPayload(layoutData.payload, layoutData.name)
end

function HT.InitializeHudLayouts()
    local function OnHudSavedVarsReady()
        HT.CreateDefaultLayoutIfNeeded()
        HT.RefreshLayoutInfoBoxSection()
    end

    -- HUD_MANAGER.savedVars is filled on EVENT_ADD_ONS_LOADED (hudmanager.lua).
    if HUD_MANAGER.savedVars then
        OnHudSavedVarsReady()
    else
        HUD_MANAGER:RegisterCallback("SavedVarsReady", OnHudSavedVarsReady)
    end

    HUD_MANAGER:RegisterCallback("OffsetsChanged", function()
        if suppressOffsetsChangedRefresh then
            return
        end
        HT.RefreshLayoutInfoBoxSection()
    end)

    EVENT_MANAGER:RegisterForEvent(HT.eventName .. "_Layouts", EVENT_PLAYER_ACTIVATED, ApplyCharacterLayoutOnActivation)
end

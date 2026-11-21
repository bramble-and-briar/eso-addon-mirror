-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.DialogueInjector = {}
local DialogueInjector = Addon.DialogueInjector

local LISTENER_NAME = "RPQuest_DialogueInjector"
local seenDialogues = {}

local function GetSeenDialogueKey(match)
    if not match then return nil end
    return tostring(match.questId or 0) .. ":" .. tostring(match.npcName or ""):lower()
end

local function ApplySeenOptionColor(interaction, controlID)
    local optionControl = interaction and interaction.optionControls and interaction.optionControls[controlID]
    if not optionControl then return end
    optionControl.chosenBefore = true
    if optionControl.SetColor then
        if GetInterfaceColor and INTERFACE_COLOR_TYPE_GENERAL and INTERFACE_GENERAL_COLOR_DISABLED then
            optionControl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_GENERAL, INTERFACE_GENERAL_COLOR_DISABLED))
        else
            optionControl:SetColor(0.5, 0.5, 0.5, 1)
        end
    end
end

local function GetCurrentPlayerZoneId()
    if GetUnitWorldPosition then
        local zoneId = GetUnitWorldPosition("player")
        if zoneId and zoneId > 0 then
            return zoneId
        end
    end
    if GetUnitZoneIndex and GetZoneId then
        local zoneIndex = GetUnitZoneIndex("player")
        if zoneIndex and zoneIndex > 0 then
            return GetZoneId(zoneIndex) or 0
        end
    end
    return 0
end

local function DisplayDialogueResponse(interaction, responseText)
    if not interaction then return end
    local text = (type(responseText) == "string" and responseText ~= "") and responseText or "..."
    if interaction.textControl and interaction.textControl.SetText then
        interaction.textControl:SetText(text)
    elseif interaction.control and interaction.control.GetNamedChild then
        local bodyLabel = interaction.control:GetNamedChild("TargetAreaBodyText")
        if bodyLabel and bodyLabel.SetText then
            bodyLabel:SetText(text)
        end
    end
end

local function HookInteractionClass(cls)
    if type(cls) ~= "table" or cls._rpquestHooked then
        return false
    end
    if type(cls.PopulateChatterOptions) ~= "function"
        or type(cls.PopulateChatterOption) ~= "function"
        or type(cls.FinalizeChatterOptions) ~= "function" then
        return false
    end

    cls._rpquestHooked = true
    local origPopulateOptions = cls.PopulateChatterOptions
    local origPopulateOption = cls.PopulateChatterOption
    local origFinalize = cls.FinalizeChatterOptions

    local state = {
        active = false,
        injected = false,
        offset = 0,
        match = nil,
    }

    cls.PopulateChatterOptions = function(interactionSelf, optionCount, backToTOCOption)
        local npcName = GetUnitName and GetUnitName("interact") or ""
        local zoneId = GetCurrentPlayerZoneId()
        local match = Addon.QuestRepository:FindDialogueForActiveQuest(npcName, zoneId)

        state.active = (match ~= nil)
        state.injected = false
        state.offset = 0
        state.match = match

        local finalCount, importantOptions = origPopulateOptions(interactionSelf, optionCount, backToTOCOption)
        local totalOffset = state.offset

        state.active = false
        state.match = nil

        return (finalCount or 0) + totalOffset, importantOptions
    end

    cls.PopulateChatterOption = function(
        interactionSelf,
        controlID,
        optionIndex,
        optionText,
        optionType,
        optionalArg,
        isImportant,
        chosenBefore,
        importantOptions,
        teleportNPCId,
        waypointIdTable,
        dialogueTone
    )
        local maxOptions = MAX_CHATTER_OPTIONS or 10
        if state.active and not state.injected and optionType == CHATTER_GOODBYE then
            state.injected = true
            if controlID and controlID < maxOptions then
                local match = state.match
                local injectedText = match.clue
                local responseText = match.response
                local seenKey = GetSeenDialogueKey(match)
                local wasChosenBefore = (seenKey and seenDialogues[seenKey]) == true
                local injectedControlID = controlID
                local callback = function()
                    if seenKey then
                        seenDialogues[seenKey] = true
                    end
                    DisplayDialogueResponse(interactionSelf, responseText)
                    ApplySeenOptionColor(interactionSelf, injectedControlID)
                end
                origPopulateOption(
                    interactionSelf,
                    injectedControlID,
                    callback,
                    injectedText,
                    CHATTER_TALK_CHOICE,
                    nil,
                    false,
                    wasChosenBefore,
                    importantOptions
                )
                state.offset = 1
            end
        end

        local targetID = (controlID or 1) + state.offset
        if targetID > maxOptions then
            return 0
        end

        return origPopulateOption(
            interactionSelf,
            targetID,
            optionIndex,
            optionText,
            optionType,
            optionalArg,
            isImportant,
            chosenBefore,
            importantOptions,
            teleportNPCId,
            waypointIdTable,
            dialogueTone
        )
    end

    cls.FinalizeChatterOptions = function(interactionSelf, optionCount)
        return origFinalize(interactionSelf, (optionCount or 0) + state.offset)
    end

    return true
end

function DialogueInjector:OnChatterBegin()
    if not GetUnitName then return nil end
    local npcName = GetUnitName("interact")
    if type(npcName) ~= "string" or npcName == "" then
        return nil
    end
    local zoneId = GetCurrentPlayerZoneId()
    return Addon.QuestRepository:SetLastInteractedNpc(npcName, zoneId)
end

function DialogueInjector:InstallHooks()
    HookInteractionClass(_G["ZO_Interaction"])
    HookInteractionClass(_G["ZO_GamepadInteraction"])
end

function DialogueInjector:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true

    self:InstallHooks()

    if EVENT_MANAGER and EVENT_CHATTER_BEGIN then
        EVENT_MANAGER:RegisterForEvent(LISTENER_NAME, EVENT_CHATTER_BEGIN, function()
            self:OnChatterBegin()
        end)
    end
end

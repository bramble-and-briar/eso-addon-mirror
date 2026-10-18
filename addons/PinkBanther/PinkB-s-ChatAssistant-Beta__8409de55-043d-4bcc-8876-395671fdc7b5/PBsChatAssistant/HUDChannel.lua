-- L2 is read, never bound. Only Right is temporarily reassigned while L2 is held on HUD.
-- The chord moves to the next chat tab; see CycleChatTab.
-- No HUD element of its own: the channel is reported to the chat log by CycleChannel.
local NAME = "PBsChatAssistantHUDChannel"
local LAYER = "PBsChatAssistantHUDChannelRightLayer"
local LEGACY_LAYER = "PBsChatAssistantHUDChannelLayer"
local MAX_PRESS_SECONDS = 5
local channel = { layerAdded = false, downs = 0, ups = 0, changes = 0 }
PBS_CHAT_ASSISTANT_HUD_CHANNEL = channel

local function GetChat()
    return type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
end

function channel:IsPlayerInCombat()
    -- EVENT_PLAYER_COMBAT_STATE is authoritative once received. Keep its value because the unit
    -- query can trail the event briefly; without the latch, the 10 ms update could put the Right
    -- action layer back during that gap. The live query remains a second guard if the event has
    -- not arrived yet.
    if self.inCombat == true then return true end
    return type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
end

function channel:IsAvailable()
    if self:IsPlayerInCombat() then return false end
    local addon = PBS_CHAT_ASSISTANT
    if not addon or not addon.sv or not addon.sv.enabled or not addon.sv.hudChannelEnabled then return false end
    if IsInGamepadPreferredMode and not IsInGamepadPreferredMode() then return false end
    if addon.sv.captureMode ~= "off" or not SCENE_MANAGER:IsShowing("hud") then return false end
    local chat = GetChat()
    if not chat or type(chat.IsTextEntryOpen) ~= "function" or chat:IsTextEntryOpen() then return false end
    return not (type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen())
end

function channel:ReadTrigger()
    local value
    if type(GetGamepadLeftTriggerMagnitude) == "function" then
        local ok, magnitude = pcall(GetGamepadLeftTriggerMagnitude)
        if ok and type(magnitude) == "number" and magnitude == magnitude and magnitude >= 0 and magnitude <= 1 then
            value = magnitude
        end
    end
    -- Match ScreenshotModeShortcut: standard L2 block is a read-only fallback.
    self.blocking = false
    if type(IsBlockActive) == "function" then
        local ok, active = pcall(IsBlockActive)
        self.blocking = ok and active == true
    end
    self.magnitude = value
    self.inputSource = self.blocking and "block" or (value and "analog" or "unavailable")
    return self.blocking and 1 or value
end

function channel:ClearPress()
    self.consumedRight = false
    self.rightDownAt = nil
end

function channel:SetLayer(wanted)
    if wanted == self.layerAdded then return end
    if wanted then
        self.layerAdded = true
        local ok, err = pcall(function() self.scene:AddFragment(self.fragment) end)
        if not ok then
            self.error = "layer: " .. tostring(err)
            self:SetLayer(false)
        end
    else
        self.layerAdded = false
        if self.fragment then self.scene:RemoveFragment(self.fragment) end
        if RemoveActionLayerByName then RemoveActionLayerByName(LAYER) end
    end
end

-- The on-screen label is gone; the chat line in CycleChannel says the channel now. What the label
-- also did was show that the feature had stopped, so that much is kept: an error is announced once,
-- when it latches, rather than leaving a silent failure.
function channel:AnnounceError()
    if not self.error or self.errorAnnounced then return end
    self.errorAnnounced = true
    d(string.format("|cFF69B4PB's ChatAssistant|r: channel switching stopped (%s) -- /pbchat hudstatus",
        tostring(self.error)))
end

function channel:Update()
    if not self.running then return end
    self:AnnounceError()
    local available = self:IsAvailable()
    if self.rightDownAt and GetGameTimeSeconds() - self.rightDownAt > MAX_PRESS_SECONDS then
        self:ClearPress()
    end
    if not available or (self.error and not self.consumedRight) then
        self:ClearPress()
        self.triggerHeld = false
        self:SetLayer(false)
    elseif self.error then
        -- A channel error must not expose the quest binding before Right Up.
        self:SetLayer(true)
    else
        local value = self:ReadTrigger()
        if value then
            if value >= 0.5 then self.triggerHeld = true
            elseif value <= 0.1 then self.triggerHeld = false end
        else
            self.triggerHeld = false
        end
        self:SetLayer(self.triggerHeld == true or self.consumedRight == true)
    end
end

-- Whether this Right came from an analogue stick rather than the D-pad.
--
-- UI_SHORTCUT_INPUT_RIGHT, the action the bind is inherited from, is the keybind strip's generic
-- "right" and is bound to the D-pad and to the sticks alike, and a binding handler is not told
-- which key fired it. So the press is judged by the sticks themselves: a stick only produces a
-- Right by being pushed well over, so one that is deflected sideways at the moment of the press
-- is the source. GetGamepadLeftStickX and GetGamepadRightStickX are what the client's own
-- directional input reads the sticks with.
--
-- The cost is that a D-pad press made while a stick is pushed sideways is ignored too; strafing
-- while blocking is the case where that happens.
local STICK_DEFLECTED = 0.3

local function StickX(reader)
    if type(reader) ~= "function" then return 0 end
    local ok, value = pcall(reader, true)
    if ok and type(value) == "number" and value == value then return value end
    return 0
end

function channel:IsStickRight()
    self.stickLeftX = StickX(GetGamepadLeftStickX)
    self.stickRightX = StickX(GetGamepadRightStickX)
    return math.abs(self.stickLeftX) >= STICK_DEFLECTED or math.abs(self.stickRightX) >= STICK_DEFLECTED
end

function channel:OnRightDown()
    self.downs = self.downs + 1
    if not self:IsAvailable() then
        self:ClearPress()
        self:SetLayer(false)
        return false
    end
    if self.consumedRight then return true end
    -- From a stick: not ours. Declined rather than consumed, so the stick keeps doing what it
    -- does, and nothing is latched for its Up to release.
    if self:IsStickRight() then
        self.stickRejects = (self.stickRejects or 0) + 1
        return false
    end
    -- A queued event after release or after opening a menu must not switch channels.
    if not self.running or not self.layerAdded or not self:IsAvailable() then return false end
    local value = self:ReadTrigger()
    if not value or value <= 0.1 then
        self.triggerHeld = false
        self:SetLayer(false)
        return false
    end
    self.consumedRight = true
    self.rightDownAt = GetGameTimeSeconds()
    local ok, err = pcall(function() PBS_CHAT_ASSISTANT:CycleChatTab(1) end)
    if not ok then
        self.error = "tab: " .. tostring(err)
    else
        self.changes = self.changes + 1
    end
    -- One channel change per physical press. Keep the quest block through Up.
    -- Right is deliberately repurposed while L2 is held; no input is synthesized.
    return true
end

function channel:OnRightUp()
    if self:IsPlayerInCombat() then
        self:ClearPress(); self:SetLayer(false); return false
    end
    self.ups = self.ups + 1
    local consumed = self.consumedRight == true
    self:ClearPress()
    -- Do not remove the layer inside Up; Update does so after dispatch completes.
    return consumed
end

function channel:PrintStatus()
    local actual = type(IsActionLayerActiveByName) == "function" and IsActionLayerActiveByName(LAYER)
    d(string.format("[PB HUD] running=%s scene=%s available=%s L2=%s source=%s attached=%s active=%s Right D/U=%d/%d changes=%d stick-rejects=%d (L %s R %s) error=%s",
        tostring(self.running), tostring(SCENE_MANAGER:GetCurrentSceneName()), tostring(self:IsAvailable()),
        tostring(self.magnitude), tostring(self.inputSource), tostring(self.layerAdded), tostring(actual), self.downs, self.ups,
        self.changes, self.stickRejects or 0, tostring(self.stickLeftX), tostring(self.stickRightX),
        tostring(self.error or "none")))
end

function channel:Start()
    -- Do not activate the layer used by the old L2+L3 implementation.
    -- The Right action now lives in a separate layer even if old action
    -- registrations survive an update in the client.
    if type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, LEGACY_LAYER)
    end
    if self.running then return end
    if not self.scene then
        self.scene = SCENE_MANAGER:GetScene("hud")
        self.fragment = ZO_ActionLayerFragment:New(LAYER)
        self.fragment:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_FRAGMENT_HIDDEN then
                self.triggerHeld = false
                self:ClearPress()
            end
        end)
    end
    self.error = nil
    self.errorAnnounced = false
    self.triggerHeld = false
    self.inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
    self.running = true
    self:Update()
    EVENT_MANAGER:RegisterForUpdate(NAME, 10, function() self:Update() end)
end

function channel:Stop()
    self:ClearPress()
    self.running = false
    self.triggerHeld = false
    EVENT_MANAGER:UnregisterForUpdate(NAME)
    self:SetLayer(false)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= "PBsChatAssistant" then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        channel.inCombat = inCombat == true
        if inCombat then
            channel:ClearPress()
            channel.triggerHeld = false
            channel:SetLayer(false)
        elseif channel.running then
            channel:Update()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() channel:Start() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() channel:Stop() end)
    if EVENT_CONTROLLER_DISCONNECTED then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CONTROLLER_DISCONNECTED, function() channel:Stop() end)
    end
    if EVENT_CONTROLLER_CONNECTED then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CONTROLLER_CONNECTED, function() channel:Start() end)
    end
end)

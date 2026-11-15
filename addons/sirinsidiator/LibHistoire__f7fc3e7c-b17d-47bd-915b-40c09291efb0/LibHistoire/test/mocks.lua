-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth or not Taneth.IsExternal() then return end

-- guild history category constants (values only need to be distinct)
GUILD_HISTORY_EVENT_CATEGORY_ACTIVITY = 1
GUILD_HISTORY_EVENT_CATEGORY_AVA_ACTIVITY = 2
GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY = 3
GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM = 4
GUILD_HISTORY_EVENT_CATEGORY_MILESTONE = 5
GUILD_HISTORY_EVENT_CATEGORY_ROSTER = 6
GUILD_HISTORY_EVENT_CATEGORY_TRADER = 7
GUILD_HISTORY_EVENT_CATEGORY_ITERATION_BEGIN = 1
GUILD_HISTORY_EVENT_CATEGORY_ITERATION_END = 7

-- milestone event type constants
GUILD_HISTORY_MILESTONE_EVENT_BANK_LOCKED = 1
GUILD_HISTORY_MILESTONE_EVENT_BANK_UNLOCKED = 2

function DecorateDisplayName(name) return name end
function GetKeepName(keepId) return "keep " .. tostring(keepId) end
function GetCampaignName(campaignId) return "campaign " .. tostring(campaignId) end

GUILD_HISTORY_MANAGER = ZO_CallbackObject:New()

function GetNumGuilds() return 0 end
function GetGuildId(index) return index end
function GetDisplayName() return "@player" end
function IsKeyboardUISupported() return false end

ZO_GuildHistory_Shared = {}
ESO_Dialogs.GAMEPAD_LOG_OUT = { buttons = { [1] = { text = "", callback = function() end } } }
SCENE_MANAGER = { GetScene = function() return {} end }

LibAddonMenu2 = {
    RegisterAddonPanel = function() return {} end,
    RegisterOptionControls = function() end,
    OpenToPanel = function() end,
}

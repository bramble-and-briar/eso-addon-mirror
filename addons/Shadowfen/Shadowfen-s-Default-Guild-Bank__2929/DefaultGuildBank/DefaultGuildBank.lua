--[[
Copyright (c) 2021 Dolores Scott
All rights reserved.
See LICENSE file for terms.
]]

local SF = LibSFUtils

local SGB = DefaultGuildBank

-------------------------------
-- saved variable defaults for both aw and toon
SGB.Defaults = {
	dgb_enabled = true,
}
-- saved variable tables
local toon = {}
local saved = {}

--[[ isValidGuildId

    Validates whether a guild ID is present among the player's active guilds.

    Checks the provided guild identifier against the list of guilds the
    local player currently belongs to, as reported by LibSFUtils. Returns
    a boolean indicating membership status, used throughout DefaultGuildBank
    to guard guild bank selection operations against invalid or stale IDs
    (e.g., from legacy saved variables or leaving a guild).

    This is an internal helper function called by SGB.onGuildBankSelected(),
    SGB.onCloseGuildBank(), SGB.enabled(), SGB.disabled(), and
    onPlayerActivated() before any guild bank selection is attempted.

    @param id number|nil
        Guild identifier to validate. Guild IDs in ESO are 1-based integers
        (1 through 5, maximum of 5 guild memberships). May be nil, in which
        case the lookup will not match and the function returns false.

    @return boolean
        true  if the provided id appears in the player's active guild list.
        false if the id is absent, nil, or the player has no guilds.
--]]
local function isValidGuildId(id)
	for i,v in ipairs(SF.GetActiveGuildIds()) do
		if v == id then
		    return true
		end
	end
	return false
end

local gbsession = false

--[[ SGB.onGuildBankSelected

    Intercepts guild bank selections and redirects them to the player's default guild bank.

    Responds to EVENT_GUILD_BANK_SELECTED, which fires whenever a guild bank
    becomes viewable. On the first selection within a guild bank session, this
    handler overrides whatever bank the game (or the player) opened and
    switches the view to the saved default guild bank, with a short delay
    to let the initial selection settle. Subsequent selections within the
    same session are ignored, preserving the player's freedom to browse
    other guild banks manually.

    Registered by SGB.enabled() and unregistered by SGB.disabled(). The
    session flag gbsession is reset when the guild bank closes (via
    SGB.onCloseGuildBank()), re-arming the auto-selection for the next
    bank opening.

    @param eventCode number
        ESO event code for EVENT_GUILD_BANK_SELECTED. Passed by the event
        system; value is unused by this handler.

    @param guildId number
        Identifier of the guild bank that was just selected/opened. Used
        only in the (currently unreachable — see @note) repeat-selection
        branch; otherwise the saved default takes precedence.

    @return nil
        No value is returned. Side effects are the guild bank selection
        change performed via ZO_SharedInventory_SelectAccessibleGuildBank()
        and the mutation of the session-local gbsession flag.
--]]
function SGB.onGuildBankSelected(_, guildId)
	local saved = SGB.saved
	if saved.dgb_enabled == false then return end
	if gbsession == true then return end
	--d("opening id 2: "..tostring(saved.defaultGuildId))

	local defaultGuildId
	if saved.defaultGuildId == nil then 
		defaultGuildId = GetGuildId(1)

	else
		defaultGuildId = saved.defaultGuildId
	end	

	local dGuildId
	gbsession = true
	dGuildId = defaultGuildId
	SGB.restoreLast(dGuildId)
	zo_callLater(function()
		ZO_SharedInventory_SelectAccessibleGuildBank(dGuildId)
	end, 100)
end

--[[ SGB.onCloseGuildBank

    Resets the guild bank session state when the guild bank window closes.

    Responds to EVENT_CLOSE_GUILD_BANK, which fires when the player closes
    any guild bank interface. The handler's primary role is to disarm the
    session flag (gbsession = false), re-arming the auto-selection logic
    for the next guild bank opening. Optionally, if the auto-redirect
    feature is enabled and a valid default guild bank exists, it also
    re-selects that default as the player's "last successful" choice.

    This function is the counterpart to SGB.onGuildBankSelected(), completing
    the session lifecycle: open → redirect once → browse freely → close →
    reset → repeat. Without this reset, the session flag would remain true
    indefinitely, blocking auto-redirect on all future openings.

    @return nil
        No value is returned. Side effects are the session flag reset and
        optional restoration of the default guild bank selection.
--]]
function SGB.onCloseGuildBank()
	local saved = SGB.saved
	gbsession = false
	if saved and saved.dgb_enabled == true and isValidGuildId(saved.defaultGuildId) == true then
		SGB.restoreLast(saved.defaultGuildId)
	end
end

--[[ SGB.isAccountWide

    Reports whether the addon is currently operating in account-wide or character-specific mode.

    Returns the account-wide flag from the toon-level saved variables table,
    indicating which saved variable schema is currently active for settings
    and preferences. This determines whether DefaultGuildBank settings apply
    to all characters on the account or only to the current character.

    The account-wide vs. character-specific distinction is managed through
    the LibSFUtils saved variable system, where `SGB.aw` holds account-wide
    data and `SGB.toon` holds character-specific data. This function queries
    the `accountWide` boolean flag within the toon schema to report the
    current operational mode.

    This function is called by the settings panel checkbox via LAM's
    getFunc callback, providing the current state for the "Account Wide"
    toggle displayed to users.

    @return boolean
        true  if the addon is configured to use account-wide saved variables
              (settings shared across all characters on the account).
        false if the addon is configured to use character-specific saved
              variables (settings isolated to the current character).
--]]
function SGB.isAccountWide()
	return SGB.toon.accountWide
end

--[[ SGB.setCurrentSV

    Switches between account-wide and character-specific saved variable schemas.

    Updates the active saved variable reference (SGB.saved) to point to either
    the account-wide schema (SGB.aw) or the character-specific schema (SGB.toon),
    based on the boolean value provided. This function is called by the settings
    panel checkbox when users toggle the "Account Wide" option, enabling
    per-character or account-wide configuration for guild bank preferences.

    This function pairs with SGB.isAccountWide() to form a bi-directional
    binding for the LAM settings checkbox, providing full read-write access
    to the account-wide mode configuration.

    @param newval boolean
        Desired operational mode:
        - true  : Switch to account-wide schema (SGB.aw)
        - false : Switch to character-specific schema (SGB.toon)

    @return nil
        No value is returned. The modification affects SGB.saved directly;
        callers do not need to capture a return value.
--]]
function SGB.setCurrentSV(newval)
    SGB.saved = SF.currentSavedVars(SGB.aw, SGB.toon, newval)
end

--[[ SGB.restoreLast

    Debounces guild bank selection to prevent rapid successive selection calls.

    Implements a debouncing mechanism using a pending flag to ensure only one
    guild bank selection can be in-flight at any time. When called with a guild
    bank ID, this function schedules a delayed selection via zo_callLater(),
    protecting against race conditions where the game's internal selection
    state might conflict with addon-initiated selections.

    This function is called by SGB.onGuildBankSelected() (on bank open) and
    SGB.onCloseGuildBank() (on bank close) to set the active guild bank. The
    10ms delay allows the game's own selection sequence to complete before
    the addon overrides it, while the pending flag prevents overlapping
    selections that could leave the UI in an inconsistent state.

    This is an internal helper function, not exposed as part of the public API.

    @param lastid number|nil
        Guild bank ID to select. Should be a valid guild identifier (1 through 5,
        representing the player's active guild slots). May be nil or invalid;
        if so, ZO_SharedInventory_SelectAccessibleGuildBank() will silently fail
        or use the game's default fallback behavior.

    @return nil
        No value is returned. The function performs a side-effecting selection
        operation via the ESO API, guarded by the debouncing flag.
--]]
local pending = false
function SGB.restoreLast(lastid)
    if pending == false then
		pending = true
		zo_callLater(function()
			ZO_SharedInventory_SelectAccessibleGuildBank(lastid)
			pending = false
		end, 10)
	end
end

local eventRegistered = false

--[[ SGB.enabled

    Registers event handlers for guild bank selection automation.

    Activates the addon's core functionality by subscribing to
    EVENT_GUILD_BANK_SELECTED and EVENT_CLOSE_GUILD_BANK. Upon enabling,
    it also performs an immediate selection to the saved default guild bank
    (if one exists and is valid), ensuring the player's preference takes
    effect even if no guild bank has been opened yet in the current session.

    This function pairs with SGB.disabled() to implement the toggle logic
    driven by the settings panel checkbox. The eventRegistered flag prevents
    duplicate handler registration on repeated enable calls, which could
    cause handlers to fire multiple times per event.

    Registered by onPlayerActivated() after saved variables initialization
    completes. Can also be called manually from the settings panel when the
    user enables the auto-redirect feature.

    @return nil
        No value is returned. Side effects are event handler registrations
        and an immediate restoration call to the saved default guild bank.
--]]
function SGB.enabled()
    if eventRegistered then return end
    eventRegistered = true

	local saved = SGB.saved
	if isValidGuildId(saved.defaultGuildId) == true then
		SGB.restoreLast(saved.defaultGuildId)
	end
    SGB.evtmgr:registerEvt(EVENT_GUILD_BANK_SELECTED, SGB.onGuildBankSelected)
    SGB.evtmgr:registerEvt(EVENT_CLOSE_GUILD_BANK, SGB.onCloseGuildBank)
end

--[[ SGB.disabled

    Deactivates guild bank selection automation by unregistering event handlers.

    Responds to user disabling the auto-redirect feature (via settings checkbox)
    or addon deactivation. Removes subscriptions to EVENT_GUILD_BANK_SELECTED
    and EVENT_CLOSE_GUILD_BANK, resets the event registration flag, and
    restores the player's guild bank selection to the pre-addon state.

    This function pairs with SGB.enabled() to form a complete enable/disable
    toggle cycle. Without calling disabled(), handlers would remain active
    even when the feature should be inactive, causing unwanted automation.

    @return nil
        No value is returned. Side effects are event handler unregistrations,
        flag reset, and restoration of the original guild bank selection.
--]]
function SGB.disabled()
    eventRegistered = false
    SGB.evtmgr:unregEvt(EVENT_GUILD_BANK_SELECTED)
    SGB.evtmgr:unregEvt(EVENT_CLOSE_GUILD_BANK)
	SGB.restoreLast(SGB.origLast)
end

--[[ onPlayerActivated

    Completes addon initialization after the player character has finished loading.

    Fires in response to EVENT_PLAYER_ACTIVATED and performs the second phase
    of addon initialization, following loadSV() during onAddonLoaded(). This
    function captures the player's original guild bank selection state, evaluates
    whether the auto-redirect feature should be activated, and triggers event
    handler registration through SGB.enabled().

    This is the bridge between the addon loading phase (where saved variables
    are populated) and full operational capability (where guild bank events
    are intercepted and redirected). It runs exactly once per session and
    unregisters itself to prevent duplicate execution on /reloadui.

    @param eventCode number
        ESO event code for EVENT_PLAYER_ACTIVATED. Passed by the event system;
        value is unused by this handler.

    @param init any
        Additional initialization parameter from ESO's event system. Value
        is unused by this handler and captured as an unnamed placeholder.

    @return nil
        No value is returned. The function performs initialization side effects
        including state capture, conditional activation, and event registration.
--]]
local function onPlayerActivated(ev, init)

	SGB.origLast = PLAYER_INVENTORY.lastSuccessfulGuildBankId
	if isValidGuildId(SGB.origLast) == false then
		SGB.origLast = SF.GetActiveGuildIds()[1]
	end
	local saved = SGB.saved

	if saved.dgb_enabled == true and isValidGuildId(saved.defaultGuildId) == true then
		SGB.restoreLast(saved.defaultGuildId)

	else
		SGB.restoreLast(SGB.origLast)
	end
	SGB.enabled()
end

--[[ onAddonLoaded

    Entry point for DefaultGuildBank addon initialization triggered by ESO's addon load system.

    Responds to EVENT_ADD_ON_LOADED and performs the first phase of addon
    initialization by loading saved variables, initializing the settings
    panel, and registering the player activation handler. This function
    serves as the gateway between the ESO addon loader and the addon's
    operational logic.

    This function executes before the player character is fully initialized,
    so it focuses on preparing data structures and event subscriptions while
    deferring player-dependent operations (guild bank state capture, handler
    registration) to onPlayerActivated().

    @param eventCode number
        ESO event code for EVENT_ADD_ON_LOADED. Passed by the event system;
        value is unused by this handler.

    @param addonName string
        Name of the addon that finished loading. Used to verify this handler
        was triggered for DefaultGuildBank specifically (prevents execution for
        other addons' load events).

    @return nil
        No value is returned. The function performs initialization side effects
        including saved variable loading, settings registration, and event
        handler subscription.
--]]
local function onAddonLoaded(ev, addonName)
	if addonName ~= SGB.name then return end

	-- make sure we are only called once
	SGB.evtmgr:unregEvt(EVENT_ADD_ON_LOADED)

	-- manage saved variables
    SGB.aw, SGB.toon = SF.getAllSavedVars("DefaultGuildBankVars", 1, SGB.Defaults)
    toon = SGB.toon

	SGB.setCurrentSV()

	-- settings page
	SGB.RegisterSettings()

	SGB.evtmgr:registerEvt(EVENT_PLAYER_ACTIVATED, 	onPlayerActivated)
end

do
	-- register our event handler function to be called to do initialization
	SGB.evtmgr:registerEvt(EVENT_ADD_ON_LOADED, 	onAddonLoaded)
end

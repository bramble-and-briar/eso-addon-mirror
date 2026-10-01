--this is AutoNomNom_UnitTests.lua
-- AutoNomNom Timing Tests
-- These tests validate AutoNomNom.CheckFoodStores_GetSendLevel()
------------------------------------------------------------
-- TEST DEFINITIONS
------------------------------------------------------------
AutoNomNom = AutoNomNom or {}
local nn = AutoNomNom
nn.UnitTests = nn.UnitTests or {}

local function SetupUrgent_BuffExpired_TooSoon()
	return {
		description = "Urgent + buff expired + too soon",
		expected = "none",
		importance = "urgent",
		messageText = "test",
		buffActive = false,
		remainingBuffTime = 0,
		lastMessageText = "test",  -- simulate repeated message
		lastMessageTime = GetFrameTimeSeconds(), -- just sent
		}
end

local function SetupUrgent_BuffExpired_TooSoon_NewMessage()
    return {
        description = "Urgent + buff expired + too soon + new message",
        expected = "urgent",
        importance = "urgent",
        messageText = "test",
        buffActive = false,          -- irrelevant for new-message rule
        remainingBuffTime = 0,       -- irrelevant for new-message rule
        lastMessageText = nil,     -- DIFFERENT → new message
        lastMessageTime = GetFrameTimeSeconds(), -- irrelevant for new-message rule
    }
end

local function SetupUrgent_BuffExpired_EnoughTime()
    AutoNomNom._test_messageImportance = "urgent"
    AutoNomNom._test_messageText = "test"
    AutoNomNom.State.buffActive = false
    AutoNomNom.State.remainingBuffTime = 0
    lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds
end

local function SetupUrgent_BuffLessThan5Min_TooSoon()
    AutoNomNom._test_messageImportance = "urgent"
    AutoNomNom._test_messageText = "test"
    AutoNomNom.State.buffActive = true
    AutoNomNom.State.remainingBuffTime = 299
    lastMessageTime = GetFrameTimeSeconds()  -- just sent
end

local function SetupUrgent_BuffLessThan5Min_EnoughTime()
    AutoNomNom._test_messageImportance = "urgent"
    AutoNomNom._test_messageText = "test"
    AutoNomNom.State.buffActive = true
    AutoNomNom.State.remainingBuffTime = 299
    lastMessageTime = GetFrameTimeSeconds() - 60
end

local function SetupUrgent_BuffMoreThan5Min_TooSoon()
    AutoNomNom._test_messageImportance = "urgent"
    AutoNomNom._test_messageText = "test"
    AutoNomNom.State.buffActive = true
    AutoNomNom.State.remainingBuffTime = 590
    lastMessageTime = GetFrameTimeSeconds()
end

local function SetupUrgent_BuffExpired_EnoughTime()
    return {
        description = "Urgent + buff expired + enough time",
        expected = "urgent",
        importance = "urgent",
        messageText = "test",
        buffActive = false,
        remainingBuffTime = 0,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds,
    }
end

local function SetupUrgent_BuffLessThan5Min_TooSoon()
    return {
        description = "Urgent + buff <5min + too soon",
        expected = "none",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 299,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupUrgent_BuffLessThan5Min_EnoughTime()
    return {
        description = "Urgent + buff <5min + enough time",
        expected = "urgent",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 299,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - 60,
    }
end

local function SetupUrgent_BuffMoreThan5Min_TooSoon()
    return {
        description = "Urgent + buff >5min + too soon",
        expected = "none",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 590,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupUrgent_BuffMoreThan5Min_EnoughTime()
    return {
        description = "Urgent + buff >5min + enough time",
        expected = "urgent",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 590,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - 60,
    }
end

local function SetupUrgent_BuffMoreThan10Min_TooSoon()
    return {
        description = "Urgent + buff >10min + too soon",
        expected = "none",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 1200,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupUrgent_BuffMoreThan10Min_EnoughTime()
    return {
        description = "Urgent + buff >10min + enough time",
        expected = "urgent",
        importance = "urgent",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 1200,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds,
    }
end

------------------------------------------------------------
-- NORMAL MESSAGE TESTS
------------------------------------------------------------

local function SetupNormal_BuffExpired_TooSoon()
    return {
        description = "Normal + buff expired + too soon",
        expected = "none",
        importance = "normal",
        messageText = "test",
        buffActive = false,
        remainingBuffTime = 0,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupNormal_BuffExpired_EnoughTime()
    return {
        description = "Normal + buff expired + enough time",
        expected = "normal",
        importance = "normal",
        messageText = "test",
        buffActive = false,
        remainingBuffTime = 0,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds,
    }
end

local function SetupNormal_BuffLessThan5Min_TooSoon()
    return {
        description = "Normal + buff <5min + too soon",
        expected = "none",
        importance = "normal",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 299,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupNormal_BuffLessThan5Min_EnoughTime()
    return {
        description = "Normal + buff <5min + enough time",
        expected = "normal",
        importance = "normal",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 299,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds,
    }
end

local function SetupNormal_BuffMoreThan10Min_TooSoon()
    return {
        description = "Normal + buff >10min + too soon",
        expected = "none",
        importance = "normal",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 1200,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

local function SetupNormal_BuffMoreThan10Min_EnoughTime()
    return {
        description = "Normal + buff >10min + enough time",
        expected = "normal",
        importance = "normal",
        messageText = "test",
        buffActive = true,
        remainingBuffTime = 1200,
        lastMessageText = "test",
        lastMessageTime = GetFrameTimeSeconds() - AutoNomNom.accountWide.autoEatFailureWarningIntervalSeconds,
    }
end

local function SetupNormal_NewMessage()
    return {
        description = "Normal + new message → should send immediately",
        expected = "normal",
        importance = "normal",
        messageText = "test",
        buffActive = false,
        remainingBuffTime = 0,
        lastMessageText = nil,
        lastMessageTime = GetFrameTimeSeconds(),
    }
end

------------------------------------------------------------
-- RUN ALL TESTS
------------------------------------------------------------

function nn.UnitTests.TimingTests()
    d("---- AutoNomNom Timing Tests ----")		
    nn.RunTimingTest(SetupUrgent_BuffExpired_TooSoon())
	nn.RunTimingTest(SetupUrgent_BuffExpired_TooSoon_NewMessage())
	
	nn.RunTimingTest(SetupUrgent_BuffExpired_TooSoon())
	nn.RunTimingTest(SetupUrgent_BuffExpired_TooSoon_NewMessage())
	nn.RunTimingTest(SetupUrgent_BuffExpired_EnoughTime())
	nn.RunTimingTest(SetupUrgent_BuffLessThan5Min_TooSoon())
	nn.RunTimingTest(SetupUrgent_BuffLessThan5Min_EnoughTime())
	nn.RunTimingTest(SetupUrgent_BuffMoreThan5Min_TooSoon())
	nn.RunTimingTest(SetupUrgent_BuffMoreThan5Min_EnoughTime())
	nn.RunTimingTest(SetupUrgent_BuffMoreThan10Min_TooSoon())
	nn.RunTimingTest(SetupUrgent_BuffMoreThan10Min_EnoughTime())

	nn.RunTimingTest(SetupNormal_BuffExpired_TooSoon())
	nn.RunTimingTest(SetupNormal_BuffExpired_EnoughTime())
	nn.RunTimingTest(SetupNormal_BuffLessThan5Min_TooSoon())
	nn.RunTimingTest(SetupNormal_BuffLessThan5Min_EnoughTime())
	nn.RunTimingTest(SetupNormal_BuffMoreThan10Min_TooSoon())
	nn.RunTimingTest(SetupNormal_BuffMoreThan10Min_EnoughTime())
	nn.RunTimingTest(SetupNormal_NewMessage())
    d("---- Tests Complete ----")
end
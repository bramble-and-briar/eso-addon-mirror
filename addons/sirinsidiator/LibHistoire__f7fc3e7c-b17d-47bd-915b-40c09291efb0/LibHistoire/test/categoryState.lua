-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
local internal = LibHistoire.internal

local real = getfenv(0)

Taneth("LibHistoire", function()
    describe("category state callbacks", function()
        local NO_PROCESSOR_THRESHOLD = 3 * 24 * 3600
        local GUILD_ID = -1

        local cache
        local stubs
        local callbackSpy
        local eventIndex
        local gaplessIndex

        local function CountCalls()
            local count = 0
            for i = 1, callbackSpy.called do
                if callbackSpy.args[i][3] == GUILD_ID then
                    count = count + 1
                end
            end
            return count
        end

        local function InstallCallbackSpy()
            callbackSpy = spy.on(internal.callbackObject, "FireCallbacks")
            callbackSpy:invokes(function(_, name, arg1, ...)
                if arg1 == GUILD_ID or arg1 == cache or (type(arg1) == "table" and arg1.cache == cache) then return end
                return callbackSpy.original(internal.callbackObject, name, arg1, ...)
            end)
        end

        local function InstallGuildSpy(key, testValue)
            local guildSpy = spy.on(real, key)
            guildSpy:invokes(function(guildId, ...)
                if guildId ~= GUILD_ID then
                    if not guildSpy.original then return end
                    return guildSpy.original(guildId, ...)
                end
                return testValue()
            end)
            return guildSpy
        end

        local function NewFakeRequest()
            return {
                StartProcessing = function() end,
                StopProcessing = function() end,
            }
        end

        local function NewFakeProcessor()
            return {
                StopInternal = function() end,
            }
        end

        setup(function()
            eventIndex = 1
            gaplessIndex = 1
            InstallCallbackSpy()
            stubs = {
                InstallGuildSpy("GetOldestGuildHistoryEventIndexForUpToDateEventsWithoutGaps",
                    function() return gaplessIndex end),
                InstallGuildSpy("GetNumGuildHistoryEvents", function() return 1 end),
                InstallGuildSpy("GetGuildHistoryEventIndex", function() return eventIndex end),
                callbackSpy,
            }

            local adapter = {
                store = {},
                GetOrCreateCacheSaveData = function(self, key)
                    self.store[key] = self.store[key] or {}
                    return self.store[key]
                end,
            }
            local guildData = { GetId = function() return GUILD_ID end }
            local categoryData = {
                GetGuildData = function() return guildData end,
                GetEventCategory = function() return GUILD_HISTORY_EVENT_CATEGORY_TRADER end,
            }
            cache = internal.class.GuildHistoryCacheCategory:New(adapter, nil, categoryData)
            cache.OnCategoryUpdated = function() end
        end)

        before_each(function()
            eventIndex = 1
            gaplessIndex = 1
            cache:Reset()
            cache.saveData.lastProcessorRegisteredTime = GetTimeStamp()
            cache:CheckState()
            callbackSpy:clear()
        end)

        teardown(function()
            for i = 1, #stubs do
                stubs[i]:revert()
            end
        end)

        it("does not fire any callbacks on construction", function()
            assert.equals(0, CountCalls())
        end)

        it("fires CATEGORY_PROCESSING_CHANGED when processing starts and stops", function()
            local request = NewFakeRequest()
            cache:QueueProcessingRequest(request)
            cache:ProcessNextRequest()

            assert.equals(1, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_PROCESSING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, true)

            cache:RemoveProcessingRequest(request)

            assert.equals(2, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_PROCESSING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, false)
        end)

        it("fires CATEGORY_AUTO_REQUESTING_CHANGED when the request mode changes", function()
            cache:SetRequestMode(internal.REQUEST_MODE_OFF)
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_AUTO_REQUESTING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, false)

            cache:SetRequestMode(internal.REQUEST_MODE_ON)
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_AUTO_REQUESTING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, true)

            assert.equals(4, CountCalls())
        end)

        it("fires CATEGORY_AUTO_REQUESTING_CHANGED when the no-processor threshold passes", function()
            cache.saveData.requestMode = internal.REQUEST_MODE_AUTO
            cache.saveData.lastProcessorRegisteredTime = GetTimeStamp() - NO_PROCESSOR_THRESHOLD - 1
            cache:CheckState()

            assert.equals(1, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_AUTO_REQUESTING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, false)

            cache:RegisterProcessor(NewFakeProcessor())

            assert.equals(2, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject,
                internal.callback.CATEGORY_AUTO_REQUESTING_CHANGED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER, true)
        end)

        it("fires CATEGORY_LINKED when the gap between the managed and gapless ranges closes", function()
            cache:SetNewestManagedEventInfo(100, 500)
            eventIndex = 1
            cache:CheckState()

            assert.equals(1, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject, internal.callback.CATEGORY_LINKED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER)

            eventIndex = 2
            cache:CheckState()

            assert.equals(1, CountCalls())
        end)

        it("fires CATEGORY_RESET when the cache is reset", function()
            cache:SetNewestManagedEventInfo(100, 500)
            eventIndex = 1
            cache:CheckState()

            assert.equals(1, CountCalls())

            cache:Reset()

            assert.equals(2, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject, internal.callback.CATEGORY_RESET, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER)

            cache:SetNewestManagedEventInfo(100, 500)
            cache:CheckState()

            assert.equals(3, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject, internal.callback.CATEGORY_LINKED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER)
        end)

        it("keeps the linked state when a new event shifts the gapless and managed ranges together", function()
            cache:SetNewestManagedEventInfo(100, 500)
            eventIndex = 1
            gaplessIndex = 1
            cache:CheckState()

            assert.equals(1, CountCalls())
            assert.stub(callbackSpy).was_called_with(internal.callbackObject, internal.callback.CATEGORY_LINKED, GUILD_ID,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER)

            eventIndex = 2
            gaplessIndex = 2
            cache:CheckState()

            assert.equals(1, CountCalls())
        end)

        it("does not repeat callbacks when the state is unchanged", function()
            cache:SetRequestMode(internal.REQUEST_MODE_ON)
            callbackSpy:clear()

            cache:CheckState()
            cache:CheckState()
            cache:CheckState()

            assert.equals(0, CountCalls())
        end)
    end)
end)

-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
local internal = LibHistoire.internal

Taneth("LibHistoire", function()
    describe("GuildHistoryProcessingRequest", function()
        local taskName
        local probeName

        local function NewFakeEvent(id, time)
            return {
                GetEventId = function() return id end,
                GetEventTimestampS = function() return time end,
            }
        end

        local function NewFakeCategoryCache(state)
            local cache = {}
            local function FindIndexForEventId(eventId)
                for i, event in ipairs(state.events) do
                    if event:GetEventId() == eventId then return i end
                end
            end
            function cache:GetKey() return state.key end
            function cache:GetOldestManagedEventInfo() return state.oldestManagedEventId, state.oldestManagedEventTime end
            function cache:GetNewestManagedEventInfo() return state.newestManagedEventId, state.newestManagedEventTime end
            function cache:GetIndexRangeForEventIdRange(startId, endId)
                local override = state.indexRangeOverride
                if override then
                    state.indexRangeOverride = nil
                    return override[1], override[2]
                end
                return FindIndexForEventId(startId), FindIndexForEventId(endId)
            end
            function cache:FindFirstAvailableEventIdForEventId(eventId)
                state.findFirstCalls = state.findFirstCalls + 1
                return state.findFirstResult
            end
            function cache:FindLastAvailableEventIdForEventId(eventId)
                state.findLastCalls = state.findLastCalls + 1
                return state.findLastResult
            end
            function cache:GetEvent(index)
                local event = state.events[index]
                if state.onEventAccess then state.onEventAccess() end
                return event
            end
            return cache
        end

        local function NewFakeProcessor(cache, currentEventId)
            return {
                running = true,
                currentEventId = currentEventId,
                afterEventId = nil,
                afterEventTime = nil,
                beforeEventId = nil,
                beforeEventTime = nil,
                categoryCache = cache,
                IsRunning = function(self) return self.running end,
                GetKey = function(self) return self.categoryCache:GetKey() end,
            }
        end

        local function NewEventCollector(processor, processedEventIds)
            return function(_, event)
                local eventId = event:GetEventId()
                if not processor.currentEventId or eventId > processor.currentEventId then
                    processor.currentEventId = eventId
                    processedEventIds[#processedEventIds + 1] = eventId
                end
            end
        end

        local function NewState(events)
            return {
                key = "test/request",
                events = events,
                findFirstCalls = 0,
                findLastCalls = 0,
            }
        end

        local function NewRequest(state, processor, onEvent, onCompleted)
            return internal.class.GuildHistoryProcessingRequest:New(processor, onEvent, onCompleted)
        end

        local function RunRequest(done, request, onError)
            local completed = false
            local origOnCompleted = request.onCompleted
            request.onCompleted = function(processor)
                completed = true
                return origOnCompleted(processor)
            end

            request:StartProcessing()
            local task = request.task
            if task then
                taskName = task.name
                if onError then
                    task:OnError(apply_test_env(function() onError() end))
                end
            end

            if not request.task then
                done()
                return
            end

            probeName = "RequestCompletionProbe"
            EVENT_MANAGER:RegisterForUpdate(probeName, 0, function()
                if request.task then return end
                if completed then
                    EVENT_MANAGER:UnregisterForUpdate(probeName)
                    probeName = nil
                    done()
                end
            end)
        end

        teardown(function()
            if probeName then
                EVENT_MANAGER:UnregisterForUpdate(probeName)
                probeName = nil
            end
            if taskName and LibAsync.jobs[taskName] then
                LibAsync.jobs[taskName]:Cancel()
                LibAsync.jobs[taskName] = nil
            end
            taskName = nil
        end)

        describe("StartProcessing", function()
            it.async("iterates all events in the managed range newest first and completes", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 200, 250, 300 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request)
            end)

            it.async("continues from the processor's currentEventId", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 250)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 300 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request)
            end)

            it.async("skips events outside the startId..endId range", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                state.indexRangeOverride = { 3, 1 }
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 250)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 300 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request)
            end)

            it.async("stops at the beforeEventId bound", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 200)
                processor.beforeEventId = 250
                state.findLastResult = 250
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 250 }, processedEventIds)
                    assert.equals(1, completed)
                    assert.equals(2, state.findLastCalls)
                    done()
                end, request)
            end)

            it("completes immediately when no events are cached", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)

                assert.has_no_error(function() request:StartProcessing() end)
                assert.equals(1, completed)
            end)

            it("completes immediately when the start bound is newer than the end bound", function()
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 300, 3000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                processor.beforeEventId = 250
                state.findLastResult = 250
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)

                assert.has_no_error(function() request:StartProcessing() end)
                assert.equals(1, completed)
            end)

            it("completes immediately when the start event is no longer cached and none is available", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 999)
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)

                assert.has_no_error(function() request:StartProcessing() end)
                assert.equals(1, completed)
            end)

            it("completes immediately when the end event is no longer cached", function()
                local state = NewState({ NewFakeEvent(200, 2000) })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 999, 9990
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)

                assert.has_no_error(function() request:StartProcessing() end)
                assert.equals(1, completed)
            end)

            it("completes immediately when the re-derived start event is not cached either", function()
                local state = NewState({
                    NewFakeEvent(300, 3000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 250, 2500
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 100)
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)

                assert.has_no_error(function() request:StartProcessing() end)
                assert.equals(1, completed)
                assert.is_nil(request.task)
            end)

            it("stops a previous task when restarted", function()
                local state = NewState({ NewFakeEvent(300, 3000) })
                state.oldestManagedEventId, state.oldestManagedEventTime = 300, 3000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request = NewRequest(state, processor, function() end, function() end)

                local oldTask = internal:CreateAsyncTask()
                oldTask:Call(function() end)
                request.task = oldTask
                request:StartProcessing()
                assert.equals(0, #oldTask.callstack)
                assert.equals(0, oldTask.lastCallIndex)
                assert.is_nil(LibAsync.jobs[oldTask.name])
            end)

            it("asserts when the processor is not running", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                processor.running = false
                local request = NewRequest(state, processor, function() end, function() end)

                assert.has_error("Processor test/request should be running (-)", function()
                    request:StartProcessing()
                end)
            end)
        end)

        describe("StopProcessing", function()
            it.async("cancels the task and clears the index range", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request
                local stoppedDuringIteration = false
                request = NewRequest(state, processor,
                    function(_, event)
                        if event:GetEventId() == 250 then
                            request:StopProcessing()
                            stoppedDuringIteration = true
                        end
                    end,
                    function() end)

                request:StartProcessing()
                taskName = request.task.name
                request.task:Finally(function()
                    assert.is_true(stoppedDuringIteration)
                    assert.is_nil(request.task)
                    assert.is_nil(request.currentIndex)
                    assert.is_nil(request.endIndex)
                    done()
                end)
            end)

            it("does nothing when no task is active", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request = NewRequest(state, processor, function() end, function() end)

                assert.has_no_error(function() request:StopProcessing() end)
            end)
        end)

        describe("FindStartId", function()
            local function NewRequestWithState(state)
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                return NewRequest(state, processor, function() end, function() end), processor
            end

            it("uses the first available event for afterEventId", function()
                local state = NewState({})
                local request, processor = NewRequestWithState(state)
                processor.afterEventId = 150
                state.findFirstResult = 200

                assert.equals(200, request:FindStartId())
                assert.equals(1, state.findFirstCalls)
            end)

            it("falls back to the oldest managed event when afterEventId has no match", function()
                local state = NewState({})
                local request, processor = NewRequestWithState(state)
                processor.afterEventId = 150
                state.findFirstResult = nil
                state.oldestManagedEventId, state.oldestManagedEventTime = 100, 1000

                assert.equals(100, request:FindStartId())
            end)

            it("uses the oldest managed event when no start bound is set", function()
                local state = NewState({})
                local request = NewRequestWithState(state)
                state.oldestManagedEventId, state.oldestManagedEventTime = 100, 1000

                assert.equals(100, request:FindStartId())
                assert.equals(0, state.findFirstCalls)
            end)

            it("returns nil when no events are cached", function()
                local state = NewState({})
                local request = NewRequestWithState(state)

                assert.is_nil(request:FindStartId())
            end)
        end)

        describe("FindEndId", function()
            local function NewRequestWithState(state)
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                return NewRequest(state, processor, function() end, function() end), processor
            end

            it("uses the last available event for beforeEventId", function()
                local state = NewState({})
                local request, processor = NewRequestWithState(state)
                processor.beforeEventId = 350
                state.findLastResult = 300

                assert.equals(300, request:FindEndId())
                assert.equals(1, state.findLastCalls)
            end)

            it("falls back to the newest managed event when beforeEventId has no match", function()
                local state = NewState({})
                local request, processor = NewRequestWithState(state)
                processor.beforeEventId = 350
                state.findLastResult = nil
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000

                assert.equals(300, request:FindEndId())
            end)

            it("uses the newest managed event when no end bound is set", function()
                local state = NewState({})
                local request = NewRequestWithState(state)
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000

                assert.equals(300, request:FindEndId())
                assert.equals(0, state.findLastCalls)
            end)

            it("returns nil when no events are cached", function()
                local state = NewState({})
                local request = NewRequestWithState(state)

                assert.is_nil(request:FindEndId())
            end)
        end)

        describe("EnsureIterationIsComplete", function()
            local function NewPreparedRequest(currentEventId, newestManagedEventId)
                local state = NewState({})
                state.newestManagedEventId, state.newestManagedEventTime = newestManagedEventId, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, currentEventId)
                local completed = 0
                local request = NewRequest(state, processor, function() end,
                    function() completed = completed + 1 end)
                return request, function() return completed end
            end

            it("completes when the processor has no current event", function()
                local request, getCompleted = NewPreparedRequest(nil, 300)
                request:EnsureIterationIsComplete(false)
                assert.equals(1, getCompleted())
            end)

            it("completes when the processor reached the end id", function()
                local request, getCompleted = NewPreparedRequest(300, 300)
                request:EnsureIterationIsComplete(false)
                assert.equals(1, getCompleted())
            end)

            it("starts another round when events were processed before reaching the end", function()
                local request = NewPreparedRequest(250, 300)
                local startStub = stub.on(request, "StartProcessing")

                request:EnsureIterationIsComplete(true)
                assert.stub(startStub).was.called_with(request, 300)
            end)

            it("errors when no events were processed and the end moved out of reach", function()
                local request = NewPreparedRequest(350, 300)
                assert.has_error("no events processed and not at the end - something went wrong", function()
                    request:EnsureIterationIsComplete(false)
                end)
            end)
        end)

        describe("GetPendingEventMetrics", function()
            it("returns idle metrics when no task is active", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request = NewRequest(state, processor, function() end, function() end)

                local count, speed, timeLeft = request:GetPendingEventMetrics()
                assert.same({ 0, -1, -1 }, { count, speed, timeLeft })
            end)

            it.async("reports the remaining event count during iteration", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request
                local remainingCount
                request = NewRequest(state, processor,
                    function()
                        remainingCount = remainingCount or request:GetPendingEventMetrics()
                    end,
                    function() end)

                RunRequest(function()
                    -- captured at the oldest event (index 3): 3 - 1 events left
                    assert.equals(2, remainingCount)
                    done()
                end, request)
            end)
        end)

        describe("GetDebugInfo", function()
            it("reports no async task when idle", function()
                local state = NewState({})
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request = NewRequest(state, processor, function() end, function() end)

                local debugInfo = request:GetDebugInfo()
                assert.is_false(debugInfo.hasAsyncTask)
                assert.is_nil(debugInfo.currentEvent)
                assert.is_nil(debugInfo.endEvent)
            end)

            it.async("reports the current and end event during iteration", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                    NewFakeEvent(200, 2000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 200, 2000
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, nil)
                local request
                local debugInfoDuringIteration
                request = NewRequest(state, processor,
                    function()
                        debugInfoDuringIteration = debugInfoDuringIteration or request:GetDebugInfo()
                    end,
                    function() end)

                RunRequest(function()
                    assert.is_true(debugInfoDuringIteration.hasAsyncTask)
                    assert.same({ id = 200, time = 2000, index = 3 }, debugInfoDuringIteration.currentEvent)
                    assert.same({ id = 300, time = 3000, index = 1 }, debugInfoDuringIteration.endEvent)
                    done()
                end, request)
            end)
        end)

        describe("managed range changes mid-iteration", function()
            it.async("completes when the processor reaches the end of the managed range", function(done)
                local state = NewState({
                    NewFakeEvent(200, 2000),
                    NewFakeEvent(150, 1500),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 150, 1500
                state.newestManagedEventId, state.newestManagedEventTime = 200, 2000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 150)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 200 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request)
            end)

            it.async("restarts against the new range when the start event is no longer cached", function(done)
                local state = NewState({
                    NewFakeEvent(300, 3000),
                    NewFakeEvent(250, 2500),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 250, 2500
                state.newestManagedEventId, state.newestManagedEventTime = 300, 3000
                local cache = NewFakeCategoryCache(state)
                local processor = NewFakeProcessor(cache, 100)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 250, 300 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request)
            end)

            it.async("continues when the managed range extends mid-iteration", function(done)
                local state = NewState({
                    NewFakeEvent(200, 2000),
                    NewFakeEvent(150, 1500),
                    NewFakeEvent(100, 1000),
                })
                state.oldestManagedEventId, state.oldestManagedEventTime = 100, 1000
                state.newestManagedEventId, state.newestManagedEventTime = 150, 1500
                state.indexRangeOverride = { 1, 1 }
                local cache = NewFakeCategoryCache(state)
                state.onEventAccess = function()
                    state.newestManagedEventId, state.newestManagedEventTime = 200, 2000
                    state.onEventAccess = nil
                end

                local processor = NewFakeProcessor(cache, 150)
                local processedEventIds = {}
                local completed = 0
                local request = NewRequest(state, processor,
                    NewEventCollector(processor, processedEventIds),
                    function() completed = completed + 1 end)

                RunRequest(function()
                    assert.same({ 200 }, processedEventIds)
                    assert.equals(1, completed)
                    done()
                end, request, function()
                    done("iteration aborted by EnsureIterationIsComplete instead of continuing against the extended range")
                end)
            end)
        end)
    end)
end)

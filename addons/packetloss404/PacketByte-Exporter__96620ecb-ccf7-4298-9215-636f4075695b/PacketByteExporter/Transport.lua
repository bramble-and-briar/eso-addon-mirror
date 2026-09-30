local PBE = PacketByteExporter
PBE.Transport = {}
local Transport = PBE.Transport
local FRAME_DELAY_MS = 25
local JSON_OPERATIONS_PER_FRAME = 160
local CHECKSUM_BYTES_PER_FRAME = 2048
local COMPRESS_BYTES_PER_FRAME = 512
local SPLIT_CHUNKS_PER_FRAME = 16
local COLLECT_OPERATIONS_PER_FRAME = 24
local activeCapture

local function BuildExportId(checksum)
    return tostring(PBE.Now()) .. "-" .. checksum:sub(1, 8)
end

local function Separator(endpoint)
    if endpoint:find("?", 1, true) then
        return "&"
    end
    return "?"
end

function Transport.CreateQueue(profile, jsonBytes, checksum, compressedBytes, chunks, version)
    local queue = {
        checksum = checksum,
        compressedBytes = compressedBytes,
        createdAt = PBE.Now(),
        exportId = BuildExportId(checksum),
        jsonBytes = jsonBytes,
        last = 0,
        next = 1,
        profile = profile,
        version = version or 1,
        chunks = chunks,
        total = #chunks,
    }
    PBE.GetSettings().queue = queue
    return queue
end

local function FinishCapture(job)
    local queue = Transport.CreateQueue(
        job.profile, job.jsonBytes, job.checksum, #job.compressed, job.chunks, job.version
    )
    activeCapture = nil
    PBE.Print(string.format(
        "Captured %s export %s: %d JSON bytes compressed to %d bytes in %d chunks.",
        job.profile, queue.exportId, queue.jsonBytes, queue.compressedBytes, queue.total
    ))
    if PBE.GetSettings().endpoint == "" then
        PBE.Print("Set a receiver first: /pbe endpoint YOUR-PC-IP")
    else
        PBE.Print("Use the Submit next export chunk binding or /pbe next.")
    end
end

local function StepCapture(job)
    if job.phase == "collect" then
        local stage = job.stages[job.stageIndex]
        if stage then
            if stage.newStepper then
                job.stageStepper = job.stageStepper or stage.newStepper()
                local done, value = job.stageStepper:step(COLLECT_OPERATIONS_PER_FRAME)
                if done then
                    job.snapshot[stage.key] = value
                    job.stageStepper = nil
                    job.stageIndex = job.stageIndex + 1
                end
            else
                job.snapshot[stage.key] = stage.capture()
                job.stageIndex = job.stageIndex + 1
            end
        else
            job.encoder = PBE.Codec.NewJsonEncoder(job.snapshot, PBE.Schema.AliasKey)
            job.snapshot = nil
            job.stages = nil
            job.phase = "encode"
        end
    elseif job.phase == "encode" then
        if PBE.Codec.JsonEncoderStep(job.encoder, JSON_OPERATIONS_PER_FRAME) then
            job.json = PBE.Codec.JsonEncoderResult(job.encoder)
            job.jsonBytes = #job.json
            job.encoder = nil
            job.checksumState = PBE.Codec.NewChecksum()
            job.phase = "checksum"
        end
    elseif job.phase == "checksum" then
        if PBE.Codec.ChecksumStep(job.checksumState, job.json, CHECKSUM_BYTES_PER_FRAME) then
            job.checksum = PBE.Codec.ChecksumResult(job.checksumState)
            job.checksumState = nil
            job.compressor = PBE.Codec.NewPackedCompressor()
            job.phase = "compress"
        end
    elseif job.phase == "compress" then
        if PBE.Codec.PackedCompressStep(job.compressor, job.json, COMPRESS_BYTES_PER_FRAME) then
            job.compressed = PBE.Codec.PackedCompressorResult(job.compressor)
            job.compressor = nil
            job.json = nil
            job.chunks = {}
            job.splitIndex = 1
            job.phase = "split"
        end
    elseif job.phase == "split" then
        for _ = 1, SPLIT_CHUNKS_PER_FRAME do
            if job.splitIndex > #job.compressed then
                FinishCapture(job)
                return
            end
            job.chunks[#job.chunks + 1] = job.compressed:sub(
                job.splitIndex, job.splitIndex + PBE.chunkSize - 1
            )
            job.splitIndex = job.splitIndex + PBE.chunkSize
        end
    end
end

local function ScheduleCapture(job)
    zo_callLater(function()
        if activeCapture ~= job then
            return
        end
        local phase = job.phase
        local ok, err = pcall(StepCapture, job)
        if not ok then
            activeCapture = nil
            PBE.Print("Capture failed during " .. phase .. ": " .. tostring(err))
        elseif activeCapture == job then
            ScheduleCapture(job)
        end
    end, FRAME_DELAY_MS)
end

function Transport.Capture(profile)
    if activeCapture then
        PBE.Print("A capture is already running. Use /pbe status or /pbe cancel.")
        return nil
    end
    if profile ~= "quick" and profile ~= "build" and profile ~= "all"
        and profile ~= "skills" and profile ~= "crafting" and profile ~= "quests" then
        profile = "build"
    end
    local ok, stages = pcall(PBE.Collectors.GetStages, profile)
    if not ok then
        PBE.Print("Capture could not start: " .. tostring(stages))
        return nil
    end
    local job = {
        phase = "collect",
        profile = profile,
        version = 2,
        snapshot = {},
        stageIndex = 1,
        stages = stages,
    }
    activeCapture = job
    PBE.Print("Capturing " .. profile .. " across frames. Use /pbe status to check progress.")
    ScheduleCapture(job)
    return nil
end

function Transport.CancelCapture()
    if not activeCapture then
        PBE.Print("No capture is running.")
        return
    end
    activeCapture = nil
    PBE.Print("Capture cancelled. The previous completed export queue, if any, is unchanged.")
end

function Transport.GetStatus()
    if activeCapture then
        local detail = activeCapture.phase
        if detail == "collect" then
            local stage = activeCapture.stages[activeCapture.stageIndex]
            detail = stage and ("collecting " .. stage.key) or "preparing encoder"
        end
        PBE.Print("Capture in progress: " .. detail .. ". Use /pbe cancel to stop it.")
        return
    end
    local queue = PBE.GetSettings().queue
    if not queue then
        PBE.Print("No export is queued. Use /pbe quick, /pbe capture, or /pbe all.")
        return
    end
    local submitted = math.min((queue.next or 1) - 1, queue.total or 0)
    PBE.Print(string.format(
        "Export %s (%s): %d/%d chunks attempted; next is %d.",
        queue.exportId,
        queue.profile,
        submitted,
        queue.total,
        queue.next or 1
    ))
end

local function BuildUrl(queue, part)
    local endpoint = PBE.GetSettings().endpoint or ""
    local chunk = queue.chunks[part]
    return endpoint
        .. Separator(endpoint)
        .. "v=" .. tostring(queue.version or 1) .. "&e=" .. queue.exportId
        .. "&p=" .. tostring(part)
        .. "&n=" .. tostring(queue.total)
        .. "&h=" .. queue.checksum
        .. "&m=" .. queue.profile
        .. "&d=" .. chunk
end

local function OpenPart(part, advance)
    if activeCapture then
        PBE.Print("Capture is still preparing the export. Use /pbe status.")
        return
    end
    local settings = PBE.GetSettings()
    local queue = settings.queue
    if not queue then
        PBE.Print("No export is queued. Use /pbe quick, /pbe capture, or /pbe all.")
        return
    end
    if not settings.endpoint or settings.endpoint == "" then
        PBE.Print("No receiver configured. Use /pbe endpoint YOUR-PC-IP")
        return
    end
    if not settings.endpoint:match("^https?://") then
        PBE.Print("The receiver must start with http:// or https://")
        return
    end
    if part < 1 or part > queue.total then
        PBE.Print("All chunks have been attempted. Check the receiver or use /pbe retry.")
        return
    end

    local url = BuildUrl(queue, part)
    local ok, err = pcall(RequestOpenUnsafeURL, url)
    if not ok then
        PBE.Print("Could not open export URL: " .. tostring(err))
        return
    end
    queue.last = part
    if advance then
        queue.next = part + 1
    end
    PBE.Print(string.format("Opened chunk %d/%d for approval.", part, queue.total))
end

function Transport.SubmitNext()
    local queue = PBE.GetSettings().queue
    OpenPart(queue and (queue.next or 1) or 1, true)
end

function Transport.RetryLast()
    local queue = PBE.GetSettings().queue
    if not queue or not queue.last or queue.last < 1 then
        PBE.Print("No previously attempted chunk to retry.")
        return
    end
    OpenPart(queue.last, false)
end

function Transport.Rewind()
    if activeCapture then
        PBE.Print("Capture is still preparing the export. Use /pbe status.")
        return
    end
    local queue = PBE.GetSettings().queue
    if not queue then
        PBE.Print("No export is queued.")
        return
    end
    queue.next = math.max(1, (queue.next or 1) - 1)
    PBE.Print("Rewound. Next chunk is now " .. tostring(queue.next) .. ".")
end

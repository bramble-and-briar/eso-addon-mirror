-- DevSandbox3DetectionUtils.lua: HarvestMap's compass maths (no side effects)
--
-- From HarvestMap Console 3.16.6 NodeDetection/Detection.lua (Shinni). The engine lays a compass pin out at a strip
-- position that depends on the horizontal angle to the camera; Shinni measured that function and inverts it with a
-- piecewise-linear table. The pin's scale encodes distance: closeScale 2.0 at 0 m -> farScale 0.0 at 200 m.
local DetectionUtils = {}

local offset = 0.005
DetectionUtils.ARC_COORDS = {
    offset,
    --0.0051947677,
    0.0159936977,
    0.0399850114,
    0.0675543836,
    0.1022636077,
    0.1356943180,
    0.1749565977,
    0.2152086055,
    0.2375973271,
    0.2634134230,
    0.3065370230,
    0.3354407635,
    0.3526835132,
    0.3778287424,
    0.3971341160,
    0.4208228338,
    0.4376307170,
    0.4565601474,
    0.4786610039,
    0.4972964314,
    0.5233592688,
    0.5512536401,
    0.5756193626,
    0.5955185730,
    0.6223989718,
    0.6438041032,
    0.6609244029,
    0.6719013304,
    0.6857532260,
    0.7023932390,
    0.7188300893,
    0.7360068572,
    0.7510755812,
    0.7622510681,
    0.7723987723,
    0.7851793065,
    0.7969084273,
    0.8040602479,
    0.8190850862,
    0.8286816117,
    0.8441680162,
    0.8560241905,
    0.8652220627,
    0.8792307803,
    0.8913809575,
    0.8993693668,
    0.9135220169,
    0.9204875538,
    0.9334408684,
    0.9431641405,
    0.9556390098,
    0.9635641993,
    0.9727795644,
    0.9769775456,
    0.9852679370,
    0.9907161979,
    0.9967693437
}

DetectionUtils.ARC_COTANGENTS = {
    0.0,
  -- -0.0004722493,
    0.0085273034,
    0.0285333869,
    0.0515696229,
    0.0806963688,
    0.1089478714,
    0.1424698159,
    0.1773397682,
    0.1970044971,
    0.2199598529,
    0.2590834413,
    0.2859391355,
    0.3022354622,
    0.3264079847,
    0.3453245844,
    0.3690022725,
    0.3861396535,
    0.4058039954,
    0.4292895232,
    0.4495709557,
    0.4787399772,
    0.5111067515,
    0.5404631615,
    0.5652689374,
    0.6000939111,
    0.6290229445,
    0.6530064915,
    0.6688099199,
    0.6892637656,
    0.7146379784,
    0.7406365624,
    0.7688877909,
    0.7946643060,
    0.8144304050,
    0.8328914282,
    0.8568829405,
    0.8796816632,
    0.8939722234,
    0.9250310727,
    0.9456528901,
    0.9803411060,
    1.0081780907,
    1.0306066431,
    1.0662892661,
    1.0988650428,
    1.1211842878,
    1.1626498188,
    1.1840383319,
    1.2257112395,
    1.2587682683,
    1.3036665641,
    1.3337922969,
    1.3705564259,
    1.3879692677,
    1.4236807059,
    1.4481727585,
    1.4764147356,
}

-- compute cotangent (ratio of right/forward) based on
-- relative position of the pin on the compass
-- returns nil if computation failed

---@param relativeX number -1..1 on the compass strip
---@return number|nil cot(angle), positive = right of camera forward; nil near the edges
function DetectionUtils.ComputeCotangent(relativeX)
    local coords, cotangents = DetectionUtils.ARC_COORDS, DetectionUtils.ARC_COTANGENTS
    local sign = 1
    if relativeX < 0 then sign = -1; relativeX = -relativeX end
    relativeX = relativeX + offset
    for i = 2, #coords do
        if coords[i] >= relativeX then
            local t = (relativeX - coords[i - 1]) / (coords[i] - coords[i - 1])
            return ((1 - t) * cotangents[i - 1] + t * cotangents[i]) * sign
        end
    end
    return nil
end

---Are three samples within 3 m of their mean? (HarvestMap's acceptance rule)
---@param xs number[] exactly 3
---@param zs number[]
---@return boolean
function DetectionUtils.IsStable(xs, zs)
    local mx, mz = (xs[1] + xs[2] + xs[3]) / 3, (zs[1] + zs[2] + zs[3]) / 3
    for i = 1, 3 do
        local dx, dz = mx - xs[i], mz - zs[i]
        if dx * dx + dz * dz > 9 then return false end
    end
    return true
end

DevSandbox3.DetectionUtils = DetectionUtils

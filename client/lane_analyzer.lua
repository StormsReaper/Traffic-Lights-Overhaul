local LaneAnalyzer = {}
LaneAnalyzer.state = {}

local function dist(a, b) return #(a - b) end
local function normalize(v)
    local n = #v
    if n < 0.001 then return vector3(0.0, 0.0, 0.0) end
    return v / n
end

local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function crossZ(a, b) return a.x * b.y - a.y * b.x end

local function approachVector(intersection, vehicle)
    local p = GetEntityCoords(vehicle)
    return normalize(vector3(p.x - intersection.center.x, p.y - intersection.center.y, 0.0))
end

local function classifyApproach(intersection, vehicle)
    local p = GetEntityCoords(vehicle)
    local dx, dy = p.x - intersection.center.x, p.y - intersection.center.y
    if math.abs(dy) >= math.abs(dx) then return dy >= 0.0 and 'NORTH' or 'SOUTH' end
    return dx >= 0.0 and 'EAST' or 'WEST'
end

local function classifyLane(intersection, vehicle, approach)
    local p = GetEntityCoords(vehicle)
    local center = intersection.center
    local laneWidth = math.max(Config.LaneAnalysis.LaneWidth, 2.5)
    local lateral

    if approach == 'NORTH' or approach == 'SOUTH' then
        lateral = p.x - center.x
    else
        lateral = p.y - center.y
    end

    local index = math.floor((lateral / laneWidth) + 0.5)
    local maxLanes = Config.LaneAnalysis.MaxLanesPerApproach
    index = math.max(-maxLanes, math.min(maxLanes, index))

    -- GTA maps vary considerably. We expose the raw lane index and a simple
    -- movement guess rather than pretending every intersection has identical
    -- lane markings.
    local movement = 'THROUGH'
    if math.abs(index) >= 1 then
        movement = index < 0 and 'LEFT' or 'RIGHT'
    end

    return {
        index = index,
        movement = movement,
        lateral = lateral,
        confidence = math.min(1.0, math.abs(lateral) / laneWidth)
    }
end

local function movementEstimate(intersection, vehicle, approach, lane)
    local forward = normalize(GetEntityForwardVector(vehicle))
    local radial = approachVector(intersection, vehicle)
    local turn = crossZ(radial, forward)

    -- A vehicle pointing approximately toward the center is probably going
    -- straight. Lateral heading indicates a turn, but remains a heuristic.
    local alignment = dot(forward, radial * -1.0)
    if alignment > Config.LaneAnalysis.ThroughAlignment then
        return 'THROUGH', math.min(1.0, alignment)
    end

    if turn > Config.LaneAnalysis.TurnThreshold then
        return 'LEFT', math.min(1.0, math.abs(turn))
    elseif turn < -Config.LaneAnalysis.TurnThreshold then
        return 'RIGHT', math.min(1.0, math.abs(turn))
    end

    return lane.movement, 0.35
end

local function analyzeVehicle(intersection, vehicle)
    if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then return nil end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or not DoesEntityExist(driver) or IsPedAPlayer(driver) then return nil end

    local p = GetEntityCoords(vehicle)
    local d = dist(p, intersection.center)
    if d > Config.LaneAnalysis.DetectionDistance or d < Config.LaneAnalysis.IntersectionClearDistance then return nil end

    local approach = classifyApproach(intersection, vehicle)
    local lane = classifyLane(intersection, vehicle, approach)
    local movement, confidence = movementEstimate(intersection, vehicle, approach, lane)

    return {
        vehicle = vehicle,
        driver = driver,
        approach = approach,
        axis = (approach == 'NORTH' or approach == 'SOUTH') and 'NS' or 'EW',
        lane = lane,
        movement = movement,
        confidence = confidence,
        distance = d,
        speed = GetEntitySpeed(vehicle),
        position = p
    }
end

function LaneAnalyzer.update(intersection)
    local state = LaneAnalyzer.state[intersection.key]
    if not state then
        state = { vehicles = {}, queues = { NORTH = {}, SOUTH = {}, EAST = {}, WEST = {} }, lastUpdate = 0 }
        LaneAnalyzer.state[intersection.key] = state
    end

    local now = GetGameTimer()
    if now - state.lastUpdate < Config.LaneAnalysis.UpdateInterval then return state end
    state.lastUpdate = now
    state.vehicles = {}
    state.queues = { NORTH = {}, SOUTH = {}, EAST = {}, WEST = {} }

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local data = analyzeVehicle(intersection, vehicle)
        if data then
            state.vehicles[#state.vehicles + 1] = data
            state.queues[data.approach][#state.queues[data.approach] + 1] = data
        end
    end

    for _, queue in pairs(state.queues) do
        table.sort(queue, function(a, b) return a.distance < b.distance end)
    end

    intersection.laneState = state
    return state
end

function LaneAnalyzer.get(intersection)
    return LaneAnalyzer.state[intersection.key]
end

_G.TLOLaneAnalyzer = LaneAnalyzer

CreateThread(function()
    while true do
        if Config.LaneAnalysis.Enabled and _G.TLOIntersections then
            for _, intersection in pairs(_G.TLOIntersections) do
                LaneAnalyzer.update(intersection)
            end
        end
        Wait(Config.LaneAnalysis.UpdateInterval)
    end
end)

local TrafficAI = {}
TrafficAI.states = {}

local function distance(a, b) return #(a - b) end

local function normalize(v)
    local len = #v
    if len < 0.001 then return vector3(0.0, 0.0, 0.0) end
    return v / len
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function approach(center, coords)
    local dx, dy = coords.x - center.x, coords.y - center.y
    if math.abs(dy) >= math.abs(dx) then return dy >= 0 and 'NORTH' or 'SOUTH' end
    return dx >= 0 and 'EAST' or 'WEST'
end

local function axis(dir)
    return (dir == 'NORTH' or dir == 'SOUTH') and 'NS' or 'EW'
end

local function controlledVehicle(vehicle)
    if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then return false end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or not DoesEntityExist(driver) or IsPedAPlayer(driver) then return false end
    return true, driver
end

local function approaching(vehicle, center)
    local coords = GetEntityCoords(vehicle)
    local delta = center - coords
    local dist = #delta
    if dist > Config.NpcTraffic.DetectionRadius or dist < Config.NpcTraffic.IntersectionClearRadius then return false, dist end
    if GetEntitySpeed(vehicle) < 0.25 then return false, dist end
    local forward = GetEntityForwardVector(vehicle)
    return dot(forward, normalize(delta)) >= Config.NpcTraffic.LookAheadDot, dist
end

local function emergency(vehicle)
    return Config.Emergency.Enabled and GetVehicleClass(vehicle) == 18 and IsVehicleSirenOn(vehicle)
end

function TrafficAI.shouldStop(intersection, vehicle)
    if emergency(vehicle) then return false end
    local phase = intersection.phase
    if not phase then return true end
    local a = axis(approach(intersection.center, GetEntityCoords(vehicle)))
    if phase == 'NS_GREEN' and a == 'NS' then return false end
    if phase == 'EW_GREEN' and a == 'EW' then return false end
    return true
end

local function stop(driver, vehicle)
    SetDriveTaskDrivingStyle(driver, Config.NpcTraffic.DrivingStyle)
    SetDriveTaskMaxCruiseSpeed(driver, Config.NpcTraffic.StopApproachSpeed)
    TaskVehicleTempAction(driver, vehicle, Config.NpcTraffic.StopAction, Config.NpcTraffic.StopActionDuration)
end

local function release(driver)
    SetDriveTaskDrivingStyle(driver, Config.NpcTraffic.DrivingStyle)
    SetDriveTaskMaxCruiseSpeed(driver, Config.NpcTraffic.ReleaseSpeed)
    ClearPedTasks(driver)
end

local function process(intersection, vehicle)
    local valid, driver = controlledVehicle(vehicle)
    if not valid then return end
    local isApproaching, dist = approaching(vehicle, intersection.center)
    if not isApproaching then return end

    local state = TrafficAI.states[vehicle]
    if not state then state = { stopped = false } TrafficAI.states[vehicle] = state end
    state.lastSeen = GetGameTimer()
    state.intersection = intersection.key
    state.distance = dist

    if TrafficAI.shouldStop(intersection, vehicle) then
        stop(driver, vehicle)
        state.stopped = true
    elseif state.stopped then
        release(driver)
        state.stopped = false
    end
end

function TrafficAI.update(intersection)
    if not Config.NpcTraffic.Enabled then return end
    local playerCoords = GetEntityCoords(PlayerPedId())
    if distance(playerCoords, intersection.center) > Config.NpcTraffic.ControlRadius then return end

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do process(intersection, vehicle) end

    local now = GetGameTimer()
    for vehicle, state in pairs(TrafficAI.states) do
        if now - (state.lastSeen or 0) > 5000 or not DoesEntityExist(vehicle) then TrafficAI.states[vehicle] = nil end
    end
end

return TrafficAI
